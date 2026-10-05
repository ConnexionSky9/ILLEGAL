-- =========================================================
--  WALLHACK
--  - En 3D : nom, ID, distance, vie/armure et véhicule de chaque
--    joueur proche, visibles à travers les murs (+ trait optionnel)
--  - Sur la carte : tous les joueurs du serveur, même très loin
--    (positions envoyées par le serveur)
-- =========================================================
local WH = Config.Wallhack
local blips = {}

local function clearBlips()
    for _, b in pairs(blips) do if DoesBlipExist(b) then RemoveBlip(b) end end
    blips = {}
end

function SetWallhack(state)
    State.wallhack = state == true
    TriggerServerEvent('adminmenu:wallhack', State.wallhack)
    if not State.wallhack then clearBlips() end
    Notify(State.wallhack and 'Wallhack activé.' or 'Wallhack désactivé.', 'info')
end

RegisterNetEvent('adminmenu:wallhackOff', function()
    State.wallhack = false
    clearBlips()
end)

-- ---------------------------------------------------------
--  Blips de la carte
-- ---------------------------------------------------------
RegisterNetEvent('adminmenu:positions', function(list)
    if not State.wallhack or not WH.blips then return end
    local me = GetPlayerServerId(PlayerId())
    local seen = {}

    for _, p in ipairs(list) do
        if p.id ~= me then
            seen[p.id] = true
            local b = blips[p.id]
            if not b or not DoesBlipExist(b) then
                b = AddBlipForCoord(p.x, p.y, p.z)
                SetBlipScale(b, 0.85)
                SetBlipColour(b, 3)
                SetBlipAsShortRange(b, false)
                SetBlipCategory(b, 7)
                ShowHeadingIndicatorOnBlip(b, true)
                blips[p.id] = b
            end
            SetBlipSprite(b, p.veh and 225 or 1)
            SetBlipColour(b, 3)
            ShowHeadingIndicatorOnBlip(b, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(('[%d] %s'):format(p.id, p.name))
            EndTextCommandSetBlipName(b)
            -- Si le joueur est chargé autour de nous, le thread ci-dessous
            -- donne une position plus précise
            if GetPlayerFromServerId(p.id) == -1 then
                SetBlipCoords(b, p.x, p.y, p.z)
                SetBlipRotation(b, math.floor(p.h))
            end
        end
    end

    for id, b in pairs(blips) do
        if not seen[id] then
            if DoesBlipExist(b) then RemoveBlip(b) end
            blips[id] = nil
        end
    end
end)

CreateThread(function()
    while true do
        if State.wallhack and next(blips) then
            for id, b in pairs(blips) do
                local pl = GetPlayerFromServerId(id)
                if pl ~= -1 and DoesBlipExist(b) then
                    local ped = GetPlayerPed(pl)
                    local c = GetEntityCoords(ped)
                    SetBlipCoords(b, c.x, c.y, c.z)
                    SetBlipRotation(b, math.floor(GetEntityHeading(ped)))
                end
            end
            Wait(200)
        else
            Wait(1000)
        end
    end
end)

-- ---------------------------------------------------------
--  Affichage 3D à travers les murs
--  Les textes sont recalculés 4 fois par seconde ; à chaque image on ne
--  fait que dessiner (positions à jour, donc aucun décalage visuel).
-- ---------------------------------------------------------
local vehLabels = {}
local function vehLabel(model)
    local l = vehLabels[model]
    if not l then
        l = GetLabelText(GetDisplayNameFromVehicleModel(model))
        if l == 'NULL' then l = GetDisplayNameFromVehicleModel(model) end
        vehLabels[model] = l
    end
    return l
end

local targets = {}
CreateThread(function()
    while true do
        if State.wallhack then
            local myPed = PlayerPedId()
            local myC = GetEntityCoords(myPed)
            local list = {}
            for _, pl in ipairs(GetActivePlayers()) do
                local ped = GetPlayerPed(pl)
                if ped ~= myPed and DoesEntityExist(ped) then
                    local dist = #(GetEntityCoords(ped) - myC)
                    if dist <= WH.maxDistance then
                        local hp = math.max(GetEntityHealth(ped) - 100, 0)
                        local dead = IsEntityDead(ped)
                        local veh = GetVehiclePedIsIn(ped, false)
                        local col = dead and '~r~' or (hp < 40 and '~o~' or '~g~')
                        local line2 = dead and '~r~Mort' or ('%sVie %d~s~  ~b~Armure %d'):format(col, hp, GetPedArmour(ped))
                        if veh ~= 0 then line2 = line2 .. '~s~  ~y~' .. vehLabel(GetEntityModel(veh)) end
                        list[#list + 1] = {
                            ped = ped,
                            text = ('~b~[%d]~s~ %s  ~c~%dm~n~'):format(GetPlayerServerId(pl), GetPlayerName(pl), math.floor(dist)) .. line2,
                            scale = math.max(0.38 - dist / 1500, 0.24),
                            line = WH.lines and dist <= WH.lineDistance,
                        }
                    end
                end
            end
            targets = list
            Wait(250)
        else
            targets = {}
            Wait(500)
        end
    end
end)

CreateThread(function()
    while true do
        if State.wallhack and #targets > 0 then
            local myC = GetEntityCoords(PlayerPedId())
            for i = 1, #targets do
                local t = targets[i]
                if DoesEntityExist(t.ped) then
                    local c = GetEntityCoords(t.ped)
                    DrawText3D(vector3(c.x, c.y, c.z + 1.25), t.text, t.scale)
                    if t.line then DrawLine(myC.x, myC.y, myC.z, c.x, c.y, c.z, 91, 141, 239, 160) end
                end
            end
            Wait(0)
        else
            Wait(250)
        end
    end
end)
