# 2026-07-12 00:12 CEST - Panneaux placeholders du menu lobby

## Perimetre realise

Le menu lateral `LobbyShortcutMenu` dispose maintenant d'un `ScreenGui` compagnon nomme `Menus` et de quatre panneaux relies a ses raccourcis :

- `ShopPanel` pour la Boutique ;
- `QuestsPanel` pour les Quetes ;
- `UnlocksPanel` pour les Deblocages ;
- `HousingPanel` pour le Refuge.

Chaque panneau contient trois placeholders adaptes a sa future fonction. Les contenus n'executent aucune logique de boutique, de Robux, de progression ou de persistance. Ils servent uniquement de surface d'interface stable pour les prochains chantiers.

## Contrat d'interface

`LobbyShortcutMenu` conserve la responsabilite de la selection et de la visibilite. `LobbyPanels` ne fait que creer les panneaux et synchroniser leur fermeture :

- clic sur un raccourci : ouverture du panneau associe ;
- second clic, touche `Echap` ou bouton `X` : fermeture synchronisee ;
- debut de run : le menu lateral ferme deja les panneaux et devient indisponible.

Les noms de panneaux sont explicites et correspondent directement au `PanelName` des raccourcis. Cela evite une dependance implicite entre le texte visible et les objets GUI.

## Validation technique

- `rojo build -o TestRoblox.rbxlx` termine avec succes ;
- `git diff --check` ne remonte aucune erreur de contenu ;
- l'artefact genere contient le LocalScript `LobbyPanels`.

## Smoke manuel canonique a effectuer dans Studio

1. Hors run, ouvrir puis refermer chacun des quatre raccourcis avec la souris.
2. Refaire une ouverture avec les touches `1` a `4`, puis fermer avec `Echap`.
3. Lancer une run alors qu'un panneau est ouvert : le panneau et le menu lateral doivent disparaitre.
4. Tester une petite fenetre : le panneau doit se centrer et rester utilisable sans recouvrir entierement l'ecran.

## Angles morts

- Les donnees reelles des Quetes, Deblocages et Refuge n'existent pas encore ; les compteurs sont des placeholders.
- La Boutique ne contient volontairement aucun achat ni appel de monetisation.
- Le smoke manuel dans Roblox Studio reste la preuve produit necessaire avant de considerer la surface lobby comme stabilisee.
