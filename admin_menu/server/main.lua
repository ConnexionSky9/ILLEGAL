-- =========================================================
--  ADMIN MENU - SERVEUR
--  Toutes les permissions sont vérifiées ici : le client ne
--  peut rien faire sans l'accord du serveur.
-- =========================================================

local function deepcopy(t)
    if type(t) ~= 'table' then return t end
    local r = {}
    for k, v in pairs(t) do r[k] = deepcopy(v) end
    return r
end

local function toSet(list)
    local s = {}
    if type(list) ~= 'table' then return s end
    if list[1] ~= nil then
        for _, v in ipairs(list) do s[v] = true end
    else
        for k, v in pairs(list) do if v == true then s[k] = true end end
    end
    return s
end

-- ---------------------------------------------------------
--  Données
-- ---------------------------------------------------------
local Ranks = Storage.load('ranks', {})
if next(Ranks) == nil then Ranks = deepcopy(Config.DefaultRanks) end
for _, r in pairs(Ranks) do r.perms = toSet(r.perms) end

if not Ranks[Config.OwnerRank] then
    Ranks[Config.OwnerRank] = deepcopy(Config.DefaultRanks[Config.OwnerRank])
end
do
    local owner = Ranks[Config.OwnerRank]
    owner.locked = true
    owner.perms = {}
    for _, p in ipairs(Config.Permissions) do owner.perms[p.key] = true end
end
-- Migration : ajoute les nouvelles permissions aux grades déjà sauvegardés (une seule fois)
do
    local meta = Storage.load('meta', {})
    if not meta.v12 then
        local add = {
            administrateur = { 'wallhack' },
            superadmin = { 'wallhack', 'editor_spawns', 'editor_props', 'editor_peds', 'editor_harvest' },
        }
        for rank, perms in pairs(add) do
            if Ranks[rank] then for _, p in ipairs(perms) do Ranks[rank].perms[p] = true end end
        end
        meta.v12 = true
        Storage.save('meta', meta)
    end
    if not meta.v19 then
        if Ranks.superadmin then Ranks.superadmin.perms.transform = true end
        meta.v19 = true
        Storage.save('meta', meta)
    end
    if not meta.v18 then
        for _, r in ipairs({ 'moderateur', 'administrateur', 'superadmin' }) do
            if Ranks[r] then Ranks[r].perms.jail = true end
        end
        if Ranks.superadmin then Ranks.superadmin.perms.editor_doors = true end
        meta.v18 = true
        Storage.save('meta', meta)
    end
    if not meta.v17 then
        for _, r in ipairs({ 'administrateur', 'superadmin' }) do
            if Ranks[r] then Ranks[r].perms.armor = true end
        end
        meta.v17 = true
        Storage.save('meta', meta)
    end
    if not meta.v16 then
        if Ranks.superadmin then Ranks.superadmin.perms.editor_zones = true end
        meta.v16 = true
        Storage.save('meta', meta)
    end
    if not meta.v15 then
        if Ranks.superadmin then Ranks.superadmin.perms.give_item = true end
        meta.v15 = true
        Storage.save('meta', meta)
    end
    if not meta.v14 then
        local add = { moderateur = { 'revive' }, administrateur = { 'revive', 'revive_area' }, superadmin = { 'revive', 'revive_area' } }
        for rank, perms in pairs(add) do
            if Ranks[rank] then for _, p in ipairs(perms) do Ranks[rank].perms[p] = true end end
        end
        meta.v14 = true
        Storage.save('meta', meta)
    end
    if not meta.v22 then
        -- Messages privés et discussion staff : pour tous les grades qui gèrent les reports
        for _, r in pairs(Ranks) do
            if r.perms and r.perms.reports then r.perms.staff_pm = true r.perms.staff_chat = true end
        end
        meta.v22 = true
        Storage.save('meta', meta)
    end
    if not meta.v21 then
        if Ranks.superadmin then Ranks.superadmin.perms.event_zombies = true end
        meta.v21 = true
        Storage.save('meta', meta)
    end
    if not meta.v20 then
        -- Onglet Événements › GoFast
        if Ranks.superadmin then
            Ranks.superadmin.perms.gofast_manage = true
            Ranks.superadmin.perms.gofast_missions = true
        end
        if Ranks.administrateur then Ranks.administrateur.perms.gofast_missions = true end
        meta.v20 = true
        Storage.save('meta', meta)
    end
    if not meta.v13 then
        if Ranks.superadmin then Ranks.superadmin.perms.editor_crafting = true end
        meta.v13 = true
        Storage.save('meta', meta)
    end
    if not meta.v29 then
        -- Métiers > Concession : SuperAdmin (le Fondateur a toujours tout)
        if Ranks.superadmin then Ranks.superadmin.perms.concess_staff = true end
        meta.v29 = true
        Storage.save('meta', meta)
    end
    if not meta.v28 then
        -- Onglet Carte : SuperAdmin (le Fondateur a toujours tout)
        if Ranks.superadmin then Ranks.superadmin.perms.manage_map = true end
        meta.v28 = true
        Storage.save('meta', meta)
    end
    if not meta.v27 then
        -- Métiers > LsCustom : donné au SuperAdmin (le Fondateur a toujours tout)
        if Ranks.superadmin then Ranks.superadmin.perms.lscustom_staff = true end
        meta.v27 = true
        Storage.save('meta', meta)
    end
    if not meta.v26 then
        -- Tablette staff Police : donnée au SuperAdmin (le Fondateur a toujours tout)
        if Ranks.superadmin then Ranks.superadmin.perms.police_staff = true end
        meta.v26 = true
        Storage.save('meta', meta)
    end
    if not meta.v25 then
        if Ranks.superadmin then Ranks.superadmin.perms.event_drops = true end
        meta.v25 = true
        Storage.save('meta', meta)
    end
    if not meta.v24 then
        if Ranks.superadmin then Ranks.superadmin.perms.editor_stashes = true end
        meta.v24 = true
        Storage.save('meta', meta)
    end
    if not meta.v23 then
        -- Tablette staff EMS : donnée au SuperAdmin (le Fondateur a toujours tout)
        if Ranks.superadmin then Ranks.superadmin.perms.ems_staff = true end
        meta.v23 = true
        Storage.save('meta', meta)
    end
end
Storage.save('ranks', Ranks)

local Admins = Storage.load('admins', {})   -- [license] = { rank, name }
local Bans   = Storage.load('bans', {})     -- liste
local Warns  = Storage.load('warns', {})    -- [license] = { {reason, by, date} }

local Reports, Logs, Frozen, SpecBucket, ReportCooldown, Wallhack = {}, {}, {}, {}, {}, {}
local reportCounter = 0

local World = {
    weather  = Config.World.defaultWeather,
    hour     = Config.World.startHour,
    minute   = 0,
    freeze   = false,
    blackout = false,
}

-- ---------------------------------------------------------
--  Utilitaires joueurs / grades
-- ---------------------------------------------------------
-- Licences mises en cache (évite de relire les identifiants à chaque vérification)
local LicenseCache = {}
local function getLicense(src)
    src = tonumber(src)
    local c = src and LicenseCache[src]
    if c then return c end
    for _, id in ipairs(GetPlayerIdentifiers(src) or {}) do
        if id:sub(1, 8) == 'license:' then
            if src and src < 65535 then LicenseCache[src] = id end
            return id
        end
    end
