-- =========================================================
--  PORTES ET PORTAILS VERROUILLABLES
--  Les portes de la map sont verrouillées avec le système de portes
--  du jeu (DoorSystem) : aucun objet n'est supprimé ni recréé.
-- =========================================================
local DC = Config.Doors
local registered = {}   -- [hashPorte] = true
local doorOpen = false   -- panneau ouvert
if type(LastInteract) ~= 'number' then LastInteract = 0 end

local function leafHash(id, i) return GetHashKey(('am_door_%d_%d'):format(id, i)) end

-- Applique l'état de toutes les portes (appelé à chaque synchro)
function RefreshDoors()
    local alive = {}
    for _, d in ipairs(Editor.doors or {}) do
        for i, l in ipairs(d.leaves) do
            local h = leafHash(d.id, i)
            alive[h] = true
            if not registered[h] or not IsDoorRegisteredWithSystem(h) then
                AddDoorToSystem(h, l.model, l.x, l.y, l.z, false, false, false)
                registered[h] = true
            end
            DoorSystemSetDoorState(h, d.locked and 1 or 0, false, false)
            if d.locked then DoorSystemSetOpenRatio(h, 0.0, false, false) end
        end
    end
    for h in pairs(registered) do
        if not alive[h] then
            if IsDoorRegisteredWithSystem(h) then RemoveDoorFromSystem(h) end
            registered[h] = nil
        end
    end
end

-- Ré-application régulière (certaines portes se réinitialisent quand la zone recharge)
CreateThread(function()
    while true do
        Wait(10000)
        if Editor.doors and #Editor.doors > 0 then RefreshDoors() end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for h in pairs(registered) do
        if IsDoorRegisteredWithSystem(h) then
            DoorSystemSetDoorState(h, 0, false, false)
            RemoveDoorFromSystem(h)
        end
    end
end)

-- ---------------------------------------------------------
--  Interaction des joueurs (touche E, la même que la récolte)
-- ---------------------------------------------------------
local nearDoor = nil
CreateThread(function()
    while true do
        -- Chaque porte a sa propre distance d'ouverture (sinon celle de la config)
        local found, bestRatio = nil, 1.0
        local doors = Editor.doors or {}
        if #doors > 0 and not doorOpen and not IsNoclipActive() then
            local p = GetEntityCoords(PlayerPedId())
            for _, d in ipairs(doors) do
                local reach = d.distance or DC.interactDistance
                for _, l in ipairs(d.leaves) do
                    local dx, dy, dz = l.x - p.x, l.y - p.y, l.z - p.z
                    local ratio = math.sqrt(dx * dx + dy * dy + dz * dz) / reach
                    if ratio <= bestRatio then bestRatio, found = ratio, d end
                end
            end
        end
        nearDoor = found
        Wait(found and 0 or 400)
        if found then
            BeginTextCommandDisplayHelp('STRING')
            AddTextComponentSubstringPlayerName(('%s %s : %s'):format(
                ('~INPUT_%X~'):format((GetHashKey('+harvest_plant') | 0x80000000) & 0xFFFFFFFF),
                found.name, found.locked and '~r~verrouillée' or '~g~ouverte'))
            EndTextCommandDisplayHelp(0, false, false, -1)
        end
    end
end)

local lastHandled = 0
CreateThread(function()
    while true do
        Wait(50)
        if nearDoor and LastInteract > lastHandled then
            lastHandled = LastInteract
            TriggerServerEvent('adminmenu:door:open', nearDoor.id)
        elseif LastInteract > lastHandled then
            lastHandled = LastInteract
        end
    end
end)

RegisterNetEvent('adminmenu:door:panel', function(data)
    doorOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'door', data = data })
end)
RegisterNUICallback('door_close', function(_, cb) doorOpen = false SetNuiFocus(false, false) cb('ok') end)
RegisterNUICallback('door_toggle', function(b, cb) cb('ok') TriggerServerEvent('adminmenu:door:toggle', b.id, b.code) end)
RegisterNUICallback('door_setcode', function(b, cb) cb('ok') TriggerServerEvent('adminmenu:door:setcode', b.id, b.code) end)

