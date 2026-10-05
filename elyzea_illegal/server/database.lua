-- =========================================================
--  ELYZEA ILLÉGAL - BASE DE DONNÉES (oxmysql)
--  Seule couche qui écrit du SQL. Les tables sont créées au
--  démarrage depuis sql/install.sql si elles n'existent pas.
-- =========================================================
DB = {}
local RES = GetCurrentResourceName()

function DB.install()
    local raw = LoadResourceFile(RES, 'sql/install.sql')
    if not raw then
        print('^1[ILLEGAL] sql/install.sql introuvable : crée les tables à la main.^7')
        return false
    end
    raw = raw:gsub('%-%-[^\n]*', '')   -- commentaires
    for stmt in raw:gmatch('[^;]+') do
        if stmt:find('%S') then
            local ok, err = pcall(MySQL.query.await, stmt)
            if not ok then
                print(('^1[ILLEGAL] Erreur SQL à l\'installation : %s^7'):format(tostring(err)))
                return false
            end
        end
    end
    -- Installations existantes : colonnes de livraison ajoutées si elles manquent
    local cols = {}
    for _, r in ipairs(MySQL.query.await([[SELECT COLUMN_NAME AS c FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'illegal_order_requests']]) or {}) do cols[r.c] = true end
    if not cols.ready_at then MySQL.query.await('ALTER TABLE illegal_order_requests ADD COLUMN ready_at INT UNSIGNED NULL') end
    if not cols.spot then MySQL.query.await('ALTER TABLE illegal_order_requests ADD COLUMN spot LONGTEXT NULL') end
    return true
end

local function enc(t) return json.encode(t or {}) end

-- ---------------------------------------------------------
--  Lecture complète au démarrage (une seule fois)
-- ---------------------------------------------------------
function DB.loadAll()
    return {
        groups   = MySQL.query.await('SELECT id, name, label, type, description, color, settings, created_by, UNIX_TIMESTAMP(created_at) AS created FROM illegal_groups') or {},
        grades   = MySQL.query.await('SELECT id, group_id, name, label, level, is_boss, permissions FROM illegal_grades') or {},
        members  = MySQL.query.await('SELECT citizenid, group_id, grade_id, name, UNIX_TIMESTAMP(joined_at) AS joined, UNIX_TIMESTAMP(last_seen) AS last_seen FROM illegal_members') or {},
        finances = MySQL.query.await('SELECT group_id, clean, dirty FROM illegal_finances') or {},
        peds     = MySQL.query.await('SELECT group_id, model, x, y, z, heading, scenario, menu FROM illegal_peds') or {},
        orders   = MySQL.query.await('SELECT id, group_id, name, description, category, price, payment, available, item, item_count, created_by FROM illegal_orders') or {},
        requests = MySQL.query.await([[SELECT id, group_id, order_id, order_name, quantity, total, account, item, item_count, status, requester, requester_cid, handled_by,
            ready_at, spot, UNIX_TIMESTAMP(created_at) AS created FROM illegal_order_requests
            WHERE status IN ('pending', 'preparing', 'ready') OR created_at > NOW() - INTERVAL 7 DAY]]) or {},
        spots    = MySQL.query.await('SELECT id, label, x, y, z, heading FROM illegal_delivery_spots') or {},
    }
end

-- Dernières transactions / logs d'un groupe (pour le cache)
function DB.recentTransactions(groupId, limit)
    return MySQL.query.await([[SELECT id, account, type, amount, balance_before, balance_after, actor, reason, UNIX_TIMESTAMP(created_at) AS created
        FROM illegal_transactions WHERE group_id = ? ORDER BY id DESC LIMIT ?]], { groupId, limit }) or {}
end

function DB.transactionsPage(groupId, beforeId, limit)
    return MySQL.query.await([[SELECT id, account, type, amount, balance_before, balance_after, actor, reason, UNIX_TIMESTAMP(created_at) AS created
        FROM illegal_transactions WHERE group_id = ? AND id < ? ORDER BY id DESC LIMIT ?]], { groupId, beforeId, limit }) or {}
end

function DB.recentLogs(groupId, limit)
    return MySQL.query.await('SELECT actor, action, details, UNIX_TIMESTAMP(created_at) AS created FROM illegal_logs WHERE group_id = ? ORDER BY id DESC LIMIT ?',
        { groupId, limit }) or {}
end

