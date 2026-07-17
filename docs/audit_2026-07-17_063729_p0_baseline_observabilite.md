# P0 - Baseline et observabilite des performances

Date de preparation : 2026-07-17 06:37 Europe/Paris

## Objet du chantier

P0 ne cherche pas a rendre le jeu plus rapide. Il construit le referentiel qui
permettra de prouver ou de refuter les gains des onze phases suivantes. Une
optimisation sans protocole stable est insuffisante : elle peut deplacer le cout
vers le client, le reseau ou la memoire tout en donnant une impression locale de
gain.

Le chantier commence donc par deux rails complementaires :

1. un laboratoire de benchmark fixe dans `Workspace`, isole du gameplay ;
2. un protocole de mesures repete sur les vraies runs generees.

Le laboratoire rend les tests comparables. La run representative garantit que
le laboratoire ne masque pas les couts de la generation procedurale, du relief,
des VFX, des interactables et des reseaux de runtime.

## Etat releve avant P0

Les capteurs locaux suivants existent deja :

- `MonsterService` publie le nombre de monstres actifs, les repartitions LOD,
  la taille de son pool, la grille spatiale et les durees moyenne/maximale du
  tick serveur ;
- `WeaponService` publie le nombre de projectiles actifs, la taille du pool et
  le cout moyen du tick ;
- `XpService` et `CoinService` publient les tailles de pools, le nombre
  d'instances suivies et les couts maximaux de scans et de fusions ;
- `CoinClient` detecte deja les pics de frame et publie un etat visuel de
  collectibles ;
- `DebugUI` expose deja FPS, memoire totale, temps CPU/GPU de rendu, temps de
  physique, instances, draw calls et triangles ;
- les profils de qualite et le budget VFX existent deja cote client.

Ces releves sont utiles, mais ils sont disperses, ont des frequences differentes
et ne sont pas encore lies a un scenario, une seed, un appareil, une repetition
ni une phase de run. Ils ne constituent donc pas une baseline globale.

## Position retenue

Juste : une scene de benchmark fixe est necessaire pour rendre la densite,
l'espace, les distances et les positions de camera comparables.

Contestable : une scene plane ne peut pas etre l'unique reference. Elle est
excellente pour isoler les couts de combat, de projectiles et de collectibles,
mais elle sous-estime les couts reels du relief procedurale, des surfaces, des
raycasts et de la visibilite. P0 gardera donc aussi un scenario de run reelle
avec seed fixe.

Simplification : P0 ne lance pas de gros moteur de telemetrie externe. La
premiere version doit exporter des echantillons structures, lisibles et
comparables ; un tableau de bord complexe ne rendrait pas les conclusions plus
fiables.

Angle mort : les mesures Studio ne sont pas une preuve de performance en
production. Elles seront distinguees des mesures sur client reel et serveur
prive publie. Une comparaison n'est recevable que si son environnement est
identifie.

## Scene P0 proposee

Le chemin reserve sera `Workspace/PerformanceBaseline`.

La scene sera placee tres loin du monde de jeu afin de ne pas modifier la map
visible, les raycasts de la run ou les spawns normaux. Elle ne contient pas de
template de gameplay et ne doit jamais etre parcourue comme un runtime de run.

Contenu fixe :

- `Arena` : surface plane ancree de 512 x 512 studs, proche de la taille des
  maps actuelles ;
- `Boundary` : limites de test simples, seulement pour les futurs scenarios
  controles ;
- `ReferencePoints` : repere de spawn joueur, repere camera et centre de
  simulation ;
- `ScenarioMarkers` : marqueurs fixes `Density25`, `Density100`, `Density250`,
  `Density500`, `DensityMax`, `Projectiles` et `Collectibles` ;
- attributs explicites `MegaRobloxBenchmark` et
  `MegaRobloxIgnoreAsSpawnSurface` afin de documenter son statut.

