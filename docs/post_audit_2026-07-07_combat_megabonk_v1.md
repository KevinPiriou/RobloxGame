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

## 2026-07-07 22:48:00 +02:00 - HUD debug performances

### Contexte

Le Play Test Studio n'est pas un reflet parfait du jeu publie. Studio ajoute le cout de l'editeur, des panneaux, des outils de debug et peut executer serveur/client dans un contexte moins representatif qu'un client Roblox reel. A l'inverse, un joueur en production peut avoir un appareil plus faible, des graphismes differents ou des conditions reseau moins bonnes.

### Changements

- `src/client/DebugUI.client.luau` ajoute un overlay debug client.
- Le HUD affiche le FPS local calcule via `RunService.RenderStepped`.
- Le HUD affiche la RAM totale via `Stats:GetTotalMemoryUsageMb()`.
- Le HUD affiche les temps CPU/GPU de rendu par frame via `Stats.RenderCPUFrameTime` et `Stats.RenderGPUFrameTime`.
- Le HUD affiche aussi le temps physique, le nombre d'instances, les draw calls et les triangles.

### Decisions

- Juste : CPU/GPU sont affiches en millisecondes par frame, pas en pourcentage systeme. C'est la mesure exposee proprement par Roblox.
- Juste : le HUD est isole dans un fichier client dedie pour pouvoir etre retire ou desactive sans toucher au gameplay.
- Contestable : l'overlay reste actif par defaut pour l'instant. C'est pratique en phase debug, mais il faudra probablement le masquer en production.

### Proof of done local

- Juste : `rojo build -o $env:TEMP\TestRoblox_debug_build.rbxlx` passe.
- Juste : `git diff --check` ne remonte pas d'erreur.

### Angles morts

- Angle mort : ces mesures sont locales au client qui joue. Elles ne mesurent pas directement le serveur Roblox en production.
- Angle mort : les valeurs Studio restent indicatives. Pour une preuve plus forte, il faudra tester aussi dans un client Roblox publie.
- Angle mort : l'overlay ajoute lui-meme une petite charge UI, normalement faible mais non nulle.

### Budget de complexite

- Complexite ajoutee : faible.
- Justification : l'outil est un seul script client sans interaction serveur.
- Voie de simplification possible : ajouter plus tard un flag `DebugEnabled` ou reserver l'affichage aux admins.

## 2026-07-07 23:06:51 +02:00 - Fusion XP et spawn ennemi au sol

### Contexte

Le nombre de collectibles XP peut devenir trop eleve avec une vague importante d'ennemis. Le besoin produit est de reduire le nombre d'instances au sol sans perdre la valeur d'XP. En parallele, des ennemis pouvaient apparaitre alors que le joueur venait de spawn ou etre poses trop haut par rapport a la surface.

### Changements

- `src/shared/CombatConfig.luau` ajoute trois tiers XP : `XpGem`, `XpGem2`, `XpGem3`.
- `src/shared/CombatConfig.luau` configure les valeurs XP : `1`, `5`, `25`.
- `src/shared/CombatConfig.luau` configure la fusion : `5` gems proches dans un rayon de `8` studs.
- `src/server/XpService.luau` fusionne serveur-side `5 XpGem -> 1 XpGem2`.
- `src/server/XpService.luau` fusionne serveur-side `5 XpGem2 -> 1 XpGem3`.
- `src/server/XpService.luau` conserve la valeur totale d'XP lors de la fusion.
- `src/client/CoinClient.client.luau` reconnait et anime tous les tiers XP.
- `src/server/MonsterService.luau` attend que le joueur ait touche le sol pendant `3` secondes avant de spawner des ennemis autour de lui.
- `src/server/MonsterService.luau` pose les ennemis sur la surface detectee par raycast en calculant l'offset entre le pivot du modele et le bas de sa bounding box.

### Decisions

- Juste : la fusion XP doit etre faite cote serveur, car elle reduit le nombre reel d'instances et conserve la valeur de recompense.
- Juste : `XpGem3` ne fusionne pas plus loin pour l'instant ; il devient le tier compact final.
- Simplification : la fusion se fait par proximite locale, pas par clustering parfait mathematique. C'est suffisant pour reduire la charge et plus simple a maintenir.
- Juste : le spawn ennemi ne retombe plus sur une hauteur fixe ; il depend de la surface trouvee.

### Proof of done local

- Juste : `rojo build -o $env:TEMP\TestRoblox_xp_merge_build.rbxlx` passe.
- Juste : `git diff --check` ne remonte que des avertissements CRLF.

### Angles morts

- Angle mort : si les assets `XpGem2` ou `XpGem3` sont absents, un fallback visuel simple est cree. Le gameplay fonctionne, mais le rendu ne correspondra pas a l'asset attendu.
- Angle mort : la fusion peut faire disparaitre visuellement plusieurs petites gems d'un coup sans animation de fusion dediee. C'est acceptable pour la performance, mais une animation de merge sera utile plus tard.
- Angle mort : `Humanoid.FloorMaterial` est utilise pour savoir si le joueur a touche le sol. Si un avatar ou une map utilise une physique atypique, il faudra peut-etre renforcer cette detection par raycast.
- Angle mort : les ennemis sont poses correctement au spawn, mais leur deplacement direct ne suit pas encore les pentes ou reliefs apres apparition.

