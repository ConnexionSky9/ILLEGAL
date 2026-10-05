-- =========================================================
--  PRISON (jail)
--  Message permanent avec le temps restant, ramené au point de jail
--  s'il s'éloigne, renvoyé à sa position d'origine à la fin.
-- =========================================================
local JC = Config.Jail
local jail = nil  -- { x, y, z, h, endsAt, reason }

function IsJailed() return jail ~= nil end

local function fmt(sec)
    sec = math.max(0, math.floor(sec))
    return ('%02d:%02d'):format(math.floor(sec / 60), sec % 60)
end

local function hud()
    if not jail then return SendNUIMessage({ action = 'jailhud', show = false }) end
    SendNUIMessage({ action = 'jailhud', show = true, time = fmt((jail.endsAt - GetGameTimer()) / 1000), reason = jail.reason })
end

RegisterNetEvent('adminmenu:jail:start', function(p, remaining, reason)
    local first = jail == nil
    jail = { x = p.x, y = p.y, z = p.z, h = p.h or 0.0, endsAt = GetGameTimer() + remaining * 1000, reason = reason }
    if IsNoclipActive() then ToggleNoclip(false) end
    TeleportTo(vector3(p.x, p.y, p.z), false)
    SetEntityHeading(PlayerPedId(), p.h or 0.0)
    hud()
    if not first then return end
    Notify(('⛓️ Tu es en prison pour %s. Raison : %s'):format(fmt(remaining), reason), 'warning')

    CreateThread(function()
        local nextHud, nextCheck = 0, 0
        while jail do
            Wait(0)
            local j = jail
            if not j then break end
            local now = GetGameTimer()
            if JC.disableWeapons then
                DisablePlayerFiring(PlayerId(), true)
                DisableControlAction(0, 24, true)
                DisableControlAction(0, 25, true)
                DisableControlAction(0, 140, true)
                DisableControlAction(0, 141, true)
                DisableControlAction(0, 142, true)
            end
            if now > nextHud then nextHud = now + 1000 hud() end
            if now > nextCheck then
                nextCheck = now + 500
                local ped = PlayerPedId()
                local c = GetEntityCoords(ped)
                local dx, dy = c.x - j.x, c.y - j.y
                if dx * dx + dy * dy > JC.radius * JC.radius or math.abs(c.z - j.z) > 30.0 then
                    local veh = GetVehiclePedIsIn(ped, false)
                    if veh ~= 0 then TaskLeaveVehicle(ped, veh, 16) end
                    TeleportTo(vector3(j.x, j.y, j.z), false)
                    Notify('Tu ne peux pas quitter la prison avant la fin de ta peine.', 'error')
                end
            end
        end
        SendNUIMessage({ action = 'jailhud', show = false })
    end)
end)

RegisterNetEvent('adminmenu:jail:sync', function(remaining)
    if jail then jail.endsAt = GetGameTimer() + remaining * 1000 end
end)

RegisterNetEvent('adminmenu:jail:end', function(ret)
    jail = nil
    SendNUIMessage({ action = 'jailhud', show = false })
    if ret then
        CreateThread(function()
            TeleportTo(vector3(ret.x, ret.y, ret.z), false)
            SetEntityHeading(PlayerPedId(), ret.h or 0.0)
        end)
    end
    Notify('Tu es libre ! Tu as été ramené là où tu étais.', 'success')
end)

-- Vérification au chargement (reconnexion pendant une peine, redémarrage de la ressource)
local function check() SetTimeout(4000, function() TriggerServerEvent('adminmenu:jail:check') end) end
RegisterNetEvent('esx:playerLoaded', check)
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', check)
RegisterNetEvent('qbx_core:client:playerLoaded', check)
AddEventHandler('playerSpawned', check)
AddEventHandler('onClientResourceStart', function(res)
    if res == GetCurrentResourceName() then check() end
end)
