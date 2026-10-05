-- =========================================================
--  TABLETTE STAFF EMS - SERVEUR
--  Le menu décide qui peut ouvrir /ems_staff (ressource elyzea_ems) :
--   - les grades qui ont la permission « ems_staff » (onglet Grades
--     ou onglet 🚑 Tablette EMS),
--   - les accès individuels donnés dans l'onglet 🚑 Tablette EMS.
--  La ressource EMS appelle exports.admin_menu:CanUseEmsStaff(src).
-- =========================================================
local AM = AdminMenu
local CFG = Config.Ems or {}
local Access = Storage.load('ems_access', {})   -- [licence] = { name, by, date }

local function emsRunning() return GetResourceState(CFG.resource or 'elyzea_ems') == 'started' end
local function staffRunning() return GetResourceState(CFG.staffResource or 'elyzea_ems_staff') == 'started' end

local function individual(src)
    local lic = AM.getLicense(src)
    return lic ~= nil and Access[lic] ~= nil
end

-- Accès à la tablette staff EMS. Renvoie true, ou false + raison ('rp', 'none').
local function canUse(src)
    src = tonumber(src)
    if not src then return false, 'none' end
    if src == 0 then return true end
    local byRank = AM.hasPerm(src, 'ems_staff')
    if not byRank and not individual(src) then return false, 'none' end
    -- Les accès individuels n'ont pas forcément de grade staff : pas de mode RP pour eux
    if CFG.requireDuty ~= false and AM.rankOf(src) and not AM.onDuty(src) then return false, 'rp' end
    return true, byRank and 'rank' or 'individual'
end
exports('CanUseEmsStaff', canUse)

-- Notifie la ressource EMS pour qu'elle relise les accès (rien à faire : elle demande à chaque ouverture)
local function refreshViewers()
    for _, p in ipairs(GetPlayers()) do
        local id = tonumber(p)
        if AM.hasPerm(id, 'ems_staff') or AM.hasPerm(id, 'manage_ranks') or AM.hasPerm(id, 'manage_staff') then AM.sendData(id) end
    end
end

-- ---------------------------------------------------------
--  Actions de l'onglet 🚑 Tablette EMS
-- ---------------------------------------------------------
local A = AM.Actions

-- Donner / retirer l'accès à un grade entier
A.ems_rank_toggle = { perm = 'manage_ranks', noRefresh = true, fn = function(src, d)
    local name = tostring(d.rank or '')
    local r = AM.Ranks[name]
    if not r then return AM.notify(src, 'Grade introuvable.', 'error') end
    if r.locked then return AM.notify(src, 'Ce grade a toujours tous les accès.', 'error') end
    if r.level >= AM.getLevel(src) then return AM.notify(src, 'Tu ne peux modifier que les grades inférieurs au tien.', 'error') end
    if not AM.hasPerm(src, 'ems_staff') then return AM.notify(src, 'Tu dois toi-même avoir accès à la tablette EMS pour le donner.', 'error') end
    local on = d.on == true
    r.perms.ems_staff = on or nil
    AM.saveRanks()
    AM.addLog(src, on and 'Accès tablette EMS donné' or 'Accès tablette EMS retiré', ('Grade %s'):format(r.label))
    AM.notify(src, ('%s : accès à la tablette staff EMS %s.'):format(r.label, on and 'donné' or 'retiré'), 'success')
    refreshViewers()
end }

