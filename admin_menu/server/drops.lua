-- =========================================================
--  ÉVÉNEMENT : LARGAGE DE DROPS - SERVEUR
--
--  Le staff prépare un PLANNING de drops (onglet Événements › Drops) :
--    heure (heure réelle du serveur), position (choisie sur la carte),
--    contenu, escouades de gardes (nombre, arme, armure, précision),
--    porteur de la clé, durée d'ouverture, public prévenu…
--
--  Déroulé d'un drop :
--    H - X min : annonce « Un drop va être largué » (aucune position)
--    H         : « Le drop est à terre » + position, fumée rouge,
--                gardes armés autour de la caisse (créés par le serveur)
--    Les gardes sont calmes ; dès qu'on leur tire dessus (ou qu'on tire
--    près d'eux, ou qu'on s'approche trop si réglé), ils ripostent.
--    La CLÉ est sur un des gardes : inspecter les corps (Alt + Inspecter).
--    Avec la clé (et tous les gardes morts si réglé) : ouverture (15 s),
--    puis le contenu s'ouvre dans un coffre temporaire.
-- =========================================================
local AM = AdminMenu
local A = AM.Actions
local DC = Config.Drops or {}

local Store = Storage.load('drops', {})
Store.settings = Store.settings or {}
Store.list = Store.list or {}

local DEFAULT_SETTINGS = {
    enabled = true,                         -- interrupteur général du système
    preTitle = 'LARGAGE IMMINENT',
    preMessage = 'Un drop va être largué dans {min} minutes. Préparez-vous !',
    landTitle = 'DROP À TERRE',
    landMessage = 'Le drop est à terre ! Sa position est marquée sur ta carte (fumée rouge).',
    endMessage = 'Le drop a été récupéré.',
    blipSprite = 478, blipColor = 1, blipRadius = 90,
    maxDuration = 45,                       -- minutes avant disparition si personne ne l'ouvre
    cleanupAfter = 5,                       -- minutes après l'ouverture avant le nettoyage
    alertRadius = 0,                        -- les gardes attaquent si on s'approche à moins de X m (0 = seulement si on tire)
    shotRadius = 60,                        -- tirer à moins de X m des gardes les met en alerte
    inspectTime = 4,                        -- secondes pour inspecter un corps
    illegalJobs = '',                       -- métiers considérés comme illégaux en plus des gangs (séparés par des virgules)
    timezone = 'paris',                     -- 'paris' (heure française, été / hiver auto), 'server' (horloge du serveur), ou décalage UTC (ex. 1)
}
for k, v in pairs(DEFAULT_SETTINGS) do if Store.settings[k] == nil then Store.settings[k] = v end end
local S = Store.settings
local function save() Storage.save('drops', Store) end

local Live = {}          -- [runId] = drop en cours
local runSeq = 0

-- ---------------------------------------------------------
--  Outils
-- ---------------------------------------------------------
local function num(v, min, max, def)
    v = tonumber(v)
    if not v then return def end
    return math.max(min, math.min(max, v))
