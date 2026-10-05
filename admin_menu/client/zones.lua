-- =========================================================
--  ZONES : safe zones, quartiers, zones à message
--  - Message personnalisé à l'entrée et à la sortie
--  - Safe zone : pas d'armes ni de coups, joueurs invincibles,
--    limite de vitesse, exception police possible
--  - Dessin libre (coins posés un par un) ou cercle
-- =========================================================
local ZC = Config.Zones
local colorById = {}
for _, c in ipairs(ZC.colors) do colorById[c.id] = c end

local inside = {}        -- [idZone] = true
local zoneBlips = {}
local safeActive = nil   -- réglages cumulés des safe zones où l'on se trouve
local wasInvincible, noDriveBy, limitedSpeed = false, false, false

local function rgb(hex)
    hex = (hex or '#4fb3a9'):gsub('#', '')
    return tonumber(hex:sub(1, 2), 16) or 79, tonumber(hex:sub(3, 4), 16) or 179, tonumber(hex:sub(5, 6), 16) or 169
end

-- Point dans un polygone (2D)
local function inPoly(pts, x, y)
    local inside2, j = false, #pts
    for i = 1, #pts do
        local xi, yi, xj, yj = pts[i].x, pts[i].y, pts[j].x, pts[j].y
        if ((yi > y) ~= (yj > y)) and (x < (xj - xi) * (y - yi) / ((yj - yi) ~= 0 and (yj - yi) or 0.0001) + xi) then
            inside2 = not inside2
        end
        j = i
    end
    return inside2
end

local function inZone(z, p)
    if p.z < z.minZ or p.z > z.maxZ then return false end
    if z.shape == 'circle' then
        local dx, dy = p.x - z.center.x, p.y - z.center.y
        return dx * dx + dy * dy <= z.radius * z.radius
    end
    if not z._box then
        local b = { minX = math.huge, minY = math.huge, maxX = -math.huge, maxY = -math.huge }
        for _, q in ipairs(z.points) do
            b.minX, b.minY = math.min(b.minX, q.x), math.min(b.minY, q.y)
            b.maxX, b.maxY = math.max(b.maxX, q.x), math.max(b.maxY, q.y)
        end
        z._box = b
    end
    local b = z._box
    if p.x < b.minX or p.x > b.maxX or p.y < b.minY or p.y > b.maxY then return false end
    return inPoly(z.points, p.x, p.y)
end

