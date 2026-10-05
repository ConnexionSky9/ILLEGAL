-- =========================================================
--  Tests de la mission niveau 1 « Le Fourgon Fantôme » (hors jeu) :
--    lua5.4 tests/fourgon.lua
--  Exécute le vrai code serveur (moteur + types colis / fourgon) avec
--  FiveM / Qbox / ox_inventory / admin_menu / base de données simulés.
-- =========================================================
package.path = './tests/?.lua;' .. package.path
math.randomseed(7)
local M = require('mocks')
local ROOT = 'elyzea_illegal/'
for _, f in ipairs({ 'config.lua', 'shared/constants.lua', 'shared/utils.lua' }) do dofile(ROOT .. f) end
dofile('tests/db_memory.lua')
for _, f in ipairs({ 'logs', 'players', 'cache', 'sync', 'groups', 'grades', 'members', 'finances', 'peds', 'orders', 'deliveries', 'stashes',
    'missions/core', 'missions/colis', 'missions/fourgon', 'tablet', 'admin', 'main' }) do
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
local function timed(src, runId, name, a, seconds)   -- action longue : début → durée → fin
    if a ~= nil then mission(src, runId, name, a, 'start') M.advance(seconds * 1000) mission(src, runId, name, a, 'done')
    else mission(src, runId, name, 'start') M.advance(seconds * 1000) mission(src, runId, name, 'done') end
end
local function eventsTo(src, name)
    local n = 0
    for _, e in ipairs(M.clientEvents) do if e.target == src and e.name == name then n = n + 1 end end
    return n
end
local function at(src, p) M.players[src].coords = vector3(p.x, p.y, p.z) end
local function infoOf(run, key) return run.infos and run.infos[key] end
local function d2(a, b) return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2) end

M.addPlayer(99, 'STAFF', 'Admin', 'Staff', { staff = true, coords = vector3(0, 0, 0) })
M.addPlayer(1, 'CID_A', 'Tony', 'Ballas', { coords = vector3(100, 100, 30) })
M.addPlayer(2, 'CID_B', 'Mike', 'Ballas', { coords = vector3(110, 100, 30) })
M.addPlayer(3, 'CID_C', 'Carl', 'Vagos', { coords = vector3(105, 100, 30) })
M.addPlayer(5, 'CID_P', 'Officer', 'Cop', { coords = vector3(-500, -500, 30), police = true })
M.addPlayer(6, 'CID_Q', 'Off', 'Duty', { coords = vector3(-500, -500, 30) })
M.players[5].police = true
admin('createGroup', { name = 'ballas', label = 'Ballas', type = 'gang' })
admin('createGroup', { name = 'vagos', label = 'Vagos', type = 'gang' })
local ballas = Cache.byName('ballas')
local vagos = Cache.byName('vagos')
local function gradeOf(g, name) for _, gr in pairs(g.grades) do if gr.name == name then return gr end end end
admin('addMember', { id = ballas.id, target = 1, gradeId = gradeOf(ballas, 'og').id })
admin('addMember', { id = ballas.id, target = 2, gradeId = gradeOf(ballas, 'og').id })
admin('addMember', { id = vagos.id, target = 3, gradeId = gradeOf(vagos, 'og').id })
admin('setStash', { id = ballas.id, label = 'Planque', model = 'prop_ld_int_safe_01', weight = 500, slots = 50, useMyPosition = true })
open(1) open(2) open(3)
local ID = 'fourgon_fantome'
local function reset() Missions.cd = { mission = {}, group = {}, player = {} } at(1, { x = 100, y = 100, z = 30 }) at(2, { x = 110, y = 100, z = 30 }) end
local function launch()
    reset()
    act(1, 'startMission', { id = ID })
    for id, r in pairs(Missions.runs) do if r.missionId == ID then return id, r end end
end
local function onlyScenario(key)
    local list = Missions.types.fourgon.defaults().scenarios.list
    for _, s in ipairs(list) do s.enabled = s.key == key end
    return admin('missionSave', { missionId = ID, section = 'scenarios', data = { list = list } })