La scene n'est pas un nouveau niveau, ne sera pas teleporte automatiquement et
ne doit pas etre utilisee par les services de generation normaux. Son activation
future devra etre un chemin Admin explicite, reserve au debug.

## QQOCCP operationnel

### Qui

- L'agent implemente les capteurs, les exports, le protocole et les protections
  contre les mesures non comparables.
- Le responsable produit choisit et valide les appareils representatifs ainsi
  que les captures de smoke manuel.

### Quoi

Construire un releve horodate par scenario, capable de separer les couts
serveur, client, reseau et memoire, avant toute optimisation de P1 a P12.

### Ou

- Studio serveur et client ;
- appareils reels disponibles ;
- serveur prive publie lorsque disponible ;
- `Workspace/PerformanceBaseline` pour les scenarios controles ;
- vraies maps runtime pour les scenarios representatifs.

### Quand

- avant P1 ;
- apres toute phase qui modifie une boucle chaude, la replication, les VFX, les
  pools, la map ou le rendu ;
- avant toute conclusion sur une amelioration de performance.

### Comment

Chaque campagne doit enregistrer :

- version Git ou commit, date, place, appareil, resolution, profil graphique,
  mode Studio ou publie et nombre de joueurs ;
- `RunId`, seed, chapitre, scenario, duree de chauffe, duree mesuree et nombre
  de repetitions ;
- echantillons cadences a intervalle fixe, pas seulement un FPS instantane ;
- minimum, moyenne, P50, P95 et P99 lorsque la source le permet ;
- memoire avant run, au pic, apres nettoyage et apres plusieurs runs ;
- evenement de pause, freeze, erreur ou retrait manuel de mesure.

### Combien

La matrice initiale de densite est :

| Famille | Paliers initiaux |
| --- | --- |
| Monstres | 25, 100, 250, 500, limite debug | 
| Projectiles | 1, 8, 24, 56, limite appropriee au build |
| Collectibles | faible, normal, pic de drop, pic de fusion |
| Repetitions | minimum 3 par scenario et environnement |
| Stabilite memoire | minimum 3 runs consecutives identiques |

Une campagne garde les memes seed, positions de reference, qualite graphique,
duree de chauffe et duree d'observation. Un changement de ces conditions cree
une nouvelle serie, pas une continuation de serie existante.

### Pourquoi

Eviter les conclusions fondees sur une impression, un FPS momentane ou une
capture isolee. P0 doit permettre de dire si un gain touche le CPU serveur, le
CPU client, le GPU, la memoire ou le reseau, et s'il reste present apres
plusieurs runs.

## Matrice de mesures P0

### Serveur

- frame time et frequence effective de `Heartbeat` ;
- cout de `MonsterService`, `WeaponService`, scans/fusions XP et coins ;
- compteurs de raycasts par famille et cout cumule ;
- instances runtime, monstres, projectiles, XP et coins actifs ;
- taille de chaque pool ;
- bande passante sortante, remotes emis et volume de replication lorsque
  accessible dans l'environnement mesure.

### Client

- frame time P50, P95 et P99, plus les pics au-dela du seuil ;
- draw calls, triangles, temps CPU/GPU de rendu, physique et ombres lorsque la
  plateforme expose ces compteurs ;
- VFX, particules, trails et lights actifs propres a MegaRoblox ;
- memoire graphique et memoire d'instances lorsque disponibles ;
- profil graphique, budget VFX applique et eventuelle reduction adaptative.

### Memoire

- total, `PhysicsParts`, `GraphicsTexture`, `Sounds`, `Instances` et
  `LuaHeap` lorsque l'API expose la categorie ;
- point avant lancement, pic, apres nettoyage et apres runs consecutives ;
- nombre de descendants runtime et contenu de pools afin de distinguer une
  retention voulue du pool d'une fuite non maitrisee.

### Reseau