end

-- Anti-spam : n actions max par fenêtre de temps et par joueur
local RateBuckets = {}
local function rateLimit(src, key, max, windowMs)
    local now = GetGameTimer()
    local b = RateBuckets[src]
    if not b then b = {} RateBuckets[src] = b end
    local e = b[key]
    if not e or now - e.t > windowMs then e = { t = now, n = 0 } b[key] = e end
    e.n = e.n + 1
    return e.n <= max
end

-- Fondateurs : config.lua (Config.Owners) ET le menu lui-même (data/owners.json).
-- Le fichier data/ n'est jamais écrasé par une mise à jour du menu.
local Owners = Storage.load('owners', {})
local function isOwner(lic)
    if not lic then return false end
    for _, o in ipairs(Config.Owners or {}) do if o == lic then return true end end
    for _, o in ipairs(Owners) do if o == lic then return true end end
    return false
end

-- Grade venant des ACE de server.cfg (mis en cache 30 s par joueur)
local AceCache = {}
local function aceRank(src)
    if not Config.AceRanks or #Config.AceRanks == 0 then return nil end
    local c = AceCache[src]
    if c and GetGameTimer() - c.t < 30000 then return c.rank end
    local best, bestLevel = nil, -1
    for _, a in ipairs(Config.AceRanks) do
        local r = Ranks[a.rank]
        if r and r.level > bestLevel and IsPlayerAceAllowed(tostring(src), a.ace) then best, bestLevel = a.rank, r.level end
    end
    AceCache[src] = { t = GetGameTimer(), rank = best }
    return best
end

local function getRankName(src)
    src = tonumber(src)
    if src == 0 then return Config.OwnerRank end
    local lic = getLicense(src)
    if not lic then return nil end
    if isOwner(lic) then return Config.OwnerRank end
    local a = Admins[lic]
    local fromFile = a and Ranks[a.rank] and a.rank or nil
    local fromAce = aceRank(src)
    if fromFile and fromAce then
        return Ranks[fromAce].level > Ranks[fromFile].level and fromAce or fromFile
    end
    return fromFile or fromAce
end

local function getLevel(src)
    src = tonumber(src)
    if src == 0 then return 99999 end
    local r = getRankName(src)
    return (r and Ranks[r]) and Ranks[r].level or 0
end

local function hasPerm(src, perm)
    src = tonumber(src)
    if src == 0 then return true end
    local r = getRankName(src)
    return r ~= nil and Ranks[r] ~= nil and Ranks[r].perms[perm] == true
end

local function pname(src)
    src = tonumber(src)
    if src == 0 then return 'Console' end
    return GetPlayerName(src) or ('#' .. tostring(src))
end

local function isOnline(id)
    return id ~= nil and GetPlayerName(id) ~= nil
end

local function notify(src, msg, typ)
    if tonumber(src) == 0 then print('[AdminMenu] ' .. msg) return end
    TriggerClientEvent('adminmenu:notify', src, msg, typ or 'info')
end

-- ---------------------------------------------------------
--  Logs
-- ---------------------------------------------------------
local function addLog(src, action, details)
    local entry = {
        time    = os.date('%d/%m %H:%M:%S'),
        admin   = pname(src),
        action  = action,
        details = details or '',
    }
    table.insert(Logs, 1, entry)
    if #Logs > 300 then table.remove(Logs) end
    print(('^3[AdminMenu]^7 %s | %s | %s'):format(entry.admin, action, entry.details))

    if Config.DiscordWebhook ~= '' then
        PerformHttpRequest(Config.DiscordWebhook, function() end, 'POST', json.encode({
            username = 'Logs Staff',
            embeds = { {
                title = action,
                description = ('**Staff :** %s\n%s'):format(entry.admin, entry.details),
                color = 15905076,
                footer = { text = entry.time },
            } },
        }), { ['Content-Type'] = 'application/json' })
    end
end

-- ---------------------------------------------------------
--  Synchronisation des permissions vers les clients
-- ---------------------------------------------------------
local function pushPerms(id)
    id = tonumber(id)
    local r = getRankName(id)
    TriggerClientEvent('adminmenu:setPerms', id, r, r and Ranks[r].perms or {}, r and Ranks[r].level or 0)
end

local function pushPermsAll()
    for _, p in ipairs(GetPlayers()) do pushPerms(p) end
end

-- Service staff : false = mode RP (fonctions staff coupées). Inconnu = en service.
local Duty = {}
local function onDuty(src) return Duty[tonumber(src)] ~= false end

