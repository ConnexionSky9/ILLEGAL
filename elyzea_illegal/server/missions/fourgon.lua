-- =========================================================
--  ELYZEA ILLÉGAL - MISSION NIVEAU 1 : « LE FOURGON FANTÔME »
--
--  Machine à états (serveur = seule source de vérité) :
--    SEARCH_AREA → FIND_CLUES → LOCATE_VAN → INVESTIGATE_VAN → RECOVER_CARGO
--    → TRANSPORT → RELAY (optionnel) → FINAL_DELIVERY → SUCCESS   (sinon FAILED)
--  Alarmes / renforts / police à tout moment selon les déclencheurs.
--
--  Le client n'envoie que des intentions (« je fouille l'indice 2 »,
--  « code 4729 pour la caisse 3 ») ; le serveur vérifie l'étape, le
--  participant, la distance, la durée, le code, la vraie caisse, le
--  porteur, et décide de tout (récompenses : moteur commun).
--  Toutes les données (positions, scénarios, ennemis, caisses, alarmes,
--  renforts, relais, livraison, bonus) se règlent dans
--  admin_menu › ILLEGAL › Missions › Le Fourgon Fantôme.
-- =========================================================
local U = Illegal.Utils
local copy = Missions.copy

-- ---------------------------------------------------------
--  SCHÉMA (réglages modifiables dans le menu staff)
-- ---------------------------------------------------------
local BEHAVIOR = { { value = 'passive', label = 'Passif' }, { value = 'wary', label = 'Méfiant' }, { value = 'aggressive', label = 'Agressif' },
    { value = 'very_aggressive', label = 'Très agressif' } }
local TRIGGER = { { value = 'distance', label = 'Distance' }, { value = 'los', label = 'Distance + ligne de vue' }, { value = 'alarm', label = 'Alarme' },
    { value = 'vanOpen', label = 'Ouverture du fourgon' }, { value = 'crate', label = 'Ouverture d\'une caisse' } }
local INFO_CAT = { { value = 'plate', label = 'Plaque' }, { value = 'code', label = 'Code' }, { value = 'password', label = 'Mot de passe' },
    { value = 'phone', label = 'Téléphone' }, { value = 'address', label = 'Adresse' }, { value = 'location', label = 'Localisation' },
    { value = 'clue', label = 'Indice' }, { value = 'info', label = 'Information' } }
local LEVELS = { { value = 0, label = 'Aucune' }, { value = 1, label = 'Alerte 1' }, { value = 2, label = 'Alerte 2' }, { value = 3, label = 'Alerte 3' } }
local SELECT = { { value = 'closest', label = 'Le plus proche' }, { value = 'random', label = 'Au hasard' }, { value = 'fixed', label = 'Fixe (n°)' } }

local function P(key, label) return { key = key, label = label, t = 'point' } end
local function B(key, label, def) return { key = key, label = label, t = 'bool', def = def } end
local function I(key, label, def, min, max) return { key = key, label = label, t = 'int', def = def, min = min or 0, max = max or 100000 } end
local function N(key, label, def, min, max) return { key = key, label = label, t = 'num', def = def, min = min or 0, max = max or 100000 } end
local function T(key, label, def, max) return { key = key, label = label, t = 'text', def = def, max = max or 120 } end
local function A(key, label, def) return { key = key, label = label, t = 'textarea', def = def, max = 500 } end
local function M(key, label, def, optional) return { key = key, label = label, t = 'model', def = def, optional = optional } end
local function AN(key, label, def) return { key = key, label = label, t = 'anim', def = def } end
local function S(key, label, def, options) return { key = key, label = label, t = 'select', def = def, options = options } end
local function L(key, label, fields, max) return { key = key, label = label, t = 'list', fields = fields, max = max or 30 } end

local CLUE_FIELDS = {
    B('enabled', 'Activé', true), I('order', 'Ordre', 1, 0, 99), T('scenario', 'Scénario (clé, « all » = tous)', 'all', 32), T('label', 'Nom', 'Indice', 64),
    M('model', 'Objet (modèle)', 'prop_npc_phone_02'), P('pos', 'Position'), A('text', 'Texte affiché', 'Tu trouves quelque chose.'),
    AN('animDict', 'Animation (dictionnaire)', 'amb@prop_human_bum_bin@base'), AN('animName', 'Animation (nom)', 'base'), N('seconds', 'Durée (s)', 4, 1, 60),
    T('infoLabel', 'Information fournie : nom (vide = aucune)', '', 64), T('infoValue', 'Valeur ({plate} {code} {password} {phone} {van} {location})', '', 120),
    S('infoCat', 'Catégorie', 'info', INFO_CAT), B('important', 'Important (gardé dans le HUD)', true),
}
local ENEMY_FIELDS = {
    M('model', 'Modèle', 'g_m_y_lost_01'), T('weapon', 'Arme', 'WEAPON_PISTOL', 40), I('ammo', 'Munitions', 120, 0, 9999),
    I('health', 'Santé', 200, 101, 2000), I('armor', 'Armure', 25, 0, 100), I('accuracy', 'Précision (%)', 35, 0, 100),
    S('behavior', 'Comportement / agressivité', 'aggressive', BEHAVIOR), S('trigger', 'Déclenchement', 'distance', TRIGGER),
    N('detect', 'Distance de détection (m)', 25, 1, 300), N('attack', 'Distance d\'attaque (m)', 18, 1, 300), N('chase', 'Distance de poursuite (m)', 60, 1, 1000),
    B('canFirearm', 'Peut utiliser une arme à feu', true), B('canMelee', 'Peut utiliser une arme blanche', true), B('cover', 'Se met à couvert', true),
    B('canChase', 'Poursuit', true), B('returnHome', 'Retour à sa position', false),
}
local ALERT_FIELDS = {
    T('label', 'Nom', 'Alerte', 40), B('police', 'Police prévenue', true), N('radius', 'Police : rayon d\'erreur (m)', 400, 0, 3000),
    I('sprite', 'Blip : icône', 161, 1, 900), I('color', 'Blip : couleur', 1, 0, 85), I('seconds', 'Blip : durée (s)', 120, 5, 1800),
    T('title', 'Titre police', 'Activité suspecte', 60), A('message', 'Message police', 'Activité suspecte signalée dans le secteur. Intervention nécessaire.'),
    T('code', 'Code dispatch', '10-31', 12), B('dispatch', 'Aussi via elyzea_police (dispatch)', true), B('reinforcements', 'Déclenche les renforts de ce niveau', true),
}
local WAVE_FIELDS = {
    T('label', 'Nom', 'Renforts', 40), S('level', 'Niveau d\'alerte (0 = embuscade)', 1, LEVELS), I('count', 'Nombre', 3, 1, 20),
    T('models', 'Modèles (séparés par des virgules)', 'g_m_y_lost_01,g_m_y_lost_02', 300), T('weapons', 'Armes (séparées par des virgules)', 'WEAPON_PISTOL,WEAPON_MICROSMG', 300),
    I('health', 'Santé', 200, 101, 2000), I('armor', 'Armure', 25, 0, 100), I('accuracy', 'Précision (%)', 35, 0, 100),
    S('behavior', 'Comportement', 'very_aggressive', BEHAVIOR), M('vehicle', 'Véhicule (vide = à pied)', '', true), I('vehicles', 'Nombre de véhicules', 0, 0, 5),
    I('delay', 'Délai (s)', 15, 0, 600), B('nearCargo', 'Apparaissent près de la marchandise (sinon près du fourgon)', true),
}

