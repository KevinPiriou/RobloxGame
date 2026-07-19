# Redressement du cycle de vie des runs

Date : 2026-07-18

## Etat initial

Le cas canonique suivant etait bloque : apres une mort, ou apres une sortie de niveau, le joueur ne pouvait pas enchainner une nouvelle run. Le lanceur pouvait rester affiche comme si une generation etait encore en cours.

Ce defaut bloquait aussi la validation multi-run de P1. Une campagne de performance ne vaut rien si le cycle produit de creation, utilisation, destruction puis recreation de la run ne tient pas.

## Hypothese

Trois causes se cumulaient :

1. `RunLauncher` persiste apres le retour au lobby, mais son verrou local `isBusy` ne suivait pas la transition `IsRunActive=true` vers `false`.
2. Un echec pendant le nettoyage de monde pouvait interrompre la finalisation de session avant la liberation du proprietaire runtime.
3. La sortie volontaire apres victoire ne demandait pas systematiquement le retour lobby, contrairement a la mort.

## Modification etudiee

- `src/client/RunLauncher.client.luau` : reinitialisation explicite du verrou du lanceur lorsque la run devient inactive.
- `src/server/RunSessionService.luau` : nettoyage de `RunLoading`, monde runtime et map protege individuellement ; la session et son proprietaire sont liberes meme si une etape echoue, avec un warning structure.
- `src/server/RunEndService.luau` : toute fin de run demande le retour lobby lorsque le service de teleport le permet ; un resultat absent de `CompleteRun` est trace.

Le serveur conserve l'autorite sur la cloture de session et la destruction du monde. La modification ne change ni les recompenses, ni les statistiques de run, ni les regles de combat.

## Validation

Smoke manuel canonique valide par le responsable produit : plusieurs morts puis relances successives de runs, sur les trois variantes de map, dans la meme session Studio.

Verification technique : `rojo build` a construit le projet apres la modification. Le diff ne contient pas de conflit ni de modification de test de regression.

## Decision

`Keep`.

## Angles morts

- La sortie volontaire apres victoire est couverte par le code, mais n'a pas encore recu son smoke manuel explicite apres ce correctif.
- Les `pcall` de nettoyage evitent qu'une session reste verrouillee ; ils ne doivent pas masquer une erreur recurrente. Les warnings `RunSession` devront etre surveilles pendant les prochains tests.
- Le comportement de retour dans un serveur publie reserve reste a verifier separement du test Studio local.

## Conclusion

Le rail simple "mort -> lobby -> nouvelle run" est de nouveau fonctionnel et permet de reprendre P1. La phase P1 reste ouverte jusqu'au releve physique final apres retour au lobby.
