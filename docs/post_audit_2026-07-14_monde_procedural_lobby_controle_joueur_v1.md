# Post-audit - Monde procedural, lobby runtime et controle joueur V1

## 2026-07-14 21:19:48 +02:00 - Consolidation depuis le loader de run

### Nature de ce document

Ce document fait suite a `post_audit_2026-07-14_run_loading_batched_generation_v1.md`.
Il ne reecrit pas ce precedent jalon : le loader reste le contrat qui masque la
construction de la run. Cette passe documente ce qui a ete ajoute apres lui pour
construire le relief, placer le contenu sur des surfaces jouables, restaurer le
lobby et fiabiliser le controle local du joueur.

Le document decrit l'etat implemente au moment de son ecriture. Il ne pretend pas
valider tous les seeds ni toutes les configurations Studio : les observations de
Play Test confirmees sont separees des validations statiques.

### Juste - Monde de run procedural implemente

- `ProceduralMapService` construit maintenant le relief avant `RunWorldService`.
  Il clone les elements du kit depuis `ServerStorage/MapTemplates/ProceduralKit`
  et conserve une compatibilite temporaire avec `Workspace/Kit_Stud`, migree avec
  un warning explicite.
- La generation cree une base runtime, des sommets `Top`, des volumes `Bottom`
  qui rejoignent le sol, des rampes et des liaisons de terrain. Les instances
  runtime sont separees dans `GeneratedTerrain` et `GeneratedDecor`.
- Le catalogue compte dix-huit layouts ponderes. Leurs rotations sont limitees
  aux quatre directions cardinales. Les rampes reprennent la largeur de la
  plateforme connectee et les volumes ne sont pas laisses flottants.
- Les limites de la V1 sont configurees et non codees en dur : inset jouable de
  12 studs, jusqu'a 18 layouts, 56 plateformes, cible de couverture de 38 %, et
  hauteur maximale de 180 studs. La base est legerement abaissee par rapport a
  la version precedente (`ElevationOffset = -5`).
- Les decorations physiques du kit sont generees avec le relief par lots. Elles
  restent decoratives : elles n'entrent pas dans les decisions de combat.

### Juste - Variantes de chapitre sans dupliquer les maps

- Les trois chapitres partent maintenant de `Map_Test` et de son point d'arrivee
  `TeleportPart1`. La structure de la map reste donc commune et le relief est
  reconstruit a chaque run.
- `ChapterConfig` choisit un theme de terrain par chapitre : `Verdant`, `Azure`
  et `Ember`. Ces themes changent uniquement les palettes herbe, terre et rampe.
  Ils ne pretendent pas encore etre trois biomes complets avec leurs propres
  assets ou leurs propres regles de generation.
- Cette direction respecte la demande de reutiliser une meme base de niveau tout
  en gardant des variations lisibles par chapitre, sans multiplier les templates
  de map a maintenir.

### Juste - Contrat de surface partage pour le contenu runtime

- `WorldSpawnService` expose maintenant les bornes jouables actives et les
  recherches de surface a une coordonnee ou dans la zone jouable. Il distingue
  explicitement les surfaces de jeu des `Bottom`, des murs de limite et des
  pieces marquees pour etre ignorees.
- Le portail, les shrines, les coffres, les jarres et les totems utilisent ces
  recherches plutot qu'une hauteur fixe. Ils acceptent les sommets generes et
  sont exclus des volumes de terre et des rampes par defaut.
- `PortalService` ajoute un fallback de placement, une mise au sol calculee sur
  la boite du modele et une zone de degagement autour du portail. La protection
  ne bloque pas pour autant une position valide sur le sol ou sur une plateforme.
- Tous ces services conservent la generation par lots introduite par le loader.
  Le relief est maintenant termine avant leur generation, afin qu'ils puissent
  utiliser sa geometrie comme surface de reference.

### Juste - Combat adapte au relief sans physique de horde

- Les monstres restent cinematiques. Ils n'utilisent pas la gravite ni les
  collisions Roblox de chaque mesh, ce qui evite de transformer une horde en
  cout de physique massif.
- `MonsterService` echantillonne le sol sous le monstre, recale sa hauteur,
  conserve une grille spatiale et regarde les barrieres de terrain devant lui.
  La rotation et le mouvement sont calcules depuis ce meme etat plutot que par
  une physique non controlee.
- Le spawn normal attend toujours que le joueur soit pose, utilise un anneau
  limite a la zone jouable et peut employer un fallback lorsqu'un rayon sort de
  la surface de la map. Les vagues sont demandees par paquets et une masse
  intacte, hors champ, peut etre recyclee devant le joueur au lieu de creer de
  nouvelles instances.
- Les seuils actuels de simulation sont `115 / 150 / 190` studs. Les ennemis
  proches sont mis a jour a cadence complete, les autres a cadence reduite ou
  sont retires au-dela de la distance de despawn. Le visuel proche reste aligne
  au serveur : `MonsterSimulationHz = 0` conserve le Heartbeat pour ce cas.

### Juste - Lobby runtime et cycle de niveau

- `LobbyWorldService` clone `ServerStorage/LobbyTemplates/LobbyMap` dans
  `Workspace/LobbyRuntime` pour les joueurs qui ne sont pas dans une run. Le
  lobby source ne reste donc plus comme une map active dans `Workspace`.
- Une run conserve la distinction deja introduite par `RunSessionService` : map
  runtime, relief, contenu runtime, puis combat. Le retour hors run remet le
  joueur sur le point `LobbySpawn` ou un `SpawnLocation` de secours.
- En Studio, le lobby peut etre masque pendant une run afin de ne pas polluer la
  scene de test. Ce masquage est une commodite locale de Studio, pas une
  simulation de plusieurs instances publiques reliees entre elles.

