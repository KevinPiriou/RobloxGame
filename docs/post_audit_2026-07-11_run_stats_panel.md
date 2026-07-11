# 2026-07-11 - Panneau statistiques de run

## Objectif

Ajouter une liste de statistiques de run inspiree des panneaux de survivor-like.
Elle doit rester visible tant que la run est en pause, notamment pendant une pause manuelle,
un choix de niveau, un choix de perk par shrine ou la decision finale d'un coffre.

## Implementation

- `PerkService` enrichit le RemoteEvent existant `Perk_UpdateStats` avec `DisplayStats`.
- Les valeurs envoyees correspondent aux calculs appliques par le gameplay : degats normaux
  et elites, cadence, projectiles, rebonds, vitesse et duree des projectiles, rayon de
  collecte, multiplicateurs XP/or et multiplicateur d'ennemis.
- `RunStatsUI.client.luau` cree un panneau client independant du HUD courant, avec les
  sections `Survie`, `Attaque` et `Mobilite et gain`.
- Le panneau ecoute `Combat_PauseState` et `Run_StateUpdate` : il est masque hors run et
  affiche a chaque pause de run sans modifier les interfaces de choix existantes.

## Validation

- `rojo build -o TestRoblox.rbxlx` termine avec succes.
- `git diff --check` ne remonte aucune erreur de contenu.
- Aucun changement de logique de combat, de coffre ou de choix de perk n'est necessaire.

## Angles morts

- Angle mort : le rendu visuel doit etre confirme dans un Play Test Studio sur une resolution desktop
  et une resolution etroite. Le build valide la synchronisation et la syntaxe, pas les
  recouvrements visuels reels avec les panneaux de choix.
- Angle mort : les statistiques affichent l'arme actuelle `Fireball`. Lors de l'ajout de plusieurs
  armes independantes, le panneau devra devenir une liste par arme plutot qu'une seule
  colonne de valeurs d'attaque.
