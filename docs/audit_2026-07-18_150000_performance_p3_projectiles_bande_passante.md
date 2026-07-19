# P3 - Projectiles et bande passante : etat de reference et protocole

Date : 2026-07-18 15:00 Europe/Paris.

## Etat initial

Commit : `a940990`, avec les modifications locales conservees des phases P1 et
P2 deja validees.

Le service de combat reste autoritaire : le serveur cree le noyau de Fireball,
simule sa position, resout le homing, les collisions, les rebonds, les degats et
la duree de vie. Le client proprietaire ajoute les VFX lourds locaux ; un impact
est deja envoye au client proprietaire via un `RemoteEvent` fiable.

La campagne existante contient `projectiles_24`, mais ce scenario ajoute aussi
`48` monstres. Il mesure donc simultanement la horde, le ciblage de
`MonsterService`, la separation, le suivi de sol et les projectiles. Il ne peut
pas etablir seul le cout reseau ou visuel d'une trajectoire de projectile.

La baseline P0 disponible pour ce scenario melange vaut : frame serveur P95
`8,24 ms` et tick monstre P95 `3,48 ms`. Cette valeur reste archivee, mais ne
sera pas employee comme baseline isolee P3.

## Hypothese

Le noyau de projectile serveur est une instance poollee dont le `PivotTo` est
repplique a chaque pas de simulation. Quand les futures armes multiplieront les
tirs, ce flux de transformations peut devenir plus couteux que le calcul logique
lui-meme, surtout avec plusieurs joueurs.

Cette hypothese n'est pas encore prouvee. Avant toute migration de rendu vers
le client, P3 doit distinguer :

- cout CPU du tick `WeaponService` ;
- nombre de noyaux vivants, creations, reutilisations, destructions et mises a
  jour de transform ;
- debit Roblox observe (`DataSendKbps` et `DataReceiveKbps`) sur serveur et
  client ;
- cout client de rendu et nombre de couches VFX actives ;
- trafic de `RemoteEvent` emet explicitement par le jeu.

## Protocole P3.0

Un scenario dedie `projectiles_isoles_24` sera ajoute comme selection P3
independante. Il utilisera le meme seed, warm-up et duree que les scenarii
existants, mais :

1. aucun monstre ne sera cree ;
2. huit marqueurs carres temporaires seront places a distance fixe autour du
   joueur dans l'arene de benchmark ;
3. le joueur emettra vingt-quatre Fireballs par seconde vers ces marqueurs ;
4. les Fireballs reutiliseront le pool, le mouvement, les `PivotTo`, le profil
   VFX, l'impact client et la duree de vie de production ;
5. atteindre un marqueur termine la trajectoire avec son impact visuel normal,
   mais ne produit jamais de degat, loot, XP ou statistique de run.

Le scenario est visible pour permettre au responsable produit d'evaluer la
trajectoire hors de la masse ennemie. Il est temporaire et est detruit lors du
nettoyage de benchmark.

La premiere capture P3.0 ne cherche aucun gain : elle constitue le reference
avant de choisir une unique modification d'architecture. Les variantes de
cadence, rebond, duree et multi-joueur ne seront ajoutees qu'apres lecture de
ce premier resultat, afin de ne pas confondre les causes.

## Instrumentation retenue

Pendant une capture seulement, `WeaponService` comptera :

- projectiles crees, reutilises et remis au pool ;
- mises a jour de transform serveur ;
- emissions de VFX d'impact fiables ;
- nombre de projectiles benchmark et de tirs demandes.

La telemetrie serveur et client echantillonnera les proprietes publiques
`Stats.DataSendKbps`, `Stats.DataReceiveKbps`, `Stats.PhysicsSendKbps` et
`Stats.PhysicsReceiveKbps`, ainsi que les mesures CPU et instances deja
capturees. Ces valeurs sont des debits globaux de l'instance, pas une attribution
par projectile : la comparaison devra donc conserver une session solo et le meme
contexte d'arene.