- debit envoye et recu ;
- nombre de remotes emises par famille ;
- volume des proprietes repliquees et comportement sous projectiles actifs ;
- test a plusieurs clients quand le serveur prive sera disponible.

## Smoke manuel canonique P0

Ce smoke bloque l'ouverture de P1 :

1. Ouvrir une session Studio avec le meme profil graphique et noter appareil,
   resolution et commit.
2. Activer le scenario fixe, attendre la chauffe, puis enregistrer la fenetre
   de mesure sans interaction supplementaire.
3. Rejouer trois fois les memes paliers monstres, projectiles et collectibles.
4. Terminer la run, verifier le nettoyage runtime et relever la memoire.
5. Refaire au minimum trois runs identiques pour observer la memoire residuelle.
6. Rejouer un scenario de vraie map avec une seed fixe et comparer la tendance,
   sans melanger les deux series.

Un FPS unique, une seule repetition ou une run sans metadonnees ne valident pas
P0.

## Phasage P0

1. P0.1 : scene de benchmark fixe et protocole documente.
2. P0.2 : collecteur serveur structure et compteurs de raycasts/remotes.
3. P0.3 : collecteur client structure, percentiles de frame et categories
   memoire accessibles.
4. P0.4 : lanceur Admin explicite, non disponible dans le gameplay normal.
5. P0.5 : campagne initiale, comparaison Studio/appareil reel, puis baseline
   append-only avec ecarts observes.

## Criteres de sortie de P0

P0 sera clos seulement lorsque :

- les scenarios fixes et representatifs sont rejouables ;
- la variance naturelle est connue par repetitions ;
- une baseline horodatee est enregistree ;
- CPU, GPU, reseau et memoire sont distinguables dans les releves ;
- chaque phase P1 a P12 peut reutiliser le meme protocole ;
- le smoke manuel canonique est valide par le responsable produit.

## Budget de complexite

P0 ajoute de la complexite, mais elle est volontairement isolee : une scene
hors gameplay, des echantillons structures et un lanceur debug futur. Il ne
modifie pas les decisions de combat, de score, de drops ou de progression.

## Rollback conceptuel

La scene `PerformanceBaseline` peut etre retiree independamment sans affecter
la map ou les runs. Les collecteurs futurs devront etre activables par flag ;
un collecteur qui modifie le gameplay ou introduit des remotes de production
sera considere comme une mauvaise direction.

## Angles morts a traiter avant cloture

- Studio peut sur- ou sous-estimer certaines charges par rapport a un serveur
  publie ; les series ne doivent jamais etre comparees sans etiquette
  d'environnement.
- Les outils Roblox n'exposent pas toutes les categories de memoire et de
  reseau de facon identique selon la plateforme. Les valeurs indisponibles
  devront etre marquees `non exposee`, jamais remplacees par zero.
- La scene plane mesurera mal les couts de relief. Le scenario de run avec seed
  fixe est donc obligatoire.
- Les logs actuels a cinq secondes sont trop grossiers pour caracteriser une
  pointe courte. Les percentiles et evenements de spike devront etre agreges
  dans P0.2/P0.3, sans spammer la console.

## Appendice chronologique - P0.1 realise a 2026-07-17 06:37 Europe/Paris

La scene `Workspace/PerformanceBaseline` a ete creee et verifiee dans Studio
en mode Edition. Elle contient :

- une arene de 512 x 512 studs a l'altitude `Y = 3000` ;
- quatre limites invisibles et sans requete de raycast ;
- cinq reperes fixes de joueur, camera, simulation, projectile et
  collectibles ;
- sept marqueurs de scenarios, dont les paliers monstres 25, 100, 250, 500 et
  1000.

Le dossier porte les attributs `MegaRobloxBenchmark` et
`MegaRobloxIgnoreAsSpawnSurface`. Il est volontairement hors des dossiers
runtime et assez loin de la map pour ne pas participer aux spawns normaux.

