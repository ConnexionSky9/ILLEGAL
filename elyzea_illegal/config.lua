-- =========================================================
--  ELYZEA ILLÉGAL - CONFIGURATION
--  Tout le reste (groupes, grades, membres, PNJ, commandes…)
--  se gère en jeu : admin_menu › ILLEGAL (permission « illegal_staff »)
--  et la tablette du groupe (F5).
-- =========================================================
Config = {}

-- Ressource du menu staff (logs, permission « illegal_staff »)
Config.AdminResource = 'admin_menu'
Config.AdminPermission = 'illegal_staff'

-- Logs Discord propres au module (en plus des logs du menu staff). Laisser vide pour désactiver.
Config.DiscordWebhook = ''

-- ---------------------------------------------------------
--  Argent du joueur utilisé pour les dépôts / retraits
-- ---------------------------------------------------------
-- Argent propre : compte Qbox (« cash » = liquide, « bank » = banque)
Config.CleanMoney = { account = 'cash' }

-- Argent sale :
--   type = 'item'    → objet d'inventaire ox_inventory (ex. black_money, markedbills)
--   type = 'account' → compte Qbox (ex. 'black_money' si ton qbx_core en a un)
Config.DirtyMoney = { type = 'item', item = 'black_money', account = 'black_money' }

-- Montant maximum d'une opération (dépôt, retrait, ajout staff, prix d'une commande)
Config.MaxAmount = 100000000

-- ---------------------------------------------------------
--  F5 : tablette du groupe
-- ---------------------------------------------------------
Config.F5 = {
    enabled = true,          -- false si tu ouvres la tablette depuis ton propre menu F5 (export OpenTablet)
    key = 'F5',              -- modifiable par chaque joueur : Échap › Paramètres › Assignation des touches › FiveM
    mode = 'context',        -- 'context' : petit menu « F5 › <Nom du groupe> » ; 'direct' : ouvre directement la tablette
}

-- ---------------------------------------------------------
--  PNJ des groupes
-- ---------------------------------------------------------
Config.Ped = {
    defaultModel = 'g_m_y_ballaeast_01',
    spawnDistance = 60.0,    -- le PNJ n'existe chez le joueur qu'à cette distance (performances)
    interactDistance = 2.0,  -- distance pour l'invite [E]
    serverDistance = 4.0,    -- distance vérifiée par le serveur à l'ouverture (anti-triche)
    key = 38,                -- E
    scenario = 'WORLD_HUMAN_SMOKING',  -- animation par défaut ('' = aucune)
}

-- ---------------------------------------------------------
--  Commandes illégales
--  Le catalogue (objet + prix) se règle dans admin_menu › ILLEGAL ›
--  groupe › Commandes (ou « pour tous les groupes » sur la liste).
-- ---------------------------------------------------------
Config.OrderMaxQuantity = 50
Config.OrderMaxPending = 10          -- commandes en cours maximum par groupe
Config.Orders = {
    requireValidation = false,       -- true : un grade « Valider les commandes » doit valider avant la livraison
    playerCanCreate = false,         -- true : les grades « Créer / configurer les commandes » gèrent aussi le catalogue
}

-- ---------------------------------------------------------
--  Livraison des commandes
--  Commande passée → payée par le coffre du groupe → préparation →
--  point GPS → un chef (bras croisés) et ses gardes armés attendent
--  dans un coin caché, le sac posé devant le chef. Sac ramassé = livré,
--  les PNJ disparaissent.
-- ---------------------------------------------------------
Config.Delivery = {
    prepareMinutes = 5,              -- délai avant que la commande soit prête
    minDistance = 1500.0,            -- distance minimum entre le joueur (au moment de la commande) et le lieu de livraison
    maxActivePerPlayer = 1,          -- livraisons en cours par joueur
    spawnDistance = 150.0,           -- les PNJ apparaissent quand le joueur est à cette distance
    pickupDistance = 2.0,            -- distance pour ramasser le sac [E]
    bossModel = 'g_m_m_chicold_01',
    guardModels = { 'g_m_y_mexgoon_02', 'g_m_y_mexgoon_03', 'g_m_m_mexboss_01', 'g_m_y_ballasout_01', 'g_m_y_lost_02' },
    guardWeapons = { 'WEAPON_CARBINERIFLE', 'WEAPON_SMG', 'WEAPON_ASSAULTRIFLE', 'WEAPON_PUMPSHOTGUN' },
    guardCount = 5,                  -- gardes armés (+ le chef = 6 PNJ)
    guardScenario = 'WORLD_HUMAN_GUARD_STAND',
    bossAnim = { dict = 'amb@world_human_hang_out_street@female_arms_crossed@base', name = 'base' },   -- bras croisés
    bagModel = 'prop_cs_heist_bag_02',
    blip = { sprite = 501, color = 1, scale = 0.9, label = 'Commande illégale' },

    -- Lieux cachés utilisés tant qu'aucun point n'est placé dans admin_menu › ILLEGAL › Points de livraison.
    -- Le sol (z) est recalculé en jeu ; ajuste ou remplace ces points depuis le menu.
    defaultSpots = {
        { label = 'Port - conteneurs',          x = 1015.0,  y = -3105.0, z = 5.9,   h = 90.0 },
        { label = 'Champs pétrolifères',         x = 1505.0,  y = -2120.0, z = 77.0,  h = 0.0 },
        { label = 'Lit de la rivière (LS)',      x = 640.0,   y = -1260.0, z = 10.5,  h = 180.0 },
        { label = 'Casse de Joshua Road',        x = 2350.0,  y = 3050.0,  z = 48.2,  h = 270.0 },
        { label = 'Carrière Davis Quartz',       x = 2955.0,  y = 2785.0,  z = 41.5,  h = 300.0 },
        { label = 'Stab City',                   x = 75.0,    y = 3705.0,  z = 39.7,  h = 45.0 },
        { label = 'Ferme O\'Neil (Grapeseed)',   x = 2445.0,  y = 4975.0,  z = 46.8,  h = 225.0 },
        { label = 'Scierie de Paleto',           x = -575.0,  y = 5325.0,  z = 70.2,  h = 160.0 },
        { label = 'Quais de Galilee',            x = 1305.0,  y = 4325.0,  z = 38.2,  h = 80.0 },
        { label = 'Raton Canyon',                x = -1520.0, y = 4415.0,  z = 11.5,  h = 300.0 },
    },
}