### Budget de complexite

- Complexite ajoutee : moyenne.
- Justification : la fusion XP evite une explosion d'instances au sol, ce qui est directement lie aux performances.
- Voie de simplification possible : reduire `XpMergeMaxGroupsPerScan`, augmenter `XpMergeScanInterval`, ou desactiver la fusion en mettant `XpMergeCount` tres haut si un bug visuel apparait.

## 2026-07-07 23:19:16 +02:00 - Fusion XP plus agressive et culling visuel collectibles

### Contexte

Le test visuel montre encore beaucoup de gems XP au sol. La fusion precedente etait trop conservatrice pour une vague dense : `5` gems dans `8` studs pouvait laisser de nombreux petits items visibles. Le besoin ajoute est un culling client : ne plus afficher les collectibles hors champ camera ou trop loin, sans les supprimer cote serveur.

### Changements

- `src/shared/CombatConfig.luau` passe `XpMergeCount` de `5` a `3`.
- `src/shared/CombatConfig.luau` passe `XpMergeRadius` de `8` a `14`.
- `src/shared/CombatConfig.luau` passe `XpMergeScanInterval` de `0.6` a `0.25`.
- `src/shared/CombatConfig.luau` passe `XpMergeMaxGroupsPerScan` de `20` a `80`.
- `src/shared/CombatConfig.luau` aligne les valeurs XP sur le nouveau seuil : `XpGem = 1`, `XpGem2 = 3`, `XpGem3 = 9`.
- `src/shared/CombatConfig.luau` ajoute les reglages de culling visuel des collectibles.
- `src/client/CoinClient.client.luau` masque localement les pieces et gems XP hors camera, derriere la camera ou au-dela de `420` studs.
- `src/client/CoinClient.client.luau` evite aussi de faire tourner les collectibles actuellement masques.

### Decisions

- Juste : la fusion serveur reste la seule reduction reelle du nombre d'instances au sol.
- Juste : le culling client ne detruit pas les objets serveur, il ne fait que masquer leur rendu local.
- Faux : conserver `XpGem2 = 5` et `XpGem3 = 25` avec une fusion par `3` aurait donne de l'XP gratuite. Les valeurs sont donc revenues a une conservation neutre.
- Simplification : le culling est limite aux collectibles XP/pieces. Les ennemis restent visibles et simules normalement pour ne pas fragiliser le combat, les degats et le ciblage des armes.

### Proof of done local

- Juste : `rojo build -o $env:TEMP\TestRoblox_culling_build.rbxlx` passe.
- Juste : `git diff --check` ne remonte que les avertissements CRLF habituels.

### Angles morts

- Angle mort : le culling client ne reduit pas la charge serveur ni le nombre d'instances repliquees. Il reduit surtout le rendu local et l'animation client des collectibles.
- Angle mort : Roblox fait deja un culling moteur pour le rendu hors champ. Cette passe ajoute un controle explicite gameplay/client, mais la preuve finale reste a mesurer dans Studio avec le HUD debug.
- Angle mort : si la densite XP reste trop haute, il faudra ajouter un seuil global serveur par zone ou une fusion plus large par cellule, pas seulement augmenter encore le rayon.
- Angle mort : masquer un collectible hors champ peut rendre moins lisible un drop tres eloigne. Le rayon `420` studs est volontairement large pour eviter une disparition trop agressive pres du joueur.

### Budget de complexite

- Complexite ajoutee : faible a moyenne.
- Justification : la fusion plus agressive traite le probleme principal cote serveur, le culling limite le bruit visuel et le cout d'animation cote client.
- Voie de simplification possible : desactiver le culling avec `CollectibleCullingEnabled = false` si un effet visuel indesirable apparait, tout en gardant la fusion XP serveur.

## 2026-07-07 23:40:08 +02:00 - Debug admin ennemis et leveling XP V1

### Contexte

Le besoin est de tester rapidement la pression ennemie sans attendre les vagues naturelles, puis d'ajouter une premiere boucle de niveau lisible. Le niveau ne donne pas encore de recompense ; il sert seulement a verifier que l'XP collectee fait progresser le joueur.

### Changements

- `src/shared/AdminConfig.luau` ajoute `DebugSpawnMonsterCount = 100`.
- `src/server/AdminService.luau` cree les remotes `Admin_SpawnMonsters` et `Admin_KillMonsters`.
- `src/server/AdminService.luau` garde la validation admin serveur pour les trois actions admin.
- `src/client/AdminUI.client.luau` ajoute les boutons `Spawn 100 ennemis` et `Tuer tous les ennemis`.
- `src/server/MonsterService.luau` expose `DebugSpawnMonstersNearPlayer` pour spawner autour du joueur admin, en respectant `MonsterMaxAlive`.
- `src/server/MonsterService.luau` expose `DebugKillAllMonsters` pour supprimer les ennemis sans generer de loot de farm.
- `src/shared/CombatConfig.luau` ajoute `LevelBaseXp = 10` et `LevelXpIncrease = 5`.
- `src/server/XpService.luau` suit maintenant `Xp`, `TotalXp` et `Level`.
- `src/server/XpService.luau` fait monter le joueur de niveau lorsque son XP courante atteint le seuil du niveau.
- `src/client/CombatUI.client.luau` ajoute une barre d'XP en bas avec niveau, XP courante et XP requise.