La scene est aussi declaree dans `default.project.json`. Cette exception au
principe de ne pas modifier la configuration Rojo est necessaire : une scene
uniquement construite a la main dans Studio ne serait pas reproductible depuis
le depot et pourrait disparaitre ou diverger lors d'une synchronisation.

Verification technique P0.1 :

- JSON de `default.project.json` valide ;
- `rojo build -o %TEMP%/TestRoblox_p0_baseline.rbxlx` valide ;
- `git diff --check` valide ;
- aucun marqueur de conflit Git trouve.

P0 reste ouvert. Aucun chiffre de baseline n'a encore ete collecte et aucun
lanceur de scenario n'est encore branche.

## Appendice chronologique - P0.2 a P0.4 realise le 2026-07-17 07:39 Europe/Paris

Le rail de mesure executable est maintenant branche. Cette passe ne modifie
pas les regles de combat, les drops, le score ni la progression : elle isole
temporairement une run solo dans l'arene P0, applique une seed fixe, execute
un scenario, puis restaure le contexte de run et la position initiale du
joueur.

### Scenarios reproductibles disponibles

Le menu Admin propose un scenario a la fois, avec 15 secondes de chauffe,
90 secondes de mesure et 2 secondes de nettoyage :

- `monsters_25`, `monsters_100`, `monsters_250`, `monsters_500` et
  `monsters_1000` ;
- `projectiles_24`, avec 24 monstres et une rafale de 24 Fireballs ;
- `collectibles_300`, avec 150 gemmes XP et 150 pieces.

Chaque scenario exige une run active et exactement un joueur. Pendant la
campagne, les vagues ordinaires sont suspendues, les monstres ne peuvent pas
blesser le joueur et les degats de test ne les tuent pas. Cette isolation
evite que le benchmark compare des charges de gameplay differentes entre deux
repetitions.

### Instrumentation ajoutee

Le serveur agrege, sans spammer la console pendant la mesure :

- Heartbeat serveur, ticks `MonsterService` et `WeaponService` ;
- raycasts de `WorldSpawnService` et du fallback monstre ;
- scans et fusions XP / pieces ;
- instances runtime, monstres, projectiles, collectibles et pools ;
- memoire totale et categories exposees (`Instances`, `LuaHeap`,
  `GraphicsTexture`, `Sounds`, `PhysicsCollision`) ;
- topologie statique des RemoteEvents et RemoteFunctions.

Le client capture les temps de frame reels P50, P95 et P99, les pics au-dela
de 33 ms, les compteurs de rendu exposes, les instances, la memoire, les VFX
MegaRoblox actifs et les reglages graphiques/VFX en cours. Les donnees client
sont acceptees uniquement depuis le joueur proprietaire du benchmark, a une
frequence bornee.

A la fin, trois logs `Perf` compacts sont emis : serveur, client et memoire.
Ils constituent le releve copiable pour la campagne. Un rapport structure est
egalement conserve temporairement par `PerformanceBenchmarkService` pour la
session en cours.

### Reseau : limite explicite

Le script ne pretend pas connaitre le debit reel en octets. Roblox n'expose
pas une mesure de bande passante suffisamment fiable et portable par le meme
chemin de script. La capture reseau reste donc obligatoire dans le
MicroProfiler ou la console Developpeur, avec la meme fenetre de 90 secondes.
Une valeur reseau absente doit etre ecrite `non capturee`, jamais `0`.

### Smoke manuel canonique P0.5

1. Lancer une run solo, sans modifier le profil graphique ni les reglages VFX.
2. Ouvrir le panneau Admin, conserver la categorie `Perf` active, choisir un
   scenario P0 puis cliquer `P0 : lancer`.
3. Ne pas deplacer le personnage et ne pas ouvrir de menu pendant les 15
   secondes de chauffe et les 90 secondes de mesure.
