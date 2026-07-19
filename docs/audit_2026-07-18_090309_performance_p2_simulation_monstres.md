# P2 - Simulation des monstres : etat de reference et protocole

Date : 2026-07-18 09:03 Europe/Paris.

## Etat mesure et connu

La baseline locale P0 fournit deja un signal CPU serveur suffisamment net pour
ouvrir P2 : le P95 du tick des monstres passe de `6,47 ms` a `100` monstres a
`20,69 ms` a `250`, `52,51 ms` a `500` et `134,31 ms` a `1 000`. Les paliers
`500` et `1 000` restent des stress tests de debug, pas une cible de gameplay
validee.

Le code actuel possede deja les fondations suivantes :

- une grille spatiale persistante, mise a jour uniquement lors du changement
  de cellule ;
- des requetes d'armes locales via `GetMonstersNear`, sans scan global pour le
  ciblage ou les impacts de projectile ;
- trois niveaux de LOD (`Full`, `Reduced`, `Distant`) et un recyclage de masse
  arriere ;
- un suivi de relief sans physique active de horde.

## Hypothese principale

La boucle `updateMonsterStep` visite actuellement tous les etats de monstre a
chaque Heartbeat lorsque `MonsterSimulationHz = 0`. Pour chaque etat vivant,
elle resout une cible, calcule la distance et le LOD, avant de decider si le
mouvement profond est du ou non. Le LOD diminue donc les mouvements, raycasts,
separations et degats, mais ne supprime pas le cout de la visite globale.

Le suivi du terrain est une seconde hypothese : les monstres actifs appellent
`FindSurfacePositionAtXZ` a intervalle borne, et l'evitement consulte un
raycast horizontal. Le compteur P0 existant melangeait ces raycasts avec les
autres consommateurs de `WorldSpawnService`.

## Points verifies avant modification

- La grille 2D actuelle est adaptee a la map essentiellement horizontale et
  aux requetes de proximite. Aucun Octree n'est justifie a ce stade.
- `updateSpawns` est appele dans chaque pas de simulation, mais le benchmark
  P0 active `benchmarkMode` : les spawns ordinaires sont donc volontairement
  absents du scenario de densite. Le cout de spawn devra etre mesure dans un
  scenario P2 distinct ou une run canonique ; il ne doit pas etre deduit des
  scenarii P0 de horde deja peuplee.
- Les degats restent serveurs et le mouvement demeure autoritaire. P2 ne
  deplacera pas cette autorite vers le client.

## Instrumentation P2.0 retenue

L'instrumentation sera active uniquement pendant une capture du service de
telemetrie. Elle enregistrera par pas de simulation :

- visites d'etats, resolution de cible et calcul LOD ;
- mouvement, separation, suivi du sol et cache de sol ;
- echantillons et raycasts de sol, evitement et raycasts d'evitement ;
- degats et spawn/recyclage ;
- P95 de chaque segment et compteurs cumules.

`WorldSpawnService` recevra un tag de telemetrie optionnel. Les appelants hors
combat conservent leur comportement et leurs options inchanges ; le tag ne
change ni filtre, ni hauteur, ni profondeur de rayon.

## Protocole P2 avant modification de simulation

1. Lancer une run solo et la campagne complete existante, seed fixe
   `17072026`, sans changement de fenetre pendant la mesure.
2. Relever les exports `P2_SIMULATION` pour les paliers `100`, `250`, `500` et
   `1 000`. Les paliers `25` sont un controle de cout fixe.
3. Comparer la somme des segments au `Monster.TickSeconds` P95 ; un ecart est
   attendu car il restera des branches non instrumentees, mais il doit etre
   explique avant toute conclusion.
4. Choisir une seule premiere modification reversible. Les candidats seront
   le scheduling par echeance/buckets ou le cache de terrain par cellule, pas
   les deux a la fois.
