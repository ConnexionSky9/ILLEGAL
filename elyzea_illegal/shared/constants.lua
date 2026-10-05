-- =========================================================
--  ELYZEA ILLÉGAL - CONSTANTES PARTAGÉES (client + serveur)
-- =========================================================
Illegal = Illegal or {}

-- ---------------------------------------------------------
--  Réglages ajoutés au fil des versions : si ton config.lua est
--  plus ancien, les valeurs manquantes sont complétées ici.
-- ---------------------------------------------------------
local function fill(dst, src)
    for k, v in pairs(src) do
        if dst[k] == nil then dst[k] = v
        elseif type(v) == 'table' and type(dst[k]) == 'table' and v[1] == nil then fill(dst[k], v) end
    end
    return dst
end
Config = Config or {}
fill(Config, {
    Orders = { requireValidation = false, playerCanCreate = false },
    Delivery = {
        prepareMinutes = 5, minDistance = 1500.0, maxActivePerPlayer = 1, spawnDistance = 150.0, pickupDistance = 2.0,
        bossModel = 'g_m_m_chicold_01', guardModels = { 'g_m_y_mexgoon_02', 'g_m_y_mexgoon_03', 'g_m_m_mexboss_01' },
        guardWeapons = { 'WEAPON_CARBINERIFLE', 'WEAPON_SMG' }, guardCount = 5, guardScenario = 'WORLD_HUMAN_GUARD_STAND',
        bossAnim = { dict = 'amb@world_human_hang_out_street@female_arms_crossed@base', name = 'base' },
        bagModel = 'prop_cs_heist_bag_02', blip = { sprite = 501, color = 1, scale = 0.9, label = 'Commande illégale' },
        defaultSpots = {
            { label = 'Port - conteneurs', x = 1015.0, y = -3105.0, z = 5.9, h = 90.0 },
            { label = 'Casse de Joshua Road', x = 2350.0, y = 3050.0, z = 48.2, h = 270.0 },
            { label = 'Scierie de Paleto', x = -575.0, y = 5325.0, z = 70.2, h = 160.0 },
        },
    },
    Missions = {
        levels = { { label = 'Niveau 0', xp = 0 }, { label = 'Niveau 1', xp = 100 }, { label = 'Niveau 2', xp = 250 },
            { label = 'Niveau 3', xp = 500 }, { label = 'Niveau 4', xp = 1000 }, { label = 'Niveau 5', xp = 2000 } },
        levelUpMessage = 'Ton groupe passe niveau {level} ({label}).',
        policeJobs = { 'police', 'sheriff', 'lspd', 'bcso', 'sasp' }, policeResource = 'elyzea_police',
        behaviors = { { key = 'passive', label = 'Passif' }, { key = 'wary', label = 'Méfiant' }, { key = 'aggressive', label = 'Agressif' },
            { key = 'very_aggressive', label = 'Très agressif' } },
        weaponActions = { { key = 'none', label = 'Rien' }, { key = 'warn', label = 'Avertissement' }, { key = 'fail', label = 'Échec' } },
        colisDefaults = { locations = {}, deliveries = {} },
    },
    Stash = {
        models = {
            { model = 'prop_ld_int_safe_01', label = 'Coffre-fort' }, { model = 'p_v_43_safe_s', label = 'Petit coffre-fort' },
            { model = 'prop_mil_crate_01', label = 'Caisse militaire' }, { model = 'prop_box_wood02a', label = 'Caisse en bois' },
        },
        defaultWeight = 500, defaultSlots = 50, maxWeight = 100000, maxSlots = 500, interactDistance = 2.0, spawnDistance = 50.0,
    },
})

