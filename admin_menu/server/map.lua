-- =========================================================
--  ONGLET 🗺️ CARTE - SERVEUR
--  - Mini-carte : forme, position, taille (même réglage pour tous).
--  - Icônes des scripts : règles appliquées par chaque joueur
--    (cacher, déplacer, renommer, recolorer, agrandir).
--  - Icônes ajoutées par le staff.
--  Permission « manage_map » vérifiée par le dispatcher d'actions.
-- =========================================================
local AM = AdminMenu
local Map = Storage.load('map', {})
Map.rules = Map.rules or {}
Map.custom = Map.custom or {}
Map.nextId = Map.nextId or 1
if not Map.minimap then
    Map.minimap = {}
    for k, v in pairs(Config.Minimap or {}) do Map.minimap[k] = v end
end

local DISPLAYS = { all = true, map = true, minimap = true, hidden = true }
local SHAPES = { square = true, round = true, default = true }
local POSITIONS = { ['top-right'] = true, ['top-left'] = true, ['bottom-left'] = true, ['bottom-right'] = true }

local function save() Storage.save('map', Map) end
local function public() return { minimap = Map.minimap, rules = Map.rules, custom = Map.custom } end
local function broadcast(target) TriggerClientEvent('adminmenu:map', target or -1, public()) end

RegisterNetEvent('adminmenu:map:request', function() broadcast(source) end)

local function num(v, def, min, max)
    v = tonumber(v) or def
    if min then v = math.max(min, v) end
    if max then v = math.min(max, v) end
    return v
end
local function str(v, max) return (tostring(v or ''):gsub('^%s+', ''):gsub('%s+$', '')):sub(1, max or 60) end

local function position(src, d)
    if d.useMyPosition then
        local c = GetEntityCoords(GetPlayerPed(src))
        return c.x, c.y, c.z
    end
    local x, y, z = tonumber(d.x), tonumber(d.y), tonumber(d.z)
    if not x or not y then return nil end
    return x, y, z or 0.0
end

local function findIn(list, id)
    id = tonumber(id)
    for i, e in ipairs(list) do if e.id == id then return e, i end end
end

local A = AM.Actions
local function act(fn)
    return { perm = 'manage_map', noRefresh = true, fn = function(src, d)
        local msg, kind = fn(src, d)
        if msg then AM.notify(src, msg, kind or 'success') end
        AM.sendData(src)
    end }
end

-- ---------------------------------------------------------
--  Mini-carte
-- ---------------------------------------------------------
A.minimap_save = act(function(src, d)
    local m = Map.minimap
    m.enabled = d.enabled ~= false
    m.shape = SHAPES[d.shape] and d.shape or 'square'
    m.position = POSITIONS[d.position] and d.position or 'top-right'
    m.size = num(d.size, 0.20, 0.08, 0.45)
    m.widthAdjust = num(d.widthAdjust, 100, 50, 200)
    m.marginX = num(d.marginX, 0.012, -0.2, 0.3)
    m.marginY = num(d.marginY, 0.018, -0.2, 0.3)
    m.hideHealthBars = d.hideHealthBars == true
    m.onlyInVehicle = d.onlyInVehicle == true
    save()
    broadcast()
    AM.addLog(src, 'Mini-carte modifiée', ('%s · %s · taille %.2f'):format(m.shape, m.position, m.size))
    return 'Mini-carte enregistrée pour tous les joueurs.'
end)

A.minimap_reset = act(function(src)
    Map.minimap = {}
    for k, v in pairs(Config.Minimap or {}) do Map.minimap[k] = v end
    save()
    broadcast()
    AM.addLog(src, 'Mini-carte remise par défaut')
    return 'Mini-carte remise par défaut.'
end)

