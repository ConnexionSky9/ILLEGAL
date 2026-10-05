-- =========================================================
--  ÉVÉNEMENT : ATTAQUE DE ZOMBIES - SERVEUR
--  * Le serveur décide de tout : où et combien de zombies, durée,
--    météo, fin de l'événement. Les zombies sont des PNJ réseau créés
--    PAR LE SERVEUR (compatible sv_entityLockdown strict).
--  * Les clients proposent seulement des points d'apparition valides
--    (trottoirs, hors safe zone), vérifiés ici.
--  * Morts des joueurs : relevés sur place par leur client, aucune perte.
-- =========================================================
local AM = AdminMenu
local ZC = Config.Zombies

local Event = { active = false }      -- état de l'événement en cours
local Zombies = {}                    -- [entité] = { born, dead, runner }
local ZombieCount = 0
local Pending = {}                    -- [joueur] = { n, at } demande de points en attente
local PrevWorld = nil                 -- météo / heure avant l'événement

local function now() return os.time() end

local function intensityOf(id)
    for _, i in ipairs(ZC.intensities) do if i.id == id then return i end end
    return ZC.intensities[2] or ZC.intensities[1]
end

local function bool(v) return v == true or v == 'true' end
local function num(v, min, max, def)
    v = tonumber(v)
    if not v or v ~= v then return def end
    return math.max(min, math.min(max, v))
end

-- ---------------------------------------------------------
--  Zone de l'événement
-- ---------------------------------------------------------
local missionHotspots -- défini avec les missions (plus bas)

local function inArea(c)
    local s = Event.settings
    if not s then return false end
    if s.area == 'map' then return true end
    if missionHotspots and missionHotspots(c) then return true end
    if s.area == 'radius' then
        local dx, dy = c.x - s.center.x, c.y - s.center.y
        return dx * dx + dy * dy <= s.radius * s.radius
    end
    local a = ZC.cityArea
    return c.x >= a.minX and c.x <= a.maxX and c.y >= a.minY and c.y <= a.maxY
end

-- ---------------------------------------------------------
--  État envoyé aux clients
-- ---------------------------------------------------------
-- Accès partagé avec server/zombies_loot.lua (caisses, récompenses, reprise des armes)
ZombieEvent = {
    get = function() return Event end,
    inArea = function(c) return inArea(c) end,
}

-- Crachat : relayé à tous les joueurs proches (chacun dessine le projectile, la cible encaisse)
local SpitAt = {}
RegisterNetEvent('adminmenu:zombies:spit', function(netId, targetSid, aim)
    local src = source
    if not Event.active or not AM.rateLimit(src, 'zspit', 12, 1000) then return end
    local ent = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if ent == 0 or not DoesEntityExist(ent) or Entity(ent).state.zombie ~= 3 then return end
    if SpitAt[ent] and GetGameTimer() - SpitAt[ent] < (ZC.spit.cooldown or 4000) - 500 then return end
    SpitAt[ent] = GetGameTimer()
    targetSid = tonumber(targetSid)
    if not targetSid or not GetPlayerName(targetSid) or type(aim) ~= 'table' then return end
    local from = GetEntityCoords(ent)
    local to = vector3(tonumber(aim.x) or 0, tonumber(aim.y) or 0, tonumber(aim.z) or 0)
    if #(from - to) > (ZC.spit.maxRange or 24) + 8.0 then return end
    for _, p in ipairs(GetPlayers()) do
        local id = tonumber(p)
        if #(GetEntityCoords(GetPlayerPed(id)) - from) < 150.0 then
            TriggerClientEvent('adminmenu:zombies:spitFx', id, { x = from.x, y = from.y, z = from.z + 0.65 }, { x = to.x, y = to.y, z = to.z }, targetSid)
        end
    end
end)

local function publicState()
    if not Event.active then return { active = false } end
    local s = Event.settings
    return {
        active = true,
        remaining = math.max(0, Event.endsAt - now()),
        emptyCity = s.emptyCity, headshot = s.headshot, damage = s.damage, spitters = s.spitters or 0,
        timecycle = s.storm and ZC.timecycle or '', timecycleStrength = ZC.timecycleStrength,
        lightning = s.storm, reviveDelay = ZC.reviveDelay, reviveProtection = ZC.reviveProtection,
    }
end

local function broadcastState(target)
    TriggerClientEvent('adminmenu:zombies:state', target or -1, publicState())
end

-- ---------------------------------------------------------
--  Météo apocalyptique (passe par la météo synchronisée du menu)
-- ---------------------------------------------------------
local function applyWorld(s)
    local W = AM.World
    PrevWorld = PrevWorld or { weather = W.weather, blackout = W.blackout, hour = W.hour, minute = W.minute, freeze = W.freeze }
    if s.storm then W.weather = ZC.weather end
    W.blackout = s.blackout == true
    if s.night then
        W.hour, W.minute, W.freeze = ZC.nightHour, 0, true
    end
    AM.broadcastWorld()
end

local function restoreWorld()
    if not PrevWorld then return end
    local W = AM.World
    W.weather, W.blackout, W.freeze = PrevWorld.weather, PrevWorld.blackout, PrevWorld.freeze
    if Event.settings and Event.settings.night then W.hour, W.minute = PrevWorld.hour, PrevWorld.minute end
    PrevWorld = nil
    AM.broadcastWorld()
end

-- ---------------------------------------------------------
--  Zombies
-- ---------------------------------------------------------
local function removeZombie(ent)
    if Zombies[ent] then
        Zombies[ent] = nil
        ZombieCount = ZombieCount - 1
    end
    if DoesEntityExist(ent) then DeleteEntity(ent) end
end

local function clearZombies()
    for ent in pairs(Zombies) do
        if DoesEntityExist(ent) then DeleteEntity(ent) end
    end
    Zombies, ZombieCount, Pending = {}, 0, {}
