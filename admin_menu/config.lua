Config = {}

-- =========================================================
--  RACCOURCIS
--  Ce sont les touches PAR DÉFAUT. Chaque staff peut ensuite
--  les changer en jeu : Échap > Paramètres > Assignation des
--  touches > FiveM (toutes commencent par "Staff").
--  ⚠ FiveM mémorise le choix du joueur : modifier une touche ici
--  ne change rien pour quelqu'un qui l'a déjà personnalisée.
--
--  mapper : 'keyboard', 'MOUSE_BUTTON' (MOUSE_LEFT, MOUSE_RIGHT,
--  MOUSE_MIDDLE) ou 'MOUSE_WHEEL' (IOM_WHEEL_UP, IOM_WHEEL_DOWN).
--  key = '' : aucune touche par défaut (à assigner soi-même).
--  Liste des noms de touches :
--  docs.fivem.net/docs/game-references/input-mapper-parameter-ids
-- =========================================================
Config.Keys = {
    { cmd = 'adminmenu',       label = 'Ouvrir le menu',       mapper = 'keyboard', key = 'F10' },
    { cmd = 'admin_quick',     label = 'Menu rapide',          mapper = 'keyboard', key = 'F9' },
    { cmd = 'admin_duty',      label = 'Service staff / mode RP', mapper = 'keyboard', key = '' },
    { cmd = 'adminnoclip',     label = 'Noclip',               mapper = 'keyboard', key = 'F2' },
    { cmd = 'admin_wallhack',  label = 'Wallhack',             mapper = 'keyboard', key = '' },
    { cmd = 'admin_godmode',   label = 'Godmode',              mapper = 'keyboard', key = '' },
    { cmd = 'admin_invisible', label = 'Invisibilité',         mapper = 'keyboard', key = '' },
    { cmd = 'admin_ids',       label = 'Noms et IDs',          mapper = 'keyboard', key = '' },
    { cmd = 'admin_tpm',       label = 'TP au marqueur',       mapper = 'keyboard', key = '' },
    { cmd = 'admin_repair',    label = 'Réparer le véhicule',  mapper = 'keyboard', key = '' },
    { cmd = 'admin_revive_me', label = 'Me réanimer',          mapper = 'keyboard', key = '' },
    { cmd = 'admin_revive_area', label = 'Réanimer autour de moi', mapper = 'keyboard', key = '' },
    { cmd = 'admin_human',     label = 'Reprendre ma forme humaine', mapper = 'keyboard', key = '' },
}

-- Touches actives uniquement pendant le noclip (défauts AZERTY)
-- hold = true : action maintenue (déplacement), sinon appui simple
Config.NoclipKeys = {
    { id = 'forward',    label = 'Avancer',               mapper = 'keyboard',     key = 'Z',              hold = true },
    { id = 'back',       label = 'Reculer',               mapper = 'keyboard',     key = 'S',              hold = true },
    { id = 'left',       label = 'Aller à gauche',        mapper = 'keyboard',     key = 'Q',              hold = true },
    { id = 'right',      label = 'Aller à droite',        mapper = 'keyboard',     key = 'D',              hold = true },
    { id = 'up',         label = 'Monter',                mapper = 'keyboard',     key = 'SPACE',          hold = true },
    { id = 'down',       label = 'Descendre',             mapper = 'keyboard',     key = 'LCONTROL',       hold = true },
    { id = 'fast',       label = 'Aller vite',            mapper = 'keyboard',     key = 'LSHIFT',         hold = true },
    { id = 'slow',       label = 'Aller lentement',       mapper = 'keyboard',     key = 'LMENU',          hold = true },
    { id = 'speed_up',   label = 'Augmenter la vitesse',  mapper = 'MOUSE_WHEEL',  key = 'IOM_WHEEL_UP' },
    { id = 'speed_down', label = 'Baisser la vitesse',    mapper = 'MOUSE_WHEEL',  key = 'IOM_WHEEL_DOWN' },
    { id = 'delete',     label = 'Supprimer le véhicule visé', mapper = 'keyboard', key = 'G' },
    { id = 'spectate',   label = 'Spectate le joueur visé', mapper = 'MOUSE_BUTTON', key = 'MOUSE_LEFT' },
}

-- Touches du mode placement (props, PNJ, plants)
Config.EditorKeys = {
    { id = 'confirm',    label = 'Valider le placement',  mapper = 'keyboard',    key = 'E' },
    { id = 'cancel',     label = 'Annuler le placement',  mapper = 'keyboard',    key = 'BACK' },
    { id = 'rot_left',   label = 'Tourner à gauche',      mapper = 'MOUSE_WHEEL', key = 'IOM_WHEEL_UP' },
    { id = 'rot_right',  label = 'Tourner à droite',      mapper = 'MOUSE_WHEEL', key = 'IOM_WHEEL_DOWN' },
    { id = 'up',         label = 'Monter l\'objet',        mapper = 'keyboard',    key = 'PRIOR', hold = true },
    { id = 'down',       label = 'Descendre l\'objet',     mapper = 'keyboard',    key = 'NEXT',  hold = true },
    { id = 'reset',      label = 'Remettre la hauteur à zéro', mapper = 'keyboard', key = 'R' },
    { id = 'snap',       label = 'Coller au sol (oui / non)', mapper = 'keyboard', key = 'G' },
    { id = 'finish',     label = 'Terminer la zone dessinée', mapper = 'keyboard', key = 'RETURN' },
    { id = 'magnet',     label = 'Aimant : coller aux autres objets (oui / non)', mapper = 'keyboard', key = 'M' },
    { id = 'magnet_side', label = 'Aimant : changer de côté (dessus, devant…)', mapper = 'keyboard', key = 'X' },
}

-- Touche de récolte (pour TOUS les joueurs)
Config.HarvestKey = { label = 'Récolter', mapper = 'keyboard', key = 'E' }

-- =========================================================
--  FONDATEURS
--  Ces licences ont TOUJOURS le grade Fondateur (impossible
--  à retirer en jeu). Pour trouver ta licence : tape
--  "status" dans la console serveur pendant que tu es connecté.
--  Sinon, en console serveur : setrank <id> fondateur
-- =========================================================
Config.Owners = {
    -- 'license:0123456789abcdef0123456789abcdef01234567',
}
Config.OwnerRank = 'fondateur'

-- Grades donnés par les ACE de server.cfg (pratique sur Qbox / txAdmin).
-- Exemple dans server.cfg :
--   add_ace group.admin adminmenu.superadmin allow
--   add_principal identifier.license:xxxx group.admin
-- Le grade le plus haut trouvé est utilisé. Laisse vide pour désactiver.
Config.AceRanks = {
    { ace = 'adminmenu.fondateur',      rank = 'fondateur' },
    { ace = 'adminmenu.superadmin',     rank = 'superadmin' },
    { ace = 'adminmenu.administrateur', rank = 'administrateur' },
    { ace = 'adminmenu.moderateur',     rank = 'moderateur' },
    { ace = 'adminmenu.support',        rank = 'support' },
}

-- Webhook Discord pour les logs (laisser vide pour désactiver)
Config.DiscordWebhook = ''

-- Délai entre deux /report d'un même joueur (secondes)
Config.ReportCooldown = 60

-- =========================================================
--  PERMISSIONS DISPONIBLES
-- =========================================================
Config.Permissions = {
    { key = 'noclip',        label = 'Noclip',                         cat = 'Personnel' },
    { key = 'staff_pm',      label = 'Envoyer un message privé (MP staff) à un joueur', cat = 'Messages' },
    { key = 'staff_chat',    label = 'Discussion entre staffs (message staff)',        cat = 'Messages' },
    { key = 'delete_entity', label = 'Supprimer des véhicules (noclip)', cat = 'Personnel' },
    { key = 'godmode',       label = 'Godmode',                        cat = 'Personnel' },
    { key = 'invisible',     label = 'Invisibilité',                   cat = 'Personnel' },
    { key = 'tp_waypoint',   label = 'TP au marqueur',                 cat = 'Personnel' },
    { key = 'tp_coords',     label = 'TP aux coordonnées',             cat = 'Personnel' },
    { key = 'player_ids',    label = 'Afficher noms et IDs',           cat = 'Personnel' },
    { key = 'wallhack',      label = 'Wallhack (voir tous les joueurs)', cat = 'Personnel' },
    { key = 'transform',     label = 'Se transformer en animal (SuperAdmin+)', cat = 'Personnel' },

    { key = 'goto',          label = 'Aller vers un joueur',           cat = 'Joueurs' },
    { key = 'bring',         label = 'Ramener un joueur',              cat = 'Joueurs' },
    { key = 'spectate',      label = 'Spectate',                       cat = 'Joueurs' },
    { key = 'freeze',        label = 'Freeze',                         cat = 'Joueurs' },
    { key = 'heal',          label = 'Soigner (vie)',                  cat = 'Joueurs' },
    { key = 'armor',         label = 'Remplir l\'armure (gilet)',       cat = 'Joueurs' },
    { key = 'revive',        label = 'Réanimer un joueur',             cat = 'Joueurs' },
    { key = 'revive_area',   label = 'Réanimer une zone',              cat = 'Joueurs' },
    { key = 'kill',          label = 'Tuer',                           cat = 'Joueurs' },
    { key = 'give_weapon',   label = 'Donner une arme',                cat = 'Joueurs' },
    { key = 'give_item',     label = 'Donner des objets (tous)',       cat = 'Joueurs' },

    { key = 'reports',       label = 'Traiter les reports',            cat = 'Sanctions' },
    { key = 'warn',          label = 'Avertir',                        cat = 'Sanctions' },
    { key = 'kick',          label = 'Expulser',                       cat = 'Sanctions' },
    { key = 'jail',          label = 'Mettre en prison (jail)',        cat = 'Sanctions' },
    { key = 'ban',           label = 'Bannir',                         cat = 'Sanctions' },
    { key = 'unban',         label = 'Débannir',                       cat = 'Sanctions' },

    { key = 'spawn_vehicle', label = 'Faire apparaître un véhicule',   cat = 'Véhicules' },
    { key = 'vehicle_tools', label = 'Réparer, retourner, supprimer…', cat = 'Véhicules' },

    { key = 'weather',       label = 'Changer la météo',               cat = 'Monde' },
    { key = 'time',          label = "Changer l'heure",                cat = 'Monde' },
    { key = 'blackout',      label = 'Blackout',                       cat = 'Monde' },
    { key = 'announce',      label = 'Annonces serveur',               cat = 'Monde' },
    { key = 'clear_area',    label = 'Nettoyer une zone',              cat = 'Monde' },
    { key = 'manage_map',    label = 'Carte : mini-carte et icônes de la carte (cacher, déplacer, ajouter)', cat = 'Monde' },

    { key = 'view_logs',     label = 'Voir les logs',                  cat = 'Gestion' },
    { key = 'manage_staff',  label = 'Gérer le staff',                 cat = 'Gestion' },
    { key = 'manage_ranks',  label = 'Gérer les grades',               cat = 'Gestion' },

    -- Éditeur de map : en plus de la permission, il faut un niveau >= Config.Editor.minLevel
    { key = 'editor_spawns',  label = 'Points de spawn (SuperAdmin+)',     cat = 'Éditeur de map' },
    { key = 'editor_props',   label = 'Props persistants (SuperAdmin+)',   cat = 'Éditeur de map' },
    { key = 'editor_peds',    label = 'PNJ persistants (SuperAdmin+)',     cat = 'Éditeur de map' },
    { key = 'editor_harvest', label = 'Récoltes et fouilles (SuperAdmin+)', cat = 'Éditeur de map' },
    { key = 'editor_crafting', label = 'Ateliers de fabrication (SuperAdmin+)', cat = 'Éditeur de map' },
    { key = 'editor_zones',    label = 'Zones (safe zones, quartiers…) (SuperAdmin+)', cat = 'Éditeur de map' },
    { key = 'editor_doors',    label = 'Portes et portails verrouillables (SuperAdmin+)', cat = 'Éditeur de map' },
    { key = 'editor_stashes',  label = 'Coffres / inventaires (SuperAdmin+)', cat = 'Éditeur de map' },

    -- Onglet Événements (ressource gofast)
    { key = 'gofast_manage',   label = 'GoFast : contacts, dialogues, paliers, réglages', cat = 'Événements' },
    { key = 'gofast_missions', label = 'GoFast : missions en cours et joueurs (XP, attente)', cat = 'Événements' },
    { key = 'event_zombies',   label = 'Attaque de zombies : lancer, prolonger, tuer les zombies, arrêter', cat = 'Événements' },
    { key = 'event_drops',     label = 'Largage de drops : planifier, régler, lancer, annuler', cat = 'Événements' },

    -- Métiers (ressources Elyzea)
    { key = 'ems_staff',       label = 'Tablette staff EMS (/ems_staff) : configurer tout le métier EMS', cat = 'Métiers' },
    { key = 'police_staff',    label = 'Tablette staff Police (/police_staff) : configurer tout le métier Police', cat = 'Métiers' },
    { key = 'lscustom_staff',  label = 'LsCustom : gérer tout le métier (grades, zones, prix, tenues, permissions)', cat = 'Métiers' },
    { key = 'concess_staff',   label = 'Concession : gérer tout le métier (grades, zones, permissions, tenues, tablette direction)', cat = 'Métiers' },

    -- Illégal (ressource elyzea_illegal)
    { key = 'illegal_staff',   label = 'ILLEGAL : gérer les groupes illégaux (gangs, organisations, cartels, grades, membres, finances, PED, commandes)', cat = 'Illégal' },
}

