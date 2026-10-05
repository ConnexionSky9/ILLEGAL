-- =========================================================
--  MÉTIERS › LSCUSTOM - SERVEUR
--  Pont entre le menu et la ressource « elyzea_lscustom ».
--  La permission « lscustom_staff » et le service staff sont vérifiés
--  par le dispatcher d'actions (server/main.lua) AVANT d'arriver ici ;
--  la ressource LsCustom revalide ensuite chaque valeur.
-- =========================================================
local AM = AdminMenu
local RES = (Config.LsCustom and Config.LsCustom.resource) or 'elyzea_lscustom'

local function available() return GetResourceState(RES) == 'started' end

AM.Actions.lscustom = { perm = 'lscustom_staff', fn = function(src, d)
    if not available() then
        return AM.notify(src, ('La ressource « %s » n\'est pas démarrée.'):format(RES), 'error')
    end
    local ok, success, msg = pcall(function() return exports[RES]:AdminAction(src, tostring(d.name or ''), type(d.data) == 'table' and d.data or {}) end)
    if not ok then
        print(('^1[AdminMenu] Appel LsCustom « %s » impossible : %s^7'):format(tostring(d.name), tostring(success)))
        return AM.notify(src, 'LsCustom ne répond pas.', 'error')
    end
    if msg and msg ~= '' then AM.notify(src, msg, success and 'success' or 'error') end
end }

table.insert(AM.DataHooks, function(src, data)
    if not AM.hasPerm(src, 'lscustom_staff') then return end
    if not available() then
        data.lscustom = { available = false, resource = RES }
        return
    end
    local ok, d = pcall(function() return exports[RES]:AdminData() end)
    data.lscustom = ok and d or { available = false, resource = RES, error = true }
end)