5. Rejouer les memes paliers et le smoke manuel : ennemi proche, ennemi sur
   relief/rampes, groupe dense, degats au contact, recycle de masse et spawn
   ordinaire.

## Budget de complexite

P2.0 ajoute une instrumentation temporairement active et quelques tags
optionnels. Elle ne modifie aucune regle de jeu. Toute phase P2.1 devra
demontre qu'elle reduit davantage de travail que la complexite qu'elle ajoute.

## Angles morts declares

- Les P95 P0 sont locaux Studio ; ils ne caracterisent ni le reseau publie ni
  une run multi-joueur.
- La campagne existante ne mesure pas le cout de spawn ordinaire pendant sa
  fenetre de mesure car elle suspend volontairement les vagues.
- La collecte de P95 ajoute un faible cout de mesure. Les comparaisons P2
  avant/apres utiliseront la meme instrumentation afin de ne pas attribuer ce
  cout a une optimisation.

## Appendice - 2026-07-18 09:50 Europe/Paris : premiere capture P2.0

### Capture exploitable

Campagne locale Studio `P0C-7883142449-54395`, complete (`7/7`) et declaree
comparable par le protocole. Le benchmark a utilise le seed fixe de population
`17072026`. L'ancien export affichait a tort le seed de session de run
`1038945637` : ce libelle a ete corrige apres cette capture ; le comportement
du benchmark n'est pas affecte car il utilisait deja le seed fixe de la
configuration.

| Scenario | Tick monstres P95 | Mouvement P95 | Separation P95 | Sol P95 | Evitement P95 |
| --- | ---: | ---: | ---: | ---: | ---: |
| 25 monstres | 1,11 ms | 1,05 ms | 0,31 ms | 0,05 ms | 0,00 ms |
| 100 monstres | 6,61 ms | 6,43 ms | 3,05 ms | 1,06 ms | 0,67 ms |
| 250 monstres | 24,78 ms | 24,35 ms | 13,22 ms | 2,96 ms | 2,21 ms |
| 500 monstres | 60,80 ms | 59,87 ms | 35,36 ms | 6,10 ms | 5,16 ms |
| 1 000 monstres | 150,44 ms | 148,52 ms | 96,58 ms | 12,56 ms | 12,47 ms |

Les couts de ciblage et de calcul du LOD restent faibles dans cette campagne :
`0,44 ms` a 500 monstres et `0,92 ms + 0,30 ms` a 1 000 monstres. La visite
globale est reelle (`VisitedStates` est egal au nombre de monstres), mais elle
n'est pas le poste dominant mesure dans cette premiere capture.

### Interpretation

✔️ Le premier suspect mesurable est la separation locale. A 1 000 monstres,
elle represente `96,58 ms` sur les `148,52 ms` du mouvement P95. Le suivi de
sol et l'evitement representent ensuite environ `25,03 ms` cumules. Le
ciblage et le LOD ne justifient pas, seuls, une reecriture ou un Octree.

~ L'hypothese de rayons LOD trop larges reste recevable : les monstres de la
campagne synthetique sont places pres du joueur, donc beaucoup peuvent etre
en LOD `Full`. Elle ne peut toutefois pas etre retenue comme cause principale
sans connaitre la repartition `Full` / `Reduced` / `Distant` et le nombre de
voisins examines par separation.

⚔️ A 1 000 monstres, le P95 de tick (`150,44 ms`) depasse l'intervalle de cache
du sol et de l'evitement (`0,12 s`). Le cache de sol n'enregistre alors aucun
hit au P95, contrairement aux `496` hits a 500 monstres. Ce phenomene peut
creer une boucle de surcharge : un tick trop long rend davantage de monstres
eligibles a un nouveau rayon au tick suivant. Ce n'est pas encore une preuve
pour modifier les intervalles ; c'est une piste a mesurer avec la repartition
LOD et les echantillons par tick.

### Correction de l'observabilite avant P2.1

