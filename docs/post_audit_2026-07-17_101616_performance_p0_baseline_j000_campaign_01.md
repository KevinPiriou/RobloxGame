# P0 - Baseline J-000, campagne 01

## Etat initial
Commit : `88c73ca` plus les modifications P0 du worktree non committe.

Scenario : campagne Admin `p0_complete`, seed `17072026`, Studio local,
un joueur. La campagne a termine les sept scenarios (`7/7`) en `815,02 s`.

Mesures : tous les scenarios sont marques `comparable=true` et
`validation=ok`. Le client n'a donc signale ni perte de focus ni changement de
viewport pendant la campagne.

## Hypothese
Quel cout est suspecte ?

La simulation des monstres est le cout dominant a partir de 250 monstres. Les
projectiles soutenus et les collectibles de fusion ne montrent pas encore une
pression equivalente dans ce protocole.

Pourquoi ?

Le P95 du tick monstre passe de `6,47 ms` a 100 monstres a `20,69 ms` a 250,
`52,51 ms` a 500 et `134,31 ms` a 1 000. Le frame time client suit la meme
pente. Cela ne prouve pas encore une causalite unique dans Studio, mais les
deux mesures convergent vers la meme zone de charge.

## Protocole
Comment la comparaison est-elle rendue reproductible ?

- campagnes en mode Admin `p0_complete` ;
- seed fixe `17072026` ;
- 15 s de chauffe, 90 s de mesure, 2 s de nettoyage et 8 s de repos observe
  par scenario ;
- VFX adaptatifs verrouilles a la qualite manuelle pendant la campagne ;
- aucune interaction, redimensionnement, perte de focus ou changement de
  reglage pendant les sept scenarios ;
- validation client de comparabilite exigee scenario par scenario.

## Modification etudiee
Description technique : aucune optimisation gameplay n'est etudiee dans cette
campagne. Elle mesure le protocole P0 calibre.

Fichiers concernes : aucun fichier de runtime n'est modifie par cette mesure.
Ce rapport archive seulement le resultat de session transmis par
`P0_CAMPAGNE`.

Risques :

- `n=1` ne permet pas d'estimer la variance naturelle ;
- Studio local partage des ressources entre serveur et client, donc il ne
  separe pas parfaitement les couts CPU serveur, CPU client et GPU ;
- le rapport compact ne contient pas les compteurs reseau, le nombre de
  projectiles actifs ni le detail des categories memoire ;
- la memoire apres campagne peut inclure le prechauffage des pools et des
  assets Studio, pas uniquement une memoire residuelle du gameplay.

## Resultats
Avant : la campagne de calibration precedente etait invalidee pour baseline
car le viewport et le focus avaient change. Ses chiffres servent de diagnostic
historique, pas de comparaison avant/apres.

Apres : premiere campagne P0 propre et comparable.

| Scenario | Frame P95 client (ms) | Equivalent FPS P95 | Tick monstre P95 (ms) | Lecture |
| --- | ---: | ---: | ---: | --- |
| `monsters_25` | 7,57 | 132,1 | 1,16 | sous le budget 60 FPS |
| `monsters_100` | 9,13 | 109,5 | 6,47 | sous le budget 60 FPS |
| `monsters_250` | 28,79 | 34,7 | 20,69 | budget 60 FPS depasse |
| `monsters_500` | 69,78 | 14,3 | 52,51 | stress test, non viable comme cible de run |
| `monsters_1000` | 185,12 | 5,4 | 134,31 | plafond debug uniquement |
| `projectiles_24` | 8,24 | 121,4 | 3,48 | charge pilote contenue, concurrence a confirmer |
| `collectibles_fusion_300` | 7,39 | 135,3 | 0,01 | creation/fusion initiale contenue |

Memoire serveur campagne :

- avant campagne : `2 140,98 MB` ;
- apres campagne : `3 590,49 MB` ;
- ecart brut : `+1 449,51 MB` (`+67,7 %`).

Cet ecart n'est pas qualifie de fuite. La campagne fait monter les pools et
charge de nombreux assets jusqu'au palier 1 000 ; il faut deux repetitions
dans les memes conditions et le detail `AfterCleanup` / `AfterIdle` pour
separer un prechauffage stable d'une croissance residuelle.

Variance : inconnue (`n=1`).

