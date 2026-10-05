-- =========================================================
--  Tests serveur de elyzea_illegal (hors jeu)
--  Lancer depuis la racine du dépôt :  lua5.4 tests/run.lua
-- =========================================================
package.path = './tests/?.lua;' .. package.path
local M = require('mocks')
local ROOT = 'elyzea_illegal/'
for _, f in ipairs({ 'config.lua', 'shared/constants.lua', 'shared/utils.lua' }) do dofile(ROOT .. f) end
dofile('tests/db_memory.lua')
for _, f in ipairs({ 'logs', 'players', 'cache', 'sync', 'groups', 'grades', 'members', 'finances', 'peds', 'orders', 'deliveries', 'tablet', 'admin', 'main' }) do
    dofile(ROOT .. 'server/' .. f .. '.lua')
end
M.flush()

-- ---------- mini framework ----------
local passed, failed = 0, 0
local function check(cond, label)
    if cond then passed = passed + 1 else failed = failed + 1 M.print('  ✗ ' .. label) end
end
local function section(name) M.print('▶ ' .. name) end

local function admin(name, data) local ok, msg = M.res:AdminAction(99, name, data) M.flush() return ok, msg end
local function act(src, name, data) M.fromClient(src, 'illegal:server:action', name, data or {}) M.advance(5000) end
local function open(src, via, gid) M.fromClient(src, 'illegal:server:open', via, gid) M.advance(5000) end

-- Acteurs
M.addPlayer(99, 'STAFF1', 'Admin', 'Staff', { staff = true, coords = vector3(100, 200, 30) })
M.addPlayer(1, 'CID_A', 'John', 'Doe', { cash = 100000, dirty = 300000, coords = vector3(100, 200, 30) })
M.addPlayer(2, 'CID_B', 'Mike', 'Ross', { cash = 5000, dirty = 0 })
M.addPlayer(3, 'CID_C', 'Carl', 'Vago', { cash = 1000 })
M.addPlayer(4, 'CID_D', 'Dana', 'Free', { cash = 0 })

-- =========================================================
section('Création de groupes (staff)')
-- =========================================================
check(M.res:AdminAction(1, 'createGroup', { name = 'pirate', label = 'Pirate', type = 'gang' }) == false, 'un non-staff ne peut pas appeler AdminAction')
check(admin('createGroup', { name = 'Bad Name!', label = 'X', type = 'gang' }) == false, 'nom interne invalide refusé')
check(admin('createGroup', { name = 'bloods', label = 'Bloods', type = 'mafia' }) == false, 'type inexistant refusé')
check(admin('createGroup', { name = 'bloods', label = 'Bloods', type = 'gang', description = 'Gang criminel', color = '#aa0000',
    pedModel = 'g_m_y_ballaeast_01', pedHere = true }) == true, 'création Bloods')
check(admin('createGroup', { name = 'bloods', label = 'Autre', type = 'cartel' }) == false, 'nom interne unique')
local bloods = Cache.byName('bloods')
check(bloods and bloods.type == 'gang', 'type enregistré : gang')
check(bloods and bloods.ped and bloods.ped.model == 'g_m_y_ballaeast_01' and math.abs(bloods.ped.z - 29) < 0.01, 'PED placé à la position du staff')
local nGrades = 0 for _ in pairs(bloods.grades) do nGrades = nGrades + 1 end
check(nGrades == 6, 'grades du modèle gang créés (6)')
local OG, RECRUE, LIEUT
for _, gr in pairs(bloods.grades) do
    if gr.name == 'og' then OG = gr elseif gr.name == 'recrue' then RECRUE = gr elseif gr.name == 'lieutenant' then LIEUT = gr end
end
check(OG and OG.boss, 'grade OG = chef')
check(admin('createGroup', { name = 'vagos', label = 'Vagos', type = 'gang' }) == true, 'création Vagos (sans PED)')
local vagos = Cache.byName('vagos')
check(vagos.ped == nil, 'Vagos sans PED')
check(admin('createGroup', { name = 'sinaloa', label = 'Cartel Sinaloa', type = 'cartel' }) == true, 'création cartel')
local data = M.res:AdminData(99)
check(data.stats.groups == 3 and data.stats.gang == 2 and data.stats.cartel == 1 and data.stats.organisation == 0, 'dashboard : compteurs par type')

