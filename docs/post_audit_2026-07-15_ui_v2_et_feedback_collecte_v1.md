# Post-audit - Fondation UI V2 et feedback de collecte V1

## 2026-07-15 10:23:50 +02:00 - Rattrapage documentaire apres les passes UI

### Nature du jalon

Ce document enregistre deux livrables realises pendant le rattrapage de l'UI :
la construction d'une base V2 isolee dans Studio et le feedback visuel de
collecte de pieces et de gemmes XP. Il ne declare pas la V2 comme interface
principale et ne remplace pas les documents de combat, de HUD ou de VFX deja
existants.

La preuve technique est posee. La preuve produit reste le Play Test manuel du
joueur, en particulier pour la lisibilite des popups en combat et la fidelite
visuelle de la V2 au kit de reference.

### Juste - Fondation UI V2 isolee dans Studio

- `StarterGui/MegaRobloxUIV2` a ete cree dans Explorer avec `Enabled = false`.
  Il ne remplace donc pas le HUD de run actuellement actif et ne perturbe pas
  les parties en cours.
- La composition V2 utilise un pack d'assets 2D reel importe dans Studio :
  panneaux, boutons, slots, barres, ornements et icones. Le board de reference
  contient les zones prevues pour le profil, les ressources, les actions hautes,
  la navigation, le choix de perks, les objets trouves, les quetes, la boutique,
  le recapitulatif, la mini-carte et les toasts.
- Le board reste intentionnellement statique et demonstratif. Les donnees de
  run ne sont pas encore branchees a cette V2 : le HUD actuel reste la source
  de verite visuelle pendant ce travail de validation.
- `UiVisualAssetsV2.luau` conserve les identifiants et les reglages de slicing
  associes au pack afin de conserver une trace cote Rojo des assets importes.

### Juste - Feedback serveur vers client pour les collectibles

- `CoinService` et `XpService` publient maintenant le RemoteEvent
  `PickupFeedback_Show` uniquement apres le calcul du montant reel attribue.
  Le client ne fournit aucune donnee de gain au serveur.
- Le payload est volontairement minimal : nature du gain, montant final et
  instant d'arrivee de l'animation d'attraction. La position du collectible,
  initialement envisagee, a ete retiree car elle n'etait pas utilisee et aurait
  augmente le trafic inutilement.
- `PickupFeedbackUI.client.luau` cree un layer local, affiche une confirmation
  au-dessus du joueur, puis la fait monter et disparaitre. Les pieces utilisent
  l'icone or existante et les gemmes affichent un marqueur XP violet.
- Les collectes simultanees d'une meme nature sont regroupees dans une fenetre
  courte de `0.12` seconde. Le total est conserve, tandis que le cap de sept
  popups actifs evite de saturer l'ecran lors du magnetisme.
- La popup est maintenant transparente, sans cadre ni fond. La lecture repose
  sur l'icone, le montant agrandi et le contour de texte, ce qui respecte son
  role de feedback transitoire plutot que de notification persistante.
- La sauvegarde DataStore des pieces est executee apres l'emission du feedback.
  Une latence de persistance ne peut donc plus retarder l'affichage d'un gain
  deja valide en memoire.

### Validation technique executee

- `rojo build -o $env:TEMP/MegaRoblox_PickupFeedback_TransparentCheck.rbxlx`
  termine avec succes.
- `git diff --check` ne remonte aucune erreur de contenu sur la passe de
  feedback. Les avertissements `LF -> CRLF` concernent le contexte Windows et
  ne signalent pas une anomalie Luau.
- La recherche ciblee confirme un seul contrat de RemoteEvent partage par les
  deux services de collecte et le controleur client.
- Aucun marqueur de conflit Git n'est present dans `src`.

### Smoke manuel canonique bloquant

1. Ramasser une seule piece : le popup or doit apparaitre a l'arrivee de la
   piece et le compteur doit augmenter du meme montant.
