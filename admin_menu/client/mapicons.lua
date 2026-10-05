-- =========================================================
--  ICÔNES DE LA CARTE (tous les joueurs)
--  - Règles du staff sur les icônes créées par les autres scripts :
--    reconnues par leur modèle + position d'origine (à 3 m près).
--  - Icônes ajoutées par le staff.
-- =========================================================
local Data = { rules = {}, custom = {} }
local customHandles = {}   -- [id] = blip
local ownHandles = {}      -- [blip] = true : nos icônes, jamais modifiées par les règles
local touched = {}         -- [blip] = { rule, orig = { x, y, z, display, color, scale } }

local DISPLAY = { all = 2, map = 3, minimap = 5, hidden = 0 }
local MATCH_DIST = 3.0

-- ---------------------------------------------------------
--  Icônes ajoutées par le staff
-- ---------------------------------------------------------
local function setName(blip, name)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(name)
    EndTextCommandSetBlipName(blip)
end

local function rebuildCustom()
    for _, b in pairs(customHandles) do if DoesBlipExist(b) then RemoveBlip(b) end end
    customHandles, ownHandles = {}, {}
    for _, c in ipairs(Data.custom or {}) do
        local b = AddBlipForCoord(c.x + 0.0, c.y + 0.0, (c.z or 0.0) + 0.0)
        SetBlipSprite(b, c.sprite or 1)
        SetBlipColour(b, c.color or 0)
        SetBlipScale(b, (c.scale or 0.9) + 0.0)
        SetBlipDisplay(b, DISPLAY[c.display or 'all'] or 2)
        SetBlipAsShortRange(b, c.shortRange == true)
        setName(b, c.label or 'Point d\'intérêt')
        customHandles[c.id] = b
        ownHandles[b] = true
    end
end

-- ---------------------------------------------------------
--  Règles sur les icônes des scripts
-- ---------------------------------------------------------
local function eachBlipOfSprite(sprite, fn)
    local b = GetFirstBlipInfoId(sprite)
    while DoesBlipExist(b) do
        fn(b)
        b = GetNextBlipInfoId(sprite)
    end
end

local function originOf(blip)
    local t = touched[blip]
    if t then return vector3(t.orig.x, t.orig.y, t.orig.z) end
    return GetBlipInfoIdCoord(blip)
end

local function restore(blip)
    local t = touched[blip]
    touched[blip] = nil
    if not t or not DoesBlipExist(blip) then return end
    local o = t.orig
    SetBlipCoords(blip, o.x, o.y, o.z)
    SetBlipDisplay(blip, o.display)
    SetBlipColour(blip, o.color)
    SetBlipScale(blip, o.scale)
end

local function applyRule(blip, rule)
    if not touched[blip] then
        local c = GetBlipInfoIdCoord(blip)
        touched[blip] = { orig = { x = c.x, y = c.y, z = c.z, display = GetBlipInfoIdDisplay(blip), color = GetBlipColour(blip), scale = 1.0 } }
    end
    local t = touched[blip]
    t.rule = rule.id
    local o = t.orig
    if rule.x then SetBlipCoords(blip, rule.x + 0.0, rule.y + 0.0, (rule.z or 0.0) + 0.0) else SetBlipCoords(blip, o.x, o.y, o.z) end
    SetBlipDisplay(blip, rule.display and DISPLAY[rule.display] or o.display)
    SetBlipColour(blip, rule.color or o.color)
    SetBlipScale(blip, (rule.scale or o.scale) + 0.0)
    if rule.name and rule.name ~= '' then setName(blip, rule.name) end
end

local function applyAll()
    local seen = {}
    local bySprite = {}
    for _, r in ipairs(Data.rules or {}) do
        bySprite[r.sprite] = bySprite[r.sprite] or {}
        table.insert(bySprite[r.sprite], r)
    end
    for sprite, rules in pairs(bySprite) do
        eachBlipOfSprite(sprite, function(blip)
            if ownHandles[blip] or GetBlipInfoIdType(blip) ~= 4 then return end
            local origin = originOf(blip)
            for _, r in ipairs(rules) do
                if #(vector2(origin.x, origin.y) - vector2(r.ox, r.oy)) <= MATCH_DIST then
                    applyRule(blip, r)
                    seen[blip] = true
                    break
                end
            end
        end)
    end
    -- Règle supprimée : l'icône reprend son état d'origine
    for blip in pairs(touched) do
        if not seen[blip] then restore(blip) end
    end
end

RegisterNetEvent('adminmenu:map', function(data)
    if type(data) ~= 'table' then return end
    Data.rules = data.rules or {}
    Data.custom = data.custom or {}
    rebuildCustom()
    applyAll()
end)

-- Les scripts recréent parfois leurs icônes : on réapplique régulièrement
CreateThread(function()
    while true do
        Wait(4000)
        if #(Data.rules or {}) > 0 then applyAll() end
    end
end)

RegisterNetEvent('adminmenu:map:tp', function(c)
    CloseMenu()
    TeleportTo(c, true)
end)

-- ---------------------------------------------------------
--  Inventaire de toutes les icônes (pour le menu du staff)
-- ---------------------------------------------------------
local DISPLAY_NAME = { [2] = 'all', [3] = 'map', [4] = 'all', [5] = 'minimap', [6] = 'all', [8] = 'map', [0] = 'hidden' }

RegisterNUICallback('map_scan', function(_, cb)
    local pc = GetEntityCoords(PlayerPedId())
    local list = {}
    for sprite = 0, 900 do
        eachBlipOfSprite(sprite, function(blip)
            if ownHandles[blip] or GetBlipInfoIdType(blip) ~= 4 then return end
            local t = touched[blip]
            local o = originOf(blip)
            local now = GetBlipInfoIdCoord(blip)
            list[#list + 1] = {
                sprite = sprite, color = t and t.orig.color or GetBlipColour(blip),
                ox = o.x, oy = o.y, oz = o.z, x = now.x, y = now.y, z = now.z,
                display = t and (DISPLAY_NAME[t.orig.display] or 'all') or (DISPLAY_NAME[GetBlipInfoIdDisplay(blip)] or 'all'),
                distance = math.floor(#(vector2(pc.x, pc.y) - vector2(o.x, o.y))),
                rule = t and t.rule or nil,
            }
        end)
    end
    table.sort(list, function(a, b) return a.distance < b.distance end)
    cb({ list = list })
end)

-- Faire clignoter une icône pour la repérer sur la carte
RegisterNUICallback('map_flash', function(body, cb)
    cb('ok')
    local sprite, ox, oy = tonumber(body.sprite), tonumber(body.ox), tonumber(body.oy)
    if not sprite then return end
    eachBlipOfSprite(sprite, function(blip)
        local o = originOf(blip)
        if #(vector2(o.x, o.y) - vector2(ox, oy)) <= MATCH_DIST then
            SetBlipFlashes(blip, true)
            SetTimeout(8000, function() if DoesBlipExist(blip) then SetBlipFlashes(blip, false) end end)
        end
    end)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for blip in pairs(touched) do restore(blip) end
end)
