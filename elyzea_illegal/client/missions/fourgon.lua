-- =========================================================
--  ELYZEA ILLÉGAL - CLIENT : MISSION « LE FOURGON FANTÔME »
--  Affiche ce que le serveur envoie (zones, indices, fourgon, caisses,
--  relais, livraison) et transmet les intentions du joueur. Aucune
--  décision ici : le serveur valide étape, distance, durée et code.
--  Objets et PNJ créés localement, seulement à proximité ; boucle
--  active uniquement pendant la mission.
-- =========================================================
local M = MissionClient
local OWNER = 'fourgon'
local S = { blips = {}, blipSig = nil, props = {}, crates = {}, peds = {} }

local function deleteEnt(e) if e and DoesEntityExist(e) then DeleteEntity(e) end end
local function clearBlips() for _, b in ipairs(S.blips) do M.removeBlip(b) end S.blips = {} S.blipSig = nil end
local function groundZ(x, y, z)
    RequestCollisionAtCoord(x, y, z)
    local ok, gz = GetGroundZFor_3dCoord(x, y, z + 3.0, false)
    return ok and gz or z
end

local function spawnProp(model, x, y, z, h)
    local hash = joaat(model)
    if not IsModelInCdimage(hash) or not lib.requestModel(hash, 5000) then return nil end
    local o = CreateObject(hash, x, y, groundZ(x, y, z), false, false, false)
    SetEntityHeading(o, h or 0.0)
    PlaceObjectOnGroundProperly(o)
    FreezeEntityPosition(o, true)
    SetModelAsNoLongerNeeded(hash)
    return o
end

local function spawnPed(model, x, y, z, h, scenario)
    local hash = joaat(model)
    if not IsModelInCdimage(hash) or not lib.requestModel(hash, 5000) then return nil end
    local p = CreatePed(4, hash, x, y, groundZ(x, y, z), h or 0.0, false, false)
    SetModelAsNoLongerNeeded(hash)
    SetEntityInvincible(p, true)
    SetBlockingOfNonTemporaryEvents(p, true)
    FreezeEntityPosition(p, true)
    if scenario and scenario ~= '' then TaskStartScenarioInPlace(p, scenario, 0, true) end
    return p
end

local function despawnAll()
    for k, o in pairs(S.props) do deleteEnt(o) S.props[k] = nil end
    for k, o in pairs(S.crates) do deleteEnt(o) S.crates[k] = nil end
    for k, p in pairs(S.peds) do deleteEnt(p) S.peds[k] = nil end
end

local function ent(netId) if netId and NetworkDoesNetworkIdExist(netId) then return NetworkGetEntityFromNetworkId(netId) end end

