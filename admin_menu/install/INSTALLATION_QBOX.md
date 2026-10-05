# Installer MenuStaff Elyzea FA sur une base Qbox

## 1. Copier la ressource
Mets le dossier `admin_menu` dans `resources/[standalone]/` (ou n'importe quel dossier entre crochets).

## 2. server.cfg
Ajoute ces lignes **après** `ox_lib`, `qbx_core` et `ox_inventory` :

```cfg
ensure admin_menu

# Donner les grades par ACE (optionnel, en plus du menu)
add_ace group.admin adminmenu.fondateur allow
# add_ace group.mod adminmenu.moderateur allow
```

Ta licence est sans doute déjà dans `group.admin` sur une base Qbox
(`add_principal identifier.fivem:xxxx group.admin` ou `identifier.license:xxxx`).
Sinon : console serveur → `setrank <ton_id> fondateur`.

## 3. Objets d'inventaire
Copie le contenu de `install/ox_inventory_items.lua` dans `ox_inventory/data/items.lua`.

## 4. Conflits à retirer
- **Météo** : si `qbx_weathersync` ou `Renewed-Weathersync` est dans ton server.cfg, enlève-le
  (le menu gère la météo et l'heure). La console te prévient au démarrage s'il en reste un.
- **Touches** : F10 (menu), F2 (noclip), E (récolte / fouille / atelier). Si une autre ressource
  utilise déjà une de ces touches, change-la en jeu : Échap › Paramètres › Assignation des touches › FiveM.

## 5. Ce qui est branché automatiquement sur Qbox
| Fonction | Branché sur |
|---|---|
| Récoltes, fouilles, ateliers | ox_inventory (objets et armes) |
| Réanimation (joueur ou zone) | qbx_medical, avec réanimation intégrée en secours |
| Détection des morts | état Qbox (isdead / laststand) + état du personnage |
| Nouveaux arrivants | après le chargement du personnage (qbx_core) |

## 6. Premier démarrage
1. `restart admin_menu` (ou redémarre le serveur).
2. En jeu : **F10**. Tu dois voir « Connecté en tant que Fondateur ».
3. La console affiche `[AdminMenu] Inventaire détecté : ox`.

Si quelque chose ne marche pas, envoie-moi les lignes rouges de la console F8 (client) et de la console serveur.
