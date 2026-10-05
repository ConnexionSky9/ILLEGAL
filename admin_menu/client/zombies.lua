-- =========================================================
--  ÉVÉNEMENT : ATTAQUE DE ZOMBIES - CLIENT
--  * Ambiance : filtre d'image, éclairs, ville vidée de ses passants.
--  * Cerveau des zombies : chaque client pilote les zombies dont il est
--    propriétaire réseau (marcheurs / coureurs, poursuite, corps à corps).
--  * Morts du joueur : relevé sur place après quelques secondes, armes et
--    inventaire intacts (on ne passe jamais par la réapparition à l'hôpital).
-- =========================================================
local ZC = Config.Zombies
local Z = { active = false }           -- état reçu du serveur
local Kills = 0
local Configured = {}                  -- [ped] = true quand le zombie est réglé par ce client
local Orders = {}                      -- [ped] = { mode, target, at }
local Owned = {}                       -- zombies contrôlés par ce client (liste rafraîchie)
local zombieGroup = nil
local reviving = false
local Missions, Hold = {}, nil         -- missions de l'événement (voir plus bas)
local refreshMissionBlips              -- défini avec les missions

local function hud()
    SendNUIMessage({ action = 'zombiehud', active = Z.active, remaining = Z.active and math.max(0, math.floor((Z.endAt - GetGameTimer()) / 1000)) or 0, kills = Kills })
end

-- ---------------------------------------------------------
--  État
-- ---------------------------------------------------------
local function setGroups()
    if zombieGroup then return end
    local _, hash = AddRelationshipGroup('AM_ZOMBIE')
    zombieGroup = hash
    local player = GetHashKey('PLAYER')
    SetRelationshipBetweenGroups(5, zombieGroup, player)
    SetRelationshipBetweenGroups(5, player, zombieGroup)
    SetRelationshipBetweenGroups(1, zombieGroup, zombieGroup)
end

local function applyAmbience(on)
    if on and Z.timecycle and Z.timecycle ~= '' then
        SetTimecycleModifier(Z.timecycle)
        SetTimecycleModifierStrength(Z.timecycleStrength or 0.5)
    else
        ClearTimecycleModifier()
    end
    SetAiMeleeWeaponDamageModifier(on and (Z.damage or 1.0) or 1.0)
end

RegisterNetEvent('adminmenu:zombies:state', function(state)
    local was = Z.active
    Z = type(state) == 'table' and state or { active = false }
    if Z.active then
        Z.endAt = GetGameTimer() + (tonumber(Z.remaining) or 0) * 1000
        setGroups()
    else
        Kills = 0
        Configured, Orders, Owned = {}, {}, {}
        Missions = {}
        Hold = nil
        refreshMissionBlips()
    end
    applyAmbience(Z.active)
    if Z.active and not was then Notify('☣ Attaque de zombies en cours : mourir ne te fait rien perdre.', 'error') end
    hud()
end)

RegisterNetEvent('adminmenu:zombies:kills', function(n)
    Kills = tonumber(n) or Kills
    hud()
end)

CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(500) end
    Wait(2000)
    TriggerServerEvent('adminmenu:zombies:request')
end)

-- Compte à rebours du bandeau (une mise à jour par seconde)
CreateThread(function()
    while true do
        if Z.active then hud() Wait(1000) else Wait(2000) end
    end
end)

-- ---------------------------------------------------------
--  Points d'apparition demandés par le serveur
-- ---------------------------------------------------------
RegisterNetEvent('adminmenu:zombies:spawnRequest', function(n, minD, maxD)
    if not Z.active then return end
    n = math.min(tonumber(n) or 0, 6)
    minD, maxD = tonumber(minD) or 35.0, tonumber(maxD) or 85.0
    local spots = {}
    local ped = PlayerPedId()
    local pc = GetEntityCoords(ped)
    if n <= 0 or GetInteriorFromEntity(ped) ~= 0 or (IsInSafeZone and IsInSafeZone(pc)) then
        return TriggerServerEvent('adminmenu:zombies:spots', spots)
    end

    for attempt = 1, n * 6 do
        if #spots >= n then break end
        local angle = math.random() * 2.0 * math.pi
        local dist = minD + math.random() * (maxD - minD)
        local x, y = pc.x + math.cos(angle) * dist, pc.y + math.sin(angle) * dist
        local okGround, gz = GetGroundZFor_3dCoord(x, y, pc.z + 40.0, false)
        if okGround then
            local ok, safe = GetSafeCoordForPed(x, y, gz + 1.0, false, 16)          -- trottoir en priorité
            if not ok then ok, safe = GetSafeCoordForPed(x, y, gz + 1.0, false, 0) end
            if ok and safe then
                local hidden = not IsSphereVisible(safe.x, safe.y, safe.z, 1.2)       -- hors du champ de vision si possible
                local inSafe = IsInSafeZone and IsInSafeZone(safe)
                if not inSafe and (hidden or attempt > n * 3) then
                    spots[#spots + 1] = { x = safe.x, y = safe.y, z = safe.z, h = math.random() * 360.0 }
                end
            end
        end
    end
    TriggerServerEvent('adminmenu:zombies:spots', spots)
end)

-- ---------------------------------------------------------
--  Réglage d'un zombie (par son propriétaire réseau)
-- ---------------------------------------------------------
local clipsetReady = false
local function loadClipset()
    if clipsetReady then return true end
    RequestAnimSet(ZC.walkClipset)
    local limit = GetGameTimer() + 2000
    while not HasAnimSetLoaded(ZC.walkClipset) and GetGameTimer() < limit do Wait(20) end
    clipsetReady = HasAnimSetLoaded(ZC.walkClipset)
    return clipsetReady
end

local function configure(ped, runner)
    local st = Entity(ped).state
    if not st.zdressed then
        SetPedRandomComponentVariation(ped, 0)
        SetPedRandomProps(ped)
        st:set('zdressed', true, true)
    end
    ApplyPedDamagePack(ped, 'BigHitByVehicle', 0.0, 9.0)
    ApplyPedDamagePack(ped, 'SCR_Dumpster', 0.0, 9.0)

    -- Vie fixée une seule fois (sinon un zombie blessé guérirait en changeant de propriétaire)
    local hp = Z.headshot and ZC.headshotHealth or ZC.health
    SetEntityMaxHealth(ped, hp)
    if not st.zhealth then
        SetEntityHealth(ped, hp)
        st:set('zhealth', true, true)
    end
    SetPedSuffersCriticalHits(ped, true)

    RemoveAllPedWeapons(ped, true)
    SetPedDropsWeaponsWhenDead(ped, false)
    SetPedMoney(ped, 0)
    SetPedRelationshipGroupHash(ped, zombieGroup)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 46, true)   -- se bat toujours
    SetPedCombatAttributes(ped, 5, true)    -- attaque même un joueur armé
    SetPedCombatAttributes(ped, 1, false)   -- n'utilise pas de véhicule
    SetPedCombatAttributes(ped, 0, false)   -- pas de couverture
    SetPedCombatAbility(ped, 0)
    SetPedCombatRange(ped, 0)
    SetPedCanEvasiveDive(ped, false)
    SetPedConfigFlag(ped, 281, true)          -- pas d'agonie au sol
    SetPedCanRagdollFromPlayerImpact(ped, false)
    SetPedKeepTask(ped, true)
    SetPedPathCanUseClimbovers(ped, true)
    StopPedSpeaking(ped, true)
    if not runner and loadClipset() then SetPedMovementClipset(ped, ZC.walkClipset, 1.0) end
    Configured[ped] = true
end