4. Capturer les trois rapports `Perf` de fin, le MicroProfiler reseau et les
   mesures memoire avant, au pic et apres nettoyage.
5. Rejouer chaque scenario au moins trois fois sur le meme appareil, la meme
   resolution et le meme commit.
6. Terminer puis relancer au moins trois runs afin de relever la memoire
   residuelle entre les campagnes.

Les series doivent etre etiquetees `Studio` ou `Published`, avec appareil,
resolution, qualite graphique, date et commit. Les valeurs ne seront comparees
qu'a environnement egal.

### Verification technique de cette passe

- `rojo build default.project.json -o %TEMP%/MegaRoblox_P0_baseline.rbxlx`
  valide ;
- `git diff --check` valide ;
- aucun marqueur de conflit Git trouve ;
- aucune session Play n'a ete lancee par Codex, conformement a la consigne de
  test manuel pilote par le responsable produit.

### P0 reste ouvert

P0.5 n'est pas encore realise : aucune baseline mesuree, aucune variance et
aucun comportement memoire post-runs n'ont ete observes. La fermeture de P0
est bloquee jusqu'a reception et analyse des campagnes manuelles. La prochaine
etape est donc une campagne reelle, pas P1.

### Angles morts conserves volontairement

- Le benchmark d'arene plane ne remplace pas le scenario de relief a seed fixe
  qui devra etre ajoute a la campagne de validation.
- Les VFX des autres joueurs et le multijoueur ne sont pas evalues par le
  protocole solo P0 ; ils seront une serie distincte, pas une extrapolation.
- L'instrumentation elle-meme a un cout faible mais non nul. Les releves
  doivent etre lus comme une baseline instrumentee, et non comme une mesure
  totalement sans observateur.

## Appendice chronologique - Charte P0 a P12 ajoutee le 2026-07-17 07:48 Europe/Paris

La charte de pilotage transversale et le journal versionne append-only sont
desormais definis dans
`audit_2026-07-17_074825_charte_pilotage_performance.md`. Elle impose le
format de rapport avant / apres de chaque phase, la decision explicite
`Keep`, `Adjust`, `Revert` ou `Defer`, et bloque toute fermeture de P0 sans
baseline manuelle reelle.

## Appendice chronologique - Correctif du rapport P0 le 2026-07-17 08:00 Europe/Paris

Le premier essai manuel du scenario `monsters_25` a revele une erreur de fin
de rapport : le rapport lisait les compteurs de raycasts comme une structure
imbriquee alors que `PerformanceTelemetryService` les stocke sous des cles
plates, par exemple `WorldSpawn.RaycastCount`. Un scenario peut legitimement
ne produire aucun raycast de cette famille ; il doit alors remonter `0`, pas
interrompre le nettoyage.

Le rapport utilise maintenant un acces borne aux compteurs absents. Le panneau
Admin affiche egalement un etat vivant pendant la chauffe, la mesure et le
nettoyage, avec le temps ecoule et la duree attendue de chaque phase.

Un benchmark arrete manuellement est utile pour valider le rail, mais il est
non comparable a une baseline complete. Seule une campagne terminee apres les
15 secondes de chauffe et les 90 secondes de mesure peut alimenter J-000.

Verification technique apres correctif :

- `rojo build default.project.json -o %TEMP%/MegaRoblox_P0_baseline.rbxlx`
  valide ;
- `git diff --check` valide ;
- aucun marqueur de conflit Git trouve.

## Appendice chronologique - Campagne P0 complete ajoutee le 2026-07-17 08:27 Europe/Paris

### Decision de protocole

La selection Admin P0 propose maintenant les scenarios unitaires existants et
`P0 - campagne complete`. Cette campagne enchaine, dans un ordre fixe et avec
le meme seed, les sept scenarios suivants :

1. `monsters_25` ;
2. `monsters_100` ;
3. `monsters_250` ;
4. `monsters_500` ;
5. `monsters_1000` ;
6. `projectiles_24` ;
7. `collectibles_300`.