local function staffOnline(perm)
    local list = {}
    for _, p in ipairs(GetPlayers()) do
        local id = tonumber(p)
        if hasPerm(id, perm) and onDuty(id) then list[#list + 1] = id end -- pas d'alertes en mode RP
    end
    return list
end

-- ---------------------------------------------------------
--  Bans
-- ---------------------------------------------------------
local function purgeBans()
    local now, changed = os.time(), false
    for i = #Bans, 1, -1 do
        local b = Bans[i]
        if b.expires and b.expires > 0 and b.expires <= now then
            table.remove(Bans, i)
            changed = true
        end
    end
    if changed then Storage.save('bans', Bans) end
end

local function getTokens(src)
    local t = {}
    for i = 0, (GetNumPlayerTokens(src) or 0) - 1 do t[#t + 1] = GetPlayerToken(src, i) end
    return t
end

local function findBan(identifiers, tokens)
    purgeBans()
    local set = {}
    for _, id in ipairs(identifiers or {}) do
        if id:sub(1, 3) ~= 'ip:' then set[id] = true end -- pas d'IP : évite de bannir une box entière
    end
    for _, tk in ipairs(tokens or {}) do set[tk] = true end
    for _, b in ipairs(Bans) do
        for _, id in ipairs(b.identifiers or {}) do if set[id] then return b end end
        for _, tk in ipairs(b.tokens or {}) do if set[tk] then return b end end
    end
end

local function formatExpire(b)
    if not b.expires or b.expires == 0 then return 'Permanent' end
    return os.date('%d/%m/%Y à %H:%M', b.expires)
end

local function banMessage(b)
    return ('\n🚫 Vous êtes banni de ce serveur.\n\nRaison : %s\nPar : %s\nExpiration : %s\nID du ban : #%d')
        :format(b.reason, b.by, formatExpire(b), b.id)
end

local function nextBanId()
    local max = 0
    for _, b in ipairs(Bans) do if (b.id or 0) > max then max = b.id end end
    return max + 1
end

AddEventHandler('playerConnecting', function(_, _, deferrals)
    local src = source
    deferrals.defer()
    Wait(0)
    deferrals.update('Vérification du statut de bannissement…')
    local ban = findBan(GetPlayerIdentifiers(src), getTokens(src))
    if ban then deferrals.done(banMessage(ban)) else deferrals.done() end
end)

AddEventHandler('playerJoining', function()
    local src = source
    local lic = getLicense(src)
    if lic and Admins[lic] then
        Admins[lic].name = GetPlayerName(src)
        Storage.saveLater('admins', Admins)
    end
    TriggerClientEvent('adminmenu:syncWorld', src, World)
end)

AddEventHandler('playerDropped', function()
    local src = source
    Frozen[src] = nil
    SpecBucket[src] = nil
    Wallhack[src] = nil
    LicenseCache[src] = nil
    RateBuckets[src] = nil
    AceCache[src] = nil
    Duty[src] = nil
    if NeedsLock then NeedsLock[src] = nil end
    for _, r in pairs(Reports) do
        if r.src == src then r.offline = true end
    end
end)

-- ---------------------------------------------------------
--  Envoi des données au menu
-- ---------------------------------------------------------
local function onlineLicenses()
    local m = {}
    for _, p in ipairs(GetPlayers()) do
        local id = tonumber(p)
        local lic = getLicense(id)
        if lic then m[lic] = id end
    end
    return m
end

local function sendData(src)
    src = tonumber(src)
    if not src or src == 0 then return end
    local rn = getRankName(src)
    if not rn then return end

    local data = {
        me = {
            id = src, rank = rn, label = Ranks[rn].label, color = Ranks[rn].color,
            level = getLevel(src), perms = Ranks[rn].perms, duty = onDuty(src),
        },
        world = World,
        ranks = Ranks,
        players = {},
    }

    local showLicense = hasPerm(src, 'ban') or hasPerm(src, 'manage_staff')
    for _, p in ipairs(GetPlayers()) do
        local id = tonumber(p)
        local r = getRankName(id)
        local lic = getLicense(id)
        data.players[#data.players + 1] = {
            id = id,
            name = GetPlayerName(id),
            ping = GetPlayerPing(id),
            rank = r,
            rankLabel = r and Ranks[r].label or nil,
            rankColor = r and Ranks[r].color or nil,
            level = getLevel(id),
            frozen = Frozen[id] == true,
            warns = (lic and Warns[lic]) and #Warns[lic] or 0,
            license = showLicense and lic or nil,
        }
    end

    if hasPerm(src, 'manage_staff') then
        local online = onlineLicenses()
        local staff = {}
        for lic, a in pairs(Admins) do
            local r = Ranks[a.rank]
            staff[#staff + 1] = {
                identifier = lic, name = a.name or '?', rank = a.rank,
                label = r and r.label or a.rank, color = r and r.color or '#888888',
                level = r and r.level or 0, online = online[lic],
            }
        end
        local o = Ranks[Config.OwnerRank]
        for _, lic in ipairs(Config.Owners) do
            staff[#staff + 1] = {
                identifier = lic, name = online[lic] and GetPlayerName(online[lic]) or 'Fondateur (config)',
                rank = Config.OwnerRank, label = o.label, color = o.color, level = o.level,
                online = online[lic], owner = true,
            }
        end
        data.staff = staff
    end

    if hasPerm(src, 'ban') or hasPerm(src, 'unban') then
        purgeBans()
        local list = {}
        for _, b in ipairs(Bans) do
            list[#list + 1] = {
                id = b.id, name = b.name, reason = b.reason, by = b.by,
                date = os.date('%d/%m/%Y %H:%M', b.date or 0), expire = formatExpire(b),
            }
        end
        data.bans = list
    end

    if hasPerm(src, 'reports') then
        local list = {}
        for _, r in pairs(Reports) do list[#list + 1] = r end
        table.sort(list, function(a, b) return a.id > b.id end)
        data.reports = list
    end

    if hasPerm(src, 'view_logs') then data.logs = Logs end
    if AdminMenu and AdminMenu.DataHooks then
        for _, hook in ipairs(AdminMenu.DataHooks) do pcall(hook, src, data) end
    end

    TriggerClientEvent('adminmenu:data', src, data)
end

-- ---------------------------------------------------------
--  Helpers d'actions
-- ---------------------------------------------------------
local function getTarget(src, d, allowSelf)
    local t = tonumber(d.target)
    if not t or not isOnline(t) then notify(src, 'Joueur introuvable.', 'error') return nil end
    if t == src and not allowSelf then notify(src, 'Action impossible sur vous-même.', 'error') return nil end
    return t
end

local function checkHierarchy(src, t)
    if t ~= src and getLevel(t) >= getLevel(src) then
        notify(src, 'Ce joueur a un grade égal ou supérieur au vôtre.', 'error')
        return false
    end
    return true
end

local function deleteByNetId(src, netId, onlyVehicles)
    netId = tonumber(netId)
    if not netId then return end
    local ent = NetworkGetEntityFromNetworkId(netId)
    if not ent or ent == 0 or not DoesEntityExist(ent) then
        TriggerClientEvent('adminmenu:forceDelete', src, netId)
        return
    end
    if onlyVehicles and GetEntityType(ent) ~= 2 then
        return notify(src, 'Seuls les véhicules peuvent être supprimés depuis le noclip.', 'error')
    end
    for _, p in ipairs(GetPlayers()) do
        if GetPlayerPed(p) == ent then return notify(src, 'Impossible de supprimer un joueur.', 'error') end
    end
    local model = GetEntityModel(ent)
    DeleteEntity(ent)
    notify(src, 'Entité supprimée.', 'success')
    addLog(src, 'Suppression entité', ('Modèle : %s | NetID : %d'):format(model, netId))
end

local function broadcastWorld()
    TriggerClientEvent('adminmenu:syncWorld', -1, World)
end

-- ---------------------------------------------------------
--  ACTIONS
-- ---------------------------------------------------------
local Actions = {}

-- Téléportation -------------------------------------------
Actions['goto'] = { perm = 'goto', fn = function(src, d)
    local t = getTarget(src, d) if not t then return end
    SetPlayerRoutingBucket(src, GetPlayerRoutingBucket(t))
    TriggerClientEvent('adminmenu:teleport', src, GetEntityCoords(GetPlayerPed(t)))
    addLog(src, 'Goto', ('Vers %s [%d]'):format(pname(t), t))
end }

Actions.bring = { perm = 'bring', fn = function(src, d)
    local t = getTarget(src, d) if not t or not checkHierarchy(src, t) then return end
    SetPlayerRoutingBucket(t, GetPlayerRoutingBucket(src))
    TriggerClientEvent('adminmenu:teleport', t, GetEntityCoords(GetPlayerPed(src)))
    notify(t, 'Vous avez été téléporté par un membre du staff.', 'info')
    addLog(src, 'Bring', ('%s [%d] ramené'):format(pname(t), t))
end }

Actions.spectate = { perm = 'spectate', noRefresh = true, fn = function(src, d)
    local t = getTarget(src, d) if not t then return end
    if SpecBucket[src] == nil then SpecBucket[src] = GetPlayerRoutingBucket(src) end
    SetPlayerRoutingBucket(src, GetPlayerRoutingBucket(t))
    TriggerClientEvent('adminmenu:spectate', src, t, GetEntityCoords(GetPlayerPed(t)))
    addLog(src, 'Spectate', ('%s [%d]'):format(pname(t), t))
end }

-- État du joueur ------------------------------------------
Actions.freeze = { perm = 'freeze', fn = function(src, d)
    local t = getTarget(src, d) if not t or not checkHierarchy(src, t) then return end
    Frozen[t] = not Frozen[t]
    TriggerClientEvent('adminmenu:freeze', t, Frozen[t])
    notify(src, ('%s est maintenant %s.'):format(pname(t), Frozen[t] and 'freeze' or 'libre'), 'success')
    addLog(src, Frozen[t] and 'Freeze' or 'Unfreeze', ('%s [%d]'):format(pname(t), t))
end }

Actions.armor = { perm = 'armor', fn = function(src, d)
    local t = getTarget(src, d, true) if not t then return end
    TriggerClientEvent('adminmenu:armor', t)
    notify(src, ('Armure de %s remplie.'):format(t == src and 'toi' or pname(t)), 'success')
    addLog(src, 'Armure', ('%s [%d]'):format(pname(t), t))
end }

Actions.heal = { perm = 'heal', fn = function(src, d)
    local t = getTarget(src, d, true) if not t then return end
    if GetResourceState('qbx_medical') == 'started' then pcall(function() exports.qbx_medical:Heal(t) end) end
    TriggerClientEvent('adminmenu:heal', t)
    notify(src, ('%s a été soigné.'):format(pname(t)), 'success')
    addLog(src, 'Soin', ('%s [%d]'):format(pname(t), t))
end }

-- Réanimation côté SERVEUR : qbx_medical (Qbox) n'accepte la réanimation que si elle
-- vient du serveur ; sinon le joueur se relève puis retombe aussitôt.
local function started(res) return GetResourceState(res) == 'started' end
local function isDownServer(id)
    local st = Player(id).state
    return st.isDead == true or st.emsDown == true or st.dead == true or st.inLastStand == true
end
function MedicalRevive(id)
    id = tonumber(id)
    if not id then return end
    if started('qbx_medical') then
        pcall(function() exports.qbx_medical:Revive(id) end)
        pcall(function() exports.qbx_medical:Heal(id) end)
    end
    -- Coma Elyzea EMS : on le termine aussi (sinon le joueur reste couché)
    if started('elyzea_ems') then
        Player(id).state:set('emsDown', false, true)
        TriggerClientEvent('elyzea_ems:revived', id, 100)
    end
end

Actions.revive = { perm = 'revive', fn = function(src, d)
    local t = getTarget(src, d, true) if not t then return end
    MedicalRevive(t)
    TriggerClientEvent('adminmenu:revive', t, false, nil)
    notify(src, ('%s a été réanimé.'):format(pname(t)), 'success')
    addLog(src, 'Réanimation', ('%s [%d]'):format(pname(t), t))
end }

local ReviveAck = {}
Actions.revive_area = { perm = 'revive_area', fn = function(src, d)
    local radius = math.floor(math.min(math.max(tonumber(d.radius) or Config.ReviveAreaRadius, 5), 300))
    local c = GetEntityCoords(GetPlayerPed(src))
    local sent = 0
    ReviveAck[src] = 0
    for _, p in ipairs(GetPlayers()) do
        local id = tonumber(p)
        if #(GetEntityCoords(GetPlayerPed(id)) - c) <= radius then
            if isDownServer(id) then MedicalRevive(id) end
            TriggerClientEvent('adminmenu:revive', id, true, src)
            sent = sent + 1
        end
    end
    SetTimeout(2500, function()
        local n = ReviveAck[src] or 0
        ReviveAck[src] = nil
        notify(src, n > 0 and ('%d joueur(s) réanimé(s) dans un rayon de %d m.'):format(n, radius)
            or ('Personne à réanimer dans un rayon de %d m.'):format(radius), n > 0 and 'success' or 'info')
        addLog(src, 'Réanimation de zone', ('Rayon %d m | %d réanimé(s) sur %d joueur(s) proches'):format(radius, n, sent))
    end)
end }

RegisterNetEvent('adminmenu:reviveAck', function(adminId)
    adminId = tonumber(adminId)
    if adminId and ReviveAck[adminId] then ReviveAck[adminId] = ReviveAck[adminId] + 1 end
end)

Actions.kill = { perm = 'kill', fn = function(src, d)
    local t = getTarget(src, d, true) if not t or not checkHierarchy(src, t) then return end
    TriggerClientEvent('adminmenu:kill', t)
    addLog(src, 'Kill', ('%s [%d]'):format(pname(t), t))
end }

Actions.give_weapon = { perm = 'give_weapon', fn = function(src, d)
    local t = getTarget(src, d, true) if not t then return end
    local w = tostring(d.weapon or ''):upper()
    if not w:match('^WEAPON_[%w_]+$') then return notify(src, 'Nom d\'arme invalide (ex : WEAPON_PISTOL).', 'error') end
    -- Avec un inventaire (ox_inventory sur Qbox…), l'arme doit passer par lui,
    -- sinon il la retire aussitôt.
    if Bridge.Mode() ~= 'none' then
        local ok, err = Bridge.AddItem(t, w, 1)
        if not ok then return notify(src, Bridge.Errors[err] or 'Impossible de donner cette arme.', 'error') end
    else
        TriggerClientEvent('adminmenu:giveWeapon', t, w)
    end
    notify(src, ('%s donné à %s.'):format(w, pname(t)), 'success')
    addLog(src, 'Don d\'arme', ('%s → %s [%d]'):format(w, pname(t), t))
end }

-- Objets ---------------------------------------------------
local itemsReload = {}
function AM_itemsRateOk(src)
    local t = GetGameTimer()
    if itemsReload[src] and t - itemsReload[src] < 10000 then return false end
    itemsReload[src] = t
    return true
end
Actions.get_items = { perm = 'give_item', noRefresh = true, fn = function(src, d)
    local force = d.force == true and AM_itemsRateOk(src)
    TriggerLatentClientEvent('adminmenu:items', src, 200000, Bridge.GetAllItems(force), Bridge.Mode())
end }

Actions.give_item = { perm = 'give_item', noRefresh = true, fn = function(src, d)
    local t = getTarget(src, d, true) if not t then return end
    local name = tostring(d.item or ''):gsub('[^%w_%-]', '')
    local count = math.floor(math.min(math.max(tonumber(d.count) or 1, 1), 10000))
    if name == '' then return notify(src, 'Choisis un objet.', 'error') end
    local exists, it = Bridge.ItemExists(name)
    if not exists and Bridge.Mode() ~= 'none' then
        return notify(src, ('L\'objet « %s » n\'existe pas dans ton inventaire.'):format(name), 'error')
    end
    name = it and it.name or name
    local ok, err = Bridge.AddItem(t, name, count)
    if not ok then
        return notify(src, (Bridge.Errors[err] or 'Impossible de donner cet objet.') .. (err == 'full' and ' (trop lourd pour son inventaire)' or ''), 'error')
    end
    local label = it and it.label or name
    notify(src, ('%d × %s donné à %s.'):format(count, label, t == src and 'toi' or pname(t)), 'success')
    if t ~= src then notify(t, ('Le staff t\'a donné %d × %s.'):format(count, label), 'info') end
    addLog(src, 'Don d\'objet', ('%d × %s → %s [%d]'):format(count, name, pname(t), t))
end }

-- Sanctions -----------------------------------------------
Actions.warn = { perm = 'warn', fn = function(src, d)
    local t = getTarget(src, d) if not t or not checkHierarchy(src, t) then return end
    local reason = tostring(d.reason or ''):sub(1, 250)
    if reason == '' then return notify(src, 'Indiquez une raison.', 'error') end
    local lic = getLicense(t)
    if lic then
        Warns[lic] = Warns[lic] or {}
        table.insert(Warns[lic], { reason = reason, by = pname(src), date = os.time() })
        Storage.saveLater('warns', Warns)
    end
    TriggerClientEvent('adminmenu:warn', t, reason, pname(src))
    notify(src, ('Avertissement envoyé à %s.'):format(pname(t)), 'success')
    addLog(src, 'Avertissement', ('%s [%d] | %s'):format(pname(t), t, reason))
end }

Actions.kick = { perm = 'kick', fn = function(src, d)
    local t = getTarget(src, d) if not t or not checkHierarchy(src, t) then return end
    local reason = tostring(d.reason or ''):sub(1, 250)
    if reason == '' then reason = 'Aucune raison précisée' end
    local name = pname(t)
    DropPlayer(t, ('Vous avez été expulsé par %s.\nRaison : %s'):format(pname(src), reason))
    notify(src, ('%s a été expulsé.'):format(name), 'success')
    addLog(src, 'Kick', ('%s [%d] | %s'):format(name, t, reason))
end }

Actions.ban = { perm = 'ban', fn = function(src, d)
    local t = getTarget(src, d) if not t or not checkHierarchy(src, t) then return end
    local hours = math.max(0, math.floor(tonumber(d.duration) or 0))
    local reason = tostring(d.reason or ''):sub(1, 250)
    if reason == '' then reason = 'Aucune raison précisée' end
    local ban = {
        id = nextBanId(),
        name = pname(t),
        identifiers = GetPlayerIdentifiers(t),
        tokens = getTokens(t),
        reason = reason,
        by = pname(src),
        date = os.time(),
        expires = hours > 0 and (os.time() + hours * 3600) or 0,
    }
    table.insert(Bans, ban)
    Storage.save('bans', Bans)
    DropPlayer(t, banMessage(ban))
    notify(src, ('%s a été banni (%s).'):format(ban.name, formatExpire(ban)), 'success')
    addLog(src, 'Ban', ('%s | %s | Expire : %s | #%d'):format(ban.name, reason, formatExpire(ban), ban.id))
end }

Actions.unban = { perm = 'unban', fn = function(src, d)
    local id = tonumber(d.banId)
    for i, b in ipairs(Bans) do
        if b.id == id then
            table.remove(Bans, i)
            Storage.save('bans', Bans)
            notify(src, ('%s a été débanni.'):format(b.name), 'success')
            addLog(src, 'Unban', ('%s | ban #%d'):format(b.name, id))
            return
        end
    end
    notify(src, 'Ban introuvable.', 'error')
end }

-- Reports -------------------------------------------------
Actions.report_claim = { perm = 'reports', fn = function(src, d)
    local r = Reports[tonumber(d.id)]
    if not r then return notify(src, 'Report introuvable.', 'error') end
    r.claimedBy = pname(src)
    if not r.offline and isOnline(r.src) then
        notify(r.src, ('Votre report est pris en charge par %s.'):format(pname(src)), 'success')
    end
    addLog(src, 'Report pris en charge', ('#%d de %s'):format(r.id, r.name))
end }

Actions.report_close = { perm = 'reports', fn = function(src, d)
    local r = Reports[tonumber(d.id)]
    if not r then return end
    Reports[r.id] = nil
    if not r.offline and isOnline(r.src) then notify(r.src, 'Votre report a été clôturé.', 'info') end
    addLog(src, 'Report clôturé', ('#%d de %s'):format(r.id, r.name))
end }

-- Véhicules / entités -------------------------------------
Actions.spawn_vehicle = { perm = 'spawn_vehicle', noRefresh = true, fn = function(src, d)
    local model = tostring(d.model or ''):lower():gsub('[^%w_]', '')
    if model == '' then return notify(src, 'Indiquez un modèle.', 'error') end
    TriggerClientEvent('adminmenu:spawnVehicle', src, model)
    addLog(src, 'Spawn véhicule', model)
end }

local VEHICLE_TOOLS = { repair = true, clean = true, flip = true, upgrade = true, delete = true, unlock = true }
Actions.vehicle_tool = { perm = 'vehicle_tools', noRefresh = true, fn = function(src, d)
    if not VEHICLE_TOOLS[d.tool] then return end
    TriggerClientEvent('adminmenu:vehicleTool', src, d.tool)
end }

Actions.delete_vehicle = { perm = 'vehicle_tools', noRefresh = true, fn = function(src, d)
    deleteByNetId(src, d.netId, true)
end }

Actions.delete_entity = { perm = 'delete_entity', noRefresh = true, fn = function(src, d)
    deleteByNetId(src, d.netId, true)
end }

-- Monde ---------------------------------------------------
Actions.weather = { perm = 'weather', fn = function(src, d)
    for _, w in ipairs(Config.Weathers) do
        if w.id == d.weather then
            World.weather = w.id
            broadcastWorld()
            notify(src, ('Météo : %s'):format(w.label), 'success')
            addLog(src, 'Météo', w.label)
            return
        end
    end
end }

Actions.time = { perm = 'time', fn = function(src, d)
    local h, m = tonumber(d.hour), tonumber(d.minute)
    if not h or not m or h < 0 or h > 23 or m < 0 or m > 59 then return notify(src, 'Heure invalide.', 'error') end
    World.hour, World.minute = math.floor(h), math.floor(m)
    broadcastWorld()
    addLog(src, 'Heure', ('%02d:%02d'):format(World.hour, World.minute))
end }

Actions.freeze_time = { perm = 'time', fn = function(src)
    World.freeze = not World.freeze
    broadcastWorld()
    addLog(src, 'Heure', World.freeze and 'Heure figée' or 'Heure relancée')
end }

Actions.blackout = { perm = 'blackout', fn = function(src)
    World.blackout = not World.blackout
    broadcastWorld()
    addLog(src, 'Blackout', World.blackout and 'Activé' or 'Désactivé')
end }

local ANNOUNCE_STYLES = { info = true, event = true, alert = true }
Actions.announce = { perm = 'announce', fn = function(src, d)
    local msg = tostring(d.message or ''):sub(1, 400)
    if msg:gsub('%s', '') == '' then return notify(src, 'Le message est vide.', 'error') end
    local image = tostring(d.image or '')
    if image ~= '' and image ~= 'logo' then
        if #image > 500 or not image:match('^https?://[%w%-%._~:/%?#%[%]@!%$&\'%(%)%*%+,;=%%]+$') then
            return notify(src, "Lien d'image invalide (il doit commencer par https://).", 'error')
        end
    end
    local payload = {
        title = tostring(d.title or ''):sub(1, 60),
        message = msg,
        image = image,
        style = ANNOUNCE_STYLES[d.style] and d.style or 'info',
        duration = math.floor(math.min(math.max(tonumber(d.duration) or 10, 4), 60)),
        ticker = d.ticker == true,
        by = pname(src),
    }
    TriggerClientEvent('adminmenu:announce', -1, payload)
    notify(src, 'Annonce envoyée à tout le serveur.', 'success')
    addLog(src, 'Annonce', (payload.title ~= '' and ('[' .. payload.title .. '] ') or '') .. msg)
end }

Actions.clear_area = { perm = 'clear_area', fn = function(src, d)
    local radius = math.floor(math.min(math.max(tonumber(d.radius) or 50, 5), 500))
    local c = GetEntityCoords(GetPlayerPed(src))
    local playerPeds = {}
    for _, p in ipairs(GetPlayers()) do playerPeds[GetPlayerPed(p)] = true end

    local nVeh, nPed = 0, 0
    for _, veh in ipairs(GetAllVehicles()) do
        if DoesEntityExist(veh) and #(GetEntityCoords(veh) - c) <= radius then
            local occupied = false
            for seat = -1, 8 do
                if playerPeds[GetPedInVehicleSeat(veh, seat)] then occupied = true break end
            end
            if not occupied then DeleteEntity(veh) nVeh = nVeh + 1 end
        end
    end
    for _, ped in ipairs(GetAllPeds()) do
        if DoesEntityExist(ped) and not playerPeds[ped] and #(GetEntityCoords(ped) - c) <= radius then
            DeleteEntity(ped) nPed = nPed + 1
        end
    end
    notify(src, ('Zone nettoyée : %d véhicule(s), %d PNJ.'):format(nVeh, nPed), 'success')
    addLog(src, 'Nettoyage de zone', ('Rayon %dm | %d véhicules | %d PNJ'):format(radius, nVeh, nPed))
end }

-- Staff ---------------------------------------------------
Actions.set_rank = { perm = 'manage_staff', fn = function(src, d)
    local t = tonumber(d.target)
    if not t or not isOnline(t) then return notify(src, 'Joueur introuvable.', 'error') end
    if t == src then return notify(src, 'Vous ne pouvez pas modifier votre propre grade.', 'error') end
    local lic = getLicense(t)
    if not lic then return notify(src, 'Ce joueur n\'a pas de licence Rockstar.', 'error') end
    if isOwner(lic) then return notify(src, 'Ce joueur est fondateur via la config.', 'error') end
    if not checkHierarchy(src, t) then return end

    local rank = tostring(d.rank or '')
    if rank == 'none' or rank == '' then
        Admins[lic] = nil
        notify(src, ('%s ne fait plus partie du staff.'):format(pname(t)), 'success')
        notify(t, 'Vous ne faites plus partie du staff.', 'warning')
        addLog(src, 'Staff retiré', pname(t))
    else
        local r = Ranks[rank]
        if not r then return notify(src, 'Grade inconnu.', 'error') end
        if r.level >= getLevel(src) then return notify(src, 'Vous ne pouvez pas donner un grade égal ou supérieur au vôtre.', 'error') end
        Admins[lic] = { rank = rank, name = pname(t) }
        notify(src, ('%s est maintenant %s.'):format(pname(t), r.label), 'success')
        notify(t, ('Vous êtes maintenant %s. Menu : %s'):format(r.label, Config.Keys[1].key), 'success')
        addLog(src, 'Grade attribué', ('%s → %s'):format(pname(t), r.label))
    end
    Storage.saveLater('admins', Admins)
    pushPerms(t)
end }

Actions.remove_staff = { perm = 'manage_staff', fn = function(src, d)
    local lic = tostring(d.identifier or '')
    local a = Admins[lic]
    if not a then return notify(src, 'Membre introuvable.', 'error') end
    local r = Ranks[a.rank]
    if r and r.level >= getLevel(src) then return notify(src, 'Grade égal ou supérieur au vôtre.', 'error') end
    Admins[lic] = nil
    Storage.saveLater('admins', Admins)
    local online = onlineLicenses()
    if online[lic] then pushPerms(online[lic]) notify(online[lic], 'Vous ne faites plus partie du staff.', 'warning') end
    notify(src, ('%s retiré du staff.'):format(a.name or lic), 'success')
    addLog(src, 'Staff retiré', a.name or lic)
end }

Actions.change_staff_rank = { perm = 'manage_staff', fn = function(src, d)
    local lic = tostring(d.identifier or '')
    local a = Admins[lic]
    local r = Ranks[tostring(d.rank or '')]
    if not a or not r then return notify(src, 'Données invalides.', 'error') end
    local cur = Ranks[a.rank]
    local my = getLevel(src)
    if (cur and cur.level >= my) or r.level >= my then return notify(src, 'Grade égal ou supérieur au vôtre.', 'error') end
    a.rank = d.rank
    Storage.saveLater('admins', Admins)
    local online = onlineLicenses()
    if online[lic] then pushPerms(online[lic]) end
    notify(src, ('%s est maintenant %s.'):format(a.name or lic, r.label), 'success')
    addLog(src, 'Grade modifié', ('%s → %s'):format(a.name or lic, r.label))
end }

-- Grades --------------------------------------------------
Actions.save_rank = { perm = 'manage_ranks', fn = function(src, d)
    local name = (tostring(d.name or ''):lower():gsub('[^%w_]', ''))
    if name == '' then return notify(src, 'Identifiant de grade invalide (lettres, chiffres, _).', 'error') end
    local my = getLevel(src)
    local existing = Ranks[name]
    if existing and (existing.locked or existing.level >= my) then
        return notify(src, 'Vous ne pouvez pas modifier ce grade.', 'error')
    end
    local level = math.floor(tonumber(d.level) or 0)
    if level < 1 or level >= my then
        return notify(src, ('Le niveau doit être entre 1 et %d.'):format(my - 1), 'error')
    end
    local perms = {}
    if type(d.perms) == 'table' then
        for _, p in ipairs(Config.Permissions) do
            if d.perms[p.key] == true and hasPerm(src, p.key) then perms[p.key] = true end
        end
    end
    local color = tostring(d.color or '')
    if not color:match('^#%x%x%x%x%x%x$') then color = '#8a96ad' end
    local label = tostring(d.label or ''):sub(1, 32)
    if label == '' then label = name end

    Ranks[name] = { label = label, level = level, color = color, perms = perms }
    Storage.save('ranks', Ranks)
    pushPermsAll()
    notify(src, ('Grade %s enregistré.'):format(label), 'success')
    addLog(src, existing and 'Grade modifié' or 'Grade créé', ('%s (niveau %d)'):format(label, level))
end }

Actions.delete_rank = { perm = 'manage_ranks', fn = function(src, d)
    local name = tostring(d.name or '')
    local r = Ranks[name]
    if not r then return end
    if r.locked or r.level >= getLevel(src) then return notify(src, 'Vous ne pouvez pas supprimer ce grade.', 'error') end
    Ranks[name] = nil
    for lic, a in pairs(Admins) do if a.rank == name then Admins[lic] = nil end end
    Storage.save('ranks', Ranks)
    Storage.saveLater('admins', Admins)
    pushPermsAll()
    notify(src, ('Grade %s supprimé.'):format(r.label), 'success')
    addLog(src, 'Grade supprimé', r.label)
end }

-- ---------------------------------------------------------
--  Évènements réseau
-- ---------------------------------------------------------
RegisterNetEvent('adminmenu:action', function(name, data)
    local src = source
    local a = Actions[name]
    if not a then return end
    if not rateLimit(src, 'action', 15, 1000) then return end
    local allowed = a.perm ~= nil and hasPerm(src, a.perm)
    for _, p in ipairs(a.permAny or {}) do
        if hasPerm(src, p) then allowed = true end
    end
    if not allowed then
        notify(src, 'Permission refusée.', 'error')
        print(('^1[AdminMenu] %s [%d] a tenté l\'action "%s" sans permission.^7'):format(pname(src), src, tostring(name)))
        return
    end
    if not onDuty(src) then
        return notify(src, 'Tu es en mode RP : reprends ton service staff pour utiliser cette fonction.', 'error')
    end
    if a.minLevel and getLevel(src) < a.minLevel then
        return notify(src, 'Réservé aux grades SuperAdmin et Fondateur.', 'error')
    end
    a.fn(src, type(data) == 'table' and data or {})
    if not a.noRefresh then sendData(src) end
end)

RegisterNetEvent('adminmenu:requestPerms', function() pushPerms(source) end)

-- Permissions renvoyées à tout le monde au démarrage du menu, et à chaque arrivée
-- (au cas où la demande du joueur serait arrivée avant que le serveur soit prêt)
AddEventHandler('onResourceStart', function(res)
    if res == GetCurrentResourceName() then SetTimeout(2500, pushPermsAll) end
end)
AddEventHandler('playerJoining', function()
    local src = source
    SetTimeout(4000, function() if GetPlayerName(src) then pushPerms(src) end end)
end)

-- ---------------------------------------------------------
--  Commandes CONSOLE (txAdmin › Live Console) pour retrouver l'accès
--  Elles ne passent ni par ox ni par les ACE : uniquement le menu lui-même.
-- ---------------------------------------------------------
local function consoleTarget(arg)
    local id = tonumber(arg)
    if id and GetPlayerName(id) then return getLicense(id), id end
    if arg and arg:sub(1, 8) == 'license:' then return arg, nil end
end
RegisterCommand('adminmenu_fondateur', function(src, args)
    if src ~= 0 then return end
    local lic, id = consoleTarget(args[1])
    if not lic then return print('^1Utilisation : adminmenu_fondateur <id du joueur | license:xxxx>^7') end
    for _, o in ipairs(Owners) do if o == lic then return print('^3Déjà Fondateur.^7') end end
    Owners[#Owners + 1] = lic
    Storage.save('owners', Owners)
    if id then pushPerms(id) end
    print(('^2[AdminMenu] %s est maintenant Fondateur (enregistré dans data/owners.json).^7'):format(id and GetPlayerName(id) or lic))
end, true)
RegisterCommand('adminmenu_retirer_fondateur', function(src, args)
    if src ~= 0 then return end
    local lic, id = consoleTarget(args[1])
    if not lic then return print('^1Utilisation : adminmenu_retirer_fondateur <id | license:xxxx>^7') end
    for i, o in ipairs(Owners) do if o == lic then table.remove(Owners, i) break end end
    Storage.save('owners', Owners)
    if id then pushPerms(id) end
    print('^2[AdminMenu] Fondateur retiré.^7')
end, true)
RegisterCommand('adminmenu_grade', function(src, args)
    if src ~= 0 then return end
    local lic, id = consoleTarget(args[1])
    local rank = args[2]
    if not lic or not rank then
        local names = {}
        for k in pairs(Ranks) do names[#names + 1] = k end
        return print(('^1Utilisation : adminmenu_grade <id | license:xxxx> <grade | aucun>   Grades : %s^7'):format(table.concat(names, ', ')))
    end
    if rank == 'aucun' then Admins[lic] = nil
    elseif not Ranks[rank] then return print('^1Grade inconnu.^7')
    else Admins[lic] = { rank = rank, name = id and GetPlayerName(id) or (Admins[lic] and Admins[lic].name) or lic } end
    Storage.save('admins', Admins)
    if id then pushPerms(id) end
    print(('^2[AdminMenu] %s : %s.^7'):format(id and GetPlayerName(id) or lic, rank == 'aucun' and 'grade retiré' or ('grade ' .. Ranks[rank].label)))
end, true)
RegisterCommand('adminmenu_qui', function(src, args)
    if src ~= 0 then return end
    for _, p in ipairs(GetPlayers()) do
        local id = tonumber(p)
        local r = getRankName(id)
        print(('[%d] %s  %s  ->  %s'):format(id, GetPlayerName(id), getLicense(id) or '?', r and Ranks[r].label or 'aucun accès'))
    end
end, true)

RegisterNetEvent('adminmenu:duty', function(on, silent)
    local src = source
    if not getRankName(src) then return end
    if not rateLimit(src, 'duty', 3, 2000) then return end
    local was = onDuty(src)
    Duty[src] = on == true
    if was ~= Duty[src] and not silent then
        addLog(src, Duty[src] and 'Prise de service staff' or 'Fin de service (mode RP)')
    end
    NeedsLock[src] = nil -- nouveau relevé au prochain passage (service) ou fin du gel (mode RP)
    TriggerClientEvent('adminmenu:needsFreeze', src, Duty[src] and Config.StaffNeeds and Config.StaffNeeds.enabled)
    sendData(src)
end)

-- ---------------------------------------------------------
--  Staff en service : faim et soif FIGÉES (elles ne baissent plus)
--  On garde le niveau relevé ; s'il baisse, on le remet ; s'il monte
--  (le staff mange ou boit), le nouveau niveau devient la référence.
-- ---------------------------------------------------------
NeedsLock = {}
local function freezeNeeds(id)
    local cur = Bridge.GetNeeds(id)
    if not cur or not cur.hunger then return end
    local lock = NeedsLock[id]
    if not lock then
        NeedsLock[id] = { hunger = cur.hunger, thirst = cur.thirst, stress = cur.stress }
        return
    end
    local fix = {}
    for _, key in ipairs({ 'hunger', 'thirst' }) do
        local v = cur[key]
        if v then
            if v < lock[key] - 0.01 then fix[key] = lock[key] else lock[key] = v end
        end
    end
    if Config.StaffNeeds.stress and cur.stress and lock.stress then
        if math.abs(cur.stress - lock.stress) > 0.01 then fix.stress = lock.stress end
    end
    if next(fix) then Bridge.SetNeeds(id, fix) end
end

CreateThread(function()
    while true do
        Wait(math.max(3, (Config.StaffNeeds and Config.StaffNeeds.interval) or 10) * 1000)
        if Config.StaffNeeds and Config.StaffNeeds.enabled and Bridge then
            for _, p in ipairs(GetPlayers()) do
                local id = tonumber(p)
                if getRankName(id) and onDuty(id) then freezeNeeds(id) else NeedsLock[id] = nil end
            end
        end
    end
end)
RegisterNetEvent('adminmenu:requestData', function()
    local src = source
    if rateLimit(src, 'data', 4, 1000) then sendData(src) end
end)
RegisterNetEvent('adminmenu:requestWorld', function() TriggerClientEvent('adminmenu:syncWorld', source, World) end)

RegisterNetEvent('adminmenu:spectateEnd', function()
    local src = source
    if SpecBucket[src] ~= nil then
        SetPlayerRoutingBucket(src, SpecBucket[src])
        SpecBucket[src] = nil
    end
end)

local SELF_LOGS = {
    noclip_on   = { 'noclip', 'Noclip activé' },
    noclip_off  = { 'noclip', 'Noclip désactivé' },
    godmode_on  = { 'godmode', 'Godmode activé' },
    godmode_off = { 'godmode', 'Godmode désactivé' },
    invisible_on  = { 'invisible', 'Invisibilité activée' },
    invisible_off = { 'invisible', 'Invisibilité désactivée' },
    tp_waypoint = { 'tp_waypoint', 'TP au marqueur' },
    tp_coords   = { 'tp_coords', 'TP coordonnées' },
    transform   = { 'transform', 'Transformation en animal' },
    transform_off = { 'transform', 'Retour forme humaine' },
}
RegisterNetEvent('adminmenu:logSelf', function(name, details)
    local src = source
    local m = SELF_LOGS[name]
    if m and hasPerm(src, m[1]) then addLog(src, m[2], type(details) == 'string' and details:sub(1, 100) or '') end
end)

-- ---------------------------------------------------------
--  Wallhack : positions de tous les joueurs pour les blips
-- ---------------------------------------------------------
local function positionsList()
    local list = {}
    for _, p in ipairs(GetPlayers()) do
        local ped = GetPlayerPed(p)
        if ped ~= 0 and DoesEntityExist(ped) then
            local c = GetEntityCoords(ped)
            list[#list + 1] = {
                id = tonumber(p), name = GetPlayerName(p),
                x = c.x, y = c.y, z = c.z, h = GetEntityHeading(ped),
                veh = GetVehiclePedIsIn(ped, false) ~= 0,
            }
        end
    end
    return list
end

RegisterNetEvent('adminmenu:wallhack', function(state)
    local src = source
    if state and not hasPerm(src, 'wallhack') then
        TriggerClientEvent('adminmenu:wallhackOff', src)
        return notify(src, 'Permission refusée.', 'error')
    end
    Wallhack[src] = state and true or nil
    addLog(src, state and 'Wallhack activé' or 'Wallhack désactivé')
    if state then TriggerClientEvent('adminmenu:positions', src, positionsList()) end
end)

CreateThread(function()
    while true do
        Wait(Config.Wallhack.refresh)
        if next(Wallhack) then
            local list = positionsList()
            for src in pairs(Wallhack) do
                if hasPerm(src, 'wallhack') then
                    TriggerClientEvent('adminmenu:positions', src, list)
                else
                    Wallhack[src] = nil
                    TriggerClientEvent('adminmenu:wallhackOff', src)
                end
            end
        end
    end
end)

-- ---------------------------------------------------------
--  Commandes
-- ---------------------------------------------------------
RegisterCommand('report', function(src, args)
    if src == 0 then return end
    local msg = table.concat(args, ' '):sub(1, 250)
    if msg == '' then return notify(src, 'Utilisation : /report <message>', 'error') end
    local now = os.time()
    if ReportCooldown[src] and now - ReportCooldown[src] < Config.ReportCooldown then
        return notify(src, ('Patientez %ds avant un nouveau report.'):format(Config.ReportCooldown - (now - ReportCooldown[src])), 'error')
    end
    ReportCooldown[src] = now
    reportCounter = reportCounter + 1
    local r = { id = reportCounter, src = src, name = pname(src), msg = msg, time = os.date('%H:%M') }
    Reports[r.id] = r
    notify(src, 'Report envoyé au staff.', 'success')
    for _, id in ipairs(staffOnline('reports')) do TriggerClientEvent('adminmenu:newReport', id, r) end
end, false)

-- Console : setrank <id> <grade|none>   (ex : setrank 1 fondateur)
RegisterCommand('setrank', function(src, args)
    if src ~= 0 and not hasPerm(src, 'manage_staff') then return notify(src, 'Permission refusée.', 'error') end
    Actions.set_rank.fn(src, { target = args[1], rank = args[2] })
end, false)

-- Console : unban <idDuBan>
RegisterCommand('unban', function(src, args)
    if src ~= 0 and not hasPerm(src, 'unban') then return notify(src, 'Permission refusée.', 'error') end
    Actions.unban.fn(src, { banId = args[1] })
end, false)

-- ---------------------------------------------------------
--  Horloge et synchronisation du monde
-- ---------------------------------------------------------
CreateThread(function()
    while true do
        Wait(Config.World.minuteDuration)
        if not World.freeze then
            World.minute = World.minute + 1
            if World.minute >= 60 then
                World.minute = 0
                World.hour = (World.hour + 1) % 24
            end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(10000)
        broadcastWorld()
    end
end)

-- Exports pour d'autres ressources
exports('HasPermission', function(src, perm) return hasPerm(src, perm) end)
exports('GetRank', function(src) return getRankName(src) end)
-- Logs du menu (console + onglet Logs + Discord) pour les ressources liées (tablettes staff)
exports('AddLog', function(src, action, details) addLog(src, tostring(action or ''), details and tostring(details) or '') end)

-- Accès partagé pour les autres fichiers serveur (éditeur de map, etc.)
AdminMenu = {
    Actions = Actions, hasPerm = hasPerm, getLevel = getLevel, getLicense = getLicense, rateLimit = rateLimit,
    notify = notify, addLog = addLog, pname = pname, sendData = sendData, World = World,
    broadcastWorld = broadcastWorld,
    rankOf = function(src) local r = getRankName(src) return r and Ranks[r] or nil end,
    isOnline = function(src) return isOnline(src) end,
    onDuty = function(src) return onDuty(src) end, DataHooks = {},
    Ranks = Ranks, getRankName = getRankName, pushPermsAll = pushPermsAll,
    saveRanks = function() Storage.save('ranks', Ranks) pushPermsAll() end,
}

-- Vérification au démarrage : scripts qui entreraient en conflit.
-- Attention : Renewed-Weathersync se fait aussi passer pour qb-weathersync
-- et cd_easytime (« provide »). On ne signale donc que les vrais dossiers.
CreateThread(function()
    Wait(3000)
    local real = {}
    for i = 0, GetNumResources() - 1 do
        local name = GetResourceByFindIndex(i)
        if name then real[name] = true end
    end
    local found = {}
    for _, r in ipairs({ 'Renewed-Weathersync', 'qbx_weathersync', 'qb-weathersync', 'vSync', 'cd_easytime', 'weathersync' }) do
        if real[r] and GetResourceState(r) == 'started' then found[#found + 1] = r end
    end
    for _, r in ipairs(found) do
        print(('^1[AdminMenu] "%s" gère aussi la météo : déplace son dossier hors de resources, sinon il va se battre avec le menu.^7'):format(r))
    end
    if GetResourceState('ox_inventory') ~= 'started' and GetResourceState('qb-core') ~= 'started' and GetResourceState('es_extended') ~= 'started' then
        print('^3[AdminMenu] Aucun inventaire détecté : récoltes, fouilles et ateliers ne pourront rien donner.^7')
    end
end)