-- Cible la plus proche (joueur vivant, hors safe zone)
local function nearestTarget(pc)
    local best, bestD = nil, ZC.aggroRange
    for _, player in ipairs(GetActivePlayers()) do
        local tp = GetPlayerPed(player)
        if tp ~= 0 and not IsEntityDead(tp) then
            local d = #(GetEntityCoords(tp) - pc)
            if d < bestD and not (IsInSafeZone and IsInSafeZone(GetEntityCoords(tp))) then best, bestD = tp, d end
        end
    end
    return best, bestD
end

local ATK = ZC.attack or { range = 1.8, cooldown = 800, damage = 12, knockdown = 8, dict = 'melee@unarmed@streamed_variations', anim = 'plyr_takedown_front_slap' }
local SPIT = ZC.spit or { minRange = 5.0, maxRange = 24.0, cooldown = 4000, speed = 20.0, damage = 14, burn = 3, burnDamage = 2, hitRadius = 2.0, dict = 'random@drunk_driver_1', anim = 'vomit_outside' }
local Swing, SpitCd = {}, {}            -- [ped] = prochain coup / prochain crachat possible
local function loadDict(d)
    if HasAnimDictLoaded(d) then return true end
    RequestAnimDict(d)
    local t = GetGameTimer() + 1500
    while not HasAnimDictLoaded(d) and GetGameTimer() < t do Wait(10) end
    return HasAnimDictLoaded(d)
end

local function think(ped, runner, spitter)
    local pc = GetEntityCoords(ped)
    if IsInSafeZone and IsInSafeZone(pc) then
        -- Un zombie ne reste pas dans une safe zone
        SetEntityHealth(ped, 0)
        return
    end
    local o = Orders[ped] or {}
    local t = GetGameTimer()
    local gnet = Entity(ped).state.zguard
    if gnet and GuardThink and GuardThink(ped, gnet, runner, o, t) then return end
    local target, dist = nearestTarget(pc)

    if not target then
        if o.mode ~= 'wander' then
            TaskWanderStandard(ped, 10.0, 10)
            Orders[ped] = { mode = 'wander', at = t }
        end
        return
    end
    -- Cracheur à bonne distance : il s'arrête, se tourne vers sa cible (le crachat est géré plus bas)
    if spitter and dist >= SPIT.minRange and dist <= SPIT.maxRange and HasEntityClearLosToEntity(ped, target, 17) then
        if o.mode ~= 'aim' or o.target ~= target or t - o.at > 2000 then
            TaskTurnPedToFaceEntity(ped, target, -1)
            Orders[ped] = { mode = 'aim', target = target, at = t }
        end
        return
    end
    -- Tous les autres : ils foncent jusqu'au contact et ne s'arrêtent jamais (ils frappent en marchant)
    if o.mode ~= 'chase' or o.target ~= target or t - o.at > 2500 then
        TaskGoToEntity(ped, target, -1, 0.3, runner and 3.0 or 1.0, 1073741824, 0)
        Orders[ped] = { mode = 'chase', target = target, at = t }
    end
end