2. Ramasser une gemme XP simple puis une gemme fusionnee : le popup doit
   afficher la valeur finale, y compris le multiplicateur de gain d'XP actif.
3. Activer le magnetisme avec des pieces et des gemmes : les gains doivent etre
   regroupes sans flood d'etiquettes ni disparition de montant.
4. Rejouer ces cas avec une camera en mouvement et pendant un combat : les
   popups ne doivent pas masquer durablement le joueur, le HUD ni les choix de
   perks.
5. Activer temporairement `StarterGui/MegaRobloxUIV2`, puis verifier la V2 en
   16:9, fenetre compacte et mobile. Elle doit rester visuellement fidele au
   pack avant tout branchement gameplay.

### Angles morts et budget de complexite

- Juste : le gain reste entierement autoritaire cote serveur. Le popup n'est
  qu'une restitution client d'un evenement deja valide.
- Simplification : le feedback ne depend pas de `CombatUI.client.luau`, qui
  est deja un point de convergence du HUD. Un controleur local dedie limite le
  risque de regression sur les barres, topbar et recapitulatif existants.
- Contestable : suivre le joueur plutot que le collectible rend toujours la
  confirmation lisible mais ne reproduit pas un nombre flottant ancre dans le
  monde. Cette position privilegie la lecture dans une horde ; elle pourra etre
  ajustee apres observation reelle sans toucher aux gains.
- Angle mort : le regroupement par `0.12` seconde et le cap de sept popups sont
  des valeurs de V1. Leur adequation doit etre mesuree pendant un magnetisme
  dense et sur une machine moins performante.
- Angle mort : `MegaRobloxUIV2` vit actuellement dans Studio et n'est pas
  mappe par `default.project.json`. Sa strategie de versionnement reste a
  decider avant qu'elle devienne une interface de production. Le restant est
  trace dans `todo_2026-07-15_ui_v2_visual_integration.md`.

### Rollback conceptuel

Le rollback du feedback est court : supprimer `PickupFeedbackUI.client.luau`
et son config retire uniquement les confirmations visuelles. Les gains, les
compteurs, les pools et les animations d'attraction existantes continuent de
fonctionner. La V2 reste desactivee et peut etre retiree de Studio sans effet
sur l'interface legacy active.

## 2026-07-15 10:59:23 +02:00 - Surface lisse du terrain runtime

### Juste - Suppression de l'aspect baseplate du sol

L'inspection Studio de `ServerStorage/MapTemplates/ProceduralKit` a etabli que
`TopBasePlateform`, `BotBasePlateform` et `RampBasePlateform` ne portent ni
texture, ni `SurfaceAppearance`, ni `MaterialVariant`. Leur rendu en studs
provient uniquement des proprietes `TopSurface` et `BottomSurface` reglees sur
`Studs` dans les templates source.

`ProceduralMapService` applique maintenant, a chaque clone de terrain runtime,
un `SmoothPlastic` et des surfaces `Smooth`. Les palettes Verdant, Azure et
Ember restent inchangees : le changement retire l'aspect de baseplate sans
transformer le terrain en un nouveau biome texture ou en modifier les couleurs.

### Validation technique

- Un clone temporaire des trois pieces du kit a ete modifie dans Studio puis
  detruit : les trois acceptent `SmoothPlastic`, `TopSurface = Smooth` et
  `BottomSurface = Smooth`.
- `rojo build -o $env:TEMP/MegaRoblox_SmoothTerrain_Check.rbxlx` termine avec
  succes.
- `git diff --check` ne remonte aucune erreur de contenu sur cette passe.

### Angle mort et smoke manuel

- Simplification : il s'agit d'un rendu par couleur et surface lisse. Aucun
  materiau genere, texture externe ou asset n'est ajoute.
- Angle mort : cette passe ne modifie pas le template Studio lui-meme. Elle est
  appliquee au runtime, ce qui protege les sources du kit mais doit etre verifie
  apres une nouvelle generation de run.