Chaque etape conserve sa propre chauffe de 15 secondes, sa mesure de 90
secondes et son nettoyage. Le panneau Admin affiche l'avancement de campagne
(`n/7`), le scenario courant et la phase en cours. A la fin, les sept rapports
enfants sont conserves avec une synthese de campagne contenant la duree et la
memoire serveur avant / apres campagne.

### Ce que la campagne mesure et ne mesure pas

La campagne est un releve de stabilite et de memoire residuelle enchaine : les
pools et le processus Studio restent chauds entre deux scenarios, tandis que
les monstres, projectiles et collectibles runtime sont nettoyes. Les vagues
ordinaires restent suspendues pendant toute la campagne afin de ne pas injecter
de charge gameplay parasite entre deux paliers.

Elle ne remplace pas les scenarios unitaires. Un ecart sur la campagne ne
permet pas, a lui seul, de conclure si le cout vient des monstres, des
projectiles, de la collecte ou de la transition. Les mesures unitaires restent
donc la reference pour comparer un changement de phase P1 a P12. La campagne
complete apporte la preuve complementaire : le projet reste-t-il stable apres
une suite representative de charges ?

### Smoke manuel canonique P0.6

1. Lancer une run solo et garder les reglages graphiques inchanges.
2. Dans Admin, faire defiler la selection jusqu'a `P0 - campagne complete`.
3. Cliquer `P0 : lancer`, sans deplacer le joueur ni ouvrir de menu pendant
   les 7 scenarios.
4. Verifier que le statut passe successivement par `chauffe`, `mesure`,
   `nettoyage`, puis `scenario suivant`, avec un compteur de 1/7 a 7/7.
5. Relever les trois logs `Perf` de chaque scenario et le log final
   `Rapport campagne P0`.
6. Rejouer la campagne complete au moins trois fois dans le meme environnement
   avant de comparer une phase ulterieure.
7. Capturer le MicroProfiler et les mesures reseau sur au moins une campagne
   complete ; elles ne sont pas inventees par le script.

Un arret Admin interromp la campagne, nettoie le contexte P0 et produit un
rapport partiel explicite. Un rapport partiel ne peut pas fermer P0.

### Verification technique de cette passe

- `rojo build default.project.json -o %TEMP%/MegaRoblox_P0_campaign.rbxlx`
  valide ;
- `git diff --check` valide ;
- aucun marqueur de conflit Git actif trouve ;
- aucune session Play n'a ete lancee par Codex.

### Etat P0 apres cette passe

P0 reste ouvert. La campagne est implementee mais aucune baseline complete,
aucune variance mesuree et aucune comparaison avant / apres ne sont encore
disponibles. La prochaine action est le smoke P0.6 manuel, pas une conclusion
sur les performances ni le demarrage de P1.

## Appendice chronologique - Calibration P0 non-baseline le 2026-07-17 09:01 Europe/Paris

### Statut de cette campagne

Une premiere campagne `p0_complete` a ete terminee dans Roblox Studio :

- source de travail : commit `88c73ca` plus le worktree P0 non committe ;
- seed : `17072026` ;
- scenarios termines : `7/7` ;
- duree observee : `759,15 s` ;
- duree theorique du protocole : `755 s` (`7 * (15 s + 90 s + 2 s) + 6 s`) ;
- environnement : serveur et client integres a Studio, un seul joueur.

La difference de l'ordre de quatre secondes est compatible avec les transitions
entre scenarios. Elle valide le sequencement de campagne : aucun scenario ne
s'est arrete avant son nettoyage.

Cette campagne ne constitue volontairement pas la baseline J-000. La fenetre
Studio a ete redimensionnee et Studio a ete quitte pendant la mesure. Ces
actions perturbent au minimum le rendu, le scheduling client et les percentiles
de frame. Elles ne doivent pas etre masquees par une moyenne globale.

