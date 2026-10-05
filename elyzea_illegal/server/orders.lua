-- =========================================================
--  ELYZEA ILLÉGAL - COMMANDES ILLÉGALES
--  Catalogue : commandes du groupe (créées par ses grades autorisés
--  ou par le staff) + commandes proposées à tous (staff uniquement).
--  Seul le staff peut lier une commande à un objet d'inventaire livré.
--
--  Cycle : un membre passe commande (en attente, rien n'est payé)
--          → un grade autorisé valide : le groupe paie
--          → objet à récupérer dans la tablette (ou livrée directement, RP)
-- =========================================================
Orders = {}
local U = Illegal.Utils

local function validPayment(p) return p == 'clean' or p == 'dirty' or p == 'both' end

-- data : name, description, category, price, payment, available, item, itemCount
local function readOrder(actor, data, current)
    local name = U.text(data.name, 64)
    if not name then return nil, 'Donne un nom à la commande.' end
    local category = U.category(data.category)
    if not category then return nil, 'Type de commande invalide.' end
    local price = U.int(data.price, 0, Config.MaxAmount)
    if not price then return nil, 'Prix invalide.' end
    local payment = validPayment(data.payment) and data.payment or nil
    if not payment then return nil, 'Paiement invalide (argent propre, sale ou les deux).' end
    local o = {
        name = name, description = U.text(data.description, 500, true), category = category, price = price, payment = payment,
        available = data.available ~= false and data.available ~= 0 and data.available ~= '0' and data.available ~= 'false',
        item = current and current.item or nil, itemCount = current and current.itemCount or 1,
    }
    if actor.isAdmin then
        local item = U.text(data.item, 64, true)
        if item ~= '' and not item:match('^[%w_]+$') then return nil, 'Nom d\'objet invalide (ex : weapon_pistol).' end
        o.item = item ~= '' and item or nil
        o.itemCount = U.int(data.itemCount, 1, 1000) or 1
    end
    return o
end

-- g = nil : commande proposée à tous les groupes (staff uniquement)
function Orders.create(actor, g, data)
    if not g and not actor.isAdmin then return false, 'Action réservée au staff.' end
    local o, err = readOrder(actor, data)
    if not o then return false, err end
    o.groupId, o.createdBy = g and g.id or nil, actor.name
    local id = DB.insertOrder(o)
    if not id then return false, 'Erreur de la base de données.' end
    o.id = id
    Cache.orders[id] = o
    Log(actor, g and g.id or nil, 'Commande créée', ('%s : %s · %s (%s)'):format(g and g.label or 'Tous les groupes', o.name, U.money(o.price), Illegal.Payments[o.payment]))
    if g then Sync.group(g.id) else for id2 in pairs(Cache.groups) do Sync.group(id2) end end
    return true, ('Commande « %s » créée.'):format(o.name)
end

-- Un joueur ne modifie que les commandes de son groupe ; le staff, toutes
local function editable(actor, g, o)
    if not o then return false end
    if actor.isAdmin then return o.groupId == nil or (g and o.groupId == g.id) end
    return g ~= nil and o.groupId == g.id
end

function Orders.update(actor, g, orderId, data)
    local cur = Cache.orders[tonumber(orderId) or -1]
    if not editable(actor, g, cur) then return false, 'Commande introuvable.' end
    local o, err = readOrder(actor, data, cur)
    if not o then return false, err end
    o.id, o.groupId, o.createdBy = cur.id, cur.groupId, cur.createdBy
    if DB.updateOrder(o) == nil then return false, 'Erreur de la base de données.' end
    Cache.orders[o.id] = o
    Log(actor, o.groupId, 'Commande modifiée', ('%s · %s%s'):format(o.name, U.money(o.price), o.available and '' or ' (indisponible)'))
    if o.groupId then Sync.group(o.groupId) else for id2 in pairs(Cache.groups) do Sync.group(id2) end end
    return true, ('Commande « %s » enregistrée.'):format(o.name)
end

function Orders.delete(actor, g, orderId)
    local cur = Cache.orders[tonumber(orderId) or -1]
    if not editable(actor, g, cur) then return false, 'Commande introuvable.' end
    if DB.deleteOrder(cur.id) == nil then return false, 'Erreur de la base de données.' end
    Cache.orders[cur.id] = nil
    Log(actor, cur.groupId, 'Commande supprimée', cur.name)
    if cur.groupId then Sync.group(cur.groupId) else for id2 in pairs(Cache.groups) do Sync.group(id2) end end
    return true, ('Commande « %s » supprimée.'):format(cur.name)
end

-- ---------------------------------------------------------
--  Demandes de commande
-- ---------------------------------------------------------
function Orders.place(actor, g, orderId, quantity, account)
    local o = Cache.orders[tonumber(orderId) or -1]
    if not o or (o.groupId ~= nil and o.groupId ~= g.id) then return false, 'Commande introuvable.' end
    if not o.available then return false, 'Cette commande n\'est pas disponible.' end
    quantity = U.int(quantity, 1, Config.OrderMaxQuantity)
    if not quantity then return false, ('Quantité invalide (1 à %d).'):format(Config.OrderMaxQuantity) end
    if o.payment ~= 'both' then account = o.payment end
    if account ~= 'clean' and account ~= 'dirty' then return false, 'Choisis le compte de paiement.' end
    local total = o.price * quantity
    if total > Config.MaxAmount then return false, 'Montant total trop élevé.' end
    local pendingCount = 0
    for _, r in pairs(Cache.requests) do if r.groupId == g.id and r.status == 'pending' then pendingCount = pendingCount + 1 end end
    if pendingCount >= Config.OrderMaxPending then return false, ('Déjà %d commandes en attente : attends qu\'elles soient traitées.'):format(pendingCount) end

    local r = { groupId = g.id, orderId = o.id, orderName = o.name, quantity = quantity, total = total, account = account,
        item = o.item, itemCount = o.item and (o.itemCount * quantity) or 0, requester = actor.name, requesterCid = actor.cid }
    local id = DB.insertRequest(r)
    if not id then return false, 'Erreur de la base de données.' end
    r.id, r.status, r.created = id, 'pending', os.time()
    Cache.requests[id] = r
    Log(actor, g.id, 'Commande passée', ('%s a commandé %dx %s pour %s (%s)'):format(actor.name, quantity, o.name, U.money(total), Illegal.Accounts[account]:lower()))
    Sync.group(g.id)
    return true, ('Commande envoyée : %dx %s (%s). Elle doit être validée.'):format(quantity, o.name, U.money(total))
end

local function getRequest(g, id, status)
    local r = Cache.requests[tonumber(id) or -1]
    if not r or r.groupId ~= g.id then return nil, 'Commande introuvable.' end
    if status and r.status ~= status then return nil, 'Cette commande a déjà été traitée.' end
    return r
end

-- Validation : l'état change d'abord en base (une seule validation possible), puis le groupe paie
function Orders.validate(actor, g, id)
    local r, err = getRequest(g, id, 'pending')
    if not r then return false, err end
    local nextStatus = r.item and 'ready' or 'delivered'
    if not DB.setRequestStatus(r.id, 'pending', nextStatus, actor.name) then return false, 'Cette commande a déjà été traitée.' end
    local ok, msg = Finances.payOrder(actor, g, r.account, r.total, ('%dx %s'):format(r.quantity, r.orderName))
    if not ok then
        DB.setRequestStatus(r.id, nextStatus, 'pending', nil)
        return false, msg
    end
    r.status, r.handledBy = nextStatus, actor.name
    Log(actor, g.id, 'Commande validée', ('%s a validé %dx %s (%s, %s)'):format(actor.name, r.quantity, r.orderName, U.money(r.total), Illegal.Accounts[r.account]:lower()))
    local src = Players.bySrcCid(r.requesterCid)
    if src then Players.notify(src, ('Ta commande %dx %s a été validée%s.'):format(r.quantity, r.orderName, r.item and ' : récupère-la dans la tablette' or ''), 'success') end
    Sync.group(g.id)
    return true, 'Commande validée et payée.'
end

function Orders.refuse(actor, g, id)
    local r, err = getRequest(g, id, 'pending')
    if not r then return false, err end
    if not DB.setRequestStatus(r.id, 'pending', 'refused', actor.name) then return false, 'Cette commande a déjà été traitée.' end
    r.status, r.handledBy = 'refused', actor.name
    Log(actor, g.id, 'Commande refusée', ('%s a refusé %dx %s'):format(actor.name, r.quantity, r.orderName))
    local src = Players.bySrcCid(r.requesterCid)
    if src then Players.notify(src, ('Ta commande %dx %s a été refusée.'):format(r.quantity, r.orderName), 'error') end
    Sync.group(g.id)
    return true, 'Commande refusée.'
end

-- Le demandeur annule sa propre commande en attente
function Orders.cancel(actor, g, id)
    local r, err = getRequest(g, id, 'pending')
    if not r then return false, err end
    if not actor.isAdmin and r.requesterCid ~= actor.cid then return false, 'Tu ne peux annuler que tes propres commandes.' end
    if not DB.setRequestStatus(r.id, 'pending', 'cancelled', actor.name) then return false, 'Cette commande a déjà été traitée.' end
    r.status = 'cancelled'
    Log(actor, g.id, 'Commande annulée', ('%dx %s'):format(r.quantity, r.orderName))
    Sync.group(g.id)
    return true, 'Commande annulée.'
end

-- Le demandeur récupère l'objet d'une commande validée
function Orders.claim(actor, g, id)
    local r, err = getRequest(g, id, 'ready')
    if not r then return false, err end
    if r.requesterCid ~= actor.cid then return false, 'Seul celui qui a passé la commande peut la récupérer.' end
    if not DB.setRequestStatus(r.id, 'ready', 'delivered', nil) then return false, 'Cette commande a déjà été récupérée.' end
    if not Players.giveItem(actor.src, r.item, r.itemCount) then
        DB.setRequestStatus(r.id, 'delivered', 'ready', nil)
        return false, 'Impossible de te donner la commande (inventaire plein ?). Réessaie plus tard.'
    end
    r.status = 'delivered'
    Log(actor, g.id, 'Commande récupérée', ('%s a récupéré %dx %s (%s x%d)'):format(actor.name, r.quantity, r.orderName, r.item, r.itemCount))
    Sync.group(g.id)
    return true, ('Commande récupérée : %dx %s.'):format(r.quantity, r.orderName)
end