### Juste - Interface de reperage et ambiance locale

- `MiniMapUI.client.luau` affiche uniquement des reperes proches du joueur
  (`VisibleRadius = 135`) : portail, shrines, coffre non ouvert, jarre intacte
  et totem non active. Elle ne dessine volontairement ni le relief ni toute la
  carte, ce qui reste conforme a son role de repere court terme.
- La mini-carte applique une cadence limitee, un scale responsif et un padding
  borne. Le correctif evite notamment le `math.clamp` invalide observe lorsque
  la zone de rendu est trop petite.
- `EnvironmentController.client.luau` applique des profils locaux de lobby et
  de niveau, reutilise les effets `Lighting` MegaRoblox existants et cree au
  besoin des motes locales. Les profils sont lies au niveau (`Map_Test`,
  `Map_Test2`, `Map_Test3`), pas directement au chapitre.
- Les preferences graphiques ne modifient pas les instances decoratives de la
  map. Elles pilotent les couches creees par les controleurs MegaRoblox.

### Juste - Controle joueur et sensation de base

- `PlayerController.client.luau` reutilise les controles Roblox standards au
  lieu de les remplacer. Il les desactive pendant le chargement, les pauses de
  combat et la reapparition, puis les restaure dans le lobby et pendant une run.
- Le serveur publie aussi `IsCombatPaused` comme attribut joueur. Le client ne
  depend donc pas uniquement du RemoteEvent et ne manque pas l'etat si celui-ci
  a ete emis avant la connexion locale.
- La camera n'est retablie que lorsque sa cible est absente et qu'elle est en
  mode `Custom`; une future camera cinematographique `Scriptable` n'est pas
  ecrasee.
- Le socle de mouvement est centralise dans `CombatConfig` : marche a `15`,
  `JumpPower` a `55` et `JumpHeight` a `8`. `PerkService` et
  `JumpBonusService` reutilisent ce socle, ce qui evite que perks, objets ou
  bonus de saut repartent de valeurs historiques differentes.

### Validation recue

#### Validation statique

- Plusieurs builds Rojo successifs ont reussi pendant cette passe, y compris
  apres l'ajout du relief, de la mini-carte, de l'environnement et du
  controleur joueur.
- `git diff --check` ne remonte pas d'erreur de contenu. Git signale seulement
  la conversion potentielle `LF -> CRLF` sur les fichiers Luau Windows.
- Les services ajoutes restent separes par responsabilite : generation du
  relief, surfaces, contenu de run, lobby, environnement client et controle
  client. Aucun ne devient un nouveau point d'entree universel.

#### Smoke manuel observe par le joueur

- Le loader masque bien la generation de la run avant le debut du combat.
- Le portail a d'abord ete observe en l'air, puis a ete observe pose au sol
  apres correction du placement et du pivot.
- Le relief genere, les reperes mini-carte locaux et la mise en place des
  plateformes sont visibles dans les captures de Play Test fournies.

### Angle mort - Smoke bloquant a maintenir

- La navigation des monstres n'est pas du pathfinding. Le suivi de sol et
  l'evitement avant raycast rendent les formes actuelles praticables, mais un
  nouveau layout tres ferme peut encore coincer une masse ou creer une poursuite
  peu naturelle. Le cas canonique a rejouer est : sol, sommet, rampe et liaison
  de terrain, avec un monstre qui rejoint le joueur sans traverser le volume.
- La couverture de relief est une cible et non une garantie geometrique. Si les
  emprises disponibles deviennent trop petites, le service plafonne la
  couverture et journalise ce choix. Il ne doit pas remplir la map au prix de
  sorties de bord ou de plateformes inaccessibles.
- Le portail et les interactables doivent etre verifies sur plusieurs seeds :
  aucune apparition dans un `Bottom`, sous la map, sur une rampe, ni dans une
  zone de depart qui empeche la lecture du joueur.
- La V1 d'ambiance est programmatique et locale. Son equilibre visuel reste a
  calibrer en Play Test; les plugins Atmosphere Pro et VFX Studio ne constituent
  pas encore une dependance runtime du projet.
- Le comportement de lobby multi-joueur et de run solo reservee doit encore
  etre smoke teste avec au moins deux joueurs. La separation du contenu runtime
  est en place, mais un test Studio local ne prouve pas la topologie de
  production.
- Les nouvelles valeurs de controle joueur doivent etre ressenties en Play Test
  sur un saut simple, un saut depuis une plateforme et une pause. Cette passe ne
  declare pas encore l'equilibrage de mouvement termine.

### Budget de complexite et rollback conceptuel

Simplification : cette passe ajoute plusieurs services, donc de la complexite. Le gain produit
est concret : la map et son contenu partagent enfin une definition de surface et
un ordre de generation. Pour eviter une couche centrale fragile, chaque domaine
reste isole par son propre config et service.

Le rollback conceptuel est court : `ProceduralMapConfig.Enabled = false` permet
de conserver la base map source, tandis que le loader et `RunWorldService`
continuent d'exister. Le lobby runtime et le controle local ne dependent pas du
relief procedural pour fonctionner.

### Suite recommandee, sans ouvrir un nouveau chantier automatiquement

1. Rejouer le smoke canonique terrain sur plusieurs seeds : arrivee, portail,
   shrine, coffre, totem, monstre et sortie de run.
2. Ajuster les poids de layouts et les plafonds de couverture a partir des
   captures reelles, pas d'une simple cible numerique.
3. Stabiliser le ressenti du controle joueur avant d'ajouter de nouvelles
   mecaniques de mouvement ou de nouveaux biomes.
