-- =========================================================
--  VÉHICULES
-- =========================================================

RegisterNetEvent('adminmenu:spawnVehicle', function(model)
    local hash = GetHashKey(model)
    if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then
        return Notify(('Le modèle "%s" n\'existe pas.'):format(model), 'error')
    end

    RequestModel(hash)
    local t = GetGameTimer()
    while not HasModelLoaded(hash) do
        Wait(10)
        if GetGameTimer() - t > 10000 then return Notify('Le modèle met trop de temps à charger.', 'error') end
    end

    if IsNoclipActive() then ToggleNoclip(false) Wait(50) end

    local ped = PlayerPedId()
    local old = GetVehiclePedIsIn(ped, false)
    if old ~= 0 and Config.DeletePreviousVehicle and GetPedInVehicleSeat(old, -1) == ped then
        if NetworkGetEntityIsNetworked(old) then
            TriggerServerEvent('adminmenu:action', 'delete_vehicle', { netId = NetworkGetNetworkIdFromEntity(old) })
        else
            SetEntityAsMissionEntity(old, true, true)
            DeleteVehicle(old)
        end
    end

    local c = GetEntityCoords(ped)
    local veh = CreateVehicle(hash, c.x, c.y, c.z + 0.5, GetEntityHeading(ped), true, false)
    SetVehicleNumberPlateText(veh, Config.VehiclePlate)
    SetVehicleDirtLevel(veh, 0.0)
    SetVehicleEngineOn(veh, true, true, false)
    SetVehicleHasBeenOwnedByPlayer(veh, true)
    SetEntityAsMissionEntity(veh, true, true)
    SetNetworkIdCanMigrate(NetworkGetNetworkIdFromEntity(veh), true)
    SetPedIntoVehicle(ped, veh, -1)
    SetModelAsNoLongerNeeded(hash)

    Notify(('%s est prêt.'):format(GetLabelText(GetDisplayNameFromVehicleModel(hash))), 'success')
end)

local function getTargetVehicle()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 then return veh end
    local c = GetEntityCoords(ped)
    local best, bestDist = 0, 8.0
    for _, v in ipairs(GetGamePool('CVehicle')) do
        local d = #(GetEntityCoords(v) - c)
        if d < bestDist then best, bestDist = v, d end
    end
    return best
end

RegisterNetEvent('adminmenu:vehicleTool', function(tool)
    local veh = getTargetVehicle()
    if veh == 0 then return Notify('Aucun véhicule à moins de 8 m.', 'error') end

    if tool == 'delete' then
        if NetworkGetEntityIsNetworked(veh) then
            TriggerServerEvent('adminmenu:action', 'delete_vehicle', { netId = NetworkGetNetworkIdFromEntity(veh) })
        else
            SetEntityAsMissionEntity(veh, true, true)
            DeleteVehicle(veh)
            Notify('Véhicule supprimé.', 'success')
        end
        return
    end

    RequestControl(veh)

    if tool == 'repair' then
        SetVehicleFixed(veh)
        SetVehicleDeformationFixed(veh)
        SetVehicleEngineHealth(veh, 1000.0)
        SetVehicleBodyHealth(veh, 1000.0)
        SetVehiclePetrolTankHealth(veh, 1000.0)
        SetVehicleUndriveable(veh, false)
        SetVehicleEngineOn(veh, true, true, false)
        Notify('Véhicule réparé.', 'success')

    elseif tool == 'clean' then
        SetVehicleDirtLevel(veh, 0.0)
        WashDecalsFromVehicle(veh, 1.0)
        Notify('Véhicule nettoyé.', 'success')

    elseif tool == 'flip' then
        local r = GetEntityRotation(veh, 2)
        SetEntityRotation(veh, 0.0, 0.0, r.z, 2, true)
        SetVehicleOnGroundProperly(veh)
        Notify('Véhicule remis sur ses roues.', 'success')

    elseif tool == 'upgrade' then
        SetVehicleModKit(veh, 0)
        for i = 0, 16 do
            local n = GetNumVehicleMods(veh, i)
            if n > 0 then SetVehicleMod(veh, i, n - 1, false) end
        end
        ToggleVehicleMod(veh, 18, true) -- turbo
        ToggleVehicleMod(veh, 22, true) -- xénon
        SetVehicleWindowTint(veh, 1)
        SetVehicleTyresCanBurst(veh, false)
        Notify('Véhicule amélioré au maximum.', 'success')

    elseif tool == 'unlock' then
        SetVehicleDoorsLocked(veh, 1)
        SetVehicleDoorsLockedForAllPlayers(veh, false)
        Notify('Véhicule déverrouillé.', 'success')
    end
end)
