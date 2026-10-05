-- =========================================================
--  PONT INVENTAIRE
--  Bridge.AddItem(src, item, count)    -> true | false, raison
--  Bridge.RemoveItem(src, item, count) -> true | false
--  Bridge.GetItemCount(src, item)      -> nombre
--  Bridge.GetLabel(item)               -> nom affiché
--  Les armes (WEAPON_XXX) sont converties automatiquement :
--  ox = WEAPON_PISTOL, qb = weapon_pistol, esx = addWeapon
-- =========================================================
Bridge = {}
local mode

local function detect()
    if mode then return mode end
    if Config.Inventory ~= 'auto' then
        mode = Config.Inventory
    elseif GetResourceState('ox_inventory') == 'started' then
        mode = 'ox'
    elseif GetResourceState('qs-inventory') == 'started' then
        mode = 'qs'
    elseif GetResourceState('qb-core') == 'started' then
        mode = 'qb'
    elseif GetResourceState('es_extended') == 'started' then
        mode = 'esx'
    else
        mode = 'none'
    end
    print(('[AdminMenu] Inventaire détecté : %s'):format(mode))
    return mode
end

local function isWeapon(item) return item:upper():sub(1, 7) == 'WEAPON_' end

local function normalize(item, m)
    if not isWeapon(item) then return item end
    if m == 'qb' then return item:lower() end
    return item:upper()
end

local QB, ESX
local function qb() QB = QB or exports['qb-core']:GetCoreObject() return QB end
local function esx() ESX = ESX or exports['es_extended']:getSharedObject() return ESX end

-- ---------------------------------------------------------
function Bridge.GetItemCount(src, item)
    local m = detect()
    item = normalize(item, m)
    local ok, n = pcall(function()
        if m == 'ox' then
            return exports.ox_inventory:Search(src, 'count', item) or 0
        elseif m == 'qs' then
            return exports['qs-inventory']:GetItemTotalAmount(src, item) or 0
        elseif m == 'qb' then
            local P = qb().Functions.GetPlayer(src)
            if not P then return 0 end
            local total = 0
            for _, it in pairs(P.PlayerData.items or {}) do
                if it and it.name == item then total = total + (it.amount or it.count or 0) end
            end
            return total
        elseif m == 'esx' then
            local x = esx().GetPlayerFromId(src)
            if not x then return 0 end
            if isWeapon(item) then return x.hasWeapon(item) and 1 or 0 end
            local it = x.getInventoryItem(item)
            return it and it.count or 0
        elseif m == 'custom' and Config.CustomGetItemCount then
            return Config.CustomGetItemCount(src, item)
        end
        return 0
    end)
    return ok and (tonumber(n) or 0) or 0
end

function Bridge.RemoveItem(src, item, count)
    local m = detect()
    item = normalize(item, m)
    local ok, res = pcall(function()
        if m == 'ox' then
            return exports.ox_inventory:RemoveItem(src, item, count)
        elseif m == 'qs' then
            return exports['qs-inventory']:RemoveItem(src, item, count) and true or false
        elseif m == 'qb' then
            local P = qb().Functions.GetPlayer(src)
            if not P or not P.Functions.RemoveItem(item, count) then return false end
            local def = qb().Shared.Items[item]
            if def then
                TriggerClientEvent('inventory:client:ItemBox', src, def, 'remove', count)
                TriggerClientEvent('qb-inventory:client:ItemBox', src, def, 'remove', count)
            end
            return true
        elseif m == 'esx' then
            local x = esx().GetPlayerFromId(src)
            if not x then return false end
            if isWeapon(item) then x.removeWeapon(item) else x.removeInventoryItem(item, count) end
            return true
        elseif m == 'custom' and Config.CustomRemoveItem then
            return Config.CustomRemoveItem(src, item, count)
        end
        return false
    end)
    return ok and res and true or false
end

