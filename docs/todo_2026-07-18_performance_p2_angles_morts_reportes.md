# TODO - Angles morts reportes apres P2

Date : 2026-07-18 Europe/Paris

## Client frame spikes

Observation : la smoke P2.4 contient un pic client de `275 ms` avant le
lancement de la run et un pic de `139 ms` vers la fin de run. Les logs actuels
ne permettent pas de distinguer correctement Studio, focus, replication, VFX,
collectables, garbage collector ou rendu.

Action future : construire une phase client qui relie les frame spikes aux VFX,
lumieres, draw calls, collectables et evenements reseau, sans supposer que le
serveur de monstres est responsable.

## Cache partage de sol

Observation : `GroundSurfaceCacheCells` atteint `2 878` cellules pendant la
smoke P2.4 et revient a zero apres la fin de run. Le cache est donc nettoye,
mais sa croissance pendant une longue run n'est pas encore quantifiee.

Action future : mesurer LuaHeap et memoire serveur sur une run longue, puis
decider avec donnees s'il faut une limite de taille, une invalidation par zone
ou conserver la borne naturelle de la map.

## Interactivables traverses par les monstres

Observation : les monstres peuvent traverser visuellement coffres, shrines,
totems et portail. C'est la consequence attendue de P1 : mouvement cinematique
et collisions physiques desactivees pour la horde.

Action future : si la direction produit confirme le besoin, concevoir un
evitement statique local, spatial et budgete. Ne pas reactiver les collisions
globales de la horde comme raccourci.

## Nettoyage massif

Observation : P2.3 a releve un pic client apres le nettoyage de plus de cent
monstres. Le recyclage courant limite les repositionnements, mais le nettoyage
administratif et la fin de run n'ont pas de benchmark cible dedie.

Action future : instrumenter separement la liberation ou le retour de pool de
masse avant de modifier ce chemin.