### Releve de calibration

Les valeurs suivantes viennent des rapports `Perf` ecrits dans le log Studio
local. Les temps sont des P95 en millisecondes, sauf indication contraire.

| Scenario | Heartbeat serveur | Tick monstre | Frame client P50 / P95 / P99 | Draw calls moy. | Triangles moy. |
| --- | ---: | ---: | ---: | ---: | ---: |
| `monsters_25` | 7,34 | 1,06 | 6,05 / 7,65 / 8,32 | 14 | 59 624 |
| `monsters_100` | 7,99 | 5,73 | 6,01 / 8,32 / 10,09 | 39 | 215 825 |
| `monsters_250` | 23,98 | 19,23 | 19,56 / 26,34 / 31,06 | 89 | 528 290 |
| `monsters_500` | 66,88 | 51,27 | 49,03 / 67,78 / 165,34 | 177 | 1 049 012 |
| `monsters_1000` | 173,79 | 128,69 | 142,54 / 180,46 / 204,56 | 352 | 2 090 542 |
| `projectiles_24` | 7,16 | 1,41 | 6,05 / 7,65 / 8,37 | 14 | 57 522 |
| `collectibles_300` | 7,95 | 0,01 | 6,04 / 7,48 / 7,99 | 6 | 45 886 |

Autres releves utiles :

- `monsters_500` : `1 734` frames superieures a `33,3 ms` ;
- `monsters_1000` : `656` frames superieures a `33,3 ms` ;
- `monsters_1000` : `1 278 560` raycasts WorldSpawn sur 90 secondes ;
- `collectibles_300` : fusion XP P95 `0,081 ms`, fusion coin P95 `0,096 ms`.

### Ce que la calibration etablit deja

1. Le rail de mesure est operationnel. Les sept scenarios, leurs phases et
   leur nettoyage sont effectivement enchaines. C'est la premiere preuve que
   P0 mesure autre chose qu'un FPS instantane.
2. La pente de charge des monstres est nette. Le palier 250 depasse deja le
   budget de `16,7 ms` correspondant a 60 FPS cote client et le tick monstre
   P95 atteint `19,23 ms`. A 500, serveur et client sont tous deux tres au
   dessus de ce budget. A 1 000, le plafond reste donc un stress test debug,
   pas une cible de gameplay stable.
3. Le cout rendu brut ne semble pas expliquer seul les frames longues : les
   P95 Render CPU et GPU restent autour de 6 ms et 2 a 4 ms dans les logs,
   alors que le frame P95 client atteint 67,78 ms puis 180,46 ms. Il faut
   exposer explicitement le P95 physique, la replication et le cout simulation
   client avant d'attribuer ce temps au GPU.

### Limites revelees par la calibration

1. Le scenario `projectiles_24` tire une salve unique au debut de la mesure.
   Les projectiles peuvent toucher ou expirer bien avant la fin des 90
   secondes. Il ne mesure donc pas encore une pression projectile soutenue.
2. Le scenario `collectibles_300` mesure surtout la creation, la fusion et le
   nettoyage de 300 drops. Les fusions reduisent rapidement le nombre de
   collectibles visibles ; il ne garantit pas 300 collectibles actifs pendant
   toute la fenetre de mesure.
3. La memoire totale Studio n'est pas une separation fiable entre serveur et
   client : les chiffres remontes sont tres proches car les deux contextes
   partagent le processus Studio. La hausse de `2 289 MB` a `3 606 MB` sur la
   campagne traduit surtout le prechauffage progressif des pools jusqu'a 1 000
   monstres, pas une fuite prouvee. La comparaison utile devra commencer apres
   prechauffage identique et suivre les tags memoire, les instances runtime et
   les tailles de pools.
