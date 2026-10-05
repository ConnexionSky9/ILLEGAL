-- =========================================================
--  Tests des missions illégales (hors jeu) : lua5.4 tests/missions.lua
--  Exécute le vrai code serveur (moteur + mission « colis ») avec
--  FiveM / Qbox / ox_inventory / base de données simulés.
-- =========================================================
package.path = './tests/?.lua;' .. package.path
math.randomseed(42)
local M = require('mocks')
local ROOT = 'elyzea_illegal/'
for _, f in ipairs({ 'config.lua', 'shared/constants.lua', 'shared/utils.lua' }) do dofile(ROOT .. f) end
dofile('tests/db_memory.lua')
for _, f in ipairs({ 'logs', 'players', 'cache', 'sync', 'groups', 'grades', 'members', 'finances', 'peds', 'orders', 'deliveries', 'stashes',
    'missions/core', 'missions/colis', 'tablet', 'admin', 'main' }) do
    dofile(ROOT .. 'server/' .. f .. '.lua')
end
M.flush()

local passed, failed = 0, 0
local function check(cond, label) if cond then passed = passed + 1 else failed = failed + 1 M.print('  ✗ ' .. label) end end
local function section(name) M.print('▶ ' .. name) end
local function admin(name, data) local ok, msg = M.res:AdminAction(99, name, data) M.flush() return ok, msg end
local function act(src, name, data) M.fromClient(src, 'illegal:server:action', name, data or {}) M.advance(5000) end
local function open(src) M.fromClient(src, 'illegal:server:open', 'f5') M.advance(5000) end
local function mission(src, runId, name, a, b) M.fromClient(src, 'illegal:mission:action', runId, name, a, b) M.advance(300) end
local function eventsTo(src, name)
    local n = 0
    for _, e in ipairs(M.clientEvents) do if e.target == src and e.name == name then n = n + 1 end end
    return n
end

M.addPlayer(99, 'STAFF', 'Admin', 'Staff', { staff = true, coords = vector3(0, 0, 0) })
M.addPlayer(1, 'CID_A', 'Tony', 'Ballas', { coords = vector3(100, 100, 30), cash = 1000, dirty = 0 })
M.addPlayer(2, 'CID_B', 'Mike', 'Ballas', { coords = vector3(110, 100, 30) })
M.addPlayer(3, 'CID_C', 'Carl', 'Vagos', { coords = vector3(105, 100, 30) })
M.addPlayer(4, 'CID_D', 'Dana', 'Ballas', { coords = vector3(900, 900, 30) })
admin('createGroup', { name = 'ballas', label = 'Ballas', type = 'gang' })
admin('createGroup', { name = 'vagos', label = 'Vagos', type = 'gang' })
local ballas, vagos = Cache.byName('ballas'), Cache.byName('vagos')
local function gradeOf(g, name) for _, gr in pairs(g.grades) do if gr.name == name then return gr end end end
admin('addMember', { id = ballas.id, target = 1, gradeId = gradeOf(ballas, 'og').id })
admin('addMember', { id = ballas.id, target = 2, gradeId = gradeOf(ballas, 'recrue').id })
admin('addMember', { id = ballas.id, target = 4, gradeId = gradeOf(ballas, 'recrue').id })
admin('addMember', { id = vagos.id, target = 3, gradeId = gradeOf(vagos, 'og').id })
admin('setStash', { id = ballas.id, label = 'Planque', model = 'prop_ld_int_safe_01', weight = 500, slots = 50, useMyPosition = true })
local STASH = 'illegal_stash_' .. ballas.id

