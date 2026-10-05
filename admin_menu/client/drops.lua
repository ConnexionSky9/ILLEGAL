-- =========================================================
--  ÉVÉNEMENT : LARGAGE DE DROPS - CLIENT
--  Blips et fumée rouge, comportement des gardes (calmes puis
--  riposte), inspection des corps (Alt + Inspecter), ouverture.
-- =========================================================
local LiveDrops = {}       -- [runId] = données du serveur
local Cfg = { sprite = 478, color = 1, radius = 90, inspect = 4, shot = 60, approach = 0 }
local Blips, Smokes = {}, {}
local Alerted = {}         -- [runId] = true
local Configured = {}      -- [ped] = runId
local busyDrop = false
local alertSent = {}

local function street(c)
    local s1, s2 = GetStreetNameAtCoord(c.x, c.y, c.z)
    local name = GetStreetNameFromHashKey(s1)
    if s2 ~= 0 then name = name .. ' / ' .. GetStreetNameFromHashKey(s2) end
    local zone = GetLabelText(GetNameOfZone(c.x, c.y, c.z))
    if zone and zone ~= 'NULL' then name = name .. ', ' .. zone end
    return name
end

-- ---------------------------------------------------------
--  Choisir la position d'un drop (menu staff)
-- ---------------------------------------------------------
RegisterNUICallback('drops_pick', function(d, cb)
    cb('ok')
    if d.mode == 'here' then
        local c = GetEntityCoords(PlayerPedId())
        local ok, gz = GetGroundZFor_3dCoord(c.x, c.y, c.z + 1.0, false)
        return SendNUIMessage({ action = d.tag and 'mapPicked' or 'dropsPicked', tag = d.tag, x = c.x, y = c.y, z = ok and gz or c.z - 1.0, place = street(c) })
    end
    CloseMenu()
    CreateThread(function()
        Notify(d.tag and 'Place un repère (point GPS) à l\'endroit voulu, puis ferme la carte (Échap).' or 'Place un repère (point GPS) à l\'endroit du drop, puis ferme la carte (Échap).', 'info')
        Wait(250)
        ActivateFrontendMenu(GetHashKey('FE_MENU_VERSION_MP_PAUSE'), false, -1)
        Wait(900)
        while IsPauseMenuActive() do Wait(100) end
        local blip = GetFirstBlipInfoId(8)
        if not DoesBlipExist(blip) then
            Notify('Aucun repère placé : la position n\'a pas changé.', 'error')
            OpenMenuStaff()
            return
        end
        local v = GetBlipInfoIdCoord(blip)
        -- On charge la zone pour connaître la hauteur exacte du sol
        SetFocusPosAndVel(v.x, v.y, 100.0, 0.0, 0.0, 0.0)
        local z, limit = nil, GetGameTimer() + 5000
        while GetGameTimer() < limit do
            RequestCollisionAtCoord(v.x, v.y, 100.0)
            local ok, gz = GetGroundZFor_3dCoord(v.x, v.y, 1000.0, false)
            if ok and gz ~= 0.0 then z = gz break end
            Wait(100)
        end
        ClearFocus()
        OpenMenuStaff()
        Wait(500)
        SendNUIMessage({ action = d.tag and 'mapPicked' or 'dropsPicked', tag = d.tag, x = v.x, y = v.y, z = z or 0.0, place = street(vector3(v.x, v.y, z or 0.0)) })
        if not z then Notify('Hauteur du sol inconnue : le drop sera posé au sol à son arrivée.', 'info') end
    end)
end)
RegisterNUICallback('drops_tp', function(d, cb)
    cb('ok')
    if not HasPerm('event_drops') then return end
    CloseMenu()
    CreateThread(function() TeleportTo(vector3(tonumber(d.x) + 3.0, tonumber(d.y), (tonumber(d.z) or 0.0) + 1.0), true) end)
end)

-- ---------------------------------------------------------
--  Drops à terre : blips, fumée
-- ---------------------------------------------------------
local function relGroup(runId)
    local _, hash = AddRelationshipGroup('AM_DROP_' .. runId)
    return hash
end
local function applyRelations(runId)
    local g = relGroup(runId)
    SetRelationshipBetweenGroups(0, g, g)
    local rel = Alerted[runId] and 5 or 1
    SetRelationshipBetweenGroups(rel, g, joaat("PLAYER"))
    SetRelationshipBetweenGroups(rel, joaat("PLAYER"), g)
end

