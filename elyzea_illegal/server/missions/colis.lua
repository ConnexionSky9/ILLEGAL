-- =========================================================
--  ELYZEA ILLÉGAL - MISSION « COLIS » (première mission : Colis test)
--
--  1. Emplacement tiré au hasard parmi ceux activés → GPS
--  2. Gardes (créés par le serveur, synchronisés pour tous les participants)
--  3. Fouille des gardes neutralisés (ALT) : l'un d'eux a la clé
--     (garde précis, garde au hasard ou probabilité ; toujours trouvable)
--  4. Ouverture du colis (animation, durée réglable) → nouveau GPS
--  5. Livraison au PNJ (ALT) → récompenses au coffre du groupe + XP
--  Le serveur vérifie chaque étape : participant, distance, durée,
--  garde réellement mort, clé réellement trouvée, porteur du colis.
-- =========================================================
local U = Illegal.Utils
local B, N, I = Missions.bool, Missions.num, Missions.int

local BEHAVIORS = { passive = true, wary = true, aggressive = true, very_aggressive = true }
local KEY_MODES = { specific = true, random = true, chance = true }

local function guard(model, weapon, behavior)
    return { model = model, weapon = weapon, health = 200, armor = 0, accuracy = 30, behavior = behavior,
        detect = 10.0, attack = 7.0, chase = 30.0, returnHome = true, canChase = true }
end

local function defaults(id)
    local D = Config.Missions.colisDefaults or {}
    return {
        general = { label = 'Colis test', description = 'Récupère un colis gardé, trouve la clé sur les gardes et livre-le.', enabled = true,
            levelRequired = 0, xp = 25, minPlayers = 1, maxPlayers = 4 },
        groups = { mode = 'all', list = {} },
        timer = { minutes = 15 },
        cooldown = { mission = 0, group = 30, player = 15 },
        phone = {
            sender = 'Numéro inconnu',
            start = 'Rappelle-toi que tu me dois un service ! Va me chercher un colis à cette emplacement, mais ne t’attends pas à être bien accueilli.',
            fail = 'Trop tard. Tu m\'as déçu, on en reparlera.',
            finish = 'Merci pour le service rendu !',
            levelup = 'Ton groupe passe niveau {level} ({label}). De nouvelles affaires vont s\'ouvrir.',
        },
        rewards = { money = { enabled = true, min = 5000, max = 8000, account = 'dirty' },
            items = { enabled = true, list = { { item = 'lockpick', min = 1, max = 3, chance = 100 } } } },
        weapons = { firearms = false, melee = true, explosives = false, vehicles = false, action = 'warn' },
        security = { participantRadius = 50.0, interactDistance = 2.5, failOnAllLeft = true },
        locations = { list = Missions.copy(D.locations or {}) },
        guards = { list = {
            guard('g_m_y_mexgoon_01', 'WEAPON_UNARMED', 'wary'), guard('g_m_y_mexgoon_02', 'WEAPON_UNARMED', 'wary'),
            guard('g_m_y_mexgoon_03', 'WEAPON_UNARMED', 'aggressive'), guard('g_m_y_mexgoon_01', 'WEAPON_UNARMED', 'aggressive'),
            guard('g_m_y_mexgang_01', 'WEAPON_KNIFE', 'very_aggressive'), guard('g_m_y_mexgang_01', 'WEAPON_KNIFE', 'very_aggressive'),
        } },
        crate = { model = 'prop_cs_cardbox_01', openSeconds = 8, animDict = 'mini@repair', animName = 'fixing_a_ped',
            keyMode = 'random', keyGuard = 1, keyChance = 35, revealAfter = 3, searchSeconds = 4, requireAllDead = false, keyLabel = 'Clé du colis' },
        delivery = { select = 'closest', deliverSeconds = 3, points = Missions.copy(D.deliveries or {}) },
    }
end

-- ---------------------------------------------------------
--  Configuration (admin) : sections propres à ce type
-- ---------------------------------------------------------
local function text(v, max, def) local t = U.text(v, max, true) if t == nil or t == '' then return def end return t end
local function ident(v, def) local t = U.text(v, 64, true) if t and t:match('^[%w_]+$') then return t end return def end
local function anim(v, def) local t = U.text(v, 80, true) if t == '' then return '' end if t and t:match('^[%w_@%.%-/]+$') then return t end return def end