end
-- Indices : zone atteinte puis N indices trouvés (révélation)
local function findClues(runId, run)
    at(1, run.state.area) M.tick()
    for i = 1, run.state.required do
        local c = run.state.clues[i].def
        at(1, c.pos)
        timed(1, runId, 'clue', i, c.seconds)
    end
end

-- =========================================================
section('1. Configuration par défaut')
-- =========================================================
local cfg = Missions.configs[ID]
check(cfg and cfg.type == 'fourgon', 'mission « Le Fourgon Fantôme » créée automatiquement')
check(cfg.general.levelRequired == 1 and cfg.timer.minutes == 30, 'défauts : niveau 1, 30 minutes')
check(cfg.phone.start:find('Je veux la marchandise, pas le chauffeur') and cfg.phone.sender == 'Numéro inconnu', 'message du numéro inconnu configuré')
check(cfg.phone.finish == 'Merci pour le service rendu !', 'message final configuré')
check(#cfg.scenarios.list == 5 and cfg.hud and cfg.hud.share == true, '5 scénarios (A à E), HUD configurable')
check(DB._tables.missions[ID] ~= nil, 'configuration enregistrée en base')
local ad = Missions.adminData(99)
local ft = ad.types and ad.types.fourgon
check(ft and ft.schema and ft.schema.locations and #ft.sections >= 20, 'menu staff : schéma et sections du fourgon envoyés')

-- =========================================================
section('2. Administration (serveur)')
-- =========================================================
check(M.res:AdminAction(1, 'missionSave', { missionId = ID, section = 'search', data = {} }) == false, 'un joueur ne peut pas modifier la mission')
local dup = Missions.types.fourgon.defaults().scenarios.list
dup[2].key = dup[1].key
check(admin('missionSave', { missionId = ID, section = 'scenarios', data = { list = dup } }) == false, 'clé de scénario en double refusée')
check(admin('missionSave', { missionId = ID, section = 'reinforcements', data = { minDistance = 300, maxDistance = 100, waves = cfg.reinforcements.waves } }) == false,
    'renforts : distance minimum > maximum refusée')
check(admin('missionSave', { missionId = ID, section = 'search', data = { radius = 999999, required = 3, reveal = 'nope' } }) == true
    and cfg.search.radius == 2000 and cfg.search.reveal == 'approx', 'valeurs bornées / nettoyées par le serveur')
admin('missionSave', { missionId = ID, section = 'search', data = Missions.types.fourgon.defaults().search })
M.players[99].coords = vector3(1234.5, -987.25, 31.0)
check(admin('missionMyPos', {}) == true and Missions.adminPos[99] and Missions.adminPos[99].x == 1234.5, '« Définir à ma position » : position du staff relevée par le serveur')
check(M.res:AdminAction(1, 'missionMyPos', {}) == false, '« Définir à ma position » refusé à un joueur')
check(onlyScenario('abandoned') == true, 'scénarios : seul « abandonné » activé')
admin('missionSave', { missionId = ID, section = 'locations', data = { select = 'fixed', fixedIndex = 1, list = cfg.locations.list } })
check(cfg.locations.select == 'fixed', 'emplacement fixe (n°1)')

-- =========================================================
section('3. Lancement : niveau, groupe, participants, téléphone')
-- =========================================================
act(1, 'startMission', { id = ID })
check(not next(Missions.runs) and M.lastNotify(1):find('niveau 1'), 'groupe niveau 0 : mission verrouillée')
admin('progress', { id = ballas.id, op = 'setLevel', value = 1 })
local runId, run = launch()
check(run ~= nil and run.participants[1] and run.participants[2] and not run.participants[3], 'mission lancée, Mike rejoint, pas Carl (autre groupe)')
local ph = M.lastClientEvent(2, 'illegal:client:phone')
check(ph and ph.args[1] == 'Numéro inconnu' and ph.args[2]:find('Le fourgon qui devait livrer'), 'téléphone : message du numéro inconnu aux participants')
local pl = M.lastClientEvent(1, 'illegal:client:mission').args[1]
check(pl.stage == 'SEARCH_AREA' and pl.area and pl.area.radius == 180 and pl.remaining >= 1799, 'zone de recherche approximative, timer 30 min')
check(pl.hud and pl.hud.enabled and pl.alert == 0, 'réglages du HUD envoyés, alerte 0')
local hasObj, hasClues = false, false
for _, e in ipairs(pl.info) do if e.key == 'objective' then hasObj = true end if e.key == 'clues' and e.value == '0 / 3' then hasClues = true end end
check(hasObj and hasClues, 'HUD : objectif et compteur d\'indices 0 / 3')
check(run.state.scenario.key == 'abandoned' and run.state.loc.label == cfg.locations.list[1].label, 'scénario et emplacement tirés par le serveur')
check(not pl.van and not pl.target, 'aucune position du fourgon envoyée avant les indices')

-- =========================================================
section('4. Zone et indices (vérifiés par le serveur)')
-- =========================================================
at(1, run.state.area) M.tick()
check(run.state.stage == 'FIND_CLUES', 'zone atteinte : étape « trouver des indices »')
local c1 = run.state.clues[1].def
at(3, c1.pos)
timed(3, runId, 'clue', 1, c1.seconds)
check(not run.state.clues[1].found, 'joueur d\'un autre groupe : indice refusé')
at(1, c1.pos)
mission(1, runId, 'clue', 1, 'start') mission(1, runId, 'clue', 1, 'done')
check(not run.state.clues[1].found, 'indice trop rapide : refusé')
at(1, { x = c1.pos.x + 40, y = c1.pos.y, z = c1.pos.z })
timed(1, runId, 'clue', 1, c1.seconds)
check(not run.state.clues[1].found, 'indice à distance : refusé')
for i = 1, 3 do local c = run.state.clues[i].def at(1, c.pos) timed(1, runId, 'clue', i, c.seconds) end
check(run.state.found == 3, '3 indices trouvés')
local plate = infoOf(run, 'clue1')
check(plate and plate.value == run.state.plate and plate.cat == 'plate', 'HUD : plaque du fourgon conservée (partagée)')
check(infoOf(run, 'code') and infoOf(run, 'code').value == run.state.code, 'HUD : code de la caisse conservé')
check(run.state.stage == 'LOCATE_VAN' and run.state.revealed and run.state.van, 'assez d\'indices : fourgon révélé et créé par le serveur')
check(infoOf(run, 'clues') == nil and infoOf(run, 'van') ~= nil, 'compteur d\'indices retiré, fourgon et plaque affichés')
check(M.entities[run.state.van].plate == run.state.plate:gsub('-', ''), 'plaque du véhicule = plaque des indices')
pl = M.lastClientEvent(2, 'illegal:client:mission').args[1]
check(pl.target and pl.target.radius == 60 and pl.van == run.state.van, 'Mike reçoit la zone révélée (approximative)')
local codeShown = false
for _, e in ipairs(pl.info) do if e.key == 'code' then codeShown = true end end
check(codeShown, 'informations partagées avec les autres participants')

-- =========================================================
section('5. Fourgon : arrivée, cabine, arrière forcé, alerte police')
-- =========================================================
local vanPos = M.entities[run.state.van].coords
mission(1, runId, 'rear', 'start')
check(run.state.stage == 'LOCATE_VAN', 'arrière : impossible avant d\'avoir atteint le fourgon')
at(1, vanPos) M.tick()
check(run.state.stage == 'INVESTIGATE_VAN', 'fourgon atteint : étape « examiner le fourgon »')
timed(1, runId, 'cabin', nil, cfg.van.cabinSeconds)
check(run.state.cabinDone, 'cabine fouillée')
local cops0, civ0 = eventsTo(5, 'illegal:client:policeAlert'), eventsTo(6, 'illegal:client:policeAlert')
mission(1, runId, 'rear', 'start')
check(M.lastClientEvent(1, 'illegal:client:missionProgress').args[2] == 'rear', 'ouverture forcée : progression lancée par le serveur')
mission(1, runId, 'rear', 'done')
check(run.state.stage == 'INVESTIGATE_VAN', 'forçage trop rapide : refusé')
timed(1, runId, 'rear', nil, cfg.van.forceSeconds)
check(run.state.stage == 'RECOVER_CARGO' and #run.state.crates == 4, 'arrière forcé : 4 caisses')
check(run.alert == 1 and infoOf(run, 'alert'), 'ouverture forcée : alerte niveau 1 (HUD)')
check(eventsTo(5, 'illegal:client:policeAlert') == cops0 + 1, 'police en service prévenue')
check(eventsTo(6, 'illegal:client:policeAlert') == civ0 and eventsTo(1, 'illegal:client:policeAlert') == 0, 'personne d\'autre n\'est prévenu')
local pa = M.lastClientEvent(5, 'illegal:client:policeAlert').args[1]
check(d2(pa, vanPos) <= 600 and pa.radius == 600 and pa.sprite == 161, 'position approximative (rayon 600 m), blip configuré')
check(#run.state.pending == 1, 'renforts du niveau 1 programmés')

-- =========================================================
section('6. Caisses : code serveur, fausses caisses, vraie marchandise')
-- =========================================================
local real = run.state.crates[run.state.realIndex]
check(real.secure and not real.unlocked, 'la vraie caisse est sécurisée')
local nsec = 0 for _, c in ipairs(run.state.crates) do if c.secure then nsec = nsec + 1 end end
check(nsec == 1, '1 caisse sécurisée')
at(1, real.pos)
mission(1, runId, 'code', run.state.realIndex, '0000' == run.state.code and '1111' or '0000')
check(not real.unlocked and real.attempts == 1, 'mauvais code refusé (1 / 3)')
at(3, real.pos)
mission(3, runId, 'code', run.state.realIndex, run.state.code)
check(not real.unlocked, 'code envoyé par un non-participant : ignoré')
mission(1, runId, 'code', run.state.realIndex, run.state.code)
check(real.unlocked and infoOf(run, 'code').used, 'bon code : caisse déverrouillée, code marqué « utilisé »')
run.cfg.crates.outEmpty, run.cfg.crates.outFake, run.cfg.crates.outAlarm, run.cfg.crates.outAmbush = 0, 0, 0, 100
local wrong
for i, c in ipairs(run.state.crates) do if not c.real then wrong = i break end end
local enemies0 = #run.state.enemies
at(1, run.state.crates[wrong].pos)
timed(1, runId, 'crate', wrong, cfg.crates.openSeconds)
check(run.state.crates[wrong].outcome == 'ambush' and #run.state.enemies > enemies0, 'mauvaise caisse : embuscade (ennemis créés)')
for i = enemies0 + 1, #run.state.enemies do
    local e = M.entities[run.state.enemies[i]]
    local far = true
    for s in pairs(run.participants) do if d2(e.coords, M.players[s].coords) < cfg.reinforcements.minDistance - 3.5 then far = false end end
    check(far, 'renfort apparu loin des joueurs')
end
mission(1, runId, 'recover', 'start')
check(not run.state.carrier, 'récupération impossible avant d\'ouvrir la vraie caisse')
at(1, real.pos)
timed(1, runId, 'crate', run.state.realIndex, cfg.crates.openSeconds)
check(real.opened and infoOf(run, 'crate'), 'vraie caisse ouverte (HUD)')
timed(1, runId, 'recover', nil, cfg.crates.recoverSeconds)
check(run.state.stage == 'TRANSPORT' and run.state.carrier == 'CID_A', 'marchandise récupérée par Tony')
check(run.state.relay and run.state.delivery and infoOf(run, 'destination'), 'relais et livraison choisis par le serveur')

-- =========================================================
section('7. Renforts, mort du porteur, marchandise lâchée')
-- =========================================================
local before = #run.state.enemies
for _, p in ipairs(run.state.pending) do p.at = 0 end
M.tick()
check(#run.state.enemies > before and #run.state.pending == 0, 'renforts programmés : vague créée')
M.players[1].health = 0 M.tick()
check(run.state.carrier == nil and run.state.cargoDropped and run.state.flags.loss and run.state.flags.died, 'porteur à terre : marchandise au sol')
M.players[1].health = 200
at(2, run.state.cargoDropped)
timed(2, runId, 'pickup', nil, 2)
check(run.state.carrier == 'CID_B', 'Mike ramasse la marchandise')

-- =========================================================
section('8. Point relais, véhicule de transfert, poursuite')
-- =========================================================
local relay = run.state.relay
at(1, relay.pos)
timed(1, runId, 'relay', nil, relay.seconds)
check(run.state.stage == 'TRANSPORT', 'seul le porteur peut valider le relais')
at(2, relay.pos)
local copsR = eventsTo(5, 'illegal:client:policeAlert')
timed(2, runId, 'relay', nil, relay.seconds)
check(run.state.stage == 'FINAL_DELIVERY' and run.state.transfer and M.entities[run.state.transfer], 'relais validé : véhicule de transfert créé')
check(run.alert == 2 and eventsTo(5, 'illegal:client:policeAlert') == copsR + 1, 'poursuite : alerte 2, police prévenue')

-- =========================================================
section('9. Livraison finale, récompenses au coffre, bonus, nettoyage')
-- =========================================================
local dp = run.state.delivery
local dirty0, xp0 = ballas.finance.dirty, Progress.get(ballas).xp
local lvl0 = Progress.get(ballas).level
local cash1 = M.players[1].qbx.PlayerData.money.cash
at(2, { x = dp.pos.x + 30, y = dp.pos.y, z = dp.pos.z })
timed(2, runId, 'deliver', nil, cfg.delivery.seconds)
check(Missions.runs[runId], 'livraison trop loin : refusée')
at(2, dp.pos)
mission(2, runId, 'deliver', 'start') mission(2, runId, 'deliver', 'done')
check(Missions.runs[runId], 'livraison trop rapide : refusée')
local ents = {}
for _, e in ipairs(run.state.enemies) do ents[#ents + 1] = e end
for _, v in ipairs(run.state.vehicles) do ents[#ents + 1] = v end
timed(2, runId, 'deliver', nil, cfg.delivery.seconds)
check(Missions.runs[runId] == nil, 'marchandise livrée : mission réussie')
local gain = ballas.finance.dirty - dirty0
check(gain >= 15000 + 2000 and gain <= 22000 + 2000, ('coffre : +%d $ (récompense + bonus temps)'):format(gain))
check(M.players[1].qbx.PlayerData.money.cash == cash1, 'rien dans les poches des joueurs')
check(M.lastClientEvent(1, 'illegal:client:phone').args[2] == 'Merci pour le service rendu !', 'téléphone : « Merci pour le service rendu ! »')
local p = Progress.get(ballas)
local xpGain = (p.level > lvl0 and (p.xp + 250 - xp0)) or (p.xp - xp0)
check(xpGain >= 85 and xpGain <= 110, ('XP : +%d (75 à 100 + bonus 10)'):format(xpGain))
local left = 0 for _, e in ipairs(ents) do if M.entities[e] then left = left + 1 end end
check(left == 0 and #ents > 0, ('nettoyage : %d entités supprimées'):format(#ents))
check(DB._tables.runs[run.dbId].status == 'success', 'historique en base')

-- =========================================================
section('10. Mission parfaite : tous les bonus')
-- =========================================================
admin('missionSave', { missionId = ID, section = 'alarms', data = { wrongCrate = 0, wrongCode = 0, forced = 0, detection = 0, recover = 0, fakeVan = 0, levels = cfg.alarms.levels } })
local T = Missions.types.fourgon.defaults().transport
T.relayEnabled, T.pursuitAfterRelay = false, 0
admin('missionSave', { missionId = ID, section = 'transport', data = T })
local V = Missions.types.fourgon.defaults().van
V.locked = false
admin('missionSave', { missionId = ID, section = 'van', data = V })
local runB
runId, runB = launch()
findClues(runId, runB)
at(1, M.entities[runB.state.van].coords) M.tick()
timed(1, runId, 'rear', nil, cfg.van.openSeconds)
local rc = runB.state.crates[runB.state.realIndex]
at(1, rc.pos)
mission(1, runId, 'code', runB.state.realIndex, runB.state.code)
timed(1, runId, 'crate', runB.state.realIndex, cfg.crates.openSeconds)
timed(1, runId, 'recover', nil, cfg.crates.recoverSeconds)
check(runB.state.stage == 'TRANSPORT' and runB.alert == 0, 'sans relais ni alarme : transport direct')
dirty0 = ballas.finance.dirty
at(1, runB.state.delivery.pos)
timed(1, runId, 'deliver', nil, cfg.delivery.seconds)
gain = ballas.finance.dirty - dirty0
check(Missions.runs[runId] == nil and gain >= 15000 + 10500 and gain <= 22000 + 10500, ('tous les bonus : +%d $'):format(gain))
local bmsg = false
for _, n in ipairs(M.notifications) do if n.target == 1 and tostring(n.msg):find('aucune alarme') and n.msg:find('aucune alerte police') then bmsg = true end end
check(bmsg, 'bonus annoncés aux participants')

-- =========================================================
section('11. Scénario « faux fourgon »')
-- =========================================================
onlyScenario('fake')
local runC
runId, runC = launch()
findClues(runId, runC)
check(runC.state.fake and not runC.state.van, 'faux fourgon trouvé d\'abord (pas de vrai fourgon)')
at(1, M.entities[runC.state.fake].coords)
timed(1, runId, 'inspectFake', nil, cfg.search.fakeSeconds)
check(runC.state.fakeChecked and runC.state.van and infoOf(runC, 'fake'), 'faux fourgon inspecté : vrai fourgon révélé')
local vanC = runC.state.van
act(1, 'abandonMission')
check(Missions.runs[runId] == nil and not M.entities[vanC] and not M.entities[runC.state.fake], 'abandon : véhicules supprimés')

-- =========================================================
section('12. Scénario « fourgon déplacé » et surveillé : détection')
-- =========================================================
admin('missionSave', { missionId = ID, section = 'alarms', data = { wrongCrate = 1, wrongCode = 1, forced = 1, detection = 2, recover = 1, fakeVan = 0, levels = cfg.alarms.levels } })
onlyScenario('moved')
local runD
runId, runD = launch()
findClues(runId, runD)
check(runD.state.traceAt and not runD.state.van, 'fourgon introuvable à sa place : traces à examiner')
at(1, runD.state.traceAt)
timed(1, runId, 'trace', nil, cfg.search.traceSeconds)
local vd = runD.state.van and M.entities[runD.state.van].coords
check(vd and vd.x == cfg.locations.list[1].movedVan.x, 'traces suivies : fourgon à sa nouvelle position')
check(#runD.state.enemies == #cfg.enemies.list, 'fourgon surveillé : ennemis configurés créés')
for _, fn in ipairs(M.local_.weaponDamageEvent) do fn(1, { hitGlobalId = runD.state.enemies[1], weaponType = GetHashKey('WEAPON_PISTOL') }) end
check(runD.state.detected and runD.alert == 2, 'ennemi attaqué : détection → alerte 2')
check(M.entities[runD.state.enemies[2]].state.illegalAlerted == true, 'les autres ennemis passent en alerte')

-- =========================================================
section('13. Code : blocage après N essais, timer écoulé')
-- =========================================================
at(1, vd) M.tick()
timed(1, runId, 'rear', nil, cfg.van.forceSeconds)
local rd = runD.state.crates[runD.state.realIndex]
at(1, rd.pos)
for _ = 1, 3 do mission(1, runId, 'code', runD.state.realIndex, 'XXXX') M.advance(2000) end
check(rd.jammed and not rd.unlocked, '3 mauvais codes : clavier bloqué')
mission(1, runId, 'code', runD.state.realIndex, runD.state.code)
check(not rd.unlocked, 'bon code refusé une fois bloqué')
timed(1, runId, 'crate', runD.state.realIndex, cfg.crates.forceSeconds)
check(rd.opened, 'caisse forcée')
local dirtyD, entsD = ballas.finance.dirty, {}
for _, e in ipairs(runD.state.enemies) do entsD[#entsD + 1] = e end
runD.deadline = os.time() - 1
M.tick()
check(Missions.runs[runId] == nil, 'timer à 0 : mission échouée')
check(M.lastClientEvent(1, 'illegal:client:missionEnd').args[1].message:find('Temps écoulé'), 'MISSION ÉCHOUÉE : temps écoulé')
local leftD = 0 for _, e in ipairs(entsD) do if M.entities[e] then leftD = leftD + 1 end end
check(leftD == 0 and ballas.finance.dirty == dirtyD, 'échec : ennemis supprimés, aucune récompense')

-- =========================================================
section('14. Mot de passe du relais, HUD privé')
-- =========================================================
onlyScenario('abandoned')
admin('missionSave', { missionId = ID, section = 'alarms', data = { wrongCrate = 0, wrongCode = 0, forced = 0, detection = 0, recover = 0, fakeVan = 0, levels = cfg.alarms.levels } })
T = Missions.types.fourgon.defaults().transport
T.requirePassword, T.pursuitAfterRelay = true, 0
admin('missionSave', { missionId = ID, section = 'transport', data = T })
local H = Missions.hudDefaults()
H.share, H.usedMode = false, 'remove'
admin('missionSave', { missionId = ID, section = 'hud', data = H })
check(cfg.hud.share == false and cfg.hud.usedMode == 'remove', 'HUD : partage désactivé, infos utilisées retirées')
local runE
runId, runE = launch()
findClues(runId, runE)
check(not Missions.knows(runE, 2, 'code') and Missions.knows(runE, 1, 'code'), 'partage OFF : seul Tony voit le code')
at(1, M.entities[runE.state.van].coords) M.tick()
timed(1, runId, 'rear', nil, cfg.van.openSeconds)
local re = runE.state.crates[runE.state.realIndex]
at(1, re.pos)
mission(1, runId, 'code', runE.state.realIndex, runE.state.code)
check(re.unlocked and not Missions.knows(runE, 1, 'code'), 'code utilisé : retiré du HUD')
timed(1, runId, 'crate', runE.state.realIndex, cfg.crates.openSeconds)
timed(1, runId, 'recover', nil, cfg.crates.recoverSeconds)
at(1, runE.state.relay.pos)
timed(1, runId, 'relay', nil, runE.state.relay.seconds)
check(runE.state.stage == 'TRANSPORT', 'relais : mot de passe inconnu → refusé')
at(1, M.entities[runE.state.van].coords)
timed(1, runId, 'cabin', nil, cfg.van.cabinSeconds)
check(Missions.knows(runE, 1, 'password'), 'mot de passe trouvé dans la cabine')
at(1, runE.state.relay.pos)
timed(1, runId, 'relay', nil, runE.state.relay.seconds)
check(runE.state.stage == 'FINAL_DELIVERY' and not Missions.knows(runE, 1, 'password'), 'relais validé, mot de passe utilisé')
act(1, 'abandonMission')

-- =========================================================
section('15. Persistance')
-- =========================================================
Missions.load()
local c2 = Missions.configs[ID]
local en = {}
for _, s in ipairs(c2.scenarios.list) do if s.enabled then en[#en + 1] = s.key end end
check(#en == 1 and en[1] == 'abandoned' and c2.transport.requirePassword and c2.hud.share == false, 'réglages du fourgon conservés au redémarrage')
check(Missions.cd.group[ID .. ':' .. ballas.id] ~= nil, 'cooldown reconstruit')

M.print(('\n%d réussis, %d échoués'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
