-- =========================================================
--  ÉDITEUR DE MAP - SERVEUR
--  Tout est sauvegardé dans data/*.json : persistant après
--  redémarrage de la ressource ou du serveur.
-- =========================================================
local AM = AdminMenu
local MIN = Config.Editor.minLevel

local Data = {
    spawns = Storage.load('spawns', {}),
    props  = Storage.load('props', {}),
    peds   = Storage.load('peds', {}),
    fields = Storage.load('fields', {}),
    stations = Storage.load('stations', {}),
    searches = Storage.load('searches', {}),
    hidden = Storage.load('hidden', {}),     -- objets de la map retirés
    zones = Storage.load('zones', {}),       -- safe zones, quartiers…
    doors = Storage.load('doors', {}),       -- portes et portails verrouillables
    propFolders = Storage.load('prop_folders', {}), -- dossiers pour ranger les props
    stashes = Storage.load('stashes', {}),   -- coffres (inventaires) posés sur la map
}
local Jails = Storage.load('jails', {})     -- [licence] = { remaining, ret, reason, by, name }
local Looted = {}      -- ["idZone:idxPoint"] = GetGameTimer() de réapprovisionnement
local Searching = {}   -- [source] = fouille en cours
local broadcastLooted  -- défini plus bas
local Known = Storage.load('known', {})   -- licences déjà venues sur le serveur
local Crafting = {}                       -- [source] = fabrication en cours

local Down = {}        -- ["idChamp:idxPlant"] = GetGameTimer() de repousse
local Harvesting = {}  -- [source] = récolte en cours

-- ---------------------------------------------------------
--  Utilitaires
-- ---------------------------------------------------------
local function nextId(list)
    local m = 0
    for _, r in ipairs(list) do if (r.id or 0) > m then m = r.id end end
    return m + 1
end

local function findIndex(list, id)
    id = tonumber(id)
    for i, r in ipairs(list) do if r.id == id then return i, r end end
end

local function num(v, min, max, def)
    v = tonumber(v)
    if not v or v ~= v then return def end
    if min and v < min then v = min end
    if max and v > max then v = max end
    return v
end

local function cleanName(v, len) return (tostring(v or ''):gsub('[%c<>]', '')):sub(1, len or 40) end
local function cleanModel(v) return (tostring(v or ''):gsub('[^%w_]', '')):sub(1, 60) end

local function bool(v, def)
    if v == nil then return def == true end
    return v == true or v == 'true'
end

local function round(v) return math.floor(v * 1000 + 0.5) / 1000 end

-- Inclinaison (objet posé sur une pente). nil si l'objet est droit.
local function tilt(d)
    local rx, ry = tonumber(d.rx), tonumber(d.ry)
    if not rx or not ry or (math.abs(rx) < 0.05 and math.abs(ry) < 0.05) then return nil, nil end
    return round(rx), round(ry)
end

local function coords(d)
    local x, y, z, h = tonumber(d.x), tonumber(d.y), tonumber(d.z), tonumber(d.h)
    if not x or not y or not z then return nil end
    return round(x), round(y), round(z), round((h or 0.0) % 360)
end

local STORAGE_NAME = { propFolders = 'prop_folders' }
local function save(kind)
    Storage.saveLater(STORAGE_NAME[kind] or kind, Data[kind])
end

-- Envoi groupé : plusieurs modifications en 150 ms = un seul envoi à tous.
-- Pour un joueur seul (connexion), envoi « latent » en arrière-plan :
-- les grosses listes ne bloquent pas le réseau.
-- Les portes sont envoyées sans le code (seul le serveur le connaît)
local function publicList(kind)
    if kind ~= 'doors' then return Data[kind] end
    local out = {}
    for _, d in ipairs(Data.doors) do
        out[#out + 1] = { id = d.id, name = d.name, leaves = d.leaves, locked = d.locked, hasCode = d.codeHash ~= nil, owners = d.owners, distance = d.distance }
    end
    return out
end

local pendingBroadcast = {}
local function broadcast(kind, target)
    if target then
        TriggerLatentClientEvent('adminmenu:editor:sync', target, 200000, kind, publicList(kind))
        return
    end
    if pendingBroadcast[kind] then return end
    pendingBroadcast[kind] = true
    SetTimeout(150, function()
        pendingBroadcast[kind] = nil
        TriggerClientEvent('adminmenu:editor:sync', -1, kind, publicList(kind))
    end)
end

local function downMap()
    local m = {}
    for k in pairs(Down) do m[k] = true end
    return m
end

local function broadcastDown(target)
    TriggerClientEvent('adminmenu:harvest:down', target or -1, downMap())
end

local function clearFieldDown(fid)
    local prefix = tostring(fid) .. ':'
    for k in pairs(Down) do if k:sub(1, #prefix) == prefix then Down[k] = nil end end
end

RegisterNetEvent('adminmenu:editor:request', function()
    local src = source
    if not AM.rateLimit(src, 'adminmenu:editor:request', 2, 5000) then return end
    for kind in pairs(Data) do broadcast(kind, src) end
    broadcastDown(src)
    broadcastLooted(src)
end)

-- ---------------------------------------------------------
--  Actions (permission + niveau minimum vérifiés par le dispatcher)
-- ---------------------------------------------------------
local A = AM.Actions
local function def(name, perm, fn) A[name] = { perm = perm, minLevel = MIN, noRefresh = true, fn = fn } end

-- Points de spawn ------------------------------------------
def('editor_add_spawn', 'editor_spawns', function(src, d)
    local ped = GetPlayerPed(src)
    local c = GetEntityCoords(ped)
    local name = cleanName(d.name)
    if name == '' then name = ('Spawn %d'):format(nextId(Data.spawns)) end
    local s = { id = nextId(Data.spawns), name = name, x = round(c.x), y = round(c.y), z = round(c.z), h = round(GetEntityHeading(ped)) }
    table.insert(Data.spawns, s)
    save('spawns') broadcast('spawns')
    AM.notify(src, ('Point de spawn « %s » ajouté.'):format(name), 'success')
    AM.addLog(src, 'Spawn ajouté', ('%s (%.1f, %.1f, %.1f)'):format(name, s.x, s.y, s.z))
end)

def('editor_rename_spawn', 'editor_spawns', function(src, d)
    local _, r = findIndex(Data.spawns, d.id)
    if not r then return end
    local name = cleanName(d.name)
    if name == '' then return end
    r.name = name
    save('spawns') broadcast('spawns')
    AM.notify(src, 'Point de spawn renommé.', 'success')
end)

def('editor_set_newcomer', 'editor_spawns', function(src, d)
    local _, r = findIndex(Data.spawns, d.id)
    if not r then return end
    local enable = not r.newcomer
    for _, s in ipairs(Data.spawns) do s.newcomer = nil end
    if enable then r.newcomer = true end
    save('spawns') broadcast('spawns')
    AM.notify(src, enable and ('Les nouveaux arrivants apparaîtront à « %s ».'):format(r.name)
        or 'Plus de point dédié aux nouveaux arrivants.', 'success')
    AM.addLog(src, 'Spawn nouveaux arrivants', enable and r.name or 'désactivé')
end)

def('editor_set_jail', 'editor_spawns', function(src, d)
    local _, r = findIndex(Data.spawns, d.id)
    if not r then return end
    local enable = not r.jail
    for _, sp in ipairs(Data.spawns) do sp.jail = nil end
    if enable then r.jail = true end
    save('spawns') broadcast('spawns')
    AM.notify(src, enable and ('Point de jail : « %s ».'):format(r.name) or 'Plus de point de jail.', 'success')
    AM.addLog(src, 'Point de jail', enable and r.name or 'désactivé')
end)

-- Props ----------------------------------------------------
def('editor_save_prop', 'editor_props', function(src, d)
    local model = cleanModel(d.model)
    local x, y, z, h = coords(d)
    if model == '' or not x then return AM.notify(src, 'Données de placement invalides.', 'error') end
    local i, r = findIndex(Data.props, d.id)
    if r then
        r.x, r.y, r.z, r.h = x, y, z, h
        r.rx, r.ry = tilt(d)
        AM.addLog(src, 'Prop déplacé', ('#%d %s'):format(r.id, r.model))
    else
        r = { id = nextId(Data.props), model = model, x = x, y = y, z = z, h = h }
        r.rx, r.ry = tilt(d)
        local _, folder = findIndex(Data.propFolders, d.folder)
        r.folder = folder and folder.id or nil
        table.insert(Data.props, r)
        AM.addLog(src, 'Prop ajouté', ('#%d %s'):format(r.id, model))
    end
    save('props') broadcast('props')
    AM.notify(src, ('Prop #%d enregistré.'):format(r.id), 'success')
end)

-- Dossiers de props ------------------------------------------
def('editor_folder_save', 'editor_props', function(src, d)
    local name = cleanName(d.name, 40):match('^%s*(.-)%s*$')
    if name == '' then return AM.notify(src, 'Donne un nom au dossier.', 'error') end
    local _, f = findIndex(Data.propFolders, d.id)
    if f then
        local old = f.name
        f.name = name
        AM.addLog(src, 'Dossier de props renommé', ('%s → %s'):format(old, name))
        AM.notify(src, ('Dossier renommé en « %s ».'):format(name), 'success')
    else
        if #Data.propFolders >= 100 then return AM.notify(src, 'Limite de 100 dossiers atteinte.', 'error') end
        f = { id = nextId(Data.propFolders), name = name }
        table.insert(Data.propFolders, f)
        AM.addLog(src, 'Dossier de props créé', name)
        AM.notify(src, ('Dossier « %s » créé.'):format(name), 'success')
    end
    save('propFolders') broadcast('propFolders')
    TriggerClientEvent('adminmenu:editor:folderSaved', src, f.id)
end)

def('editor_folder_delete', 'editor_props', function(src, d)
    local i, f = findIndex(Data.propFolders, d.id)
    if not f then return AM.notify(src, 'Dossier introuvable.', 'error') end
    local withProps = d.withProps == true
    local n = 0
    for k = #Data.props, 1, -1 do
        local r = Data.props[k]
        if r.folder == f.id then
            n = n + 1
            if withProps then table.remove(Data.props, k) else r.folder = nil end
        end
    end
    table.remove(Data.propFolders, i)
    save('propFolders') broadcast('propFolders')
    if n > 0 then save('props') broadcast('props') end
    AM.addLog(src, 'Dossier de props supprimé', ('%s (%d prop(s) %s)'):format(f.name, n, withProps and 'supprimés' or 'gardés sans dossier'))
    AM.notify(src, withProps and ('Dossier « %s » et ses %d prop(s) supprimés.'):format(f.name, n)
        or ('Dossier « %s » supprimé, ses %d prop(s) sont maintenant sans dossier.'):format(f.name, n), 'success')
end)

def('editor_props_folder', 'editor_props', function(src, d)
    local target = tonumber(d.folder) or 0
    local folder
    if target ~= 0 then
        local _, f = findIndex(Data.propFolders, target)
        if not f then return AM.notify(src, 'Dossier introuvable.', 'error') end
        folder = f
    end
    local wanted = {}
    for i, id in ipairs(type(d.ids) == 'table' and d.ids or {}) do
        if i > 500 then break end
        wanted[tonumber(id) or -1] = true
    end
    local n = 0
    for _, r in ipairs(Data.props) do
        if wanted[r.id] then r.folder = folder and folder.id or nil n = n + 1 end
    end
    if n == 0 then return AM.notify(src, 'Aucun prop sélectionné.', 'error') end
    save('props') broadcast('props')
    AM.addLog(src, 'Props rangés', ('%d prop(s) → %s'):format(n, folder and folder.name or 'sans dossier'))
    AM.notify(src, ('%d prop(s) rangé(s) dans « %s ».'):format(n, folder and folder.name or 'Sans dossier'), 'success')
end)

-- PNJ ------------------------------------------------------
-- Rôle d'un PNJ (vendeur / acheteur). Renvoie nil si aucun rôle.
local function cleanNpc(n)
    if type(n) ~= 'table' then return nil end
    local out = {
        payment = (n.payment == 'bank' or n.payment == 'item') and n.payment or 'cash',
        paymentItem = cleanModel(n.paymentItem),
    }
    if out.paymentItem == '' then out.paymentItem = 'black_money' end

    local shop = {}
    for _, it in ipairs(type(n.shop) == 'table' and type(n.shop.items) == 'table' and n.shop.items or {}) do
        local item = cleanModel(it.item)
        if item ~= '' and #shop < 30 then shop[#shop + 1] = { item = item, price = math.floor(num(it.price, 0, 10000000, 0)) } end
    end
    if #shop > 0 then out.shop = { items = shop } end

    local b = type(n.buyer) == 'table' and n.buyer or nil
    if b then
        local items = {}
        for _, it in ipairs(type(b.items) == 'table' and b.items or {}) do
            local item = cleanModel(it.item)
            if item ~= '' and #items < 30 then
                local mn = math.floor(num(it.min, 0, 10000000, 0))
                local mx = math.floor(num(it.max, 0, 10000000, mn))
                if mx < mn then mx = mn end
                items[#items + 1] = { item = item, min = mn, max = mx }
            end
        end
        if #items > 0 then
            out.buyer = {
                items = items,
                maxPerSale = math.floor(num(b.maxPerSale, 1, 1000, 10)),
                cooldown = math.floor(num(b.cooldown, 0, 86400, 60)),
                policeChance = math.floor(num(b.policeChance, 0, 100, 0)),
                minPolice = math.floor(num(b.minPolice, 0, 50, 0)),
            }
        end
    end

    if type(n.hours) == 'table' and n.hours.from ~= nil and n.hours.to ~= nil then
        local f, t = math.floor(num(n.hours.from, 0, 23, 0)), math.floor(num(n.hours.to, 0, 23, 0))
        if f ~= t then out.hours = { from = f, to = t } end
    end

    -- Métiers autorisés à utiliser ce PNJ (vide = tout le monde). S'applique à tous ses rôles.
    local jobsIn = type(n.jobs) == 'table' and n.jobs or (type(n.garage) == 'table' and type(n.garage.jobs) == 'table' and n.garage.jobs) or {}
    local jobs = {}
    for _, j in ipairs(jobsIn) do
        local job = cleanModel(j.job):lower()
        if job ~= '' and #jobs < 20 then jobs[#jobs + 1] = { job = job, grade = math.floor(num(j.grade, 0, 100, 0)) } end
    end
    if #jobs > 0 then out.jobs = jobs end

    -- Garage : véhicules proposés, options. Les points de sortie
    -- ne viennent jamais du client ici (ils se posent un par un, voir editor_garage_spot).
    local g = type(n.garage) == 'table' and n.garage or nil
    if g then
        local G = Config.Garages or {}
        local vehicles = {}
        for _, v in ipairs(type(g.vehicles) == 'table' and g.vehicles or {}) do
            local model = cleanModel(v.model):lower()
            if model ~= '' and #vehicles < (G.maxVehicles or 40) then
                local label = cleanName(v.label, 40)
                vehicles[#vehicles + 1] = { model = model, label = label ~= '' and label or model, price = math.floor(num(v.price, 0, 10000000, 0)) }
            end
        end
        local plate = (tostring(g.plate or ''):upper():gsub('[^%w]', '')):sub(1, 4)
        if #vehicles > 0 then
            out.garage = {
                vehicles = vehicles,
                plate = plate ~= '' and plate or (G.platePrefix or 'GAR'),
                onePerPlayer = bool(g.onePerPlayer, true),
                warp = bool(g.warp, true),
                fuel = math.floor(num(g.fuel, 0, 100, 100)),
                blip = bool(g.blip, false),
                blipSprite = math.floor(num(g.blipSprite, 1, 900, G.blipSprite or 357)),
                blipColor = math.floor(num(g.blipColor, 0, 85, G.blipColor or 3)),
                spots = {},
            }
        end
    end
    -- Boutique de vêtements (ressource elyzea_clothing)
    local cl = type(n.clothing) == 'table' and n.clothing or nil
    if cl then
        local cats = {}
        for _, id in ipairs(type(cl.categories) == 'table' and cl.categories or {}) do
            local c = cleanModel(id)
            if c ~= '' and #cats < 30 then cats[#cats + 1] = c end
        end
        local name = cleanName(cl.name, 40)
        out.clothing = { name = name ~= '' and name or 'Boutique de vêtements', multiplier = math.floor(num(cl.multiplier, 0, 1000, 100)), categories = cats }
    end
    -- Catalogue de la concession en lecture seule (ressource elyzea_concess)
    -- (+ essai routier : durée ici, point de départ posé à part, voir editor_catalog_spot)
    local ca = type(n.catalog) == 'table' and n.catalog or nil
    if ca then
        local name = cleanName(ca.name, 40)
        out.catalog = { name = name ~= '' and name or 'Catalogue des véhicules',
            test = bool(ca.test, false), testDuration = math.floor(num(ca.testDuration, 30, 1800, 120)) }
    end
    -- Garage public Elyzea (ressource elyzea_garage) : les points de sortie se posent à part
    local pg = type(n.pubgarage) == 'table' and n.pubgarage or nil
    if pg then
        local name = cleanName(pg.name, 40)
        out.pubgarage = { name = name ~= '' and name or 'Garage public', blip = bool(pg.blip, true),
            blipSprite = math.floor(num(pg.blipSprite, 1, 900, 357)), blipColor = math.floor(num(pg.blipColor, 0, 85, 3)),
            storeRadius = math.floor(num(pg.storeRadius, 1.5, 15, 4) * 10 + 0.5) / 10, spots = {}, stores = {} }
    end
    if not out.shop and not out.buyer and not out.garage and not out.clothing and not out.catalog and not out.pubgarage then return nil end
    return out
end

def('editor_save_ped', 'editor_peds', function(src, d)
    local i, r = findIndex(Data.peds, d.id)
    local x, y, z, h = coords(d)
    if r then
        if x then r.x, r.y, r.z, r.h = x, y, z, h end
        if d.scenario ~= nil then r.scenario = cleanModel(d.scenario) end
        if d.name ~= nil then r.name = cleanName(d.name) end
        if d.npc ~= nil then
            local oldSpots = r.npc and r.npc.garage and r.npc.garage.spots
            local oldTest = r.npc and r.npc.catalog and r.npc.catalog.testSpot
            local oldPub = r.npc and r.npc.pubgarage and r.npc.pubgarage.spots
            local oldStores = r.npc and r.npc.pubgarage and r.npc.pubgarage.stores
            r.npc = cleanNpc(d.npc)
            if r.npc and r.npc.garage then r.npc.garage.spots = oldSpots or {} end   -- les points de sortie sont gardés
            if r.npc and r.npc.catalog then r.npc.catalog.testSpot = oldTest end     -- le point d'essai aussi
            if r.npc and r.npc.pubgarage then r.npc.pubgarage.spots = oldPub or {} r.npc.pubgarage.stores = oldStores or {} end
        end
        AM.addLog(src, 'PNJ modifié', ('#%d %s'):format(r.id, r.model))
    else
        local model = cleanModel(d.model)
        if model == '' or not x then return AM.notify(src, 'Données de placement invalides.', 'error') end
        r = { id = nextId(Data.peds), model = model, x = x, y = y, z = z, h = h,
              scenario = cleanModel(d.scenario), name = cleanName(d.name), npc = cleanNpc(d.npc) }
        table.insert(Data.peds, r)
        AM.addLog(src, 'PNJ ajouté', ('#%d %s'):format(r.id, model))
    end
    save('peds') broadcast('peds')
    AM.notify(src, ('PNJ #%d enregistré.'):format(r.id), 'success')
end)

-- Zones de récolte -----------------------------------------
local function fieldSettings(d, base)
    base = base or {}
    local f = {
        name      = cleanName(d.name ~= nil and d.name or base.name),
        model     = cleanModel(d.model ~= nil and d.model or base.model),
        item      = cleanModel(d.item ~= nil and d.item or base.item),
        itemLabel = cleanName(d.itemLabel ~= nil and d.itemLabel or base.itemLabel),
        min       = math.floor(num(d.min, 0, 1000, base.min or 1)),
        max       = math.floor(num(d.max, 0, 1000, base.max or 1)),
        duration  = num(d.duration, 1, 60, base.duration or 5),
        regrow    = math.floor(num(d.regrow, 0, 86400, base.regrow or 300)),
        blip      = bool(d.blip, base.blip),
        blipSprite = math.floor(num(d.blipSprite, 1, 900, base.blipSprite or 1)),
    }
    if f.max < f.min then f.max = f.min end
    if f.name == '' then f.name = 'Zone de récolte' end
    if f.itemLabel == '' then f.itemLabel = f.item end
    return f
end

def('editor_create_field', 'editor_harvest', function(src, d)
    local f = fieldSettings(d)
    if f.model == '' or f.item == '' then return AM.notify(src, 'Modèle et objet obligatoires.', 'error') end
    f.id = nextId(Data.fields)
    f.plants = {}
    for _, p in ipairs(type(d.plants) == 'table' and d.plants or {}) do
        local x, y, z, h = coords(p)
        if x and #f.plants < 200 then
            local rx, ry = tilt(p)
            f.plants[#f.plants + 1] = { x = x, y = y, z = z, h = h, rx = rx, ry = ry }
        end
    end
    if #f.plants == 0 then return AM.notify(src, 'Aucun plant n\'a pu être placé ici.', 'error') end
    table.insert(Data.fields, f)
    save('fields') broadcast('fields')
    AM.notify(src, ('Zone « %s » créée avec %d plants.'):format(f.name, #f.plants), 'success')
    AM.addLog(src, 'Zone de récolte créée', ('#%d %s | %s x%d-%d'):format(f.id, f.name, f.item, f.min, f.max))
end)

def('editor_update_field', 'editor_harvest', function(src, d)
    local _, f = findIndex(Data.fields, d.id)
    if not f then return AM.notify(src, 'Zone introuvable.', 'error') end
    local s = fieldSettings(d, f)
    for k, v in pairs(s) do f[k] = v end
    save('fields') broadcast('fields')
    AM.notify(src, ('Zone « %s » mise à jour.'):format(f.name), 'success')
    AM.addLog(src, 'Zone de récolte modifiée', ('#%d %s | %s x%d-%d | repousse %ds'):format(f.id, f.name, f.item, f.min, f.max, f.regrow))
end)

def('editor_save_plant', 'editor_harvest', function(src, d)
    local _, f = findIndex(Data.fields, d.fieldId)
    local x, y, z, h = coords(d)
    if not f or not x then return AM.notify(src, 'Données invalides.', 'error') end
    local idx = tonumber(d.idx)
    if idx and f.plants[idx] then
        local rx, ry = tilt(d)
        f.plants[idx] = { x = x, y = y, z = z, h = h, rx = rx, ry = ry }
    else
        if #f.plants >= 200 then return AM.notify(src, '200 plants maximum par zone.', 'error') end
        local rx, ry = tilt(d)
        f.plants[#f.plants + 1] = { x = x, y = y, z = z, h = h, rx = rx, ry = ry }
    end
    save('fields') broadcast('fields')
    AM.notify(src, ('Plant enregistré (%d dans la zone).'):format(#f.plants), 'success')
end)

def('editor_delete_plant', 'editor_harvest', function(src, d)
    local _, f = findIndex(Data.fields, d.fieldId)
    local idx = tonumber(d.idx)
    if not f or not idx or not f.plants[idx] then return end
    table.remove(f.plants, idx)
    clearFieldDown(f.id)
    save('fields') broadcast('fields') broadcastDown()
    AM.notify(src, ('Plant supprimé (%d restants).'):format(#f.plants), 'success')
end)

-- Ateliers de fabrication ----------------------------------
local function cleanRecipes(list)
    local out = {}
    for _, r in ipairs(type(list) == 'table' and list or {}) do
        if #out >= 30 then break end
        local rec = {
            label = cleanName(r.label),
            output = cleanModel(r.output),
            count = math.floor(num(r.count, 1, 1000, 1)),
            duration = num(r.duration, 1, 300, 5),
            inputs = {},
        }
        for _, inp in ipairs(type(r.inputs) == 'table' and r.inputs or {}) do
            local item = cleanModel(inp.item)
            if item ~= '' and #rec.inputs < 8 then
                rec.inputs[#rec.inputs + 1] = { item = item, count = math.floor(num(inp.count, 1, 1000, 1)) }
            end
        end
        if rec.output ~= '' then
            if rec.label == '' then rec.label = rec.output end
            out[#out + 1] = rec
        end
    end
    return out
end

local function stationSettings(d, base)
    base = base or {}
    local st = {
        name = cleanName(d.name ~= nil and d.name or base.name),
        model = cleanModel(d.model ~= nil and d.model or base.model),
        scenario = cleanModel(d.scenario ~= nil and d.scenario or base.scenario),
        blip = bool(d.blip, base.blip),
        blipSprite = math.floor(num(d.blipSprite, 1, 900, base.blipSprite or 1)),
        recipes = d.recipes ~= nil and cleanRecipes(d.recipes) or base.recipes or {},
    }
    if st.name == '' then st.name = 'Atelier' end
    return st
end

def('editor_save_station', 'editor_crafting', function(src, d)
    local x, y, z, h = coords(d)
    if not x then return AM.notify(src, 'Données de placement invalides.', 'error') end
    local _, st = findIndex(Data.stations, d.id)
    if st then
        st.x, st.y, st.z, st.h = x, y, z, h
        st.rx, st.ry = tilt(d)
        AM.addLog(src, 'Atelier déplacé', ('#%d %s'):format(st.id, st.name))
    else
        st = stationSettings(d)
        if st.model == '' then return AM.notify(src, 'Modèle obligatoire.', 'error') end
        st.id, st.x, st.y, st.z, st.h = nextId(Data.stations), x, y, z, h
        st.rx, st.ry = tilt(d)
        table.insert(Data.stations, st)
        AM.addLog(src, 'Atelier créé', ('#%d %s (%d recettes)'):format(st.id, st.name, #st.recipes))
    end
    save('stations') broadcast('stations')
    AM.notify(src, ('Atelier « %s » enregistré.'):format(st.name), 'success')
end)

def('editor_update_station', 'editor_crafting', function(src, d)
    local _, st = findIndex(Data.stations, d.id)
    if not st then return AM.notify(src, 'Atelier introuvable.', 'error') end
    for k, v in pairs(stationSettings(d, st)) do st[k] = v end
    save('stations') broadcast('stations')
    AM.notify(src, ('Atelier « %s » mis à jour (%d recettes).'):format(st.name, #st.recipes), 'success')
    AM.addLog(src, 'Atelier modifié', ('#%d %s (%d recettes)'):format(st.id, st.name, #st.recipes))
end)

-- Zones de fouille -----------------------------------------
local function cleanLoot(list)
    local out = {}
    for _, l in ipairs(type(list) == 'table' and list or {}) do
        local item = cleanModel(l.item)
        if item ~= '' and #out < 10 then
            local mn = math.floor(num(l.min, 0, 1000, 1))
            local mx = math.floor(num(l.max, 0, 1000, mn))
            if mx < mn then mx = mn end
            out[#out + 1] = { item = item, min = mn, max = mx, chance = math.floor(num(l.chance, 1, 100, 100)) }
        end
    end
    return out
end

local function searchSettings(d, base)
    base = base or {}
    local z = {
        name = cleanName(d.name ~= nil and d.name or base.name),
        model = cleanModel(d.model ~= nil and d.model or base.model),
        requiredItem = cleanModel(d.requiredItem ~= nil and d.requiredItem or base.requiredItem),
        breakChance = math.floor(num(d.breakChance, 0, 100, base.breakChance or 0)),
        duration = num(d.duration, 1, 60, base.duration or 6),
        cooldown = math.floor(num(d.cooldown, 0, 86400, base.cooldown or 600)),
        blip = bool(d.blip, base.blip),
        blipSprite = math.floor(num(d.blipSprite, 1, 900, base.blipSprite or 1)),
        loot = d.loot ~= nil and cleanLoot(d.loot) or base.loot or {},
    }
    if z.name == '' then z.name = 'Zone de fouille' end
    return z
end

def('editor_create_search', 'editor_harvest', function(src, d)
    local z = searchSettings(d)
    if z.model == '' then return AM.notify(src, 'Modèle obligatoire.', 'error') end
    if #z.loot == 0 then return AM.notify(src, 'Ajoute au moins un objet à trouver.', 'error') end
    z.id = nextId(Data.searches)
    z.points = {}
    table.insert(Data.searches, z)
    save('searches') broadcast('searches')
    AM.addLog(src, 'Zone de fouille créée', ('#%d %s'):format(z.id, z.name))
    TriggerClientEvent('adminmenu:editor:placePoints', src, z.id)
end)

def('editor_update_search', 'editor_harvest', function(src, d)
    local _, z = findIndex(Data.searches, d.id)
    if not z then return AM.notify(src, 'Zone introuvable.', 'error') end
    for k, v in pairs(searchSettings(d, z)) do z[k] = v end
    save('searches') broadcast('searches')
    AM.notify(src, ('Zone « %s » mise à jour.'):format(z.name), 'success')
    AM.addLog(src, 'Zone de fouille modifiée', ('#%d %s'):format(z.id, z.name))
end)

def('editor_save_searchpoint', 'editor_harvest', function(src, d)
    local _, z = findIndex(Data.searches, d.searchId)
    local x, y, zz, h = coords(d)
    if not z or not x then return AM.notify(src, 'Données invalides.', 'error') end
    local idx = tonumber(d.idx)
    if idx and z.points[idx] then
        local rx, ry = tilt(d)
        z.points[idx] = { x = x, y = y, z = zz, h = h, rx = rx, ry = ry }
    else
        if #z.points >= 100 then return AM.notify(src, '100 points maximum par zone.', 'error') end
        local rx, ry = tilt(d)
        z.points[#z.points + 1] = { x = x, y = y, z = zz, h = h, rx = rx, ry = ry }
    end
    save('searches') broadcast('searches')
    AM.notify(src, ('Point enregistré (%d dans « %s »).'):format(#z.points, z.name), 'success')
end)

local function clearLooted(id)
    local prefix = tostring(id) .. ':'
    for k in pairs(Looted) do if k:sub(1, #prefix) == prefix then Looted[k] = nil end end
end

local function lootedMap()
    local m = {}
    for k in pairs(Looted) do m[k] = true end
    return m
end
broadcastLooted = function(target)
    TriggerClientEvent('adminmenu:search:looted', target or -1, lootedMap())
end

def('editor_delete_searchpoint', 'editor_harvest', function(src, d)
    local _, z = findIndex(Data.searches, d.searchId)
    local idx = tonumber(d.idx)
    if not z or not idx or not z.points[idx] then return end
    table.remove(z.points, idx)
    clearLooted(z.id)
    save('searches') broadcast('searches') broadcastLooted()
    AM.notify(src, ('Point supprimé (%d restants).'):format(#z.points), 'success')
end)

-- Objets de la map retirés (masqués pour tout le monde) -----
def('editor_hide_object', 'editor_props', function(src, d)
    local model = math.floor(tonumber(d.model) or 0)
    local x, y, z = coords(d)
    if model == 0 or not x then return AM.notify(src, 'Objet invalide.', 'error') end
    for _, h in ipairs(Data.hidden) do
        if h.model == model and math.abs(h.x - x) < 1.0 and math.abs(h.y - y) < 1.0 and math.abs(h.z - z) < 2.0 then
            return AM.notify(src, 'Cet objet est déjà retiré.', 'info')
        end
    end
    local id = nextId(Data.hidden)
    table.insert(Data.hidden, { id = id, model = model, x = x, y = y, z = z, radius = 1.5, label = ('Objet #%d'):format(id) })
    save('hidden') broadcast('hidden')
    AM.notify(src, 'Objet retiré de la map pour tout le monde.', 'success')
    AM.addLog(src, 'Objet de la map retiré', ('#%d modèle %d (%.1f, %.1f, %.1f)'):format(id, model, x, y, z))
end)

def('editor_rename_hidden', 'editor_props', function(src, d)
    local _, h = findIndex(Data.hidden, d.id)
    local name = cleanName(d.name)
    if not h or name == '' then return end
    h.label = name
    save('hidden') broadcast('hidden')
end)

-- Zones -----------------------------------------------------
local ZONE_COLORS = {}
for _, c in ipairs(Config.Zones.colors) do ZONE_COLORS[c.id] = true end

local function zoneSettings(d, base)
    base = base or {}
    local z = {
        name     = cleanName(d.name ~= nil and d.name or base.name),
        enterMsg = (tostring(d.enterMsg ~= nil and d.enterMsg or base.enterMsg or ''):gsub('[%c<>]', '')):sub(1, 140),
        exitMsg  = (tostring(d.exitMsg ~= nil and d.exitMsg or base.exitMsg or ''):gsub('[%c<>]', '')):sub(1, 140),
        color    = ZONE_COLORS[d.color] and d.color or (base.color or 'green'),
        safe        = bool(d.safe, base.safe),          -- zone sécurisée
        noWeapons   = bool(d.noWeapons, base.noWeapons), -- armes et coups bloqués
        invincible  = bool(d.invincible, base.invincible),
        exemptPolice = bool(d.exemptPolice, base.exemptPolice),
        speedLimit  = math.floor(num(d.speedLimit, 0, 300, base.speedLimit or 0)), -- km/h, 0 = aucune
        blip        = bool(d.blip, base.blip),
        showBorder  = bool(d.showBorder, base.showBorder),
        -- Icône sur la carte : n° de blip GTA (0 = automatique : bouclier si safe zone, sinon point)
        blipSprite  = math.floor(num(d.blipSprite, 0, 2000, base.blipSprite or 0)),
        blipScale   = num(d.blipScale, 0.4, 1.6, base.blipScale or 0.8),
    }
    if z.name == '' then z.name = 'Zone' end
    return z
end

local function zoneShape(src, d, z)
    if d.shape == 'circle' then
        local c = GetEntityCoords(GetPlayerPed(src))
        local r = num(d.radius, 3, 1500, 50)
        z.shape, z.points = 'circle', nil
        z.center = { x = round(c.x), y = round(c.y) }
        z.radius = round(r)
        z.minZ, z.maxZ = round(c.z - Config.Zones.depth), round(c.z + Config.Zones.height)
        return true
    end
    local pts, minZ, maxZ = {}, math.huge, -math.huge
    for _, p in ipairs(type(d.points) == 'table' and d.points or {}) do
        local x, y, zz = tonumber(p.x), tonumber(p.y), tonumber(p.z)
        if x and y and zz and #pts < 60 then
            pts[#pts + 1] = { x = round(x), y = round(y) }
            if zz < minZ then minZ = zz end
            if zz > maxZ then maxZ = zz end
        end
    end
    if #pts < 3 then return false end
    z.shape, z.points, z.center, z.radius = 'poly', pts, nil, nil
    z.minZ, z.maxZ = round(minZ - Config.Zones.depth), round(maxZ + Config.Zones.height)
    return true
end

def('editor_save_zone', 'editor_zones', function(src, d)
    local _, z = findIndex(Data.zones, d.id)
    if z then
        if d.shape then
            if not zoneShape(src, d, z) then return AM.notify(src, 'Il faut au moins 3 coins pour une zone.', 'error') end
        end
        if d.settings then for k, v in pairs(zoneSettings(d.settings, z)) do z[k] = v end end
        AM.addLog(src, 'Zone modifiée', ('#%d %s'):format(z.id, z.name))
    else
        z = zoneSettings(d.settings or {})
        if not zoneShape(src, d, z) then return AM.notify(src, 'Il faut au moins 3 coins pour une zone.', 'error') end
        z.id = nextId(Data.zones)
        table.insert(Data.zones, z)
        AM.addLog(src, 'Zone créée', ('#%d %s (%s)'):format(z.id, z.name, z.shape == 'circle' and 'cercle' or (#z.points .. ' coins')))
    end
    save('zones') broadcast('zones')
    AM.notify(src, ('Zone « %s » enregistrée.'):format(z.name), 'success')
end)

-- Portes ----------------------------------------------------
local function doorOf(id) local _, d = findIndex(Data.doors, id) return d end

def('editor_add_door', 'editor_doors', function(src, d)
    local leaves = {}
    for _, l in ipairs(type(d.leaves) == 'table' and d.leaves or {}) do
        local x, y, z = coords(l)
        local m = math.floor(tonumber(l.model) or 0)
        if x and m ~= 0 and #leaves < 2 then leaves[#leaves + 1] = { model = m, x = x, y = y, z = z } end
    end
    if #leaves == 0 then return AM.notify(src, 'Aucune porte sélectionnée.', 'error') end
    local id = nextId(Data.doors)
    local name = cleanName(d.name)
    if name == '' then name = (#leaves == 2 and 'Porte double #%d' or 'Porte #%d'):format(id) end
    table.insert(Data.doors, { id = id, name = name, leaves = leaves, locked = true, owners = {} })
    save('doors') broadcast('doors')
    AM.notify(src, ('« %s » ajoutée et verrouillée. Attribue-la à un joueur dans le menu.'):format(name), 'success')
    AM.addLog(src, 'Porte ajoutée', ('#%d %s'):format(id, name))
end)

def('editor_door_toggle', 'editor_doors', function(src, d)
    local door = doorOf(d.id)
    if not door then return end
    door.locked = not door.locked
    save('doors') broadcast('doors')
    AM.notify(src, ('« %s » %s.'):format(door.name, door.locked and 'verrouillée' or 'déverrouillée'), 'success')
end)

-- Distance à laquelle on peut ouvrir cette porte (mètres)
def('editor_door_distance', 'editor_doors', function(src, d)
    local door = doorOf(d.id)
    if not door then return end
    local DC = Config.Doors
    local v = tonumber(d.distance)
    if not v then return AM.notify(src, 'Distance invalide.', 'error') end
    door.distance = math.floor(math.max(DC.minDistance or 0.8, math.min(DC.maxDistance or 15.0, v)) * 10 + 0.5) / 10
    save('doors') broadcast('doors')
    AM.notify(src, ('« %s » s\'ouvre maintenant à %.1f m.'):format(door.name, door.distance), 'success')
    AM.addLog(src, 'Porte : distance d\'ouverture', ('#%d %s · %.1f m'):format(door.id, door.name, door.distance))
end)

def('editor_door_rename', 'editor_doors', function(src, d)
    local door = doorOf(d.id)
    local name = cleanName(d.name)
    if not door or name == '' then return end
    door.name = name
    save('doors') broadcast('doors')
end)

def('editor_door_add_owner', 'editor_doors', function(src, d)
    local door = doorOf(d.id)
    local t = tonumber(d.target)
    if not door then return end
    if not t or not GetPlayerName(t) then return AM.notify(src, 'Joueur introuvable (il doit être connecté).', 'error') end
    local cid = Bridge.GetCharId(t)
    if not cid then return AM.notify(src, 'Personnage non chargé.', 'error') end
    for _, o in ipairs(door.owners) do if o.id == cid then return AM.notify(src, 'Ce joueur a déjà accès à cette porte.', 'info') end end
    local name = Bridge.GetCharName(t)
    table.insert(door.owners, { id = cid, name = name })
    save('doors') broadcast('doors')
    AM.notify(src, ('%s a maintenant les clés de « %s ».'):format(name, door.name), 'success')
    AM.notify(t, ('Tu as reçu les clés de « %s ».'):format(door.name), 'success')
    AM.addLog(src, 'Clés de porte données', ('%s → %s'):format(door.name, name))
end)

def('editor_door_remove_owner', 'editor_doors', function(src, d)
    local door = doorOf(d.id)
    if not door then return end
    for i, o in ipairs(door.owners) do
        if o.id == d.owner then
            table.remove(door.owners, i)
            save('doors') broadcast('doors')
            AM.notify(src, ('%s n\'a plus les clés de « %s ».'):format(o.name, door.name), 'success')
            AM.addLog(src, 'Clés de porte retirées', ('%s → %s'):format(door.name, o.name))
            return
        end
    end
end)

def('editor_door_reset_code', 'editor_doors', function(src, d)
    local door = doorOf(d.id)
    if not door then return end
    door.codeHash = nil
    save('doors') broadcast('doors')
    AM.notify(src, ('Code de « %s » supprimé.'):format(door.name), 'success')
end)

-- Suppression générique ------------------------------------
local KIND = {
    spawn = { list = 'spawns', perm = 'editor_spawns', label = 'Point de spawn' },
    prop  = { list = 'props',  perm = 'editor_props',  label = 'Prop' },
    ped   = { list = 'peds',   perm = 'editor_peds',   label = 'PNJ' },
    field = { list = 'fields', perm = 'editor_harvest', label = 'Zone de récolte' },
    station = { list = 'stations', perm = 'editor_crafting', label = 'Atelier' },
    search = { list = 'searches', perm = 'editor_harvest', label = 'Zone de fouille' },
    hidden = { list = 'hidden', perm = 'editor_props', label = 'Objet de la map (restauré)' },
    zone = { list = 'zones', perm = 'editor_zones', label = 'Zone' },
    door = { list = 'doors', perm = 'editor_doors', label = 'Porte' },
    stash = { list = 'stashes', perm = 'editor_stashes', label = 'Coffre' },
}

-- Accessible avec n'importe quel droit éditeur, puis vérifié selon le type supprimé
A.editor_delete = {
    permAny = { 'editor_spawns', 'editor_props', 'editor_peds', 'editor_harvest', 'editor_crafting', 'editor_zones', 'editor_doors', 'editor_stashes' },
    minLevel = MIN, noRefresh = true,
    fn = function(src, d)
        local k = KIND[d.kind]
        if not k then return end
        if not AM.hasPerm(src, k.perm) then return AM.notify(src, 'Permission refusée.', 'error') end
        local i, r = findIndex(Data[k.list], d.id)
        if not i then return AM.notify(src, 'Élément introuvable.', 'error') end
        table.remove(Data[k.list], i)
        if d.kind == 'field' then clearFieldDown(r.id) broadcastDown() end
        if d.kind == 'search' then clearLooted(r.id) broadcastLooted() end
        save(k.list) broadcast(k.list)
        AM.notify(src, d.kind == 'hidden' and 'Objet remis sur la map.' or ('%s #%d supprimé.'):format(k.label, r.id), 'success')
        AM.addLog(src, k.label .. ' supprimé', ('#%d %s'):format(r.id, r.name or r.model or ''))
    end,
}

-- ---------------------------------------------------------
--  Récolte
-- ---------------------------------------------------------
local function plantOf(fid, idx)
    local _, f = findIndex(Data.fields, fid)
    if not f then return nil end
    local p = f.plants[tonumber(idx)]
    if not p then return nil end
    return f, p
end

local function near(src, p, max)
    local c = GetEntityCoords(GetPlayerPed(src))
    return #(c - vector3(p.x, p.y, p.z)) <= max
end

RegisterNetEvent('adminmenu:harvest:start', function(fid, idx)
    local src = source
    if not AM.rateLimit(src, 'adminmenu:harvest:start', 5, 1000) then return end
    local f, p = plantOf(fid, idx)
    if not f then return end
    local key = ('%d:%d'):format(f.id, tonumber(idx))
    if Down[key] then return AM.notify(src, "Ce plant n'a pas encore repoussé.", 'error') end
    for s, h in pairs(Harvesting) do
        if h.key == key and s ~= src then return AM.notify(src, "Quelqu'un récolte déjà ce plant.", 'error') end
    end
    if not near(src, p, 3.5) then return end
    Harvesting[src] = { key = key, fid = f.id, idx = tonumber(idx), started = GetGameTimer(), duration = f.duration * 1000 }
    TriggerClientEvent('adminmenu:harvest:begin', src, f.id, tonumber(idx), f.duration, f.itemLabel)
end)

RegisterNetEvent('adminmenu:harvest:cancel', function() Harvesting[source] = nil end)

RegisterNetEvent('adminmenu:harvest:finish', function()
    local src = source
    local h = Harvesting[src]
    Harvesting[src] = nil
    if not h then return end
    if GetGameTimer() - h.started < h.duration - 500 then return end -- trop rapide : triche
    local f, p = plantOf(h.fid, h.idx)
    if not f or Down[h.key] or not near(src, p, 3.5) then return end

    local amount = math.random(f.min, f.max)
    if amount <= 0 then
        AM.notify(src, 'Rien à récolter cette fois.', 'info')
    else
        local ok, err = Bridge.AddItem(src, f.item, amount)
        if not ok then return AM.notify(src, Bridge.Errors[err] or 'Impossible de récupérer la récolte.', 'error') end
        AM.notify(src, ('+%d %s'):format(amount, f.itemLabel), 'success')
    end

    if f.regrow > 0 then
        Down[h.key] = GetGameTimer() + f.regrow * 1000
        broadcastDown()
    end
end)

AddEventHandler('playerDropped', function() Harvesting[source] = nil end)

-- Repousse des plants et réapprovisionnement des fouilles
CreateThread(function()
    while true do
        Wait(5000)
        local now, changed, changed2 = GetGameTimer(), false, false
        for k, t in pairs(Down) do
            if t <= now then Down[k] = nil changed = true end
        end
        for k, t in pairs(Looted) do
            if t <= now then Looted[k] = nil changed2 = true end
        end
        if changed then broadcastDown() end
        if changed2 then broadcastLooted() end
    end
end)

-- ---------------------------------------------------------
--  Fouille (tous les joueurs)
-- ---------------------------------------------------------
local function pointOf(sid, idx)
    local _, z = findIndex(Data.searches, sid)
    if not z then return nil end
    local p = z.points[tonumber(idx)]
    if not p then return nil end
    return z, p
end

RegisterNetEvent('adminmenu:search:start', function(sid, idx)
    local src = source
    if not AM.rateLimit(src, 'adminmenu:search:start', 5, 1000) then return end
    local z, p = pointOf(sid, idx)
    if not z then return end
    local key = ('%d:%d'):format(z.id, tonumber(idx))
    if Looted[key] then return AM.notify(src, 'Déjà fouillé. Reviens plus tard.', 'error') end
    for s2, h in pairs(Searching) do
        if h.key == key and s2 ~= src then return AM.notify(src, "Quelqu'un fouille déjà ici.", 'error') end
    end
    if not near(src, p, 3.5) then return end
    if z.requiredItem ~= '' and Bridge.GetItemCount(src, z.requiredItem) < 1 then
        return AM.notify(src, ('Il te faut : %s.'):format(Bridge.GetLabel(z.requiredItem)), 'error')
    end
    Searching[src] = { key = key, sid = z.id, idx = tonumber(idx), started = GetGameTimer(), duration = z.duration * 1000 }
    TriggerClientEvent('adminmenu:search:begin', src, z.id, tonumber(idx), z.duration, z.name)
end)

RegisterNetEvent('adminmenu:search:cancel', function() Searching[source] = nil end)

RegisterNetEvent('adminmenu:search:finish', function()
    local src = source
    local h = Searching[src]
    Searching[src] = nil
    if not h or GetGameTimer() - h.started < h.duration - 500 then return end
    local z, p = pointOf(h.sid, h.idx)
    if not z or Looted[h.key] or not near(src, p, 3.5) then return end
    if z.requiredItem ~= '' and Bridge.GetItemCount(src, z.requiredItem) < 1 then return end

    local found, full = {}, false
    for _, l in ipairs(z.loot) do
        if math.random(100) <= l.chance then
            local n = math.random(l.min, l.max)
            if n > 0 then
                local ok, err = Bridge.AddItem(src, l.item, n)
                if ok then
                    found[#found + 1] = ('%d %s'):format(n, Bridge.GetLabel(l.item))
                elseif err == 'full' then
                    full = true
                else
                    AM.notify(src, Bridge.Errors[err] or 'Erreur d\'inventaire.', 'error')
                end
            end
        end
    end

    if #found > 0 then
        AM.notify(src, 'Trouvé : ' .. table.concat(found, ', '), 'success')
    elseif full then
        return AM.notify(src, Bridge.Errors.full, 'error') -- le point reste disponible
    else
        AM.notify(src, "Tu n'as rien trouvé d'intéressant.", 'info')
    end
    if full and #found > 0 then AM.notify(src, 'Inventaire plein : une partie est restée sur place.', 'warning') end

    if z.requiredItem ~= '' and z.breakChance > 0 and math.random(100) <= z.breakChance then
        if Bridge.RemoveItem(src, z.requiredItem, 1) then
            AM.notify(src, ('Ton outil s\'est cassé : %s.'):format(Bridge.GetLabel(z.requiredItem)), 'warning')
        end
    end

    if z.cooldown > 0 then
        Looted[h.key] = GetGameTimer() + z.cooldown * 1000
        broadcastLooted()
    end
end)

-- ---------------------------------------------------------
--  Fabrication (tous les joueurs)
-- ---------------------------------------------------------
local function stationOf(sid)
    local _, st = findIndex(Data.stations, sid)
    return st
end

RegisterNetEvent('adminmenu:craft:open', function(sid)
    local src = source
    if not AM.rateLimit(src, 'adminmenu:craft:open', 3, 1000) then return end
    local st = stationOf(sid)
    if not st or not near(src, st, 3.5) then return end
    local list = {}
    for i, r in ipairs(st.recipes) do
        local inputs = {}
        for _, inp in ipairs(r.inputs) do
            inputs[#inputs + 1] = { item = inp.item, count = inp.count, label = Bridge.GetLabel(inp.item), have = Bridge.GetItemCount(src, inp.item) }
        end
        list[#list + 1] = { idx = i, label = r.label, output = r.output, outputLabel = Bridge.GetLabel(r.output),
                            count = r.count, duration = r.duration, inputs = inputs }
    end
    TriggerClientEvent('adminmenu:craft:menu', src, { stationId = st.id, name = st.name, recipes = list })
end)

RegisterNetEvent('adminmenu:craft:start', function(sid, idx, times)
    local src = source
    if not AM.rateLimit(src, 'adminmenu:craft:start', 3, 1000) then return end
    local st = stationOf(sid)
    if not st or not near(src, st, 3.5) then return end
    local r = st.recipes[tonumber(idx)]
    if not r then return end
    times = math.floor(num(times, 1, 10, 1))
    for _, inp in ipairs(r.inputs) do
        if Bridge.GetItemCount(src, inp.item) < inp.count * times then
            return AM.notify(src, ('Il te manque : %s.'):format(Bridge.GetLabel(inp.item)), 'error')
        end
    end
    Crafting[src] = { sid = st.id, idx = tonumber(idx), times = times, started = GetGameTimer(), duration = r.duration * times * 1000 }
    TriggerClientEvent('adminmenu:craft:begin', src, st.id, r.duration * times, ('%s x%d'):format(r.label, r.count * times), st.scenario)
end)

RegisterNetEvent('adminmenu:craft:cancel', function() Crafting[source] = nil end)

RegisterNetEvent('adminmenu:craft:finish', function()
    local src = source
    local c = Crafting[src]
    Crafting[src] = nil
    if not c or GetGameTimer() - c.started < c.duration - 500 then return end
    local st = stationOf(c.sid)
    if not st or not near(src, st, 3.5) then return end
    local r = st.recipes[c.idx]
    if not r then return end

    -- Vérification finale puis retrait des ingrédients
    for _, inp in ipairs(r.inputs) do
        if Bridge.GetItemCount(src, inp.item) < inp.count * c.times then
            return AM.notify(src, ('Il te manque : %s.'):format(Bridge.GetLabel(inp.item)), 'error')
        end
    end
    local removed = {}
    for _, inp in ipairs(r.inputs) do
        if not Bridge.RemoveItem(src, inp.item, inp.count * c.times) then
            for _, back in ipairs(removed) do Bridge.AddItem(src, back.item, back.count) end
            return AM.notify(src, 'Impossible de retirer les ingrédients.', 'error')
        end
        removed[#removed + 1] = { item = inp.item, count = inp.count * c.times }
    end

    local ok, err = Bridge.AddItem(src, r.output, r.count * c.times)
    if not ok then
        for _, back in ipairs(removed) do Bridge.AddItem(src, back.item, back.count) end
        return AM.notify(src, (Bridge.Errors[err] or 'Fabrication impossible.') .. ' Ingrédients rendus.', 'error')
    end
    AM.notify(src, ('+%d %s'):format(r.count * c.times, Bridge.GetLabel(r.output)), 'success')
end)

AddEventHandler('playerDropped', function() Crafting[source] = nil Searching[source] = nil end)

-- ---------------------------------------------------------
--  PNJ vendeurs / acheteurs (tous les joueurs)
-- ---------------------------------------------------------
local NpcCooldown = {}   -- ["source:idPNJ"] = GetGameTimer() de fin

local function pedOf(id)
    local _, r = findIndex(Data.peds, id)
    return r
end

local function isOpen(n)
    if not n.hours then return true end
    local h = AM.World.hour
    if n.hours.from < n.hours.to then return h >= n.hours.from and h < n.hours.to end
    return h >= n.hours.from or h < n.hours.to
end

local function policeOnline()
    local list = {}
    for _, p in ipairs(GetPlayers()) do
        local id = tonumber(p)
        if Bridge.IsPolice(id) then list[#list + 1] = id end
    end
    return list
end

local function payLabel(n)
    if n.payment == 'bank' then return 'Banque' end
    if n.payment == 'item' then return Bridge.GetLabel(n.paymentItem) end
    return 'Liquide'
end

local function sendNpcMenu(src, r)
    local n = r.npc
    local key = src .. ':' .. r.id
    local cd = NpcCooldown[key] and math.max(0, math.ceil((NpcCooldown[key] - GetGameTimer()) / 1000)) or 0
    local data = {
        id = r.id, name = (r.name ~= '' and r.name) or 'Inconnu',
        payment = payLabel(n), money = Bridge.GetMoney(src, n.payment, n.paymentItem),
        shop = {}, buyer = {}, cooldown = cd,
        maxPerSale = n.buyer and n.buyer.maxPerSale or 0,
    }
    for i, it in ipairs(n.shop and n.shop.items or {}) do
        data.shop[#data.shop + 1] = { idx = i, label = Bridge.GetLabel(it.item), price = it.price }
    end
    for i, it in ipairs(n.buyer and n.buyer.items or {}) do
        data.buyer[#data.buyer + 1] = { idx = i, label = Bridge.GetLabel(it.item), min = it.min, max = it.max, have = Bridge.GetItemCount(src, it.item) }
    end
    if n.garage and GarageMenuData then data.garage = GarageMenuData(src, r) end
    TriggerClientEvent('adminmenu:npc:menu', src, data)
end

local function npcJobs(n) return (n.jobs and #n.jobs > 0 and n.jobs) or (n.garage and n.garage.jobs) or nil end
function NpcAccess(src, n)
    local jobs = npcJobs(n)
    if not jobs or #jobs == 0 then return true end
    local job, grade = Bridge.GetJob(src)
    for _, j in ipairs(jobs) do
        if job == j.job and (grade or 0) >= (j.grade or 0) then return true end
    end
    return false
end
function NpcJobsText(n)
    local t = {}
    for _, j in ipairs(npcJobs(n) or {}) do
        local label = j.job
        for _, x in ipairs(Bridge.GetJobs()) do if x.name == j.job then label = x.label end end
        t[#t + 1] = (j.grade or 0) > 0 and ('%s (grade %d et plus)'):format(label, j.grade) or label
    end
    return table.concat(t, ', ')
end

local function checkNpc(src, id)
    local r = pedOf(id)
    if not r or not r.npc or not near(src, r, 4.0) then return nil end
    if not NpcAccess(src, r.npc) then
        AM.notify(src, ('Il ne parle qu\'aux membres de : %s.'):format(NpcJobsText(r.npc)), 'error')
        return nil
    end
    if not isOpen(r.npc) then
        AM.notify(src, ('Il n\'est pas là à cette heure-ci. Reviens entre %dh et %dh.'):format(r.npc.hours.from, r.npc.hours.to), 'error')
        return nil
    end
    return r
end

-- Garage public : le PNJ ouvre l'interface Elyzea Public Garage (garages connectés)
RegisterNetEvent('adminmenu:pubgarage:open', function(id)
    local src = source
    if not AM.rateLimit(src, 'npc', 4, 1000) then return end
    local r = checkNpc(src, tonumber(id))
    if not r or not r.npc.pubgarage then return end
    if GetResourceState('elyzea_garage') ~= 'started' then
        return AM.notify(src, 'Le garage est fermé (ressource elyzea_garage non démarrée).', 'error')
    end
    local pg = r.npc.pubgarage
    exports.elyzea_garage:OpenFor(src, { name = pg.name, spots = pg.spots or {}, npc = { x = r.x, y = r.y, z = r.z } })
end)

-- Catalogue de la concession : le PNJ montre les véhicules en vente (sans achat)
RegisterNetEvent('adminmenu:catalog:open', function(id)
    local src = source
    if not AM.rateLimit(src, 'npc', 4, 1000) then return end
    local r = checkNpc(src, tonumber(id))
    if not r or not r.npc.catalog then return end
    local res = (Config.Concess and Config.Concess.resource) or 'elyzea_concess'
    if GetResourceState(res) ~= 'started' then
        return AM.notify(src, 'Le catalogue est indisponible (concession non démarrée).', 'error')
    end
    local ca = r.npc.catalog
    exports[res]:ViewCatalog(src, ca.name, {
        test = ca.test == true and ca.testSpot ~= nil, duration = ca.testDuration or 120, spot = ca.testSpot,
        npc = { x = r.x, y = r.y, z = r.z }, pedId = r.id,
    })
end)

-- Boutique de vêtements : le PNJ ouvre la boutique de la ressource elyzea_clothing
RegisterNetEvent('adminmenu:clothing:open', function(id)
    local src = source
    if not AM.rateLimit(src, 'npc', 4, 1000) then return end
    local r = checkNpc(src, tonumber(id))
    if not r or not r.npc.clothing then return end
    if GetResourceState('elyzea_clothing') ~= 'started' then
        return AM.notify(src, 'La boutique est fermée (ressource elyzea_clothing non démarrée).', 'error')
    end
    local cl = r.npc.clothing
    exports.elyzea_clothing:OpenFor(src, { name = cl.name, multiplier = cl.multiplier, categories = cl.categories, coords = { x = r.x, y = r.y, z = r.z } })
end)

RegisterNetEvent('adminmenu:npc:open', function(id)
    local src = source
    if not AM.rateLimit(src, 'npc', 4, 1000) then return end
    local r = checkNpc(src, tonumber(id))
    if r then sendNpcMenu(src, r) end
end)

RegisterNetEvent('adminmenu:npc:buy', function(id, idx, qty)
    local src = source
    if not AM.rateLimit(src, 'npc', 4, 1000) then return end
    local r = checkNpc(src, tonumber(id))
    if not r or not r.npc.shop then return end
    local it = r.npc.shop.items[tonumber(idx)]
    qty = math.floor(num(qty, 1, 100, 1))
    if not it then return end
    local n, total = r.npc, it.price * qty
    if Bridge.GetMoney(src, n.payment, n.paymentItem) < total then
        AM.notify(src, ('Pas assez d\'argent (%s $ demandés).'):format(total), 'error')
        return sendNpcMenu(src, r)
    end
    if not Bridge.RemoveMoney(src, n.payment, n.paymentItem, total, 'achat-pnj') then
        AM.notify(src, 'Paiement refusé.', 'error')
        return sendNpcMenu(src, r)
    end
    local ok, err = Bridge.AddItem(src, it.item, qty)
    if not ok then
        Bridge.AddMoney(src, n.payment, n.paymentItem, total, 'remboursement-pnj')
        AM.notify(src, (Bridge.Errors[err] or 'Achat impossible.') .. ' Tu as été remboursé.', 'error')
    else
        AM.notify(src, ('Acheté : %d %s pour %s $.'):format(qty, Bridge.GetLabel(it.item), total), 'success')
    end
    sendNpcMenu(src, r)
end)

RegisterNetEvent('adminmenu:npc:sell', function(id, idx, qty)
    local src = source
    if not AM.rateLimit(src, 'npc', 4, 1000) then return end
    local r = checkNpc(src, tonumber(id))
    if not r or not r.npc.buyer then return end
    local b = r.npc.buyer
    local it = b.items[tonumber(idx)]
    if not it then return end
    qty = math.floor(num(qty, 1, b.maxPerSale, 1))

    local key = src .. ':' .. r.id
    if NpcCooldown[key] and NpcCooldown[key] > GetGameTimer() then
        AM.notify(src, 'Il ne veut plus rien pour le moment. Reviens plus tard.', 'error')
        return sendNpcMenu(src, r)
    end
    local cops = policeOnline()
    if #cops < b.minPolice then
        AM.notify(src, 'Il sent que le coin est trop calme… il n\'achète pas maintenant.', 'error')
        return sendNpcMenu(src, r)
    end
    if Bridge.GetItemCount(src, it.item) < qty then
        AM.notify(src, 'Tu n\'en as pas assez sur toi.', 'error')
        return sendNpcMenu(src, r)
    end
    if not Bridge.RemoveItem(src, it.item, qty) then return sendNpcMenu(src, r) end

    local total = 0
    for _ = 1, qty do total = total + math.random(it.min, it.max) end
    if not Bridge.AddMoney(src, r.npc.payment, r.npc.paymentItem, total, 'vente-pnj') then
        Bridge.AddItem(src, it.item, qty)
        AM.notify(src, 'Paiement impossible, la marchandise t\'a été rendue.', 'error')
        return sendNpcMenu(src, r)
    end
    AM.notify(src, ('Vendu : %d %s pour %s $.'):format(qty, Bridge.GetLabel(it.item), total), 'success')
    if b.cooldown > 0 then NpcCooldown[key] = GetGameTimer() + b.cooldown * 1000 end

    -- Alerte police
    if b.policeChance > 0 and #cops > 0 and math.random(100) <= b.policeChance then
        local policeRes = (Config.Police and Config.Police.resource) or 'elyzea_police'
        local sent = GetResourceState(policeRes) == 'started' and pcall(function()
            exports[policeRes]:SendDispatch({ coords = { x = r.x, y = r.y, z = r.z }, title = 'Transaction suspecte',
                message = 'Une transaction suspecte a été signalée.', code = '10-31', priority = 2 })
        end)
        if not sent then
            for _, cop in ipairs(cops) do
                TriggerClientEvent('adminmenu:police:alert', cop, { x = r.x, y = r.y, z = r.z }, 'Transaction suspecte signalée')
            end
        end
    end
    sendNpcMenu(src, r)
end)

AddEventHandler('playerDropped', function()
    local prefix = source .. ':'
    for k in pairs(NpcCooldown) do if k:sub(1, #prefix) == prefix then NpcCooldown[k] = nil end end
end)

-- ---------------------------------------------------------
--  GARAGES SUR PNJ
--  Le staff pose les points de sortie (éditeur, comme un prop) ;
--  le joueur parle au PNJ, choisit un véhicule : il apparaît sur le
--  premier point de sortie libre, créé PAR LE SERVEUR.
-- ---------------------------------------------------------
local G = Config.Garages or {}
local GarageOut = {}   -- [netId] = { src, ped, plate, label }
local VTYPES = { automobile = true, bike = true, boat = true, heli = true, plane = true, submarine = true, trailer = true, train = true }

local function garagePed(id)
    local r = pedOf(tonumber(id))
    if r and r.npc and r.npc.garage then return r, r.npc.garage end
end

-- Qui peut utiliser ce garage : réglage « Qui peut l'utiliser » du PNJ
local function garageAccess(src, g, n) return NpcAccess(src, n or { garage = g }) end
local function jobsText(g, n) return NpcJobsText(n or { garage = g }) end

-- Véhicule déjà sorti par ce joueur depuis ce garage (et toujours dans le monde)
local function outOf(src, pedId)
    for netId, o in pairs(GarageOut) do
        if o.src == src and o.ped == pedId then
            local veh = NetworkGetEntityFromNetworkId(netId)
            if veh ~= 0 and DoesEntityExist(veh) then return netId, o, veh end
            GarageOut[netId] = nil
        end
    end
end

local function nearGarage(coords, r, g)
    local radius = G.storeRadius or 25.0
    if #(coords - vector3(r.x, r.y, r.z)) <= radius then return true end
    for _, s in ipairs(g.spots or {}) do
        if #(coords - vector3(s.x, s.y, s.z)) <= radius then return true end
    end
    return false
end

local function freeSpot(g)
    local vehicles = GetAllVehicles()
    local clear = G.spotClearRadius or 3.0
    for i, s in ipairs(g.spots or {}) do
        local p, free = vector3(s.x, s.y, s.z), true
        for _, v in ipairs(vehicles) do
            if DoesEntityExist(v) and #(GetEntityCoords(v) - p) < clear then free = false break end
        end
        if free then return i, s end
    end
end

local function makePlate(prefix)
    prefix = tostring(prefix or 'GAR'):upper():sub(1, 4)
    local plate = prefix
    while #plate < 8 do plate = plate .. tostring(math.random(0, 9)) end
    return plate
end

local function giveKeys(src, veh, plate)
    local ev = G.keysEvent
    if type(ev) == 'table' and ev.name then
        if ev.type == 'server' then TriggerEvent(ev.name, src, plate, veh) else TriggerClientEvent(ev.name, src, plate) end
        return
    end
    if G.keys == false or G.keys == 'none' then return end
    if GetResourceState('qbx_vehiclekeys') == 'started' then pcall(function() exports.qbx_vehiclekeys:GiveKeys(src, veh) end) return end
    if GetResourceState('qb-vehiclekeys') == 'started' then TriggerClientEvent('vehiclekeys:client:SetOwner', src, plate) return end
    if GetResourceState('wasabi_carlock') == 'started' then pcall(function() exports.wasabi_carlock:GiveKey(src, plate) end) return end
    if GetResourceState('MrNewbVehicleKeys') == 'started' then pcall(function() exports.MrNewbVehicleKeys:GiveKeys(src, NetworkGetNetworkIdFromEntity(veh)) end) return end
end

-- Données affichées au joueur dans le menu du PNJ (appelée par sendNpcMenu)
function GarageMenuData(src, r)
    local g, n = r.npc.garage, r.npc
    local money = Bridge.GetMoney(src, n.payment, n.paymentItem)
    local data = { allowed = garageAccess(src, g, n), jobs = jobsText(g, n), spots = #(g.spots or {}), vehicles = {}, onePerPlayer = g.onePerPlayer }
    for i, v in ipairs(g.vehicles) do data.vehicles[#data.vehicles + 1] = { idx = i, label = v.label, model = v.model, price = v.price, afford = money >= v.price } end
    local netId, o, veh = outOf(src, r.id)
    if netId then
        data.out = { netId = netId, label = o.label, plate = o.plate, storeOk = nearGarage(GetEntityCoords(veh), r, g) }
    end
    return data
end

RegisterNetEvent('adminmenu:garage:take', function(pedId, idx, vtype)
    local src = source
    if not AM.rateLimit(src, 'garage', 2, 2000) then return end
    local r = checkNpc(src, tonumber(pedId))
    if not r or not r.npc.garage then return end
    local g, n = r.npc.garage, r.npc
    if not garageAccess(src, g, n) then return AM.notify(src, ('Ce garage est réservé : %s.'):format(jobsText(g, n)), 'error') end
    local v = g.vehicles[tonumber(idx) or 0]
    if not v then return end
    if #(g.spots or {}) == 0 then return AM.notify(src, 'Ce garage n\'a pas encore de place de sortie. Préviens le staff.', 'error') end
    if g.onePerPlayer and outOf(src, r.id) then
        AM.notify(src, 'Tu as déjà un véhicule de ce garage dehors : range-le d\'abord.', 'error')
        return sendNpcMenu(src, r)
    end
    local _, spot = freeSpot(g)
    if not spot then return AM.notify(src, 'Toutes les places de sortie sont occupées. Libère la place et réessaie.', 'error') end
    if v.price > 0 then
        if Bridge.GetMoney(src, n.payment, n.paymentItem) < v.price then return AM.notify(src, ('Il te faut %d $.'):format(v.price), 'error') end
        if not Bridge.RemoveMoney(src, n.payment, n.paymentItem, v.price, 'garage-pnj') then return AM.notify(src, 'Paiement refusé.', 'error') end
    end

    vtype = VTYPES[vtype] and vtype or 'automobile'
    local veh = CreateVehicleServerSetter(joaat(v.model), vtype, spot.x, spot.y, spot.z, spot.h)
    local t = GetGameTimer()
    while (not veh or veh == 0 or not DoesEntityExist(veh)) and GetGameTimer() - t < 3000 do Wait(50) end
    if not veh or veh == 0 or not DoesEntityExist(veh) then
        if v.price > 0 then Bridge.AddMoney(src, n.payment, n.paymentItem, v.price, 'remboursement-garage') end
        return AM.notify(src, ('Le véhicule « %s » n\'a pas pu apparaître (modèle inconnu ?).'):format(v.model), 'error')
    end
    local plate = makePlate(g.plate)
    SetVehicleNumberPlateText(veh, plate)
    Entity(veh).state:set('fuel', g.fuel + 0.0, true)   -- ox_fuel / lc_fuel
    local netId = NetworkGetNetworkIdFromEntity(veh)
    GarageOut[netId] = { src = src, ped = r.id, plate = plate, label = v.label }
    giveKeys(src, veh, plate)
    TriggerClientEvent('adminmenu:garage:spawned', src, netId, plate, g.fuel, g.warp, r.id)
    AM.notify(src, ('%s sorti (plaque %s)%s.'):format(v.label, plate, v.price > 0 and (' pour %d $'):format(v.price) or ''), 'success')
end)

RegisterNetEvent('adminmenu:garage:store', function(netId)
    local src = source
    if not AM.rateLimit(src, 'garage', 2, 1500) then return end
    netId = tonumber(netId)
    local o = netId and GarageOut[netId]
    if not o or o.src ~= src then return AM.notify(src, 'Ce véhicule ne vient pas de ce garage.', 'error') end
    local r, g = garagePed(o.ped)
    local veh = NetworkGetEntityFromNetworkId(netId)
    if veh == 0 or not DoesEntityExist(veh) then GarageOut[netId] = nil return end
    if not r or not nearGarage(GetEntityCoords(veh), r, g) then return AM.notify(src, 'Ramène le véhicule près du garage pour le ranger.', 'error') end
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(veh)) > 8.0 then return AM.notify(src, 'Approche-toi du véhicule.', 'error') end
    DeleteEntity(veh)
    GarageOut[netId] = nil
    TriggerClientEvent('adminmenu:garage:stored', src, netId)
    AM.notify(src, ('%s rangé.'):format(o.label), 'success')
end)

AddEventHandler('playerDropped', function()
    local src = source
    for netId, o in pairs(GarageOut) do
        if o.src == src then
            if G.deleteOnDrop ~= false then
                local veh = NetworkGetEntityFromNetworkId(netId)
                if veh ~= 0 and DoesEntityExist(veh) then DeleteEntity(veh) end
            end
            GarageOut[netId] = nil
        end
    end
end)

-- Points de sortie (staff) : ajout / déplacement d'un point, suppression
-- Point de départ de l'essai routier d'un PNJ « Catalogue concession »
def('editor_catalog_spot', 'editor_peds', function(src, d)
    local r = pedOf(tonumber(d.pedId))
    if not r or not r.npc or not r.npc.catalog then return AM.notify(src, 'Active d\'abord le rôle « Catalogue concession » sur ce PNJ et enregistre.', 'error') end
    local x, y, z, h = coords(d)
    if not x then return AM.notify(src, 'Position invalide.', 'error') end
    if #(GetEntityCoords(GetPlayerPed(src)) - vector3(x, y, z)) > 250.0 then return AM.notify(src, 'Position trop loin de toi.', 'error') end
    r.npc.catalog.testSpot = { x = x, y = y, z = z, h = h }
    save('peds') broadcast('peds')
    AM.addLog(src, 'Catalogue : point d\'essai', ('PNJ #%d'):format(r.id))
    AM.notify(src, 'Point de départ des essais enregistré.', 'success')
end)

-- Places de sortie d'un garage public (plusieurs, le joueur prend la première libre)
def('editor_pubgarage_spot', 'editor_peds', function(src, d)
    local r = pedOf(tonumber(d.pedId))
    local pg = r and r.npc and r.npc.pubgarage
    if not pg then return AM.notify(src, 'Active d\'abord le rôle « Garage public » sur ce PNJ et enregistre.', 'error') end
    local x, y, z, h = coords(d)
    if not x then return AM.notify(src, 'Position invalide.', 'error') end
    if #(GetEntityCoords(GetPlayerPed(src)) - vector3(x, y, z)) > 250.0 then return AM.notify(src, 'Position trop loin de toi.', 'error') end
    pg.spots = pg.spots or {}
    local idx = tonumber(d.idx)
    if idx and pg.spots[idx] then
        pg.spots[idx] = { x = x, y = y, z = z, h = h }
    else
        if #pg.spots >= 20 then return AM.notify(src, '20 places de sortie maximum.', 'error') end
        pg.spots[#pg.spots + 1] = { x = x, y = y, z = z, h = h }
    end
    save('peds') broadcast('peds')
    AM.addLog(src, 'Garage public : place de sortie', ('PNJ #%d · %d place(s)'):format(r.id, #pg.spots))
end)

-- Zones de rangement (cercle rouge au sol, E au volant pour ranger)
def('editor_pubgarage_store', 'editor_peds', function(src, d)
    local r = pedOf(tonumber(d.pedId))
    local pg = r and r.npc and r.npc.pubgarage
    if not pg then return AM.notify(src, 'Active d\'abord le rôle « Garage public » sur ce PNJ et enregistre.', 'error') end
    local x, y, z, h = coords(d)
    if not x then return AM.notify(src, 'Position invalide.', 'error') end
    if #(GetEntityCoords(GetPlayerPed(src)) - vector3(x, y, z)) > 250.0 then return AM.notify(src, 'Position trop loin de toi.', 'error') end
    pg.stores = pg.stores or {}
    local idx = tonumber(d.idx)
    if idx and pg.stores[idx] then
        pg.stores[idx] = { x = x, y = y, z = z, h = h }
    else
        if #pg.stores >= 10 then return AM.notify(src, '10 zones de rangement maximum.', 'error') end
        pg.stores[#pg.stores + 1] = { x = x, y = y, z = z, h = h }
    end
    save('peds') broadcast('peds')
    AM.addLog(src, 'Garage public : zone de rangement', ('PNJ #%d · %d zone(s)'):format(r.id, #pg.stores))
end)

def('editor_pubgarage_store_delete', 'editor_peds', function(src, d)
    local r = pedOf(tonumber(d.pedId))
    local pg = r and r.npc and r.npc.pubgarage
    local idx = tonumber(d.idx)
    if not pg or not idx or not (pg.stores or {})[idx] then return end
    table.remove(pg.stores, idx)
    save('peds') broadcast('peds')
    AM.notify(src, 'Zone de rangement supprimée.', 'success')
end)

-- Un joueur au volant dans une zone de rangement appuie sur E
RegisterNetEvent('adminmenu:pubgarage:storeZone', function(pedId, idx)
    local src = source
    if not AM.rateLimit(src, 'pubstore', 2, 2000) then return end
    local r = pedOf(tonumber(pedId))
    local pg = r and r.npc and r.npc.pubgarage
    local zone = pg and (pg.stores or {})[tonumber(idx) or 0]
    if not zone then return end
    if #(GetEntityCoords(GetPlayerPed(src)) - vector3(zone.x, zone.y, zone.z)) > (pg.storeRadius or 4) + 4.0 then return end
    if not NpcAccess(src, r.npc) then return AM.notify(src, ('Ce garage est réservé : %s.'):format(NpcJobsText(r.npc)), 'error') end
    if GetResourceState('elyzea_garage') ~= 'started' then
        return AM.notify(src, 'Le garage est fermé (ressource elyzea_garage non démarrée).', 'error')
    end
    exports.elyzea_garage:StoreAt(src, { name = pg.name, zone = { x = zone.x, y = zone.y, z = zone.z }, radius = pg.storeRadius or 4 })
end)

def('editor_pubgarage_spot_delete', 'editor_peds', function(src, d)
    local r = pedOf(tonumber(d.pedId))
    local pg = r and r.npc and r.npc.pubgarage
    local idx = tonumber(d.idx)
    if not pg or not idx or not (pg.spots or {})[idx] then return end
    table.remove(pg.spots, idx)
    save('peds') broadcast('peds')
    AM.notify(src, 'Place de sortie supprimée.', 'success')
end)

def('editor_garage_spot', 'editor_peds', function(src, d)
    local r, g = garagePed(d.pedId)
    if not r then return AM.notify(src, 'Active d\'abord le rôle « Garage » sur ce PNJ et enregistre.', 'error') end
    local x, y, z, h = coords(d)
    if not x then return AM.notify(src, 'Position invalide.', 'error') end
    if #(GetEntityCoords(GetPlayerPed(src)) - vector3(x, y, z)) > 250.0 then return AM.notify(src, 'Position trop loin de toi.', 'error') end
    g.spots = g.spots or {}
    local idx = tonumber(d.idx)
    if idx and g.spots[idx] then
        g.spots[idx] = { x = x, y = y, z = z, h = h }
    else
        if #g.spots >= (G.maxSpots or 12) then return AM.notify(src, ('%d points de sortie maximum.'):format(G.maxSpots or 12), 'error') end
        g.spots[#g.spots + 1] = { x = x, y = y, z = z, h = h }
    end
    save('peds') broadcast('peds')
    AM.addLog(src, 'Garage : point de sortie', ('PNJ #%d · %d point(s)'):format(r.id, #g.spots))
    AM.notify(src, ('Point de sortie enregistré (%d pour ce garage).'):format(#g.spots), 'success')
end)

def('editor_garage_spot_delete', 'editor_peds', function(src, d)
    local r, g = garagePed(d.pedId)
    local idx = tonumber(d.idx)
    if not r or not idx or not g.spots or not g.spots[idx] then return end
    table.remove(g.spots, idx)
    save('peds') broadcast('peds')
    AM.addLog(src, 'Garage : point de sortie supprimé', ('PNJ #%d · %d restant(s)'):format(r.id, #g.spots))
    AM.notify(src, ('Point de sortie supprimé (%d restant(s)).'):format(#g.spots), 'success')
end)

-- ---------------------------------------------------------
--  COFFRES (inventaires posés sur la map)
--  Un objet (caisse, coffre-fort…) qui ouvre un inventaire partagé.
--  Poids et emplacements réglables ; accès : tout le monde, certains
--  métiers et/ou certains groupes illégaux (gangs), avec grade minimum.
-- ---------------------------------------------------------
local function stashInvId(st) return ('am_stash_%d'):format(st.id) end

local function cleanGroups(list, key, max)
    local out = {}
    for _, g in ipairs(type(list) == 'table' and list or {}) do
        local name = cleanModel(g[key]):lower()
        if name ~= '' and #out < (max or 20) then out[#out + 1] = { [key] = name, grade = math.floor(num(g.grade, 0, 100, 0)) } end
    end
    return out
end

local function stashSettings(d, base)
    base = base or {}
    local st = {
        name = cleanName(d.name ~= nil and d.name or base.name, 40),
        model = cleanModel(d.model ~= nil and d.model or base.model):lower(),
        weight = math.floor(num(d.weight, 1, 100000, base.weight or 100)),     -- kg
        slots = math.floor(num(d.slots, 1, 500, base.slots or 50)),
        jobs = cleanGroups(d.jobs ~= nil and d.jobs or base.jobs, 'job'),
        gangs = cleanGroups(d.gangs ~= nil and d.gangs or base.gangs, 'gang'),
    }
    if st.name == '' then st.name = 'Coffre' end
    return st
end

local function registerStash(st)
    if GetResourceState('ox_inventory') ~= 'started' then return end
    pcall(function()
        exports.ox_inventory:RegisterStash(stashInvId(st), st.name, st.slots, st.weight * 1000, false, nil, vector3(st.x, st.y, st.z))
    end)
end
local function registerAllStashes() for _, st in ipairs(Data.stashes) do registerStash(st) end end
AddEventHandler('onServerResourceStart', function(res)
    if res == 'ox_inventory' or res == GetCurrentResourceName() then SetTimeout(1000, registerAllStashes) end
end)

-- Qui peut l'ouvrir
function StashAccess(src, st)
    local hasJobs, hasGangs = st.jobs and #st.jobs > 0, st.gangs and #st.gangs > 0
    if not hasJobs and not hasGangs then return true end
    if hasJobs then
        local job, grade = Bridge.GetJob(src)
        for _, j in ipairs(st.jobs) do if job == j.job and (grade or 0) >= (j.grade or 0) then return true end end
    end
    if hasGangs then
        local gang, grade = Bridge.GetGang(src)
        for _, g in ipairs(st.gangs) do if gang == g.gang and (grade or 0) >= (g.grade or 0) then return true end end
    end
    return false
end

local function openStashFor(src, st)
    local inv = Bridge.Mode()
    if GetResourceState('ox_inventory') == 'started' then
        registerStash(st)
        exports.ox_inventory:forceOpenInventory(src, 'stash', stashInvId(st))
    elseif GetResourceState('qb-inventory') == 'started' then
        exports['qb-inventory']:OpenInventory(src, stashInvId(st), { maxweight = st.weight * 1000, slots = st.slots, label = st.name })
    else
        AM.notify(src, ('Ton inventaire (%s) ne gère pas les coffres : ox_inventory ou qb-inventory requis.'):format(tostring(inv)), 'error')
    end
end

RegisterNetEvent('adminmenu:stash:open', function(id)
    local src = source
    if not AM.rateLimit(src, 'stash', 3, 1500) then return end
    local _, st = findIndex(Data.stashes, id)
    if not st or not near(src, st, 3.5) then return end
    if not StashAccess(src, st) then return AM.notify(src, 'Ce coffre ne s\'ouvre pas pour toi.', 'error') end
    openStashFor(src, st)
end)

def('editor_save_stash', 'editor_stashes', function(src, d)
    local x, y, z, h = coords(d)
    if not x then return AM.notify(src, 'Données de placement invalides.', 'error') end
    local _, st = findIndex(Data.stashes, d.id)
    if st then
        st.x, st.y, st.z, st.h = x, y, z, h
        st.rx, st.ry = tilt(d)
        AM.addLog(src, 'Coffre déplacé', ('#%d %s'):format(st.id, st.name))
    else
        st = stashSettings(d)
        if st.model == '' then return AM.notify(src, 'Choisis l\'apparence du coffre.', 'error') end
        st.id, st.x, st.y, st.z, st.h = nextId(Data.stashes), x, y, z, h
        st.rx, st.ry = tilt(d)
        table.insert(Data.stashes, st)
        AM.addLog(src, 'Coffre créé', ('#%d %s · %d kg · %d emplacements'):format(st.id, st.name, st.weight, st.slots))
    end
    registerStash(st)
    save('stashes') broadcast('stashes')
    AM.notify(src, ('Coffre « %s » enregistré.'):format(st.name), 'success')
end)

def('editor_update_stash', 'editor_stashes', function(src, d)
    local _, st = findIndex(Data.stashes, d.id)
    if not st then return AM.notify(src, 'Coffre introuvable.', 'error') end
    for k, v in pairs(stashSettings(d, st)) do st[k] = v end
    registerStash(st)
    save('stashes') broadcast('stashes')
    AM.notify(src, ('Coffre « %s » mis à jour.'):format(st.name), 'success')
    AM.addLog(src, 'Coffre modifié', ('#%d %s · %d kg · %d emplacements'):format(st.id, st.name, st.weight, st.slots))
end)

-- Le staff peut ouvrir n'importe quel coffre depuis le menu (vérification, nettoyage…)
def('editor_stash_open', 'editor_stashes', function(src, d)
    local _, st = findIndex(Data.stashes, d.id)
    if not st then return end
    AM.addLog(src, 'Coffre ouvert (staff)', ('#%d %s'):format(st.id, st.name))
    openStashFor(src, st)
end)

-- ---------------------------------------------------------
--  Nouveaux arrivants
--  Toute licence jamais vue est enregistrée ; si un point « nouveaux
--  arrivants » existe, le joueur y est téléporté à sa toute première venue.
-- ---------------------------------------------------------
local knownDirty = false
RegisterNetEvent('adminmenu:spawn:check', function()
    local src = source
    if not AM.rateLimit(src, 'adminmenu:spawn:check', 2, 10000) then return end
    local lic = AM.getLicense(src)
    if not lic or Known[lic] then return end
    Known[lic] = os.time()
    knownDirty = true
    for _, s in ipairs(Data.spawns) do
        if s.newcomer then
            TriggerClientEvent('adminmenu:spawn:newcomer', src, s)
            AM.addLog(0, 'Nouvel arrivant', ('%s → %s'):format(AM.pname(src), s.name))
            return
        end
    end
end)

CreateThread(function()
    while true do
        Wait(30000)
        if knownDirty then knownDirty = false Storage.saveLater('known', Known) end
    end
end)
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and knownDirty then Storage.save('known', Known) end
end)

-- ---------------------------------------------------------
--  PORTES : utilisation par les joueurs
-- ---------------------------------------------------------
local CodeTries = {}  -- ["source:porte"] = { n, until }

local function nearDoor(src, door)
    local c = GetEntityCoords(GetPlayerPed(src))
    for _, l in ipairs(door.leaves) do
        if #(c - vector3(l.x, l.y, l.z)) <= (door.distance or Config.Doors.interactDistance) + 2.0 then return true end
    end
    return false
end

local function doorRole(src, door)
    if AM.hasPerm(src, 'editor_doors') and AM.getLevel(src) >= MIN and AM.onDuty(src) then return 'admin' end
    local cid = Bridge.GetCharId(src)
    for _, o in ipairs(door.owners) do if o.id == cid then return 'owner' end end
    return 'visitor'
end

local function codeHash(door, code) return GetHashKey(('am_door_%d_%s'):format(door.id, code)) end

local function sendDoorPanel(src, door)
    local role = doorRole(src, door)
    TriggerClientEvent('adminmenu:door:panel', src, {
        id = door.id, name = door.name, locked = door.locked, role = role, hasCode = door.codeHash ~= nil,
        owners = (role ~= 'visitor') and door.owners or nil,
    })
end

RegisterNetEvent('adminmenu:door:open', function(id)
    local src = source
    if not AM.rateLimit(src, 'door', 5, 1000) then return end
    local door = doorOf(tonumber(id))
    if door and nearDoor(src, door) then sendDoorPanel(src, door) end
end)

RegisterNetEvent('adminmenu:door:toggle', function(id, code)
    local src = source
    if not AM.rateLimit(src, 'door', 5, 1000) then return end
    local door = doorOf(tonumber(id))
    if not door or not nearDoor(src, door) then return end
    local role = doorRole(src, door)
    if role == 'visitor' then
        if not door.codeHash then return AM.notify(src, 'Cette porte est verrouillée.', 'error') end
        local key = src .. ':' .. door.id
        local t = CodeTries[key]
        if t and t.untilT and t.untilT > os.time() then
            return AM.notify(src, ('Trop d\'essais. Réessaie dans %d s.'):format(t.untilT - os.time()), 'error')
        end
        if codeHash(door, tostring(code or '')) ~= door.codeHash then
            t = t or { n = 0 }
            t.n = t.n + 1
            if t.n >= Config.Doors.maxTries then t.n, t.untilT = 0, os.time() + Config.Doors.lockout end
            CodeTries[key] = t
            return AM.notify(src, 'Code incorrect.', 'error')
        end
        CodeTries[key] = nil
    end
    door.locked = not door.locked
    save('doors') broadcast('doors')
    AM.notify(src, door.locked and '🔒 Porte verrouillée.' or '🔓 Porte déverrouillée.', 'success')
    sendDoorPanel(src, door)
end)

RegisterNetEvent('adminmenu:door:setcode', function(id, code)
    local src = source
    if not AM.rateLimit(src, 'door', 5, 1000) then return end
    local door = doorOf(tonumber(id))
    if not door or not nearDoor(src, door) or doorRole(src, door) == 'visitor' then return end
    code = tostring(code or '')
    if code == '' then
        door.codeHash = nil
        AM.notify(src, 'Code supprimé : seuls les propriétaires peuvent ouvrir.', 'success')
    else
        if not code:match('^%d+$') or #code < Config.Doors.codeMin or #code > Config.Doors.codeMax then
            return AM.notify(src, ('Le code doit faire %d à %d chiffres.'):format(Config.Doors.codeMin, Config.Doors.codeMax), 'error')
        end
        door.codeHash = codeHash(door, code)
        AM.notify(src, 'Code enregistré. Donne-le aux personnes que tu veux laisser entrer.', 'success')
    end
    save('doors') broadcast('doors')
    sendDoorPanel(src, door)
end)

AddEventHandler('playerDropped', function()
    local prefix = source .. ':'
    for k in pairs(CodeTries) do if k:sub(1, #prefix) == prefix then CodeTries[k] = nil end end
end)

-- ---------------------------------------------------------
--  PRISON (jail)
--  Le temps ne s'écoule que pendant que le joueur est connecté.
--  À la fin, il est renvoyé là où il était au moment du jail.
-- ---------------------------------------------------------
local function jailPoint()
    for _, sp in ipairs(Data.spawns) do if sp.jail then return sp end end
end

local function onlineByLicense()
    local m = {}
    for _, p in ipairs(GetPlayers()) do
        local lic = AM.getLicense(tonumber(p))
        if lic then m[lic] = tonumber(p) end
    end
    return m
end

local function releaseJail(lic, by)
    local j = Jails[lic]
    if not j then return end
    Jails[lic] = nil
    Storage.saveLater('jails', Jails)
    local id = onlineByLicense()[lic]
    if id then TriggerClientEvent('adminmenu:jail:end', id, j.ret) end
    if by then AM.addLog(by, 'Libération de prison', j.name or lic) end
end

A.jail = { perm = 'jail', fn = function(src, d)
    local t = tonumber(d.target)
    if not t or not GetPlayerName(t) then return AM.notify(src, 'Joueur introuvable.', 'error') end
    if t ~= src and AM.getLevel(t) >= AM.getLevel(src) then return AM.notify(src, 'Ce joueur a un grade égal ou supérieur au vôtre.', 'error') end
    local jp = jailPoint()
    if not jp then return AM.notify(src, 'Aucun point de jail : définis-le dans Éditeur de map › Points de spawn.', 'error') end
    local minutes = math.floor(num(d.minutes, 1, 1440, 10))
    local reason = cleanName(d.reason, 120)
    if reason == '' then reason = 'Aucune raison précisée' end
    local lic = AM.getLicense(t)
    if not lic then return end
    local ped = GetPlayerPed(t)
    local c = GetEntityCoords(ped)
    local prev = Jails[lic]
    Jails[lic] = {
        remaining = minutes * 60, reason = reason, by = AM.pname(src), name = GetPlayerName(t),
        ret = prev and prev.ret or { x = round(c.x), y = round(c.y), z = round(c.z), h = round(GetEntityHeading(ped)) },
    }
    Storage.saveLater('jails', Jails)
    TriggerClientEvent('adminmenu:jail:start', t, jp, Jails[lic].remaining, reason)
    AM.notify(src, ('%s est en prison pour %d min.'):format(GetPlayerName(t), minutes), 'success')
    AM.addLog(src, 'Jail', ('%s [%d] | %d min | %s'):format(GetPlayerName(t), t, minutes, reason))
end }

A.unjail = { perm = 'jail', fn = function(src, d)
    local lic = tostring(d.license or '')
    if not Jails[lic] then return AM.notify(src, 'Ce joueur n\'est pas en prison.', 'error') end
    AM.notify(src, ('%s est libéré.'):format(Jails[lic].name or lic), 'success')
    releaseJail(lic, src)
end }

RegisterNetEvent('adminmenu:jail:check', function()
    local src = source
    if not AM.rateLimit(src, 'jailcheck', 3, 10000) then return end
    local lic = AM.getLicense(src)
    local j = lic and Jails[lic]
    local jp = jailPoint()
    if j and jp then TriggerClientEvent('adminmenu:jail:start', src, jp, j.remaining, j.reason) end
end)

CreateThread(function()
    local tick = 0
    while true do
        Wait(5000)
        tick = tick + 1
        if next(Jails) then
            local online = onlineByLicense()
            local changed = false
            for lic, j in pairs(Jails) do
                local id = online[lic]
                if id then
                    j.remaining = j.remaining - 5
                    changed = true
                    if j.remaining <= 0 then
                        releaseJail(lic)
                        AM.notify(id, 'Ta peine est terminée. Tu es libre !', 'success')
                    elseif tick % 6 == 0 then
                        TriggerClientEvent('adminmenu:jail:sync', id, j.remaining)
                    end
                end
            end
            if changed and tick % 6 == 0 then Storage.saveLater('jails', Jails) end
        end
    end
end)

-- Liste des prisonniers dans le menu
-- Liste des métiers du serveur (pour les menus déroulants de l'éditeur : garages…)
table.insert(AM.DataHooks, function(src, data)
    if AM.hasPerm(src, 'editor_peds') or AM.hasPerm(src, 'editor_stashes') then
        data.jobs = Bridge.GetJobs()
        data.gangs = Bridge.GetGangs()
    end
end)

table.insert(AM.DataHooks, function(src, data)
    if not AM.hasPerm(src, 'jail') then return end
    local online = onlineByLicense()
    local list = {}
    for lic, j in pairs(Jails) do
        list[#list + 1] = { license = lic, name = j.name, remaining = j.remaining, reason = j.reason, by = j.by, online = online[lic] }
    end
    table.sort(list, function(a, b) return a.remaining > b.remaining end)
    data.jails = list
    data.hasJailPoint = jailPoint() ~= nil
end)

-- ---------------------------------------------------------
--  Accès aux PNJ de l'éditeur pour les autres fichiers serveur
--  (conversion d'un PNJ en contact GoFast)
-- ---------------------------------------------------------
AM.EditorPeds = {
    get = function(id)
        local _, r = findIndex(Data.peds, id)
        return r
    end,
    remove = function(id)
        local i, r = findIndex(Data.peds, id)
        if not i then return false end
        table.remove(Data.peds, i)
        save('peds') broadcast('peds')
        return true, r
    end,
}

-- ---------------------------------------------------------
--  Exports pour d'autres ressources (ESX, QBCore, multichar…)
-- ---------------------------------------------------------
exports('GetSpawnPoints', function() return Data.spawns end)
exports('GetNewcomerSpawn', function()
    for _, s in ipairs(Data.spawns) do if s.newcomer then return s end end
end)
exports('GetRandomSpawnPoint', function()
    if #Data.spawns == 0 then return nil end
    return Data.spawns[math.random(#Data.spawns)]
end)
