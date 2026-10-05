-- =========================================================
--  SPECTATE
-- =========================================================
local spectating = false
local specTarget = nil
local returnCoords = nil
local resumeNoclip = false

local function stopSpectate()
    if not spectating then return end
    spectating = false
    specTarget = nil
    local ped = PlayerPedId()

    DoScreenFadeOut(200)
    while not IsScreenFadedOut() do Wait(0) end
    NetworkSetInSpectatorMode(false, ped)
    if returnCoords then
        RequestCollisionAtCoord(returnCoords.x, returnCoords.y, returnCoords.z)
        SetEntityCoords(ped, returnCoords.x, returnCoords.y, returnCoords.z, false, false, false, false)
    end
    FreezeEntityPosition(ped, resumeNoclip) -- reste en l'air si on reprend le noclip
    SetEntityCollision(ped, true, true)
    SetEntityInvincible(ped, State.godmode)
    if not State.invisible then SetEntityVisible(ped, true, false) end
    TriggerServerEvent('adminmenu:spectateEnd')
    Wait(300)
    DoScreenFadeIn(200)
    -- Lancé depuis le noclip : on y retourne, là où on était
    if resumeNoclip then
        resumeNoclip = false
        ToggleNoclip(true)
    end
end

RegisterNetEvent('adminmenu:spectate', function(targetId, coords)
    if spectating then
        local same = specTarget == targetId
        stopSpectate()
        if same then return end
    end
    local ped = PlayerPedId()
    returnCoords = GetEntityCoords(ped)
    resumeNoclip = IsNoclipActive()
    if resumeNoclip then ToggleNoclip(false) Wait(100) end
    ped = PlayerPedId()

    DoScreenFadeOut(200)
    while not IsScreenFadedOut() do Wait(0) end

    SetEntityVisible(ped, false, false)
    SetEntityCollision(ped, false, false)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetEntityCoords(ped, coords.x, coords.y, coords.z - 15.0, false, false, false, false)

    -- Attendre que le joueur cible soit chargé autour de nous
    local pl, t = -1, GetGameTimer()
    while GetGameTimer() - t < 5000 do
        pl = GetPlayerFromServerId(targetId)
        if pl ~= -1 and DoesEntityExist(GetPlayerPed(pl)) then break end
        pl = -1
        Wait(100)
    end

    spectating = true
    if pl == -1 then
        stopSpectate()
        return Notify('Impossible de charger ce joueur.', 'error')
    end

    specTarget = targetId
    NetworkSetInSpectatorMode(true, GetPlayerPed(pl))
    DoScreenFadeIn(200)

    CreateThread(function()
      local ok, err = pcall(function()
        local lastMove = 0
        while spectating do
            Wait(0)
            if not spectating then break end
            local tped = GetPlayerPed(pl)
            if not NetworkIsPlayerActive(pl) or not DoesEntityExist(tped) then
                Notify('Le joueur a quitté la zone ou le serveur.', 'warning')
                stopSpectate()
                break
            end

            -- On garde notre ped sous la cible pour rester dans sa zone de streaming
            if GetGameTimer() - lastMove > 1000 then
                local tc = GetEntityCoords(tped)
                SetEntityCoordsNoOffset(PlayerPedId(), tc.x, tc.y, tc.z - 15.0, false, false, false)
                lastMove = GetGameTimer()
            end

            local veh = GetVehiclePedIsIn(tped, false)
            DrawTxt(0.5, 0.04, ('~y~SPECTATE~s~   %s [%d]'):format(GetPlayerName(pl), targetId), 0.45, true)
            DrawTxt(0.5, 0.075, ('Vie %d   Armure %d   %s'):format(
                math.max(GetEntityHealth(tped) - 100, 0), GetPedArmour(tped),
                veh ~= 0 and ('Véhicule %d km/h'):format(math.floor(GetEntitySpeed(veh) * 3.6)) or 'À pied'
            ), 0.34, true)
            DrawTxt(0.5, 0.1, '~c~[Retour arrière] Quitter le spectate', 0.3, true)

            DisableControlAction(0, 177, true)
            if IsDisabledControlJustPressed(0, 177) then stopSpectate() end
        end
      end)
      if not ok then
          print(('^1[AdminMenu] Erreur spectate : %s^7'):format(tostring(err)))
          stopSpectate() -- on remet toujours le staff à sa place
      end
    end)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() or not spectating then return end
    local ped = PlayerPedId()
    NetworkSetInSpectatorMode(false, ped)
    if returnCoords then SetEntityCoords(ped, returnCoords.x, returnCoords.y, returnCoords.z, false, false, false, false) end
    FreezeEntityPosition(ped, false)
    SetEntityCollision(ped, true, true)
    SetEntityInvincible(ped, false)
    SetEntityVisible(ped, true, false)
    DoScreenFadeIn(0)
end)

-- Utilisé au passage en mode RP
function StopSpectateIfAny()
    if spectating then CreateThread(stopSpectate) end
end