La capture ci-dessus precede l'ajout des metriques suivantes :

- etats et pas par LOD `Full`, `Reduced`, `Distant` ;
- candidats parcourus et voisins reellement proches dans la separation ;
- echantillons de sol et d'evitement par tick ;
- tags de raycasts `Monster.Ground`, `Monster.Avoidance` et `Monster.Spawn` ;
- seed de benchmark et seed de run affiches separement.

Ces ajouts sont uniquement observatoires : aucun rayon LOD, intervalle,
degat, vitesse, densite ou regle de spawn n'a ete modifie. Une nouvelle
campagne identique est requise avant de choisir P2.1. Elle deviendra la
reference instrumentee avant/apres de P2, sans effacer la presente capture.

### Decision provisoire

`Adjust` le protocole, pas la simulation. La prochaine mesure devra relever
les exports `P2_SIMULATION` des paliers `25`, `100`, `250`, `500` et `1 000`
sans redimensionnement ni perte de focus. P2 reste ouvert.

## Appendice - 2026-07-18 09:53 Europe/Paris : completude spawn et recyclage

L'export P2 distingue desormais la collecte des cibles joueurs, le cout total
de mise a jour de spawn, le cout des lots de vague et le cout du recyclage
arriere. Ces metriques restent a zero dans les scenarios de horde synthetique
car `benchmarkMode` suspend volontairement les vagues. Elles servent a la
future capture canonique de run reelle, sans extrapoler un cout de spawn a
partir d'un scenario qui ne spawn rien.

Budget de complexite : quatre chronometres actifs uniquement pendant une
capture, aucune branche de gameplay ajoutee. La creation d'un scenario de
vague isole est reportee tant que les mesures P2 de horde n'ont pas etabli le
premier poste CPU a corriger.

## Appendice - 2026-07-18 10:21 Europe/Paris : baseline instrumentee P2.0 et decision P2.1

La campagne instrumentee a produit les sept exports `P2_SIMULATION` attendus.
Les scenarii de horde placent volontairement tous les monstres pres de la
cible : les paliers `25`, `100`, `250`, `500` et `1 000` sont donc a `100 %`
en LOD `Full`. Cette campagne ne permet pas de conclure sur le calibrage des
rayons LOD d'une run reelle ; aucune valeur LOD ne sera modifiee dans P2.1.

| Scenario | Mouvement P95 | Separation P95 | Candidats P95 | Voisins reels P95 | Sol P95 | Evitement P95 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 25 monstres | 1,07 ms | 0,32 ms | 600 | 239 | 0,05 ms | 0,00 ms |
| 100 monstres | 6,44 ms | 3,09 ms | 7 798 | 1 576 | 1,06 ms | 0,68 ms |
| 250 monstres | 23,54 ms | 12,75 ms | 35 293 | 5 356 | 2,88 ms | 2,19 ms |
| 500 monstres | 59,16 ms | 35,16 ms | 98 933 | 13 423 | 5,88 ms | 5,15 ms |
| 1 000 monstres | 151,84 ms | 100,87 ms | 282 080 | 37 646 | 12,85 ms | 12,55 ms |

La separation est le premier cout mesurable : a `1 000` monstres elle porte
environ les deux tiers du mouvement P95. La grille actuelle a une maille de
`8` studs, adaptee aux requetes d'armes. Avec un rayon de separation de `4,5`
studs, son balayage de neuf cellules retourne cependant beaucoup de candidats
qui sont rejetes apres calcul de distance.

Decision P2.1 : ajouter une grille persistante distincte, reservee a la
separation, avec une maille egale au rayon de separation. Le balayage reste
sur les neuf cellules adjacentes et conserve le test exact de distance. Une
paire situee a au moins deux cellules de distance sur un axe ne peut pas etre
a moins du rayon : le comportement de separation est donc conserve. La grille
de ciblage actuelle reste intacte pour ne pas degrader les requetes a longue
portee de `WeaponService`.