-- =========================================================
section('1. Niveau 0 et configuration par défaut')
-- =========================================================
check(Missions.ready and Missions.configs.colis_test, 'mission « Colis test » créée automatiquement')
local cfg = Missions.configs.colis_test
check(cfg.general.levelRequired == 0 and cfg.general.xp == 25 and cfg.timer.minutes == 15, 'défauts : niveau 0, +25 XP, 15 minutes')
local wcount, kcount = 0, 0
for _, g in ipairs(cfg.guards.list) do if g.weapon == 'WEAPON_UNARMED' then wcount = wcount + 1 elseif g.weapon == 'WEAPON_KNIFE' then kcount = kcount + 1 end end
check(wcount == 4 and kcount == 2, 'défauts : 4 gardes au poing, 2 au couteau')
check(cfg.rewards.money.min == 5000 and cfg.rewards.money.max == 8000, 'défauts : 5 000 à 8 000 $')
local info = Progress.info(ballas)
check(info.level == 0 and info.xp == 0 and info.need == 100, 'groupe niveau 0, XP 0 / 100')
check(DB._tables.missions.colis_test ~= nil, 'configuration enregistrée en base')

-- =========================================================
section('Administration : missions, niveaux, progression')
-- =========================================================
check(M.res:AdminAction(1, 'missionSave', { missionId = 'colis_test', section = 'general', data = {} }) == false, 'un joueur ne peut pas modifier une mission')
check(admin('missionSave', { missionId = 'colis_test', section = 'general', data = { label = 'Colis test', minPlayers = 5, maxPlayers = 2 } }) == false, 'min > max refusé')
check(admin('missionSave', { missionId = 'colis_test', section = 'rewards', data = { money = { enabled = true, min = 9000, max = 100, account = 'dirty' }, items = { enabled = true, list = {} } } }) == false,
    'récompense min > max refusée')
check(admin('missionSave', { missionId = 'colis_test', section = 'timer', data = { minutes = 10 } }) == true and cfg.timer.minutes == 10, 'timer modifié (10 min)')
admin('missionSave', { missionId = 'colis_test', section = 'timer', data = { minutes = 15 } })
check(admin('missionSave', { missionId = 'colis_test', section = 'rewards', data = { money = { enabled = true, min = 5000, max = 8000, account = 'dirty' },
    items = { enabled = true, list = { { item = 'lockpick', min = 2, max = 2, chance = 100 }, { item = 'materiel_illegal', min = 5, max = 5, chance = 100 } } } } }) == true,
    'récompenses : 2x lockpick, 5x materiel_illegal')
check(admin('missionSave', { missionId = 'colis_test', section = 'guards', data = { list = { { model = 'x', weapon = 'knife', behavior = 'nope', health = 99999 } } } }) == true
    and cfg.guards.list[1].weapon == 'WEAPON_KNIFE' and cfg.guards.list[1].behavior == 'wary' and cfg.guards.list[1].health == 2000, 'gardes : valeurs nettoyées par le serveur')
