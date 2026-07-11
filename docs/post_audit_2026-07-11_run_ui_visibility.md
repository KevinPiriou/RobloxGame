# 2026-07-11 - Visibilite des interfaces lobby et run

## Regle appliquee

Les deux surfaces ne sont plus disponibles au meme moment :

- `LobbyShortcutMenu` est visible et interactif uniquement hors run ;
- la top bar de `CombatUI` (kills, or, pause, temps) est visible uniquement pendant une run.

## Implementation

`RunStateService` replique maintenant l'attribut joueur `IsRunActive` en plus du RemoteEvent existant. Les deux LocalScripts ecoutent le remote pour les transitions et l'attribut pour couvrir le chargement tardif d'une interface.

Quand une run commence, le menu slide est masque, ses raccourcis clavier sont bloques et un panneau lobby deja ouvert est ferme. Quand la run se termine, le menu redevient disponible. La top bar est masquee hors run sans modifier le HUD de combat inferieur.

## Validation

- `rojo build -o TestRoblox.rbxlx` termine avec succes.
- `git diff --check` ne remonte aucune erreur de contenu.

## Angle mort

Les vrais contenus des panneaux Boutique, Quetes, Deblocages et Refuge restent a brancher dans le `ScreenGui` `Menus`. Cette passe ne modifie ni leur logique ni leur direction artistique.
