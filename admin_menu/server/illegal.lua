-- =========================================================
--  ILLEGAL - SERVEUR
--  Pont entre le menu et la ressource « elyzea_illegal ».
--  La permission « illegal_staff » et le service staff sont vérifiés
--  par le dispatcher d'actions (server/main.lua) AVANT d'arriver ici ;
--  la ressource Illégal revalide ensuite chaque valeur.
-- =========================================================
local AM = AdminMenu
local RES = (Config.Illegal and Config.Illegal.resource) or 'elyzea_illegal'

local function available() return GetResourceState(RES) == 'started' end

-- Donne la nouvelle permission au SuperAdmin, une seule fois (le Fondateur a toujours tout)
do
    local meta = Storage.load('meta', {})
    if not meta.illegal_v1 then
        if AM.Ranks.superadmin then
            AM.Ranks.superadmin.perms.illegal_staff = true
            Storage.save('ranks', AM.Ranks)
        end
        meta.illegal_v1 = true
        Storage.save('meta', meta)
    end
end

AM.Actions.illegal = { perm = 'illegal_staff', fn = function(src, d)
    if not available() then
        return AM.notify(src, ('La ressource « %s » n\'est pas démarrée.'):format(RES), 'error')
    end
    local ok, success, msg = pcall(function() return exports[RES]:AdminAction(src, tostring(d.name or ''), type(d.data) == 'table' and d.data or {}) end)
    if not ok then
        print(('^1[AdminMenu] Appel Illégal « %s » impossible : %s^7'):format(tostring(d.name), tostring(success)))
        return AM.notify(src, 'Le module illégal ne répond pas.', 'error')
    end
    if msg and msg ~= '' then AM.notify(src, msg, success and 'success' or 'error') end
end }

table.insert(AM.DataHooks, function(src, data)
    if not AM.hasPerm(src, 'illegal_staff') then return end
    if not available() then
        data.illegal = { available = false, resource = RES }
        return
    end
    local ok, d = pcall(function() return exports[RES]:AdminData(src) end)
    data.illegal = ok and d or { available = false, resource = RES, error = true }
end)

-- ---------------------------------------------------------
--  Éditeur de map › Coffres › « Groupes illégaux »
--  Les groupes créés dans l'onglet ILLEGAL s'ajoutent à la liste des gangs
--  Qbox, et leurs membres peuvent ouvrir les coffres qui les autorisent
--  (grade minimum = niveau du grade ILLEGAL). Rien ne change pour les gangs Qbox.
-- ---------------------------------------------------------
local function illegalGroups()
    if not available() then return {} end
    local ok, list = pcall(function() return exports[RES]:GetGroupList() end)
    return ok and type(list) == 'table' and list or {}
end

local function illegalMembership(src)
    if not available() then return nil end
    local ok, g = pcall(function() return exports[RES]:GetPlayerGroup(src) end)
    return ok and type(g) == 'table' and g or nil
end

if Bridge and Bridge.GetGangs then
    local baseGetGangs = Bridge.GetGangs
    Bridge.GetGangs = function(...)
        local base = baseGetGangs(...)
        local extra = illegalGroups()
        if #extra == 0 then return base end
        local out, seen = {}, {}
        for _, g in ipairs(base) do out[#out + 1] = g seen[g.name] = true end   -- copie : la liste Qbox reste en cache intacte
        for _, g in ipairs(extra) do
            if not seen[g.name] then out[#out + 1] = { name = g.name, label = g.label .. ' (Illégal)', grades = g.grades or {} } end
        end
        table.sort(out, function(a, b) return a.label:lower() < b.label:lower() end)
        return out
    end
end

-- Joueur sans gang Qbox : son groupe ILLEGAL compte comme groupe illégal (coffres, annonces des drops)
if Bridge and Bridge.GetGang then
    local baseGetGang = Bridge.GetGang
    Bridge.GetGang = function(src, ...)
        local name, grade = baseGetGang(src, ...)
        if name then return name, grade end
        local g = illegalMembership(src)
        if g then return g.name, g.gradeLevel or 0 end
        return name, grade
    end
end

-- Coffre réservé à certains groupes : un membre d'un groupe ILLEGAL autorisé l'ouvre aussi,
-- même s'il a par ailleurs un gang Qbox
if StashAccess then
    local baseStashAccess = StashAccess
    StashAccess = function(src, st, ...)
        if baseStashAccess(src, st, ...) then return true end
        if not (st and st.gangs and #st.gangs > 0) then return false end
        local g = illegalMembership(src)
        if not g then return false end
        for _, x in ipairs(st.gangs) do
            if x.gang == g.name and (g.gradeLevel or 0) >= (x.grade or 0) then return true end
        end
        return false
    end
end

-- ---------------------------------------------------------
--  Police en service (système existant du menu : Config.PoliceJobs + service)
--  Utilisé par les missions illégales pour prévenir uniquement les policiers en service.
-- ---------------------------------------------------------
exports('GetOnDutyPolice', function()
    local list = {}
    if not (Bridge and Bridge.IsPolice) then return list end
    for _, p in ipairs(GetPlayers()) do
        local id = tonumber(p)
        if Bridge.IsPolice(id) then list[#list + 1] = id end
    end
    return list
end)