-- ---------------------------------------------------------
--  Blips / GPS : reconstruits quand l'objectif change
-- ---------------------------------------------------------
local function blips(run)
    local sig = table.concat({ run.stage, tostring(run.target and run.target.x), tostring(run.trace ~= nil), tostring(run.fake),
        tostring(run.relay and run.relay.x), tostring(run.delivery and run.delivery.x), tostring(run.dropped and run.dropped.x) }, '|')
    if sig == S.blipSig then return end
    clearBlips()
    S.blipSig = sig
    local function gps(x, y) SetNewWaypoint(x, y) end
    if run.stage == 'SEARCH_AREA' or run.stage == 'FIND_CLUES' then
        local a = run.area
        S.blips[#S.blips + 1] = M.radiusBlip(a.x, a.y, a.z, a.radius, 5)
        S.blips[#S.blips + 1] = M.blip(a.x, a.y, a.z, 67, 5, 'Zone de recherche : fourgon', false)
        if run.stage == 'SEARCH_AREA' then gps(a.x, a.y) end
    elseif run.stage == 'LOCATE_VAN' and run.target then
        local t = run.target
        if t.exact then S.blips[#S.blips + 1] = M.blip(t.x, t.y, t.z, 67, 1, 'Fourgon', true)
        else
            S.blips[#S.blips + 1] = M.radiusBlip(t.x, t.y, t.z, t.radius, 1)
            S.blips[#S.blips + 1] = M.blip(t.x, t.y, t.z, 67, 1, 'Fourgon (zone)', false)
        end
        gps(t.x, t.y)
    elseif (run.stage == 'TRANSPORT' and run.relay) then
        local r = run.relay
        S.blips[#S.blips + 1] = M.blip(r.x, r.y, r.z, 514, 46, ('Relais : %s'):format(r.label), true)
        gps(r.x, r.y)
    end
    if run.delivery then
        local d = run.delivery
        S.blips[#S.blips + 1] = M.blip(d.x, d.y, d.z, d.blipSprite, d.blipColor, ('Livraison : %s'):format(d.label), true)
        gps(d.x, d.y)
    end
    if run.dropped then
        S.blips[#S.blips + 1] = M.blip(run.dropped.x, run.dropped.y, run.dropped.z, 478, 1, 'Marchandise tombée', false)
    end
end

-- ---------------------------------------------------------
--  Actions longues : barre de progression puis confirmation au serveur
-- ---------------------------------------------------------
local function timed(name, arg, label, seconds, dict, anim, at)
    if M.busy then return end
    if arg ~= nil then M.action(name, arg, 'start') else M.action(name, 'start') end
    if M.progress(label, seconds, dict, anim, at, 4.0) then
        if arg ~= nil then M.action(name, arg, 'done') else M.action(name, 'done') end
    else
        if arg ~= nil then M.action(name, arg, 'cancel') else M.action(name, 'cancel') end
        Notify('Action annulée.', 'info')
    end
end

-- Saisie du code d'une caisse (fenêtre au design du MenuStaff) : vérifié par le serveur
local codeCrate = nil
local function askCode(i, jammed)
    codeCrate = i
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'codeInput', crate = i, jammed = jammed == true })
end
RegisterNUICallback('codeResult', function(body, cb)
    cb('ok')
    SetNuiFocus(false, false)
    local i = codeCrate
    codeCrate = nil
    if not i or not M.run or type(body) ~= 'table' then return end
    if body.action == 'code' then M.action('code', i, tostring(body.code or ''):sub(1, 12))
    elseif body.action == 'force' then M.action('crate', i, 'start') end
end)

-- Le serveur autorise une action longue (ouverture du fourgon, caisse)
local function progress(kind, seconds, idx)
    local run = M.run
    if not run then return end
    local c = run.crates and run.crates[idx or 0]
    local at = c and vector3(c.x, c.y, c.z) or (run.van and ent(run.van) and GetEntityCoords(ent(run.van)))
    local label = kind == 'rear' and (run.locked and 'Ouverture forcée du fourgon' or 'Ouverture du fourgon')
        or kind == 'force' and ('Caisse n°%d : forçage'):format(idx) or ('Caisse n°%d : ouverture'):format(idx)
    local key, arg = kind == 'rear' and 'rear' or 'crate', kind ~= 'rear' and idx or nil
    if M.progress(label, seconds, run.anim.dict, run.anim.name, at, 4.0) then
        if arg then M.action(key, arg, 'done') else M.action(key, 'done') end
    else
        if arg then M.action(key, arg, 'cancel') else M.action(key, 'cancel') end
        Notify('Action annulée.', 'info')
    end
end

local function update(run) blips(run) end

local function stop()
    clearBlips()
    despawnAll()
    Prompt.hide(OWNER)
    if codeCrate then codeCrate = nil SetNuiFocus(false, false) SendNUIMessage({ action = 'codeClose' }) end
end

M.registerType('fourgon', { update = update, stop = stop, progress = progress })

-- ---------------------------------------------------------
--  Boucle (uniquement pendant la mission « fourgon »)
-- ---------------------------------------------------------
local lastVehicleReport = 0
CreateThread(function()
    while true do
        local run = M.run
        local sleep = 1000
        local shown = false
        if run and run.type == 'fourgon' and not M.busy then
            local ped = PlayerPedId()
            local me = GetEntityCoords(ped)
            local reach = (run.interactDistance or 2.5)
            local onFoot = not IsPedInAnyVehicle(ped, false) and not IsEntityDead(ped)
            local function want(owner, verb, name, fn)
                if shown then return end
                shown = true
                if M.interact(owner, verb, name) then Prompt.hide(owner) fn() end
            end

            -- Indices (objets locaux)
            local keep = {}
            for _, c in ipairs(run.clues or {}) do
                keep[c.i] = true
                local d = #(me - vector3(c.x, c.y, c.z))
                if d < 80.0 and not S.props[c.i] then S.props[c.i] = spawnProp(c.model, c.x, c.y, c.z, c.h)
                elseif d > 110.0 and S.props[c.i] then deleteEnt(S.props[c.i]) S.props[c.i] = nil end
                if d < 30.0 then sleep = 0 end
                if d <= reach and onFoot then
                    want(OWNER, 'Rechercher un indice', c.label, function()
                        timed('clue', c.i, ('Indice : %s'):format(c.label), c.seconds or 4, c.animDict, c.animName, vector3(c.x, c.y, c.z))
                    end)
                end
            end
            for i, o in pairs(S.props) do if not keep[i] then deleteEnt(o) S.props[i] = nil end end

            -- Fourgon déplacé : traces à l'emplacement d'origine
            if run.trace then
                local d = #(me - vector3(run.trace.x, run.trace.y, run.trace.z))
                if d < 30.0 then sleep = 0 end
                if d <= 6.0 and onFoot then
                    want(OWNER, 'Examiner les traces', 'Emplacement d\'origine du fourgon', function()
                        timed('trace', nil, 'Examen des traces', run.seconds.trace, 'amb@medic@standing@kneel@base', 'base', vector3(run.trace.x, run.trace.y, run.trace.z))
                    end)
                end
            end

            -- Faux fourgon
            local fake = ent(run.fake)
            if fake and DoesEntityExist(fake) then
                local d = #(me - GetEntityCoords(fake))
                if d < 30.0 then sleep = 0 end
                if d <= 5.0 and onFoot then
                    want(OWNER, 'Inspecter le véhicule', 'Fourgon suspect', function()
                        timed('inspectFake', nil, 'Inspection du véhicule', run.seconds.fake, 'amb@prop_human_bum_bin@base', 'base', GetEntityCoords(fake))
                    end)
                end
            end

            -- Vrai fourgon : cabine puis arrière
            local van = ent(run.van)
            if van and DoesEntityExist(van) and (run.stage == 'INVESTIGATE_VAN' or run.stage == 'RECOVER_CARGO' or (run.stage == 'TRANSPORT' and not run.cabinDone)) then
                local vc = GetEntityCoords(van)
                local d = #(me - vc)
                if d < 30.0 then sleep = 0 end
                if d <= 6.0 and onFoot then
                    local rear = GetOffsetFromEntityInWorldCoords(van, 0.0, -3.4, 0.0)
                    local front = GetOffsetFromEntityInWorldCoords(van, -1.3, 1.2, 0.0)
                    if not run.cabinDone and #(me - front) <= 2.5 then
                        want(OWNER, 'Fouiller la cabine', 'Fourgon', function()
                            timed('cabin', nil, 'Fouille de la cabine', run.seconds.cabin, 'amb@prop_human_bum_bin@base', 'base', front)
                        end)
                    elseif run.stage == 'INVESTIGATE_VAN' and #(me - rear) <= 3.0 then
                        want(OWNER, run.locked and 'Forcer l\'arrière (alarme possible)' or 'Ouvrir l\'arrière', 'Fourgon', function() M.action('rear', 'start') end)
                    end
                end
            end

            -- Caisses
            local ckeep = {}
            for i, c in ipairs(run.crates or {}) do
                ckeep[i] = true
                local d = #(me - vector3(c.x, c.y, c.z))
                if d < 80.0 and not S.crates[i] then S.crates[i] = spawnProp(run.crateModel or 'prop_box_wood02a', c.x, c.y, c.z, 0.0) end
                if d < 30.0 then sleep = 0 end
                if d <= reach and onFoot then
                    local name = ('Caisse n°%d%s'):format(i, c.secure and ' (sécurisée)' or '')
                    if c.opened and c.real and run.stage == 'RECOVER_CARGO' then
                        want(OWNER, run.recoverText or 'Récupérer la marchandise', name, function()
                            timed('recover', nil, run.recoverText or 'Récupération', run.seconds.recover, run.anim.dict, run.anim.name, vector3(c.x, c.y, c.z))
                        end)
                    elseif not c.opened and c.secure and not c.unlocked then
                        want(OWNER, c.jammed and 'Forcer la caisse (alarme)' or 'Entrer le code', name, function()
                            if c.jammed then M.action('crate', i, 'start') else askCode(i, false) end
                        end)
                    elseif not c.opened then
                        want(OWNER, 'Ouvrir la caisse', name, function() M.action('crate', i, 'start') end)
                    elseif not shown then
                        shown = true
                        Prompt.show(OWNER, c.real and 'Vraie marchandise' or 'Caisse ouverte', ({ empty = 'Vide', fake = 'Faux contenu', alarm = 'Piégée', ambush = 'Embuscade' })[c.outcome] or name, 'E', true)
                    end
                end
            end
            for i, o in pairs(S.crates) do if not ckeep[i] then deleteEnt(o) S.crates[i] = nil end end

            -- Marchandise tombée
            if run.dropped then
                local d = #(me - vector3(run.dropped.x, run.dropped.y, run.dropped.z))
                if d < 30.0 then sleep = 0 end
                if d <= reach + 0.5 and onFoot then
                    want(OWNER, 'Ramasser la marchandise', 'Marchandise', function()
                        timed('pickup', nil, 'Ramassage', 2, 'pickup_object', 'pickup_low', vector3(run.dropped.x, run.dropped.y, run.dropped.z))
                    end)
                end
            end

            -- Relais
            if run.relay then
                local r = run.relay
                local d = #(me - vector3(r.x, r.y, r.z))
                if d < 120.0 and r.type == 'ped' and not S.peds.relay then S.peds.relay = spawnPed(r.ped, r.x, r.y, r.z, r.h, r.scenario) end
                if d < 30.0 then sleep = 0 end
                if r.type == 'zone' and d < 60.0 then DrawMarker(1, r.x, r.y, r.z - 1.0, 0, 0, 0, 0, 0, 0, r.radius * 2, r.radius * 2, 1.0, 217, 181, 106, 90, false, false, 2, false, nil, nil, false) end
                if d <= r.radius and onFoot then
                    if run.carrier then
                        want(OWNER, r.text, r.label, function() timed('relay', nil, r.text, r.seconds, 'mp_common', 'givetake1_a', vector3(r.x, r.y, r.z)) end)
                    elseif not shown then
                        shown = true
                        Prompt.show(OWNER, 'Point relais', ('%s porte la marchandise'):format(run.carrierName or 'Ton coéquipier'), 'E', true)
                    end
                end
            elseif S.peds.relay then deleteEnt(S.peds.relay) S.peds.relay = nil end

            -- Livraison finale
            if run.delivery then
                local dl = run.delivery
                local d = #(me - vector3(dl.x, dl.y, dl.z))
                if d < 120.0 and not S.peds.delivery then S.peds.delivery = spawnPed(dl.ped, dl.x, dl.y, dl.z, dl.h, dl.scenario) end
                if d < 30.0 then sleep = 0 end
                if d <= dl.distance and onFoot then
                    if run.carrier then
                        want(OWNER, dl.text, dl.label, function() timed('deliver', nil, dl.text, dl.seconds, dl.animDict, dl.animName, vector3(dl.x, dl.y, dl.z)) end)
                    elseif not shown then
                        shown = true
                        Prompt.show(OWNER, 'Commanditaire', ('%s porte la marchandise'):format(run.carrierName or 'Ton coéquipier'), 'E', true)
                    end
                end
            elseif S.peds.delivery then deleteEnt(S.peds.delivery) S.peds.delivery = nil end

            -- Véhicules interdits dans la zone du fourgon (signalé au serveur, qui décide)
            if run.weapons and run.weapons.vehicles == false and IsPedInAnyVehicle(ped, false) and van and #(me - GetEntityCoords(van)) < 40.0
                and GetGameTimer() - lastVehicleReport > 5000 then
                lastVehicleReport = GetGameTimer()
                M.action('vehicle')
            end
        end
        if not shown then Prompt.hide(OWNER) end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() then stop() end end)