- Smoke : lancer une run sur les chapitres vert, bleu et rouge; verifier que le
  sol, les plateformes et les rampes sont lisses, conservent leur palette et
  restent praticables pour le joueur et les monstres.

## 2026-07-15 11:15:15 +02:00 - Elimination de la plaque source runtime

### Juste - Une seule surface de sol par run

Le retour visuel a montre qu'une surface en studs restait visible a distance
malgre la conversion des clones generes en `SmoothPlastic`. Ce comportement est
coherent avec deux plaques presque coplanaires : la base runtime generee et la
plaque source clonee depuis le template. Une simple transparence ne constitue
pas une preuve assez forte que la surface historique ne participera plus au
rendu selon la distance camera.

`ProceduralMapService` retire maintenant la `Base3` source du clone de map
apres avoir cree `GeneratedBase/BaseTop` et `GeneratedBase/BaseBottom`.
`DestroySourceSurface = true` remplace donc l'ancien masquage. Les objets sous
`ServerStorage/MapTemplates` ne sont jamais modifies : seule leur copie de run
est concernee.

### Validation technique

- `rojo build -o $env:TEMP/MegaRoblox_RuntimeBaseRemoval_Check.rbxlx` termine
  avec succes.
- `git diff --check` ne remonte aucune erreur de contenu.
- La recherche ciblee ne trouve plus aucune reference au mode historique
  `HideSourceSurface`.

### Smoke manuel bloquant

1. Quitter la run actuellement generee, puis en lancer une nouvelle : une map
   deja construite conserve necessairement ses anciennes instances.
2. Alterner camera proche et eloignee sur le sol bas, sous les rampes et entre
   les plateformes : aucune surface a studs ne doit reapparaitre.
3. Verifier le deplacement du joueur, le raycast de surface, le spawn des
   monstres et les interactables sur la nouvelle base unique.

### Angle mort et rollback

- Simplification : la correction retire une instance runtime au lieu de tenter
  de rendre sa transparence et son ordre de rendu plus complexes.
- Angle mort : si une surface a studs subsiste apres une nouvelle run, elle ne
  peut plus provenir de `Base3`; il faudra alors identifier l'objet restant par
  son chemin runtime dans Explorer, plutot que changer a nouveau le materiau.
- Rollback : regler `DestroySourceSurface = false` reactive le masquage de
  compatibilite sans modifier les templates source.

## 2026-07-15 11:29:25 +02:00 - Source Lighting unique et profils de niveau

### Juste - L'ambiance n'a qu'un seul service source

Le symptome observe etait le suivant : l'ambiance auteur du lobby etait visible,
mais la variation d'ambiance attendue pendant une run ne l'etait pas clairement.
Il ne peut pas exister deux services Roblox `Lighting` en parallele : le service
est singleton. En revanche, plusieurs effets enfants peuvent coexister dans ce
service. L'ancien controleur pouvait selectionner un effet disponible trop tot
ou creer un fallback local avant la replication de l'effet auteur. Cette
coexistence rendait la source visuelle effective ambigue.

La passe corrige ce contrat dans `EnvironmentController.client.luau` :

- la premiere `Atmosphere` et le premier `SunRaysEffect` auteur disponibles
  sont captures comme sources de rendu ;
- leur etat initial ainsi que les proprietes globales de `Lighting` deviennent
  le baseline de lobby ;
- une run applique son profil directement sur cette source unique ;
- le retour lobby restaure exactement ce baseline ;
- un fallback local n'est cree qu'en absence totale de source et il est detruit
  si une source auteur arrive ensuite ;
- le log `Environment` indique desormais le niveau, le profil, la source
  d'atmosphere et la densite effectivement appliquee.

Cette passe ne modifie ni la map runtime, ni le `Lighting` serveur, ni les
preferences graphiques persistantes. Les effets decoratifs locaux restent
separes sous `Workspace/MegaRobloxClientEnvironment`.

### Validation statique