-- Le point est-il dans une safe zone ? (utilisé par l'événement zombies)
function IsInSafeZone(p)
    for _, z in ipairs((Editor and Editor.zones) or {}) do
        if z.safe and inZone(z, p) then return true end
    end
    return false
end

local function zoneCenter(z)
    if z.shape == 'circle' then return z.center.x, z.center.y, z.radius end
    local cx, cy = 0.0, 0.0
    for _, q in ipairs(z.points) do cx, cy = cx + q.x, cy + q.y end
    cx, cy = cx / #z.points, cy / #z.points
    local r = 0.0
    for _, q in ipairs(z.points) do r = math.max(r, math.sqrt((q.x - cx) ^ 2 + (q.y - cy) ^ 2)) end
    return cx, cy, r
end

-- ---------------------------------------------------------
--  Blips et synchro
-- ---------------------------------------------------------
function RefreshZones()
    for _, b in ipairs(zoneBlips) do if DoesBlipExist(b) then RemoveBlip(b) end end
    zoneBlips = {}
    for _, z in ipairs(Editor.zones or {}) do
        z._box = nil
        if z.blip then
            local cx, cy, r = zoneCenter(z)
            local col = (colorById[z.color] or {}).blip or 2
            local area = AddBlipForRadius(cx, cy, 0.0, r + 0.0)
            SetBlipColour(area, col)
            SetBlipAlpha(area, 90)
            local b = AddBlipForCoord(cx, cy, 0.0)
            local sprite = tonumber(z.blipSprite) or 0
            SetBlipSprite(b, sprite > 0 and sprite or (z.safe and 487 or 1))
            SetBlipColour(b, col)
            SetBlipScale(b, (tonumber(z.blipScale) or 0.8) + 0.0)
            SetBlipAsShortRange(b, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(z.name)
            EndTextCommandSetBlipName(b)
            zoneBlips[#zoneBlips + 1] = area
            zoneBlips[#zoneBlips + 1] = b
        end
    end
    -- Zones supprimées : on en sort proprement
    local ids = {}
    for _, z in ipairs(Editor.zones or {}) do ids[z.id] = true end
    for id in pairs(inside) do if not ids[id] then inside[id] = nil end end
end

local function isPolice()
    for _, r in ipairs({ 'qbx_core', 'qb-core' }) do
        if GetResourceState(r) == 'started' then
            local ok, job = pcall(function()
                local pd = r == 'qbx_core' and exports.qbx_core:GetPlayerData() or exports['qb-core']:GetCoreObject().Functions.GetPlayerData()
                return pd and pd.job
            end)
            if ok and job then
                for _, j in ipairs(Config.PoliceJobs or {}) do
                    if job.name == j and job.onduty ~= false then return true end
                end
                return false
            end
        end
    end
    return false
end

-- ---------------------------------------------------------
--  Entrée / sortie (4 fois par seconde)
-- ---------------------------------------------------------
CreateThread(function()
    while true do
        Wait(250)
        local zones = Editor.zones or {}
        if #zones > 0 then
            local p = GetEntityCoords(PlayerPedId())
            local safe = nil
            for _, z in ipairs(zones) do
                local now = inZone(z, p)
                if now and not inside[z.id] then
                    inside[z.id] = true
                    local msg = (z.enterMsg and z.enterMsg ~= '') and z.enterMsg or nil
                    if msg then SendNUIMessage({ action = 'zonemsg', text = msg, color = (colorById[z.color] or {}).hex, safe = z.safe }) end
                elseif not now and inside[z.id] then
                    inside[z.id] = nil
                    if z.exitMsg and z.exitMsg ~= '' then
                        SendNUIMessage({ action = 'zonemsg', text = z.exitMsg, color = (colorById[z.color] or {}).hex })
                    end
                end
                if now and z.safe and not (z.exemptPolice and isPolice()) then
                    safe = safe or { noWeapons = false, invincible = false, speedLimit = 0 }
                    safe.noWeapons = safe.noWeapons or z.noWeapons
                    safe.invincible = safe.invincible or z.invincible
                    if z.speedLimit > 0 and (safe.speedLimit == 0 or z.speedLimit < safe.speedLimit) then safe.speedLimit = z.speedLimit end
                end
            end
            safeActive = safe
        else
            safeActive = nil
        end
    end
end)

-- Effets de la safe zone (à chaque image seulement quand on y est)
CreateThread(function()
    local UNARMED = GetHashKey('WEAPON_UNARMED')
    while true do
        local s = safeActive
        if s then
            local ped, pid = PlayerPedId(), PlayerId()
            if s.noWeapons then
                DisablePlayerFiring(pid, true)
                for _, c in ipairs({ 24, 25, 37, 45, 47, 58, 140, 141, 142, 143, 257, 263, 264 }) do DisableControlAction(0, c, true) end
                if GetSelectedPedWeapon(ped) ~= UNARMED then SetCurrentPedWeapon(ped, UNARMED, true) end
                SetPlayerCanDoDriveBy(pid, false)
                noDriveBy = true
            end
            if s.invincible then
                SetEntityInvincible(ped, true)
                wasInvincible = true
            end
            if s.speedLimit > 0 then
                local veh = GetVehiclePedIsIn(ped, false)
                if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then
                    SetVehicleMaxSpeed(veh, s.speedLimit / 3.6)
                    limitedSpeed = true
                end
            end
            Wait(0)
        else
            -- Sortie de safe zone : on rend tout comme avant
            if wasInvincible then
                wasInvincible = false
                if not State.godmode and not IsNoclipActive() then SetEntityInvincible(PlayerPedId(), false) end
            end
            if noDriveBy then noDriveBy = false SetPlayerCanDoDriveBy(PlayerId(), true) end
            if limitedSpeed then
                limitedSpeed = false
                local veh = GetVehiclePedIsIn(PlayerPedId(), false)
                if veh ~= 0 then SetVehicleMaxSpeed(veh, 0.0) end
            end
            while not safeActive do Wait(250) end
        end
    end
end)

-- ---------------------------------------------------------
--  Limites visibles (pour tous si la zone le demande,
--  pour le staff si « Afficher les limites » est activé)
-- ---------------------------------------------------------
local function drawWall(a, b, zMin, zMax, r, g, bl, al)
    DrawPoly(a.x, a.y, zMin, b.x, b.y, zMin, b.x, b.y, zMax, r, g, bl, al)
    DrawPoly(a.x, a.y, zMin, b.x, b.y, zMax, a.x, a.y, zMax, r, g, bl, al)
    DrawPoly(b.x, b.y, zMax, b.x, b.y, zMin, a.x, a.y, zMin, r, g, bl, al)
    DrawPoly(a.x, a.y, zMax, b.x, b.y, zMax, a.x, a.y, zMin, r, g, bl, al)
end

local function drawZone(z, p)
    local r, g, b = rgb((colorById[z.color] or {}).hex)
    local zMin, zMax = p.z - 2.0, p.z + 8.0
    if z.shape == 'circle' then
        DrawMarker(1, z.center.x, z.center.y, p.z - 2.0, 0, 0, 0, 0, 0, 0, z.radius * 2.0, z.radius * 2.0, 10.0,
            r, g, b, 45, false, false, 2, false, nil, nil, false)
        return
    end
    local n = #z.points
    for i = 1, n do
        local a, c = z.points[i], z.points[i % n + 1]
        drawWall(a, c, zMin, zMax, r, g, b, 45)
        DrawLine(a.x, a.y, zMin, c.x, c.y, zMin, r, g, b, 220)
        DrawLine(a.x, a.y, zMax, c.x, c.y, zMax, r, g, b, 220)
    end
end

CreateThread(function()
    while true do
        local zones = Editor.zones or {}
        local any = false
        if #zones > 0 then
            local p = GetEntityCoords(PlayerPedId())
            for _, z in ipairs(zones) do
                if z.showBorder or State.showZones then
                    local cx, cy, rad = zoneCenter(z)
                    if (p.x - cx) ^ 2 + (p.y - cy) ^ 2 < (rad + 200.0) ^ 2 then
                        any = true
                        drawZone(z, p)
                    end
                end
            end
        end
        Wait(any and 0 or 500)
    end
end)

-- ---------------------------------------------------------
--  MODE DESSIN : on pose les coins un par un
-- ---------------------------------------------------------
local drawing = nil

function IsZoneDraw() return drawing ~= nil end
function CancelZoneDraw() drawing = nil end

local function aimPoint()
    local rot = GetGameplayCamRot(2)
    local zr, xr = math.rad(rot.z), math.rad(rot.x)
    local n = math.abs(math.cos(xr))
    local dir = vector3(-math.sin(zr) * n, math.cos(zr) * n, math.sin(xr))
    local from = GetGameplayCamCoord()
    local to = from + dir * 200.0
    local ray = StartExpensiveSynchronousShapeTestLosProbe(from.x, from.y, from.z, to.x, to.y, to.z, 1, PlayerPedId(), 7)
    local _, hit, pos = GetShapeTestResult(ray)
    if hit == 1 then return pos end
    return GetEntityCoords(PlayerPedId())
end

function ZoneDrawKey(id)
    if not drawing then return false end
    if id == 'confirm' then
        local p = drawing.aim
        if p then
            drawing.points[#drawing.points + 1] = { x = p.x, y = p.y, z = p.z }
            PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
        end
    elseif id == 'cancel' then
        if #drawing.points > 0 then
            table.remove(drawing.points)
        else
            drawing = nil
            Notify('Dessin de la zone annulé.', 'info')
        end
    elseif id == 'finish' then
        if #drawing.points < 3 then return true, Notify('Pose au moins 3 coins.', 'error') end
        TriggerServerEvent('adminmenu:action', 'editor_save_zone', {
            id = drawing.id, shape = 'poly', points = drawing.points, settings = drawing.settings,
        })
        drawing = nil
    end
    return true
end

local function drawLoop()
    while drawing do
        Wait(0)
        local d = drawing
        if not d then break end -- terminé ou annulé pendant l'attente
        DisableControlAction(0, 24, true)
        DisableControlAction(0, 25, true)
        local aim = aimPoint()
        d.aim = aim
        local r, g, b = rgb((colorById[(d.settings or {}).color] or {}).hex)
        DrawMarker(28, aim.x, aim.y, aim.z, 0, 0, 0, 0, 0, 0, 0.35, 0.35, 0.35, r, g, b, 220, false, false, 2, false, nil, nil, false)

        local pts = d.points
        for i, p in ipairs(pts) do
            DrawMarker(1, p.x, p.y, p.z - 1.0, 0, 0, 0, 0, 0, 0, 0.6, 0.6, 6.0, r, g, b, 200, false, false, 2, false, nil, nil, false)
            DrawText3D(vector3(p.x, p.y, p.z + 5.5), ('Coin %d'):format(i), 0.32)
            local nx = pts[i + 1] or aim
            DrawLine(p.x, p.y, p.z + 0.2, nx.x, nx.y, nx.z + 0.2, r, g, b, 255)
            drawWall(p, nx, math.min(p.z, nx.z) - 0.5, math.max(p.z, nx.z) + 5.0, r, g, b, 50)
        end
        if #pts >= 2 then
            DrawLine(aim.x, aim.y, aim.z + 0.2, pts[1].x, pts[1].y, pts[1].z + 0.2, r, g, b, 120)
        end

        ShowKeysHud('zonedraw', 'Dessiner la zone', {
            { keys = { EK('confirm') }, label = 'Poser un coin ici' },
            { keys = { EK('cancel') }, label = #pts > 0 and 'Retirer le dernier coin' or 'Annuler' },
            { keys = { EK('finish') }, label = 'Terminer la zone' },
        }, ('%d coin(s) posé(s)%s'):format(#pts, #pts < 3 and ' · 3 minimum' or ''))
    end
    if HudOwner == 'zonedraw' then HideKeysHud() end
end

function StartZoneDraw(id, settings)
    if drawing then return end
    if IsPlacing() then return Notify('Termine d\'abord le placement en cours.', 'error') end
    drawing = { id = id, settings = settings, points = {} }
    Notify('Vise le sol et pose les coins de la zone un par un (le noclip marche aussi).', 'info')
    CreateThread(function()
        local ok, err = pcall(drawLoop)
        if not ok then
            print(('^1[AdminMenu] Erreur dessin de zone : %s^7'):format(tostring(err)))
            drawing = nil
            HideKeysHud()
        end
    end)
end

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, b in ipairs(zoneBlips) do if DoesBlipExist(b) then RemoveBlip(b) end end
    if wasInvincible and not State.godmode then SetEntityInvincible(PlayerPedId(), false) end
    SetPlayerCanDoDriveBy(PlayerId(), true)
end)
