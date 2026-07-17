# P1.3 - Interactables runtime : participation tactile et requetes physiques

Date : 2026-07-17 12:18:00

## Etat initial

Commit : `88c73ca` (arbre de travail du chantier P1).

Scenario : run locale avec shrines, coffres, jarres, totems, portail et coffre de recompense elite `ChestOpen`.

Mesures : audit `P1-Physics-25328165` avant la normalisation. Les interactables ordinaires participaient tous aux collisions, touches et requetes physiques. Le coffre de recompense elite restait une exception fonctionnelle attendue, car son ouverture est declenchee par contact.

## Hypothese

Les interactables ordinaires utilisent des `ProximityPrompt` avec validation serveur de distance. Leur participation a `CanTouch` et `CanQuery` est donc injustifiee, alors que `CanCollide` peut rester un choix de parcours.

## Protocole

1. Conserver les collisions des interactables.
2. Imposer `CanTouch=false` et `CanQuery=false` sur les clones runtime.
3. Reactiver explicitement `CanTouch=true` uniquement pour le coffre de recompense avant le listener `Touched`.
4. Relever l'inventaire P1 avec runtime genere.
5. Verifier manuellement prompts ordinaires puis ouverture au contact de `ChestOpen`.

## Modification etudiee

Description technique : normalisation explicite des parties runtime des shrines, coffres, jarres, totems et portail. L'exception `ChestOpen` restaure `CanTouch=true` au moment de l'installation de son interaction tactile.

Fichiers concernes :

- `src/server/ShrineService.luau`
- `src/server/ChestService.luau`
- `src/server/JarService.luau`
- `src/server/TotemService.luau`
- `src/server/PortalService.luau`

Risques : une interaction non repertoriee pouvait dependre de `Touched` ou d'une requete physique. Ce risque est borne par les recherches de code et le smoke manuel, mais pas annule pour de futurs assets tiers importes dans Studio.

## Resultats

Avant : les interactables ordinaires participaient aux touches et requetes physiques.

Apres : audit `P1-Physics-26080844` :

- shrines : `CanTouch=0`, `CanQuery=0` ;
- coffres ordinaires : `CanTouch=0`, `CanQuery=0` ;
- jarres : `CanTouch=0`, `CanQuery=0` ;
- totems : `CanTouch=0`, `CanQuery=0` ;
- portail : `CanTouch=0`, `CanQuery=0` ;
- coffre de recompense : smoke manuel valide, ouverture au contact conservee.

Memoire : `PhysicsParts=149.73 MB`, `PhysicsCollision=1.61 MB` pendant le releve. La map etait differente du releve precedent : aucun gain memoire global ne peut etre attribue a cette seule modification.

Variance : le volume de terrain et de decor genere varie avec la run ; seules les proprietes runtime par categorie sont comparables directement.

Regression : aucune observee au smoke manuel canonique.

## Decision

`Keep`.

## Conclusion

Gain demontre : retrait de participations tactiles et de requetes inutiles sur les interactables ordinaires, sans perdre l'exception de coffre de recompense.

Limites : le gain en temps frame et en memoire globale reste non quantifie, car le volume de map runtime n'est pas fige entre les releves.

Etape suivante : P1.4, retirer uniquement `CanTouch` du relief genere, qui garde collision et raycast.