Les compteurs locaux d'instances et de transformations ne seront pas presentes
comme des octets reseau. Ils servent a expliquer une variation de debit, pas a
la remplacer.

## Perimetre et frontieres

`WeaponService` est partage par le combat reel, les items et le benchmark. La
modification P3.0 doit rester appendice de benchmark : aucune regle de degat,
portee, rebond, cadence de combat, son, VFX ou selection de cible reelle ne
change.

`PerformanceBenchmarkService` est egalement partage avec les campagnes P0-P2.
Le scenario ajoute doit conserver les sept scenarii existants et ne modifier ni
leurs valeurs, ni leur ordre. La campagne P0 historique reste donc a sept
scenarii ; P3 est lance explicitement comme scenario isole pour conserver sa
propre baseline de trajectoires et de trafic.

## Budget de complexite et rollback

P3.0 ajoute un type de cible de benchmark borne, une entree de scenario et des
compteurs actifs seulement pendant la capture. Il n'ajoute aucun nouveau remote,
aucune bibliotheque et aucune autorite cliente.

Rollback conceptuel : supprimer le scenario, les marqueurs temporaires et le
point d'entree benchmark. Le chemin Fireball de jeu reste alors identique.

## Angles morts declares

- Un Studio solo ne reproduit pas la replication vers plusieurs joueurs ni les
  conditions reseau publiees. Une capture publiee privee et un test multi-client
  seront requis avant de conclure sur la bande passante multi-joueur.
- `DataSendKbps` est un debit global. La premiere capture doit minimiser les
  autres sources de trafic ; elle ne permet pas d'attribuer tous les octets aux
  seuls projectiles.
- Les impacts sur marqueur sont presents pour conserver un cycle de vie de
  projectile credible, mais ils n'exercent aucune regle de combat. Un scenario
  rebond sera decide separement si la premiere baseline montre que le cout de
  trajectoire et d'impact n'est pas dominant.
- Les `UnreliableRemoteEvent` ne sont pas retenus a ce stade. La documentation
  Roblox les destine aux donnees continues et non critiques, ce qui peut etre
  pertinent pour une correction visuelle future, mais pas pour les hits,
  recompenses ou resultats serveur.

## Capture P3.0-A - 2026-07-18 14:58 Europe/Paris

Scenario : `projectiles_isoles_24` en Studio, session solo, seed benchmark
`17072026`, capture comparable et validee par le protocole.

Resultats bruts :

- tirs demandes et emis : `2 128` sur `90 s`, soit `23,64 tirs/s` ;
- projectiles crees : `2 128`, dont `2 082` reutilisations de pool et `46`
  clones ;
- projectiles remis au pool : `2 128` ;
- transforms serveur : `815 119`, soit environ `9 057/s` et `383` par tir ;
- impacts visuels : `1 694` ;
- fins de trajectoire sans impact : `434` par deduction (`2 128 - 1 694`) ;
- projectiles actifs P95 : `65`, pool P95 : `20` ;
- tick `WeaponService` P95 : `1,25 ms`, coeur serveur P95 : `8,03 ms` ;
- debit serveur sortant P95 : `316,23 Kbps` ;
- frame client P95 : `8,41 ms`, VFX P95 : `80` emitters et `32` lights ;
- memoire serveur : `2 479,75 MB` avant, `2 510,43 MB` au pic et
  `2 483,09 MB` apres repos.

Lecture : le pool ne presente pas de croissance non bornee pendant cette
capture. Les `46` clones correspondent au depassement ponctuel du prechauffage
de `24` instances ; tous les projectiles sont ensuite recycles. En revanche,
le nombre de transforms est suffisamment eleve pour justifier P3, mais ne
prouve pas encore que la replication automatique est le cout dominant.

Le `DataReceiveKbps` client est revenu a `0` tandis que le serveur rapportait
`316,23 Kbps` sortants. Cette contradiction rend la lecture client du debit
inexploitable dans Studio pour cette capture. Le chiffre serveur restera une
serie comparative a contexte identique ; toute attribution par type de paquet
devra passer par un dump MicroProfiler reseau avant une decision d'architecture.

