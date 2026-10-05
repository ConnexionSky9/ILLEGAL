-- =========================================================
--  ELYZEA ILLÉGAL - MISSIONS : MOTEUR COMMUN
--
--  Une mission = un « type » (code : server/missions/<type>.lua)
--  + une configuration (base de données, modifiée dans
--  admin_menu › ILLEGAL › Missions). Le moteur gère tout ce qui est
--  commun à toutes les missions :
--    niveaux / XP des groupes, groupes autorisés, cooldowns,
--    participants, timer, récompenses (coffre du groupe), téléphone,
--    restrictions d'armes, logs, historique.
--  Le type ne gère que son déroulé (objectifs) : voir colis.lua.
--
--  Ajouter une mission : créer server/missions/<type>.lua avec
--    Missions.registerType('<type>', { defaults, sanitize, start, actions, payload, cleanup, ... })
--    Missions.registerDefault('<id>', '<type>')
--  et son pendant client client/missions/<type>.lua.
--
--  SÉCURITÉ : le client ne choisit jamais son groupe, l'emplacement,
--  la récompense, l'XP, ni la validation. Il ne fait qu'annoncer
--  « je fouille / j'ouvre / je livre » ; le serveur vérifie tout
--  (participant, groupe, étape, distance, durée, état des gardes).
-- =========================================================
Missions = {
    types = {},          -- [type] = définition
    defaults = {},       -- [missionId] = type (missions créées automatiquement)
    configs = {},        -- [missionId] = configuration
    runs = {},           -- [runId] = mission en cours
    byGroup = {},        -- [groupId] = runId
    byPlayer = {},       -- [src] = runId
    levels = nil,
    cd = { mission = {}, group = {}, player = {} },   -- dernière fin (os.time)
    ready = false,
}
Progress = {}
local U = Illegal.Utils
local runSeq = 0

-- ---------------------------------------------------------
--  Outils
-- ---------------------------------------------------------
local function copy(t)
    if type(t) ~= 'table' then return t end
    local o = {}
    for k, v in pairs(t) do o[k] = copy(v) end
    return o
end
Missions.copy = copy

-- Complète une config enregistrée avec les valeurs par défaut (nouveaux réglages après une mise à jour)
local function fill(dst, src)
    for k, v in pairs(src) do
        if dst[k] == nil then dst[k] = copy(v)
        elseif type(v) == 'table' and type(dst[k]) == 'table' and v[1] == nil and next(v) ~= nil then fill(dst[k], v) end
    end
    return dst
end

local function bool(v, def) if v == nil then return def end return v == true or v == 1 or v == '1' or v == 'true' end
-- Nombre : valeur invalide → valeur actuelle ; hors limites → ramené dans les limites
local function num(v, min, max, def)
    local n = tonumber(v)
    if not n or n ~= n or n == math.huge or n == -math.huge then return def end
    return math.max(min, math.min(max, n)) + 0.0
end
local function int(v, min, max, def)
    local n = tonumber(v)
    if not n or n ~= n or n == math.huge or n == -math.huge then return def end
    return math.max(min, math.min(max, math.floor(n)))
end
Missions.bool, Missions.num, Missions.int = bool, num, int

function Missions.registerType(key, def) Missions.types[key] = def end
function Missions.registerDefault(id, typ) Missions.defaults[id] = typ end

local function phone(src, cfg, msg, vars)
    if not src or not msg or msg == '' then return end
    msg = tostring(msg):gsub('{(%w+)}', function(k) return vars and vars[k] ~= nil and tostring(vars[k]) or '{' .. k .. '}' end)
    TriggerClientEvent('illegal:client:phone', src, (cfg and cfg.phone and cfg.phone.sender) or 'Numéro inconnu', msg)
end
Missions.phone = phone