- `rojo build default.project.json -o MegaRoblox_EnvironmentLighting_SourceCheck.rbxlx` reussit ;
- `git diff --check` ne remonte pas d'erreur de contenu. Les seuls messages
  concernent les conversions de fin de ligne Windows deja presentes dans le
  worktree ;
- la recherche des ecritures de `Lighting` confirme que seul
  `EnvironmentController.client.luau` regle l'ambiance. `GraphicsController`
  ne regle que `GlobalShadows`.

### Smoke manuel canonique bloquant

1. Entrer dans le lobby : son brouillard et ses rayons auteurs restent visibles.
2. Lancer une run `Map_Test` : la console client doit emettre
   `Ambiance de niveau appliquee` avec `Profile=ForestVerdant`, la source
   `Lighting.Atmosphere` et une densite autour de `0.225` en qualite `Balanced`.
3. Changer temporairement la qualite graphique puis revenir a `Balanced` :
   l'ambiance varie sans creer une seconde `Atmosphere` dans `Lighting`.
4. Terminer la run et revenir au lobby : les valeurs du brouillard reviennent
   a celles de l'auteur, sans conserver la teinte forestiere.

### Classification et angles morts

- [Juste] le probleme n'est pas la creation d'un second service `Lighting`,
  mais la concurrence possible entre effets enfants dans son singleton.
- [Simplification] le lobby n'a plus de profil code parallele. Son rendu est
  celui que le projet a effectivement authorise dans Studio, ce qui evite deux
  sources de verite pour la meme ambiance.
- [Angle mort] `ChapterConfig` associe actuellement les trois chapitres a
  `Map_Test`. Les profils `Map_Test2` et `Map_Test3` ne seront donc jamais
  selectionnes tant que les vraies maps de ces niveaux ne seront pas rebranchees.
- [Angle mort] ce correctif est valide statiquement, pas encore par le smoke
  Play manuel. Une sortie visuelle stable dans le lobby ne prouve pas seule la
  bascule de profil en run.

### Budget de complexite et rollback

La passe ajoute des snapshots courts pour restaurer correctement le lobby, mais
retire la dualite entre un profil lobby code et l'ambiance auteur. Le gain est
une source de verite unique pour chaque effet. Le rollback conceptuel consiste
a restaurer `LobbyProfile`; il est volontairement deconseille, car il recreerait
un deuxieme contrat d'ambiance sans resoudre la course de replication.

## 2026-07-15 11:52:54 +02:00 - Feedback de gain et d'elimination V1

### Juste - Un seul canal, plusieurs gains valides

Le RemoteEvent `PickupFeedback_Show` et son controleur local existaient deja
pour les pieces et les gemmes XP. Ils acceptent maintenant cinq types visuels :
`Coin`, `Xp`, `Kill`, `ArcaneGem` et `Run`. La presentation reste sans cadre,
ancree au joueur, avec le meme mouvement vertical, la meme fusion temporelle et
le meme plafond que les feedbacks de collecte deja verifies.

- `MonsterService` envoie `Kill +1` uniquement apres que le serveur a credite
  le kill et les analytics de run ; l'icone de squelette et le montant sont rouges ;
- `ArcaneGemService.AwardArcaneGems` accepte maintenant un quatrieme parametre
  booleen `showFeedback`. Lorsqu'il vaut `true`, la gemme permanente est deja
  attribuee et persistable avant le popup cyan ;
- le type `Run` est present dans le client avec son placeholder textuel, mais
  aucun compteur ni aucun gain par pas n'est invente dans cette passe.

### Validation statique

- `rojo build default.project.json -o $env:TEMP/MegaRoblox_FeedbackKinds_Check.rbxlx`
  reussit ;
- `git diff --check` ne remonte pas d'erreur de contenu. Les avertissements
  concernent uniquement les conversions de fin de ligne Windows deja presentes
  dans le worktree ;
- le nouveau RemoteEvent est le meme que celui des pieces et de l'XP : aucun
  canal client-serveur supplementaire n'a ete introduit.