Budget de complexite : une appartenance de cellule supplementaire par monstre
et une table de grille supplementaire. Cette complexite n'est retenue que si
la reduction de candidats et du P95 de separation est mesuree avec la meme
campagne. Le rollback conceptuel est simple : supprimer la grille dediee et
rebrancher la separation sur la grille de ciblage existante.

Angles morts : les monstres exactement superposes conservent une direction de
separation aleatoire, comme avant. Une campagne de run reelle reste necessaire
pour mesurer la distribution des LOD, le spawn ordinaire et le recyclage, mais
elle ne remplace pas ce stress test de densite.

## Appendice - 2026-07-18 10:45 Europe/Paris : rapport P2.1 - grille de separation dediee

### Etat initial

Commit : arbre de travail local non committe, apres la baseline instrumentee
P2.0.

Scenario : campagne synthetique fixe de sept scenarii, seed `17072026`, avec
les memes paliers de horde et les memes captures P2.

Mesures initiales pertinentes : la separation P95 etait de `3,09 ms` a `100`,
`12,75 ms` a `250`, `35,16 ms` a `500` et `100,87 ms` a `1 000` monstres. Le
balayage retournait jusqu'a `282 080` candidats par tick P95 a `1 000`.

### Hypothese

La grille de ciblage de `8` studs regroupe plus de voisins que necessaire pour
un rayon de separation de `4,5` studs. Une grille dediee de taille `4,5`
studs doit reduire les candidats rejetes par le test de distance, sans modifier
les voisins effectivement separes.

### Protocole

Comparaison avant/apres realisee par deux campagnes P2 de meme duree, meme
seed de population et memes scenarii. Le responsable produit a aussi execute
un smoke de run reelle : aucun changement perceptible de mouvement, relief,
groupe dense ou combat n'a ete observe.

### Modification et risque

`MonsterService` maintient maintenant deux grilles persistantes :

- la grille historique pour `GetMonstersNear` et le ciblage des armes ;
- une grille de separation dont la maille est egale au rayon de separation.

Le balayage de separation conserve les neuf cellules adjacentes et le test
exact de distance. Les degats, vitesses, rayons de gameplay, LOD et requetes
d'armes ne changent pas.

Risque : l'ordre d'iteration des voisins peut varier pour les monstres
exactement superposes, dont la direction de separation etait deja aleatoire.
Les compteurs P95 de voisins reels ne doivent donc pas etre lus comme une
egalite bit a bit entre deux campagnes.

### Resultats

| Scenario | Separation avant | Separation apres | Ecart | Candidats avant | Candidats apres | Ecart |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 25 monstres | 0,32 ms | 0,28 ms | -12,5 % | 600 | 424 | -29,3 % |
| 100 monstres | 3,09 ms | 1,83 ms | -40,8 % | 7 798 | 3 851 | -50,6 % |
| 250 monstres | 12,75 ms | 6,14 ms | -51,8 % | 35 293 | 14 301 | -59,5 % |
| 500 monstres | 35,16 ms | 15,75 ms | -55,2 % | 98 933 | 37 164 | -62,4 % |
| 1 000 monstres | 100,87 ms | 44,68 ms | -55,7 % | 282 080 | 107 845 | -61,8 % |

Le mouvement P95 total passe de `151,84 ms` a `92,84 ms` a `1 000` monstres,
soit `-38,9 %`. Les voisins reels restent du meme ordre de grandeur a tous les
paliers. A `1 000`, leur P95 passe de `37 646` a `40 726`, variation compatible
avec un echantillon P95 pris sur des ticks differents et la dynamique aleatoire
des groupes, pas avec une modification du predicate de distance qui reste
identique.

### Decision

Keep. Le gain est mesure, le cout ajoute reste borne a une appartenance de
cellule supplementaire par monstre et le smoke manuel canonique n'a pas releve
de regression.

