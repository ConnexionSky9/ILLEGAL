-- =========================================================
--  ELYZEA ILLÉGAL - LIVRAISON DES COMMANDES
--  Commande payée → « en préparation » (notification téléphone)
--  → après Config.Delivery.prepareMinutes : « prête », point GPS et
--  blip chez celui qui a commandé, PNJ (chef bras croisés + gardes
--  armés) dans un lieu caché éloigné → il ramasse le sac devant le
--  chef → objets donnés, PNJ supprimés.
--
--  Le serveur choisit le lieu, vérifie la distance au ramassage,
--  l'identité de celui qui ramasse et ne livre qu'une seule fois.
-- =========================================================
Deliveries = {}
local U = Illegal.Utils
local C = Config.Delivery

-- ---------------------------------------------------------
--  Lieux : ceux placés par le staff, sinon ceux de config.lua
-- ---------------------------------------------------------
function Deliveries.spots()
    local list = {}
    for _, s in pairs(Cache.spots) do list[#list + 1] = { key = 's' .. s.id, label = s.label, x = s.x, y = s.y, z = s.z, h = s.h } end
    if #list == 0 then
        for i, s in ipairs(C.defaultSpots) do list[#list + 1] = { key = 'd' .. i, label = s.label, x = s.x, y = s.y, z = s.z, h = s.h or 0.0 } end
    end
    return list
end

local function dist2d(a, b) return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2) end

-- Lieu éloigné du joueur et libre (pas déjà utilisé par une autre livraison)
local function pickSpot(from)
    local used = {}
    for _, r in pairs(Cache.requests) do
        if (r.status == 'preparing' or r.status == 'ready') and r.spot then used[r.spot.key or ''] = true end
    end
    local all, far, farthest, best = Deliveries.spots(), {}, nil, -1
    for _, s in ipairs(all) do
        local d = from and dist2d(from, s) or C.minDistance
        if not used[s.key] then
            if d >= C.minDistance then far[#far + 1] = s end
            if d > best then best, farthest = d, s end
        end
    end
    if #far > 0 then return far[math.random(#far)] end
    if farthest then return farthest end
    return all[math.random(#all)]   -- tous occupés : on partage un lieu
end

-- Position du sac : 1,2 m devant le chef
function Deliveries.bagPos(spot)
    local r = math.rad(spot.h or 0)
    return { x = spot.x - math.sin(r) * 1.2, y = spot.y + math.cos(r) * 1.2, z = spot.z }
end

function Deliveries.activeCount(cid)
    local n = 0
    for _, r in pairs(Cache.requests) do
        if r.requesterCid == cid and (r.status == 'preparing' or r.status == 'ready') then n = n + 1 end
    end
    return n
end

local function phone(src, title, msg)
    if src then TriggerClientEvent('illegal:client:phone', src, title, msg) end
end

local function clientPayload(r)
    return { id = r.id, label = r.spot.label, x = r.spot.x, y = r.spot.y, z = r.spot.z, h = r.spot.h,
        order = ('%dx %s'):format(r.quantity, r.orderName) }
end

-- La commande est payée : on lance la préparation
function Deliveries.start(actor, g, r)
    local src = Players.bySrcCid(r.requesterCid)
    local from = src and Groups.positionOf(src) or nil
    local spot = pickSpot(from)
    if not spot then return false, 'Aucun lieu de livraison configuré.' end
    local readyAt = os.time() + math.floor(C.prepareMinutes * 60)
    if not DB.startDelivery(r.id, r.status, readyAt, spot, actor.name) then return false, 'Cette commande a déjà été traitée.' end
    r.status, r.readyAt, r.spot = 'preparing', readyAt, spot
    if actor.name ~= r.requester then r.handledBy = actor.name end
    phone(src, 'Commande illégale', ('Ta commande (%dx %s) est en préparation. Elle sera disponible dans %d minutes.')
        :format(r.quantity, r.orderName, C.prepareMinutes))
    Log(actor, g.id, 'Livraison en préparation', ('%dx %s pour %s · %s'):format(r.quantity, r.orderName, r.requester, spot.label))
    return true
end

-- Préparation terminée : point GPS et PNJ chez celui qui a commandé
function Deliveries.markReady(r)
    if not DB.setRequestStatus(r.id, 'preparing', 'ready', nil) then return end
    r.status = 'ready'
    local src = Players.bySrcCid(r.requesterCid)
    if src then
        TriggerClientEvent('illegal:client:delivery', src, clientPayload(r), true)
        phone(src, 'Commande illégale', ('Ta commande (%dx %s) est prête. Le point GPS est sur ta carte.'):format(r.quantity, r.orderName))
    end
    Sync.group(r.groupId)
end

-- Vérification légère toutes les 10 s (seulement les commandes en préparation)
CreateThread(function()
    while true do
        Wait(10000)
        if Cache.ready then
            local now = os.time()
            for _, r in pairs(Cache.requests) do
                if r.status == 'preparing' and (r.readyAt or 0) <= now then Deliveries.markReady(r) end
            end
        end
    end
end)

-- Connexion : le joueur retrouve ses commandes prêtes
function Deliveries.resend(src)
    local cid = Players.cid(src)
    if not cid then return end
    for _, r in pairs(Cache.requests) do
        if r.status == 'ready' and r.requesterCid == cid and r.spot then
            TriggerClientEvent('illegal:client:delivery', src, clientPayload(r), false)
        end
    end
end

-- Ramassage du sac
RegisterNetEvent('illegal:server:pickup', function(id)
    local src = source
    if not Players.rateLimit(src, 'pickup', 3, 3000) then return end
    local r = Cache.requests[U.int(id, 1) or -1]
    if not r or r.status ~= 'ready' or not r.spot then return end
    local cid = Players.cid(src)
    if r.requesterCid ~= cid then return Players.notify(src, 'Ce sac n\'est pas pour toi.', 'error') end
    local pos = Groups.positionOf(src)
    if not pos or dist2d(pos, Deliveries.bagPos(r.spot)) > C.pickupDistance + 1.5 then return end

    if not DB.setRequestStatus(r.id, 'ready', 'delivered', nil) then return end
    if r.item and not Players.giveItem(src, r.item, r.itemCount) then
        DB.setRequestStatus(r.id, 'delivered', 'ready', nil)
        return Players.notify(src, 'Tu ne peux pas tout porter : fais de la place puis reviens prendre le sac.', 'error')
    end
    r.status = 'delivered'
    TriggerClientEvent('illegal:client:deliveryDone', src, r.id)
    Players.notify(src, ('Commande récupérée : %dx %s.'):format(r.quantity, r.orderName), 'success')
    Log(Players.actor(src), r.groupId, 'Commande récupérée', ('%s a récupéré %dx %s%s'):format(Players.charName(src), r.quantity, r.orderName,
        r.item and (' (%s x%d)'):format(r.item, r.itemCount) or ''))
    Sync.group(r.groupId)
end)

-- ---------------------------------------------------------
--  Staff : lieux de livraison
-- ---------------------------------------------------------
function Deliveries.addSpot(actor, data)
    local pos
    if data.useMyPosition then pos = Groups.positionOf(actor.src) else pos = U.coords(data) end
    if not pos then return false, 'Position invalide.' end
    local s = { label = U.text(data.label, 64, true), x = pos.x, y = pos.y, z = pos.z, h = pos.h }
    if s.label == '' then s.label = 'Point de livraison' end
    local id = DB.insertSpot(s)
    if not id then return false, 'Erreur de la base de données.' end
    s.id = id
    Cache.spots[id] = s
    Log(actor, nil, 'Point de livraison ajouté', ('%s (%.1f, %.1f, %.1f)'):format(s.label, s.x, s.y, s.z))
    return true, ('Point « %s » ajouté.'):format(s.label)
end

function Deliveries.removeSpot(actor, id)
    local s = Cache.spots[U.int(id, 1) or -1]
    if not s then return false, 'Point introuvable.' end
    if DB.deleteSpot(s.id) == nil then return false, 'Erreur de la base de données.' end
    Cache.spots[s.id] = nil
    Log(actor, nil, 'Point de livraison supprimé', s.label)
    return true, 'Point supprimé.'
end

-- Staff : rendre une commande en préparation prête tout de suite (tests, RP)
function Deliveries.readyNow(actor, g, id)
    local r = Cache.requests[U.int(id, 1) or -1]
    if not r or r.groupId ~= g.id or r.status ~= 'preparing' then return false, 'Commande introuvable ou pas en préparation.' end
    Deliveries.markReady(r)
    Log(actor, g.id, 'Livraison accélérée', ('%dx %s'):format(r.quantity, r.orderName))
    return true, 'Commande prête.'
end
