# Coiffeur / barbier

## Installation
Rien à ajouter dans server.cfg : le coiffeur fait partie de `admin_menu`.
Remplace les fichiers du menu, **garde ton dossier `data/`**, puis `restart admin_menu`.

## Poser un salon
1. F10 › Éditeur › PNJ › choisis le rôle tout prêt **💈 Coiffeur / barbier** (ou **✂️ Salon de luxe**).
2. Place le PNJ, puis « Modifier son rôle » pour régler :
   - le nom du salon, les services proposés, le prix de chaque prestation (0 = gratuit) ;
   - liquide / banque au choix, lentilles fantaisie, icône sur la carte ;
   - comme pour les autres PNJ : horaires, métiers autorisés, monnaie.
3. Les joueurs appuient sur **E** devant le PNJ.

## Commandes du salon
- Survol d'un style : aperçu immédiat sur le personnage. Clic : ajout au panier.
- Glisser la souris sur le personnage ou ← / → : tourner. Molette : zoomer.
- Échap : quitter sans payer (tout est remis comme avant).

## Enregistrement de la nouvelle tête (`Config.Barber.saveMode`)
| Mode | Utilisé quand |
|---|---|
| `illenium` | illenium-appearance démarré (Qbox / QBCore) |
| `esx` | esx_skin + skinchanger démarrés |
| `internal` | aucun des deux : le menu garde la tête dans `data/barber_looks.json` et la remet à chaque spawn |

## Pour les développeurs
- Événement serveur `adminmenu:barber:paid` (src, total, idPnj, panier) : verser l'argent à une société, logs…
- Événement client `adminmenu:barber:saved` (tête, mode).
- Exports : `exports.admin_menu:IsBarberOpen()` (client), `exports.admin_menu:GetBarberLook(src)` (serveur).