-- =========================================================
section('Membres (staff) et accès F5')
-- =========================================================
check(admin('addMember', { id = bloods.id, target = 1, gradeId = OG.id }) == true, 'staff ajoute John (id 1) comme OG')
check(admin('addMember', { id = vagos.id, target = 1 }) == false, 'un personnage ne peut pas être dans deux groupes')
check(admin('addMember', { id = vagos.id, target = 3 }) == true, 'Carl rejoint Vagos (grade le plus bas par défaut)')
check(admin('addMember', { id = bloods.id, target = 'OFFLINE1' }) == true, 'staff ajoute un personnage hors ligne par citizenid')
check(admin('addMember', { id = bloods.id, target = 'NOPE' }) == false, 'citizenid inexistant refusé')
check(admin('addMember', { id = bloods.id, target = 77 }) == false, 'ID joueur inexistant refusé')
local ms = M.lastClientEvent(1, 'illegal:client:membership')
check(ms and ms.args[1].inGroup and ms.args[1].label == 'Bloods', 'F5 de John : « Bloods » envoyé au client')

open(4, 'f5')
check(M.lastNotify(4) and M.lastNotify(4):find('aucun groupe'), 'sans groupe : pas de tablette')
check(Sessions[4] == nil, 'aucune session pour un joueur sans groupe')
act(4, 'deposit', { account = 'clean', amount = 10 })
check(bloods.finance.clean == 0, 'action sans tablette ouverte ignorée')

open(1, 'f5')
local opened = M.lastClientEvent(1, 'illegal:client:openTablet')
check(opened and opened.args[1].group.name == 'bloods', 'John ouvre la tablette Bloods')
check(opened and opened.args[1].me.boss and opened.args[1].me.perms.manage_grades, 'OG : toutes les permissions')

-- =========================================================
section('Recrutement et hiérarchie (tablette)')
-- =========================================================
act(1, 'recruit', { target = 2, gradeId = OG.id })
check(Cache.memberOf.CID_B == nil, 'OG ne peut pas recruter au niveau OG')
act(1, 'recruit', { target = 3, gradeId = RECRUE.id })
check(Cache.memberOf.CID_C == vagos.id, 'recruter un membre d\'un autre groupe est refusé')
act(1, 'recruit', { target = 2, gradeId = RECRUE.id })
check(Cache.memberOf.CID_B == bloods.id and bloods.members.CID_B.gradeId == RECRUE.id, 'John recrute Mike comme Recrue')
check(M.lastClientEvent(2, 'illegal:client:membership').args[1].inGroup, 'Mike reçoit son groupe sans redémarrage')

open(2, 'f5')
act(2, 'kick', { cid = 'CID_A' })
check(bloods.members.CID_A ~= nil, 'Recrue ne peut pas exclure l\'OG')
act(2, 'deposit', { account = 'clean', amount = 100 })
check(bloods.finance.clean == 0, 'Recrue sans permission de dépôt : refusé')
act(2, 'createGrade', { name = 'boss2', label = 'Boss', level = 5 })
check(not next((function() local t = {} for _, g in pairs(bloods.grades) do if g.name == 'boss2' then t[1] = 1 end end return t end)()), 'Recrue ne peut pas créer de grade')

act(1, 'promote', { cid = 'CID_B' })
local membre = bloods.grades[bloods.members.CID_B.gradeId]
check(membre.name == 'membre', 'OG promeut Mike (Recrue → Membre)')
act(1, 'setGrade', { cid = 'CID_B', gradeId = LIEUT.id })
check(bloods.members.CID_B.gradeId == LIEUT.id, 'OG passe Mike Lieutenant')
act(1, 'setGrade', { cid = 'CID_A', gradeId = RECRUE.id })
check(bloods.members.CID_A.gradeId == OG.id, 'personne ne change son propre grade')

-- Lieutenant : recruit/promote/set_grade, pas kick ni manage_grades
act(2, 'kick', { cid = 'OFFLINE1' })
check(bloods.members.OFFLINE1 ~= nil, 'Lieutenant sans permission « exclusion » : refusé')
act(2, 'setGrade', { cid = 'OFFLINE1', gradeId = LIEUT.id })
check(bloods.grades[bloods.members.OFFLINE1.gradeId].level < LIEUT.level, 'Lieutenant ne peut pas donner son propre niveau')

