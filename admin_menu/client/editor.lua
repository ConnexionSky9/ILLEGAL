-- =========================================================
--  ÉDITEUR DE MAP - CLIENT
--  - Fait apparaître localement (autour de chaque joueur) les props,
--    PNJ et plants enregistrés sur le serveur
--  - Mode placement : l'objet suit le point visé à l'écran
--  - Récolte pour tous les joueurs
-- =========================================================
local E = Config.Editor
Editor = { spawns = {}, props = {}, peds = {}, fields = {}, stations = {}, searches = {}, hidden = {}, zones = {}, doors = {}, down = {}, looted = {}, propFolders = {}, stashes = {} }

local spawned = {}   -- [clé] = { ent, sig }
local lookup = {}    -- [entité] = { kind, id, fieldId, idx }
local Placing = nil
local pheld = {}

function IsPlacing() return Placing ~= nil end

-- Contour lumineux : UNIQUEMENT sur les objets. Sur un personnage (PNJ, joueur),
-- le contour de GTA fait planter le jeu : on ne l'applique donc jamais aux peds.
local function canOutline(ent)
    return ent and ent ~= 0 and DoesEntityExist(ent) and GetEntityType(ent) == 3
end
local function outline(ent, on)
    if not canOutline(ent) then return false end
    if on then
        SetEntityDrawOutlineColor(242, 177, 52, 255)
        SetEntityDrawOutlineShader(1)
    end
    SetEntityDrawOutline(ent, on == true)
    return true
end
-- Repère sans danger pour un PNJ : cercle au sol + flèche au-dessus de la tête
local function markPed(ent)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return end
    local c = GetEntityCoords(ent)
    DrawMarker(25, c.x, c.y, c.z - 0.98, 0, 0, 0, 0, 0, 0, 1.1, 1.1, 1.1, 242, 177, 52, 180, false, false, 2, false, nil, nil, false)
    DrawMarker(2, c.x, c.y, c.z + 1.25, 0, 0, 0, 180.0, 0, 0, 0.3, 0.3, 0.3, 242, 177, 52, 220, true, true, 2, false, nil, nil, false)
end
function EditorLookup(ent) return lookup[ent] end

function CanUseEditor()
    return (MyLevel or 0) >= E.minLevel
end

local function canEdit(perm)
    return HasPerm(perm) and CanUseEditor()
end

local function keyToken(cmd)
    return ('~INPUT_%X~'):format((GetHashKey(cmd) | 0x80000000) & 0xFFFFFFFF)
end

local function rotToDir(rot)
    local z, x = math.rad(rot.z), math.rad(rot.x)
    local n = math.abs(math.cos(x))
    return vector3(-math.sin(z) * n, math.cos(z) * n, math.sin(x))
end

local function loadModel(hash)
    if not IsModelInCdimage(hash) then return false end
    RequestModel(hash)
    local t = GetGameTimer()
    while not HasModelLoaded(hash) do
        Wait(10)
        if GetGameTimer() - t > 5000 then return false end
    end
    return true
end

-- Origine à donner à une entité pour que sa base touche le sol
local function originZ(hash, groundZ)
    local minDim = GetModelDimensions(hash)
    return groundZ - minDim.z
end

-- ---------------------------------------------------------
--  Création des entités locales
-- ---------------------------------------------------------
local function createObject(model, x, y, z, h, ghost)
    local hash = GetHashKey(model)
    if not loadModel(hash) then return nil end
    local o = CreateObjectNoOffset(hash, x, y, z, false, false, false)
    SetEntityCoordsNoOffset(o, x, y, z, false, false, false)
    SetEntityHeading(o, h)
    FreezeEntityPosition(o, true)
    if ghost then
        SetEntityAlpha(o, 170, false)
        SetEntityCollision(o, false, false)
    end
    SetModelAsNoLongerNeeded(hash)
    return o
end

local function createPed(rec, ghost)
    local hash = GetHashKey(rec.model)
    if not loadModel(hash) then return nil end
    local p = CreatePed(4, hash, rec.x, rec.y, rec.z, rec.h, false, true)
    SetEntityCoordsNoOffset(p, rec.x, rec.y, rec.z, false, false, false)
    SetEntityHeading(p, rec.h)
    FreezeEntityPosition(p, true)
    SetEntityInvincible(p, true)
    SetBlockingOfNonTemporaryEvents(p, true)
    SetPedCanRagdoll(p, false)
    SetPedFleeAttributes(p, 0, false)
    SetPedDiesWhenInjured(p, false)
    SetPedCanBeTargetted(p, false)
    if ghost then
        SetEntityAlpha(p, 170, false)
        SetEntityCollision(p, false, false)
    elseif rec.scenario and rec.scenario ~= '' then
        TaskStartScenarioInPlace(p, rec.scenario, 0, true)
    end
    SetModelAsNoLongerNeeded(hash)
    return p
end

local function deleteKey(key)
    local s = spawned[key]
    if not s then return end
    if DoesEntityExist(s.ent) then DeleteEntity(s.ent) end
    lookup[s.ent] = nil
    spawned[key] = nil
end