### Decisions

- Juste : les boutons admin restent des demandes client, mais toutes les decisions sont faites cote serveur.
- Juste : le bouton `Tuer tous les ennemis` ne donne pas de loot, XP ou kills. C'est un outil de nettoyage/debug, pas une recompense.
- Simplification : le leveling V1 ne donne pas encore de bonus. Il valide seulement la progression.
- Contestable : le niveau n'est pas encore persistant. C'est acceptable pour une V1 de mecanique, mais il faudra le traiter avec le DataStore si le niveau devient une progression joueur reelle.

### Proof of done local

- Juste : `rojo build -o $env:TEMP\TestRoblox_level_admin_build.rbxlx` passe.
- Juste : `git diff --check` ne remonte que les avertissements CRLF habituels.

### Angles morts

- Angle mort : le spawn debug de `100` ennemis peut provoquer un pic CPU/replication selon la machine Studio. C'est volontairement un outil de stress test.
- Angle mort : si le joueur admin est dans une zone sans surface valide autour de lui, tous les `100` ennemis ne spawneront pas forcement.
- Angle mort : le level-up n'a pas encore d'effet gameplay, d'animation, de son, de choix de bonus ou de persistance.
- Angle mort : l'XP courante est consommee par le passage de niveau, tandis que `TotalXp` continue d'augmenter pour le leaderstat.

### Budget de complexite

- Complexite ajoutee : moyenne faible.
- Justification : les actions admin restent isolees, et le leveling V1 reste dans `XpService`.
- Voie de simplification possible : retirer les remotes admin debug apres la phase de stress test sans toucher au combat normal.

## 2026-07-08 00:04:42 +02:00 - Feedback rouge degats Monster1

### Contexte

Les tirs sur `Monster1` manquaient d'un retour visuel immediat. Le besoin est de faire passer le monstre en rouge tres brievement lorsqu'il prend des degats, puis de restaurer ses couleurs d'origine.

### Changements

- `src/shared/CombatConfig.luau` ajoute `MonsterDamageFlashColor`.
- `src/shared/CombatConfig.luau` ajoute `MonsterDamageFlashDuration = 0.5`.
- `src/server/MonsterService.luau` memorise les couleurs d'origine des `BasePart` au spawn.
- `src/server/MonsterService.luau` applique un flash rouge quand `DamageMonster` accepte des degats positifs.
- `src/server/MonsterService.luau` restaure les couleurs d'origine apres le delai, avec une priorite au dernier flash si plusieurs tirs touchent rapidement.

### Decisions

- Juste : le feedback est gere cote serveur, comme les degats, pour rester coherent entre les joueurs.
- Simplification : le flash change seulement `BasePart.Color`, sans tween ni effet particule.
- Juste : les couleurs originales sont memorisees par part, donc un monstre multicolore retrouve ses couleurs initiales.

### Proof of done local

- Juste : `rojo build -o $env:TEMP\TestRoblox_monster_damage_flash_build.rbxlx` passe.
- Juste : `git diff --check` ne remonte que les avertissements CRLF habituels.

### Angles morts

- Angle mort : si une partie du monstre utilise une texture tres dominante, le changement de `Color` peut etre moins visible.
- Angle mort : un monstre tue instantanement peut etre detruit trop vite pour que le flash soit perceptible.

### Budget de complexite

- Complexite ajoutee : faible.
- Justification : le feedback est localise dans `MonsterService` et parametrable depuis `CombatConfig`.
- Voie de simplification possible : mettre `MonsterDamageFlashDuration` a `0` et ne plus appeler le flash si l'effet devient trop bruyant avec de grandes vagues.

## 2026-07-08 01:01:36 +02:00 - Table perks et choix au level-up V1

### Contexte

La boucle XP/niveau avait besoin d'une premiere couche de progression roguelite. Le besoin est d'avoir une table de perks bonus cumulables, 4 raretes par perk, 3 propositions a chaque montee de niveau, et une pause du combat pendant le choix.

### Changements

