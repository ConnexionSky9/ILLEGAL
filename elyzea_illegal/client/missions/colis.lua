-- =========================================================
--  ELYZEA ILLÉGAL - CLIENT : MISSION « COLIS »
--  GPS de l'emplacement, colis (objet local), fouille des gardes (ALT),
--  ouverture, puis GPS et PNJ de livraison (ALT). Les boucles ne tournent
--  que pendant la mission ; objets et PNJ n'existent qu'à proximité.
-- =========================================================
local M = MissionClient
local S = { blips = {}, crate = nil, pedDeliv = nil, targets = {} }
local OWNER = 'mission'

local function clearBlips() for _, b in ipairs(S.blips) do M.removeBlip(b) end S.blips = {} end

local function deleteEnt(e) if e and DoesEntityExist(e) then DeleteEntity(e) end end

local function removeTargets()
    if M.useTarget() then
        for _, e in ipairs(S.targets) do pcall(function() exports.ox_target:removeLocalEntity(e) end) end
    end
    S.targets = {}
end

local function despawnAll()
    removeTargets()
    deleteEnt(S.crate) S.crate = nil
    deleteEnt(S.pedDeliv) S.pedDeliv = nil
end

local function groundZ(x, y, z)
    RequestCollisionAtCoord(x, y, z)
    local ok, gz = GetGroundZFor_3dCoord(x, y, z + 3.0, false)
    return ok and gz or z
end

-- ---------------------------------------------------------
--  Actions (passent toutes par le serveur)
-- ---------------------------------------------------------
local function searchGuard(ent)
    local run = M.run
    if M.busy or not run or not DoesEntityExist(ent) then return end
    local netId = NetworkGetNetworkIdFromEntity(ent)
    M.action('search', netId, 'start')
    if M.progress('Fouille du garde', run.searchSeconds or 4, 'amb@medic@standing@kneel@base', 'base', GetEntityCoords(ent), 3.0) then
        M.action('search', netId, 'done')
    else
        Notify('Fouille annulée.', 'info')
    end
end

local function openCrate() if not M.busy then M.action('open', 'start') end end

local function deliver()
    local run = M.run
    if M.busy or not run or not run.delivery then return end
    local d = run.delivery
    M.action('deliver', 'start')
    if M.progress(d.text or 'Livraison', d.seconds or 3, d.animDict, d.animName, vector3(d.x, d.y, d.z), (d.distance or 2.0) + 1.5) then
        M.action('deliver', 'done')
    else
        Notify('Livraison annulée.', 'info')
    end
end

local function isSearchable(ent)
    local run = M.run
    if not run or not ent or ent == 0 or not DoesEntityExist(ent) then return false end
    local st = Entity(ent).state
    return st.illegalGuard ~= nil and st.illegalGuard.run == run.runId and IsEntityDead(ent) and not st.illegalSearched
end

-- ox_target (ALT) s'il est installé : « Fouiller le garde » sur les gardes neutralisés
CreateThread(function()
    Wait(3000)
    if M.useTarget() then
        pcall(function()
            exports.ox_target:addGlobalPed({
                { name = 'illegal_mission_search', icon = 'fa-solid fa-magnifying-glass', label = 'Fouiller le garde', distance = 2.2,
                  canInteract = function(ent) return isSearchable(ent) end,
                  onSelect = function(data) searchGuard(data.entity) end },
            })
        end)
    end
end)

