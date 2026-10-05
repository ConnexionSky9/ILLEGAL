-- =========================================================
--  ONGLET ÉVÉNEMENTS › GOFAST - SERVEUR
--  Pont entre le menu staff et la ressource « gofast ».
--  Les permissions et le service staff sont vérifiés par le
--  dispatcher d'actions (server/main.lua) AVANT d'arriver ici ;
--  la ressource gofast revalide ensuite chaque valeur.
-- =========================================================
local AM = AdminMenu
local RES = (Config.Events and Config.Events.goFastResource) or 'gofast'

local function available()
    return GetResourceState(RES) == 'started'
end

-- Actions envoyées par le menu -> permission requise
local ACTIONS = {
    toggle = 'gofast_manage', settings = 'gofast_manage', settings_reset = 'gofast_manage',
    tier = 'gofast_manage', tier_reset = 'gofast_manage',
    contact_create = 'gofast_manage', contact_update = 'gofast_manage', contact_delete = 'gofast_manage',
    loc_add = 'gofast_manage', loc_here = 'gofast_manage', loc_rename = 'gofast_manage', loc_remove = 'gofast_manage',
    veh_add = 'gofast_manage', veh_remove = 'gofast_manage', move_now = 'gofast_manage', tp = 'gofast_manage',
    dest_add = 'gofast_manage', dest_update = 'gofast_manage', dest_remove = 'gofast_manage',
    dest_tp = 'gofast_manage', dest_reset = 'gofast_manage',
    mission_stop = 'gofast_missions', mission_tp = 'gofast_missions',
    player_info = 'gofast_missions', player_resetcd = 'gofast_missions',
    player_setxp = 'gofast_missions', player_addxp = 'gofast_missions',
}

local function call(src, name, data)
    if not available() then
        return AM.notify(src, ('La ressource « %s » n\'est pas démarrée.'):format(RES), 'error')
    end
    local ok, err = pcall(function() return exports[RES]:AdminAction(src, name, data) end)
    if not ok then
        print(('^1[AdminMenu] Appel GoFast « %s » impossible : %s^7'):format(name, tostring(err)))
        AM.notify(src, 'GoFast ne répond pas (version trop ancienne ?).', 'error')
    end
end

for name, perm in pairs(ACTIONS) do
    AM.Actions['gofast_' .. name] = {
        perm = perm,
        noRefresh = true, -- le menu est rafraîchi quand gofast répond
        fn = function(src, data) call(src, name, data) end,
    }
end

-- Conversion d'un PNJ de l'éditeur de map en contact GoFast
AM.Actions.gofast_import_ped = {
    perm = 'gofast_manage',
    noRefresh = true,
    fn = function(src, data)
        if not AM.hasPerm(src, 'editor_peds') or AM.getLevel(src) < Config.Editor.minLevel then
            return AM.notify(src, 'Il faut aussi la permission « PNJ persistants » (SuperAdmin+) pour convertir un PNJ.', 'error')
        end
        local ped = AM.EditorPeds and AM.EditorPeds.get(data.pedId)
        if not ped then return AM.notify(src, 'PNJ introuvable.', 'error') end
        if ped.npc then
            return AM.notify(src, 'Ce PNJ a déjà un rôle (achat / vente). Remets-le en « Décor » avant de le convertir.', 'error')
        end
        data.ped = { model = ped.model, x = ped.x, y = ped.y, z = ped.z, h = ped.h, name = ped.name, scenario = ped.scenario }
        data.editorPedId = ped.id
        call(src, 'import_ped', data)
    end,
}

-- Réponse de gofast (évènement serveur local, jamais envoyé par un client)
AddEventHandler('gofast:adminReply', function(src, ok, message, extra)
    src = tonumber(src)
    if not src or src <= 0 or not GetPlayerName(src) then return end
    extra = type(extra) == 'table' and extra or {}

    if ok and extra.teleport then
        TriggerClientEvent('adminmenu:teleport', src, extra.teleport)
    end
    if message and message ~= '' then AM.notify(src, message, ok and 'success' or 'error') end
    if ok and extra.log then AM.addLog(src, 'GoFast : ' .. extra.log, extra.details or '') end

    -- PNJ converti : on retire l'original de l'éditeur (sinon il y aurait deux PNJ au même endroit)
    if ok and extra.select and extra.importedFrom then
        AM.EditorPeds.remove(extra.importedFrom)
    end

    TriggerClientEvent('adminmenu:gofastReply', src, ok == true, extra.select, extra.player)
    AM.sendData(src)
end)

-- Données de l'onglet (seulement pour ceux qui y ont accès)
table.insert(AM.DataHooks, function(src, data)
    if not (AM.hasPerm(src, 'gofast_manage') or AM.hasPerm(src, 'gofast_missions')) then return end
    if not available() then
        data.gofast = { available = false, resource = RES }
        return
    end
    local ok, result = pcall(function() return exports[RES]:AdminGetData() end)
    if ok and type(result) == 'table' then
        data.gofast = result
    else
        data.gofast = { available = false, resource = RES, error = true }
    end
end)

-- Rafraîchit l'onglet des staffs qui le regardent quand gofast (re)démarre
AddEventHandler('onResourceStart', function(res)
    if res ~= RES then return end
    SetTimeout(1000, function()
        for _, p in ipairs(GetPlayers()) do
            local id = tonumber(p)
            if AM.hasPerm(id, 'gofast_manage') or AM.hasPerm(id, 'gofast_missions') then AM.sendData(id) end
        end
    end)
end)