- `src/shared/Perks.luau` ajoute les 20 perks demandes.
- `src/shared/Perks.luau` definit les raretes `Common`, `Rare`, `Epic`, `Legendary` avec couleurs vert, bleu, violet et dore.
- `src/server/CombatStateService.luau` ajoute une pause serveur avec horloge non pausee.
- `src/server/PerkService.luau` choisit 3 perks sans doublon dans la meme proposition.
- `src/server/PerkService.luau` valide le choix cote serveur via `Perk_SelectChoice`.
- `src/server/PerkService.luau` cumule les stats de perks par joueur.
- `src/client/PerkUI.client.luau` affiche une UI de choix de 3 perks au level-up.
- `src/server/XpService.luau` declenche un choix de perk a chaque niveau gagne.
- `src/server/XpService.luau` applique le bonus de gain d'XP avec reliquat fractionnaire.
- `src/server/CoinService.luau` applique le bonus de gain d'or et le rayon de recolte.
- `src/server/WeaponService.luau` applique vitesse d'attaque, nombre de projectiles, degats, critiques, vitesse projectile, duree et rebonds.
- `src/server/MonsterService.luau` applique armure, bouclier, chance de drop piece et augmentation du nombre d'ennemis.
- `src/server/JumpBonusService.luau` accepte un multiplicateur externe de saut pour composer perks et bonus quiz.
- `src/client/CombatUI.client.luau` affiche le bouclier dans le HUD quand il existe.

### Decisions

- Juste : le client ne choisit pas librement un perk ; il renvoie seulement l'option proposee, et le serveur valide `ChoiceId` et `OptionId`.
- Juste : la pause bloque les boucles ennemis, armes, XP et pieces pendant le choix.
- Simplification : le perk `Saut supplementaire` est une augmentation de puissance de saut pour cette V1, pas encore un vrai double-jump multi-sauts.
- Simplification : les degats elites sont deja stockes et calcules si un ennemi a `IsElite = true`, mais il n'existe pas encore de systeme d'elites.
- Contestable : la pause est globale au serveur. C'est adapte a une experience solo/small co-op, mais discutable pour un vrai multijoueur public.

### Proof of done local

- Juste : `rojo build -o $env:TEMP\TestRoblox_perks_build.rbxlx` passe.
- Juste : `git diff --check` ne remonte que les avertissements CRLF habituels.

### Angles morts

- Angle mort : les perks ne sont pas encore persistants apres deconnexion.
- Angle mort : l'UI ne liste pas encore les perks deja accumules.
- Angle mort : le systeme de rarete est aleatoire avec poids simples, sans pity timer ni contraintes de build.
- Angle mort : les rebonds de projectiles peuvent augmenter fortement le cout combat avec beaucoup de projectiles.
- Angle mort : certains bonus doivent etre rebalances en Play Test, surtout projectiles, critique, bouclier et plus d'ennemis.
- Angle mort : le choix de perk n'a pas encore d'effet sonore, animation ou feedback de selection avance.

### Budget de complexite

- Complexite ajoutee : moyenne a elevee.
- Justification : la progression par perks est une colonne vertebrale de gameplay et justifie plusieurs points d'integration.
- Voie de simplification possible : desactiver temporairement `PerkService.QueueLevelUp` dans `XpService` si le choix/pause perturbe le combat, tout en conservant la table `Perks.luau`.

## 2026-07-08 01:21:36 +02:00 - Vol de vie et affichage golds

### Contexte

La liste de perks devait remplacer la regeneration passive par un vol de vie actif. Le besoin est de soigner le joueur selon un taux faible des degats vraiment infliges. Les golds devaient aussi etre visibles en haut a gauche, independamment du panneau quiz.

### Changements

- `src/shared/Perks.luau` remplace `Regeneration de vie` par `Vol de vie`.
- `src/shared/Perks.luau` ajoute `LifeStealPercent` avec des valeurs basses : `1%`, `2%`, `3.5%`, `6%`.
- `src/server/PerkService.luau` retire la logique de regeneration passive.
- `src/server/PerkService.luau` ajoute `ApplyLifeSteal`.
- `src/server/MonsterService.luau` retourne maintenant les degats reellement retires au monstre.
- `src/server/WeaponService.luau` applique le vol de vie uniquement apres un impact valide.
- `src/client/UI.client.luau` affiche les golds dans un badge separe en haut a gauche.

### Decisions

- Juste : le soin se base sur les degats reellement infliges, pas sur les degats theoriques. L'overkill ne donne donc pas de soin supplementaire.
- Juste : la regeneration passive est retiree du code, pas seulement masquee dans la table de perks.
- Simplification : le vol de vie ne declenche pas encore de feedback visuel dedie.

### Proof of done local

- Juste : `rojo build -o $env:TEMP\TestRoblox_lifesteal_gold_build.rbxlx` passe.
- Juste : `git diff --check` ne remonte que les avertissements CRLF habituels.

### Angles morts

- Angle mort : les taux de vol de vie sont volontairement bas et devront etre testes avec les builds critiques/projectiles multiples.
- Angle mort : le badge golds en haut a gauche peut devoir bouger si l'UI Roblox/chat le chevauche selon les options joueur.

### Budget de complexite

- Complexite ajoutee : faible.
- Complexite reduite : suppression de la boucle de regeneration passive.
- Justification : le vol de vie est branche sur le chemin de degats existant sans ajouter de nouveau systeme permanent.

## 2026-07-08 01:26:06 +02:00 - Correction regen perk et regen native

### Contexte