### Smoke manuel canonique bloquant

1. Tuer un monstre seul : une icone de squelette rouge `+1` doit apparaitre au-dessus du
   joueur, tandis que le compteur de kills augmente egalement.
2. Eliminer rapidement plusieurs monstres : le feedback peut devenir `+N`,
   mais ne doit ni flooder l'ecran ni retarder le loot XP/or.
3. Rejouer une collecte simple de piece et de gemme XP : leurs popups et leurs
   compteurs doivent rester identiques au comportement precedent.
4. Lorsqu'un futur drop appelle
   `AwardArcaneGems(player, montant, source, true)`, verifier que l'attribut
   `ArcaneGems` augmente avant l'apparition du popup cyan.

### Classification et angles morts

- [Juste] les kills et les gemmes arcaniques restent des decisions serveur ;
  le client ne peut ni demander ni modifier un montant.
- [Simplification] la reutilisation du RemoteEvent existant evite trois
  transports redondants et garde le plafond anti-flood deja en place.
- [Angle mort] aucune gemme arcanique ne drop encore dans le gameplay actuel.
  Le branchement est pret, mais le smoke de drop reel attend la future table de
  loot.
- [Angle mort] le score de course n'a ni definition, ni compteur, ni destination
  de fin de run. Ajouter un `+1` a chaque pas maintenant serait un faux gain et
  produirait du bruit visuel. Son type visuel reste pret sans declenchement.

### Budget de complexite et rollback

Cette passe ajoute deux emissions serveur tres courtes et etend un union type
client. Elle n'ajoute aucun service ni boucle de simulation. Le rollback est
local : retirer `Kill` et `ArcaneGem` du controleur puis leurs deux emissions
serveur laisse les gains, analytics et persistance intacts.

## 2026-07-15 12:35:37 +02:00 - Feedback de combat et score de course V1

### Perimetre livre

Le feedback visuel reste une consequence d'une decision serveur deja prise.
Le client ne peut ni demander un soin, ni creer un bouclier, ni augmenter le
score de course. Deux services etroits ont ete ajoutes :

- `GameplayFeedbackService` agrege pendant `0.12` seconde les confirmations
  serveur avant de les transmettre via le RemoteEvent existant
  `PickupFeedback_Show` ;
- `RunScoreService` lit la position repliquee du `HumanoidRootPart` uniquement
  pendant une run active. Il credite un point par stud horizontal, ignore les
  grands sauts de position (teleport) et reinitialise son echantillon pendant
  une pause.

Le score est affiche entre le prix du prochain coffre et `LVL` dans la top bar.
Il est conserve dans le recapitulatif et l'historique de la run sous
`ProgressionStats.RunScore`, mais ce n'est ni une monnaie, ni une progression
permanente.

### Sources de feedback

- regeneration de vie : `HealRegen` ;
- soin instantane : `HealInstant` ;
- vol de vie sur impact : `LifeStealHit` ;
- vol de vie issu d'un tick de poison : `LifeStealDot` ;
- augmentation de PV maximum : `MaxHealth` ;
- gain de bouclier de perk : `Shield` ;
- coup critique : `Critical`, seulement apres degats reels ;
- poison applique : `Poison`, seulement apres application reussie de l'effet ;
- course : `Run`, publie par petits lots pour eviter un popup a chaque frame.

`PerkService` expose maintenant `ApplyInstantHeal` et `GrantMaxHealth` pour
les futures sources de gameplay. Ces fonctions restent serveur et mettent a
jour le HUD de statistiques avant le feedback visuel.

### Routage visuel

Les routes sont intentionnellement regroupees par destination plutot que par
une nouvelle famille de GUI :

- XP, PV, bouclier, regeneration et vol de vie partent sous le joueur, rejoignent
  la barre correspondante du panneau inferieur puis la font pulser ;