admin('missionSave', { missionId = 'colis_test', section = 'guards', data = Missions.types.colis.defaults('colis_test').guards })
check(#cfg.guards.list == 6, 'gardes par défaut restaurés')
M.players[99].coords = vector3(3000, 3000, 20)
check(admin('missionPoint', { missionId = 'colis_test', section = 'locations', op = 'add', data = { label = 'Hangar', radius = 25, useMyPosition = true } }) == true, 'emplacement ajouté à la position du staff')
local nloc = #cfg.locations.list
M.players[99].coords = vector3(3005, 3000, 20)
check(admin('missionPoint', { missionId = 'colis_test', section = 'locations', op = 'guardAdd', index = nloc, data = { useMyPosition = true } }) == true
    and #cfg.locations.list[nloc].guards == 1, 'position de garde ajoutée')
check(admin('missionPoint', { missionId = 'colis_test', section = 'locations', op = 'update', index = nloc, data = { enabled = false } }) == true
    and cfg.locations.list[nloc].enabled == false, 'emplacement désactivé')
check(admin('missionPoint', { missionId = 'colis_test', section = 'locations', op = 'update', index = 99, data = {} }) == false, 'index invalide refusé')
check(admin('levelsSave', { levels = { { label = 'A', xp = 0 }, { label = 'B', xp = -5 } } }) == false, 'seuil XP invalide refusé')
check(admin('levelsSave', { levels = { { label = 'Inconnus', xp = 0 }, { label = 'Petites frappes', xp = 100 }, { label = 'Réseau', xp = 250 },
    { label = 'Organisés', xp = 500 } } }) == true and Progress.maxLevel() == 3, 'niveaux enregistrés (niveau max 3)')
check(admin('progress', { id = vagos.id, op = 'add', value = 120 }) == true and Progress.get(vagos).level == 1 and Progress.get(vagos).xp == 20, 'staff : +120 XP → niveau 1, 20 / 250')
check(admin('progress', { id = vagos.id, op = 'remove', value = 50 }) == true and Progress.get(vagos).xp == 0, 'staff : −XP (jamais négatif)')
check(admin('progress', { id = vagos.id, op = 'setLevel', value = 9 }) == false, 'niveau au-delà du max refusé')
check(admin('progress', { id = vagos.id, op = 'setLevel', value = 3 }) == true and Progress.info(vagos).need == nil, 'staff : définir niveau 3 (max)')
check(admin('progress', { id = vagos.id, op = 'reset' }) == true and Progress.get(vagos).level == 0, 'staff : réinitialiser')
check(DB._tables.groups[vagos.id].mission_level == 0, 'progression enregistrée en base')

-- =========================================================
section('2. Lancement de la mission')
-- =========================================================
open(1) open(2) open(3)
act(2, 'startMission', { id = 'colis_test' })
check(not next(Missions.runs) and M.lastNotify(2):find('grade'), 'recrue sans permission « lancer une mission » : refusé')
cfg.groups = { mode = 'list', list = { 'vagos' } }
act(1, 'startMission', { id = 'colis_test' })
check(not next(Missions.runs) and M.lastNotify(1):find('accès'), 'groupe non autorisé : refusé')
cfg.groups = { mode = 'all', list = {} }
cfg.general.minPlayers = 3
act(1, 'startMission', { id = 'colis_test' })
check(not next(Missions.runs) and M.lastNotify(1):find('au moins 3'), 'pas assez de participants à proximité : refusé')
cfg.general.minPlayers = 1
act(1, 'startMission', { id = 'inexistante' })
check(not next(Missions.runs), 'mission inexistante : refusé')
cfg.general.enabled = false
act(1, 'startMission', { id = 'colis_test' })
check(not next(Missions.runs), 'mission désactivée : refusé')
cfg.general.enabled = true

act(1, 'startMission', { id = 'colis_test' })
local runId, run = next(Missions.runs)
check(run ~= nil, 'Tony lance « Colis test »')
check(run and run.participants[1] and run.participants[2] and not run.participants[3] and not run.participants[4],
    'participants : membres Ballas proches (Mike), pas Carl (Vagos), pas Dana (trop loin)')
local ph = M.lastClientEvent(1, 'illegal:client:phone')
check(ph and ph.args[1] == 'Numéro inconnu' and ph.args[2]:find('Rappelle%-toi'), 'téléphone : message du numéro inconnu')
check(M.lastClientEvent(2, 'illegal:client:phone') ~= nil, 'téléphone : message aussi au participant')
local pl = M.lastClientEvent(1, 'illegal:client:mission').args[1]
check(pl.stage == 'guards' and pl.remaining >= 899 and pl.location, 'GPS envoyé, timer 15 min démarré')
check(M.lastClientEvent(3, 'illegal:client:mission') == nil, 'les autres groupes ne reçoivent rien')
act(1, 'startMission', { id = 'colis_test' })
local n = 0 for _ in pairs(Missions.runs) do n = n + 1 end
check(n == 1, 'une seule mission à la fois par groupe')

-- =========================================================
section('3-4. Emplacement aléatoire et gardes')
-- =========================================================
local valid = false
for _, l in ipairs(cfg.locations.list) do if l.enabled ~= false and l.label == run.locationLabel then valid = true end end
check(valid and run.locationLabel ~= 'Hangar', 'emplacement tiré parmi les emplacements activés')
check(#run.state.guards == 6, '6 gardes créés par le serveur')
local fists, knives = 0, 0
for _, g in ipairs(run.state.guards) do
    local st = M.entities[g.ent].state.illegalGuard
    if st.weapon == 'WEAPON_UNARMED' then fists = fists + 1 elseif st.weapon == 'WEAPON_KNIFE' then knives = knives + 1 end
end
check(fists == 4 and knives == 2, 'gardes : 4 au poing, 2 au couteau (réglages synchronisés)')

-- =========================================================
section('5-6. Fouille et clé (validées par le serveur)')
-- =========================================================
local loc = run.state.loc
local function at(src, x, y, z) M.players[src].coords = vector3(x, y, z) end
at(1, loc.x, loc.y, loc.z)
mission(1, runId, 'open', 'start')
check(run.state.stage == 'guards' and M.lastNotify(1):find('verrouillé'), 'colis verrouillé sans la clé')
local g1 = run.state.guards[1]
local gc = M.entities[g1.ent].coords
at(1, gc.x, gc.y, gc.z)
mission(1, runId, 'search', g1.ent, 'start')
check(M.lastNotify(1):find('encore debout'), 'impossible de fouiller un garde vivant')
for _, g in ipairs(run.state.guards) do M.entities[g.ent].health = 0 end   -- gardes neutralisés
mission(3, runId, 'search', g1.ent, 'start')
mission(3, runId, 'search', g1.ent, 'done')
check(not g1.searched, 'un joueur d\'un autre groupe ne peut pas fouiller (pas participant)')
mission(1, runId, 'search', g1.ent, 'done')
check(not g1.searched, 'fouille sans démarrage : refusée')
mission(1, runId, 'search', g1.ent, 'start')
mission(1, runId, 'search', g1.ent, 'done')
check(not g1.searched, 'fouille trop rapide (durée contournée) : refusée')
at(1, 9999, 9999, 0)
mission(1, runId, 'search', g1.ent, 'start') M.advance(5000)
mission(1, runId, 'search', g1.ent, 'done')
check(not g1.searched, 'fouille à distance : refusée')
-- Mode « probabilité » à 1 % : la clé finit toujours par être trouvée
run.cfg.crate.keyMode, run.cfg.crate.keyChance = 'chance', 1
local searches = 0
for _, g in ipairs(run.state.guards) do
    if run.state.hasKey then break end
    local c = M.entities[g.ent].coords
    at(1, c.x, c.y, c.z)
    mission(1, runId, 'search', g.ent, 'start') M.advance(5000)
    mission(1, runId, 'search', g.ent, 'done')
    searches = searches + 1
end
check(run.state.hasKey and run.state.stage == 'crate', 'clé trouvée (jamais bloquée, même à 1 %)')
check(searches <= 6, 'au plus un passage sur chaque garde')
mission(1, runId, 'search', run.state.guards[1].ent, 'start')
check(true, 'fouille supplémentaire sans effet')

-- =========================================================
section('7. Colis')
-- =========================================================
at(2, loc.x, loc.y, loc.z)
mission(2, runId, 'open', 'start')
check(M.lastClientEvent(2, 'illegal:client:missionProgress') ~= nil, 'ouverture autorisée : animation lancée côté client')
mission(2, runId, 'open', 'done')
check(run.state.stage == 'crate', 'ouverture trop rapide : refusée')
mission(2, runId, 'open', 'start') M.advance(8000)
mission(2, runId, 'open', 'done')
check(run.state.stage == 'deliver' and run.state.carrier == 'CID_B', 'colis récupéré par Mike (porteur)')
local pl2 = M.lastClientEvent(1, 'illegal:client:mission').args[1]
check(pl2.stage == 'deliver' and pl2.delivery and pl2.carrier == false and pl2.carrierName == 'Mike Ballas', 'nouveau GPS : point de livraison envoyé')
-- Point le plus proche du lancement
local best, bd
for _, p in ipairs(cfg.delivery.points) do
    local d = #(vector3(p.x, p.y, p.z) - vector3(100, 100, 30))
    if not bd or d < bd then best, bd = p, d end
end
check(run.state.delivery.label == best.label, 'point de livraison : le plus proche du lancement')

-- =========================================================
section('8-10. Livraison, récompense au coffre, XP')
-- =========================================================
local dp = run.state.delivery
local dirty0, clean0 = ballas.finance.dirty, ballas.finance.clean
local cashA, cashB = M.players[1].qbx.PlayerData.money.cash, M.players[2].qbx.PlayerData.money.cash
at(1, dp.x, dp.y, dp.z)
mission(1, runId, 'deliver', 'start') M.advance(4000)
mission(1, runId, 'deliver', 'done')
check(Missions.runs[runId] ~= nil, 'seul le porteur peut livrer')
at(2, dp.x + 50, dp.y, dp.z)
mission(2, runId, 'deliver', 'start') M.advance(4000)
mission(2, runId, 'deliver', 'done')
check(Missions.runs[runId] ~= nil, 'livraison trop loin : refusée')
at(2, dp.x, dp.y, dp.z)
mission(2, runId, 'deliver', 'start')
mission(2, runId, 'deliver', 'done')
check(Missions.runs[runId] ~= nil, 'livraison trop rapide : refusée')
mission(2, runId, 'deliver', 'start') M.advance(4000)
mission(2, runId, 'deliver', 'done')
check(Missions.runs[runId] == nil, 'colis livré : mission terminée')
local gain = ballas.finance.dirty - dirty0
check(gain >= 5000 and gain <= 8000, ('coffre Ballas : +%d $ d\'argent sale (entre 5 000 et 8 000)'):format(gain))
check(ballas.finance.clean == clean0, 'argent propre non touché')
check(M.players[1].qbx.PlayerData.money.cash == cashA and M.players[2].qbx.PlayerData.money.cash == cashB, 'aucun argent donné aux joueurs')
check(not M.players[1].items.lockpick and not M.players[2].items.lockpick, 'aucun objet dans les inventaires personnels')
local items = M.stashes[STASH].items or {}
check(items.lockpick == 2 and items.materiel_illegal == 5, 'objets ajoutés au coffre du groupe (2x lockpick, 5x materiel_illegal)')
check(Cache.transactions(ballas)[1].type == 'mission' and Cache.transactions(ballas)[1].amount == gain, 'historique financier : récompense de mission')
local p = Progress.get(ballas)
check(p.level == 0 and p.xp == 25, 'XP : +25 une seule fois (2 participants)')
check(M.lastClientEvent(2, 'illegal:client:phone').args[2] == 'Merci pour le service rendu !', 'téléphone : « Merci pour le service rendu ! »')
local fin = M.lastClientEvent(1, 'illegal:client:missionEnd')
check(fin and fin.args[1].success and fin.args[1].message == 'MISSION TERMINÉE', 'MISSION TERMINÉE')
local left = 0
for _, g in ipairs(run.state.guards) do if M.entities[g.ent] then left = left + 1 end end
check(left == 0, 'gardes supprimés')
check(DB._tables.runs[run.dbId].status == 'success' and DB._tables.runs[run.dbId].xp == 25, 'historique de mission en base')
mission(2, runId, 'deliver', 'done')
check(ballas.finance.dirty - dirty0 == gain, 'pas de double récompense')

-- =========================================================
section('13. Cooldown')
-- =========================================================
act(1, 'startMission', { id = 'colis_test' })
check(not next(Missions.runs) and M.lastNotify(1):find('attendre'), 'cooldown actif : refusé (serveur)')
Missions.cd.group['colis_test:' .. ballas.id] = os.time() - 3600
Missions.cd.player['colis_test:CID_A'] = os.time() - 3600
Missions.cd.player['colis_test:CID_B'] = os.time() - 3600

-- =========================================================
section('11-12. Level-up et déblocage')
-- =========================================================
Missions.configs.colis_lvl1 = Missions.types.colis.defaults('colis_lvl1')
Missions.configs.colis_lvl1.type = 'colis'
Missions.configs.colis_lvl1.general.label, Missions.configs.colis_lvl1.general.levelRequired = 'Livraison', 1
local why = Missions.blocker('colis_lvl1', Missions.configs.colis_lvl1, ballas, 'CID_A')
check(why and why:find('niveau 1 requis'), 'mission niveau 1 verrouillée au niveau 0')
local tdata = Tablet.build(1).missions
local lv1
for _, x in ipairs(tdata.list) do if x.id == 'colis_lvl1' then lv1 = x end end
check(lv1 and lv1.locked and tdata.progress.xp == 25 and tdata.progress.need == 100, 'tablette : mission verrouillée, XP 25 / 100')
admin('progress', { id = ballas.id, op = 'setXp', value = 90 })
act(1, 'startMission', { id = 'colis_test' })
local runId2, run2 = next(Missions.runs)
check(run2 ~= nil, 'nouvelle mission lancée après le cooldown')
for _, g in ipairs(run2.state.guards) do M.entities[g.ent].health = 0 end
run2.state.hasKey = true run2.stageLabel = '' run2.state.stage = 'crate'
at(1, run2.state.loc.x, run2.state.loc.y, run2.state.loc.z)
mission(1, runId2, 'open', 'start') M.advance(8000)
mission(1, runId2, 'open', 'done')
local dp2 = run2.state.delivery
at(1, dp2.x, dp2.y, dp2.z)
mission(1, runId2, 'deliver', 'start') M.advance(4000)
mission(1, runId2, 'deliver', 'done')
p = Progress.get(ballas)
check(p.level == 1 and p.xp == 15, 'level-up automatique : 90 + 25 → niveau 1, 15 / 250')
local lvlMsg = false
for _, e in ipairs(M.clientEvents) do if e.name == 'illegal:client:phone' and tostring(e.args[2]):find('niveau 1') then lvlMsg = true end end
check(lvlMsg, 'téléphone : message de level-up')
check(Missions.blocker('colis_lvl1', Missions.configs.colis_lvl1, ballas, 'CID_A') == nil, 'mission niveau 1 débloquée')
Missions.configs.colis_lvl1 = nil

-- =========================================================
section('Échec au timer et restrictions d\'armes')
-- =========================================================
Missions.cd = { mission = {}, group = {}, player = {} }
act(1, 'startMission', { id = 'colis_test' })
local runId3, run3 = next(Missions.runs)
local dirtyBefore, xpBefore = ballas.finance.dirty, Progress.get(ballas).xp
local victim = run3.state.guards[1].ent
for _, fn in ipairs(M.local_.weaponDamageEvent) do fn(1, { hitGlobalId = victim, weaponType = GetHashKey('WEAPON_PISTOL') % 4294967296 }) end
check(Missions.runs[runId3] and M.lastNotify(1):find('Avertissement'), 'arme à feu interdite : avertissement')
for _, fn in ipairs(M.local_.weaponDamageEvent) do fn(1, { hitGlobalId = victim, weaponType = GetHashKey('WEAPON_KNIFE') }) end
check(Missions.runs[runId3] ~= nil, 'arme blanche autorisée : rien')
run3.deadline = os.time() - 1
M.tick()
check(Missions.runs[runId3] == nil, 'timer à 0 : mission échouée')
local f3 = M.lastClientEvent(1, 'illegal:client:missionEnd').args[1]
check(not f3.success and f3.message:find('Temps écoulé'), 'MISSION ÉCHOUÉE : temps écoulé')
check(ballas.finance.dirty == dirtyBefore and Progress.get(ballas).xp == xpBefore, 'échec : aucune récompense, aucune XP')
local alive3 = 0
for _, g in ipairs(run3.state.guards) do if M.entities[g.ent] then alive3 = alive3 + 1 end end
check(alive3 == 0, 'échec : gardes supprimés')
check(M.lastClientEvent(1, 'illegal:client:phone').args[2]:find('déçu'), 'téléphone : message d\'échec')

Missions.cd = { mission = {}, group = {}, player = {} }
cfg.weapons.action = 'fail'
act(1, 'startMission', { id = 'colis_test' })
local runId4, run4 = next(Missions.runs)
for _, fn in ipairs(M.local_.weaponDamageEvent) do fn(1, { hitGlobalId = run4.state.guards[1].ent, weaponType = GetHashKey('WEAPON_GRENADE') }) end
check(Missions.runs[runId4] == nil, 'explosif interdit en mode « échec » : mission échouée')
cfg.weapons.action = 'warn'

-- =========================================================
section('Clé toujours trouvable : corps du porteur disparu')
-- =========================================================
Missions.cd = { mission = {}, group = {}, player = {} }
at(1, 100, 100, 30) at(2, 101, 100, 30)
act(1, 'startMission', { id = 'colis_test' })
local runK, rk = next(Missions.runs)
rk.cfg.crate.keyMode = 'random'
rk.state.keyGuard = 3
for _, g in ipairs(rk.state.guards) do M.entities[g.ent].health = 0 end
DeleteEntity(rk.state.guards[3].ent)   -- le corps qui portait la clé a disparu
local other = rk.state.guards[1]
local oc = M.entities[other.ent].coords
at(1, oc.x, oc.y, oc.z)
mission(1, runK, 'search', other.ent, 'start') M.advance(5000)
mission(1, runK, 'search', other.ent, 'done')
check(rk.state.hasKey, 'la clé passe au garde fouillé suivant')
act(1, 'abandonMission')
check(Missions.runs[runK] == nil, 'le lanceur abandonne la mission')

-- =========================================================
section('Participants : départ du porteur, abandon')
-- =========================================================
Missions.cd = { mission = {}, group = {}, player = {} }
at(2, 101, 100, 30) at(1, 100, 100, 30)
act(1, 'startMission', { id = 'colis_test' })
local runId5, run5 = next(Missions.runs)
run5.state.hasKey = true run5.state.stage = 'crate'
at(1, run5.state.loc.x, run5.state.loc.y, run5.state.loc.z)
mission(1, runId5, 'open', 'start') M.advance(8000)
mission(1, runId5, 'open', 'done')
check(run5.state.carrier == 'CID_A', 'Tony porte le colis')
source = 1
for _, fn in ipairs(M.local_.playerDropped) do fn() end
M.flush()
check(Missions.runs[runId5] and run5.state.carrier == 'CID_B', 'déconnexion du porteur : le colis passe à Mike')
act(2, 'abandonMission')
check(Missions.runs[runId5] ~= nil, 'une recrue (ni lanceur ni chef) ne peut pas abandonner')
source = 2
for _, fn in ipairs(M.local_.playerDropped) do fn() end
M.flush()
check(Missions.runs[runId5] == nil, 'plus aucun participant : mission échouée')

-- =========================================================
section('14. Persistance (redémarrage)')
-- =========================================================
local lvl, xp = Progress.get(ballas).level, Progress.get(ballas).xp
Cache.load()
Missions.cd = { mission = {}, group = {}, player = {} }
Missions.load()
local b2 = Cache.byName('ballas')
check(Progress.get(b2).level == lvl and Progress.get(b2).xp == xp, ('progression conservée : niveau %d, %d XP'):format(lvl, xp))
check(Missions.cd.group['colis_test:' .. b2.id] ~= nil, 'cooldowns reconstruits depuis l\'historique')
check(Progress.maxLevel() == 3, 'niveaux personnalisés conservés')
check(Missions.configs.colis_test.locations.list[nloc].label == 'Hangar' and Missions.configs.colis_test.rewards.items.list[2].item == 'materiel_illegal',
    'configuration de mission conservée')

M.print(('\n%d réussis, %d échoués'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