### Conclusion

Gain demontre : la separation cesse d'etre le cout ecrasant du mouvement de
horde. P2 reste ouvert : le suivi de sol et l'evitement totalisent encore
`26,75 ms` P95 a `1 000` monstres, et la campagne synthetique ne mesure pas
une distribution LOD representative d'une run reelle.

Etape suivante : auditer une unique passe P2.2 sur le relief, en commencant par
la reutilisation locale de surface et la frequence des echantillons. Aucun
changement de LOD, de gameplay ou de scheduling ne sera introduit sans une
nouvelle hypothese mesuree.

## Appendice - 2026-07-18 11:18 Europe/Paris : rapport P2.2 - cache partage de surface plane

### Etat initial

Commit : arbre de travail local non committe, apres P2.1 conservee.

Scenario : campagne synthetique fixe de sept scenarii, seed `17072026`, avec
un smoke de run reelle execute par le responsable produit. Aucun changement
visuel ou de comportement de combat n'a ete observe pendant ce smoke.

Mesures initiales pertinentes : apres P2.1, le suivi du sol mesurait `2,79 ms`
a `250`, `5,87 ms` a `500` et `15,41 ms` a `1 000` monstres. Les raycasts de
sol etaient encore le cout principal du suivi de relief sur surfaces planes.

### Hypothese

Sur une plateforme plate, ancree et collisionnable, plusieurs monstres d'une
meme cellule de separation consultent la meme hauteur de sol. Reutiliser cette
hauteur apres validation du footprint de la piece doit supprimer les raycasts
redondants sans changer le comportement sur rampe, pente ou geometrie ambigue.

### Protocole

La meme campagne P2 est executee apres warm-up. Les compteurs de raycasts ne
couvrent donc que la fenetre de mesure, pas le premier raycast de remplissage
du cache execute pendant le warm-up. Les comparaisons de cout portent sur les
P95 de suivi du sol et de mouvement aux memes paliers.

### Modification et risque

`MonsterService` maintient un cache par cellule de separation. Une entree est
acceptee uniquement si la surface est une `BasePart` ancree, collisionnable,
horizontale et si le point candidat est dans son footprint. La hauteur est
rejetee si elle ne reste pas coherente avec la hauteur du monstre. Les rampes,
pentes, surfaces dynamiques et resultats sans `BasePart` continuent d'utiliser
le raycast existant.

Risque : une plateforme superposee ou une piece de map remplacee pendant une
run pourrait rendre une entree obsolete. Le cache invalide les instances
detruites, est vide au nettoyage des monstres et la tolerance verticale force
un retour au raycast lorsqu'une hauteur ne correspond plus.

Budget de complexite : une table par cellule de separation et deux validations
geometriques simples par reutilisation. Aucun etat de gameplay, degat, vitesse,
rayon LOD ou comportement des armes n'est ajoute.

### Resultats

| Scenario | Sol P95 avant | Sol P95 apres | Ecart | Cache partage P95 | Raycasts de sol pendant la mesure |
| --- | ---: | ---: | ---: | ---: | ---: |
| 25 monstres | 0,11 ms | 0,06 ms | non significatif | 0 | 0 |
| 100 monstres | 0,10 ms | 0,24 ms | non significatif | 0 | 0 |
| 250 monstres | 2,79 ms | 0,65 ms | -76,7 % | 248 | 0 |
| 500 monstres | 5,87 ms | 1,36 ms | -76,8 % | 497 | 0 |
| 1 000 monstres | 15,41 ms | 2,73 ms | -82,3 % | 907 | 0 |

Le mouvement P95 a `1 000` monstres passe de `92,84 ms` a `84,10 ms`, soit
`-9,4 %`. Le cout combine suivi du sol et evitement passe de `26,75 ms` a
`14,07 ms` P95 a ce palier. L'evitement reste a `11,34 ms` : P2.2 ne pretend
pas l'optimiser.

