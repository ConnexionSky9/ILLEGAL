-- =========================================================
--  ONGLET ÉVÉNEMENTS › GOFAST - CLIENT
--  Ajoute aux actions qui en ont besoin ce que seul le client
--  connaît (route la plus proche, sol, véhicule du staff).
--  Le serveur vérifie que ces positions sont bien près du staff.
-- =========================================================
local NEEDS_POSITION = {
    contact_create = true, loc_add = true, veh_add = true, dest_add = true, import_ped = true,
}

local function positionExtras(d)
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)

    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 then
        local vc = GetEntityCoords(veh)
        d.vehicle = { x = vc.x, y = vc.y, z = vc.z, h = GetEntityHeading(veh) }
    end

    local found, gz = GetGroundZFor_3dCoord(c.x, c.y, c.z + 1.0, false)
    if found then d.ground = gz end

    -- Point d'apparition automatique : la route la plus proche (type 1 = toutes les routes)
    local ok, node, heading = GetClosestVehicleNodeWithHeading(c.x, c.y, c.z, 1, 3.0, 0)
    if ok and node then d.node = { x = node.x, y = node.y, z = node.z, h = heading } end
end

RegisterNUICallback('gofast', function(body, cb)
    cb({})
    if type(body) ~= 'table' or type(body.name) ~= 'string' then return end
    local d = type(body.data) == 'table' and body.data or {}
    if NEEDS_POSITION[body.name] then
        local placesPed = body.name == 'contact_create' or body.name == 'loc_add'
        if placesPed and GetVehiclePedIsIn(PlayerPedId(), false) ~= 0 then
            return Notify('Descends du véhicule : le PNJ sera placé exactement là où tu te tiens.', 'error')
        end
        positionExtras(d)
    end
    TriggerServerEvent('adminmenu:action', 'gofast_' .. body.name, d)
end)

-- Réponse : permet au menu d'ouvrir directement un contact créé / converti
RegisterNetEvent('adminmenu:gofastReply', function(ok, select, player)
    SendNUIMessage({ action = 'gofastReply', ok = ok, select = select, player = player })
end)