-- Donner l'accès à un joueur précis (même sans grade staff)
A.ems_access_add = { perm = 'manage_staff', noRefresh = true, fn = function(src, d)
    local id = tonumber(d.target)
    if not id or not GetPlayerName(id) then return AM.notify(src, 'Joueur introuvable (il doit être connecté).', 'error') end
    if not AM.hasPerm(src, 'ems_staff') then return AM.notify(src, 'Tu dois toi-même avoir accès à la tablette EMS pour le donner.', 'error') end
    local lic = AM.getLicense(id)
    if not lic then return AM.notify(src, 'Licence du joueur introuvable.', 'error') end
    if AM.getRankName(id) and AM.getLevel(id) >= AM.getLevel(src) and src ~= 0 then
        return AM.notify(src, 'Ce staff a un grade égal ou supérieur au tien.', 'error')
    end
    Access[lic] = { name = GetPlayerName(id), by = AM.pname(src), date = os.date('%d/%m/%Y %H:%M') }
    Storage.save('ems_access', Access)
    AM.addLog(src, 'Accès tablette EMS donné', ('%s [%d] (accès individuel)'):format(GetPlayerName(id), id))
    AM.notify(src, ('%s a maintenant accès à la tablette staff EMS.'):format(GetPlayerName(id)), 'success')
    AM.notify(id, ('Tu as maintenant accès à la tablette staff EMS : /%s'):format(CFG.command or 'ems_staff'), 'success')
    refreshViewers()
end }

A.ems_access_remove = { perm = 'manage_staff', noRefresh = true, fn = function(src, d)
    local lic = tostring(d.license or '')
    local a = Access[lic]
    if not a then return end
    Access[lic] = nil
    Storage.save('ems_access', Access)
    AM.addLog(src, 'Accès tablette EMS retiré', ('%s (accès individuel)'):format(a.name or lic))
    AM.notify(src, ('Accès retiré à %s.'):format(a.name or 'ce joueur'), 'success')
    refreshViewers()
end }

-- ---------------------------------------------------------
--  Données de l'onglet
-- ---------------------------------------------------------
table.insert(AM.DataHooks, function(src, data)
    local canManageRanks, canManageStaff = AM.hasPerm(src, 'manage_ranks'), AM.hasPerm(src, 'manage_staff')
    if not (AM.hasPerm(src, 'ems_staff') or canManageRanks or canManageStaff) then return end
    local my = AM.getLevel(src)
    local out = {
        available = emsRunning(), staffAvailable = staffRunning(),
        resource = CFG.resource or 'elyzea_ems', staffResource = CFG.staffResource or 'elyzea_ems_staff',
        command = CFG.command or 'ems_staff', requireDuty = CFG.requireDuty ~= false,
        mine = (canUse(src)), canManageRanks = canManageRanks, canManageStaff = canManageStaff,
        ranks = {}, individuals = {}, online = {},
    }
    for name, r in pairs(AM.Ranks) do
        out.ranks[#out.ranks + 1] = { name = name, label = r.label, color = r.color, level = r.level,
            on = r.locked or r.perms.ems_staff == true, locked = r.locked == true, editable = not r.locked and r.level < my }
    end
    table.sort(out.ranks, function(a, b) return a.level > b.level end)
    local onlineLic = {}
    for _, p in ipairs(GetPlayers()) do
        local id = tonumber(p)
        local lic = AM.getLicense(id)
        if lic then onlineLic[lic] = id end
        local ok, why = canUse(id)
        local byRank = AM.hasPerm(id, 'ems_staff')
        if byRank or (lic and Access[lic]) then
            local r = AM.rankOf(id)
            out.online[#out.online + 1] = { id = id, name = GetPlayerName(id), rank = r and r.label or nil, color = r and r.color or nil,
                via = byRank and 'rank' or 'individual', ok = ok, rp = why == 'rp' }
        end
    end
    table.sort(out.online, function(a, b) return a.id < b.id end)
    if canManageStaff then
        for lic, a in pairs(Access) do
            out.individuals[#out.individuals + 1] = { license = lic, name = a.name, by = a.by, date = a.date, online = onlineLic[lic] }
        end
        table.sort(out.individuals, function(a, b) return (a.name or '') < (b.name or '') end)
    end
    data.ems = out
end)

-- Rafraîchit l'onglet quand la ressource EMS démarre ou s'arrête
AddEventHandler('onResourceStart', function(res)
    if res == (CFG.resource or 'elyzea_ems') or res == (CFG.staffResource or 'elyzea_ems_staff') then SetTimeout(1000, refreshViewers) end
end)
AddEventHandler('onResourceStop', function(res)
    if res == (CFG.resource or 'elyzea_ems') or res == (CFG.staffResource or 'elyzea_ems_staff') then SetTimeout(500, refreshViewers) end
end)