local function sanitizeGuard(d, cur)
    cur = cur or guard('g_m_y_mexgoon_01', 'WEAPON_UNARMED', 'wary')
    local w = ident(d.weapon, cur.weapon):upper()
    if not w:match('^WEAPON_') then w = 'WEAPON_' .. w end
    return { model = ident(d.model, cur.model), weapon = w, health = I(d.health, 101, 2000, cur.health), armor = I(d.armor, 0, 100, cur.armor),
        accuracy = I(d.accuracy, 0, 100, cur.accuracy), behavior = BEHAVIORS[d.behavior] and d.behavior or cur.behavior,
        detect = N(d.detect, 1, 200, cur.detect), attack = N(d.attack, 1, 200, cur.attack), chase = N(d.chase, 1, 500, cur.chase),
        returnHome = B(d.returnHome, cur.returnHome), canChase = B(d.canChase, cur.canChase) }
end

local function sanitize(section, d, cur, cfg)
    if section == 'guards' then
        local list = {}
        for i, x in ipairs(type(d.list) == 'table' and d.list or {}) do
            if type(x) == 'table' and #list < 20 then list[#list + 1] = sanitizeGuard(x, cur.list[i]) end
        end
        return { list = list }
    elseif section == 'crate' then
        return { model = ident(d.model, cur.model), openSeconds = N(d.openSeconds, 1, 120, cur.openSeconds),
            animDict = anim(d.animDict, cur.animDict), animName = anim(d.animName, cur.animName),
            keyMode = KEY_MODES[d.keyMode] and d.keyMode or cur.keyMode, keyGuard = I(d.keyGuard, 1, 20, cur.keyGuard),
            keyChance = N(d.keyChance, 1, 100, cur.keyChance), revealAfter = I(d.revealAfter, 0, 20, cur.revealAfter),
            searchSeconds = N(d.searchSeconds, 1, 60, cur.searchSeconds), requireAllDead = B(d.requireAllDead, cur.requireAllDead),
            keyLabel = text(d.keyLabel, 40, cur.keyLabel) }
    elseif section == 'delivery' then
        return { select = d.select == 'random' and 'random' or 'closest', deliverSeconds = N(d.deliverSeconds, 1, 60, cur.deliverSeconds), points = cur.points }
    elseif section == 'locations' then
        return nil, 'Utilise les boutons de la liste des emplacements.'
    end
    return nil, 'Section inconnue.'
end

-- Points : emplacements du colis (avec positions des gardes) et points de livraison
local function newPoint(section, pos, d)
    if section == 'locations' then
        return { label = text(d.label, 64, 'Emplacement'), x = pos.x, y = pos.y, z = pos.z, h = pos.h, radius = N(d.radius, 5, 200, 30.0), enabled = true, guards = {} }
    end
    return { label = text(d.label, 64, 'Point de livraison'), x = pos.x, y = pos.y, z = pos.z, h = pos.h, enabled = true,
        ped = 'g_m_m_armboss_01', scenario = 'WORLD_HUMAN_SMOKING', animDict = 'mp_common', animName = 'givetake1_a',
        blipSprite = 478, blipColor = 5, distance = 2.0, text = 'Livrer le colis' }
end

local function sanitizePoint(section, cur, d, pos)
    local p = Missions.copy(cur)
    if pos then p.x, p.y, p.z, p.h = pos.x, pos.y, pos.z, pos.h end
    p.label = text(d.label, 64, p.label)
    p.enabled = B(d.enabled, p.enabled)
    if section == 'locations' then
        p.radius = N(d.radius, 5, 200, p.radius)
    else
        p.ped = ident(d.ped, p.ped)
        p.scenario = d.scenario ~= nil and ident(d.scenario, '') or p.scenario
        p.animDict, p.animName = anim(d.animDict, p.animDict), anim(d.animName, p.animName)
        p.blipSprite, p.blipColor = I(d.blipSprite, 1, 900, p.blipSprite), I(d.blipColor, 0, 85, p.blipColor)
        p.distance = N(d.distance, 1, 10, p.distance)
        p.text = text(d.text, 40, p.text)
    end
    return p
end

