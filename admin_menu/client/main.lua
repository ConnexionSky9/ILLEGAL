-- =========================================================
--  ADMIN MENU - CLIENT PRINCIPAL
-- =========================================================
Perms   = {}
MyRank  = nil
MyLevel = 0
State   = { godmode = false, invisible = false, showIds = false, wallhack = false, showZones = false,
            duty = GetResourceKvpInt('adminmenu_rp_mode') ~= 1 } -- service staff (mémorisé entre les sessions)
local menuOpen = false

function HasPerm(p) return Perms[p] == true end

function Notify(msg, typ)
    SendNUIMessage({ action = 'notify', message = msg, type = typ or 'info' })
end

-- ---------------------------------------------------------
--  Dessin
-- ---------------------------------------------------------
function DrawTxt(x, y, text, scale, center)
    SetTextFont(4)
    SetTextScale(scale, scale)
    SetTextColour(255, 255, 255, 230)
    SetTextOutline()
    SetTextCentre(center == true)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(x, y)
end

function DrawText3D(coords, text, scale)
    scale = scale or 0.35
    SetDrawOrigin(coords.x, coords.y, coords.z, 0)
    SetTextFont(4)
    SetTextScale(scale, scale)
    SetTextColour(255, 255, 255, 230)
    SetTextOutline()
    SetTextCentre(true)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

function RequestControl(ent)
    local t = GetGameTimer()
    NetworkRequestControlOfEntity(ent)
    while not NetworkHasControlOfEntity(ent) and GetGameTimer() - t < 1500 do
        Wait(10)
        NetworkRequestControlOfEntity(ent)
    end
    return NetworkHasControlOfEntity(ent)
end

-- ---------------------------------------------------------
--  Téléportation
-- ---------------------------------------------------------
function TeleportTo(c, findGround)
    local ped = PlayerPedId()
    local ent = GetVehiclePedIsIn(ped, false)
    if ent == 0 or GetPedInVehicleSeat(ent, -1) ~= ped then ent = ped end

    DoScreenFadeOut(250)
    while not IsScreenFadedOut() do Wait(0) end

    local x, y, z = c.x + 0.0, c.y + 0.0, c.z + 0.0
    RequestCollisionAtCoord(x, y, z)

    if findGround then
        local found = false
        for h = 950.0, 0.0, -25.0 do
            SetEntityCoordsNoOffset(ent, x, y, h, false, false, false)
            RequestCollisionAtCoord(x, y, h)
            Wait(15)
            local ok, gz = GetGroundZFor_3dCoord(x, y, h, false)
            if ok then z = gz + 1.0 found = true break end
        end
        if not found then z = 100.0 end
    end

    SetEntityCoords(ent, x, y, z, false, false, false, false)
    local t = GetGameTimer()
    while not HasCollisionLoadedAroundEntity(ent) and GetGameTimer() - t < 3000 do Wait(0) end
    DoScreenFadeIn(250)
end