-- ---------------------------------------------------------
--  Groupes
-- ---------------------------------------------------------
-- Création atomique : groupe + grades + finances (+ PNJ) dans une transaction
function DB.createGroup(g, grades, ped)
    local id = MySQL.insert.await('INSERT INTO illegal_groups (name, label, type, description, color, settings, created_by) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { g.name, g.label, g.type, g.description, g.color, enc(g.settings), g.createdBy })
    if not id then return nil end
    local queries = { { query = 'INSERT INTO illegal_finances (group_id, clean, dirty) VALUES (?, 0, 0)', values = { id } } }
    for _, gr in ipairs(grades) do
        queries[#queries + 1] = { query = 'INSERT INTO illegal_grades (group_id, name, label, level, is_boss, permissions) VALUES (?, ?, ?, ?, ?, ?)',
            values = { id, gr.name, gr.label, gr.level, gr.boss and 1 or 0, enc(gr.perms) } }
    end
    if ped then
        queries[#queries + 1] = { query = 'INSERT INTO illegal_peds (group_id, model, x, y, z, heading, scenario, menu) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
            values = { id, ped.model, ped.x, ped.y, ped.z, ped.h, ped.scenario or '', enc(ped.menu) } }
    end
    if not MySQL.transaction.await(queries) then
        MySQL.query.await('DELETE FROM illegal_groups WHERE id = ?', { id })
        return nil
    end
    local rows = MySQL.query.await('SELECT id, name FROM illegal_grades WHERE group_id = ?', { id }) or {}
    return id, rows
end

function DB.updateGroup(id, g)
    return MySQL.update.await('UPDATE illegal_groups SET label = ?, type = ?, description = ?, color = ?, settings = ? WHERE id = ?',
        { g.label, g.type, g.description, g.color, enc(g.settings), id })
end

function DB.deleteGroup(id)
    -- Les membres référencent les grades : on les retire d'abord, le reste part en cascade
    return MySQL.transaction.await({
        { query = 'DELETE FROM illegal_members WHERE group_id = ?', values = { id } },
        { query = 'DELETE FROM illegal_groups WHERE id = ?', values = { id } },
    })
end

function DB.nameTaken(name)
    return MySQL.scalar.await('SELECT 1 FROM illegal_groups WHERE name = ?', { name }) ~= nil
end

-- ---------------------------------------------------------
--  Grades
-- ---------------------------------------------------------
function DB.insertGrade(groupId, gr)
    return MySQL.insert.await('INSERT INTO illegal_grades (group_id, name, label, level, is_boss, permissions) VALUES (?, ?, ?, ?, ?, ?)',
        { groupId, gr.name, gr.label, gr.level, gr.boss and 1 or 0, enc(gr.perms) })
end

function DB.updateGrade(gr)
    return MySQL.update.await('UPDATE illegal_grades SET name = ?, label = ?, level = ?, is_boss = ?, permissions = ? WHERE id = ?',
        { gr.name, gr.label, gr.level, gr.boss and 1 or 0, enc(gr.perms), gr.id })
end

function DB.swapGradeLevels(a, b)
    return MySQL.transaction.await({
        { query = 'UPDATE illegal_grades SET level = ? WHERE id = ?', values = { a.level, a.id } },
        { query = 'UPDATE illegal_grades SET level = ? WHERE id = ?', values = { b.level, b.id } },
    })
end

-- Supprime un grade en déplaçant ses membres vers un autre grade
function DB.deleteGrade(gradeId, fallbackId)
    return MySQL.transaction.await({
        { query = 'UPDATE illegal_members SET grade_id = ? WHERE grade_id = ?', values = { fallbackId, gradeId } },
        { query = 'DELETE FROM illegal_grades WHERE id = ?', values = { gradeId } },
    })
end

-- ---------------------------------------------------------
--  Membres
-- ---------------------------------------------------------
function DB.insertMember(cid, groupId, gradeId, name)
    return MySQL.insert.await('INSERT INTO illegal_members (citizenid, group_id, grade_id, name, last_seen) VALUES (?, ?, ?, ?, NOW())',
        { cid, groupId, gradeId, name })
end

function DB.setMemberGrade(cid, gradeId)
    return MySQL.update.await('UPDATE illegal_members SET grade_id = ? WHERE citizenid = ?', { gradeId, cid })
end

function DB.deleteMember(cid)
    return MySQL.update.await('DELETE FROM illegal_members WHERE citizenid = ?', { cid })
end

function DB.touchMember(cid, name)
    MySQL.update('UPDATE illegal_members SET last_seen = NOW(), name = ? WHERE citizenid = ?', { name, cid })
end

-- Personnage existant (même hors ligne) dans la table Qbox
function DB.findCharacter(cid)
    local ok, row = pcall(MySQL.single.await, 'SELECT citizenid, charinfo FROM players WHERE citizenid = ?', { cid })
    if not ok or not row then return nil end
    local ci = json.decode(row.charinfo or '{}') or {}
    local name = ((ci.firstname or '') .. ' ' .. (ci.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
    return { citizenid = row.citizenid, name = name ~= '' and name or row.citizenid }
end

-- ---------------------------------------------------------
--  Finances : mise à jour conditionnelle (jamais de solde négatif)
-- ---------------------------------------------------------
local ACCOUNT_COL = { clean = 'clean', dirty = 'dirty' }

function DB.addBalance(groupId, account, amount)
    local col = ACCOUNT_COL[account]
    return MySQL.update.await(('UPDATE illegal_finances SET %s = %s + ? WHERE group_id = ?'):format(col, col), { amount, groupId }) == 1
end

function DB.removeBalance(groupId, account, amount)
    local col = ACCOUNT_COL[account]
    return MySQL.update.await(('UPDATE illegal_finances SET %s = %s - ? WHERE group_id = ? AND %s >= ?'):format(col, col, col), { amount, groupId, amount }) == 1
end

function DB.insertTransaction(groupId, tx)
    return MySQL.insert.await([[INSERT INTO illegal_transactions (group_id, account, type, amount, balance_before, balance_after, actor, actor_cid, reason)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)]], { groupId, tx.account, tx.type, tx.amount, tx.before, tx.after, tx.actor, tx.actorCid, tx.reason or '' })
end

-- ---------------------------------------------------------
--  PNJ
-- ---------------------------------------------------------
function DB.savePed(groupId, p)
    return MySQL.query.await([[INSERT INTO illegal_peds (group_id, model, x, y, z, heading, scenario, menu) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE model = VALUES(model), x = VALUES(x), y = VALUES(y), z = VALUES(z), heading = VALUES(heading),
        scenario = VALUES(scenario), menu = VALUES(menu)]], { groupId, p.model, p.x, p.y, p.z, p.h, p.scenario or '', enc(p.menu) })
end

function DB.deletePed(groupId)
    return MySQL.update.await('DELETE FROM illegal_peds WHERE group_id = ?', { groupId })
end

-- ---------------------------------------------------------
--  Commandes
-- ---------------------------------------------------------
function DB.insertOrder(o)
    return MySQL.insert.await([[INSERT INTO illegal_orders (group_id, name, description, category, price, payment, available, item, item_count, created_by)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]], { o.groupId, o.name, o.description, o.category, o.price, o.payment, o.available and 1 or 0, o.item, o.itemCount, o.createdBy })
end

function DB.updateOrder(o)
    return MySQL.update.await([[UPDATE illegal_orders SET name = ?, description = ?, category = ?, price = ?, payment = ?, available = ?, item = ?, item_count = ? WHERE id = ?]],
        { o.name, o.description, o.category, o.price, o.payment, o.available and 1 or 0, o.item, o.itemCount, o.id })
end

function DB.deleteOrder(id)
    return MySQL.update.await('DELETE FROM illegal_orders WHERE id = ?', { id })
end

function DB.insertRequest(r)
    return MySQL.insert.await([[INSERT INTO illegal_order_requests (group_id, order_id, order_name, quantity, total, account, item, item_count, status, requester, requester_cid)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'pending', ?, ?)]], { r.groupId, r.orderId, r.orderName, r.quantity, r.total, r.account, r.item, r.itemCount, r.requester, r.requesterCid })
end

-- Changement d'état conditionnel : n'aboutit que si l'état attendu est encore le bon (anti double validation)
function DB.setRequestStatus(id, from, to, by)
    return MySQL.update.await('UPDATE illegal_order_requests SET status = ?, handled_by = COALESCE(?, handled_by), updated_at = NOW() WHERE id = ? AND status = ?',
        { to, by, id, from }) == 1
end

-- Commande payée : la livraison démarre (préparation jusqu'à ready_at, au lieu « spot »)
function DB.startDelivery(id, from, readyAt, spot, by)
    return MySQL.update.await([[UPDATE illegal_order_requests SET status = 'preparing', ready_at = ?, spot = ?, handled_by = COALESCE(?, handled_by), updated_at = NOW()
        WHERE id = ? AND status = ?]], { readyAt, json.encode(spot), by, id, from }) == 1
end

-- ---------------------------------------------------------
--  Lieux de livraison
-- ---------------------------------------------------------
function DB.insertSpot(s)
    return MySQL.insert.await('INSERT INTO illegal_delivery_spots (label, x, y, z, heading) VALUES (?, ?, ?, ?, ?)', { s.label, s.x, s.y, s.z, s.h })
end

function DB.deleteSpot(id)
    return MySQL.update.await('DELETE FROM illegal_delivery_spots WHERE id = ?', { id })
end

-- ---------------------------------------------------------
--  Logs
-- ---------------------------------------------------------
function DB.insertLog(groupId, actor, action, details)
    MySQL.insert('INSERT INTO illegal_logs (group_id, actor, action, details) VALUES (?, ?, ?, ?)', { groupId, actor, action, details })
end