-- Cerveau : liste des zombies contrôlés + ordres (toutes les 700 ms)
CreateThread(function()
    while true do
        if Z.active then
            local list = {}
            for _, ped in ipairs(GetGamePool('CPed')) do
                if not IsPedAPlayer(ped) then
                    local kind = Entity(ped).state.zombie
                    if kind and NetworkHasControlOfEntity(ped) and not IsPedDeadOrDying(ped, true) then
                        local runner, spitter = kind == 2, kind == 3
                        if not Configured[ped] then configure(ped, runner) end
                        think(ped, runner, spitter)
                        list[#list + 1] = ped
                    end
                end
            end
            Owned = list
            -- Nettoyage des entités disparues
            for ped in pairs(Configured) do
                if not DoesEntityExist(ped) then Configured[ped], Orders[ped] = nil, nil end
            end
            Wait(700)
        else
            Wait(1500)
        end
    end
end)

-- ---------------------------------------------------------
--  Attaques rapides (zombies contrôlés par ce client), 10 fois par seconde
--  Coup : animation du haut du corps PENDANT la marche -> il arrive et frappe aussitôt.
-- ---------------------------------------------------------
local function targetOf(ped)
    local o = Orders[ped]
    return o and o.target and DoesEntityExist(o.target) and o.target or nil
end
CreateThread(function()
    while true do
        if Z.active and #Owned > 0 then
            local now = GetGameTimer()
            for i = 1, #Owned do
                local ped = Owned[i]
                local target = DoesEntityExist(ped) and not IsPedDeadOrDying(ped, true) and targetOf(ped)
                if target and not IsEntityDead(target) then
                    local dist = #(GetEntityCoords(ped) - GetEntityCoords(target))
                    local spitter = Entity(ped).state.zombie == 3
                    if dist <= ATK.range and (Swing[ped] or 0) <= now then
                        Swing[ped] = now + ATK.cooldown
                        if loadDict(ATK.dict) then
                            TaskPlayAnim(ped, ATK.dict, ATK.anim, 8.0, -8.0, math.min(900, ATK.cooldown), 48, 0, false, false, false)
                        end
                        local pl = NetworkGetPlayerIndexFromPed(target)
                        if pl ~= -1 then
                            local zped, tgt, sid = ped, target, GetPlayerServerId(pl)
                            SetTimeout(280, function()   -- le coup porte au milieu de l'animation
                                if DoesEntityExist(zped) and not IsPedDeadOrDying(zped, true) and DoesEntityExist(tgt)
                                    and #(GetEntityCoords(zped) - GetEntityCoords(tgt)) <= ATK.range + 0.8 then
                                    TriggerServerEvent('adminmenu:zombies:melee', NetworkGetNetworkIdFromEntity(zped), sid)
                                end
                            end)
                        end
                    elseif spitter and dist >= SPIT.minRange and dist <= SPIT.maxRange and (SpitCd[ped] or 0) <= now
                        and HasEntityClearLosToEntity(ped, target, 17) then
                        SpitCd[ped] = now + SPIT.cooldown + math.random(0, 1200)
                        local pl = NetworkGetPlayerIndexFromPed(target)
                        if pl ~= -1 then
                            if loadDict(SPIT.dict) then TaskPlayAnim(ped, SPIT.dict, SPIT.anim, 8.0, -8.0, 900, 48, 0, false, false, false) end
                            local zped, tgt = ped, target
                            SetTimeout(450, function()
                                if not DoesEntityExist(zped) or IsPedDeadOrDying(zped, true) or not DoesEntityExist(tgt) then return end
                                -- On vise là où sera la cible (un peu en avance) : en bougeant, on peut l'esquiver
                                local tc, vel = GetEntityCoords(tgt), GetEntityVelocity(tgt)
                                local travel = #(GetEntityCoords(zped) - tc) / SPIT.speed
                                local aim = tc + vel * (travel * 0.6)
                                TriggerServerEvent('adminmenu:zombies:spit', NetworkGetNetworkIdFromEntity(zped), GetPlayerServerId(pl), { x = aim.x, y = aim.y, z = aim.z })
                            end)
                        end
                    end
                end
            end
            for ped in pairs(Swing) do if not DoesEntityExist(ped) then Swing[ped], SpitCd[ped] = nil, nil end end
            Wait(100)
        else
            Wait(800)
        end
    end
end)

-- ---------------------------------------------------------
--  Coups reçus : validés par le serveur (fiables pour tout le monde)
-- ---------------------------------------------------------
local function protected()
    local me = PlayerPedId()
    return reviving or IsEntityDead(me) or GetPlayerInvincible(PlayerId()) or (IsInSafeZone and IsInSafeZone(GetEntityCoords(me)))
end
RegisterNetEvent('adminmenu:zombies:hurt', function(kind, from)
    if not Z.active or protected() then return end
    local me = PlayerPedId()
    if kind == 'boss' then
        local m = BossMelee or { damage = 40 }
        ApplyDamageToPed(me, math.floor((m.damage or 40) * (Z.damage or 1.0)), false)
        ShakeGameplayCam('MEDIUM_EXPLOSION_SHAKE', 0.35)
        PlayPain(me, 7, 0.0, 0)
        if not IsPedInAnyVehicle(me, false) and from then
            -- Projeté en arrière par le coup du boss
            local dir = GetEntityCoords(me) - vector3(from.x, from.y, from.z)
            local l = #dir
            dir = l > 0.1 and dir / l or vector3(0.0, 1.0, 0.0)
            SetPedToRagdoll(me, 1600, 1600, 0, false, false, false)
            ApplyForceToEntity(me, 1, dir.x * 7.0, dir.y * 7.0, 2.5, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
        end
    else
        ApplyDamageToPed(me, math.floor((ATK.damage or 12) * (Z.damage or 1.0)), false)
        ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.12)
        PlayPain(me, 6, 0.0, 0)
        if math.random(100) <= (ATK.knockdown or 0) and not IsPedInAnyVehicle(me, false) then
            SetPedToRagdoll(me, 900, 900, 0, false, false, false)
        end
    end
end)

-- ---------------------------------------------------------
--  Crachat acide : chacun dessine le projectile, seule la cible encaisse
--  (s'il est encore dans l'éclaboussure à l'arrivée : on peut l'esquiver)
-- ---------------------------------------------------------
local function acidBurn()
    AnimpostfxPlay('DrugsMichaelAliensFightIn', 0, false)
    CreateThread(function()
        for _ = 1, SPIT.burn or 3 do
            Wait(1000)
            if not Z.active then break end
            local me = PlayerPedId()
            if not IsEntityDead(me) and not reviving then ApplyDamageToPed(me, SPIT.burnDamage or 2, false) end
        end
        AnimpostfxStop('DrugsMichaelAliensFightIn')
        AnimpostfxPlay('DrugsMichaelAliensFightOut', 0, false)
        Wait(1200)
        AnimpostfxStop('DrugsMichaelAliensFightOut')
    end)
end
-- Outils d'effets : particules teintées (un seul chargement), trajectoire en cloche
local function ptfx()
    if HasNamedPtfxAssetLoaded('core') then return true end
    RequestNamedPtfxAsset('core')
    local t = GetGameTimer() + 800
    while not HasNamedPtfxAssetLoaded('core') and GetGameTimer() < t do Wait(0) end
    return HasNamedPtfxAssetLoaded('core')
end
local function burst(name, pos, scale, r, g, b)
    if not ptfx() then return end
    UseParticleFxAssetNextCall('core')
    if r then SetParticleFxNonLoopedColour(r / 255, g / 255, b / 255) end
    StartParticleFxNonLoopedAtCoord(name, pos.x, pos.y, pos.z, 0.0, 0.0, 0.0, scale, false, false, false)
end
-- Point de la trajectoire en cloche (k de 0 à 1)
local function arcPoint(a, b, k, h)
    local p = a + (b - a) * k
    return vector3(p.x, p.y, p.z + h * 4.0 * k * (1.0 - k))
end
-- Flaque / impact collé au sol (décalque teinté qui s'efface tout seul)
local function groundDecal(pos, size, r, g, b, life)
    local ok, gz = GetGroundZFor_3dCoord(pos.x, pos.y, pos.z + 1.5, false)
    local z = ok and gz or pos.z
    AddDecal(1010, pos.x, pos.y, z + 0.05, 0.0, 0.0, -1.0, 0.0, 1.0, 0.0, size, size, r / 255, g / 255, b / 255, 1.0, life, false, false, false)
end

-- ---------------------------------------------------------
--  CRACHAT D'ACIDE (réaliste)
--  Jet de liquide en cloche : un paquet principal suivi de gouttelettes,
--  traînée d'éclaboussures vertes, impact qui gicle, flaque qui fume.
-- ---------------------------------------------------------
RegisterNetEvent('adminmenu:zombies:spitFx', function(from, to, targetSid, kind)
    if not Z.active then return end
    if kind == 'boss' and BossThrowFx then return BossThrowFx(from, to, targetSid) end
    local a, b = vector3(from.x, from.y, from.z), vector3(to.x, to.y, to.z - 0.6)
    local dist = #(b - a)
    local dur = math.max(180, dist / (SPIT.speed or 20.0) * 1000)
    local h = math.min(3.0, 0.4 + dist * 0.07)
    local mine = targetSid == GetPlayerServerId(PlayerId())
    CreateThread(function()
        local start, lastDrop = GetGameTimer(), 0
        while true do
            local k = (GetGameTimer() - start) / dur
            if k >= 1.0 then break end
            -- Paquet principal + 5 gouttelettes qui suivent, de plus en plus petites
            for i = 0, 5 do
                local kk = k - i * 0.025
                if kk > 0 then
                    local p = arcPoint(a, b, kk, h)
                    local sz = (i == 0 and 0.13 or 0.09 - i * 0.012)
                    DrawMarker(28, p.x, p.y, p.z, 0, 0, 0, 0, 0, 0, sz, sz, sz * 1.25, 95, 150, 30, 235 - i * 30, false, false, 2, false, nil, nil, false)
                end
            end
            -- Traînée de liquide (petites éclaboussures vertes le long du trajet)
            if GetGameTimer() - lastDrop > 45 then
                lastDrop = GetGameTimer()
                burst('ent_sht_water', arcPoint(a, b, k, h), 0.22, 110, 190, 30)
            end
            Wait(0)
        end
        -- Impact : ça gicle, puis une flaque d'acide reste au sol
        burst('ent_sht_water', b, 1.3, 110, 190, 30)
        burst('ent_sht_water', b + vector3(0.3, 0.2, 0.0), 0.8, 140, 210, 40)
        groundDecal(b, (SPIT.hitRadius or 2.0) * 0.9, 90, 170, 20, 12.0)
        if mine and not protected() and #(GetEntityCoords(PlayerPedId()) - b) <= (SPIT.hitRadius or 2.0) + 0.4 then
            local me = PlayerPedId()
            ApplyDamageToPed(me, math.floor((SPIT.damage or 14) * (Z.damage or 1.0)), false)
            ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.18)
            PlayPain(me, 6, 0.0, 0)
            acidBurn()
        end
        -- La flaque fume quelques secondes (petites volutes vertes)
        local smokeEnd = GetGameTimer() + 4000
        while GetGameTimer() < smokeEnd do
            burst('ent_sht_water', b + vector3((math.random() - 0.5) * 1.2, (math.random() - 0.5) * 1.2, 0.0), 0.18, 120, 200, 50)
            Wait(350)
        end
    end)
end)

-- « Seulement la tête » : un tir dans la tête tue net (vérifié souvent, sur les zombies contrôlés)
CreateThread(function()
    while true do
        if Z.active and Z.headshot and #Owned > 0 then
            for i = 1, #Owned do
                local ped = Owned[i]
                if DoesEntityExist(ped) and not IsPedDeadOrDying(ped, true) then
                    local ok, bone = GetPedLastDamageBone(ped)
                    if ok and (bone == 31086 or bone == 39317) then -- tête, cou
                        SetEntityHealth(ped, 0)
                    end
                end
            end
            Wait(150)
        else
            Wait(1000)
        end
    end
end)

RegisterNetEvent('adminmenu:zombies:killAll', function()
    for _, ped in ipairs(GetGamePool('CPed')) do
        if Entity(ped).state.zombie and NetworkHasControlOfEntity(ped) and not IsPedDeadOrDying(ped, true) then
            SetEntityHealth(ped, 0)
        end
    end
end)

-- ---------------------------------------------------------
--  Ambiance : ville vide, éclairs
-- ---------------------------------------------------------
CreateThread(function()
    while true do
        if Z.active and Z.emptyCity then
            SetPedDensityMultiplierThisFrame(0.0)
            SetScenarioPedDensityMultiplierThisFrame(0.0, 0.0)
            SetVehicleDensityMultiplierThisFrame(0.0)
            SetRandomVehicleDensityMultiplierThisFrame(0.0)
            SetParkedVehicleDensityMultiplierThisFrame(0.3)
            Wait(0)
        else
            Wait(1000)
        end
    end
end)

CreateThread(function()
    while true do
        if Z.active and Z.lightning then
            local range = ZC.lightning or { 15, 45 }
            Wait(math.random(range[1], range[2]) * 1000)
            if Z.active and Z.lightning then ForceLightningFlash() end
        else
            Wait(2000)
        end
    end
end)

-- ---------------------------------------------------------
--  Mort du joueur : relevé sur place, rien n'est perdu
-- ---------------------------------------------------------
CreateThread(function()
    while true do
        if Z.active then
            local ped = PlayerPedId()
            SetPedDropsWeaponsWhenDead(ped, false)
            if not reviving and IsPlayerDead() then
                reviving = true
                TriggerServerEvent('adminmenu:zombies:died')
                Notify(('Tu es tombé… relevé dans %d s, sans rien perdre.'):format(Z.reviveDelay or ZC.reviveDelay), 'info')
                CreateThread(function()
                    Wait((Z.reviveDelay or ZC.reviveDelay) * 1000)
                    if Z.active and IsPlayerDead() then
                        ReviveSelf()
                        Wait(1500)
                        local me = PlayerPedId()
                        SetEntityInvincible(me, true)
                        Notify('Relevé ! Armes et objets intacts. Protégé quelques secondes.', 'success')
                        Wait((Z.reviveProtection or ZC.reviveProtection) * 1000)
                        if not State.godmode then SetEntityInvincible(PlayerPedId(), false) end
                    end
                    reviving = false
                end)
            end
            Wait(500)
        else
            Wait(1500)
        end
    end
end)

-- ---------------------------------------------------------
--  MISSIONS DE L'ÉVÉNEMENT
--  Le serveur envoie les missions actives ; ce client affiche blips, zones,
--  encadré d'objectifs, et gère « maintenir E » (validé par le serveur).
-- ---------------------------------------------------------
local MissionBlips = {}       -- [id] = { point, area, key }
-- Missions : liste reçue du serveur ; Hold : { mission, step, start, seconds } pendant « maintenir E »
local TYPE_COLOR = { reach = { 120, 200, 80 }, interact = { 240, 190, 70 }, defend = { 230, 80, 70 }, boss = { 200, 30, 30 } }
local TYPE_BLIP = { reach = 2, interact = 5, defend = 1, boss = 1 }
local TYPE_SPRITE = { boss = 303 }   -- tête de mort pour le boss

local function clearMissionBlip(id)
    local b = MissionBlips[id]
    if not b then return end
    if DoesBlipExist(b.point) then RemoveBlip(b.point) end
    if b.area and DoesBlipExist(b.area) then RemoveBlip(b.area) end
    MissionBlips[id] = nil
end

refreshMissionBlips = function()
    local keep = {}
    for i, m in ipairs(Missions) do
        local c = m.current
        local key = ('%d:%d'):format(m.id, m.step)
        keep[m.id] = true
        local b = MissionBlips[m.id]
        if not b or b.key ~= key then
            clearMissionBlip(m.id)
            local point = AddBlipForCoord(c.x, c.y, c.z)
            SetBlipSprite(point, TYPE_SPRITE[c.type] or 280)
            SetBlipColour(point, TYPE_BLIP[c.type] or 2)
            SetBlipScale(point, 1.0)
            SetBlipAsShortRange(point, false)
            SetBlipRoute(point, i == 1)
            SetBlipRouteColour(point, TYPE_BLIP[c.type] or 2)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName((c.type == 'boss' and '☠ ' or '☣ ') .. c.title)
            EndTextCommandSetBlipName(point)
            local area = nil
            if c.type == 'defend' or c.type == 'boss' then
                area = AddBlipForRadius(c.x, c.y, c.z, c.radius + 0.0)
                SetBlipColour(area, 1)
                SetBlipAlpha(area, c.type == 'boss' and 70 or 110)
            end
            MissionBlips[m.id] = { point = point, area = area, key = key }
        end
    end
    for id in pairs(MissionBlips) do if not keep[id] then clearMissionBlip(id) end end
end

local function holdCancel()
    if not Hold then return end
    TriggerServerEvent('adminmenu:zombies:interact', Hold.mission, Hold.step, 'cancel')
    Hold = nil
end

RegisterNetEvent('adminmenu:zombies:missions', function(list)
    Missions = {}
    for _, m in ipairs(type(list) == 'table' and list or {}) do
        if type(m) == 'table' and type(m.current) == 'table' then Missions[#Missions + 1] = m end
    end
    if Hold then
        local still = false
        for _, m in ipairs(Missions) do if m.id == Hold.mission and m.step == Hold.step then still = true end end
        if not still then Hold = nil end
    end
    refreshMissionBlips()
end)

RegisterNetEvent('adminmenu:zombies:decontaminate', function()
    AnimpostfxPlay('MinigameEndNeutral', 0, false)
    ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.25)
    PlaySoundFrontend(-1, 'Mission_Pass_Notify', 'DLC_HEISTS_GENERAL_FRONTEND_SOUNDS', true)
    Notify('🧪 Décontamination en cours : l\'antidote se répand sur la ville !', 'success')
end)

CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(500) end
    Wait(2500)
    TriggerServerEvent('adminmenu:zombies:requestMissions')
end)

