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
-- ---------------------------------------------------------
Config.OrderMaxQuantity = 50
Config.OrderMaxPending = 10          -- commandes en attente maximum par groupe

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
        { name = 'lieutenant', label = 'Lieutenant', level = 50,  perms = { 'orders_place', 'orders_manage', 'orders_validate', 'recruit', 'promote', 'set_grade',
                                                                             'finance_view', 'clean_deposit', 'clean_withdraw', 'dirty_deposit', 'dirty_withdraw' } },
        { name = 'brasdroit',  label = 'Bras droit', level = 80,  perms = { 'orders_place', 'orders_manage', 'orders_validate', 'recruit', 'kick', 'promote', 'demote', 'set_grade',
                                                                             'finance_view', 'clean_deposit', 'clean_withdraw', 'dirty_deposit', 'dirty_withdraw' } },
        { name = 'og',         label = 'OG',         level = 100, boss = true },
    },
    organisation = {
        { name = 'associe',    label = 'Associé',    level = 10,  perms = { 'orders_place' } },
        { name = 'soldat',     label = 'Soldat',     level = 30,  perms = { 'orders_place', 'clean_deposit', 'dirty_deposit' } },
        { name = 'capo',       label = 'Capo',       level = 60,  perms = { 'orders_place', 'orders_manage', 'orders_validate', 'recruit', 'promote', 'set_grade',
                                                                             'finance_view', 'clean_deposit', 'clean_withdraw', 'dirty_deposit', 'dirty_withdraw' } },
        { name = 'consigliere', label = 'Consigliere', level = 80, perms = { 'orders_place', 'orders_manage', 'orders_validate', 'recruit', 'kick', 'promote', 'demote', 'set_grade',
                                                                             'manage_grades', 'finance_view', 'clean_deposit', 'clean_withdraw', 'dirty_deposit', 'dirty_withdraw' } },
        { name = 'parrain',    label = 'Parrain',    level = 100, boss = true },
    },
    cartel = {
        { name = 'novice',     label = 'Novice',     level = 10,  perms = { 'orders_place' } },
        { name = 'sicario',    label = 'Sicario',    level = 40,  perms = { 'orders_place', 'clean_deposit', 'dirty_deposit', 'finance_view' } },
        { name = 'capitaine',  label = 'Capitaine',  level = 70,  perms = { 'orders_place', 'orders_manage', 'orders_validate', 'recruit', 'kick', 'promote', 'demote', 'set_grade',
                                                                             'finance_view', 'clean_deposit', 'clean_withdraw', 'dirty_deposit', 'dirty_withdraw' } },
        { name = 'patron',     label = 'Patron',     level = 100, boss = true },
    },
}
