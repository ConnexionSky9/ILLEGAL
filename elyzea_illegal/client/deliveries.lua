-- =========================================================
--  ELYZEA ILLÉGAL - CLIENT : LIVRAISON DES COMMANDES
--  Le serveur envoie le lieu seulement quand la commande est prête.
--  Les PNJ (chef bras croisés + gardes armés) et le sac n'existent que
--  chez celui qui a commandé, et seulement quand il approche.
-- =========================================================
local C = Config.Delivery
local Active = {}   -- [id] = { data, blip, peds = {}, bag, spawned }

-- ---------------------------------------------------------
--  Notification « téléphone »
-- ---------------------------------------------------------
function PhoneNotify(title, msg)
    if type(Config.PhoneNotify) == 'function' then
        local ok = pcall(Config.PhoneNotify, title, msg)
        if ok then return end
    end
    if GetResourceState('lb-phone') == 'started' then
        local ok = pcall(function() exports['lb-phone']:SendNotification({ app = 'Messages', title = title, content = msg }) end)
        if ok then return end
    end
    Notify(('📱 %s : %s'):format(title, msg), 'warning')
    PlaySoundFrontend(-1, 'Text_Arrive_Tone', 'Phone_SoundSet_Default', true)
end
RegisterNetEvent('illegal:client:phone', function(title, msg) PhoneNotify(title, msg) end)

-- ---------------------------------------------------------
--  Outils
-- ---------------------------------------------------------
local function groundZ(x, y, hint)
    RequestCollisionAtCoord(x, y, hint)
    for _, start in ipairs({ hint + 2.0, hint + 25.0, 150.0, 400.0 }) do
        local ok, z = GetGroundZFor_3dCoord(x, y, start, false)
        if ok then return z end
    end
    return hint
end

local function offset(x, y, h, angle, dist)
    local r = math.rad(h + angle)
    return x - math.sin(r) * dist, y + math.cos(r) * dist
end

local function bagCoords(d)
    local x, y = offset(d.x, d.y, d.h, 0.0, 1.2)
    return vector3(x, y, d.z)
end

local relGroup
local function relationship()
    if relGroup then return relGroup end
    local _, hash = AddRelationshipGroup('ILLEGAL_DELIVERY')
    relGroup = hash
    SetRelationshipBetweenGroups(1, relGroup, joaat('PLAYER'))   -- respect : ils ne tirent pas
    SetRelationshipBetweenGroups(1, joaat('PLAYER'), relGroup)
    return relGroup
end

local function makePed(model, x, y, z, h)
    local hash = joaat(model)
    if not IsModelInCdimage(hash) or not lib.requestModel(hash, 5000) then
        print(('^1[ILLEGAL] Modèle de PNJ inconnu : %s^7'):format(model))
        return nil
    end
    local ped = CreatePed(4, hash, x, y, z, h, false, false)
    SetModelAsNoLongerNeeded(hash)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCanRagdoll(ped, false)
    SetPedRelationshipGroupHash(ped, relationship())
    FreezeEntityPosition(ped, true)
    return ped
end

-- ---------------------------------------------------------
--  Apparition / disparition
-- ---------------------------------------------------------
local function despawn(a)
    for _, p in ipairs(a.peds) do if DoesEntityExist(p) then DeleteEntity(p) end end
    if a.bag and DoesEntityExist(a.bag) then DeleteEntity(a.bag) end
    a.peds, a.bag, a.spawned = {}, nil, false
end

