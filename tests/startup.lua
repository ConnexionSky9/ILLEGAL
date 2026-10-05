-- Reproduit l'erreur « attempt to index a nil value (global 'Deliveries') » :
-- fichiers ajoutés par une mise à jour mais pas chargés (refresh oublié). (lua5.4 tests/startup.lua)
package.path = './tests/?.lua;' .. package.path
local M = require('mocks')
local ROOT = 'elyzea_illegal/'
Config = {}   -- ancien config.lua : sans Config.Orders / Delivery / Stash
dofile(ROOT .. 'config.lua')
Config.Orders, Config.Delivery, Config.Stash = nil, nil, nil
for _, f in ipairs({ 'shared/constants.lua', 'shared/utils.lua' }) do dofile(ROOT .. f) end
dofile('tests/db_memory.lua')
for _, f in ipairs({ 'logs', 'players', 'cache', 'sync', 'groups', 'grades', 'members', 'finances', 'peds', 'orders', 'tablet', 'admin', 'main' }) do
    dofile(ROOT .. 'server/' .. f .. '.lua')   -- sans deliveries.lua ni stashes.lua
end
M.flush()
local passed, failed = 0, 0
local function check(c, l) if c then passed = passed + 1 else failed = failed + 1 M.print('  ✗ ' .. l) end end
local warned = false
for _, p in ipairs(M.prints) do if p:find('Fichiers non chargés') and p:find('server/deliveries.lua') and p:find('server/stashes.lua') then warned = true end end
check(warned, 'console : fichiers manquants signalés')
local hint = false
for _, p in ipairs(M.prints) do if p:find('refresh') then hint = true end end
check(hint, 'console : indique « refresh » puis « ensure »')
check(Config.Orders and Config.Delivery and Config.Stash and Config.Delivery.prepareMinutes == 5, 'ancien config.lua complété par les valeurs par défaut')

M.addPlayer(99, 'STAFF1', 'Admin', 'Staff', { staff = true })
M.addPlayer(1, 'CID_A', 'John', 'Doe', { coords = vector3(0, 0, 0) })
M.res:AdminAction(99, 'createGroup', { name = 'bloods', label = 'Bloods', type = 'gang' }) M.flush()
local g = Cache.byName('bloods')
local og
for _, gr in pairs(g.grades) do if gr.boss then og = gr end end
M.res:AdminAction(99, 'addMember', { id = g.id, target = 1, gradeId = og.id }) M.flush()
M.res:AdminAction(99, 'money', { id = g.id, account = 'dirty', amount = 5000, add = true }) M.flush()
M.res:AdminAction(99, 'createOrder', { id = g.id, name = 'Test', category = 'other', price = 10, payment = 'dirty' }) M.flush()
local oid for id in pairs(Cache.orders) do oid = id end
M.fromClient(1, 'illegal:server:open', 'f5')
local ok, err = pcall(M.fromClient, 1, 'illegal:server:action', 'placeOrder', { id = oid, quantity = 1 })
check(ok, 'passer commande ne plante plus : ' .. tostring(err))
check(M.lastNotify(1) and M.lastNotify(1):find('Livraisons indisponibles'), 'message clair au joueur')
check(g.finance.dirty == 5000, 'rien n\'est débité')
M.print(('%d réussis, %d échoués'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
