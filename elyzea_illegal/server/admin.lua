-- =========================================================
--  ELYZEA ILLÉGAL - ADMINISTRATION (admin_menu › ILLEGAL)
--  Même principe que les autres modules du menu (Concession,
--  LsCustom) : admin_menu vérifie la permission « illegal_staff »
--  et le service staff, puis appelle :
--    exports.elyzea_illegal:AdminData(src)              → données de l'onglet
--    exports.elyzea_illegal:AdminAction(src, name, data) → ok, message
--  La permission est revérifiée ici, et chaque valeur est validée
--  par les services (groups, grades, members, finances…).
-- =========================================================
local U = Illegal.Utils
local Selected = {}   -- [src] = groupId ouvert dans le menu staff
AddEventHandler('playerDropped', function() Selected[source] = nil end)

local function staffActor(src)
    local a = Players.actor(src, true)
    a.name = ('%s (staff)'):format(GetPlayerName(src) or ('#' .. src))
    return a
end

local function groupSummary(g)
    local og, top = {}, Cache.topGrades(g)
    for _, m in pairs(g.members) do if top[m.gradeId] then og[#og + 1] = m.name ~= '' and m.name or m.cid end end
    return {
        id = g.id, name = g.name, label = g.label, type = g.type, typeLabel = U.typeLabel(g.type), color = g.color,
        members = Cache.memberCount(g), og = og, clean = g.finance.clean, dirty = g.finance.dirty,
        ped = g.ped and g.ped.model or nil,
    }
end

local function orderRow(o)
    return { id = o.id, name = o.name, description = o.description, category = o.category, price = o.price, payment = o.payment,
        available = o.available, item = o.item, itemCount = o.itemCount, global = o.groupId == nil, createdBy = o.createdBy }
end

local function groupDetail(g)
    local d = groupSummary(g)
    d.description, d.created, d.createdBy = g.description, g.created, g.createdBy
    d.settings = { f5Tabs = g.settings.f5Tabs }

    local count = {}
    for _, m in pairs(g.members) do count[m.gradeId] = (count[m.gradeId] or 0) + 1 end
    d.grades = {}
    for _, gr in ipairs(Cache.sortedGrades(g)) do
        d.grades[#d.grades + 1] = { id = gr.id, name = gr.name, label = gr.label, level = gr.level, boss = gr.boss, perms = gr.perms, members = count[gr.id] or 0 }
    end

    d.memberList = {}
    for cid, m in pairs(g.members) do
        local gr = g.grades[m.gradeId]
        local online = Players.bySrcCid(cid)
        d.memberList[#d.memberList + 1] = { cid = cid, name = m.name ~= '' and m.name or cid, gradeId = m.gradeId, grade = gr and gr.label or '?',
            level = gr and gr.level or 0, boss = gr and gr.boss or false, online = online ~= nil, id = online, lastSeen = m.lastSeen, joined = m.joined }
    end
    table.sort(d.memberList, function(a, b) if a.level ~= b.level then return a.level > b.level end return a.name < b.name end)

    d.finance = { clean = g.finance.clean, dirty = g.finance.dirty, history = Cache.transactions(g) }
    d.pedData = g.ped and { model = g.ped.model, x = g.ped.x, y = g.ped.y, z = g.ped.z, h = g.ped.h, scenario = g.ped.scenario, menu = g.ped.menu } or nil

    d.orders = {}
    for _, o in ipairs(Cache.ordersFor(g)) do if o.groupId == g.id then d.orders[#d.orders + 1] = orderRow(o) end end
    d.requests = {}
    for _, r in ipairs(Cache.requestsFor(g)) do
        d.requests[#d.requests + 1] = { id = r.id, orderName = r.orderName, quantity = r.quantity, total = r.total, account = r.account,
            status = r.status, requester = r.requester, handledBy = r.handledBy, created = r.created }
    end
    d.logs = Cache.logs(g)
    return d
end

exports('AdminData', function(src)
    if not Cache.ready then return { available = true, loading = true } end
    local stats = { groups = 0, members = 0, gang = 0, organisation = 0, cartel = 0, clean = 0, dirty = 0 }
    local list = {}
    for _, g in pairs(Cache.groups) do
        local s = groupSummary(g)
        list[#list + 1] = s
        stats.groups = stats.groups + 1
        stats.members = stats.members + s.members
        stats[g.type] = (stats[g.type] or 0) + 1
        stats.clean = stats.clean + g.finance.clean
        stats.dirty = stats.dirty + g.finance.dirty
    end
    table.sort(list, function(a, b) return a.label:lower() < b.label:lower() end)

    local global = {}
    for _, o in pairs(Cache.orders) do if o.groupId == nil then global[#global + 1] = orderRow(o) end end
    table.sort(global, function(a, b) return a.name < b.name end)

    local sel = src and Cache.group(Selected[src])
    return {
        available = true, stats = stats, groups = list, globalOrders = global,
        selected = sel and groupDetail(sel) or nil,
        types = Config.Types, permissions = Illegal.Permissions, tabs = Illegal.Tabs, categories = Config.OrderCategories,
        defaultPed = Config.Ped.defaultModel, defaultScenario = Config.Ped.scenario, maxAmount = Config.MaxAmount,
    }
end)

-- ---------------------------------------------------------
--  Actions du staff
-- ---------------------------------------------------------
local function needGroup(d)
    local g = Cache.group(U.int(d.id, 1))
    if not g then return nil, 'Groupe introuvable (déjà supprimé ?).' end
    return g
end

local A = {}

A.select = function(src, d)
    local g, err = needGroup(d)
    if not g then return false, err end
    Selected[src] = g.id
    return true
end
A.back = function(src) Selected[src] = nil return true end

A.createGroup = function(src, d)
    local ok, msg, g = Groups.create(staffActor(src), d)
    if ok and g then Selected[src] = g.id end
    return ok, msg
end
A.updateGroup = function(src, d, g) return Groups.update(staffActor(src), g, d) end
A.deleteGroup = function(src, d, g)
    local ok, msg = Groups.delete(staffActor(src), g, d.confirm)
    if ok then Selected[src] = nil end
    return ok, msg
end

A.addMember = function(src, d, g)
    local target = U.int(d.target, 1, 65535) or U.text(d.target, 50)
    return Members.add(staffActor(src), g, target, U.int(d.gradeId, 1))
end
A.removeMember = function(src, d, g) return Members.remove(staffActor(src), g, U.text(d.cid, 50)) end
A.setMemberGrade = function(src, d, g) return Members.setGrade(staffActor(src), g, U.text(d.cid, 50), U.int(d.gradeId, 1)) end
A.promote = function(src, d, g) return Members.step(staffActor(src), g, U.text(d.cid, 50), 1) end
A.demote = function(src, d, g) return Members.step(staffActor(src), g, U.text(d.cid, 50), -1) end

A.createGrade = function(src, d, g) return Grades.create(staffActor(src), g, d) end
A.updateGrade = function(src, d, g) return Grades.update(staffActor(src), g, U.int(d.gradeId, 1), d) end
A.deleteGrade = function(src, d, g) return Grades.delete(staffActor(src), g, U.int(d.gradeId, 1)) end
A.moveGrade = function(src, d, g) return Grades.move(staffActor(src), g, U.int(d.gradeId, 1), U.int(d.dir, -1, 1)) end

A.money = function(src, d, g) return Finances.adminAdjust(staffActor(src), g, d.account, d.amount, d.add == true, d.reason) end

A.setPed = function(src, d, g) return Peds.set(staffActor(src), g, d) end
A.removePed = function(src, d, g) return Peds.remove(staffActor(src), g) end
A.respawnPed = function(src, d, g) return Peds.respawn(staffActor(src), g) end
A.gotoPed = function(src, d, g)
    if not g.ped then return false, 'Ce groupe n\'a pas de PNJ.' end
    -- Téléportation existante du menu staff (aucun nouvel évènement côté admin_menu)
    TriggerClientEvent('adminmenu:teleport', src, { x = g.ped.x, y = g.ped.y + 1.0, z = g.ped.z + 1.0 })
    return true
end

A.createOrder = function(src, d, g) return Orders.create(staffActor(src), (not d.global) and g or nil, d) end
A.updateOrder = function(src, d, g) return Orders.update(staffActor(src), g, U.int(d.orderId, 1), d) end
A.deleteOrder = function(src, d, g) return Orders.delete(staffActor(src), g, U.int(d.orderId, 1)) end
A.validateRequest = function(src, d, g) return Orders.validate(staffActor(src), g, U.int(d.requestId, 1)) end
A.refuseRequest = function(src, d, g) return Orders.refuse(staffActor(src), g, U.int(d.requestId, 1)) end

-- Actions qui n'ont pas besoin d'un groupe existant
local NO_GROUP = { select = true, back = true, createGroup = true }
-- Commandes « tous les groupes » : le groupe est facultatif
local OPTIONAL_GROUP = { createOrder = true, updateOrder = true, deleteOrder = true }

exports('AdminAction', function(src, name, data)
    src = tonumber(src)
    if not src or not Players.isStaff(src) then return false, 'Permission refusée.' end
    local fn = A[name]
    if not fn then return false, 'Action inconnue.' end
    if not Cache.ready then return false, 'Le module illégal démarre, réessaie dans un instant.' end
    data = type(data) == 'table' and data or {}

    local g
    if not NO_GROUP[name] then
        local err
        g, err = needGroup(data)
        if not g and not (OPTIONAL_GROUP[name] and data.id == nil) then return false, err end
    end
    local ok, res, msg = pcall(fn, src, data, g)
    if not ok then
        print(('^1[ILLEGAL] Erreur pendant l\'action staff « %s » : %s^7'):format(name, tostring(res)))
        return false, 'Erreur interne (voir la console serveur).'
    end
    return res, msg
end)