La passe precedente avait mal interprete la demande : `Regeneration de vie` devait rester dans la liste des perks, et `Vol de vie` devait etre ajoute en plus. La regeneration a retirer etait la regeneration native/gratuite du personnage, pas le perk de regeneration.

### Changements

- `src/shared/Perks.luau` restaure le perk `Regeneration de vie`.
- `src/shared/Perks.luau` conserve le perk `Vol de vie`.
- `src/server/PerkService.luau` ajoute `HealthRegen` aux stats cumulables.
- `src/server/PerkService.luau` reactive une boucle serveur de regeneration uniquement si le joueur possede un bonus `HealthRegen`.
- `src/server/PerkService.luau` desactive le script Roblox `Health` ajoute au personnage quand il est present.

### Decisions

- Juste : `Vol de vie` et `Regeneration de vie` sont deux perks separes et cumulables.
- Juste : sans perk `HealthRegen`, le joueur ne doit plus recevoir de regeneration passive gratuite.
- Contestable : la desactivation cible le script nomme `Health`, ce qui correspond au cas Roblox natif, mais ne couvre pas un eventuel script custom renomme.

### Proof of done local

- Juste : `rojo build -o $env:TEMP\TestRoblox_regen_lifesteal_build.rbxlx` passe.
- Juste : `git diff --check` ne remonte que les avertissements CRLF habituels.

### Angles morts

- Angle mort : il faut valider en Play que le script `Health` est bien celui qui etait responsable de la regeneration observee sur la map actuelle.
- Angle mort : les valeurs de regeneration et de vol de vie devront etre reequilibrees avec les builds critiques, projectiles multiples et rebonds.

### Budget de complexite

- Complexite ajoutee : faible.
- Complexite restauree : la boucle de regeneration revient, mais elle est bornee par une stat de perk.
- Gain produit : le joueur peut obtenir regeneration et vol de vie comme deux choix distincts, sans soin gratuit hors perks.

## 2026-07-08 01:44:20 +02:00 - Interaction coffre et tirage slot V1

### Contexte

Un nouvel item 3D `Chest` a ete ajoute dans la map depuis Roblox Studio. Le besoin est d'avoir une interaction simple sans modifier la map par Rojo : un label discret au-dessus du coffre quand le joueur est proche, puis une ouverture avec animation type slot qui choisit un objet aleatoire temporaire.

### Changements

- `src/shared/ChestConfig.luau` ajoute la configuration du coffre : nom de l'asset, distances, duree de slot et recompenses temporaires.
- `src/server/ChestService.luau` detecte les instances nommees `Chest` dans `Workspace`.
- `src/server/ChestService.luau` cree les remotes `Chest_OpenRequest` et `Chest_OpenResult`.
- `src/server/ChestService.luau` valide cote serveur que le joueur est assez proche avant ouverture.
- `src/server/ChestService.luau` choisit aleatoirement le resultat du tirage.
- `src/client/ChestClient.client.luau` affiche un `BillboardGui` discret avec `E pour ouvrir` au-dessus du coffre proche.
- `src/client/ChestClient.client.luau` envoie la demande d'ouverture avec la touche `E`.
- `src/client/ChestClient.client.luau` affiche une petite UI de slot non bloquante avec le resultat.
- `src/server/GameManager.server.luau` demarre `ChestService`.

### Decisions

- Juste : le client ne choisit pas l'objet gagne ; il demande seulement l'ouverture et le serveur valide la distance.
- Juste : les objets gagnes ne sont pas encore appliques au joueur, car le systeme d'inventaire/equipement n'existe pas encore.
- Simplification : un coffre ouvert est marque ouvert via attributs repliques `ChestOpened` et `ChestOpening`, sans animation 3D du couvercle pour cette V1.
- Contestable : l'ouverture est globale au coffre. En multijoueur, le premier joueur a l'ouvrir le consomme pour tout le monde.

### Proof of done local

- Juste : `rojo build -o $env:TEMP\TestRoblox_chest_build.rbxlx` passe.
- Juste : `git diff --check` ne remonte que les avertissements CRLF habituels.

### Angles morts

- Angle mort : il faut verifier en Play que l'asset `Chest` expose bien au moins une `BasePart` detectable.
- Angle mort : il n'y a pas encore de recompense reelle, d'inventaire, de sons, ni d'animation 3D d'ouverture du coffre.
- Angle mort : si plusieurs coffres doivent etre ouvrables par joueur plutot que globalement, il faudra remplacer l'etat global `ChestOpened` par un etat par joueur.

### Budget de complexite

- Complexite ajoutee : faible a moyenne.
- Justification : le service est isole pour preparer les futurs objets sans melanger cette logique avec les pieces, l'XP ou les perks.
- Voie de simplification possible : garder seulement `Chest_OpenRequest` et retirer l'UI slot si le futur systeme d'objets impose une autre presentation.

## 2026-07-08 01:49:59 +02:00 - Correction detection coffre imbrique

### Contexte