function Bridge.AddItem(src, item, count, metadata)
    local m = detect()
    item = normalize(item, m)
    local ok, a, b = pcall(function()
        if m == 'ox' then
            if not exports.ox_inventory:Items(item) then return false, 'unknown' end
            if not exports.ox_inventory:CanCarryItem(src, item, count) then return false, 'full' end
            return exports.ox_inventory:AddItem(src, item, count, metadata) and true or false, 'full'

        elseif m == 'qs' then
            local list = exports['qs-inventory']:GetItemList() or {}
            if not list[item] then return false, 'unknown' end
            return exports['qs-inventory']:AddItem(src, item, count, nil, metadata) and true or false, 'full'

        elseif m == 'qb' then
            local P = qb().Functions.GetPlayer(src)
            if not P then return false, 'noplayer' end
            local def = qb().Shared.Items[item]
            if not def then return false, 'unknown' end
            if not P.Functions.AddItem(item, count, false, metadata) then return false, 'full' end
            TriggerClientEvent('inventory:client:ItemBox', src, def, 'add', count)
            TriggerClientEvent('qb-inventory:client:ItemBox', src, def, 'add', count)
            return true

        elseif m == 'esx' then
            local x = esx().GetPlayerFromId(src)
            if not x then return false, 'noplayer' end
            if isWeapon(item) then
                if x.hasWeapon(item) then return false, 'hasweapon' end
                x.addWeapon(item, 0)
                return true
            end
            if x.canCarryItem and not x.canCarryItem(item, count) then return false, 'full' end
            x.addInventoryItem(item, count)
            return true

        elseif m == 'custom' then
            return Config.CustomAddItem(src, item, count)
        end
        return false, 'noinv'
    end)
    if not ok then
        print(('^1[AdminMenu] Erreur inventaire (%s) : %s^7'):format(item, tostring(a)))
        return false, 'noinv'
    end
    return a, b
end