local SCHEMA = {
    scenarios = { key = 'scenarios', label = 'Scénarios', t = 'object', fields = {
        L('list', 'Scénarios', {
            T('key', 'Clé (unique)', 'abandoned', 32), T('label', 'Nom', 'Scénario', 64), B('enabled', 'Activé', true), A('description', 'Description', ''),
            B('damaged', 'Fourgon accidenté', false), B('guarded', 'Fourgon surveillé (ennemis sur place)', false),
            B('fakeVan', 'Faux fourgon trouvé d\'abord', false), B('moved', 'Fourgon déplacé (traces à suivre)', false),
            S('arrivalAlert', 'Alerte à l\'arrivée', 0, LEVELS),
        }, 20),
    } },
    search = { key = 'search', label = 'Recherche', t = 'object', fields = {
        N('radius', 'Rayon de la zone de recherche (m)', 180, 30, 2000), I('required', 'Indices nécessaires', 3, 1, 20),
        S('reveal', 'Révélation du fourgon', 'approx', { { value = 'exact', label = 'Position exacte' }, { value = 'approx', label = 'Zone approximative' } }),
        N('revealRadius', 'Rayon de la zone révélée (m)', 60, 5, 500), N('approachDistance', 'Distance pour « fourgon trouvé » (m)', 12, 3, 60),
        A('objectiveSearch', 'Objectif : recherche', 'Trouver le fourgon disparu'), A('objectiveLocate', 'Objectif : rejoindre', 'Rejoindre le fourgon'),
        N('traceSeconds', 'Durée : examiner les traces (s)', 5, 1, 60), N('fakeSeconds', 'Durée : inspecter le faux fourgon (s)', 5, 1, 60),
    } },
    van = { key = 'van', label = 'Fourgon', t = 'object', fields = {
        M('model', 'Modèle', 'speedo'), M('fakeModel', 'Modèle du faux fourgon', 'burrito3'), T('label', 'Nom du fourgon', 'Fourgon Vapid Speedo blanc', 64),
        S('plateMode', 'Plaque', 'random', { { value = 'random', label = 'Aléatoire' }, { value = 'fixed', label = 'Fixe' } }), T('plate', 'Plaque fixe', 'AB472CD', 8),
        B('locked', 'Portes verrouillées (ouverture forcée)', true), B('engineOff', 'Moteur coupé', true), B('doorsOpen', 'Portes arrière ouvertes', false),
        I('bodyDamage', 'Carrosserie si accident (0-1000)', 300, 0, 1000), I('engineDamage', 'Moteur si accident (0-1000)', 200, -4000, 1000),
        N('cabinSeconds', 'Durée : fouiller la cabine (s)', 5, 1, 60), N('openSeconds', 'Durée : ouvrir l\'arrière (s)', 4, 1, 60),
        N('forceSeconds', 'Durée : forcer l\'arrière (s)', 10, 1, 120),
    } },
    locations = { key = 'locations', label = 'Emplacements', t = 'object', fields = {
        S('select', 'Choix', 'random', { { value = 'random', label = 'Au hasard' }, { value = 'fixed', label = 'Fixe (n°)' } }), I('fixedIndex', 'N° si fixe', 1, 1, 30),
        L('list', 'Emplacements', {
            T('label', 'Nom', 'Emplacement', 64), B('enabled', 'Activé', true), T('scenarios', 'Scénarios autorisés (clés, virgules, « all »)', 'all', 200),
            P('van', 'Position du fourgon'), P('fakeVan', 'Position du faux fourgon'), P('movedVan', 'Position du fourgon déplacé'),
            L('clues', 'Indices', CLUE_FIELDS, 15), L('guards', 'Positions des ennemis', { P('pos', 'Position') }, 20),
            L('crates', 'Positions des caisses (vide = derrière le fourgon)', { P('pos', 'Position') }, 8),
            L('spawns', 'Points de spawn des renforts (vide = automatique)', { P('pos', 'Position') }, 20),
        }, 30),
    } },
    enemies = { key = 'enemies', label = 'Ennemis', t = 'object', fields = { L('list', 'Ennemis sur place (scénario surveillé)', ENEMY_FIELDS, 20) } },
    crates = { key = 'crates', label = 'Caisses', t = 'object', fields = {
        I('count', 'Nombre de caisses', 4, 2, 8), M('model', 'Objet', 'prop_box_wood02a'), I('secureCount', 'Caisses sécurisées (code)', 1, 0, 8),
        B('realSecure', 'La vraie caisse est sécurisée', true),
        S('codeMode', 'Code', 'clue', { { value = 'clue', label = 'Trouvé dans un indice (et dans la cabine)' }, { value = 'random', label = 'Aléatoire (cabine)' },
            { value = 'fixed', label = 'Fixe' } }), T('fixedCode', 'Code fixe', '4729', 12), I('codeLength', 'Longueur du code', 4, 3, 8),
        I('maxAttempts', 'Essais avant blocage (forcer ensuite)', 3, 1, 10), N('openSeconds', 'Durée : ouvrir (s)', 4, 1, 60), N('forceSeconds', 'Durée : forcer (s)', 12, 1, 120),
        AN('animDict', 'Animation (dictionnaire)', 'mini@repair'), AN('animName', 'Animation (nom)', 'fixing_a_ped'),
        T('recoverText', 'Texte : récupérer', 'Récupérer la marchandise', 64), N('recoverSeconds', 'Durée : récupérer (s)', 6, 1, 60),
        T('cargoLabel', 'Nom de la marchandise', 'Marchandise', 64), I('cargoQty', 'Quantité (affichée)', 1, 1, 1000),
        I('outEmpty', 'Fausse caisse : vide (poids)', 50, 0, 100), I('outFake', 'Fausse caisse : faux contenu (poids)', 20, 0, 100),
        I('outAlarm', 'Fausse caisse : alarme (poids)', 20, 0, 100), I('outAmbush', 'Fausse caisse : embuscade (poids)', 10, 0, 100),
    } },
    alarms = { key = 'alarms', label = 'Alarmes', t = 'object', fields = {
        S('wrongCrate', 'Mauvaise caisse (si « alarme »)', 1, LEVELS), S('wrongCode', 'Mauvais code', 1, LEVELS), S('forced', 'Ouverture forcée', 1, LEVELS),
        S('detection', 'Détection (gardes attaqués)', 1, LEVELS), S('recover', 'Récupération de la marchandise', 1, LEVELS), S('fakeVan', 'Faux fourgon inspecté', 0, LEVELS),
        L('levels', 'Niveaux d\'alerte (1, 2, 3)', ALERT_FIELDS, 3),
    } },
    reinforcements = { key = 'reinforcements', label = 'Renforts', t = 'object', fields = {
        N('minDistance', 'Distance minimum des joueurs (m)', 70, 20, 500), N('maxDistance', 'Distance maximum (m)', 120, 30, 800),
        L('waves', 'Vagues', WAVE_FIELDS, 12),
    } },
    transport = { key = 'transport', label = 'Transport', t = 'object', fields = {
        A('objective', 'Objectif : transport', 'Transporter la marchandise'),
        B('relayEnabled', 'Point relais', true), S('relaySelect', 'Choix du relais', 'closest', SELECT), I('relayIndex', 'N° si fixe', 1, 1, 20),
        B('requirePassword', 'Le relais demande le mot de passe', false),
        B('transferEnabled', 'Changement de véhicule au relais', true), M('transferModel', 'Véhicule de transfert', 'burrito3'),
        B('requireTransferVehicle', 'Livraison avec le véhicule de transfert', false),
        S('pursuitAfterRecover', 'Poursuite après récupération (alerte)', 0, LEVELS), S('pursuitAfterRelay', 'Poursuite après le relais (alerte)', 2, LEVELS),
        L('relays', 'Points relais', {
            T('label', 'Nom', 'Point relais', 64), P('pos', 'Position'),
            S('type', 'Type', 'ped', { { value = 'zone', label = 'Zone' }, { value = 'ped', label = 'PNJ' }, { value = 'vehicle', label = 'Véhicule' } }),
            M('ped', 'PNJ (modèle)', 'g_m_m_chicold_01'), AN('scenario', 'Animation d\'attente (scénario)', 'WORLD_HUMAN_SMOKING'),
            N('radius', 'Rayon (m)', 4, 1, 50), T('text', 'Texte', 'Transférer la marchandise', 64), N('seconds', 'Durée (s)', 5, 1, 60), P('vehiclePos', 'Position du véhicule de transfert'),
        }, 20),
    } },
    delivery = { key = 'delivery', label = 'Livraison', t = 'object', fields = {
        S('select', 'Choix du point', 'closest', SELECT), I('fixedIndex', 'N° si fixe', 1, 1, 20), N('seconds', 'Durée (s)', 4, 1, 60),
        A('objective', 'Objectif : livraison', 'Livrer la marchandise au commanditaire'),
        L('points', 'Points de livraison', {
            T('label', 'Nom', 'Commanditaire', 64), P('pos', 'Position'), M('ped', 'PNJ', 'g_m_m_armboss_01'), AN('scenario', 'Animation d\'attente', 'WORLD_HUMAN_STAND_IMPATIENT'),
            AN('animDict', 'Animation livraison (dict.)', 'mp_common'), AN('animName', 'Animation livraison (nom)', 'givetake1_a'),
            T('text', 'Texte', 'Livrer la marchandise', 64), N('distance', 'Distance d\'interaction (m)', 2.5, 1, 10),
            I('blipSprite', 'Blip : icône', 478, 1, 900), I('blipColor', 'Blip : couleur', 5, 0, 85),
        }, 20),
    } },
    bonus = { key = 'bonus', label = 'Bonus', t = 'object', fields = (function()
        local out = { I('timeLeftMinutes', 'Bonus temps : minutes restantes minimum', 10, 0, 180) }
        for _, b in ipairs({ { 'timeLeft', 'Temps restant' }, { 'noAlarm', 'Aucune alarme' }, { 'noWrongCrate', 'Aucune mauvaise caisse' },
            { 'noDeath', 'Aucun participant mort' }, { 'noPolice', 'Aucune alerte police' }, { 'noLoss', 'Livraison sans perte' } }) do
            out[#out + 1] = { key = b[1], label = b[2], t = 'object', fields = { B('enabled', 'Activé', false), I('money', 'Argent', 0, 0, 10000000),
                I('xp', 'XP', 0, 0, 100000), M('item', 'Objet (vide = aucun)', '', true), I('itemCount', 'Quantité', 1, 1, 1000) } }
        end
        return out
    end)() },
}
local SECTIONS = { 'general', 'groups', 'progression', 'hud', 'scenarios', 'search', 'locations', 'van', 'enemies', 'crates', 'alarms',
    'reinforcements', 'transport', 'delivery', 'timer', 'rewards', 'bonus', 'phone', 'cooldown', 'weapons', 'security' }

-- ---------------------------------------------------------
--  CONTENU PAR DÉFAUT (coordonnées approximatives : à refaire en jeu
--  avec « Définir à ma position »)
-- ---------------------------------------------------------
local function pt(x, y, z, h) return { x = x, y = y, z = z, h = h or 0.0 } end
local function clue(order, label, model, pos, text, infoLabel, infoValue, cat, scenario, dict, name)
    return { enabled = true, order = order, scenario = scenario or 'all', label = label, model = model, pos = pos, text = text,
        animDict = dict or 'amb@prop_human_bum_bin@base', animName = name or 'base', seconds = 4, infoLabel = infoLabel or '', infoValue = infoValue or '',
        infoCat = cat or 'info', important = infoLabel ~= nil }
end
local function enemy(model, weapon, behavior, trigger)
    return { model = model, weapon = weapon, ammo = 150, health = 220, armor = 30, accuracy = 40, behavior = behavior, trigger = trigger or 'distance',
        detect = 30.0, attack = 22.0, chase = 70.0, canFirearm = true, canMelee = true, cover = true, canChase = true, returnHome = false }