-- Positions des gardes d'un emplacement : ajout à la position du staff / effacer
local pointExtra = {
    guardAdd = function(p, pos)
        if not pos then return false, 'Position requise.' end
        if not p.guards then return false, 'Ce point n\'a pas de gardes.' end
        if #p.guards >= 20 then return false, 'Maximum 20 positions.' end
        p.guards[#p.guards + 1] = { x = pos.x, y = pos.y, z = pos.z, h = pos.h }
        return true
    end,
    guardClear = function(p)
        if not p.guards then return false, 'Ce point n\'a pas de gardes.' end
        p.guards = {}
        return true
    end,
}

-- ---------------------------------------------------------
--  Déroulé
-- ---------------------------------------------------------
local function waitEntity(e)
    local limit = GetGameTimer() + 2000
    while (not e or e == 0 or not DoesEntityExist(e)) and GetGameTimer() < limit do Wait(50) end
    return e and e ~= 0 and DoesEntityExist(e)
end

local function alive(ent) return ent and DoesEntityExist(ent) and GetEntityHealth(ent) > 0 end

local function dist(src, x, y, z)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return math.huge end
    return #(GetEntityCoords(ped) - vector3(x, y, z))
end

local function stageLabel(run)
    local s = run.state
    if s.stage == 'guards' then return 'Trouver la clé sur les gardes'
    elseif s.stage == 'crate' then return 'Ouvrir le colis'
    else return 'Livrer le colis' end
end

local function setStage(run, stage)
    run.state.stage = stage
    run.stageLabel = stageLabel(run)
end

local function notifyAll(run, msg, kind)
    for src in pairs(run.participants) do Players.notify(src, msg, kind) end
end

local function start(run)
    local cfg = run.cfg
    local pool = {}
    for _, l in ipairs(cfg.locations.list) do if l.enabled ~= false then pool[#pool + 1] = l end end
    if #pool == 0 then return false, 'Aucun emplacement de colis n\'est configuré : préviens le staff.' end
    local points = {}
    for _, p in ipairs(cfg.delivery.points) do if p.enabled ~= false then points[#points + 1] = p end end
    if #points == 0 then return false, 'Aucun point de livraison n\'est configuré : préviens le staff.' end

    local loc = pool[math.random(#pool)]
    run.state = { loc = loc, guards = {}, searched = 0, hasKey = false, searchStart = {}, openStart = {}, deliverStart = {} }
    run.entities = {}
    run.locationLabel = loc.label
    setStage(run, 'guards')

    -- Gardes : positions de l'emplacement, sinon en cercle autour du colis
    local n = #cfg.guards.list
    for i, gc in ipairs(cfg.guards.list) do
        local p = loc.guards and loc.guards[i]
        local x, y, z, h
        if p then x, y, z, h = p.x, p.y, p.z, p.h
        else
            local ang = (i / math.max(1, n)) * math.pi * 2
            local r = math.min(8.0, (loc.radius or 30) * 0.3)
            x, y, z, h = loc.x + math.cos(ang) * r, loc.y + math.sin(ang) * r, loc.z, math.deg(ang) + 90.0
        end
        local ped = CreatePed(4, joaat(gc.model), x, y, z + 0.5, h, true, true)
        if waitEntity(ped) then
            if gc.weapon ~= 'WEAPON_UNARMED' then GiveWeaponToPed(ped, joaat(gc.weapon), 999, false, true) end
            if gc.armor > 0 then SetPedArmour(ped, gc.armor) end
            Entity(ped).state:set('illegalGuard', { run = run.id, i = i, model = gc.model, weapon = gc.weapon, health = gc.health,
                accuracy = gc.accuracy, behavior = gc.behavior, detect = gc.detect, attack = gc.attack, chase = gc.chase,
                returnHome = gc.returnHome, canChase = gc.canChase, hx = x, hy = y, hz = z, hh = h }, true)
            run.state.guards[#run.state.guards + 1] = { ent = ped, i = i, searched = false }
            run.entities[ped] = #run.state.guards
        end
    end
    local count = #run.state.guards
    -- Porteur de la clé (modes « garde précis » et « au hasard »)
    local c = cfg.crate
    if count == 0 then
        run.state.hasKey = true          -- aucun garde n'a pu apparaître : la mission n'est jamais bloquée
        setStage(run, 'crate')
    elseif c.keyMode == 'specific' then
        run.state.keyGuard = math.min(c.keyGuard, count)
    elseif c.keyMode == 'random' then
        run.state.keyGuard = math.random(count)
    end
    run.state.alive = count
    return true
end

-- La clé est-elle sur ce garde ? Toujours trouvable : dernier garde fouillé, ou porteur disparu.
local function rollKey(run, idx)
    local s, c = run.state, run.cfg.crate
    local remaining = 0
    for _, g in ipairs(s.guards) do if not g.searched then remaining = remaining + 1 end end
    if remaining == 0 then return true end
    if c.keyMode == 'chance' then return math.random() * 100 < c.keyChance end
    if idx == s.keyGuard then return true end
    local kg = s.guards[s.keyGuard]
    if kg and not kg.searched and not DoesEntityExist(kg.ent) then return true end   -- corps disparu : la clé passe à ce garde
    return false
end

local actions = {}

-- Fouiller un garde neutralisé (phase 'start' puis 'done' après la durée)
actions.search = function(run, src, netId, phase)
    local s = run.state
    local ent = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    local idx = ent and run.entities[ent]
    if not idx then return end
    local g = s.guards[idx]
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(ent)) > run.cfg.security.interactDistance + 1.5 then return end
    if alive(ent) then return Players.notify(src, 'Il est encore debout !', 'error') end
    if g.searched then return Players.notify(src, 'Ce garde a déjà été fouillé.', 'info') end
    if phase == 'start' then s.searchStart[src] = { ent = ent, at = GetGameTimer() } return end
    local st = s.searchStart[src]
    s.searchStart[src] = nil
    if not st or st.ent ~= ent or GetGameTimer() - st.at < run.cfg.crate.searchSeconds * 1000 - 800 then return end
    g.searched = true
    s.searched = s.searched + 1
    Entity(ent).state:set('illegalSearched', true, true)
    if s.hasKey then return Players.notify(src, 'Rien d\'intéressant.', 'info') end
    if rollKey(run, idx) then
        s.hasKey, s.keyFinder = true, run.names[src]
        setStage(run, 'crate')
        local kg = s.guards[s.keyGuard or 0]
        if kg and DoesEntityExist(kg.ent) then Entity(kg.ent).state:set('illegalKeyHint', false, true) end
        Log({ src = src, name = run.names[src] }, run.groupId, 'Mission : clé trouvée', ('%s · %s'):format(run.cfg.general.label, run.names[src]))
        notifyAll(run, ('🔑 %s a trouvé : %s. Ouvrez le colis !'):format(run.names[src], run.cfg.crate.keyLabel), 'success')
        Missions.push(run)
    else
        s.failed = (s.failed or 0) + 1
        local rv = run.cfg.crate.revealAfter
        if rv > 0 and s.failed >= rv and s.keyGuard and not s.revealed then
            s.revealed = true
            local kg = s.guards[s.keyGuard]
            if kg and DoesEntityExist(kg.ent) then Entity(kg.ent).state:set('illegalKeyHint', true, true) end
            notifyAll(run, 'Rien sur ce corps… mais la clé brille maintenant sur l\'un des gardes.', 'info')
        else
            Players.notify(src, 'Rien sur ce corps. La clé est sur un autre garde.', 'info')
        end
    end
end

local function allDead(run)
    for _, g in ipairs(run.state.guards) do if alive(g.ent) then return false end end
    return true
end

-- Point de livraison : le plus proche du lancement (ou au hasard)
local function pickDelivery(run)
    local list = {}
    for _, p in ipairs(run.cfg.delivery.points) do if p.enabled ~= false then list[#list + 1] = p end end
    if run.cfg.delivery.select == 'random' then return list[math.random(#list)] end
    local best, bd
    for _, p in ipairs(list) do
        local d = #(vector3(p.x, p.y, p.z) - vector3(run.startPos.x, run.startPos.y, run.startPos.z))
        if not bd or d < bd then best, bd = p, d end
    end
    return best
end

-- Ouvrir le colis (clé trouvée) : 'start' → animation → 'done'
actions.open = function(run, src, phase)
    local s, c = run.state, run.cfg.crate
    if s.stage == 'deliver' then return end
    if dist(src, s.loc.x, s.loc.y, s.loc.z) > run.cfg.security.interactDistance + 2.5 then return end
    if not s.hasKey then return Players.notify(src, 'Le colis est verrouillé : trouve la clé sur les gardes.', 'error') end
    if c.requireAllDead and not allDead(run) then return Players.notify(src, 'Des gardes sont encore debout !', 'error') end
    if phase == 'start' then
        s.openStart[src] = GetGameTimer()
        return TriggerClientEvent('illegal:client:missionProgress', src, run.id, 'open', c.openSeconds)
    end
    if phase == 'cancel' then s.openStart[src] = nil return end
    local t = s.openStart[src]
    s.openStart[src] = nil
    if not t or GetGameTimer() - t < c.openSeconds * 1000 - 1000 then return end
    s.carrier = run.participants[src]
    s.delivery = pickDelivery(run)
    setStage(run, 'deliver')
    Log({ src = src, name = run.names[src] }, run.groupId, 'Mission : colis récupéré', ('%s · %s · livraison : %s'):format(run.cfg.general.label, run.names[src], s.delivery.label))
    notifyAll(run, ('📦 %s a récupéré le colis. Direction le point de livraison !'):format(run.names[src]), 'success')
    Missions.push(run)
end

-- Livrer le colis (seul le porteur) : 'start' → animation → 'done' → mission réussie
actions.deliver = function(run, src, phase)
    local s = run.state
    if s.stage ~= 'deliver' or not s.delivery then return end
    if s.carrier ~= run.participants[src] then return Players.notify(src, 'C\'est ton coéquipier qui porte le colis.', 'error') end
    local p = s.delivery
    if dist(src, p.x, p.y, p.z) > p.distance + 2.0 then return end
    if phase == 'start' then s.deliverStart[src] = GetGameTimer() return end
    local t = s.deliverStart[src]
    s.deliverStart[src] = nil
    if not t or GetGameTimer() - t < run.cfg.delivery.deliverSeconds * 1000 - 800 then return end
    Log({ src = src, name = run.names[src] }, run.groupId, 'Mission : colis livré', ('%s · %s'):format(run.cfg.general.label, run.names[src]))
    Missions.complete(run, src)
end

-- Véhicule dans la zone (signalé par le client : ne peut que pénaliser)
actions.vehicle = function(run, src) Missions.violation(run, src, 'vehicles') end

-- Le porteur du colis part : le colis passe à un autre participant
local function onLeave(run, src, cid)
    local s = run.state
    if s.carrier and s.carrier == cid then
        local nextSrc = next(run.participants)
        if nextSrc then
            s.carrier = run.participants[nextSrc]
            notifyAll(run, ('Le colis passe à %s.'):format(run.names[nextSrc]), 'info')
        end
    end
end

-- Chaque seconde : gardes encore debout (affichage)
local function tick(run)
    local n = 0
    for _, g in ipairs(run.state.guards) do if alive(g.ent) then n = n + 1 end end
    if n ~= run.state.alive then
        run.state.alive = n
        Missions.push(run)
    end
end

local function cleanup(run)
    for _, g in ipairs((run.state and run.state.guards) or {}) do
        if g.ent and DoesEntityExist(g.ent) then DeleteEntity(g.ent) end
    end
    run.entities = {}
end

local function payload(run, src, base)
    local s, c = run.state, run.cfg.crate
    base.stage = s.stage
    base.stageLabel = run.stageLabel
    base.alive = s.alive
    base.total = #s.guards
    base.searchSeconds = c.searchSeconds
    base.hasKey = s.hasKey
    base.keyFinder = s.keyFinder
    base.keyLabel = c.keyLabel
    base.location = { x = s.loc.x, y = s.loc.y, z = s.loc.z, radius = s.loc.radius or 30, label = s.loc.label }
    base.crate = { model = c.model, openSeconds = c.openSeconds, animDict = c.animDict, animName = c.animName, requireAllDead = c.requireAllDead }
    if s.stage == 'deliver' and s.delivery then
        local p = s.delivery
        base.delivery = { x = p.x, y = p.y, z = p.z, h = p.h, ped = p.ped, scenario = p.scenario, animDict = p.animDict, animName = p.animName,
            blipSprite = p.blipSprite, blipColor = p.blipColor, distance = p.distance, text = p.text, label = p.label,
            seconds = run.cfg.delivery.deliverSeconds }
        base.carrier = s.carrier == run.participants[src]
        for s2, cid in pairs(run.participants) do if cid == s.carrier then base.carrierName = run.names[s2] end end
    end
end

Missions.registerType('colis', {
    label = 'Colis',
    defaults = defaults,
    sanitize = sanitize,
    pointLists = { locations = 'list', delivery = 'points' },
    newPoint = newPoint,
    sanitizePoint = sanitizePoint,
    pointExtra = pointExtra,
    start = start,
    actions = actions,
    onLeave = onLeave,
    tick = tick,
    cleanup = cleanup,
    payload = payload,
})
Missions.registerDefault('colis_test', 'colis')