-- ---------------------------------------------------------
--  Objets marqués (caisses de l'événement zombies)
--  ox_inventory et qb-inventory gardent une étiquette sur l'objet :
--  on peut reprendre EXACTEMENT ces objets, même s'ils ont changé de main.
-- ---------------------------------------------------------
function Bridge.SupportsTags()
    local m = detect()
    return m == 'ox' or m == 'qb'
end

-- Retire tous les objets portant l'étiquette tag. Renvoie { [objet] = quantité retirée }
function Bridge.RemoveTagged(src, tag)
    local m = detect()
    local removed = {}
    pcall(function()
        if m == 'ox' then
            for _, it in pairs(exports.ox_inventory:GetInventoryItems(src) or {}) do
                if type(it) == 'table' and it.metadata and it.metadata.am_event == tag then
                    if exports.ox_inventory:RemoveItem(src, it.name, it.count, nil, it.slot) then
                        removed[it.name] = (removed[it.name] or 0) + it.count
                    end
                end
            end
        elseif m == 'qb' then
            local P = qb().Functions.GetPlayer(src)
            if not P then return end
            for slot, it in pairs(P.PlayerData.items or {}) do
                if type(it) == 'table' and it.info and type(it.info) == 'table' and it.info.am_event == tag then
                    local n = it.amount or it.count or 1
                    if P.Functions.RemoveItem(it.name, n, slot) then removed[it.name] = (removed[it.name] or 0) + n end
                end
            end
        end
    end)
    return removed
end

local labelCache = {}
function Bridge.GetLabel(item)
    if labelCache[item] then return labelCache[item] end
    local m = detect()
    local n = normalize(item, m)
    local ok, label = pcall(function()
        if m == 'ox' then
            local it = exports.ox_inventory:Items(n)
            return it and it.label
        elseif m == 'qb' then
            local it = qb().Shared.Items[n]
            return it and it.label
        elseif m == 'esx' then
            if isWeapon(n) then return esx().GetWeaponLabel(n) end
            return esx().GetItemLabel(n)
        end
    end)
    label = (ok and label) or item
    labelCache[item] = label
    return label
end

Bridge.Errors = {
    full      = 'Inventaire plein.',
    unknown   = "Cet objet n'existe pas dans l'inventaire du serveur. Préviens le staff.",
    noplayer  = 'Personnage non chargé.',
    noinv     = 'Aucun inventaire configuré sur le serveur. Préviens le staff.',
    hasweapon = 'Tu possèdes déjà cette arme.',
}

-- =========================================================
--  ARGENT ET MÉTIERS (Qbox, QBCore, ESX)
--  kind : 'cash', 'bank' ou 'item' (item = nom de l'objet monnaie)
-- =========================================================
local function fw()
    if GetResourceState('qbx_core') == 'started' then return 'qbx' end
    if GetResourceState('qb-core') == 'started' then return 'qb' end
    if GetResourceState('es_extended') == 'started' then return 'esx' end
    return 'none'
end

local function qbxPlayer(src)
    local ok, P = pcall(function() return exports.qbx_core:GetPlayer(src) end)
    return ok and P or nil
end

function Bridge.GetMoney(src, kind, item)
    if kind == 'item' then return Bridge.GetItemCount(src, item) end
    local f = fw()
    local ok, n = pcall(function()
        if f == 'qbx' then
            local ok2, v = pcall(function() return exports.qbx_core:GetMoney(src, kind) end)
            if ok2 and v then return v end
            local P = qbxPlayer(src)
            return P and P.PlayerData.money[kind] or 0
        elseif f == 'qb' then
            local P = qb().Functions.GetPlayer(src)
            return P and P.PlayerData.money[kind] or 0
        elseif f == 'esx' then
            local x = esx().GetPlayerFromId(src)
            local a = x and x.getAccount(kind == 'cash' and 'money' or 'bank')
            return a and a.money or 0
        end
        return 0
    end)
    return ok and (tonumber(n) or 0) or 0
end

local function moneyOp(src, kind, item, amount, add, reason)
    if amount <= 0 then return true end
    if kind == 'item' then
        if add then return (Bridge.AddItem(src, item, amount)) end
        return Bridge.RemoveItem(src, item, amount)
    end
    local f = fw()
    local ok, res = pcall(function()
        if f == 'qbx' then
            local fn = add and 'AddMoney' or 'RemoveMoney'
            local ok2, v = pcall(function() return exports.qbx_core[fn](exports.qbx_core, src, kind, amount, reason) end)
            if ok2 and v ~= nil then return v end
            local P = qbxPlayer(src)
            return P and P.Functions[fn](kind, amount, reason)
        elseif f == 'qb' then
            local P = qb().Functions.GetPlayer(src)
            if not P then return false end
            if add then return P.Functions.AddMoney(kind, amount, reason) end
            return P.Functions.RemoveMoney(kind, amount, reason)
        elseif f == 'esx' then
            local x = esx().GetPlayerFromId(src)
            if not x then return false end
            local acc = kind == 'cash' and 'money' or 'bank'
            if add then x.addAccountMoney(acc, amount) else x.removeAccountMoney(acc, amount) end
            return true
        end
        return false
    end)
    return ok and res ~= false and res ~= nil
end

function Bridge.AddMoney(src, kind, item, amount, reason) return moneyOp(src, kind, item, amount, true, reason) end
function Bridge.RemoveMoney(src, kind, item, amount, reason) return moneyOp(src, kind, item, amount, false, reason) end

-- Joueur policier en service ?
local policeSet
function Bridge.IsPolice(src)
    if not policeSet then
        policeSet = {}
        for _, j in ipairs(Config.PoliceJobs or {}) do policeSet[j] = true end
    end
    local f = fw()
    local ok, res = pcall(function()
        local job
        if f == 'qbx' then
            local P = qbxPlayer(src)
            job = P and P.PlayerData.job
            return job and policeSet[job.name] and job.onduty ~= false
        elseif f == 'qb' then
            local P = qb().Functions.GetPlayer(src)
            job = P and P.PlayerData.job
            return job and policeSet[job.name] and job.onduty ~= false
        elseif f == 'esx' then
            local x = esx().GetPlayerFromId(src)
            return x and x.job and policeSet[x.job.name]
        end
        return false
    end)
    return ok and res == true
end

-- =========================================================
--  LISTE DE TOUS LES OBJETS DE L'INVENTAIRE (armes comprises)
--  Mise en cache 60 s. image = lien direct vers l'icône de l'inventaire.
-- =========================================================
function Bridge.Mode() return detect() end

local itemsCache, itemsCacheTime = nil, -100000
-- Liste COMPLÈTE des objets connus par l'inventaire du serveur (armes et munitions comprises).
-- force = true : ignore le cache (bouton « Recharger la liste » du menu).
function Bridge.GetAllItems(force)
    if not force and itemsCache and GetGameTimer() - itemsCacheTime < 60000 then return itemsCache end
    local m = detect()
    local list, seen = {}, {}
    local function img(base, name, custom)
        if type(custom) == 'string' and (custom:find('^https?://') or custom:find('^nui://')) then return custom end
        if not base then return '' end
        return base .. (type(custom) == 'string' and custom ~= '' and custom or (name .. '.png'))
    end
    local function kindOf(name, d)
        local n = tostring(name):lower()
        if (type(d) == 'table' and (d.weapon or d.type == 'weapon')) or n:sub(1, 7) == 'weapon_' then return 'weapon' end
        if (type(d) == 'table' and (d.ammo or d.type == 'ammo')) or n:find('^ammo') or n:find('_ammo$') then return 'ammo' end
        return 'other'
    end
    local function add(name, d, base, image)
        if type(name) ~= 'string' or name == '' or seen[name:lower()] then return end
        seen[name:lower()] = true
        d = type(d) == 'table' and d or {}
        list[#list + 1] = {
            name = name, label = tostring(d.label or name), weight = tonumber(d.weight) or 0,
            image = img(base, name, image), kind = kindOf(name, d),
        }
    end
    local ok, err = pcall(function()
        if m == 'ox' then
            for name, d in pairs(exports.ox_inventory:Items() or {}) do
                add(name, d, 'nui://ox_inventory/web/images/', d.client and d.client.image)
            end
        elseif m == 'qs' then
            for name, d in pairs(exports['qs-inventory']:GetItemList() or {}) do
                add(name, d, 'nui://qs-inventory/html/images/', d.image)
            end
        elseif m == 'qb' then
            for name, d in pairs(qb().Shared.Items or {}) do
                add(name, d, 'nui://qb-inventory/html/images/', d.image)
            end
            -- Armes déclarées à part (certaines versions de qb-core)
            for _, d in pairs(qb().Shared.Weapons or {}) do
                if type(d) == 'table' and d.name then add(d.name, d, 'nui://qb-inventory/html/images/', d.image) end
            end
        elseif m == 'esx' then
            for name, d in pairs(esx().Items or {}) do add(name, d) end
            for _, w in ipairs(esx().GetWeaponList and esx().GetWeaponList() or {}) do add(w.name, { label = w.label, weapon = true }) end
        elseif m == 'custom' and Config.CustomGetItemList then
            for _, d in ipairs(Config.CustomGetItemList() or {}) do add(d.name, d, nil, d.image) end
        end
    end)
    if not ok then print(('^1[AdminMenu] Lecture de la liste des objets impossible : %s^7'):format(tostring(err))) end
    table.sort(list, function(a, b) return a.label:lower() < b.label:lower() end)
    itemsCache, itemsCacheTime = list, GetGameTimer()
    print(('[AdminMenu] %d objets chargés depuis l\'inventaire (%s).'):format(#list, m))
    return list
end

function Bridge.ItemExists(name)
    for _, it in ipairs(Bridge.GetAllItems()) do
        if it.name == name or it.name:lower() == name:lower() then return true, it end
    end
    return false
end


-- =========================================================
--  PERSONNAGE (Qbox / QBCore : citizenid, ESX : identifier)
--  La propriété d'une porte suit le personnage, pas le compte.
-- =========================================================
function Bridge.GetCharId(src)
    local f = fw()
    local ok, id = pcall(function()
        if f == 'qbx' then
            local P = qbxPlayer(src)
            return P and P.PlayerData.citizenid
        elseif f == 'qb' then
            local P = qb().Functions.GetPlayer(src)
            return P and P.PlayerData.citizenid
        elseif f == 'esx' then
            local x = esx().GetPlayerFromId(src)
            return x and x.identifier
        end
    end)
    if ok and id then return tostring(id) end
    for _, i in ipairs(GetPlayerIdentifiers(src) or {}) do
        if i:sub(1, 8) == 'license:' then return i end
    end
end

function Bridge.GetCharName(src)
    local f = fw()
    local ok, name = pcall(function()
        if f == 'qbx' or f == 'qb' then
            local P = f == 'qbx' and qbxPlayer(src) or qb().Functions.GetPlayer(src)
            local c = P and P.PlayerData.charinfo
            return c and (c.firstname .. ' ' .. c.lastname)
        elseif f == 'esx' then
            local x = esx().GetPlayerFromId(src)
            return x and x.getName()
        end
    end)
    return (ok and name) or GetPlayerName(src) or ('#' .. src)
end

-- Tous les métiers déclarés sur le serveur, avec leurs grades (mis en cache 10 s).
-- Un métier créé plus tard (ex. par elyzea_ems) apparaît donc tout seul.
local jobsCache, jobsTime = nil, -100000
local function gradeList(grades)
    local out = {}
    for k, g in pairs(type(grades) == 'table' and grades or {}) do
        local lvl = tonumber(k) or tonumber(type(g) == 'table' and (g.grade or g.level))
        if lvl then
            local label = type(g) == 'table' and (g.label or g.name) or tostring(g)
            out[#out + 1] = { level = lvl, label = tostring(label or ('Grade ' .. lvl)) }
        end
    end
    table.sort(out, function(a, b) return a.level < b.level end)
    return out
end
function Bridge.GetJobs()
    if jobsCache and GetGameTimer() - jobsTime < 10000 then return jobsCache end
    local f = fw()
    local ok, raw = pcall(function()
        if f == 'qbx' then return exports.qbx_core:GetJobs() end
        if f == 'qb' then return qb().Shared.Jobs end
        if f == 'esx' then return esx().GetJobs() end
    end)
    local list = {}
    if ok and type(raw) == 'table' then
        for name, j in pairs(raw) do
            if type(j) == 'table' then
                list[#list + 1] = { name = tostring(j.name or name), label = tostring(j.label or name), grades = gradeList(j.grades) }
            end
        end
    end
    table.sort(list, function(a, b) return a.label:lower() < b.label:lower() end)
    jobsCache, jobsTime = list, GetGameTimer()
    return list
end

-- Groupes illégaux (gangs) déclarés sur le serveur, avec leurs grades (Qbox / QBCore).
local gangsCache, gangsTime = nil, -100000
function Bridge.GetGangs()
    if gangsCache and GetGameTimer() - gangsTime < 10000 then return gangsCache end
    local f = fw()
    local ok, raw = pcall(function()
        if f == 'qbx' then return exports.qbx_core:GetGangs() end
        if f == 'qb' then return qb().Shared.Gangs end
    end)
    local list = {}
    if ok and type(raw) == 'table' then
        for name, g in pairs(raw) do
            if type(g) == 'table' and name ~= 'none' then
                list[#list + 1] = { name = tostring(g.name or name), label = tostring(g.label or name), grades = gradeList(g.grades) }
            end
        end
    end
    table.sort(list, function(a, b) return a.label:lower() < b.label:lower() end)
    gangsCache, gangsTime = list, GetGameTimer()
    return list
end

-- Gang du joueur : nom et grade. nil si aucun.
function Bridge.GetGang(src)
    local f = fw()
    local ok, name, grade = pcall(function()
        if f == 'qbx' or f == 'qb' then
            local P = f == 'qbx' and qbxPlayer(src) or qb().Functions.GetPlayer(src)
            local g = P and P.PlayerData.gang
            if not g or g.name == 'none' then return nil end
            return g.name, (type(g.grade) == 'table' and (g.grade.level or 0)) or tonumber(g.grade) or 0
        end
    end)
    if not ok then return nil end
    return name, grade or 0
end

-- Métier du joueur : nom, grade (niveau) et en service. nil si inconnu.
function Bridge.GetJob(src)
    local f = fw()
    local ok, name, grade, duty = pcall(function()
        if f == 'qbx' or f == 'qb' then
            local P = f == 'qbx' and qbxPlayer(src) or qb().Functions.GetPlayer(src)
            local j = P and P.PlayerData.job
            if not j then return nil end
            return j.name, (type(j.grade) == 'table' and (j.grade.level or 0)) or tonumber(j.grade) or 0, j.onduty ~= false
        elseif f == 'esx' then
            local x = esx().GetPlayerFromId(src)
            return x and x.job and x.job.name, x and x.job and x.job.grade or 0, true
        end
    end)
    if not ok then return nil end
    return name, grade or 0, duty
end

-- Change le métier principal du joueur. Renvoie true si réussi.
function Bridge.SetJob(src, job, grade)
    local f = fw()
    local ok, res = pcall(function()
        if f == 'qbx' then
            local P = qbxPlayer(src)
            if not P then return false end
            P.Functions.SetJob(job, grade)
            return true
        elseif f == 'qb' then
            local P = qb().Functions.GetPlayer(src)
            return P ~= nil and P.Functions.SetJob(job, grade) ~= false
        elseif f == 'esx' then
            local x = esx().GetPlayerFromId(src)
            if not x then return false end
            x.setJob(job, grade)
            return true
        end
        return false
    end)
    return ok and res == true
end

-- Retire un métier de la liste des métiers du personnage (Qbox multi-métiers). Sans effet ailleurs.
function Bridge.RemoveFromJob(src, job)
    if fw() ~= 'qbx' then return end
    local cid = Bridge.GetCharId(src)
    if cid then pcall(function() exports.qbx_core:RemovePlayerFromJob(cid, job) end) end
end

-- =========================================================
--  BESOINS (faim, soif, stress) : lecture / écriture (Qbox, QBCore)
--  ESX (esx_status) est géré côté client.
-- =========================================================
function Bridge.GetNeeds(src)
    local f = fw()
    if f ~= 'qbx' and f ~= 'qb' then return nil end
    local ok, md = pcall(function()
        local P = f == 'qbx' and qbxPlayer(src) or qb().Functions.GetPlayer(src)
        return P and P.PlayerData.metadata
    end)
    if not ok or not md then return nil end
    return { hunger = tonumber(md.hunger), thirst = tonumber(md.thirst), stress = tonumber(md.stress) }
end

function Bridge.SetNeeds(src, values)
    local f = fw()
    if f ~= 'qbx' and f ~= 'qb' then return end
    pcall(function()
        local P = f == 'qbx' and qbxPlayer(src) or qb().Functions.GetPlayer(src)
        if not P then return end
        for key, value in pairs(values) do
            if f == 'qbx' then
                local ok = pcall(function() exports.qbx_core:SetMetadata(src, key, value) end)
                if not ok then P.Functions.SetMetaData(key, value) end
            else
                P.Functions.SetMetaData(key, value)
            end
        end
        local md = P.PlayerData.metadata or {}
        TriggerClientEvent('hud:client:UpdateNeeds', src, md.hunger or values.hunger, md.thirst or values.thirst)
        if values.stress then TriggerClientEvent('hud:client:UpdateStress', src, values.stress) end
    end)
end