local function participantsOf(run)
    local list = {}
    for src in pairs(run.participants) do list[#list + 1] = src end
    return list
end
Missions.participantsOf = participantsOf

local function names(run)
    local list = {}
    for _, n in pairs(run.names) do list[#list + 1] = n end
    table.sort(list)
    return list
end

-- =========================================================
--  NIVEAUX DES GROUPES
--  levels[i] = { label, xp } : niveau i-1, « xp » = XP à gagner pour l'atteindre
--  depuis le niveau précédent. L'XP du groupe repart à 0 à chaque niveau.
-- =========================================================
function Progress.get(g)
    g.progress = g.progress or { level = 0, xp = 0 }
    return g.progress
end

function Progress.maxLevel() return #Missions.levels - 1 end

function Progress.need(level)
    local nxt = Missions.levels[level + 2]
    return nxt and nxt.xp or nil
end

function Progress.label(level)
    local l = Missions.levels[level + 1]
    return l and l.label or ('Niveau ' .. level)
end

function Progress.info(g)
    local p = Progress.get(g)
    return { level = p.level, xp = p.xp, need = Progress.need(p.level), label = Progress.label(p.level),
        nextLabel = Progress.need(p.level) and Progress.label(p.level + 1) or nil, max = Progress.maxLevel() }
end

local function normalize(p)
    local max = Progress.maxLevel()
    if p.level > max then p.level = max end
    if p.level < 0 then p.level = 0 end
    local gained = 0
    while p.level < max do
        local need = Progress.need(p.level)
        if not need or p.xp < need then break end
        p.xp = p.xp - need
        p.level = p.level + 1
        gained = gained + 1
    end
    if p.xp < 0 then p.xp = 0 end
    return gained
end

-- Applique une nouvelle progression : base, logs, tablettes, message de level-up
local function commit(actor, g, old, reason, cfg)
    local p = Progress.get(g)
    DB.saveProgress(g.id, p.level, p.xp)
    Log(actor, g.id, 'Progression', ('%s : niveau %d → %d · XP %d → %d%s'):format(g.label, old.level, p.level, old.xp, p.xp,
        reason and reason ~= '' and (' · ' .. reason) or ''))
    if p.level > old.level then
        Log(actor, g.id, 'Niveau supérieur', ('%s passe niveau %d (%s)'):format(g.label, p.level, Progress.label(p.level)))
        local msg = (cfg and cfg.phone and cfg.phone.levelup) or Config.Missions.levelUpMessage
        for cid in pairs(g.members) do
            local src = Players.bySrcCid(cid)
            if src then phone(src, cfg, msg, { level = p.level, label = Progress.label(p.level), group = g.label }) end
        end
    end
    Sync.group(g.id)
end

-- op : add | remove | setXp | setLevel | reset
function Progress.change(actor, g, op, value, reason, cfg)
    local p = Progress.get(g)
    local old = { level = p.level, xp = p.xp }
    if op == 'reset' then p.level, p.xp = 0, 0
    else
        local v = U.int(value, 0, 100000000)
        if not v then return false, 'Valeur invalide.' end
        if op == 'add' then p.xp = p.xp + v
        elseif op == 'remove' then p.xp = math.max(0, p.xp - v)
        elseif op == 'setXp' then p.xp = v
        elseif op == 'setLevel' then
            if v > Progress.maxLevel() then return false, ('Niveau maximum : %d.'):format(Progress.maxLevel()) end
            p.level, p.xp = v, 0
        else return false, 'Opération inconnue.' end
    end
    normalize(p)
    commit(actor, g, old, reason, cfg)
    return true, ('%s : niveau %d · %d XP'):format(g.label, p.level, p.xp)
end

-- Paliers (admin) : liste { label, xp } ; le premier est toujours à 0 XP
function Progress.saveLevels(actor, list)
    if type(list) ~= 'table' or #list == 0 then return false, 'Il faut au moins un niveau.' end
    if #list > 100 then return false, 'Maximum 100 niveaux.' end
    local out = {}
    for i, l in ipairs(list) do
        if type(l) ~= 'table' then return false, 'Niveau invalide.' end
        local xp = i == 1 and 0 or U.int(l.xp, 1, 100000000)
        if not xp then return false, ('XP invalide pour le niveau %d.'):format(i - 1) end
        out[i] = { label = U.text(l.label, 40) or ('Niveau ' .. (i - 1)), xp = xp }
    end
    if DB.saveSetting('levels', out) == nil then return false, 'Erreur de la base de données.' end
    Missions.levels = out
    -- Groupes au-delà du nouveau maximum : ramenés au dernier niveau
    for _, g in pairs(Cache.groups) do
        local p = Progress.get(g)
        local old = { level = p.level, xp = p.xp }
        normalize(p)
        if p.level ~= old.level or p.xp ~= old.xp then DB.saveProgress(g.id, p.level, p.xp) end
        Sync.group(g.id)
    end
    Log(actor, nil, 'Niveaux modifiés', ('%d niveau(x) : %s'):format(#out, table.concat((function()
        local t = {} for i, l in ipairs(out) do t[#t + 1] = ('%d=%s (%d XP)'):format(i - 1, l.label, l.xp) end return t end)(), ', ')))
    return true, 'Niveaux enregistrés.'
end

-- =========================================================
--  CONFIGURATION DES MISSIONS
-- =========================================================
local COMMON = { general = true, groups = true, timer = true, cooldown = true, phone = true, rewards = true, weapons = true, security = true }
local ACCOUNTS = { clean = true, dirty = true }
local WEAPON_ACTIONS = { none = true, warn = true, fail = true }

local function sanitizeCommon(section, d, cur)
    if section == 'general' then
        local label = U.text(d.label, 64)
        if not label then return nil, 'Donne un nom à la mission.' end
        local minP = int(d.minPlayers, 1, 16, cur.minPlayers)
        local maxP = int(d.maxPlayers, 1, 16, cur.maxPlayers)
        if minP > maxP then return nil, 'Le nombre minimum de joueurs dépasse le maximum.' end
        return { label = label, description = U.text(d.description, 300, true), enabled = bool(d.enabled, cur.enabled),
            levelRequired = int(d.levelRequired, 0, 100, cur.levelRequired), xp = int(d.xp, 0, 1000000, cur.xp),
            minPlayers = minP, maxPlayers = maxP }
    elseif section == 'groups' then
        local list = {}
        for _, n in ipairs(type(d.list) == 'table' and d.list or {}) do
            local name = U.ident(n)
            if name and #list < 200 then list[#list + 1] = name end
        end
        return { mode = d.mode == 'list' and 'list' or 'all', list = list }
    elseif section == 'timer' then
        return { minutes = num(d.minutes, 1, 180, cur.minutes) }
    elseif section == 'cooldown' then
        return { mission = num(d.mission, 0, 10080, cur.mission), group = num(d.group, 0, 10080, cur.group), player = num(d.player, 0, 10080, cur.player) }
    elseif section == 'phone' then
        return { sender = U.text(d.sender, 40) or cur.sender, start = U.text(d.start, 400, true), fail = U.text(d.fail, 400, true),
            finish = U.text(d.finish, 400, true), levelup = U.text(d.levelup, 400, true) }
    elseif section == 'rewards' then
        local m = type(d.money) == 'table' and d.money or {}
        local mmin, mmax = int(m.min, 0, Config.MaxAmount, cur.money.min), int(m.max, 0, Config.MaxAmount, cur.money.max)
        if mmin > mmax then return nil, 'Argent : le minimum dépasse le maximum.' end
        local items = {}
        local it = type(d.items) == 'table' and d.items or {}
        for _, x in ipairs(type(it.list) == 'table' and it.list or {}) do
            local name = U.text(x.item, 64, true)
            if name ~= '' then
                if not name:match('^[%w_]+$') then return nil, ('Nom d\'objet invalide : %s'):format(name) end
                local qmin, qmax = int(x.min, 1, 10000, 1), int(x.max, 1, 10000, 1)
                if qmin > qmax then return nil, ('%s : quantité minimum supérieure au maximum.'):format(name) end
                if #items < 50 then items[#items + 1] = { item = name, min = qmin, max = qmax, chance = num(x.chance, 0, 100, 100) } end
            end
        end
        return { money = { enabled = bool(m.enabled, cur.money.enabled), min = mmin, max = mmax, account = ACCOUNTS[m.account] and m.account or cur.money.account },
            items = { enabled = bool(it.enabled, cur.items.enabled), list = items } }
    elseif section == 'weapons' then
        return { firearms = bool(d.firearms, cur.firearms), melee = bool(d.melee, cur.melee), explosives = bool(d.explosives, cur.explosives),
            vehicles = bool(d.vehicles, cur.vehicles), action = WEAPON_ACTIONS[d.action] and d.action or cur.action }
    elseif section == 'security' then
        return { participantRadius = num(d.participantRadius, 5, 1000, cur.participantRadius),
            interactDistance = num(d.interactDistance, 1, 10, cur.interactDistance),
            failOnAllLeft = bool(d.failOnAllLeft, cur.failOnAllLeft) }
    end
    return nil, 'Section inconnue.'
end

function Missions.saveSection(actor, missionId, section, data)
    local cfg = Missions.configs[missionId]
    if not cfg then return false, 'Mission introuvable.' end
    local def = Missions.types[cfg.type]
    if type(section) ~= 'string' or type(data) ~= 'table' then return false, 'Données invalides.' end
    local value, err
    if COMMON[section] then value, err = sanitizeCommon(section, data, cfg[section])
    elseif def.sanitize then value, err = def.sanitize(section, data, cfg[section], cfg)
    else return false, 'Section inconnue.' end
    if not value then return false, err or 'Données invalides.' end
    cfg[section] = value
    if DB.saveMission(missionId, cfg.type, cfg) == nil then return false, 'Erreur de la base de données.' end
    Log(actor, nil, 'Mission modifiée', ('%s › %s'):format(cfg.general.label, section))
    for gid in pairs(Cache.groups) do Sync.group(gid) end
    return true, 'Mission enregistrée.'
end

-- Listes de points (emplacements, livraison…) : ajout à la position du staff, modification, suppression
function Missions.pointOp(actor, missionId, section, op, index, data)
    local cfg = Missions.configs[missionId]
    if not cfg then return false, 'Mission introuvable.' end
    local def = Missions.types[cfg.type]
    local field = def.pointLists and def.pointLists[section]
    if not field then return false, 'Liste inconnue.' end
    local list = cfg[section][field]
    data = type(data) == 'table' and data or {}
    local i = U.int(index, 1, #list)
    local pos
    if data.useMyPosition then
        pos = Groups.positionOf(actor.src)
        if not pos then return false, 'Position introuvable.' end
    elseif data.x ~= nil then
        pos = U.coords(data)
        if not pos then return false, 'Coordonnées invalides.' end
    end

    if op == 'add' then
        if not pos then return false, 'Position requise.' end
        if #list >= 50 then return false, 'Maximum 50 points.' end
        local p = def.newPoint(section, pos, data, cfg)
        list[#list + 1] = p
    elseif op == 'update' then
        if not i then return false, 'Point introuvable.' end
        local p, err = def.sanitizePoint(section, list[i], data, pos, cfg)
        if not p then return false, err end
        list[i] = p
    elseif op == 'delete' then
        if not i then return false, 'Point introuvable.' end
        table.remove(list, i)
    elseif def.pointExtra and def.pointExtra[op] then
        if not i then return false, 'Point introuvable.' end
        local ok, err = def.pointExtra[op](list[i], pos, data, cfg)
        if not ok then return false, err end
    else
        return false, 'Opération inconnue.'
    end
    if DB.saveMission(missionId, cfg.type, cfg) == nil then return false, 'Erreur de la base de données.' end
    Log(actor, nil, 'Mission modifiée', ('%s › %s : %s%s'):format(cfg.general.label, section, op, i and (' #' .. i) or ''))
    return true, 'Enregistré.'
end

-- =========================================================
--  CONDITIONS : groupe autorisé, niveau, cooldowns
-- =========================================================
function Missions.groupAllowed(cfg, g)
    if cfg.groups.mode ~= 'list' then return true end
    for _, n in ipairs(cfg.groups.list) do if n == g.name then return true end end
    return false
end

local function left(t, minutes) if not t or minutes <= 0 then return 0 end return math.max(0, math.floor(t + minutes * 60 - os.time())) end

function Missions.cooldownLeft(id, cfg, g, cid)
    local c = cfg.cooldown
    local m = left(Missions.cd.mission[id], c.mission)
    local gr = g and left(Missions.cd.group[id .. ':' .. g.id], c.group) or 0
    local p = cid and left(Missions.cd.player[id .. ':' .. cid], c.player) or 0
    return math.max(m, gr, p), { mission = m, group = gr, player = p }
end

local function fmtTime(s)
    if s >= 3600 then return ('%dh%02d'):format(s // 3600, (s % 3600) // 60) end
    return ('%d min %02d s'):format(s // 60, s % 60)
end
Missions.fmtTime = fmtTime

-- Pourquoi ce groupe / joueur ne peut pas lancer cette mission (nil = il peut)
function Missions.blocker(id, cfg, g, cid)
    if not cfg.general.enabled then return 'Mission désactivée.' end
    if not Missions.types[cfg.type] then return 'Type de mission indisponible.' end
    if not Missions.groupAllowed(cfg, g) then return 'Ton groupe n\'a pas accès à cette mission.' end
    local p = Progress.get(g)
    if p.level < cfg.general.levelRequired then
        return ('Mission verrouillée : niveau %d requis (ton groupe : niveau %d).'):format(cfg.general.levelRequired, p.level)
    end
    if Missions.byGroup[g.id] then return 'Ton groupe a déjà une mission en cours.' end
    local wait, parts = Missions.cooldownLeft(id, cfg, g, cid)
    if wait > 0 then
        local who = parts.player == wait and 'Tu dois' or parts.group == wait and 'Ton groupe doit' or 'Cette mission doit'
        return ('%s attendre encore %s.'):format(who, fmtTime(wait))
    end
    return nil
end

-- =========================================================
--  DÉROULÉ D'UNE MISSION
-- =========================================================
function Missions.payload(run, src)
    local def = Missions.types[run.type]
    local base = {
        runId = run.id, missionId = run.missionId, type = run.type, label = run.cfg.general.label, group = run.groupLabel,
        remaining = math.max(0, run.deadline - os.time()), participants = names(run),
        weapons = run.cfg.weapons, interactDistance = run.cfg.security.interactDistance,
    }
    if def.payload then def.payload(run, src, base) end
    return base
end

function Missions.push(run, only)
    for _, src in ipairs(only and { only } or participantsOf(run)) do
        TriggerClientEvent('illegal:client:mission', src, Missions.payload(run, src))
    end
end

local ticking = false
local function ensureTicker()
    if ticking then return end
    ticking = true
    CreateThread(function()
        while next(Missions.runs) do
            Wait(1000)
            local now = os.time()
            for _, run in pairs(Missions.runs) do
                if now >= run.deadline then
                    Missions.finish(run, 'failed', 'Temps écoulé')
                else
                    local def = Missions.types[run.type]
                    if def.tick then def.tick(run) end
                end
            end
        end
        ticking = false
    end)
end

-- Lancement depuis la tablette (ctx = joueur, groupe et grade relus par le serveur)
function Missions.start(ctx, missionId)
    local cfg = Missions.configs[missionId]
    if not cfg then return false, 'Mission introuvable.' end
    local g = ctx.group
    if Missions.byPlayer[ctx.src] then return false, 'Tu participes déjà à une mission.' end
    local why = Missions.blocker(missionId, cfg, g, ctx.cid)
    if why then return false, why end

    -- Participants : le lanceur + les membres du groupe proches de lui (sans mission ni cooldown)
    local center = Groups.positionOf(ctx.src)
    if not center then return false, 'Position introuvable.' end
    local parts, list = { [ctx.src] = ctx.cid }, { ctx.cid }
    local count = 1
    for cid in pairs(g.members) do
        if count >= cfg.general.maxPlayers then break end
        local src = Players.bySrcCid(cid)
        if src and src ~= ctx.src and not Missions.byPlayer[src] then
            local pos = Groups.positionOf(src)
            if pos and #(vector3(pos.x, pos.y, pos.z) - vector3(center.x, center.y, center.z)) <= cfg.security.participantRadius
                and left(Missions.cd.player[missionId .. ':' .. cid], cfg.cooldown.player) == 0 then
                parts[src] = cid
                list[#list + 1] = cid
                count = count + 1
            end
        end
    end
    if count < cfg.general.minPlayers then
        return false, ('Il faut au moins %d membre(s) du groupe à moins de %d m de toi (%d trouvé(s)).')
            :format(cfg.general.minPlayers, math.floor(cfg.security.participantRadius), count)
    end

    runSeq = runSeq + 1
    local run = {
        id = runSeq, missionId = missionId, type = cfg.type, cfg = copy(cfg), groupId = g.id, groupLabel = g.label,
        starterSrc = ctx.src, starterCid = ctx.cid, participants = parts, names = {}, startPos = center,
        deadline = os.time() + math.floor(cfg.timer.minutes * 60), startedAt = os.time(), state = {},
    }
    for src in pairs(parts) do run.names[src] = Players.charName(src) end
    local def = Missions.types[cfg.type]
    local ok, err = def.start(run)
    if not ok then
        if def.cleanup then def.cleanup(run) end
        return false, err or 'Impossible de lancer la mission.'
    end
    run.participantList = list
    run.dbId = DB.insertRun(run)
    Missions.runs[run.id] = run
    Missions.byGroup[g.id] = run.id
    for src in pairs(parts) do Missions.byPlayer[src] = run.id end

    for src in pairs(parts) do phone(src, run.cfg, run.cfg.phone.start, { group = g.label }) end
    Missions.push(run)
    Log(ctx, g.id, 'Mission lancée', ('%s · %s par %s · participants : %s · emplacement : %s'):format(cfg.general.label, g.label, ctx.name,
        table.concat(names(run), ', '), run.locationLabel or '?'))
    Sync.group(g.id)
    ensureTicker()
    return true, ('Mission « %s » lancée (%d participant%s).'):format(cfg.general.label, count, count > 1 and 's' or '')
end

-- Rejoindre la mission en cours de son groupe
function Missions.join(ctx)
    local run = Missions.runs[Missions.byGroup[ctx.group.id] or -1]
    if not run then return false, 'Aucune mission en cours dans ton groupe.' end
    if Missions.byPlayer[ctx.src] then return false, 'Tu participes déjà à une mission.' end
    local n = 0
    for _ in pairs(run.participants) do n = n + 1 end
    if n >= run.cfg.general.maxPlayers then return false, 'La mission est complète.' end
    if left(Missions.cd.player[run.missionId .. ':' .. ctx.cid], run.cfg.cooldown.player) > 0 then return false, 'Tu es encore en cooldown pour cette mission.' end
    run.participants[ctx.src] = ctx.cid
    run.names[ctx.src] = ctx.name
    run.participantList[#run.participantList + 1] = ctx.cid
    Missions.byPlayer[ctx.src] = run.id
    Missions.push(run)
    Log(ctx, run.groupId, 'Mission rejointe', ('%s rejoint « %s »'):format(ctx.name, run.cfg.general.label))
    Sync.group(run.groupId)
    return true, ('Tu rejoins la mission « %s ».'):format(run.cfg.general.label)
end

function Missions.abandon(ctx)
    local run = Missions.runs[Missions.byGroup[ctx.group.id] or -1]
    if not run then return false, 'Aucune mission en cours.' end
    if run.starterCid ~= ctx.cid and not ctx.grade.boss then return false, 'Seul celui qui a lancé la mission (ou le chef) peut l\'abandonner.' end
    Missions.finish(run, 'failed', ('Abandonnée par %s'):format(ctx.name))
    return true, 'Mission abandonnée.'
end

-- Un participant part (déconnexion, changement de personnage, exclusion du groupe)
function Missions.leave(src, why)
    local run = Missions.runs[Missions.byPlayer[src] or -1]
    Missions.byPlayer[src] = nil
    if not run then return end
    local cid = run.participants[src]
    run.participants[src] = nil
    run.names[src] = nil
    local def = Missions.types[run.type]
    if def.onLeave then def.onLeave(run, src, cid) end
    TriggerClientEvent('illegal:client:missionEnd', src, { runId = run.id, success = false, message = why or 'Tu as quitté la mission.' })
    if not next(run.participants) then
        Missions.finish(run, 'failed', 'Plus aucun participant')
    else
        Missions.push(run)
        Sync.group(run.groupId)
    end
end

-- Fin (réussite ou échec) : nettoyage complet, cooldowns, historique
function Missions.finish(run, status, reason, reward)
    if run.ended then return end
    run.ended = true
    local def = Missions.types[run.type]
    if def.cleanup then pcall(def.cleanup, run) end
    Missions.runs[run.id] = nil
    if Missions.byGroup[run.groupId] == run.id then Missions.byGroup[run.groupId] = nil end
    local now = os.time()
    Missions.cd.mission[run.missionId] = now
    Missions.cd.group[run.missionId .. ':' .. run.groupId] = now
    for _, cid in ipairs(run.participantList or {}) do Missions.cd.player[run.missionId .. ':' .. cid] = now end
    local success = status == 'success'
    for src in pairs(run.participants) do
        Missions.byPlayer[src] = nil
        if not success then phone(src, run.cfg, run.cfg.phone.fail) end
        TriggerClientEvent('illegal:client:missionEnd', src, { runId = run.id, success = success,
            message = success and 'MISSION TERMINÉE' or ('MISSION ÉCHOUÉE' .. (reason and (' : ' .. reason) or '')) })
    end
    if run.dbId then DB.endRun(run.dbId, status, reward, success and run.cfg.general.xp or 0, run.participantList) end
    Log({ name = 'Système' }, run.groupId, success and 'Mission terminée' or 'Mission échouée', ('%s · %s%s'):format(run.cfg.general.label, run.groupLabel,
        reason and (' · ' .. reason) or ''))
    Sync.group(run.groupId)
end

-- Objectif final validé par le type de mission (serveur) : récompenses au coffre du groupe + XP
function Missions.complete(run, src)
    if run.ended then return end
    local g = Cache.group(run.groupId)
    local cfg = run.cfg
    local actor = { src = src, name = run.names[src] or 'Mission', cid = run.participants[src] }
    local reward = { money = 0, items = {} }
    if g then
        local m = cfg.rewards.money
        if m.enabled and m.max > 0 then
            local amount = math.random(m.min, m.max)
            if amount > 0 then
                local ok = Finances.missionReward(actor, g, m.account, amount, ('Mission : %s'):format(cfg.general.label))
                if ok then
                    reward.money, reward.account = amount, m.account
                    Log(actor, g.id, 'Récompense : argent', ('%s d\'%s ajoutés au coffre de %s (%s)'):format(U.money(amount),
                        Illegal.Accounts[m.account]:lower(), g.label, cfg.general.label))
                end
            end
        end
        if cfg.rewards.items.enabled then
            for _, it in ipairs(cfg.rewards.items.list) do
                if math.random() * 100 < it.chance then
                    local count = math.random(it.min, it.max)
                    local ok = Stashes and Stashes.addItem(g, it.item, count)
                    if ok then reward.items[#reward.items + 1] = { item = it.item, count = count } end
                    Log(actor, g.id, ok and 'Récompense : objets' or 'Récompense : objets non ajoutés', ('%dx %s %s le coffre de %s'):format(count, it.item,
                        ok and 'dans' or 'impossible à mettre dans (coffre plein ou ox_inventory absent)', g.label))
                end
            end
        end
        if cfg.general.xp > 0 then
            Progress.change(actor, g, 'add', cfg.general.xp, ('Mission %s (+%d XP)'):format(cfg.general.label, cfg.general.xp), cfg)
            Log(actor, g.id, 'Récompense : XP', ('+%d XP pour %s'):format(cfg.general.xp, g.label))
        end
    end
    for s in pairs(run.participants) do phone(s, cfg, cfg.phone.finish) end
    Missions.finish(run, 'success', nil, reward)
end

-- Arrêt par le staff
function Missions.stop(actor, runId)
    local run = Missions.runs[U.int(runId, 1) or -1]
    if not run then return false, 'Mission introuvable.' end
    Missions.finish(run, 'failed', ('Arrêtée par le staff (%s)'):format(actor.name))
    return true, 'Mission arrêtée.'
end

function Missions.onGroupDeleted(groupId)
    local run = Missions.runs[Missions.byGroup[groupId] or -1]
    if run then Missions.finish(run, 'failed', 'Groupe supprimé') end
end

-- =========================================================
--  RESTRICTIONS D'ARMES (dégâts sur les gardes : contrôlés par le serveur)
-- =========================================================
local function hashSet(list)
    local s = {}
    for _, n in ipairs(list) do s[GetHashKey(n) % 4294967296] = true end
    return s
end
local MELEE = hashSet({ 'WEAPON_KNIFE', 'WEAPON_NIGHTSTICK', 'WEAPON_HAMMER', 'WEAPON_BAT', 'WEAPON_GOLFCLUB', 'WEAPON_CROWBAR', 'WEAPON_BOTTLE',
    'WEAPON_DAGGER', 'WEAPON_HATCHET', 'WEAPON_KNUCKLE', 'WEAPON_MACHETE', 'WEAPON_SWITCHBLADE', 'WEAPON_WRENCH', 'WEAPON_BATTLEAXE',
    'WEAPON_POOLCUE', 'WEAPON_STONE_HATCHET', 'WEAPON_FLASHLIGHT' })
local EXPLOSIVE = hashSet({ 'WEAPON_GRENADE', 'WEAPON_STICKYBOMB', 'WEAPON_PROXMINE', 'WEAPON_PIPEBOMB', 'WEAPON_MOLOTOV', 'WEAPON_RPG',
    'WEAPON_GRENADELAUNCHER', 'WEAPON_HOMINGLAUNCHER', 'WEAPON_COMPACTLAUNCHER', 'WEAPON_EXPLOSION', 'WEAPON_FIREWORK', 'WEAPON_RAILGUN' })
local VEHICLE = hashSet({ 'WEAPON_RUN_OVER_BY_CAR', 'WEAPON_RAMMED_BY_CAR', 'VEHICLE_WEAPON_ROTORS' })
local UNARMED = hashSet({ 'WEAPON_UNARMED', 'WEAPON_FALL' })

function Missions.weaponKind(hash)
    hash = (tonumber(hash) or 0) % 4294967296
    if UNARMED[hash] then return 'unarmed' end
    if MELEE[hash] then return 'melee' end
    if EXPLOSIVE[hash] then return 'explosives' end
    if VEHICLE[hash] then return 'vehicles' end
    return 'firearms'
end

local KIND_LABEL = { melee = 'arme blanche', firearms = 'arme à feu', explosives = 'explosif', vehicles = 'véhicule' }
local warned = {}
function Missions.violation(run, src, kind)
    local w = run.cfg.weapons
    if kind == 'unarmed' or w[kind] ~= false or w.action == 'none' then return end
    if w.action == 'fail' then
        Log({ src = src, name = run.names[src] or '?' }, run.groupId, 'Mission : arme interdite', ('%s · %s'):format(run.cfg.general.label, KIND_LABEL[kind]))
        return Missions.finish(run, 'failed', ('%s interdit(e) utilisé(e)'):format(KIND_LABEL[kind]))
    end
    local key = src .. ':' .. kind
    if warned[key] and GetGameTimer() - warned[key] < 10000 then return end
    warned[key] = GetGameTimer()
    Players.notify(src, ('Avertissement : %s interdit(e) pour cette mission.'):format(KIND_LABEL[kind]), 'warning')
end

-- Entité → mission en cours (gardes)
function Missions.runOfEntity(ent)
    for _, run in pairs(Missions.runs) do
        if run.entities and run.entities[ent] then return run, run.entities[ent] end
    end
end

AddEventHandler('weaponDamageEvent', function(sender, data)
    if not next(Missions.runs) or type(data) ~= 'table' then return end
    local src = tonumber(sender)
    local ids = data.hitGlobalIds or { data.hitGlobalId }
    for _, netId in ipairs(ids) do
        local ent = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
        local run = ent and ent ~= 0 and Missions.runOfEntity(ent)
        if run and run.participants[src] then Missions.violation(run, src, Missions.weaponKind(data.weaponType)) end
    end
end)

-- =========================================================
--  ACTIONS DES PARTICIPANTS (fouille, ouverture, livraison…)
-- =========================================================
RegisterNetEvent('illegal:mission:action', function(runId, name, a, b)
    local src = source
    if not Players.rateLimit(src, 'mission', 10, 2000) then return end
    local run = Missions.runs[U.int(runId, 1) or -1]
    if not run or run.ended or type(name) ~= 'string' then return end
    local cid = run.participants[src]
    -- Participant réel, toujours le même personnage, toujours dans le groupe de la mission
    if not cid or Players.cid(src) ~= cid or Cache.memberOf[cid] ~= run.groupId then
        print(('^1[ILLEGAL] %s [%d] : action de mission « %s » refusée (pas participant).^7'):format(GetPlayerName(src) or '?', src, name))
        return
    end
    local def = Missions.types[run.type]
    local fn = def.actions and def.actions[name]
    if not fn then return end
    fn(run, src, a, b)
end)

AddEventHandler('playerDropped', function() Missions.leave(source, 'Déconnexion') end)
AddEventHandler('QBCore:Server:OnPlayerUnload', function(src) if tonumber(src) then Missions.leave(tonumber(src), 'Changement de personnage') end end)

-- Reconnexion de la ressource cliente : renvoi de l'état
RegisterNetEvent('illegal:mission:resync', function()
    local src = source
    if not Players.rateLimit(src, 'mresync', 2, 5000) then return end
    local run = Missions.runs[Missions.byPlayer[src] or -1]
    if run then Missions.push(run, src) end
end)

-- =========================================================
--  DONNÉES : tablette du groupe et menu staff
-- =========================================================
function Missions.tabletData(ctx)
    local g = ctx.group
    local list = {}
    for id, cfg in pairs(Missions.configs) do
        if cfg.general.enabled and Missions.types[cfg.type] and Missions.groupAllowed(cfg, g) then
            local p = Progress.get(g)
            local wait = Missions.cooldownLeft(id, cfg, g, ctx.cid)
            list[#list + 1] = {
                id = id, label = cfg.general.label, description = cfg.general.description, levelRequired = cfg.general.levelRequired,
                xp = cfg.general.xp, minPlayers = cfg.general.minPlayers, maxPlayers = cfg.general.maxPlayers, minutes = cfg.timer.minutes,
                money = cfg.rewards.money.enabled and { min = cfg.rewards.money.min, max = cfg.rewards.money.max, account = cfg.rewards.money.account } or nil,
                items = cfg.rewards.items.enabled and #cfg.rewards.items.list or 0,
                locked = p.level < cfg.general.levelRequired, cooldown = wait,
            }
        end
    end
    table.sort(list, function(a, b) if a.levelRequired ~= b.levelRequired then return a.levelRequired < b.levelRequired end return a.label < b.label end)
    local active
    local run = Missions.runs[Missions.byGroup[g.id] or -1]
    if run then
        active = { runId = run.id, label = run.cfg.general.label, remaining = math.max(0, run.deadline - os.time()), participants = names(run),
            stage = run.stageLabel or '', mine = run.participants[ctx.src] ~= nil, starter = run.starterCid == ctx.cid }
    end
    return { progress = Progress.info(g), list = list, active = active, canStart = Cache.hasPerm(ctx.grade, 'missions_start'), boss = ctx.grade.boss }
end

function Missions.adminData()
    local list = {}
    for id, cfg in pairs(Missions.configs) do
        local c = copy(cfg)
        c.id = id
        c.typeLabel = Missions.types[cfg.type] and Missions.types[cfg.type].label or cfg.type
        list[#list + 1] = c
    end
    table.sort(list, function(a, b) return a.general.levelRequired < b.general.levelRequired or (a.general.levelRequired == b.general.levelRequired and a.id < b.id) end)
    local active = {}
    for _, run in pairs(Missions.runs) do
        active[#active + 1] = { runId = run.id, missionId = run.missionId, label = run.cfg.general.label, group = run.groupLabel,
            remaining = math.max(0, run.deadline - os.time()), participants = names(run), stage = run.stageLabel or '', location = run.locationLabel }
    end
    local groups = {}
    for _, g in pairs(Cache.groups) do
        local info = Progress.info(g)
        info.id, info.name, info.groupLabel = g.id, g.name, g.label
        groups[#groups + 1] = info
    end
    table.sort(groups, function(a, b) return a.groupLabel:lower() < b.groupLabel:lower() end)
    return { levels = Missions.levels, list = list, active = active, groups = groups,
        behaviors = Config.Missions.behaviors, weaponActions = Config.Missions.weaponActions }
end

-- =========================================================
--  CHARGEMENT
-- =========================================================
function Missions.load()
    DB.closeStaleRuns()
    local d = DB.loadMissions()
    Missions.levels = nil
    for _, s in ipairs(d.settings) do
        if s.name == 'levels' then
            local ok, v = pcall(json.decode, s.value)
            if ok and type(v) == 'table' and #v > 0 then Missions.levels = v end
        end
    end
    Missions.levels = Missions.levels or copy(Config.Missions.levels)
    for _, r in ipairs(d.progress) do
        local g = Cache.groups[r.id]
        if g then g.progress = { level = tonumber(r.mission_level) or 0, xp = tonumber(r.mission_xp) or 0 } end
    end
    Missions.configs = {}
    for _, r in ipairs(d.missions) do
        local def = Missions.types[r.type]
        local ok, cfg = pcall(json.decode, r.config)
        if def and ok and type(cfg) == 'table' then
            cfg.type = r.type
            Missions.configs[r.id] = fill(cfg, def.defaults(r.id))
        end
    end
    for id, typ in pairs(Missions.defaults) do
        if not Missions.configs[id] and Missions.types[typ] then
            local cfg = Missions.types[typ].defaults(id)
            cfg.type = typ
            Missions.configs[id] = cfg
            DB.saveMission(id, typ, cfg)
        end
    end
    for _, r in ipairs(d.runs) do
        local t = tonumber(r.ended) or 0
        if t > (Missions.cd.mission[r.mission_id] or 0) then Missions.cd.mission[r.mission_id] = t end
        local gk = r.mission_id .. ':' .. r.group_id
        if t > (Missions.cd.group[gk] or 0) then Missions.cd.group[gk] = t end
        local ok, parts = pcall(json.decode, r.participants or '[]')
        for _, cid in ipairs(ok and type(parts) == 'table' and parts or {}) do
            local pk = r.mission_id .. ':' .. cid
            if t > (Missions.cd.player[pk] or 0) then Missions.cd.player[pk] = t end
        end
    end
    Missions.ready = true
    local n = 0
    for _ in pairs(Missions.configs) do n = n + 1 end
    print(('^2[ILLEGAL] %d mission(s) chargée(s), %d niveau(x).^7'):format(n, #Missions.levels))
end
