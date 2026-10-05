-- =========================================================
--  ÉVÉNEMENT ZOMBIES : CAISSES D'ARMES, RÉCOMPENSES, REPRISE
--  * Caisses : types composés dans le menu (contenu libre), placées
--    automatiquement sur des emplacements de la zone et/ou à la main.
--  * Tout ce qui sort d'une caisse est enregistré (et étiqueté sur
--    ox_inventory / qb-inventory) puis REPRIS à la fin de l'événement :
--    seulement ces objets-là, jamais ceux que les joueurs avaient déjà.
--  * Joueur déconnecté à la fin : reprise à sa prochaine connexion.
-- =========================================================
local AM = AdminMenu
local ZC = Config.Zombies

ZombieLoot = {}

local Crates = {}          -- [id] = { id, type, x, y, z, looted, lootedBy = { [perso] = true } }
local CrateTypes = {}      -- types de l'événement en cours
local crateSeq = 0
local Reclaim = Storage.load('zombie_reclaim', {})   -- [perso] = { tag, name, items = { [objet] = n }, active }
local Given = 0            -- objets sortis des caisses pendant l'événement
local applyReclaim         -- défini plus bas (reprise des objets d'un joueur)

local function now() return os.time() end
local function num(v, min, max, def)
    v = tonumber(v)
    if not v or v ~= v then return def end
    return math.max(min, math.min(max, v))
end
local function cleanText(v, n)
    if type(v) ~= 'string' then return '' end
    return (v:gsub('[%c<>]', '')):sub(1, n):match('^%s*(.-)%s*$')
end
local function cleanItem(v)
    if type(v) ~= 'string' then return '' end
    return (v:gsub('[^%w_%-]', '')):sub(1, 60)
end
local function saveReclaim() Storage.saveLater('zombie_reclaim', Reclaim) end

-- Au démarrage de la ressource : rien n'est « en cours », tout ce qui reste est à reprendre
for _, e in pairs(Reclaim) do e.active = false end

-- =========================================================
--  RÉCOMPENSES (où et à qui)
-- =========================================================
local KINDS = { cash = true, bank = true, item = true }
local TARGETS = { participants = true, finisher = true, laststep = true, all = true, area = true, top = true, players = true }

function ZombieLoot.CleanRewards(r)
    if type(r) ~= 'table' then return { lines = {}, to = 'participants' } end
    local lines = {}
    for i, l in ipairs(type(r.lines) == 'table' and r.lines or {}) do
        if i > 8 then break end
        if type(l) == 'table' and KINDS[l.kind] then
            local amount = math.floor(num(l.amount, 0, 100000000, 0))
            local item = l.kind == 'item' and cleanItem(l.item) or nil
            if l.kind == 'item' and item == '' then return nil, 'une récompense « objet » n\'a pas de nom d\'objet.' end
            if amount > 0 then lines[#lines + 1] = { kind = l.kind, item = item, amount = amount } end
        end
    end
    local to = TARGETS[r.to] and r.to or 'participants'
    local players = {}
    if to == 'players' then
        for i, id in ipairs(type(r.players) == 'table' and r.players or {}) do
            if i > 64 then break end
            id = tonumber(id)
            if id then players[#players + 1] = math.floor(id) end
        end
        if #lines > 0 and #players == 0 then return nil, 'choisis au moins un joueur pour la récompense.' end
    end
    return { lines = lines, to = to, top = math.floor(num(r.top, 1, 50, 3)), players = players }
end

local function recipientsOf(r, ctx)
    local ev = ZombieEvent.get()
    local set = {}
    if r.to == 'participants' then
        for id in pairs(ctx.participants or {}) do set[id] = true end
    elseif r.to == 'finisher' then
        if ctx.finisher and ctx.finisher > 0 then set[ctx.finisher] = true
        else for id in pairs(ctx.lastStep or {}) do set[id] = true end end
    elseif r.to == 'laststep' then
        for id in pairs(ctx.lastStep or {}) do set[id] = true end
    elseif r.to == 'all' then
        for _, p in ipairs(GetPlayers()) do set[tonumber(p)] = true end
    elseif r.to == 'area' then
        for _, p in ipairs(GetPlayers()) do
            local ped = GetPlayerPed(p)
            if ped ~= 0 and ZombieEvent.inArea(GetEntityCoords(ped)) then set[tonumber(p)] = true end
        end
    elseif r.to == 'top' then
        local list = {}
        for id, k in pairs(ev.kills or {}) do list[#list + 1] = { id = id, k = k } end
        table.sort(list, function(a, b) return a.k > b.k end)
        for i = 1, math.min(r.top, #list) do set[list[i].id] = true end
    elseif r.to == 'players' then
        for _, id in ipairs(r.players) do set[id] = true end
    end
    return set
end

local function rewardText(lines)
    local parts = {}
    for _, l in ipairs(lines) do
        if l.kind == 'item' then parts[#parts + 1] = ('%dx %s'):format(l.amount, Bridge.GetLabel(l.item) or l.item)
        else parts[#parts + 1] = ('%d $%s'):format(l.amount, l.kind == 'bank' and ' en banque' or '') end
    end
    return table.concat(parts, ', ')
end

-- Verse les récompenses ; renvoie le nombre de joueurs récompensés
function ZombieLoot.GiveRewards(r, what, ctx)
    if not r or #r.lines == 0 then return 0 end
    local n = 0
    local text = rewardText(r.lines)
    for id in pairs(recipientsOf(r, ctx or {})) do
        if GetPlayerName(id) then
            n = n + 1
            local missed = false
            for _, l in ipairs(r.lines) do
                if l.kind == 'item' then
                    if not Bridge.AddItem(id, l.item, l.amount) then missed = true end
                else
                    Bridge.AddMoney(id, l.kind, nil, l.amount, 'Événement zombies : ' .. what)
                end
            end
            AM.notify(id, ('Récompense pour %s : %s.%s'):format(what, text, missed and ' (inventaire plein : une partie n\'a pas pu être donnée)' or ''), 'success')
        end
    end
    return n
end

-- =========================================================
--  TYPES DE CAISSES
-- =========================================================
local MODELS = {}
for _, m in ipairs(ZC.crateModels or {}) do MODELS[m.id] = true end

function ZombieLoot.CleanCrateType(t)
    if type(t) ~= 'table' then return nil, 'Type de caisse invalide.' end
    local label = cleanText(t.label, 40)
    if label == '' then return nil, 'Donne un nom à chaque type de caisse.' end
    local contents = {}
    for i, c in ipairs(type(t.contents) == 'table' and t.contents or {}) do
        if i > 12 then break end
        local item = cleanItem(type(c) == 'table' and c.item)
        local count = math.floor(num(type(c) == 'table' and c.count, 1, 5000, 1))
        if item ~= '' then contents[#contents + 1] = { item = item, count = count } end
    end
    if #contents == 0 then return nil, ('La caisse « %s » est vide.'):format(label) end
    local manual = {}
    for i, p in ipairs(type(t.manual) == 'table' and t.manual or {}) do
        if i > 30 then break end
        local x, y, z = tonumber(p.x), tonumber(p.y), tonumber(p.z)
        if x and y and z and math.abs(x) < 20000 and math.abs(y) < 20000 then manual[#manual + 1] = { x = x, y = y, z = z } end
    end
    return {
        label = label,
        model = MODELS[t.model] and t.model or ((ZC.crateModels and ZC.crateModels[1] and ZC.crateModels[1].id) or 'prop_mil_crate_01'),
        mode = t.mode == 'each' and 'each' or 'once',
        blip = t.blip ~= false and t.blip ~= 'false',
        color = math.floor(num(t.color, 0, 85, 1)),
        count = math.floor(num(t.count, 0, 60, 0)),
        manual = manual,
        contents = contents,
    }
end

function ZombieLoot.CleanCrateTypes(list)
    local out = {}
    for i, t in ipairs(type(list) == 'table' and list or {}) do
        if i > 8 then break end
        local ct, err = ZombieLoot.CleanCrateType(t)
        if not ct then return nil, err end
        out[#out + 1] = ct
    end
    return out
end

-- =========================================================
--  CAISSES : placement et synchro
-- =========================================================
local function publicCrate(c)
    local t = CrateTypes[c.type]
    if not t then return nil end
    local parts = {}
    for _, it in ipairs(t.contents) do parts[#parts + 1] = ('%dx %s'):format(it.count, Bridge.GetLabel(it.item) or it.item) end
    return { id = c.id, x = c.x, y = c.y, z = c.z, label = t.label, model = t.model, mode = t.mode, blip = t.blip,
        color = t.color, contents = table.concat(parts, ', ') }
end

local function publicList()
    local list = {}
    for _, c in pairs(Crates) do
        if not c.looted then
            local p = publicCrate(c)
            if p then list[#list + 1] = p end
        end
    end
    return list
end

local syncPending = false
local function broadcast()
    if syncPending then return end
    syncPending = true
    SetTimeout(150, function()
        syncPending = false
        TriggerClientEvent('adminmenu:zombies:crates', -1, publicList())
    end)
end

function ZombieLoot.SendTo(src)
    local key = Bridge.GetCharId(src)
    local mine = {}
    for _, c in pairs(Crates) do
        if key and c.lootedBy[key] then mine[#mine + 1] = c.id end
    end
    TriggerLatentClientEvent('adminmenu:zombies:crates', src, 100000, publicList(), mine)
end

local function addCrate(typeIndex, x, y, z)
    crateSeq = crateSeq + 1
    Crates[crateSeq] = { id = crateSeq, type = typeIndex, x = x + 0.0, y = y + 0.0, z = z + 0.0, looted = false, lootedBy = {} }
    return crateSeq
end

-- Emplacements libres de la zone (mélangés), en évitant ceux déjà pris
local function freeSpots()
    local used, list = {}, {}
    for _, c in pairs(Crates) do used[('%.0f:%.0f'):format(c.x, c.y)] = true end
    for _, s in ipairs(ZC.crateSpots or {}) do
        if not used[('%.0f:%.0f'):format(s.x, s.y)] and ZombieEvent.inArea(vector3(s.x, s.y, s.z)) then list[#list + 1] = s end
    end
    for i = #list, 2, -1 do
        local j = math.random(i)
        list[i], list[j] = list[j], list[i]
    end
    return list
end

local function placeAuto(typeIndex, count)
    local spots = freeSpots()
    local n = 0
    for i = 1, math.min(count, #spots) do
        addCrate(typeIndex, spots[i].x, spots[i].y, spots[i].z)
        n = n + 1
    end
    return n
end

function ZombieLoot.Start(types)
    Crates, CrateTypes, crateSeq, Given = {}, types or {}, 0, 0
    local missing = 0
    for i, t in ipairs(CrateTypes) do
        local placed = placeAuto(i, t.count)
        missing = missing + (t.count - placed)
        for _, p in ipairs(t.manual) do addCrate(i, p.x, p.y, p.z) end
    end
    if missing > 0 then
        print(('^3[AdminMenu] Caisses zombies : %d caisse(s) non placée(s), pas assez d\'emplacements dans la zone (Config.Zombies.crateSpots).^7'):format(missing))
    end
    broadcast()
end

-- =========================================================
--  OUVERTURE D'UNE CAISSE
-- =========================================================
local Opening = {}   -- [joueur] = { crate, at }

RegisterNetEvent('adminmenu:zombies:crate', function(id, phase)
    local src = source
    if not AM.rateLimit(src, 'zombies:crate', 6, 2000) then return end
    local ev = ZombieEvent.get()
    local c = Crates[tonumber(id) or -1]
    if not ev.active or not c or c.looted then Opening[src] = nil return end
    local ped = GetPlayerPed(src)
    if ped == 0 or GetEntityHealth(ped) <= 0 then return end
    local pc = GetEntityCoords(ped)
    local dx, dy = pc.x - c.x, pc.y - c.y
    if dx * dx + dy * dy > 4.5 * 4.5 or math.abs(pc.z - c.z) > 12.0 then Opening[src] = nil return end

    if phase == 'start' then
        Opening[src] = { crate = c.id, at = GetGameTimer() }
        return
    end
    local op = Opening[src]
    Opening[src] = nil
    if phase ~= 'done' or not op or op.crate ~= c.id or GetGameTimer() - op.at < (ZC.crateOpenTime * 1000 - 600) then return end

    local t = CrateTypes[c.type]
    local key = Bridge.GetCharId(src)
    if not t or not key then return end
    if t.mode == 'each' and c.lootedBy[key] then return AM.notify(src, 'Tu as déjà pris ta part dans cette caisse.', 'error') end

    -- Reste d'un ancien événement pas encore repris : on le reprend d'abord
    if Reclaim[key] and not Reclaim[key].active then applyReclaim(src, key, Reclaim[key]) end

    -- Distribution avec étiquette + registre pour la reprise
    local entry = Reclaim[key] or { tag = ev.tag, name = GetPlayerName(src), items = {}, active = true }
    entry.tag, entry.active, entry.name = ev.tag, true, GetPlayerName(src)
    local got, missed = {}, {}
    local meta = { am_event = ev.tag, description = 'Caisse de l\'attaque zombies : reprise à la fin de l\'événement.' }
    for _, it in ipairs(t.contents) do
        local ok = Bridge.AddItem(src, it.item, it.count, meta)
        if ok then
            entry.items[it.item] = (entry.items[it.item] or 0) + it.count
            got[#got + 1] = ('%dx %s'):format(it.count, Bridge.GetLabel(it.item) or it.item)
            Given = Given + it.count
        else
            missed[#missed + 1] = Bridge.GetLabel(it.item) or it.item
        end
    end
    if #got == 0 then
        return AM.notify(src, 'Inventaire plein : impossible de prendre le contenu de la caisse.', 'error')
    end
    Reclaim[key] = entry
    saveReclaim()

    c.lootedBy[key] = true
    if t.mode == 'once' then
        c.looted = true
        broadcast()
    end
    TriggerClientEvent('adminmenu:zombies:crateLooted', src, c.id)
    AM.notify(src, ('Caisse « %s » : %s.%s Ces armes seront reprises à la fin de l\'attaque.'):format(t.label, table.concat(got, ', '),
        #missed > 0 and (' Inventaire plein pour : ' .. table.concat(missed, ', ') .. '.') or ''), 'success')
end)

AddEventHandler('playerDropped', function() Opening[source] = nil end)

-- =========================================================
--  REPRISE DES ARMES À LA FIN
-- =========================================================
applyReclaim = function(src, key, entry)
    local removed = {}
    if Bridge.SupportsTags() and entry.tag then
        removed = Bridge.RemoveTagged(src, entry.tag)
    else
        -- Inventaire sans étiquette : on retire au plus ce qui a été pris dans les caisses
        for item, n in pairs(entry.items or {}) do
            local have = Bridge.GetItemCount(src, item)
            local take = math.min(n, have)
            if take > 0 and Bridge.RemoveItem(src, item, take) then removed[item] = take end
        end
    end
    Reclaim[key] = nil
    saveReclaim()
    local parts = {}
    for item, n in pairs(removed) do parts[#parts + 1] = ('%dx %s'):format(n, Bridge.GetLabel(item) or item) end
    if #parts > 0 then
        AM.notify(src, ('Fin de l\'attaque : les armes et munitions des caisses ont été reprises (%s).'):format(table.concat(parts, ', ')), 'info')
    end
    return removed
end

function ZombieLoot.Stop(ev)
    Crates, CrateTypes, Opening = {}, {}, {}
    TriggerClientEvent('adminmenu:zombies:crates', -1, {})

    local online = {}
    for _, p in ipairs(GetPlayers()) do
        local id = tonumber(p)
        local key = Bridge.GetCharId(id)
        if key then online[key] = id end
    end

    local done, pending = 0, 0
    for key, entry in pairs(Reclaim) do
        entry.active = false
        if online[key] then
            applyReclaim(online[key], key, entry)
            done = done + 1
        else
            pending = pending + 1
        end
    end
    -- Objets étiquetés passés à un autre joueur (en ligne) : repris aussi
    if Bridge.SupportsTags() and ev.tag then
        for _, id in pairs(online) do Bridge.RemoveTagged(id, ev.tag) end
    end
    saveReclaim()
    if Given > 0 or done > 0 or pending > 0 then
        AM.addLog(0, 'Attaque de zombies : reprise des armes', ('%d objet(s) sortis des caisses · repris chez %d joueur(s) · %d à la prochaine connexion'):format(Given, done, pending))
    end
end

-- Joueurs revenus après la fin : reprise dès que leur personnage est chargé
CreateThread(function()
    while true do
        Wait(20000)
        if next(Reclaim) then
            for _, p in ipairs(GetPlayers()) do
                local id = tonumber(p)
                local key = Bridge.GetCharId(id)
                local entry = key and Reclaim[key]
                if entry and not entry.active then applyReclaim(id, key, entry) end
            end
        end
    end
end)

-- =========================================================
--  ACTIONS DU MENU (pendant l'événement)
-- =========================================================
local A = AM.Actions
local function def(name, fn) A[name] = { perm = 'event_zombies', fn = fn } end

def('zombies_crate_type', function(src, d)
    if not ZombieEvent.get().active then return AM.notify(src, 'Aucune attaque en cours.', 'error') end
    if #CrateTypes >= 12 then return AM.notify(src, 'Trop de types de caisses.', 'error') end
    local t, err = ZombieLoot.CleanCrateType(d.crate)
    if not t then return AM.notify(src, err, 'error') end
    CrateTypes[#CrateTypes + 1] = t
    local placed = placeAuto(#CrateTypes, t.count)
    for _, p in ipairs(t.manual) do addCrate(#CrateTypes, p.x, p.y, p.z) end
    broadcast()
    AM.notify(src, ('Caisses « %s » ajoutées (%d placée(s)).'):format(t.label, placed + #t.manual), 'success')
    AM.addLog(src, 'Caisses zombies ajoutées', t.label)
end)

def('zombies_crate_more', function(src, d)
    local i = math.floor(tonumber(d.type) or 0)
    if not ZombieEvent.get().active or not CrateTypes[i] then return AM.notify(src, 'Type de caisse introuvable.', 'error') end
    local placed = placeAuto(i, math.floor(num(d.count, 1, 30, 5)))
    broadcast()
    if placed == 0 then return AM.notify(src, 'Plus aucun emplacement libre dans la zone : utilise « Ici ».', 'error') end
    AM.notify(src, ('%d caisse(s) « %s » ajoutée(s).'):format(placed, CrateTypes[i].label), 'success')
end)

def('zombies_crate_here', function(src, d)
    local i = math.floor(tonumber(d.type) or 0)
    if not ZombieEvent.get().active or not CrateTypes[i] then return AM.notify(src, 'Type de caisse introuvable.', 'error') end
    local ped = GetPlayerPed(src)
    if ped == 0 then return end
    local c = GetEntityCoords(ped)
    addCrate(i, c.x, c.y, c.z)
    broadcast()
    AM.notify(src, ('Caisse « %s » posée à ta position.'):format(CrateTypes[i].label), 'success')
end)

def('zombies_crate_clear', function(src)
    local n = 0
    for id, c in pairs(Crates) do
        if not c.looted then n = n + 1 end
        Crates[id] = nil
    end
    broadcast()
    AM.notify(src, ('%d caisse(s) retirée(s). Les armes déjà prises seront reprises à la fin.'):format(n), 'success')
    AM.addLog(src, 'Caisses zombies retirées', tostring(n))
end)

def('zombies_reclaim_now', function(src)
    local n = 0
    for key, entry in pairs(Reclaim) do
        if not entry.active then
            for _, p in ipairs(GetPlayers()) do
                local id = tonumber(p)
                if Bridge.GetCharId(id) == key then applyReclaim(id, key, entry) n = n + 1 break end
            end
        end
    end
    AM.notify(src, n > 0 and ('Reprise effectuée chez %d joueur(s).'):format(n) or 'Personne à qui reprendre des armes pour le moment.', 'info')
end)

-- =========================================================
--  DONNÉES DU MENU
-- =========================================================
function ZombieLoot.AdminData()
    local types = {}
    for i, t in ipairs(CrateTypes) do
        local left, opened = 0, 0
        for _, c in pairs(Crates) do
            if c.type == i then
                if c.looted then opened = opened + 1 else left = left + 1 end
            end
        end
        local parts = {}
        for _, it in ipairs(t.contents) do parts[#parts + 1] = ('%dx %s'):format(it.count, Bridge.GetLabel(it.item) or it.item) end
        types[#types + 1] = { index = i, label = t.label, mode = t.mode, left = left, opened = opened, contents = table.concat(parts, ', '), blip = t.blip }
    end
    local looters = 0
    for _, e in pairs(Reclaim) do if e.active then looters = looters + 1 end end
    return { types = types, given = Given, looters = looters }
end

function ZombieLoot.PendingCount()
    local n = 0
    for _, e in pairs(Reclaim) do if not e.active then n = n + 1 end end
    return n
end
