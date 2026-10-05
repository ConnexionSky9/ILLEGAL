-- =========================================================
--  ELYZEA ILLÉGAL - CACHE MÉMOIRE
--  Tout est chargé une fois au démarrage : les lectures (tablette,
--  menu staff rafraîchi toutes les 5 s) ne touchent jamais la base.
--  Chaque écriture passe d'abord par la base puis met le cache à jour.
-- =========================================================
Cache = {
    groups = {},     -- [groupId] = group
    memberOf = {},   -- [citizenid] = groupId
    orders = {},     -- [orderId] = order (groupId nil = proposée à tous)
    requests = {},   -- [requestId] = demande de commande
    ready = false,
}

local TX_KEEP = 50
local function decode(s) if type(s) ~= 'string' or s == '' then return nil end local ok, v = pcall(json.decode, s) return ok and v or nil end

-- ---------------------------------------------------------
--  Construction des objets
-- ---------------------------------------------------------
function Cache.newGroup(row)
    local s = decode(row.settings) or {}
    return {
        id = row.id, name = row.name, label = row.label, type = row.type, description = row.description or '',
        color = row.color or '#e0433b', createdBy = row.created_by, created = row.created,
        settings = { f5Tabs = Illegal.Utils.tabSet(s.f5Tabs) },
        grades = {}, members = {}, finance = { clean = 0, dirty = 0 }, ped = nil,
        tx = nil,   -- dernières transactions, chargées à la première consultation
    }
end

function Cache.newGrade(row)
    return {
        id = row.id, groupId = row.group_id, name = row.name, label = row.label, level = tonumber(row.level) or 0,
        boss = row.is_boss == 1 or row.is_boss == true, perms = Illegal.Utils.permSet(decode(row.permissions)),
    }
end

function Cache.newPed(row)
    return {
        model = row.model, x = row.x + 0.0, y = row.y + 0.0, z = row.z + 0.0, h = (row.heading or 0) + 0.0,
        scenario = row.scenario or '', menu = Illegal.Utils.tabSet(decode(row.menu)), version = 1,
    }
end

function Cache.newOrder(row)
    return {
        id = row.id, groupId = row.group_id, name = row.name, description = row.description or '', category = row.category,
        price = tonumber(row.price) or 0, payment = row.payment, available = row.available == 1 or row.available == true,
        item = (row.item and row.item ~= '') and row.item or nil, itemCount = tonumber(row.item_count) or 1, createdBy = row.created_by,
    }
end

function Cache.newRequest(row)
    return {
        id = row.id, groupId = row.group_id, orderId = row.order_id, orderName = row.order_name, quantity = row.quantity,
        total = tonumber(row.total) or 0, account = row.account, item = row.item, itemCount = tonumber(row.item_count) or 0,
        status = row.status, requester = row.requester, requesterCid = row.requester_cid, handledBy = row.handled_by,
        created = row.created or os.time(),
    }
end

-- ---------------------------------------------------------
--  Chargement
-- ---------------------------------------------------------
function Cache.load()
    local d = DB.loadAll()
    Cache.groups, Cache.memberOf, Cache.orders, Cache.requests = {}, {}, {}, {}
    for _, r in ipairs(d.groups) do Cache.groups[r.id] = Cache.newGroup(r) end
    for _, r in ipairs(d.grades) do
        local g = Cache.groups[r.group_id]
        if g then g.grades[r.id] = Cache.newGrade(r) end
    end
    for _, r in ipairs(d.members) do
        local g = Cache.groups[r.group_id]
        if g and g.grades[r.grade_id] then
            g.members[r.citizenid] = { cid = r.citizenid, groupId = r.group_id, gradeId = r.grade_id, name = r.name, joined = r.joined, lastSeen = r.last_seen }
            Cache.memberOf[r.citizenid] = r.group_id
        end
    end
    for _, r in ipairs(d.finances) do
        local g = Cache.groups[r.group_id]
        if g then g.finance = { clean = tonumber(r.clean) or 0, dirty = tonumber(r.dirty) or 0 } end
    end
    for _, r in ipairs(d.peds) do
        local g = Cache.groups[r.group_id]
        if g then g.ped = Cache.newPed(r) end
    end
    for _, r in ipairs(d.orders) do Cache.orders[r.id] = Cache.newOrder(r) end
    for _, r in ipairs(d.requests) do Cache.requests[r.id] = Cache.newRequest(r) end
    Cache.ready = true

    local n = 0
    for _ in pairs(Cache.groups) do n = n + 1 end
    print(('^2[ILLEGAL] %d groupe(s) chargé(s).^7'):format(n))
