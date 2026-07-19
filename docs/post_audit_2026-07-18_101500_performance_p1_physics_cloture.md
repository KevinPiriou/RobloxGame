# P1 - Physics memory usage

## Etat initial

Commit : `171ae5a` avec les corrections locales non commit du cycle de vie de run.

Scenario : trois variantes de map regenerees dans une meme session Studio, puis retour au lobby apres la derniere run et inventaire physique hors run.

Mesures :

- `P1-Physics-64730161` : `PhysicsParts=51.49 MB`, `PhysicsCollision=0.24 MB`, `runtimeParts=3196` pendant run ;
- `P1-Physics-64854003` : `PhysicsParts=61.56 MB`, `PhysicsCollision=0.25 MB`, `runtimeParts=3380` pendant run ;
- `P1-Physics-64937262` : `PhysicsParts=64.75 MB`, `PhysicsCollision=0.25 MB`, `runtimeParts=3019` pendant run ;
- `P1-Physics-65580531` : retour lobby, `runtimeParts=0`, `PhysicsParts=67.79 MB`, `PhysicsCollision=0.25 MB`.

## Hypothese

Quel cout est suspecte ? La participation physique non justifiee des assets Studio et une retention de monde runtime apres plusieurs runs.

Pourquoi ? Les assets importes, les decorations, les interactivables et les templates peuvent porter des collisions, touches, requetes, contraintes ou joints inutiles. Sans audit, leur cout se confond avec celui de la simulation combat.

## Protocole

La comparaison a ete rendue reproductible par le meme bouton `Inventaire physique P1`, les memes familles de templates et runtime inspectees, et un cycle produit simple : lancement, mort, retour lobby, nouvelle run.

Les trois runs ne sont pas des comparaisons de volume identiques : leurs maps generees sont differentes. Les comparaisons legitimement utilisables sont donc les proprietes par categorie et la disparition complete du runtime au lobby, pas un delta brut de megabytes entre variantes.

## Modification etudiee

Description technique :

- audit P1 structure des templates et du runtime ;
- normalisation runtime des collectables, interactivables et relief genere ;
- conservation explicite de `CanQuery` sur les seules surfaces consultees par les raycasts de spawn ;
- redressement du cycle de vie pour garantir que la destruction du monde ne bloque pas la session suivante.

Fichiers concernes :

- `src/server/PhysicsAuditService.luau`
- `src/server/CoinService.luau`
- `src/server/XpService.luau`
- `src/server/ChestService.luau`
- `src/server/JarService.luau`
- `src/server/TotemService.luau`
- `src/server/ShrineService.luau`
- `src/server/PortalService.luau`
- `src/server/ProceduralMapService.luau`
- `src/client/RunLauncher.client.luau`
- `src/server/RunEndService.luau`
- `src/server/RunSessionService.luau`

Risques : une future feature qui utiliserait un `Touched` ou un raycast sur un element normalise doit declarer son besoin et reactiver uniquement la propriete de la piece concernee. Les sources dans `ServerStorage` restent volontairement descriptives ; les services de preparation runtime restent la barriere de securite.

## Resultats

Avant : aucune vision consolidee des proprietes physiques par asset et aucune preuve que les mondes de run etaient detruits entre plusieurs runs.

Apres :

- tous les dossiers runtime audites sont vides apres retour lobby : `CombatRuntime`, loot, shrines, coffres, jarres, totems, portail et `MapRuntime` affichent chacun `0` partie ;
- le rapport final contient `runtimeParts=0`, `unanchored=0`, `constraints=0`, `joints=0` pour le runtime ;
- les runs actives conservent les invariants retenus : combat sans collision/touch/query, interactivables sans touch/query hors exception explicite, relief sans touch et avec query seulement pour les raycasts de spawn ;
- les mesures avant/apres de chaque inventaire sont stables a l'echelle du scan.

Variance : les trois variantes ne comportent pas le meme nombre de parties, meshes, constraints et joints. `PhysicsParts` varie donc de `51.49` a `64.75 MB` pendant les runs. La valeur lobby a `67.79 MB` ne prouve pas une retention de map puisque le runtime est vide ; Roblox Studio peut conserver des allocations internes dans la session.

Regression : les smokes manuels ont valide generation, parcours du relief, prompts, ouverture de coffre normal, coffre de recompense au contact, jarres, shrines, totems et portail. Les morts puis relances successives sont valides.

## Decision

`Keep` et cloture de P1 dans son perimetre : inventaire, normalisation des participations physiques inutiles et preuve de destruction runtime.

## Conclusion

Gain demontre : reduction structurelle des surfaces qui participent aux touches et requetes sans raison gameplay, plus absence verifiee de monde de run residuel apres retour lobby.

Limites : aucun gain global de `PhysicsParts` en MB ne peut etre attribue avec rigueur entre les trois variantes de map. Le cout dominant reste potentiellement la geometrie et les joints des decorations generees, sujet a mesurer dans une phase ulterieure plutot qu'a optimiser a l'aveugle.

Etape suivante : ne pas modifier la physique sans nouvel etat de reference. La prochaine phase performance devra partir de P0 et isoler son propre cout cible.