La capture A est une pre-capture utile, mais ne sera pas combinee aux captures
finales tant que le decompte explicite des expirations P3 n'aura pas ete active.
Le seul changement suivant est ce compteur, sans impact sur le gameplay ni la
simulation.

## Repetitions P3.0-B a D - 2026-07-18 15:08 a 15:15 Europe/Paris

Les quatre executions ont ete lancees dans une meme session Studio et avec le
meme `run_seed` `2074650518`. Trois exports generiques sont comparables ; une
execution intermediaire est exclue car la fenetre a perdu le focus.

| Capture | Comparable | Coeur P95 | Weapon P95 | Frame client P95 |
| --- | --- | --- | --- | --- |
| B - 15:08 | oui | 8,00 ms | 1,02 ms | 8,38 ms |
| C - 15:10 | oui | 8,01 ms | 1,13 ms | 8,38 ms |
| exclue - 15:12 | non, focus perdu | 8,00 ms | 1,07 ms | 8,76 ms |
| D - 15:15 | oui | 8,00 ms | 1,12 ms | 8,23 ms |

Sur les trois captures comparables, le tick projectile P95 vaut en moyenne
`1,09 ms`, avec un ecart total de `0,11 ms`. Le frame client P95 est compris
entre `8,23` et `8,38 ms`. Cette variance est suffisamment faible pour comparer
une future modification CPU dans ce meme protocole chaud.

Limite explicite : seules les lignes generiques `P0_EXPORT` ont ete conservees
pour cette serie. Les lignes `P3_PROJECTILES`, contenant transforms, impacts,
expirations, reutilisation et debit, manquent donc encore pour etablir la
baseline P3 reseau complete.

Les valeurs memoire ne sont pas interpretees comme une fuite : les repetitions
partagent la meme session Studio et le premier passage peut remplir des pools,
charger des assets et faire evoluer les caches moteur. Le passage de
`2 748,21 MB` apres B a `2 940,21 MB` avant C exige une mesure de cycle de vie
dediee, pas une conclusion sur les projectiles seuls.

## Sources techniques consultees

- Roblox `Stats` : `DataSendKbps` et `DataReceiveKbps` sont des debits reseau
  observes par seconde ; vus du serveur, ils couvrent le trafic total vers ou
  depuis les clients.
- Roblox Remote Events : les `UnreliableRemoteEvent` sacrifient fiabilite et
  ordre pour des donnees continues non critiques. Aucun emploi n'est justifie
  avant une baseline qui demontre que les transformations repliquees sont le
  cout dominant.
- Roblox MicroProfiler Network : un dump reste necessaire pour attribuer un
  paquet a ses details de replication si les compteurs globaux deviennent
  insuffisants.

## Capture P3.0-B a D detaillee - 2026-07-18 15:08 a 15:15 Europe/Paris

Les lignes `P3_PROJECTILES` des trois repetitions comparables ont ete
recuperees apres coup. Elles completent la serie precedente ; la capture de
15:12 reste exclue car la fenetre Studio a perdu le focus.

| Capture | Transforms | Impacts | Expirations | Actifs P95 | Pool P95 | Weapon P95 | Envoi serveur P95 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| B - 15:08 | 827 579 | 1 691 | 380 | 67 | 20 | 1,02 ms | 318,94 Kbps |
| C - 15:10 | 790 862 | 1 763 | 309 | 62 | 24 | 1,13 ms | 303,66 Kbps |
| D - 15:15 | 841 399 | 1 641 | 419 | 65 | 19 | 1,12 ms | 324,45 Kbps |

Les trois repetitions ont toutes demande, emis et recycle `2 128` projectiles
sur `90 s`, soit `23,64 tirs/s`. Le premier passage a clone `47` noyaux, le
second n'en a clone aucun et le troisieme un seul : le pool chaud couvre donc
l'essentiel de la charge stable. Les quelques clones restants sont un
depassement transitoire du prechauffage, pas une croissance permanente
constatee dans la capture.