-- /tpc x y z  (accepte aussi vector3(…), vector4(…), « x, y, z » ; sans Z : au sol)
local function parseCoordsText(text)
    text = tostring(text or ''):gsub('vector[234]%s*%(', '('):gsub('[xyzwhXYZWH]%s*[=:]', ' ')
    local nums = {}
    for n in text:gmatch('%-?%d+%.?%d*') do nums[#nums + 1] = tonumber(n) end
    if #nums < 2 or not nums[1] or not nums[2] then return nil end
    if math.abs(nums[1]) > 10000 or math.abs(nums[2]) > 10000 then return nil end
    local z = nums[3]
    if z and (z < -300 or z > 3000) then return nil end
    return nums[1], nums[2], z
end

RegisterCommand((Config.Messages and Config.Messages.commands.tpCoords) or 'tpc', function(_, args)
    if not MyRank or not HasPerm('tp_coords') then return Notify("Tu n'as pas la permission de te téléporter à des coordonnées.", 'error') end
    if DutyBlocked() then return end
    local x, y, z = parseCoordsText(table.concat(args, ' '))
    if not x then return Notify('Utilisation : /tpc x y z  (ou colle vector3(…)). Sans Z, tu es posé au sol.', 'error') end
    SelfAction('tp_coords', { x = x, y = y, z = z })
end, false)
TriggerEvent('chat:addSuggestion', '/' .. ((Config.Messages and Config.Messages.commands.tpCoords) or 'tpc'), 'Staff : se téléporter à des coordonnées',
    { { name = 'x', help = 'X (ou colle vector3(...))' }, { name = 'y', help = 'Y' }, { name = 'z', help = 'Z (facultatif : au sol)' } })

local function teleportToWaypoint()
    local blip = GetFirstBlipInfoId(8)
    if not DoesBlipExist(blip) then return Notify('Aucun marqueur sur la carte.', 'error') end
    TeleportTo(GetBlipInfoIdCoord(blip), true)
    TriggerServerEvent('adminmenu:logSelf', 'tp_waypoint')
end

-- ---------------------------------------------------------
--  Menu
-- ---------------------------------------------------------
local permsAsked = 0
local function openMenu()
    if not MyRank then
        -- Les permissions ont peut-être été perdues au démarrage : on les redemande une fois
        if GetGameTimer() - permsAsked > 3000 then
            permsAsked = GetGameTimer()
            TriggerServerEvent('adminmenu:requestPerms')
            CreateThread(function()
                local t = GetGameTimer() + 2000
                while not MyRank and GetGameTimer() < t do Wait(50) end
                if MyRank then openMenu() else Notify("Vous n'avez pas accès au menu staff.", 'error') end
            end)
            return
        end
        return Notify("Vous n'avez pas accès au menu staff.", 'error')
    end
    if IsQuickOpen and IsQuickOpen() then ToggleQuickMenu(false) end
    menuOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open' })
    TriggerServerEvent('adminmenu:requestData')
end

function OpenMenuStaff() if not menuOpen then openMenu() end end
function IsStaffMenuOpen() return menuOpen end

function CloseMenu()
    menuOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function selfState()
    return {
        noclip = IsNoclipActive(), godmode = State.godmode, invisible = State.invisible,
        showIds = State.showIds, wallhack = State.wallhack == true, showZones = State.showZones == true,
        duty = State.duty, transformed = TransformedInto and TransformedInto() or nil,
    }
end

-- ---------------------------------------------------------
--  Actions personnelles (utilisées par le menu ET les raccourcis)
-- ---------------------------------------------------------
function SelfAction(name, d)
    d = d or {}
    local ped = PlayerPedId()
    local result = {}

    if name == 'duty' then
        SetDuty(not State.duty)
        result.self = selfState()
        return result
    end
    if name ~= 'coords' and name ~= 'open_keybinds' and name ~= 'human' and DutyBlocked() then
        result.self = selfState()
        return result
    end

    if name == 'noclip' and HasPerm('noclip') then
        if menuOpen then CloseMenu() end
        ToggleNoclip()

    elseif name == 'godmode' and HasPerm('godmode') then
        State.godmode = not State.godmode
        if not State.godmode and not IsNoclipActive() then
            SetEntityInvincible(ped, false)
            SetPlayerInvincible(PlayerId(), false)
        end
        Notify(State.godmode and 'Godmode activé.' or 'Godmode désactivé.', 'success')
        TriggerServerEvent('adminmenu:logSelf', State.godmode and 'godmode_on' or 'godmode_off')

    elseif name == 'invisible' and HasPerm('invisible') then
        State.invisible = not State.invisible
        if not State.invisible then
            SetEntityVisible(ped, true, false)
            ResetEntityAlpha(ped)
        end
        Notify(State.invisible and 'Vous êtes invisible.' or 'Vous êtes visible.', 'success')
        TriggerServerEvent('adminmenu:logSelf', State.invisible and 'invisible_on' or 'invisible_off')

    elseif name == 'showIds' and HasPerm('player_ids') then
        State.showIds = not State.showIds
        Notify(State.showIds and 'Noms et IDs affichés.' or 'Noms et IDs masqués.', 'info')

    elseif name == 'transform' then
        if menuOpen then CloseMenu() end
        TransformInto(d.model)

    elseif name == 'human' then
        if menuOpen then CloseMenu() end
        RevertTransform()

    elseif name == 'showZones' then
        State.showZones = not State.showZones
        Notify(State.showZones and 'Limites des zones affichées.' or 'Limites des zones masquées.', 'info')

    elseif name == 'wallhack' and HasPerm('wallhack') then
        SetWallhack(not State.wallhack)

    elseif name == 'tp_waypoint' and HasPerm('tp_waypoint') then
        if menuOpen then CloseMenu() end
        CreateThread(teleportToWaypoint)

    elseif name == 'tp_coords' and HasPerm('tp_coords') then
        local x, y, z = tonumber(d.x), tonumber(d.y), tonumber(d.z)
        if not x or not y then
            Notify('Coordonnées invalides.', 'error')
        else
            if menuOpen then CloseMenu() end
            CreateThread(function() TeleportTo(vector3(x, y, z or 0.0), z == nil) end)
            TriggerServerEvent('adminmenu:logSelf', 'tp_coords', ('%.1f, %.1f, %.1f'):format(x, y, z or 0.0))
        end

    elseif name == 'coords' then
        local c, h = GetEntityCoords(ped), GetEntityHeading(ped)
        result.coords = ('vector4(%.2f, %.2f, %.2f, %.2f)'):format(c.x, c.y, c.z, h)

    elseif name == 'revive_preview' and HasPerm('revive_area') then
        if menuOpen then CloseMenu() end
        StartRevivePreview(tonumber(d.radius))

    elseif name == 'open_keybinds' then
        if menuOpen then CloseMenu() end
        ActivateFrontendMenu(GetHashKey('FE_MENU_VERSION_LANDING_KEYMAPPING_MENU'), false, -1)
    end

    result.self = selfState()
    return result
end

-- ---------------------------------------------------------
--  SERVICE STAFF / MODE RP
--  Hors service : toutes les fonctions staff sont coupées (noclip,
--  godmode, wallhack…), les raccourcis ne font rien, et tu ne reçois
--  plus les alertes de reports. Le choix est mémorisé.
-- ---------------------------------------------------------
function SetDuty(on, silent)
    State.duty = on == true
    SetResourceKvpInt('adminmenu_rp_mode', State.duty and 0 or 1)
    if not State.duty then
        if IsNoclipActive() then ToggleNoclip(false) end
        if CancelStaffModes then CancelStaffModes() end
        if State.wallhack and SetWallhack then SetWallhack(false) end
        local ped = PlayerPedId()
        if State.godmode then
            State.godmode = false
            SetEntityInvincible(ped, false)
            SetPlayerInvincible(PlayerId(), false)
        end
        if State.invisible then
            State.invisible = false
            SetEntityVisible(ped, true, false)
            ResetEntityAlpha(ped)
        end
        State.showIds, State.showZones = false, false
    end
    TriggerServerEvent('adminmenu:duty', State.duty, silent)
    if not silent then
        Notify(State.duty and 'Service staff : activé. Toutes tes fonctions sont disponibles.'
            or 'Mode RP : fonctions staff désactivées. Bon jeu !', State.duty and 'success' or 'info')
    end
end

function DutyBlocked()
    if State.duty then return false end
    Notify('Tu es en mode RP. Reprends ton service staff (menu F10) pour utiliser ça.', 'error')
    return true
end

-- ---------------------------------------------------------
--  Raccourcis généraux (tous modifiables dans les paramètres)
-- ---------------------------------------------------------
local KEY_ACTIONS = {
    adminmenu       = function() if menuOpen then CloseMenu() else openMenu() end end,
    admin_quick     = function() if ToggleQuickMenu then ToggleQuickMenu() end end,
    admin_duty      = function() SetDuty(not State.duty) end,
    admin_human     = function() RevertTransform() end,
    adminnoclip     = function() SelfAction('noclip') end,
    admin_wallhack  = function() SelfAction('wallhack') end,
    admin_godmode   = function() SelfAction('godmode') end,
    admin_invisible = function() SelfAction('invisible') end,
    admin_ids       = function() SelfAction('showIds') end,
    admin_tpm       = function() SelfAction('tp_waypoint') end,
    admin_repair    = function() TriggerServerEvent('adminmenu:action', 'vehicle_tool', { tool = 'repair' }) end,
    admin_revive_me = function() TriggerServerEvent('adminmenu:action', 'revive', { target = GetPlayerServerId(PlayerId()) }) end,
    admin_revive_area = function() StartRevivePreview(Config.ReviveAreaRadius) end,
}

for _, k in ipairs(Config.Keys) do
    local fn = KEY_ACTIONS[k.cmd]
    if fn then
        RegisterCommand(k.cmd, function()
            if not MyRank then
                if k.cmd == 'adminmenu' then Notify("Vous n'avez pas accès au menu staff.", 'error') end
                return
            end
            if k.cmd ~= 'adminmenu' and k.cmd ~= 'admin_duty' and k.cmd ~= 'admin_quick' and DutyBlocked() then return end
            fn()
        end, false)
        RegisterKeyMapping(k.cmd, 'Staff - ' .. k.label, k.mapper or 'keyboard', k.key or '')
    end
end

-- Touche actuellement assignée à une commande (nil si non lisible)
local MOUSE_LABELS = { b_100 = 'MOUSE_LEFT', b_101 = 'MOUSE_RIGHT', b_102 = 'MOUSE_MIDDLE' }
function CurrentKey(cmd)
    local s = GetControlInstructionalButton(0, GetHashKey(cmd) | 0x80000000, true)
    if type(s) ~= 'string' then return nil end
    if s:sub(1, 2) == 't_' then return s:sub(3) end
    return MOUSE_LABELS[s]
end

-- ---------------------------------------------------------
--  Liste des touches en bas à droite (noclip, placement, aperçus…)
--  owner : qui affiche la liste ; elle n'est renvoyée à l'interface
--  que si son contenu change (aucun envoi à chaque image).
-- ---------------------------------------------------------
HudOwner = nil
local hudSig = nil
function ShowKeysHud(owner, title, rows, footer)
    local parts = { owner, title, footer or '' }
    for i = 1, #rows do parts[#parts + 1] = table.concat(rows[i].keys, ',') .. '=' .. rows[i].label end
    local sig = table.concat(parts, '|')
    HudOwner = owner
    if sig == hudSig then return end
    hudSig = sig
    SendNUIMessage({ action = 'keyshud', show = true, title = title, rows = rows, footer = footer })
end
function HideKeysHud()
    HudOwner, hudSig = nil, nil
    SendNUIMessage({ action = 'keyshud', show = false })
end

local function keyList()
    local list = {}
    for _, k in ipairs(Config.Keys) do
        list[#list + 1] = { group = 'Général', label = k.label, default = k.key, current = CurrentKey(k.cmd) }
    end
    for _, k in ipairs(Config.NoclipKeys) do
        list[#list + 1] = { group = 'Noclip', label = k.label, default = k.key, current = CurrentKey('+admin_nc_' .. k.id) }
    end
    for _, k in ipairs(Config.EditorKeys) do
        list[#list + 1] = { group = 'Placement (éditeur de map)', label = k.label, default = k.key, current = CurrentKey('+admin_ed_' .. k.id) }
    end
    list[#list + 1] = { group = 'Joueurs', label = 'Récolter', default = Config.HarvestKey.key, current = CurrentKey('+harvest_plant') }
    return list
end

local dutySent = false
RegisterNetEvent('adminmenu:setPerms', function(rank, perms, level)
    MyRank = rank
    Perms = perms or {}
    MyLevel = level or 0
    if MyRank and not dutySent then
        dutySent = true
        SetDuty(State.duty, true)
    end
    if not HasPerm('wallhack') and State.wallhack then SetWallhack(false) end
    if not MyRank then
        if IsNoclipActive() then ToggleNoclip(false) end
        State.godmode, State.showIds = false, false
        if State.invisible then
            State.invisible = false
            SetEntityVisible(PlayerPedId(), true, false)
            ResetEntityAlpha(PlayerPedId())
        end
        SetEntityInvincible(PlayerPedId(), false)
        if menuOpen then CloseMenu() end
    elseif menuOpen then
        TriggerServerEvent('adminmenu:requestData')
    end
end)

RegisterNetEvent('adminmenu:data', function(data)
    data.self = selfState()
    data.keys = keyList()
    data.editor = EditorMenuData()
    local noclipKey = Config.Keys[2].key
    for _, k in ipairs(Config.Keys) do
        if k.cmd == 'adminnoclip' then noclipKey = CurrentKey(k.cmd) or k.key end
    end
    data.config = {
        permissions = Config.Permissions,
        weathers    = Config.Weathers,
        vehicles    = Config.QuickVehicles,
        weapons     = Config.Weapons,
        noclipKey   = noclipKey,
        announceImages = Config.AnnounceImages,
        animals = Config.Animals,
        minLevel = Config.Editor.minLevel,
        reviveRadius = Config.ReviveAreaRadius,
        garages = { platePrefix = (Config.Garages or {}).platePrefix, blipSprite = (Config.Garages or {}).blipSprite, blipColor = (Config.Garages or {}).blipColor },
        doorDistance = Config.Doors.interactDistance, doorMinDistance = Config.Doors.minDistance, doorMaxDistance = Config.Doors.maxDistance,
        editor      = {
            minLevel = Config.Editor.minLevel,
            quickProps = Config.Editor.quickProps,
            quickPeds = Config.Editor.quickPeds,
            scenarios = Config.Editor.scenarios,
            presets = Config.Editor.harvestPresets,
            npcPresets = Config.Editor.npcPresets,
            craftPresets = Config.Editor.craftPresets,
            searchPresets = Config.Editor.searchPresets,
            craftScenarios = Config.Editor.craftScenarios,
            zoneColors = Config.Zones.colors,
            zoneIcons = Config.Zones.icons or {},
            jailDurations = Config.Jail.durations,
        },
    }
    SendNUIMessage({ action = 'data', data = data })
end)

AddEventHandler('onClientResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    TriggerServerEvent('adminmenu:requestPerms')
    TriggerServerEvent('adminmenu:requestWorld')
    -- Redemande pendant 1 minute tant que le serveur n'a pas répondu (démarrage lent…)
    CreateThread(function()
        for _ = 1, 12 do
            Wait(5000)
            if MyRank ~= nil then return end
            TriggerServerEvent('adminmenu:requestPerms')
        end
    end)
end)

-- ---------------------------------------------------------
--  Callbacks NUI
-- ---------------------------------------------------------
RegisterNUICallback('close', function(_, cb) CloseMenu() cb('ok') end)

RegisterNUICallback('refresh', function(_, cb)
    TriggerServerEvent('adminmenu:requestData')
    cb('ok')
end)

RegisterNUICallback('action', function(body, cb)
    TriggerServerEvent('adminmenu:action', body.name, body.data or {})
    cb('ok')
end)

RegisterNUICallback('self', function(body, cb)
    cb(SelfAction(body.name, body.data))
end)

-- ---------------------------------------------------------
--  Évènements envoyés par le serveur
-- ---------------------------------------------------------
RegisterNetEvent('adminmenu:notify', function(msg, typ) Notify(msg, typ) end)

RegisterNetEvent('adminmenu:items', function(items, mode)
    SendNUIMessage({ action = 'items', items = items, mode = mode })
end)

RegisterNetEvent('adminmenu:teleport', function(c)
    TeleportTo(vector3(c.x, c.y, c.z), false)
end)

RegisterNetEvent('adminmenu:freeze', function(state)
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, state)
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 then FreezeEntityPosition(veh, state) end
    Notify(state and 'Vous avez été immobilisé par le staff.' or 'Vous pouvez de nouveau bouger.', 'warning')
end)

RegisterNetEvent('adminmenu:heal', function()
    local ped = PlayerPedId()
    if IsEntityDead(ped) or IsPedFatallyInjured(ped) then
        local c = GetEntityCoords(ped)
        NetworkResurrectLocalPlayer(c.x, c.y, c.z, GetEntityHeading(ped), true, false)
        ped = PlayerPedId()
    end
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    ClearPedBloodDamage(ped)
    Notify('Vous avez été soigné.', 'success')
end)

RegisterNetEvent('adminmenu:armor', function()
    SetPedArmour(PlayerPedId(), 100)
    Notify('Ton armure a été remplie.', 'success')
end)

RegisterNetEvent('adminmenu:kill', function()
    SetEntityHealth(PlayerPedId(), 0)
end)

RegisterNetEvent('adminmenu:giveWeapon', function(weapon)
    GiveWeaponToPed(PlayerPedId(), GetHashKey(weapon), 250, false, true)
    Notify('Une arme vous a été donnée par le staff.', 'info')
end)

RegisterNetEvent('adminmenu:warn', function(reason, by)
    SendNUIMessage({ action = 'warn', reason = reason, by = by })
    PlaySoundFrontend(-1, 'CHECKPOINT_MISSED', 'HUD_MINI_GAME_SOUNDSET', true)
end)

RegisterNetEvent('adminmenu:announce', function(data)
    SendNUIMessage({ action = 'announce', data = data })
    if data.style == 'alert' then
        PlaySoundFrontend(-1, 'CHECKPOINT_MISSED', 'HUD_MINI_GAME_SOUNDSET', true)
    else
        PlaySoundFrontend(-1, 'CHECKPOINT_PERFECT', 'HUD_MINI_GAME_SOUNDSET', true)
    end
end)

-- ---------------------------------------------------------
--  Réanimation
-- ---------------------------------------------------------
local function started(r) return GetResourceState(r) == 'started' end

function IsPlayerDead()
    local ped = PlayerPedId()
    if IsEntityDead(ped) or IsPedFatallyInjured(ped) then return true end
    local st = LocalPlayer and LocalPlayer.state
    if st and (st.isDead or st.inLastStand or st.dead) then return true end
    -- Qbox
    if started('qbx_core') then
        local ok, dead = pcall(function()
            local pd = exports.qbx_core:GetPlayerData()
            return pd and pd.metadata and (pd.metadata.isdead or pd.metadata.inlaststand)
        end)
        if ok and dead then return true end
    -- QBCore
    elseif started('qb-core') then
        local ok, dead = pcall(function()
            local pd = exports['qb-core']:GetCoreObject().Functions.GetPlayerData()
            return pd and pd.metadata and (pd.metadata.isdead or pd.metadata.inlaststand)
        end)
        if ok and dead then return true end
    end
    return false
end

local function nativeRevive()
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    NetworkResurrectLocalPlayer(c.x, c.y, c.z, GetEntityHeading(ped), true, false)
    ped = PlayerPedId()
    ClearPedTasksImmediately(ped)
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    ClearPedBloodDamage(ped)
end

-- Réanimation : passe par le système médical du serveur s'il existe
-- (pour qu'il remette ses propres états à zéro), puis vérifie le résultat
-- et réanime nous-mêmes si besoin. Aucun risque de rester bloqué au sol.
local function doRevive()
    local mode = Config.Revive
    if mode == 'custom' then
        Config.CustomRevive()
    elseif mode == 'auto' then
        if started('qbx_medical') then
            -- Qbox : la réanimation est faite par le SERVEUR (export qbx_medical:Revive).
            -- On ne relève pas le personnage nous-mêmes : qbx_medical le remettrait au sol.
            SetTimeout(4000, function()
                if IsPlayerDead() then Notify('La réanimation n\'a pas abouti : réessaie.', 'error') end
            end)
            return
        elseif started('esx_ambulancejob') then
            TriggerEvent('esx_ambulancejob:revive')
        elseif started('qb-ambulancejob') then
            TriggerEvent('hospital:client:Revive')
        else
            return nativeRevive()
        end
    else
        return nativeRevive()
    end
    SetTimeout(1200, function()
        if IsPlayerDead() then nativeRevive() end
    end)
end

-- Réanimation de soi-même (utilisée par l'événement zombies) : demandée au serveur
function ReviveSelf()
    TriggerServerEvent('adminmenu:zombies:revive')
    if not started('qbx_medical') then doRevive() end
end

-- onlyIfDead : réanimation de zone (on ne touche pas aux vivants)
RegisterNetEvent('adminmenu:revive', function(onlyIfDead, adminId)
    if onlyIfDead and not IsPlayerDead() then return end
    doRevive()
    Notify('Tu as été réanimé par le staff.', 'success')
    if adminId then TriggerServerEvent('adminmenu:reviveAck', adminId) end
end)

RegisterNetEvent('adminmenu:newReport', function(r)
    Notify(('Report #%d de %s : %s'):format(r.id, r.name, r.msg), 'report')
    PlaySoundFrontend(-1, 'Text_Arrive_Tone', 'Phone_SoundSet_Default', true)
end)

RegisterNetEvent('adminmenu:forceDelete', function(netId)
    if not NetworkDoesNetworkIdExist(netId) then return Notify('Entité introuvable.', 'error') end
    local ent = NetworkGetEntityFromNetworkId(netId)
    if ent == 0 or not DoesEntityExist(ent) then return Notify('Entité introuvable.', 'error') end
    RequestControl(ent)
    SetEntityAsMissionEntity(ent, true, true)
    DeleteEntity(ent)
    Notify(DoesEntityExist(ent) and 'Suppression impossible.' or 'Entité supprimée.', DoesEntityExist(ent) and 'error' or 'success')
end)

-- ---------------------------------------------------------
--  Boucles : godmode, invisibilité, noms au-dessus des têtes
-- ---------------------------------------------------------
CreateThread(function()
    while true do
        local sleep = 500
        local ped = PlayerPedId()
        if State.godmode then
            SetEntityInvincible(ped, true)
            SetPlayerInvincible(PlayerId(), true)
        end
        if State.invisible and not IsNoclipActive() then
            sleep = 0
            SetEntityVisible(ped, false, false)
            SetEntityLocallyVisible(ped)
            SetEntityAlpha(ped, 150, false)
        end
        Wait(sleep)
    end
end)

local idTargets = {}
CreateThread(function()
    while true do
        if State.showIds then
            local myPed = PlayerPedId()
            local myC = GetEntityCoords(myPed)
            local list = {}
            for _, pl in ipairs(GetActivePlayers()) do
                local ped = GetPlayerPed(pl)
                if ped ~= myPed and #(GetEntityCoords(ped) - myC) < 100.0 then
                    list[#list + 1] = { ped = ped, pl = pl, text = ('[%d] %s'):format(GetPlayerServerId(pl), GetPlayerName(pl)) }
                end
            end
            idTargets = list
            Wait(300)
        else
            idTargets = {}
            Wait(500)
        end
    end
end)

CreateThread(function()
    while true do
        if State.showIds and #idTargets > 0 then
            for i = 1, #idTargets do
                local t = idTargets[i]
                if DoesEntityExist(t.ped) then
                    local c = GetEntityCoords(t.ped)
                    DrawText3D(vector3(c.x, c.y, c.z + 1.15), (NetworkIsPlayerTalking(t.pl) and '~b~' or '~w~') .. t.text, 0.32)
                end
            end
            Wait(0)
        else
            Wait(250)
        end
    end
end)

-- Redémarrage de la ressource : rien ne doit rester bloqué
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
    local ped = PlayerPedId()
    if State.invisible then SetEntityVisible(ped, true, false) ResetEntityAlpha(ped) end
    if State.godmode then SetEntityInvincible(ped, false) SetPlayerInvincible(PlayerId(), false) end
    if IsScreenFadedOut() or IsScreenFadingOut() then DoScreenFadeIn(0) end
end)

-- ---------------------------------------------------------
--  ESX (esx_status) : gel de la faim et de la soif côté client
--  (Qbox / QBCore sont gérés par le serveur)
-- ---------------------------------------------------------
local needsFrozen = false
RegisterNetEvent('adminmenu:needsFreeze', function(on) needsFrozen = on == true end)
CreateThread(function()
    local lock = {}
    while true do
        Wait(5000)
        if needsFrozen and State.duty and GetResourceState('esx_status') == 'started' then
            for _, name in ipairs({ 'hunger', 'thirst' }) do
                TriggerEvent('esx_status:getStatus', name, function(st)
                    if not st or not st.val then return end
                    if not lock[name] or st.val > lock[name] then lock[name] = st.val
                    elseif st.val < lock[name] then TriggerEvent('esx_status:set', name, lock[name]) end
                end)
            end
        else
            lock = {}
        end
    end
end)
