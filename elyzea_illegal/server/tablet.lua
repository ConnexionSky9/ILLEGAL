-- =========================================================
--  ELYZEA ILLÉGAL - TABLETTE DU JOUEUR (F5 / PNJ)
--
--  SÉCURITÉ : le client n'envoie JAMAIS son groupe. À chaque appel
--  le serveur relit lui-même :
--    personnage (Qbox) → groupe → grade → permissions,
--  vérifie que la tablette a bien été ouverte (F5 ou à côté du PNJ),
--  que l'onglet est autorisé, puis la permission de l'action.
-- =========================================================
Tablet = {}
local U = Illegal.Utils

-- Permission demandée par chaque action (nil = aucune, contrôles propres à l'action)
local ACTION_PERM = {
    recruit = 'recruit', kick = 'kick', promote = 'promote', demote = 'demote', setGrade = 'set_grade',
    createGrade = 'manage_grades', updateGrade = 'manage_grades', deleteGrade = 'manage_grades', moveGrade = 'manage_grades',
    placeOrder = 'orders_place', createOrder = 'orders_manage', updateOrder = 'orders_manage', deleteOrder = 'orders_manage',
    validateRequest = 'orders_validate', refuseRequest = 'orders_validate',
    saveSettings = 'settings',
    -- deposit / withdraw : permission selon le compte (clean_deposit, dirty_withdraw…)
    -- cancelRequest / leave : seulement ses propres commandes / soi-même (le sac se ramasse sur place : deliveries.lua)
}

-- Contexte complet d'un joueur, recalculé à chaque appel
local function context(src)
    local cid = Players.cid(src)
    local g, m, grade = Cache.membership(cid)
    if not g or not grade then return nil end
    return { src = src, cid = cid, name = Players.charName(src), group = g, member = m, grade = grade, isAdmin = false }
end

-- Onglets autorisés, relus en direct (un changement du staff s'applique tout de suite)
function Tablet.tabsOf(s, g)
    if s.via == 'ped' then return g.ped and g.ped.menu or { home = true } end
    return g.settings.f5Tabs
end

local function effectivePerms(grade)
    local out = {}
    for _, p in ipairs(Illegal.Permissions) do if Cache.hasPerm(grade, p.key) then out[p.key] = true end end
    return out
end

-- ---------------------------------------------------------
--  Données de la tablette (uniquement le groupe du joueur)
-- ---------------------------------------------------------
function Tablet.build(src)
    local ctx = context(src)
    local s = Sessions[src]
    if not ctx or not s or s.groupId ~= ctx.group.id then return nil end
    local g, grade = ctx.group, ctx.grade
    local perms = effectivePerms(grade)
    local top = Cache.topGrades(g)

    local grades, gradeCount = {}, {}
    for _, m in pairs(g.members) do gradeCount[m.gradeId] = (gradeCount[m.gradeId] or 0) + 1 end
    for _, gr in ipairs(Cache.sortedGrades(g)) do
        grades[#grades + 1] = { id = gr.id, name = gr.name, label = gr.label, level = gr.level, boss = gr.boss, perms = gr.perms,
            members = gradeCount[gr.id] or 0, editable = gr.level < grade.level }
    end

    local members = {}
    for cid, m in pairs(g.members) do
        local gr = g.grades[m.gradeId]
        local online = Players.bySrcCid(cid)
        members[#members + 1] = { cid = cid, name = m.name ~= '' and m.name or cid, gradeId = m.gradeId, grade = gr and gr.label or '?',
            level = gr and gr.level or 0, boss = gr and gr.boss or false, online = online ~= nil, id = online, lastSeen = m.lastSeen,
            joined = m.joined, me = cid == ctx.cid, below = gr ~= nil and gr.level < grade.level }
    end
    table.sort(members, function(a, b) if a.level ~= b.level then return a.level > b.level end return a.name < b.name end)

    local og = {}
    for _, m in ipairs(members) do if top[m.gradeId] then og[#og + 1] = m.name end end

    local data = {
        via = s.via, tabs = Tablet.tabsOf(s, g),
        group = { id = g.id, name = g.name, label = g.label, type = g.type, typeLabel = U.typeLabel(g.type), color = g.color,
            description = g.description, memberCount = #members, og = og, created = g.created,
            stash = g.stash and { label = g.stash.label, weight = g.stash.weight, slots = g.stash.slots } or nil },
        me = { name = ctx.name, grade = grade.label, gradeId = grade.id, level = grade.level, boss = grade.boss, perms = perms },
        members = members, grades = grades,
        permissions = Illegal.Permissions, categories = Config.OrderCategories,
        config = { maxQuantity = Config.OrderMaxQuantity, maxAmount = Config.MaxAmount, cleanAccount = Config.CleanMoney.account,
            canCreateOrders = Config.Orders.playerCanCreate, requireValidation = Config.Orders.requireValidation,
            prepareMinutes = Config.Delivery.prepareMinutes, now = os.time() },
    }

    if perms.finance_view then
        data.finance = { clean = g.finance.clean, dirty = g.finance.dirty, history = Cache.transactions(g) }
    end

    local orders = {}
    for _, o in ipairs(Cache.ordersFor(g)) do
        if o.available or perms.orders_manage then
            orders[#orders + 1] = { id = o.id, name = o.name, description = o.description, category = o.category, price = o.price,
                payment = o.payment, available = o.available, global = o.groupId == nil, hasItem = o.item ~= nil,
                editable = Config.Orders.playerCanCreate and perms.orders_manage == true and o.groupId == g.id }
        end
    end
    data.orders = orders

    local requests = {}
    for _, r in ipairs(Cache.requestsFor(g)) do
        if perms.orders_validate or r.requesterCid == ctx.cid then
            requests[#requests + 1] = { id = r.id, orderName = r.orderName, quantity = r.quantity, total = r.total, account = r.account,
                status = r.status, requester = r.requester, handledBy = r.handledBy, created = r.created, hasItem = r.item ~= nil,
                mine = r.requesterCid == ctx.cid, readyAt = r.readyAt }
        end
    end
    data.requests = requests

    if grade.boss or perms.settings then data.logs = Cache.logs(g) end
    return data
end

function Tablet.push(src)
    local data = Tablet.build(src)
    if not data then
        Sessions[src] = nil
        TriggerClientEvent('illegal:client:close', src)
        return
    end
    TriggerClientEvent('illegal:client:tablet', src, data)
end

-- ---------------------------------------------------------
--  Ouverture : F5 ou PNJ
-- ---------------------------------------------------------
RegisterNetEvent('illegal:server:open', function(via, pedGroupId)
    local src = source
    if not Players.rateLimit(src, 'open', 4, 3000) then return end
    local ctx = context(src)

    if via == 'ped' then
        local pg = Cache.group(U.int(pedGroupId, 1))
        if not pg or not pg.ped or not Peds.isNear(src, pg) then return end
        if not ctx or ctx.group.id ~= pg.id then
            return Players.notify(src, 'Vous n\'êtes pas membre de ce groupe.', 'error')
        end
        Sessions[src] = { groupId = pg.id, via = 'ped' }
    else
        -- F5 intégré ou ton propre menu (export OpenTablet) : même accès, même contrôles
        if not ctx then return Players.notify(src, 'Tu ne fais partie d\'aucun groupe illégal.', 'error') end
        Sessions[src] = { groupId = ctx.group.id, via = 'f5' }
    end
    local data = Tablet.build(src)
    if not data then Sessions[src] = nil return end
    TriggerClientEvent('illegal:client:openTablet', src, data)
end)

RegisterNetEvent('illegal:server:close', function() Sessions[source] = nil end)

-- ---------------------------------------------------------
--  Actions
-- ---------------------------------------------------------
local HANDLERS = {
    recruit     = function(a, g, d) return Members.add(a, g, U.int(d.target, 1, 65535), U.int(d.gradeId, 1)) end,
    kick        = function(a, g, d) return Members.remove(a, g, U.text(d.cid, 50)) end,
    promote     = function(a, g, d) return Members.step(a, g, U.text(d.cid, 50), 1) end,
    demote      = function(a, g, d) return Members.step(a, g, U.text(d.cid, 50), -1) end,
    setGrade    = function(a, g, d) return Members.setGrade(a, g, U.text(d.cid, 50), U.int(d.gradeId, 1)) end,
    leave       = function(a, g) return Members.leave(a, g) end,

    createGrade = function(a, g, d) return Grades.create(a, g, d) end,
    updateGrade = function(a, g, d) return Grades.update(a, g, U.int(d.id, 1), d) end,
    deleteGrade = function(a, g, d) return Grades.delete(a, g, U.int(d.id, 1)) end,
    moveGrade   = function(a, g, d) return Grades.move(a, g, U.int(d.id, 1), U.int(d.dir, -1, 1)) end,

    deposit     = function(a, g, d) return Finances.deposit(a, g, d.account, d.amount) end,
    withdraw    = function(a, g, d) return Finances.withdraw(a, g, d.account, d.amount) end,

    placeOrder  = function(a, g, d) return Orders.place(a, g, U.int(d.id, 1), d.quantity, d.account) end,
    createOrder = function(a, g, d) return Orders.create(a, g, d) end,
    updateOrder = function(a, g, d) return Orders.update(a, g, U.int(d.id, 1), d) end,
    deleteOrder = function(a, g, d) return Orders.delete(a, g, U.int(d.id, 1)) end,
    validateRequest = function(a, g, d) return Orders.validate(a, g, U.int(d.id, 1)) end,
    refuseRequest   = function(a, g, d) return Orders.refuse(a, g, U.int(d.id, 1)) end,
    cancelRequest   = function(a, g, d) return Orders.cancel(a, g, U.int(d.id, 1)) end,

    -- Le type et les onglets F5 restent réservés au staff
    saveSettings = function(a, g, d)
        return Groups.update(a, g, { label = d.label, description = d.description, color = d.color })
    end,
}

local function suspicious(src, name, why)
    print(('^1[ILLEGAL] %s [%d] : action « %s » refusée (%s).^7'):format(GetPlayerName(src) or '?', src, tostring(name), why))
end

RegisterNetEvent('illegal:server:action', function(name, data)
    local src = source
    if type(name) ~= 'string' or not HANDLERS[name] then return end
    if not Players.rateLimit(src, 'action', 8, 2000) then return Players.notify(src, 'Doucement…', 'error') end
    data = type(data) == 'table' and data or {}

    local s = Sessions[src]
    if not s then return suspicious(src, name, 'tablette fermée') end
    local ctx = context(src)
    if not ctx or ctx.group.id ~= s.groupId then
        Sessions[src] = nil
        TriggerClientEvent('illegal:client:close', src)
        return suspicious(src, name, 'pas membre du groupe de la session')
    end
    local g = ctx.group
    if s.via == 'ped' and not Peds.isNear(src, g) then
        return Players.notify(src, 'Tu t\'es éloigné du PNJ.', 'error')
    end
    local tabKey = Illegal.ActionTab[name]
    if tabKey and not Tablet.tabsOf(s, g)[tabKey] then return suspicious(src, name, 'onglet non autorisé') end

    local perm = ACTION_PERM[name]
    if name == 'deposit' or name == 'withdraw' then
        if data.account ~= 'clean' and data.account ~= 'dirty' then return end
        perm = data.account .. (name == 'deposit' and '_deposit' or '_withdraw')
    end
    if perm and not Cache.hasPerm(ctx.grade, perm) then
        suspicious(src, name, 'permission ' .. perm)
        return Players.notify(src, 'Ton grade ne permet pas de faire ça.', 'error')
    end

    local ok, msg = HANDLERS[name](ctx, g, data)
    if msg then Players.notify(src, msg, ok and 'success' or 'error') end
    if not ok and Sessions[src] then Tablet.push(src) end   -- remet la tablette d'aplomb
end)

-- Historique financier plus ancien (pagination)
lib.callback.register('illegal:server:history', function(src, beforeId)
    if not Players.rateLimit(src, 'history', 5, 3000) then return nil end
    local s, ctx = Sessions[src], context(src)
    if not s or not ctx or ctx.group.id ~= s.groupId or not Tablet.tabsOf(s, ctx.group).finances then return nil end
    if not Cache.hasPerm(ctx.grade, 'finance_view') then return nil end
    return Finances.history(ctx.group, beforeId)
end)
