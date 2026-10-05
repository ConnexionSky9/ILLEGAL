# elyzea_illegal · Elyzea Illégal

Gangs, organisations et cartels pour Qbox (ox_lib, oxmysql, ox_inventory), administrés depuis
**admin_menu › ILLEGAL** et gérés en jeu par chaque groupe depuis sa tablette (**F5** ou son **PED**).

## Installation
1. Place `elyzea_illegal` dans `resources/`.
2. `server.cfg`, **après** `admin_menu` :
   ```cfg
   ensure elyzea_illegal
   ```
3. Les tables sont créées automatiquement au premier démarrage (`sql/install.sql` si tu préfères les créer à la main).
4. Remplace le dossier `admin_menu` par celui de ce dépôt (seule la section ILLEGAL y est ajoutée, voir plus bas).
5. En jeu : **F10 › ILLEGAL**. Le Fondateur a la permission d'office, le SuperAdmin la reçoit une fois ;
   pour les autres grades staff : onglet **Grades** du menu, permission « ILLEGAL » (catégorie *Illégal*).

## Ce qui a été ajouté dans admin_menu (et rien d'autre)
| Fichier | Modification |
|---|---|
| `server/illegal.lua` | **nouveau** : pont vers cette ressource (même modèle que Concession / LsCustom) |
| `html/illegal.js` | **nouveau** : onglet ILLEGAL (réutilise les composants du menu : `formModal`, `confirmBox`, `.section`, `.stats`, `.segmented`…) |
| `fxmanifest.lua` | +2 lignes : `server/illegal.lua`, `html/illegal.js` |
| `html/index.html` | +1 ligne : `<script src="illegal.js">` |
| `config.lua` | +1 permission `illegal_staff` et un bloc `Config.Illegal = { resource = 'elyzea_illegal' }` |

Aucune ligne existante n'est modifiée ni supprimée (`git diff` : 14 lignes ajoutées, 0 supprimée).

## Utilisation
**Staff (F10 › ILLEGAL)** : dashboard (groupes, membres, gangs / organisations / cartels, argent propre et sale totaux),
liste des groupes, création (nom interne unique, nom affiché, type, description, couleur, PED et sa position), puis pour
chaque groupe : *Informations · Membres · Grades · Finances · PED · Commandes · Paramètres*. La suppression d'un groupe
demande une confirmation puis de taper son nom interne.

**Joueurs** : **F5 › <Nom du groupe>** ou **E** à côté du PED du groupe ouvrent la tablette du groupe :
membres (promouvoir, rétrograder, changer de grade, expulser, profil, recruter par ID), grades (créer, modifier,
supprimer, réorganiser, permissions), finances (argent propre / sale séparés, dépôt, retrait, historique),
commandes (catalogue, commander, valider / refuser, récupérer) et paramètres. Chaque bouton n'apparaît que si le grade le permet.

## Sécurité
- Le client n'envoie **jamais** son groupe : à chaque action le serveur relit personnage (Qbox) → groupe → grade → permission.
- Hiérarchie : un joueur n'agit que sur les grades / membres **inférieurs** au sien et ne donne que des permissions qu'il possède.
  Seul le staff crée un grade chef.
- Tablette ouverte obligatoire (F5, ou à côté du PED, distance revérifiée), onglets autorisés vérifiés côté serveur.
- Argent : montants entiers > 0 et plafonnés, verrou par groupe (pas de double transaction), base qui refuse tout solde négatif,
  argent du joueur retiré avant crédit et remboursé en cas d'échec, commande validée une seule fois (changement d'état conditionnel).
- Seul le staff peut lier une commande à un objet d'inventaire livré.
- Anti-spam sur toutes les actions ; les tentatives refusées sont écrites en console.

## Configuration (`config.lua`)
Compte de l'argent propre (`cash` / `bank`), argent sale (objet `black_money` ou compte), touche F5 et mode (`context` / `direct`),
PED (modèle par défaut, distances, animation), types de groupes, catégories de commandes et grades créés par défaut pour chaque type.

**Tu as déjà un menu F5 ?** `Config.F5.enabled = false`, puis dans ton menu :
```lua
local label = exports.elyzea_illegal:GetGroupLabel()   -- nil si le joueur n'a pas de groupe
if label then -- ajoute une entrée « label » qui appelle :
    exports.elyzea_illegal:OpenTablet()
end
```

## Exports serveur
`GetPlayerGroup(src)` → `{ id, name, label, type, grade, gradeLabel, gradeLevel, boss }` · `HasGroupPermission(src, perm)`

## Logs
Toutes les actions passent par `Log()` (`server/logs.lua`) : console `[ILLEGAL]`, table `illegal_logs`,
onglet **Logs** du menu staff (et son webhook Discord), webhook propre facultatif (`Config.DiscordWebhook`).

## Architecture
```
config.lua            réglages
shared/               permissions, onglets, validation des données
server/database.lua   tout le SQL (oxmysql)
server/cache.lua      données en mémoire (aucune requête pour lire)
server/groups|grades|members|finances|peds|orders.lua   services réutilisables
server/tablet.lua     actions des joueurs (contrôles de sécurité)
server/admin.lua      exports AdminData / AdminAction pour admin_menu
server/sync.lua       mise à jour des tablettes ouvertes, du F5 et des PED
client/               F5, PED (apparition par proximité), NUI
html/                 tablette du groupe
```

## Tests (hors jeu)
Depuis la racine du dépôt : `lua5.4 tests/run.lua` (serveur : permissions, hiérarchie, argent, isolation des groupes, persistance…),
`lua5.4 tests/bridge.lua` (pont admin_menu) et `FIXTURES=/tmp/fx lua5.4 tests/run.lua && FIXTURES=/tmp/fx node tests/ui.js` (rendu des interfaces).