Moyennes comparables :

- `819 947` transforms par capture, soit environ `9 110/s` et `386` par tir ;
- `315,68 Kbps` d'envoi serveur P95 ;
- `1,09 ms` de tick projectile P95 ;
- `64,7` projectiles actifs P95 ;
- `145,92 Kbps` d'envoi client P95, chiffre global non attribuable aux seuls
  projectiles.

La dispersion des transforms est de `6,2 %` autour de la moyenne et celle de
l'envoi serveur de `6,6 %`. Elles sont suffisamment contenues pour comparer un
pilote P3.1 dans le meme environnement. Les compteurs client de reception sont
a `0` dans les trois captures alors que le serveur declare un trafic sortant :
ils restent donc explicitement non exploitables pour une attribution de debit
dans Studio.

Les fins de cycle sont coherentes : impacts et expirations expliquent entre
`2 060` et `2 072` projectiles ; les `56` a `68` restants sont les noyaux
encore actifs au nettoyage force de fin de scenario. Cette difference ne doit
pas etre lue comme une perte de projectile ou une fuite de pool.

## Decision intermediaire P3.0

✔️ Juste : la baseline est desormais assez complete pour ouvrir un pilote
P3.1. Elle isole le cout de trajectoires de la horde, prouve la stabilite du
pool a chaud et mesure le nombre effectif de transforms qui reste le meilleur
suspect du trafic.

⚡ Simplification : augmenter simplement le prechauffage a `72` supprimerait
les clones de la premiere salve, mais ne supprimerait ni les environ `9 110`
transforms par seconde ni leur replication. Cette modification reporterait de
la memoire et du travail au debut de run sans traiter le cout dominant observe.
Elle n'est donc pas retenue a ce stade.

⚔️ Angle mort : l'envoi serveur est un debit global et le test reste solo. Il
ne permet pas encore de quantifier le surcout exact d'un projectile pour deux,
quatre ou huit clients. Le pilote suivant devra garder le serveur autoritaire,
etre activable par configuration et etre compare au meme scenario avant toute
bascule de production.

P3.1 commencera par un audit du contrat de presentation puis un pilote isole
sur le scenario de benchmark. Le pilote ne modifiera ni les degats, ni les
rebonds, ni la cadence, ni les regles de loot : il evaluera seulement la
substitution du noyau replique par une presentation locale creee depuis un
evenement serveur fiable de creation et terminee par les evenements existants
d'impact ou de destruction.

## P3.1 - Pilote de presentation locale isolee - 2026-07-18 15:35 Europe/Paris

### Point d'impact avant modification

`WeaponService` est un fichier partage : il gere les tirs automatiques reels,
les salves, les degats, les rebonds, les items de run, les analytics, le pool
et les tirs synthétiques de benchmark. La modification P3.1 est donc bornee a
la methode de benchmark `DebugFireballBurstAtPositions` et ne peut etre activee
que par le nouveau scenario `projectiles_isoles_24_client_pilot`.

`ProjectileVisualService` possede deja le remote fiable de VFX
`CombatVfx_Play`, employe pour les impacts. P3.1 reutilise ce contrat de VFX
pour les evenements bornes `ProjectileSpawn` et `ProjectileDestroy` plutot que
de creer un canal supplementaire. `ProjectileVfxController` continue de gerer
les pools locaux d'attachments, de trails, de particules, de lights et
d'impacts ; il recoit seulement une nouvelle source locale de noyau pour le
scenario pilote.

Les dependances explicitement hors perimetre sont `MonsterService`,
`PerkService`, `RunItemService`, `RunAnalyticsService` et `AudioService` :
elles conservent les memes appels et les memes regles de jeu. L'audio de cast
reste intentionnellement a une emission par projectile, conformement au choix
produit deja valide.

### Modification et hypothese testee

