-- =========================================================
--  ELYZEA ILLÉGAL - CLIENT : MISSIONS (commun à toutes les missions)
--  État reçu du serveur, HUD (timer), barre de progression, invite ALT,
--  IA des gardes. Chaque type de mission (client/missions/<type>.lua)
--  s'enregistre avec MissionClient.registerType(type, { update, stop }).
--  Le client n'envoie que des intentions (« je fouille », « j'ouvre ») :
--  le serveur vérifie et décide.
-- =========================================================
MissionClient = { run = nil, types = {} }
local M = MissionClient

function M.registerType(key, def) M.types[key] = def end
function M.useTarget() return GetResourceState('ox_target') == 'started' end

function M.action(name, a, b)
    if M.run then TriggerServerEvent('illegal:mission:action', M.run.runId, name, a, b) end
end

-- HUD de mission : objectif, informations importantes (codes, plaques…), alerte, timer.
-- Réglages (position, taille, transparence, catégories) envoyés par le serveur avec la mission.
local function hud(p)
    if not p then return SendNUIMessage({ action = 'missionHud', show = false }) end
    SendNUIMessage({ action = 'missionHud', show = true, label = p.label, objective = p.objective or p.stageLabel or '', lines = p.lines or {},
        info = p.info or {}, alert = p.alert or 0, remaining = p.remaining, cfg = p.hud or {} })
end

RegisterNetEvent('illegal:client:mission', function(p)
    if type(p) ~= 'table' then return end
    local prev = M.run
    if prev and prev.runId ~= p.runId then
        local def = M.types[prev.type]
        if def and def.stop then def.stop(prev) end
        prev = nil
    end
    M.run = p
    hud(p)
    local def = M.types[p.type]
    if def and def.update then def.update(p, prev) end
end)

RegisterNetEvent('illegal:client:missionEnd', function(d)
    local run = M.run
    if run and (not d or d.runId == run.runId) then
        local def = M.types[run.type]
        if def and def.stop then def.stop(run) end
        M.run = nil
        Prompt.hide()
    end
    hud(nil)
    SendNUIMessage({ action = 'missionEnd', success = d and d.success, message = d and d.message or '' })
end)

-- Le serveur autorise une action longue : barre de progression puis confirmation
RegisterNetEvent('illegal:client:missionProgress', function(runId, kind, seconds, extra)
    local run = M.run
    if not run or run.runId ~= runId then return end
    local def = M.types[run.type]
    if def and def.progress then def.progress(kind, seconds, extra) end
end)

