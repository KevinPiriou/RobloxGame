# Boss Humanoid Grounding

## 2026-07-12 15:12 CEST - Boss1 anime sans chute physique

### Probleme identifie

- ✓ `MonsterService` detectait la presence d'un `Humanoid`, desancrait toutes les pieces puis utilisait `Humanoid:MoveTo`.
- ✓ Les collisions des monstres sont desactivees par la configuration de combat. Le boss Humanoid etait donc soumis a la gravite sans surface de collision et traversait le sol.

### Correctif applique

- ✓ Toutes les pieces d'un monstre sont maintenant ancrees, y compris si le template contient un `Humanoid`.
- ✓ Le deplacement du boss reste serveur et deterministe via `PivotTo`, comme les autres ennemis. Le `Humanoid` reste disponible pour la vie, les degats et l'animation du rig.
- ✓ Le boss Humanoid ne recoit plus le bobbing et le sway proceduraux des monstres non rigges, afin de ne pas perturber son animation.
- ✓ Le log `Boss genere` indique maintenant `HasHumanoid`, `Root` et `RootAnchored` pour un diagnostic Studio direct.

### Smoke manuel canonique

1. Lancer une run puis activer le portail boss.
2. Verifier que Boss1 apparait pose sur le sol, sans tomber ni etre en hauteur.
3. Verifier qu'il se dirige vers le joueur et conserve ses attaques de bulles.
4. Verifier dans la console le log `Boss genere` avec `RootAnchored = true`.
5. Verifier que l'animation attachee au template continue de se jouer. Si elle ne se joue pas, transmettre le contenu du script `PlayAnimation` et l'arborescence du rig : ce sera alors un chantier animation distinct de la physique.

### Angle mort

- ◐ Le modele Boss1 et son script `PlayAnimation` vivent dans ServerStorage/CombatTemplates, hors fichiers Rojo. Le build valide le code serveur mais ne peut pas inspecter leur contenu Studio depuis ce depot.

## 2026-07-12 15:18 CEST - Piste d'animation explicite du boss

- ✓ `BossConfig.AnimationId` reference `rbxassetid://507777826` avec une priorite `Action`.
- ✓ `BossService` transmet cette animation au spawn et `MonsterService` la charge dans `RuntimeCombatAnimation`, sans activer les animations serveur de toute la population de monstres.
- ✓ Le script `PlayAnimation` du modele peut rester en place. Sa piste `Movement` est dominee par la piste `Action` du boss, ce qui evite le conflit avec les mouvements serveur.
- ◐ Si le log indique que l'animation ne peut pas etre chargee, l'experience ne dispose pas de l'autorisation pour cet asset. Il faudra alors importer/publier l'animation sous le proprietaire de l'experience.

## 2026-07-12 15:27 CEST - Correctif de relais du spawn boss

- ✓ Le test Studio a montre que le script `PlayAnimation` chargeait bien sa piste `Movement`, mais que la piste `Action` configuree par le service n'etait jamais creee.
- ✓ La cause etait interne : `SpawnBossNearPlayer` ne retransmettait ni `AnimationId`, ni `AnimationPriority`, ni `SpeedMultiplier` vers `spawnMonsterAtSurface`.
- ✓ Le relais est maintenant complet. Le prochain spawn doit produire le log `Animation monstre lancee` avec la priorite `Action`, en plus du log du script du modele.

## 2026-07-12 15:35 CEST - Une seule autorite d'animation

- ✓ Les logs confirment que les pistes `Movement` du script `PlayAnimation` et `Action` du service etaient toutes deux chargees, sans animation visible.
- ✓ La piste `Action` ajoutee par le service est retiree. Le template retrouve une seule autorite : son script `PlayAnimation`.
- ✓ Pour Boss1, le montage Studio cible est `AnimationController > Animator`, sans `Humanoid` ni `HumanoidRigDescription`. Le combat gere deja la vie du boss sans Humanoid et le script fourni selectionne naturellement l'`AnimationController` lorsque le Humanoid est absent.
- ◐ Un `AnimationTrack` peut etre charge et jouer sans erreur tout en ne transformant aucune bone si son asset a ete cree pour un autre rig. Si la configuration ci-dessus ne restaure pas le mouvement, il faudra republier une animation creee directement depuis les bones de Boss1 dans l'Animation Editor.

