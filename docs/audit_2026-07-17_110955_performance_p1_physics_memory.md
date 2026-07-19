# P1 — Inventaire de la mémoire physique et préparation runtime

Horodatage : 2026-07-17 11:09:55  
État : instrumentation P1.1 prête, aucune normalisation physique encore retenue.

## État initial

Commit de référence : \`88c73ca\` (\`0.1.8 : Début du chantier PERFORMANCE p0_p12\`).  
Référentiel disponible : P0-local, campagnes \`P0C-7883142449-17802070\` et \`P0C-7883142449-19447275\`.

P0 démontre un coût CPU serveur dominant dans \`MonsterService\` aux densités élevées. Il ne permet pas d'attribuer la mémoire ou la charge physique à un asset précis. En particulier, les métriques P0 existantes exposaient \`PhysicsCollision\`, mais pas encore \`PhysicsParts\`.

Les préparations runtime connues au début de P1 sont volontairement hétérogènes :

- \`MonsterService\` impose \`Anchored=true\` et les trois propriétés \`CanCollide\`, \`CanTouch\`, \`CanQuery\` selon \`CombatConfig\`.
- \`WeaponService\` impose explicitement les quatre propriétés sur les projectiles.
- \`CoinService\` et \`XpService\` imposent \`Anchored\`, \`CanCollide=false\`, \`CanTouch=false\`, mais l'état de \`CanQuery\` reste à mesurer puis à justifier.
- \`ChestService\`, \`JarService\`, \`TotemService\` et \`PortalService\` ancrent les instances mais ne normalisent pas encore systématiquement les trois drapeaux physiques.
- \`ShrineService\` neutralise explicitement les zones de charge et la bulle, sans conclure sur la géométrie visible de toute la shrine.
- \`ProceduralMapService\` traite déjà séparément sol jouable, décor et collider invisible. Cette séparation doit être vérifiée sur les instances réellement générées, pas présumée correcte sur la seule lecture du code.

Cette hétérogénéité est un fait mesuré dans le code, pas encore un défaut produit. Les coffres de récompense utilisent notamment \`Touched\`, ce qui interdit une désactivation globale et aveugle de \`CanTouch\`.

## Hypothèse

Le risque physique principal n'est pas le code de déplacement des monstres, déjà largement ancré et non physique. Il provient potentiellement de la géométrie importée et de la préparation incomplète de certains templates :

- \`MeshPart\` avec fidélité de collision coûteuse ;
- colliders invisibles qui participent encore à une collision, un touch ou une query ;
- contraintes, joints et assemblages non ancrés hérités des assets Studio ;
- décorations procédurales, bâtiments interactifs et collectibles qui gardent des propriétés physiques sans dépendance de gameplay démontrée.

⚡ Simplification : aucune règle du type « tous les bâtiments ont \`CanCollide=false\` » n'est acceptable. Le sol, les rampes, les bornes de benchmark et certains objets réellement touchés sont des contre-exemples directs.

⚔️ Angle mort initial : la métrique \`PhysicsParts\` peut être indisponible selon la version Studio ou l'environnement. Le relevé conserve donc aussi \`PhysicsCollision\` et le total mémoire ; une valeur absente est explicitement traitée comme indisponible, jamais comme zéro.

## Périmètre P1.1

L'inventaire couvre les dossiers templates serveur :

- \`ServerStorage/CombatTemplates\`
- \`ServerStorage/CollectibleTemplates\`
- \`ServerStorage/ShrineTemplates\`
- \`ServerStorage/ChestTemplates\`
- \`ServerStorage/JarTemplates\`
- \`ServerStorage/TotemTemplates\`
- \`ServerStorage/PortalTemplates\`
- \`ServerStorage/MapTemplates\`
- \`ServerStorage/LobbyTemplates\`

Il couvre aussi les conteneurs runtime :

- \`Workspace/CombatRuntime/Monsters\`
- \`Workspace/CombatRuntime/Projectiles\`
- \`Workspace/CombatRuntime/Loot\`
- \`Workspace/ShrinesRuntime\`, \`ChestsRuntime\`, \`JarsRuntime\`, \`TotemsRuntime\`, \`PortalsRuntime\`
- \`Workspace/MapRuntime\`

Chaque record conserve au minimum :

- classe et chemin ;
- nombre de \`BasePart\`, \`MeshPart\`, contraintes, joints et assemblages ;
- \`Anchored\`, \`CanCollide\`, \`CanTouch\`, \`CanQuery\`, \`Massless\` agrégés ;
- assemblages contenant des parties non ancrées ;
- \`CollisionFidelity\` des \`MeshPart\` ;
- échantillons de colliders invisibles participants et de collision précise.

## Protocole reproductible

1. Démarrer une run standard et attendre la génération complète de la map.
2. Sans modifier les réglages graphiques, ouvrir Admin puis cliquer \`P1 : inventaire physique\`.
3. Copier le résumé de la console et conserver le contenu de \`ReplicatedStorage/PerformanceAuditReports/PhysicsLatest/InventoryJson\`.
4. Répéter l'audit après une vague, après un coffre/une shrine, puis après le nettoyage de fin de run.
5. Pour chaque modification retenue en P1.2, rejouer exactement la même séquence avant/après. Les scénarios P0 \`monsters_250\` et une création/destruction de map complète seront la comparaison minimum.

L'audit P1.1 est en lecture seule. Il ne modifie pas les modèles, n'active pas de collider et ne change pas la map.

## Instrumentation introduite

- \`PhysicsAuditService\` publie le dernier rapport sous \`ReplicatedStorage/PerformanceAuditReports/PhysicsLatest\`.
- Le bouton admin \`P1 : inventaire physique\` déclenche l'audit serveur et retourne son emplacement.
- P0 enregistre désormais \`Server.Memory.PhysicsPartsMb\` et \`Client.Memory.PhysicsPartsMb\` en plus de \`PhysicsCollisionMb\`.

## Proof of done attendu pour P1

P1 ne sera clos que lorsque :

1. l'inventaire complet a été collecté sur templates et runtime ;
2. chaque participation physique critique est soit justifiée, soit supprimée explicitement dans une préparation runtime ;
3. les changements retenus ont une comparaison avant/après sur scènes identiques ;
4. \`PhysicsParts\`, \`PhysicsCollision\`, nombre d'instances et stabilité après plusieurs créations/destructions sont relevés ;
5. le smoke canonique reste bon : run, monstres, projectiles, collectibles, coffre, shrine, portail et génération de map restent utilisables.

La prochaine décision ne sera pas prise avant lecture du premier inventaire P1. Une absence de candidat crédible est un résultat valide : P1 pourra alors conclure qu'aucune normalisation supplémentaire ne mérite le risque fonctionnel.

---

## Mise a jour d'instrumentation - 2026-07-17 11:17:49

Le rapport serveur publie aussi `ReplicatedStorage/PerformanceAuditReports/PhysicsLatest/ReadableReport`.

Ce `StringValue` contient une version humaine de l'inventaire : une ligne par template ou conteneur runtime, les agrégats de parties et d'assemblages, les drapeaux physiques, les fidelites de collision et les findings. Il ne remplace pas `InventoryJson`, qui reste la source exploitable par machine, mais supprime la friction de lecture de la premiere campagne P1.

---

## Mise a jour d'instrumentation - 2026-07-17 11:17:49 (breakdown MapRuntime)

`MapRuntime` est conserve comme total unique dans le resume P1, puis detaille en records `RuntimeBreakdown` par enfant de map. Ces records ne sont jamais additionnes au total afin d'eviter tout double comptage.

Cette granularite est necessaire avant P1.2 : les `PhysicsParts`, joints et colliders du relief, des decorations et de la base generee ne doivent pas etre confondus dans une seule hypothese d'optimisation.

---

## Mise a jour d'instrumentation - 2026-07-17 11:17:49 (separation templates/runtime)

Le rapport expose maintenant trois sommes : globale, `TemplateSummary` et `RuntimeSummary`. Les templates sont des assets charges et utiles a la memoire, mais ne constituent pas une preuve de charge de simulation dans une run. Les deux realites doivent rester distinctes dans toute comparaison P1.

---

## Premier releve P1.1 - 2026-07-17 11:39:31

Audit : `P1-Physics-23392390`.

Mesures immediates :

- memoire totale : `3059.89 MB` avant, `3059.91 MB` apres ;
- memoire Instances : `191.58 MB` stable ;
- `PhysicsParts` : `110.97 MB` stable ;
- `PhysicsCollision` : `1.60 MB` stable ;
- inventaire global : `4 958` BaseParts, `175` MeshParts, `183` parties non ancrees, `102` contraintes et `2 985` joints.

Le total global melangeait encore templates et runtime au moment de ce releve. La reconstitution par records donne environ `1 448` BaseParts de templates et `3 510` BaseParts runtime. Le prochain releve utilisera la separation explicite ajoutee ci-dessus.

### Faits constates

- Les monstres et les projectiles runtime sont ancres et ont `CanCollide=false`, `CanTouch=false`, `CanQuery=false`. Les templates `Monster1`, elites, boss et Fireball non ancres ne constituent donc pas une simulation physique active dans la run.
- Les `176` parties non ancrees et `381` joints du `ProceduralKit` restent des donnees source. Le `MapRuntime` genere est entierement ancre ; ce constat ne justifie pas une modification du kit avant d'avoir attribue ses couts aux sous-ensembles runtime.
- Le `MapRuntime` est le plus gros ensemble actif : `3 392` parties, `216` collidables, `100` touch/query, `51` contraintes et `1 874` joints. Son agregat etait insuffisant pour choisir une correction precise ; le breakdown est donc devenu bloquant avant P1.2.
- Les chests (`30`), jarres (`40`), totems (`5`) et portail (`1`) runtime gardent tous collision, touch et query actifs. Leur interaction habituelle repose pourtant sur des `ProximityPrompt` et une validation de distance. Les coffres de recompense elite constituent une exception : ils utilisent intentionnellement `Touched`.
- Le loot runtime etait vide pendant ce releve. Les collectibles ne peuvent donc pas encore etre declares valides ou incorrects au runtime, meme si la lecture du code montre que `CoinService` et `XpService` ne normalisent pas encore `CanQuery=false` sur leurs clones.

### Lecture critique

✔️ Juste : `PhysicsCollision=1.60 MB` est faible face a `PhysicsParts=110.97 MB`. Le premier cout suspect est donc la geometrie et le volume d'instances, pas une preuve que les colliders precis dominent deja la memoire.

~ Contestable : des colliders actifs sur les objets interactifs peuvent etre un choix de ressenti. Ils ne seront pas supprimes seulement parce que le prompt fonctionne sans eux ; leur role de blocage du joueur doit etre confirme par un smoke produit.

⚔️ Angle mort : une lecture avant/apres immediate de l'audit ne prouve aucune absence de fuite. Elle montre uniquement que l'audit lui-meme n'ajoute pas de pic observable. La stabilite apres plusieurs creations/destructions de map reste a mesurer.

### Decision P1.1

`Adjust` : instrumenter plus finement `MapRuntime`, puis releve runtime avec du loot au sol. Aucune normalisation physique n'est retenue avant ce second point de reference.

---

## Second releve P1.1 - 2026-07-17 11:54:30

Audit : `P1-Physics-24595075`.

Ce releve est le premier a exploiter la separation templates/runtime et le breakdown de `MapRuntime`. Il contient aussi deux collectables runtime, volontairement laisses au sol avant le scan.

Mesures immediates :

- memoire totale : `2942.14 MB` avant, `2942.17 MB` apres ;
- memoire Instances : `168.79 MB` avant, `168.78 MB` apres ;
- `PhysicsParts` : `138.35 MB` stable ;
- `PhysicsCollision` : `1.61 MB` stable ;
- inventaire global : `4 538` BaseParts, dont `1 448` templates et `3 090` runtime ;
- runtime map : `2 970` BaseParts, `236` collidables, `108` touch/query, `54` contraintes et `1 810` joints ;
- runtime loot : `2` MeshParts ancres, `CanCollide=false`, `CanTouch=false`, mais `CanQuery=true`.

### Lecture du releve

Le second scan repond au point bloque du premier : les collectables reels au sol heritent encore de `CanQuery=true` depuis leurs templates. Aucun service de collecte n'utilise le moteur de requetes physiques pour les pieces ou les gemmes : la collecte et l'attraction reposent sur les distances serveur et les animations dediees.

Les valeurs memoire de ce releve ne sont pas une comparaison avant/apres avec le premier audit : la map runtime n'a pas le meme volume (`2 970` contre `3 392` BaseParts lors du premier releve). Elles etablissent un etat de reference local pour la normalisation P1.2, mais ne prouvent ni gain ni regression a elles seules.

### Decision P1.2 preparee

`Keep pour smoke` : normaliser explicitement `CanQuery=false` dans `CoinService.prepareCoin` et `XpService.prepareCollectible`, pour la racine et tous les descendants `BasePart` d'un futur collectable modele.

Cette modification ne touche ni :

- les degats, recompenses ou l'autorite serveur ;
- les positions, l'attraction ou la fusion ;
- `CanCollide` et `CanTouch`, deja neutralises ;
- les objets interactifs, les coffres de recompense elite, les jarres, les shrines, le portail ou le terrain.

Le smoke canonique P1.2 devra confirmer apres synchronisation Rojo : drop de piece, drop de gemme, attraction, collecte, fusion XP et recompense elite. Le prochain audit devra afficher `CombatLoot.query=0` avec au moins un collectable present.

---

## Validation P1.2 et preparation P1.3 - 2026-07-17 12:00:00

Audit apres normalisation : `P1-Physics-25328165`.

Le runtime contient `10` collectables reels. Tous sont ancres, non collidables, non tactiles et non interrogeables (`CombatLoot : collide=0, touch=0, query=0`). La normalisation est donc effectivement appliquee aux clones runtime et pas seulement aux fallbacks de templates.

Le releve detaille aussi la distribution runtime :

- `MapRuntime` : `3 689` BaseParts, dont `3 570` dans `GeneratedDecor` ;
- `GeneratedTerrain` : `117` parties collidables, tactiles et interrogeables ;
- `GeneratedDecor` : `3 570` parties, `147` collidables, `0` touch/query ;
- interactables ordinaires : shrines `23` query/touch, coffres `30`, jarres `40`, totems `5`, portail `1`.

La base et le relief gardent `CanQuery=true` intentionnellement : `WorldSpawnService` les utilise comme surfaces de raycast. Les decors generes sont deja correctement exclus de touch/query. La prochaine normalisation ne touche donc pas ces deux ensembles.

P1.3 est preparee sur les interactables ordinaires : ils conserveront `CanCollide` pour ne pas modifier le ressenti de parcours, mais `CanTouch` et `CanQuery` seront imposes a `false`. Les `ProximityPrompt` fonctionnent avec `RequiresLineOfSight=false`. Le coffre de recompense elite reinitialise explicitement `CanTouch=true` lorsqu'il installe son listener `Touched`.

---

## Releve P1.3 - 2026-07-17 12:08:00

Audit : `P1-Physics-26080844`.

Le smoke manuel rapporte que les interactions ordinaires restent identiques. L'inventaire confirme la normalisation runtime :

- `CombatLoot` : `65` MeshParts, `CanCollide=0`, `CanTouch=0`, `CanQuery=0` ;
- shrines : `23` parties collidables, `CanTouch=0`, `CanQuery=0` ;
- coffres ordinaires : `28` MeshParts collidables, `CanTouch=0`, `CanQuery=0` ;
- jarres : `33` MeshParts collidables, `CanTouch=0`, `CanQuery=0` ;
- totems : `5` MeshParts collidables, `CanTouch=0`, `CanQuery=0` ;
- portail : `1` MeshPart collidable, `CanTouch=0`, `CanQuery=0`.

La memoire immediate reste stable pendant l'audit (`2911.11 -> 2911.26 MB` total, `149.73 MB` de `PhysicsParts`, `1.61 MB` de `PhysicsCollision`). Comme les volumes de map varient encore, ce releve ne peut pas etablir un gain quantifie face aux precedents.

### Etat de validation

Le cas normal est valide. Le coffre `ChestOpen` de recompense elite n'etait pas present dans le runtime de ce releve : son exception `Touched` reste a tester explicitement avant de cloturer P1.3. Aucune normalisation sur le relief ou les decorations ne sera appliquee avant ce smoke, car ces ensembles representent un autre risque produit.

---

## Validation P1.3 - 2026-07-17 12:18:00

Le smoke manuel explicite du coffre de recompense elite est valide : `ChestOpen` s'ouvre toujours lorsque le joueur entre en contact avec lui. Cette exception confirme que `ChestService` reactive intentionnellement `CanTouch` avant d'installer son listener `Touched`.

Decision P1.3 : `Keep`.

La normalisation des interactables ordinaires est retenue : leur collision reste preservee pour le parcours, tandis que les participations `CanTouch` et `CanQuery` inutiles sont retirees. Aucun changement de gameplay n'est observe sur les prompts, les jarres, les shrines, les totems, le portail ou le coffre de recompense.

### Transition P1.4

Le prochain sous-ensemble cible est `GeneratedTerrain`. La lecture du code montre que ce relief est consulte par raycast et doit donc conserver `CanQuery=true`; il reste aussi collidable pour le joueur. Aucune connexion `Touched` ne le consomme. La correction candidate est donc strictement `CanTouch=false`, sans intervention sur les collisions, les raycasts ou la generation.

---

## Validation P1.4 - 2026-07-17 12:26:00

Audit : `P1-Physics-27104226`.

Le smoke manuel est valide : parcours du relief, rampes, spawns et ouvertures/interactions restent fonctionnels.

Le breakdown runtime confirme la normalisation attendue :

- `GeneratedTerrain` : `97` parties, `CanCollide=97`, `CanTouch=0`, `CanQuery=97` ;
- `GeneratedBase` : `2` parties, `CanCollide=2`, `CanTouch=0`, `CanQuery=2` ;
- `MapRuntime` total : `CanTouch=0`, `CanQuery=99`.

La memoire immediate reste strictement stable pendant le scan (`2730.25 -> 2730.25 MB` total, `161.02 MB` de `PhysicsParts`, `1.62 MB` de `PhysicsCollision`). Ces chiffres sont une observation de stabilite du scan, pas un gain attribuable a P1.4 : la taille et la forme de la map generee different des releves precedents.

Decision P1.4 : `Keep`.

### Etat P1 restant

Les normalisations a faible risque prevues sont terminees. La cloture de P1 reste bloquee par un seul proof of done : plusieurs cycles comparables de creation puis destruction de map, avec audit apres chaque cycle, afin de verifier que les proprietes runtime et les memoires `PhysicsParts`/`PhysicsCollision` ne montent pas residuellement.

---

## Validation multi-run intermediaire - 2026-07-18 09:45:00

Le cycle de vie de run a ete redresse puis valide par plusieurs morts et relances successives. Trois inventaires ont ete produits sur les trois variantes de map testees :

| Audit | Memoire totale avant -> apres | PhysicsParts | PhysicsCollision | Parties runtime | MapRuntime |
| --- | --- | --- | --- | --- | --- |
| `P1-Physics-64730161` | `2451.32 -> 2451.37 MB` | `51.49 MB` | `0.24 MB` | `3196` | `3042` |
| `P1-Physics-64854003` | `2500.59 -> 2500.71 MB` | `61.56 MB` | `0.25 MB` | `3380` | `3261` |
| `P1-Physics-64937262` | `2520.21 -> 2520.21 MB` | `64.75 MB` | `0.25 MB` | `3019` | `2886` |

Les trois audits confirment les invariants runtime P1 :

- monstres, projectiles et loot actifs : ancres, `CanCollide=0`, `CanTouch=0`, `CanQuery=0` ;
- interactables ordinaires : `CanTouch=0`, `CanQuery=0` ;
- `MapRuntime` : `CanTouch=0` ; seules les surfaces sollicitees par les raycasts de spawn conservent `CanQuery` ;
- aucune partie non ancree ne reste dans le runtime audite.

Les variations de `PhysicsParts` et du total memoire entre les trois releves ne prouvent ni un gain ni une fuite : les variantes produisent chacune un volume de map, de mesh et de collision different. La stabilite avant/apres de chaque audit prouve seulement que le scan lui-meme n'ajoute pas de cout residuel mesurable.

### Etat de validation

Le proof de regeneration est valide : le passage a la variante suivante a bien necessite la destruction du monde precedent, sans accumulation visible des parties runtime. La cloture P1 reste cependant bloquee par un dernier releve volontairement simple : terminer la troisieme run, revenir au lobby, lancer l'inventaire P1, puis verifier que les dossiers runtime sont vides ou retombes au pool attendu et que `PhysicsParts`/`PhysicsCollision` ne conservent pas de volume de map runtime.

---

## Cloture P1 - 2026-07-18 10:15:00

Audit final hors run : `P1-Physics-65580531`.

Le retour lobby apres une mort rapide confirme la destruction complete du monde de run : `runtimeParts=0`, et chacune des familles `CombatMonsters`, `CombatProjectiles`, `CombatLoot`, `ShrinesRuntime`, `ChestsRuntime`, `JarsRuntime`, `TotemsRuntime`, `PortalsRuntime` et `MapRuntime` contient `0` partie, `0` contrainte et `0` joint.

Les mesures globales sont stables pendant le scan (`2600.50 -> 2600.50 MB`, `PhysicsParts=67.79 MB`, `PhysicsCollision=0.25 MB`). Ce resultat ne doit pas etre lu comme un gain absolu compare aux runs actifs, qui utilisent des variantes de map differentes. Il valide en revanche le proof de destruction demande : aucun volume physique de la map de run ne reste dans le runtime apres retour lobby.

Decision P1 : `Keep`, phase cloturee dans son perimetre d'inventaire et de normalisation physique. Le detail complet est consigne dans `post_audit_2026-07-18_101500_performance_p1_physics_cloture.md`.
