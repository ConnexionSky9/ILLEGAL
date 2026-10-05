-- =========================================================
--  COIFFEUR / BARBIER - SERVEUR
--  Le PNJ est posé avec l'éditeur (rôle « Coiffeur »).
--  Le serveur ne fait JAMAIS confiance au prix envoyé par le client :
--  il recalcule le total avec les prix du PNJ avant de débiter.
-- =========================================================
local AM = AdminMenu
local CFG = Config.Barber or {}

-- Clés du panier → service qui les autorise
local KEYS = {
    hair = 'hair', hair_color = 'hair_color', hair_highlight = 'hair_color',
    beard = 'beard', beard_color = 'beard', beard_highlight = 'beard',
    brows = 'brows', brows_color = 'brows',
    eyes = 'eyes',
    chest = 'chest', chest_color = 'chest',
}
local SERVICES = { 'hair', 'hair_color', 'beard', 'brows', 'eyes', 'chest' }
local STYLE_KEYS = { beard = 28, brows = 33, chest = 16 } -- max vanilla (les addons sont acceptés jusqu'à 60)

local function num(v, mn, mx, def)
    v = tonumber(v)
    if not v or v ~= v then return def end
    if v < mn then return mn end
    if v > mx then return mx end
    return v
end
local function int(v, mn, mx, def) local n = num(v, mn, mx, nil) return n and math.floor(n) or def end

-- ---------------------------------------------------------
--  Nettoyage du rôle (appelé par server/editor.lua › cleanNpc)
-- ---------------------------------------------------------
function BarberCleanRole(b)
    local def = CFG.defaultPrices or {}
    local prices = {}
    local src = type(b.prices) == 'table' and b.prices or {}
    for key in pairs(KEYS) do
        prices[key] = int(src[key], 0, 1000000, int(def[key], 0, 1000000, 0))
    end
    local services = {}
    local seen = {}
    for _, s in ipairs(type(b.services) == 'table' and b.services or {}) do
        for _, ok in ipairs(SERVICES) do
            if s == ok and not seen[s] then seen[s] = true services[#services + 1] = s end
        end
    end
    local name = tostring(b.name or ''):gsub('[<>]', ''):sub(1, 40)
    return {
        name = name ~= '' and name or 'Salon de coiffure',
        prices = prices,
        services = services,                       -- vide = tous les services
        payChoice = b.payChoice ~= false,          -- le joueur choisit liquide ou banque
        specialEyes = b.specialEyes == true,       -- lentilles fantaisie (yeux de démon, zombie…)
        blip = b.blip == true,
        blipSprite = int(b.blipSprite, 1, 900, CFG.blipSprite or 71),
        blipColor = int(b.blipColor, 0, 85, CFG.blipColor or 4),
    }
end

local function offers(bb, service)
    if not bb.services or #bb.services == 0 then return true end
    for _, s in ipairs(bb.services) do if s == service then return true end end
    return false
end

-- ---------------------------------------------------------
--  Têtes sauvegardées (mode 'internal')
-- ---------------------------------------------------------
local Looks = Storage.load('barber_looks', {})

local function charKey(src)
    return Bridge.GetCharId(src) or AM.getLicense(src)
end

-- Valide une valeur de panier / de tête. Renvoie nil si invalide.
local function cleanValue(key, v, bb)
    if key == 'hair' then return int(v, 0, 500, nil) end
    if key == 'eyes' then
        local e = int(v, 0, 31, nil)
        if e and bb and not bb.specialEyes and e > 8 then return nil end
        return e
    end
    if STYLE_KEYS[key] then
        if type(v) ~= 'table' then return nil end
        local s = int(v.s, -1, 60, nil)
        if not s then return nil end
        return { s = s, o = math.floor(num(v.o, 0, 1, 1) * 100 + 0.5) / 100 }
    end
    return int(v, 0, 63, nil) -- couleurs
end

local function cleanLook(look)
    if type(look) ~= 'table' then return nil end
    local out = { model = (look.model == 'female') and 'female' or 'male' }
    for key in pairs(KEYS) do
        local v = cleanValue(key, look[key], nil)
        if v == nil then return nil end
        out[key] = v
    end
    return out
end

RegisterNetEvent('adminmenu:barber:getLook', function()
    local src = source
    if not AM.rateLimit(src, 'barber_look', 3, 5000) then return end
    local key = charKey(src)
    TriggerClientEvent('adminmenu:barber:look', src, key and Looks[key] or nil)
end)

-- ---------------------------------------------------------
--  Ouverture du salon (le joueur a appuyé sur E)
-- ---------------------------------------------------------
local Paying = {}

RegisterNetEvent('adminmenu:barber:request', function(id)
    local src = source
    if CFG.enabled == false then return end
    if not AM.rateLimit(src, 'npc', 4, 1000) then return end
    local r = AM.EditorPeds.check(src, id)
    if not r or not r.npc.barber then return end
    local bb, n = r.npc.barber, r.npc

    local prices = {}
    for key, service in pairs(KEYS) do
        if offers(bb, service) then prices[key] = bb.prices[key] or 0 end
    end
    local wallet = {}
    if bb.payChoice and n.payment ~= 'item' then
        wallet.cash = Bridge.GetMoney(src, 'cash')
        wallet.bank = Bridge.GetMoney(src, 'bank')
    else
        wallet[n.payment] = Bridge.GetMoney(src, n.payment, n.paymentItem)
    end

    TriggerClientEvent('adminmenu:barber:show', src, {
        id = r.id, name = bb.name, prices = prices,
        payChoice = bb.payChoice and n.payment ~= 'item', payment = n.payment,
        paymentLabel = n.payment == 'item' and (Bridge.GetLabel(n.paymentItem) or n.paymentItem) or nil,
        specialEyes = bb.specialEyes, wallet = wallet,
    })
end)

-- ---------------------------------------------------------
--  Paiement du panier
-- ---------------------------------------------------------
local function result(src, ok, msg, total)
    TriggerClientEvent('adminmenu:barber:result', src, ok, msg, total)
end

RegisterNetEvent('adminmenu:barber:pay', function(id, cart, look, method)
    local src = source
    if not AM.rateLimit(src, 'barber_pay', 2, 1500) then return end
    if Paying[src] then return end
    local r = AM.EditorPeds.check(src, id)
    if not r or not r.npc.barber then return result(src, false, 'Tu es trop loin du salon.') end
    local bb, n = r.npc.barber, r.npc
    if type(cart) ~= 'table' then return result(src, false, 'Panier invalide.') end

    -- Recalcul du total avec les prix du serveur
    local total, lines = 0, 0
    for key, value in pairs(cart) do
        local service = KEYS[key]
        if not service or not offers(bb, service) then return result(src, false, 'Ce salon ne propose pas ce service.') end
        if cleanValue(key, value, bb) == nil then return result(src, false, 'Choix invalide dans le panier.') end
        total = total + (bb.prices[key] or 0)
        lines = lines + 1
    end
    if lines == 0 then return result(src, false, 'Ton panier est vide.') end

    local kind, item = n.payment, n.paymentItem
    if bb.payChoice and n.payment ~= 'item' then kind = (method == 'bank') and 'bank' or 'cash' end

    Paying[src] = true
    if total > 0 then
        if Bridge.GetMoney(src, kind, item) < total then
            Paying[src] = nil
            return result(src, false, kind == 'bank' and 'Pas assez d\'argent sur ton compte.' or 'Tu n\'as pas assez d\'argent sur toi.')
        end
        if not Bridge.RemoveMoney(src, kind, item, total, 'coiffeur') then
            Paying[src] = nil
            return result(src, false, 'Le paiement a échoué.')
        end
    end
    Paying[src] = nil

    -- Sauvegarde interne (sert de secours si aucune ressource d'apparence n'est trouvée)
    local clean = cleanLook(look)
    local key = charKey(src)
    if clean and key then
        Looks[key] = clean
        Storage.saveLater('barber_looks', Looks, 3000)
    end

    result(src, true, total > 0 and ('Payé %s $. Nouvelle tête enregistrée !'):format(total) or 'Nouvelle tête enregistrée !', total)
    TriggerEvent('adminmenu:barber:paid', src, total, r.id, cart)  -- pour une société / des logs externes
end)

AddEventHandler('playerDropped', function() Paying[source] = nil end)

-- Statistiques simples pour d'autres ressources
exports('GetBarberLook', function(src) local k = charKey(src) return k and Looks[k] or nil end)
