# Contre-analyse du rapport Cursor sur la charge serveur

Date : 2026-07-21 22:30 Europe/Paris

## Objet

Ce document evalue un rapport externe de performance. Il ne constitue pas une
phase d'optimisation et ne modifie aucun comportement. Son role est de
distinguer les observations techniques utiles des recommandations generiques,
des sujets deja traites par P2/P3 et des propositions incompatibles avec le
contrat produit actuel.

## Referentiel de comparaison

Les conclusions sont comparees a :

- la campagne P0/P2, qui a mesure le tick monstre P95 de `1.16` a `134.31 ms`
  avant P2 puis de `1.00` a `90.86 ms` apres P2 sur les paliers 25 a 1 000 ;
- P3, qui a retire la replication continue des transforms Fireball du run
  solo : `320.05` a `18.27 Kbps` serveur P95 et `1.10` a `0.24 ms` de tick
  projectile P95 ;
- le contrat produit actuel : une run est solo, le serveur reste autoritaire
  pour les degats et les recompenses, et les aires de Leyde frappent toutes les
  cibles presentes dans leur zone.

## Verdict par sujet

### Simulation de monstres et LOD

**Juste, avec une priorite exageree.** `MonsterService` visite encore chaque
etat de monstre et calcule une cible avant d'appliquer le LOD. A
`MonsterSimulationHz = 0`, cela arrive a chaque Heartbeat. En revanche, dans
le contrat solo, le ciblage ne compare qu'un joueur et a pese `0.86 ms P95` a
1 000 monstres, loin derriere mouvement et separation. P2 a deja reduit ces
derniers de facon materialisee.

Un fixed-step existe deja mais n'est pas actif par defaut, justement pour ne
pas changer sans validation la reactivite des monstres pres du joueur. Une
planification par buckets reste une piste P2.x possible, non une correction
immediate. Elle devra prouver un gain au palier canonique 250/500 et un smoke
de proximite, degats et mouvement.

### Comptage global des monstres

**Juste.** `getAliveMonsterCount` parcourt `monstersByInstance` a chaque
appel. Il est notamment appele dans le chemin de spawn. Le rapport surestime
neanmoins sa frequence : ce n'est pas quatre a six scans par joueur et par
frame dans la simulation de chaque monstre. En solo, le cout est borne mais
evitable. Un compteur maintenu par spawn, mort et recyclage serait une petite
evolution reversible a mesurer avant adoption.

### Separation et recyclage derriere le joueur

**Simplification.** Le rapport traite le recyclage comme une visite globale
chaque frame. En realite, son scan est garde par un intervalle de `1.5 s`, un
cooldown de `4 s` et un maximum de deux monstres recycles. Son but produit est
de reconstituer une menace devant le joueur sans creer de nouveaux monstres.

La grille de separation persistante et les requetes locales sont deja le coeur
de P2. Une recherche de candidats de recyclage par cellules est envisageable,
mais seulement si les mesures montrent qu'elle pese pendant une run reelle.

### Raycasts de sol et RaycastParams

**Juste sur l'allocation, insuffisant sur la causalite.** Certains appels
creent encore un `RaycastParams`. Cela ne prouve pas un probleme de GC ni de
frame. P2 a introduit un cache de hauteur partage : apres chauffe, la campagne
observe `0` raycast sol dans les paliers mesures et `907` utilisations de
cache partage a 1 000 monstres.

Un `RaycastParams` singleton mutable serait risque car les filtres different
selon le chemin. Une optimisation ne doit donc pas etre appliquee de maniere
globale. Le cout restant doit d'abord etre ventile par appelant.

### Collectables serveur et client

**Juste pour la complexite, non prouve comme goulot actuel.** XP et coins
parcourent les collectables puis les joueurs toutes les `0.15 s`. Le scenario
P0 de fusion de 300 collectables ne montre pas de cout serveur notable, mais
ne remplace pas une mesure de collecte reelle en mouvement.

Cote client, les collectables sont parcours a une cadence de culling et
d'animation idle configuree, pas tous transformes a chaque frame. Seules les
attractions actives sont animees a chaque frame, avec un cap. Une grille
persistante de collectables n'est justifiee que si une mesure de run lie les
pics a ces scans. Une grille reconstruite par joueur serait elle-meme une
mauvaise direction : une grille persistante interrogee autour du joueur serait
le modele a evaluer si necessaire.

### Scans descendants et prompt coffre client

**Partiellement juste.** Les scans `Workspace:GetDescendants()` et les
callbacks `DescendantAdded` existent au demarrage client. Ils peuvent etre
nettoyes un jour, mais ils sont hors boucle de combat et ne constituent pas
une preuve de perte de FPS en run.

**Faux pour le coffre chaque RenderStepped.** Le fallback client existe mais
`CLIENT_CHEST_PROMPTS_ENABLED = false`; son suivi et sa recherche du coffre
le plus proche retournent immediatement. Les coffres normaux utilisent deja le
`ProximityPrompt` serveur.

### Animation de course

**Juste, mais hors cadre performance de run.** La construction du mapping des
Motor6D parcourt les descendants du personnage plusieurs fois. Elle ne se
declenche qu'au bind du personnage, donc au spawn/respawn et non a chaque
frame. Une passe unique est un micro-nettoyage raisonnable, mais elle ne doit
pas etre presentee comme une optimisation de horde.

### Coffre de recompense et Touched

