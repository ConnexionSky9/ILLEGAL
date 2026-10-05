-- =========================================================
--  ELYZEA ILLÉGAL - GROUPES
--  Services réutilisables : chaque fonction valide tout ce qu'elle
--  reçoit et renvoie ok, message. L'appelant (menu staff ou tablette)
--  a déjà vérifié QUI a le droit de l'appeler.
-- =========================================================
Groups = {}
local U = Illegal.Utils
local creating = {}

local function templateFor(typ)
    local out = {}
    for _, gr in ipairs(Config.Templates[typ] or Config.Templates.gang) do
        out[#out + 1] = { name = gr.name, label = gr.label, level = gr.level, boss = gr.boss == true, perms = U.permSet(gr.perms) }
    end
    return out
end

-- Position actuelle d'un joueur (lue par le serveur, jamais envoyée par le client)
function Groups.positionOf(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    return { x = c.x + 0.0, y = c.y + 0.0, z = c.z - 1.0, h = GetEntityHeading(ped) + 0.0 }
end

-- data : name, label, type, description, color, pedModel, pedHere
function Groups.create(actor, data)
    local name = U.ident(data.name)
    if not name then return false, 'Nom interne invalide : 2 à 32 caractères, minuscules, chiffres ou _ (ex : bloods).' end
    local label = U.text(data.label, 64)
    if not label then return false, 'Donne un nom affiché au groupe.' end
    local typ = U.typeKey(data.type)
    if not typ then return false, 'Type de groupe invalide.' end
    local color = U.color(data.color) or '#e0433b'
    local description = U.text(data.description, 500, true)

    local ped
    if data.pedHere then
        local model = U.model(data.pedModel) or Config.Ped.defaultModel
        local pos = Groups.positionOf(actor.src)
        if not pos then return false, 'Position introuvable pour placer le PNJ.' end
        ped = { model = model, x = pos.x, y = pos.y, z = pos.z, h = pos.h, scenario = Config.Ped.scenario, menu = U.tabSet(nil) }
    end

    if creating[name] or Cache.byName(name) or DB.nameTaken(name) then return false, ('Le nom interne « %s » est déjà utilisé.'):format(name) end
    creating[name] = true
    local g = { name = name, label = label, type = typ, description = description, color = color,
        settings = { f5Tabs = U.tabSet(nil) }, createdBy = actor.name }
    local grades = templateFor(typ)
    local id, gradeRows = DB.createGroup(g, grades, ped)
    creating[name] = nil
    if not id then return false, 'Erreur de la base de données : groupe non créé.' end

    local group = Cache.newGroup({ id = id, name = name, label = label, type = typ, description = description, color = color,
        settings = json.encode(g.settings), created_by = actor.name, created = os.time() })
    local idByName = {}
    for _, r in ipairs(gradeRows) do idByName[r.name] = r.id end
    for _, gr in ipairs(grades) do
        gr.id, gr.groupId = idByName[gr.name], id
        if gr.id then group.grades[gr.id] = gr end
    end
    if ped then ped.version = 1 group.ped = ped end
    Cache.groups[id] = group

    Log(actor, id, 'Groupe créé', ('%s (%s, %s)'):format(label, name, U.typeLabel(typ)))
    if ped then Sync.peds() end
    return true, ('Groupe « %s » créé.'):format(label), group
end

-- data : label, type, description, color, f5Tabs
function Groups.update(actor, g, data)
    local label = U.text(data.label, 64)
    if not label then return false, 'Le nom affiché ne peut pas être vide.' end
    local typ = data.type ~= nil and U.typeKey(data.type) or g.type
    if not typ then return false, 'Type de groupe invalide.' end
    if typ ~= g.type and not actor.isAdmin then return false, 'Seul le staff peut changer le type du groupe.' end
    local color = U.color(data.color) or g.color
    local description = U.text(data.description, 500, true)
    local settings = { f5Tabs = data.f5Tabs ~= nil and U.tabSet(data.f5Tabs) or g.settings.f5Tabs }

    -- (une mise à jour sans changement renvoie 0 ligne : seule l'absence de réponse est une erreur)
    if DB.updateGroup(g.id, { label = label, type = typ, description = description, color = color, settings = settings }) == nil then
        return false, 'Erreur de la base de données.'
    end
    local renamed = label ~= g.label or color ~= g.color
    g.label, g.type, g.description, g.color, g.settings = label, typ, description, color, settings

    Log(actor, g.id, 'Groupe modifié', ('%s (%s)'):format(label, g.name))
    if renamed then Sync.allMembers(g) Sync.peds() if Stashes then Stashes.refresh(g) end end
    Sync.group(g.id)
    return true, 'Groupe enregistré.'
end

-- Suppression définitive : il faut renvoyer le nom interne exact (évite les erreurs)
function Groups.delete(actor, g, confirmName)
    if confirmName ~= g.name then return false, 'Confirmation incorrecte : tape le nom interne exact du groupe.' end
    if not DB.deleteGroup(g.id) then return false, 'Erreur de la base de données : groupe non supprimé.' end
    local members, hadPed, hadStash = {}, g.ped ~= nil, g.stash ~= nil
    for cid in pairs(g.members) do members[#members + 1] = cid end
    Cache.forgetGroup(g)

    for src, s in pairs(Sessions) do
        if s.groupId == g.id then Sessions[src] = nil TriggerClientEvent('illegal:client:close', src) end
    end
    for _, cid in ipairs(members) do Sync.player(cid) end
    if hadPed then Sync.peds() end
    if hadStash and Stashes then Stashes.sync() end
    Log(actor, nil, 'Groupe supprimé', ('%s (%s) · %d membre(s)'):format(g.label, g.name, #members))
    return true, ('Groupe « %s » supprimé.'):format(g.label)
end
