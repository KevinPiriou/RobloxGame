# TODO - Observabilite P0 complete reportee

## Statut

P0 a ete clos localement pour permettre P1 sur la simulation des monstres. Ce
document ne signifie pas que les criteres P0 complets ont ete atteints.

## Restant a faire

1. Realiser deux campagnes `p0_complete` entierement comparables afin de
   completer la variance par scenario, notamment `projectiles_24`.
2. Capturer au moins un dump MicroProfiler avec donnees reseau sur un scenario
   representatif, de preference `monsters_250` ou `monsters_500`.
3. Relever `AfterCleanup` et `AfterIdle` sur plusieurs sessions identiques pour
   separer prechauffage des pools, cache Studio et memoire residuelle.
4. Rejouer une baseline sur un environnement publie prive ou un appareil reel
   avant toute conclusion de performance produit multi-joueur.
5. Reouvrir P0-complet si une phase P1 a un effet ambigu sur le reseau, la
   memoire ou la sensation de frame pacing.

## Conditions de reouverture

Le chantier P0-complet redevient bloquant si :

- une optimisation de P1 reduit le tick monstre mais augmente les freezes ;
- une croissance memoire persiste apres plusieurs runs nettoyes ;
- le profil publie ou multi-joueur diverge fortement de Studio local ;
- un cout reseau ou de replication devient suspect.
