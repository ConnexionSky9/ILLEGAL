-- =========================================================
--  ELYZEA ILLÉGAL - CONSTANTES PARTAGÉES (client + serveur)
-- =========================================================
Illegal = Illegal or {}

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
    { key = 'settings', label = 'Paramètres' },
}
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
}

Illegal.Accounts = { clean = 'Argent propre', dirty = 'Argent sale' }

Illegal.TxTypes = {
    deposit = 'Dépôt', withdraw = 'Retrait',
    admin_add = 'Ajout staff', admin_remove = 'Retrait staff',
    order = 'Commande',
}

Illegal.Payments = { clean = 'Argent propre', dirty = 'Argent sale', both = 'Propre ou sale' }

Illegal.RequestStatus = {
    pending = 'En attente de validation', preparing = 'En préparation', ready = 'Prête : point GPS', delivered = 'Livrée',
    refused = 'Refusée', cancelled = 'Annulée',
}
