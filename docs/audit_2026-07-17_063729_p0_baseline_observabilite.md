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