-- ---------------------------------------------------------
--  Synchronisation
-- ---------------------------------------------------------
local smIds = {}
local function applySpawnmanager()
    if not E.useSpawnmanager or GetResourceState('spawnmanager') ~= 'started' then return end
    for _, id in ipairs(smIds) do pcall(function() exports.spawnmanager:removeSpawnPoint(id) end) end
    smIds = {}
    local pool = {}
    for _, s in ipairs(Editor.spawns) do if not s.newcomer then pool[#pool + 1] = s end end
    if #pool == 0 then pool = Editor.spawns end
    for _, s in ipairs(pool) do
        local ok, id = pcall(function()
            return exports.spawnmanager:addSpawnPoint({ x = s.x, y = s.y, z = s.z, heading = s.h, model = E.spawnModel })
        end)
        if ok and id then smIds[#smIds + 1] = id end
    end
end

local editorBlips = {}
local function refreshBlips()
    for _, b in ipairs(editorBlips) do if DoesBlipExist(b) then RemoveBlip(b) end end
    editorBlips = {}
    local function add(x, y, z, sprite, name)
        local b = AddBlipForCoord(x, y, z)
        SetBlipSprite(b, sprite or 1)
        SetBlipScale(b, 0.8)
        SetBlipAsShortRange(b, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(name)
        EndTextCommandSetBlipName(b)
        editorBlips[#editorBlips + 1] = b
    end
    for _, f in ipairs(Editor.fields) do
        if f.blip and #f.plants > 0 then
            local cx, cy, cz = 0.0, 0.0, 0.0
            for _, p in ipairs(f.plants) do cx, cy, cz = cx + p.x, cy + p.y, cz + p.z end
            local n = #f.plants
            add(cx / n, cy / n, cz / n, f.blipSprite, f.name)
        end
    end
    for _, st in ipairs(Editor.stations) do
        if st.blip then add(st.x, st.y, st.z, st.blipSprite, st.name) end
    end
    for _, z in ipairs(Editor.searches) do
        if z.blip and #z.points > 0 then
            local cx, cy, cz = 0.0, 0.0, 0.0
            for _, p in ipairs(z.points) do cx, cy, cz = cx + p.x, cy + p.y, cz + p.z end
            local n = #z.points
            add(cx / n, cy / n, cz / n, z.blipSprite, z.name)
        end
    end
end

-- Objets de la map retirés : masqués proprement par le jeu (CreateModelHide),
-- jamais supprimés (supprimer un objet de la map peut faire planter le jeu)
local appliedHides = {}
local function applyHides()
    for _, h in ipairs(appliedHides) do RemoveModelHide(h.x, h.y, h.z, h.r, h.m, false) end
    appliedHides = {}
    for _, h in ipairs(Editor.hidden) do
        local r = (h.radius or 1.5) + 0.0
        CreateModelHide(h.x, h.y, h.z, r, h.model, true)
        appliedHides[#appliedHides + 1] = { x = h.x, y = h.y, z = h.z, r = r, m = h.model }
    end
end

RegisterNetEvent('adminmenu:editor:sync', function(kind, list)
    Editor[kind] = list or {}
    if kind == 'propFolders' then return end
    if kind == 'hidden' then applyHides() return end
    if kind == 'zones' then if RefreshZones then RefreshZones() end return end
    if kind == 'doors' then if RefreshDoors then RefreshDoors() end return end
    if kind ~= 'spawns' then RebuildEditorIndex() end
    if kind == 'peds' and RefreshBarberBlips then RefreshBarberBlips() end
    if kind == 'fields' or kind == 'stations' or kind == 'searches' then refreshBlips() end
    if kind == 'spawns' then
        applySpawnmanager()
        TriggerEvent('adminmenu:spawnPointsUpdated', Editor.spawns)
    end
end)

RegisterNetEvent('adminmenu:harvest:down', function(map) Editor.down = map or {} end)
RegisterNetEvent('adminmenu:search:looted', function(map) Editor.looted = map or {} end)

AddEventHandler('onClientResourceStart', function(res)
    if res == GetCurrentResourceName() then TriggerServerEvent('adminmenu:editor:request') end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for key in pairs(spawned) do deleteKey(key) end
    for _, b in ipairs(editorBlips) do if DoesBlipExist(b) then RemoveBlip(b) end end
    for _, h in ipairs(appliedHides) do RemoveModelHide(h.x, h.y, h.z, h.r, h.m, false) end
    if Placing and Placing.ghost and DoesEntityExist(Placing.ghost) then DeleteEntity(Placing.ghost) end
end)

-- ---------------------------------------------------------
--  Streaming : on ne crée que ce qui est proche
--  Optimisé : index précalculé à chaque synchro (aucune chaîne créée
--  en boucle), distances au carré, chargement des modèles sans
--  bloquer, nombre de créations limité par passage.
-- ---------------------------------------------------------
local Entries = {}           -- liste à plat de tout ce qui peut apparaître
local NearInteract = {}      -- plants / ateliers / fouilles à moins de 25 m
local NearNamed = {}         -- PNJ nommés à moins de 15 m
local badModel = {}          -- modèles inexistants (on ne réessaie pas)
local SPAWN_BUDGET = 12      -- créations max par passage (évite les à-coups)

local function addEntry(key, kind, model, x, y, z, h, info, extra, rx, ry)
    local e = {
        key = key, kind = kind, model = model, hash = GetHashKey(model),
        x = x, y = y, z = z, h = h or 0.0, rx = rx, ry = ry, info = info,
        sig = ('%s|%.3f|%.3f|%.3f|%.2f|%s|%s|%s'):format(model, x, y, z, h or 0.0, extra and extra.scenario or '', rx or 0, ry or 0),
    }
    if extra then for k, v in pairs(extra) do e[k] = v end end
    Entries[#Entries + 1] = e
end

function RebuildEditorIndex()
    Entries = {}
    for _, r in ipairs(Editor.props) do
        addEntry('prop:' .. r.id, 'object', r.model, r.x, r.y, r.z, r.h, { kind = 'prop', id = r.id, model = r.model }, nil, r.rx, r.ry)
    end
    for _, r in ipairs(Editor.peds) do
        addEntry('ped:' .. r.id, 'ped', r.model, r.x, r.y, r.z, r.h, { kind = 'ped', id = r.id, model = r.model },
            { scenario = r.scenario, name = r.name, interact = r.npc and 'npc' or nil, ref = r })
    end
    for _, r in ipairs(Editor.stashes or {}) do
        addEntry('stash:' .. r.id, 'object', r.model, r.x, r.y, r.z, r.h, { kind = 'stash', id = r.id, model = r.model },
            { interact = 'stash', ref = r }, r.rx, r.ry)
    end
    for _, r in ipairs(Editor.stations) do
        addEntry('station:' .. r.id, 'object', r.model, r.x, r.y, r.z, r.h, { kind = 'station', id = r.id, model = r.model },
            { interact = 'station', ref = r }, r.rx, r.ry)
    end
    for _, z in ipairs(Editor.searches) do
        for i, p in ipairs(z.points) do
            addEntry(('spoint:%d:%d'):format(z.id, i), 'object', z.model, p.x, p.y, p.z, p.h,
                { kind = 'searchpoint', searchId = z.id, idx = i, model = z.model },
                { interact = 'search', ref = z, idx = i, stateKey = z.id .. ':' .. i }, p.rx, p.ry)
        end
    end
    for _, f in ipairs(Editor.fields) do
        for i, p in ipairs(f.plants) do
            addEntry(('plant:%d:%d'):format(f.id, i), 'object', f.model, p.x, p.y, p.z, p.h,
                { kind = 'plant', fieldId = f.id, idx = i, model = f.model },
                { interact = 'plant', ref = f, idx = i, stateKey = f.id .. ':' .. i }, p.rx, p.ry)
        end
    end
end

-- Création immédiate d'une entité dont le modèle est déjà chargé
local function spawnEntry(e)
    local ent
    if e.kind == 'ped' then
        ent = CreatePed(4, e.hash, e.x, e.y, e.z, e.h, false, true)
        SetEntityCoordsNoOffset(ent, e.x, e.y, e.z, false, false, false)
        SetEntityHeading(ent, e.h)
        FreezeEntityPosition(ent, true)
        SetEntityInvincible(ent, true)
        SetBlockingOfNonTemporaryEvents(ent, true)
        SetPedCanRagdoll(ent, false)
        SetPedFleeAttributes(ent, 0, false)
        SetPedDiesWhenInjured(ent, false)
        SetPedCanBeTargetted(ent, false)
        if e.scenario and e.scenario ~= '' then TaskStartScenarioInPlace(ent, e.scenario, 0, true) end
    else
        ent = CreateObjectNoOffset(e.hash, e.x, e.y, e.z, false, false, false)
        SetEntityCoordsNoOffset(ent, e.x, e.y, e.z, false, false, false)
        if e.rx or e.ry then
            SetEntityRotation(ent, e.rx or 0.0, e.ry or 0.0, e.h, 2, true)
        else
            SetEntityHeading(ent, e.h)
        end
        FreezeEntityPosition(ent, true)
    end
    SetModelAsNoLongerNeeded(e.hash)
    return ent
end

CreateThread(function()
    local SD2 = E.streamDistance * E.streamDistance
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        local px, py, pz = pos.x, pos.y, pos.z
        local hidden = Placing and Placing.hideKey
        local alive, budget = {}, SPAWN_BUDGET
        local near, named = {}, {}

        for i = 1, #Entries do
            local e = Entries[i]
            local dx, dy, dz = e.x - px, e.y - py, e.z - pz
            local d2 = dx * dx + dy * dy + dz * dz
            local down = e.stateKey and e.interact == 'plant' and Editor.down[e.stateKey]

            if not down then
                alive[e.key] = true
                local cur = spawned[e.key]
                if hidden == e.key then
                    if cur then deleteKey(e.key) end
                elseif d2 < SD2 then
                    if cur and cur.sig ~= e.sig then deleteKey(e.key) cur = nil end
                    if not cur and budget > 0 and not NoclipMovingFast and not badModel[e.hash] then
                        if HasModelLoaded(e.hash) then
                            local ent = spawnEntry(e)
                            spawned[e.key] = { ent = ent, sig = e.sig }
                            lookup[ent] = e.info
                            budget = budget - 1
                        elseif IsModelInCdimage(e.hash) then
                            RequestModel(e.hash) -- sera créé au prochain passage
                        else
                            badModel[e.hash] = true
                            print(('^3[AdminMenu] Modèle introuvable, ignoré : %s^7'):format(e.model))
                        end
                    end
                elseif cur then
                    deleteKey(e.key)
                end
            end

            if e.interact and d2 < 625.0 then near[#near + 1] = e end           -- 25 m
            if e.name and e.name ~= '' and d2 < 225.0 then named[#named + 1] = e end -- 15 m
        end

        for key in pairs(spawned) do
            if not alive[key] then deleteKey(key) end
        end
        NearInteract, NearNamed = near, named
        Wait(budget == 0 and 100 or 500) -- s'il reste des choses à créer, on repasse vite
    end
end)

-- Nom affiché au-dessus des PNJ nommés (seulement ceux qui sont proches)
CreateThread(function()
    while true do
        if #NearNamed > 0 then
            for i = 1, #NearNamed do
                local e = NearNamed[i]
                DrawText3D(vector3(e.x, e.y, e.z + 1.05), e.name, 0.34)
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)

-- ---------------------------------------------------------
--  MODE PLACEMENT
-- ---------------------------------------------------------
local T = {}
for _, k in ipairs(Config.EditorKeys) do T[k.id] = keyToken('+admin_ed_' .. k.id) end

-- Touche actuelle d'une action du mode placement (pour la liste en bas à droite)
local ekCache = {}
function EK(id)
    local c = ekCache[id]
    if c and GetGameTimer() - c.t < 5000 then return c.v end
    local v = CurrentKey and CurrentKey('+admin_ed_' .. id)
    if not v then
        for _, k in ipairs(Config.EditorKeys) do if k.id == id then v = k.key end end
    end
    ekCache[id] = { t = GetGameTimer(), v = v or '?' }
    return v or '?'
end

local function stopPlacement()
    if not Placing then return end
    if Placing.ghost and DoesEntityExist(Placing.ghost) then DeleteEntity(Placing.ghost) end
    Placing = nil
    pheld = {}
    if HudOwner == 'placement' then HideKeysHud() end
end

local function confirmPlacement()
    local P = Placing
    if not P or not P.pos then return end
    local d = { id = P.id, model = P.model, x = P.pos.x, y = P.pos.y, z = P.pos.z, h = P.heading,
                rx = P.rot and P.rot.x or 0.0, ry = P.rot and P.rot.y or 0.0, folder = P.folder }

    if P.kind == 'prop' then
        TriggerServerEvent('adminmenu:action', 'editor_save_prop', d)
    elseif P.kind == 'ped' then
        d.scenario, d.name = P.scenario, P.name
        if not P.id then d.npc = P.npc end
        TriggerServerEvent('adminmenu:action', 'editor_save_ped', d)
    elseif P.kind == 'station' then
        for k, v in pairs(P.station or {}) do if d[k] == nil then d[k] = v end end
        TriggerServerEvent('adminmenu:action', 'editor_save_station', d)
    elseif P.kind == 'stash' then
        for k, v in pairs(P.stash or {}) do if d[k] == nil then d[k] = v end end
        TriggerServerEvent('adminmenu:action', 'editor_save_stash', d)
    elseif P.kind == 'plant' then
        d.fieldId, d.idx = P.fieldId, P.idx
        TriggerServerEvent('adminmenu:action', 'editor_save_plant', d)
        if not P.idx then return end -- ajout de plants à la chaîne : on continue
    elseif P.kind == 'searchpoint' then
        d.searchId, d.idx = P.searchId, P.idx
        TriggerServerEvent('adminmenu:action', 'editor_save_searchpoint', d)
        if not P.idx then return end -- ajout de points à la chaîne
    elseif P.kind == 'garagespot' and P.target == 'pubstore' then
        d.pedId, d.idx = P.pedId, P.idx
        TriggerServerEvent('adminmenu:action', 'editor_pubgarage_store', d)
        if not P.idx then return end -- plusieurs zones à la chaîne
    elseif P.kind == 'garagespot' and P.target == 'pubgarage' then
        d.pedId, d.idx = P.pedId, P.idx
        TriggerServerEvent('adminmenu:action', 'editor_pubgarage_spot', d)
        if not P.idx then return end -- plusieurs places à la chaîne
    elseif P.kind == 'garagespot' and P.target == 'catalog' then
        d.pedId = P.pedId
        TriggerServerEvent('adminmenu:action', 'editor_catalog_spot', d)
    elseif P.kind == 'garagespot' then
        d.pedId, d.idx = P.pedId, P.idx
        TriggerServerEvent('adminmenu:action', 'editor_garage_spot', d)
        if not P.idx then return end -- plusieurs points de sortie à la chaîne
    end
    stopPlacement()
end

local editorKeyTime = 0
local function onEditorKey(id)
    if ZonePreviewKey and ZonePreviewKey(id) then editorKeyTime = GetGameTimer() return end
    if MapPickKey and MapPickKey(id) then editorKeyTime = GetGameTimer() return end
    if PreviewKey and PreviewKey(id) then editorKeyTime = GetGameTimer() return end
    if ZoneDrawKey and ZoneDrawKey(id) then editorKeyTime = GetGameTimer() return end
    if DoorPickKey and DoorPickKey(id) then editorKeyTime = GetGameTimer() return end
    if not Placing then
        if PropSelectKey and PropSelectKey(id) then editorKeyTime = GetGameTimer() end
        return
    end
    editorKeyTime = GetGameTimer()
    if id == 'confirm' then confirmPlacement()
    elseif id == 'cancel' then stopPlacement() Notify('Placement annulé.', 'info')
    elseif (id == 'rot_left' or id == 'rot_right') and Placing.magnet and Placing.magnetTarget then
        -- Collé à un objet : on tourne par quarts de tour, pour rester aligné
        Placing.magnetRot = ((Placing.magnetRot or 0) + (id == 'rot_left' and 90 or -90)) % 360
    elseif id == 'rot_left' then Placing.heading = (Placing.heading + E.rotateStep) % 360
    elseif id == 'rot_right' then Placing.heading = (Placing.heading - E.rotateStep) % 360
    elseif id == 'reset' then Placing.zOff = 0.0
    elseif id == 'snap' then
        Placing.snap = not Placing.snap
        Notify(Placing.snap and 'Collé au sol : activé.' or 'Collé au sol : désactivé (placement libre).', 'info')
    elseif id == 'magnet' and Placing.kind ~= 'ped' and Placing.kind ~= 'garagespot' then
        Placing.magnet = not Placing.magnet
        LastMagnet = Placing.magnet
        Notify(Placing.magnet and 'Aimant activé : vise un objet pour coller le nouveau contre lui.' or 'Aimant désactivé.', 'info')
    elseif id == 'magnet_side' and Placing.magnet then
        Placing.magnetSide = (Placing.magnetSide or 1) % #MAGNET_SIDES + 1
    end
end

for _, k in ipairs(Config.EditorKeys) do
    local cmd = 'admin_ed_' .. k.id
    if k.hold then
        RegisterCommand('+' .. cmd, function() pheld[k.id] = true end, false)
        RegisterCommand('-' .. cmd, function() pheld[k.id] = false end, false)
    else
        RegisterCommand('+' .. cmd, function() onEditorKey(k.id) end, false)
        RegisterCommand('-' .. cmd, function() end, false)
    end
    RegisterKeyMapping('+' .. cmd, 'Staff - Placement : ' .. k.label, k.mapper or 'keyboard', k.key or '')
end

local BLOCK = { 24, 25, 37, 44, 45, 140, 141, 142, 143, 257, 263, 264, 14, 15, 16, 17, 38, 51, 54, 47, 58, 45, 80 }

-- ---------------------------------------------------------
--  AIMANT : le nouvel objet se colle à l'objet visé
--  (dessus, devant, derrière, à gauche, à droite), aligné sur lui.
-- ---------------------------------------------------------
MAGNET_SIDES = { 'auto', 'top', 'front', 'back', 'left', 'right' }
local SIDE_LABEL = { auto = 'Automatique', top = 'Dessus', front = 'Devant', back = 'Derrière', left = 'À gauche', right = 'À droite' }

-- Props proches du point visé : TOUS les objets autour (posés avec l'éditeur ou déjà sur la map),
-- même sans collision. Liste rafraîchie 4 fois par seconde seulement.
local magnetPool, magnetPoolAt = {}, 0
local function refreshMagnetPool(center, ghost)
    if GetGameTimer() - magnetPoolAt < 250 then return end
    magnetPoolAt = GetGameTimer()
    local list = {}
    for _, obj in ipairs(GetGamePool('CObject')) do
        if obj ~= ghost and DoesEntityExist(obj) and not IsEntityAttached(obj) and IsEntityVisible(obj) then
            local d = #(GetEntityCoords(obj) - center)
            if d < 30.0 then list[#list + 1] = obj end
        end
    end
    magnetPool = list
end

-- Distance entre un point et la boîte d'un objet (dans le repère de l'objet)
local function boxDistance(ent, point)
    local mn, mx = GetModelDimensions(GetEntityModel(ent))
    local p = GetOffsetFromEntityGivenWorldCoords(ent, point.x, point.y, point.z)
    local dx = math.max(mn.x - p.x, 0.0, p.x - mx.x)
    local dy = math.max(mn.y - p.y, 0.0, p.y - mx.y)
    local dz = math.max(mn.z - p.z, 0.0, p.z - mx.z)
    return math.sqrt(dx * dx + dy * dy + dz * dz), p, mn, mx
end

-- Choisit l'objet auquel s'aimanter : celui touché par le viseur, sinon le plus proche du point visé
local function magnetTarget(P, hitEnt, point)
    if hitEnt and hitEnt ~= 0 and hitEnt ~= P.ghost and DoesEntityExist(hitEnt) and GetEntityType(hitEnt) == 3 then return hitEnt end
    refreshMagnetPool(point, P.ghost)
    local best, bestD = nil, E.magnetRange or 1.6
    for i = 1, #magnetPool do
        local obj = magnetPool[i]
        if obj ~= P.ghost and DoesEntityExist(obj) then
            local d = boxDistance(obj, point)
            if d < bestD then best, bestD = obj, d end
        end
    end
    return best
end

-- Côté automatique : celui que tu vises (au-dessus = dessus, sinon la face la plus proche)
local function autoSide(ent, point)
    local _, p, mn, mx = boxDistance(ent, point)
    local hx, hy = math.max(0.05, (mx.x - mn.x) / 2), math.max(0.05, (mx.y - mn.y) / 2)
    local cx, cy = (mn.x + mx.x) / 2, (mn.y + mx.y) / 2
    if p.z >= mx.z - 0.08 then return 'top' end
    local dx, dy = (p.x - cx) / hx, (p.y - cy) / hy
    if math.abs(dx) > math.abs(dy) then return dx > 0 and 'right' or 'left' end
    return dy > 0 and 'front' or 'back'
end
LastMagnet = false

local function drawBox(ent, r, g, b)
    local mn, mx = GetModelDimensions(GetEntityModel(ent))
    local c = {}
    local i = 0
    for _, x in ipairs({ mn.x, mx.x }) do for _, y in ipairs({ mn.y, mx.y }) do for _, z in ipairs({ mn.z, mx.z }) do
        i = i + 1
        c[i] = GetOffsetFromEntityInWorldCoords(ent, x, y, z)
    end end end
    local E12 = { {1,2},{3,4},{5,6},{7,8},{1,3},{2,4},{5,7},{6,8},{1,5},{2,6},{3,7},{4,8} }
    for _, e in ipairs(E12) do
        local a, bb = c[e[1]], c[e[2]]
        DrawLine(a.x, a.y, a.z, bb.x, bb.y, bb.z, r, g, b, 230)
    end
end

-- Renvoie true si l'objet a été collé à la cible
local function magnetFrame(P, ent, point)
    if not ent or ent == 0 or ent == P.ghost or not DoesEntityExist(ent) then return false end
    local tmin, tmax = GetModelDimensions(GetEntityModel(ent))
    local gmin, gmax = GetModelDimensions(P.hash)
    local rel = (P.magnetRot or 0) % 360
    -- Encombrement du nouvel objet dans le repère de l'objet visé (rotation par quarts de tour)
    local gx0, gx1, gy0, gy1 = gmin.x, gmax.x, gmin.y, gmax.y
    if rel == 90 then gx0, gx1, gy0, gy1 = -gmax.y, -gmin.y, gmin.x, gmax.x
    elseif rel == 180 then gx0, gx1, gy0, gy1 = -gmax.x, -gmin.x, -gmax.y, -gmin.y
    elseif rel == 270 then gx0, gx1, gy0, gy1 = gmin.y, gmax.y, -gmax.x, -gmin.x end
    local tcx, tcy = (tmin.x + tmax.x) / 2, (tmin.y + tmax.y) / 2
    local gcx, gcy = (gx0 + gx1) / 2, (gy0 + gy1) / 2
    local side = MAGNET_SIDES[P.magnetSide or 1]
    if side == 'auto' then side = autoSide(ent, point) end
    local gap = 0.004
    local ox, oy, oz = tcx - gcx, tcy - gcy, tmin.z - gmin.z
    if side == 'top' then oz = tmax.z - gmin.z + gap
    elseif side == 'front' then oy = tmax.y - gy0 + gap
    elseif side == 'back' then oy = tmin.y - gy1 - gap
    elseif side == 'right' then ox = tmax.x - gx0 + gap
    elseif side == 'left' then ox = tmin.x - gx1 - gap end
    oz = oz + (P.zOff or 0.0)
    local pos = GetOffsetFromEntityInWorldCoords(ent, ox, oy, oz)
    local r = GetEntityRotation(ent, 2)
    local heading = (r.z + rel) % 360
    SetEntityCoordsNoOffset(P.ghost, pos.x, pos.y, pos.z, false, false, false)
    SetEntityRotation(P.ghost, r.x, r.y, heading, 2, true)
    P.pos, P.heading, P.rot = pos, heading, vector3(r.x, r.y, heading)
    P.magnetTarget = ent
    drawBox(ent, 79, 179, 169)
    return true, side, MAGNET_SIDES[P.magnetSide or 1] == 'auto'
end

local placeGen = 0
local function placementFrame(P)
    for i = 1, #BLOCK do DisableControlAction(0, BLOCK[i], true) end

    local from = GetGameplayCamCoord()
    local to = from + rotToDir(GetGameplayCamRot(2)) * E.placeDistance
    -- 1 monde + 16 objets (on peut poser sur une table, un toit…)
    local ray = StartExpensiveSynchronousShapeTestLosProbe(from.x, from.y, from.z, to.x, to.y, to.z, 17, P.ghost, 7)
    local _, hit, endPos, _, hitEnt = GetShapeTestResult(ray)
    local base = (hit == 1) and endPos or to

    if pheld.up then P.zOff = P.zOff + E.heightSpeed * GetFrameTime() * 60.0 end
    if pheld.down then P.zOff = P.zOff - E.heightSpeed * GetFrameTime() * 60.0 end

    -- Aimant : collé à l'objet visé
    if P.magnet then
        local target = magnetTarget(P, hit == 1 and hitEnt or nil, base)
        local stuck, side, auto = magnetFrame(P, target, base)
        if stuck then
            local title = ({ prop = 'Prop', plant = 'Plant', station = 'Atelier', searchpoint = 'Point de fouille', stash = 'Coffre' })[P.kind] or ''
            ShowKeysHud('placement', 'Placement : ' .. title .. ' · aimanté', {
                { keys = { EK('magnet_side') }, label = 'Côté : ' .. SIDE_LABEL[side] .. (auto and ' (auto)' or '') },
                { keys = { EK('rot_left'), EK('rot_right') }, label = 'Tourner d\'un quart de tour' },
                { keys = { EK('up'), EK('down') }, label = ('Hauteur (%+.2f m)'):format(P.zOff) },
                { keys = { EK('magnet') }, label = 'Aimant : OUI' },
                { keys = { EK('confirm') }, label = 'Valider' },
                { keys = { EK('cancel') }, label = ((P.kind == 'plant' or P.kind == 'searchpoint') and not P.idx) and 'Terminer' or 'Annuler' },
            }, P.model)
            return
        end
    end
    P.magnetTarget = nil

    local z = originZ(P.hash, base.z)
    P.rot = nil
    if P.snap and P.kind ~= 'ped' then
        -- Le jeu pose lui-même l'objet sur la surface (et suit la pente)
        SetEntityCoordsNoOffset(P.ghost, base.x, base.y, z + 0.05, false, false, false)
        SetEntityRotation(P.ghost, 0.0, 0.0, P.heading, 2, true)
        local grounded
        if P.kind == 'garagespot' then grounded = SetVehicleOnGroundProperly(P.ghost) else grounded = PlaceObjectOnGroundProperly(P.ghost) end
        if grounded then
            local gc = GetEntityCoords(P.ghost)
            local r = GetEntityRotation(P.ghost, 2)
            z = gc.z
            P.rot = vector3(r.x, r.y, P.heading)
        end
        z = z + P.zOff
        SetEntityCoordsNoOffset(P.ghost, base.x, base.y, z, false, false, false)
        SetEntityRotation(P.ghost, P.rot and P.rot.x or 0.0, P.rot and P.rot.y or 0.0, P.heading, 2, true)
    elseif P.snap then
        -- PNJ : on mesure une fois l'écart entre son centre et ses pieds
        -- (os des chevilles), puis ses pieds touchent exactement le sol
        if not P.footOffset then
            P.measure = (P.measure or 0) + 1
            if P.measure >= 3 then
                local oc = GetEntityCoords(P.ghost)
                local lf = GetPedBoneCoords(P.ghost, 14201, 0.0, 0.0, 0.0)
                local rf = GetPedBoneCoords(P.ghost, 52301, 0.0, 0.0, 0.0)
                local low = math.min(lf.z, rf.z)
                if low ~= 0.0 and math.abs(oc.z - low) < 3.0 then
                    P.footOffset = oc.z - (low - 0.08)
                else
                    P.footOffset = z - base.z
                end
            end
            z = z + P.zOff
        else
            z = base.z + P.footOffset + P.zOff
            SetEntityCoordsNoOffset(P.ghost, base.x, base.y, z, false, false, false)
            SetEntityHeading(P.ghost, P.heading)
        end
    else
        z = z + P.zOff
        SetEntityCoordsNoOffset(P.ghost, base.x, base.y, z, false, false, false)
        SetEntityHeading(P.ghost, P.heading)
    end
    P.pos = vector3(base.x, base.y, z)

    DrawMarker(25, base.x, base.y, base.z + 0.03, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.9, 0.9, 0.9,
        242, 177, 52, 140, false, false, 2, false, nil, nil, false)

    local title = ({ prop = 'Prop', ped = 'PNJ', plant = 'Plant', station = 'Atelier', searchpoint = 'Point de fouille', garagespot = 'Sortie du garage', stash = 'Coffre' })[P.kind] or ''
    local rows = {
        { keys = { EK('rot_left'), EK('rot_right') }, label = 'Tourner' },
        { keys = { EK('snap') }, label = P.snap and 'Collé au sol : OUI' or 'Collé au sol : NON' },
        { keys = { EK('up'), EK('down') }, label = ('Hauteur (%+.1f m)'):format(P.zOff) },
        { keys = { EK('reset') }, label = 'Hauteur à zéro' },
        { keys = { EK('confirm') }, label = 'Valider' },
        { keys = { EK('cancel') }, label = ((P.kind == 'plant' or P.kind == 'searchpoint' or P.kind == 'garagespot') and not P.idx) and 'Terminer' or 'Annuler' },
    }
    if P.kind ~= 'ped' and P.kind ~= 'garagespot' then
        table.insert(rows, 3, { keys = { EK('magnet') }, label = P.magnet and 'Aimant : OUI (approche-toi d\'un prop)' or 'Aimant : NON' })
    end
    ShowKeysHud('placement', 'Placement : ' .. title, rows, P.model)
end

local function placementLoop(gen)
    while Placing and gen == placeGen do
        Wait(0)
        if not Placing or gen ~= placeGen then break end -- validé ou annulé pendant l'attente
        local ok, err = pcall(placementFrame, Placing)
        if not ok then
            print(('^1[AdminMenu] Erreur placement : %s^7'):format(tostring(err)))
            Notify('Placement annulé suite à une erreur (détails en F8).', 'error')
            stopPlacement()
        end
    end
end

-- opts : kind, model, id?, fieldId?, idx?, scenario?, name?, hideKey?, heading?
function StartPlacement(opts)
    stopPlacement()
    local hash = GetHashKey(opts.model or '')
    if not IsModelInCdimage(hash) then return Notify(('Le modèle "%s" n\'existe pas.'):format(opts.model or ''), 'error') end
    if not loadModel(hash) then return Notify('Le modèle met trop de temps à charger.', 'error') end

    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    local heading = opts.heading or GetEntityHeading(ped)
    local ghost
    if opts.kind == 'ped' then
        ghost = createPed({ model = opts.model, x = c.x, y = c.y, z = c.z - 50.0, h = heading }, true)
    elseif opts.kind == 'garagespot' then
        -- Aperçu du véhicule qui sortira (local, transparent, sans collision)
        ghost = CreateVehicle(hash, c.x, c.y, c.z - 50.0, heading, false, false)
        if ghost and ghost ~= 0 then
            SetEntityAlpha(ghost, 170, false)
            SetEntityCollision(ghost, false, false)
            FreezeEntityPosition(ghost, true)
            SetVehicleDoorsLocked(ghost, 2)
            SetEntityInvincible(ghost, true)
        else ghost = nil end
        SetModelAsNoLongerNeeded(hash)
    else
        ghost = createObject(opts.model, c.x, c.y, c.z - 50.0, heading, true)
    end
    if not ghost then return Notify('Impossible de créer l\'aperçu.', 'error') end
    if opts.kind ~= 'ped' then outline(ghost, true) end

    opts.hash, opts.ghost, opts.heading, opts.zOff = hash, ghost, heading, opts.zOff or 0.0
    if opts.snap == nil then opts.snap = E.snapToGround end
    if opts.magnet == nil then opts.magnet = LastMagnet end
    if opts.kind == 'ped' or opts.kind == 'garagespot' then opts.magnet = false end
    opts.magnetSide = opts.magnetSide or 1
    Placing = opts
    placeGen = placeGen + 1
    local gen = placeGen
    CreateThread(function() placementLoop(gen) end)
end

-- Déplacer un élément existant
function EditorMove(info)
    if not info then return end
    if info.kind == 'prop' and canEdit('editor_props') then
        for _, r in ipairs(Editor.props) do
            if r.id == info.id then
                return StartPlacement({ kind = 'prop', model = r.model, id = r.id, heading = r.h, hideKey = 'prop:' .. r.id })
            end
        end
    elseif info.kind == 'ped' and canEdit('editor_peds') then
        for _, r in ipairs(Editor.peds) do
            if r.id == info.id then
                return StartPlacement({ kind = 'ped', model = r.model, id = r.id, heading = r.h,
                    scenario = r.scenario, name = r.name, hideKey = 'ped:' .. r.id })
            end
        end
    elseif info.kind == 'stash' and canEdit('editor_stashes') then
        for _, r in ipairs(Editor.stashes) do
            if r.id == info.id then
                return StartPlacement({ kind = 'stash', model = r.model, id = r.id, heading = r.h, hideKey = 'stash:' .. r.id })
            end
        end
    elseif info.kind == 'station' and canEdit('editor_crafting') then
        for _, r in ipairs(Editor.stations) do
            if r.id == info.id then
                return StartPlacement({ kind = 'station', model = r.model, id = r.id, heading = r.h, hideKey = 'station:' .. r.id })
            end
        end
    elseif info.kind == 'searchpoint' and canEdit('editor_harvest') then
        for _, z in ipairs(Editor.searches) do
            if z.id == info.searchId and z.points[info.idx] then
                return StartPlacement({ kind = 'searchpoint', model = z.model, searchId = z.id, idx = info.idx,
                    heading = z.points[info.idx].h, hideKey = ('spoint:%d:%d'):format(z.id, info.idx) })
            end
        end
    elseif info.kind == 'plant' and canEdit('editor_harvest') then
        for _, f in ipairs(Editor.fields) do
            if f.id == info.fieldId and f.plants[info.idx] then
                return StartPlacement({ kind = 'plant', model = f.model, fieldId = f.id, idx = info.idx,
                    heading = f.plants[info.idx].h, hideKey = ('plant:%d:%d'):format(f.id, info.idx) })
            end
        end
    else
        Notify('Permission insuffisante pour modifier cet élément.', 'error')
    end
end

-- Supprimer un élément ciblé dans le noclip
function EditorDelete(info)
    if info.kind == 'searchpoint' then
        TriggerServerEvent('adminmenu:action', 'editor_delete_searchpoint', { searchId = info.searchId, idx = info.idx })
    elseif info.kind == 'plant' then
        TriggerServerEvent('adminmenu:action', 'editor_delete_plant', { fieldId = info.fieldId, idx = info.idx })
    else
        TriggerServerEvent('adminmenu:action', 'editor_delete', { kind = info.kind, id = info.id })
    end
end

-- ---------------------------------------------------------
--  Création d'une zone de récolte autour du staff
-- ---------------------------------------------------------
local function groundAt(x, y, zRef)
    local ray = StartExpensiveSynchronousShapeTestLosProbe(x, y, zRef + 15.0, x, y, zRef - 30.0, 1, PlayerPedId(), 7)
    local _, hit, endPos = GetShapeTestResult(ray)
    if hit == 1 then return endPos.z end
    local ok, gz = GetGroundZFor_3dCoord(x, y, zRef + 10.0, false)
    if ok then return gz end
end

local function createField(d)
    local model = tostring(d.model or '')
    local hash = GetHashKey(model)
    if not IsModelInCdimage(hash) then return Notify(('Le modèle "%s" n\'existe pas.'):format(model), 'error') end
    if not loadModel(hash) then return Notify('Le modèle met trop de temps à charger.', 'error') end

    local radius = math.min(math.max(tonumber(d.radius) or 8, 2), 40) + 0.0
    local count = math.min(math.max(math.floor(tonumber(d.count) or 15), 1), 200)
    local spacing = math.max(1.0, math.min(2.0, radius / math.sqrt(count) * 0.8))
    local c = GetEntityCoords(PlayerPedId())
    local plants, tries = {}, 0

    while #plants < count and tries < count * 40 do
        tries = tries + 1
        local a, r = math.random() * math.pi * 2, math.sqrt(math.random()) * radius
        local x, y = c.x + math.cos(a) * r, c.y + math.sin(a) * r
        local ok = true
        for _, p in ipairs(plants) do
            if (p.x - x) ^ 2 + (p.y - y) ^ 2 < spacing ^ 2 then ok = false break end
        end
        if ok then
            local gz = groundAt(x, y, c.z)
            if gz then plants[#plants + 1] = { x = x, y = y, z = originZ(hash, gz), h = math.random(0, 359) + 0.0 } end
        end
    end

    -- Chaque plant est réellement posé au sol par le jeu (plus de plants qui flottent)
    for i, p in ipairs(plants) do
        local o = CreateObjectNoOffset(hash, p.x, p.y, p.z + 0.05, false, false, false)
        SetEntityRotation(o, 0.0, 0.0, p.h, 2, true)
        if PlaceObjectOnGroundProperly(o) then
            local gc = GetEntityCoords(o)
            local r = GetEntityRotation(o, 2)
            p.z, p.rx, p.ry = gc.z, r.x, r.y
        end
        DeleteEntity(o)
        if i % 25 == 0 then Wait(0) end
    end
    SetModelAsNoLongerNeeded(hash)

    if #plants < count then
        Notify(('Seulement %d plants placés (terrain ou espacement). Agrandis le rayon si besoin.'):format(#plants), 'warning')
    end
    d.plants = plants
    TriggerServerEvent('adminmenu:action', 'editor_create_field', d)
end

-- ---------------------------------------------------------
--  Données pour le menu + callback NUI
-- ---------------------------------------------------------
function EditorMenuData()
    local pos = GetEntityCoords(PlayerPedId())
    local function dist(r) return math.floor(#(pos - vector3(r.x, r.y, r.z))) end
    local out = { spawns = {}, props = {}, peds = {}, fields = {}, stations = {}, searches = {}, hidden = {}, zones = {}, doors = {}, stashes = {} }
    for _, r in ipairs(Editor.stashes or {}) do
        out.stashes[#out.stashes + 1] = { id = r.id, name = r.name, model = r.model, weight = r.weight, slots = r.slots,
            jobs = r.jobs or {}, gangs = r.gangs or {}, dist = dist(r) }
    end
    for _, d in ipairs(Editor.doors) do
        local l = d.leaves[1]
        out.doors[#out.doors + 1] = { id = d.id, name = d.name, locked = d.locked, hasCode = d.hasCode, owners = d.owners,
            double = #d.leaves == 2, dist = l and dist(l) or nil, distance = d.distance }
    end
    for _, z in ipairs(Editor.zones) do
        local cx, cy
        if z.shape == 'circle' then cx, cy = z.center.x, z.center.y
        else
            cx, cy = 0.0, 0.0
            for _, q in ipairs(z.points) do cx, cy = cx + q.x, cy + q.y end
            cx, cy = cx / #z.points, cy / #z.points
        end
        local zz = vector3(cx, cy, pos.z)
        out.zones[#out.zones + 1] = {
            id = z.id, name = z.name, enterMsg = z.enterMsg, exitMsg = z.exitMsg, color = z.color,
            safe = z.safe, noWeapons = z.noWeapons, invincible = z.invincible, exemptPolice = z.exemptPolice,
            speedLimit = z.speedLimit, blip = z.blip, showBorder = z.showBorder, shape = z.shape,
            blipSprite = z.blipSprite or 0, blipScale = z.blipScale or 0.8,
            corners = z.points and #z.points or 0, radius = z.radius, dist = math.floor(#(pos - zz)),
        }
    end
    for _, h in ipairs(Editor.hidden) do
        out.hidden[#out.hidden + 1] = { id = h.id, label = h.label, model = h.model, dist = dist(h) }
    end
    for _, z in ipairs(Editor.searches) do
        local looted = 0
        for i in ipairs(z.points) do if Editor.looted[z.id .. ':' .. i] then looted = looted + 1 end end
        out.searches[#out.searches + 1] = {
            id = z.id, name = z.name, model = z.model, requiredItem = z.requiredItem, breakChance = z.breakChance,
            duration = z.duration, cooldown = z.cooldown, blip = z.blip == true, blipSprite = z.blipSprite,
            loot = z.loot, points = #z.points, looted = looted, dist = z.points[1] and dist(z.points[1]) or nil,
        }
    end
    for _, r in ipairs(Editor.spawns) do out.spawns[#out.spawns + 1] = { id = r.id, name = r.name, newcomer = r.newcomer == true, dist = dist(r) } end
    for _, r in ipairs(Editor.stations) do
        out.stations[#out.stations + 1] = {
            id = r.id, name = r.name, model = r.model, scenario = r.scenario, blip = r.blip == true,
            blipSprite = r.blipSprite, recipes = r.recipes, dist = dist(r),
        }
    end
    for _, r in ipairs(Editor.props) do out.props[#out.props + 1] = { id = r.id, model = r.model, folder = r.folder, dist = dist(r) } end
    out.propFolders = Editor.propFolders or {}
    for _, r in ipairs(Editor.peds) do
        out.peds[#out.peds + 1] = { id = r.id, model = r.model, scenario = r.scenario, name = r.name, npc = r.npc, dist = dist(r) }
    end
    for _, f in ipairs(Editor.fields) do
        local first = f.plants[1]
        local down = 0
        for i in ipairs(f.plants) do if Editor.down[f.id .. ':' .. i] then down = down + 1 end end
        out.fields[#out.fields + 1] = {
            id = f.id, name = f.name, model = f.model, item = f.item, itemLabel = f.itemLabel,
            min = f.min, max = f.max, duration = f.duration, regrow = f.regrow,
            plants = #f.plants, down = down, dist = first and dist(first) or nil,
            blip = f.blip == true, blipSprite = f.blipSprite,
        }
    end
    return out
end

local function teleportTo(kind, id)
    local list = ({ spawn = Editor.spawns, prop = Editor.props, ped = Editor.peds, station = Editor.stations, hidden = Editor.hidden, stash = Editor.stashes })[kind]
    if kind == 'door' then
        for _, dd in ipairs(Editor.doors) do
            if dd.id == id and dd.leaves[1] then
                local l = dd.leaves[1]
                return CreateThread(function() TeleportTo(vector3(l.x + 1.2, l.y + 1.2, l.z), true) end)
            end
        end
        return
    end
    if kind == 'zone' then
        for _, z in ipairs(Editor.zones) do
            if z.id == id then
                local x, y
                if z.shape == 'circle' then x, y = z.center.x, z.center.y else x, y = z.points[1].x, z.points[1].y end
                return CreateThread(function() TeleportTo(vector3(x, y, z.minZ + Config.Zones.depth), true) end)
            end
        end
        return
    end
    if kind == 'search' then
        for _, z in ipairs(Editor.searches) do
            if z.id == id and z.points[1] then
                local p = z.points[1]
                return CreateThread(function() TeleportTo(vector3(p.x + 1.5, p.y, p.z + 1.0), false) end)
            end
        end
        return
    end
    if kind == 'field' then
        for _, f in ipairs(Editor.fields) do
            if f.id == id and f.plants[1] then
                local p = f.plants[1]
                return CreateThread(function() TeleportTo(vector3(p.x + 1.5, p.y, p.z + 1.0), false) end)
            end
        end
        return
    end
    for _, r in ipairs(list or {}) do
        if r.id == id then
            local off = kind == 'spawn' and 0.0 or 1.5
            return CreateThread(function() TeleportTo(vector3(r.x + off, r.y, r.z + (kind == 'prop' and 1.0 or 0.0)), false) end)
        end
    end
end

-- Après la création d'une zone de fouille : on enchaîne sur la pose des points
RegisterNetEvent('adminmenu:editor:placePoints', function(id)
    -- La liste à jour peut arriver juste après : on l'attend (3 s max)
    local t = GetGameTimer()
    while GetGameTimer() - t < 3000 do
        for _, z in ipairs(Editor.searches) do
            if z.id == id then
                Notify('Zone créée. Pose maintenant les objets à fouiller un par un, puis Annuler pour terminer.', 'success')
                return StartPlacement({ kind = 'searchpoint', model = z.model, searchId = z.id })
            end
        end
        Wait(100)
    end
end)

RegisterNUICallback('editor', function(body, cb)
    cb('ok')
    if not State.duty then return Notify('Tu es en mode RP : reprends ton service staff.', 'error') end
    local n, d = body.name, body.data or {}

    if n == 'place_prop' and canEdit('editor_props') then
        CloseMenu()
        if d.magnet ~= nil then LastMagnet = d.magnet == true end
        StartPlacement({ kind = 'prop', model = tostring(d.model or ''):lower(), folder = tonumber(d.folder) })
    elseif n == 'place_ped' and canEdit('editor_peds') then
        CloseMenu()
        StartPlacement({ kind = 'ped', model = tostring(d.model or ''):lower(), scenario = d.scenario or '', name = d.name or '', npc = d.npc })
    elseif n == 'move' then
        CloseMenu()
        EditorMove({ kind = d.kind, id = tonumber(d.id) })
    elseif n == 'add_plants' and canEdit('editor_harvest') then
        for _, f in ipairs(Editor.fields) do
            if f.id == tonumber(d.id) then
                CloseMenu()
                Notify('Place les plants un par un, puis appuie sur Annuler pour terminer.', 'info')
                return StartPlacement({ kind = 'plant', model = f.model, fieldId = f.id })
            end
        end
    elseif n == 'place_stash' and canEdit('editor_stashes') then
        CloseMenu()
        StartPlacement({ kind = 'stash', model = tostring(d.model or ''):lower(), stash = d })
    elseif n == 'stash_open' and canEdit('editor_stashes') then
        CloseMenu()
        TriggerServerEvent('adminmenu:action', 'editor_stash_open', { id = tonumber(d.id) })
    elseif n == 'place_station' and canEdit('editor_crafting') then
        CloseMenu()
        StartPlacement({ kind = 'station', model = tostring(d.model or ''):lower(), station = d })
    elseif n == 'garage_spot' and canEdit('editor_peds') then
        local model = tostring(d.model or ''):lower()
        if model == '' or not IsModelInCdimage(GetHashKey(model)) then model = 'blista' end
        CloseMenu()
        if not d.idx then Notify('Place la voiture là où les véhicules sortiront (molette pour l\'orienter), E pour valider. Plusieurs à la suite, puis Retour pour terminer.', 'info') end
        StartPlacement({ kind = 'garagespot', model = model, pedId = tonumber(d.id), idx = tonumber(d.idx), heading = tonumber(d.h) })
    elseif n == 'pubgarage_spot' and canEdit('editor_peds') then
        CloseMenu()
        if not d.idx then Notify('Place la voiture sur une place de sortie (molette pour l\'orienter), E pour valider. Plusieurs à la suite, puis Retour pour terminer.', 'info') end
        StartPlacement({ kind = 'garagespot', target = 'pubgarage', model = 'blista', pedId = tonumber(d.id), idx = tonumber(d.idx), heading = tonumber(d.h) })
    elseif n == 'pubgarage_store' and canEdit('editor_peds') then
        CloseMenu()
        if not d.idx then Notify('Place la voiture au centre de la zone de rangement, E pour valider. Plusieurs à la suite, puis Retour pour terminer.', 'info') end
        StartPlacement({ kind = 'garagespot', target = 'pubstore', model = 'blista', pedId = tonumber(d.id), idx = tonumber(d.idx), heading = tonumber(d.h) })
    elseif n == 'pubgarage_store_tp' and canEdit('editor_peds') then
        for _, r in ipairs(Editor.peds) do
            local sp = r.id == tonumber(d.id) and r.npc and r.npc.pubgarage and (r.npc.pubgarage.stores or {})[tonumber(d.idx) or 0]
            if sp then CloseMenu() CreateThread(function() TeleportTo(vector3(sp.x + 3.0, sp.y, sp.z + 0.5), true) end) end
        end
    elseif n == 'pubgarage_spot_tp' and canEdit('editor_peds') then
        for _, r in ipairs(Editor.peds) do
            local sp = r.id == tonumber(d.id) and r.npc and r.npc.pubgarage and (r.npc.pubgarage.spots or {})[tonumber(d.idx) or 0]
            if sp then CloseMenu() CreateThread(function() TeleportTo(vector3(sp.x + 2.5, sp.y, sp.z + 0.5), true) end) end
        end
    elseif n == 'catalog_spot' and canEdit('editor_peds') then
        CloseMenu()
        Notify('Place la voiture là où les essais commenceront (molette pour l\'orienter), E pour valider.', 'info')
        StartPlacement({ kind = 'garagespot', target = 'catalog', model = 'blista', pedId = tonumber(d.id), heading = tonumber(d.h) })
    elseif n == 'catalog_spot_tp' and canEdit('editor_peds') then
        for _, r in ipairs(Editor.peds) do
            local sp = r.id == tonumber(d.id) and r.npc and r.npc.catalog and r.npc.catalog.testSpot
            if sp then CloseMenu() CreateThread(function() TeleportTo(vector3(sp.x + 2.5, sp.y, sp.z + 0.5), true) end) end
        end
    elseif n == 'garage_spot_tp' and canEdit('editor_peds') then
        for _, r in ipairs(Editor.peds) do
            if r.id == tonumber(d.id) and r.npc and r.npc.garage then
                local sp = (r.npc.garage.spots or {})[tonumber(d.idx) or 0]
                if sp then CloseMenu() CreateThread(function() TeleportTo(vector3(sp.x + 2.5, sp.y, sp.z + 0.5), true) end) end
            end
        end
    elseif n == 'preview3d' and (canEdit('editor_props') or canEdit('editor_peds')) then
        CloseMenu()
        StartModelPreview(d.kind == 'ped' and 'ped' or 'prop', tostring(d.model or ''))
    elseif n == 'door_pick' and canEdit('editor_doors') then
        CloseMenu()
        StartDoorPick(d.name)
    elseif n == 'zone_draw' and canEdit('editor_zones') then
        CloseMenu()
        StartZoneDraw(tonumber(d.id), d.settings)
    elseif n == 'zone_circle' and canEdit('editor_zones') then
        TriggerServerEvent('adminmenu:action', 'editor_save_zone', { id = tonumber(d.id), shape = 'circle', radius = d.radius, settings = d.settings })
    elseif n == 'map_pick' and canEdit('editor_props') then
        CloseMenu()
        StartMapPick()
    elseif n == 'add_searchpoints' and canEdit('editor_harvest') then
        for _, z in ipairs(Editor.searches) do
            if z.id == tonumber(d.id) then
                CloseMenu()
                Notify('Pose les objets à fouiller un par un, puis Annuler pour terminer.', 'info')
                return StartPlacement({ kind = 'searchpoint', model = z.model, searchId = z.id })
            end
        end
    elseif n == 'create_search' and canEdit('editor_harvest') then
        local hash = GetHashKey(tostring(d.model or ''))
        if not IsModelInCdimage(hash) then return Notify(('Le modèle "%s" n\'existe pas.'):format(tostring(d.model)), 'error') end
        CloseMenu()
        TriggerServerEvent('adminmenu:action', 'editor_create_search', d)
    elseif n == 'create_field' and canEdit('editor_harvest') then
        CloseMenu()
        CreateThread(function() createField(d) end)
    elseif n == 'tp' then
        CloseMenu()
        teleportTo(d.kind, tonumber(d.id))
    elseif n == 'prop_select' and canEdit('editor_props') then
        CloseMenu()
        StartPropSelect()
    elseif n == 'prop_show' and canEdit('editor_props') then
        CloseMenu()
        ShowPropsInWorld(d.ids, d.label)
    end
end)

RegisterNetEvent('adminmenu:editor:folderSaved', function(id)
    SendNUIMessage({ action = 'folderSaved', id = id })
end)

-- ---------------------------------------------------------
--  RÉCOLTE ET FABRICATION (tous les joueurs)
-- ---------------------------------------------------------
-- Métier du joueur (mis en cache 2 s) : sert à cacher les PNJ réservés à d'autres métiers
local myJobName, myJobGrade, myJobAt = nil, 0, -10000
local function myJob()
    if GetGameTimer() - myJobAt < 2000 then return myJobName, myJobGrade end
    myJobAt = GetGameTimer()
    local ok, name, grade = pcall(function()
        local pd
        if GetResourceState('qbx_core') == 'started' then pd = exports.qbx_core:GetPlayerData()
        elseif GetResourceState('qb-core') == 'started' then pd = exports['qb-core']:GetCoreObject().Functions.GetPlayerData()
        elseif GetResourceState('es_extended') == 'started' then
            pd = exports.es_extended:getSharedObject().GetPlayerData()
            return pd and pd.job and pd.job.name, pd and pd.job and pd.job.grade or 0
        end
        local j = pd and pd.job
        return j and j.name, j and (type(j.grade) == 'table' and j.grade.level or tonumber(j.grade)) or 0
    end)
    if ok then myJobName, myJobGrade = name, grade or 0 end
    return myJobName, myJobGrade
end
for _, ev in ipairs({ 'QBCore:Client:OnJobUpdate', 'QBCore:Client:OnPlayerLoaded', 'esx:setJob' }) do
    AddEventHandler(ev, function() myJobAt = -10000 end)
end
local myGangName, myGangGrade, myGangAt = nil, 0, -10000
local function myGang()
    if GetGameTimer() - myGangAt < 2000 then return myGangName, myGangGrade end
    myGangAt = GetGameTimer()
    local ok, name, grade = pcall(function()
        local pd
        if GetResourceState('qbx_core') == 'started' then pd = exports.qbx_core:GetPlayerData()
        elseif GetResourceState('qb-core') == 'started' then pd = exports['qb-core']:GetCoreObject().Functions.GetPlayerData() end
        local g = pd and pd.gang
        if not g or g.name == 'none' then return nil, 0 end
        return g.name, (type(g.grade) == 'table' and g.grade.level or tonumber(g.grade)) or 0
    end)
    if ok then myGangName, myGangGrade = name, grade or 0 end
    return myGangName, myGangGrade
end
AddEventHandler('QBCore:Client:OnGangUpdate', function() myGangAt = -10000 end)
local function stashAllowed(st)
    local hasJobs, hasGangs = st.jobs and #st.jobs > 0, st.gangs and #st.gangs > 0
    if not hasJobs and not hasGangs then return true end
    if hasJobs then
        local job, grade = myJob()
        for _, j in ipairs(st.jobs) do if job == j.job and (grade or 0) >= (j.grade or 0) then return true end end
    end
    if hasGangs then
        local gang, grade = myGang()
        for _, g in ipairs(st.gangs) do if gang == g.gang and (grade or 0) >= (g.grade or 0) then return true end end
    end
    return false
end
local function npcAllowed(n)
    local jobs = (n.jobs and #n.jobs > 0 and n.jobs) or (n.garage and n.garage.jobs)
    if not jobs or #jobs == 0 then return true end
    local job, grade = myJob()
    for _, j in ipairs(jobs) do
        if job == j.job and (grade or 0) >= (j.grade or 0) then return true end
    end
    return false
end

-- Boutique de vêtements ouverte ? (lu au plus 3 fois par seconde)
local clothingOpenV, clothingOpenAt = false, 0
local function clothingOpen()
    if GetGameTimer() - clothingOpenAt < 300 then return clothingOpenV end
    clothingOpenAt = GetGameTimer()
    clothingOpenV = false
    if GetResourceState('elyzea_clothing') == 'started' then
        local ok, v = pcall(function() return exports.elyzea_clothing:IsOpen() end)
        clothingOpenV = ok and v == true
    end
    return clothingOpenV
end

local interactPressed = false
local busy = false
local stationOpen = false
local INTERACT_CMD = 'harvest_plant'

RegisterCommand('+' .. INTERACT_CMD, function() interactPressed = true LastInteract = GetGameTimer() end, false)
RegisterCommand('-' .. INTERACT_CMD, function() end, false)
RegisterKeyMapping('+' .. INTERACT_CMD, 'Récolte / atelier : ' .. Config.HarvestKey.label, Config.HarvestKey.mapper, Config.HarvestKey.key)
local INTERACT_TOKEN = keyToken('+' .. INTERACT_CMD)

-- Invite en bas au centre, au style du serveur. N'est envoyée à l'interface que si elle change.
local promptSig
local promptOwner
function ShowPrompt(actionText, name, muted, owner)
    owner = owner or 'interact'
    if promptOwner and promptOwner ~= owner and promptSig then return end   -- une seule invite à la fois
    local key = CurrentKey and CurrentKey('+' .. INTERACT_CMD) or nil
    key = key or Config.HarvestKey.key or 'E'
    local sig = ('%s|%s|%s|%s'):format(actionText, name, key, tostring(muted))
    promptOwner = owner
    if sig == promptSig then return end
    promptSig = sig
    SendNUIMessage({ action = 'prompt', show = true, key = key, verb = actionText, name = name, muted = muted == true })
end
function HidePrompt(owner)
    if promptSig == nil or (promptOwner and promptOwner ~= (owner or 'interact')) then return end
    promptSig, promptOwner = nil, nil
    SendNUIMessage({ action = 'prompt', show = false })
end

CreateThread(function()
    while true do
        local sleep = 500
        local near = NearInteract
        if #near > 0 and not busy and not stationOpen and not NpcOpen and not Placing and not IsNoclipActive() and not clothingOpen() and not BarberOpen then
            sleep = 0
            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)
            local px, py, pz = pos.x, pos.y, pos.z
            local best, bestD2 = nil, 4.84 -- 2,2 m
            for i = 1, #near do
                local e = near[i]
                local dx, dy, dz = e.x - px, e.y - py, e.z - pz
                local d2 = dx * dx + dy * dy + dz * dz
                local reach = e.interact == 'plant' and 3.24 or 4.84 -- plants : 1,8 m
                if d2 < reach and d2 < bestD2 and not (e.interact == 'plant' and Editor.down[e.stateKey])
                    and not (e.interact == 'npc' and e.ref.npc and not npcAllowed(e.ref.npc))
                    and not (e.interact == 'stash' and not stashAllowed(e.ref)) then
                    best, bestD2 = e, d2
                end
            end

            if best and not IsPedInAnyVehicle(ped, false) and not IsEntityDead(ped) then
                local pressed = interactPressed and GetGameTimer() - editorKeyTime > 500
                if best.interact == 'npc' and best.ref.npc and best.ref.npc.pubgarage then
                    ShowPrompt('Appuyer pour ouvrir', best.ref.npc.pubgarage.name or 'le garage')
                    if pressed then TriggerServerEvent('adminmenu:pubgarage:open', best.ref.id) end
                elseif best.interact == 'npc' and best.ref.npc and best.ref.npc.catalog then
                    ShowPrompt('Appuyer pour voir', best.ref.npc.catalog.name or 'le catalogue')
                    if pressed then TriggerServerEvent('adminmenu:catalog:open', best.ref.id) end
                elseif best.interact == 'npc' and best.ref.npc and best.ref.npc.barber then
                    ShowPrompt('Appuyer pour entrer chez', best.ref.npc.barber.name or best.ref.name or 'le coiffeur')
                    if pressed then TriggerServerEvent('adminmenu:barber:request', best.ref.id) end
                elseif best.interact == 'npc' and best.ref.npc and best.ref.npc.clothing then
                    ShowPrompt('Appuyer pour entrer dans', best.ref.npc.clothing.name or best.ref.name or 'la boutique')
                    if pressed then TriggerServerEvent('adminmenu:clothing:open', best.ref.id) end
                elseif best.interact == 'npc' then
                    ShowPrompt('Appuyer pour parler à', (best.ref.name ~= '' and best.ref.name) or 'l\'inconnu')
                    if pressed then TriggerServerEvent('adminmenu:npc:open', best.ref.id) end
                elseif best.interact == 'station' then
                    ShowPrompt('Appuyer pour utiliser', best.ref.name)
                    if pressed then TriggerServerEvent('adminmenu:craft:open', best.ref.id) end
                elseif best.interact == 'stash' then
                    ShowPrompt('Appuyer pour ouvrir', best.ref.name)
                    if pressed then TriggerServerEvent('adminmenu:stash:open', best.ref.id) end
                elseif best.interact == 'search' then
                    if Editor.looted[best.stateKey] then
                        ShowPrompt('Déjà fouillé', 'Reviens plus tard', true)
                    else
                        ShowPrompt('Appuyer pour fouiller', best.ref.requiredItem ~= '' and (best.ref.name .. ' · outil requis') or best.ref.name)
                        if pressed then TriggerServerEvent('adminmenu:search:start', best.ref.id, best.idx) end
                    end
                else
                    ShowPrompt('Appuyer pour récolter', best.ref.itemLabel)
                    if pressed then TriggerServerEvent('adminmenu:harvest:start', best.ref.id, best.idx) end
                end
            else
                HidePrompt()
            end
        else
            HidePrompt()
        end
        interactPressed = false
        Wait(sleep)
    end
end)

-- Barre de progression commune. Renvoie true si terminée, false si annulée.
local function progress(label, seconds, scenario, anchor, maxDist)
    local ped = PlayerPedId()
    busy = true
    TaskTurnPedToFaceCoord(ped, anchor.x, anchor.y, anchor.z, 600)
    Wait(600)
    if scenario and scenario ~= '' then TaskStartScenarioInPlace(ped, scenario, 0, true) end

    local start, total, done = GetGameTimer(), seconds * 1000, true
    while GetGameTimer() - start < total do
        Wait(0)
        local pct = math.min((GetGameTimer() - start) / total, 1.0)
        DrawRect(0.5, 0.9, 0.2, 0.022, 20, 24, 32, 190)
        DrawRect(0.4 + 0.1 * pct, 0.9, 0.2 * pct, 0.022, 79, 179, 169, 230)
        DrawTxt(0.5, 0.866, label, 0.36, true)
        DrawTxt(0.5, 0.915, '~c~[X] Annuler', 0.28, true)
        DisableControlAction(0, 24, true)
        DisableControlAction(0, 25, true)
        if IsEntityDead(ped) or IsPedRagdoll(ped) or IsControlJustPressed(0, 73)
            or #(GetEntityCoords(ped) - vector3(anchor.x, anchor.y, anchor.z)) > maxDist then
            done = false
            break
        end
    end
    ClearPedTasks(ped)
    busy = false
    return done
end

RegisterNetEvent('adminmenu:harvest:begin', function(fid, idx, duration, label)
    local f
    for _, x in ipairs(Editor.fields) do if x.id == fid then f = x end end
    if not f or not f.plants[idx] then return end
    -- 600 ms de rotation + durée : le serveur attend au moins la durée
    if progress('Récolte : ' .. label, duration, 'WORLD_HUMAN_GARDENER_PLANT', f.plants[idx], 3.0) then
        TriggerServerEvent('adminmenu:harvest:finish')
    else
        TriggerServerEvent('adminmenu:harvest:cancel')
        Notify('Récolte annulée.', 'info')
    end
end)

RegisterNetEvent('adminmenu:search:begin', function(sid, idx, duration, name)
    local z
    for _, x in ipairs(Editor.searches) do if x.id == sid then z = x end end
    if not z or not z.points[idx] then return end
    if progress('Fouille : ' .. name, duration, 'PROP_HUMAN_BUM_BIN', z.points[idx], 3.0) then
        TriggerServerEvent('adminmenu:search:finish')
    else
        TriggerServerEvent('adminmenu:search:cancel')
        Notify('Fouille annulée.', 'info')
    end
end)

-- PNJ vendeur / acheteur : interface du joueur
NpcOpen = false
RegisterNetEvent('adminmenu:npc:menu', function(data)
    NpcOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'npc', data = data })
end)
RegisterNUICallback('npc_close', function(_, cb)
    NpcOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)
RegisterNUICallback('npc_buy', function(b, cb)
    cb('ok')
    TriggerServerEvent('adminmenu:npc:buy', b.id, b.idx, b.qty)
end)
RegisterNUICallback('npc_sell', function(b, cb)
    cb('ok')
    TriggerServerEvent('adminmenu:npc:sell', b.id, b.idx, b.qty)
end)

-- Alerte reçue par la police
RegisterNetEvent('adminmenu:police:alert', function(c, text)
    Notify('🚨 ' .. text .. ' (voir la carte)', 'warning')
    PlaySoundFrontend(-1, 'Lose_1st', 'GTAO_FM_Events_Soundset', true)
    local b = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(b, 161)
    SetBlipColour(b, 1)
    SetBlipScale(b, 1.2)
    SetBlipFlashes(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandSetBlipName(b)
    SetTimeout((Config.PoliceAlertBlip or 60) * 1000, function() if DoesBlipExist(b) then RemoveBlip(b) end end)
end)

-- Fabrication : menu de l'atelier (interface pour le joueur)
RegisterNetEvent('adminmenu:craft:menu', function(data)
    stationOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'station', data = data })
end)

RegisterNUICallback('station_close', function(_, cb)
    stationOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('craft', function(b, cb)
    stationOpen = false
    SetNuiFocus(false, false)
    cb('ok')
    TriggerServerEvent('adminmenu:craft:start', b.stationId, b.idx, b.times)
end)

RegisterNetEvent('adminmenu:craft:begin', function(sid, duration, label, scenario)
    local st
    for _, x in ipairs(Editor.stations) do if x.id == sid then st = x end end
    if not st then return end
    if progress('Fabrication : ' .. label, duration, scenario, st, 3.0) then
        TriggerServerEvent('adminmenu:craft:finish')
    else
        TriggerServerEvent('adminmenu:craft:cancel')
        Notify('Fabrication annulée.', 'info')
    end
end)

-- ---------------------------------------------------------
--  NOUVEAUX ARRIVANTS
--  Avec ESX / QBCore : après le chargement du personnage.
--  Sinon : après le spawn (spawnmanager).
-- ---------------------------------------------------------
local newcomerChecked = false
local function newcomerCheck()
    if newcomerChecked then return end
    newcomerChecked = true
    SetTimeout(E.newcomerDelay, function() TriggerServerEvent('adminmenu:spawn:check') end)
end

RegisterNetEvent('esx:playerLoaded', newcomerCheck)
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', newcomerCheck)      -- QBCore et Qbox
RegisterNetEvent('qbx_core:client:playerLoaded', newcomerCheck)      -- Qbox
AddEventHandler('playerSpawned', function()
    for _, r in ipairs({ 'es_extended', 'qb-core', 'qbx_core' }) do
        if GetResourceState(r) == 'started' then return end
    end
    newcomerCheck()
end)

RegisterNetEvent('adminmenu:spawn:newcomer', function(s)
    TeleportTo(vector3(s.x, s.y, s.z), false)
    SetEntityHeading(PlayerPedId(), s.h or 0.0)
    Notify('Bienvenue sur le serveur !', 'success')
end)

-- Exports client pour les autres ressources
exports('GetSpawnPoints', function() return Editor.spawns end)


-- ---------------------------------------------------------
--  RETIRER UN OBJET DE LA MAP (poteaux, panneaux, barrières…)
--  Mode à part, lancé depuis le menu. L'objet est masqué pour tout
--  le monde, de façon persistante, et peut être restauré.
-- ---------------------------------------------------------
local picking = false
local pickTarget, pickRay = 0, nil

function IsMapPick() return picking end

local function pickRaycast()
    if pickRay then
        local status, hit, _, _, ent = GetShapeTestResult(pickRay)
        if status == 1 then return pickTarget end
        pickRay = nil
        local t = 0
        if hit == 1 and ent ~= 0 and DoesEntityExist(ent) and GetEntityType(ent) == 3
            and not NetworkGetEntityIsNetworked(ent) and not lookup[ent] then
            t = ent
        end
        pickTarget = t
    end
    local from = GetGameplayCamCoord()
    local to = from + rotToDir(GetGameplayCamRot(2)) * 60.0
    pickRay = StartShapeTestLosProbe(from.x, from.y, from.z, to.x, to.y, to.z, 16, PlayerPedId(), 4)
    return pickTarget
end

function MapPickKey(id)
    if not picking then return false end
    if id == 'confirm' then
        local t = pickTarget
        if t ~= 0 and DoesEntityExist(t) then
            local c = GetEntityCoords(t)
            local m = GetEntityModel(t)
            CreateModelHide(c.x, c.y, c.z, 1.5, m, true) -- effet immédiat chez soi
            TriggerServerEvent('adminmenu:action', 'editor_hide_object', { model = m, x = c.x, y = c.y, z = c.z })
            pickTarget = 0
        else
            Notify('Vise un objet de la map (poteau, panneau, barrière…).', 'error')
        end
    elseif id == 'cancel' then
        picking = false
    end
    return true
end

local function pickLoop()
    while picking do
        Wait(0)
        if not picking then break end
        DisableControlAction(0, 24, true)
        DisableControlAction(0, 25, true)
        DisableControlAction(0, 47, true)
        DrawRect(0.5, 0.5, 0.0025, 0.0045, 255, 255, 255, 200)
        local t = pickRaycast()
        local label = 'Vise un objet de la map'
        if t ~= 0 and DoesEntityExist(t) then
            local c = GetEntityCoords(t)
            DrawMarker(2, c.x, c.y, c.z + 2.0, 0.0, 0.0, 0.0, 180.0, 0.0, 0.0, 0.4, 0.4, 0.4,
                224, 67, 59, 220, true, false, 2, true, nil, nil, false)
            label = ('Objet visé : %X'):format(GetEntityModel(t) & 0xFFFFFFFF)
            DrawText3D(vector3(c.x, c.y, c.z + 2.6), '~r~À retirer~s~ ' .. label, 0.32)
        end
        ShowKeysHud('mappick', 'Retirer un objet de la map', {
            { keys = { EK('confirm') }, label = 'Retirer l\'objet visé (pour tout le monde)' },
            { keys = { EK('cancel') }, label = 'Terminer' },
        }, label)
    end
    pickTarget, pickRay = 0, nil
    if HudOwner == 'mappick' then HideKeysHud() end
end

function StartMapPick()
    if picking then return end
    if IsPlacing() then return Notify('Termine d\'abord le placement en cours.', 'error') end
    picking = true
    Notify('Vise un objet de la map puis appuie sur Valider. Tu peux utiliser le noclip pour t\'approcher.', 'info')
    CreateThread(function()
        local ok, err = pcall(pickLoop)
        if not ok then
            print(('^1[AdminMenu] Erreur retrait d\'objet : %s^7'):format(tostring(err)))
            picking = false
            HideKeysHud()
        end
    end)
end


-- ---------------------------------------------------------
--  VISER UN ÉLÉMENT DE L'ÉDITEUR (props, ateliers, fouilles, plants, PNJ)
--  L'élément visé est entouré d'un contour lumineux, avec son nom,
--  son numéro et son dossier. Les éléments proches ont une étiquette.
--    Valider (E)      : le déplacer
--    Coller (G) x2    : le supprimer
--    Remise à 0 (R)   : dupliquer un prop (même modèle, même dossier)
--    Annuler          : terminer
-- ---------------------------------------------------------
local selecting = false
local selTarget, selRay, selOutlined = 0, nil, 0
local selDelete, selDeleteTime = 0, 0
local KIND_LABEL = { prop = '📦 Prop', station = '🛠️ Atelier', searchpoint = '🔍 Fouille', plant = '🌿 Plant', ped = '🧍 PNJ' }

function IsPropSelect() return selecting end

local function folderName(id)
    for _, f in ipairs(Editor.propFolders or {}) do if f.id == id then return f.name end end
end

local function infoLabel(info)
    local base = ('%s %s'):format(KIND_LABEL[info.kind] or info.kind, info.model or '')
    if info.kind == 'prop' then
        local fname
        for _, r in ipairs(Editor.props) do if r.id == info.id then fname = folderName(r.folder) break end end
        return ('%s ~c~#%d~s~ %s'):format(base, info.id, fname and ('· 📁 ' .. fname) or '· ~c~sans dossier~s~')
    end
    return base
end

local function setOutline(ent)
    if selOutlined ~= ent and selOutlined ~= 0 then outline(selOutlined, false) end
    selOutlined = ent
    if ent ~= 0 then outline(ent, true) end -- sans effet (et sans risque) sur un PNJ
end

local function selRaycast()
    if selRay then
        local status, hit, _, _, ent = GetShapeTestResult(selRay)
        if status == 1 then return selTarget end
        selRay = nil
        selTarget = (hit == 1 and ent ~= 0 and lookup[ent]) and ent or 0
    end
    local from = GetGameplayCamCoord()
    local to = from + rotToDir(GetGameplayCamRot(2)) * 40.0
    -- 16 objets + 4/8 personnages : uniquement ce qui a été posé avec l'éditeur
    selRay = StartShapeTestLosProbe(from.x, from.y, from.z, to.x, to.y, to.z, 28, PlayerPedId(), 4)
    return selTarget
end

function PropSelectKey(id)
    if not selecting or Placing then return false end
    local info = selTarget ~= 0 and lookup[selTarget] or nil
    if id == 'cancel' then
        selecting = false
    elseif id == 'confirm' then
        if not info then Notify('Vise un élément posé avec l\'éditeur.', 'error') return true end
        setOutline(0)
        EditorMove(info)
    elseif id == 'snap' then
        if not info then return true end
        local now = GetGameTimer()
        if selDelete ~= selTarget or now - selDeleteTime > 3000 then
            selDelete, selDeleteTime = selTarget, now
            Notify('Appuie encore une fois pour supprimer définitivement cet élément.', 'warning')
            return true
        end
        selDelete = 0
        setOutline(0)
        EditorDelete(info)
    elseif id == 'reset' then
        if not info or info.kind ~= 'prop' then Notify('Seuls les props peuvent être dupliqués.', 'error') return true end
        local folder
        for _, r in ipairs(Editor.props) do if r.id == info.id then folder = r.folder break end end
        local h = GetEntityHeading(selTarget)
        setOutline(0)
        StartPlacement({ kind = 'prop', model = info.model, heading = h, folder = folder })
    end
    return true
end

local function selectLoop()
    while selecting do
        Wait(0)
        if not selecting then break end
        if Placing then
            setOutline(0)
            selTarget, selRay = 0, nil
        else
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 47, true)
            DrawRect(0.5, 0.5, 0.0025, 0.0045, 255, 255, 255, 200)

            -- Étiquettes discrètes sur les éléments proches (les 20 plus près)
            local me = GetEntityCoords(PlayerPedId())
            local near = {}
            for ent, info in pairs(lookup) do
                if DoesEntityExist(ent) then
                    local d = #(GetEntityCoords(ent) - me)
                    if d < 25.0 then near[#near + 1] = { ent = ent, info = info, d = d } end
                end
            end
            table.sort(near, function(a, b) return a.d < b.d end)

            local t = selRaycast()
            setOutline(t)
            if t ~= 0 and DoesEntityExist(t) and GetEntityType(t) == 1 then markPed(t) end
            for i = 1, math.min(#near, 20) do
                local n = near[i]
                if n.ent ~= t then
                    local c = GetEntityCoords(n.ent)
                    DrawText3D(vector3(c.x, c.y, c.z + 0.9), ('~c~%s'):format(n.info.kind == 'prop' and ('#' .. n.info.id) or (KIND_LABEL[n.info.kind] or '')), 0.26)
                end
            end
            local footer = 'Vise un élément posé avec l\'éditeur'
            if t ~= 0 and DoesEntityExist(t) then
                local info = lookup[t]
                local c = GetEntityCoords(t)
                DrawText3D(vector3(c.x, c.y, c.z + 1.2), infoLabel(info), 0.34)
                footer = (KIND_LABEL[info.kind] or '') .. ' ' .. (info.model or '')
            end
            ShowKeysHud('propselect', 'Viser pour modifier', {
                { keys = { EK('confirm') }, label = 'Déplacer l\'élément visé' },
                { keys = { EK('reset') }, label = 'Dupliquer (props)' },
                { keys = { EK('snap') }, label = 'Supprimer (appuyer 2 fois)' },
                { keys = { EK('cancel') }, label = 'Terminer' },
            }, footer)
        end
    end
    setOutline(0)
    selTarget, selRay = 0, nil
    if HudOwner == 'propselect' then HideKeysHud() end
end

function StartPropSelect()
    if selecting then return end
    if IsPlacing() then return Notify('Termine d\'abord le placement en cours.', 'error') end
    selecting = true
    Notify('Vise un prop : il s\'entoure d\'un contour avec son nom et son dossier. Le noclip marche pendant la sélection.', 'info')
    CreateThread(function()
        local ok, err = pcall(selectLoop)
        if not ok then
            print(('^1[AdminMenu] Erreur sélection : %s^7'):format(tostring(err)))
            selecting = false
            setOutline(0)
            HideKeysHud()
        end
    end)
end

-- « Montrer en jeu » depuis le menu : contour + colonne lumineuse pendant 12 s
local showGen = 0
function ShowPropsInWorld(ids, label)
    local wanted = {}
    for _, id in ipairs(type(ids) == 'table' and ids or {}) do wanted[tonumber(id) or -1] = true end
    local list = {}
    for _, r in ipairs(Editor.props) do if wanted[r.id] then list[#list + 1] = r end end
    if #list == 0 then return Notify('Aucun prop à montrer.', 'error') end
    showGen = showGen + 1
    local gen = showGen
    local me = GetEntityCoords(PlayerPedId())
    local closest, cd = nil, 1e9
    for _, r in ipairs(list) do
        local d = #(vector3(r.x, r.y, r.z) - me)
        if d < cd then closest, cd = r, d end
    end
    Notify(('%s : %d prop(s) en surbrillance pendant 12 s (le plus proche à %d m).'):format(label or 'Props', #list, math.floor(cd)), 'info')
    CreateThread(function()
        local untilT = GetGameTimer() + 12000
        local lit = {}
        while GetGameTimer() < untilT and gen == showGen do
            Wait(0)
            for _, r in ipairs(list) do
                local s2 = spawned['prop:' .. r.id]
                local ent = s2 and s2.ent
                if ent and not lit[ent] and outline(ent, true) then lit[ent] = true end
                DrawMarker(1, r.x, r.y, r.z - 1.0, 0, 0, 0, 0, 0, 0, 0.5, 0.5, 40.0, 242, 177, 52, 90, false, false, 2, false, nil, nil, false)
                if #(vector3(r.x, r.y, r.z) - GetEntityCoords(PlayerPedId())) < 40.0 then
                    DrawText3D(vector3(r.x, r.y, r.z + 1.2), ('#%d %s'):format(r.id, r.model), 0.3)
                end
            end
        end
        for ent in pairs(lit) do
            if ent ~= selOutlined then outline(ent, false) end
        end
    end)
end

-- ---------------------------------------------------------
--  APERÇU 3D D'UN MODÈLE (depuis le catalogue)
--  Le modèle apparaît devant toi, une caméra tourne autour.
-- ---------------------------------------------------------
local previewing = nil

function IsModelPreview() return previewing ~= nil end

local function stopModelPreview(reopen)
    local p = previewing
    previewing = nil
    if not p then return end
    RenderScriptCams(false, true, 400, true, true)
    if p.cam then DestroyCam(p.cam, false) end
    if p.ent and DoesEntityExist(p.ent) then DeleteEntity(p.ent) end
    if HudOwner == 'preview' then HideKeysHud() end
    if reopen then SetTimeout(450, function() OpenMenuStaff() end) end
end

function PreviewKey(id)
    if not previewing then return false end
    if id == 'confirm' then
        local p = previewing
        stopModelPreview(p.kind ~= 'prop')
        if p.kind == 'prop' then SetTimeout(450, function() StartPlacement({ kind = 'prop', model = p.model }) end) end
    elseif id == 'cancel' then
        stopModelPreview(true)
    elseif id == 'rot_left' then
        previewing.zoom = math.max(previewing.zoom - 0.1, 0.5)
    elseif id == 'rot_right' then
        previewing.zoom = math.min(previewing.zoom + 0.1, 2.5)
    end
    return true
end

function StartModelPreview(kind, model)
    if previewing or Placing then return end
    local hash = GetHashKey(model)
    if not IsModelInCdimage(hash) then
        Notify(('Le modèle « %s » n\'existe pas dans le jeu.'):format(model), 'error')
        return SetTimeout(300, function() OpenMenuStaff() end)
    end
    if not loadModel(hash) then
        Notify('Le modèle met trop de temps à charger.', 'error')
        return SetTimeout(300, function() OpenMenuStaff() end)
    end

    local ped = PlayerPedId()
    local pc = GetEntityCoords(ped)
    local fwd = GetEntityForwardVector(ped)
    local x, y = pc.x + fwd.x * 4.0, pc.y + fwd.y * 4.0
    local ok, gz = GetGroundZFor_3dCoord(x, y, pc.z + 2.0, false)
    if not ok then gz = pc.z - 1.0 end

    local ent
    if kind == 'ped' then
        ent = createPed({ model = model, x = x, y = y, z = gz, h = GetEntityHeading(ped) + 180.0 }, true)
    else
        ent = createObject(model, x, y, originZ(hash, gz), 0.0, true)
    end
    if not ent then return OpenMenuStaff() end
    ResetEntityAlpha(ent)
    SetEntityVisible(ent, true, false)

    local mn, mx = GetModelDimensions(hash)
    local size = math.max(#(mx - mn), 0.8)
    local center = GetEntityCoords(ent)
    if kind ~= 'ped' then center = vector3(center.x, center.y, center.z + (mn.z + mx.z) / 2) end

    previewing = { kind = kind, model = model, ent = ent, cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true),
                   center = center, size = size, angle = 0.0, zoom = 1.0 }
    CreateThread(function()
        local ok2, err = pcall(function()
            local first = true
            while previewing do
                Wait(0)
                local p = previewing
                if not p then break end
                DisableAllControlActions(0)
                EnableControlAction(0, 199, true)
                EnableControlAction(0, 200, true)
                p.angle = p.angle + GetFrameTime() * 25.0
                local a = math.rad(p.angle)
                local dist = math.max(p.size * 1.25, 1.8) * p.zoom
                SetCamCoord(p.cam, p.center.x + math.cos(a) * dist, p.center.y + math.sin(a) * dist, p.center.z + p.size * 0.35)
                PointCamAtCoord(p.cam, p.center.x, p.center.y, p.center.z)
                if first then RenderScriptCams(true, true, 500, true, true) first = false end
                ShowKeysHud('preview', 'Aperçu 3D', {
                    { keys = { EK('confirm') }, label = p.kind == 'prop' and 'Placer cet objet' or 'Choisir ce personnage' },
                    { keys = { EK('rot_left'), EK('rot_right') }, label = 'Zoomer / dézoomer' },
                    { keys = { EK('cancel') }, label = 'Retour au menu' },
                }, p.model)
            end
        end)
        if not ok2 then
            print(('^1[AdminMenu] Erreur aperçu 3D : %s^7'):format(tostring(err)))
            stopModelPreview(true)
        end
    end)
end

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and previewing then stopModelPreview(false) end
end)

-- Coupe tous les modes staff en cours (passage en mode RP)
function CancelStaffModes()
    if Placing then stopPlacement() end
    if picking then picking = false end
    if selecting then selecting = false end
    if previewing then stopModelPreview(false) end
    if CancelZoneDraw then CancelZoneDraw() end
    if CancelDoorPick then CancelDoorPick() end
    if RevertTransform and TransformedInto and TransformedInto() then RevertTransform(true) end
    if CancelRevivePreview then CancelRevivePreview() end
    if StopSpectateIfAny then StopSpectateIfAny() end
end