end

local function aliveCount()
    local n = 0
    for _, z in pairs(Zombies) do if not z.dead then n = n + 1 end end
    return n
end

local function isDead(ent)
    return GetEntityHealth(ent) <= 0 or GetPedSourceOfDeath(ent) ~= 0
end

-- Qui a tué ce zombie ? (joueur à pied ou conducteur du véhicule)
local function killerOf(ent)
    local source = GetPedSourceOfDeath(ent)
    if not source or source == 0 or not DoesEntityExist(source) then return nil end
    if GetEntityType(source) == 2 then source = GetPedInVehicleSeat(source, -1) end
    for _, p in ipairs(GetPlayers()) do
        if GetPlayerPed(p) == source then return tonumber(p) end
    end
end

local function creditKill(src)
    if not src then return end
    Event.killed = Event.killed + 1
    Event.kills[src] = (Event.kills[src] or 0) + 1
    TriggerClientEvent('adminmenu:zombies:kills', src, Event.kills[src])
end

local function spawnZombie(x, y, z, h)
    local model = ZC.models[math.random(#ZC.models)]
    local spitter = ZC.spit and math.random(100) <= (Event.settings.spitters or 0)
    if spitter then model = ZC.spit.model or model end
    local runner = not spitter and math.random(100) <= Event.settings.runners
    local ent = CreatePed(4, joaat(model), x, y, z, h, true, true)
    local limit = GetGameTimer() + 1500
    while (not ent or ent == 0 or not DoesEntityExist(ent)) and GetGameTimer() < limit do Wait(50) end
    if not ent or ent == 0 or not DoesEntityExist(ent) then return end
    if not Event.active then DeleteEntity(ent) return end
    if SetEntityOrphanMode then SetEntityOrphanMode(ent, 0) end -- retiré tout seul si plus aucun joueur autour
    Entity(ent).state:set('zombie', spitter and 3 or (runner and 2 or 1), true)   -- 1 marcheur, 2 coureur, 3 cracheur
    Zombies[ent] = { born = now(), runner = runner }
    ZombieCount = ZombieCount + 1
end

-- Points proposés par un client (réponse à une demande du serveur)
RegisterNetEvent('adminmenu:zombies:spots', function(spots)
    local src = source
    local p = Pending[src]
    Pending[src] = nil
    if not Event.active or Event.paused or not p or type(spots) ~= 'table' then return end
    local ped = GetPlayerPed(src)
    if ped == 0 then return end
    local pc = GetEntityCoords(ped)
    local global = intensityOf(Event.settings.intensity).global
    for i = 1, math.min(#spots, p.n) do
        local s = spots[i]
        local x, y, z, h = tonumber(type(s) == 'table' and s.x), tonumber(type(s) == 'table' and s.y), tonumber(type(s) == 'table' and s.z), tonumber(type(s) == 'table' and s.h) or 0.0
        if x and y and z and aliveCount() < global then
            local d = #(vector3(x, y, z) - pc)
            if d >= 10.0 and d <= ZC.spawnMax + 40.0 and math.abs(z - pc.z) < 60.0 then
                spawnZombie(x + 0.0, y + 0.0, z + 0.0, h + 0.0)
            end
        end
    end
end)

-- Boucle d'apparition : demande des points aux joueurs qui manquent de zombies autour d'eux
CreateThread(function()
    while true do
        Wait(ZC.spawnInterval)
        if Event.active and not Event.paused then
            local inten = intensityOf(Event.settings.intensity)
            local alive = aliveCount()
            local positions = {}
            for ent, z in pairs(Zombies) do
                if not z.dead and DoesEntityExist(ent) then positions[#positions + 1] = GetEntityCoords(ent) end
            end
            local t = GetGameTimer()
            for _, p in ipairs(GetPlayers()) do
                if alive >= inten.global then break end
                local id = tonumber(p)
                local ped = GetPlayerPed(id)
                local pend = Pending[id]
                if ped ~= 0 and (not pend or t - pend.at > 4000) then
                    local pc = GetEntityCoords(ped)
                    if inArea(pc) and GetEntityHealth(ped) > 0 then
                        local near = 0
                        for _, zc in ipairs(positions) do
                            if #(zc - pc) < ZC.nearRadius then near = near + 1 end
                        end
                        local need = math.min(inten.perPlayer - near, ZC.spawnBatch, inten.global - alive)
                        if need > 0 then
                            Pending[id] = { n = need, at = t }
                            alive = alive + need
                            TriggerClientEvent('adminmenu:zombies:spawnRequest', id, need, ZC.spawnMin, ZC.spawnMax)
                        end
                    end
                end
            end
        end
    end
end)

-- Boucle d'entretien : morts (compteur de kills), corps, zombies trop loin
CreateThread(function()
    while true do
        Wait(2500)
        if ZombieCount > 0 then
            local players = {}
            for _, p in ipairs(GetPlayers()) do
                local ped = GetPlayerPed(p)
                if ped ~= 0 then players[#players + 1] = GetEntityCoords(ped) end
            end
            local t = now()
            for ent, z in pairs(Zombies) do
                if not DoesEntityExist(ent) then
                    Zombies[ent] = nil
                    ZombieCount = ZombieCount - 1
                elseif z.dead then
                    if t - z.dead >= ZC.bodyTime then removeZombie(ent) end
                elseif isDead(ent) then
                    z.dead = t
                    creditKill(killerOf(ent))
                else
                    local c = GetEntityCoords(ent)
                    local close = false
                    for _, pc in ipairs(players) do
                        if #(pc - c) < ZC.despawnDistance then close = true break end
                    end
                    if not close then removeZombie(ent) end
                end
            end
        end
    end
end)

-- ---------------------------------------------------------
--  Début / fin
-- ---------------------------------------------------------
-- Tous les zombies tombent (chaque client tue ceux qu'il contrôle), puis le serveur nettoie
function KillAllZombies()
    local n = aliveCount()
    if n == 0 then return 0 end
    TriggerClientEvent('adminmenu:zombies:killAll', -1)
    for _, z in pairs(Zombies) do z.dead = z.dead or now() end
    SetTimeout(5000, function()
        for ent, z in pairs(Zombies) do
            if z.dead and now() - z.dead >= 4 then removeZombie(ent) end
        end
    end)
    return n
end

local function announce(message, style)
    if not message or message == '' then return end
    TriggerClientEvent('adminmenu:announce', -1, {
        title = ZC.announce.title, message = message, image = '', style = style or 'alert',
        duration = 12, ticker = false, by = 'Événement',
    })
end

local function stopEvent(src, reason, message)
    if not Event.active then return end
    Event.active = false
    if ZombieBossCleanup then ZombieBossCleanup() end
    clearZombies()
    restoreWorld()
    local okLoot, lootErr = pcall(ZombieLoot.Stop, Event)
    if not okLoot then print('^1[AdminMenu] Fin des caisses : ' .. tostring(lootErr) .. '^7') end
    broadcastState()
    TriggerClientEvent('adminmenu:zombies:missions', -1, {})
    if message then
        announce(message, 'event')
    elseif Event.settings.announce then
        announce(ZC.announce.stop, 'event')
    end
    local top = {}
    for id, k in pairs(Event.kills) do top[#top + 1] = ('%s : %d'):format(GetPlayerName(id) or ('#' .. id), k) end
    AM.addLog(src or 0, 'Attaque de zombies terminée', ('%s · %d zombies tués · %d joueurs relevés%s'):format(
        reason or 'arrêtée', Event.killed, Event.deaths, #top > 0 and (' · ' .. table.concat(top, ', ')) or ''))
end

-- ---------------------------------------------------------
--  MISSIONS DE L'ÉVÉNEMENT (coopératives, pour tout le serveur)
--  Une mission = des étapes dans l'ordre. Types d'étape :
--   reach    : un joueur atteint le point
--   interact : un joueur maintient E sur le point pendant X s
--   defend   : au moins un joueur reste dans la zone pendant X s (cumulé)
--  Résultat à la fin : décontamination (fin de l'événement), zombies tués, ou rien.
-- ---------------------------------------------------------
local STEP_TYPES = { reach = true, interact = true, defend = true, boss = true }
local OUTCOMES = { decontaminate = true, killall = true, none = true }
local Interacting = {}   -- [joueur] = { mission, step, at }
local missionSeq = 0

local function cleanText(v, n)
    if type(v) ~= 'string' then return '' end
    return (v:gsub('[%c<>]', '')):sub(1, n):match('^%s*(.-)%s*$')
end

local function cleanStep(st)
    if type(st) ~= 'table' or not STEP_TYPES[st.type] then return nil, 'Type d\'étape invalide.' end
    local x, y, z = tonumber(st.x), tonumber(st.y), tonumber(st.z)
    if not x or not y or not z or math.abs(x) > 20000 or math.abs(y) > 20000 then return nil, 'Une étape n\'a pas de lieu.' end
    local title = cleanText(st.title, 60)
    if title == '' then return nil, 'Chaque étape doit avoir un titre.' end
    local B = ZC.boss or {}
    local out = {
        type = st.type, title = title, desc = cleanText(st.desc, 160),
        x = x + 0.0, y = y + 0.0, z = z + 0.0,
        radius = num(st.radius, 3, 300, st.type == 'defend' and 25 or (st.type == 'boss' and (B.leash or 80) or 6)),
        seconds = math.floor(num(st.seconds, 3, 900, st.type == 'defend' and 60 or 10)),
        progress = 0,
    }
    if st.type == 'boss' then
        local name = cleanText(st.bossName, 40)
        out.bossName = name ~= '' and name or (B.name or 'Le Colosse')
        out.bossHealth = math.floor(num(st.bossHealth, 500, 200000, B.health or 8000))
        out.bossScale = num(st.bossScale, 1.0, 3.0, B.scale or 2.0)
        out.bossSpeed = num(st.bossSpeed, 0.6, 3.0, B.speed or 1.6)
        out.bossModel = (tostring(st.bossModel or ''):gsub('[^%w_]', '')):sub(1, 40)
        if out.bossModel == '' then out.bossModel = B.model or 'u_m_y_juggernaut_01' end
        out.minions = math.floor(num(st.minions, 0, 40, B.minions or 12))
        out.reinforce = st.reinforce == nil and (B.reinforce ~= false) or (st.reinforce == true or st.reinforce == 'true')
    end
    return out
end

local function cleanMission(m)
    if type(m) ~= 'table' then return nil, 'Mission invalide.' end
    local title = cleanText(m.title, 60)
    if title == '' then return nil, 'Donne un titre à chaque mission.' end
    local steps = {}
    for i, st in ipairs(type(m.steps) == 'table' and m.steps or {}) do
        if i > ZC.missionMaxSteps then break end
        local cs, err = cleanStep(st)
        if not cs then return nil, ('« %s », étape %d : %s'):format(title, i, err) end
        steps[#steps + 1] = cs
    end
    if #steps == 0 then return nil, ('« %s » n\'a aucune étape.'):format(title) end
    local rewards, rerr = ZombieLoot.CleanRewards(m.rewards)
    if not rewards then return nil, ('« %s » : %s'):format(title, rerr) end
    missionSeq = missionSeq + 1
    return {
        id = missionSeq, title = title, desc = cleanText(m.desc, 200),
        outcome = OUTCOMES[m.outcome] and m.outcome or 'none',
        delay = math.floor(num(m.delay, 0, ZC.maxDuration, 0)),
        steps = steps, step = 1, state = 'waiting', participants = {},
        rewards = rewards,
    }
end

local function cleanMissionList(list)
    local out = {}
    for i, m in ipairs(type(list) == 'table' and list or {}) do
        if i > ZC.missionMax then break end
        local cm, err = cleanMission(m)
        if not cm then return nil, err end
        out[#out + 1] = cm
    end
    return out
end

local function activeStep(m)
    if m.state ~= 'active' then return nil end
    return m.steps[m.step]
end

-- Les zombies apparaissent aussi autour des objectifs en cours (même hors de la zone)
missionHotspots = function(c)
    for _, m in ipairs(Event.missions or {}) do
        local st = activeStep(m)
        if st then
            local dx, dy = c.x - st.x, c.y - st.y
            if dx * dx + dy * dy <= ZC.missionHotspot * ZC.missionHotspot then return true end
        end
    end
    return false
end

local function publicMissions()
    local list = {}
    if not Event.active then return list end
    for _, m in ipairs(Event.missions or {}) do
        if m.state == 'active' then
            local st = m.steps[m.step]
            list[#list + 1] = {
                id = m.id, title = m.title, desc = m.desc, step = m.step, total = #m.steps, outcome = m.outcome,
                current = { type = st.type, title = st.title, desc = st.desc, x = st.x, y = st.y, z = st.z,
                    radius = st.radius, seconds = st.seconds, progress = st.progress,
                    bossName = st.bossName, bossHealth = st.bossHealth,
                    bossNet = (st.type == 'boss' and ZombieBossNet) and ZombieBossNet(m.id) or nil },
            }
        end
    end
    return list
end

local missionsPending = false
local function broadcastMissions(target)
    if target then return TriggerClientEvent('adminmenu:zombies:missions', target, publicMissions()) end
    if missionsPending then return end
    missionsPending = true
    SetTimeout(100, function()
        missionsPending = false
        TriggerClientEvent('adminmenu:zombies:missions', -1, publicMissions())
    end)
end

local function playersNear(x, y, z, radius)
    local list = {}
    local p3 = vector3(x, y, z)
    for _, p in ipairs(GetPlayers()) do
        local ped = GetPlayerPed(p)
        if ped ~= 0 and GetEntityHealth(ped) > 0 and #(GetEntityCoords(ped) - p3) <= radius then list[#list + 1] = tonumber(p) end
    end
    return list
end

local function notifyAll(msg, typ)
    TriggerClientEvent('adminmenu:notify', -1, msg, typ or 'info')
end

local function giveRewards(m, by)
    local ok, n = pcall(ZombieLoot.GiveRewards, m.rewards, ('la mission « %s »'):format(m.title), {
        participants = m.participants, finisher = by, lastStep = m.lastStepPlayers,
    })
    if not ok then print('^1[AdminMenu] Récompenses : ' .. tostring(n) .. '^7') return 0 end
    return n or 0
end

local function completeMission(m, by)
    m.state = 'done'
    local rewarded = giveRewards(m, by)
    AM.addLog(by or 0, 'Mission zombies réussie', ('%s · %d participant(s) récompensé(s)'):format(m.title, rewarded))
    if m.outcome == 'decontaminate' then
        notifyAll(('✔ Mission « %s » accomplie : décontamination lancée !'):format(m.title), 'success')
        TriggerClientEvent('adminmenu:zombies:decontaminate', -1)
        KillAllZombies()
        Event.paused = true
        SetTimeout(6000, function()
            stopEvent(0, 'décontamination réussie (' .. m.title .. ')', ZC.announce.decontaminated)
        end)
    elseif m.outcome == 'killall' then
        notifyAll(('✔ Mission « %s » accomplie : tous les zombies tombent !'):format(m.title), 'success')
        KillAllZombies()
    else
        notifyAll(('✔ Mission « %s » accomplie !'):format(m.title), 'success')
    end
end

local function completeStep(m, by)
    local st = activeStep(m)
    if not st then return end
    m.lastStepPlayers = {}
    for _, id in ipairs(playersNear(st.x, st.y, st.z, st.radius + 15.0)) do
        m.participants[id] = true
        m.lastStepPlayers[id] = true
    end
    if by and by > 0 then m.participants[by] = true m.lastStepPlayers[by] = true end
    for id, it in pairs(Interacting) do
        if it.mission == m.id then Interacting[id] = nil end
    end
    if m.step >= #m.steps then
        completeMission(m, by)
    else
        m.step = m.step + 1
        notifyAll(('Mission « %s » : étape %d/%d → %s'):format(m.title, m.step, #m.steps, m.steps[m.step].title), 'success')
    end
    broadcastMissions()
end

-- ---------------------------------------------------------
--  ÉTAPE « TUER LE BOSS »
--  Un boss géant (vie et taille réglables) apparaît au lieu de l'étape,
--  entouré de zombies qui attaquent ceux qui s'en prennent à lui.
-- ---------------------------------------------------------
local Bosses = {}   -- [missionId] = { ent, step, guards = { ent... }, aggro = { [src] = t }, nextReinforce }
local LooseGuards = {}   -- gardes libérés à la mort du boss (retirés à la fin de l'événement)
local BC = ZC.boss or {}

local function spawnGuard(b, st)
    local ang = math.random() * math.pi * 2
    local d = 4.0 + math.random() * 8.0
    local bc = DoesEntityExist(b.ent) and GetEntityCoords(b.ent) or vector3(st.x, st.y, st.z)
    local model = ZC.models[math.random(#ZC.models)]
    local ent = CreatePed(4, joaat(model), bc.x + math.cos(ang) * d, bc.y + math.sin(ang) * d, bc.z, math.deg(ang), true, true)
    local limit = GetGameTimer() + 1500
    while (not ent or ent == 0 or not DoesEntityExist(ent)) and GetGameTimer() < limit do Wait(50) end
    if not ent or ent == 0 or not DoesEntityExist(ent) then return end
    Entity(ent).state:set('zombie', math.random(100) <= 35 and 2 or 1, true)
    Entity(ent).state:set('zguard', NetworkGetNetworkIdFromEntity(b.ent), true)
    b.guards[#b.guards + 1] = ent
end

local function spawnBoss(m, st)
    local ent = CreatePed(4, joaat(st.bossModel), st.x, st.y, st.z + 0.5, 0.0, true, true)
    local limit = GetGameTimer() + 2500
    while (not ent or ent == 0 or not DoesEntityExist(ent)) and GetGameTimer() < limit do Wait(50) end
    if not ent or ent == 0 or not DoesEntityExist(ent) then
        print(('^1[AdminMenu] Boss « %s » : modèle %s introuvable.^7'):format(st.bossName, st.bossModel))
        return
    end
    Entity(ent).state:set('zboss', {
        mission = m.id, name = st.bossName, hp = st.bossHealth, scale = st.bossScale, speed = st.bossSpeed or 1.6,
        cx = st.x, cy = st.y, cz = st.z, leash = st.radius,
    }, true)
    local b = { ent = ent, step = m.step, guards = {}, aggro = {}, nextReinforce = now() + (BC.reinforceEvery or 20) }
    Bosses[m.id] = b
    for _ = 1, st.minions do spawnGuard(b, st) end
    notifyAll(('☠ %s est apparu ! Mission « %s » : abattez-le.'):format(st.bossName, m.title), 'error')
    broadcastMissions()
    AM.addLog(0, 'Boss zombie', ('%s apparu (%d PV, ×%.1f, %d gardes)'):format(st.bossName, st.bossHealth, st.bossScale, st.minions))
end

local function removeBoss(mid, keepGuards)
    local b = Bosses[mid]
    if not b then return end
    Bosses[mid] = nil
    if DoesEntityExist(b.ent) then DeleteEntity(b.ent) end
    for _, g in ipairs(b.guards) do
        if DoesEntityExist(g) then
            if keepGuards then Entity(g).state:set('zguard', nil, true) LooseGuards[#LooseGuards + 1] = g else DeleteEntity(g) end
        end
    end
end
function ZombieBossCleanup()
    for mid in pairs(Bosses) do removeBoss(mid) end
    for _, g in ipairs(LooseGuards) do if DoesEntityExist(g) then DeleteEntity(g) end end
    LooseGuards = {}
end

-- Joueurs qui frappent le boss : ses gardes les prennent pour cible
RegisterNetEvent('adminmenu:zombies:bossHit', function(netId)
    local src = source
    if not AM.rateLimit(src, 'zbosshit', 3, 2000) then return end
    local ent = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    for _, b in pairs(Bosses) do
        if b.ent == ent then
            b.aggro[src] = now()
            local list = {}
            for id, t in pairs(b.aggro) do if now() - t < 25 and GetPlayerName(id) then list[#list + 1] = id end end
            Entity(ent).state:set('zaggro', list, true)
            return
        end
    end
end)

-- Corps à corps : le client qui contrôle le zombie (ou le boss) signale un coup,
-- le serveur vérifie la distance et la cadence, puis la victime encaisse.
local MeleeAt = {}
RegisterNetEvent('adminmenu:zombies:melee', function(netId, targetSid)
    local src = source
    if not Event.active or not AM.rateLimit(src, 'zmelee', 40, 1000) then return end
    local ent = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if ent == 0 or not DoesEntityExist(ent) or GetEntityHealth(ent) <= 0 then return end
    local est = Entity(ent).state
    local boss = est.zboss
    if not boss and not est.zombie then return end
    local B = ZC.boss or {}
    local atk = boss and (B.melee or {}) or (ZC.attack or {})
    local cd = (atk.cooldown or 800) - 250
    if MeleeAt[ent] and GetGameTimer() - MeleeAt[ent] < cd then return end
    targetSid = tonumber(targetSid)
    if not targetSid or not GetPlayerName(targetSid) then return end
    local tp = GetPlayerPed(targetSid)
    if tp == 0 or GetEntityHealth(tp) <= 0 then return end
    local reach = (atk.range or 1.8) * (boss and (0.6 + 0.4 * (boss.scale or 1.0)) or 1.0) + 1.5
    if #(GetEntityCoords(ent) - GetEntityCoords(tp)) > reach then return end
    MeleeAt[ent] = GetGameTimer()
    local c = GetEntityCoords(ent)
    TriggerClientEvent('adminmenu:zombies:hurt', targetSid, boss and 'boss' or 'zombie', { x = c.x, y = c.y, z = c.z })
end)

-- Tirs sur la partie AGRANDIE du boss (hitbox à sa vraie taille) :
-- le tireur signale le tir, le serveur vérifie et transmet au client qui « possède » le boss
RegisterNetEvent('adminmenu:zombies:bossDamage', function(netId, dmg)
    local src = source
    if not Event.active or not AM.rateLimit(src, 'zbossdmg', 25, 1000) then return end
    local ent = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if ent == 0 or not DoesEntityExist(ent) or not Entity(ent).state.zboss or GetEntityHealth(ent) <= 0 then return end
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(ent)) > 250.0 then return end
    dmg = math.floor(math.max(1, math.min(250, tonumber(dmg) or 0)))
    local owner = NetworkGetEntityOwner(ent)
    if owner and owner > 0 then TriggerClientEvent('adminmenu:zombies:bossApplyDamage', owner, netId, dmg) end
    for _, b in pairs(Bosses) do if b.ent == ent then b.aggro[src] = now() end end
end)

-- Attaque à distance du boss : relayée comme un crachat, en plus gros
RegisterNetEvent('adminmenu:zombies:bossThrow', function(netId, targetSid, aim)
    local src = source
    if not Event.active or not AM.rateLimit(src, 'zbossthrow', 4, 1000) then return end
    local ent = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if ent == 0 or not DoesEntityExist(ent) or not Entity(ent).state.zboss then return end
    targetSid = tonumber(targetSid)
    if not targetSid or type(aim) ~= 'table' then return end
    local from = GetEntityCoords(ent)
    local to = vector3(tonumber(aim.x) or 0, tonumber(aim.y) or 0, tonumber(aim.z) or 0)
    if #(from - to) > ((BC.throw and BC.throw.maxRange) or 40) + 10.0 then return end
    local scale = (Entity(ent).state.zboss.scale or 1.0)
    for _, p in ipairs(GetPlayers()) do
        local id = tonumber(p)
        if #(GetEntityCoords(GetPlayerPed(id)) - from) < 200.0 then
            TriggerClientEvent('adminmenu:zombies:spitFx', id, { x = from.x, y = from.y, z = from.z + 1.2 * scale }, { x = to.x, y = to.y, z = to.z }, targetSid, 'boss')
        end
    end
end)

-- Chaque seconde (appelé par missionTick) : apparition, renforts, mort du boss
local function bossTick(m, st)
    local b = Bosses[m.id]
    if not b then
        if not st.spawned then st.spawned = true spawnBoss(m, st) end
        return
    end
    -- Mort (ou disparu) : étape réussie
    if not DoesEntityExist(b.ent) or GetEntityHealth(b.ent) <= 0 then
        local killer = DoesEntityExist(b.ent) and killerOf(b.ent) or nil
        notifyAll(('☠ %s est tombé%s !'):format(st.bossName, killer and (' sous les coups de ' .. (GetPlayerName(killer) or '?')) or ''), 'success')
        for id in pairs(b.aggro) do m.participants[id] = true end
        local ent = b.ent
        removeBoss(m.id, true)
        SetTimeout(15000, function() if DoesEntityExist(ent) then DeleteEntity(ent) end end)   -- le corps reste un moment
        completeStep(m, killer)
        return
    end
    -- Gardes morts retirés, renforts
    local alive = {}
    for _, g in ipairs(b.guards) do
        if DoesEntityExist(g) and GetEntityHealth(g) > 0 then alive[#alive + 1] = g
        elseif DoesEntityExist(g) then SetTimeout(10000, function() if DoesEntityExist(g) then DeleteEntity(g) end end) end
    end
    b.guards = alive
    if st.reinforce and now() >= b.nextReinforce then
        b.nextReinforce = now() + (BC.reinforceEvery or 20)
        for _ = 1, math.min(4, st.minions - #b.guards) do spawnGuard(b, st) end
    end
    -- Joueurs qui l'ont frappé il y a plus de 25 s : oubliés
    for id, t in pairs(b.aggro) do if now() - t >= 25 or not GetPlayerName(id) then b.aggro[id] = nil end end
end

function ZombieBossNet(mid)
    local b = Bosses[mid]
    return b and DoesEntityExist(b.ent) and NetworkGetNetworkIdFromEntity(b.ent) or nil
end

local function findMission(id)
    for _, m in ipairs(Event.missions or {}) do
        if m.id == tonumber(id) then return m end
    end
end

-- Chaque seconde : missions qui démarrent, points atteints, zones défendues
local function missionTick()
    if not Event.active or not Event.missions then return end
    local t = now()
    for _, m in ipairs(Event.missions) do
        if m.state == 'waiting' and t >= m.startAt then
            m.state = 'active'
            notifyAll(('☣ Nouvelle mission : %s'):format(m.title), 'error')
            AM.addLog(0, 'Mission zombies', 'Démarrée : ' .. m.title)
            broadcastMissions()
        end
        local st = activeStep(m)
        if st then
            if st.type == 'reach' then
                if #playersNear(st.x, st.y, st.z, st.radius) > 0 then completeStep(m) end
            elseif st.type == 'boss' then
                bossTick(m, st)
            elseif st.type == 'defend' then
                local inside = playersNear(st.x, st.y, st.z, st.radius)
                if #inside > 0 then
                    for _, id in ipairs(inside) do m.participants[id] = true end
                    st.progress = st.progress + 1
                    if st.progress >= st.seconds then completeStep(m) else broadcastMissions() end
                end
            end
        end
    end
end

-- Interaction « maintenir E »
RegisterNetEvent('adminmenu:zombies:interact', function(missionId, stepIndex, phase)
    local src = source
    if not AM.rateLimit(src, 'zombies:interact', 6, 2000) then return end
    local m = findMission(missionId)
    local st = m and activeStep(m)
    if not st or st.type ~= 'interact' or m.step ~= tonumber(stepIndex) then Interacting[src] = nil return end
    local ped = GetPlayerPed(src)
    if ped == 0 or #(GetEntityCoords(ped) - vector3(st.x, st.y, st.z)) > st.radius + 3.0 then Interacting[src] = nil return end

    if phase == 'start' then
        Interacting[src] = { mission = m.id, step = m.step, at = GetGameTimer() }
    elseif phase == 'done' then
        local it = Interacting[src]
        Interacting[src] = nil
        if it and it.mission == m.id and it.step == m.step and GetGameTimer() - it.at >= st.seconds * 1000 - 800 then
            completeStep(m, src)
        end
    else
        Interacting[src] = nil
    end
end)

RegisterNetEvent('adminmenu:zombies:requestMissions', function()
    local src = source
    if not AM.rateLimit(src, 'zombies:missions', 2, 5000) then return end
    broadcastMissions(src)
end)

AddEventHandler('playerDropped', function() Interacting[source] = nil end)

local function scheduleMissions(list)
    local t = now()
    for _, m in ipairs(list) do
        m.startAt = t + m.delay * 60
        Event.missions[#Event.missions + 1] = m
    end
    missionTick()
    broadcastMissions()
end

CreateThread(function()
    while true do
        Wait(1000)
        if Event.active and now() >= Event.endsAt then stopEvent(0, 'durée écoulée') end
        if Event.active then
            local ok, err = pcall(missionTick)
            if not ok then print('^1[AdminMenu] Missions zombies : ' .. tostring(err) .. '^7') end
        end
    end
end)

-- ---------------------------------------------------------
--  Actions du menu (permission event_zombies, service staff vérifié par le dispatcher)
-- ---------------------------------------------------------
local A = AM.Actions
local function def(name, fn) A[name] = { perm = 'event_zombies', fn = fn } end

def('zombies_start', function(src, d)
    if Event.active then return AM.notify(src, 'Une attaque est déjà en cours.', 'error') end
    local minutes = math.floor(num(d.duration, 1, ZC.maxDuration, 30))
    local area = (d.area == 'map' or d.area == 'radius') and d.area or 'city'
    local settings = {
        intensity = intensityOf(d.intensity).id,
        area = area,
        storm = d.storm ~= false and d.storm ~= 'false',
        blackout = bool(d.blackout),
        night = bool(d.night),
        emptyCity = d.emptyCity ~= false and d.emptyCity ~= 'false',
        headshot = bool(d.headshot),
        runners = math.floor(num(d.runners, 0, 100, 20)),
        spitters = math.floor(num(d.spitters, 0, 100, 15)),
        damage = num(d.damage, 0.2, 5.0, ZC.damage),
        announce = d.announce ~= false and d.announce ~= 'false',
    }
    if area == 'radius' then
        local ped = GetPlayerPed(src)
        if ped == 0 then return AM.notify(src, 'Position introuvable.', 'error') end
        local c = GetEntityCoords(ped)
        settings.center = { x = c.x, y = c.y }
        settings.radius = num(d.radius, 100, 5000, 800)
    end

    local missions, err = cleanMissionList(d.missions)
    if not missions then return AM.notify(src, err, 'error') end
    local crateTypes, cerr = ZombieLoot.CleanCrateTypes(d.crates)
    if not crateTypes then return AM.notify(src, cerr, 'error') end

    Event = {
        active = true, settings = settings, startedAt = now(), endsAt = now() + minutes * 60,
        paused = false, killed = 0, deaths = 0, kills = {}, by = AM.pname(src), missions = {},
        tag = ('zev_%d'):format(now()),
    }
    Interacting = {}
    clearZombies()
    applyWorld(settings)
    broadcastState()
    if settings.announce then
        local msg = tostring(d.message or ''):sub(1, 400)
        announce(msg:gsub('%s', '') ~= '' and msg or ZC.announce.start, 'alert')
    end
    scheduleMissions(missions)
    ZombieLoot.Start(crateTypes)
    AM.notify(src, ('Attaque de zombies lancée pour %d minutes%s.'):format(minutes,
        #missions > 0 and (' avec %d mission(s)'):format(#missions) or ''), 'success')
    AM.addLog(src, 'Attaque de zombies lancée', ('%d min · intensité %s · zone %s'):format(minutes, intensityOf(settings.intensity).label,
        area == 'map' and 'toute la carte' or area == 'radius' and ('rayon ' .. math.floor(settings.radius) .. ' m') or 'Los Santos'))
end)

def('zombies_extend', function(src, d)
    if not Event.active then return AM.notify(src, 'Aucune attaque en cours.', 'error') end
    local minutes = math.floor(num(d.minutes, -120, 120, 10))
    local maxEnd = Event.startedAt + ZC.maxDuration * 60
    Event.endsAt = math.min(maxEnd, math.max(now() + 30, Event.endsAt + minutes * 60))
    broadcastState()
    AM.notify(src, ('Fin de l\'attaque dans %d min.'):format(math.ceil((Event.endsAt - now()) / 60)), 'success')
    AM.addLog(src, 'Attaque de zombies prolongée', ('%+d min'):format(minutes))
end)

def('zombies_intensity', function(src, d)
    if not Event.active then return AM.notify(src, 'Aucune attaque en cours.', 'error') end
    Event.settings.intensity = intensityOf(d.intensity).id
    AM.notify(src, ('Intensité : %s.'):format(intensityOf(Event.settings.intensity).label), 'success')
    AM.addLog(src, 'Attaque de zombies', 'Intensité ' .. intensityOf(Event.settings.intensity).label)
end)

def('zombies_pause', function(src)
    if not Event.active then return AM.notify(src, 'Aucune attaque en cours.', 'error') end
    Event.paused = not Event.paused
    Pending = {}
    AM.notify(src, Event.paused and 'Apparitions suspendues : plus aucun nouveau zombie.' or 'Apparitions reprises.', 'success')
    AM.addLog(src, 'Attaque de zombies', Event.paused and 'Apparitions suspendues' or 'Apparitions reprises')
end)

def('zombies_killall', function(src)
    local n = KillAllZombies()
    if n == 0 then return AM.notify(src, 'Aucun zombie en vie.', 'info') end
    AM.notify(src, ('%d zombie(s) éliminé(s).'):format(n), 'success')
    AM.addLog(src, 'Attaque de zombies', ('Tous les zombies tués (%d)'):format(n))
end)

def('zombies_mission_add', function(src, d)
    if not Event.active then return AM.notify(src, 'Aucune attaque en cours.', 'error') end
    if #Event.missions >= ZC.missionMax * 2 then return AM.notify(src, 'Trop de missions pour cet événement.', 'error') end
    local m, err = cleanMission(d.mission)
    if not m then return AM.notify(src, err, 'error') end
    scheduleMissions({ m })
    AM.notify(src, m.delay > 0 and ('Mission « %s » programmée dans %d min.'):format(m.title, m.delay)
        or ('Mission « %s » lancée.'):format(m.title), 'success')
    AM.addLog(src, 'Mission zombies ajoutée', m.title)
end)

def('zombies_mission_skip', function(src, d)
    local m = findMission(d.id)
    if not Event.active or not m then return AM.notify(src, 'Mission introuvable.', 'error') end
    if m.state == 'waiting' then
        m.startAt = now()
        missionTick()
        return AM.notify(src, ('Mission « %s » lancée maintenant.'):format(m.title), 'success')
    end
    if m.state ~= 'active' then return AM.notify(src, 'Cette mission est terminée.', 'error') end
    completeStep(m, nil)
    AM.notify(src, 'Étape validée.', 'success')
    AM.addLog(src, 'Mission zombies', ('Étape validée par le staff : %s'):format(m.title))
end)

def('zombies_mission_cancel', function(src, d)
    local m = findMission(d.id)
    if not Event.active or not m then return AM.notify(src, 'Mission introuvable.', 'error') end
    if m.state == 'done' or m.state == 'cancelled' then return AM.notify(src, 'Cette mission est déjà terminée.', 'error') end
    m.state = 'cancelled'
    broadcastMissions()
    notifyAll(('Mission « %s » annulée.'):format(m.title), 'info')
    AM.addLog(src, 'Mission zombies annulée', m.title)
end)

def('zombies_stop', function(src)
    if not Event.active then return AM.notify(src, 'Aucune attaque en cours.', 'error') end
    stopEvent(src, 'arrêtée par ' .. AM.pname(src))
    AM.notify(src, 'Attaque de zombies arrêtée, la ville redevient normale.', 'success')
end)

-- ---------------------------------------------------------
--  Évènements joueurs
-- ---------------------------------------------------------
RegisterNetEvent('adminmenu:zombies:request', function()
    local src = source
    if not AM.rateLimit(src, 'zombies:request', 2, 5000) then return end
    broadcastState(src)
    if Event.active then broadcastMissions(src) ZombieLoot.SendTo(src) end
    if Event.active and Event.kills[src] then TriggerClientEvent('adminmenu:zombies:kills', src, Event.kills[src]) end
end)

local DiedAt = {}
RegisterNetEvent('adminmenu:zombies:died', function()
    local src = source
    if not Event.active or not AM.rateLimit(src, 'zombies:died', 1, 5000) then return end
    Event.deaths = Event.deaths + 1
    DiedAt[src] = os.time()
end)

-- Relevé automatique pendant l'attaque : la réanimation passe par le serveur (qbx_medical)
RegisterNetEvent('adminmenu:zombies:revive', function()
    local src = source
    if not Event.active or not DiedAt[src] or os.time() - DiedAt[src] > 120 then return end
    DiedAt[src] = nil
    if MedicalRevive then MedicalRevive(src) end
end)

AddEventHandler('playerDropped', function()
    Pending[source] = nil
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    clearZombies()
end)

-- ---------------------------------------------------------
--  Données de l'onglet Événements
-- ---------------------------------------------------------
table.insert(AM.DataHooks, function(src, data)
    if not AM.hasPerm(src, 'event_zombies') then return end
    local z = {
        active = Event.active, now = now(),
        intensities = ZC.intensities, durations = ZC.durations, maxDuration = ZC.maxDuration,
        defaultMessage = ZC.announce.start,
        places = ZC.places, presets = ZC.missionPresets,
        cratePresets = ZC.cratePresets and ZC.cratePresets[Bridge.Mode()] or ZC.cratePresets and ZC.cratePresets.ox,
        crateModels = ZC.crateModels, crateColors = ZC.crateColors, inventory = Bridge.Mode(),
        tagged = Bridge.SupportsTags(),
        reclaimPending = ZombieLoot.PendingCount(),
        limits = { missions = ZC.missionMax, steps = ZC.missionMaxSteps },
        boss = { name = (ZC.boss or {}).name, health = (ZC.boss or {}).health, scale = (ZC.boss or {}).scale, speed = (ZC.boss or {}).speed,
                 model = (ZC.boss or {}).model, minions = (ZC.boss or {}).minions, reinforce = (ZC.boss or {}).reinforce },
    }
    if Event.active then
        local top = {}
        for id, k in pairs(Event.kills) do
            if GetPlayerName(id) then top[#top + 1] = { name = GetPlayerName(id), kills = k } end
        end
        table.sort(top, function(a, b) return a.kills > b.kills end)
        while #top > 5 do table.remove(top) end
        z.endsAt, z.startedAt, z.paused = Event.endsAt, Event.startedAt, Event.paused
        z.settings, z.by = Event.settings, Event.by
        z.alive, z.killed, z.deaths, z.top = aliveCount(), Event.killed, Event.deaths, top
        z.maxEnd = Event.startedAt + ZC.maxDuration * 60
        local ms = {}
        for _, m in ipairs(Event.missions or {}) do
            local st = m.steps[math.min(m.step, #m.steps)]
            ms[#ms + 1] = {
                id = m.id, title = m.title, state = m.state, step = m.step, total = #m.steps, outcome = m.outcome,
                stepTitle = st.title, stepType = st.type, progress = st.progress, seconds = st.seconds,
                bossName = st.bossName,
                startsAt = m.startAt, participants = (function() local n = 0 for _ in pairs(m.participants) do n = n + 1 end return n end)(),
            }
        end
        z.missions = ms
        z.crates = ZombieLoot.AdminData()
    end
    data.zombies = z
end)

exports('IsZombieEventActive', function() return Event.active == true end)