local function spawn(a)
    local d = a.data
    d.z = groundZ(d.x, d.y, d.z)
    a.spawned = true

    -- Le chef, bras croisés, face au sac
    local boss = makePed(C.bossModel, d.x, d.y, d.z, d.h)
    if boss then
        if lib.requestAnimDict(C.bossAnim.dict, 5000) then
            TaskPlayAnim(boss, C.bossAnim.dict, C.bossAnim.name, 8.0, -8.0, -1, 1, 0.0, false, false, false)
        end
        a.peds[#a.peds + 1] = boss
    end

    -- Les gardes armés, en arc de cercle derrière et autour du chef, tournés vers l'extérieur
    local n = math.max(0, C.guardCount)
    for i = 1, n do
        local angle = n == 1 and 180.0 or (60.0 + (240.0 / (n - 1)) * (i - 1))
        local gx, gy = offset(d.x, d.y, d.h, angle, 4.0)
        local gz = groundZ(gx, gy, d.z)
        local guard = makePed(C.guardModels[math.random(#C.guardModels)], gx, gy, gz, (d.h + angle) % 360.0)
        if guard then
            local weapon = joaat(C.guardWeapons[math.random(#C.guardWeapons)])
            GiveWeaponToPed(guard, weapon, 250, false, true)
            SetCurrentPedWeapon(guard, weapon, true)
            TaskStartScenarioInPlace(guard, C.guardScenario, 0, true)
            a.peds[#a.peds + 1] = guard
        end
    end

    -- Le sac, posé devant le chef
    local bag = bagCoords(d)
    local hash = joaat(C.bagModel)
    if lib.requestModel(hash, 5000) then
        a.bag = CreateObject(hash, bag.x, bag.y, groundZ(bag.x, bag.y, d.z), false, false, false)
        PlaceObjectOnGroundProperly(a.bag)
        FreezeEntityPosition(a.bag, true)
        SetModelAsNoLongerNeeded(hash)
    end
end

local function removeDelivery(id)
    local a = Active[id]
    if not a then return end
    despawn(a)
    if a.blip and DoesBlipExist(a.blip) then RemoveBlip(a.blip) end
    Active[id] = nil
end

local function setGps(d)
    SetNewWaypoint(d.x, d.y)
end

-- ---------------------------------------------------------
--  Évènements serveur
-- ---------------------------------------------------------
RegisterNetEvent('illegal:client:delivery', function(d, fresh)
    if type(d) ~= 'table' or not d.id then return end
    removeDelivery(d.id)
    local blip = AddBlipForCoord(d.x, d.y, d.z)
    SetBlipSprite(blip, C.blip.sprite)
    SetBlipColour(blip, C.blip.color)
    SetBlipScale(blip, C.blip.scale)
    SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(('%s : %s'):format(C.blip.label, d.order or ''))
    EndTextCommandSetBlipName(blip)
    Active[d.id] = { data = d, blip = blip, peds = {}, spawned = false }
    if fresh then setGps(d) end
end)

RegisterNetEvent('illegal:client:deliveryDone', function(id) removeDelivery(id) end)

-- Tablette : « Remettre le GPS »
function DeliveryGps(id)
    local a = Active[tonumber(id) or -1]
    if not a then return false end
    setGps(a.data)
    return true
end

-- ---------------------------------------------------------
--  Boucle : rien à faire sans livraison ; 1 vérification / s ; chaque image près du sac
-- ---------------------------------------------------------
local prompt = false
CreateThread(function()
    while true do
        local wait = 1000
        if next(Active) then
            local pos = GetEntityCoords(PlayerPedId())
            local nearId
            for id, a in pairs(Active) do
                local d = a.data
                local dist = #(pos.xy - vector2(d.x, d.y))
                if dist <= C.spawnDistance and not a.spawned then spawn(a)
                elseif dist > C.spawnDistance + 50.0 and a.spawned then despawn(a) end
                if a.spawned and #(pos - bagCoords(d)) <= C.pickupDistance + 1.0 then nearId = id end
            end
            if nearId then
                wait = 0
                Prompt.show('bag', 'Appuyer pour ramasser le sac', Active[nearId].data.order or 'Commande')
                prompt = true
                if IsControlJustReleased(0, 38) then
                    TriggerServerEvent('illegal:server:pickup', nearId)
                    Wait(1000)
                end
            elseif prompt then
                Prompt.hide('bag') prompt = false
            end
        elseif prompt then
            Prompt.hide('bag') prompt = false
        end
        Wait(wait)
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    for id in pairs(Active) do removeDelivery(id) end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if prompt then Prompt.hide('bag') end
    for id in pairs(Active) do removeDelivery(id) end
end)