Les paliers `25` et `100` sont sous la milliseconde pour le suivi du sol ; leur
variation ne permet pas une conclusion utile. Le gain demonstrable est celui
des hordes de `250` monstres et plus.

### Decision

Keep. Le gain est fort aux densites ou le suivi du sol devenait mesurable, le
smoke de run ne rapporte aucune regression, et les surfaces non planes restent
sur le chemin exact precedent.

### Angles morts et P2.3

Le benchmark synthetique suspend encore les vagues ordinaires : ses compteurs
`spawn_ms_p95` et `vague_spawn_ms_p95` restent donc nuls. Le responsable
produit a observe un pic lors de spawns massifs dans une run longue. Cette
observation est prioritaire sur les compteurs nuls : P2.3 devra d'abord mesurer
les lots reels, leur taille, leur duree et leur effet sur les pics de tick,
avant de sequencer la creation des monstres.

Les monstres traversent actuellement coffres, shrines et totems parce que leur
collision physique est explicitement desactivee. C'est coherent avec P1 et
avec un mouvement cinematique par `PivotTo`, mais cela peut etre un defaut
visuel. Si le produit exige que les monstres contournent ces elements, la piste
correcte est un evitement statique local et budgete, jamais la reactivation de
collisions physiques pour toute la horde. Cette piste ne fait pas partie de
P2.2.

### Conclusion

Gain demontre : le relief plat ne consomme plus de raycasts durant la fenetre
de mesure apres warm-up et son cout P95 baisse fortement a partir de `250`
monstres.

Limites : les rampes demandent encore un smoke explicite avant cloture de P2,
et l'evitement de terrain reste le prochain cout de relief mesurable.

Etape suivante : P2.3, rendre les spawns ordinaires observables dans une run
reelle, puis choisir entre conservation, limitation de batch ou sequencage.

## Appendice - 2026-07-18 13:03 Europe/Paris : rapport P2.3 - file de spawn debug

### Etat initial

Commit : arbre de travail local non committe, apres P2.2 conservee.

Scenario : smoke de run reelle avec plusieurs utilisations du bouton admin
`Spawn 100 ennemis`, suivi d'un nettoyage admin. Les vagues ordinaires restent
actives pour conserver la concurrence reelle entre les deux sources de spawn.

Mesure initiale : le bouton admin appelait la creation synchrone de tous les
monstres demandes. La smoke precedente a releve un lot de `100` monstres a
`133,25 ms`, puis deux lots debug de `100` a `81,51 ms` et `92,69 ms` max.
Les pics client de `706 ms`, `657 ms`, `136 ms` et `640 ms` surviennent dans
la meme fenetre temporelle. Cette correlation ne prouve pas que le serveur est
la seule cause, mais elle rend le chemin debug suffisamment suspect pour une
correction isolee.

### Hypothese

Le cout de creation et de replication de `100` modeles dans un seul tick
produit une surcharge transitoire inutile au debug. Decouper seulement cette
commande en petits lots doit lisser ce cout sans changer la population finale,
les vagues ordinaires, les regles de combat ou le protocole P0.

### Protocole

Le meme bouton admin demande `100` monstres. La nouvelle sortie de logs
`Perf lots de spawn serveur` distingue les lots ordinaires et debug : nombre de
lots, demandes, creations, moyenne, maximum et nombre restant dans la file.
Le smoke verifie aussi qu'un second clic est refuse pendant la file et que
`Tuer tous les ennemis` ne laisse aucun spawn tardif.

### Modification et risque

La commande admin place maintenant sa demande dans une file propre au joueur.
Chaque pas de simulation cree au plus `5` monstres et la file attend au moins
`0,05 s` avant le lot suivant. Les vagues ordinaires restent sur leur chemin
precedent et le benchmark continue d'utiliser son spawn synchrone afin de
preserver ses fixtures reproductibles.