-- ---------------------------------------------------------
--  Alerte police (envoyée uniquement aux policiers en service par le serveur)
--  Position approximative : zone + icône, durée réglée par niveau d'alerte.
-- ---------------------------------------------------------
RegisterNetEvent('illegal:client:policeAlert', function(a)
    if type(a) ~= 'table' then return end
    Notify(('🚨 %s : %s'):format(a.title or 'Alerte', a.message or ''), 'warning')
    PlaySoundFrontend(-1, 'Lose_1st', 'GTAO_FM_Events_Soundset', true)
    local area = AddBlipForRadius(a.x, a.y, a.z, (a.radius or 300) + 0.0)
    SetBlipColour(area, a.color or 1)
    SetBlipAlpha(area, 100)
    local b = AddBlipForCoord(a.x, a.y, a.z)
    SetBlipSprite(b, a.sprite or 161)
    SetBlipColour(b, a.color or 1)
    SetBlipScale(b, 1.1)
    SetBlipFlashes(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(a.title or 'Alerte')
    EndTextCommandSetBlipName(b)
    SetTimeout((a.seconds or 120) * 1000, function()
        if DoesBlipExist(b) then RemoveBlip(b) end
        if DoesBlipExist(area) then RemoveBlip(area) end
    end)
end)

-- Ressource redémarrée côté client : on redemande l'état
CreateThread(function()
    Wait(2500)
    TriggerServerEvent('illegal:mission:resync')
end)

-- ---------------------------------------------------------
--  Barre de progression (même rendu que celle du MenuStaff)
--  Annulée si on bouge trop loin, meurt, tombe ou appuie sur X.
-- ---------------------------------------------------------
M.busy = false
function M.progress(label, seconds, dict, anim, anchor, maxDist)
    local ped = PlayerPedId()
    M.busy = true
    Prompt.hide()
    if anchor then TaskTurnPedToFaceCoord(ped, anchor.x, anchor.y, anchor.z, 600) Wait(600) end
    local hasAnim = dict and dict ~= '' and anim and anim ~= '' and lib.requestAnimDict(dict, 2000)
    if hasAnim then TaskPlayAnim(ped, dict, anim, 6.0, -6.0, -1, 1, 0, false, false, false) end
    SendNUIMessage({ action = 'dprogress', show = true, label = label, time = seconds })
    local start, ok = GetGameTimer(), true
    while GetGameTimer() - start < seconds * 1000 do
        Wait(0)
        DisableControlAction(0, 24, true) DisableControlAction(0, 25, true)
        if IsEntityDead(ped) or IsPedRagdoll(ped) or IsControlJustPressed(0, 73)
            or (anchor and #(GetEntityCoords(ped) - vector3(anchor.x, anchor.y, anchor.z)) > (maxDist or 3.0)) then
            ok = false
            break
        end
        if hasAnim and not IsEntityPlayingAnim(ped, dict, anim, 3) then TaskPlayAnim(ped, dict, anim, 6.0, -6.0, -1, 1, 0, false, false, false) end
    end
    SendNUIMessage({ action = 'dprogress', show = false })
    ClearPedTasks(ped)
    M.busy = false
    return ok
end

-- ---------------------------------------------------------
--  Interaction ALT (sans ox_target) : maintenir ALT, puis E
--  Retourne true quand le joueur valide. À appeler chaque image.
-- ---------------------------------------------------------
-- Interaction : avec ox_target installé (qui utilise déjà ALT), simple E ; sinon ALT + E
function M.interact(owner, verb, name)
    if M.useTarget() then
        Prompt.show(owner, verb, name, 'E')
        return IsControlJustPressed(0, 38)
    end
    return M.alt(owner, verb, name)
end

function M.alt(owner, verb, name)
    if IsControlPressed(0, 19) then
        Prompt.show(owner, verb, name, 'ALT + E')
        return IsControlJustPressed(0, 38)
    end
    Prompt.show(owner, 'Maintiens ALT', name, 'ALT', true)
    return false
end

-- ---------------------------------------------------------
--  Blips
-- ---------------------------------------------------------
function M.blip(x, y, z, sprite, color, label, route)
    local b = AddBlipForCoord(x, y, z)
    SetBlipSprite(b, sprite or 1)
    SetBlipColour(b, color or 1)
    SetBlipScale(b, 0.9)
    SetBlipAsShortRange(b, false)
    if route then SetBlipRoute(b, true) SetBlipRouteColour(b, color or 1) end
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(label or 'Mission')
    EndTextCommandSetBlipName(b)
    return b
end

function M.radiusBlip(x, y, z, radius, color)
    local b = AddBlipForRadius(x, y, z, radius + 0.0)
    SetBlipColour(b, color or 1)
    SetBlipAlpha(b, 90)
    return b
end

function M.removeBlip(b) if b and DoesBlipExist(b) then RemoveBlip(b) end end

-- =========================================================
--  IA DES GARDES (toutes missions)
--  Les gardes sont créés par le serveur ; le client « propriétaire »
--  réseau de chaque garde applique son comportement :
--   passif : n'attaque jamais
--   méfiant : se retourne à la détection, attaque à la distance d'attaque
--   agressif : attaque dès la détection, ne poursuit pas loin
--   très agressif : attaque et poursuit jusqu'à la distance de poursuite
--  Retour à la position de départ si la cible s'éloigne (réglable).
-- =========================================================
local Guards = {}       -- [ped] = { st, mode, provoked }
local anyGuard = false
local relGroup

AddStateBagChangeHandler('illegalGuard', nil, function() anyGuard = true end)

local function relationship()
    if relGroup then return relGroup end
    local _, h = AddRelationshipGroup('ILLEGAL_MISSION_GUARDS')
    relGroup = h
    SetRelationshipBetweenGroups(3, relGroup, joaat('PLAYER'))
    SetRelationshipBetweenGroups(3, joaat('PLAYER'), relGroup)
    return relGroup
end

local function configure(ped, st)
    SetEntityMaxHealth(ped, st.health)
    SetEntityHealth(ped, st.health)
    SetPedAccuracy(ped, st.accuracy)
    SetPedRelationshipGroupHash(ped, relationship())
    SetPedCombatAbility(ped, 1)
    SetPedCombatMovement(ped, st.behavior == 'very_aggressive' and 3 or 2)
    SetPedCombatAttributes(ped, 0, st.cover ~= false)   -- se met à couvert
    SetPedCombatAttributes(ped, 5, true)     -- se bat même désarmé
    SetPedCombatAttributes(ped, 46, true)    -- jusqu'au bout
    SetPedFleeAttributes(ped, 0, false)
    SetPedConfigFlag(ped, 281, true)         -- pas d'agonie au sol : mort net (fouille possible)
    SetPedDropsWeaponsWhenDead(ped, false)
    SetPedKeepTask(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    if st.weapon and st.weapon ~= 'WEAPON_UNARMED' then SetCurrentPedWeapon(ped, joaat(st.weapon), true) end
    local c = GetEntityCoords(ped)
    local ok, gz = GetGroundZFor_3dCoord(c.x, c.y, c.z + 30.0, false)
    if ok and math.abs(gz - c.z) < 30.0 then SetEntityCoordsNoOffset(ped, c.x, c.y, gz, false, false, false) end
    SetEntityHeading(ped, st.hh or 0.0)
    TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_GUARD_STAND', 0, true)
end

local function nearestPlayer(pos)
    local best, bd
    for _, pid in ipairs(GetActivePlayers()) do
        local p = GetPlayerPed(pid)
        if p ~= 0 and not IsEntityDead(p) then
            local d = #(GetEntityCoords(p) - pos)
            if not bd or d < bd then best, bd = p, d end
        end
    end
    return best, bd or math.huge
end

local function behave(ped, g)
    local st = g.st
    if st.behavior == 'passive' then return end
    local pos = GetEntityCoords(ped)
    local home = vector3(st.hx, st.hy, st.hz)
    local target, d = nearestPlayer(pos)
    if HasEntityBeenDamagedByAnyPed(ped) then g.provoked = true ClearEntityLastDamageEntity(ped) end
    -- Jusqu'où il suit sa cible (mesuré depuis sa position de départ)
    local limit = st.detect
    if st.behavior == 'very_aggressive' then limit = st.canChase and st.chase or st.attack end
    local targetFromHome = target and #(GetEntityCoords(target) - home) or math.huge

    if g.mode == 'combat' then
        if not target or IsEntityDead(target) or targetFromHome > limit then
            if st.returnHome then
                g.mode, g.provoked = 'return', false
                ClearPedTasks(ped)
                TaskGoStraightToCoord(ped, home.x, home.y, home.z, 2.0, -1, st.hh or 0.0, 0.5)
            else
                g.mode = 'idle'
                ClearPedTasks(ped)
                TaskGuardCurrentPosition(ped, 5.0, 5.0, true)
            end
        end
        return
    end
    if g.mode == 'return' then
        if #(pos - home) < 1.5 then
            g.mode = 'idle'
            SetEntityHeading(ped, st.hh or 0.0)
            TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_GUARD_STAND', 0, true)
        elseif not target or d > st.detect then return end
    end
    if not target then return end
    -- Déclenchement : distance, ligne de vue, ou évènement (alarme, ouverture du fourgon / d'une caisse)
    local trig = st.trigger or 'distance'
    local alerted = Entity(ped).state.illegalAlerted == true
    local canSee = trig ~= 'los' or HasEntityClearLosToEntity(ped, target, 17)
    local armed = trig == 'distance' or trig == 'los' or alerted
    local engage = g.provoked or (alerted and d <= math.max(st.detect, 60.0))
        or (armed and canSee and st.behavior == 'wary' and d <= st.attack)
        or (armed and canSee and (st.behavior == 'aggressive' or st.behavior == 'very_aggressive') and d <= st.detect)
    if alerted and not st.returnHome then limit = math.max(limit, 500.0) end
    if engage and targetFromHome <= limit + 5.0 then
        g.mode = 'combat'
        SetBlockingOfNonTemporaryEvents(ped, false)
        TaskCombatPed(ped, target, 0, 16)
    elseif st.behavior == 'wary' and d <= st.detect and g.mode ~= 'alert' then
        g.mode = 'alert'
        TaskTurnPedToFaceEntity(ped, target, -1)
    elseif g.mode == 'alert' and d > st.detect then
        g.mode = 'idle'
        TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_GUARD_STAND', 0, true)
    end
end

-- Fourgon de mission : moteur, dégâts (accident), portes, appliqués par le propriétaire réseau
local Vans = {}
AddStateBagChangeHandler('illegalVan', nil, function() anyGuard = true end)
local function vanTick()
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        local st = Entity(veh).state.illegalVan
        if st and NetworkHasControlOfEntity(veh) then
            if not Vans[veh] then
                Vans[veh] = true
                SetVehicleOnGroundProperly(veh)
                if st.engineOff then SetVehicleEngineOn(veh, false, true, true) end
                if st.damaged then
                    SetVehicleBodyHealth(veh, (st.body or 300) + 0.0)
                    SetVehicleEngineHealth(veh, (st.engine or 200) + 0.0)
                    SmashVehicleWindow(veh, 0) SmashVehicleWindow(veh, 1)
                    SetVehicleDoorBroken(veh, 4, true)
                    SetVehicleDamage(veh, 0.0, 1.5, 0.3, 400.0, 150.0, true)
                end
                if st.doorsOpen then SetVehicleDoorOpen(veh, 2, false, false) SetVehicleDoorOpen(veh, 3, false, false) end
            end
            if Entity(veh).state.illegalVanOpen and GetVehicleDoorAngleRatio(veh, 2) < 0.1 then
                SetVehicleDoorOpen(veh, 2, false, false) SetVehicleDoorOpen(veh, 3, false, false)
            end
        end
    end
    for veh in pairs(Vans) do if not DoesEntityExist(veh) then Vans[veh] = nil end end
end

CreateThread(function()
    local quiet = 0
    while true do
        if anyGuard then
            local found = false
            for _, ped in ipairs(GetGamePool('CPed')) do
                local st = Entity(ped).state.illegalGuard
                if st then
                    found = true
                    if NetworkHasControlOfEntity(ped) and not IsEntityDead(ped) then
                        local g = Guards[ped]
                        if not g or g.run ~= st.run then
                            g = { st = st, run = st.run, mode = 'idle' }
                            Guards[ped] = g
                            configure(ped, st)
                        end
                        behave(ped, g)
                    end
                end
            end
            for ped in pairs(Guards) do if not DoesEntityExist(ped) then Guards[ped] = nil end end
            vanTick()
            if found or next(Vans) then quiet = 0 else quiet = quiet + 1 if quiet > 10 then anyGuard = false end end
            Wait(500)
        else
            Wait(2000)
        end
    end
end)