- pieces, kills, gemmes arcaniques et score de course partent a gauche du
  joueur, rejoignent leur valeur de top bar puis la font pulser ;
- critiques et poison restent a droite du joueur, montent puis disparaissent.
  Ils n'ont volontairement aucune destination HUD afin de ne pas melanger
  information de combat et ressource cumulee.

L'icone definitive du score de course attend encore son import Roblox. Le HUD
et le popup dessinent temporairement deux empreintes cyan par code, afin de
garder le score lisible sans asset manquant.

### Validation statique

- `rojo build default.project.json -o $env:TEMP/MegaRoblox_FeedbackAndRunScore_Check.rbxlx`
  reussit ;
- `git diff --check` ne remonte aucune erreur de contenu. Les avertissements
  de fin de ligne Windows existaient deja dans le worktree ;
- la recherche des appels confirme que `CalculateOutgoingDamage` ne change de
  contrat que pour `WeaponService`, et que le vol de vie est appele par le hit
  Fireball et par le tick de poison ;
- aucune marque de conflit Git n'est presente dans les sources.

### Smoke manuel canonique bloquant

1. Lancer une run et marcher une dizaine de studs : la valeur de course doit
   monter dans la top bar, puis un `+N` cyan doit partir de la gauche du joueur
   vers cette valeur et la faire pulser.
2. Mettre la run en pause, se deplacer puis reprendre : aucun point ne doit etre
   gagne pendant la pause ni credite en rafale a la reprise.
3. Tuer un monstre critique : `CRIT N` doit apparaitre a droite du joueur sans
   voler vers un HUD. Rejouer un hit normal : aucun popup critique ne doit etre
   produit.
4. Appliquer le poison avec Camembert : `POISON` apparait a droite du joueur.
   Si le joueur a du vol de vie et des PV manquants, les soins de tick partent
   ensuite sous le joueur vers la barre de PV.
5. Choisir un perk de bouclier : le gain part sous le joueur vers la barre de
   bouclier et cette barre pulse. Rejouer une collecte XP puis de piece pour
   verifier les destinations inferieure et superieure deja connues.
6. Tester une regeneration de vie sur un personnage blesse : le feedback est
   groupe, sans flood de fractions de PV. Tester une source future qui appelle
   `ApplyInstantHeal` puis `GrantMaxHealth` : les libelles doivent rester
   distincts (`SOIN` et `PV MAX`).
7. Quitter une run juste apres un gain : aucun popup mis en attente ne doit
   apparaitre ensuite dans le lobby.

### Classification et angles morts

- [Juste] le serveur demeure l'unique source des montants. Le RemoteEvent ne
  transporte que des confirmations vers le proprietaire du gain.
- [Simplification] un seul canal de feedback et trois routes visuelles couvrent
  les nouveaux cas. Creer un RemoteEvent par type de popup aurait augmente la
  surface de synchronisation sans gain produit.
- [Angle mort] le gameplay actuel ne fournit pas encore de soin instantane ni
  de gain de PV maximum. Leurs APIs et leurs feedbacks sont prets, mais le smoke
  reel attend un futur objet, coffre ou perk qui les appelle.
- [Angle mort] le score de course est une premiere definition volontairement
  simple. La persistance en historique permet de l'observer, mais sa valeur
  metier (classement, recompense ou objectif de chapitre) reste a decider avant
  toute recompense permanente.
- [Angle mort] l'icone bitmap definitive du score de course n'a pas encore
  d'identifiant Roblox. Le fallback code ne remplace pas un asset final de DA.

### Budget de complexite et rollback

La passe ajoute deux petites boucles serveur cadencees : l'une agrege des
feedbacks, l'autre echantillonne une position toutes les `0.15` seconde. Elle
reduit en contrepartie les emissions de soins et de course qui auraient pu
flooder le client. Le rollback conceptuel est direct : ne plus demarrer
`RunScoreService` et `GameplayFeedbackService`, puis retirer les routes
associees du controleur local. Les regles de combat, les degats et les gains
serveur restent independants de cette presentation.

