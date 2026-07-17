# P0 - Cloture locale de baseline CPU/frame

## Etat initial
Commit : `88c73ca` plus le worktree P0 non committe.

Scenario : deux campagnes `p0_complete` de sept scenarios. La premiere est
integralement comparable ; la seconde est partiellement comparable a cause de
`projectiles_24` marque `fenetre_non_focalisee`.

Mesures : deux repetitions proches existent pour les scenarios monstres et
collectibles, une seule repetition comparable existe pour les projectiles.

## Hypothese
Quel cout est suspecte ?

La simulation serveur des monstres est le premier cout a etudier en P1.

Pourquoi ?

Le tick monstre P95 et le frame P95 augmentent ensemble de facon tres nette.
Le palier 250 franchit deja le budget 60 FPS ; 500 et 1 000 ne sont pas des
cibles de run jouable dans l'etat actuel.

## Protocole
Comment la comparaison est-elle rendue reproductible ?

Le protocole P0 calibre est conserve : seed fixe, scenarios Admin fixes,
chauffe de 15 s, mesure de 90 s, nettoyage de 2 s, repos de 8 s et verrou VFX
adaptatif. Les resultats futurs P1 devront etre compares a la campagne P0
integralement comparable `P0C-7883142449-17802070`.

## Modification etudiee
Description technique : aucune optimisation n'est appliquee. La decision est
un changement de perimetre de validation, demande par le responsable produit.

Fichiers concernes : documentation uniquement.

Risques :

- le reseau n'est pas mesure par un dump MicroProfiler ;
- la stabilite memoire apres plusieurs runs n'est pas demontree ;
- la variance du scenario projectile n'est pas connue ;
- une optimisation P1 pourrait deplacer le cout vers le GPU, la replication
  ou la memoire sans que cette baseline locale le detecte seule.

## Resultats
Avant : pas de baseline synchronisee exploitable.

Apres : baseline locale CPU/frame disponible.

| Palier monstres | Frame P95 client (ms) | Tick monstre P95 (ms) |
| --- | ---: | ---: |
| 25 | 7,57 | 1,16 |
| 100 | 9,13 | 6,47 |
| 250 | 28,79 | 20,69 |
| 500 | 69,78 | 52,51 |
| 1 000 | 185,12 | 134,31 |

La seconde campagne confirme les paliers monstres comparables avec un ecart de
frame P95 compris entre `-4,3 %` et `+1,0 %`.

Variance : suffisamment borne pour demarrer un P1 CPU/monstres, insuffisante
pour declarer une variance globale de tout le systeme.

Regression : aucune modification gameplay n'est incluse dans P0.

## Decision
Keep, avec perimetre explicitement reduit.

`P0-local` est clos : il constitue le referentiel CPU/frame Studio pour les
phases P1 a P12. `P0-complet` est reporte, non annule ; ses angles morts sont
portes dans le todo associe.

## Conclusion
Gain demontre : une reference locale robuste existe pour les couts de
simulation des monstres et les frame times client. Aucun gain de performance
n'est revendique.

Limites : le referentiel ne distingue pas completement CPU serveur, CPU client,
GPU, reseau et memoire. Il ne doit jamais etre presente comme une preuve de
performance publiee ou multi-joueur.

Etape suivante : cadrer P1 sur une hypothese unique, mesurable et reversible
du `MonsterService`, avec comparaison directe contre le palier P0 retenu.

Budget de complexite : aucune complexite runtime ajoutee ; la dette de mesure
est deplacee dans un backlog explicite plutot que masquee.
