-- =========================================================
--  Base de données en mémoire : même API que server/database.lua,
--  mêmes formes de lignes que oxmysql (JSON en texte, 0/1 pour les booléens),
--  mêmes garde-fous (UNIQUE, solde jamais négatif, changement d'état conditionnel).
-- =========================================================
local T = { groups = {}, grades = {}, members = {}, finances = {}, tx = {}, peds = {}, orders = {}, requests = {}, logs = {}, spots = {} }
local seq = 0
local function nextId() seq = seq + 1 return seq end
local function enc(t) return json.encode(t or {}) end
local function copy(t) local o = {} for k, v in pairs(t) do o[k] = v end return o end
local function list(t) local o = {} for _, r in pairs(t) do o[#o + 1] = copy(r) end return o end

DB = { _tables = T, failNext = {} }
local function fail(name) if DB.failNext[name] then DB.failNext[name] = nil return true end end

function DB.install() return true end

function DB.loadAll()
    local req = {}
    for _, r in pairs(T.requests) do req[#req + 1] = copy(r) end
    return { groups = list(T.groups), grades = list(T.grades), members = list(T.members), finances = list(T.finances),
        peds = list(T.peds), orders = list(T.orders), requests = req, spots = list(T.spots) }
end

local function txRows(groupId, beforeId, limit)
    local rows = {}
    for _, r in ipairs(T.tx) do if r.group_id == groupId and r.id < beforeId then rows[#rows + 1] = copy(r) end end
    table.sort(rows, function(a, b) return a.id > b.id end)
    local out = {}
    for i = 1, math.min(limit, #rows) do out[i] = rows[i] end
    return out
end
function DB.recentTransactions(groupId, limit) return txRows(groupId, math.huge, limit) end
function DB.transactionsPage(groupId, beforeId, limit) return txRows(groupId, beforeId, limit) end
function DB.recentLogs(groupId, limit)
    local out = {}
    for i = #T.logs, 1, -1 do
        local l = T.logs[i]
        if l.group_id == groupId and #out < limit then out[#out + 1] = { actor = l.actor, action = l.action, details = l.details, created = l.created } end
    end
    return out
end

function DB.nameTaken(name) for _, g in pairs(T.groups) do if g.name == name then return true end end return false end

function DB.createGroup(g, grades, ped)
    if fail('createGroup') or DB.nameTaken(g.name) then return nil end
    local id = nextId()
    T.groups[id] = { id = id, name = g.name, label = g.label, type = g.type, description = g.description, color = g.color,
        settings = enc(g.settings), created_by = g.createdBy, created = os.time() }
    T.finances[id] = { group_id = id, clean = 0, dirty = 0 }
    local rows = {}
    for _, gr in ipairs(grades) do
        local gid = nextId()
        T.grades[gid] = { id = gid, group_id = id, name = gr.name, label = gr.label, level = gr.level, is_boss = gr.boss and 1 or 0, permissions = enc(gr.perms) }
        rows[#rows + 1] = { id = gid, name = gr.name }
    end
    if ped then T.peds[id] = { group_id = id, model = ped.model, x = ped.x, y = ped.y, z = ped.z, heading = ped.h, scenario = ped.scenario or '', menu = enc(ped.menu) } end
    return id, rows
end

function DB.updateGroup(id, g)
    local r = T.groups[id]
    if not r then return 0 end
    r.label, r.type, r.description, r.color, r.settings = g.label, g.type, g.description, g.color, enc(g.settings)
    return 1
end

function DB.deleteGroup(id)
    for cid, m in pairs(T.members) do if m.group_id == id then T.members[cid] = nil end end
    for k, r in pairs(T.grades) do if r.group_id == id then T.grades[k] = nil end end
    for k, r in pairs(T.orders) do if r.group_id == id then T.orders[k] = nil end end
    for k, r in pairs(T.requests) do if r.group_id == id then T.requests[k] = nil end end
    T.finances[id], T.peds[id], T.groups[id] = nil, nil, nil
    return true
end

function DB.insertGrade(groupId, gr)
    for _, r in pairs(T.grades) do if r.group_id == groupId and r.name == gr.name then return nil end end
    local id = nextId()
    T.grades[id] = { id = id, group_id = groupId, name = gr.name, label = gr.label, level = gr.level, is_boss = gr.boss and 1 or 0, permissions = enc(gr.perms) }
    return id
end
function DB.updateGrade(gr)
    local r = T.grades[gr.id]
    r.name, r.label, r.level, r.is_boss, r.permissions = gr.name, gr.label, gr.level, gr.boss and 1 or 0, enc(gr.perms)
    return 1
end
function DB.swapGradeLevels(a, b) T.grades[a.id].level, T.grades[b.id].level = a.level, b.level return true end
function DB.deleteGrade(gradeId, fallbackId)
    for _, m in pairs(T.members) do if m.grade_id == gradeId then m.grade_id = fallbackId end end
    T.grades[gradeId] = nil
    return true
end

function DB.insertMember(cid, groupId, gradeId, name)
    if T.members[cid] then return nil end   -- clé primaire : un seul groupe par personnage
    T.members[cid] = { citizenid = cid, group_id = groupId, grade_id = gradeId, name = name, joined = os.time(), last_seen = os.time() }
    return 1
end
function DB.setMemberGrade(cid, gradeId) T.members[cid].grade_id = gradeId return 1 end
function DB.deleteMember(cid) T.members[cid] = nil return 1 end
function DB.touchMember(cid, name) if T.members[cid] then T.members[cid].last_seen = os.time() T.members[cid].name = name end end
function DB.findCharacter(cid)
    if cid == 'OFFLINE1' then return { citizenid = 'OFFLINE1', name = 'Hors Ligne' } end
    return nil
end

function DB.addBalance(groupId, account, amount)
    if fail('addBalance') then return false end
    T.finances[groupId][account] = T.finances[groupId][account] + amount
    return true
end
function DB.removeBalance(groupId, account, amount)
    local f = T.finances[groupId]
    if f[account] < amount then return false end   -- WHERE solde >= montant
    f[account] = f[account] - amount
    return true
end
function DB.insertTransaction(groupId, tx)
    local id = nextId()
    T.tx[#T.tx + 1] = { id = id, group_id = groupId, account = tx.account, type = tx.type, amount = tx.amount, balance_before = tx.before,
        balance_after = tx.after, actor = tx.actor, reason = tx.reason or '', created = os.time() }
    return id
end

function DB.savePed(groupId, p)
    T.peds[groupId] = { group_id = groupId, model = p.model, x = p.x, y = p.y, z = p.z, heading = p.h, scenario = p.scenario or '', menu = enc(p.menu) }
    return {}
end
function DB.deletePed(groupId) T.peds[groupId] = nil return 1 end

function DB.insertOrder(o)
    local id = nextId()
    T.orders[id] = { id = id, group_id = o.groupId, name = o.name, description = o.description, category = o.category, price = o.price,
        payment = o.payment, available = o.available and 1 or 0, item = o.item, item_count = o.itemCount, created_by = o.createdBy }
    return id
end
function DB.updateOrder(o)
    local r = T.orders[o.id]
    r.name, r.description, r.category, r.price, r.payment, r.available, r.item, r.item_count =
        o.name, o.description, o.category, o.price, o.payment, o.available and 1 or 0, o.item, o.itemCount
    return 1
end
function DB.deleteOrder(id) T.orders[id] = nil return 1 end

function DB.insertRequest(r)
    local id = nextId()
    T.requests[id] = { id = id, group_id = r.groupId, order_id = r.orderId, order_name = r.orderName, quantity = r.quantity, total = r.total,
        account = r.account, item = r.item, item_count = r.itemCount, status = 'pending', requester = r.requester, requester_cid = r.requesterCid, created = os.time() }
    return id
end
function DB.setRequestStatus(id, from, to, by)
    local r = T.requests[id]
    if not r or r.status ~= from then return false end
    r.status = to
    if by then r.handled_by = by end
    return true
end

function DB.startDelivery(id, from, readyAt, spot, by)
    local r = T.requests[id]
    if not r or r.status ~= from then return false end
    r.status, r.ready_at, r.spot = 'preparing', readyAt, json.encode(spot)
    if by then r.handled_by = by end
    return true
end
function DB.insertSpot(s)
    local id = nextId()
    T.spots[id] = { id = id, label = s.label, x = s.x, y = s.y, z = s.z, heading = s.h }
    return id
end
function DB.deleteSpot(id) T.spots[id] = nil return 1 end

function DB.insertLog(groupId, actor, action, details)
    T.logs[#T.logs + 1] = { group_id = groupId, actor = actor, action = action, details = details, created = os.time() }
end