-- ---------------------------------------------------------
--  STAFF : choisir une porte (ou les deux battants d'une porte double)
-- ---------------------------------------------------------
local picking = nil
function IsDoorPick() return picking ~= nil end

local function aimObject()
    local rot = GetGameplayCamRot(2)
    local zr, xr = math.rad(rot.z), math.rad(rot.x)
    local n = math.abs(math.cos(xr))
    local from = GetGameplayCamCoord()
    local to = from + vector3(-math.sin(zr) * n, math.cos(zr) * n, math.sin(xr)) * 30.0
    local ray = StartExpensiveSynchronousShapeTestLosProbe(from.x, from.y, from.z, to.x, to.y, to.z, 16, PlayerPedId(), 7)
    local _, hit, _, _, ent = GetShapeTestResult(ray)
    if hit == 1 and ent ~= 0 and DoesEntityExist(ent) and GetEntityType(ent) == 3 and not NetworkGetEntityIsNetworked(ent) then
        return ent
    end
    return 0
end

function DoorPickKey(id)
    if not picking then return false end
    if id == 'confirm' then
        local e = picking.aim
        if e and e ~= 0 then
            for _, l in ipairs(picking.leaves) do
                if l.ent == e then return true, Notify('Ce battant est déjà sélectionné.', 'info') end
            end
            if #picking.leaves >= 2 then return true, Notify('2 battants maximum (porte double).', 'error') end
            local c = GetEntityCoords(e)
            picking.leaves[#picking.leaves + 1] = { ent = e, model = GetEntityModel(e), x = c.x, y = c.y, z = c.z }
            PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
        else
            Notify('Vise une porte ou un portail.', 'error')
        end
    elseif id == 'cancel' then
        if #picking.leaves > 0 then table.remove(picking.leaves) else picking = nil end
    elseif id == 'finish' then
        if #picking.leaves == 0 then return true, Notify('Sélectionne au moins une porte avec Valider.', 'error') end
        local leaves = {}
        for _, l in ipairs(picking.leaves) do leaves[#leaves + 1] = { model = l.model, x = l.x, y = l.y, z = l.z } end
        TriggerServerEvent('adminmenu:action', 'editor_add_door', { leaves = leaves, name = picking.name })
        picking = nil
    end
    return true
end

local function pickLoop()
    while picking do
        Wait(0)
        local p = picking
        if not p then break end
        DisableControlAction(0, 24, true)
        DisableControlAction(0, 25, true)
        DrawRect(0.5, 0.5, 0.0025, 0.0045, 255, 255, 255, 200)
        p.aim = aimObject()
        if p.aim ~= 0 then
            local c = GetEntityCoords(p.aim)
            DrawMarker(2, c.x, c.y, c.z + 1.4, 0, 0, 0, 180.0, 0, 0, 0.35, 0.35, 0.35, 217, 181, 106, 220, true, false, 2, true, nil, nil, false)
        end
        for i, l in ipairs(p.leaves) do
            DrawMarker(1, l.x, l.y, l.z - 1.2, 0, 0, 0, 0, 0, 0, 0.8, 0.8, 0.6, 79, 179, 169, 200, false, false, 2, false, nil, nil, false)
            DrawText3D(vector3(l.x, l.y, l.z + 1.2), ('~g~Battant %d'):format(i), 0.32)
        end
        ShowKeysHud('doorpick', 'Choisir une porte', {
            { keys = { EK('confirm') }, label = 'Sélectionner la porte visée' },
            { keys = { EK('finish') }, label = 'Terminer (porte verrouillée)' },
            { keys = { EK('cancel') }, label = #p.leaves > 0 and 'Retirer le dernier battant' or 'Annuler' },
        }, ('%d battant(s) sélectionné(s) · 2 pour une porte double'):format(#p.leaves))
    end
    if HudOwner == 'doorpick' then HideKeysHud() end
end

function StartDoorPick(name)
    if picking then return end
    picking = { leaves = {}, name = name }
    Notify('Vise une porte ou un portail et appuie sur Valider. Pour une porte double, sélectionne les 2 battants.', 'info')
    CreateThread(function()
        local ok, err = pcall(pickLoop)
        if not ok then
            print(('^1[AdminMenu] Erreur sélection de porte : %s^7'):format(tostring(err)))
            picking = nil
            HideKeysHud()
        end
    end)
end
function CancelDoorPick() picking = nil end
