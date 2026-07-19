# P2 - Simulation des monstres

## Etat initial

Commit : `171ae5a`, avec les modifications locales non committe du chantier
P2.

Scenario : baseline P0 fixe, campagnes P2 avec seed `17072026`, smokes de run
reelle et smoke ciblee de lissage de vague. Les campagnes synthetiques et les
runs reels sont volontairement lus comme deux preuves complementaires : la
premiere isole les couts de horde, la seconde observe les vagues, le recyclage
et la sensation produit.

Mesures P0 de reference :

| Scenario | Frame P95 | Monstre P95 |
| --- | ---: | ---: |
| 25 monstres | 7,57 ms | 1,16 ms |
| 100 monstres | 9,13 ms | 6,47 ms |
| 250 monstres | 28,79 ms | 20,69 ms |
| 500 monstres | 69,78 ms | 52,51 ms |
| 1 000 monstres | 185,12 ms | 134,31 ms |

## Hypothese

Quels couts etaient suspects ? La separation de horde visitait trop de voisins,
le suivi du sol raycastait des surfaces planes redondantes et les creations de
monstres pouvaient arriver en bloc.

Pourquoi ? Ces couts progressaient avec la densite, alors que le combat ne
necessite ni une large recherche de voisinage ni une recreation instantanee de
toute une vague.

## Protocole

Les memes paliers P0 ont ete compares pour le mouvement serveur. La campagne
synthetique a ete completee par :

- une smoke de relief et combat reel ;
- une smoke du bouton admin de 100 monstres ;
- une smoke de vagues ordinaires avec les compteurs de lots ;
- le cas canonique de fin de run avec retour a `Alive=0` et pool reutilisable.

## Modification etudiee

Description technique :

- grille de separation persistante, dimensionnee sur le rayon reel de
  separation ;
- cache partage de hauteur limite aux surfaces planes ancrees et validees ;
- telemetrie P2 par cout : ciblage, LOD, mouvement, separation, suivi du sol,
  evitement, degats, spawns et recyclage ;
- file admin de 100 monstres en lots de cinq ;
- file de vagues ordinaires limitee a quatre creations par `Heartbeat` ;
- recyclage limite a deux monstres par passe ;
- aucune modification des degats, vitesses, rayons, cibles ou plafond logique
  des vagues.

Fichiers concernes :

- `src/server/MonsterService.luau`
- `src/server/PerformanceBenchmarkService.luau`
- `src/server/PerformanceTelemetryService.luau`
- `src/server/WorldSpawnService.luau`
- `src/shared/CombatConfig.luau`

Risques : les vagues massives arrivent maintenant par une courte sequence au
lieu d'un bloc. Ce changement est produit et perceptible dans son rythme, mais
le total demande est conserve. Le cache de sol reste intentionnellement absent
des rampes et surfaces ambigues, qui gardent le raycast exact.

## Resultats

| Scenario | Monstre P95 avant | Monstre P95 apres | Ecart |
| --- | ---: | ---: | ---: |
| 25 monstres | 1,16 ms | 1,00 ms | -13,8 % |
| 100 monstres | 6,47 ms | 3,40 ms | -47,4 % |
| 250 monstres | 20,69 ms | 11,18 ms | -45,9 % |
| 500 monstres | 52,51 ms | 30,81 ms | -41,3 % |
| 1 000 monstres | 134,31 ms | 90,86 ms | -32,3 % |

Le frame P95 serveur passe de `28,79` a `18,58 ms` a `250` monstres, de
`69,78` a `46,43 ms` a `500`, et de `185,12` a `131,78 ms` a `1 000`.

La separation P95 a `1 000` passe de `100,87` a `44,68 ms`. Le suivi de sol
P95 a `1 000` passe de `15,41` a `2,73 ms`, sans raycast de sol pendant la
fenetre mesuree apres warm-up sur les surfaces planes cachees.

La smoke P2.4 prouve le bornage de creation ordinaire : la plus grande demande
observee de `12` est traitee par `3` lots de `4`, avec `WavePending=0` apres
drainage. Le spawn debug de `100` passe auparavant de plus de `133 ms` dans un
bloc a des lots inferieurs a `15 ms` lors de P2.3.

Variance : les valeurs faibles, notamment a `25` monstres, ne sont pas assez
eloignees du bruit Studio pour conclure a un gain important. Les gains retenus
concernent les densites de `100` et plus, et sont confirmes par plusieurs
campagnes P2.

Regression : les smokes manuels valident combat, relief, collecte, projectiles,
fin de run et reprise de run. Aucun changement de vitesse, de degat ou de
densite cible n'est introduit. Le recyclage et les vagues sont seulement
etales.

## Decision

`Keep` et cloture de P2 dans son perimetre : le cout CPU serveur de horde est
sensiblement reduit, les creations massives sont bornees et la simulation reste
autoritaire.

## Conclusion

Gain demontre : le P95 de simulation de monstre est reduit de `32,3 %` a
`47,4 %` entre `100` et `1 000` monstres, avec une reduction de `55,7 %` du
cout P95 de separation a `1 000` et une creation de vague etalee a quatre
monstres par frame.

Limites : P2 ne mesure pas un gain GPU ou client. Les deux pics client isoles
vus dans une smoke ne sont pas attribuables avec certitude. La collision des
monstres avec les interactivables reste volontairement inactive : une future
passe devra choisir un evitement statique local si le produit exige un vrai
contournement.

Etape suivante : ouvrir la phase suivante uniquement apres lecture du
`todo_2026-07-18_performance_p2_angles_morts_reportes.md`. Les outils P0 et
les compteurs P2 restent la reference de toute optimisation ulterieure.
