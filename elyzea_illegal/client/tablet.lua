-- =========================================================
--  ELYZEA ILLÉGAL - CLIENT : TABLETTE (NUI)
--  Simple relais : les données viennent du serveur, les actions y
--  repartent telles quelles et y sont toutes revérifiées.
-- =========================================================
local open = false
function IsTabletOpen() return open end

local function close(notifyServer)
    if not open then return end
    open = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    if notifyServer then TriggerServerEvent('illegal:server:close') end
end

RegisterNetEvent('illegal:client:openTablet', function(data)
    open = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', data = data })
end)

RegisterNetEvent('illegal:client:tablet', function(data)
    if open then SendNUIMessage({ action = 'data', data = data }) end
end)

RegisterNetEvent('illegal:client:close', function() close(false) end)

RegisterNUICallback('close', function(_, cb) close(true) cb('ok') end)

RegisterNUICallback('action', function(body, cb)
    cb('ok')
    if not open or type(body) ~= 'table' or type(body.name) ~= 'string' then return end
    TriggerServerEvent('illegal:server:action', body.name, type(body.data) == 'table' and body.data or {})
end)

RegisterNUICallback('history', function(body, cb)
    local list = lib.callback.await('illegal:server:history', false, body and body.before)
    cb(list or {})
end)

-- La tablette se ferme si le joueur meurt (l'éloignement du PNJ est contrôlé par le serveur)
CreateThread(function()
    while true do
        Wait(open and 500 or 2000)
        if open and IsEntityDead(PlayerPedId()) then close(true) end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and open then SetNuiFocus(false, false) end
end)
