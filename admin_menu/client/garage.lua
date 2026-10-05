-- =========================================================
--  GARAGES SUR PNJ - CLIENT (tous les joueurs)
--  Sortie : menu du PNJ (onglet « Garage »). Le véhicule est créé
--  par le serveur sur un point de sortie libre.
--  Rangement : au volant, près du PNJ ou d'un point de sortie, E.
-- =========================================================
local G = Config.Garages or {}
local Mine = {}        -- [netId] = idPNJ (véhicules sortis par moi)
local Blips = {}       -- [idPNJ] = blip

local function vehicleType(model)
    local hash = GetHashKey(model)
    local class = GetVehicleClassFromName(hash)
    if class == 15 then return 'heli' end
    if class == 16 then return 'plane' end
    if class == 21 then return 'train' end
    if class == 8 or class == 13 then return 'bike' end
    if class == 14 then
        if model == 'submersible' or model == 'submersible2' or model == 'kosatka' then return 'submarine' end
        return 'boat'
    end
    if IsThisModelATrain and IsThisModelATrain(hash) then return 'train' end
    return 'automobile'
end

local function pedById(id)
    for _, r in ipairs(Editor.peds or {}) do if r.id == id then return r end end
end

-- Menu du PNJ : boutons « Sortir » et « Ranger »
RegisterNUICallback('npc_garage_take', function(d, cb)
    cb('ok')
    local r = pedById(tonumber(d.id))
    local v = r and r.npc and r.npc.garage and r.npc.garage.vehicles[tonumber(d.idx) or 0]
    if not v then return end
    NpcOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'npcClose' })
    TriggerServerEvent('adminmenu:garage:take', r.id, tonumber(d.idx), vehicleType(v.model))
end)
RegisterNUICallback('npc_garage_store', function(d, cb)
    cb('ok')
    NpcOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'npcClose' })
    TriggerServerEvent('adminmenu:garage:store', tonumber(d.netId))
end)

RegisterNetEvent('adminmenu:garage:spawned', function(netId, plate, fuel, warp, pedId)
    Mine[netId] = pedId
    local t = GetGameTimer()
    while not NetworkDoesNetworkIdExist(netId) and GetGameTimer() - t < 4000 do Wait(50) end
    local veh = NetworkDoesNetworkIdExist(netId) and NetToVeh(netId) or 0
    if veh == 0 then return end
    t = GetGameTimer()
    while not NetworkHasControlOfEntity(veh) and GetGameTimer() - t < 1500 do NetworkRequestControlOfEntity(veh) Wait(50) end
    SetVehicleNumberPlateText(veh, plate)
    SetVehicleFuelLevel(veh, (fuel or 100) + 0.0)
    SetVehicleOnGroundProperly(veh)
    SetVehicleHasBeenOwnedByPlayer(veh, true)
    SetVehicleEngineOn(veh, false, true, true)
    if warp then TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1) end
end)
RegisterNetEvent('adminmenu:garage:stored', function(netId) Mine[netId] = nil end)

-- Rangement au volant
CreateThread(function()
    local radius = G.storeRadius or 25.0
    local shown = false
    while true do
        local sleep = 800
        local wasShown = shown
        shown = false
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped and next(Mine) then
            local netId = NetworkGetNetworkIdFromEntity(veh)
            local pedId = Mine[netId]
            local r = pedId and pedById(pedId)
            if r and r.npc and r.npc.garage then
                local c = GetEntityCoords(veh)
                local close = #(c - vector3(r.x, r.y, r.z)) <= radius
                for _, s in ipairs(r.npc.garage.spots or {}) do
                    if close then break end
                    close = #(c - vector3(s.x, s.y, s.z)) <= radius
                end
                if close then
                    sleep = 0
                    shown = true
                    ShowPrompt('Appuyer pour ranger le véhicule', (r.name and r.name ~= '' and r.name or 'Garage'), false, 'garage')
                    if IsControlJustReleased(0, 38) then
                        HidePrompt('garage') shown = false
                        TaskLeaveVehicle(ped, veh, 0)
                        Wait(1600)
                        TriggerServerEvent('adminmenu:garage:store', netId)
                    end
                end
            end
        end
        if wasShown and not shown then HidePrompt('garage') end
        Wait(sleep)
    end
end)

-- Icônes des garages sur la carte (si « Visible sur la carte » est coché)
CreateThread(function()
    while true do
        local seen = {}
        for _, r in ipairs(Editor.peds or {}) do
            local g = r.npc and (r.npc.garage or r.npc.pubgarage)
            if g and g.blip then
                seen[r.id] = true
                local b = Blips[r.id]
                local sig = ('%.1f%.1f%d%d%s'):format(r.x, r.y, g.blipSprite or 357, g.blipColor or 3, r.name or '')
                if not b or b.sig ~= sig then
                    if b then RemoveBlip(b.id) end
                    local id = AddBlipForCoord(r.x, r.y, r.z)
                    SetBlipSprite(id, g.blipSprite or G.blipSprite or 357)
                    SetBlipColour(id, g.blipColor or G.blipColor or 3)
                    SetBlipScale(id, 0.8)
                    SetBlipAsShortRange(id, true)
                    BeginTextCommandSetBlipName('STRING')
                    AddTextComponentSubstringPlayerName(r.npc.pubgarage and (r.npc.pubgarage.name or 'Garage public') or ((r.name and r.name ~= '') and r.name or 'Garage'))
                    EndTextCommandSetBlipName(id)
                    Blips[r.id] = { id = id, sig = sig }
                end
            end
        end
        for id, b in pairs(Blips) do
            if not seen[id] then RemoveBlip(b.id) Blips[id] = nil end
        end
        Wait(4000)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, b in pairs(Blips) do RemoveBlip(b.id) end
end)

-- =========================================================
--  GARAGES PUBLICS : zones de rangement (cercle rouge, E au volant)
-- =========================================================
CreateThread(function()
    local shown = false
    while true do
        local sleep = 800
        local wasShown = shown
        shown = false
        local ped = PlayerPedId()
        local pc = GetEntityCoords(ped)
        local veh = GetVehiclePedIsIn(ped, false)
        local driving = veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped
        for _, r in ipairs(Editor.peds or {}) do
            local pg = r.npc and r.npc.pubgarage
            if pg and pg.stores then
                local radius = pg.storeRadius or 4.0
                for i, z in ipairs(pg.stores) do
                    local d = #(pc - vector3(z.x, z.y, z.z))
                    if d < 40.0 then
                        sleep = 0
                        DrawMarker(1, z.x, z.y, z.z - 0.98, 0, 0, 0, 0, 0, 0, radius * 2.0, radius * 2.0, 0.4, 224, 67, 59, 110, false, false, 2, false, nil, nil, false)
                        DrawMarker(25, z.x, z.y, z.z - 0.95, 0, 0, 0, 0, 0, 0, radius * 1.8, radius * 1.8, 1.0, 255, 120, 110, 120, false, false, 2, false, nil, nil, false)
                        if driving and d <= radius + 0.5 and not shown then
                            shown = true
                            ShowPrompt('Appuyer pour ranger le véhicule', pg.name or 'Garage public', false, 'pubstore')
                            if IsControlJustReleased(0, 38) then
                                HidePrompt('pubstore') shown = false
                                TriggerServerEvent('adminmenu:pubgarage:storeZone', r.id, i)
                                Wait(1500)
                            end
                        end
                    end
                end
            end
        end
        if wasShown and not shown then HidePrompt('pubstore') end
        Wait(sleep)
    end
end)