Le nouveau scenario reproduit exactement les huit cibles fixes et la cadence
de `24/s` de P3.0. Pour lui seul :

1. le serveur cree toujours l'etat Fireball, calcule homing, age, expiration et
   impact ;
2. le template poolé actif reste dans `ServerStorage/ProjectileSimulation`, pas
   dans `Workspace/CombatRuntime/Projectiles` ;
3. le serveur ne lui applique donc aucun `PivotTo` replique ;
4. il envoie au seul client proprietaire un spawn VFX fiable ferme, contenant
   le profil, la position initiale, la cible fixe et les parametres de courbe ;
5. le client cree un noyau local et lui applique les memes couches VFX et le
   meme budget graphique que les projectiles observes precedemment ;
6. le serveur envoie encore l'impact et la destruction, puis recycle le
   template exactement comme avant.

Le nouveau rapport distingue `transforms_repliques` et
`transforms_logiques`. Le premier doit passer de l'ordre de `819 947` a `0`
dans le pilote ; le second doit rester voisin de la baseline, puisqu'il mesure
la simulation serveur qui n'est volontairement pas deplacee vers le client.

### Budget de complexite et rollback

Complexite ajoutee : un mode de presentation explicite, deux messages VFX
fiables bornes et un simulateur visuel client reserve aux cibles fixes de P3.
Elle est volontairement isolee du tir reel. Aucun `UnreliableRemoteEvent`,
aucun package externe, aucune serialisation maison et aucun changement de
cadence ou de degat ne sont introduits.

Rollback conceptuel et technique : retirer le scenario
`projectiles_isoles_24_client_pilot` et les branches `ClientPilot`. Le chemin
de production reste deja sur `ReplicatedCore`, sans migration inverse a faire.

### Proof of done intermediaire attendu

Le pilote est retenu seulement si :

- les cibles visibles recoivent une trajectoire et un impact acceptables ;
- le rapport montre `transforms_repliques=0` tout en gardant les memes tirs,
  impacts, expirations et recyclages ;
- `Weapon.TickSeconds` ne regresse pas materiallement ;
- le debit serveur sortant diminue dans des repetitions comparables ;
- aucun projectile local ne persiste apres nettoyage ;
- le scenario standard `projectiles_isoles_24` reste visuellement et
  numeriquement inchange.

⚔️ Angle mort : cette premiere presentation locale ne convient qu'aux cibles
fixes du benchmark. Les cibles de production bougent et les rebonds changent
de cible ; les generaliser requerra un contrat de corrections visuelles
separe, puis un smoke multi-client. P3.1 ne revendique donc aucun gain
production tant que cette preuve plus stricte n'existe pas.

## Resultat P3.1 preliminaire - 2026-07-18 15:35 Europe/Paris

### Etat initial

Commit : `a940990` plus les modifications locales du pilote P3.1, non encore
retenues pour le combat de production.

Scenario : `projectiles_isoles_24_client_pilot`, huit cibles fixes, `2 128`
tirs demandes, emis et recycles. Le scenario standard P3.0 conserve le meme
volume de tirs et constitue la reference directe.

### Resultats

| Mesure | P3.0, moyenne de trois captures comparables | P3.1 pilote | Ecart |
| --- | ---: | ---: | ---: |
| Tirs emis | 2 128 | 2 128 | 0 % |
| Transforms repliques | 819 947 | 0 | -100 % |
| Pas logiques serveur | environ 819 947 | 794 322 | -3,1 % |
| Impacts | 1 698 | 1 689 | dans la variance attendue |
| Projectiles actifs P95 | 64,7 | 65 | stable |
| Tick `WeaponService` P95 | 1,09 ms | 0,27 ms | -75,2 % |
| Envoi serveur P95 | 315,68 Kbps | 19,14 Kbps | -93,9 % |
| Frame client P95 | 8,33 ms | 8,23 ms | pas de regression observee |

Le pool se comporte comme lors du premier passage P3.0 : `2 080` reutilisations
et `48` clones pour absorber un maximum de `65` projectiles actifs. Les
`2 128` destructions pilote et les `2 128` recyclages confirment que le
nettoyage du scenario est complet.

