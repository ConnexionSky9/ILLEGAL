-- =========================================================
--  ELYZEA ILLÉGAL - CLIENT : COFFRES DES GROUPES
--  L'objet n'existe chez le joueur qu'à proximité ; [E] demande
--  l'ouverture au serveur, qui vérifie groupe, grade et distance.
-- =========================================================
local S = Config.Stash
local Defs = {}      -- liste reçue du serveur
local Spawned = {}   -- [groupId] = { entity, version }
local prompt = nil

local function delete(groupId)
    local s = Spawned[groupId]
    if s and s.entity and DoesEntityExist(s.entity) then DeleteEntity(s.entity) end
    Spawned[groupId] = nil
end

local function spawn(d)
    local hash = joaat(d.model)
    Spawned[d.groupId] = { version = d.version }
    if not IsModelInCdimage(hash) or not lib.requestModel(hash, 5000) then
        print(('^1[ILLEGAL] Modèle de coffre inconnu : %s^7'):format(d.model))
        return
    end
    local obj = CreateObject(hash, d.x, d.y, d.z, false, false, false)
    SetEntityHeading(obj, d.h)
    PlaceObjectOnGroundProperly(obj)
    FreezeEntityPosition(obj, true)
    SetModelAsNoLongerNeeded(hash)
    Spawned[d.groupId].entity = obj
end

local function hidePrompt() if prompt then lib.hideTextUI() prompt = nil end end

RegisterNetEvent('illegal:client:stashes', function(list)
    Defs = type(list) == 'table' and list or {}
    local keep = {}
    for _, d in ipairs(Defs) do keep[d.groupId] = d end
    for groupId, s in pairs(Spawned) do
        if not keep[groupId] or keep[groupId].version ~= s.version then delete(groupId) end
    end
    hidePrompt()
end)

CreateThread(function()
    while true do
        local wait = 1000
        if #Defs > 0 then
            local pos = GetEntityCoords(PlayerPedId())
            local near
            for _, d in ipairs(Defs) do
                local dist = #(pos - vector3(d.x, d.y, d.z))
                if dist <= S.spawnDistance then
                    if not Spawned[d.groupId] then spawn(d) end
                    if dist <= S.interactDistance + 1.0 then near = d end
                elseif Spawned[d.groupId] then
                    delete(d.groupId)
                end
            end
            if near then
                wait = 0
                if prompt ~= near.groupId then lib.showTextUI(('[E] Ouvrir le coffre (%s)'):format(near.label)) prompt = near.groupId end
                if IsControlJustReleased(0, 38) and not IsTabletOpen() then
                    TriggerServerEvent('illegal:server:openStash', near.groupId)
                    Wait(800)
                end
            else
                hidePrompt()
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
    for groupId in pairs(Spawned) do delete(groupId) end
end)