-- =========================================================
section('Grades personnalisés et permissions')
-- =========================================================
act(1, 'createGrade', { name = 'sergent', label = 'Sergent', level = 100 })
check(not (function() for _, g in pairs(bloods.grades) do if g.name == 'sergent' then return true end end end)(), 'niveau >= au sien refusé')
act(1, 'createGrade', { name = 'sergent', label = 'Sergent', level = 40, perms = { recruit = true, kick = true, hack = true } })
local SERGENT
for _, g in pairs(bloods.grades) do if g.name == 'sergent' then SERGENT = g end end
check(SERGENT and SERGENT.perms.recruit and SERGENT.perms.kick and not SERGENT.perms.hack, 'OG crée « Sergent » (permission inconnue ignorée)')
act(1, 'createGrade', { name = 'sergent', label = 'Doublon', level = 41 })
local dup = 0 for _, g in pairs(bloods.grades) do if g.name == 'sergent' then dup = dup + 1 end end
check(dup == 1, 'nom de grade unique dans le groupe')
-- Mike (Lieutenant) reçoit manage_grades par le staff, puis tente de donner « kick » qu'il n'a pas
local lp = {} for k in pairs(LIEUT.perms) do lp[k] = true end lp.manage_grades = true
check(admin('updateGrade', { id = bloods.id, gradeId = LIEUT.id, name = 'lieutenant', label = 'Lieutenant', level = 50, perms = lp }) == true, 'staff modifie les permissions du Lieutenant')
act(2, 'createGrade', { name = 'escroc', label = 'Escroc', level = 15, perms = { kick = true, recruit = true } })
local ESCROC
for _, g in pairs(bloods.grades) do if g.name == 'escroc' then ESCROC = g end end
check(ESCROC and ESCROC.perms.recruit and not ESCROC.perms.kick, 'anti-escalade : on ne donne pas une permission qu\'on n\'a pas')
act(2, 'updateGrade', { id = OG.id, name = 'og', label = 'Nul', level = 1 })
check(OG.label == 'OG', 'modifier un grade supérieur est refusé')
act(2, 'createGrade', { name = 'faux_og', label = 'Faux OG', level = 12, boss = true })
local fake
for _, g in pairs(bloods.grades) do if g.name == 'faux_og' then fake = g end end
check(fake and not fake.boss, 'un joueur ne peut pas créer de grade chef')
act(1, 'deleteGrade', { id = OG.id })
check(bloods.grades[OG.id] ~= nil, 'impossible de supprimer son propre grade / le seul grade chef')
check(admin('deleteGrade', { id = bloods.id, gradeId = OG.id }) == false, 'staff : le seul grade chef ne se supprime pas')
local before = bloods.members.OFFLINE1.gradeId
check(admin('deleteGrade', { id = bloods.id, gradeId = before }) == true, 'staff supprime le grade de OFFLINE1')
check(bloods.members.OFFLINE1.gradeId ~= before and bloods.grades[bloods.members.OFFLINE1.gradeId], 'ses membres passent à un grade existant')
LIEUT = bloods.grades[LIEUT.id]   -- l'objet est remplacé à chaque modification
local lvlS, lvlL = SERGENT.level, LIEUT.level
check(admin('moveGrade', { id = bloods.id, gradeId = SERGENT.id, dir = 1 }) == true, 'staff réorganise les grades')
check(SERGENT.level == lvlL and LIEUT.level == lvlS, 'niveaux échangés')
admin('moveGrade', { id = bloods.id, gradeId = SERGENT.id, dir = -1 })
SERGENT, LIEUT = bloods.grades[SERGENT.id], bloods.grades[LIEUT.id]

-- =========================================================
section('Finances : argent propre / sale')
-- =========================================================
act(1, 'deposit', { account = 'clean', amount = 500000 })
check(bloods.finance.clean == 0 and M.players[1].qbx.PlayerData.money.cash == 100000, 'dépôt supérieur à l\'argent du joueur refusé')
for _, bad in ipairs({ -50, 0, 0.4, 'abc', 1e300, 0 / 0, math.huge, {} }) do
    act(1, 'deposit', { account = 'clean', amount = bad })
