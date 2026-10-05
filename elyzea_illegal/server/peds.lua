-- =========================================================
--  ELYZEA ILLÉGAL - PNJ DES GROUPES
--  Un PNJ par groupe : modèle, position, heading, animation et
--  onglets de la tablette accessibles depuis lui. Les joueurs le
--  font apparaître localement uniquement quand ils sont proches.
-- =========================================================
Peds = {}
local U = Illegal.Utils

local function save(actor, g, ped, what)
    if DB.savePed(g.id, ped) == nil then return false, 'Erreur de la base de données.' end
    ped.version = ((g.ped and g.ped.version) or 0) + 1
    g.ped = ped
    Sync.group(g.id)
    Log(actor, g.id, 'PNJ ' .. what, ('%s : %s (%.1f, %.1f, %.1f · %.0f°)'):format(g.label, ped.model, ped.x, ped.y, ped.z, ped.h))
    Sync.peds()
    return true, 'PNJ enregistré.'
end

local function copy(p)
    return { model = p.model, x = p.x, y = p.y, z = p.z, h = p.h, scenario = p.scenario, menu = p.menu }
end

-- data : model, scenario, menu, x/y/z/h (ou useMyPosition)
function Peds.set(actor, g, data)
    local ped = g.ped and copy(g.ped) or { model = Config.Ped.defaultModel, scenario = Config.Ped.scenario, menu = U.tabSet(nil) }
    if data.model ~= nil then
        local model = U.model(data.model)
        if not model then return false, 'Modèle de PNJ invalide (ex : g_m_y_ballaeast_01).' end
        ped.model = model
    end
    if data.scenario ~= nil then
        local sc = U.text(data.scenario, 64, true)
        if sc ~= '' and not sc:match('^[%w_]+$') then return false, 'Animation invalide (ex : WORLD_HUMAN_SMOKING).' end
        ped.scenario = sc
    end
    if data.menu ~= nil then ped.menu = U.tabSet(data.menu) end

    if data.useMyPosition then
        local pos = Groups.positionOf(actor.src)
        if not pos then return false, 'Position introuvable.' end
        ped.x, ped.y, ped.z, ped.h = pos.x, pos.y, pos.z, pos.h
    elseif data.x ~= nil then
        local c = U.coords(data)
        if not c then return false, 'Coordonnées invalides.' end
        ped.x, ped.y, ped.z, ped.h = c.x, c.y, c.z, c.h
    elseif data.h ~= nil and g.ped then
        local h = U.number(data.h, -720, 720)
        if not h then return false, 'Heading invalide (0 à 360).' end
        ped.h = h % 360.0
    end
    if not ped.x then return false, 'Place le PNJ : « Placer à ma position » ou coordonnées.' end
    return save(actor, g, ped, g.ped and 'modifié' or 'ajouté')
end

function Peds.remove(actor, g)
    if not g.ped then return false, 'Ce groupe n\'a pas de PNJ.' end
    if DB.deletePed(g.id) == nil then return false, 'Erreur de la base de données.' end
    g.ped = nil
    for src, s in pairs(Sessions) do
        if s.groupId == g.id and s.via == 'ped' then Sessions[src] = nil TriggerClientEvent('illegal:client:close', src) end
    end
    Log(actor, g.id, 'PNJ supprimé', g.label)
    Sync.peds()
    return true, 'PNJ supprimé.'
end

-- Recrée le PNJ chez tous les joueurs (bloqué, disparu…)
function Peds.respawn(actor, g)
    if not g.ped then return false, 'Ce groupe n\'a pas de PNJ.' end
    g.ped.version = g.ped.version + 1
    Sync.peds()
    Log(actor, g.id, 'PNJ respawn', g.label)
    return true, 'PNJ réapparu.'
end

-- Le joueur est-il vraiment à côté du PNJ de ce groupe ? (vérifié par le serveur)
function Peds.isNear(src, g)
    if not g.ped then return false end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    return #(GetEntityCoords(ped) - vector3(g.ped.x, g.ped.y, g.ped.z + 1.0)) <= Config.Ped.serverDistance
end