### Lecture critique

Juste : le pilote demontre que supprimer les `PivotTo` repliques est bien le
levier dominant dans ce scenario. Le serveur continue de calculer les memes
trajectoires et conserve la decision d'impact. Le gain CPU et debit est donc
attribuable a la representation, pas a une simplification cachee du combat.

Simplification : le passage de `315,68` a `19,14 Kbps` est un debit global
Studio. Il prouve un ecart tres important dans le meme environnement, mais ne
mesure pas encore le cout par client supplementaire ni le detail exact de
chaque paquet Roblox.

Angle mort : les compteurs VFX historiques totalisent les descendants du
runtime, y compris les packages places dans le pool mais desactives. Le
`P95=288` particules et `P95=83` lumieres de P3.1 ne peut donc pas etre lu
comme un cout de rendu actif ni compare directement au `P95=80/32` de P3.0.
L'instrumentation ajoute maintenant les compteurs distincts de particules,
lumieres et trails **actifs**. Une repetition P3.0 et P3.1 est necessaire
avant toute conclusion visuelle ou memoire.

### Decision intermediaire

Keep pour le pilote isole. Defer pour toute bascule du tir reel : les cibles
mobiles, les rebonds et la correction visuelle de production ne sont pas
couverts. Aucun changement gameplay n'est retenu a ce stade.

## Rectification de l'instrumentation VFX - 2026-07-18 15:53 Europe/Paris

La premiere separation "alloues / actifs" a revele une seconde limite : le
compteur parcourait uniquement `MegaRobloxClientVfxRuntime`. Lors du scenario
standard, les attachments et les VFX du noyau replique sont attaches
localement sous `Workspace/CombatRuntime/Projectiles`, donc hors de ce dossier.
Le resultat `particules_actives_p95=0` et `trails_actifs_p95=0` du scenario
standard ne decrit pas l'absence de rendu ; il decrit un perimetre de comptage
incomplet.

L'instrumentation repose maintenant sur le tag local
`MegaRobloxProjectileVfx`, attribue aux emitters, trails et lights fabriques
par `ProjectileVfxController`, qu'ils soient attaches au noyau replique, au
noyau pilote local ou remis dans le pool. Les prochains exports distingueront
donc correctement les elements alloues et ceux dont la propriete `Enabled` est
active, sans parcourir les VFX de map ni modifier le comportement visuel.

Cette rectification est de l'observabilite uniquement. Elle ne modifie ni la
simulation, ni les remotes, ni le budget VFX, ni la qualite choisie par le
joueur. Une nouvelle paire de captures P3.0/P3.1 est requise avant de comparer
la densite visuelle des deux presentations.

## Comparaison VFX corrigee P3.0 / P3.1 - 2026-07-18 16:00 a 16:03 Europe/Paris

Les deux scenarios ont ete executes dans la meme session Play, avec le meme
seed de benchmark et de run. Les deux captures sont comparables.

| Mesure | Noyau replique P3.0 | Pilote client P3.1 | Lecture |
| --- | ---: | ---: | --- |
| Particules actives P95 | 210 | 209 | parite pratique |
| Lumieres actives P95 | 54 | 54 | identique |
| Trails actifs P95 | 66 | 65 | parite pratique |
| Draw calls moyens | 619 | 626 | +1,1 % |
| Triangles moyens | 68 187 | 68 781 | +0,9 % |
| Instances client P95 | 59 697 | 59 648 | stable |
| Frame client P95 | 8,32 ms | 7,88 ms | pas de regression observee |
| Tick `WeaponService` P95 | 1,10 ms | 0,24 ms | -78,2 % |
| Envoi serveur P95 | 320,05 Kbps | 18,27 Kbps | -94,3 % |