end
check(bloods.finance.clean == 0 and M.players[1].qbx.PlayerData.money.cash == 100000, 'montants invalides (négatif, 0, NaN, infini, texte) refusés')
act(1, 'deposit', { account = 'gold', amount = 10 })
check(bloods.finance.clean == 0 and bloods.finance.dirty == 0, 'compte inexistant refusé')
act(1, 'deposit', { account = 'clean', amount = 50000 })
check(bloods.finance.clean == 50000 and M.players[1].qbx.PlayerData.money.cash == 50000, 'dépôt de 50 000 $ d\'argent propre')
check(bloods.finance.dirty == 0, 'argent sale non touché par un dépôt propre')
act(1, 'deposit', { account = 'dirty', amount = 200000 })
check(bloods.finance.dirty == 200000 and M.players[1].items.black_money == 100000 and bloods.finance.clean == 50000, 'dépôt d\'argent sale (objet), comptes séparés')
act(1, 'withdraw', { account = 'clean', amount = 60000 })
check(bloods.finance.clean == 50000 and M.players[1].qbx.PlayerData.money.cash == 50000, 'retrait supérieur au solde refusé')
act(1, 'withdraw', { account = 'clean', amount = 20000 })
check(bloods.finance.clean == 30000 and M.players[1].qbx.PlayerData.money.cash == 70000, 'retrait de 20 000 $')
check(DB._tables.finances[bloods.id].clean == 30000, 'solde enregistré en base')

-- Double transaction : une opération déjà en cours bloque la suivante
Finances.lock(bloods.id)
act(1, 'withdraw', { account = 'clean', amount = 1000 })
check(bloods.finance.clean == 30000, 'opération concurrente refusée (verrou)')
Finances.unlock(bloods.id)
-- Cache désynchronisé : la base refuse le retrait, le joueur ne reçoit rien
bloods.finance.clean = 999999
local cashBefore = M.players[1].qbx.PlayerData.money.cash
act(1, 'withdraw', { account = 'clean', amount = 500000 })
check(M.players[1].qbx.PlayerData.money.cash == cashBefore and DB._tables.finances[bloods.id].clean == 30000, 'la base empêche tout solde négatif (anti-duplication)')
bloods.finance.clean = 30000
-- Inventaire plein : le retrait d'argent sale est annulé et l'argent revient au groupe
M.players[1].canCarry = false
act(1, 'withdraw', { account = 'dirty', amount = 50000 })
check(bloods.finance.dirty == 200000 and DB._tables.finances[bloods.id].dirty == 200000, 'retrait annulé si le joueur ne peut pas recevoir')
M.players[1].canCarry = true
-- Échec base au dépôt : le joueur est remboursé
DB.failNext.addBalance = true
act(1, 'deposit', { account = 'clean', amount = 1000 })
check(M.players[1].qbx.PlayerData.money.cash == cashBefore and bloods.finance.clean == 30000, 'dépôt annulé et remboursé si la base échoue')