## 2026-07-15 13:09:51 +02:00 - Redressement popup de collecte

### Incident et correction

Le smoke canonique de collecte etait casse : les pieces et les gemmes XP etaient
bien attribuees par le serveur, mais aucun popup client ne pouvait apparaitre.
Le log de Play Test a etabli la cause exacte :

`PickupFeedbackUI:470: Expected identifier when parsing expression, got '['`

`PickupFeedbackUI.client.luau` tentait d'indexer directement une table
litterale. Luau refuse cette forme dans ce contexte, ce qui empechait le
`LocalScript` entier de se compiler et donc d'enregistrer son listener sur
`PickupFeedback_Show`. La correspondance entre les cibles HUD est maintenant
une table statique `hudTargetNames`, puis est lue par indexation classique.

La passe de diagnostic avait aussi ajoute des appels a `DebugLog` sans import
local. Cet import est desormais explicite, ce qui evite un second echec runtime
une fois le script compile.

### Validation

- `rojo build default.project.json` reussit apres la correction ;
- la recherche de la forme invalide `}[` ne trouve plus aucun resultat dans
  `PickupFeedbackUI.client.luau` ;
- le log confirme que les collectes serveur de pieces et de gemmes XP avaient
  toujours lieu avant la correction ;
- smoke manuel confirme par le joueur : les popups de collecte sont revenus.

### Classification et angles morts

- [Juste] le probleme ne venait ni de `CoinService` ni de `XpService` : les
  attributions et les animations de collecte client etaient deja visibles dans
  le log. La rupture etait strictement dans la compilation du controleur GUI.
- [Simplification] le mapping des cibles HUD est construit une seule fois au
  lieu de recreer une table a chaque frame de rendu.
- [Angle mort] ce smoke valide seulement le flux piece et XP. Les routes de
  soin, bouclier, critique, poison, gemme arcanique et score de course doivent
  etre validees chacune avec une source de gameplay reelle avant d'etre
  considerees comme tenues.

## 2026-07-15 17:42:47 +02:00 - Contrat de design du RunLayoutDraft V2

### Perimetre verrouille

Le contrat de design appartient exclusivement a
`StarterGui/MegaRobloxUIV_RunLayoutDraft`. Il ne remplace pas le HUD runtime
actuel et ne lui applique aucun style. Cette exclusion est explicite dans le
contrat avec le scope `MegaRobloxUIV_RunLayoutDraft`, la policy
`DoNotBindCurrentHud` et l'attribut `RuntimeHudExcluded`.

### Structure du contrat

`DesignContract` passe en version 2 et separe maintenant les tokens par role :

- `Typography` : famille Montserrat, couleurs et graisses semantiques ;
- `Surfaces` : variantes centrale et compacte ;
- `GlassCards` : verre, matiere, bordures et inspection ;
- `Buttons` : primaire, secondaire, confirmation et annulation ;
- `Rarities` : commun, rare, epique et legendaire ;
- `Motion` : hover, retour, inclinaison et aura idle ;
- `Layouts` : contrat du layout central responsive valide ;
- `Policies` : isolation du brouillon et preservation du layout.

Les composants existants portent des roles explicites comme
`Surface.Central`, `Surface.Compact`, `Button.Primary`, `Card.Glass` et
`Layout.CentralChoice`. Le controleur des cartes ne maintient plus sa propre
table de raretes : il lit les valeurs de `Rarities`, `GlassCards` et `Motion`.

### Validation technique

- compilation statique de `PerkHoverController` reussie via `loadstring` ;
- huit sections contractuelles et quatre raretes presentes ;
- trois cartes liees a la version 2 du contrat ;
- position et taille du layout central strictement preservees ;
- aucune execution Play lancee par l'agent.

### Classification, complexite et angles morts

- [Juste] la DA glassmorphism n'est plus seulement un assemblage visuel : ses
  tokens et ses roles sont inspectables et reutilisables dans le brouillon.