Le coffre visible dans Studio est un asset imbrique : `Chest` contient un modele `Elegant Chest`, puis des parties nommees `Top` et `Meshes/...`. La V1 supposait trop fortement que l'instance nommee `Chest` etait directement un `Model` avec une `BasePart` deja disponible au moment du scan.

### Changements

- `src/client/ChestClient.client.luau` remonte maintenant depuis n'importe quel descendant vers le parent nomme `Chest`.
- `src/server/ChestService.luau` applique la meme resolution de coffre cote serveur.
- `src/client/ChestClient.client.luau` peut detecter un coffre quand les `MeshPart` arrivent apres le parent `Chest`.
- `src/server/ChestService.luau` accepte aussi une demande d'ouverture envoyee depuis un descendant du coffre.
- `src/shared/ChestConfig.luau` augmente legerement les distances d'affichage et d'ouverture pour rendre l'interaction moins stricte.
- `src/server/ChestService.luau` corrige une reference invalide a `instance` dans le calcul de position serveur.

### Decisions

- Juste : la racine gameplay reste l'objet nomme `Chest`, meme si le mesh reel est dans des enfants imbriques.
- Juste : la validation serveur reste obligatoire avant de lancer le tirage.
- Simplification : la distance utilise le centre du modele ou la premiere `BasePart` detectable, pas encore un vrai point le plus proche sur la surface du coffre.

### Proof of done local

- Juste : `rojo build -o $env:TEMP\TestRoblox_chest_detection_build.rbxlx` passe.
- Juste : `git diff --check` ne remonte que les avertissements CRLF habituels.

### Angles morts

- Angle mort : si l'asset `Chest` est place hors `Workspace`, il ne sera toujours pas detecte.
- Angle mort : si plusieurs objets differents sont nommes `Chest` dans une meme arborescence, seul le premier parent `Chest` sert de racine gameplay.

### Budget de complexite

- Complexite ajoutee : faible.
- Gain produit : l'interaction coffre devient compatible avec les assets 3D importes et imbriques.

## 2026-07-08 02:35:28 +02:00 - Coffres payants, choix joueur et pause

### Contexte

Les coffres doivent devenir une vraie interaction de run : ils s'ouvrent avec les coins ramasses, le prix augmente apres chaque ouverture, le jeu se met en pause pendant le tirage, puis le joueur choisit de passer ou valider. Le coffre doit disparaitre apres cette decision.

### Changements

- `src/shared/ChestConfig.luau` ajoute `BaseOpenCost = 5` et `OpenCostIncrease = 5`.
- `src/server/CoinService.luau` expose `GetCoins` et `TrySpendCoins` pour les depenses serveur.
- `src/server/ChestService.luau` conserve un prix de prochain coffre par joueur.
- `src/server/ChestService.luau` valide distance, disponibilite du coffre et solde de coins avant ouverture.
- `src/server/ChestService.luau` depense les coins uniquement apres validation serveur.
- `src/server/ChestService.luau` met le combat en pause pendant la boucle coffre via `CombatStateService`.
- `src/server/ChestService.luau` attend une decision `Accept` ou `Skip`.
- `src/server/ChestService.luau` detruit le coffre apres la decision du joueur.
- `src/client/ChestClient.client.luau` affiche le prix dans le prompt du coffre.
- `src/client/ChestClient.client.luau` ajoute les boutons `Passer` et `Valider`.
- `src/client/ChestClient.client.luau` garde l'UI ouverte apres le tirage jusqu'au choix joueur.
- `src/server/GameManager.server.luau` initialise `ChestService` apres chargement des coins du joueur.

### Decisions

- Juste : la depense de coins est serveur-authoritative.
- Juste : le coffre est consomme apres `Passer` comme apres `Valider`, car l'ouverture a deja ete payee.
- Juste : le prix augmente apres une ouverture acceptee par le serveur, pas apres un simple appui client.
- Simplification : `Valider` ne donne pas encore d'objet reel, car les objets/inventaire ne sont pas implementes.
- Contestable : le prix de prochain coffre est pour l'instant un etat de session joueur, pas une donnee persistante.

### Proof of done local

- Juste : `rojo build -o $env:TEMP\TestRoblox_chest_paid_choice_build.rbxlx` passe.
- Juste : `git diff --check` ne remonte que les avertissements CRLF habituels.

### Angles morts

- Angle mort : il faut tester en Play le cas avec assez de coins et le cas sans assez de coins.
- Angle mort : la recompense validee n'est pas encore appliquee au joueur.
- Angle mort : si le futur systeme de run remet les coins a zero par run, il faudra clarifier si le cout coffre consomme les coins persistants ou une monnaie temporaire de run.
- Angle mort : le coffre est detruit globalement. Cela convient a une run solo, mais pas a une arene multi partagee.

### Budget de complexite

- Complexite ajoutee : moyenne faible.
- Justification : le coffre devient un systeme interactif complet avec cout, pause et decision, mais reste isole de l'inventaire futur.
- Voie de simplification possible : retirer temporairement les boutons et auto-resoudre en `Valider` si la boucle coffre ralentit trop les tests de combat.

## 2026-07-08 04:11:35 +02:00 - Stabilisation boucle survivor sans quiz