**Contestable.** Le branchement `Touched` concerne uniquement le coffre de
recompense d'elite et ses BasePart, pas les coffres ordinaires. `CanTouch`
n'active pas a lui seul la collision physique : il active les evenements de
contact. Le comportement est volontaire et a ete smoke-teste apres P1.

Un volume de contact unique reduirait les connexions mais changerait le
comportement et necessiterait une decision gameplay/UX. Ce n'est pas une
optimisation transparente.

### Projectiles et recherche de cible

**Faux comme priorite actuelle, juste comme limite future.** La recherche des
monstres par les armes passe par le spatial hash, pas par une liste globale.
Le serveur calcule encore le resultat autoritaire, mais P3 a deja retire les
transforms repliques et obtenu un gain reseau de `-94.3 %` et serveur de
`-78.2 %` sur le scenario isole.

Le rapport ne prend pas en compte que les runs sont solo : le pilote visuel
client est donc un choix de contrat, pas une dette immediate. Une arme future
doit entrer dans P3 seulement avec un benchmark propre, sans reintroduire une
replication continue par defaut.

### Aiguille de Leyde

**Juste techniquement, hors contrat gameplay si interprete comme un cap.**
L'impact evalue toutes les cibles de la zone puis applique les rebonds. C'est
exactement la regle declaree pour cette arme : toute cible dans la zone au
moment de l'impact est touchee. Un nombre maximal de cibles modifierait
silencieusement l'arme et serait donc incorrect sans nouvel arbitrage produit.

Le vrai angle mort est l'absence actuelle de benchmark zone a densite
representative. Il faudra isoler cette arme dans MetaBuildLab et une future
campagne d'armes, avec mesures par nombre de cibles et par nombre de rebonds.

### Envoi des statistiques au joueur

**Juste.** Chaque degat de monstre retenu par cooldown appelle un `FireClient`
de stats pour le joueur touche. Dans le contrat solo cela ne multiplie pas le
trafic entre joueurs, mais une horde au contact peut rendre la frequence
inutilement haute.

Cette piste est meilleure qu'un changement de LOD non mesure : un coalescing
local de stats par Heartbeat ou a 10-20 Hz conserverait la valeur autoritaire
et le feedback HUD. Il exige toutefois un smoke dommages/bouclier/popups pour
ne pas degrader la lisibilite des barres.

### XP transmis a tous les clients

**Juste techniquement, hors contrat solo actuel.** `XpService` utilise encore
`FireAllClients` pour l'attraction visuelle. Dans une run solo, il n'y a pas
d'observateur inutile. Si les runs deviennent cooperatives, il faudra decider
explicitement qui voit le collectable partir et remplacer cet envoi global par
une politique de visibilite. Ce n'est pas une urgence P2/P3.

### Presence dans les bulles de shrine

**Juste, a faible risque aujourd'hui.** Chaque Heartbeat, chaque shrine actif
teste les joueurs. Le cout est actuellement `O(shrines x joueurs)` avec un
seul joueur et peu de shrines. Un throttle pourrait diminuer le cout, mais il
change la latence de charge/annulation : le smoke de prompts et de charge est
donc bloquant avant toute modification.

### Logs Performance et generation procedurale

**Hors contrat pour les logs.** Le canal `Perf` est volontairement actif par
defaut pendant le chantier P0 a P12, a la demande produit. Le retirer
maintenant contredirait l'observabilite. Son cout est borne par throttling,
mais la construction des tables de contexte reste a mesurer si elle apparait
dans un profil. La bonne sortie future est un profil benchmark/Studio ou un
toggle de telemetrie, pas la suppression aveugle des mesures.

**Juste mais hors boucle de run pour la generation.** Les parcours descendants
proceduraux ont principalement lieu a la creation de map, derriere le loader.
Ils concernent la duree de generation et le pic de chargement, non le frame
time du combat. Une optimisation ne serait justifiee que par un benchmark de
generation de map reproductible.

## Hierarchie de travail recommandee

1. Mesurer avant de changer : cout de `sendStats`, collecte reelle et charge
   shrine en run canonique ; aucun changement pousse avant ces donnees.
2. Conserver P2 et P3 tels quels. Le rapport ne justifie ni une reecriture du
   spatial hash, ni un Octree, ni une replication projectile differente.
3. Reouvrir une sous-phase uniquement lorsqu'un cout est prouve : `P2.x`
   pour compteur alive et/ou scheduling, `P3.x` pour armes non projectile et
   multijoueur, ou une future phase collectables.
4. Ajouter un scenario zone Aiguille de Leyde avant d'en deduire une limite de
   cibles. La limite produit actuelle reste toutes les cibles dans la zone.

## Angles morts

- La campagne P0/P2/P3 est Studio local et ne remplace ni MicroProfiler, ni
  session publiee, ni multi-client.
- Les paliers 500/1 000 restent trop couteux pour la cible de jeu. Cela ne
  prouve pas qu'un element particulier du rapport est responsable ; P2 a
  seulement etabli la hierarchie actuelle : mouvement et separation avant
  ciblage et LOD.
- Le contrat solo rend certains envois globaux neutres. Il ne doit jamais etre
  extrapole sans reouverture explicite si le produit evolue vers le coop.

## Decision

**Defer.** Aucune recommandation du rapport ne justifie une modification
immediate sans nouvelle reference ciblee. Les deux pistes a forte valeur de
mesure sont le coalescing des statistiques et le benchmark de zone Aiguille de
Leyde. Elles sont distinctes et ne doivent pas etre fusionnees dans une passe
generique de performance.