local function clearDrop(id)
    if Blips[id] then for _, b in ipairs(Blips[id]) do if DoesBlipExist(b) then RemoveBlip(b) end end Blips[id] = nil end
    if Smokes[id] then StopParticleFxLooped(Smokes[id], false) Smokes[id] = nil end
end

RegisterNetEvent('adminmenu:drops:live', function(list, cfg)
    Cfg = cfg or Cfg
    local seen = {}
    for _, d in ipairs(list or {}) do
        seen[d.id] = true
        if d.alerted then Alerted[d.id] = true end
        LiveDrops[d.id] = d
        applyRelations(d.id)
        if not Blips[d.id] then
            local b = AddBlipForCoord(d.x, d.y, d.z)
            SetBlipSprite(b, Cfg.sprite or 478) SetBlipColour(b, Cfg.color or 1) SetBlipScale(b, 1.1)
            SetBlipFlashes(b, true) SetBlipAsShortRange(b, false)
            BeginTextCommandSetBlipName('STRING') AddTextComponentSubstringPlayerName('Drop : ' .. (d.name or '')) EndTextCommandSetBlipName(b)
            local list2 = { b }
            if (Cfg.radius or 0) > 0 then
                local r = AddBlipForRadius(d.x, d.y, d.z, (Cfg.radius or 90) + 0.0)
                SetBlipColour(r, Cfg.color or 1) SetBlipAlpha(r, 90)
                list2[#list2 + 1] = r
            end
            Blips[d.id] = list2
            SetTimeout(10000, function() if DoesBlipExist(b) then SetBlipFlashes(b, false) end end)
        end
    end
    for id in pairs(LiveDrops) do if not seen[id] then LiveDrops[id] = nil clearDrop(id) end end
end)
RegisterNetEvent('adminmenu:drops:ended', function(id) LiveDrops[id] = nil Alerted[id] = nil clearDrop(id) end)
CreateThread(function() Wait(4000) TriggerServerEvent('adminmenu:drops:request') end)

-- Fumée rouge sur la caisse, seulement à proximité (économise les effets)
CreateThread(function()
    while true do
        local me = GetEntityCoords(PlayerPedId())
        for id, d in pairs(LiveDrops) do
            local close = #(me - vector3(d.x, d.y, d.z)) < 600.0 and d.phase ~= 'opened'
            if close and not Smokes[id] then
                RequestNamedPtfxAsset('core')
                local t = GetGameTimer() + 2000
                while not HasNamedPtfxAssetLoaded('core') and GetGameTimer() < t do Wait(10) end
                UseParticleFxAssetNextCall('core')
                Smokes[id] = StartParticleFxLoopedAtCoord('exp_grd_flare', d.x, d.y, d.z + 0.3, 0.0, 0.0, 0.0, 1.6, false, false, false, false)
            elseif not close and Smokes[id] then
                StopParticleFxLooped(Smokes[id], false)
                Smokes[id] = nil
            end
        end
        Wait(2000)
    end
end)

-- ---------------------------------------------------------
--  Gardes : réglés par le joueur qui les « possède » (réseau)
-- ---------------------------------------------------------
local function configureGuard(ped, st)
    local g = relGroup(st.run)
    applyRelations(st.run)
    SetPedRelationshipGroupHash(ped, g)
    SetPedMaxHealth(ped, st.hp or 200)
    SetEntityHealth(ped, st.hp or 200)
    if (st.armor or 0) > 0 then SetPedArmour(ped, st.armor) end
    SetPedAccuracy(ped, st.acc or 35)
    -- Combat à couvert : ils se cachent derrière les véhicules, les sacs de sable, la caisse…
    SetPedCombatAbility(ped, st.ability or 1)       -- 0 faible, 1 moyen, 2 professionnel
    SetPedCombatRange(ped, 1)                       -- distance moyenne : tirent depuis leurs abris
    SetPedCombatMovement(ped, st.movement or 1)     -- 1 défensif (reste à couvert), 2 avance, 3 fonce
    SetPedCombatAttributes(ped, 0, true)            -- utilise les abris
    SetPedCombatAttributes(ped, 1, false)           -- ne part pas avec les véhicules
    SetPedCombatAttributes(ped, 3, true)            -- sort d'un véhicule pour combattre
    SetPedCombatAttributes(ped, 5, true)            -- se bat même désarmé
    SetPedCombatAttributes(ped, 46, true)           -- se bat jusqu'au bout
    SetPedCombatAttributes(ped, 42, st.flank == true)   -- prend à revers (difficile, extrême)
    SetPedCombatAttributes(ped, 50, st.flank == true)   -- charge quand la cible est à découvert
    SetPedCombatAttributes(ped, 20, true)           -- tire en se déplaçant d'un abri à l'autre
    SetPedShootRate(ped, st.rate or 600)
    SetPedSuffersCriticalHits(ped, st.crit ~= false) -- extrême : pas de mort en un tir à la tête
    SetPedConfigFlag(ped, 281, true)                -- pas d'agonie au sol : mort net (fouille possible)
    SetPedConfigFlag(ped, 188, true)                -- reste dans sa zone
    SetPedFleeAttributes(ped, 0, false)
    SetPedSeeingRange(ped, 90.0)
    SetPedHearingRange(ped, 90.0)
    SetPedDropsWeaponsWhenDead(ped, false)
    SetPedKeepTask(ped, true)
    SetCanAttackFriendly(ped, false, false)
    if st.weapon then SetCurrentPedWeapon(ped, joaat(st.weapon), true) end
    -- Remis au sol (le serveur ne connaît pas la hauteur exacte du terrain)
    local c = GetEntityCoords(ped)
    local ok, gz = GetGroundZFor_3dCoord(c.x, c.y, c.z + 30.0, false)
    if ok and math.abs(gz - c.z) < 30.0 then SetEntityCoordsNoOffset(ped, c.x, c.y, gz, false, false, false) end
    SetPedSphereDefensiveArea(ped, st.cx, st.cy, st.cz, st.r or 20.0, true, false)
    if Alerted[st.run] then TaskCombatHatedTargetsAroundPed(ped, 150.0, 0)
    else TaskGuardCurrentPosition(ped, 8.0, 8.0, true) end
end

CreateThread(function()
    while true do
        local any = next(LiveDrops) ~= nil
        if any then
            for _, ped in ipairs(GetGamePool('CPed')) do
                local st = Entity(ped).state.dropGuard
                if st and NetworkHasControlOfEntity(ped) and not IsEntityDead(ped) and Configured[ped] ~= st.run then
                    Configured[ped] = st.run
                    configureGuard(ped, st)
                end
            end
            -- La caisse et les abris : posés au sol par leur « propriétaire »
            for _, obj in ipairs(GetGamePool('CObject')) do
                local est = Entity(obj).state
                if (est.dropCrate or est.dropCover) and NetworkHasControlOfEntity(obj) and not est.dropGrounded then
                    PlaceObjectOnGroundProperly(obj)
                    FreezeEntityPosition(obj, true)
                    est:set('dropGrounded', true, true)
                end
            end
            -- Les véhicules : au sol, moteur coupé, fermés à clé (ils servent d'abri)
            for _, veh in ipairs(GetGamePool('CVehicle')) do
                local vst = Entity(veh).state
                if vst.dropVehicle and NetworkHasControlOfEntity(veh) and not vst.dropGrounded then
                    SetVehicleOnGroundProperly(veh)
                    SetVehicleEngineOn(veh, false, true, true)
                    if vst.dropVehicle.lock then SetVehicleDoorsLocked(veh, 2) SetVehicleDoorsLockedForAllPlayers(veh, true) end
                    SetVehicleHasBeenOwnedByPlayer(veh, false)
                    vst:set('dropGrounded', true, true)
                end
            end
        end
        for ped in pairs(Configured) do if not DoesEntityExist(ped) then Configured[ped] = nil end end
        Wait(any and 1000 or 3000)
    end
end)

-- Alerte : tout le monde passe en combat
RegisterNetEvent('adminmenu:drops:alerted', function(runId)
    Alerted[runId] = true
    applyRelations(runId)
    for _, ped in ipairs(GetGamePool('CPed')) do
        local st = Entity(ped).state.dropGuard
        if st and st.run == runId and NetworkHasControlOfEntity(ped) and not IsEntityDead(ped) then
            TaskCombatHatedTargetsAroundPed(ped, 150.0, 0)
        end
    end
end)
local function sendAlert(runId)
    if Alerted[runId] or (alertSent[runId] and GetGameTimer() - alertSent[runId] < 3000) then return end
    alertSent[runId] = GetGameTimer()
    TriggerServerEvent('adminmenu:drops:alert', runId)
end
-- On tire sur un garde -> alerte
AddEventHandler('gameEventTriggered', function(name, args)
    if name ~= 'CEventNetworkEntityDamage' then return end
    local victim, attacker = args[1], args[2]
    if not victim or not DoesEntityExist(victim) then return end
    local st = Entity(victim).state.dropGuard
    if st and attacker and attacker ~= 0 and IsPedAPlayer(attacker) then sendAlert(st.run) end
end)
-- On tire près des gardes, ou on s'approche trop (si réglé) -> alerte
CreateThread(function()
    while true do
        local sleep = 1000
        if next(LiveDrops) then
            local ped = PlayerPedId()
            local me = GetEntityCoords(ped)
            for id, d in pairs(LiveDrops) do
                if not Alerted[id] and d.phase == 'landed' then
                    local dist = #(me - vector3(d.x, d.y, d.z))
                    if dist < 200.0 then sleep = 0 end
                    if (Cfg.shot or 0) > 0 and dist < Cfg.shot and IsPedShooting(ped) then sendAlert(id) end
                    if (Cfg.approach or 0) > 0 and dist < Cfg.approach then sendAlert(id) end
                end
            end
        end
        Wait(sleep)
    end
end)

-- ---------------------------------------------------------
--  Barre de progression (style du menu)
-- ---------------------------------------------------------
local function progress(label, seconds, dict, anim, anchor, maxDist)
    local ped = PlayerPedId()
    busyDrop = true
    if anchor then TaskTurnPedToFaceCoord(ped, anchor.x, anchor.y, anchor.z, 600) Wait(600) end
    if dict then
        RequestAnimDict(dict)
        local t = GetGameTimer() + 2000
        while not HasAnimDictLoaded(dict) and GetGameTimer() < t do Wait(10) end
        TaskPlayAnim(ped, dict, anim, 6.0, -6.0, -1, 1, 0, false, false, false)
    end
    SendNUIMessage({ action = 'dprogress', show = true, label = label, time = seconds })
    local start, ok = GetGameTimer(), true
    while GetGameTimer() - start < seconds * 1000 do
        Wait(0)
        DisableControlAction(0, 24, true) DisableControlAction(0, 25, true)
        if IsEntityDead(ped) or IsPedRagdoll(ped) or IsControlJustPressed(0, 73)
            or (anchor and #(GetEntityCoords(ped) - vector3(anchor.x, anchor.y, anchor.z)) > (maxDist or 3.0)) then
            ok = false
            break
        end
        if dict and not IsEntityPlayingAnim(ped, dict, anim, 3) then TaskPlayAnim(ped, dict, anim, 6.0, -6.0, -1, 1, 0, false, false, false) end
    end
    SendNUIMessage({ action = 'dprogress', show = false })
    ClearPedTasks(ped)
    busyDrop = false
    return ok
end

-- ---------------------------------------------------------
--  Inspecter un corps (Alt + Inspecter)
-- ---------------------------------------------------------
local function inspect(ent)
    if busyDrop or not DoesEntityExist(ent) then return end
    local netId = NetworkGetNetworkIdFromEntity(ent)
    TriggerServerEvent('adminmenu:drops:inspect', netId, 'start')
    if progress('Inspection du corps', Cfg.inspect or 4, 'amb@medic@standing@kneel@base', 'base', GetEntityCoords(ent), 3.0) then
        TriggerServerEvent('adminmenu:drops:inspect', netId, 'done')
    else
        Notify('Inspection annulée.', 'info')
    end
end

local function isSearchableGuard(ent)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return false end
    local st = Entity(ent).state
    return st.dropGuard ~= nil and IsEntityDead(ent) and not st.dropSearched
end

-- ox_target (Alt) s'il est installé : « Inspecter le corps » sur les gardes morts
CreateThread(function()
    Wait(3000)
    if GetResourceState('ox_target') == 'started' then
        pcall(function()
            exports.ox_target:addGlobalPed({
                { name = 'am_drop_inspect', icon = 'fa-solid fa-magnifying-glass', label = 'Inspecter le corps', distance = 2.2,
                  canInteract = function(ent) return isSearchableGuard(ent) end,
                  onSelect = function(data) inspect(data.entity) end },
            })
        end)
    end
end)

-- Sinon : maintenir Alt près d'un garde mort, puis E
local function nearestBody(maxDist)
    local me = GetEntityCoords(PlayerPedId())
    local best, bd = nil, maxDist
    for _, ped in ipairs(GetGamePool('CPed')) do
        if Entity(ped).state.dropGuard and isSearchableGuard(ped) then
            local d = #(me - GetEntityCoords(ped))
            if d < bd then best, bd = ped, d end
        end
    end
    return best
end

-- ---------------------------------------------------------
--  Ouvrir la caisse
-- ---------------------------------------------------------
RegisterNetEvent('adminmenu:drops:opening', function(runId, seconds)
    local d = LiveDrops[runId]
    if not d then return end
    if progress('Ouverture du drop', seconds or 15, 'mini@repair', 'fixing_a_ped', vector3(d.x, d.y, d.z), 4.0) then
        TriggerServerEvent('adminmenu:drops:open', runId, 'done')
    else
        TriggerServerEvent('adminmenu:drops:open', runId, 'cancel')
        Notify('Ouverture annulée.', 'info')
    end
end)

CreateThread(function()
    local useTarget = false
    local shown = false
    while true do
        local sleep = 700
        local want
        if next(LiveDrops) and not busyDrop then
            useTarget = GetResourceState('ox_target') == 'started'
            local ped = PlayerPedId()
            local me = GetEntityCoords(ped)
            for id, d in pairs(LiveDrops) do
                local dist = #(me - vector3(d.x, d.y, d.z))
                if dist < 60.0 then sleep = 0 end
                if dist < 3.0 and not IsPedInAnyVehicle(ped, false) and not IsEntityDead(ped) then
                    if d.phase == 'opened' then
                        want = { 'Appuyer pour fouiller', 'Le drop', false, id }
                    elseif d.mineKey then
                        local guardsLeft = d.requireAllDead and (d.alive or 0) > 0
                        want = guardsLeft and { 'Des gardes sont encore en vie', 'Élimine-les d\'abord', true } or { 'Appuyer pour ouvrir', 'Le drop (' .. (d.openTime or 15) .. ' s)', false, id }
                    else
                        want = { 'Caisse verrouillée', 'La clé est sur un des gardes', true }
                    end
                end
            end
            if not want and not useTarget and sleep == 0 then
                local body = nearestBody(2.2)
                if body then
                    if IsControlPressed(0, 19) then want = { 'Alt + E', 'Inspecter le corps', false, nil, body }
                    else want = { 'Maintiens Alt', 'pour inspecter le corps', true } end
                end
            end
        end
        if want then
            shown = true
            ShowPrompt(want[1], want[2], want[3], 'drops')
            if not want[3] and IsControlJustPressed(0, 38) then
                if want[5] then HidePrompt('drops') shown = false inspect(want[5])
                elseif want[4] then HidePrompt('drops') shown = false TriggerServerEvent('adminmenu:drops:open', want[4], LiveDrops[want[4]].phase == 'opened' and 'loot' or 'start') end
            end
        elseif shown then
            shown = false
            HidePrompt('drops')
        end
        Wait(sleep)
    end
end)

-- ---------------------------------------------------------
--  Surbrillance du garde qui porte la clé (après X fouilles ratées)
-- ---------------------------------------------------------
local hinted = {}
CreateThread(function()
    while true do
        local list = {}
        if next(LiveDrops) then
            local me = GetEntityCoords(PlayerPedId())
            for _, ped in ipairs(GetGamePool('CPed')) do
                local st = Entity(ped).state
                if st.dropKeyHint and not st.dropSearched and #(me - GetEntityCoords(ped)) < 150.0 then list[#list + 1] = ped end
            end
        end
        hinted = list
        Wait(500)
    end
end)
CreateThread(function()
    while true do
        if #hinted > 0 then
            local t = GetGameTimer() / 1000.0
            for i = 1, #hinted do
                local ped = hinted[i]
                if DoesEntityExist(ped) then
                    local c = GetEntityCoords(ped)
                    local bob = math.sin(t * 3.0) * 0.12
                    -- Halo doré au sol, chevron au-dessus du corps, lumière qui pulse
                    DrawMarker(25, c.x, c.y, c.z - 0.95, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.6, 1.6, 1.0, 241, 216, 153, 170, false, false, 2, false, nil, nil, false)
                    DrawMarker(2, c.x, c.y, c.z + 1.0 + bob, 0.0, 0.0, 0.0, 180.0, 0.0, 0.0, 0.35, 0.35, 0.35, 217, 181, 106, 230, true, true, 2, false, nil, nil, false)
                    DrawLightWithRange(c.x, c.y, c.z + 0.4, 241, 216, 153, 3.5, 2.0 + math.abs(math.sin(t * 2.0)) * 3.0)
                end
            end
            Wait(0)
        else
            Wait(300)
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(Blips) do clearDrop(id) end
    for id in pairs(Smokes) do clearDrop(id) end
end)