-- ---------------------------------------------------------
--  Coffre du groupe (placé dans admin_menu › ILLEGAL › groupe › Coffre)
--  Accès : permission « Accès au coffre du groupe » des grades (le OG la donne).
-- ---------------------------------------------------------
Config.Stash = {
    models = {
        { model = 'prop_ld_int_safe_01',     label = 'Coffre-fort' },
        { model = 'p_v_43_safe_s',           label = 'Petit coffre-fort' },
        { model = 'prop_mil_crate_01',       label = 'Caisse militaire' },
        { model = 'prop_box_wood02a',        label = 'Caisse en bois' },
        { model = 'xm_prop_x17_chest_closed', label = 'Coffre de pirate' },
        { model = 'prop_toolchest_05',       label = 'Servante à outils' },
        { model = 'prop_rub_cabinet01',      label = 'Armoire métallique' },
    },
    defaultWeight = 500,     -- kg
    defaultSlots = 50,
    maxWeight = 100000,      -- kg
    maxSlots = 500,
    interactDistance = 2.0,  -- invite [E]
    spawnDistance = 50.0,    -- l'objet n'existe chez le joueur qu'à cette distance
}

-- ---------------------------------------------------------
--  Missions illégales (admin_menu › ILLEGAL › Missions)
--  Tout se règle en jeu ; ici seulement les valeurs de départ,
--  utilisées à la première installation.
-- ---------------------------------------------------------
Config.Missions = {
    -- Niveaux des groupes : « xp » = XP à gagner pour atteindre ce niveau depuis le précédent
    levels = {
        { label = 'Inconnus',       xp = 0 },
        { label = 'Petites frappes', xp = 100 },
        { label = 'Réseau',         xp = 250 },
        { label = 'Organisés',      xp = 500 },
        { label = 'Redoutés',       xp = 1000 },
        { label = 'Intouchables',   xp = 2000 },
    },
    levelUpMessage = 'Ton groupe passe niveau {level} ({label}).',
    behaviors = {
        { key = 'passive',         label = 'Passif (n\'attaque jamais)' },
        { key = 'wary',            label = 'Méfiant (agressif si on s\'approche)' },
        { key = 'aggressive',      label = 'Agressif (attaque, ne poursuit pas)' },
        { key = 'very_aggressive', label = 'Très agressif (attaque et poursuit)' },
    },
    weaponActions = {
        { key = 'none', label = 'Rien' }, { key = 'warn', label = 'Avertissement' }, { key = 'fail', label = 'Échec de la mission' },
    },
    -- Mission « Colis test » : emplacements et points de livraison de départ (coordonnées approximatives :
    -- remplace-les en jeu, admin_menu › ILLEGAL › Missions › Colis test › Emplacements / Livraison)
    colisDefaults = {
        locations = {
            { label = 'Entrepôt du port',     x = 1015.0, y = -3105.0, z = 5.9,  h = 90.0,  radius = 30.0, enabled = true, guards = {} },
            { label = 'Casse de Joshua Road', x = 2350.0, y = 3050.0,  z = 48.2, h = 270.0, radius = 30.0, enabled = true, guards = {} },
            { label = 'Lit de la rivière',    x = 640.0,  y = -1260.0, z = 10.5, h = 180.0, radius = 30.0, enabled = true, guards = {} },
        },
        deliveries = {
            { label = 'Ruelle de Strawberry', x = 166.0, y = -1307.0, z = 29.3, h = 240.0, enabled = true, ped = 'g_m_m_armboss_01',
              scenario = 'WORLD_HUMAN_SMOKING', animDict = 'mp_common', animName = 'givetake1_a', blipSprite = 478, blipColor = 5,
              distance = 2.0, text = 'Livrer le colis' },
            { label = 'Parking de Sandy Shores', x = 1961.0, y = 3740.0, z = 32.3, h = 300.0, enabled = true, ped = 'g_m_m_armboss_01',
              scenario = 'WORLD_HUMAN_SMOKING', animDict = 'mp_common', animName = 'givetake1_a', blipSprite = 478, blipColor = 5,
              distance = 2.0, text = 'Livrer le colis' },
        },
    },
}

