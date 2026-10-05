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