### Contexte

Un audit externe a signale que l'ancien systeme de quiz restait actif et melangeait deux jeux : un quiz a manches et une boucle survivor-like. La direction produit clarifie que la V1 doit devenir lisible : spawn joueur, ennemis, arme auto, XP, level-up, choix de perk, reprise du combat. La generation procedurale, le boss, le lobby social et les microtransactions ne doivent pas etre ajoutes maintenant.

### Changements

- `src/shared/FeatureFlags.luau` ajoute les flags `QuizEnabled`, `AdminToolsEnabled` et `DebugUIEnabled`.
- `src/shared/FeatureFlags.luau` desactive le quiz par defaut avec `QuizEnabled = false`.
- `src/shared/FeatureFlags.luau` desactive le HUD debug par defaut avec `DebugUIEnabled = false`.
- `src/server/GameManager.server.luau` ne lance plus `RoundService.Start()` quand `QuizEnabled = false`.
- `src/server/GameManager.server.luau` ne cree plus le leaderstat `Score` quand le quiz est desactive.
- `src/client/UI.client.luau` ne se connecte plus aux remotes quiz quand le quiz est desactive.
- `src/client/UI.client.luau` conserve seulement l'affichage des coins.
- `src/client/AdminUI.client.luau` respecte `AdminToolsEnabled`.
- `src/client/DebugUI.client.luau` respecte `DebugUIEnabled`.
- `src/server/JumpBonusService.luau` ignore les anciens stacks de saut quiz quand `QuizEnabled = false`, tout en gardant le multiplicateur externe utilise par les perks.
- `src/server/CoinService.luau` ne persiste plus les coins : ils repartent a `0` au setup joueur pour cette V1 run/session.

### Decisions

- Juste : desactiver `RoundService.Start()` clarifie immediatement la boucle principale.
- Juste : garder les fichiers quiz sans les supprimer conserve une possibilite de rollback.
- Juste : les coins de run ne doivent pas etre une monnaie persistante.
- Simplification : les coins sont remis a zero au setup joueur, faute de vrai `RunService` mort/victoire/lobby pour l'instant.
- Contestable : `AdminToolsEnabled` reste `true` par defaut pour faciliter le stress test, meme si ce sont des outils debug.

### Proof of done local

- Juste : `rojo build -o $env:TEMP\TestRoblox_survivor_loop_build.rbxlx` passe.
- Juste : `git diff --check` ne remonte que les avertissements CRLF habituels.

### Angles morts

- Angle mort : XP, niveau, perks et coins ne sont pas encore resets sur une vraie fin de run mort/victoire.
- Angle mort : il n'existe pas encore de separation technique lobby/run.
- Angle mort : le leaderstat `Level` actuel represente encore le niveau de run, pas un niveau valide permanent.
- Angle mort : `MonsterMaxAlive = 1000` reste un plafond de stress test, pas une cible stable de gameplay.

### Budget de complexite

- Complexite reduite : l'ancien quiz ne s'execute plus dans la boucle principale.
- Complexite ajoutee : faible, via un module de flags.
- Gain produit : le Play Test doit maintenant lire comme une boucle survivor-like sans questions quiz parasites.

## 2026-07-08 04:23:48 +02:00 - Equilibrage CombatConfig V1

### Contexte

La boucle survivor est maintenant prioritaire. L'objectif de cette passe est de rendre le Play Test plus lisible sans ajouter de systeme : pression ennemie progressive, premier level-up plus rapide, Fireball plus reactive, coins de run un peu plus accessibles, et courbe normale moins agressive pour ne pas viser trop vite le plafond technique de `1000` ennemis.

### Changements

- `src/shared/CombatConfig.luau` retarde legerement le premier spawn ennemi avec `MonsterInitialSpawnDelay = 3.5`.
- `src/shared/CombatConfig.luau` rapproche un peu les spawns avec `MonsterMinSpawnDistance = 38` et `MonsterMaxSpawnDistance = 62`.
- `src/shared/CombatConfig.luau` ralentit la croissance des vagues : `WaveDuration = 45`, `WaveBaseMaxAlive = 10`, `WaveMaxAliveIncrease = 6`.
- `src/shared/CombatConfig.luau` ralentit la croissance des batches avec `WaveSpawnBatchIncreaseEvery = 3`.
- `src/shared/CombatConfig.luau` baisse les PV ennemis a `36`.
- `src/shared/CombatConfig.luau` baisse legerement la vitesse et les degats ennemis.
- `src/shared/CombatConfig.luau` rend la Fireball plus reactive : cooldown `0.95`, vitesse `100`, portee `90`, homing `6`.
- `src/shared/CombatConfig.luau` accelere le premier level-up : `LevelBaseXp = 6`, `LevelXpIncrease = 6`.
- `src/shared/CombatConfig.luau` augmente le rayon de collecte XP a `8`.
- `src/shared/CombatConfig.luau` augmente la chance de drop coin a `25%`.
- `src/shared/CombatConfig.luau` rend la fusion XP un peu plus large mais moins frequente : rayon `16`, scan `0.3`, groupes max `60`.
- `src/shared/CombatConfig.luau` reduit la distance de culling collectibles a `360`.