end

-- ---------------------------------------------------------
--  Accès
-- ---------------------------------------------------------
function Cache.group(id) return Cache.groups[tonumber(id) or -1] end

function Cache.byName(name)
    for _, g in pairs(Cache.groups) do if g.name == name then return g end end
end

-- Groupe + membre + grade d'un personnage
function Cache.membership(cid)
    if not cid then return nil end
    local g = Cache.groups[Cache.memberOf[cid] or -1]
    local m = g and g.members[cid]
    if not m then return nil end
    return g, m, g.grades[m.gradeId]
end

function Cache.sortedGrades(g)
    local list = {}
    for _, gr in pairs(g.grades) do list[#list + 1] = gr end
    table.sort(list, function(a, b) if a.level ~= b.level then return a.level < b.level end return a.id < b.id end)
    return list
end

function Cache.lowestGrade(g) return Cache.sortedGrades(g)[1] end

function Cache.topGrades(g)
    local top, out = nil, {}
    for _, gr in pairs(g.grades) do if not top or gr.level > top then top = gr.level end end
    for _, gr in pairs(g.grades) do if gr.level == top then out[gr.id] = true end end
    return out
end

function Cache.hasPerm(grade, perm)
    return grade ~= nil and (grade.boss or grade.perms[perm] == true)
end

function Cache.memberCount(g)
    local n = 0
    for _ in pairs(g.members) do n = n + 1 end
    return n
end

-- Dernières transactions (chargées à la demande, puis tenues à jour en mémoire)
function Cache.transactions(g)
    if not g.tx then
        g.tx = {}
        for _, r in ipairs(DB.recentTransactions(g.id, TX_KEEP)) do
            g.tx[#g.tx + 1] = { id = r.id, account = r.account, type = r.type, amount = tonumber(r.amount), before = tonumber(r.balance_before),
                after = tonumber(r.balance_after), actor = r.actor, reason = r.reason, created = r.created }
        end
    end
    return g.tx
end

function Cache.pushTransaction(g, tx)
    if not g.tx then return end   -- pas encore chargé : sera lu en base
    table.insert(g.tx, 1, tx)
    if #g.tx > TX_KEEP then g.tx[#g.tx] = nil end
end

function Cache.logs(g)
    if not RecentLogs[g.id] then
        RecentLogs[g.id] = DB.recentLogs(g.id, 30)
    end
    return RecentLogs[g.id]
end

-- Commandes visibles par un groupe (les siennes + celles proposées à tous)
function Cache.ordersFor(g)
    local list = {}
    for _, o in pairs(Cache.orders) do
        if o.groupId == nil or o.groupId == g.id then list[#list + 1] = o end
    end
    table.sort(list, function(a, b) if a.category ~= b.category then return a.category < b.category end return a.name < b.name end)
    return list
end

function Cache.requestsFor(g)
    local list = {}
    for _, r in pairs(Cache.requests) do if r.groupId == g.id then list[#list + 1] = r end end
    table.sort(list, function(a, b) return a.id > b.id end)
    return list
end

function Cache.forgetGroup(g)
    for cid in pairs(g.members) do Cache.memberOf[cid] = nil end
    for id, o in pairs(Cache.orders) do if o.groupId == g.id then Cache.orders[id] = nil end end
    for id, r in pairs(Cache.requests) do if r.groupId == g.id then Cache.requests[id] = nil end end
    RecentLogs[g.id] = nil
    Cache.groups[g.id] = nil
end
