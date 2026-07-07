# Post-audit - Combat Megabonk V1

## 2026-07-07 16:28:54 +02:00 - Première boucle combat automatique

### Contexte

Le projet bascule d'une fondation quiz/bonus vers une première boucle de survie inspiree de Megabonk :

- des monstres apparaissent autour du joueur ;
- les monstres poursuivent le joueur ;
- le contact avec un monstre retire des PV ;
- une Fireball tire automatiquement vers l'ennemi le plus proche ;
- un petit HUD affiche PV, monstres actifs, kills et arme active.

### Fichiers ajoutes

- `src/shared/CombatConfig.luau`
- `src/server/MonsterService.luau`
- `src/server/WeaponService.luau`
- `src/client/CombatUI.client.luau`

### Fichier modifie

- `src/server/GameManager.server.luau`

### Decisions

- ✓ Le serveur reste autoritaire pour le spawn, la poursuite, les degats, les kills et les tirs.
- ✓ Les assets Studio `Monster1` et `Fireball` sont utilises comme templates runtime. Ils peuvent etre places dans `Workspace`, `ReplicatedStorage` ou `ServerStorage`.
- ✓ Si un template est trouve dans `Workspace`, il est deplace au runtime dans `ServerStorage/CombatTemplates` pour eviter qu'un objet de template reste actif dans la map.
- ✓ Si un template est introuvable, un objet de secours est cree pour que la boucle reste testable.
- ⚡ La V1 ne cree pas encore de systeme complet de vagues, d'XP, de choix d'amelioration ou de build d'armes. Le but est de valider la boucle simple avant sophistication.

### Proof of done local

- ✓ `rojo build -o $env:TEMP\TestRoblox_combat_build.rbxlx` passe.
- ✓ `git diff --check` ne remonte pas d'erreur sur les nouveaux fichiers.
- ◐ `luau` n'est pas installe localement, donc aucune compilation Luau independante n'a pu etre lancee.
- ◐ La validation produit finale doit etre faite dans Roblox Studio avec `Play`, car la qualite depend du rig réel de `Monster1` et de la forme réelle de `Fireball`.

### Angles morts

- ◐ Si `Monster1` est un rig avec Humanoid mal configure, le service essaie `Humanoid:MoveTo`, mais le comportement exact dependra des pieces, collisions, joints et ancrages du modele.
- ◐ Si `Monster1` est seulement un mesh ou une Part, il sera deplace directement par le serveur. C'est suffisant pour une V1, mais moins riche qu'un vrai rig anime.
- ◐ Il n'y a pas encore de pathfinding : les monstres vont en ligne directe vers le joueur.
- ◐ Il n'y a pas encore de respawn intelligent par zone, de vague progressive, d'elite, de boss, d'XP, ni de choix de bonus type survivor-like.
- ◐ Les kills ne sont pas persistants pour l'instant.

### Budget de complexite

- Complexite ajoutee : moyenne.
- Justification : la boucle combat necessite deux services serveur distincts (`MonsterService`, `WeaponService`) pour eviter de polluer le quiz et la persistance des bonus.
- Voie de simplification possible : si la V1 se revele instable, couper `WeaponService` ou `MonsterService` depuis `GameManager.server.luau` suffit a isoler le probleme sans toucher aux autres systemes.

## 2026-07-07 16:47:22 +02:00 - Vagues progressives et plafond global

### Contexte

La boucle combat initiale avait un plafond fixe par joueur. Cela permettait de tester le spawn, mais ne creait pas une pression croissante.

### Changements

- `src/shared/CombatConfig.luau` ajoute un plafond global `MonsterMaxAlive = 1000`.
- `src/shared/CombatConfig.luau` ajoute des parametres de vague : duree, cible de monstres vivants, croissance de cible et taille des paquets de spawn.
- `src/server/MonsterService.luau` calcule une vague temporelle continue.
- `src/server/MonsterService.luau` augmente progressivement le nombre maximum de monstres vivants.
- `src/server/MonsterService.luau` augmente progressivement la taille des paquets de spawn.
- `src/client/CombatUI.client.luau` affiche la vague courante et le compteur `monstres vivants / objectif de vague`.

### Decisions

- ✓ Le plafond de 1000 ennemis est global, pas par joueur.
- ✓ La vague grossit avec le temps, ce qui correspond mieux a une boucle survivor-like continue qu'a une succession de manches arretees.
- ⚡ Le service ne declenche pas encore de phase "vague terminee" ou "pause entre vagues". Cette simplification garde la boucle jouable et proche de Megabonk.