-- ---------------------------------------------------------
--  Icônes des scripts : règles
--  Une règle reconnaît une icône par son modèle (sprite) et sa position d'origine.
-- ---------------------------------------------------------
A.blip_rule_save = act(function(src, d)
    local rule = d.id and findIn(Map.rules, d.id)
    if not rule then
        local sprite, ox, oy = tonumber(d.sprite), tonumber(d.ox), tonumber(d.oy)
        if not sprite or not ox or not oy then return 'Icône invalide.', 'error' end
        rule = { id = Map.nextId, sprite = math.floor(sprite), ox = ox, oy = oy, oz = tonumber(d.oz) or 0.0 }
        Map.nextId = Map.nextId + 1
        table.insert(Map.rules, rule)
    end
    if d.display ~= nil then rule.display = DISPLAYS[d.display] and d.display or nil end
    if d.name ~= nil then rule.name = str(d.name, 60) ~= '' and str(d.name, 60) or nil end
    if d.color ~= nil then rule.color = tonumber(d.color) and tonumber(d.color) >= 0 and math.floor(tonumber(d.color)) or nil end
    if d.scale ~= nil then
        local sc = tonumber(d.scale)
        rule.scale = (sc and sc > 0) and num(sc, 1.0, 0.3, 3.0) or nil
    end
    if d.label ~= nil then rule.label = str(d.label, 60) end
    if d.move == 'reset' then
        rule.x, rule.y, rule.z = nil, nil, nil
    elseif d.move == 'me' or d.move == 'coords' then
        local x, y, z = position(src, { useMyPosition = d.move == 'me', x = d.x, y = d.y, z = d.z })
        if not x then return 'Coordonnées invalides.', 'error' end
        rule.x, rule.y, rule.z = x, y, z
    end
    save()
    broadcast()
    AM.addLog(src, 'Icône de la carte modifiée', ('#%d · icône %d · %s'):format(rule.id, rule.sprite, rule.display or 'visible'))
    return 'Icône modifiée pour tous les joueurs.'
end)

A.blip_rule_delete = act(function(src, d)
    local rule, i = findIn(Map.rules, d.id)
    if not rule then return end
    table.remove(Map.rules, i)
    save()
    broadcast()
    AM.addLog(src, 'Icône de la carte remise comme avant', ('#%d · icône %d'):format(rule.id, rule.sprite))
    return 'L\'icône est remise comme avant.'
end)

-- ---------------------------------------------------------
--  Icônes ajoutées par le staff
-- ---------------------------------------------------------
A.blip_custom_save = act(function(src, d)
    local b = d.id and findIn(Map.custom, d.id)
    if not b then
        b = { id = Map.nextId }
        Map.nextId = Map.nextId + 1
        table.insert(Map.custom, b)
    end
    b.label = str(d.label, 60) ~= '' and str(d.label, 60) or (b.label or 'Point d\'intérêt')
    b.sprite = math.floor(num(d.sprite, b.sprite or 1, 0, 2000))
    b.color = math.floor(num(d.color, b.color or 0, 0, 85))
    b.scale = num(d.scale, b.scale or 0.9, 0.3, 3.0)
    b.display = DISPLAYS[d.display] and d.display or (b.display or 'all')
    if d.shortRange ~= nil then b.shortRange = d.shortRange == true or d.shortRange == 'true' end
    if d.useMyPosition or d.x ~= nil then
        local x, y, z = position(src, d)
        if not x then return 'Coordonnées invalides.', 'error' end
        b.x, b.y, b.z = x, y, z
    end
    if not b.x then
        local c = GetEntityCoords(GetPlayerPed(src))
        b.x, b.y, b.z = c.x, c.y, c.z
    end
    save()
    broadcast()
    AM.addLog(src, 'Icône ajoutée / modifiée', ('#%d · %s'):format(b.id, b.label))
    return ('Icône « %s » enregistrée.'):format(b.label)
end)

A.blip_custom_delete = act(function(src, d)
    local b, i = findIn(Map.custom, d.id)
    if not b then return end
    table.remove(Map.custom, i)
    save()
    broadcast()
    AM.addLog(src, 'Icône supprimée', ('#%d · %s'):format(b.id, b.label))
    return ('Icône « %s » supprimée.'):format(b.label)
end)

A.map_tp = { perm = 'manage_map', noRefresh = true, fn = function(src, d)
    local x, y, z = tonumber(d.x), tonumber(d.y), tonumber(d.z)
    if not x or not y then return end
    TriggerClientEvent('adminmenu:map:tp', src, { x = x, y = y, z = z or 0.0 })
    AM.addLog(src, 'Téléportation (carte)', ('%.1f, %.1f, %.1f'):format(x, y, z or 0.0))
end }

-- ---------------------------------------------------------
--  Données de l'onglet
-- ---------------------------------------------------------
table.insert(AM.DataHooks, function(src, data)
    if not AM.hasPerm(src, 'manage_map') then return end
    -- Clés en texte : une table à trous ne passe pas bien en JSON
    local icons = {}
    for id, label in pairs(Config.MapIcons or {}) do icons[tostring(id)] = label end
    data.map = {
        minimap = Map.minimap, defaults = Config.Minimap, rules = Map.rules, custom = Map.custom,
        icons = icons, colors = Config.MapColors or {}, iconList = (Config.Zones and Config.Zones.icons) or {},
    }
end)
