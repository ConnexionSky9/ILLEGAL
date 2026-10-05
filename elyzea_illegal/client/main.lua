-- =========================================================
--  ELYZEA ILLÉGAL - CLIENT : ÉTAT DU JOUEUR, NOTIFICATIONS
--  Le client ne connaît que ce que le serveur lui envoie ; il
--  n'envoie jamais son groupe ni son grade (le serveur les relit).
-- =========================================================
Membership = { inGroup = false }

-- Notifications : même rendu que celles du MenuStaff (en haut à droite)
local KIND = { inform = 'info', info = 'info', success = 'success', error = 'error', warning = 'warning' }
function Notify(msg, kind)
    SendNUIMessage({ action = 'notify', message = tostring(msg or ''), type = KIND[kind or 'inform'] or 'info' })
end

-- ---------------------------------------------------------
--  Invite d'interaction [E] : même rendu que celle du MenuStaff
--  (« APPUYER POUR … » + nom en doré). Une seule invite à la fois.
-- ---------------------------------------------------------
Prompt = {}
local promptOwner, promptSig
function Prompt.show(owner, verb, name, key, muted)
    if promptOwner and promptOwner ~= owner then return end   -- une autre invite est déjà affichée
    local sig = ('%s|%s|%s|%s'):format(verb, name, key or 'E', tostring(muted))
    promptOwner = owner
    if sig == promptSig then return end
    promptSig = sig
    SendNUIMessage({ action = 'prompt', show = true, key = key or 'E', verb = verb, name = name, muted = muted == true })
end
function Prompt.hide(owner)
    if not promptOwner or (owner and promptOwner ~= owner) then return end
    promptOwner, promptSig = nil, nil
    SendNUIMessage({ action = 'prompt', show = false })
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