4. Le budget VFX adaptatif s'est reduit pendant la campagne (`Quality`, puis
   `Balanced`, puis `Performance`). La charge graphique n'est donc pas restée
   constante entre paliers. Une baseline devra distinguer un mode graphique
   verrouille d'une campagne representative avec adaptation active.
5. Le reseau reste explicitement non mesure par le script. Le rapport demande
   encore une capture MicroProfiler ou Developer Console. P0 ne peut pas
   pretendre separer CPU, GPU, reseau et memoire tant que cette capture manque.
6. Les rapports detailes existent dans le log Studio, mais la synthese Admin
   n'expose pas encore les sept resultats de facon directement exportable.

### Decision de calibration

Decision : `Adjust`.

Avant de rejouer les trois campagnes de baseline, P0 doit etre renforce pour :

1. fixer ou declarer explicitement l'etat du budget VFX pendant une campagne ;
2. rendre les scenarios projectile et collectibles soutenus, ou les renommer
   strictement comme tests de salve et de fusion ;
3. afficher les P95 physique, instances, VFX et tags memoire deja collectes ;
4. rendre le rapport de campagne recuperable sans dependre d'une longue
   recherche manuelle dans les logs ;
5. ajouter au protocole la capture reseau et MicroProfiler.

P0 reste ouvert. Aucun gain de performance n'est revendique et P1 ne doit pas
etre ouvert sur cette premiere campagne de calibration.

### Observation complementaire issue du journal brut

Apres l'emission du rapport de campagne, le contexte de jeu normal est restaure
et le combat recommence a peupler la run. Les mesures `AfterCleanup` de chaque
scenario restent exploitables car elles sont ecrites avant cette reprise, mais
la memoire observee apres la campagne ne peut pas servir de mesure de stabilite
au repos. Le protocole officiel devra ajouter une fenetre idle explicite, avec
le spawn combat suspendu, avant de mesurer le nettoyage et la memoire residuelle.

## Appendice chronologique - Calibration P0.5 appliquee le 2026-07-17 10:15 Europe/Paris

Les limites de la calibration non-baseline precedente sont traitees dans
`post_audit_2026-07-17_101500_performance_p0_calibration.md`.

Le protocole officiel est maintenant :

1. `15 s` de chauffe ;
2. `90 s` de mesure ;
3. `2 s` de nettoyage sans reprise des vagues ordinaires ;
4. `8 s` de repos observe dans le contexte P0 ;
5. transition de campagne ou restauration du contexte de run.

La campagne `p0_complete` est la selection Admin par defaut. Elle contient :

1. `monsters_25` ;
2. `monsters_100` ;
3. `monsters_250` ;
4. `monsters_500` ;
5. `monsters_1000` ;
6. `projectiles_24`, explicitement une charge soutenue de 24 tirs par seconde
   et non 24 projectiles garantis simultanement ;
7. `collectibles_fusion_300`, explicitement une creation et fusion initiale
   de 300 collectibles, et non une population stable de 300 objets.

Le budget VFX adaptatif est verrouille a la qualite manuelle pendant P0. La
configuration effective reste relevee dans chaque rapport et le verrou est
retire a la fin de la campagne sans modifier les preferences du joueur.

Une campagne est marquee non comparable si le client constate un changement de
viewport ou une perte de focus. Cette detection ne remplace pas la discipline
manuelle : aucune interaction, aucun changement de qualite et aucune navigation
hors Studio ne doivent avoir lieu pendant les sept scenarios.

Les resultats de la session sont recuperables sans parcourir les logs courants
via `ReplicatedStorage/PerformanceBaselineReports/LatestCampaign` et les
valeurs `Scenario_*`. Les memes syntheses sont imprimees avec le prefixe
`[MegaRoblox][P0_EXPORT]` afin de pouvoir etre archivees apres l'arret du Play
Test.

P0 reste ouvert. La prochaine campagne propre servira de baseline J-000 ; elle
ne devra pas etre confondue avec la calibration precedente.