-- =========================================================
--  ÉVÉNEMENT : LARGAGE DE DROPS (onglet Événements › Drops)
--  Tout se règle dans le menu ; ici, seulement les valeurs par défaut
--  et les listes proposées.
-- =========================================================
Config.Drops = {
    crateModel = 'prop_drop_armscrate_01',   -- caisse du drop
    keyLabel = 'Clé du drop',
    -- Armes proposées pour les gardes
    weapons = {
        { id = 'WEAPON_PISTOL', label = 'Pistolet' },
        { id = 'WEAPON_COMBATPISTOL', label = 'Pistolet de combat' },
        { id = 'WEAPON_PISTOL50', label = 'Pistolet .50' },
        { id = 'WEAPON_MICROSMG', label = 'Micro SMG' },
        { id = 'WEAPON_SMG', label = 'SMG' },
        { id = 'WEAPON_ASSAULTSMG', label = 'SMG d\'assaut' },
        { id = 'WEAPON_PUMPSHOTGUN', label = 'Fusil à pompe' },
        { id = 'WEAPON_ASSAULTRIFLE', label = 'AK-47' },
        { id = 'WEAPON_CARBINERIFLE', label = 'Carabine' },
        { id = 'WEAPON_SPECIALCARBINE', label = 'Carabine spéciale' },
        { id = 'WEAPON_COMBATMG', label = 'Mitrailleuse' },
        { id = 'WEAPON_SNIPERRIFLE', label = 'Sniper' },
    },
    -- Apparences proposées pour les gardes, avec les véhicules qui leur correspondent
    -- (garés autour de la caisse, ils servent d'abri aux gardes)
    models = {
        { id = 'g_m_y_mexgoon_01',   label = 'Voyou mexicain', vehicles = { 'chino2', 'buccaneer2', 'voodoo', 'moonbeam2' } },
        { id = 'g_m_y_ballasout_01', label = 'Ballas',          vehicles = { 'baller', 'cavalcade', 'manana', 'peyote' } },
        { id = 'g_m_y_lost_01',      label = 'Biker (Lost)',    vehicles = { 'gburrito', 'sandking2', 'rebel2', 'slamvan' } },
        { id = 'mp_g_m_pros_01',     label = 'Mercenaire',      vehicles = { 'mesa3', 'dubsta2', 'granger', 'kamacho' } },
        { id = 's_m_y_blackops_01',  label = 'Black ops',       vehicles = { 'fbi2', 'granger', 'riot', 'baller6' } },
        { id = 's_m_m_marine_01',    label = 'Militaire',       vehicles = { 'crusader', 'barracks', 'mesa3', 'insurgent3' } },
        { id = 'g_m_m_chicold_01',   label = 'Gangster âgé',    vehicles = { 'cavalcade2', 'washington', 'stretch', 'cognoscenti' } },
    },
    -- Abris posés autour de la caisse (sacs de sable, barrières, caisses)
    coverModels = { 'prop_mb_sandblock_03', 'prop_mb_sandblock_02', 'prop_barrier_work05', 'prop_mil_crate_02', 'prop_mb_cargo_04a' },
    -- Niveaux de difficulté : multiplicateurs et comportement des gardes
    difficulties = {
        easy    = { label = 'Facile',    acc = 0.6, hp = 0.8, armor = 0.5, ability = 0, movement = 1, flank = false, crit = true,  rate = 400 },
        normal  = { label = 'Normal',    acc = 1.0, hp = 1.0, armor = 1.0, ability = 1, movement = 1, flank = false, crit = true,  rate = 600 },
        hard    = { label = 'Difficile', acc = 1.3, hp = 1.4, armor = 1.2, ability = 2, movement = 2, flank = true,  crit = true,  rate = 800 },
        extreme = { label = 'Extrême',   acc = 1.6, hp = 2.0, armor = 1.5, ability = 2, movement = 3, flank = true,  crit = false, rate = 1000 },
    },
}

-- =========================================================
--  TABLETTE STAFF EMS (ressource elyzea_ems)
--  Accès donné par la permission « ems_staff » (onglet Grades)
--  ou individuellement (onglet 🚑 Tablette EMS du menu).
-- =========================================================
Config.Ems = {
    resource = 'elyzea_ems',            -- dossier de la ressource EMS
    staffResource = 'elyzea_ems_staff', -- dossier de la tablette staff
    command = 'ems_staff',              -- commande qui ouvre la tablette staff
    requireDuty = true,                 -- refuser l'accès en mode RP
    jobs = { 'ambulance' },             -- métiers EMS (tenues et « Rejoindre ce métier »)
}

-- =========================================================
--  TABLETTE STAFF POLICE (ressource elyzea_police)
--  Accès donné par la permission « police_staff » (onglet Grades)
--  ou individuellement (onglet 🚓 Police du menu, groupe Métiers).
-- =========================================================
Config.Police = {
    resource = 'elyzea_police',            -- dossier de la ressource Police (métier + tablette joueur)
    staffResource = 'elyzea_police_staff', -- dossier de la tablette staff
    command = 'police_staff',              -- commande qui ouvre la tablette staff
    requireDuty = true,                    -- refuser l'accès en mode RP
    jobs = { 'police' },                   -- métiers police (complétés par la liste de elyzea_police)
}

-- =========================================================
--  LSCUSTOM (ressource elyzea_lscustom)
--  Tout se gère dans le menu : Métiers > LsCustom (permission « lscustom_staff »).
-- =========================================================
Config.LsCustom = {
    resource = 'elyzea_lscustom',  -- dossier de la ressource
    jobs = { 'lscustom' },         -- métier (complété par celui de la ressource)
}

-- =========================================================
--  CONCESSION (ressource elyzea_concess)
--  Métiers > Concession (permission « concess_staff »).
-- =========================================================
Config.Concess = {
    resource = 'elyzea_concess',  -- dossier de la ressource
    jobs = { 'cardealer' },       -- métier (complété par celui de la ressource)
}

-- =========================================================
--  ILLEGAL (ressource elyzea_illegal)
--  Onglet ILLEGAL (permission « illegal_staff »).
-- =========================================================
Config.Illegal = {
    resource = 'elyzea_illegal',  -- dossier de la ressource
}

-- =========================================================
--  CARTE (onglet 🗺️ Carte du menu, permission « manage_map »)
--  Valeurs de départ de la mini-carte : tout se règle ensuite en
--  jeu avec un aperçu en direct, puis « Enregistrer pour tous ».
-- =========================================================
Config.Minimap = {
    enabled = true,           -- false : le menu ne touche pas à la mini-carte
    shape = 'square',         -- 'square' (carrée), 'round' (ronde), 'default' (rectangle GTA)
    position = 'top-right',   -- 'top-right', 'top-left', 'bottom-left', 'bottom-right'
    size = 0.20,              -- hauteur (part de l'écran)
    widthAdjust = 100,        -- % de largeur (100 = carré parfait)
    marginX = 0.012,          -- écart avec le bord gauche / droit
    marginY = 0.018,          -- écart avec le bord haut / bas
    hideHealthBars = true,    -- cacher les barres de vie / armure de GTA sous la carte
    onlyInVehicle = false,    -- mini-carte seulement en véhicule
    -- Commandes d'autres scripts qui déplacent la mini-carte : désactivées (la position est celle du staff)
    blockCommands = { 'carte', 'minimap' },
}

-- Noms des icônes de la carte (pour la liste « Icônes des scripts »)
Config.MapIcons = {
    [1] = 'Point', [40] = 'Maison', [43] = 'Hélicoptère', [50] = 'Garage', [52] = 'Supérette', [60] = 'Police',
    [61] = 'Hôpital', [68] = 'Fourrière', [71] = 'Coiffeur', [72] = 'Los Santos Customs', [73] = 'Vêtements',
    [75] = 'Tatoueur', [93] = 'Bar', [100] = 'Lavage auto', [108] = 'Banque', [110] = 'Armurerie', [121] = 'Club',
    [135] = 'Cinéma', [225] = 'Voiture', [280] = 'Personne', [326] = 'Concession', [357] = 'Garage',
    [361] = 'Station-service', [410] = 'Bateaux', [446] = 'Mécanicien', [469] = 'Cannabis', [487] = 'Zone sûre',
    [679] = 'Casino', [161] = 'Alerte', [153] = 'Croix médicale', [526] = 'Alerte urgente',
}

-- Couleurs d'icônes proposées (numéro GTA)
Config.MapColors = {
    { id = 0,  label = 'Blanc',       hex = '#f0f0f0' }, { id = 1,  label = 'Rouge',      hex = '#e03232' },
    { id = 2,  label = 'Vert',        hex = '#71cb71' }, { id = 3,  label = 'Bleu',       hex = '#5db6e5' },
    { id = 5,  label = 'Jaune',       hex = '#eec64e' }, { id = 6,  label = 'Rouge clair', hex = '#c25050' },
    { id = 7,  label = 'Violet',      hex = '#9c6eaf' }, { id = 8,  label = 'Rose',       hex = '#ff7bc4' },
    { id = 17, label = 'Orange',      hex = '#f5a623' }, { id = 25, label = 'Vert foncé', hex = '#3a8a3a' },
    { id = 27, label = 'Violet vif',  hex = '#a14ad8' }, { id = 29, label = 'Bleu foncé', hex = '#3b6fe0' },
    { id = 40, label = 'Gris',        hex = '#5a5a5a' }, { id = 46, label = 'Or',         hex = '#d9b56a' },
}

-- =========================================================
--  TENUES DE SERVICE (onglets EMS et Police du groupe Métiers)
--  Quand un joueur prend son service, il enfile la tenue de son
--  grade ; il retrouve ses vêtements en terminant son service.
-- =========================================================
Config.Uniforms = {
    enabled = true,
    components = { 1, 3, 4, 5, 6, 7, 8, 9, 10, 11 }, -- masque, bras, jambes, sac, chaussures, accessoires, t-shirt, gilet, badge, haut
    props = { 0, 1, 2, 6, 7 },                         -- chapeau, lunettes, oreilles, montre, bracelet
    notify = true,                                     -- message « Tenue de service enfilée »

    -- Tenues créées automatiquement au premier démarrage pour chaque métier de Config.Ems.jobs / Config.Police.jobs
    -- (vêtements du jeu de base). Format : [composant] = { modèle, texture } ; accessoire -1 = aucun.
    -- Pour changer une tenue : habille-toi en jeu puis « Enregistrer ma tenue » dans la tablette du métier.
    defaults = {
        police = {
            male = {
                base = {
                    c = { [1] = { 0, 0 }, [3] = { 41, 0 }, [4] = { 25, 0 }, [5] = { 0, 0 }, [6] = { 25, 0 }, [7] = { 0, 0 },
                          [8] = { 59, 1 }, [9] = { 0, 0 }, [10] = { 0, 0 }, [11] = { 55, 0 } },
                    p = { [0] = { 46, 0 }, [2] = { 2, 0 } },               -- casquette, oreillette
                },
                -- Galons sur l'épaule (composant 10) selon le grade
                grades = { [2] = { [10] = { 8, 1 } }, [3] = { [10] = { 8, 2 } }, [4] = { [10] = { 8, 3 } } },
            },
            female = {
                base = {
                    c = { [1] = { 0, 0 }, [3] = { 44, 0 }, [4] = { 34, 0 }, [5] = { 0, 0 }, [6] = { 27, 0 }, [7] = { 0, 0 },
                          [8] = { 36, 1 }, [9] = { 0, 0 }, [10] = { 0, 0 }, [11] = { 48, 0 } },
                    p = { [0] = { 45, 0 }, [2] = { 2, 0 } },
                },
                grades = { [2] = { [10] = { 7, 1 } }, [3] = { [10] = { 7, 2 } }, [4] = { [10] = { 7, 3 } } },
            },
        },
        concess = {
            -- Costume de vendeur
            male = {
                base = {
                    c = { [1] = { 0, 0 }, [3] = { 4, 0 }, [4] = { 10, 0 }, [5] = { 0, 0 }, [6] = { 10, 0 }, [7] = { 0, 0 },
                          [8] = { 4, 0 }, [9] = { 0, 0 }, [10] = { 0, 0 }, [11] = { 4, 0 } },
                    p = { [0] = { -1, 0 } },
                },
                grades = {},
            },
            female = {
                base = {
                    c = { [1] = { 0, 0 }, [3] = { 3, 0 }, [4] = { 6, 0 }, [5] = { 0, 0 }, [6] = { 13, 0 }, [7] = { 0, 0 },
                          [8] = { 38, 0 }, [9] = { 0, 0 }, [10] = { 0, 0 }, [11] = { 7, 0 } },
                    p = { [0] = { -1, 0 } },
                },
                grades = {},
            },
        },
        lscustom = {
            -- Combinaison de travail
            male = {
                base = {
                    c = { [1] = { 0, 0 }, [3] = { 0, 0 }, [4] = { 39, 0 }, [5] = { 0, 0 }, [6] = { 25, 0 }, [7] = { 0, 0 },
                          [8] = { 15, 0 }, [9] = { 0, 0 }, [10] = { 0, 0 }, [11] = { 66, 0 } },
                    p = { [0] = { -1, 0 } },
                },
                grades = {},
            },
            female = {
                base = {
                    c = { [1] = { 0, 0 }, [3] = { 14, 0 }, [4] = { 39, 0 }, [5] = { 0, 0 }, [6] = { 25, 0 }, [7] = { 0, 0 },
                          [8] = { 14, 0 }, [9] = { 0, 0 }, [10] = { 0, 0 }, [11] = { 60, 0 } },
                    p = { [0] = { -1, 0 } },
                },
                grades = {},
            },
        },
        ems = {
            male = {
                base = {
                    c = { [1] = { 0, 0 }, [3] = { 85, 0 }, [4] = { 96, 0 }, [5] = { 0, 0 }, [6] = { 54, 0 }, [7] = { 0, 0 },
                          [8] = { 15, 0 }, [9] = { 0, 0 }, [10] = { 58, 0 }, [11] = { 250, 0 } },
                    p = { [0] = { -1, 0 } },
                },
                grades = {},
            },
            female = {
                base = {
                    c = { [1] = { 0, 0 }, [3] = { 109, 0 }, [4] = { 99, 0 }, [5] = { 0, 0 }, [6] = { 55, 0 }, [7] = { 0, 0 },
                          [8] = { 14, 0 }, [9] = { 0, 0 }, [10] = { 66, 0 }, [11] = { 258, 0 } },
                    p = { [0] = { -1, 0 } },
                },
                grades = {},
            },
        },
    },
}

-- =========================================================
--  GARAGES SUR PNJ (Éditeur de map › PNJ › rôle « Garage »)
-- =========================================================
Config.Garages = {
    platePrefix = 'GAR',        -- début des plaques par défaut (modifiable par garage)
    storeRadius = 25.0,         -- distance max (m) du PNJ ou d'un point de sortie pour ranger
    spotClearRadius = 3.0,      -- un point de sortie est « libre » si aucun véhicule à moins de X m
    maxSpots = 12,              -- points de sortie max par garage
    maxVehicles = 40,           -- véhicules max par garage
    blipSprite = 357,           -- icône par défaut (garage)
    blipColor = 3,
    -- Clés du véhicule : 'auto' détecte qbx_vehiclekeys, qb-vehiclekeys, wasabi_carlock, MrNewbVehicleKeys.
    -- Pour un autre script, mets keysEvent = { type = 'client' ou 'server', name = 'mon:event' } (reçoit la plaque).
    keys = 'auto',
    keysEvent = nil,
    deleteOnDrop = true,        -- retirer les véhicules de garage d'un joueur qui se déconnecte
}

-- =========================================================
--  ÉVÉNEMENTS (onglet « Événements » du menu)
-- =========================================================
Config.Events = {
    goFastResource = 'gofast',   -- nom du dossier de la ressource Go Fast
}

-- =========================================================
--  ÉVÉNEMENT : ATTAQUE DE ZOMBIES (onglet Événements)
--  Tout se lance et se règle depuis le menu ; ici les valeurs de base.
-- =========================================================
Config.Zombies = {
    -- Intensités proposées dans le menu : zombies max autour de CHAQUE joueur / sur tout le serveur
    intensities = {
        { id = 'low',       label = 'Faible',    perPlayer = 5,  global = 60 },
        { id = 'medium',    label = 'Moyenne',   perPlayer = 10, global = 110 },
        { id = 'high',      label = 'Forte',     perPlayer = 16, global = 160 },
        { id = 'nightmare', label = 'Cauchemar', perPlayer = 24, global = 220 },
    },
    durations = { 10, 20, 30, 45, 60, 90 },   -- minutes proposées
    maxDuration = 240,                         -- minutes, durée max (prolongations comprises)

    -- Zone « Ville de Los Santos » (rectangle autour de la ville, Vinewood Hills et port compris)
    cityArea = { minX = -3300.0, maxX = 1750.0, minY = -3700.0, maxY = 1550.0 },

    -- Apparition autour des joueurs
    spawnInterval = 2000,       -- ms entre deux passages du serveur
    spawnBatch = 3,             -- zombies max créés par joueur à chaque passage
    spawnMin = 35.0,            -- distance min d'apparition (m)
    spawnMax = 85.0,            -- distance max d'apparition (m)
    nearRadius = 120.0,         -- zombies comptés « autour » d'un joueur dans ce rayon
    despawnDistance = 220.0,    -- un zombie plus loin que ça de tout joueur disparaît
    bodyTime = 20,              -- secondes avant de retirer un corps

    -- Comportement
    models = {
        'u_m_y_zombie_01', 'u_m_y_zombie_01', 'a_m_m_skidrow_01', 'a_m_m_tramp_01', 'a_m_o_tramp_01',
        'a_f_m_tramp_01', 'a_m_y_methhead_01', 'a_f_y_rurmeth_01', 'a_m_m_hillbilly_01', 'a_m_m_salton_02',
        'a_m_y_salton_01', 'a_m_m_trampbeac_01', 'a_f_m_trampbeac_01', 'a_m_y_genstreet_01', 'a_m_m_beach_01',
        'a_f_y_hipster_02', 'a_m_y_hipster_01', 's_m_y_construct_01', 's_m_m_doctor_01', 's_m_m_paramedic_01',
    },
    health = 260,               -- vie des zombies (un humain : 200)
    headshotHealth = 1200,      -- vie si « seulement la tête » est activé (le corps n'y fait presque rien)
    walkClipset = 'move_m@drunk@verydrunk',
    aggroRange = 70.0,          -- ils foncent sur un joueur à moins de X m, sinon ils errent
    damage = 1.0,               -- multiplicateur des coups de zombie (1.0 = coup de poing normal)

    -- Attaque au corps à corps : le zombie fonce et frappe EN MARCHANT, sans se mettre en garde
    attack = {
        range = 1.8,            -- distance de frappe (m)
        cooldown = 800,         -- temps entre deux coups (ms)
        damage = 12,            -- dégâts d'un coup (× « Force des coups » de l'événement)
        knockdown = 8,          -- % de chances de faire tomber le joueur
        dict = 'melee@unarmed@streamed_variations', anim = 'plyr_takedown_front_slap',
    },
    -- Boss (étape de mission « Tuer le boss ») : valeurs par défaut, toutes réglables dans le menu
    boss = {
        model = 'u_m_y_juggernaut_01',  -- apparence (le « Juggernaut » : massif et blindé)
        name = 'Le Colosse',
        health = 8000,          -- vie (un zombie : 260)
        scale = 2.0,            -- taille (×1 à ×3) : agrandissement visuel
        speed = 1.6,            -- vitesse (0,8 très lent · 1,6 normal · 3,0 il court)
        minions = 12,           -- zombies qui le protègent
        reinforce = true,       -- les gardes morts sont remplacés
        reinforceEvery = 20,    -- secondes entre deux renforts
        leash = 80,             -- il ne s'éloigne pas à plus de X m de son point d'apparition
        walk = 'ANIM_GROUP_MOVE_BALLISTIC',   -- démarche lourde
        melee = { range = 3.4, cooldown = 1600, damage = 40, dict = 'melee@large_wpn@streamed_core', anim = 'ground_attack_on_spot' },
        throw = { minRange = 8.0, maxRange = 40.0, cooldown = 6000, speed = 18.0, damage = 30, radius = 4.5,
                  dict = 'weapons@projectile@grenade_str', anim = 'throw_h_fb_stand' },
    },

    -- Cracheurs : gardent leurs distances et crachent un acide qu'on peut esquiver
    spit = {
        model = 'u_m_y_zombie_01',
        minRange = 5.0,         -- trop près : il griffe comme les autres
        maxRange = 24.0,        -- portée du crachat (m)
        cooldown = 4000,        -- temps entre deux crachats (ms)
        speed = 20.0,           -- vitesse du crachat (m/s) : on peut l'esquiver en bougeant
        damage = 14,            -- dégâts à l'impact (× « Force des coups »)
        burn = 3,               -- secondes de brûlure acide après l'impact
        burnDamage = 2,         -- dégâts par seconde de brûlure
        hitRadius = 2.0,        -- rayon de l'éclaboussure (m)
        dict = 'random@drunk_driver_1', anim = 'vomit_outside',
    },

    -- Ambiance (appliquée à tous les joueurs pendant l'événement)
    weather = 'THUNDER',        -- orage + pluie
    nightHour = 23,
    timecycle = 'rply_saturation_neg',  -- filtre d'image désaturé ('' = aucun)
    timecycleStrength = 0.55,
    lightning = { 15, 45 },     -- éclairs supplémentaires toutes les X à Y secondes

    -- Morts des joueurs pendant l'événement : aucune perte (relevé sur place par le menu)
    reviveDelay = 6,            -- secondes au sol avant d'être relevé
    reviveProtection = 6,       -- secondes d'invincibilité après avoir été relevé

    -- ---------- Missions de l'événement ----------
    missionMax = 5,             -- missions max au lancement (le double en ajoutant pendant l'événement)
    missionMaxSteps = 8,        -- étapes max par mission
    missionHotspot = 250.0,     -- les zombies apparaissent aussi à moins de X m d'un objectif en cours
    -- Lieux proposés dans le menu (coordonnées à vérifier sur ta map : bouton « Y aller », ou « Ma position »)
    places = {
        { id = 'humane',   label = 'Humane Labs (entrée du labo)', x = 3537.0,  y = 3661.0,  z = 28.1 },
        { id = 'humane_gate', label = 'Humane Labs (portail)',     x = 3433.0,  y = 3767.0,  z = 30.5 },
        { id = 'pillbox',  label = 'Hôpital Pillbox Hill',         x = 298.7,   y = -584.6,  z = 43.3 },
        { id = 'zancudo',  label = 'Fort Zancudo (entrée)',        x = -1587.6, y = 2805.4,  z = 17.0 },
        { id = 'power',    label = 'Centrale Palmer-Taylor',       x = 2694.0,  y = 1550.0,  z = 24.6 },
        { id = 'chiliad',  label = 'Sommet du mont Chiliad',       x = 501.8,   y = 5604.3,  z = 797.9 },
        { id = 'lsia',     label = 'Aéroport de Los Santos',       x = -1037.0, y = -2737.0, z = 20.2 },
        { id = 'sandy_sheriff', label = 'Bureau du shérif (Sandy)', x = 1853.0, y = 3686.0,  z = 34.3 },
    },
    -- Missions toutes prêtes (boutons dans le menu, modifiables avant de lancer)
    missionPresets = {
        {
            id = 'decon', icon = '🧪', label = 'Décontamination à Humane Labs',
            mission = {
                title = 'Décontamination totale',
                desc = 'L\'épidémie est partie de Humane Labs. Remontez à la source et lancez la décontamination de la ville.',
                outcome = 'decontaminate', delay = 10,
                rewards = { to = 'participants', lines = { { kind = 'cash', amount = 5000 } } },
                steps = {
                    { type = 'reach',    place = 'humane_gate', title = 'Rejoindre Humane Labs', desc = 'Là où la contamination a commencé.', radius = 40 },
                    { type = 'interact', place = 'humane', title = 'Récupérer les données du virus', desc = 'Maintiens E sur le terminal du labo.', radius = 6, seconds = 12 },
                    { type = 'defend',   place = 'humane', title = 'Protéger la synthèse de l\'antidote', desc = 'Restez dans la zone pendant la synthèse. Ils arrivent…', radius = 30, seconds = 90 },
                    { type = 'interact', place = 'humane', title = 'Lancer la décontamination', desc = 'Maintiens E pour diffuser l\'antidote sur toute la ville.', radius = 6, seconds = 8 },
                },
            },
        },
        {
            id = 'vaccines', icon = '💉', label = 'Vaccins de l\'hôpital',
            mission = {
                title = 'Les vaccins de Pillbox',
                desc = 'Des doses de vaccin sont restées à Pillbox. Allez les chercher et tenez la position.',
                outcome = 'killall', delay = 0,
                rewards = { to = 'laststep', lines = { { kind = 'bank', amount = 2000 } } },
                steps = {
                    { type = 'reach',    place = 'pillbox', title = 'Atteindre l\'hôpital Pillbox', desc = '', radius = 35 },
                    { type = 'defend',   place = 'pillbox', title = 'Tenir l\'entrée de l\'hôpital', desc = 'Le temps que les médecins préparent les doses.', radius = 30, seconds = 60 },
                    { type = 'interact', place = 'pillbox', title = 'Récupérer les vaccins', desc = 'Maintiens E pour charger les caisses.', radius = 6, seconds = 10 },
                },
            },
        },
        {
            id = 'boss', icon = '☠️', label = 'Tuer le boss (Fort Zancudo)',
            mission = {
                title = 'Le Colosse de Zancudo',
                desc = 'Une abomination géante est sortie de la base militaire. Abattez-la avant qu\'elle ne ravage la ville.',
                outcome = 'killall', delay = 5,
                rewards = { to = 'participants', lines = { { kind = 'cash', amount = 10000 } } },
                steps = {
                    { type = 'reach', place = 'zancudo', title = 'Rejoindre Fort Zancudo', desc = 'Le monstre a été repéré à l\'entrée de la base.', radius = 60 },
                    { type = 'boss', place = 'zancudo', title = 'Tuer le Colosse', desc = 'Il frappe le sol et lance des masses de chair. Ses zombies le protègent.',
                      radius = 80, bossName = 'Le Colosse', bossModel = 'u_m_y_juggernaut_01', bossHealth = 12000, bossScale = 2.2, bossSpeed = 1.6, minions = 14, reinforce = true },
                },
            },
        },
        {
            id = 'bigfoot', icon = '🦍', label = 'Tuer la bête du Chiliad',
            mission = {
                title = 'La bête du mont Chiliad',
                desc = 'Une créature énorme rôde au sommet du Chiliad. Montez la chasser.',
                outcome = 'none', delay = 0,
                rewards = { to = 'participants', lines = { { kind = 'bank', amount = 6000 } } },
                steps = {
                    { type = 'boss', place = 'chiliad', title = 'Abattre la bête', desc = 'Elle ne quitte pas le sommet.',
                      radius = 70, bossName = 'La Bête', bossModel = 'ig_orleans', bossHealth = 8000, bossScale = 2.6, bossSpeed = 2.4, minions = 8, reinforce = false },
                },
            },
        },
    },

    -- ---------- Caisses d'armes ----------
    crateOpenTime = 3,          -- secondes à maintenir E pour ouvrir une caisse
    crateModels = {
        { id = 'prop_mil_crate_01',  label = 'Caisse militaire' },
        { id = 'prop_box_ammo04a',   label = 'Caisse de munitions' },
        { id = 'prop_box_guncase_03a', label = 'Mallette d\'armes' },
        { id = 'prop_box_wood02a',   label = 'Caisse en bois' },
    },
    crateColors = {             -- couleurs proposées pour le blip
        { id = 1, label = 'Rouge' }, { id = 2, label = 'Vert' }, { id = 3, label = 'Bleu' },
        { id = 5, label = 'Jaune' }, { id = 17, label = 'Orange' }, { id = 27, label = 'Violet' }, { id = 0, label = 'Blanc' },
    },
    -- Caisses toutes prêtes selon ton inventaire (noms des munitions différents)
    cratePresets = {
        ox = {
            { id = 'pistols', icon = '🔫', label = 'Caisse de pistolets', mode = 'once', model = 'prop_box_guncase_03a', color = 5, count = 10,
              contents = { { item = 'WEAPON_PISTOL', count = 1 }, { item = 'ammo-9', count = 60 } } },
            { id = 'smg', icon = '💥', label = 'Caisse de mitraillettes', mode = 'once', model = 'prop_box_ammo04a', color = 17, count = 6,
              contents = { { item = 'WEAPON_MICROSMG', count = 1 }, { item = 'ammo-9', count = 120 } } },
            { id = 'heavy', icon = '🪖', label = 'Caisse lourde', mode = 'once', model = 'prop_mil_crate_01', color = 1, count = 3,
              contents = { { item = 'WEAPON_CARBINERIFLE', count = 1 }, { item = 'WEAPON_PUMPSHOTGUN', count = 1 },
                           { item = 'ammo-rifle', count = 150 }, { item = 'ammo-shotgun', count = 30 } } },
            { id = 'ammo', icon = '📦', label = 'Ravitaillement en munitions', mode = 'each', model = 'prop_box_wood02a', color = 2, count = 5,
              contents = { { item = 'ammo-9', count = 60 }, { item = 'ammo-rifle', count = 60 } } },
        },
        qb = {
            { id = 'pistols', icon = '🔫', label = 'Caisse de pistolets', mode = 'once', model = 'prop_box_guncase_03a', color = 5, count = 10,
              contents = { { item = 'weapon_pistol', count = 1 }, { item = 'pistol_ammo', count = 5 } } },
            { id = 'smg', icon = '💥', label = 'Caisse de mitraillettes', mode = 'once', model = 'prop_box_ammo04a', color = 17, count = 6,
              contents = { { item = 'weapon_microsmg', count = 1 }, { item = 'smg_ammo', count = 6 } } },
            { id = 'heavy', icon = '🪖', label = 'Caisse lourde', mode = 'once', model = 'prop_mil_crate_01', color = 1, count = 3,
              contents = { { item = 'weapon_carbinerifle', count = 1 }, { item = 'weapon_pumpshotgun', count = 1 },
                           { item = 'rifle_ammo', count = 8 }, { item = 'shotgun_ammo', count = 4 } } },
            { id = 'ammo', icon = '📦', label = 'Ravitaillement en munitions', mode = 'each', model = 'prop_box_wood02a', color = 2, count = 5,
              contents = { { item = 'pistol_ammo', count = 4 }, { item = 'rifle_ammo', count = 4 } } },
        },
        esx = {
            { id = 'pistols', icon = '🔫', label = 'Caisse de pistolets', mode = 'once', model = 'prop_box_guncase_03a', color = 5, count = 10,
              contents = { { item = 'WEAPON_PISTOL', count = 1 } } },
            { id = 'heavy', icon = '🪖', label = 'Caisse lourde', mode = 'once', model = 'prop_mil_crate_01', color = 1, count = 3,
              contents = { { item = 'WEAPON_CARBINERIFLE', count = 1 }, { item = 'WEAPON_PUMPSHOTGUN', count = 1 } } },
        },
    },
    -- Emplacements des caisses posées automatiquement (seuls ceux dans la zone de l'événement sont utilisés).
    -- Lieux dégagés (stations-service, places, parkings). Ajoute les tiens : { x = , y = , z = }
    crateSpots = {
        { x = 195.2, y = -933.8, z = 30.7 },   { x = 298.7, y = -584.6, z = 43.3 },   { x = 433.5, y = -981.8, z = 30.7 },
        { x = -1223.0, y = -1491.0, z = 4.4 }, { x = -1641.0, y = -1014.0, z = 13.0 }, { x = -365.0, y = -131.0, z = 38.7 },
        { x = -205.0, y = -1308.0, z = 31.3 }, { x = -70.2, y = -1761.8, z = 29.5 },  { x = 265.6, y = -1261.3, z = 29.3 },
        { x = 819.7, y = -1028.8, z = 26.4 },  { x = 1209.0, y = -1402.6, z = 35.2 }, { x = 1181.4, y = -330.8, z = 69.3 },
        { x = 620.8, y = 269.1, z = 103.1 },   { x = 176.6, y = -1562.0, z = 29.3 },  { x = -319.3, y = -1471.7, z = 30.5 },
        { x = -724.6, y = -935.2, z = 19.2 },  { x = -526.0, y = -1211.0, z = 18.2 }, { x = -1437.6, y = -276.7, z = 46.2 },
        { x = -2096.2, y = -320.3, z = 13.2 }, { x = -1800.4, y = 803.7, z = 138.7 }, { x = 2581.3, y = 362.0, z = 108.5 },
        { x = 49.4, y = 2778.8, z = 58.0 },    { x = 263.9, y = 2606.5, z = 45.0 },   { x = 1040.0, y = 2671.1, z = 39.6 },
        { x = 1207.3, y = 2660.2, z = 37.9 },  { x = 2539.7, y = 2594.2, z = 37.9 },  { x = 2679.9, y = 3263.9, z = 55.2 },
        { x = 2005.1, y = 3773.9, z = 32.4 },  { x = 1784.3, y = 3330.6, z = 41.3 },  { x = 1687.2, y = 4929.4, z = 42.1 },
        { x = 1701.3, y = 6416.0, z = 32.8 },  { x = 179.9, y = 6602.8, z = 31.9 },   { x = -94.5, y = 6419.6, z = 31.5 },
        { x = -2555.0, y = 2334.4, z = 33.1 },
    },

    announce = {
        title = 'ALERTE : ÉPIDÉMIE',
        start = 'Une épidémie ravage la ville. Les morts se relèvent… Restez groupés, armez-vous. Pendant l\'attaque, mourir ne vous fait rien perdre.',
        stop = 'L\'épidémie est maîtrisée. La ville peut respirer.',
        decontaminated = 'Décontamination réussie ! L\'antidote se répand sur toute la ville. Merci aux survivants.',
    },
}

-- =========================================================
--  GRADES PAR DÉFAUT (utilisés seulement au 1er démarrage,
--  ensuite tout se gère en jeu dans l'onglet Grades)
--  Le niveau définit la hiérarchie : on ne peut agir que sur
--  quelqu'un de niveau inférieur.
-- =========================================================
local function with(base, extra)
    local t = {}
    for _, v in ipairs(base) do t[#t + 1] = v end
    for _, v in ipairs(extra) do t[#t + 1] = v end
    return t
end

local P_SUPPORT = { 'reports', 'goto', 'spectate', 'warn', 'noclip', 'tp_waypoint', 'player_ids', 'heal', 'staff_pm', 'staff_chat' }
local P_MODO    = with(P_SUPPORT, { 'bring', 'freeze', 'kick', 'delete_entity', 'vehicle_tools', 'revive', 'jail' })
local P_ADMIN   = with(P_MODO, { 'ban', 'unban', 'kill', 'spawn_vehicle', 'godmode', 'invisible', 'tp_coords',
                                 'weather', 'time', 'announce', 'clear_area', 'view_logs', 'wallhack', 'revive_area', 'armor',
                                 'gofast_missions' })
local P_SUPER   = with(P_ADMIN, { 'give_weapon', 'give_item', 'blackout', 'manage_staff', 'transform',
                                  'editor_spawns', 'editor_props', 'editor_peds', 'editor_harvest', 'editor_crafting', 'editor_zones', 'editor_doors',
                                  'gofast_manage', 'event_zombies', 'ems_staff', 'police_staff', 'lscustom_staff', 'manage_map', 'concess_staff', 'editor_stashes', 'event_drops' })

Config.DefaultRanks = {
    support        = { label = 'Support',        level = 10,  color = '#4fb3a9', perms = P_SUPPORT },
    moderateur     = { label = 'Modérateur',     level = 20,  color = '#5b8def', perms = P_MODO },
    administrateur = { label = 'Administrateur', level = 30,  color = '#f2b134', perms = P_ADMIN },
    superadmin     = { label = 'SuperAdmin',     level = 40,  color = '#e07a3f', perms = P_SUPER },
    fondateur      = { label = 'Fondateur',      level = 100, color = '#e5534b', perms = {} }, -- toutes les permissions, verrouillé
}

-- =========================================================
--  MESSAGES PRIVÉS (MP STAFF) ET DISCUSSION STAFF
--  Le joueur voit le MP s'afficher à l'écran et répond avec /r.
--  Les staffs : /mp [id] [message] et /sc [message] (ou le menu rapide F9).
-- =========================================================
Config.Messages = {
    showStaffName = true,     -- false : le joueur voit seulement « Staff » (et le grade si showRank)
    showRank      = true,
    maxLength     = 300,
    duration      = 15,       -- secondes d'affichage d'un message
    replyMinutes  = 15,       -- le joueur peut répondre pendant X minutes après le dernier MP
    commands = { reply = 'r', pm = 'mp', staffChat = 'sc', tpCoords = 'tpc' },
    staffChatOnDutyOnly = true, -- les staffs en mode RP ne reçoivent pas la discussion staff
}

-- =========================================================
--  NOCLIP
-- =========================================================
Config.Noclip = {
    -- 15 vitesses en mètres par seconde (molette pour passer de l'une à l'autre)
    speeds         = { 0.5, 1.0, 2.0, 3.5, 5.0, 7.5, 10.0, 14.0, 19.0, 25.0, 33.0, 45.0, 60.0, 85.0, 120.0 },
    defaultSpeed   = 7,     -- index dans la liste ci-dessus (7 = 10 m/s, environ 36 km/h)
    rememberSpeed  = true,  -- garde ta dernière vitesse d'une session à l'autre
    fastMultiplier = 3.0,   -- Shift
    slowMultiplier = 0.3,   -- Alt
    -- Fluidité : douceur de l'accélération et du freinage (plus haut = plus nerveux, 0 = instantané)
    smoothing      = 8.0,
    -- Avancer quand la caméra penche :
    --   'deadzone'   : tout droit tant que la caméra penche de moins de pitchDeadzone degrés (conseillé),
    --                  au-delà on monte / descend dans la direction regardée
    --   'horizontal' : toujours à l'horizontale (monter / descendre seulement avec Espace / Ctrl)
    --   'camera'     : suit exactement la caméra (ancien comportement)
    pitchMode      = 'deadzone',
    pitchDeadzone  = 22.0,
    targetDistance = 80.0,  -- portée du viseur (suppression / spectate)
    maxSpeed       = 160.0, -- vitesse max en m/s (plus haut = risque de crash en volant au-dessus de la map)
    fastThreshold  = 70.0,  -- au-dessus (m/s), le viseur se met en pause pendant le vol
}

-- =========================================================
--  WALLHACK
-- =========================================================
Config.Wallhack = {
    maxDistance = 600.0,  -- distance max d'affichage des noms en 3D
    lines       = true,   -- trait entre toi et chaque joueur proche
    lineDistance = 150.0, -- distance max des traits
    blips       = true,   -- tous les joueurs sur la carte, même très loin
    refresh     = 2000,   -- ms entre deux envois de positions par le serveur
}

-- =========================================================
--  VÉHICULES
-- =========================================================
Config.VehiclePlate = 'STAFF'
Config.DeletePreviousVehicle = true

Config.QuickVehicles = {
    { cat = 'Sport',       list = { 'adder', 'zentorno', 't20', 'turismor', 'italigtb', 'elegy' } },
    { cat = 'SUV et 4x4',  list = { 'baller', 'granger', 'sandking', 'mesa', 'dubsta' } },
    { cat = 'Urgences',    list = { 'police', 'police2', 'police3', 'ambulance', 'firetruk', 'fbi' } },
    { cat = 'Motos',       list = { 'bati', 'akuma', 'sanchez', 'hakuchou', 'faggio' } },
    { cat = 'Aérien',      list = { 'buzzard2', 'maverick', 'frogger', 'luxor', 'duster' } },
    { cat = 'Utilitaires', list = { 'flatbed', 'towtruck', 'mule', 'burrito3', 'speedo' } },
}

Config.Weapons = {
    { id = 'WEAPON_PISTOL',          label = 'Pistolet' },
    { id = 'WEAPON_COMBATPISTOL',    label = 'Pistolet de combat' },
    { id = 'WEAPON_STUNGUN',         label = 'Taser' },
    { id = 'WEAPON_NIGHTSTICK',      label = 'Matraque' },
    { id = 'WEAPON_FLASHLIGHT',      label = 'Lampe torche' },
    { id = 'WEAPON_SMG',             label = 'SMG' },
    { id = 'WEAPON_CARBINERIFLE',    label = 'Carabine' },
    { id = 'WEAPON_PUMPSHOTGUN',     label = 'Fusil à pompe' },
    { id = 'WEAPON_SNIPERRIFLE',     label = 'Sniper' },
    { id = 'WEAPON_FIREEXTINGUISHER',label = 'Extincteur' },
}

-- =========================================================
--  MONDE
-- =========================================================
Config.World = {
    defaultWeather = 'EXTRASUNNY',
    startHour      = 12,
    minuteDuration = 2000, -- ms réels pour 1 minute en jeu
}

Config.Weathers = {
    { id = 'EXTRASUNNY', label = 'Grand soleil' },
    { id = 'CLEAR',      label = 'Dégagé' },
    { id = 'CLOUDS',     label = 'Nuageux' },
    { id = 'OVERCAST',   label = 'Couvert' },
    { id = 'CLEARING',   label = 'Éclaircies' },
    { id = 'RAIN',       label = 'Pluie' },
    { id = 'THUNDER',    label = 'Orage' },
    { id = 'SMOG',       label = 'Smog' },
    { id = 'FOGGY',      label = 'Brouillard' },
    { id = 'SNOWLIGHT',  label = 'Neige légère' },
    { id = 'XMAS',       label = 'Neige' },
    { id = 'BLIZZARD',   label = 'Blizzard' },
    { id = 'HALLOWEEN',  label = 'Halloween' },
    { id = 'NEUTRAL',    label = 'Neutre' },
}

-- =========================================================
--  ÉDITEUR DE MAP
-- =========================================================
Config.Editor = {
    minLevel       = 40,     -- niveau minimum (40 = SuperAdmin, 100 = Fondateur)
    streamDistance = 150.0,  -- distance d'apparition des props / PNJ / plants
    placeDistance  = 25.0,   -- portée du placement
    rotateStep     = 7.5,    -- degrés par cran de molette
    heightSpeed    = 0.02,   -- vitesse de montée / descente
    snapToGround   = true,   -- au début d'un placement, l'objet est collé au sol (G pour changer)
    magnetRange    = 1.6,    -- aimant : distance (m) entre le point visé et un prop pour s'y coller

    -- Points de spawn : ajoutés automatiquement à spawnmanager s'il tourne
    -- (serveur standalone). Pour ESX / QBCore : export GetSpawnPoints().
    useSpawnmanager = true,
    spawnModel      = 'mp_m_freemode_01',

    quickProps = {
        'prop_roadcone02a', 'prop_barrier_work05', 'prop_mp_barrier_02b', 'prop_bench_01a',
        'prop_table_03', 'prop_chair_01a', 'prop_gazebo_02', 'prop_tool_box_04',
        'prop_dumpster_01a', 'prop_bin_05a', 'prop_atm_01', 'prop_vend_soda_01',
        'prop_beach_fire', 'prop_tent_01', 'prop_generator_03b', 'prop_worklight_03b',
    },
    quickPeds = {
        'a_m_y_business_01', 's_m_m_security_01', 's_m_y_cop_01', 'a_f_y_hipster_01',
        'a_m_m_farmer_01', 's_m_y_dealer_01', 'g_m_y_mexgoon_01', 's_m_m_doctor_01',
        'a_m_m_hillbilly_01', 's_f_y_shop_mid',
    },
    scenarios = {
        { id = '',                              label = 'Aucune (debout)' },
        { id = 'WORLD_HUMAN_STAND_IMPATIENT',   label = 'Attend' },
        { id = 'WORLD_HUMAN_GUARD_STAND',       label = 'Garde' },
        { id = 'WORLD_HUMAN_SMOKING',           label = 'Fume' },
        { id = 'WORLD_HUMAN_CLIPBOARD',         label = 'Bloc-notes' },
        { id = 'WORLD_HUMAN_STAND_MOBILE',      label = 'Téléphone' },
        { id = 'WORLD_HUMAN_AA_COFFEE',         label = 'Café' },
        { id = 'WORLD_HUMAN_LEANING',           label = 'Appuyé' },
        { id = 'WORLD_HUMAN_DRINKING',          label = 'Boit' },
        { id = 'WORLD_HUMAN_COP_IDLES',         label = 'Policier' },
        { id = 'WORLD_HUMAN_GARDENER_PLANT',    label = 'Jardine' },
        { id = 'WORLD_HUMAN_HANG_OUT_STREET',   label = 'Traîne' },
        { id = 'WORLD_HUMAN_MUSCLE_FLEX',       label = 'Muscu' },
    },

    -- Préréglages des zones de récolte (tout reste modifiable dans le menu)
    -- blipSprite : icône sur la carte (docs.fivem.net/docs/game-references/blips)
    harvestPresets = {
        { id = 'weed',      icon = '🌿', label = 'Weed',                   model = 'prop_weed_01',              item = 'weed_leaf',      itemLabel = 'Feuille de weed',     min = 1, max = 3, duration = 5, regrow = 300, blipSprite = 140 },
        { id = 'weed2',     icon = '🌱', label = 'Weed (petit plant)',     model = 'prop_weed_02',              item = 'weed_leaf',      itemLabel = 'Feuille de weed',     min = 1, max = 2, duration = 4, regrow = 300, blipSprite = 140 },
        { id = 'coca',      icon = '🍃', label = 'Coca',                   model = 'h4_prop_bush_cocaplant_01', item = 'coca_leaf',      itemLabel = 'Feuille de coca',     min = 1, max = 3, duration = 6, regrow = 420, blipSprite = 51 },
        { id = 'mushroom',  icon = '🍄', label = 'Champignons hallucinogènes', model = 'prop_stoneshroom1',     item = 'magic_mushroom', itemLabel = 'Champignon',          min = 1, max = 2, duration = 4, regrow = 360, blipSprite = 51 },
        { id = 'meth',      icon = '⚗️', label = 'Produits chimiques (méth)', model = 'prop_barrel_02a',        item = 'meth_chemicals', itemLabel = 'Produits chimiques', min = 1, max = 2, duration = 6, regrow = 480, blipSprite = 51 },
    },

    -- Préréglages des zones de fouille : on fouille des objets posés à la main
    -- (épaves, bennes, caisses). loot : chaque ligne a sa propre chance (%).
    -- requiredItem : outil obligatoire (vide = aucun), breakChance : % de le casser.
    searchPresets = {
        { id = 'scrapyard', icon = '🚗', label = 'Casse auto (ferraille)', model = 'prop_rub_carwreck_3',
          requiredItem = '', breakChance = 0, duration = 7, cooldown = 600, blipSprite = 1,
          loot = { { item = 'metal_scrap', min = 2, max = 5, chance = 100 } } },
        { id = 'dumpster', icon = '🗑️', label = 'Bennes (ferraille)', model = 'prop_dumpster_01a',
          requiredItem = '', breakChance = 0, duration = 5, cooldown = 480, blipSprite = 1,
          loot = { { item = 'metal_scrap', min = 1, max = 3, chance = 80 } } },
        { id = 'crates_light', icon = '📦', label = 'Caisses de contrebande (pièces légères)', model = 'prop_box_wood02a',
          requiredItem = 'lockpick', breakChance = 15, duration = 10, cooldown = 1200, blipSprite = 110,
          loot = { { item = 'gun_parts_light', min = 1, max = 2, chance = 100 }, { item = 'metal_scrap', min = 1, max = 2, chance = 50 } } },
        { id = 'crates_medium', icon = '🧰', label = 'Caisses militaires (pièces moyennes)', model = 'prop_box_ammo04a',
          requiredItem = 'crowbar', breakChance = 10, duration = 14, cooldown = 1800, blipSprite = 110,
          loot = { { item = 'gun_parts_medium', min = 1, max = 2, chance = 100 } } },
        { id = 'crates_heavy', icon = '🪖', label = 'Cargaison militaire (pièces lourdes)', model = 'prop_mil_crate_01',
          requiredItem = 'crowbar', breakChance = 20, duration = 20, cooldown = 3600, blipSprite = 110,
          loot = { { item = 'gun_parts_heavy', min = 1, max = 1, chance = 70 }, { item = 'gun_parts_medium', min = 1, max = 1, chance = 40 } } },
    },

    -- Rôles des PNJ (tout reste modifiable dans le menu après la pose)
    -- buyer : ce que le PNJ rachète (prix au hasard entre min et max, par unité)
    -- shop  : ce que le PNJ vend
    -- payment : 'cash' (liquide), 'bank' (banque) ou 'item' (paymentItem, ex. argent sale)
    -- hours : heures de présence (nil = toujours là), ex. de 20 h à 5 h
    npcPresets = {
        { id = 'decor', icon = '🧍', label = 'Décor (aucun rôle)' },
        { id = 'buy_weed', icon = '🌿', label = 'Acheteur de weed', scenario = 'WORLD_HUMAN_SMOKING', name = 'Client louche',
          npc = { payment = 'cash', hours = { from = 20, to = 5 },
                  buyer = { items = { { item = 'weed_pouch', min = 80, max = 120 } }, maxPerSale = 10, cooldown = 60, policeChance = 10, minPolice = 0 } } },
        { id = 'buy_coke', icon = '❄️', label = 'Acheteur de cocaïne', scenario = 'WORLD_HUMAN_STAND_IMPATIENT', name = 'Client',
          npc = { payment = 'cash', hours = { from = 21, to = 4 },
                  buyer = { items = { { item = 'cocaine', min = 180, max = 250 } }, maxPerSale = 5, cooldown = 120, policeChance = 20, minPolice = 1 } } },
        { id = 'buy_meth', icon = '⚗️', label = 'Acheteur de méth', scenario = 'WORLD_HUMAN_STAND_IMPATIENT', name = 'Client',
          npc = { payment = 'cash', hours = { from = 22, to = 5 },
                  buyer = { items = { { item = 'meth', min = 220, max = 300 } }, maxPerSale = 5, cooldown = 120, policeChance = 25, minPolice = 1 } } },
        { id = 'buy_shroom', icon = '🍄', label = 'Acheteur de champignons', scenario = 'WORLD_HUMAN_SMOKING', name = 'Hippie',
          npc = { payment = 'cash',
                  buyer = { items = { { item = 'dried_mushroom', min = 60, max = 90 } }, maxPerSale = 10, cooldown = 60, policeChance = 5, minPolice = 0 } } },
        { id = 'buy_all', icon = '💰', label = 'Grossiste (toutes drogues)', scenario = 'WORLD_HUMAN_GUARD_STAND', name = 'Grossiste',
          npc = { payment = 'cash', hours = { from = 0, to = 4 },
                  buyer = { items = { { item = 'weed_pouch', min = 60, max = 90 }, { item = 'cocaine', min = 150, max = 200 },
                                      { item = 'meth', min = 180, max = 240 }, { item = 'dried_mushroom', min = 45, max = 70 } },
                            maxPerSale = 50, cooldown = 600, policeChance = 35, minPolice = 2 } } },
        { id = 'tools', icon = '🧰', label = 'Vendeur d\'outils', scenario = 'WORLD_HUMAN_CLIPBOARD', name = 'Quincaillier',
          npc = { payment = 'cash', shop = { items = { { item = 'lockpick', price = 150 }, { item = 'crowbar', price = 350 } } } } },
        { id = 'shop', icon = '🛒', label = 'Petit commerce', scenario = 'WORLD_HUMAN_STAND_IMPATIENT', name = 'Vendeur',
          npc = { payment = 'cash', shop = { items = { { item = 'water', price = 5 }, { item = 'burger', price = 12 } } } } },
        { id = 'clothing', icon = '👕', label = 'Boutique de vêtements', scenario = 'WORLD_HUMAN_STAND_IMPATIENT', name = 'Vendeuse',
          npc = { payment = 'cash', clothing = { name = 'Binco', multiplier = 100, categories = {} } } },
        { id = 'clothing_lux', icon = '👔', label = 'Boutique de luxe', scenario = 'WORLD_HUMAN_CLIPBOARD', name = 'Conseiller',
          npc = { payment = 'cash', clothing = { name = 'Ponsonbys', multiplier = 250, categories = {} } } },
        { id = 'barber', icon = '💈', label = 'Coiffeur / barbier', scenario = 'WORLD_HUMAN_STAND_IMPATIENT', name = 'Coiffeur',
          npc = { payment = 'cash', barber = { name = 'Salon de coiffure', payChoice = true, blip = true } } },
        { id = 'barber_lux', icon = '✂️', label = 'Salon de luxe', scenario = 'WORLD_HUMAN_CLIPBOARD', name = 'Styliste',
          npc = { payment = 'bank', barber = { name = 'Salon Prestige', payChoice = true, blip = true, specialEyes = true,
                  prices = { hair = 450, hair_color = 250, hair_highlight = 180, beard = 180, beard_color = 120, beard_highlight = 90,
                             brows = 120, brows_color = 80, eyes = 600, chest = 90, chest_color = 60 } } } },
        { id = 'garage', icon = '🚗', label = 'Garage (location)', scenario = 'WORLD_HUMAN_CLIPBOARD', name = 'Garagiste',
          npc = { payment = 'bank', garage = { plate = 'LOC', fuel = 100, warp = true, onePerPlayer = true, blip = true,
                  vehicles = { { model = 'blista', label = 'Blista', price = 150 }, { model = 'panto', label = 'Panto', price = 100 },
                               { model = 'faggio', label = 'Scooter Faggio', price = 50 } } } } },
        { id = 'garage_job', icon = '🚓', label = 'Garage de service (métier)', scenario = 'WORLD_HUMAN_CLIPBOARD', name = 'Garage de service',
          npc = { payment = 'cash', garage = { plate = 'SRV', fuel = 100, warp = true, onePerPlayer = true,
                  jobs = { { job = 'police', grade = 0 } },
                  vehicles = { { model = 'police', label = 'Cruiser', price = 0 }, { model = 'police2', label = 'Buffalo', price = 0 } } } } },
    },

    -- Animations possibles pendant une fabrication
    craftScenarios = {
        { id = 'PROP_HUMAN_PARKING_METER', label = 'Manipule (labo)' },
        { id = 'WORLD_HUMAN_WELDING',      label = 'Soude (armes)' },
        { id = 'WORLD_HUMAN_HAMMERING',    label = 'Martèle' },
        { id = 'WORLD_HUMAN_CLIPBOARD',    label = 'Note' },
        { id = 'PROP_HUMAN_BUM_BIN',       label = 'Fouille' },
    },

    -- Préréglages des ateliers de fabrication / transformation
    craftPresets = {
        { id = 'weed_lab', icon = '🌿', label = 'Traitement de la weed', model = 'bkr_prop_weed_table_01a', scenario = 'PROP_HUMAN_PARKING_METER', blipSprite = 140,
          recipes = {
            { label = 'Pochon de weed', output = 'weed_pouch', count = 1, duration = 6, inputs = { { item = 'weed_leaf', count = 3 } } },
          } },
        { id = 'coke_lab', icon = '❄️', label = 'Laboratoire de cocaïne', model = 'bkr_prop_coke_table01a', scenario = 'PROP_HUMAN_PARKING_METER', blipSprite = 51,
          recipes = {
            { label = 'Cocaïne', output = 'cocaine', count = 1, duration = 8, inputs = { { item = 'coca_leaf', count = 4 } } },
          } },
        { id = 'meth_lab', icon = '⚗️', label = 'Laboratoire de méth', model = 'bkr_prop_meth_table01a', scenario = 'PROP_HUMAN_PARKING_METER', blipSprite = 51,
          recipes = {
            { label = 'Méthamphétamine', output = 'meth', count = 1, duration = 10, inputs = { { item = 'meth_chemicals', count = 3 } } },
          } },
        { id = 'mushroom_lab', icon = '🍄', label = 'Séchage des champignons', model = 'prop_table_03', scenario = 'PROP_HUMAN_PARKING_METER', blipSprite = 51,
          recipes = {
            { label = 'Champignons séchés', output = 'dried_mushroom', count = 1, duration = 5, inputs = { { item = 'magic_mushroom', count = 2 } } },
          } },
        { id = 'guns_light', icon = '🔫', label = 'Établi : armes légères', model = 'prop_tool_bench02', scenario = 'WORLD_HUMAN_WELDING', blipSprite = 110,
          recipes = {
            { label = 'Pistolet SNS',       output = 'WEAPON_SNSPISTOL',    count = 1, duration = 15, inputs = { { item = 'metal_scrap', count = 10 }, { item = 'gun_parts_light', count = 2 } } },
            { label = 'Pistolet',           output = 'WEAPON_PISTOL',       count = 1, duration = 20, inputs = { { item = 'metal_scrap', count = 15 }, { item = 'gun_parts_light', count = 3 } } },
            { label = 'Pistolet de combat', output = 'WEAPON_COMBATPISTOL', count = 1, duration = 25, inputs = { { item = 'metal_scrap', count = 20 }, { item = 'gun_parts_light', count = 4 } } },
          } },
        { id = 'guns_medium', icon = '🔫', label = 'Établi : armes moyennes', model = 'prop_tool_bench02', scenario = 'WORLD_HUMAN_WELDING', blipSprite = 110,
          recipes = {
            { label = 'Micro SMG',     output = 'WEAPON_MICROSMG',    count = 1, duration = 30, inputs = { { item = 'metal_scrap', count = 30 }, { item = 'gun_parts_medium', count = 6 } } },
            { label = 'SMG',           output = 'WEAPON_SMG',         count = 1, duration = 35, inputs = { { item = 'metal_scrap', count = 35 }, { item = 'gun_parts_medium', count = 8 } } },
            { label = 'Fusil à pompe', output = 'WEAPON_PUMPSHOTGUN', count = 1, duration = 35, inputs = { { item = 'metal_scrap', count = 40 }, { item = 'gun_parts_medium', count = 8 } } },
          } },
        { id = 'guns_heavy', icon = '💣', label = 'Établi : armes lourdes', model = 'prop_tool_bench02', scenario = 'WORLD_HUMAN_WELDING', blipSprite = 110,
          recipes = {
            { label = 'Fusil d\'assaut', output = 'WEAPON_ASSAULTRIFLE', count = 1, duration = 50, inputs = { { item = 'metal_scrap', count = 60 }, { item = 'gun_parts_heavy', count = 12 } } },
            { label = 'Carabine',        output = 'WEAPON_CARBINERIFLE', count = 1, duration = 50, inputs = { { item = 'metal_scrap', count = 60 }, { item = 'gun_parts_heavy', count = 12 } } },
            { label = 'Mitrailleuse',    output = 'WEAPON_MG',           count = 1, duration = 70, inputs = { { item = 'metal_scrap', count = 90 }, { item = 'gun_parts_heavy', count = 20 } } },
          } },
    },

    -- Nouveaux arrivants : délai avant la téléportation après le chargement
    -- du personnage (laisse le temps à ESX / QBCore de finir le spawn)
    newcomerDelay = 2500,

    -- Supprimer un élément de l'éditeur en noclip demande deux appuis sur G
    confirmDelete = true,
}

-- =========================================================
--  COIFFEUR / BARBIER
--  Pose un PNJ dans l'éditeur (F10 › Éditeur › PNJ), choisis le rôle
--  « Coiffeur » et règle ses prix. Les joueurs appuient sur E devant lui.
-- =========================================================
Config.Barber = {
    enabled = true,

    -- Où enregistrer la nouvelle tête après paiement :
    --  'auto'     : illenium-appearance / fivem-appearance, sinon esx_skin, sinon 'internal'
    --  'illenium' : illenium-appearance (Qbox / QBCore)
    --  'esx'      : esx_skin + skinchanger
    --  'internal' : sauvegardé par le menu (data/barber_looks.json) et remis à chaque spawn
    saveMode = 'auto',

    -- Prix par défaut d'un nouveau coiffeur (modifiables PNJ par PNJ dans l'éditeur)
    defaultPrices = {
        hair = 150, hair_color = 80, hair_highlight = 60,
        beard = 60, beard_color = 40, beard_highlight = 30,
        brows = 40, brows_color = 25,
        eyes = 200,
        chest = 30, chest_color = 20,
    },

    blipSprite = 71,          -- icône de ciseaux
    blipColor  = 4,
    blipScale  = 0.75,

    beardForFemale = false,   -- montrer l'onglet Barbe aux personnages féminins
    chestForFemale = false,   -- montrer l'onglet Torse aux personnages féminins
    hideAccessories = true,   -- retire chapeau, lunettes et masque pendant la coupe (remis à la sortie)

    -- Coupes cachées (bugs connus du jeu : coiffure « vision nocturne »)
    hairBlacklist = { male = { 23 }, female = { 24 } },

    -- Noms de tes coupes ajoutées (addon) : [numéro] = 'Nom'
    customHairLabels = { male = {}, female = {} },
}

-- =========================================================
--  INVENTAIRE (pour les récoltes)
--  'auto' détecte ox_inventory, qs-inventory, qb-core puis es_extended.
--  'custom' utilise la fonction ci-dessous.
--  ⚠ L'objet (ex : weed_leaf) doit exister dans ton inventaire.
-- =========================================================
Config.Inventory = 'auto'

Config.CustomAddItem = function(source, item, count)
    -- Exemple : return exports['mon_inventaire']:AddItem(source, item, count)
    return false, 'noinv'
end
Config.CustomRemoveItem = function(source, item, count)
    return false
end
Config.CustomGetItemCount = function(source, item)
    return 0
end
-- Liste des objets pour l'onglet Objets en mode 'custom' (optionnel) :
-- doit renvoyer { { name = 'bread', label = 'Pain', weight = 100, image = 'nui://…' }, … }
Config.CustomGetItemList = nil

-- =========================================================
--  RÉANIMATION
--  'auto' : utilise qbx_medical (Qbox), esx_ambulancejob ou qb-ambulancejob
--  s'ils tournent, puis vérifie : si le joueur est encore mort, la
--  réanimation intégrée prend le relais. 'custom' : fonction ci-dessous (client).
-- =========================================================
Config.Revive = 'auto'
Config.ReviveAreaRadius = 30.0          -- rayon du raccourci "Réanimer autour de moi"
Config.CustomRevive = function()
    -- Exemple : TriggerEvent('mon_ambulance:revive')
end

-- =========================================================
--  ZONES (safe zones, quartiers, zones à message)
-- =========================================================
Config.Zones = {
    height = 80.0,   -- hauteur couverte au-dessus du point le plus haut de la zone
    depth  = 15.0,   -- profondeur couverte sous le point le plus bas
    -- Couleurs proposées (blip = couleur sur la carte)
    colors = {
        { id = 'green',  label = 'Vert',   hex = '#4fb3a9', blip = 2 },
        { id = 'blue',   label = 'Bleu',   hex = '#3b6fe0', blip = 3 },
        { id = 'red',    label = 'Rouge',  hex = '#e0433b', blip = 1 },
        { id = 'gold',   label = 'Or',     hex = '#d9b56a', blip = 5 },
        { id = 'orange', label = 'Orange', hex = '#e07a3f', blip = 47 },
        { id = 'purple', label = 'Violet', hex = '#9b6be0', blip = 27 },
        { id = 'pink',   label = 'Rose',   hex = '#e06bb5', blip = 8 },
        { id = 'white',  label = 'Blanc',  hex = '#ecf0f8', blip = 0 },
    },
    -- Icônes proposées pour le point de la zone sur la carte (n° de blip GTA).
    -- N'importe quel autre numéro peut être tapé dans le menu :
    -- liste complète sur docs.fivem.net/docs/game-references/blips
    icons = {
        { id = 357, emoji = '🅿️', label = 'Garage',            cat = 'Véhicules' },
        { id = 225, emoji = '🚗', label = 'Voiture',           cat = 'Véhicules' },
        { id = 326, emoji = '🚘', label = 'Concession auto',   cat = 'Véhicules' },
        { id = 446, emoji = '🔧', label = 'Mécanicien',        cat = 'Véhicules' },
        { id = 68,  emoji = '🚛', label = 'Fourrière',         cat = 'Véhicules' },
        { id = 361, emoji = '⛽', label = 'Station-service',   cat = 'Véhicules' },
        { id = 410, emoji = '🚤', label = 'Bateaux',           cat = 'Véhicules' },
        { id = 359, emoji = '🛩️', label = 'Hangar à avions',   cat = 'Véhicules' },
        { id = 43,  emoji = '🚁', label = 'Hélicoptère',       cat = 'Véhicules' },
        { id = 60,  emoji = '👮', label = 'Police',            cat = 'Services' },
        { id = 61,  emoji = '🏥', label = 'Hôpital',           cat = 'Services' },
        { id = 108, emoji = '💵', label = 'Banque',            cat = 'Commerces' },
        { id = 52,  emoji = '🛒', label = 'Supérette',         cat = 'Commerces' },
        { id = 73,  emoji = '👕', label = 'Vêtements',         cat = 'Commerces' },
        { id = 71,  emoji = '💈', label = 'Coiffeur',          cat = 'Commerces' },
        { id = 75,  emoji = '🖋️', label = 'Tatoueur',          cat = 'Commerces' },
        { id = 110, emoji = '🔫', label = 'Armurerie',         cat = 'Commerces' },
        { id = 93,  emoji = '🍸', label = 'Bar',               cat = 'Commerces' },
        { id = 679, emoji = '🎰', label = 'Casino',            cat = 'Commerces' },
        { id = 40,  emoji = '🏠', label = 'Maison',            cat = 'Lieux' },
        { id = 487, emoji = '🛡️', label = 'Bouclier (zone sûre)', cat = 'Lieux' },
        { id = 280, emoji = '🧍', label = 'Personne',          cat = 'Lieux' },
        { id = 469, emoji = '🌿', label = 'Cannabis',          cat = 'Lieux' },
        { id = 1,   emoji = '⚪', label = 'Point simple',      cat = 'Lieux' },
    },
}

-- =========================================================
--  TRANSFORMATION EN ANIMAL (SuperAdmin et Fondateur)
--  Ton apparence est sauvegardée avant et restaurée au retour
--  (illenium-appearance / fivem-appearance détectés automatiquement).
-- =========================================================
Config.Animals = {
    { cat = 'Chiens et chats', icon = '🐕', list = {
        { model = 'a_c_chop',       label = 'Chop' },
        { model = 'a_c_chop_02',    label = 'Chop (variante)' },
        { model = 'a_c_husky',      label = 'Husky' },
        { model = 'a_c_retriever',  label = 'Golden retriever' },
        { model = 'a_c_shepherd',   label = 'Berger allemand' },
        { model = 'a_c_rottweiler', label = 'Rottweiler' },
        { model = 'a_c_poodle',     label = 'Caniche' },
        { model = 'a_c_pug',        label = 'Carlin' },
        { model = 'a_c_pug_02',     label = 'Carlin (variante)' },
        { model = 'a_c_westy',      label = 'Westie' },
        { model = 'a_c_cat_01',     label = 'Chat' },
    } },
    { cat = 'Ferme', icon = '🐄', list = {
        { model = 'a_c_cow',        label = 'Vache' },
        { model = 'a_c_pig',        label = 'Cochon' },
        { model = 'a_c_hen',        label = 'Poule' },
        { model = 'a_c_rabbit_01',  label = 'Lapin' },
        { model = 'a_c_rabbit_02',  label = 'Lapin (variante)' },
    } },
    { cat = 'Animaux sauvages', icon = '🦌', list = {
        { model = 'a_c_deer',       label = 'Cerf' },
        { model = 'a_c_deer_02',    label = 'Biche' },
        { model = 'a_c_boar',       label = 'Sanglier' },
        { model = 'a_c_boar_02',    label = 'Sanglier (variante)' },
        { model = 'a_c_coyote',     label = 'Coyote' },
        { model = 'a_c_coyote_02',  label = 'Coyote (variante)' },
        { model = 'a_c_mtlion',     label = 'Puma' },
        { model = 'a_c_mtlion_02',  label = 'Puma (variante)' },
        { model = 'a_c_panther',    label = 'Panthère' },
        { model = 'a_c_chimp',      label = 'Chimpanzé' },
        { model = 'a_c_chimp_02',   label = 'Chimpanzé (variante)' },
        { model = 'a_c_rhesus',     label = 'Singe rhésus' },
        { model = 'a_c_rat',        label = 'Rat' },
    } },
    { cat = 'Oiseaux', icon = '🐦', list = {
        { model = 'a_c_chickenhawk', label = 'Faucon' },
        { model = 'a_c_cormorant',  label = 'Cormoran' },
        { model = 'a_c_crow',       label = 'Corbeau' },
        { model = 'a_c_pigeon',     label = 'Pigeon' },
        { model = 'a_c_seagull',    label = 'Mouette' },
    } },
    { cat = 'Animaux marins (dans l\'eau)', icon = '🐬', list = {
        { model = 'a_c_dolphin',    label = 'Dauphin' },
        { model = 'a_c_humpback',   label = 'Baleine à bosse' },
        { model = 'a_c_killerwhale', label = 'Orque' },
        { model = 'a_c_sharkhammer', label = 'Requin-marteau' },
        { model = 'a_c_sharktiger', label = 'Requin-tigre' },
        { model = 'a_c_stingray',   label = 'Raie' },
        { model = 'a_c_fish',       label = 'Poisson' },
    } },
    { cat = 'Créatures', icon = '👽', list = {
        { model = 'ig_orleans',        label = 'Bigfoot' },
        { model = 'u_m_m_yeti',        label = 'Yéti' },
        { model = 's_m_m_movalien_01', label = 'Extraterrestre' },
    } },
}

-- =========================================================
--  BESOINS DU STAFF EN SERVICE
--  En service staff, la faim et la soif sont FIGÉES à leur niveau
--  actuel (elles ne baissent plus). En mode RP, elles reprennent
--  normalement à partir de ce niveau. Manger ou boire en service
--  fait toujours remonter les jauges.
-- =========================================================
Config.StaffNeeds = {
    enabled  = true,
    interval = 10,      -- secondes entre deux vérifications
    stress   = false,   -- true = fige aussi le stress (Qbox / QBCore)
}

-- =========================================================
--  PRISON (jail)
-- =========================================================
Config.Jail = {
    radius = 45.0,          -- distance max autour du point de jail avant d'être ramené
    disableWeapons = true,  -- pas d'armes en prison
    durations = { 5, 10, 15, 30, 60, 120 }, -- minutes proposées dans le menu
}

-- =========================================================
--  PORTES VERROUILLABLES
-- =========================================================
Config.Doors = {
    interactDistance = 2.2,  -- distance par défaut pour interagir avec une porte (réglable porte par porte dans le menu)
    minDistance = 0.8, maxDistance = 15.0,   -- limites du réglage par porte
    codeMin = 4, codeMax = 8, -- longueur du code (chiffres)
    maxTries = 5,             -- essais de code ratés avant blocage
    lockout = 60,             -- secondes de blocage après trop d'essais
}

-- =========================================================
--  POLICE (pour les PNJ acheteurs de drogue)
--  Métiers comptés comme police (en service) : alerte et nombre minimum.
-- =========================================================
Config.PoliceJobs = { 'police', 'sheriff', 'lspd', 'bcso', 'sasp' }
Config.PoliceAlertBlip = 60   -- secondes d'affichage du point d'alerte sur la carte

-- =========================================================
--  ANNONCES SERVEUR
--  Images proposées dans le menu ('logo' = logo du serveur).
--  Tu peux aussi coller un lien d'image (https://…png/jpg/gif)
--  directement dans le menu. Évite les liens Discord, ils expirent.
-- =========================================================
Config.AnnounceImages = {
    { label = 'Logo Elyzea', url = 'logo' },
    -- { label = 'Événement', url = 'https://i.imgur.com/xxxxxxx.png' },
}
