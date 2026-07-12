# Post-audit - Runs, maps et chapitres V1

## 2026-07-13 00:00:27 +02:00 - Cloture de la passe structurelle

### Perimetre

Cette passe transforme le lancement de combat en cycle de run explicite. Elle couvre les trois templates initiaux `Map_test`, `Map_test2` et `Map_test3`, la progression permanente des chapitres, la seed de generation, l'identite persistante de run et la destruction du runtime.

La generation procedurale des formes de terrain, la reprise exacte d'une run apres reconnexion et l'ecran final de selection de chapitre ne font pas partie de cette V1.

### Architecture retenue

- `ChapterConfig` decrit les chapitres et leurs templates sans contenir de logique serveur.
- `ChapterProgressService` est l'autorite permanente pour les chapitres termines, debloques et selectionnes.
- `RunSessionService` possede le cycle `Creating -> Generating -> Active -> Saving -> Destroyed`.
- `RunMapService` clone une map depuis `ServerStorage/MapTemplates`, publie le contexte de surface puis detruit la map en fin de run.
- `RunWorldService` garantit l'ordre de generation `portail -> shrines -> coffres -> totems -> jarres` avant le demarrage du combat.
- `RunStateService.RunStarted` n'est emis qu'une fois la map et les interactables disponibles.
- `WorldSpawnService` limite ses raycasts a la map active, afin d'exclure le lobby et les autres objets de `Workspace`.

### Contrats de donnees

La progression permanente utilise `MegaRobloxChapters_v1` :

- `HighestUnlockedChapter` ;
- `CompletedChapters` ;
- selection courante publiee par attribut joueur.

Les sessions utilisent `MegaRobloxRuns_v1` :

- `RunId` genere par GUID ;
- `Seed` serveur ;
- `UserId`, `ChapterId` et `MapId` ;
- statut de cycle, resultat, dates et validation du chapitre ;
- historique borne aux 20 dernieres runs.

Une run interrompue n'est pas restauree en V1. Elle est classee `Abandoned` lors de la prochaine arrivee sans donnees de teleport. Ce choix evite une fausse reprise qui oublierait les monstres, le loot, les perks, les coffres et la position du joueur.

### Regles de progression

- Le chapitre 1 est disponible par defaut.
- La validation du boss du chapitre 1 debloque le chapitre 2.
- La validation du boss du chapitre 2 debloque le chapitre 3.
- Le serveur refuse toujours un chapitre verrouille, y compris si le client envoie une selection invalide.
- `Chapter_GetState` expose l'etat en lecture et `Chapter_Select` demande une selection serveur pour la future interface de niveau.

### Rangement Studio attendu

```text
ServerStorage
└─ MapTemplates
   ├─ Map_test
   ├─ Map_test2
   └─ Map_test3
```

Chaque template doit contenir un point d'arrivee nomme `TeleportPart1`. Un `SpawnLocation` enfant sert de fallback, mais le nom explicite reste recommande. La plaque du lobby `TeleportPart2` peut recevoir un attribut numerique `ChapterId`; sans cet attribut, le chapitre selectionne du joueur est utilise.

Les scripts inclus dans les templates de map sont desactives lors du clonage. La logique de gameplay reste sous l'autorite des services Rojo.

### Budget de complexite

La passe ajoute quatre proprietaires specialises et un orchestrateur. Elle reduit en contrepartie la complexite implicite : les services d'interactables ne generent plus arbitrairement leur contenu au demarrage, le teleporte ne decide plus seul qu'une run existe, et le lobby ne peut plus etre pris pour une surface de run.

### Proof of done technique

- `rojo build -o TestRoblox.rbxlx` : succes.
- analyse locale du graphe des `require(script.Parent...)` : aucun cycle detecte.
- `git diff --check` : aucune erreur de patch, uniquement les avertissements CRLF existants.
- recherche des marqueurs de conflit exacts : aucun marqueur dans `src`.

### Smoke manuel canonique bloquant

Le chantier n'est pas declare valide produit avant ce smoke Studio :

1. Au lobby, `MapRuntime` et tous les dossiers d'interactables runtime sont vides.
2. Toucher `TeleportPart2` genere `Map_test`, puis les interactables, puis teleporte le joueur sur `TeleportPart1`.
3. Les monstres et l'arme automatique ne demarrent qu'apres cette generation.
4. Une mort detruit la map et remet les statistiques de run a zero au lobby.
5. Vaincre le boss du chapitre 1 rend le chapitre 2 disponible apres reconnexion.
6. Une demande du chapitre 3 avant validation du chapitre 2 est refusee cote serveur.

### Angles morts et suite conseillee

- ◐ La reprise exacte d'une run interrompue demanderait un snapshot de tous les systemes de combat ; elle reste volontairement absente.
- ◐ Le serveur suppose une seule map active, coherent avec la run solo reservee. Plusieurs runs dans un meme serveur demanderaient des contextes spatiaux par joueur.
- ◐ La seed couvre les placements et les tirages des coffres/jarres de cette V1, mais pas encore tous les futurs systemes aleatoires.
- ~ Une interface de selection de chapitre doit consommer `Chapter_GetState` et `Chapter_Select` ; la construire maintenant melangerait ce chantier serveur avec un chantier UX non encore cadre.
- ~ Une future generation procedurale devra produire le meme contrat de sortie qu'un template : une racine de map, des surfaces valides et un point `TeleportPart1`.