local function helpText(text)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, false, -1)
end

-- Zones au sol + « maintenir E » (chaque image seulement si un objectif est proche)
CreateThread(function()
    while true do
        local sleep = 1000
        if Z.active and #Missions > 0 then
            local ped = PlayerPedId()
            local pc = GetEntityCoords(ped)
            local inInteract = nil
            for _, m in ipairs(Missions) do
                local c = m.current
                local d = #(pc - vector3(c.x, c.y, c.z))
                if d < 120.0 and c.type ~= 'boss' then
                    sleep = 0
                    local col = TYPE_COLOR[c.type] or { 255, 255, 255 }
                    local size = c.radius * 2.0
                    DrawMarker(1, c.x, c.y, c.z - 1.0, 0, 0, 0, 0, 0, 0, size, size, c.type == 'defend' and 2.0 or 1.0,
                        col[1], col[2], col[3], 70, false, false, 2, false, nil, nil, false)
                    if c.type == 'interact' and d <= c.radius and not IsPlayerDead() then inInteract = m end
                elseif d < 250.0 and sleep > 250 then
                    sleep = 250
                end
            end

            if inInteract then
                local c = inInteract.current
                if not Hold then helpText(('Maintiens ~INPUT_CONTEXT~ : %s'):format(c.title)) end
                if IsControlPressed(0, 38) then
                    if not Hold or Hold.mission ~= inInteract.id or Hold.step ~= inInteract.step then
                        Hold = { mission = inInteract.id, step = inInteract.step, start = GetGameTimer(), seconds = c.seconds }
                        TriggerServerEvent('adminmenu:zombies:interact', Hold.mission, Hold.step, 'start')
                    elseif GetGameTimer() - Hold.start >= Hold.seconds * 1000 then
                        TriggerServerEvent('adminmenu:zombies:interact', Hold.mission, Hold.step, 'done')
                        Hold.sent = true
                    end
                elseif Hold and not Hold.sent then
                    holdCancel()
                end
            elseif Hold and not Hold.sent then
                holdCancel()
            end
        elseif Hold then
            Hold = nil
        end
        Wait(sleep)
    end
end)

