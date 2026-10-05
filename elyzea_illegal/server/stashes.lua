-- =========================================================
--  ELYZEA ILLÉGAL - COFFRE DU GROUPE
--  Un coffre par groupe, placé par le staff (objet, poids, places).
--  Inventaire ox_inventory « illegal_stash_<id du groupe> ».
--  Ouverture : membre du groupe, permission « stash » de son grade
--  (le OG la donne aux grades qu'il veut), à côté du coffre.
--  Le serveur vérifie tout ; un hook ox_inventory bloque aussi
--  toute ouverture qui ne passerait pas par ici.
-- =========================================================
Stashes = {}
local U = Illegal.Utils
local S = Config.Stash

function Stashes.invId(groupId) return ('illegal_stash_%d'):format(groupId) end

local function oxStarted() return GetResourceState('ox_inventory') == 'started' end

local function register(g)
    if not g.stash or not oxStarted() then return end
    local s = g.stash
    pcall(function()
        exports.ox_inventory:RegisterStash(Stashes.invId(g.id), ('%s · %s'):format(g.label, s.label), s.slots, s.weight * 1000, false, nil,
            vector3(s.x, s.y, s.z))
    end)
end

-- Qui peut ouvrir le coffre de ce groupe, et est-il à côté ?
function Stashes.canOpen(src, g)
    if not g or not g.stash then return false end
    local mg, _, grade = Cache.membership(Players.cid(src))
    if not mg or mg.id ~= g.id or not Cache.hasPerm(grade, 'stash') then return false end
    local pos = Groups.positionOf(src)
    if not pos then return false end
    return #(vector3(pos.x, pos.y, pos.z + 1.0) - vector3(g.stash.x, g.stash.y, g.stash.z + 0.5)) <= S.interactDistance + 2.0
end

-- Hook ox_inventory : aucune ouverture d'un coffre de groupe sans les bons droits
local hookId
local function registerHook()
    if not oxStarted() then return end
    local ok, id = pcall(function()
        return exports.ox_inventory:registerHook('openInventory', function(payload)
            local gid = tonumber(tostring(payload.inventoryId or ''):match('^illegal_stash_(%d+)$'))
            if not gid then return end
            return Stashes.canOpen(payload.source, Cache.group(gid))
        end, { inventoryFilter = { '^illegal_stash_%d+$' } })
    end)
    if ok then hookId = id end
end

function Stashes.registerAll()
    for _, g in pairs(Cache.groups) do register(g) end
    registerHook()
end

AddEventHandler('onServerResourceStart', function(res)
    if res == 'ox_inventory' and Cache.ready then SetTimeout(1000, Stashes.registerAll) end
end)
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and hookId then pcall(function() exports.ox_inventory:removeHooks(hookId) end) end
end)

-- ---------------------------------------------------------
--  Synchronisation : position et apparence (ce que tout le monde voit en jeu)
-- ---------------------------------------------------------
function Stashes.list()
    local list = {}
    for _, g in pairs(Cache.groups) do
        local s = g.stash
        if s then
            list[#list + 1] = { groupId = g.id, label = ('%s · %s'):format(g.label, s.label), model = s.model, x = s.x, y = s.y, z = s.z, h = s.h, version = s.version }
        end
    end
    return list
end

function Stashes.sync(target)
    TriggerClientEvent('illegal:client:stashes', target or -1, Stashes.list())
end

-- Groupe renommé : nom de l'inventaire et invite [E] à jour
function Stashes.refresh(g)
    if not g.stash then return end
    register(g)
    Stashes.sync()
end

-- ---------------------------------------------------------
--  Staff : placer / modifier / supprimer
--  data : label, model, weight (kg), slots, useMyPosition | x, y, z, h
-- ---------------------------------------------------------
local function validModel(m)
    m = U.model(m)
    return m
end

function Stashes.set(actor, g, data)
    local cur = g.stash
    local s = cur and { label = cur.label, model = cur.model, x = cur.x, y = cur.y, z = cur.z, h = cur.h, weight = cur.weight, slots = cur.slots }
        or { label = 'Coffre', model = S.models[1].model, weight = S.defaultWeight, slots = S.defaultSlots }
    if data.label ~= nil then s.label = U.text(data.label, 64) or 'Coffre' end
    if data.model ~= nil then
        s.model = validModel(data.model)
        if not s.model then return false, 'Modèle d\'objet invalide (ex : prop_ld_int_safe_01).' end
    end
    if data.weight ~= nil then
        s.weight = U.int(data.weight, 1, S.maxWeight)
        if not s.weight then return false, ('Poids invalide (1 à %d kg).'):format(S.maxWeight) end
    end
    if data.slots ~= nil then
        s.slots = U.int(data.slots, 1, S.maxSlots)
        if not s.slots then return false, ('Nombre de places invalide (1 à %d).'):format(S.maxSlots) end
    end
    if data.useMyPosition then
        local pos = Groups.positionOf(actor.src)
        if not pos then return false, 'Position introuvable.' end
        s.x, s.y, s.z, s.h = pos.x, pos.y, pos.z, pos.h
    elseif data.x ~= nil then
        local c = U.coords(data)
        if not c then return false, 'Coordonnées invalides.' end
        s.x, s.y, s.z, s.h = c.x, c.y, c.z, c.h
    end
    if not s.x then return false, 'Place le coffre : « Placer à ma position ».' end

    if DB.saveStash(g.id, s) == nil then return false, 'Erreur de la base de données.' end
    s.version = ((cur and cur.version) or 0) + 1
    g.stash = s
    register(g)
    Stashes.sync()
    Sync.group(g.id)
    Log(actor, g.id, cur and 'Coffre modifié' or 'Coffre placé', ('%s : %s · %d kg · %d places (%.1f, %.1f, %.1f)'):format(g.label, s.label, s.weight, s.slots, s.x, s.y, s.z))
    return true, cur and 'Coffre enregistré.' or 'Coffre placé.'
end

-- Le contenu reste enregistré dans ox_inventory : replacer un coffre le retrouve
function Stashes.remove(actor, g)
    if not g.stash then return false, 'Ce groupe n\'a pas de coffre.' end
    if DB.deleteStash(g.id) == nil then return false, 'Erreur de la base de données.' end
    g.stash = nil
    Stashes.sync()
    Sync.group(g.id)
    Log(actor, g.id, 'Coffre supprimé', g.label)
    return true, 'Coffre supprimé (son contenu est conservé si tu en replaces un).'
end

-- ---------------------------------------------------------
--  Joueur : [E] à côté du coffre
-- ---------------------------------------------------------
RegisterNetEvent('illegal:server:openStash', function(groupId)
    local src = source
    if not Players.rateLimit(src, 'stash', 3, 2000) then return end
    local g = Cache.group(U.int(groupId, 1))
    if not g or not g.stash then return end
    local mg, _, grade = Cache.membership(Players.cid(src))
    if not mg or mg.id ~= g.id then return Players.notify(src, 'Ce coffre n\'appartient pas à ton groupe.', 'error') end
    if not Cache.hasPerm(grade, 'stash') then return Players.notify(src, 'Ton grade n\'a pas accès au coffre du groupe.', 'error') end
    if not Stashes.canOpen(src, g) then return end   -- trop loin
    if not oxStarted() then return Players.notify(src, 'ox_inventory n\'est pas démarré.', 'error') end
    register(g)
    pcall(function() exports.ox_inventory:forceOpenInventory(src, 'stash', Stashes.invId(g.id)) end)
end)
