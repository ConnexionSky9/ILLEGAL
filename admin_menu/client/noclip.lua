-- =========================================================
--  NOCLIP 3E PERSONNE
--  Le viseur ne cible QUE les véhicules et les joueurs :
--    [G]           supprimer le véhicule visé (PNJ ou joueur)
--    [Clic gauche] spectate le joueur visé (ou un joueur dans le véhicule)
--  Les objets de la map (poteaux, panneaux…) ne sont jamais touchés ici :
--  ils se retirent depuis le menu (Éditeur de map › Props › Objets de la map).
--  Les touches s'affichent en bas à droite et sont toutes modifiables.
-- =========================================================
local NC = Config.Noclip
local active = false
local function clampSpeed(i) return math.max(1, math.min(#NC.speeds, math.floor(tonumber(i) or NC.defaultSpeed))) end
local speedIndex = clampSpeed(NC.defaultSpeed)
if NC.rememberSpeed then
    local saved = GetResourceKvpInt('noclip_speed')
    if saved and saved > 0 then speedIndex = clampSpeed(saved) end
end
local target, targetInfo = 0, nil
local pendingDelete, pendingTime = 0, 0
local held = {}
local prevPedCam, prevVehCam
local loopGen, lastToggle, lastError = 0, 0, -100000

NoclipMovingFast = false -- lu par l'éditeur : on n'y crée rien pendant un vol rapide

-- Seuls ces contrôles GTA restent actifs : caméra, pause, chat, micro
local ALLOWED = { 1, 2, 199, 200, 245, 249 }

function IsNoclipActive() return active end

local function otherModeActive()
    return (IsPlacing and IsPlacing()) or (IsZonePreview and IsZonePreview()) or (IsMapPick and IsMapPick())
        or (IsModelPreview and IsModelPreview()) or (IsZoneDraw and IsZoneDraw()) or (IsDoorPick and IsDoorPick())
        or (IsPropSelect and IsPropSelect())
end

-- ---------------------------------------------------------
--  Outils
-- ---------------------------------------------------------
local function rotToDir(rot)
    local z, x = math.rad(rot.z), math.rad(rot.x)
    local n = math.abs(math.cos(x))
    return vector3(-math.sin(z) * n, math.cos(z) * n, math.sin(x))
end

local function getNoclipEntity()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then return veh, ped end
    return ped, ped
end

local function setGhost(ent, enable)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return end
    local isMe = ent == PlayerPedId()
    FreezeEntityPosition(ent, enable)
    SetEntityCollision(ent, not enable, not enable)
    SetEntityInvincible(ent, enable or (isMe and State.godmode))
    if enable then
        SetEntityVisible(ent, false, false)
    else
        SetEntityVisible(ent, not (isMe and State.invisible), false)
        ResetEntityAlpha(ent)
    end
end

-- ---------------------------------------------------------
--  Ciblage : véhicules et joueurs seulement
--  Rayon asynchrone (lancé à une image, lu à la suivante)
-- ---------------------------------------------------------
local rayHandle, rayResult = nil, 0
local function raycast(ent, ped)
    if rayHandle then
        local status, hit, _, _, hitEnt = GetShapeTestResult(rayHandle)
        if status == 1 then return rayResult end
        rayHandle, rayResult = nil, 0
        if hit == 1 and hitEnt ~= 0 and hitEnt ~= ped and hitEnt ~= ent and DoesEntityExist(hitEnt) then
            local t = GetEntityType(hitEnt)
            if t == 2 or (t == 1 and IsPedAPlayer(hitEnt)) then rayResult = hitEnt end
        end
    end
    local from = GetGameplayCamCoord()
    local to = from + rotToDir(GetGameplayCamRot(2)) * NC.targetDistance
    -- 2 véhicules + 4/8 personnages. Pas d'objets (16) : jamais la map.
    rayHandle = StartShapeTestLosProbe(from.x, from.y, from.z, to.x, to.y, to.z, 14, ent, 4)
    return rayResult
end

local function playerInfo(ped)
    local pl = NetworkGetPlayerIndexFromPed(ped)
    if pl == -1 then return nil end
    return GetPlayerServerId(pl), GetPlayerName(pl)
end

local function buildInfo(e)
    local info = {}
    if GetEntityType(e) == 1 then
        local id, name = playerInfo(e)
        if not id then return nil end
        info.player, info.serverId = true, id
        info.label = ('~b~Joueur~s~ %s [%d]'):format(name, id)
        info.short = ('Joueur %s [%d]'):format(name, id)
        return info
    end
    local model = GetEntityModel(e)
    local name = GetLabelText(GetDisplayNameFromVehicleModel(model))
    if name == 'NULL' then name = GetDisplayNameFromVehicleModel(model) end
    info.vehicle = true
    info.label = ('~y~Véhicule~s~ %s'):format(name)
    info.short = 'Véhicule ' .. name
    -- Un joueur à bord ? (conducteur en priorité)
    for seat = -1, math.max(GetVehicleMaxNumberOfPassengers(e) - 1, 0) do
        local p = GetPedInVehicleSeat(e, seat)
        if p ~= 0 and IsPedAPlayer(p) then
            local id, pname = playerInfo(p)
            if id then
                info.hasPlayer, info.serverId = true, id
                info.label = info.label .. ('~n~~b~À bord~s~ %s [%d]'):format(pname, id)
                info.short = info.short .. (' · %s [%d] à bord'):format(pname, id)
                break
            end
        end
    end
    return info
end

local function setTarget(e)
    if e == target then return end
    target, targetInfo = e, nil
    if e ~= 0 and DoesEntityExist(e) then
        targetInfo = buildInfo(e)
        if not targetInfo then target = 0 end
    else
        target = 0
    end
end

-- ---------------------------------------------------------
--  Liste des touches (en bas à droite de l'écran)
-- ---------------------------------------------------------
local function K(id, default)
    return CurrentKey and CurrentKey('+admin_nc_' .. id) or default
end
local function defaultKey(id)
    for _, k in ipairs(Config.NoclipKeys) do if k.id == id then return k.key end end
    return '?'
end

local hudKey = nil
local function updateHud(fast)
    local key = table.concat({ speedIndex, targetInfo and targetInfo.short or '-', fast and 'f' or '', tostring(HasPerm('delete_entity')), tostring(HasPerm('spectate')) }, '|')
    if HudOwner == 'noclip' and key == hudKey then return end
    hudKey = key
    local rows = {
        { keys = { K('forward', defaultKey('forward')), K('left', defaultKey('left')), K('back', defaultKey('back')), K('right', defaultKey('right')) }, label = 'Se déplacer' },
        { keys = { K('up', defaultKey('up')), K('down', defaultKey('down')) }, label = 'Monter / descendre' },
        { keys = { K('fast', defaultKey('fast')) }, label = 'Aller vite' },
        { keys = { K('slow', defaultKey('slow')) }, label = 'Aller lentement' },
        { keys = { K('speed_up', defaultKey('speed_up')), K('speed_down', defaultKey('speed_down')) },
          label = ('Vitesse %d / %d · %d km/h'):format(speedIndex, #NC.speeds, math.floor(NC.speeds[speedIndex] * 3.6 + 0.5)) },
    }
    if HasPerm('delete_entity') then rows[#rows + 1] = { keys = { K('delete', defaultKey('delete')) }, label = 'Supprimer le véhicule visé' } end
    if HasPerm('spectate') then rows[#rows + 1] = { keys = { K('spectate', defaultKey('spectate')) }, label = 'Spectate le joueur visé' } end
    rows[#rows + 1] = { keys = { CurrentKey and CurrentKey('adminnoclip') or Config.Keys[2].key }, label = 'Quitter le noclip' }

    local footer
    if fast then footer = 'Vol rapide : viseur en pause'
    elseif targetInfo then footer = 'Cible : ' .. targetInfo.short
    else footer = 'Vise un véhicule ou un joueur' end
    ShowKeysHud('noclip', 'Noclip', rows, footer)
end

-- ---------------------------------------------------------
--  Actions des touches
-- ---------------------------------------------------------
local function deleteVehicle(e)
    if NetworkGetEntityIsNetworked(e) then
        TriggerServerEvent('adminmenu:action', 'delete_entity', { netId = NetworkGetNetworkIdFromEntity(e) })
    else
        SetEntityAsMissionEntity(e, true, true)
        DeleteVehicle(e)
        Notify('Véhicule supprimé.', 'success')
    end
end

local function onPress(id)
    if not active or otherModeActive() or IsPauseMenuActive() then return end

    if id == 'speed_up' or id == 'speed_down' then
        speedIndex = clampSpeed(speedIndex + (id == 'speed_up' and 1 or -1))
        if NC.rememberSpeed then SetResourceKvpInt('noclip_speed', speedIndex) end

    elseif id == 'delete' then
        if not HasPerm('delete_entity') or target == 0 or not targetInfo or not DoesEntityExist(target) then return end
        if not targetInfo.vehicle then return Notify('En noclip, seuls les véhicules peuvent être supprimés.', 'error') end
        -- Un joueur est à bord : on demande une confirmation (2e appui)
        if targetInfo.hasPlayer then
            local now = GetGameTimer()
            if pendingDelete ~= target or now - pendingTime > 3000 then
                pendingDelete, pendingTime = target, now
                return Notify('Un joueur est à bord : appuie encore une fois pour supprimer le véhicule.', 'warning')
            end
        end
        pendingDelete = 0
        local e = target
        setTarget(0)
        deleteVehicle(e)

    elseif id == 'spectate' then
        if not HasPerm('spectate') or not targetInfo then return end
        if not targetInfo.serverId then return Notify('Vise un joueur, ou un véhicule avec un joueur à bord.', 'error') end
        TriggerServerEvent('adminmenu:action', 'spectate', { target = targetInfo.serverId })
    end
end

for _, k in ipairs(Config.NoclipKeys) do
    local cmd = 'admin_nc_' .. k.id
    if k.hold then
        RegisterCommand('+' .. cmd, function() if not IsPauseMenuActive() then held[k.id] = true end end, false)
        RegisterCommand('-' .. cmd, function() held[k.id] = false end, false)
    else
        RegisterCommand('+' .. cmd, function() onPress(k.id) end, false)
        RegisterCommand('-' .. cmd, function() end, false)
    end
    RegisterKeyMapping('+' .. cmd, 'Staff - Noclip : ' .. k.label, k.mapper or 'keyboard', k.key or '')
end

-- ---------------------------------------------------------
--  Une image du noclip (protégée par pcall dans la boucle)
-- ---------------------------------------------------------
local function frame(state)
    -- Aperçu 3D en cours : le noclip se met en pause (la caméra est utilisée)
    if IsModelPreview and IsModelPreview() then
        DisableAllControlActions(0)
        return
    end
    -- Menu pause / carte ouverts (Échap) : on rend toutes les commandes au jeu pour pouvoir
    -- zoomer et se déplacer sur la carte. Le personnage reste figé sur place en attendant.
    if IsPauseMenuActive() then
        for k in pairs(held) do held[k] = false end
        if state.vel then state.vel.x, state.vel.y, state.vel.z = 0.0, 0.0, 0.0 end
        if HudOwner == 'noclip' then HideKeysHud() hudKey = nil end
        if state.current and DoesEntityExist(state.current) then SetEntityVelocity(state.current, 0.0, 0.0, 0.0) end
        return
    end
    local ent, ped = getNoclipEntity()
    if ent ~= state.current then
        setGhost(state.current, false)
        setGhost(ent, true)
        state.current = ent
        state.pos = nil
        state.vel = { x = 0.0, y = 0.0, z = 0.0 }
    end

    DisableAllControlActions(0)
    for i = 1, #ALLOWED do EnableControlAction(0, ALLOWED[i], true) end

    if ent == ped then
        if GetFollowPedCamViewMode() == 4 then SetFollowPedCamViewMode(1) end
    elseif GetFollowVehicleCamViewMode() == 4 then
        SetFollowVehicleCamViewMode(1)
    end

    -- Vitesse en m/s, plafonnée (voler trop vite surcharge le chargement de la map)
    local speed = NC.speeds[speedIndex] or 10.0
    if held.fast then speed = speed * NC.fastMultiplier
    elseif held.slow then speed = speed * NC.slowMultiplier end
    if speed > NC.maxSpeed then speed = NC.maxSpeed end
    local dt = math.min(GetFrameTime(), 0.05)

    -- Direction : cap de la caméra + inclinaison filtrée (zone morte) pour ne plus
    -- glisser vers le bas quand la caméra penche un peu toute seule
    local camRot = GetGameplayCamRot(2)
    local hr = math.rad(camRot.z)
    local pitch = camRot.x
    if NC.pitchMode == 'horizontal' then
        pitch = 0.0
    elseif NC.pitchMode ~= 'camera' then
        local dz = NC.pitchDeadzone or 22.0
        local a = math.abs(pitch)
        pitch = a <= dz and 0.0 or ((a - dz) * 90.0 / (90.0 - dz)) * (pitch < 0 and -1 or 1)
    end
    local pr = math.rad(pitch)
    local cp = math.cos(pr)
    local fx, fy, fz = -math.sin(hr) * cp, math.cos(hr) * cp, math.sin(pr)
    local rx, ry = math.cos(hr), math.sin(hr)
    local mx, my, mz = 0.0, 0.0, 0.0
    if held.forward then mx, my, mz = mx + fx, my + fy, mz + fz end
    if held.back then mx, my, mz = mx - fx, my - fy, mz - fz end
    if held.left then mx, my = mx - rx, my - ry end
    if held.right then mx, my = mx + rx, my + ry end
    if held.up then mz = mz + 1.0 end
    if held.down then mz = mz - 1.0 end

    -- Vitesse visée, puis lissage (accélération et freinage progressifs)
    local len = math.sqrt(mx * mx + my * my + mz * mz)
    local tx, ty, tz = 0.0, 0.0, 0.0
    if len > 0.001 then tx, ty, tz = mx / len * speed, my / len * speed, mz / len * speed end
    local v = state.vel
    if (NC.smoothing or 0) > 0 then
        local k = 1.0 - math.exp(-NC.smoothing * dt)
        v.x, v.y, v.z = v.x + (tx - v.x) * k, v.y + (ty - v.y) * k, v.z + (tz - v.z) * k
    else
        v.x, v.y, v.z = tx, ty, tz
    end
    if len <= 0.001 and v.x * v.x + v.y * v.y + v.z * v.z < 0.0004 then v.x, v.y, v.z = 0.0, 0.0, 0.0 end
    local moving = len > 0.001

    -- Position gardée en mémoire (plus précise que relire l'entité à chaque image) ;
    -- si quelque chose nous a déplacés (téléportation), on repart de la vraie position
    local real = GetEntityCoords(ent)
    local p = state.pos
    if not p or #(real - vector3(p.x, p.y, p.z)) > 6.0 then
        p = { x = real.x, y = real.y, z = real.z }
        state.pos = p
    end
    local px, py, pz = p.x + v.x * dt, p.y + v.y * dt, p.z + v.z * dt
    if px > 8000.0 then px = 8000.0 elseif px < -8000.0 then px = -8000.0 end
    if py > 9000.0 then py = 9000.0 elseif py < -8000.0 then py = -8000.0 end
    if pz > 2500.0 then pz = 2500.0 elseif pz < -200.0 then pz = -200.0 end
    p.x, p.y, p.z = px, py, pz

    SetEntityVelocity(ent, 0.0, 0.0, 0.0)
    SetEntityCoordsNoOffset(ent, px, py, pz, true, true, true)
    if ent == ped then
        SetEntityHeading(ped, camRot.z)
    else
        SetEntityRotation(ent, 0.0, 0.0, camRot.z, 2, true)
    end

    SetEntityLocallyVisible(ent)
    SetEntityAlpha(ent, 140, false)
    if ent ~= ped then SetEntityLocallyVisible(ped) SetEntityAlpha(ped, 140, false) end

    -- En vol rapide, on ne vise rien (les entités apparaissent / disparaissent
    -- trop vite autour de nous) et l'éditeur ne crée rien
    local fast = moving and speed > NC.fastThreshold
    NoclipMovingFast = fast

    if otherModeActive() then
        setTarget(0)
        rayHandle = nil
        return
    end

    if fast or not (HasPerm('delete_entity') or HasPerm('spectate')) then
        setTarget(0)
        rayHandle = nil
    else
        DrawRect(0.5, 0.5, 0.0025, 0.0045, 255, 255, 255, 200)
        setTarget(raycast(ent, ped))
        if target ~= 0 then
            if DoesEntityExist(target) then
                local c = GetEntityCoords(target)
                local top = c.z + (targetInfo.player and 1.0 or 2.2)
                local r, g, b = 242, 177, 52
                if targetInfo.player then r, g, b = 91, 141, 239 end
                DrawMarker(2, c.x, c.y, top, 0.0, 0.0, 0.0, 180.0, 0.0, 0.0, 0.35, 0.35, 0.35,
                    r, g, b, 210, true, false, 2, true, nil, nil, false)
                DrawText3D(vector3(c.x, c.y, top + 0.55), targetInfo.label, 0.33)
            else
                setTarget(0)
            end
        end
    end
    updateHud(fast)
end

-- Sortie sûre : sol chargé avant de poser, puis 4 s sans dégâts de chute
local function exitNoclip(state)
    local ent, ped = state.current, PlayerPedId()
    setTarget(0)
    held, rayHandle, rayResult = {}, nil, 0
    NoclipMovingFast = false
    if HudOwner == 'noclip' then HideKeysHud() end
    setGhost(ent, false)
    if ent ~= ped then setGhost(ped, false) end

    if ent == ped and DoesEntityExist(ped) then
        local c = GetEntityCoords(ped)
        local t, found, gz = GetGameTimer(), false, 0.0
        while GetGameTimer() - t < 1500 do
            RequestCollisionAtCoord(c.x, c.y, c.z)
            found, gz = GetGroundZFor_3dCoord(c.x, c.y, c.z, false)
            if found then break end
            Wait(50)
        end
        if found and c.z - gz > 1.0 then SetEntityCoords(ped, c.x, c.y, gz, false, false, false, false) end
        if not State.godmode then
            SetEntityInvincible(ped, true)
            SetTimeout(4000, function()
                if not State.godmode and not active then SetEntityInvincible(PlayerPedId(), false) end
            end)
        end
    elseif DoesEntityExist(ent) then
        SetVehicleOnGroundProperly(ent)
    end

    if prevPedCam then SetFollowPedCamViewMode(prevPedCam) end
    if prevVehCam then SetFollowVehicleCamViewMode(prevVehCam) end
end

local function noclipLoop(gen)
    local ent, ped = getNoclipEntity()
    local state = { current = ent, pos = nil, vel = { x = 0.0, y = 0.0, z = 0.0 } }
    setGhost(ent, true)
    if ent ~= ped then setGhost(ped, true) end
    hudKey = nil

    while active and gen == loopGen do
        Wait(0)
        local ok, err = pcall(frame, state)
        if not ok then
            if GetGameTimer() - lastError > 5000 then
                lastError = GetGameTimer()
                print(('^1[AdminMenu] Erreur noclip : %s^7'):format(tostring(err)))
            end
            active = false
            Notify('Noclip coupé suite à une erreur (détails en F8).', 'error')
        end
    end

    if active and gen ~= loopGen then return end -- un nouveau noclip a pris le relais
    local ok, err = pcall(exitNoclip, state)
    if not ok then
        print(('^1[AdminMenu] Erreur sortie noclip : %s^7'):format(tostring(err)))
        local p = PlayerPedId()
        FreezeEntityPosition(p, false)
        SetEntityCollision(p, true, true)
        SetEntityVisible(p, true, false)
        ResetEntityAlpha(p)
        HideKeysHud()
    end
end

function ToggleNoclip(force)
    local newState = force
    if newState == nil then
        if GetGameTimer() - lastToggle < 350 then return end -- anti double-appui
        newState = not active
    end
    lastToggle = GetGameTimer()
    if newState == active then return end
    if newState and not HasPerm('noclip') then return end
    if newState and not State.duty then
        return Notify('Tu es en mode RP. Reprends ton service staff pour utiliser le noclip.', 'error')
    end
    if newState and IsPlayerDead and IsPlayerDead() then
        return Notify('Impossible d\'activer le noclip en étant mort.', 'error')
    end

    active = newState
    if active then
        held = {}
        prevPedCam = GetFollowPedCamViewMode()
        prevVehCam = GetFollowVehicleCamViewMode()
        loopGen = loopGen + 1
        local gen = loopGen
        CreateThread(function() noclipLoop(gen) end)
        Notify('Noclip activé.', 'success')
    else
        Notify('Noclip désactivé.', 'info')
    end
    TriggerServerEvent('adminmenu:logSelf', active and 'noclip_on' or 'noclip_off')
end

-- Si la ressource redémarre pendant le noclip : on rend le joueur normal
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() or not active then return end
    active = false
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    for _, e in ipairs({ ped, veh }) do
        if e ~= 0 and DoesEntityExist(e) then
            FreezeEntityPosition(e, false)
            SetEntityCollision(e, true, true)
            SetEntityInvincible(e, false)
            SetEntityVisible(e, true, false)
            ResetEntityAlpha(e)
        end
    end
end)