-- Notification « téléphone » : lb-phone est détecté automatiquement, sinon notification ox_lib.
-- Pour un autre téléphone, remplace cette fonction (côté client) :
--   Config.PhoneNotify = function(title, message) exports['mon-phone']:Notify(title, message) end
Config.PhoneNotify = nil

-- ---------------------------------------------------------
--  Types de groupes
-- ---------------------------------------------------------
Config.Types = {
    { key = 'gang',         label = 'Gang',         color = '#e0433b', examples = 'Families, Ballas, Vagos' },
    { key = 'organisation', label = 'Organisation', color = '#d9b56a', examples = 'Mafia, organisation clandestine' },
    { key = 'cartel',       label = 'Cartel',       color = '#4fb3a9', examples = 'Cartel, réseau de trafic international' },
}

-- Catégories des commandes
Config.OrderCategories = {
    { key = 'weapons',   label = 'Armes',     ico = '🔫' },
    { key = 'drugs',     label = 'Drogues',   ico = '💊' },
    { key = 'vehicles',  label = 'Véhicules', ico = '🚗' },
    { key = 'equipment', label = 'Matériel',  ico = '🧰' },
    { key = 'other',     label = 'Autres',    ico = '📦' },
}

-- ---------------------------------------------------------
--  Grades créés automatiquement avec un nouveau groupe (modifiables ensuite)
--  boss = true : toutes les permissions, toujours (le « OG » / chef)
-- ---------------------------------------------------------
Config.Templates = {
    gang = {
        { name = 'recrue',     label = 'Recrue',     level = 10,  perms = { 'orders_place' } },
        { name = 'membre',     label = 'Membre',     level = 20,  perms = { 'orders_place', 'clean_deposit', 'dirty_deposit' } },
        { name = 'soldat',     label = 'Soldat',     level = 30,  perms = { 'orders_place', 'clean_deposit', 'dirty_deposit', 'finance_view' } },
        { name = 'lieutenant', label = 'Lieutenant', level = 50,  perms = { 'stash', 'orders_place', 'orders_manage', 'orders_validate', 'recruit', 'promote', 'set_grade',
                                                                             'finance_view', 'clean_deposit', 'clean_withdraw', 'dirty_deposit', 'dirty_withdraw' } },
        { name = 'brasdroit',  label = 'Bras droit', level = 80,  perms = { 'stash', 'orders_place', 'orders_manage', 'orders_validate', 'recruit', 'kick', 'promote', 'demote', 'set_grade',
                                                                             'finance_view', 'clean_deposit', 'clean_withdraw', 'dirty_deposit', 'dirty_withdraw' } },
        { name = 'og',         label = 'OG',         level = 100, boss = true },
    },
    organisation = {
        { name = 'associe',    label = 'Associé',    level = 10,  perms = { 'orders_place' } },
        { name = 'soldat',     label = 'Soldat',     level = 30,  perms = { 'orders_place', 'clean_deposit', 'dirty_deposit' } },
        { name = 'capo',       label = 'Capo',       level = 60,  perms = { 'stash', 'orders_place', 'orders_manage', 'orders_validate', 'recruit', 'promote', 'set_grade',
                                                                             'finance_view', 'clean_deposit', 'clean_withdraw', 'dirty_deposit', 'dirty_withdraw' } },
        { name = 'consigliere', label = 'Consigliere', level = 80, perms = { 'stash', 'orders_place', 'orders_manage', 'orders_validate', 'recruit', 'kick', 'promote', 'demote', 'set_grade',
                                                                             'manage_grades', 'finance_view', 'clean_deposit', 'clean_withdraw', 'dirty_deposit', 'dirty_withdraw' } },
        { name = 'parrain',    label = 'Parrain',    level = 100, boss = true },
    },
    cartel = {
        { name = 'novice',     label = 'Novice',     level = 10,  perms = { 'orders_place' } },
        { name = 'sicario',    label = 'Sicario',    level = 40,  perms = { 'orders_place', 'clean_deposit', 'dirty_deposit', 'finance_view' } },
        { name = 'capitaine',  label = 'Capitaine',  level = 70,  perms = { 'stash', 'orders_place', 'orders_manage', 'orders_validate', 'recruit', 'kick', 'promote', 'demote', 'set_grade',
                                                                             'finance_view', 'clean_deposit', 'clean_withdraw', 'dirty_deposit', 'dirty_withdraw' } },
        { name = 'patron',     label = 'Patron',     level = 100, boss = true },
    },
}
