-- =========================================================
--  ELYZEA ILLÉGAL - CLIENT : PNJ DES GROUPES
--  Les PNJ sont créés localement, seulement à proximité.
--  Boucle légère : 1 vérification par seconde loin des PNJ,
--  chaque image uniquement à portée d'interaction.
-- =========================================================
local PedDefs = {}      -- liste reçue du serveur
local Spawned = {}      -- [groupId] = { entity, version }
local promptFor = nil

local function deleteSpawned(groupId)
    local s = Spawned[groupId]
    if s and DoesEntityExist(s.entity) then DeleteEntity(s.entity) end
    Spawned[groupId] = nil
end

local function spawn(def)
    local hash = joaat(def.model)
    if not IsModelInCdimage(hash) then
        print(('^1[ILLEGAL] Modèle de PNJ inconnu : %s (groupe %s)^7'):format(def.model, def.label))
        Spawned[def.groupId] = { entity = 0, version = def.version, invalid = true }
        return
    end
    if not lib.requestModel(hash, 5000) then return end
    local ped = CreatePed(4, hash, def.x, def.y, def.z, def.h, false, false)
    SetModelAsNoLongerNeeded(hash)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)
    SetPedFleeAttributes(ped, 0, false)
    SetPedDiesWhenInjured(ped, false)
    FreezeEntityPosition(ped, true)
    if def.scenario and def.scenario ~= '' then TaskStartScenarioInPlace(ped, def.scenario, 0, true) end
    Spawned[def.groupId] = { entity = ped, version = def.version }
end

local function hidePrompt()
    if promptFor then Prompt.hide('ped') promptFor = nil end
end

RegisterNetEvent('illegal:client:peds', function(list)
    PedDefs = type(list) == 'table' and list or {}
    -- Supprime les PNJ retirés, déplacés ou à faire réapparaître
    local keep = {}
    for _, d in ipairs(PedDefs) do keep[d.groupId] = d end
    for groupId, s in pairs(Spawned) do
        local d = keep[groupId]
        if not d or d.version ~= s.version then deleteSpawned(groupId) end
    end
    hidePrompt()
end)

CreateThread(function()
    while true do
        local wait = 1000
        local pos = GetEntityCoords(PlayerPedId())
        local near, nearDist = nil, nil
        for _, d in ipairs(PedDefs) do
            local dist = #(pos - vector3(d.x, d.y, d.z))
            if dist <= Config.Ped.spawnDistance then
                if not Spawned[d.groupId] then spawn(d) end
                if dist <= Config.Ped.interactDistance + 1.0 and (not nearDist or dist < nearDist) then near, nearDist = d, dist end
            elseif Spawned[d.groupId] then
                deleteSpawned(d.groupId)
            end
        end

        if near and nearDist <= Config.Ped.interactDistance + 1.0 then
            wait = 0
            Prompt.show('ped', 'Appuyer pour ouvrir le menu', near.label)
            promptFor = near.groupId
            if IsControlJustReleased(0, Config.Ped.key) and not IsTabletOpen() then
                -- Le serveur vérifie la distance ET l'appartenance au groupe
                TriggerServerEvent('illegal:server:open', 'ped', near.groupId)
            end
        else
            hidePrompt()
        end
        Wait(wait)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    hidePrompt()
    for groupId in pairs(Spawned) do deleteSpawned(groupId) end
end)
