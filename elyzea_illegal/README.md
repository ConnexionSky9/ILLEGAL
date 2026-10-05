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

## Mise à jour
Remplace **tout** le dossier `elyzea_illegal` (de nouveaux fichiers sont parfois ajoutés), puis dans la console serveur :
```
refresh
ensure elyzea_illegal
```
`refresh` est obligatoire : sans lui, FiveM ne relit pas `fxmanifest.lua` et les nouveaux fichiers ne sont pas chargés.
Au démarrage, la console indique en rouge `[ILLEGAL] Fichiers non chargés : …` s'il en manque un.
Un ancien `config.lua` reste utilisable : les réglages ajoutés depuis sont complétés par défaut (`shared/constants.lua`).

## Ce qui a été ajouté dans admin_menu (et rien d'autre)
| Fichier | Modification |
|---|---|
| `server/illegal.lua` | **nouveau** : pont vers cette ressource (même modèle que Concession / LsCustom) + groupes ILLEGAL dans les coffres de l'éditeur de map + export `GetOnDutyPolice` (policiers en service via `Bridge.IsPolice`, système existant du menu) |
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

**Commandes et livraison** :
1. *ILLEGAL › Gérer › Commandes* (ou « pour tous les groupes » sur la liste) : choisis l'**objet** (liste ox_inventory), la quantité livrée,
   le **prix** et le compte (propre / sale / au choix). Une fois enregistré, les membres le voient dans leur tablette et peuvent commander.
2. Un membre commande : le **coffre du groupe paie** (ou à la validation si `Config.Orders.requireValidation = true`).
   Notification sur son **téléphone** : « en préparation, disponible dans 5 minutes ».
3. 5 minutes plus tard : notification « prête », **point GPS** et **blip** sur sa carte, dans un lieu caché à plus de 1 500 m de lui.
4. Sur place : **1 chef bras croisés** et **5 gardes armés** (animation de garde), le **sac** posé devant le chef.
   **E** sur le sac : les objets arrivent dans son inventaire, les PNJ disparaissent.
   Seul celui qui a commandé voit les PNJ et peut ramasser le sac (distance et identité vérifiées par le serveur).
