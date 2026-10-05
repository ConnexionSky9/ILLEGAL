# MenuStaff Elyzea FA (ressource `admin_menu`)

Aucun framework ni base de données requis : tout est stocké en JSON dans `data/`.
Fonctionne à côté d'ESX, QBCore, ox_core, etc.

## Installation

**Base Qbox :** suis `install/INSTALLATION_QBOX.md` (objets ox_inventory prêts à copier dans `install/`).


1. Copie le dossier `admin_menu` dans `resources/`.
2. Dans `server.cfg` :
   ```
   set onesync on
   ensure admin_menu
   ```
3. Donne-toi le grade Fondateur, au choix :
   - ajoute ta licence dans `Config.Owners` (`config.lua`) — tape `status` dans la console serveur pour la voir ;
   - ou, connecté au serveur, tape dans la console : `setrank <ton_id> fondateur`.
4. Redémarre la ressource. En jeu : **F10** pour le menu, **F2** pour le noclip.

⚠ Désactive tout autre script météo/heure (vSync, qb-weathersync, cd_easytime…) pour éviter les conflits.

## Raccourcis
Tous les raccourcis sont modifiables, sans toucher au code :
Échap › Paramètres › Assignation des touches › FiveM › lignes « Staff - … »
(ou bouton « Modifier mes touches » dans l'onglet Raccourcis du menu).

Les touches par défaut sont dans `Config.Keys` et `Config.NoclipKeys`. FiveM retient le choix
de chaque joueur : changer un défaut dans la config n'affecte que ceux qui ne l'ont pas encore modifié.

| Action | Défaut |
|---|---|
| Menu | F10 |
| Noclip | F2 |
| Wallhack, godmode, invisibilité, noms/IDs, TP marqueur, réparer | aucune (à assigner) |
| Noclip : déplacement | Z Q S D (AZERTY) |
| Noclip : monter / descendre | Espace / Ctrl gauche |
| Noclip : vite / lent | Shift gauche / Alt gauche |
| Noclip : vitesse (15 crans, de 2 à 430 km/h) | Molette |
| Noclip : supprimer la cible | G |

**Noclip et carte** : en noclip, Échap ouvre le menu pause normalement et la carte répond (zoom, déplacement,
marqueur). Le personnage reste figé sur place tant que la pause est ouverte.

**Noclip** : 15 vitesses (molette, la dernière est retenue), accélération et freinage progressifs pour un vol fluide.
Avancer reste à l'horizontale tant que la caméra penche de moins de 22° : on ne descend plus tout seul sans toucher
à la souris. Pour monter ou descendre en avançant, regarde franchement vers le haut ou le bas, ou utilise Espace / Ctrl.
Réglages dans `Config.Noclip` (`speeds`, `smoothing`, `pitchMode`, `pitchDeadzone`).
| Noclip : spectate le joueur visé | Clic gauche |

## Noclip
- Caméra 3e personne, le staff est invisible pour les autres joueurs.
- Le viseur (point au centre) ne cible **que les véhicules et les joueurs** :
  - **G** : supprime le véhicule visé (PNJ ou joueur ; 2e appui demandé si un joueur est à bord) ;
  - **Clic gauche** : spectate le joueur visé, ou un joueur à bord du véhicule visé.
- Les objets de la map et les PNJ ne sont jamais touchés depuis le noclip.
- La liste des touches s'affiche **en bas à droite** (avec tes vraies touches si tu les as changées),
  ainsi que la cible actuelle. Même chose pour le placement, la réanimation de zone et le retrait d'objets.
- Vitesse plafonnée (`Config.Noclip.maxSpeed`, 160 m/s). En vol rapide (au-dessus de 70 m/s), le viseur
  se met en pause et l'éditeur de map ne crée rien : c'est ce qui évite les crashs en volant vite.

## Catalogue des props et personnages
Éditeur de map › 📚 **Catalogue** (ou « Parcourir… » dans Props et PNJ) : 344 props et 270 personnages
rangés par catégorie et par ordre alphabétique, avec recherche.
- **Survol** : aperçu de l'objet ou du personnage à droite.
- **Clic** : sélection, puis « Placer cet objet » / « Utiliser pour un PNJ », « Voir en 3D », « Copier le nom ».
- **Double-clic** : place directement.
- **Voir en 3D** : le modèle apparaît devant toi en jeu avec une caméra qui tourne autour (molette pour zoomer,
  E pour le placer, Retour pour revenir au menu). Pratique quand un modèle n'a pas d'image.
- Images : personnages depuis la documentation FiveM, props depuis gta-objects.xyz.
- Pour ajouter tes propres modèles (packs, MLO…) : ajoute leur nom dans `html/catalog.js`, dans la catégorie
  de ton choix (ou crée une catégorie). L'ordre alphabétique est automatique.

## Zones (safe zones, quartiers, zones à message)
Éditeur de map › 🗺️ **Zones** (permission `editor_zones`, SuperAdmin et Fondateur).
1. Choisis un type : 🛡️ Safe zone, 🏘️ Quartier, 📢 Message seul, 🚸 Zone 30 km/h (tout reste modifiable).
2. Écris le **message d'entrée** et le **message de sortie** (aperçu en direct), choisis la couleur.
3. Délimite la zone :
   - ✏️ **Forme libre** : vise le sol, E pour poser un coin, Retour pour retirer le dernier, Entrée pour
     terminer (3 coins minimum, carré, rectangle ou n'importe quelle forme). Le noclip marche pendant le dessin.
   - ⭕ **Cercle autour de moi** : rayon en mètres.

Options : **Safe zone** (pas d'armes ni de coups, joueurs invincibles, limite de vitesse en véhicule,
exception pour la police en service), **sur la carte** (zone colorée + nom), **limites visibles** pour tous.
Le bouton « Afficher les limites (staff) » montre toutes les zones avec des murs colorés.
En quittant une safe zone, tout redevient normal (armes, dégâts, vitesse).

## Portes et portails verrouillables (permission `editor_doors`)
Éditeur de map › 🚪 **Portes** › « Choisir la porte » : vise la porte (ou les 2 battants d'une porte double),
E pour sélectionner, Entrée pour terminer. Elle est aussitôt verrouillée pour tout le monde.
- **Gérer les clés** : donne les clés à un joueur connecté (par son ID). Les clés suivent le **personnage**
  (citizenid sur Qbox), pas le compte. Plusieurs propriétaires possibles.
- **Côté joueur** : près de la porte, E ouvre un petit panneau.
  - Propriétaire : verrouiller / déverrouiller, créer / changer / supprimer un **code** (4 à 8 chiffres).
  - Invité : clavier pour taper le code. 5 mauvais codes = blocage 60 s.
  - Sans clé ni code : la porte reste fermée.
- Le staff en service peut tout ouvrir, et verrouiller / déverrouiller depuis le menu à distance.
- Les portes sont verrouillées avec le système de portes du jeu (rien n'est supprimé).
  Si tu utilises déjà ox_doorlock, ne mets pas la même porte dans les deux.

## Prison (jail)
1. Éditeur de map › Points de spawn : ajoute ta position à l'endroit de la prison, puis « ⛓️ Point de jail ».
2. Fiche d'un joueur › **⛓️ Jail** : durée (5 min à 2 h, ou autre) et raison.
- Le joueur est téléporté en prison, voit en permanence **« Tu es en prison »** avec le **temps restant**
  et la raison. S'il s'éloigne (`Config.Jail.radius`), il est ramené. Pas d'armes en prison.
- À la fin, il est **renvoyé automatiquement là où il était** au moment du jail.
- Le temps ne s'écoule que pendant qu'il est connecté : se déconnecter ne raccourcit pas la peine.
- Onglet **Prison et bans** : liste des prisonniers, temps restant, bouton « Libérer ».

## Retirer un objet de la map (poteau, panneau, barrière…)
Éditeur de map › Props › **Choisir un objet de la map à retirer** : vise l'objet, E pour le retirer, Retour
pour terminer (le noclip reste utilisable pour s'approcher). L'objet est masqué pour tout le monde, reste
retiré après les redémarrages, et se remet avec « Remettre ». Les objets de GTA ne sont jamais vraiment
supprimés : c'est la seule méthode qui ne fait pas planter le jeu.

## Wallhack (permission `wallhack`)
- Noms, ID, distance, vie, armure et véhicule de chaque joueur proche, visibles à travers les murs,
  avec un trait vers les plus proches.
- Tous les joueurs du serveur sur la carte, même à l'autre bout (rafraîchi toutes les 2 s).
- Réglages dans `Config.Wallhack`.

## Éditeur de map (SuperAdmin et Fondateur)
Onglet **Éditeur de map** du menu. Réservé aux grades de niveau ≥ `Config.Editor.minLevel` (40 = SuperAdmin),
même si quelqu'un coche la permission sur un grade inférieur. Tout est sauvegardé dans `data/` :
rien ne disparaît au redémarrage.

**Points de spawn** — « Ajouter ma position » enregistre ta position et ta direction.
- Serveur standalone avec `spawnmanager` : ajoutés automatiquement.
- ESX / QBCore / multichar : `exports.admin_menu:GetSpawnPoints()` ou `GetRandomSpawnPoint()` (serveur),
  `exports.admin_menu:GetSpawnPoints()` (client), évènement client `adminmenu:spawnPointsUpdated`.

**Props et PNJ** — choisis un modèle, l'objet suit le point que tu vises (marche aussi en noclip).
Il est **collé au sol** automatiquement : posé par le jeu sur la vraie surface, en suivant la pente
(pieds au sol pour un PNJ). G pour le décoller si tu veux le mettre en l'air. Les plants des zones de
récolte sont aussi posés réellement au sol. Pour corriger un objet qui flotte déjà :
bouton « Déplacer » dans la liste (il se recolle au sol), puis E.
| Touche | Action |
|---|---|
| Molette | Tourner |
| G | Coller au sol oui / non (oui par défaut) |
| Page haut / Page bas | Monter / descendre |
| R | Remettre la hauteur à zéro |
| E | Valider |
| Retour arrière | Annuler |

**Protection** : tout ce qui est créé avec l'éditeur (spawns, props, PNJ, plants, ateliers) ne peut être
déplacé ou supprimé que par un SuperAdmin ou un Fondateur, côté serveur. Les autres membres du staff
voient « Protégé » dans le viseur du noclip et ne peuvent rien faire.
Ils se déplacent et se suppriment depuis les listes de l'éditeur (boutons « Déplacer » / « Supprimer »,
avec confirmation).
Les PNJ sont invincibles, figés, avec une animation et un nom affiché au-dessus si tu veux.

**Rôle des PNJ** — à la pose, choisis un rôle tout prêt (acheteur de weed, de cocaïne, de méth, de champignons,
grossiste, vendeur d'outils, petit commerce) ou « Décor ». Ensuite « Modifier son rôle » permet de tout régler :
- **Il rachète** : quels objets, prix min et max par unité (tiré au hasard à chaque vente), quantité max par vente,
  attente entre deux ventes, risque d'alerter la police (%) et nombre de policiers en ligne requis ;
- **Il vend** : quels objets et à quel prix ;
- **Monnaie** : liquide, banque ou un objet (ex. `black_money` pour l'argent sale) ;
- **Horaires** : toujours là, ou seulement de telle heure à telle heure (heure du jeu).
Le joueur s'approche, appuie sur E et voit ce qu'il peut vendre ou acheter. Le serveur vérifie tout
(distance, horaires, quantités, argent) et rembourse si l'inventaire est plein.
Les policiers en service (`Config.PoliceJobs`) reçoivent l'alerte avec un point clignotant sur la carte.

**Zones de récolte** — ex. champ de weed : choisis le type, règle les quantités, le temps de récolte et de
repousse, le rayon et le nombre de plants, puis « Créer la zone ici ». Les plants sont posés au sol autour de toi.
Les quantités se modifient à tout moment avec « Modifier les réglages ».

Côté joueur : s'approcher d'un plant → **E** → animation et barre de progression (X pour annuler) → objets
dans l'inventaire → le plant disparaît puis repousse. Le serveur vérifie la distance et la durée (anti-triche).

**Inventaire** : détection automatique d'ox_inventory, qb-core ou es_extended (`Config.Inventory`).
⚠ L'objet doit exister dans ton inventaire, par exemple pour ox_inventory dans `data/items.lua` :
```lua
['weed_leaf'] = { label = 'Feuille de weed', weight = 10, stack = true },
```
Pour QBCore : dans `qb-core/shared/items.lua`. Pour ESX : dans la table `items` de la base de données.

**Préréglages de récolte** (ce qui pousse) : weed, coca, champignons hallucinogènes, produits chimiques (méth).

**Zones de fouille** (onglet 🔍 Fouilles) : pour ce qui ne pousse pas. Tu poses toi-même les objets à fouiller
(épaves, bennes, caisses) un par un, puis le joueur appuie sur E pour fouiller. Chaque zone a :
- une table de butin : chaque ligne a son objet, sa quantité min/max et sa chance en % ;
- un outil obligatoire optionnel (ex. `lockpick`, `crowbar`) avec un risque de le casser ;
- un temps avant que l'objet se remplisse à nouveau.

Préréglages : casse auto et bennes (ferraille), caisses de contrebande (pièces légères, crochet),
caisses militaires (pièces moyennes, pied-de-biche), cargaison militaire (pièces lourdes, pied-de-biche).
La ferraille sert dans toutes les recettes d'armes, chaque établi utilise les pièces de sa catégorie. Chaque zone peut être secrète ou visible sur la carte.

**Ateliers** (labos et établis) : traitement de la weed, labo de cocaïne, labo de méth, séchage des champignons,
établis d'armes légères, moyennes et lourdes. Tout se modifie dans le menu (« Gérer les recettes ») :
nom, meuble, animation, visibilité sur la carte, et pour chaque recette les ingrédients, le résultat,
la quantité et la durée. Le joueur appuie sur E près de l'atelier, choisit la recette et la quantité (x1 à x10).
Le serveur vérifie les ingrédients, ne les retire qu'à la fin, et les rend si l'inventaire est plein.

Armes : mets le nom de code (`WEAPON_PISTOL`…). Le menu l'adapte à ton inventaire
(ox : `WEAPON_PISTOL`, QBCore : `weapon_pistol`, ESX : ajoutée comme arme).

**Objets à créer dans ton inventaire** (préréglages) :
`weed_leaf`, `weed_pouch`, `coca_leaf`, `cocaine`, `meth_chemicals`, `meth`, `magic_mushroom`,
`dried_mushroom`, `metal_scrap`, `gun_parts_light`, `gun_parts_medium`, `gun_parts_heavy`,
`lockpick`, `crowbar`. Tu peux les renommer dans le menu pour utiliser tes objets existants.

**Nouveaux arrivants** : dans Points de spawn, « Pour les nouveaux » sur un point. Toute licence jamais vue
y est téléportée à sa première venue (après le chargement du personnage avec ESX / QBCore).
Le suivi commence à l'installation de cette version : un joueur déjà venu avant mais qui ne s'est pas
reconnecté depuis sera considéré comme nouveau une fois.

## Événements › GoFast (permissions `gofast_manage` et `gofast_missions`)
Nouvel onglet **🎯 Événements** qui pilote toute la ressource **gofast** (à installer à côté, dossier `gofast`,
`ensure gofast` après `ensure admin_menu` ; nom du dossier modifiable dans `Config.Events.goFastResource`).
- `gofast_manage` (SuperAdmin par défaut) : contacts, emplacements, dialogues, contrats, destinations, réglages, ouvrir / fermer le réseau.
- `gofast_missions` (Administrateur et SuperAdmin) : Go Fast en cours (y aller, annuler) et joueurs (niveau, XP, attente).
- Au premier démarrage de cette version, ces permissions sont ajoutées automatiquement aux grades existants.

Sous-onglets :
- **Vue d'ensemble** : état du réseau, compteurs, liste « À corriger » (contact sans emplacement, sans point véhicule, sans contrat).
- **Contacts (PNJ)** : crée un contact **à ta position** (nom, apparence, animation) ou convertis un PNJ « Décor » de l'éditeur
  (bouton « 🏎️ Contact GoFast » sur sa fiche dans Éditeur de map › PNJ). Dans la fiche d'un contact :
  - emplacements (ajouter ma position, mettre à ma position, faire venir le PNJ ici, y aller, supprimer) ;
  - points véhicule de chaque emplacement (monte dans une voiture garée au bon endroit, puis « Ajouter un point véhicule ») ;
  - déplacements automatiques : ne bouge pas / tour à tour / au hasard, toutes les X à Y minutes, option « seulement quand personne n'est autour » ;
  - dialogues : accueil, refus/attente, contrat accepté, réussite, échec, avec `{joueur}` `{contact}` `{niveau}` `{palier}` `{temps}` ;
  - contrats proposés, blip (icône, couleur), cercle au sol, actif ou non.
  Les emplacements et points véhicule sont enregistrés tout de suite ; le reste avec le bouton « Enregistrer ».
- **Contrats** : paie, XP, niveau requis, livraisons, temps, police, chances d'événement et de contrat rare, activer / désactiver.
- **Destinations** : ajoute ta position (à pied ou en voiture), renomme, change la zone, supprime, ou reviens à la liste de config.lua.
- **Réglages** : attentes, missions simultanées, temps de récupération, police, événements, XP, bonus et pénalités.
- **Missions et joueurs** : missions en cours (y aller, annuler sans attente) ; pour un joueur en ligne : voir son niveau,
  retirer son attente, ajouter ou définir son XP.

Toutes les positions sont prises **côté serveur** (celles envoyées par le client sont vérifiées), chaque action est
enregistrée dans les logs (menu + Discord), et le mode RP bloque tout comme pour les autres fonctions staff.
Si la ressource gofast n'est pas démarrée, l'onglet l'indique simplement.

## Événements › Attaque de zombies (permission `event_zombies`)
Intégré au menu : aucune ressource en plus. Permission à cocher dans l'onglet **Grades** (catégorie Événements),
donnée au SuperAdmin par défaut. Si plusieurs événements sont disponibles, un sélecteur en haut de l'onglet
**🎯 Événements** permet de passer de l'un à l'autre (GoFast / Attaque de zombies).

**Lancer** : durée (10 min à 1 h 30, ou autre jusqu'à `Config.Zombies.maxDuration`), intensité (Faible, Moyenne, Forte,
Cauchemar = zombies max autour de chaque joueur et sur tout le serveur), zone (ville de Los Santos, toute la carte,
ou un rayon autour de toi), puis les options :
- ⛈️ orage et pluie (météo synchronisée du menu + éclairs + filtre d'image désaturé) ;
- 💡 coupure de courant (blackout) ; 🌙 nuit (heure bloquée à 23 h) ;
- 🏚️ ville déserte (plus de passants ni de trafic normal) ;
- 🎯 seulement la tête (les tirs au corps ne les arrêtent presque pas) ;
- pourcentage de zombies coureurs, force de leurs coups, annonce aux joueurs (message modifiable).

**Pendant l'attaque** : compte à rebours, zombies en vie / tués, joueurs relevés, meilleurs survivants, et :
- **💀 Tuer tous les zombies** : ils tombent tous d'un coup, les corps disparaissent après quelques secondes ;
- **⏸️ Suspendre / reprendre les apparitions** (accalmie sans arrêter l'événement) ;
- prolonger ou raccourcir (−10 min, +10, +30, +1 h) et changer l'intensité en direct ;
- **⏹️ Arrêter** : zombies supprimés, météo, heure et éclairage remis comme avant.
À la fin du temps, tout redevient normal automatiquement.

**Missions pour les joueurs** (facultatif, au lancement ou pendant l'attaque) : des objectifs coopératifs pour tout
le serveur. Chaque mission a des étapes dans l'ordre :
- 📍 **Aller à un lieu** : terminée dès qu'un joueur arrive dans le rayon ;
- ✋ **Maintenir E** : un joueur maintient E sur place pendant X secondes (vérifié par le serveur) ;
- 🛡️ **Tenir une zone** : au moins un joueur reste dans la zone (temps cumulé) pendant que les zombies affluent.
Le lieu se choisit dans une liste (`Config.Zombies.places`, bouton « Y aller » pour vérifier) ou « 📍 Ma position ».
Quand la mission est réussie : **🧪 décontamination totale** (effet à l'écran, tous les zombies tombent, l'événement
se termine et la ville redevient normale), **💀 tous les zombies tombent** (l'attaque continue), ou rien de spécial.
Options : délai d'apparition (ex. la piste de Humane Labs apparaît après 10 min), récompense en argent liquide et/ou
objet pour chaque participant (joueurs présents aux étapes).
Missions toutes prêtes : **🧪 Décontamination à Humane Labs** (rejoindre le labo → récupérer les données du virus →
protéger la synthèse de l'antidote → lancer la décontamination) et **💉 Vaccins de l'hôpital**, modifiables avant de lancer
(`Config.Zombies.missionPresets` pour en créer d'autres).
Pendant l'attaque : progression de chaque mission, « Lancer maintenant », « Valider l'étape », « Annuler », et
« Ajouter une mission maintenant ». Côté joueurs : blip avec itinéraire, zone colorée au sol, et un encadré
« ☣ Missions » (milieu gauche de l'écran) avec l'étape en cours, la distance et la progression.
Les zombies apparaissent aussi autour des objectifs en cours, même hors de la zone choisie (`missionHotspot`).
Les coordonnées des lieux fournis sont approximatives : vérifie-les avec « Y aller ».

**Récompenses des missions : où et à qui.** Chaque mission peut verser plusieurs récompenses :
💵 argent liquide, 🏦 banque ou 🎒 objet (n'importe quel objet de ton inventaire, avec la quantité). À qui :
tous les participants, les joueurs présents à la dernière étape, celui qui a validé la dernière étape, les N meilleurs
tueurs de zombies, tous les joueurs dans la zone, tous les joueurs connectés, ou des joueurs que tu coches dans la liste.
Les récompenses ne sont pas reprises à la fin.

**Caisses d'armes.** Compose autant de types de caisses que tu veux (8 au lancement) : nom, apparence, contenu libre
(armes, munitions, soins, n'importe quel objet + quantité), « le premier qui l'ouvre » ou « chaque joueur une fois »,
visible ou cachée sur la carte (couleur du point au choix), nombre de caisses placées automatiquement et/ou positions
précises (📍 Ma position). Caisses toutes prêtes selon ton inventaire : pistolets, mitraillettes, caisse lourde,
ravitaillement en munitions (`Config.Zombies.cratePresets`). Les caisses automatiques sont posées sur des lieux dégagés
de la zone (`Config.Zombies.crateSpots`, ajoute les tiens). Les joueurs maintiennent E pour ouvrir (contenu affiché avant).
Pendant l'attaque : caisses restantes / ouvertes par type, « +5 (auto) », « 📍 Ici », nouveau type de caisse, tout retirer.

**Reprise des armes à la fin.** Tout ce qui sort d'une caisse est enregistré (sauvegardé dans `data/zombie_reclaim.json`).
À la fin de l'attaque, **seulement ces objets** sont retirés des inventaires, jamais ceux que les joueurs avaient déjà :
- ox_inventory et qb-inventory : les objets des caisses portent une étiquette ; seuls les objets étiquetés sont retirés,
  même s'ils ont été donnés à un autre joueur connecté ;
- ESX et autres : on retire au plus la quantité prise dans les caisses, chez ceux qui les ont ouvertes.
Un joueur déconnecté à la fin est repris dès sa prochaine connexion (personnage chargé). Si des reprises sont en attente,
le menu l'indique avec un bouton « Reprendre maintenant ». Limites : un objet déposé dans un coffre, un stash ou au sol
n'est pas repris ; les munitions déjà tirées ne peuvent évidemment pas l'être.

**Mort des joueurs : aucune perte.** Pendant l'événement, un joueur qui meurt (zombie, chute, tir…) est relevé sur place
après `reviveDelay` secondes, puis protégé `reviveProtection` secondes. Il ne passe jamais par la réapparition à
l'hôpital : armes, munitions et inventaire restent intacts, et GTA ne fait pas tomber son arme au sol.
Compatible qbx_medical, esx_ambulancejob, qb-ambulancejob (sinon réanimation intégrée).

**Joueurs** : un petit bandeau en haut de l'écran affiche « ☣ Attaque de zombies », le temps restant et leurs zombies tués.

**Fonctionnement** : les zombies sont créés **par le serveur** (compatible `sv_entityLockdown strict`) autour des joueurs
présents dans la zone, sur les trottoirs, hors de leur champ de vision si possible, jamais en safe zone ni en intérieur.
Ils errent, puis foncent sur le joueur le plus proche (marche titubante ou course) et l'attaquent au corps à corps.
Ceux trop loin de tout joueur et les corps sont retirés automatiquement : le nombre d'entités reste sous contrôle.
Un zombie qui entre dans une safe zone s'effondre. Réglages fins dans `Config.Zombies` (modèles, vie, distances,
intensités, zone de la ville, filtre, éclairs, textes des annonces).
Export serveur : `exports.admin_menu:IsZombieEventActive()`.

## Menu rapide (F9)
Un panneau compact sur la droite de l'écran, sans ouvrir la tablette. Touche par défaut **F9** (modifiable :
Paramètres › Assignation des touches › FiveM › « Staff - Menu rapide »). Échap ou F9 pour fermer.
- **Moi** : TP au marqueur, noclip, godmode, invisible, noms et IDs, wallhack, me soigner, me réanimer,
  réparer mon véhicule, réanimer autour (chaque bouton n'apparaît que si ton grade a la permission).
- **Joueur** : recherche par nom ou ID, les joueurs proches en premier (avec la distance), puis : aller vers lui,
  l'amener, spectate, soigner, réanimer, freeze, fiche complète, et **message privé**.
- **Message aux staffs** (discussion staff) et **annonce rapide**.
- Service staff / mode RP en un clic (en mode RP, seul ce bouton reste disponible).

## Messages privés (MP staff) et discussion staff
Permissions `staff_pm` et `staff_chat` (onglet Grades, catégorie Messages ; données à tous les grades par défaut).
- **MP à un joueur** : menu rapide, bouton « ✉️ Message privé » sur la fiche du joueur, ou `/mp [id] [message]`.
  Le joueur le voit à l'écran comme un message du staff (nom et grade du staff, couleur du grade) et répond avec
  `/r [message]` pendant 15 min. La réponse s'affiche chez le staff avec un rappel pour lui répondre.
- **Discussion staff** : menu rapide ou `/sc [message]`, visible par les staffs en service.
- Tout est enregistré dans les logs (menu + Discord). Réglages : `Config.Messages` (afficher le nom du staff ou
  seulement « Staff », durée, commandes).

## Donner des objets (permission `give_item`)
L'onglet **Objets** affiche **tous les objets connus par l'inventaire du serveur**, armes et munitions comprises
(ox_inventory, qs-inventory, qb-core / ps / lj-inventory, ESX ; ou `Config.CustomGetItemList` en mode `custom`).
- Recherche par nom ou par code, catégories avec leur nombre (Tout, Elyzea, Armes, Munitions, Objets).
- 300 objets affichés d'abord pour rester fluide, puis « Afficher 300 de plus » ou « Tout afficher ».
- Le code de chaque objet est écrit sous son nom ; 🔄 recharge la liste depuis l'inventaire (après l'ajout d'un objet au serveur).
- Un objet absent de la liste peut quand même être choisi en tapant son code exact.
- Choisis la quantité, puis **À moi** ou **À un joueur** (ID ou liste des joueurs connectés).

## Service staff / mode RP
Pour jouer normalement en RP sans risquer d'utiliser une fonction staff par erreur :
- clique sur **🛡️ En service** en haut du menu (ou « Passer en mode RP » sur l'Accueil) pour passer en **🎭 Mode RP** ;
- noclip, godmode, invisibilité, wallhack, noms/IDs, spectate et modes en cours sont coupés aussitôt ;
- tous les raccourcis staff sont bloqués, et le serveur refuse toute action staff tant que tu es en RP ;
- tu ne reçois plus les alertes de reports ; l'Accueil compte le « Staff en service » ;
- le menu (F10) reste accessible et affiche un bouton « Reprendre mon service staff » ;
- **en service, la faim et la soif sont figées** à leur niveau du moment (elles ne baissent plus ; manger
  ou boire les fait toujours monter). En mode RP, elles reprennent normalement à partir de ce niveau
  (`Config.StaffNeeds`, compatible Qbox, QBCore et esx_status ; option pour figer aussi le stress) ;
- ton choix est mémorisé d'une session à l'autre. Raccourci assignable : « Service staff / mode RP ».

## Transformation en animal (permission `transform`, SuperAdmin et Fondateur)
Mes outils › **🐾 Se transformer en animal** : chiens et chats, ferme, animaux sauvages, oiseaux,
animaux marins, créatures (Bigfoot, Yéti, extraterrestre), ou n'importe quel modèle ajouté par son nom.
- Ton apparence complète (via illenium-appearance / fivem-appearance), ta vie et ton armure sont
  sauvegardées et remises à l'identique avec « Reprendre ma forme humaine » (raccourci assignable).
- Passer en mode RP te fait reprendre automatiquement ta forme humaine.
- Les animaux marins ne vivent que dans l'eau ; les oiseaux marchent (noclip pour voler).

## Soin et armure
Fiche d'un joueur : **❤️ Soigner** (vie à 100 %) et **🛡️ Remplir l'armure** (gilet à 100 %), séparés.
Pour toi : « Me soigner » et « Remplir mon armure » dans Mes outils (et sur l'Accueil).
Permissions : `heal` et `armor` (Administrateur et plus par défaut pour l'armure).

## Réanimation
- Fiche d'un joueur : bouton **Réanimer**.
- Mes outils : **Réanimer autour de moi** : la zone s'affiche d'abord au sol (cercle vert) avec les joueurs
  à terre signalés en rouge. Molette pour changer le rayon, E pour réanimer, Retour pour annuler.
  Seuls les joueurs morts sont réanimés, le menu indique combien l'ont été. Raccourcis assignables : « Me réanimer » et « Réanimer autour de moi ».
- Compatible qbx_medical (Qbox), esx_ambulancejob et qb-ambulancejob automatiquement (`Config.Revive`), sinon réanimation intégrée.

## Annonces serveur
Onglet 📢 Annonces : titre, message, type (or, bleu ou rouge), image (logo, images de `Config.AnnounceImages`
ou n'importe quel lien https), durée, texte fixe ou défilant. Un aperçu en direct montre le bandeau exact
qui apparaîtra en haut de l'écran de tous les joueurs.

## Logo
Le logo est `html/logo.png`. Remplace ce fichier (format carré, fond transparent) pour le changer.

## Mise à jour depuis une version précédente
Les établis d'armes déjà créés gardent leurs anciennes recettes (`gun_parts`) : ouvre « Gérer les recettes »
et remplace l'ingrédient par `gun_parts_light`, `gun_parts_medium` ou `gun_parts_heavy`.

Au premier démarrage, les grades déjà sauvegardés reçoivent automatiquement les nouvelles permissions
(Wallhack pour Administrateur et SuperAdmin, Éditeur de map et Ateliers pour SuperAdmin).

## Grades par défaut
| Grade | Niveau |
|---|---|
| Support | 10 |
| Modérateur | 20 |
| Administrateur | 30 |
| SuperAdmin | 40 |
| Fondateur | 100 (verrouillé, toutes les permissions) |

Règles de hiérarchie :
- on ne peut sanctionner / ramener / modifier que quelqu'un de **niveau inférieur** ;
- on ne peut donner que des grades de niveau inférieur au sien ;
- dans l'éditeur de grades, on ne peut donner que des permissions qu'on possède soi-même.

Tout se gère en jeu : onglet **Grades** (créer, modifier, supprimer, cocher les permissions)
et onglet **Staff** (changer le grade ou retirer un membre, même hors ligne).

## Commandes
| Commande | Rôle |
|---|---|
| `/report <message>` | Tous les joueurs : alerte le staff |
| `setrank <id> <grade\|none>` | Console ou staff avec `manage_staff` |
| `unban <idDuBan>` | Console ou staff avec `unban` |

## Logs
Console serveur + onglet Logs (300 dernières actions) + Discord si `Config.DiscordWebhook` est rempli.

## Exports serveur
```lua
exports.admin_menu:HasPermission(source, 'ban')
exports.admin_menu:GetRank(source) -- 'administrateur' ou nil
```

## Notes
- Le soin utilise `NetworkResurrectLocalPlayer`. Si ton framework a son propre système de mort
  (esx_ambulancejob, qb-ambulancejob…), remplace le contenu de l'évènement `adminmenu:heal`
  dans `client/main.lua` par l'appel de revive de ton framework.
- Les bans vérifient licence, Discord, Steam, Xbox, Live et les tokens matériels (pas l'IP).

## Stabilité du noclip
- Plus de contour sur la cible : ce contour pouvait faire planter le jeu quand l'objet visé disparaissait.
- Vitesse plafonnée (`Config.Noclip.maxSpeed`, 220 m/s) : voler trop vite surcharge le chargement de la map.
- Impossible de sortir des limites de la map.
- Un double appui rapide ne lance plus deux noclips en même temps.
- En sortie : attente du sol chargé, puis 4 s d'invincibilité contre les chutes.
- Si une erreur survient (noclip, placement, spectate), le joueur est toujours remis à la normale
  et l'erreur est écrite en console F8.

## Performances
- Props, PNJ, plants et ateliers n'apparaissent qu'autour de chaque joueur, avec un nombre de créations
  limité par passage (pas d'à-coups en arrivant dans une zone chargée) et des modèles chargés sans bloquer.
- Les interactions (E) ne vérifient que les éléments à moins de 25 m.
- Noclip : visée asynchrone. Wallhack et noms : textes recalculés 4 fois par seconde, dessin à chaque image.
- Serveur : licences en cache, sauvegardes regroupées, mises à jour de la map regroupées, anti-spam sur
  tous les évènements. Le menu ne se redessine que si quelque chose a changé.
- Si la ressource redémarre pendant un noclip ou un spectate, le joueur est remis à la normale.

## Icône des zones sur la carte
Quand « 📍 Sur la carte » est activé pour une zone (Éditeur de map › Zones), tu choisis son icône : garage, voiture,
concession, mécanicien, fourrière, station-service, police, hôpital, banque, magasins, maison… (recherche par nom),
ou **n'importe quelle icône de GTA** en tapant son numéro de blip (liste sur docs.fivem.net › Game references › Blips).
« Automatique » garde l'ancien comportement (bouclier pour une safe zone, point sinon). Taille réglable, l'icône
prend la couleur de la zone. Liste proposée modifiable dans `Config.Zones.icons`.

## Téléportation à des coordonnées (permission `tp_coords`)
- **Mes outils › Déplacement** : un seul champ où tu colles des coordonnées dans n'importe quel format
  (`vector3(215.7, -810.1, 30.7)`, `vector4(…)`, `215.7, -810.1, 30.7`, `215 -810 30`, `{x = …, y = …, z = …}`).
  L'aperçu affiche ce qui a été compris ; Entrée ou « Téléporter ». Sans Z, tu es posé au sol.
- Les 6 dernières positions et tes **favoris** (☆ pour nommer et garder un lieu) restent sous le champ.
- **Menu rapide (F9)** : section « Téléportation » avec le même champ, les favoris et l'historique.
- **Commande** : `/tpc x y z` (ou `/tpc vector3(…)`), nom modifiable dans `Config.Messages.commands.tpCoords`.
- Chaque téléportation est enregistrée dans les logs. Par défaut la permission est donnée à l'Administrateur et
  au-dessus ; coche « TP aux coordonnées » dans l'onglet Grades pour la donner à d'autres grades.

## Props : dossiers et surbrillance
**Dossiers** (Éditeur de map › Props) : « + Nouveau dossier », puis clique sur un dossier pour n'afficher que ses props.
Dans un dossier : ✏️ Renommer, 👁️ Montrer en jeu, Supprimer le dossier (en gardant ses props « Sans dossier », ou avec eux).
- Chaque prop a une liste « dossier » pour le ranger en un clic ; coche plusieurs props (ou « Tout cocher ») pour les
  ranger d'un coup. Recherche par modèle ou par numéro (#12).
- Le nouveau prop que tu poses va dans le dossier choisi à côté du bouton « Placer » (par défaut, le dossier ouvert).
- Sauvegardé dans `data/prop_folders.json` (les props gardent leur dossier dans `data/props.json`).

**Surbrillance en jeu** :
- 🎯 « Viser un prop en jeu » : l'élément visé (prop, atelier, point de fouille, plant, PNJ) s'entoure d'un contour
  lumineux avec son modèle, son numéro et son dossier ; les éléments proches affichent leur numéro.
  Valider (E) = le déplacer, Remise à zéro (R) = dupliquer un prop, Coller au sol (G) deux fois = supprimer,
  Annuler = terminer. Le noclip marche pendant la sélection, et on y revient après chaque déplacement.
- Pendant un déplacement, l'objet déplacé est aussi entouré d'un contour.
- 👁️ (sur un prop, une sélection ou un dossier) : les props brillent 12 s avec une colonne lumineuse visible de loin.

## 🧰 Groupe « Métiers » (en bas du menu)
Les tablettes staff des métiers sont rangées tout en bas de la barre latérale, sous le titre **Métiers** :
🚑 **EMS** et 🚓 **Police**. Chaque onglet n'apparaît que pour les staffs concernés.

## 🚑 Tablette staff EMS (ressource `elyzea_ems`)
Le menu décide qui peut ouvrir la tablette staff EMS (`/ems_staff`), qui configure tout le métier EMS.
- **Permission `ems_staff`** (onglet Grades, catégorie Métiers) : donnée au SuperAdmin par défaut, le Fondateur l'a toujours.
- **Onglet 🚑 EMS** du menu (groupe Métiers) :
  - **Ouvrir la tablette staff EMS** en un clic (ou `/ems_staff`) ;
  - **Grades qui ont accès** : interrupteur par grade (permission `manage_ranks`, grades inférieurs au tien seulement) ;
  - **Accès individuels** : donner l'accès à un joueur précis, staff ou non, sans changer son grade (permission
    `manage_staff`). L'accès suit sa licence et se retire en un clic ;
  - **Connectés avec l'accès** : qui peut l'ouvrir maintenant, par son grade ou individuellement, et qui est en mode RP.
- Un staff **en mode RP ne peut pas ouvrir** la tablette (`Config.Ems.requireDuty`).
- Pour donner un accès, il faut l'avoir soi-même. Tout est enregistré dans les logs (menu + Discord).
- Ordre dans server.cfg : `ensure admin_menu`, puis `ensure elyzea_ems` et `ensure elyzea_ems_staff`.
- Export serveur : `exports.admin_menu:CanUseEmsStaff(source)` → `true` ou `false, 'rp' | 'none'`.

## 🚓 Tablette staff Police (ressource `elyzea_police`)
Même fonctionnement que l'EMS, pour la tablette staff Police (`/police_staff`) qui configure tout le métier Police.
- **Permission `police_staff`** (onglet Grades, catégorie Métiers) : donnée au SuperAdmin par défaut (ajoutée automatiquement
  aux grades existants au premier démarrage de cette version), le Fondateur l'a toujours.
- **Onglet 🚓 Police** du menu (groupe Métiers) : ouvrir la tablette, grades qui ont accès, accès individuels, connectés avec l'accès.
- Un staff **en mode RP ne peut pas ouvrir** la tablette (`Config.Police.requireDuty`).
- Les alertes « transaction suspecte » des PNJ acheteurs arrivent dans le **dispatch de la police** (avec Accepter / Ignorer)
  quand `elyzea_police` est démarré ; sinon l'ancien point clignotant est utilisé.
- Ordre dans server.cfg : `ensure admin_menu`, puis `ensure elyzea_police` et `ensure elyzea_police_staff`.
- Exports serveur : `exports.admin_menu:CanUsePoliceStaff(source)` → `true` ou `false, 'rp' | 'none'` ;
  `exports.admin_menu:AddLog(source, action, détails)` (les actions de la tablette staff et des agents sont enregistrées dans les logs).

## 👔 Tenues de service et « Rejoindre ce métier » (onglets EMS et Police)
En bas des onglets 🚑 EMS et 🚓 Police (permission `ems_staff` ou `police_staff`) :

**Tenues de service, par grade**
Des tenues **par défaut** sont créées au premier démarrage (vêtements du jeu de base, `Config.Uniforms.defaults`) :
- Police : tenue LSPD (chemise, pantalon, ceinturon, casquette, oreillette), galons sur l'épaule à partir de Sergent (grades 2, 3, 4) ;
- EMS : tenue d'ambulancier pour tous les grades.
Homme et femme. « Remettre les tenues par défaut » les remet à tout moment. Pour les personnaliser :
1. Habille-toi avec ton magasin de vêtements (illenium-appearance, qb-clothing…).
2. Clique « Enregistrer ma tenue » sur le grade voulu. La tenue est enregistrée pour le sexe de ton personnage :
   fais-le une fois avec un personnage homme et une fois avec un personnage femme.
3. « Essayer » met la tenue sur toi pour vérifier, « Remettre mes vêtements » annule l'essai.
- À la **prise de service** (tablette, point de service, peu importe), le joueur enfile la tenue de son grade.
  Un grade sans tenue prend celle du grade inférieur le plus proche (une tenue au grade 0 suffit pour tout le monde).
- À la **fin du service**, ou s'il change de métier, il retrouve exactement ses vêtements.
- Les métiers concernés : `Config.Ems.jobs` et `Config.Police.jobs` (+ les métiers police choisis dans la tablette staff Police).
- Réglages : `Config.Uniforms` (vêtements et accessoires concernés, message, tenues par défaut). Enregistré dans `data/uniforms.json`.
- Les vêtements du joueur sont aussi gardés sur son PC (par personnage) : après un crash ou une déconnexion en service,
  il les retrouve.
- Les tablettes staff des métiers peuvent gérer les tenues avec les exports serveur `SaveUniform(src, job, grade, gender, outfit)`,
  `DeleteUniform(src, job, grade, gender)`, `ResetUniforms(src, job)`, `GetUniformSummary(job)` et les exports client
  `CaptureOutfit()`, `TryUniform(job, grade)`, `UntryUniform()` (déjà utilisés par la tablette staff Police, onglet Tenues).

**Rejoindre ce métier (staff)**
- Choisis le grade puis « Devenir … » : tu prends ce métier pour utiliser la tablette des joueurs (ex. un staff EMS qui veut
  tester la tablette Police). Prends ensuite ton service dans la tablette du métier.
- Ton **métier d'origine est gardé** (même si tu changes plusieurs fois) : « ↩ Reprendre mon métier » te le rend, et le métier
  temporaire est retiré de ton personnage. Enregistré dans `data/job_switch.json`, donc ça survit à un redémarrage.
- Refusé en mode RP. Chaque changement est dans les logs.

## 🔧 Métiers › LsCustom (ressource `elyzea_lscustom`, permission `lscustom_staff`)
Le métier LsCustom n'a **pas d'interface admin à lui** : tout se gère ici, avec le design et les permissions du menu.
Permission « LsCustom : gérer tout le métier » (onglet Grades, catégorie Métiers), donnée au SuperAdmin par défaut.
- **Informations** : nom, identifiant, ouvert / fermé, mécanos en service et connectés (avec le travail en cours),
  nombre de zones, véhicules pris en charge, factures et chiffre du jour, « Rejoindre ce métier ».
- **Grades** : nom (identifiant), label, niveau (ordre ↑ ↓), salaire, patron. Créés dans Qbox sans redémarrage.
- **Zones** : Modification, Service, Vestiaire, Garage, Spawn véhicule, Parking, Réparation, Nettoyage.
  Ajouter avec « 📍 Utiliser ma position actuelle » ou « 🎯 Définir la position manuellement » (X / Y / Z / Heading),
  modifier (nom, type, rayon), déplacer à ma position, activer / désactiver, y aller, supprimer. Filtre par type.
- **Prix** : réparation, nettoyage, toute l'esthétique et la performance (par niveau). Appliqués immédiatement.
- **Tenues** : par grade, homme et femme (mêmes outils que l'EMS et la Police). Une combinaison de travail est créée par défaut.
- **Permissions** : tableau grade × action (réparer, nettoyer, modifier, facturer, véhicule de service, gérer les prix en jeu).
- **Configuration** : commission, facture max, délais, travail limité aux zones, icône sur la carte, véhicules de service.
Tout est enregistré dans les logs du menu.

## 🚘 Métiers › Concession (ressource `elyzea_concess`, permission `concess_staff`)
- **📱 Ouvrir la tablette direction** : la tablette du métier avec tous les droits, même sans être vendeur
  (catalogue, prix, ajout, masquer, supprimer, catégories, employés, permissions, finances).
- **Informations** (ouverte / fermée, vendeurs, ventes du mois, véhicules présentés et essais en cours, « Rejoindre ce métier »),
  **Grades**, **Zones** (service, podium de présentation, livraison, départ des essais, garage, sortie du garage, rangement),
  **Tenues** (costume par défaut, par grade, homme / femme), **Permissions** (tableau grade × action + remise maximum),
  **Configuration** (commission, délais, plaques, livraison ou garage, garage de la concession, icône).
Donnée au SuperAdmin par défaut, toutes les actions dans les logs.
- **PNJ « Catalogue concession »** (Éditeur de map › PNJ › Ce qu'il fait) : en lui parlant, les joueurs voient les véhicules
  en vente, sans pouvoir les acheter. Option « 🏁 Essai routier » : durée et point de départ (📍 Placer le point d'essai).

## 🅿️ PNJ « Garage public » (ressource `elyzea_garage`)
Éditeur de map › PNJ › Ce qu'il fait › **🅿️ Garage public** : nom du garage, icône sur la carte, places de sortie
(📍 Placer, Déplacer, Y aller, Supprimer), **zones de rangement** (🔴 cercle rouge au sol, rayon réglable : au volant, E pour ranger). Tous les garages publics sont connectés et gardent l'état exact des véhicules.

## 🚪 Portes : distance d'ouverture
Éditeur de map › Portes › **Gérer** une porte › **📏 Distance d'ouverture** : curseur de 0,8 à 15 m (portail de garage,
grande grille…), « Défaut » pour revenir à `Config.Doors.interactDistance`. La distance s'affiche sur chaque porte de la liste.

## 🗺️ Carte (permission `manage_map`, onglet Carte)
**Mini-carte** : carrée en haut à droite par défaut, pour tous les joueurs.
- Forme (carrée, ronde, rectangle GTA), position (4 coins), taille, largeur (100 % = carré parfait), écarts avec les bords.
- Chaque réglage s'applique **en direct sur ton écran** (« 👁 Voir l'écran » cache le menu 5 s) ; « Enregistrer pour tous »
  l'applique à tout le monde. Options : cacher les barres de vie GTA sous la carte, mini-carte seulement en véhicule.
- Les écrans plus larges que 16:9 sont corrigés automatiquement. « Gérée par le menu » désactivé : la mini-carte de GTA reste intacte.
- **✋ Placer la mini-carte à la souris** : le menu se cache, tu fais glisser le cadre (il s'accroche au coin le plus proche),
  molette pour la taille, Entrée pour enregistrer pour tous, Échap pour annuler.
- La position est enregistrée sur le serveur et **reposée à chaque connexion** (plusieurs fois pendant la première minute,
  pour passer derrière les scripts qui reposent leur propre mini-carte au chargement).
- **/carte** (et /minimap) d'autres ressources sont désactivées (`Config.Minimap.blockCommands`). L'onglet indique quelle
  ressource les avait créées : retire sa partie mini-carte pour éviter tout conflit.
- Valeurs de départ : `Config.Minimap`.

**Icônes des scripts** : toutes les icônes posées sur la carte par les autres ressources, de la plus proche à la plus éloignée.
- Repérer (clignote sur ta carte), Y aller, Cacher / Afficher, 📍 Déplacer à ma position, Modifier (nom, couleur, taille,
  affichage carte / mini-carte, position d'origine, ma position ou coordonnées), ↺ Remettre comme avant.
- Une icône est reconnue par son modèle et sa position d'origine : la règle s'applique chez tous les joueurs, même si le
  script recrée l'icône. Un nom changé revient à celui d'origine quand le script qui l'a créé redémarre.
- Seules les icônes posées à un endroit fixe sont gérées (pas celles qui suivent un joueur ou un véhicule).

**Icônes ajoutées** : à ta position ou par coordonnées, avec nom, icône (liste ou numéro GTA), couleur, taille, affichage
et visibilité sur la mini-carte (toujours ou seulement à proximité). Modifier, déplacer, Y aller, supprimer.

Tout est enregistré dans `data/map.json` et dans les logs.

## 🚗 Garages sur PNJ (Éditeur de map › PNJ)
Un PNJ peut maintenant sortir des véhicules aux joueurs.
1. **Placer le PNJ** avec le rôle « 🚗 Garage (location) » ou « 🚓 Garage de service (métier) », ou ouvre un PNJ existant
   avec « Modifier son rôle » et active la tuile **🚗 Garage**.
2. **Véhicules** : nom de code (`blista`, `police`…), nom affiché, prix (0 = gratuit). La monnaie se choisit dans
   « Argent et horaires » (liquide, banque ou objet), comme pour les autres rôles.
3. **Qui peut l'utiliser** : tout le monde, ou certains métiers avec un grade minimum. Le métier et le grade se
   choisissent dans des **listes déroulantes** remplies avec tous les métiers du serveur (Qbox, QBCore ou ESX) et leurs
   grades. Un métier créé plus tard (ex. `ambulance` par elyzea_ems) apparaît tout seul dans la liste (mise à jour toutes les 10 s).
4. **Enregistrer**, puis **📍 Placer les points de sortie** : un véhicule fantôme suit ton viseur, molette pour l'orienter,
   E pour valider. Pose-en plusieurs à la suite (le joueur prend le **premier libre**), Retour pour terminer.
   Chaque point se déplace, se supprime ou se visite (« Y aller ») depuis la fiche du PNJ.
5. **Options** : un véhicule à la fois par joueur, mettre le joueur au volant, carburant à la sortie, début de plaque,
   icône sur la carte (numéro et couleur du blip).

Côté joueur : E sur le PNJ → onglet **🚗 Garage** → « Sortir ». Le véhicule est **créé par le serveur**
(compatible `sv_entityLockdown strict`) sur une place libre, avec une plaque unique, et le joueur reçoit les clés
(qbx_vehiclekeys, qb-vehiclekeys, wasabi_carlock, MrNewbVehicleKeys détectés ; autre script : `Config.Garages.keysEvent`).
Pour **ranger** : revenir au volant près du PNJ ou d'un point de sortie et appuyer sur E, ou bouton « Ranger » dans le
menu du PNJ. Seuls les véhicules sortis de ce garage par ce joueur peuvent y être rangés. À la déconnexion, ses
véhicules de garage sont retirés (`Config.Garages.deleteOnDrop = false` pour les garder).
Réglages par défaut : `Config.Garages` (rayon de rangement, places, nombre max de véhicules et de points, icône).


## 🔑 PNJ réservés à un métier (Éditeur de map › PNJ)
Tout PNJ qui a un rôle (il rachète, il vend, garage) peut être réservé à un ou plusieurs métiers.
- **À la pose** : sous l'apparence, « 🔑 Qui peut lui parler » : *Tout le monde* ou *Uniquement : <métier>*, avec le grade minimum.
- **Après** : « Modifier son rôle » › section **🔑 Qui peut lui parler** : *Tout le monde* ou *Certains métiers uniquement*,
  plusieurs métiers possibles, chacun avec son grade minimum (listes déroulantes remplies avec les métiers du serveur).
- Les joueurs qui n'ont pas le bon métier **ne voient même pas** « Parler à… » ; le serveur revérifie à chaque action.
- La liste des PNJ affiche « 🔑 Réservé à … ». Les anciens garages réservés à un métier sont repris automatiquement.


## Invite « Appuyer sur E » (tous les joueurs)
Près d'un PNJ, d'un atelier, d'un coffre, d'un plant ou d'un point de fouille, l'ancien texte en haut à gauche est
remplacé par une invite **en bas au centre de l'écran**, au style du serveur (or et bleu nuit) :
touche dorée + « APPUYER POUR PARLER À » + **nom du PNJ** (ou « Appuyer pour ouvrir · Coffre des Ballas », etc.).
La touche affichée est celle que le joueur a réellement choisie dans ses raccourcis.

## 🗄️ Coffres (Éditeur de map › Coffres, permission `editor_stashes`)
Un objet posé sur la map (caisse, coffre-fort, armoire… ou n'importe quel prop) qui ouvre un **inventaire partagé**.
1. **Nom**, **poids maximum (kg)** et **nombre d'emplacements**.
2. **Qui peut l'ouvrir** : *Tout le monde*, et/ou *Métiers* (ex. police grade 3+), et/ou *Groupes illégaux*
   (gangs Qbox / QBCore, ex. Ballas grade 1+). Il suffit d'appartenir à l'un des métiers ou groupes cochés.
   Listes déroulantes remplies automatiquement avec les métiers et les gangs du serveur.
3. **Apparence** (9 modèles proposés ou n'importe quel prop), puis **Placer le coffre** : comme un prop, E pour valider.
- Ensuite : Modifier (nom, poids, emplacements, accès), 📦 Voir le contenu (staff, de n'importe où), Déplacer, Y aller, Supprimer.
- Le contenu est conservé par l'inventaire (ox_inventory ou qb-inventory) ; supprimer le coffre ne vide pas la base.
- Les joueurs non autorisés ne voient pas l'invite, et le serveur revérifie (distance + accès) à chaque ouverture.
- Permission donnée au SuperAdmin au premier démarrage (le Fondateur l'a toujours).


## 👕 Boutique de vêtements (rôle de PNJ, ressource `elyzea_clothing`)
Éditeur de map › PNJ › rôle « 👕 Boutique de vêtements » (ou « 👔 Boutique de luxe »), ou « Modifier son rôle » › tuile
**👕 Boutique de vêtements** : nom de la boutique, prix en % des prix de base, rayons vendus.
En jeu, « APPUYER POUR ENTRER DANS · <nom> » ouvre la boutique (essayage en direct, panier, paiement).
Il faut la ressource **elyzea_clothing** (`ensure elyzea_clothing` après admin_menu). Voir son LISEZ-MOI.


## 🧲 Aimant : coller un prop à un autre (Éditeur de map › Props)
Bouton **🧲 Aimant** à côté de « Placer » (ou touche **M** pendant le placement). Approche le viseur de **n'importe quel
prop** : ceux posés avec l'éditeur **et ceux déjà présents sur la map** (bancs, poubelles, barrières…), même sans le toucher
exactement et même s'il n'a pas de collision (portée : `Config.Editor.magnetRange`, 1,6 m). Le nouveau prop se colle contre
lui, **parfaitement aligné** (même orientation, bas alignés, centré).
- **Côté automatique** : celui que tu vises (au-dessus → dessus, sinon la face la plus proche du viseur).
- **X** : force un côté → Automatique, Dessus, Devant, Derrière, À gauche, À droite.
- **Molette** : tourne d'un quart de tour (reste aligné). **Page haut / bas** : décale en hauteur.
- Un cadre vert entoure l'objet visé ; sans objet visé, le placement redevient normal.
- Marche aussi pour les ateliers, coffres, plants et points de fouille. Touches modifiables
  (« Staff - Placement : Aimant… » dans les raccourcis FiveM).

## 🪂 Largage de drops (onglet Événements, permission `event_drops`)
Planifie des drops qui tombent à heure fixe, défendus par des gardes armés.
**Planning** : une liste de drops (Drop 1 à 18:00, Drop 2 à 19:00…), chacun avec :
- **Heure de l'annonce** : à l'heure réglée (ex. 16:32), l'annonce « un drop va être largué » est faite ; le drop touche
  le sol X minutes après (ex. 16:37). **Heure de Paris** par défaut (été / hiver automatique), même si l'hébergeur règle le serveur en UTC.
  Réglable dans les réglages généraux (Paris, horloge brute du serveur, ou UTC±N). « Tous les jours » ou « Une seule fois ».
- **Abris et difficulté** : véhicules garés autour de la caisse (0 à 8), **assortis au style des gardes** (voyous mexicains
  → lowriders, Ballas → SUV, Lost → vans, Black ops → FBI / Riot, militaires → Crusader / Barracks…), verrouillés pour
  servir d'abri ; sacs de sable et barrières (0 à 12). Les gardes se cachent derrière pour tirer.
  Difficulté : Facile, Normal, Difficile (précis, coriaces, passent d'abri en abri, prennent à revers),
  Extrême (très précis, 2× plus de vie, foncent, pas de mort en un tir à la tête).
  Véhicules par style et modèles d'abris : `Config.Drops.models` et `Config.Drops.coverModels`.
- **Position** : « 🗺️ Choisir sur la carte » (pose un repère GPS sur la carte, ferme-la) ou « 📍 Ma position ».
- **Contenu** : objets et quantités (liste des objets du serveur proposée).
- **Gardes** : jusqu'à 6 escouades (nombre, arme, apparence, armure, santé, précision, « lourdement armés »).
  Préréglages : escouade légère (12 pistolets), lourde (7 carabines, armure 100), tireurs d'élite.
- **Clé** : au hasard, sur un garde lourdement armé, sur un garde léger, ou dans une escouade précise.
  **Surbrillance** : après X fouilles ratées (5 par défaut, 0 = jamais), le garde qui porte la clé est mis en
  surbrillance pour les joueurs (halo doré au sol, flèche au-dessus, lumière qui pulse).
- **Ouverture** : durée (15 s par défaut), « tous les gardes doivent être morts ».
- **Annonce** : X minutes avant (5 par défaut), pour les **groupes illégaux** (gangs + métiers listés) ou **tout le monde**.

**En jeu** : X min avant, annonce « Largage imminent » sans position. À l'heure : « Drop à terre », blip + zone
sur la carte, **fumée rouge** sur la caisse, gardes autour (créés par le serveur). Ils restent calmes ; dès qu'on
leur tire dessus ou qu'on tire près d'eux (ou qu'on s'approche, si réglé), **tous ripostent**. Il faut les tuer,
**inspecter les corps** (Alt avec ox_target, sinon maintenir Alt + E) pour trouver la **clé**, puis ouvrir la
caisse (barre de 15 s) : le contenu s'ouvre dans un coffre temporaire (ox_inventory) ou va dans l'inventaire.
Boutons : 📣 Lancer (annonce maintenant), 🪂 Larguer tout de suite, Larguer maintenant (drop annoncé), Y aller,
Annuler. Réglages généraux : messages, blip, temps d'inspection, alertes, durée max, nettoyage.

## 🔐 Retrouver l'accès au menu (commandes CONSOLE)
L'accès dépend **uniquement du menu** : Fondateurs (`data/owners.json` + `Config.Owners`), staffs (`data/admins.json`),
et en option les ACE de `Config.AceRanks`. Rien ne passe par ox. Les fichiers de `data/` ne sont jamais écrasés par une mise à jour.
À taper dans la console du serveur (txAdmin › Live Console) :
- `adminmenu_qui` : liste les joueurs connectés, leur ID, leur licence et leur grade dans le menu.
- `adminmenu_fondateur <id>` : donne le grade Fondateur (enregistré dans `data/owners.json`).
- `adminmenu_grade <id> <grade>` : donne un grade (fondateur, superadmin, administrateur, moderateur, support) ; `aucun` pour retirer.
- `adminmenu_retirer_fondateur <id>` : retire un Fondateur.
On peut aussi mettre une licence à la place de l'ID (`license:xxxx`) pour un joueur hors ligne.
Si le menu dit « pas d'accès » juste après un redémarrage, il redemande tout seul les permissions au serveur
(pendant 1 minute, et à chaque appui sur la touche du menu).

## 🧟 Zombies : attaque directe et cracheurs
- **Attaque directe** : les zombies n'utilisent plus le combat de mêlée de GTA (garde, tour autour de la cible, regard
  puis frappe). Ils foncent jusqu'au contact et **frappent en marchant**, sans s'arrêter (un coup toutes les 0,8 s).
  Les coups sont calculés par la victime : fiables même avec de la latence. Petite chance de faire tomber le joueur.
- **Cracheurs d'acide** (15 % par défaut, réglable au lancement : « Cracheurs d'acide (%) ») : modèle zombie distinct.
  Entre 5 et 24 m, ils s'arrêtent, se tournent vers leur cible et **crachent un projectile vert** visible par tous
  (courbe, lueur, éclaboussure). Ils visent légèrement en avance : **on peut esquiver en bougeant**. Touché : dégâts,
  brûlure acide quelques secondes et image troublée. Trop près, ils griffent comme les autres.
- Tout se règle dans `Config.Zombies.attack` (portée, cadence, dégâts, chute) et `Config.Zombies.spit`
  (portée, cadence, vitesse du crachat, dégâts, brûlure, rayon d'éclaboussure, modèle).

## ☠️ Mission « Tuer le boss » (Événements › Attaque de zombies › missions)
Nouveau type d'étape dans les missions de l'événement zombies : **☠️ Tuer le boss**.
- **Réglages** : nom, apparence (Juggernaut, Bigfoot, zombie, extraterrestre, clown, mutant), **vie (500 à 200 000)**,
  **taille (×1 à ×3)**, **lieu** (liste, ta position ou position personnalisée), **territoire** (il ne s'en éloigne pas),
  **zombies autour de lui** (0 à 40) et **renforts** (les gardes morts reviennent toutes les 20 s, 4 par vague).
- **Le boss** marche lentement mais sans s'arrêter vers le joueur le plus proche ; **coup au sol** à courte portée
  (gros dégâts, renverse) ; **attaque à distance** de 8 à 40 m (masse orange en cloche, impact en zone qui renverse,
  esquivable). Pas de mort en un tir à la tête, ne tombe pas, armure.
- **Sa garde** le suit ; elle attaque **en priorité ceux qui frappent le boss** (pendant 25 s), sinon ceux qui s'approchent à moins de 22 m.
- **Barre de vie** en haut de l'écran pour les joueurs à moins de 200 m (nom, jauge rouge, PV restants).
- L'étape est réussie à la mort du boss : participants (ceux qui l'ont frappé) et récompenses de la mission comme d'habitude.
- Valeurs par défaut et attaques : `Config.Zombies.boss` (dont `melee` et `throw`).
- **Missions toutes prêtes** dans « Missions pour les joueurs » : « ☠️ Tuer le boss (Fort Zancudo) » (rejoindre la base,
  puis abattre le Colosse : 12 000 PV, ×2,2, 14 gardes) et « 🦍 Tuer la bête du Chiliad » (Bigfoot ×2,6). Modifiables avant de lancer.
- **Côté joueurs** : blip tête de mort et zone du territoire sur la carte, encadré des missions avec la vie du boss en %
  et sa distance, barre de vie en haut de l'écran à l'approche.
- **Hitbox à la taille du boss** : GTA n'agrandit que l'apparence. À chaque tir, le menu teste aussi un cylindre à la
  vraie taille du boss (largeur et hauteur × la taille) ; un tir qui le traverse sans toucher la hitbox normale inflige
  les dégâts de l'arme (vérifiés par le serveur, appliqués par le client qui contrôle le boss). Pas de double comptage,
  et les murs arrêtent toujours les balles.
- **Position au choix** : bouton « 🗺️ Carte » sur chaque étape de mission (boss compris) : pose un repère sur la carte,
  ferme-la, la position est enregistrée. Ou « 📍 Ma position », ou un lieu de la liste.

### Vitesse du boss et attaques à distance réalistes
- **Vitesse** (par boss, dans l'étape) : très lent, lent, normal (marche), rapide (trot), très rapide (il court).
  L'animation est accélérée en même temps : il ne glisse pas. Valeur par défaut : `Config.Zombies.boss.speed`.
- **Crachat d'acide** : jet de liquide vert en cloche (un paquet suivi de gouttelettes), traînée d'éclaboussures,
  impact qui gicle, **flaque d'acide au sol** qui fume puis s'efface (12 s). Touché : cri, dégâts, brûlure.
- **Lancer du boss** : un **vrai rocher** part de sa main, tournoie en cloche avec une traînée de poussière, s'écrase
  (gerbe de terre, cratère au sol, tremblement selon la distance). Dans la zone : dégâts selon la distance et le joueur
  est **projeté en arrière**. Le rocher reste au sol quelques secondes.

### Corps à corps fiable (zombies, gardes du boss, boss)
Les coups ne dépendent plus de l'animation vue par la victime (ces animations ne sont pas toujours transmises entre
joueurs). Le client qui contrôle le zombie ou le boss signale le coup, le serveur vérifie la distance et la cadence,
puis la victime encaisse. La portée du boss grandit avec sa taille (×2,2 : environ 5 m) et son coup projette en arrière.