Une seconde demande admin est refusee tant que la premiere reste active. La
file est annulee au nettoyage global, a la fin de run et au depart du joueur.

Risque : le bouton debug ne remplit plus instantanement la horde. C'est voulu,
mais ce decalage pourrait rendre un scenario de test moins commode. La
confirmation utilisateur et les logs indiquent explicitement que la demande
reste en cours puis terminee.

Budget de complexite : une table de demandes en attente et un passage borne
par demande a chaque pas de simulation. Aucune couche n'est ajoutee aux vagues
de jeu, aux degats, au LOD ou au ciblage.

### Resultats

| Mesure | Avant | Apres | Ecart |
| --- | ---: | ---: | ---: |
| Demande debug | 100 dans un lot | 100 en 20 lots de 5 | creation sequencee |
| Duree max d'un lot debug | 133,25 ms | 14,62 ms | -89,0 % |
| Duree moyenne d'un lot debug | 133,25 ms | 11,42 ms | -91,4 % |
| Second passage, maximum | 81,51 a 92,69 ms | 6,60 ms | au moins -91,9 % |
| Duree de la file de 100 | blocage ponctuel | environ 1,20 s | cout etale |

La smoke de validation montre trois demandes de `100` monstres toutes
terminees. Le troisieme essai comporte aussi un second clic pendant la file,
correctement refuse avec `40 ennemis restants`. Aucun pic client n'est logge
pendant les trois sequences de creation. Un pic client de `181 ms` apparait
apres un nettoyage de `102` monstres ; il ne doit pas etre attribue a cette
file de spawn et reste une observation distincte a mesurer si elle se repete.

Les vagues ordinaires de la smoke sont mesurees entre `2,20 ms` et `4,87 ms`
pour leurs petits lots observes. Elles ne sont donc pas modifiees sur la base
d'une suspicion non demontree.

### Decision

Keep. Le gain est mesure, le smoke manuel confirme que la population deja
installee reste fluide, et le changement est strictement limite au chemin
debug qui provoquait les gros pics. Aucun changement de gameplay n'est
introduit.

### Angles morts

La file debug ne prouve pas que les futures vagues de jeu tres denses seront
gratuites : si leur lot naturel depasse les tailles observees ici, elles devront
etre mesurees avec ce meme compteur avant toute adaptation. Le cout du nettoyage
massif reste egalement hors du perimetre de cette sous-passe.

### Conclusion

Gain demontre : la creation admin de 100 monstres passe d'un bloc de plus de
`133 ms` a des lots inferieurs a `15 ms` dans la smoke de validation.

Limites : P2 reste ouvert. L'evitement de terrain, les rampes, les pics de
nettoyage et la distribution LOD d'une vraie run doivent encore etre
documentes avant une cloture generale.

Etape suivante : poursuivre uniquement sur un cout P2 encore mesure dans un
cas reel ou synthetique reproductible. Ne pas sequencer les vagues ordinaires
sans comparaison avant/apres qui justifie ce cout supplementaire de scheduling.

## Appendice - 2026-07-18 14:21 Europe/Paris : rapport P2.4 - lissage des vagues et recyclage

### Etat initial

Commit : `171ae5a`, arbre de travail local non committe, apres P2.3.

Scenario : smoke de run reelle avec le canal `Performance` seul active. Le
joueur a laisse la population monter tout en collectant XP et pieces. Les logs
`Perf lots de spawn serveur` servent de mesure directe du chemin ordinaire,
que la campagne P0 ne couvre pas car elle suspend les vagues naturelles.

Mesure initiale : les vagues ordinaires observables dans les smokes precedent
P2.4 etaient petites, mais le responsable produit a rapporte des chutes
visuelles lors de poussees de population. La creation d'une vague complete
restait executee dans un seul pas de simulation, avec un maximum theorique de
`8` avant multiplicateur de perk.