end
local function wave(label, level, count, models, weapons, vehicle, vehicles, delay, nearCargo)
    return { label = label, level = level, count = count, models = models, weapons = weapons, health = 220, armor = 35, accuracy = 40,
        behavior = 'very_aggressive', vehicle = vehicle or '', vehicles = vehicles or 0, delay = delay or 15, nearCargo = nearCargo ~= false }
end
local function alertLevel(label, radius, seconds)
    return { label = label, police = true, radius = radius, sprite = 161, color = 1, seconds = seconds, title = 'Activité suspecte',
        message = 'Activité suspecte signalée dans le secteur. Intervention nécessaire.', code = '10-31', dispatch = true, reinforcements = true }
end

local function defaults()
    return {
        general = { label = 'Le Fourgon Fantôme', description = 'Un fourgon chargé de marchandise a disparu avec son chauffeur. Retrouvez-le, récupérez la vraie cargaison et livrez-la.',
            enabled = true, levelRequired = 1, xp = 75, xpMax = 100, difficulty = 'normal', minPlayers = 1, maxPlayers = 4 },
        groups = { mode = 'all', list = {} },
        timer = { minutes = 30 },
        cooldown = { mission = 0, group = 60, player = 45 },
        phone = {
            sender = 'Numéro inconnu',
            start = 'Le fourgon qui devait livrer notre marchandise n\'est jamais arrivé. Le chauffeur a disparu avec la cargaison. Retrouvez le fourgon avant que quelqu\'un d\'autre mette la main dessus. Je veux la marchandise, pas le chauffeur.',
            fail = 'La marchandise est perdue. Je m\'en souviendrai.',
            finish = 'Merci pour le service rendu !',
            levelup = 'Ton groupe passe niveau {level} ({label}). On parlera de choses plus sérieuses.',
        },
        rewards = { money = { enabled = true, min = 15000, max = 22000, account = 'dirty' },
            items = { enabled = true, list = { { item = 'lockpick', min = 2, max = 4, chance = 100 } } } },
        weapons = { firearms = true, melee = true, explosives = false, vehicles = true, action = 'warn' },
        security = { participantRadius = 60.0, interactDistance = 2.5, failOnAllLeft = true },
        hud = Missions.hudDefaults(),
        scenarios = { list = {
            { key = 'abandoned', label = 'Fourgon abandonné', enabled = true, description = 'Le fourgon est là, le chauffeur a disparu.', damaged = false, guarded = false, fakeVan = false, moved = false, arrivalAlert = 0 },
            { key = 'accident', label = 'Accident', enabled = true, description = 'Le fourgon a été accidenté.', damaged = true, guarded = false, fakeVan = false, moved = false, arrivalAlert = 0 },
            { key = 'watched', label = 'Fourgon surveillé', enabled = true, description = 'Des ennemis surveillent la zone.', damaged = false, guarded = true, fakeVan = false, moved = false, arrivalAlert = 0 },
            { key = 'fake', label = 'Faux fourgon', enabled = true, description = 'Le premier véhicule trouvé n\'est pas le bon.', damaged = false, guarded = false, fakeVan = true, moved = false, arrivalAlert = 0 },
            { key = 'moved', label = 'Fourgon déplacé', enabled = true, description = 'Des indices montrent que le fourgon a été déplacé.', damaged = false, guarded = true, fakeVan = false, moved = true, arrivalAlert = 0 },
        } },
        search = { radius = 180.0, required = 3, reveal = 'approx', revealRadius = 60.0, approachDistance = 12.0,
            objectiveSearch = 'Trouver le fourgon disparu', objectiveLocate = 'Rejoindre le fourgon', traceSeconds = 5, fakeSeconds = 5 },
        van = { model = 'speedo', fakeModel = 'burrito3', label = 'Fourgon Vapid Speedo blanc', plateMode = 'random', plate = 'AB472CD', locked = true,
            engineOff = true, doorsOpen = false, bodyDamage = 300, engineDamage = 200, cabinSeconds = 5, openSeconds = 4, forceSeconds = 10 },
        locations = { select = 'random', fixedIndex = 1, list = {
            { label = 'Carrière de Davis Quartz', enabled = true, scenarios = 'all',
              van = pt(2952.0, 2788.0, 41.5, 300.0), fakeVan = pt(2920.0, 2770.0, 43.0, 120.0), movedVan = pt(2690.0, 2860.0, 36.8, 30.0),
              clues = {
                clue(1, 'Téléphone abandonné', 'prop_npc_phone_02', pt(2905.0, 2795.0, 45.0), 'Un message non lu : « Plaque du fourgon : {plate}. Ne t\'arrête pas. »', 'Plaque du fourgon', '{plate}', 'plate'),
                clue(2, 'GPS arraché', 'prop_cs_tablet', pt(2935.0, 2760.0, 42.5), 'Le GPS indique un arrêt prolongé près de la carrière.', 'Localisation', 'Carrière de Davis Quartz', 'location'),
                clue(3, 'Document froissé', 'prop_cs_documents_01', pt(2965.0, 2805.0, 41.0), 'Bon de livraison : « Caisse sécurisée — code {code} ».', 'Code caisse', '{code}', 'code'),
                clue(4, 'Traces de pneus', 'prop_tyre_spike_01', pt(2925.0, 2820.0, 42.0), 'Des traces fraîches partent vers le nord.', nil, nil, 'clue'),
              },
              guards = {}, crates = {}, spawns = {} },
            { label = 'Port de Los Santos', enabled = true, scenarios = 'all',
              van = pt(1220.0, -3020.0, 5.9, 90.0), fakeVan = pt(1180.0, -3050.0, 5.9, 0.0), movedVan = pt(1015.0, -3105.0, 5.9, 180.0),
              clues = {
                clue(1, 'Sac du chauffeur', 'prop_cs_heist_bag_02', pt(1195.0, -3000.0, 5.9), 'Un carnet : « Mot de passe du relais : {password} ».', 'Mot de passe', '{password}', 'password'),
                clue(2, 'Caméra de surveillance', 'prop_cctv_cam_01a', pt(1240.0, -3040.0, 6.5), 'L\'enregistrement montre le {van} passer à 03:12.', 'Fourgon', '{van}', 'info',
                    nil, 'amb@world_human_stand_mobile@male@text@base', 'base'),
                clue(3, 'Témoin effrayé', 'prop_cs_documents_01', pt(1210.0, -2990.0, 5.9), 'Le témoin a noté un numéro : {phone}.', 'Numéro de téléphone', '{phone}', 'phone'),
                clue(4, 'Plaque arrachée', 'prop_cs_package_01', pt(1250.0, -3010.0, 5.9), 'Une plaque tordue : {plate}.', 'Plaque du fourgon', '{plate}', 'plate'),
              },
              guards = {}, crates = {}, spawns = {} },
        } },
        enemies = { list = {
            enemy('g_m_y_lost_01', 'WEAPON_PISTOL', 'aggressive', 'los'), enemy('g_m_y_lost_02', 'WEAPON_MICROSMG', 'aggressive', 'los'),
            enemy('g_m_y_lost_03', 'WEAPON_PUMPSHOTGUN', 'very_aggressive', 'distance'), enemy('g_m_y_lost_01', 'WEAPON_BAT', 'very_aggressive', 'distance'),
        } },
        crates = { count = 4, model = 'prop_box_wood02a', secureCount = 1, realSecure = true, codeMode = 'clue', fixedCode = '4729', codeLength = 4,
            maxAttempts = 3, openSeconds = 4, forceSeconds = 12, animDict = 'mini@repair', animName = 'fixing_a_ped', recoverText = 'Récupérer la marchandise',
            recoverSeconds = 6, cargoLabel = 'Marchandise', cargoQty = 1, outEmpty = 50, outFake = 20, outAlarm = 20, outAmbush = 10 },
        alarms = { wrongCrate = 1, wrongCode = 1, forced = 1, detection = 1, recover = 1, fakeVan = 0, levels = {
            alertLevel('Alerte 1', 600.0, 90), alertLevel('Alerte 2', 300.0, 150), alertLevel('Alerte 3', 120.0, 240) } },
        reinforcements = { minDistance = 70.0, maxDistance = 120.0, waves = {
            wave('Embuscade', 0, 3, 'g_m_y_lost_01,g_m_y_lost_03', 'WEAPON_PISTOL,WEAPON_BAT', '', 0, 2, true),
            wave('Renforts', 1, 2, 'g_m_y_lost_01,g_m_y_lost_02', 'WEAPON_PISTOL', '', 0, 20, true),
            wave('Renforts motorisés', 2, 4, 'g_m_y_lost_02,g_m_y_lost_03', 'WEAPON_MICROSMG,WEAPON_PISTOL', 'gburrito', 1, 25, true),
            wave('Gros renforts', 3, 6, 'g_m_y_lost_01,g_m_y_lost_02,g_m_y_lost_03', 'WEAPON_MICROSMG,WEAPON_PUMPSHOTGUN', 'gburrito2', 2, 20, true),
            wave('Deuxième vague', 3, 4, 'g_m_y_lost_02,g_m_y_lost_03', 'WEAPON_ASSAULTRIFLE', 'gburrito', 1, 60, true),
        } },
        transport = { objective = 'Transporter la marchandise', relayEnabled = true, relaySelect = 'closest', relayIndex = 1, requirePassword = false,
            transferEnabled = true, transferModel = 'burrito3', requireTransferVehicle = false, pursuitAfterRecover = 0, pursuitAfterRelay = 2,
            relays = {
                { label = 'Garage abandonné de Sandy', pos = pt(2001.0, 3780.0, 32.2, 210.0), type = 'ped', ped = 'g_m_m_chicold_01', scenario = 'WORLD_HUMAN_SMOKING',
                  radius = 4.0, text = 'Transférer la marchandise', seconds = 5, vehiclePos = pt(2008.0, 3775.0, 32.2, 210.0) },
                { label = 'Hangar de La Mesa', pos = pt(890.0, -1050.0, 32.8, 0.0), type = 'ped', ped = 'g_m_m_chicold_01', scenario = 'WORLD_HUMAN_SMOKING',
                  radius = 4.0, text = 'Transférer la marchandise', seconds = 5, vehiclePos = pt(895.0, -1058.0, 32.8, 90.0) },
            } },
        delivery = { select = 'closest', fixedIndex = 1, seconds = 4, objective = 'Livrer la marchandise au commanditaire', points = {
            { label = 'Le commanditaire (Vinewood Hills)', pos = pt(-1515.0, 850.0, 181.6, 30.0), ped = 'g_m_m_armboss_01', scenario = 'WORLD_HUMAN_STAND_IMPATIENT',
              animDict = 'mp_common', animName = 'givetake1_a', text = 'Livrer la marchandise', distance = 2.5, blipSprite = 478, blipColor = 5 },
            { label = 'Le commanditaire (Paleto)', pos = pt(-150.0, 6300.0, 31.5, 300.0), ped = 'g_m_m_armboss_01', scenario = 'WORLD_HUMAN_STAND_IMPATIENT',
              animDict = 'mp_common', animName = 'givetake1_a', text = 'Livrer la marchandise', distance = 2.5, blipSprite = 478, blipColor = 5 },
        } },
        bonus = { timeLeftMinutes = 10,
            timeLeft = { enabled = true, money = 2000, xp = 10, item = '', itemCount = 1 },
            noAlarm = { enabled = true, money = 3000, xp = 15, item = '', itemCount = 1 },
            noWrongCrate = { enabled = true, money = 1000, xp = 5, item = '', itemCount = 1 },
            noDeath = { enabled = true, money = 1500, xp = 10, item = '', itemCount = 1 },
            noPolice = { enabled = true, money = 2000, xp = 10, item = '', itemCount = 1 },
            noLoss = { enabled = true, money = 1000, xp = 5, item = '', itemCount = 1 } },
    }
