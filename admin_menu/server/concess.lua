-- =========================================================
--  MÉTIERS › CONCESSION - SERVEUR
--  Pont entre le menu et la ressource « elyzea_concess ».
--  La permission « concess_staff » et le service staff sont vérifiés
--  par le dispatcher d'actions (server/main.lua) AVANT d'arriver ici ;
--  la ressource Concession revalide ensuite chaque valeur.
-- =========================================================
local AM = AdminMenu
local RES = (Config.Concess and Config.Concess.resource) or 'elyzea_concess'

local function available() return GetResourceState(RES) == 'started' end

AM.Actions.concess = { perm = 'concess_staff', fn = function(src, d)
    if not available() then
        return AM.notify(src, ('La ressource « %s » n\'est pas démarrée.'):format(RES), 'error')
    end
    local ok, success, msg = pcall(function() return exports[RES]:AdminAction(src, tostring(d.name or ''), type(d.data) == 'table' and d.data or {}) end)
    if not ok then
        print(('^1[AdminMenu] Appel Concession « %s » impossible : %s^7'):format(tostring(d.name), tostring(success)))
        return AM.notify(src, 'La concession ne répond pas.', 'error')
    end
    if msg and msg ~= '' then AM.notify(src, msg, success and 'success' or 'error') end
end }

table.insert(AM.DataHooks, function(src, data)
    if not AM.hasPerm(src, 'concess_staff') then return end
    if not available() then
        data.concess = { available = false, resource = RES }
        return
    end
    local ok, d = pcall(function() return exports[RES]:AdminData() end)
    data.concess = ok and d or { available = false, resource = RES, error = true }
end)