- [Simplification] les constantes de hover dupliquees dans le controleur ont
  ete remplacees par une lecture du contrat. La passe deplace puis reduit la
  complexite au lieu d'ajouter un second moteur de theme.
- [Angle mort] les objets V2 sont actuellement stockes dans le fichier Studio,
  hors arborescence Rojo. Leur sauvegarde depend donc du `.rbxlx` tant qu'une
  strategie de versionnement n'est pas choisie.
- [Angle mort] les roles rendent les futurs panneaux et boutons deterministes,
  mais aucun moteur generique n'applique automatiquement tout le contrat. Cette
  automatisation ne devra etre ajoutee que si plusieurs composants reels la
  justifient.
- [Angle mort] la validation est structurelle. Le ressenti du glass, du hover
  et de la matiere reste soumis au prochain Play Test manuel du joueur.

Le rollback conceptuel consiste a repasser le contrat en version 1 et a
restaurer les constantes locales de rarete dans `PerkHoverController`. Le HUD
runtime actuel n'est pas concerne par ce rollback.

## 2026-07-15 18:02:30 +02:00 - Matiere glass et identite PowerAscension

### Evolution du contrat V2

Le contrat de design du seul `MegaRobloxUIV_RunLayoutDraft` decrit maintenant
les comportements de matiere des cartes par rarete : transparence idle,
renforcement hover, variation des motifs et parallaxe liee au pointeur. Les
motifs existants restent distincts : fibres communes, panneaux cristallins
rares, facettes epiques et rayons legendaires prepares.

Une section `CentralPanels/PerkChoice` formalise la premiere specialisation de
panneau central avec le theme `PowerAscension` :

- matiere de surface `ForgedArcaneRim` ;
- matiere d'InnerGlass `AscendingPower` ;
- derive verticale idle lente ;
- pulse central tres transparent ;
- mouvement de gradient borne et sans boucle par frame.

Cette separation permet aux futurs panneaux centraux de reutiliser le contrat
de surface et de verre tout en declarant leur propre theme semantique, plutot
que de dupliquer aveuglement le fond du choix de perks.

### Implementation et validation

`PerkHoverController` pilote maintenant le contraste et la parallaxe des
motifs au hover et au mouvement de la souris. Les animations du panneau central
utilisent uniquement des tweens longs et reversibles. Les couches decoratives
restent sous le contenu du panneau.

- compilation statique Luau reussie ;
- position et taille du layout central preservees ;
- 17 motifs repartis sur les trois cartes de test ;
- matiere presente sur la Surface et l'InnerGlass du panneau ;
- aucune reference `RenderStepped` ;
- inspection visuelle effectuee en mode Edition, sans lancer Play ;
- aucun changement apporte au HUD runtime actuel.

### Classification, budget et angles morts

- [Juste] la matiere est plus visible sans remplacer les descriptions ni les
  assets de perks comme signal principal.
- [Simplification] une seule couche `PatternCanvas` par carte fournit le
  mouvement de matiere. Animer chaque forme avec une boucle autonome aurait
  augmente le cout et rendu le mouvement incoherent.
- [Juste] le panneau de perks possede une identite propre de montee en puissance
  tout en heritant des primitives communes du contrat glass.
- [Angle mort] le screenshot Edition ne montre pas la cadence, le hover ni le
  confort apres plusieurs secondes. Le Play Test manuel reste le proof of done
  visuel bloquant.
- [Angle mort] la reduction de mouvement est declaree dans le contrat mais n'est
  pas encore branchee a une preference d'accessibilite du kit de dev.

La passe ajoute de la complexite visuelle locale mais reduit la duplication des
futures variantes grace au theme `CentralPanel.PerkChoice`. Le rollback est
borne : retirer `PerkAscensionRim`, `PerkAscensionMaterial` et les quatre tokens
de matiere par rarete, puis restaurer le controleur precedent. Le HUD runtime
reste hors de ce chemin.