end

local function sanitize(section, d, cur)
    local f = SCHEMA[section]
    if not f then return nil, 'Section inconnue.' end
    local v = Missions.sanitizeField(f, d, cur)
    if section == 'scenarios' then
        local seen = {}
        for _, s in ipairs(v.list) do
            s.key = (U.ident(s.key) or ('s' .. tostring(#seen + 1)))
            if seen[s.key] then return nil, ('Clé de scénario en double : %s'):format(s.key) end
            seen[s.key] = true
        end
    elseif section == 'reinforcements' and v.minDistance > v.maxDistance then
        return nil, 'Renforts : la distance minimum dépasse la maximum.'
    end
    return v
end

-- =========================================================
--  OUTILS
-- =========================================================
local DIFF = { easy = 0.75, normal = 1.0, hard = 1.3, extreme = 1.6 }
local WORDS = { 'REDFOX', 'NIGHTOWL', 'BLACKJACK', 'SILVERCAT', 'IRONWOLF', 'GHOSTRIDER', 'COBRA', 'MIDNIGHT', 'VIPER', 'SHADOW' }
local STAGE_LABEL = {
    SEARCH_AREA = 'Rejoindre la zone de recherche', FIND_CLUES = 'Trouver des indices', LOCATE_VAN = 'Localiser le fourgon',
    INVESTIGATE_VAN = 'Examiner le fourgon', RECOVER_CARGO = 'Trouver la vraie marchandise', TRANSPORT = 'Transporter la marchandise',
    RELAY = 'Point relais', FINAL_DELIVERY = 'Livraison finale',
}

local function v3(p) return vector3(p.x, p.y, p.z) end
local function dist2(a, b) return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2) end
local function waitEntity(e)
    local limit = GetGameTimer() + 2000
    while (not e or e == 0 or not DoesEntityExist(e)) and GetGameTimer() < limit do Wait(50) end
    return e and e ~= 0 and DoesEntityExist(e)
end
local function alive(e) return e and DoesEntityExist(e) and GetEntityHealth(e) > 0 end
local function ppos(src) local ped = GetPlayerPed(src) if not ped or ped == 0 then return nil end return GetEntityCoords(ped) end
local function near(src, p, d) local c = ppos(src) return c ~= nil and #(c - v3(p)) <= d end
local function nearEnt(src, ent, d)
    local c = ppos(src)
    return c ~= nil and ent ~= nil and DoesEntityExist(ent) and #(c - GetEntityCoords(ent)) <= d
end
local function split(s) local t = {} for w in tostring(s or ''):gmatch('[^,%s]+') do t[#t + 1] = w end return t end
local function notifyAll(run, msg, kind) for s in pairs(run.participants) do Players.notify(s, msg, kind) end end
local function randomPlate()
    local L = 'ABCDEFGHJKLMNPRSTUVWXYZ'
    local function l() local i = math.random(#L) return L:sub(i, i) end
    return ('%s%s-%03d-%s%s'):format(l(), l(), math.random(0, 999), l(), l())
end
local function randomCode(n) local t = {} for i = 1, n do t[i] = tostring(math.random(0, 9)) end return table.concat(t) end

local function tokens(run, s)
    local st = run.state
    return (tostring(s or ''):gsub('{(%w+)}', function(k)
        local v = ({ plate = st.plate, code = st.code, password = st.password, phone = st.phone, van = run.cfg.van.label, location = st.loc.label })[k]
        return v ~= nil and tostring(v) or ('{' .. k .. '}')
    end))
end

local function setStage(run, stage)
    run.state.stage = stage
    run.stageLabel = STAGE_LABEL[stage] or stage
end

-- Étape « en cours » d'une action longue : le client annonce le début, le serveur mesure la durée
local function begin(run, src, key) run.state.timing[src .. ':' .. key] = GetGameTimer() end
local function finished(run, src, key, seconds)
    local t = run.state.timing[src .. ':' .. key]
    run.state.timing[src .. ':' .. key] = nil
    return t ~= nil and GetGameTimer() - t >= seconds * 1000 - 900
end

-- Véhicule créé par le serveur (fourgon, faux fourgon, renforts, transfert)
local function spawnVehicle(run, model, p, plate)
    local veh = CreateVehicleServerSetter(joaat(model), 'automobile', p.x + 0.0, p.y + 0.0, p.z + 0.0, (p.h or 0.0) + 0.0)
    if not waitEntity(veh) then return nil end
    if plate then SetVehicleNumberPlateText(veh, plate) end
    run.state.vehicles[#run.state.vehicles + 1] = veh
    return veh
end

-- Ennemi créé par le serveur, comportement appliqué par l'IA commune (client/missions/core.lua)
local function spawnEnemy(run, e, p, opts)
    opts = opts or {}
    local mul = DIFF[run.cfg.general.difficulty] or 1
    local ped = CreatePed(4, joaat(e.model), p.x + 0.0, p.y + 0.0, p.z + 0.5, (p.h or 0.0) + 0.0, true, true)
    if not waitEntity(ped) then return nil end
    local weapon = (e.weapon or 'WEAPON_UNARMED'):upper()
    local kind = Missions.weaponKind(GetHashKey(weapon))
    if kind == 'firearms' and e.canFirearm == false then weapon = e.canMelee ~= false and 'WEAPON_KNIFE' or 'WEAPON_UNARMED'
    elseif kind == 'melee' and e.canMelee == false then weapon = 'WEAPON_UNARMED' end
    if weapon ~= 'WEAPON_UNARMED' then GiveWeaponToPed(ped, joaat(weapon), e.ammo or 200, false, true) end
    local armor = math.min(100, math.floor((e.armor or 0) * mul))
    if armor > 0 then SetPedArmour(ped, armor) end
    if opts.vehicle then SetPedIntoVehicle(ped, opts.vehicle, opts.seat or -1) end
    Entity(ped).state:set('illegalGuard', { run = run.id, model = e.model, weapon = weapon, health = math.min(2000, math.floor((e.health or 200) * mul)),
        accuracy = math.min(100, math.floor((e.accuracy or 30) * mul)), behavior = e.behavior or 'aggressive', trigger = e.trigger or 'distance',
        detect = e.detect or 30, attack = e.attack or 20, chase = e.chase or 60, returnHome = e.returnHome == true, canChase = e.canChase ~= false,
        cover = e.cover ~= false, hx = p.x, hy = p.y, hz = p.z, hh = p.h or 0.0 }, true)
    if opts.alerted then Entity(ped).state:set('illegalAlerted', true, true) end
    run.state.enemies[#run.state.enemies + 1] = ped
    run.entities[ped] = #run.state.enemies
    return ped
end

local function alertEnemies(run, reason)
    for _, ped in ipairs(run.state.enemies) do
        if DoesEntityExist(ped) then
            local st = Entity(ped).state.illegalGuard
            if st and (reason == 'alarm' or st.trigger == reason) then Entity(ped).state:set('illegalAlerted', true, true) end
        end
    end
end

-- Point de spawn des renforts : jamais sur les joueurs (distance minimum à tous les participants)
local function farEnough(run, p)
    local min = run.cfg.reinforcements.minDistance
    for src in pairs(run.participants) do
        local c = ppos(src)
        if c and dist2(c, p) < min then return false end
    end
    return true
end

local function spawnPoint(run, anchor)
    local R = run.cfg.reinforcements
    local pts = {}
    for _, s in ipairs(run.state.loc.spawns or {}) do if farEnough(run, s.pos) then pts[#pts + 1] = s.pos end end
    if #pts > 0 then return copy(pts[math.random(#pts)]) end
    for _ = 1, 16 do
        local a = math.random() * math.pi * 2
        local d = R.minDistance + math.random() * (R.maxDistance - R.minDistance)
        local p = { x = anchor.x + math.cos(a) * d, y = anchor.y + math.sin(a) * d, z = anchor.z, h = (math.deg(a) + 180.0) % 360.0 }
        if farEnough(run, p) then return p end
    end
    local a = math.random() * math.pi * 2
    return { x = anchor.x + math.cos(a) * R.maxDistance, y = anchor.y + math.sin(a) * R.maxDistance, z = anchor.z, h = 0.0 }
end

-- Position de référence : porteur de la marchandise, sinon fourgon, sinon zone
local function anchorOf(run, nearCargo)
    local st = run.state
    if nearCargo and st.carrier then
        for s, cid in pairs(run.participants) do if cid == st.carrier then local c = ppos(s) if c then return { x = c.x, y = c.y, z = c.z } end end end
    end
    if st.van and DoesEntityExist(st.van) then local c = GetEntityCoords(st.van) return { x = c.x, y = c.y, z = c.z } end
    return { x = st.realPos.x, y = st.realPos.y, z = st.realPos.z }
end

local function spawnWave(run, w)
    local mul = DIFF[run.cfg.general.difficulty] or 1
    local models, weapons = split(w.models), split(w.weapons)
    if #models == 0 then models = { 'g_m_y_lost_01' } end
    if #weapons == 0 then weapons = { 'WEAPON_PISTOL' } end
    local count = math.max(1, math.floor(w.count * mul + 0.5))
    local base = spawnPoint(run, anchorOf(run, w.nearCargo))
    local e = { health = w.health, armor = w.armor, accuracy = w.accuracy, behavior = w.behavior, trigger = 'distance', detect = 200.0, attack = 200.0,
        chase = 400.0, canChase = true, returnHome = false, cover = true, canFirearm = true, canMelee = true, ammo = 400 }
    local vehs = {}
    if w.vehicle ~= '' and w.vehicles > 0 then
        for i = 1, w.vehicles do
            local p = { x = base.x + (i - 1) * 5.0, y = base.y, z = base.z, h = base.h }
            local veh = spawnVehicle(run, w.vehicle, p)
            if veh then vehs[#vehs + 1] = veh end
        end
    end
    for i = 1, count do
        e.model, e.weapon = models[math.random(#models)], weapons[math.random(#weapons)]
        local veh, seat = vehs[((i - 1) % math.max(1, #vehs)) + 1], (i - 1) // math.max(1, #vehs) - 1
        if veh and seat > 2 then veh = nil end
        local a = math.random() * math.pi * 2
        local p = { x = base.x + math.cos(a) * 3.0, y = base.y + math.sin(a) * 3.0, z = base.z, h = base.h }
        spawnEnemy(run, e, p, { vehicle = veh, seat = seat, alerted = true })
    end
    Log({ name = 'Système' }, run.groupId, 'Mission : renforts', ('%s · %s : %d ennemi(s), %d véhicule(s)'):format(run.cfg.general.label, w.label, count, #vehs))
    notifyAll(run, ('⚠️ %s en approche !'):format(w.label), 'error')
end

-- Monte l'alerte (jamais à la baisse) : police, renforts, ennemis en alerte, HUD
local function raise(run, level, reason)
    local st = run.state
    level = math.min(3, math.floor(tonumber(level) or 0))
    if level <= 0 then return end
    st.alarm = true
    if level <= (run.alert or 0) then return end
    run.alert = level
    local lvl = run.cfg.alarms.levels[level]
    Missions.info(run, nil, 'alert', 'Alerte', ('%d — %s'):format(level, lvl and lvl.label or ''), 'alert', { order = 2, persistent = true })
    notifyAll(run, ('🚨 ALERTE %d : %s'):format(level, reason or ''), 'error')
    Log({ name = 'Système' }, run.groupId, 'Mission : alerte', ('%s · niveau %d · %s'):format(run.cfg.general.label, level, reason or ''))
    alertEnemies(run, 'alarm')
    if lvl and lvl.police then
        local a = anchorOf(run, true)
        st.police = true
        Missions.policeAlert(run, lvl, a.x, a.y, a.z)
    end
    if not lvl or lvl.reinforcements ~= false then
        for i, w in ipairs(run.cfg.reinforcements.waves) do
            if w.level > 0 and w.level <= level and not st.waves[i] then
                st.waves[i] = true
                st.pending[#st.pending + 1] = { at = os.time() + w.delay, wave = w }
            end
        end
    end
end

local function trigger(run, key, reason)
    local lvl = run.cfg.alarms[key]
    if lvl and lvl > 0 then raise(run, lvl, reason) end
end

-- =========================================================
--  LANCEMENT : emplacement, scénario, codes, indices
-- =========================================================
local function scenarioAllowed(loc, key)
    if loc.scenarios == '' or loc.scenarios == 'all' then return true end
    for _, k in ipairs(split(loc.scenarios)) do if k == key or k == 'all' then return true end end
    return false
end

local function start(run)
    local cfg = run.cfg
    local L = cfg.locations
    local pool = {}
    for i, l in ipairs(L.list) do if l.enabled then pool[#pool + 1] = i end end
    if #pool == 0 then return false, 'Aucun emplacement de fourgon n\'est configuré : préviens le staff.' end
    local li = pool[math.random(#pool)]
    if L.select == 'fixed' and L.list[L.fixedIndex] and L.list[L.fixedIndex].enabled then li = L.fixedIndex end
    local loc = L.list[li]
    local scen = {}
    for _, s in ipairs(cfg.scenarios.list) do if s.enabled and scenarioAllowed(loc, s.key) then scen[#scen + 1] = s end end
    if #scen == 0 then return false, 'Aucun scénario activé pour cet emplacement : préviens le staff.' end
    if #cfg.delivery.points == 0 then return false, 'Aucun point de livraison n\'est configuré : préviens le staff.' end
    if cfg.transport.relayEnabled and #cfg.transport.relays == 0 then return false, 'Aucun point relais n\'est configuré : préviens le staff.' end
    local sc = scen[math.random(#scen)]

    local C = cfg.crates
    local st = {
        loc = loc, scenario = sc, timing = {}, vehicles = {}, enemies = {}, waves = {}, pending = {},
        plate = cfg.van.plateMode == 'fixed' and cfg.van.plate:upper() or randomPlate(),
        code = C.codeMode == 'fixed' and C.fixedCode or randomCode(C.codeLength),
        password = WORDS[math.random(#WORDS)], phone = ('555-%04d'):format(math.random(0, 9999)),
        found = 0, clues = {}, flags = { wrongCrate = false, died = false, loss = false },
    }
    run.state, run.entities, run.alert = st, {}, 0
    st.realPos = (sc.moved and loc.movedVan) or loc.van
    -- Zone de recherche approximative (le fourgon n'est pas au centre)
    local r = cfg.search.radius * 0.55 * math.sqrt(math.random())
    local a = math.random() * math.pi * 2
    st.area = { x = loc.van.x + math.cos(a) * r, y = loc.van.y + math.sin(a) * r, z = loc.van.z, radius = cfg.search.radius }
    -- Indices du scénario, triés par ordre
    for _, c in ipairs(loc.clues) do
        if c.enabled and (c.scenario == '' or c.scenario == 'all' or c.scenario == sc.key) then st.clues[#st.clues + 1] = { def = c, found = false } end
    end
    table.sort(st.clues, function(x, y) return x.def.order < y.def.order end)
    st.required = math.max(1, math.min(cfg.search.required, #st.clues))
    if #st.clues == 0 then st.required = 0 end
    run.locationLabel = ('%s · %s'):format(loc.label, sc.label)
    setStage(run, 'SEARCH_AREA')
    Missions.info(run, nil, 'objective', 'Objectif', cfg.search.objectiveSearch, 'objective', { order = 1, persistent = true })
    Missions.info(run, nil, 'clues', 'Indices', ('0 / %d'):format(st.required), 'clues', { order = 3, persistent = true })
    if st.required == 0 then
        st.revealNow = true   -- aucun indice configuré : le fourgon est révélé directement (jamais bloqué)
    end
    return true
end

-- =========================================================
--  PROGRESSION
-- =========================================================
local function guardsAround(run, p)
    local list = run.cfg.enemies.list
    for i, e in ipairs(list) do
        local gp = run.state.loc.guards[i] and run.state.loc.guards[i].pos
        if not gp then
            local a = (i / math.max(1, #list)) * math.pi * 2
            gp = { x = p.x + math.cos(a) * 9.0, y = p.y + math.sin(a) * 9.0, z = p.z, h = math.deg(a) + 90.0 }
        end
        spawnEnemy(run, e, gp)
    end
end

local function spawnRealVan(run)
    local st, cfg = run.state, run.cfg
    local p = st.realPos
    st.van = spawnVehicle(run, cfg.van.model, p, st.plate:gsub('-', ''))
    if st.van then
        SetVehicleDoorsLocked(st.van, cfg.van.locked and 2 or 1)
        Entity(st.van).state:set('illegalVan', { run = run.id, damaged = st.scenario.damaged, body = cfg.van.bodyDamage, engine = cfg.van.engineDamage,
            engineOff = cfg.van.engineOff, doorsOpen = cfg.van.doorsOpen }, true)
    end
    if st.scenario.guarded then guardsAround(run, p) end
end

-- Assez d'indices : la position (exacte ou approximative) du fourgon est révélée
local function reveal(run)
    local st, cfg = run.state, run.cfg
    if st.revealed then return end
    st.revealed = true
    setStage(run, 'LOCATE_VAN')
    local target = st.scenario.moved and st.loc.van or st.realPos
    if st.scenario.moved then st.traceAt = st.loc.van end
    if st.scenario.fakeVan then
        st.fake = spawnVehicle(run, cfg.van.fakeModel, st.loc.fakeVan, randomPlate():gsub('-', ''))
        if st.fake then SetVehicleDoorsLocked(st.fake, 2) end
        target = st.loc.fakeVan
    end
    if not st.scenario.moved and not st.scenario.fakeVan then spawnRealVan(run) end
    local exact = cfg.search.reveal == 'exact'
    local r = exact and 0 or cfg.search.revealRadius * 0.6 * math.sqrt(math.random())
    local a = math.random() * math.pi * 2
    st.target = { x = target.x + math.cos(a) * r, y = target.y + math.sin(a) * r, z = target.z, radius = exact and 0 or cfg.search.revealRadius, exact = exact }
    Missions.info(run, nil, 'objective', 'Objectif', cfg.search.objectiveLocate, 'objective', { order = 1, persistent = true })
    Missions.info(run, nil, 'van', 'Fourgon', ('%s · %s'):format(cfg.van.label, st.plate), 'plate', { order = 4, persistent = true })
    Missions.dropInfo(run, 'clues')
    notifyAll(run, 'Assez d\'indices : la position du fourgon est sur votre GPS.', 'success')
    Log({ name = 'Système' }, run.groupId, 'Mission : fourgon localisé', ('%s · %s'):format(cfg.general.label, run.locationLabel))
end

local function arrived(run)
    local st = run.state
    setStage(run, 'INVESTIGATE_VAN')
    Missions.info(run, nil, 'objective', 'Objectif', 'Fouiller la cabine et ouvrir l\'arrière du fourgon', 'objective', { order = 1, persistent = true })
    if st.scenario.arrivalAlert > 0 then raise(run, st.scenario.arrivalAlert, 'Vous êtes repérés') end
    notifyAll(run, ('Fourgon trouvé : %s.'):format(run.cfg.van.label), 'success')
end

-- Caisses : la vraie et les sécurisées sont tirées par le serveur
local function makeCrates(run)
    local st, C = run.state, run.cfg.crates
    local vc, vh = GetEntityCoords(st.van), GetEntityHeading(st.van)
    local rad = math.rad(vh)
    local fx, fy = -math.sin(rad), math.cos(rad)       -- avant du fourgon
    local rx, ry = math.cos(rad), math.sin(rad)        -- côté
    st.crates = {}
    st.realIndex = math.random(C.count)
    local secure = {}
    local nSecure = math.min(C.secureCount, C.count)
    if C.realSecure and nSecure > 0 then secure[st.realIndex] = true nSecure = nSecure - 1 end
    local others = {}
    for i = 1, C.count do if not secure[i] then others[#others + 1] = i end end
    for _ = 1, nSecure do if #others == 0 then break end secure[table.remove(others, math.random(#others))] = true end
    for i = 1, C.count do
        local cp = st.loc.crates[i] and st.loc.crates[i].pos
        local p = cp and { x = cp.x, y = cp.y, z = cp.z } or {
            x = vc.x - fx * 4.2 + rx * ((i - (C.count + 1) / 2) * 1.1) - fx * ((i % 2) * 0.9),
            y = vc.y - fy * 4.2 + ry * ((i - (C.count + 1) / 2) * 1.1) - fy * ((i % 2) * 0.9), z = vc.z - 0.9 }
        st.crates[i] = { pos = p, secure = secure[i] == true, unlocked = not secure[i], opened = false, attempts = 0, jammed = false, real = i == st.realIndex }
    end
    if next(secure) and not Missions.knows(run, nil, 'code') then
        -- Rappel dans le HUD : une caisse demande un code (trouvé dans un indice ou dans la cabine)
        Missions.info(run, nil, 'codeHint', 'Caisse sécurisée', 'Code requis (indice ou cabine)', 'info', { order = 6, persistent = true })
    end
end

local function cargoTaken(run, src)
    local st, cfg = run.state, run.cfg
    st.carrier = run.participants[src]
    st.cargoDropped = nil
    setStage(run, 'TRANSPORT')
    local T = cfg.transport
    if T.relayEnabled then
        local list = T.relays
        local pick = list[math.random(#list)]
        if T.relaySelect == 'fixed' and list[T.relayIndex] then pick = list[T.relayIndex]
        elseif T.relaySelect == 'closest' then
            local c = anchorOf(run, false)
            local bd
            for _, r in ipairs(list) do local d = dist2(r.pos, c) if not bd or d < bd then pick, bd = r, d end end
        end
        st.relay = pick
    end
    local D = cfg.delivery
    local dl = D.points[math.random(#D.points)]
    if D.select == 'fixed' and D.points[D.fixedIndex] then dl = D.points[D.fixedIndex]
    elseif D.select == 'closest' then
        local from = st.relay and st.relay.pos or anchorOf(run, false)
        local bd
        for _, p in ipairs(D.points) do local d = dist2(p.pos, from) if not bd or d < bd then dl, bd = p, d end end
    end
    st.delivery = dl
    Missions.dropInfo(run, 'codeHint')
    Missions.info(run, nil, 'cargo', cfg.crates.cargoLabel, ('x%d · porteur : %s'):format(cfg.crates.cargoQty, run.names[src] or '?'), 'info', { order = 5, persistent = true })
    Missions.info(run, nil, 'objective', 'Objectif', T.objective, 'objective', { order = 1, persistent = true })
    Missions.info(run, nil, 'destination', 'Destination', st.relay and ('Point relais : %s'):format(st.relay.label) or st.delivery.label, 'location', { order = 3, persistent = true })
    Log({ src = src, name = run.names[src] }, run.groupId, 'Mission : marchandise récupérée', ('%s · %s'):format(cfg.general.label, run.names[src]))
    trigger(run, 'recover', 'La marchandise a été récupérée')
    if T.pursuitAfterRecover > 0 then raise(run, T.pursuitAfterRecover, 'Poursuite') end
end

-- =========================================================
--  ACTIONS DES PARTICIPANTS (toutes vérifiées ici)
-- =========================================================
local actions = {}
local R = function(run) return run.cfg.security.interactDistance + 1.5 end

-- Indice n°i : étape de recherche, distance, durée
actions.clue = function(run, src, i, phase)
    local st = run.state
    if st.stage ~= 'SEARCH_AREA' and st.stage ~= 'FIND_CLUES' and st.stage ~= 'LOCATE_VAN' then return end
    local c = st.clues[U.int(i, 1) or 0]
    if not c or c.found then return end
    if not near(src, c.def.pos, R(run)) then return end
    if phase == 'start' then return begin(run, src, 'clue' .. i) end
    if not finished(run, src, 'clue' .. i, c.def.seconds) then return end
    c.found = true
    st.found = st.found + 1
    local text = tokens(run, c.def.text)
    Players.notify(src, ('🔎 %s : %s'):format(c.def.label, text), 'info')
    if c.def.infoLabel ~= '' then
        local value = tokens(run, c.def.infoValue)
        local key = c.def.infoCat == 'code' and 'code' or c.def.infoCat == 'password' and 'password' or ('clue' .. i)
        Missions.info(run, src, key, c.def.infoLabel, value, c.def.infoCat, { order = 10 + c.def.order, persistent = c.def.important })
        if key == 'code' then Missions.dropInfo(run, 'codeHint') end
        if run.cfg.hud.share then
            for s in pairs(run.participants) do if s ~= src then Players.notify(s, ('%s a trouvé : %s'):format(run.names[src], c.def.infoLabel), 'info') end end
        end
    end
    Log({ src = src, name = run.names[src] }, run.groupId, 'Mission : indice', ('%s · %s · %d / %d'):format(run.cfg.general.label, c.def.label, st.found, st.required))
    if not st.revealed then
        Missions.info(run, nil, 'clues', 'Indices', ('%d / %d'):format(math.min(st.found, st.required), st.required), 'clues', { order = 3, persistent = true })
        if st.found >= st.required then reveal(run) end
    end
    Missions.push(run)
end

-- Fourgon déplacé : examiner les traces à l'emplacement d'origine → nouvelle position
actions.trace = function(run, src, phase)
    local st = run.state
    if st.stage ~= 'LOCATE_VAN' or not st.traceAt or st.traced then return end
    if not near(src, st.traceAt, 8.0) then return end
    if phase == 'start' then return begin(run, src, 'trace') end
    if not finished(run, src, 'trace', run.cfg.search.traceSeconds) then return end
    st.traced = true
    spawnRealVan(run)
    st.target = { x = st.realPos.x, y = st.realPos.y, z = st.realPos.z, radius = run.cfg.search.revealRadius * 0.5, exact = false }
    Missions.info(run, nil, 'trace', 'Indice', 'Le fourgon a été déplacé : nouvelle zone sur le GPS', 'clue', { order = 4, persistent = true })
    notifyAll(run, 'Les traces mènent ailleurs : le fourgon a été déplacé. Nouvelle zone sur le GPS.', 'info')
    Missions.push(run)
end

-- Faux fourgon : l'inspecter révèle la bonne plaque et la vraie position
actions.inspectFake = function(run, src, phase)
    local st = run.state
    if st.stage ~= 'LOCATE_VAN' or not st.fake or st.fakeChecked then return end
    if not nearEnt(src, st.fake, 6.0) then return end
    if phase == 'start' then return begin(run, src, 'fake') end
    if not finished(run, src, 'fake', run.cfg.search.fakeSeconds) then return end
    st.fakeChecked = true
    spawnRealVan(run)
    st.target = { x = st.realPos.x, y = st.realPos.y, z = st.realPos.z, radius = run.cfg.search.revealRadius * 0.5, exact = false }
    Missions.info(run, nil, 'fake', 'Faux fourgon', ('Plaque %s ≠ %s'):format(GetVehicleNumberPlateText(st.fake) or '?', st.plate), 'info', { order = 4, persistent = true })
    notifyAll(run, 'Ce n\'est pas le bon fourgon ! La vraie position est sur le GPS.', 'error')
    trigger(run, 'fakeVan', 'Le faux fourgon était surveillé')
    Missions.push(run)
end

-- Cabine : le code (toujours trouvable ici) et le mot de passe du relais
actions.cabin = function(run, src, phase)
    local st = run.state
    -- Aussi pendant le transport : le mot de passe du relais reste toujours trouvable
    if st.stage ~= 'INVESTIGATE_VAN' and st.stage ~= 'RECOVER_CARGO' and st.stage ~= 'TRANSPORT' then return end
    local needPw = run.cfg.transport.requirePassword and not Missions.knows(run, src, 'password')
    if (st.cabinDone and not needPw) or not nearEnt(src, st.van, 5.0) then return end
    if phase == 'start' then return begin(run, src, 'cabin') end
    if not finished(run, src, 'cabin', run.cfg.van.cabinSeconds) then return end
    st.cabinDone = true
    if run.cfg.crates.secureCount > 0 and not Missions.knows(run, src, 'code') then
        Missions.info(run, src, 'code', 'Code caisse', st.code, 'code', { order = 7, persistent = true })
        Missions.dropInfo(run, 'codeHint')
        notifyAll(run, ('%s a trouvé un code dans la cabine.'):format(run.names[src]), 'success')
    end
    if run.cfg.transport.requirePassword and not Missions.knows(run, src, 'password') then
        Missions.info(run, src, 'password', 'Mot de passe', st.password, 'password', { order = 8, persistent = true })
    end
    Players.notify(src, 'Cabine fouillée.', 'info')
    Missions.push(run)
end

-- Arrière du fourgon : ouverture (ou forcée si verrouillé) → caisses
actions.rear = function(run, src, phase)
    local st, V = run.state, run.cfg.van
    if st.stage ~= 'INVESTIGATE_VAN' or not st.van then return end
    if not nearEnt(src, st.van, 6.5) then return end
    local forced = V.locked
    if phase == 'start' then
        begin(run, src, 'rear')
        return TriggerClientEvent('illegal:client:missionProgress', src, run.id, 'rear', forced and V.forceSeconds or V.openSeconds)
    end
    if phase == 'cancel' then st.timing[src .. ':rear'] = nil return end
    if not finished(run, src, 'rear', forced and V.forceSeconds or V.openSeconds) then return end
    makeCrates(run)
    setStage(run, 'RECOVER_CARGO')
    Entity(st.van).state:set('illegalVanOpen', true, true)
    Missions.info(run, nil, 'objective', 'Objectif', ('Trouver la vraie marchandise (%d caisses)'):format(run.cfg.crates.count), 'objective', { order = 1, persistent = true })
    alertEnemies(run, 'vanOpen')
    if forced then trigger(run, 'forced', 'Ouverture forcée du fourgon') end
    Missions.push(run)
end

-- Code d'une caisse sécurisée : vérifié par le serveur uniquement
actions.code = function(run, src, i, code)
    local st, C = run.state, run.cfg.crates
    if st.stage ~= 'RECOVER_CARGO' then return end
    local cr = st.crates[U.int(i, 1) or 0]
    if not cr or not cr.secure or cr.unlocked or cr.jammed or cr.opened then return end
    if not near(src, cr.pos, R(run)) then return end
    code = U.text(code, 12, true) or ''
    if code == st.code then
        cr.unlocked = true
        Players.notify(src, 'Code correct : la caisse est déverrouillée.', 'success')
        local any = false
        for _, c in ipairs(st.crates) do if c.secure and not c.unlocked then any = true end end
        if not any then Missions.useInfo(run, 'code') end
    else
        cr.attempts = cr.attempts + 1
        st.flags.wrongCode = true
        if cr.attempts >= C.maxAttempts then
            cr.jammed = true
            Players.notify(src, 'Code incorrect : le clavier est bloqué. Il faut forcer la caisse.', 'error')
        else
            Players.notify(src, ('Code incorrect (%d / %d essais).'):format(cr.attempts, C.maxAttempts), 'error')
        end
        trigger(run, 'wrongCode', 'Mauvais code')
    end
    Missions.push(run)
end

local function outcome(run, src, cr)
    local C = run.cfg.crates
    local total = C.outEmpty + C.outFake + C.outAlarm + C.outAmbush
    local roll = total > 0 and math.random() * total or 0
    run.state.flags.wrongCrate = true
    if roll < C.outEmpty or total == 0 then cr.outcome = 'empty' Players.notify(src, 'Caisse vide.', 'info')
    elseif roll < C.outEmpty + C.outFake then cr.outcome = 'fake' Players.notify(src, 'Faux contenu : ce n\'est pas la bonne marchandise.', 'info')
    elseif roll < C.outEmpty + C.outFake + C.outAlarm then
        cr.outcome = 'alarm'
        Players.notify(src, 'La caisse était piégée : alarme !', 'error')
        trigger(run, 'wrongCrate', 'Caisse piégée')
    else
        cr.outcome = 'ambush'
        Players.notify(src, 'Embuscade !', 'error')
        for i, w in ipairs(run.cfg.reinforcements.waves) do
            if w.level == 0 and not run.state.waves[i] then run.state.waves[i] = true spawnWave(run, w) end
        end
        trigger(run, 'wrongCrate', 'Embuscade')
    end
end

-- Ouvrir une caisse (déverrouillée) ou la forcer (sécurisée) : 'start' → durée → 'done'
actions.crate = function(run, src, i, phase)
    local st, C = run.state, run.cfg.crates
    if st.stage ~= 'RECOVER_CARGO' then return end
    local idx = U.int(i, 1) or 0
    local cr = st.crates[idx]
    if not cr or cr.opened or not near(src, cr.pos, R(run)) then return end
    local force = cr.secure and not cr.unlocked
    local secs = force and C.forceSeconds or C.openSeconds
    if phase == 'start' then
        begin(run, src, 'crate' .. idx)
        return TriggerClientEvent('illegal:client:missionProgress', src, run.id, force and 'force' or 'crate', secs, idx)
    end
    if phase == 'cancel' then st.timing[src .. ':crate' .. idx] = nil return end
    if not finished(run, src, 'crate' .. idx, secs) then return end
    cr.opened = true
    alertEnemies(run, 'crate')
    if force then trigger(run, 'forced', 'Caisse forcée') end
    if cr.real then
        Missions.info(run, nil, 'crate', 'Caisse n°', ('%d : %s'):format(idx, run.cfg.crates.cargoLabel), 'info', { order = 6, persistent = true })
        notifyAll(run, ('La vraie marchandise est dans la caisse n°%d !'):format(idx), 'success')
    else
        outcome(run, src, cr)
    end
    Missions.push(run)
end

-- Récupérer la marchandise (vraie caisse ouverte)
actions.recover = function(run, src, phase)
    local st, C = run.state, run.cfg.crates
    if st.stage ~= 'RECOVER_CARGO' then return end
    local cr = st.crates[st.realIndex]
    if not cr.opened or not near(src, cr.pos, R(run)) then return end
    if phase == 'start' then return begin(run, src, 'recover') end
    if not finished(run, src, 'recover', C.recoverSeconds) then return end
    cargoTaken(run, src)
    Missions.push(run)
end

-- Ramasser la marchandise tombée (porteur mort ou parti)
actions.pickup = function(run, src, phase)
    local st = run.state
    if not st.cargoDropped or not near(src, st.cargoDropped, R(run) + 1.0) then return end
    if phase == 'start' then return begin(run, src, 'pickup') end
    if not finished(run, src, 'pickup', 2) then return end
    st.carrier, st.cargoDropped = run.participants[src], nil
    Missions.info(run, nil, 'cargo', run.cfg.crates.cargoLabel, ('x%d · porteur : %s'):format(run.cfg.crates.cargoQty, run.names[src] or '?'), 'info', { order = 5, persistent = true })
    notifyAll(run, ('%s a récupéré la marchandise.'):format(run.names[src]), 'success')
    Missions.push(run)
end

-- Point relais : transfert (nouveau véhicule) puis livraison finale
actions.relay = function(run, src, phase)
    local st, T = run.state, run.cfg.transport
    if st.stage ~= 'TRANSPORT' or not st.relay or st.carrier ~= run.participants[src] then return end
    if not near(src, st.relay.pos, st.relay.radius + 2.0) then return end
    if T.requirePassword and not Missions.knows(run, src, 'password') then
        return Players.notify(src, 'Le contact attend le mot de passe : fouillez la cabine du fourgon ou les indices.', 'error')
    end
    if phase == 'start' then return begin(run, src, 'relay') end
    if not finished(run, src, 'relay', st.relay.seconds) then return end
    setStage(run, 'FINAL_DELIVERY')
    if T.transferEnabled then
        st.transfer = spawnVehicle(run, T.transferModel, st.relay.vehiclePos, ('ILL%03d'):format(math.random(0, 999)))
        if st.transfer then
            SetVehicleDoorsLocked(st.transfer, 1)
            if GetResourceState('qbx_vehiclekeys') == 'started' then
                for s in pairs(run.participants) do pcall(function() exports.qbx_vehiclekeys:GiveKeys(s, st.transfer) end) end
            end
        end
    end
    Missions.useInfo(run, 'password')
    Missions.info(run, nil, 'objective', 'Objectif', run.cfg.delivery.objective, 'objective', { order = 1, persistent = true })
    Missions.info(run, nil, 'destination', 'Destination', st.delivery.label, 'location', { order = 3, persistent = true })
    if st.transfer then Missions.info(run, nil, 'vehicle', 'Véhicule', ('Transfert : %s'):format(GetVehicleNumberPlateText(st.transfer) or ''), 'plate', { order = 4, persistent = true }) end
    Log({ src = src, name = run.names[src] }, run.groupId, 'Mission : relais', ('%s · %s'):format(run.cfg.general.label, st.relay.label))
    if T.pursuitAfterRelay > 0 then raise(run, T.pursuitAfterRelay, 'Poursuite') end
    Missions.push(run)
end

-- Livraison finale au commanditaire → mission réussie (récompenses : moteur commun)
actions.deliver = function(run, src, phase)
    local st = run.state
    local final = st.stage == 'FINAL_DELIVERY' or (st.stage == 'TRANSPORT' and not run.cfg.transport.relayEnabled)
    if not final or st.carrier ~= run.participants[src] then return end
    local d = st.delivery
    if not near(src, d.pos, d.distance + 2.0) then return end
    if run.cfg.transport.requireTransferVehicle and st.transfer then
        if not DoesEntityExist(st.transfer) or #(GetEntityCoords(st.transfer) - v3(d.pos)) > 40.0 then
            return Players.notify(src, 'Amène la marchandise avec le véhicule de transfert.', 'error')
        end
    end
    if phase == 'start' then return begin(run, src, 'deliver') end
    if not finished(run, src, 'deliver', run.cfg.delivery.seconds) then return end
    Log({ src = src, name = run.names[src] }, run.groupId, 'Mission : marchandise livrée', ('%s · %s'):format(run.cfg.general.label, run.names[src]))
    Missions.complete(run, src)
end

actions.vehicle = function(run, src) Missions.violation(run, src, 'vehicles') end

-- =========================================================
--  BOUCLE SERVEUR (1 s, seulement pendant la mission)
-- =========================================================
local function tick(run)
    local st, cfg = run.state, run.cfg
    local changed = false
    if st.revealNow and not st.revealed then reveal(run) changed = true end
    -- Zone de recherche atteinte
    if st.stage == 'SEARCH_AREA' then
        for s in pairs(run.participants) do
            local c = ppos(s)
            if c and dist2(c, st.area) <= st.area.radius then
                setStage(run, 'FIND_CLUES')
                Missions.info(run, nil, 'objective', 'Objectif', ('Trouver des indices (%d nécessaires)'):format(st.required), 'objective', { order = 1, persistent = true })
                changed = true
                break
            end
        end
    end
    -- Fourgon atteint
    if st.stage == 'LOCATE_VAN' and st.van and DoesEntityExist(st.van) then
        local vc = GetEntityCoords(st.van)
        for s in pairs(run.participants) do
            local c = ppos(s)
            if c and #(c - vc) <= cfg.search.approachDistance then arrived(run) changed = true break end
        end
    end
    -- Morts : bonus « aucun mort », marchandise lâchée par le porteur
    for s, cid in pairs(run.participants) do
        local ped = GetPlayerPed(s)
        if ped and ped ~= 0 and GetEntityHealth(ped) <= 0 then
            if not st.deadNow or not st.deadNow[s] then
                st.deadNow = st.deadNow or {}
                st.deadNow[s] = true
                st.flags.died = true
                if st.carrier == cid then
                    local c = GetEntityCoords(ped)
                    st.carrier, st.cargoDropped, st.flags.loss = nil, { x = c.x, y = c.y, z = c.z }, true
                    Missions.info(run, nil, 'cargo', cfg.crates.cargoLabel, 'Tombée au sol : à ramasser !', 'info', { order = 5, persistent = true })
                    notifyAll(run, ('%s est à terre : la marchandise est tombée !'):format(run.names[s]), 'error')
                end
                changed = true
            end
        elseif st.deadNow then st.deadNow[s] = nil end
    end
    -- Renforts programmés
    local now = os.time()
    for i = #st.pending, 1, -1 do
        if now >= st.pending[i].at then
            local p = table.remove(st.pending, i)
            spawnWave(run, p.wave)
            changed = true
        end
    end
    if changed then Missions.push(run) end
end

-- Dégâts sur un ennemi par un participant : détection
local function onDamage(run, src)
    if not run.state.detected then
        run.state.detected = true
        alertEnemies(run, 'alarm')
        trigger(run, 'detection', 'Vous êtes repérés')
    end
end

local function onLeave(run, src, cid)
    local st = run.state
    if st.carrier and st.carrier == cid then
        local c = ppos(src) or anchorOf(run, false)
        st.carrier, st.cargoDropped, st.flags.loss = nil, { x = c.x, y = c.y, z = c.z }, true
        Missions.info(run, nil, 'cargo', run.cfg.crates.cargoLabel, 'Tombée au sol : à ramasser !', 'info', { order = 5, persistent = true })
    end
end

local function cleanup(run)
    local st = run.state or {}
    for _, e in ipairs(st.enemies or {}) do if DoesEntityExist(e) then DeleteEntity(e) end end
    for _, v in ipairs(st.vehicles or {}) do if DoesEntityExist(v) then DeleteEntity(v) end end
    st.enemies, st.vehicles, st.pending = {}, {}, {}
    run.entities = {}
end

-- Bonus (calculés par le serveur à la livraison)
local function bonus(run)
    local st, Bc = run.state, run.cfg.bonus
    local out = { money = 0, xp = 0, items = {}, labels = {} }
    local function add(key, ok, label)
        local b = Bc[key]
        if not b or not b.enabled or not ok then return end
        out.money, out.xp = out.money + b.money, out.xp + b.xp
        if b.item ~= '' then out.items[#out.items + 1] = { item = b.item, min = b.itemCount, max = b.itemCount, chance = 100 } end
        out.labels[#out.labels + 1] = label
    end
    add('timeLeft', run.deadline - os.time() >= Bc.timeLeftMinutes * 60, 'temps restant')
    add('noAlarm', not st.alarm, 'aucune alarme')
    add('noWrongCrate', not st.flags.wrongCrate, 'aucune mauvaise caisse')
    add('noDeath', not st.flags.died, 'aucun mort')
    add('noPolice', not st.police, 'aucune alerte police')
    add('noLoss', not st.flags.loss, 'livraison sans perte')
    return out
end

-- =========================================================
--  DONNÉES ENVOYÉES AUX PARTICIPANTS (uniquement ce qui est utile)
-- =========================================================
local function payload(run, src, base)
    local st, cfg = run.state, run.cfg
    local cid = run.participants[src]
    base.stage, base.stageLabel = st.stage, run.stageLabel
    base.objective = run.stageLabel
    base.area = st.area
    base.seconds = { clue = 4, trace = cfg.search.traceSeconds, fake = cfg.search.fakeSeconds, cabin = cfg.van.cabinSeconds,
        recover = cfg.crates.recoverSeconds, open = cfg.crates.openSeconds, force = cfg.crates.forceSeconds }
    base.anim = { dict = cfg.crates.animDict, name = cfg.crates.animName }
    if not st.revealed or st.stage == 'LOCATE_VAN' or st.stage == 'FIND_CLUES' or st.stage == 'SEARCH_AREA' then
        base.clues = {}
        for i, c in ipairs(st.clues) do
            if not c.found then
                local d = c.def
                base.clues[#base.clues + 1] = { i = i, x = d.pos.x, y = d.pos.y, z = d.pos.z, h = d.pos.h, model = d.model, label = d.label,
                    seconds = d.seconds, animDict = d.animDict, animName = d.animName }
            end
        end
    end
    base.target = st.target
    if st.traceAt and not st.traced then base.trace = st.traceAt end
    if st.fake and not st.fakeChecked and DoesEntityExist(st.fake) then base.fake = NetworkGetNetworkIdFromEntity(st.fake) end
    if st.van and DoesEntityExist(st.van) then base.van = NetworkGetNetworkIdFromEntity(st.van) end
    -- Cabine encore utile tant que le mot de passe du relais manque à ce joueur
    base.cabinDone = st.cabinDone and not (cfg.transport.requirePassword and not Missions.knows(run, src, 'password'))
    base.locked = cfg.van.locked
    if st.crates then
        base.crates = {}
        for i, c in ipairs(st.crates) do
            base.crates[i] = { i = i, x = c.pos.x, y = c.pos.y, z = c.pos.z, secure = c.secure, unlocked = c.unlocked, opened = c.opened, jammed = c.jammed,
                real = c.opened and c.real or nil, outcome = c.outcome }
        end
        base.crateModel = cfg.crates.model
        base.recoverText = cfg.crates.recoverText
        base.codeKnown = Missions.knows(run, src, 'code')
    end
    base.carrier = st.carrier ~= nil and st.carrier == cid
    for s, c in pairs(run.participants) do if c == st.carrier then base.carrierName = run.names[s] end end
    base.dropped = st.cargoDropped
    if (st.stage == 'TRANSPORT') and st.relay then
        local r = st.relay
        base.relay = { x = r.pos.x, y = r.pos.y, z = r.pos.z, h = r.pos.h, type = r.type, ped = r.ped, scenario = r.scenario, radius = r.radius,
            text = r.text, label = r.label, seconds = r.seconds }
    end
    if st.stage == 'FINAL_DELIVERY' or (st.stage == 'TRANSPORT' and not st.relay and st.delivery) then
        local d = st.delivery
        base.delivery = { x = d.pos.x, y = d.pos.y, z = d.pos.z, h = d.pos.h, ped = d.ped, scenario = d.scenario, animDict = d.animDict, animName = d.animName,
            text = d.text, label = d.label, distance = d.distance, blipSprite = d.blipSprite, blipColor = d.blipColor, seconds = cfg.delivery.seconds }
    end
    if st.transfer and DoesEntityExist(st.transfer) then base.transfer = NetworkGetNetworkIdFromEntity(st.transfer) end
end

Missions.registerType('fourgon', {
    label = 'Fourgon (niveau 1)',
    schema = SCHEMA,
    sections = SECTIONS,
    defaults = function() return defaults() end,
    sanitize = sanitize,
    start = start,
    actions = actions,
    onLeave = onLeave,
    onDamage = onDamage,
    tick = tick,
    cleanup = cleanup,
    payload = payload,
    bonus = bonus,
})
Missions.registerDefault('fourgon_fantome', 'fourgon')
