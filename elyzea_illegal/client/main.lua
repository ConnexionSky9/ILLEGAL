-- =========================================================
--  ELYZEA ILLÉGAL - CLIENT : ÉTAT DU JOUEUR, NOTIFICATIONS
--  Le client ne connaît que ce que le serveur lui envoie ; il
--  n'envoie jamais son groupe ni son grade (le serveur les relit).
-- =========================================================
Membership = { inGroup = false }

function Notify(msg, kind)
    lib.notify({ title = 'Illégal', description = msg, type = kind or 'inform' })
end
RegisterNetEvent('illegal:client:notify', function(msg, kind) Notify(msg, kind) end)

RegisterNetEvent('illegal:client:membership', function(data)
    Membership = type(data) == 'table' and data or { inGroup = false }
end)

-- État demandé au serveur quand le personnage est prêt (ou au démarrage de la ressource)
local function hello() TriggerServerEvent('illegal:server:hello') end
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', hello)
RegisterNetEvent('qbx_core:client:playerLoaded', hello)
RegisterNetEvent('QBCore:Client:OnPlayerUnload', function() Membership = { inGroup = false } end)

CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(500) end
    Wait(1500)
    hello()
end)