-- Permissions des grades (cochées grade par grade, dans la tablette ou le menu staff).
-- Un grade « chef » (boss) les a toutes, toujours.
Illegal.Permissions = {
    { key = 'recruit',         label = 'Recrutement',                      cat = 'Gestion membres' },
    { key = 'kick',            label = 'Exclusion',                        cat = 'Gestion membres' },
    { key = 'promote',         label = 'Promotion',                        cat = 'Gestion membres' },
    { key = 'demote',          label = 'Rétrogradation',                   cat = 'Gestion membres' },
    { key = 'set_grade',       label = 'Changer le grade d\'un membre',    cat = 'Gestion membres' },
    { key = 'manage_grades',   label = 'Gestion des grades',               cat = 'Gestion grades' },
    { key = 'finance_view',    label = 'Voir les soldes et l\'historique', cat = 'Finances' },
    { key = 'clean_deposit',   label = 'Argent propre : déposer',          cat = 'Finances' },
    { key = 'clean_withdraw',  label = 'Argent propre : retirer',          cat = 'Finances' },
    { key = 'dirty_deposit',   label = 'Argent sale : déposer',            cat = 'Finances' },
    { key = 'dirty_withdraw',  label = 'Argent sale : retirer',            cat = 'Finances' },
    { key = 'orders_place',    label = 'Passer une commande',              cat = 'Commandes' },
    { key = 'orders_manage',   label = 'Créer / configurer les commandes', cat = 'Commandes' },
    { key = 'orders_validate', label = 'Valider / refuser les commandes',  cat = 'Commandes' },
    { key = 'stash',           label = 'Accès au coffre du groupe',        cat = 'Coffre' },
    { key = 'missions_start',  label = 'Lancer une mission illégale',      cat = 'Missions' },
    { key = 'settings',        label = 'Paramètres du groupe',             cat = 'Configuration' },
}

Illegal.PermSet = {}
for _, p in ipairs(Illegal.Permissions) do Illegal.PermSet[p.key] = true end

-- Onglets de la tablette du groupe (F5 et PNJ). « home » est toujours accessible.
Illegal.Tabs = {
    { key = 'home',     label = 'Informations' },
    { key = 'members',  label = 'Membres' },
    { key = 'grades',   label = 'Grades' },
    { key = 'finances', label = 'Finances' },
    { key = 'orders',   label = 'Commandes' },
    { key = 'missions', label = 'Missions' },
    { key = 'settings', label = 'Paramètres' },
}
-- Onglets ajoutés après coup : actifs par défaut pour les groupes et PNJ déjà configurés
Illegal.NewTabs = { missions = true }
Illegal.TabSet = {}
for _, t in ipairs(Illegal.Tabs) do Illegal.TabSet[t.key] = true end

-- Onglet nécessaire pour chaque action de la tablette (vérifié par le serveur)
Illegal.ActionTab = {
    recruit = 'members', kick = 'members', promote = 'members', demote = 'members', setGrade = 'members',
    createGrade = 'grades', updateGrade = 'grades', deleteGrade = 'grades', moveGrade = 'grades',
    deposit = 'finances', withdraw = 'finances',
    placeOrder = 'orders', createOrder = 'orders', updateOrder = 'orders', deleteOrder = 'orders',
    validateRequest = 'orders', refuseRequest = 'orders', cancelRequest = 'orders',
    saveSettings = 'settings',
    startMission = 'missions', joinMission = 'missions', abandonMission = 'missions',
}

Illegal.Accounts = { clean = 'Argent propre', dirty = 'Argent sale' }

Illegal.TxTypes = {
    deposit = 'Dépôt', withdraw = 'Retrait',
    admin_add = 'Ajout staff', admin_remove = 'Retrait staff',
    order = 'Commande', mission = 'Mission',
}

Illegal.Payments = { clean = 'Argent propre', dirty = 'Argent sale', both = 'Propre ou sale' }

Illegal.RequestStatus = {
    pending = 'En attente de validation', preparing = 'En préparation', ready = 'Prête : point GPS', delivered = 'Livrée',
    refused = 'Refusée', cancelled = 'Annulée',
}