Regression : aucune modification produit n'est associee a cette campagne. Le
smoke benchmark a ete valide par la completion `7/7`, mais il ne remplace pas
un smoke gameplay distinct apres une future optimisation.

## Decision
Adjust.

La campagne est retenue comme baseline J-000 initiale, mais P0 reste ouvert.
Elle suffit a etablir une reference de depart et a exclure 500/1 000 ennemis
comme cible de fluidite, pas a fermer le chantier ni a attribuer le cout a un
sous-systeme unique.

## Conclusion
Gain demontre : aucun gain de performance n'est revendique. Le gain est une
mesure propre, reproductible et exploitable.

Limites : deux campagnes comparables manquent encore ; une capture
MicroProfiler ou Developer Console reseau manque egalement. Le mode Studio
local ne permet pas encore de conclure separement sur CPU serveur, CPU client,
GPU, replication et bande passante.

Etape suivante : executer deux nouvelles campagnes `p0_complete` dans le meme
environnement, relever les memes exports `P0_CAMPAGNE`, puis calculer les
min/max et la variance des P95. Capturer au moins une campagne avec le
MicroProfiler ou les statistiques reseau Roblox avant de decider la cloture de
P0 et l'ouverture de P1.

## Appendice chronologique - Campagne 02 partiellement comparable, le 2026-07-17 10:37 Europe/Paris

### Etat de la campagne

Identifiant : `P0C-7883142449-19447275`.

La campagne a termine `7/7` en `814,84 s`. Six scenarios sont comparables et
valides. `projectiles_24` est explicitement invalide par le client avec le
motif `fenetre_non_focalisee`.

La perte de focus a ete breve selon l'observation utilisateur. Cela ne change
pas la decision de protocole : un bref unfocus peut suspendre ou replanifier le
rendu client, modifier le frame pacing et alterer les percentiles. Une mesure
marquee non comparable ne peut pas devenir comparable par jugement a
posteriori, sinon le flag perd sa fonction de garde-fou.

### Resultats exploitables

| Scenario | Frame P95 campagne 01 | Frame P95 campagne 02 | Ecart | Tick monstre P95 campagne 01 | Tick monstre P95 campagne 02 |
| --- | ---: | ---: | ---: | ---: | ---: |
| `monsters_25` | 7,57 | 7,63 | +0,8 % | 1,16 | 1,17 |
| `monsters_100` | 9,13 | 9,06 | -0,8 % | 6,47 | 6,34 |
| `monsters_250` | 28,79 | 28,46 | -1,1 % | 20,69 | 20,63 |
| `monsters_500` | 69,78 | 70,49 | +1,0 % | 52,51 | 52,04 |
| `monsters_1000` | 185,12 | 177,10 | -4,3 % | 134,31 | 128,60 |
| `collectibles_fusion_300` | 7,39 | 7,42 | +0,4 % | 0,01 | 0,01 |

Ces six releves montrent une variance initiale basse dans cet environnement.
Ils renforcent la pente et les seuils observes lors de la campagne 01, sans
fermer P0 car le sous-scenario projectile ne possede toujours qu'une mesure
comparable.

`projectiles_24` passe de `8,24 ms` lors de la campagne 01 a `25,45 ms` lors
de cette campagne invalide. Cet ecart de `+208,9 %` ne doit ni etre moyenne ni
etre attribue aux projectiles. Il prouve au contraire que le critere de focus
est utile : accepter cette valeur sans reserve fausserait immediatement la
baseline projectile.

### Memoire

- campagne 02 avant : `2 922,31 MB` ;
- campagne 02 apres : `4 231,63 MB` ;
- delta interne campagne 02 : `+1 309,32 MB`.

Le delta est proche, sans etre identique, a celui de la campagne 01
(`+1 449,51 MB`). Le niveau de depart varie toutefois fortement entre les deux
sessions. Sans les releves detailes `AfterCleanup` et `AfterIdle`, il est trop
tot pour conclure a une stabilisation comme a une fuite.

### Decision

`Adjust` : conserver les six repetitions comparables comme donnees
secondaires, exclure `projectiles_24` de toute moyenne et executer une campagne
03 integralement comparable. Cette campagne devra aussi porter une capture
MicroProfiler ou Developer Console pour la partie reseau.