end
local function bool(v, def) if v == nil then return def end return v == true end
local function text(v, n) return (tostring(v or ''):gsub('[%c<>]', '')):sub(1, n or 60) end
local function code(v) return (tostring(v or ''):gsub('[^%w_%-]', '')):sub(1, 60) end
-- ---------------------------------------------------------
--  HEURE RÉELLE (par défaut : heure de Paris, été / hiver automatique)
--  Beaucoup d'hébergeurs règlent le serveur en UTC : on ne se fie pas à son horloge.
-- ---------------------------------------------------------
local function dow(y, m, d)   -- 0 = dimanche (algorithme de Sakamoto)
    local t = { 0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4 }
    if m < 3 then y = y - 1 end
    return (y + y // 4 - y // 100 + y // 400 + t[m] + d) % 7
end
local function parisOffset(epoch)
    local u = os.date('!*t', epoch)
    local startDay = 31 - dow(u.year, 3, 31)     -- dernier dimanche de mars, 1 h UTC
    local endDay = 31 - dow(u.year, 10, 31)      -- dernier dimanche d'octobre, 1 h UTC
    local function key(mo, d, h) return mo * 10000 + d * 100 + h end
    local k = key(u.month, u.day, u.hour)
    local summer = k >= key(3, startDay, 1) and k < key(10, endDay, 1)
    return summer and 2 or 1
end
local function localEpoch()
    local now = os.time()
    local tz = S.timezone
    if tz == 'server' then return nil end
    if tz == 'paris' or tz == nil then return now + parisOffset(now) * 3600 end
    return now + (tonumber(tz) or 0) * 3600
end
local function fmt(pattern)
    local e = localEpoch()
    if e then return os.date('!' .. pattern, e) end
    return os.date(pattern)
end
local function today() return fmt('%Y-%m-%d') end
local function clockNow() return fmt('%H:%M') end
local function nowMinutes() return tonumber(fmt('%H')) * 60 + tonumber(fmt('%M')) end
local function tzLabel()
    local tz = S.timezone
    if tz == 'paris' or tz == nil then return ('Heure de Paris (UTC+%d)'):format(parisOffset(os.time())) end
    if tz == 'server' then return 'Heure du serveur' end
    local n = tonumber(tz) or 0
    return ('UTC%s%d'):format(n >= 0 and '+' or '', n)
end
local function nextId(list) local m = 0 for _, d in ipairs(list) do if d.id > m then m = d.id end end return m + 1 end
local function findPlanned(id) for i, d in ipairs(Store.list) do if d.id == tonumber(id) then return i, d end end end

-- Minutes depuis minuit pour « 18:30 »
local function minutesOf(t)
    local h, m = tostring(t or ''):match('^(%d%d?):(%d%d)$')
    if not h then return nil end
    h, m = tonumber(h), tonumber(m)
    if h > 23 or m > 59 then return nil end
    return h * 60 + m
end

-- Qui reçoit les annonces et voit la position : illégaux (gangs + métiers listés) ou tout le monde
local function illegalJobs()
    local t = {}
    for j in tostring(S.illegalJobs or ''):gmatch('[^,%s]+') do t[j:lower()] = true end
    return t
end
local function concerned(src, audience)
    if AM.rankOf(src) and AM.onDuty(src) then return true end           -- le staff en service voit tout
    if audience == 'all' then return true end
    local gang = Bridge.GetGang and Bridge.GetGang(src)
    if gang then return true end
    local job = Bridge.GetJob and Bridge.GetJob(src)
    return job ~= nil and illegalJobs()[job] == true
end
local function forAudience(audience, fn)
    for _, p in ipairs(GetPlayers()) do
        local id = tonumber(p)
        if concerned(id, audience) then fn(id) end
    end
end
local function announce(audience, title, message, style)
    forAudience(audience, function(id)
        TriggerClientEvent('adminmenu:announce', id, { title = title, message = message, image = '', style = style or 'alert', duration = 12, ticker = false, by = 'Événement' })
    end)
end

-- ---------------------------------------------------------
--  Nettoyage d'un drop planifié (ce qui vient du menu)
-- ---------------------------------------------------------
local WEAPONS, MODELS = {}, {}
for _, w in ipairs(DC.weapons or {}) do WEAPONS[w.id] = w.label end
for _, m in ipairs(DC.models or {}) do MODELS[m.id] = m end
local DIFF = DC.difficulties or {}

local function cleanSquad(q)
    q = type(q) == 'table' and q or {}
    local weapon = code(q.weapon):upper()
    if weapon == '' then weapon = 'WEAPON_PISTOL' end
    local model = code(q.model):lower()
    if model == '' then model = 'g_m_y_mexgoon_01' end
    return {
        label = text(q.label ~= nil and q.label or 'Gardes', 30),
        count = math.floor(num(q.count, 1, 40, 6)),
        weapon = weapon, model = model,
        armor = math.floor(num(q.armor, 0, 100, 0)),
        health = math.floor(num(q.health, 100, 1000, 200)),
        accuracy = math.floor(num(q.accuracy, 5, 100, 35)),
        heavy = bool(q.heavy, false),
    }
end

local function cleanDrop(d, base)
    d = type(d) == 'table' and d or {}
    base = base or {}
    local items = {}
    for _, it in ipairs(type(d.items) == 'table' and d.items or {}) do
        local name = code(it.item):lower()
        if name ~= '' and #items < 30 then items[#items + 1] = { item = name, count = math.floor(num(it.count, 1, 10000, 1)) } end
    end
    local squads = {}
    for _, q in ipairs(type(d.squads) == 'table' and d.squads or {}) do
        if #squads < 6 then squads[#squads + 1] = cleanSquad(q) end
    end
    if #squads == 0 then squads[1] = cleanSquad({}) end
    local c = type(d.coords) == 'table' and d.coords or base.coords
    local keyHolder = tostring(d.keyHolder or base.keyHolder or 'random')
    if keyHolder ~= 'random' and keyHolder ~= 'heavy' and keyHolder ~= 'light' and not keyHolder:match('^squad:%d$') then keyHolder = 'random' end
    return {
        id = base.id,
        name = text(d.name ~= nil and d.name or base.name or 'Drop', 40),
        time = minutesOf(d.time) and d.time or (base.time or '18:00'),
        repeatDaily = bool(d.repeatDaily, base.repeatDaily or false),
        enabled = bool(d.enabled, base.enabled ~= false),
        coords = c and { x = num(c.x, -10000, 10000, 0) + 0.0, y = num(c.y, -10000, 10000, 0) + 0.0, z = num(c.z, -200, 2000, 0) + 0.0 } or nil,
        place = text(d.place ~= nil and d.place or base.place or '', 60),
        items = items,
        squads = squads,
        radius = num(d.radius, 4, 60, 14),
        keyHolder = keyHolder,
        openTime = math.floor(num(d.openTime, 1, 300, 15)),
        announceMinutes = math.floor(num(d.announceMinutes, 0, 60, 5)),
        audience = d.audience == 'all' and 'all' or 'illegal',
        requireAllDead = bool(d.requireAllDead, true),
        difficulty = DIFF[d.difficulty] and d.difficulty or (base.difficulty or 'normal'),
        vehicles = math.floor(num(d.vehicles, 0, 8, base.vehicles or 3)),
        vehicleModels = (function()
            local out = {}
            for m in tostring(d.vehicleModels or ''):gmatch('[^,%s]+') do if #out < 8 then out[#out + 1] = code(m):lower() end end
            return table.concat(out, ', ')
        end)(),
        lockVehicles = bool(d.lockVehicles, base.lockVehicles ~= false),
        cover = math.floor(num(d.cover, 0, 12, base.cover or 4)),
        revealAfter = math.floor(num(d.revealAfter, 0, 50, base.revealAfter or 5)),   -- 0 = jamais
        lastRun = base.lastRun,
        lastAnnounce = base.lastAnnounce,
    }
end

-- ---------------------------------------------------------
--  Gardes, caisse, clé
-- ---------------------------------------------------------
local function deleteEntity(e) if e and e ~= 0 and DoesEntityExist(e) then DeleteEntity(e) end end
local function waitEntity(e)
    local limit = GetGameTimer() + 2000
    while (not e or e == 0 or not DoesEntityExist(e)) and GetGameTimer() < limit do Wait(50) end
    return e and e ~= 0 and DoesEntityExist(e)
end

local function publicLive(run)
    local alive = 0
    for _, g in ipairs(run.guards) do
        if DoesEntityExist(g.ent) and GetEntityHealth(g.ent) > 0 then alive = alive + 1 end
    end
    run.alive = alive
    return {
        id = run.id, plannedId = run.plannedId, name = run.name, phase = run.phase,
        x = run.coords.x, y = run.coords.y, z = run.coords.z, place = run.place,
        guards = #run.guards, alive = alive, alerted = run.alerted, keyFound = run.keyOwner ~= nil,
        crate = run.crate and NetworkGetNetworkIdFromEntity(run.crate) or nil,
        openTime = run.openTime, requireAllDead = run.requireAllDead, landAt = run.landAt,
        failed = run.failed or 0, revealAfter = run.revealAfter or 0, revealed = run.revealed == true,
        radius = S.blipRadius,
    }
end

-- Envoie la liste des drops à terre à ceux qui doivent les voir
local function broadcastLive()
    for _, p in ipairs(GetPlayers()) do
        local id = tonumber(p)
        local list = {}
        for _, run in pairs(Live) do
            if run.phase ~= 'announced' and concerned(id, run.audience) then
                local pub = publicLive(run)
                pub.mineKey = run.keyOwner == id
                list[#list + 1] = pub
            end
        end
        TriggerClientEvent('adminmenu:drops:live', id, list, { sprite = S.blipSprite, color = S.blipColor, radius = S.blipRadius, inspect = S.inspectTime, shot = S.shotRadius, approach = S.alertRadius })
    end
end

local function pickKeyHolder(run)
    local pool = {}
    local rule = run.keyHolder
    for i, g in ipairs(run.guards) do
        local ok = rule == 'random'
            or (rule == 'heavy' and g.heavy) or (rule == 'light' and not g.heavy)
            or (rule:match('^squad:(%d)$') and tonumber(rule:match('^squad:(%d)$')) == g.squad)
        if ok then pool[#pool + 1] = i end
    end
    if #pool == 0 then for i in ipairs(run.guards) do pool[#pool + 1] = i end end
    run.keyGuard = pool[math.random(#pool)]
end

local function spawnRun(run)
    local c = run.coords
    -- La caisse
    local crate = CreateObjectNoOffset(joaat(DC.crateModel or 'prop_drop_armscrate_01'), c.x, c.y, c.z, true, true, false)
    if waitEntity(crate) then
        FreezeEntityPosition(crate, true)
        Entity(crate).state:set('dropCrate', run.id, true)
        run.crate = crate
    end
    -- Abris (sacs de sable, barrières…) en cercle, face à l'extérieur
    run.props = {}
    local covers = DC.coverModels or {}
    if #covers > 0 then
        for i = 1, run.cover do
            local ang = (i / run.cover) * math.pi * 2 + 0.3
            local dist = run.radius * 0.5
            local x, y = c.x + math.cos(ang) * dist, c.y + math.sin(ang) * dist
            local obj = CreateObjectNoOffset(joaat(covers[(i - 1) % #covers + 1]), x, y, c.z, true, true, false)
            if waitEntity(obj) then
                SetEntityHeading(obj, math.deg(ang) + 90.0)
                FreezeEntityPosition(obj, true)
                Entity(obj).state:set('dropCover', run.id, true)
                run.props[#run.props + 1] = obj
            end
        end
    end
    -- Véhicules assortis au style des gardes, garés de travers : ils servent d'abri
    run.cars = {}
    if run.vehicles > 0 then
        local pool = {}
        for m in tostring(run.vehicleModels or ''):gmatch('[^,%s]+') do pool[#pool + 1] = m end
        if #pool == 0 then
            for _, q in ipairs(run.squads) do
                local style = MODELS[q.model]
                for _, v in ipairs(style and style.vehicles or {}) do pool[#pool + 1] = v end
            end
        end
        if #pool == 0 then pool = { 'granger', 'baller', 'cavalcade' } end
        for i = 1, run.vehicles do
            local ang = (i / run.vehicles) * math.pi * 2 + 0.9
            local dist = run.radius * 0.85
            local x, y = c.x + math.cos(ang) * dist, c.y + math.sin(ang) * dist
            local veh = CreateVehicleServerSetter(joaat(pool[(i - 1) % #pool + 1]), 'automobile', x, y, c.z + 0.6, math.deg(ang) + 180.0 + (math.random() - 0.5) * 30.0)
            if waitEntity(veh) then
                if run.lockVehicles then SetVehicleDoorsLocked(veh, 2) end
                Entity(veh).state:set('dropVehicle', { run = run.id, lock = run.lockVehicles }, true)
                run.cars[#run.cars + 1] = veh
            end
        end
    end
    -- Les gardes, en cercle irrégulier autour de la caisse
    local df = DIFF[run.difficulty] or DIFF.normal or { acc = 1, hp = 1, armor = 1, ability = 1, movement = 1, flank = false, crit = true, rate = 600 }
    local total = 0
    for _, q in ipairs(run.squads) do total = total + q.count end
    local n = 0
    for si, q in ipairs(run.squads) do
        for _ = 1, q.count do
            n = n + 1
            local ang = (n / math.max(1, total)) * math.pi * 2 + (math.random() - 0.5) * 0.6
            local dist = run.radius * (0.45 + math.random() * 0.55)
            local x, y = c.x + math.cos(ang) * dist, c.y + math.sin(ang) * dist
            local ped = CreatePed(4, joaat(q.model), x, y, c.z + 0.5, math.deg(ang) + 90.0, true, true)
            if waitEntity(ped) then
                GiveWeaponToPed(ped, joaat(q.weapon), 999, false, true)
                local armor = math.min(100, math.floor(q.armor * df.armor))
                if armor > 0 then SetPedArmour(ped, armor) end
                Entity(ped).state:set('dropGuard', { run = run.id, squad = si,
                    acc = math.min(100, math.floor(q.accuracy * df.acc)), hp = math.min(2000, math.floor(q.health * df.hp)), armor = armor,
                    ability = df.ability, movement = df.movement, flank = df.flank, crit = df.crit, rate = df.rate,
                    cx = c.x, cy = c.y, cz = c.z, r = run.radius + 10.0, weapon = q.weapon }, true)
                run.guards[#run.guards + 1] = { ent = ped, squad = si, heavy = q.heavy, searched = false }
            end
        end
    end
    pickKeyHolder(run)
end

local function endRun(run, message)
    if not Live[run.id] then return end
    Live[run.id] = nil
    deleteEntity(run.crate)
    for _, g in ipairs(run.guards) do deleteEntity(g.ent) end
    for _, o in ipairs(run.props or {}) do deleteEntity(o) end
    for _, v in ipairs(run.cars or {}) do deleteEntity(v) end
    if message and message ~= '' then announce(run.audience, 'DROP', message, 'info') end
    TriggerClientEvent('adminmenu:drops:ended', -1, run.id)
    broadcastLive()
end

-- ---------------------------------------------------------
--  Déroulé d'un drop
-- ---------------------------------------------------------
local function startRun(d, skipAnnounce)
    if not d.coords then return false, 'Ce drop n\'a pas de position.' end
    runSeq = runSeq + 1
    local run = {
        id = runSeq, plannedId = d.id, name = d.name, coords = d.coords, place = d.place,
        items = d.items, squads = d.squads, radius = d.radius, keyHolder = d.keyHolder,
        openTime = d.openTime, audience = d.audience, requireAllDead = d.requireAllDead,
        difficulty = d.difficulty or 'normal', vehicles = d.vehicles or 0, vehicleModels = d.vehicleModels or '',
        lockVehicles = d.lockVehicles ~= false, cover = d.cover or 0,
        revealAfter = d.revealAfter or 5, failed = 0, revealed = false,
        guards = {}, props = {}, cars = {}, phase = 'announced', alerted = false, startedAt = os.time(),
    }
    run.landAt = os.time() + (skipAnnounce and 0 or d.announceMinutes * 60)
    Live[run.id] = run
    if not skipAnnounce and d.announceMinutes > 0 then
        local msg = (S.preMessage or ''):gsub('{min}', tostring(d.announceMinutes))
        announce(run.audience, S.preTitle, msg, 'alert')
    end
    return true, run
end

local function landRun(run)
    run.phase = 'landed'
    spawnRun(run)
    announce(run.audience, S.landTitle, S.landMessage, 'alert')
    broadcastLive()
end

-- Planning : vérifié toutes les 15 secondes (heure réelle du serveur)
CreateThread(function()
    while true do
        Wait(15000)
        if S.enabled then
            local nowMin = nowMinutes()
            for _, d in ipairs(Store.list) do
                local at = minutesOf(d.time)
                if d.enabled and at and d.coords and d.lastRun ~= today() then
                    local announceAt = at   -- l'heure réglée est celle de l'annonce ; atterrissage X min après
                    local busy = false
                    for _, r in pairs(Live) do if r.plannedId == d.id then busy = true end end
                    if not busy and nowMin == announceAt then
                        d.lastRun = today()
                        if not d.repeatDaily then d.enabled = false end
                        save()
                        startRun(d, d.announceMinutes == 0)
                    end
                end
            end
        end
        -- Drops en cours : atterrissage, durée maximale, nettoyage
        for _, run in pairs(Live) do
            if run.phase == 'announced' and os.time() >= run.landAt then landRun(run)
            elseif run.phase == 'landed' and os.time() - run.landAt > S.maxDuration * 60 then endRun(run, 'Le drop a disparu : personne ne l\'a récupéré à temps.')
            elseif run.phase == 'opened' and os.time() - (run.openedAt or 0) > S.cleanupAfter * 60 then endRun(run) end
        end
    end
end)
-- Atterrissage précis à la seconde (la boucle ci-dessus passe toutes les 15 s)
CreateThread(function()
    while true do
        Wait(1000)
        for _, run in pairs(Live) do
            if run.phase == 'announced' and os.time() >= run.landAt then landRun(run) end
        end
    end
end)
-- Liste des drops à jour (gardes restants) toutes les 5 s pendant un drop
CreateThread(function()
    while true do
        Wait(5000)
        if next(Live) then broadcastLive() end
    end
end)

-- ---------------------------------------------------------
--  Joueurs : alerte, inspection, ouverture
-- ---------------------------------------------------------
local function runOfGuard(ent)
    for _, run in pairs(Live) do
        for i, g in ipairs(run.guards) do if g.ent == ent then return run, i, g end end
    end
end

RegisterNetEvent('adminmenu:drops:alert', function(runId)
    local src = source
    local run = Live[tonumber(runId) or 0]
    if not run or run.alerted or run.phase ~= 'landed' then return end
    if #(GetEntityCoords(GetPlayerPed(src)) - vector3(run.coords.x, run.coords.y, run.coords.z)) > 250.0 then return end
    run.alerted = true
    TriggerClientEvent('adminmenu:drops:alerted', -1, run.id)
    broadcastLive()
end)

local inspectStart = {}
RegisterNetEvent('adminmenu:drops:inspect', function(netId, phase)
    local src = source
    local ent = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    local run, idx, g = runOfGuard(ent)
    if not run then return TriggerClientEvent('adminmenu:notify', src, 'Il n\'y a rien d\'intéressant sur ce corps.', 'info') end
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(ent)) > 4.0 then return end
    if GetEntityHealth(ent) > 0 then return TriggerClientEvent('adminmenu:notify', src, 'Il est encore en vie !', 'error') end
    if phase == 'start' then inspectStart[src] = { ent = ent, at = GetGameTimer() } return end
    local st = inspectStart[src]
    inspectStart[src] = nil
    if not st or st.ent ~= ent or GetGameTimer() - st.at < (S.inspectTime * 1000) - 800 then return end
    if g.searched then return TriggerClientEvent('adminmenu:notify', src, 'Ce corps a déjà été fouillé.', 'info') end
    g.searched = true
    Entity(ent).state:set('dropSearched', true, true)
    if idx == run.keyGuard and not run.keyOwner then
        run.keyOwner = src
        Entity(ent).state:set('dropKeyHint', false, true)
        TriggerClientEvent('adminmenu:notify', src, ('🔑 Tu as trouvé : %s ! Va ouvrir la caisse.'):format(DC.keyLabel or 'Clé du drop'), 'success')
        AM.addLog(src, 'Drop : clé trouvée', ('%s (#%d)'):format(run.name, run.id))
    else
        run.failed = (run.failed or 0) + 1
        local left = (run.revealAfter or 0) - run.failed
        if (run.revealAfter or 0) > 0 and left <= 0 and not run.revealed then
            -- Trop de corps fouillés pour rien : le porteur de la clé est mis en surbrillance
            run.revealed = true
            local kg = run.guards[run.keyGuard]
            if kg and DoesEntityExist(kg.ent) then Entity(kg.ent).state:set('dropKeyHint', true, true) end
            TriggerClientEvent('adminmenu:notify', src, 'Rien sur ce corps… Mais la clé brille maintenant sur l\'un des gardes !', 'success')
            forAudience(run.audience, function(id)
                if id ~= src and #(GetEntityCoords(GetPlayerPed(id)) - vector3(run.coords.x, run.coords.y, run.coords.z)) < 250.0 then
                    TriggerClientEvent('adminmenu:notify', id, '🔑 La clé du drop brille sur l\'un des corps !', 'info')
                end
            end)
        elseif (run.revealAfter or 0) > 0 then
            TriggerClientEvent('adminmenu:notify', src, ('Rien sur ce corps… La clé est sur un autre garde (%d fouille%s avant qu\'elle se voie).'):format(left, left > 1 and 's' or ''), 'info')
        else
            TriggerClientEvent('adminmenu:notify', src, 'Rien sur ce corps… La clé est sur un autre garde.', 'info')
        end
    end
    broadcastLive()
end)

local function allDead(run)
    for _, g in ipairs(run.guards) do
        if DoesEntityExist(g.ent) and GetEntityHealth(g.ent) > 0 then return false end
    end
    return true
end

local function deliverLoot(src, run)
    local list = run.items or {}
    if GetResourceState('ox_inventory') == 'started' then
        local stashId = ('am_drop_%d_%d'):format(run.id, os.time())
        local ok = pcall(function()
            exports.ox_inventory:RegisterStash(stashId, ('Drop : %s'):format(run.name), 40, 2000000, false, nil, vector3(run.coords.x, run.coords.y, run.coords.z))
            for _, it in ipairs(list) do exports.ox_inventory:AddItem(stashId, it.item, it.count) end
        end)
        if ok then
            run.stash = stashId
            pcall(function() exports.ox_inventory:forceOpenInventory(src, 'stash', stashId) end)
            return
        end
    end
    -- Sans ox_inventory : directement dans l'inventaire de celui qui ouvre
    for _, it in ipairs(list) do Bridge.AddItem(src, it.item, it.count) end
    TriggerClientEvent('adminmenu:notify', src, 'Le contenu du drop est dans ton inventaire.', 'success')
end

local openStart = {}
RegisterNetEvent('adminmenu:drops:open', function(runId, phase)
    local src = source
    local run = Live[tonumber(runId) or 0]
    if not run or not run.crate then return end
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(run.crate)) > 4.0 then return end
    if run.phase == 'opened' then
        if run.stash then pcall(function() exports.ox_inventory:forceOpenInventory(src, 'stash', run.stash) end) end
        return
    end
    if run.keyOwner ~= src then return TriggerClientEvent('adminmenu:notify', src, 'La caisse est verrouillée : trouve la clé sur un des gardes.', 'error') end
    if run.requireAllDead and not allDead(run) then return TriggerClientEvent('adminmenu:notify', src, 'Des gardes sont encore en vie autour de la caisse !', 'error') end
    if phase == 'start' then
        openStart[src] = { run = run.id, at = GetGameTimer() }
        return TriggerClientEvent('adminmenu:drops:opening', src, run.id, run.openTime)
    end
    if phase == 'cancel' then openStart[src] = nil return end
    local st = openStart[src]
    openStart[src] = nil
    if not st or st.run ~= run.id or GetGameTimer() - st.at < (run.openTime * 1000) - 1000 then return end
    run.phase = 'opened'
    run.openedAt = os.time()
    AM.addLog(src, 'Drop ouvert', ('%s (#%d) · %d objet(s)'):format(run.name, run.id, #run.items))
    deliverLoot(src, run)
    announce(run.audience, 'DROP', S.endMessage, 'info')
    broadcastLive()
end)

RegisterNetEvent('adminmenu:drops:request', function() broadcastLive() end)
AddEventHandler('playerDropped', function()
    local src = source
    -- La clé n'est pas perdue : elle retourne sur le corps qui la portait
    for _, run in pairs(Live) do
        if run.keyOwner == src then
            run.keyOwner = nil
            local g = run.guards[run.keyGuard]
            if g then
                g.searched = false
                if DoesEntityExist(g.ent) then
                    Entity(g.ent).state:set('dropSearched', false, true)
                    if run.revealed then Entity(g.ent).state:set('dropKeyHint', true, true) end
                end
            end
        end
    end
end)
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, run in pairs(Live) do
        deleteEntity(run.crate)
        for _, g in ipairs(run.guards) do deleteEntity(g.ent) end
        for _, o in ipairs(run.props or {}) do deleteEntity(o) end
        for _, v in ipairs(run.cars or {}) do deleteEntity(v) end
    end
end)

-- ---------------------------------------------------------
--  Actions du staff
-- ---------------------------------------------------------
local function def(name, fn) A[name] = { perm = 'event_drops', noRefresh = true, fn = fn } end

def('drops_settings', function(src, d)
    S.enabled = bool(d.enabled, S.enabled)
    S.preTitle = text(d.preTitle or S.preTitle, 40)
    S.preMessage = text(d.preMessage or S.preMessage, 160)
    S.landTitle = text(d.landTitle or S.landTitle, 40)
    S.landMessage = text(d.landMessage or S.landMessage, 160)
    S.endMessage = text(d.endMessage or S.endMessage, 160)
    S.blipSprite = math.floor(num(d.blipSprite, 1, 900, S.blipSprite))
    S.blipColor = math.floor(num(d.blipColor, 0, 85, S.blipColor))
    S.blipRadius = math.floor(num(d.blipRadius, 0, 500, S.blipRadius))
    S.maxDuration = math.floor(num(d.maxDuration, 5, 240, S.maxDuration))
    S.cleanupAfter = math.floor(num(d.cleanupAfter, 1, 60, S.cleanupAfter))
    S.alertRadius = math.floor(num(d.alertRadius, 0, 100, S.alertRadius))
    S.shotRadius = math.floor(num(d.shotRadius, 0, 200, S.shotRadius))
    S.inspectTime = math.floor(num(d.inspectTime, 1, 30, S.inspectTime))
    S.illegalJobs = text(d.illegalJobs ~= nil and d.illegalJobs or S.illegalJobs, 200)
    if d.timezone == 'paris' or d.timezone == 'server' then S.timezone = d.timezone
    elseif tonumber(d.timezone) then S.timezone = tostring(math.floor(num(d.timezone, -12, 14, 0))) end
    save()
    AM.addLog(src, 'Drops : réglages', S.enabled and 'système activé' or 'système désactivé')
    AM.notify(src, 'Réglages des drops enregistrés.', 'success')
end)

def('drops_save', function(src, d)
    local i, cur = findPlanned(d.id)
    local drop = cleanDrop(d, cur)
    if not drop.coords then return AM.notify(src, 'Choisis la position du drop (carte ou ta position).', 'error') end
    if cur then
        drop.id = cur.id
        Store.list[i] = drop
    else
        drop.id = nextId(Store.list)
        Store.list[#Store.list + 1] = drop
    end
    table.sort(Store.list, function(a, b) return (minutesOf(a.time) or 0) < (minutesOf(b.time) or 0) end)
    save()
    local guards = 0
    for _, q in ipairs(drop.squads) do guards = guards + q.count end
    AM.addLog(src, cur and 'Drop modifié' or 'Drop planifié', ('%s à %s · %d gardes · %d objet(s)'):format(drop.name, drop.time, guards, #drop.items))
    AM.notify(src, ('%s planifié à %s.'):format(drop.name, drop.time), 'success')
end)

def('drops_delete', function(src, d)
    local i, cur = findPlanned(d.id)
    if not cur then return end
    table.remove(Store.list, i)
    save()
    AM.addLog(src, 'Drop supprimé', cur.name)
    AM.notify(src, ('%s supprimé du planning.'):format(cur.name), 'success')
end)

def('drops_toggle', function(src, d)
    local _, cur = findPlanned(d.id)
    if not cur then return end
    cur.enabled = d.enabled == true
    if cur.enabled then cur.lastRun = nil end
    save()
    AM.notify(src, ('%s %s.'):format(cur.name, cur.enabled and 'activé' or 'désactivé'), 'success')
end)

def('drops_run', function(src, d)
    local _, cur = findPlanned(d.id)
    if not cur then return end
    local ok, err = startRun(cur, d.now == true)
    if not ok then return AM.notify(src, err, 'error') end
    AM.addLog(src, 'Drop lancé à la main', ('%s (%s)'):format(cur.name, d.now and 'largage immédiat' or ('annonce ' .. cur.announceMinutes .. ' min avant')))
    AM.notify(src, d.now and ('%s largué maintenant.'):format(cur.name) or ('%s : annonce faite, il touchera le sol dans %d min.'):format(cur.name, cur.announceMinutes), 'success')
end)

def('drops_cancel', function(src, d)
    local run = Live[tonumber(d.run) or 0]
    if not run then return end
    endRun(run, d.silent and '' or 'Le drop a été annulé.')
    AM.addLog(src, 'Drop annulé', run.name)
    AM.notify(src, ('%s annulé, gardes et caisse retirés.'):format(run.name), 'success')
end)

def('drops_land', function(src, d)
    local run = Live[tonumber(d.run) or 0]
    if not run or run.phase ~= 'announced' then return end
    run.landAt = os.time()
    landRun(run)
    AM.notify(src, ('%s largué tout de suite.'):format(run.name), 'success')
end)

-- ---------------------------------------------------------
--  Données de l'onglet
-- ---------------------------------------------------------
table.insert(AM.DataHooks, function(src, data)
    if not AM.hasPerm(src, 'event_drops') then return end
    local live = {}
    for _, run in pairs(Live) do
        local p = publicLive(run)
        p.keyGuard = run.keyGuard
        live[#live + 1] = p
    end
    table.sort(live, function(a, b) return a.id < b.id end)
    data.drops = {
        settings = S, list = Store.list, live = live, now = os.time(), clock = clockNow(), tzLabel = tzLabel(),
        serverClock = os.date('%H:%M'),
        weapons = DC.weapons or {}, models = DC.models or {}, difficulties = DIFF,
    }
end)