### Proof of done local

- ✓ `rojo build -o $env:TEMP\TestRoblox_wave_build.rbxlx` passe hors sandbox.
- ✓ `git diff --check` ne remonte pas d'erreur sur les fichiers modifies.

### Angles morts

- ◐ Un plafond de 1000 ennemis est volontairement permis par la config, mais la performance reelle dependra fortement du modele `Monster1`, du nombre de pieces, des collisions et de la presence d'un Humanoid.
- ◐ Si `Monster1` est un rig Humanoid complet, 1000 ennemis peut etre trop couteux. Il faudra probablement basculer vers des monstres simplifiés ou du pooling si le Play Test sature.
- ◐ Le spawn reste autour des joueurs et sans pathfinding ; les obstacles de map ne sont donc pas encore pris en compte.

### Budget de complexite

- Complexite ajoutee : faible a moyenne.
- Justification : la progression de vague est centralisee dans `MonsterService` et configuree dans `CombatConfig`, sans nouveau service.
- Voie de simplification possible : remettre `WaveMaxAliveIncrease` a `0` ou reduire `MonsterMaxAlive` permet de revenir a une pression fixe sans retirer la structure.

## 2026-07-07 17:04:09 +02:00 - Separation ennemis et loot XP/pieces

### Contexte

Le modele `Monster1` observe dans Studio contient un `RootPart`, plusieurs objets de mesh et un `AnimationController`, mais pas de `Humanoid`. Le deplacement direct par `PivotTo` rendait les ennemis capables de se superposer visuellement, car la physique Roblox ne resout pas naturellement les collisions entre objets ancres deplaces par script.

### Changements

- `src/shared/CombatConfig.luau` ajoute les parametres de racine, animation, separation, loot XP, chance de pieces et dispersion.
- `src/server/MonsterService.luau` prefere maintenant `RootPart` comme racine de `Monster1`.
- `src/server/MonsterService.luau` ajoute une separation serveur entre ennemis via une grille spatiale simple.
- `src/server/MonsterService.luau` tente de jouer une `Animation` du modele si elle existe sous l'`AnimationController`.
- `src/server/MonsterService.luau` ajoute un mouvement procedural leger si aucune animation exploitable n'est trouvee.
- `src/server/MonsterService.luau` fait tomber des `XpGem` quand un joueur tue un ennemi.
- `src/server/MonsterService.luau` fait parfois tomber des `Coin`, selon `CoinDropChance`.
- `src/server/XpService.luau` ajoute la collecte, l'attraction et le compteur XP.
- `src/server/CoinService.luau` expose `SpawnCoin` pour permettre les drops serveur.
- `src/client/CoinClient.client.luau` anime maintenant `Coin` et `XpGem` avec le meme comportement d'attraction.
- `src/client/CombatUI.client.luau` affiche le compteur XP.

### Decisions

- ✓ Les drops ne sont crees que pour une mort attribuee a un joueur. Un despawn lointain ne genere pas de loot.
- ✓ L'XP n'est pas persistante pour l'instant ; elle sert de socle de partie pour une future boucle de level-up.
- ✓ Les pieces gardent leur persistance existante via `CoinService`.
- ⚡ La "collision" entre ennemis est une separation de gameplay, pas une collision physique stricte. C'est plus adapte au modele actuel sans `Humanoid`.

### Proof of done local

- ✓ `rojo build -o $env:TEMP\TestRoblox_loot_build.rbxlx` passe.
- ✓ `git diff --check` ne remonte pas d'erreur sur les fichiers modifies.

### Angles morts

- ◐ Si le modele `Monster1` ne contient aucune instance `Animation` avec un `AnimationId`, l'`AnimationController` ne peut pas jouer de vraie animation ; seul le mouvement procedural sera visible.
- ◐ La separation limite le chevauchement, mais ne remplace pas un vrai systeme de steering complet avec pathfinding et evitement d'obstacles.
- ◐ La chance de drop des pieces est fixe pour l'instant. Elle pourra plus tard etre reliee a un attribut `Chance` du joueur.
- ◐ Les `XpGem` doivent etre nommees exactement `XpGem` si un asset Studio personnalisé est fourni.

### Budget de complexite

- Complexite ajoutee : moyenne.
- Justification : le loot XP demande un service dedie, car il a un compteur propre et un comportement de collecte distinct des pieces persistantes.
- Voie de simplification possible : si la collecte XP doit etre fusionnee plus tard avec les pieces, extraire un service generique `CollectibleService` sera plus propre que dupliquer davantage de logique.