## 2026-07-12 15:46 CEST - Suppression du mouvement procedural du boss

- ✓ `UseProceduralMotion = false` est transmis seulement au boss. Il ne recoit plus le bobbing et le sway utilises pour les monstres non rigges.
- ✓ Les monstres ordinaires conservent leur mouvement procedural existant.
- ◐ Le log de test ne montre pas encore le demarrage de `PlayAnimation` dans l'instance runtime du boss. Le prochain test doit donc verifier separatement : absence de sway procedural et demarrage reel de la piste du rig.

## 2026-07-12 16:11 CEST - Convention d'animation des templates de combat

### Correctif applique

- Un template de monstre contenant un `Script` nomme `PlayAnimation` est considere comme autonome pour son animation.
- Dans ce cas, `MonsterService` desactive automatiquement le balancement procedural du combat pour eviter de melanger deux rendus visuels.
- Les templates existants sans `PlayAnimation` conservent le mouvement procedural actuel.
- Le boss garde son option explicite `UseProceduralMotion = false`, qui reste prioritaire sur la convention.

### Contrat Studio

1. Le template est range dans `ServerStorage/CombatTemplates`.
2. Le modele contient un `AnimationController` et son `Animator`.
3. Le script serveur enfant du modele est nomme exactement `PlayAnimation`.
4. Le script charge une animation publiee depuis le rig Meshy exact du template.

### Smoke manuel canonique

1. Faire apparaitre un `Monster1` normal en run.
2. Verifier que son cycle Meshy se joue et qu'il ne recoit plus le sway procedural.
3. Faire apparaitre un elite et le boss.
4. Verifier que les animations propres se jouent, que le suivi du joueur reste identique et qu'aucun modele ne tombe a travers le sol.

### Angle mort

- Le depot Rojo ne contient pas les templates Studio. La presence effective du script `PlayAnimation`, de son `Animator` et de l'asset publie reste a verifier dans Studio pour chaque nouveau template.

## 2026-07-12 18:17 CEST - Reinitialisation des pistes d'animation du pool

### Probleme identifie

- Le pool replace les instances de monstres dans `ServerStorage`, puis les reutilise pour le spawn suivant.
- Le script Studio `PlayAnimation` rechargeait une piste a chaque reutilisation de `Monster1`, tandis que les anciennes pistes arretees restaient comptees par Roblox.
- Apres 64 cycles, Roblox refusait toute nouvelle piste avec `AnimationTrack limit of 64 tracks exceeded`.

### Correctif applique

- Lors du retour d'un monstre dans son pool, `MonsterService` arrete la piste connue puis supprime tous les `Animator` presents dans le modele.
- Le `AnimationController` et le script `PlayAnimation` sont conserves. Lors du prochain spawn, le script recrée un `Animator` propre et recharge une seule piste.
- Cette remise a zero couvre les monstres normaux, elites et boss qui passent par le pool de combat.

### Smoke manuel canonique

1. Lancer une run et utiliser plusieurs fois le debug de spawn puis `Tuer tous les ennemis` afin de depasser 70 reutilisations de `Monster1`.
2. Verifier que l'animation Meshy reste visible apres chaque reutilisation.
3. Verifier que la console ne contient plus `AnimationTrack limit of 64 tracks exceeded`.
4. Faire apparaitre un elite et le boss pour verifier que leurs animations propres sont toujours lancees.

### Angle mort

- Les scripts et riggs des templates vivent dans Studio. Si un nouveau template recharge lui-meme des pistes sans utiliser son `Animator`, son script devra respecter la meme regle : une seule piste active par animator runtime.
