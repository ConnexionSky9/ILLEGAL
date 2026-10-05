-- =========================================================
--  MINI-CARTE (tous les joueurs)
--  Forme et position réglées dans le menu (onglet 🗺️ Carte).
--  Les trois éléments de la mini-carte (carte, masque, flou) sont
--  posés sur le même rectangle : on voit exactement ce rectangle.
-- =========================================================
local saved = nil      -- réglage commun (serveur)
local preview = nil    -- aperçu du staff en cours de réglage
local scaleform = nil

local ALIGN = {
    ['top-right'] = { 'R', 'T' }, ['top-left'] = { 'L', 'T' },
    ['bottom-left'] = { 'L', 'B' }, ['bottom-right'] = { 'R', 'B' },
}

local function current() return preview or saved end

-- Pose les trois éléments de la mini-carte
local function apply()
    local s = current()
    if not s or s.enabled == false then return end

    -- Hauteur en part de l'écran ; largeur calculée pour un carré à l'écran (base 16:9)
    local h = tonumber(s.size) or 0.20
    local w = h * (9 / 16) * ((tonumber(s.widthAdjust) or 100) / 100)
    if s.shape == 'default' then w = h * 0.80 end

    -- Écrans plus larges que 16:9 : on rapproche du bord (même correction que les HUD courants)
    local rx, ry = GetActiveScreenResolution()
    local aspect = rx / math.max(ry, 1)
    local extra = 0.0
    if aspect > 16 / 9 + 0.01 then extra = ((16 / 9) - aspect) / 3.6 end

    local a = ALIGN[s.position] or ALIGN['top-right']
    local mx, my = tonumber(s.marginX) or 0.012, tonumber(s.marginY) or 0.018
    -- Chaque élément est collé au bord choisi ; le décalage l'en éloigne
    local x = (a[1] == 'R') and -(mx + extra) or (mx + extra)
    local y = (a[2] == 'T') and my or -my

    SetMinimapClipType(s.shape == 'round' and 1 or 0)
    SetMinimapComponentPosition('minimap', a[1], a[2], x, y, w, h)
    SetMinimapComponentPosition('minimap_mask', a[1], a[2], x, y, w, h)
    SetMinimapComponentPosition('minimap_blur', a[1], a[2], x - (a[1] == 'R' and 0.004 or -0.004), y, w + 0.008, h + 0.012)

    -- La position ne se met à jour qu'après un passage en grande carte
    SetBigmapActive(true, false)
    Wait(0)
    SetBigmapActive(false, false)
end

local function hideHealthBars()
    if not scaleform or not HasScaleformMovieLoaded(scaleform) then
        scaleform = RequestScaleformMovie('minimap')
        local t = GetGameTimer()
        while not HasScaleformMovieLoaded(scaleform) and GetGameTimer() - t < 2000 do Wait(0) end
    end
    BeginScaleformMovieMethod(scaleform, 'SETUP_HEALTH_ARMOUR')
    ScaleformMovieMethodAddParamInt(3)
    EndScaleformMovieMethod()
end

-- Entretien : barres de vie cachées, mini-carte seulement en véhicule
CreateThread(function()
    local lastVeh = nil
    while true do
        local s = current()
        if s and s.enabled ~= false then
            if s.hideHealthBars then hideHealthBars() end
            if s.onlyInVehicle then
                local inVeh = IsPedInAnyVehicle(PlayerPedId(), false)
                if inVeh ~= lastVeh then DisplayRadar(inVeh) lastVeh = inVeh end
            elseif lastVeh == false then
                DisplayRadar(true)
                lastVeh = nil
            end
        end
        Wait(500)
    end
end)

-- Après la connexion, d'autres scripts reposent leur propre mini-carte (souvent sauvegardée sur le PC
-- du joueur) : on repasse plusieurs fois derrière eux pour que la position du staff gagne toujours.
local enforceToken = 0
local function enforce()
    enforceToken = enforceToken + 1
    local token = enforceToken
    CreateThread(function()
        for _, delay in ipairs({ 0, 2000, 6000, 15000, 30000, 60000 }) do
            Wait(delay)
            if token ~= enforceToken then return end
            if not preview and not IsBigmapActive() then apply() end
        end
    end)
end

RegisterNetEvent('adminmenu:map', function(data)
    local hadOnly = saved and saved.onlyInVehicle
    saved = data and data.minimap or saved
    if hadOnly and not (saved and saved.onlyInVehicle) then DisplayRadar(true) end
    if not preview then enforce() end
end)

-- ---------------------------------------------------------
--  Commandes d'autres scripts qui déplacent la mini-carte (/carte…) : neutralisées
-- ---------------------------------------------------------
local Blocked = {}   -- { command, resource }

local function blockCommands()
    if not saved or saved.enabled == false then return end
    local owners = {}
    for _, c in ipairs(GetRegisteredCommands() or {}) do owners[c.name] = c.resource end
    Blocked = {}
    for _, name in ipairs((Config.Minimap and Config.Minimap.blockCommands) or {}) do
        local owner = owners[name]
        if owner and owner ~= GetCurrentResourceName() then
            Blocked[#Blocked + 1] = { command = name, resource = owner }
            RegisterCommand(name, function()
                Notify('La mini-carte est placée par le staff : elle ne peut plus être déplacée.', 'info')
                enforce()
            end, false)
        end
    end
end

CreateThread(function()
    Wait(10000)   -- laisse les autres ressources enregistrer leurs commandes
    blockCommands()
    -- Une autre ressource gère aussi la mini-carte : on vérifie la position chaque minute
    while true do
        Wait(60000)
        if #Blocked > 0 and not preview and not IsBigmapActive() and saved and saved.enabled ~= false then apply() end
    end
end)
AddEventHandler('onClientResourceStart', function(res)
    if res ~= GetCurrentResourceName() then SetTimeout(3000, function() blockCommands() enforce() end) end
end)

RegisterNUICallback('minimap_conflicts', function(_, cb)
    cb({ list = Blocked })
end)

-- Le changement de résolution déplace la mini-carte : on la repose de temps en temps
CreateThread(function()
    local lastRes = nil
    while true do
        local rx, ry = GetActiveScreenResolution()
        local res = rx .. 'x' .. ry
        if res ~= lastRes then lastRes = res apply() end
        Wait(5000)
    end
end)

AddEventHandler('onClientResourceStart', function(res)
    if res == GetCurrentResourceName() then TriggerServerEvent('adminmenu:map:request') end
end)
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function() SetTimeout(2000, function() TriggerServerEvent('adminmenu:map:request') end) end)
AddEventHandler('playerSpawned', function() enforce() end)
RegisterNetEvent('esx:playerLoaded', function() SetTimeout(2000, function() TriggerServerEvent('adminmenu:map:request') end) end)

-- ---------------------------------------------------------
--  Aperçu en direct pour le staff (onglet Carte)
-- ---------------------------------------------------------
RegisterNUICallback('minimap_preview', function(body, cb)
    cb('ok')
    if type(body) ~= 'table' then return end
    preview = body
    CreateThread(apply)
end)

RegisterNUICallback('minimap_preview_end', function(_, cb)
    cb('ok')
    preview = nil
    CreateThread(apply)
end)
