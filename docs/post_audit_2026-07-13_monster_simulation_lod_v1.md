# Post-audit - 2026-07-13 - Monster Simulation LOD V1

## Objectif

Reduire le cout serveur de la horde sans refaire le gameplay : les ennemis proches doivent rester fluides et dangereux, les ennemis eloignes doivent continuer a rejoindre le joueur a cadence reduite, et les ennemis vraiment perdus doivent toujours retourner dans le pool.

## Implementation

`CombatConfig` porte les seuils suivants :

| Zone | Distance | Cadence | Travail effectue |
| --- | ---: | ---: | --- |
| Complete | `0 - 100` studs | Heartbeat | Mouvement, separation, bob procedural et degats. |
| Reduite | `100 - 160` studs | `10 Hz` | Mouvement simple sans separation, bob ni degats. |
| Distante | `160 - 220` studs | `2 Hz` | Mouvement simple sans separation, bob ni degats. |
| Hors zone | `> 220` studs | - | Retour au pool existant. |

Les valeurs sont configurees dans `src/shared/CombatConfig.luau` :

- `MonsterFullSimulationDistance = 100`
- `MonsterReducedSimulationDistance = 160`
- `MonsterReducedSimulationHz = 10`
- `MonsterDistantSimulationHz = 2`

Le boss reste toujours en simulation complete tant qu'il n'est pas au-dela de la distance de despawn. Les elites utilisent les memes seuils que les ennemis standards.

`MonsterService` construit une liste des joueurs actifs une seule fois par tick. Cette liste est reutilisee pour le choix de cible et les degats, au lieu de rechercher a nouveau personnage, Humanoid et `HumanoidRootPart` pour chaque monstre.

La grille spatiale continue de contenir tous les monstres actifs. Un monstre reduit ou distant met a jour sa cellule lorsqu'il effectue son mouvement planifie ; le ciblage des armes reste donc serveur et spatial.

## Instrumentation

Le log `Perf monstres serveur` contient maintenant :

- `LodFull`, `LodReduced`, `LodDistant` et `LodDespawned` ;
- `LodFullSteps`, `LodReducedSteps` et `LodDistantSteps` ;
- `LodPlayerTargets`.

Ces valeurs servent a verifier que le plafond debug ne force plus tous les monstres a faire separation et `PivotTo` a chaque frame.

## Validation technique

- `rojo build -o $env:TEMP\TestRoblox-monster-simulation-lod-v1.rbxlx` termine avec succes ;
- `git diff --check` ne remonte aucune erreur de contenu ;
- aucun marqueur de conflit Git n'est present dans `src` ou `docs`.

## Smoke manuel canonique bloquant

1. Lancer une run normale : les ennemis generes entre 38 et 62 studs doivent etre dans la zone complete et conserver leur mouvement fluide actuel.
2. Courir loin d'une horde : les ennemis entre 100 et 160 studs doivent rejoindre le joueur sans former de blocage ni causer de degats avant leur entree dans la zone complete.
3. Revenir vers des ennemis distants : ils doivent reprendre un mouvement fluide avant d'etre dans la portee de Fireball et avant de pouvoir attaquer.
4. Utiliser `Spawn 100 ennemis` puis observer les logs `Perf` : la somme des zones doit etre coherente avec le nombre d'ennemis vivants et les ennemis eloignes ne doivent pas produire majoritairement de `FullSteps`.
5. Declencher une elite et un boss : les elites conservent leur pack, le boss garde un mouvement et ses patterns fluides, et leurs morts/drops restent inchanges.
6. Tuer tous les ennemis via admin, puis relancer une run : aucun monstre bloque ne doit rester dans `CombatRuntime/Monsters`.

## Evaluation

- Juste : les decisions de cible, mouvement, collision, degats, mort et recompense restent sur le serveur.
- Juste : la zone complete couvre la portee de Fireball actuelle (`90` studs) avec une marge de dix studs, ce qui preserve le comportement combat visible.
- Simplification : le LOD est entierement dans `MonsterService`. Il n'ajoute ni interpolation client, ni nouveaux remotes, ni etat replique par monstre.
- Angle mort : un monstre de la zone distante peut avancer par pas visibles si une camera a tres longue portee le regarde. Cette zone est volontairement hors du rayon de combat ; si ce cas est frequemment visible, il faudra d'abord augmenter le rayon complet ou reduit avant d'introduire une interpolation client.
- Angle mort : le gain dependra de la repartition spatiale reelle. Une horde compacte autour du joueur restera presque entierement en zone complete, ce qui est normal : il serait faux de degrader le danger immediat uniquement pour afficher un meilleur chiffre de performance.