### Decisions

- Juste : `MonsterMaxAlive = 1000` reste un plafond technique/stress test, pas une cible de densite normale.
- Juste : le premier level-up doit arriver vite pour rendre la boucle XP/perk visible.
- Juste : la Fireball doit rester simple mais suffisamment reactive pour compenser le fait qu'il n'y a encore qu'une seule arme.
- Simplification : l'equilibrage est fait par valeurs fixes, sans scaling dynamique avance.
- Contestable : les coins de run restent lies au drop aleatoire simple, sans table de loot ni pity timer.

### Proof of done local

- Juste : `rojo build -o $env:TEMP\TestRoblox_combat_balance_build.rbxlx` passe.
- Juste : `git diff --check` ne remonte que les avertissements CRLF habituels.

### Angles morts

- Angle mort : l'equilibrage doit etre juge en Play Test sur des reperes temporels : 1 min, 3 min, 5 min et 8 min.
- Angle mort : `Monster1` peut rester trop lourd si les vagues depassent la capacite machine, meme avec une courbe plus lente.
- Angle mort : les perks `Plus d'ennemis`, projectiles multiples et rebonds peuvent rendre la charge tres differente d'une run a l'autre.
- Angle mort : le cout coffre devra etre re-teste apres le changement de drop coin.

### Budget de complexite

- Complexite ajoutee : nulle cote architecture.
- Complexite reduite : pression normale moins agressive, donc meilleure lisibilite du gameplay.
- Gain produit : la V1 doit laisser le joueur atteindre rapidement les premiers choix de perks sans etre submerge trop tot.

## 2026-07-08 04:48:50 +02:00 - HUD joueur MegaRoblox V1

### Contexte

La boucle survivor-like est lisible, mais le HUD joueur devait devenir plus propre et mieux oriente run. L'objectif de cette passe est de remplacer l'ancien affichage minimal par une interface compacte, lisible et plus expressive, sans reprendre le quiz et sans masquer le terrain de jeu.

### Changements

- `src/client/CombatUI.client.luau` devient le HUD principal de run.
- `src/client/CombatUI.client.luau` affiche les golds de run en haut a gauche.
- `src/client/CombatUI.client.luau` affiche un panneau survie en bas a gauche avec PV, bouclier si present, vague, kills, monstres vivants, arme active et compteur de stacks de perks.
- `src/client/CombatUI.client.luau` affiche une barre d'XP centrale basse avec niveau actuel et progression vers le niveau suivant.
- `src/client/CombatUI.client.luau` ajoute une petite jauge de menace liee au ratio ennemis vivants / ennemis max de vague.
- `src/client/CombatUI.client.luau` utilise des formes UI Roblox codees : panneaux, badges, gradients, contours et barres animees.
- `src/client/CombatUI.client.luau` ecoute maintenant `Coin_UpdateCount` et `Perk_UpdateStats` en plus de `Combat_UpdateStats` et `Xp_UpdateCount`.
- `src/client/CombatUI.client.luau` ajuste ses dimensions sur petits viewports.
- `src/client/UI.client.luau` quitte completement quand `QuizEnabled = false`, avant d'attendre les remotes de coins ou de creer l'ancien affichage quiz.

### Decisions

- Juste : le HUD de run doit etre porte par `CombatUI.client.luau`, pas par l'ancien script quiz.
- Juste : les golds affiches sont les golds de run actuels, coherents avec la decision de ne plus persister cette monnaie.
- Juste : aucun asset externe ou payant n'est ajoute ; les assets 2D de cette V1 sont crees avec les primitives UI Roblox.
- Contestable : l'identite visuelle `MegaRoblox` reste une premiere passe codee, sans bitmap importe ni vraie direction artistique definitive.
- Simplification : les armes et perks restent sous forme de labels/badges, pas encore sous forme d'inventaire complet avec quatre slots.

### Proof of done local

- Juste : `rojo build -o $env:TEMP\TestRoblox_hud_build.rbxlx` passe.
- Juste : `git diff --check` ne remonte que les avertissements CRLF habituels.

### Angles morts

- Angle mort : le rendu visuel doit encore etre juge en Play Test Roblox Studio, surtout sur petite resolution.
- Angle mort : la lisibilite mobile n'est pas garantie tant que le projet n'a pas de cible mobile stabilisee.
- Angle mort : le compteur de perks additionne les stacks, mais ne montre pas encore le detail des perks actifs.
- Angle mort : l'UI chest et l'UI perk ont encore leur propre style ; une passe HUD globale pourra les harmoniser plus tard.

### Budget de complexite

- Complexite ajoutee : moyenne cote client UI.
- Complexite reduite : les informations de run sont regroupees dans un seul HUD principal au lieu d'etre dispersees entre l'ancien quiz et le combat.
- Gain produit : le joueur lit plus vite sa survie, son XP, ses golds, sa vague et sa progression sans perdre le controle visuel de l'arene.