## 2026-07-13 00:04:42 +02:00 - Correction de sortie sans sol runtime

La destruction de la map intervient desormais avec un rechargement du personnage sur le `SpawnLocation` du lobby avant l'affichage du recapitulatif pour les sorties autres que la mort. Cette correction evite qu'un joueur vivant tombe dans le vide pendant l'ecran de score apres `VictoryExit`.

## 2026-07-13 00:21:23 +02:00 - Suppression de la dependance obligatoire a TeleportPart2

Le smoke lobby a revele un defaut du rail simple : si `TeleportPart2` etait range dans le modele de map, son deplacement vers `ServerStorage/MapTemplates` supprimait egalement le seul declencheur de run du lobby.

La correction remplace ce point d'entree obligatoire par un contrat explicite :

- `RunLauncher.client.luau` affiche les chapitres disponibles, termines et verrouilles dans le lobby ;
- `Run_StartRequest` transmet uniquement l'identifiant du chapitre demande ;
- `ChapterProgressService` valide la selection et le deverrouillage ;
- `RunTeleportService` conserve l'autorite sur le cooldown, la creation de session et le teleport ;
- `TeleportPart2` reste supporte comme declencheur physique facultatif, mais son absence n'empeche plus une run.

Le budget de complexite reste borne : aucun second chemin de creation de run n'a ete ajoute. Le GUI et la plaque facultative convergent tous deux vers `RunTeleportService.StartSoloRun`.

Validation technique de la correction :

- `rojo build -o TestRoblox.rbxlx` : succes ;
- aucun cycle de `require(script.Parent...)` ;
- aucun marqueur de conflit exact dans `src` ou `docs` ;
- `git diff --check` sans erreur, hors avertissements CRLF connus.

Le proof of done produit exige encore un Play Test : ouvrir le lanceur au lobby, selectionner le chapitre 1, constater la generation de `Map_test`, puis verifier que le bouton disparait lorsque `IsRunActive` devient vrai.

## 2026-07-13 00:27:03 +02:00 - Alignement des noms de templates Studio

Le Play Test a revele une erreur de contrat de nommage : la configuration cherchait `Map_test`, `Map_test2` et `Map_test3`, alors que les trois modeles ranges dans `ServerStorage/MapTemplates` sont nommes `Map_Test`, `Map_Test2` et `Map_Test3`.

`ChapterConfig` utilise maintenant les noms reels des templates Studio. Les noms d'instances Roblox etant sensibles a la casse et aux caracteres, ce contrat doit rester identique entre le code et l'Explorer.

## 2026-07-13 00:40:02 +02:00 - Redressement spawn elite/boss et prompts camera

Le log `Spawn monstre impossible` avec `HasTemplate=true` et `IsElite=true` confirmait que le template `Monster1_Elite` etait correctement trouve, mais que la recherche de sol retournait `nil`. Les elites et le boss utilisaient une recherche de surface plus stricte que `Monster1`.

Le spawn elite/boss accepte maintenant les surfaces horizontales sans rejeter leur nom, puis applique un fallback de raycast direct si la recherche stricte ne trouve rien. Le fallback exclut les dossiers runtime afin de ne pas poser une entite sur une shrine, un portail ou un collectible.

Le rendu des prompts custom utilise aussi une distance visuelle de 300 studs. La distance effective de l'interaction n'est pas modifiee : un joueur doit toujours etre proche pour presser `E`, mais une camera reculee ne masque plus le prompt alors que le joueur est deja dans cette distance.

Validation technique : `rojo build -o TestRoblox.rbxlx` reussit. Le smoke Play Test doit verifier un pack elite complet et l'apparition du boss apres activation du portail.

## 2026-07-13 00:41:38 +02:00 - Diagnostic explicite d'activation du portail

Le portail journalise maintenant chaque pression de prompt avec le resultat de `BossService.TryStartBoss`. Les raisons attendues sont notamment `RunInactive`, `CombatPaused`, `BossAlreadyActive` et `PortalPositionMissing`.

Le log de spawn monstre distingue aussi explicitement `TemplateMissing` et `SurfaceMissing`. Cette instrumentation ne modifie pas les regles de combat ; elle rend le prochain retour Play Test directement exploitable si le boss ne se genere toujours pas.

## 2026-07-13 00:53:01 +02:00 - Points d'arrivee par chapitre

Le chapitre 2 utilise le point d'arrivee existant `TeleportPart3`, tandis que le chapitre 1 utilise `TeleportPart1`. `RunMapService` recherche d'abord le nom configure pour le chapitre courant.

En absence de nom configure, le service accepte un unique descendant nomme `TeleportPart*`, puis un `SpawnLocation` enfant. Plusieurs candidats non configures restent volontairement ambigus et sont refuses : une teleportation arbitraire serait un mauvais comportement produit.