-- ---------------------------------------------------------
--  Objets / PNJ (créés seulement à proximité)
-- ---------------------------------------------------------
local function spawnCrate(run)
    local l, c = run.location, run.crate
    local hash = joaat(c.model)
    if not IsModelInCdimage(hash) or not lib.requestModel(hash, 5000) then return end
    S.crate = CreateObject(hash, l.x, l.y, groundZ(l.x, l.y, l.z), false, false, false)
    PlaceObjectOnGroundProperly(S.crate)
    FreezeEntityPosition(S.crate, true)
    SetModelAsNoLongerNeeded(hash)
    if M.useTarget() then
        pcall(function()
            exports.ox_target:addLocalEntity(S.crate, {
                { name = 'illegal_mission_open', icon = 'fa-solid fa-box-open', label = 'Ouvrir le colis', distance = 2.5,
                  canInteract = function() return M.run and M.run.stage == 'crate' and M.run.hasKey end, onSelect = openCrate },
            })
        end)
        S.targets[#S.targets + 1] = S.crate
    end
end

local function spawnDeliveryPed(run)
    local d = run.delivery
    local hash = joaat(d.ped)
    if not IsModelInCdimage(hash) or not lib.requestModel(hash, 5000) then return end
    local ped = CreatePed(4, hash, d.x, d.y, groundZ(d.x, d.y, d.z), d.h or 0.0, false, false)
    SetModelAsNoLongerNeeded(hash)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)
    if d.scenario and d.scenario ~= '' then TaskStartScenarioInPlace(ped, d.scenario, 0, true) end
    S.pedDeliv = ped
    if M.useTarget() then
        pcall(function()
            exports.ox_target:addLocalEntity(ped, {
                { name = 'illegal_mission_deliver', icon = 'fa-solid fa-handshake', label = d.text or 'Livrer le colis', distance = (d.distance or 2.0) + 0.5,
                  canInteract = function() return M.run and M.run.stage == 'deliver' and M.run.carrier end, onSelect = deliver },
            })
        end)
        S.targets[#S.targets + 1] = ped
    end
end

-- ---------------------------------------------------------
--  Mises à jour envoyées par le serveur
-- ---------------------------------------------------------
local function update(run, prev)
    local first = not prev
    if run.stage ~= 'deliver' and (first or #S.blips == 0) then
        clearBlips()
        local l = run.location
        S.blips[#S.blips + 1] = M.radiusBlip(l.x, l.y, l.z, l.radius, 1)
        S.blips[#S.blips + 1] = M.blip(l.x, l.y, l.z, 501, 1, ('Mission : %s'):format(run.label), true)
        SetNewWaypoint(l.x, l.y)
    end
    if run.stage == 'deliver' and (first or prev.stage ~= 'deliver') then
        -- Colis récupéré : le premier GPS disparaît, nouveau point de livraison
        clearBlips()
        deleteEnt(S.crate) S.crate = nil
        local d = run.delivery
        S.blips[#S.blips + 1] = M.blip(d.x, d.y, d.z, d.blipSprite, d.blipColor, ('Livraison : %s'):format(d.label), true)
        SetNewWaypoint(d.x, d.y)
    end
end

local function stop()
    clearBlips()
    despawnAll()
    Prompt.hide(OWNER)
end

local function progress(kind, seconds)
    local run = M.run
    if kind ~= 'open' or not run then return end
    local l = run.location
    if M.progress('Ouverture du colis', seconds, run.crate.animDict, run.crate.animName, vector3(l.x, l.y, l.z), 4.0) then
        M.action('open', 'done')
    else
        M.action('open', 'cancel')
        Notify('Ouverture annulée.', 'info')
    end
end

M.registerType('colis', { update = update, stop = stop, progress = progress })

-- ---------------------------------------------------------
--  Boucle : seulement pendant une mission « colis »
-- ---------------------------------------------------------
local lastVehicleReport = 0
CreateThread(function()
    while true do
        local run = M.run
        local sleep = 1000
        local shown = false
        if run and run.type == 'colis' and not M.busy then
            local ped = PlayerPedId()
            local me = GetEntityCoords(ped)
            local l = run.location
            local dLoc = #(me - vector3(l.x, l.y, l.z))
            local reach = run.interactDistance or 2.5
            local useTarget = M.useTarget()

            if run.stage ~= 'deliver' then
                if dLoc < 120.0 and not S.crate then spawnCrate(run) elseif dLoc > 170.0 and S.crate then deleteEnt(S.crate) S.crate = nil end
                if dLoc < 60.0 then sleep = 0 end
                -- Véhicule interdit dans la zone (signalé au serveur, qui décide)
                if run.weapons and run.weapons.vehicles == false and dLoc < (l.radius or 30) and IsPedInAnyVehicle(ped, false)
                    and GetGameTimer() - lastVehicleReport > 5000 then
                    lastVehicleReport = GetGameTimer()
                    M.action('vehicle')
                end
                if sleep == 0 and not IsPedInAnyVehicle(ped, false) and not IsEntityDead(ped) then
                    -- Le colis
                    if S.crate and #(me - GetEntityCoords(S.crate)) <= reach then
                        if not run.hasKey then
                            Prompt.show(OWNER, 'Colis verrouillé', ('%s : sur un des gardes'):format(run.keyLabel or 'La clé'), 'E', true) shown = true
                        elseif not useTarget then
                            shown = true
                            if M.alt(OWNER, 'Ouvrir le colis', run.label) then Prompt.hide(OWNER) openCrate() end
                        end
                    elseif not useTarget then
                        -- Gardes neutralisés à fouiller
                        local best, bd
                        for _, p in ipairs(GetGamePool('CPed')) do
                            if isSearchable(p) then
                                local d = #(me - GetEntityCoords(p))
                                if d <= 2.2 and (not bd or d < bd) then best, bd = p, d end
                            end
                        end
                        if best then
                            shown = true
                            if M.alt(OWNER, 'Fouiller le garde', 'Garde neutralisé') then Prompt.hide(OWNER) searchGuard(best) end
                        end
                    end
                end
            elseif run.delivery then
                local d = run.delivery
                local dd = #(me - vector3(d.x, d.y, d.z))
                if dd < 120.0 and not S.pedDeliv then spawnDeliveryPed(run) elseif dd > 170.0 and S.pedDeliv then deleteEnt(S.pedDeliv) S.pedDeliv = nil end
                if dd < 30.0 then sleep = 0 end
                if dd <= (d.distance or 2.0) and not IsPedInAnyVehicle(ped, false) then
                    if not run.carrier then
                        Prompt.show(OWNER, 'Point de livraison', ('%s porte le colis'):format(run.carrierName or 'Ton coéquipier'), 'E', true) shown = true
                    elseif not useTarget then
                        shown = true
                        if M.alt(OWNER, d.text or 'Livrer le colis', d.label) then Prompt.hide(OWNER) deliver() end
                    end
                end
            end
        end
        if not shown then Prompt.hide(OWNER) end
        Wait(sleep)
    end
end)

-- Surbrillance du garde qui porte la clé (après plusieurs fouilles ratées)
CreateThread(function()
    while true do
        local run = M.run
        if run and run.type == 'colis' and run.stage == 'guards' then
            local list = {}
            for _, ped in ipairs(GetGamePool('CPed')) do
                local st = Entity(ped).state
                if st.illegalKeyHint and not st.illegalSearched and st.illegalGuard and st.illegalGuard.run == run.runId then list[#list + 1] = ped end
            end
            local untilT = GetGameTimer() + 500
            while #list > 0 and GetGameTimer() < untilT do
                local t = GetGameTimer() / 1000.0
                for _, ped in ipairs(list) do
                    if DoesEntityExist(ped) then
                        local c = GetEntityCoords(ped)
                        DrawMarker(25, c.x, c.y, c.z - 0.95, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.6, 1.6, 1.0, 241, 216, 153, 170, false, false, 2, false, nil, nil, false)
                        DrawMarker(2, c.x, c.y, c.z + 1.0 + math.sin(t * 3.0) * 0.12, 0.0, 0.0, 0.0, 180.0, 0.0, 0.0, 0.35, 0.35, 0.35, 217, 181, 106, 230, true, true, 2, false, nil, nil, false)
                    end
                end
                Wait(0)
            end
            if #list == 0 then Wait(500) end
        else
            Wait(1500)
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then stop() end
end)