local hist = Cache.transactions(bloods)
check(#hist == 3, 'historique : 3 transactions réussies')
check(hist[1].type == 'withdraw' and hist[1].amount == -20000 and hist[1].before == 50000 and hist[1].after == 30000 and hist[1].actor == 'John Doe',
    'historique : joueur, type, montant, solde avant/après')
check(admin('money', { id = bloods.id, account = 'dirty', amount = 1000, add = true, reason = 'Event' }) == true and bloods.finance.dirty == 201000, 'staff ajoute de l\'argent sale')
check(admin('money', { id = bloods.id, account = 'clean', amount = 999999, add = false }) == false and bloods.finance.clean == 30000, 'staff ne peut pas rendre un solde négatif')
check(Cache.transactions(bloods)[1].type == 'admin_add', 'action staff dans l\'historique')

-- =========================================================
section('Isolation entre groupes')
-- =========================================================
open(3, 'f5')
local vt = M.lastClientEvent(3, 'illegal:client:openTablet').args[1]
check(vt.group.name == 'vagos' and vt.finance == nil, 'Carl ne voit que Vagos (et pas les soldes : Recrue)')
check(admin('updateGrade', { id = vagos.id, gradeId = Cache.lowestGrade(vagos).id, name = Cache.lowestGrade(vagos).name, label = 'Recrue',
    level = Cache.lowestGrade(vagos).level, perms = { kick = true, clean_withdraw = true, finance_view = true } }) == true, 'staff donne des droits au grade de Carl')
act(3, 'kick', { cid = 'CID_B' })
check(bloods.members.CID_B ~= nil, 'Carl ne peut pas exclure un membre des Bloods')
act(3, 'withdraw', { account = 'clean', amount = 100, group = 'bloods', groupId = bloods.id })
check(bloods.finance.clean == 30000, 'envoyer group = "bloods" ne donne aucun accès aux Bloods')
open(3, 'ped', bloods.id)
check(M.lastNotify(3) == nil or not Sessions[3] or Sessions[3].groupId == vagos.id, 'PED Bloods loin : rien ne se passe')
M.players[3].coords = vector3(100, 200, 30)
open(3, 'ped', bloods.id)
check(M.lastNotify(3) == 'Vous n\'êtes pas membre de ce groupe.', 'PED Bloods de près : « Vous n\'êtes pas membre de ce groupe. »')

-- =========================================================
section('PED et menu du PED')
-- =========================================================
M.players[2].coords = vector3(500, 500, 30)
open(2, 'ped', bloods.id)
check(Sessions[2] and Sessions[2].via == 'f5', 'Mike loin du PED : pas de session PED')
M.players[2].coords = vector3(100, 201, 30)
open(2, 'ped', bloods.id)
check(Sessions[2] and Sessions[2].via == 'ped', 'Mike à côté du PED : tablette ouverte (E)')
check(admin('setPed', { id = bloods.id, menu = { home = true, orders = true } }) == true, 'staff limite le menu du PED')
open(2, 'ped', bloods.id)
act(2, 'deposit', { account = 'dirty', amount = 1 })
check(bloods.finance.dirty == 201000, 'onglet Finances fermé depuis le PED : refusé')
M.players[2].coords = vector3(500, 500, 30)
act(2, 'placeOrder', { id = 1 })
check(M.lastNotify(2) == 'Tu t\'es éloigné du PNJ.', 'action PED refusée si le joueur s\'est éloigné')
check(admin('setPed', { id = bloods.id, x = 10, y = 20, z = 30, h = 450 }) == true and bloods.ped.h == 90, 'PED déplacé, heading normalisé')
check(admin('setPed', { id = bloods.id, x = 1e9, y = 0, z = 0 }) == false, 'coordonnées hors carte refusées')
check(admin('setPed', { id = bloods.id, model = 'bad model;' }) == false, 'modèle invalide refusé')
local v0 = bloods.ped.version
check(admin('respawnPed', { id = bloods.id }) == true and bloods.ped.version == v0 + 1, 'respawn du PED')
check(admin('removePed', { id = vagos.id }) == false, 'supprimer un PED inexistant refusé')

-- =========================================================
section('Commandes : catalogue choisi par le staff')
-- =========================================================
open(2, 'f5')
check(admin('createOrder', { global = true, name = 'Pistolet', category = 'weapons', price = 1000, payment = 'dirty', item = 'weapon_pistol', itemCount = 1 }) == true, 'staff crée une commande pour tous')
local pistol
for _, o in pairs(Cache.orders) do if o.name == 'Pistolet' then pistol = o end end
check(pistol and pistol.groupId == nil and pistol.item == 'weapon_pistol', 'commande globale avec objet')
check(admin('createOrder', { id = bloods.id, name = '', category = 'drugs', price = 50, payment = 'both', item = 'weed', itemCount = 10 }) == true, 'staff choisit un objet pour les Bloods')
local weed
for _, o in pairs(Cache.orders) do if o.item == 'weed' then weed = o end end
check(weed and weed.name == 'Cannabis' and weed.groupId == bloods.id and weed.price == 50, 'nom vide = nom de l\'objet ox_inventory, prix enregistré')
check(admin('createOrder', { id = bloods.id, name = 'X', category = 'other', price = 1, payment = 'dirty', item = 'objet_inexistant' }) == false, 'objet inexistant dans ox_inventory refusé')
act(2, 'createOrder', { name = 'Kalash', category = 'weapons', price = 1, payment = 'clean', item = 'weapon_assaultrifle', itemCount = 50 })
check(not (function() for _, o in pairs(Cache.orders) do if o.name == 'Kalash' then return true end end end)(), 'les joueurs ne créent pas de commande (catalogue staff)')
act(2, 'updateOrder', { id = pistol.id, name = 'Pistolet', category = 'weapons', price = 0, payment = 'dirty' })
check(pistol.price == 1000, 'un joueur ne modifie pas le catalogue')
act(3, 'placeOrder', { id = weed.id, quantity = 1, account = 'dirty' })
check(not (function() for _, r in pairs(Cache.requests) do if r.groupId == vagos.id then return true end end end)(), 'Vagos ne peut pas commander le catalogue des Bloods')
local vt2 = Tablet.build(3)
check(vt2 and #vt2.orders == 1 and vt2.orders[1].name == 'Pistolet', 'Vagos ne voit que les commandes pour tous')

-- =========================================================
section('Commandes : paiement et livraison')
-- =========================================================
act(2, 'placeOrder', { id = pistol.id, quantity = 999 })
check(not next(Cache.requests), 'quantité hors limite refusée')
M.players[2].coords = vector3(500, 500, 30)
local dirtyBefore = bloods.finance.dirty
act(2, 'placeOrder', { id = pistol.id, quantity = 2, account = 'clean' })
local req
for _, r in pairs(Cache.requests) do if r.orderName == 'Pistolet' then req = r end end
check(req and req.quantity == 2 and req.account == 'dirty' and req.total == 2000, 'commande passée (paiement imposé : sale)')
check(req and req.status == 'preparing' and bloods.finance.dirty == dirtyBefore - 2000, 'payée tout de suite par le coffre du groupe, en préparation')
check(req and req.readyAt and req.readyAt - os.time() >= 299 and req.readyAt - os.time() <= 300, 'prête dans 5 minutes')
check(req and req.spot and math.sqrt((req.spot.x - 500) ^ 2 + (req.spot.y - 500) ^ 2) >= Config.Delivery.minDistance, 'lieu de livraison éloigné du joueur')
local ph = M.lastClientEvent(2, 'illegal:client:phone')
check(ph and ph.args[2]:find('en préparation') and ph.args[2]:find('5 minutes'), 'notification téléphone : en préparation, disponible dans 5 minutes')
check(M.lastClientEvent(2, 'illegal:client:delivery') == nil, 'aucun point GPS avant la fin de la préparation')
check(Cache.transactions(bloods)[1].type == 'order' and Cache.transactions(bloods)[1].amount == -2000, 'paiement dans l\'historique financier')
act(2, 'placeOrder', { id = weed.id, quantity = 1, account = 'clean' })
local n = 0 for _ in pairs(Cache.requests) do n = n + 1 end
check(n == 1, 'une seule livraison en cours par joueur')

local bag = Deliveries.bagPos(req.spot)
M.players[2].coords = vector3(bag.x, bag.y, bag.z)
M.fromClient(2, 'illegal:server:pickup', req.id)
check(req.status == 'preparing' and not M.players[2].items.weapon_pistol, 'impossible de ramasser avant la fin de la préparation')
M.tick()
check(req.status == 'preparing', 'pas prête avant 5 minutes')
req.readyAt = os.time() - 1
M.tick()
check(req.status == 'ready' and DB._tables.requests[req.id].status == 'ready', 'après 5 minutes : prête')
local dl = M.lastClientEvent(2, 'illegal:client:delivery')
check(dl and dl.args[1].id == req.id and dl.args[1].x == req.spot.x and dl.args[2] == true, 'point GPS + blip envoyés à celui qui a commandé')
check(M.lastClientEvent(2, 'illegal:client:phone').args[2]:find('prête'), 'notification téléphone : commande prête')
check(M.lastClientEvent(1, 'illegal:client:delivery') == nil, 'les autres joueurs ne reçoivent pas le lieu')

M.players[1].coords = vector3(bag.x, bag.y, bag.z)
M.fromClient(1, 'illegal:server:pickup', req.id) M.advance(5000)
check(req.status == 'ready' and M.lastNotify(1) == 'Ce sac n\'est pas pour toi.', 'un autre joueur ne peut pas prendre le sac')
M.players[2].coords = vector3(bag.x + 30, bag.y, bag.z)
M.fromClient(2, 'illegal:server:pickup', req.id) M.advance(5000)
check(req.status == 'ready', 'trop loin du sac : rien')
M.players[2].coords = vector3(bag.x, bag.y, bag.z)
M.players[2].canCarry = false
M.fromClient(2, 'illegal:server:pickup', req.id) M.advance(5000)
check(req.status == 'ready' and not M.players[2].items.weapon_pistol, 'inventaire plein : le sac reste là')
M.players[2].canCarry = true
M.fromClient(2, 'illegal:server:pickup', req.id) M.advance(5000)
check(req.status == 'delivered' and M.players[2].items.weapon_pistol == 2, 'sac ramassé : 2 pistolets donnés')
check(M.lastClientEvent(2, 'illegal:client:deliveryDone') and M.lastClientEvent(2, 'illegal:client:deliveryDone').args[1] == req.id, 'les PNJ disparaissent (évènement client)')
M.fromClient(2, 'illegal:server:pickup', req.id) M.advance(5000)
check(M.players[2].items.weapon_pistol == 2, 'pas de double ramassage')

check(admin('createOrder', { id = bloods.id, name = 'Villa', category = 'other', price = 5000000, payment = 'clean' }) == true, 'staff crée une commande chère')
local villa
for _, o in pairs(Cache.orders) do if o.name == 'Villa' then villa = o end end
local cleanBefore = bloods.finance.clean
act(2, 'placeOrder', { id = villa.id, quantity = 1 })
check(bloods.finance.clean == cleanBefore and Deliveries.activeCount('CID_B') == 0, 'coffre insuffisant : refusée, rien débité')

-- Reconnexion : la livraison prête est renvoyée
act(2, 'placeOrder', { id = weed.id, quantity = 2, account = 'clean' })
local wreq
for _, r in pairs(Cache.requests) do if r.orderName == 'Cannabis' then wreq = r end end
check(wreq and wreq.status == 'preparing' and wreq.account == 'clean' and wreq.total == 100 and wreq.itemCount == 20, 'commande « propre ou sale » payée avec le compte choisi')
check(admin('readyNow', { id = bloods.id, requestId = wreq.id }) == true and wreq.status == 'ready', 'staff : « rendre prête maintenant »')
local before = #M.clientEvents
M.fromClient(2, 'illegal:server:hello') M.advance(20000)
local resent = false
for i = before + 1, #M.clientEvents do local e = M.clientEvents[i] if e.target == 2 and e.name == 'illegal:client:delivery' and e.args[1].id == wreq.id then resent = true end end
check(resent, 'reconnexion : point GPS de la commande prête renvoyé')

-- Mode validation (Config.Orders.requireValidation)
Config.Orders.requireValidation = true
local cleanV = bloods.finance.clean
act(1, 'placeOrder', { id = weed.id, quantity = 1, account = 'clean' })
local vreq
for _, r in pairs(Cache.requests) do if r.requesterCid == 'CID_A' then vreq = r end end
check(vreq and vreq.status == 'pending' and bloods.finance.clean == cleanV, 'avec validation : en attente, rien payé')
act(1, 'validateRequest', { id = vreq.id })
check(vreq.status == 'preparing' and bloods.finance.clean == cleanV - 50, 'validée : payée et en préparation')
act(1, 'validateRequest', { id = vreq.id })
check(bloods.finance.clean == cleanV - 50, 'double validation impossible')
Config.Orders.requireValidation = false

-- Points de livraison placés par le staff
M.players[99].coords = vector3(-2000, 3000, 20)
check(admin('addSpot', { label = 'Hangar', useMyPosition = true }) == true, 'staff ajoute un point de livraison à sa position')
local spots = Deliveries.spots()
check(#spots == 1 and spots[1].label == 'Hangar' and spots[1].x == -2000, 'les points du staff remplacent ceux par défaut')
local sid
for id in pairs(Cache.spots) do sid = id end
check(admin('removeSpot', { spotId = sid }) == true and #Deliveries.spots() == #Config.Delivery.defaultSpots, 'suppression : retour aux lieux par défaut')

-- Données réelles pour le test de rendu des interfaces (tests/ui.js)
local FIX = os.getenv('FIXTURES')
if FIX then
    local function dump(name, v) local f = assert(io.open(FIX .. '/' .. name .. '.json', 'w')) f:write(json.encode(v)) f:close() end
    admin('select', { id = bloods.id })
    dump('admin_bloods', M.res:AdminData(99))
    admin('select', { id = vagos.id })
    dump('admin_vagos', M.res:AdminData(99))
    admin('back')
    dump('admin_list', M.res:AdminData(99))
    dump('tablet_og', Tablet.build(1))
    dump('tablet_lieutenant', Tablet.build(2))
    dump('tablet_recrue_vagos', Tablet.build(3))
end

-- =========================================================
section('Rate limit')
-- =========================================================
local n0 = #Cache.transactions(bloods)
for _ = 1, 12 do M.fromClient(1, 'illegal:server:action', 'deposit', { account = 'clean', amount = 1 }) end
check(#Cache.transactions(bloods) - n0 == 8, 'max 8 actions / 2 s par joueur')
M.advance(5000)

-- =========================================================
section('Persistance (redémarrage)')
-- =========================================================
local snapshot = { members = 0, clean = bloods.finance.clean, dirty = bloods.finance.dirty, grades = 0, sergentPerms = SERGENT.perms.kick, ped = bloods.ped.model }
for _ in pairs(bloods.members) do snapshot.members = snapshot.members + 1 end
for _ in pairs(bloods.grades) do snapshot.grades = snapshot.grades + 1 end
Cache.load()
local b2 = Cache.byName('bloods')
local m2, g2 = 0, 0
for _ in pairs(b2.members) do m2 = m2 + 1 end
for _ in pairs(b2.grades) do g2 = g2 + 1 end
check(m2 == snapshot.members and g2 == snapshot.grades, 'membres et grades rechargés')
check(b2.finance.clean == snapshot.clean and b2.finance.dirty == snapshot.dirty, 'finances rechargées')
local s2
for _, g in pairs(b2.grades) do if g.name == 'sergent' then s2 = g end end
check(s2 and s2.perms.kick == snapshot.sergentPerms and s2.perms.recruit, 'permissions des grades rechargées')
check(b2.ped and b2.ped.model == snapshot.ped and b2.ped.menu.orders and not b2.ped.menu.finances, 'PED et son menu rechargés')
check(b2.settings.f5Tabs.finances == true, 'configuration F5 rechargée')
local w2 = Cache.requests[wreq.id]
check(w2 and w2.status == 'ready' and w2.spot and w2.spot.x == wreq.spot.x and w2.itemCount == 20, 'livraison prête rechargée (lieu, objets)')
local v2 = Cache.requests[vreq.id]
check(v2 and v2.status == 'preparing' and v2.readyAt == vreq.readyAt, 'livraison en préparation rechargée (heure de fin conservée)')
local g, m, grade = Cache.membership('CID_A')
check(g and g.name == 'bloods' and grade.boss, 'à la reconnexion, John retrouve groupe, grade et permissions')
bloods = b2

-- =========================================================
section('Suppression d\'un groupe')
-- =========================================================
open(1, 'f5')
check(admin('deleteGroup', { id = bloods.id, confirm = 'Bloods' }) == false and Cache.byName('bloods'), 'confirmation incorrecte : rien n\'est supprimé')
check(admin('deleteGroup', { id = bloods.id, confirm = 'bloods' }) == true, 'suppression confirmée')
check(Cache.byName('bloods') == nil and Cache.memberOf.CID_A == nil and Cache.memberOf.CID_B == nil, 'groupe et membres supprimés')
check(DB._tables.peds[bloods.id] == nil and DB._tables.finances[bloods.id] == nil, 'PED et finances supprimés en base')
check(Sessions[1] == nil and M.lastClientEvent(1, 'illegal:client:close'), 'tablette ouverte fermée')
check(M.lastClientEvent(1, 'illegal:client:membership').args[1].inGroup == false, 'F5 de John mis à jour')
check(M.res:AdminData(99).stats.groups == 2, 'dashboard à jour')

M.print(('\n%d réussis, %d échoués'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
