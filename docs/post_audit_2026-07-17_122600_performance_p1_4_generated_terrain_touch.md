# P1.4 - Relief genere : retrait de la participation tactile

Date : 2026-07-17 12:26:00

## Etat initial

Commit : `88c73ca` (arbre de travail du chantier P1).

Scenario : run locale avec relief procedural, rampes, spawns de combat et interactables generes.

Mesures : audit `P1-Physics-25328165` : `GeneratedTerrain` contribuait avec `117` parties collidables, tactiles et interrogeables.

## Hypothese

Le relief doit rester collidable pour le parcours et interrogeable pour les raycasts de spawn/sol. Aucune connexion `Touched` ne lit ses parties : sa participation tactile est donc superflue.

## Protocole

1. Ne modifier que `CanTouch` dans la preparation runtime du relief.
2. Conserver `Anchored=true`, `CanCollide=true`, `CanQuery=true`.
3. Compiler Rojo et verifier le diff.
4. Verifier manuellement parcours, rampes, spawns et interactions.
5. Relever l'inventaire P1 avec une map generee et du loot runtime.

## Modification etudiee

Description technique : `setGeneratedTerrainProperties` impose maintenant `CanTouch=false` aux bases, plateformes, rampes et liens generes.

Fichier concerne : `src/server/ProceduralMapService.luau`.

Risques : un futur systeme Studio peut introduire une connexion tactile sur le relief sans passer par le code actuel. Dans ce cas, ce systeme devra declarer explicitement son besoin et reactiver seulement les parties concernees.

## Resultats

Avant : `GeneratedTerrain`, `CanCollide=117`, `CanTouch=117`, `CanQuery=117`.

Apres, audit `P1-Physics-27104226` :

- `GeneratedTerrain` : `97` parties, `CanCollide=97`, `CanTouch=0`, `CanQuery=97` ;
- `GeneratedBase` : `2` parties, `CanCollide=2`, `CanTouch=0`, `CanQuery=2` ;
- `MapRuntime` : `CanTouch=0`, `CanQuery=99`.

Memoire immediate : `2730.25 -> 2730.25 MB` total, `PhysicsParts=161.02 MB`, `PhysicsCollision=1.62 MB`.

Variance : le nombre de parties du relief varie avec le seed et la generation ; le changement prouve la propriete runtime, pas un gain absolu de memoire entre maps differentes.

Regression : aucune lors du smoke manuel : spawn, ouverture et interactions sont restes fonctionnels.

## Decision

`Keep`.

## Conclusion

Gain demontre : suppression de `CanTouch` sur toutes les surfaces de relief runtime inspectees, sans retirer les garanties de collision et de raycast necessaires.

Limites : aucune mesure de frame ou de memoire comparable ne permet d'attribuer un gain chiffre a cette reduction.

Etape suivante : lancer plusieurs cycles comparables creation/destruction de map et relever P1 apres chaque cycle avant de cloturer la phase.