### Hypothese

Le cout de creation, de preparation et de replication d'une vague augmente
avec le nombre d'instances creees simultanement. Conserver la taille logique
d'une vague mais limiter strictement le nombre de creations par `Heartbeat`
doit etaler ce cout sans reduire la population finale ni modifier les regles
de combat.

### Protocole

La demande logique de vague est conservee dans une file par joueur. La smoke
observe explicitement :

- `WaveLargestRequested` et `WaveLargestSpawned` ;
- `WavePending` ;
- la duree des lots et le pic du tick serveur associe ;
- la poursuite normale du combat, de la collecte et du nettoyage de fin de run.

Le test ne pretend pas mesurer un P95 de campagne pour ce sous-changement :
le protocole P0 suspend justement le spawn ordinaire. Cette smoke est donc la
preuve adaptee au cout vise, mais elle ne qualifie pas les pics client isoles.

### Modification et risque

`MonsterService` distingue desormais la taille logique demandee de la taille
physiquement creee dans une frame. `WaveSpawnDispatchBudget=4` borne toute
creation de vague a quatre monstres par `Heartbeat`, y compris lorsque la
simulation rattrape plusieurs pas fixes. La capacite est reservee globalement
par les requetes en attente afin que deux joueurs ne puissent pas sur-reserver
le plafond commun.

Le recyclage d'une masse intacte passe de quatre a deux monstres par passe.
Les files sont videes au nettoyage global, au depart du joueur et a la fin de
run.

Risque : une vague tres grande arrive legerement plus progressivement. Ce
decalage est intentionnel ; la taille demandee et le plafond total ne changent
pas. La file ne peut pas depasser la capacite disponible.

Budget de complexite : une file de vague courte et une allocation numerique
remise a zero a chaque `Heartbeat`. La complexite augmente localement, mais
elle remplace le bloc de creation unique plutot que de rajouter une couche sur
le mouvement, les degats ou le LOD.

### Resultats

Dans la smoke `14:15` a `14:18` :

| Observation | Resultat |
| --- | --- |
| Plus grande vague logique observee | `12` demandes |
| Plus grand lot cree | `4` monstres |
| Decomposition observee | `12 = 3 x 4` lots |
| File apres les lots observes | `WavePending=0` |
| Pic serveur associe a 46 monstres et 12 demandes | `9,82 ms` |
| Pic serveur associe a 50 monstres et 7 demandes | `7,54 ms` |

Les lots plus petits restent eux aussi bornes : les demandes de `4`, `5`, `6`
et `9` sont decoupees en lots de `1` a `4`. Aucun lot ordinaire ne depasse la
limite configuree dans les logs. La fin de run laisse `Alive=0` et `Pool=51`,
sans spawn tardif en attente.

Deux pics client sont presents dans la trace : `275 ms` avant le lancement de
la run et `139 ms` vers la fin de la smoke. Le second arrive pres d'une vague,
mais le log ne permet pas d'etablir une causalite serveur, VFX, Studio ou
focus. Il ne doit pas etre attribue artificiellement au spawn ni considere
resolu par P2.4.

### Decision

Keep. Le lissage demande est observe directement sur le chemin reel vise et
ne modifie pas la taille logique des vagues. La smoke ne rapporte aucune
regression de combat ou de collecte.

### Conclusion

Gain demontre : la creation normale est bornee a quatre monstres par frame,
et une vague de douze est etalee sans residu de file dans la smoke.

Limites : la smoke ne mesure pas la cause des deux pics client isoles. Le cache
de sol atteint `2 878` cellules pendant cette run puis revient a zero a la fin
de run ; son cout memoire exact doit etre mesure dans une phase memoire, pas
suppose ici.

Etape suivante : cloturer P2 dans son perimetre serveur, puis traiter les
angles morts documentes separement. Ne pas utiliser P2.4 comme preuve d'une
optimisation GPU ou client.