- Lieux : *ILLEGAL › Points de livraison › 📍 Ajouter un point à ma position* (chef placé à ta position, tourné dans ta direction).
  Tant qu'aucun point n'est placé, les 10 lieux de `Config.Delivery.defaultSpots` sont utilisés (coordonnées approximatives : le sol est recalculé en jeu,
  mais place tes propres points pour être sûr qu'ils soient bien cachés).
- Le staff voit chaque livraison (statut, lieu, heure) et peut la **rendre prête tout de suite** (tests).
- Téléphone : **lb-phone** détecté automatiquement, sinon notification ox_lib. Autre téléphone : `Config.PhoneNotify` dans `config.lua`.

**Coffre du groupe** : *ILLEGAL › Gérer › Coffre › 📍 Placer un coffre à ma position* : nom, objet (coffre-fort, caisse…),
**poids maximum (kg)** et **nombre de places** au choix, modifiables ensuite ; déplacer, téléporter, supprimer (le contenu est conservé
et revient si un coffre est replacé). Les membres l'ouvrent avec **E** à côté. Accès : permission **« Accès au coffre du groupe »**
des grades : le OG la donne aux grades qu'il veut depuis sa tablette (*Grades › Modifier*), le staff depuis *Grades › Permissions*.
Le serveur vérifie groupe, grade et distance, et un hook ox_inventory bloque toute ouverture qui ne passe pas par là.

**Coffres de l'éditeur de map** : *Éditeur de map › Coffres › Groupes illégaux* propose aussi les groupes créés dans ILLEGAL
(suffixe « (Illégal) »), avec leurs grades comme grade minimum. Les gangs Qbox fonctionnent comme avant ;
si un gang Qbox porte le même nom interne qu'un groupe ILLEGAL, seul le gang Qbox apparaît dans la liste.
Le grade minimum d'un coffre est plafonné à 100 par l'éditeur : garde des niveaux de grade ≤ 100.

**Joueurs** : **F5 › <Nom du groupe>** ou **E** à côté du PED du groupe ouvrent la tablette du groupe :
membres (promouvoir, rétrograder, changer de grade, expulser, profil, recruter par ID), grades (créer, modifier,
supprimer, réorganiser, permissions), finances (argent propre / sale séparés, dépôt, retrait, historique),
commandes (catalogue, commander, suivi de livraison, bouton « 📍 GPS ») et paramètres. Chaque bouton n'apparaît que si le grade le permet.

## Missions illégales
**Staff : ADMIN › ILLEGAL › Groupes / Missions**
- **Groupes** : liste des groupes (comme avant) + **progression** de chacun (niveau, XP x / y) avec `+ XP`, `− XP`, `Définir XP`, `Définir niveau`, `Réinitialiser`.
- **Missions** : missions en cours (arrêt possible), liste des missions, **niveaux** (ajouter / supprimer le dernier = niveau max, nom, XP requise).
- **Configurer une mission** : Général · Groupes autorisés · Progression · Emplacements · Gardes · Armes · Colis · Livraison · Timer · Récompenses · Téléphone · Cooldown · Sécurité.
  Emplacements et points de livraison se placent à ta position (📍), avec positions des gardes (« + Garde ici »), activation, coordonnées, rayon, téléportation.

**Joueurs : tablette F5 › Missions** : niveau et XP du groupe, missions débloquées (🟢) ou verrouillées (🔒 niveau requis, XP manquante),
cooldown, lancement (permission de grade « Lancer une mission illégale », le chef l'a toujours), mission en cours (rejoindre / abandonner).

**Colis test** : message du numéro inconnu → emplacement tiré au hasard (GPS + zone) → timer (15 min) → 6 gardes (4 au poing, 2 au couteau) →
**ALT** « Fouiller le garde » sur les gardes neutralisés (ox_target s'il est installé, sinon maintenir ALT puis E) → clé → **ALT** « Ouvrir le colis »
(animation) → nouveau GPS vers le point de livraison le plus proche du lancement → **ALT** « Livrer le colis » au PNJ → « Merci pour le service rendu ! »
→ **MISSION TERMINÉE** → argent + objets dans le **coffre du groupe** (une seule fois, jamais au joueur) → **+XP au groupe** → level-up automatique.
À 0 : mission échouée, tout est nettoyé, aucune récompense.

- Gardes : modèle, arme, santé, armure, précision, comportement (passif / méfiant / agressif / très agressif), distances de détection,
  d'agression et de poursuite, retour à la position, poursuite autorisée — créés par le serveur, synchronisés pour tous les participants.
- Clé : garde précis, garde au hasard ou probabilité par fouille ; **toujours trouvable** (dernier garde fouillé, porteur disparu → clé au suivant,
  surbrillance après X fouilles ratées).
- Armes : armes à feu / blanches / explosifs / véhicules autorisés ou non → rien / avertissement / échec (dégâts sur les gardes contrôlés par le serveur).
- Participants : membres du groupe proches du lanceur (rayon réglable), min / max, rejoindre en cours ; porteur du colis déconnecté → le colis passe à un autre.
- Cooldowns mission / groupe / joueur (serveur, conservés après redémarrage via l'historique).
- **Ajouter une mission** : `server/missions/<type>.lua` (`Missions.registerType` + `Missions.registerDefault`) et `client/missions/<type>.lua`
  (`MissionClient.registerType`) ; le moteur (`server/missions/core.lua`) gère niveaux, groupes, cooldowns, participants, timer, récompenses, téléphone, logs.
- Réutilise l'existant : finances du groupe (`Finances.missionReward`), inventaire du coffre (`Stashes.addItem`), téléphone (`PhoneNotify` / lb-phone),
  invite et notifications du MenuStaff, logs (`Log` → onglet Logs du menu + Discord), oxmysql.

### Mission niveau 1 : « Le Fourgon Fantôme »
**Staff : ILLEGAL › Missions › Niveau 1 › Le Fourgon Fantôme** — sections générées depuis le schéma du serveur :
Général · Groupes · Progression · HUD · Scénarios · Recherche · Emplacements · Fourgon · Ennemis · Caisses · Alarmes · Renforts · Transport ·
Livraison · Timer · Récompenses · Bonus · Téléphone · Cooldown · Armes · Sécurité. Toutes les positions : **X / Y / Z / Heading** +
**📍 Définir à ma position** (position relevée par le serveur) + **Y aller**. Aucun mode placement. Listes : ajouter, dupliquer, déplacer,
activer / désactiver, supprimer (scénarios, emplacements, indices, ennemis, vagues, relais, points de livraison…).

Déroulé (machine à états serveur) : `SEARCH_AREA → FIND_CLUES → LOCATE_VAN → INVESTIGATE_VAN → RECOVER_CARGO → TRANSPORT → RELAY → FINAL_DELIVERY → SUCCESS / FAILED`
- Lancement : groupe, **niveau 1** (réglable), cooldowns vérifiés par le serveur ; message du numéro inconnu ; timer 30 min ; d'autres membres peuvent rejoindre.
- Zone de recherche **approximative** → indices (**ALT**) → N indices (réglable) → position exacte ou approximative du fourgon.
- Scénarios A–E (abandonné, accident, surveillé, faux fourgon, déplacé) + scénarios personnalisés, activables, autorisés par emplacement.
- Fourgon : cabine (le code — et le mot de passe du relais si exigé — y est **toujours** trouvable, même pendant le transport), arrière ouvert ou forcé.
- Caisses : la vraie est tirée par le serveur ; caisses sécurisées à code (**vérifié par le serveur**, blocage après N essais → forcer) ;
  fausses caisses : vide / faux contenu / alarme / embuscade (poids réglables).
- Alarmes : déclencheurs (mauvaise caisse, mauvais code, forçage, détection, récupération, faux fourgon) → alertes 1 à 3 (jamais à la baisse) :
  **seuls les policiers en service** reçoivent un blip approximatif (rayon, icône, couleur, durée réglables) + dispatch `elyzea_police` s'il existe.
- Renforts : vagues par niveau d'alerte, avec ou sans véhicules, délai, **toujours loin des joueurs** (distance min / max, points de spawn optionnels).
- Transport : porteur unique ; porteur mort ou parti → marchandise au sol, à ramasser ; point relais (zone / PNJ / véhicule, mot de passe optionnel),
  véhicule de transfert (clés `qbx_vehiclekeys`), poursuite optionnelle.
- Livraison **ALT** au commanditaire → « Merci pour le service rendu ! » → argent + objets **dans le coffre du groupe** + XP (fixe ou aléatoire min–max)
  + bonus (temps restant, aucune alarme, aucune mauvaise caisse, aucun mort, aucune police, sans perte).
- **HUD** discret et configurable (position, taille, opacité, catégories) : objectif, codes, plaques, mots de passe, indices, alerte, timer.
  Les informations importantes **restent affichées** tant qu'elles sont utiles, puis sont marquées « utilisé » ou retirées (réglage) ;
  partage entre participants **ON / OFF** (serveur). Une notification n'est jamais le seul endroit où une information importante apparaît.
- Échec (timer, plus de participants, abandon, arme interdite en mode « échec ») : ennemis, véhicules, objets et blips nettoyés, aucune récompense.

## Interfaces
Même design que le MenuStaff (styles repris tels quels de `admin_menu/html/style.css`) : tablette du groupe, fenêtres,
notifications, menu **F5** (panneau du menu rapide F9) et invite **[E]** « APPUYER POUR … » + nom en doré
pour le PNJ du groupe, le coffre et le sac de livraison.

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
Coffre (`Config.Stash` : objets proposés, poids et places par défaut / maximum, distances),
commandes (`Config.Orders` : validation obligatoire, création par les joueurs), livraison (`Config.Delivery` : délai, distance minimum,
modèles et armes des PNJ, nombre de gardes, animations, sac, blip, lieux par défaut), téléphone (`Config.PhoneNotify`),
compte de l'argent propre (`cash` / `bank`), argent sale (objet `black_money` ou compte), touche F5 et mode (`context` / `direct`),
PED (modèle par défaut, distances, animation), types de groupes, catégories de commandes et grades créés par défaut pour chaque type.

**Tu as déjà un menu F5 ?** `Config.F5.enabled = false`, puis dans ton menu :
```lua
local label = exports.elyzea_illegal:GetGroupLabel()   -- nil si le joueur n'a pas de groupe
if label then -- ajoute une entrée « label » qui appelle :
    exports.elyzea_illegal:OpenTablet()
end
```

## Exports serveur
`GetPlayerGroup(src)` → `{ id, name, label, type, grade, gradeLabel, gradeLevel, boss }` · `HasGroupPermission(src, perm)` ·
`GetGroupList()` → groupes et grades (utilisé par les coffres d'admin_menu)

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
server/deliveries.lua livraison des commandes (lieux, préparation, ramassage du sac)
server/stashes.lua    coffre du groupe (ox_inventory, accès par grade)
server/missions/      moteur des missions (core.lua) et missions (colis.lua)
client/missions/      HUD, ALT, IA des gardes (core.lua) et déroulé client des missions (colis.lua)
server/tablet.lua     actions des joueurs (contrôles de sécurité)
server/admin.lua      exports AdminData / AdminAction pour admin_menu
server/sync.lua       mise à jour des tablettes ouvertes, du F5 et des PED
client/               F5, PED (apparition par proximité), livraison (PNJ, sac, GPS, téléphone), NUI
html/                 tablette du groupe
```

## Tests (hors jeu)
Depuis la racine du dépôt : `lua5.4 tests/run.lua` (serveur : permissions, hiérarchie, argent, isolation des groupes, persistance…),
`lua5.4 tests/bridge.lua` (pont admin_menu, coffres), `lua5.4 tests/startup.lua` (fichiers manquants), `lua5.4 tests/missions.lua` (missions), `lua5.4 tests/fourgon.lua` (Fourgon Fantôme) et `FIXTURES=/tmp/fx lua5.4 tests/run.lua && FIXTURES=/tmp/fx node tests/ui.js` (rendu des interfaces).