-- Encadré des objectifs (envoyé à l'interface seulement s'il change)
CreateThread(function()
    local last = ''
    while true do
        if Z.active and #Missions > 0 then
            local pc = GetEntityCoords(PlayerPedId())
            local list = {}
            for _, m in ipairs(Missions) do
                local c = m.current
                local d = #(pc - vector3(c.x, c.y, c.z))
                local progress = nil
                if c.type == 'defend' then progress = math.min(1.0, (c.progress or 0) / math.max(1, c.seconds)) end
                if c.type == 'interact' and Hold and Hold.mission == m.id then
                    progress = math.min(1.0, (GetGameTimer() - Hold.start) / (Hold.seconds * 1000))
                end
                local bossPct, bossDist
                if c.type == 'boss' then
                    local boss = c.bossNet and NetworkDoesNetworkIdExist(c.bossNet) and NetToPed(c.bossNet) or 0
                    if boss ~= 0 and DoesEntityExist(boss) then
                        local st = Entity(boss).state.zboss
                        local max = (st and st.hp) or c.bossHealth or 1
                        bossPct = math.max(0, math.min(100, math.floor((GetEntityHealth(boss) - 100) / max * 100)))
                        bossDist = math.floor(#(pc - GetEntityCoords(boss)))
                    end
                    progress = bossPct and (bossPct / 100) or nil
                end
                list[#list + 1] = {
                    title = m.title, step = m.step, total = m.total, type = c.type, stepTitle = c.title, desc = c.desc,
                    distance = math.floor(d), inside = d <= c.radius, seconds = c.seconds, done = c.progress or 0,
                    progress = progress and math.floor(progress * 100) or nil, decon = m.outcome == 'decontaminate',
                    bossName = c.bossName, bossPct = bossPct, bossDist = bossDist,
                }
            end
            local payload = json.encode(list)
            if payload ~= last then
                last = payload
                SendNUIMessage({ action = 'zombiemissions', list = list })
            end
            Wait(Hold and 100 or 500)
        else
            if last ~= '' then
                last = ''
                SendNUIMessage({ action = 'zombiemissions', list = {} })
            end
            Wait(1000)
        end
    end
end)

-- ---------------------------------------------------------
--  CAISSES D'ARMES
-- ---------------------------------------------------------
local Crates = {}          -- [id] = caisse reçue du serveur
local MyLooted = {}        -- caisses « chacun sa part » déjà ouvertes par moi
local CrateObj = {}        -- [id] = objet local
local CrateBlips = {}      -- [id] = blip
local CrateHold = nil      -- { id, start }

local function crateVisible(c) return not (c.mode == 'each' and MyLooted[c.id]) end

local function deleteCrate(id)
    local o = CrateObj[id]
    if o and DoesEntityExist(o) then DeleteEntity(o) end
    CrateObj[id] = nil
    local b = CrateBlips[id]
    if b and DoesBlipExist(b) then RemoveBlip(b) end
    CrateBlips[id] = nil
end

local function refreshCrateBlips()
    for id, c in pairs(Crates) do
        local want = c.blip and crateVisible(c)
        if want and not CrateBlips[id] then
            local b = AddBlipForCoord(c.x, c.y, c.z)
            SetBlipSprite(b, 110)
            SetBlipColour(b, c.color or 1)
            SetBlipScale(b, 0.8)
            SetBlipAsShortRange(b, false)
            SetBlipCategory(b, 10)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName('Caisse : ' .. c.label)
            EndTextCommandSetBlipName(b)
            CrateBlips[id] = b
        elseif not want and CrateBlips[id] then
            if DoesBlipExist(CrateBlips[id]) then RemoveBlip(CrateBlips[id]) end
            CrateBlips[id] = nil
        end
    end
end

RegisterNetEvent('adminmenu:zombies:crates', function(list, mine)
    local incoming = {}
    for _, c in ipairs(type(list) == 'table' and list or {}) do
        if type(c) == 'table' and tonumber(c.id) and tonumber(c.x) then incoming[c.id] = c end
    end
    for id in pairs(Crates) do if not incoming[id] then deleteCrate(id) end end
    Crates = incoming
    if type(mine) == 'table' then for _, id in ipairs(mine) do MyLooted[id] = true end end
    if not next(Crates) then MyLooted = {} end
    if CrateHold and not Crates[CrateHold.id] then CrateHold = nil end
    refreshCrateBlips()
end)

RegisterNetEvent('adminmenu:zombies:crateLooted', function(id)
    MyLooted[id] = true
    CrateHold = nil
    local c = Crates[id]
    if c and not crateVisible(c) then
        local o = CrateObj[id]
        if o and DoesEntityExist(o) then DeleteEntity(o) end
        CrateObj[id] = nil
    end
    PlaySoundFrontend(-1, 'PICK_UP', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    refreshCrateBlips()
end)

-- Objets créés seulement à proximité (locaux, aucune entité réseau)
CreateThread(function()
    while true do
        if next(Crates) then
            local pc = GetEntityCoords(PlayerPedId())
            for id, c in pairs(Crates) do
                local near = crateVisible(c) and #(pc - vector3(c.x, c.y, c.z)) < 120.0
                local o = CrateObj[id]
                if near and (not o or not DoesEntityExist(o)) then
                    local hash = GetHashKey(c.model)
                    if IsModelInCdimage(hash) then
                        RequestModel(hash)
                        local limit = GetGameTimer() + 3000
                        while not HasModelLoaded(hash) and GetGameTimer() < limit do Wait(20) end
                        if HasModelLoaded(hash) and Crates[id] then
                            local obj = CreateObject(hash, c.x, c.y, c.z, false, false, false)
                            PlaceObjectOnGroundProperly(obj)
                            FreezeEntityPosition(obj, true)
                            SetEntityInvincible(obj, true)
                            CrateObj[id] = obj
                        end
                        SetModelAsNoLongerNeeded(hash)
                    end
                elseif not near and o then
                    if DoesEntityExist(o) then DeleteEntity(o) end
                    CrateObj[id] = nil
                end
            end
            Wait(1000)
        else
            Wait(2000)
        end
    end
end)

-- Ouverture : maintenir E près d'une caisse (validé par le serveur)
CreateThread(function()
    while true do
        local sleep = 1000
        if Z.active and next(Crates) then
            local ped = PlayerPedId()
            local pc = GetEntityCoords(ped)
            local best, bestD = nil, 2.4
            for id, c in pairs(Crates) do
                local o = CrateObj[id]
                if o and DoesEntityExist(o) then
                    local d = #(pc - GetEntityCoords(o))
                    if d < 25.0 then sleep = 0 end
                    if d < 25.0 and d > 2.0 then
                        local oc = GetEntityCoords(o)
                        DrawMarker(2, oc.x, oc.y, oc.z + 1.1, 0, 0, 0, 0, 180.0, 0, 0.25, 0.25, 0.25, 240, 190, 70, 170, true, true, 2, false, nil, nil, false)
                    end
                    if d < bestD then best, bestD = c, d end
                elseif #(pc - vector3(c.x, c.y, c.z)) < 150.0 and sleep > 250 then
                    sleep = 250
                end
            end

            if best and not IsPlayerDead() and not IsPedInAnyVehicle(ped, false) then
                local total = (ZC.crateOpenTime or 3) * 1000
                if CrateHold and CrateHold.id == best.id and IsControlPressed(0, 38) then
                    local pct = math.min(100, math.floor((GetGameTimer() - CrateHold.start) / total * 100))
                    helpText(('Ouverture de la caisse… %d %%'):format(pct))
                    if pct >= 100 and not CrateHold.sent then
                        CrateHold.sent = true
                        TriggerServerEvent('adminmenu:zombies:crate', best.id, 'done')
                    end
                elseif IsControlPressed(0, 38) and not CrateHold then
                    CrateHold = { id = best.id, start = GetGameTimer() }
                    TriggerServerEvent('adminmenu:zombies:crate', best.id, 'start')
                else
                    if CrateHold then
                        if not CrateHold.sent then TriggerServerEvent('adminmenu:zombies:crate', CrateHold.id, 'cancel') end
                        CrateHold = nil
                    end
                    helpText(('Maintiens ~INPUT_CONTEXT~ : ouvrir « %s »~n~%s'):format(best.label, best.contents or ''))
                end
            elseif CrateHold then
                if not CrateHold.sent then TriggerServerEvent('adminmenu:zombies:crate', CrateHold.id, 'cancel') end
                CrateHold = nil
            end
        end
        Wait(sleep)
    end
end)

-- Position du staff (bouton « Ma position » dans l'éditeur de missions)
RegisterNUICallback('zombiesPos', function(_, cb)
    local c = GetEntityCoords(PlayerPedId())
    cb({ x = c.x, y = c.y, z = c.z })
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    ClearTimecycleModifier()
    SetAiMeleeWeaponDamageModifier(1.0)
    for id in pairs(MissionBlips) do clearMissionBlip(id) end
    for id in pairs(CrateObj) do deleteCrate(id) end
    for id in pairs(CrateBlips) do deleteCrate(id) end
end)


-- =========================================================
--  BOSS (étape de mission « Tuer le boss »)
-- =========================================================
local BC = ZC.boss or {}
BossMelee = BC.melee or { range = 3.4, cooldown = 1600, damage = 40, dict = 'melee@large_wpn@streamed_core', anim = 'ground_attack_on_spot' }
local BossThrow = BC.throw or { minRange = 8.0, maxRange = 40.0, cooldown = 6000, speed = 18.0, damage = 30, radius = 4.5, dict = 'weapons@projectile@grenade_str', anim = 'throw_h_fb_stand' }
local BossConfigured, BossCd, BossOrders = {}, {}, {}
local Bosses = {}          -- liste des boss proches (tous les clients), rafraîchie 2 fois par seconde

local function playerFromSid(sid)
    local pl = GetPlayerFromServerId(sid)
    if pl == -1 then return nil end
    local ped = GetPlayerPed(pl)
    if ped == 0 or IsEntityDead(ped) then return nil end
    return ped
end
local function safe(c) return IsInSafeZone and IsInSafeZone(c) end

-- Gardes : cible = ceux qui ont frappé le boss, sinon ceux qui s'approchent de lui, sinon ils le suivent
function GuardThink(ped, gnet, runner, o, t)
    local boss = NetworkDoesNetworkIdExist(gnet) and NetToPed(gnet) or 0
    if boss == 0 or not DoesEntityExist(boss) or IsPedDeadOrDying(boss, true) then return false end
    local bc, pc = GetEntityCoords(boss), GetEntityCoords(ped)
    local best, bestD
    for _, sid in ipairs(Entity(boss).state.zaggro or {}) do
        local tp = playerFromSid(sid)
        if tp and #(GetEntityCoords(tp) - bc) < 90.0 and not safe(GetEntityCoords(tp)) then
            local d = #(GetEntityCoords(tp) - pc)
            if not bestD or d < bestD then best, bestD = tp, d end
        end
    end
    if not best then
        for _, player in ipairs(GetActivePlayers()) do
            local tp = GetPlayerPed(player)
            if tp ~= 0 and not IsEntityDead(tp) and #(GetEntityCoords(tp) - bc) < 22.0 and not safe(GetEntityCoords(tp)) then
                local d = #(GetEntityCoords(tp) - pc)
                if not bestD or d < bestD then best, bestD = tp, d end
            end
        end
    end
    if best then
        if o.mode ~= 'chase' or o.target ~= best or t - o.at > 2500 then
            TaskGoToEntity(ped, best, -1, 0.3, runner and 3.0 or 1.0, 1073741824, 0)
            Orders[ped] = { mode = 'chase', target = best, at = t }
        end
    elseif o.mode ~= 'follow' or t - o.at > 4000 then
        TaskGoToEntity(ped, boss, -1, 5.0, 2.0, 1073741824, 0)
        Orders[ped] = { mode = 'follow', at = t }
    end
    return true
end

local function configureBoss(ped, st)
    local s = Entity(ped).state
    RemoveAllPedWeapons(ped, true)
    SetPedRelationshipGroupHash(ped, zombieGroup)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 46, true)
    if not s.zhp then
        SetEntityMaxHealth(ped, st.hp + 100)
        SetEntityHealth(ped, st.hp + 100)
        s:set('zhp', true, true)
    end
    SetPedArmour(ped, 100)
    SetPedSuffersCriticalHits(ped, false)       -- pas de mort en un tir à la tête
    SetPedCanRagdoll(ped, false)
    SetPedCanRagdollFromPlayerImpact(ped, false)
    SetPedDiesWhenInjured(ped, false)
    SetPedConfigFlag(ped, 281, true)
    SetPedCanEvasiveDive(ped, false)
    SetPedKeepTask(ped, true)
    StopPedSpeaking(ped, true)
    ApplyPedDamagePack(ped, 'BigHitByVehicle', 0.0, 9.0)
    if BC.walk then
        RequestAnimSet(BC.walk)
        local t = GetGameTimer() + 1500
        while not HasAnimSetLoaded(BC.walk) and GetGameTimer() < t do Wait(10) end
        if HasAnimSetLoaded(BC.walk) then SetPedMovementClipset(ped, BC.walk, 1.0) end
    end
    BossConfigured[ped] = true
end

-- Cerveau du boss (sur le client qui le « possède »)
local function bossBrain(ped, st)
    local pc = GetEntityCoords(ped)
    local center = vector3(st.cx, st.cy, st.cz)
    local now = GetGameTimer()
    local cd = BossCd[ped] or { melee = 0, throw = 0 }
    BossCd[ped] = cd
    local o = BossOrders[ped] or {}
    -- Trop loin de son territoire : il y retourne
    if #(pc - center) > (st.leash or 80) then
        if o.mode ~= 'return' then
            TaskGoStraightToCoord(ped, center.x, center.y, center.z, 2.0, -1, 0.0, 2.0)
            BossOrders[ped] = { mode = 'return', at = now }
        end
        return
    end
    -- Cible : le joueur le plus proche
    local best, bestD
    for _, player in ipairs(GetActivePlayers()) do
        local tp = GetPlayerPed(player)
        if tp ~= 0 and not IsEntityDead(tp) and not safe(GetEntityCoords(tp)) then
            local d = #(GetEntityCoords(tp) - pc)
            if d < 90.0 and (not bestD or d < bestD) then best, bestD = tp, d end
        end
    end
    if not best then
        if o.mode ~= 'roam' or now - o.at > 15000 then
            TaskWanderInArea(ped, center.x, center.y, center.z, 15.0, 2.0, 4.0)
            BossOrders[ped] = { mode = 'roam', at = now }
        end
        return
    end
    -- Corps à corps : énorme coup qui renverse (sa portée grandit avec sa taille)
    local reach = BossMelee.range * (0.6 + 0.4 * (st.scale or 1.0))
    if bestD <= reach and cd.melee <= now then
        cd.melee = now + BossMelee.cooldown
        RequestAnimDict(BossMelee.dict)
        if HasAnimDictLoaded(BossMelee.dict) then
            TaskPlayAnim(ped, BossMelee.dict, BossMelee.anim, 6.0, -6.0, 1200, 0, 0, false, false, false)
        end
        local pl = NetworkGetPlayerIndexFromPed(best)
        if pl ~= -1 then
            local tgt, sid = best, GetPlayerServerId(pl)
            SetTimeout(450, function()
                if DoesEntityExist(ped) and not IsPedDeadOrDying(ped, true) and DoesEntityExist(tgt)
                    and #(GetEntityCoords(ped) - GetEntityCoords(tgt)) <= reach + 1.0 then
                    TriggerServerEvent('adminmenu:zombies:melee', NetworkGetNetworkIdFromEntity(ped), sid)
                end
                BossOrders[ped] = nil     -- il repart aussitôt vers sa cible
            end)
        end
        return
    -- À distance : il lance une masse de chair putréfiée (zone d'impact)
    elseif bestD >= BossThrow.minRange and bestD <= BossThrow.maxRange and cd.throw <= now and HasEntityClearLosToEntity(ped, best, 17) then
        cd.throw = now + BossThrow.cooldown + math.random(0, 1500)
        RequestAnimDict(BossThrow.dict)
        TaskTurnPedToFaceEntity(ped, best, 600)
        if HasAnimDictLoaded(BossThrow.dict) then TaskPlayAnim(ped, BossThrow.dict, BossThrow.anim, 6.0, -6.0, 1100, 48, 0, false, false, false) end
        local pl = NetworkGetPlayerIndexFromPed(best)
        local tgt = best
        SetTimeout(550, function()
            if pl == -1 or not DoesEntityExist(ped) or IsPedDeadOrDying(ped, true) or not DoesEntityExist(tgt) then return end
            local tc, vel = GetEntityCoords(tgt), GetEntityVelocity(tgt)
            local aim = tc + vel * ((#(GetEntityCoords(ped) - tc) / BossThrow.speed) * 0.5)
            TriggerServerEvent('adminmenu:zombies:bossThrow', NetworkGetNetworkIdFromEntity(ped), GetPlayerServerId(pl), { x = aim.x, y = aim.y, z = aim.z })
        end)
    end
    -- Il avance toujours vers sa cible (lentement, mais sans s'arrêter)
    -- Vitesse réglée dans le menu : 1 = marche, 2 = trot, 3 = course ; l'animation suit (pas de glissade)
    local speed = st.speed or 1.6
    SetPedMoveRateOverride(ped, math.max(0.85, math.min(1.35, 0.7 + speed * 0.22)))
    if o.mode ~= 'chase' or o.target ~= best or now - o.at > 2000 then
        TaskGoToEntity(ped, best, -1, 1.5, speed, 1073741824, 0)
        BossOrders[ped] = { mode = 'chase', target = best, at = now }
    end
end

-- Liste des boss proches + cerveau des boss possédés
CreateThread(function()
    while true do
        local list = {}
        if Z.active then
            local me = GetEntityCoords(PlayerPedId())
            for _, ped in ipairs(GetGamePool('CPed')) do
                local st = Entity(ped).state.zboss
                if st and not IsPedDeadOrDying(ped, true) then
                    if #(GetEntityCoords(ped) - me) < 300.0 then list[#list + 1] = { ped = ped, st = st } end
                    if NetworkHasControlOfEntity(ped) then
                        if zombieGroup and not BossConfigured[ped] then configureBoss(ped, st) end
                        bossBrain(ped, st)
                    end
                end
            end
        end
        Bosses = list
        for ped in pairs(BossConfigured) do if not DoesEntityExist(ped) then BossConfigured[ped], BossCd[ped], BossOrders[ped] = nil, nil, nil end end
        Wait(300)
    end
end)

-- Le boss est ÉNORME : agrandi à chaque image (visuel), pieds posés au sol
CreateThread(function()
    while true do
        if #Bosses > 0 then
            for i = 1, #Bosses do
                local b = Bosses[i]
                local ped, sc = b.ped, b.st.scale or 1.0
                if sc > 1.01 and DoesEntityExist(ped) and not IsPedDeadOrDying(ped, true) then
                    local r, f, u, pos = GetEntityMatrix(ped)
                    local function norm(v) local l = #v if l < 0.0001 then return v end return v / l end
                    r, f, u = norm(r) * sc, norm(f) * sc, norm(u) * sc
                    local ok, gz = GetGroundZFor_3dCoord(pos.x, pos.y, pos.z + 1.0, false)
                    local z = ok and (gz + 0.98 * sc) or pos.z
                    SetEntityMatrix(ped, f.x, f.y, f.z, r.x, r.y, r.z, u.x, u.y, u.z, pos.x, pos.y, z)
                end
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)

-- Barre de vie du boss en haut de l'écran (quand on est à moins de 200 m)
CreateThread(function()
    local shown = nil
    while true do
        local best, bestD
        if Z.active and #Bosses > 0 then
            local me = GetEntityCoords(PlayerPedId())
            for i = 1, #Bosses do
                local d = #(GetEntityCoords(Bosses[i].ped) - me)
                if d < 200.0 and (not bestD or d < bestD) then best, bestD = Bosses[i], d end
            end
        end
        if best and DoesEntityExist(best.ped) then
            local max = math.max(1, best.st.hp or 1)
            local hp = math.max(0, GetEntityHealth(best.ped) - 100)
            local pct = math.floor(math.min(1.0, hp / max) * 1000) / 10
            local sig = ('%s|%.1f'):format(best.st.name, pct)
            if sig ~= shown then
                shown = sig
                SendNUIMessage({ action = 'zboss', show = true, name = best.st.name, pct = pct, hp = hp, max = max })
            end
        elseif shown then
            shown = nil
            SendNUIMessage({ action = 'zboss', show = false })
        end
        Wait(250)
    end
end)

-- On frappe le boss : ses gardes nous prennent pour cible
local bossHitAt = 0
AddEventHandler('gameEventTriggered', function(name, args)
    if name ~= 'CEventNetworkEntityDamage' or not Z.active then return end
    local victim, attacker = args[1], args[2]
    if not victim or not DoesEntityExist(victim) or attacker ~= PlayerPedId() then return end
    if Entity(victim).state.zboss and GetGameTimer() - bossHitAt > 2000 then
        bossHitAt = GetGameTimer()
        TriggerServerEvent('adminmenu:zombies:bossHit', NetworkGetNetworkIdFromEntity(victim))
    end
end)

-- ---------------------------------------------------------
--  LANCER DE ROCHER DU BOSS (réaliste)
--  Un vrai rocher part de sa main, tournoie en cloche, s'écrase :
--  poussière, débris, sol qui tremble ; tout le monde dans la zone est renversé.
-- ---------------------------------------------------------
local ROCKS = { 'prop_rock_4_c', 'prop_rock_4_e', 'prop_rock_1_d', 'prop_rock_3_c' }
function BossThrowFx(from, to, targetSid)
    local a, b = vector3(from.x, from.y, from.z), vector3(to.x, to.y, to.z - 0.8)
    -- Départ depuis la main du boss le plus proche (s'il est visible)
    local best, bd
    for i = 1, #Bosses do
        local d = #(GetEntityCoords(Bosses[i].ped) - a)
        if not bd or d < bd then best, bd = Bosses[i], d end
    end
    local scale = best and (best.st.scale or 1.0) or 1.0
    if best and DoesEntityExist(best.ped) then
        local hand = GetPedBoneCoords(best.ped, 57005, 0.0, 0.0, 0.0)
        -- La main suit l'agrandissement visuel : on la remonte d'autant
        local bc = GetEntityCoords(best.ped)
        a = vector3(bc.x + (hand.x - bc.x) * scale, bc.y + (hand.y - bc.y) * scale, bc.z + (hand.z - bc.z) * scale)
    end
    local dist = #(b - a)
    local dur = math.max(400, dist / (BossThrow.speed or 18.0) * 1000)
    local h = math.min(8.0, 1.0 + dist * 0.2)
    CreateThread(function()
        local model = joaat(ROCKS[math.random(#ROCKS)])
        RequestModel(model)
        local t = GetGameTimer() + 1000
        while not HasModelLoaded(model) and GetGameTimer() < t do Wait(0) end
        local rock = HasModelLoaded(model) and CreateObjectNoOffset(model, a.x, a.y, a.z, false, false, false) or 0
        if rock ~= 0 then
            SetEntityCollision(rock, false, false)
            SetEntityAsMissionEntity(rock, true, true)
        end
        SetModelAsNoLongerNeeded(model)
        local start, spin, lastDust = GetGameTimer(), math.random() * 360.0, 0
        local rx, ry = math.random(300, 600), math.random(200, 500)
        while true do
            local k = (GetGameTimer() - start) / dur
            if k >= 1.0 then break end
            local p = arcPoint(a, b, k, h)
            if rock ~= 0 then
                SetEntityCoordsNoOffset(rock, p.x, p.y, p.z, false, false, false)
                local el = (GetGameTimer() - start) / 1000.0
                SetEntityRotation(rock, (spin + el * rx) % 360.0, (el * ry) % 360.0, (spin + el * 180.0) % 360.0, 2, true)
            end
            -- Fine traînée de poussière derrière le rocher
            if GetGameTimer() - lastDust > 90 then lastDust = GetGameTimer() burst('bul_dirt', p, 0.6) end
            Wait(0)
        end
        -- Impact : gerbe de terre et de poussière, cratère au sol
        if rock ~= 0 then SetEntityCoordsNoOffset(rock, b.x, b.y, b.z + 0.2, false, false, false) end
        for _ = 1, 6 do
            burst('bul_dirt', b + vector3((math.random() - 0.5) * 2.5, (math.random() - 0.5) * 2.5, 0.2), 3.0)
        end
        burst('ent_sht_water', b, 2.2, 120, 95, 60)
        groundDecal(b, (BossThrow.radius or 4.5) * 0.8, 60, 45, 30, 20.0)
        local me = PlayerPedId()
        local d = #(GetEntityCoords(me) - b)
        if d < (BossThrow.radius or 4.5) * 4.0 then
            ShakeGameplayCam('MEDIUM_EXPLOSION_SHAKE', math.max(0.08, 0.45 - d * 0.02))
        end
        if d <= (BossThrow.radius or 4.5) and not protected() then
            ApplyDamageToPed(me, math.floor((BossThrow.damage or 30) * (Z.damage or 1.0) * (1.0 - d / ((BossThrow.radius or 4.5) * 1.6))), false)
            if not IsPedInAnyVehicle(me, false) then
                -- Projeté en arrière, à l'opposé de l'impact
                local dir = GetEntityCoords(me) - b
                local l = #dir
                if l > 0.1 then dir = dir / l else dir = vector3(0.0, 1.0, 0.0) end
                SetPedToRagdoll(me, 2000, 2000, 0, false, false, false)
                ApplyForceToEntity(me, 1, dir.x * 6.0, dir.y * 6.0, 3.0, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
            end
            PlayPain(me, 7, 0.0, 0)
        end
        -- Le rocher reste un moment au sol puis disparaît
        Wait(6000)
        if rock ~= 0 and DoesEntityExist(rock) then DeleteObject(rock) end
    end)
end

-- ---------------------------------------------------------
--  HITBOX À LA TAILLE DU BOSS
--  GTA agrandit seulement l'apparence : sa zone de touche reste celle d'un humain.
--  À chaque tir, on teste aussi un « cylindre » à la vraie taille du boss ;
--  si la balle le traverse sans toucher la hitbox normale, les dégâts sont envoyés.
-- ---------------------------------------------------------
local function camRay(dist)
    local c = GetFinalRenderedCamCoord()
    local r = GetFinalRenderedCamRot(2)
    local rx, rz = math.rad(r.x), math.rad(r.z)
    local dir = vector3(-math.sin(rz) * math.abs(math.cos(rx)), math.cos(rz) * math.abs(math.cos(rx)), math.sin(rx))
    return c, c + dir * dist, dir
end
local function dot(a, b) return a.x * b.x + a.y * b.y + a.z * b.z end
-- Distance la plus courte entre deux segments [p1,q1] et [p2,q2] (+ position sur le premier)
local function segDist(p1, q1, p2, q2)
    local d1, d2, r = q1 - p1, q2 - p2, p1 - p2
    local a, e, f = dot(d1, d1), dot(d2, d2), dot(d2, r)
    local s, t
    local c = dot(d1, r)
    local b = dot(d1, d2)
    local denom = a * e - b * b
    s = denom ~= 0 and math.max(0, math.min(1, (b * f - c * e) / denom)) or 0
    t = (b * s + f) / e
    if t < 0 then t = 0 s = math.max(0, math.min(1, -c / a))
    elseif t > 1 then t = 1 s = math.max(0, math.min(1, (b - c) / a)) end
    local c1, c2 = p1 + d1 * s, p2 + d2 * t
    return #(c1 - c2), s
end
RegisterNetEvent('adminmenu:zombies:bossApplyDamage', function(netId, dmg)
    local ent = NetworkDoesNetworkIdExist(netId) and NetToPed(netId) or 0
    if ent ~= 0 and DoesEntityExist(ent) and NetworkHasControlOfEntity(ent) and not IsPedDeadOrDying(ent, true) then
        ApplyDamageToPed(ent, math.floor(tonumber(dmg) or 0), false)
    end
end)

CreateThread(function()
    while true do
        if Z.active and #Bosses > 0 then
            local me = PlayerPedId()
            if IsPedShooting(me) then
                local weapon = GetSelectedPedWeapon(me)
                local o, to = camRay(300.0)
                -- La hitbox normale touchée ? Alors GTA compte déjà le tir : on ne double pas.
                local ray = StartExpensiveSynchronousShapeTestLosProbe(o.x, o.y, o.z, to.x, to.y, to.z, 31, me, 7)
                local _, hit, endPos, _, hitEnt = GetShapeTestResult(ray)
                for i = 1, #Bosses do
                    local b = Bosses[i]
                    local boss, sc = b.ped, b.st.scale or 1.0
                    if DoesEntityExist(boss) and not IsPedDeadOrDying(boss, true) and hitEnt ~= boss and sc > 1.01 then
                        local bc = GetEntityCoords(boss)
                        local foot = vector3(bc.x, bc.y, bc.z - 0.98 * sc)
                        local top = vector3(bc.x, bc.y, foot.z + 1.85 * sc)
                        local radius = 0.42 * sc
                        local d, s = segDist(o, to, foot, top)
                        -- Le cylindre est touché, et aucun mur n'est devant (le tir du monde s'arrête après)
                        local wallDist = hit == 1 and #(endPos - o) or 1e9
                        if d <= radius and s * 300.0 <= wallDist + 0.5 then
                            local dmg = GetWeaponDamage(weapon, 0)
                            if not dmg or dmg <= 0 then dmg = 25 end
                            TriggerServerEvent('adminmenu:zombies:bossDamage', NetworkGetNetworkIdFromEntity(boss), dmg)
                            break
                        end
                    end
                end
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)