Les tirs emis et recycles sont identiques (`2 128`). Les impacts (`1 692`
contre `1 678`) et expirations (`380` contre `400`) restent dans la variance
deja observee sur les repetitions P3.0. Les pas logiques serveur diminuent de
`2,2 %`, valeur inferieure a la dispersion historique de la simulation ; aucun
changement de regle n'est donc deduit de cet ecart.

Juste : P3.1 atteint son proof of done intermediaire sur le cas fixe. Le cout
reseau et CPU serveur diminue fortement sans economiser artificiellement les
couches VFX du joueur.

Angle mort bloquant : cette parite est demontree sur huit cibles immobiles.
Elle ne prouve pas encore la fidelite d'un homing vers un monstre mobile, d'un
rebond ou d'une correction apres retard reseau. P3 reste ouvert ; le prochain
travail doit traiter ces trois comportements avant toute activation du pilote
sur les tirs reels.

## P3.2 - Pilote reel solo a cible mobile - 2026-07-18 16:16 Europe/Paris

### Etat avant modification

Le pilote P3.1 etait volontairement limite aux huit positions fixes du
benchmark. Le code client etait donc proche de la courbe serveur mais contenait
des constantes locales et aucune mise a jour de cible. Cette limite protegeait
le tir reel mais empechait de verifier le comportement qui compte : une
Fireball qui suit un monstre vivant puis rebondit vers un autre.

### Modification et isolation

Un interrupteur admin `P3 : pilote client` active maintenant ce mode seulement
pour le joueur administrateur et seulement lorsque la session ne contient qu'un
joueur. Le chemin normal reste `ReplicatedCore`. En particulier, un second
joueur ne peut pas activer ce test et un test deja actif peut toujours etre
desactive afin de ne pas emprisonner une session dans un etat experimental.

Quand cet interrupteur est actif :

1. le serveur conserve le projectile poolÃ©, la trajectoire autoritaire, le
   ciblage spatial, les impacts, les degats, les effets de run, les rebonds et
   le recyclage ;
2. le noyau temporaire reste dans `ServerStorage/ProjectileSimulation`, donc
   ses transforms ne sont pas repliques ;
3. le serveur envoie une creation VFX fiable avec la `BasePart` de cible et sa
   position de secours ;
4. le client suit la vraie `BasePart` repliquee pour son homing visuel, en
   consommant les memes valeurs de `CombatConfig` que le serveur ;
5. un rebond autoritaire envoie une unique correction fiable de position,
   direction et nouvelle cible ; le client ne choisit jamais cette cible.

Le contrat ne cree aucun nouveau remote : il reutilise le canal fiable VFX
deja employe par les impacts, avec les messages bornes `ProjectileSpawn`,
`ProjectileRetarget` et `ProjectileDestroy`.

### Budget de complexite et rollback

Complexite ajoutee : un attribut de joueur de test, une correction de rebond
et le suivi local d'une cible repliquee. Complexite retiree : les constantes
dupliquees dans le simulateur client ; il lit maintenant `CombatConfig`.
Le test est desactive par defaut et le retrait de l'attribut, de la branche
`ClientPilot` et des trois messages rend immediatement le noyau replique.

### Smoke manuel canonique requis

Avant toute migration de production, le responsable produit doit effectuer en
Studio solo :

1. activer `P3 : pilote client` dans l'admin ;
2. lancer une run, faire apparaitre des ennemis et verifier que la Fireball
   suit une cible mobile, touche, applique les degats et declenche l'impact ;
3. obtenir au moins un rebond et verifier visuellement la redirection sans
   disparition ni duplication de noyau ;
4. desactiver le pilote et verifier le retour immediat du comportement normal
   sur les nouveaux tirs ;
5. terminer la run puis en lancer une autre pour verifier qu'aucun noyau local
   ne persiste.

Angle mort bloquant : ce mode ne rend aucun projectile aux autres joueurs. Ce
choix est intentionnel pour un test solo sans degrader silencieusement une
partie multijoueur. Une strategie explicite de presentation des projectiles
d'autrui, puis un smoke a deux clients, restent necessaires avant une bascule
de production.
