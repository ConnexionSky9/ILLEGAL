-- =========================================================
--  MENU RAPIDE (F9 par défaut) + AFFICHAGE DES MESSAGES PRIVÉS
--  Petit panneau sur le côté : TP au marqueur, noclip, godmode,
--  actions sur un joueur (proches en premier), MP, message staff…
-- =========================================================
local quickOpen = false

function IsQuickOpen() return quickOpen end

-- Joueurs proches (les plus près en premier)
local function nearbyPlayers()
    local list, me = {}, PlayerId()
    local myPos = GetEntityCoords(PlayerPedId())
    for _, pl in ipairs(GetActivePlayers()) do
        if pl ~= me then
            local d = #(GetEntityCoords(GetPlayerPed(pl)) - myPos)
            if d < 150.0 then list[#list + 1] = { id = GetPlayerServerId(pl), dist = math.floor(d) } end
        end
    end
    table.sort(list, function(a, b) return a.dist < b.dist end)
    while #list > 12 do table.remove(list) end
    return list
end

function ToggleQuickMenu(force)
    local want = force
    if want == nil then want = not quickOpen end
    if want == quickOpen then return end
    if want then
        if IsStaffMenuOpen and IsStaffMenuOpen() then return end
        if not MyRank then return Notify("Vous n'avez pas accès au menu staff.", 'error') end
        quickOpen = true
        SetNuiFocus(true, true)
        SetNuiFocusKeepInput(false)
        SendNUIMessage({ action = 'quick', open = true, nearby = nearbyPlayers() })
        TriggerServerEvent('adminmenu:requestData')
    else
        quickOpen = false
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'quick', open = false })
    end
end

RegisterNUICallback('quick_close', function(_, cb)
    ToggleQuickMenu(false)
    cb('ok')
end)

RegisterNUICallback('quick_nearby', function(_, cb)
    cb(nearbyPlayers())
end)

-- « Fiche complète » : ouvre le grand menu sur ce joueur
RegisterNUICallback('quick_full', function(body, cb)
    ToggleQuickMenu(false)
    cb('ok')
    Wait(50)
    if OpenMenuStaff then OpenMenuStaff() end
    SendNUIMessage({ action = 'gotoPlayer', id = tonumber(body and body.id) })
end)

-- Message privé / réponse / discussion staff reçus
RegisterNetEvent('adminmenu:pm', function(p)
    if type(p) ~= 'table' then return end
    SendNUIMessage({ action = 'pm', data = p })
    if p.kind == 'staff' or p.kind == 'reply' or p.kind == 'staffchat' then
        PlaySoundFrontend(-1, 'Text_Arrive_Tone', 'Phone_SoundSet_Default', true)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and quickOpen then SetNuiFocus(false, false) end
end)
