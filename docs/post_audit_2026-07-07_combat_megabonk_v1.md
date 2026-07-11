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

## 2026-07-08 10:42:49 +02:00 - Arborescence templates/runtime et PerkShrine V1

### Contexte

Les templates places dans `Workspace` finissent par exister comme objets reels de la map : ils peuvent etre visibles, repliques, detectes par les scripts, touches par des raycasts ou pris pour des objets runtime. La passe separe donc clairement les sources serveur et les objets actifs, puis ajoute une premiere generation d'autel de perk.

### Changements

- `src/server/TemplateService.luau` centralise la creation des dossiers de templates et de runtime.
- `src/server/TemplateService.luau` cree ou reutilise `ServerStorage/CombatTemplates`, `ServerStorage/CollectibleTemplates`, `ServerStorage/ShrineTemplates`, `ServerStorage/MapTemplates` et `ServerStorage/ChestTemplates`.
- `src/server/TemplateService.luau` cree ou reutilise `Workspace/CombatRuntime`, `Workspace/CombatRuntime/Monsters`, `Workspace/CombatRuntime/Projectiles`, `Workspace/CombatRuntime/Loot`, `Workspace/ShrinesRuntime` et `Workspace/MapRuntime`.
- `src/server/TemplateService.luau` cherche les templates en priorite dans `ServerStorage`.
- `src/server/TemplateService.luau` garde une compatibilite temporaire : un template trouve dans `Workspace` est deplace vers le bon dossier `ServerStorage` avec un warning explicite.
- `src/server/MonsterService.luau`, `src/server/WeaponService.luau`, `src/server/CoinService.luau` et `src/server/XpService.luau` utilisent maintenant `TemplateService` pour recuperer leurs templates.
- `src/shared/ShrineConfig.luau` ajoute la configuration V1 des autels de perk.
- `src/server/ShrineService.luau` clone `ServerStorage/ShrineTemplates/PerkShrine` dans `Workspace/ShrinesRuntime`.
- `src/server/ShrineService.luau` cache `Bubble` au spawn, l'affiche pendant la charge, puis la cache quand l'autel devient inactif.
- `src/server/ShrineService.luau` ajoute un `ProximityPrompt` maintenu sur `E` pour charger l'autel.
- `src/server/ShrineService.luau` declenche un choix de perk bonus via `PerkService.QueueBonusChoice`.
- `src/server/PerkService.luau` expose une petite API `QueueBonusChoice` sans modifier la table des perks ni la logique d'application des choix.
- `src/client/PerkUI.client.luau` accepte un titre optionnel pour afficher `Autel de perk` au lieu de forcer un titre de niveau.
- `src/server/GameManager.server.luau` demarre `TemplateService` puis `ShrineService`.

### Decisions

- Juste : `Workspace` reste le lieu des objets actifs, pas le lieu principal des templates source.
- Juste : la migration temporaire depuis `Workspace` est volontairement accompagnee d'un warning pour signaler les templates encore mal ranges dans Studio.
- Juste : `default.project.json` n'est pas modifie, car les assets 3D restent geres dans Roblox Studio et Rojo ne sert ici qu'aux scripts.
- Juste : les collectibles runtime continuent d'aller dans `Workspace/CombatRuntime/Loot`, mais leurs sources viennent de `ServerStorage/CollectibleTemplates`.
- Contestable : `ChestTemplates` est cree pour preparer la suite, mais les coffres deja presents en scene restent consideres comme objets actifs tant qu'il n'existe pas encore de generateur de coffres.
- Simplification : la V1 genere un seul autel de perk initial autour du joueur, pas encore un reseau procedural d'autels.

### Proof of done local

- Juste : `rojo build -o $env:TEMP\TestRoblox_templates_shrines_build.rbxlx` passe.
- Juste : `git diff --check` ne remonte que les avertissements CRLF habituels.

### Angles morts

- Angle mort : le deplacement reel des instances Studio vers `ServerStorage` se fait au lancement serveur, pas en mode edition Studio avant Play.
- Angle mort : si `PerkShrine` ne contient aucune `BasePart`, le service ne pourra pas la generer.
- Angle mort : si `Bubble` n'est pas enfant de `PerkShrine`, le service tente de rattacher une `Bubble` trouvee dans `Workspace`, mais il faut quand meme verifier la hierarchie propre dans Studio.
- Angle mort : le placement de l'autel utilise un raycast autour du joueur ; il faudra l'adapter quand la generation procedurale de map arrivera.
- Angle mort : la pause reste celle du choix de perk, pas de la charge de l'autel.

### Budget de complexite

- Complexite ajoutee : moyenne, car un service de structure et un service interactable sont ajoutes.
- Complexite reduite : la recherche de templates n'est plus dupliquee dans chaque service gameplay.
- Gain produit : la scene devient plus lisible et les sources `Monster1`, `Monster3`, `Fireball`, `Coin`, `XpGem*` et `PerkShrine` ne doivent plus rester actifs dans `Workspace` par accident.

## 2026-07-08 10:58:45 +02:00 - Correction ancrage sol PerkShrine

### Contexte

La `PerkShrine` se genere correctement avec sa bulle et son interaction, mais son placement peut etre influence par `Bubble` ou `ChargePart`. Le resultat observe est une shrine trop haute, comme si le contact au sol etait calcule depuis un enfant utilitaire au lieu du corps reel de l'autel.

### Changements

- `src/server/ShrineService.luau` exclut maintenant `Bubble` et `ChargePart` du choix de racine de placement.
- `src/server/ShrineService.luau` calcule le bas de la shrine uniquement avec les `BasePart` utiles au contact au sol.
- `src/server/ShrineService.luau` garde un fallback sur le bounding box global si aucun morceau exploitable n'est trouve.

### Decisions

- Juste : `Bubble` est un feedback visuel de charge, pas une piece de placement.
- Juste : `ChargePart` est une zone d'interaction invisible, pas une piece de placement.
- Simplification : le calcul utilise les parties solides/visuelles du modele sans imposer une PrimaryPart parfaite dans Studio.

### Proof of done local

- Juste : `rojo build -o $env:TEMP\TestRoblox_shrine_grounding_build.rbxlx` passe.
- Juste : `git diff --check` ne remonte que les avertissements CRLF habituels.

### Angles morts

- Angle mort : si le modele visuel de la shrine contient des pieces decoratives tres basses, elles determineront le contact au sol.
- Angle mort : le rendu final doit etre verifie en Play Test, car la geometrie exacte du modele Studio n'est pas visible depuis les fichiers Rojo.

### Budget de complexite

- Complexite ajoutee : faible.
- Gain produit : la shrine doit maintenant toucher le sol avec son corps reel, sans etre surelevee par la bulle ou la zone de charge.

## 2026-07-08 11:02:45 +02:00 - Audio interaction PerkShrine

### Contexte

Deux sons du catalogue Roblox doivent accompagner l'interaction avec la shrine : un son pendant le chargement et un son bref de fin de chargement. L'audio doit rester attache a l'autel dans le monde, pas au HUD.

### Changements

- `src/shared/ShrineConfig.luau` ajoute `ChargeSoundId`, `ChargeSoundVolume`, `ChargeSoundMaxDistance`, `CompleteSoundId`, `CompleteSoundVolume` et `CompleteSoundMaxDistance`.
- `src/server/ShrineService.luau` cree un `Sound` boucle nomme `ShrineChargeSound` sur la partie du `ProximityPrompt`.
- `src/server/ShrineService.luau` cree un `Sound` non boucle nomme `ShrineCompleteSound` sur la partie du `ProximityPrompt`.
- `src/server/ShrineService.luau` lance le son de charge au debut du maintien de `E`.
- `src/server/ShrineService.luau` stoppe le son de charge si le joueur relache avant la fin.
- `src/server/ShrineService.luau` stoppe le son de charge et joue le son de fin quand la shrine est chargee avec succes.

### Decisions

- Juste : les sons sont spatialises sur la shrine, donc ils suivent l'objet monde.
- Juste : les IDs vides ne jouent rien, ce qui permet de garder le systeme actif sans asset configure.
- Simplification : les IDs audio restent dans `ShrineConfig` pour cette V1, pas encore dans des attributs Studio par shrine.

### Proof of done local

- Juste : `rojo build -o $env:TEMP\TestRoblox_shrine_audio_build.rbxlx` passe.
- Juste : `git diff --check` ne remonte que les avertissements CRLF habituels.

### Angles morts

- Angle mort : les assets audio du catalogue doivent etre autorises par Roblox pour l'experience, sinon le code joue le son mais Roblox peut le bloquer.
- Angle mort : l'equilibrage du volume et de la distance doit etre juge en Play Test.

### Budget de complexite

- Complexite ajoutee : faible.
- Gain produit : l'interaction shrine donne maintenant un feedback sonore pendant la charge et au moment de la validation.

## 2026-07-08 11:13:54 +02:00 - Spawn anticipe PerkShrine

### Contexte

La shrine apparaissait apres un delai proche de la securite utilisee pour les monstres. Cette securite est utile pour eviter des spawns ennemis pendant que le joueur tombe ou n'a pas encore touche le sol, mais elle ne doit pas retarder un interactable statique comme la `PerkShrine`.

### Changements

- `src/shared/ShrineConfig.luau` reduit `InitialSpawnDelay` a `0.25`.
- `src/shared/ShrineConfig.luau` ajoute `SpawnRootWaitTimeout` et `SpawnRootWaitInterval`.
- `src/server/ShrineService.luau` attend seulement que le joueur ait un `HumanoidRootPart` avant de tenter le spawn.
- `src/shared/CombatConfig.luau` conserve `MonsterSpawnGroundedDelay = 3` pour les monstres.

### Decisions

- Juste : le delai de sol appartient au spawn des mobs, pas aux shrines.
- Juste : attendre la racine du personnage reste necessaire pour placer la shrine autour du joueur.
- Simplification : la shrine ne verifie pas encore que le joueur est pose au sol ; le raycast de placement suffit pour cette V1.

### Proof of done local

- Juste : `rojo build -o $env:TEMP\TestRoblox_shrine_early_spawn_build.rbxlx` passe.
- Juste : `git diff --check` ne remonte que les avertissements CRLF habituels.

### Angles morts

- Angle mort : si le personnage met plus de `2` secondes a obtenir son `HumanoidRootPart`, la shrine ne sera pas generee sur cette tentative.
- Angle mort : sur une future generation procedurale, le spawn de shrine devra attendre que la map runtime autour du joueur existe.

### Budget de complexite

- Complexite ajoutee : faible.
- Gain produit : la shrine devient disponible avant la premiere pression ennemie, ce qui clarifie le rythme de debut de run.

## 2026-07-08 11:31:59 +02:00 - Passe debug console structuree V1

### Contexte

La `PerkShrine` ne spawn plus de maniere visible en Play Test, et les retours disponibles reposent trop sur l'observation visuelle ou la supposition. Le besoin de cette passe est de rendre la console Studio exploitable : savoir quels services demarrent, ou les templates sont cherches, si les dossiers runtime existent, pourquoi une shrine ne spawn pas, et quels evenements client/serveur circulent reellement.

### Changements

- `src/shared/DebugConfig.luau` ajoute une configuration centrale des logs console.
- `src/shared/DebugLog.luau` ajoute un logger structure avec categories, contexte serialise et logs throttles.
- Les lignes de debug utilisent le prefixe stable `[MegaRoblox][LEVEL][Categorie]`.
- `src/server/TemplateService.luau` log la creation des dossiers, la migration des templates et les fallbacks.
- `src/server/GameManager.server.luau` log le demarrage des services, les feature flags et le setup/remove joueur.
- `src/server/ShrineService.luau` log le cycle complet de shrine : template, bulle, audio, planification, racine joueur, tentatives de spawn, raycast sans surface, generation, charge et validation.
- `src/server/ShrineService.luau` ajoute une logique de retry courte pour le spawn initial de shrine afin de ne pas perdre la tentative si la racine joueur ou la map runtime arrivent juste apres.
- `src/server/MonsterService.luau`, `src/server/WeaponService.luau`, `src/server/XpService.luau`, `src/server/CoinService.luau`, `src/server/ChestService.luau`, `src/server/PerkService.luau`, `src/server/AdminService.luau`, `src/server/CombatStateService.luau` et `src/server/JumpBonusService.luau` utilisent maintenant `DebugLog` sur leurs transitions importantes.
- Les scripts client principaux log leurs initialisations et les evenements utiles : HUD combat, UI admin, UI debug, UI quiz, UI coffre, animation collectibles et choix de perks.
- `src/shared/Hello.luau` ne produit plus de `print("Hello, world!")` non structure.

### Decisions

- Juste : un logger centralise est plus utile que des `print` disperses, car il donne une categorie, un niveau et un contexte lisible.
- Juste : les logs frequents comme les spawns de mobs, tirs, collectes et fusions XP sont throttles pour eviter de noyer l'Output Studio.
- Juste : les logs de shrine ne sont pas trop throttles, car c'est precisement le chantier bloque.
- Simplification : il n'y a pas encore de panneau de logs en jeu ni d'export automatique ; la source de verite reste l'Output Studio.
- Contestable : `ConsoleEnabled = true` par defaut est pratique en developpement, mais devra etre desactive ou filtre avant une publication publique.

### Proof of done local

- Juste : `rojo build -o $env:TEMP\TestRoblox_console_debug_build.rbxlx` passe.
- Juste : `git diff --check` ne remonte que les avertissements CRLF habituels.
- Juste : `rg -n "warn\\(|print\\(" src/server src/client src/shared` ne trouve plus que les appels internes de `DebugLog`.

### Angles morts

- Angle mort : Rojo build ne remplace pas un vrai Play Test Studio ; il valide la structure projet mais pas toutes les erreurs runtime Luau.
- Angle mort : si Studio contient encore un `Script` manuel dans `Workspace` qui imprime `Hello world`, ce bruit ne vient pas de Rojo et doit etre retire dans Studio, pas dans `src`.
- Angle mort : les assets audio peuvent encore etre refuses par Roblox si les permissions du son ne sont pas compatibles avec l'experience.
- Angle mort : si aucun log `[MegaRoblox][INFO][Shrine] PerkShrine generee` n'apparait, il faudra lire les logs `[Templates]` et `[Shrine]` precedents pour savoir si le probleme vient du template, du joueur, du raycast ou de la limite de spawn.

### Budget de complexite

- Complexite ajoutee : moyenne, car un systeme de logs transverse est ajoute.
- Complexite reduite : les futurs retours Play Test pourront s'appuyer sur des faits console au lieu de deviner depuis l'image.
- Gain produit : le prochain diagnostic shrine/combat devrait etre beaucoup plus court et plus fiable.

## 2026-07-08 11:42:12 +02:00 - Generation repartie shrines et coffres V1

### Contexte

Les logs du Play Test montrent que la shrine fonctionne bien : template trouve, instance generee, charge detectee, choix de perk affiche, perk applique et reprise du combat. Le probleme n'est donc plus un blocage de service, mais un besoin de densite et de repartition dans l'espace de jeu. La V1 doit generer 15 `PerkShrine` et 30 `Chest` sur le sol disponible, sans modifier la map Studio.

### Changements

- `src/server/WorldSpawnService.luau` ajoute un module serveur de placement par raycast sur surface.
- `src/server/WorldSpawnService.luau` repartit les positions avec une distribution en spirale/jitter, une distance minimale et un filtre de surface.
- `src/server/WorldSpawnService.luau` exclut les personnages et les dossiers runtime dynamiques des raycasts.
- `src/server/WorldSpawnService.luau` rejette les surfaces trop verticales et les noms configures comme `MurInvisible`.
- `src/shared/ShrineConfig.luau` passe `InitialSpawnCount` a `15`.
- `src/shared/ShrineConfig.luau` remplace les anciens reglages de spawn pres du joueur par des reglages de spawn monde.
- `src/server/ShrineService.luau` genere maintenant les shrines en une passe initiale repartie dans `Workspace/ShrinesRuntime`.
- `src/shared/ChestConfig.luau` ajoute `TemplateFolderName`, `RuntimeFolderName` et les reglages de generation de 30 coffres.
- `src/server/ChestService.luau` recupere `ServerStorage/ChestTemplates/Chest`, clone les coffres dans `Workspace/ChestsRuntime`, puis les tracke comme coffres ouvrables.
- `src/server/ChestService.luau` cree un fallback visuel simple si aucun template `Chest` n'est trouve.
- `src/server/TemplateService.luau` gere maintenant `ChestTemplates` et `ChestsRuntime`, avec migration temporaire depuis `Workspace`.
- `src/server/GameManager.server.luau` demarre `PerkService`, puis `ShrineService`, puis `ChestService` afin que les coffres puissent eviter les shrines deja placees.

### Decisions

- Juste : le log prouve que la shrine n'etait pas cassee ; elle etait generee et validait bien un choix de perk.
- Juste : le placement monde doit etre independant du joueur, contrairement aux monstres qui restent lies au joueur.
- Juste : les templates restent dans `ServerStorage`, les instances jouables vont dans `Workspace`.
- Juste : `MurInvisible` est exclu du placement afin d'eviter les spawns sur les murs invisibles.
- Simplification : il n'y a pas encore de generateur procedural de map ; on echantillonne le sol existant par raycast.
- Contestable : les rayons de spawn sont centres sur `(0, 0, 0)`, ce qui est adapte a la map actuelle mais devra devenir un contrat de run/map plus tard.

### Proof of done local

- Juste : `rojo build -o $env:TEMP\TestRoblox_interactables_spawn_build.rbxlx` passe.
- Juste : `git diff --check` ne remonte que les avertissements CRLF habituels.
- Juste : `rg -n "warn\\(|print\\(" src/server src/client src/shared` ne trouve plus que les appels internes de `DebugLog`.

### Angles morts

- Angle mort : la distribution reelle doit etre jugee en Play Test, car elle depend de la geometrie Studio effective.
- Angle mort : si moins de 15 shrines ou 30 coffres apparaissent, les logs `Placement surface incomplet` indiqueront si le rayon, la distance minimale ou les surfaces rejetees sont trop restrictifs.
- Angle mort : la generation est encore globale a la session serveur, pas rattachee a une instance de run solo.
- Angle mort : les coffres generes coutent les coins de run actuels ; l'economie coffre devra etre re-equilibree quand les recompenses reelles existeront.

### Budget de complexite

- Complexite ajoutee : moyenne, avec un module de placement reutilisable.
- Complexite reduite : les futurs interactables pourront reutiliser `WorldSpawnService` au lieu de recreer un raycast de sol specifique.
- Gain produit : la map contient maintenant plusieurs objectifs optionnels visibles/repartis, ce qui rapproche la boucle du survivor-like vise.

## 2026-07-08 11:51:04 +02:00 - Validation Play Test generation interactables

### Contexte

Un Play Test d'environ quatre minutes confirme que la generation repartie des shrines et coffres fonctionne dans Studio. Cette entree documente la validation utilisateur et les preuves console observees.

### Preuves observees

- Juste : les logs indiquent `Placement surface pret` avec `Placed=15` pour les shrines.
- Juste : les logs indiquent `Generation shrines initiale terminee` avec `SpawnedCount=15`.
- Juste : les logs indiquent `Placement surface pret` avec `Placed=30` pour les coffres.
- Juste : les coffres sont generes dans `Workspace.ChestsRuntime`.
- Juste : un coffre a ete ouvert avec depense de coins, pause combat, animation client, validation de recompense et reprise combat.
- Juste : le cout de coffre augmente bien apres ouverture : exemple observe `Cost=10`, puis `NextOpenCost=15`.
- Juste : la boucle combat continue ensuite : monstres, projectiles, XP, coins et vagues restent actifs.

### Angles morts restants

- Angle mort : le `Hello world! - Serveur - Script:1` vient encore d'un `Script` manuel dans Studio, hors Rojo.
- Angle mort : la validation porte sur la map actuelle ; une future generation procedurale devra reprendre le centre/rayon de placement comme contrat de run.
- Angle mort : les recompenses de coffre restent des placeholders non appliques au gameplay.

### Verdict

- Juste : le palier `15 shrines + 30 coffres runtime repartis sur sol disponible` est valide en Play Test Studio.

## 2026-07-08 11:59:37 +02:00 - Jarres cassables V1

### Contexte

Un nouvel element `Jar` est ajoute dans Studio. Les jarres doivent etre cassables instantanement avec `E` et pouvoir laisser au sol de l'XP, de l'or ou les deux.

### Changements

- `src/shared/JarConfig.luau` ajoute la configuration V1 des jarres.
- `src/server/JarService.luau` tracke les instances actives nommees `Jar` dans `Workspace`.
- `src/server/JarService.luau` ajoute un `ProximityPrompt` serveur instantane sur `E`.
- `src/server/JarService.luau` valide cote serveur que le joueur est assez proche et que la jarre n'est pas deja cassee.
- `src/server/JarService.luau` detruit la jarre apres interaction validee.
- `src/server/JarService.luau` choisit un drop pondere : XP, coin ou les deux.
- `src/server/JarService.luau` utilise `XpService.SpawnXpGem` et `CoinService.SpawnCoin` pour rester coherent avec les collectibles existants.
- `src/server/JarService.luau` pose les drops par raycast sur la surface sous la jarre.
- `src/server/TemplateService.luau` cree aussi `ServerStorage/JarTemplates` et `Workspace/JarsRuntime` pour preparer le rangement propre.
- `src/server/GameManager.server.luau` demarre `JarService` apres `CoinService` et `XpService`.

### Decisions

- Juste : la casse de jarre reste serveur-autoritaire ; le client ne decide ni du drop ni de la destruction.
- Juste : la V1 ne pause pas le combat, contrairement aux coffres.
- Juste : les drops reutilisent les services XP/coin existants, donc ils profitent deja de l'attraction, du culling et du HUD.
- Simplification : pas d'animation de casse ni de fragments physiques pour cette V1.
- Contestable : aucune generation automatique de jarres n'est ajoutee tant qu'un nombre cible n'est pas demande.

### Proof of done local

- Juste : `rojo build -o $env:TEMP\TestRoblox_jar_breakables_build.rbxlx` passe.
- Juste : `git diff --check` ne remonte que les avertissements CRLF habituels.

### Angles morts

- Angle mort : pour cette V1, une jarre visible et active doit etre dans `Workspace`, par exemple `Workspace/JarsRuntime/Jar` ou dans la map active.
- Angle mort : si `Jar` est seulement rangee comme template source dans `ServerStorage/JarTemplates`, elle ne sera pas visible et donc pas cassable tant qu'un generateur de jarres n'existe pas.
- Angle mort : les chances et quantites de drop devront etre equilibrees apres Play Test.

### Budget de complexite

- Complexite ajoutee : faible a moyenne, avec un service interactable dedie.
- Complexite reduite : les jarres evitent de reutiliser le systeme coffre, qui a des responsabilites differentes.
- Gain produit : la run gagne un interactable instantane, lisible et compatible avec l'economie XP/or actuelle.

## 2026-07-08 12:02:59 +02:00 - Generation runtime des jarres

### Contexte

La V1 precedente rendait les instances `Jar` actives cassables, mais ne les generait pas automatiquement. Pour aligner les jarres avec les shrines et coffres, le service doit cloner un template source et placer 40 jarres runtime sur le sol disponible.

### Changements

- `src/shared/JarConfig.luau` ajoute `InitialSpawnCount = 40`.
- `src/shared/JarConfig.luau` ajoute les reglages de placement monde des jarres.
- `src/server/TemplateService.luau` migre maintenant `Jar` vers `ServerStorage/JarTemplates` si le template est encore dans `Workspace`.
- `src/server/JarService.luau` recupere `ServerStorage/JarTemplates/Jar`.
- `src/server/JarService.luau` clone les jarres dans `Workspace/JarsRuntime`.
- `src/server/JarService.luau` repartit les jarres avec `WorldSpawnService`, en evitant les shrines et coffres deja places.
- `src/server/JarService.luau` cree un fallback simple si aucun template `Jar` n'est trouve.

### Decisions

- Juste : les jarres suivent maintenant le meme contrat source/runtime que coffres et shrines.
- Juste : les jarres restent des interactables instantanes sans pause combat.
- Simplification : la generation est globale et initiale, pas encore rattachee a une instance de run.

### Proof of done local

- Juste : `rojo build -o $env:TEMP\TestRoblox_jar_generation_build.rbxlx` passe.
- Juste : `git diff --check` ne remonte que les avertissements CRLF habituels.
- Juste : `rg -n "warn\\(|print\\(" src/server src/client src/shared` ne trouve plus que les appels internes de `DebugLog`.

### Angles morts

- Angle mort : la distribution exacte doit etre validee en Play Test avec les logs `Placement surface pret` et `Generation jarres initiale terminee`.
- Angle mort : si moins de 40 jarres apparaissent, il faudra ajuster rayon, distance minimale ou surfaces rejetees dans `JarConfig`.

## 2026-07-08 12:08:01 +02:00 - Validation Play Test jarres, coffres et shrines

### Contexte

Un Play Test Studio d'environ une minute a ete fourni apres l'ajout de la generation runtime des jarres. L'objectif etait de verifier que la scene genere bien les interactables attendus et que les jarres cassables produisent des drops exploitables.

### Observations logs

- Juste : `GameManager` demarre avec `QuizEnabled=false`, donc l'ancien quiz reste bien hors boucle principale.
- Juste : `ShrineService` genere `15` shrines, avec `Generation shrines initiale terminee | {Requested=15, SpawnedCount=15}`.
- Juste : `ChestService` genere `30` coffres, avec `Generation coffres initiale terminee | {Requested=30, SpawnedCount=30}`.
- Juste : `JarService` genere `40` jarres, avec `Generation jarres initiale terminee | {Requested=40, SpawnedCount=40}`.
- Juste : plusieurs jarres sont cassees pendant le test et produisent bien les trois cas attendus : `Coin`, `Xp` et `Both`.
- Juste : les drops de jarre passent par `CoinService` et `XpService`, puis sont collectes par le joueur.
- Juste : les refus d'ouverture coffre observes sont des refus metier normaux : le joueur n'avait pas assez de coins pour le prochain cout.

### Verdict

- Juste : le palier `15 shrines + 30 coffres + 40 jarres` est valide en Play Test Studio.
- Juste : la boucle jarre V1 est validee : interaction `E`, destruction, drop, collecte et mise a jour economie runtime.
- Contestable : le cout croissant des coffres fonctionne techniquement, mais son rythme devra etre equilibre quand l'economie de run sera plus stable.

### Angles morts

- Angle mort : la validation porte sur un seul joueur en Studio, pas encore sur une run longue avec forte densite de monstres.
- Angle mort : les jarres n'ont pas encore d'effet visuel de casse, de son ou de feedback HUD dedie.
- Angle mort : la distribution spatiale est validee fonctionnellement, mais pas encore jugee comme interessante pour le flow de navigation.

## 2026-07-08 13:57:14 +02:00 - Equilibrage difficulte combat V1

### Contexte

Avec les coffres, les jarres et le leveling, la boucle de run devient trop permissive. L'objectif est d'augmenter la difficulte dans le temps sans modifier les attributs de `Monster1`, afin de garder ce monstre comme reference stable et de preparer l'ajout futur d'autres ennemis.

### Point d'impact

- Juste : `src/shared/CombatConfig.luau` est un fichier partage lu par combat, armes, XP, coins et templates.
- Juste : la passe ne modifie que les parametres de pression ennemie.
- Juste : `src/server/MonsterService.luau` est le seul service dont la logique change.
- Juste : les stats de `Monster1` restent inchangees : vie, vitesse, degats, portee et cooldown d'attaque.

### Changements

- `src/shared/CombatConfig.luau` ajoute une fenetre calme de `20` secondes.
- `src/shared/CombatConfig.luau` limite cette fenetre calme a `6` ennemis vivants.
- `src/shared/CombatConfig.luau` rend les vagues plus courtes : `30` secondes au lieu de `45`.
- `src/shared/CombatConfig.luau` augmente plus vite le plafond d'ennemis vivants par vague.
- `src/shared/CombatConfig.luau` ajoute une reduction progressive de l'intervalle de spawn.
- `src/shared/CombatConfig.luau` ajoute un intervalle minimum de spawn pour eviter une derive infinie.
- `src/shared/CombatConfig.luau` ajoute un plafond de taille de batch.
- `src/server/MonsterService.luau` applique dynamiquement le plafond calme, l'intervalle de spawn courant et le batch courant.

### Decisions

- Juste : la difficulte augmente par densite et cadence, pas par buff invisible de `Monster1`.
- Juste : le debut reste lisible pour laisser le joueur comprendre la run et trouver les premiers interactables.
- Simplification : aucune table multi-ennemis n'est ajoutee maintenant ; les futurs monstres seront un chantier separe.
- Contestable : le plafond theorique `MonsterMaxAlive = 1000` reste present pour debug, mais la courbe reelle ne doit pas chercher a l'atteindre rapidement.

### Proof of done local

- Juste : `rojo build -o $env:TEMP\TestRoblox_difficulty_curve_build.rbxlx` passe.
- Juste : `git diff --check -- src/shared/CombatConfig.luau src/server/MonsterService.luau` ne remonte que les avertissements CRLF habituels.

### Angles morts

- Angle mort : la sensation exacte doit etre validee en Play Test, surtout autour de 20, 60 et 120 secondes.
- Angle mort : le nouveau rythme peut rendre les coffres moins accessibles si la pression arrive trop vite.
- Angle mort : cette V1 ne separe pas encore les runs par instance joueur ; la pause globale reste une dette connue.

### Rollback conceptuel

- Revenir a l'ancien ressenti revient a remettre `MonsterSpawnInterval = 2.2`, `WaveDuration = 45`, `WaveBaseMaxAlive = 10`, `WaveMaxAliveIncrease = 6` et `WaveSpawnBatchIncreaseEvery = 3`, puis a ignorer les nouveaux champs de courbe.

## 2026-07-08 16:10:08 +02:00 - Pause joueur et distances interactables

### Contexte

Les coffres et jarres pouvaient etre actives a une distance trop confortable, ce qui affaiblissait la lecture physique des interactables. En parallele, les pauses de combat arretaient les systemes serveur, mais le joueur pouvait encore se deplacer. L'objectif est de rendre les interactions plus proches et de centraliser une vraie pause joueur.

### Point d'impact

- Juste : `src/shared/ChestConfig.luau` et `src/shared/JarConfig.luau` changent uniquement les distances d'interaction.
- Juste : `src/server/CombatStateService.luau` devient responsable du verrouillage mouvement pendant toute pause de combat.
- Juste : `src/client/CombatUI.client.luau` ajoute seulement le bouton UI de pause et son etat visuel.
- Juste : les ouvertures de coffre, choix de perk et pause utilisateur passent par le meme rail serveur de pause.

### Changements

- `ChestConfig.PromptDistance` passe a `7`.
- `ChestConfig.OpenDistance` passe a `7.5`.
- `ChestConfig.PromptMaxDistance` passe a `16`.
- `JarConfig.BreakDistance` passe a `5`.
- `JarConfig.BreakValidationTolerance` ajoute une tolerance serveur de `0.75`.
- `JarService` utilise maintenant cette tolerance au lieu d'un bonus fixe de `2` studs.
- `CombatStateService` cree les remotes `Combat_TogglePause` et `Combat_PauseState`.
- `CombatStateService` verrouille `WalkSpeed`, `JumpPower`, `JumpHeight`, `Jump` et `AutoRotate` pendant les pauses.
- `CombatStateService` conserve les changements de mouvement recus pendant une pause, afin que les perks de vitesse ou de saut ne soient pas perdus a la reprise.
- `CombatUI` ajoute un bouton pause `||` a cote du compteur d'or de run.
- `CombatUI` affiche `>` quand la pause utilisateur est active et bloque le bouton quand une autre pause systeme est deja active.

### Decisions

- Juste : la pause reste serveur-autoritaire ; le client demande seulement un toggle.
- Juste : une pause utilisateur n'est pas empilee au-dessus d'une pause coffre/perk deja active.
- Simplification : pas de menu pause complet pour l'instant ; le bouton est un interrupteur minimal.
- Contestable : le verrouillage mouvement agit sur tous les joueurs parce que les runs ne sont pas encore instanciees par joueur.

### Proof of done local

- Juste : `rojo build -o $env:TEMP\TestRoblox_pause_interactions_build.rbxlx` passe.
- Juste : `git diff --check -- src/shared/ChestConfig.luau src/shared/JarConfig.luau src/server/JarService.luau src/server/CombatStateService.luau src/client/CombatUI.client.luau` ne remonte que les avertissements CRLF habituels.

### Angles morts

- Angle mort : la sensation exacte des distances doit etre validee en Play Test sur les assets reels `Chest` et `Jar`, car leurs pivots et tailles influencent la distance ressentie.
- Angle mort : la pause globale reste acceptable en run solo, mais devra devenir une pause par run quand lobby et runs instanciees coexisteront.
- Angle mort : le bouton pause n'ouvre pas encore d'ecran de menu ; il suspend seulement le gameplay.

### Rollback conceptuel

- Revenir au comportement precedent revient a remettre `ChestConfig.PromptDistance = 18`, `ChestConfig.OpenDistance = 20`, `ChestConfig.PromptMaxDistance = 40`, `JarConfig.BreakDistance = 10`, puis a ignorer les remotes `Combat_TogglePause` et `Combat_PauseState`.

## 2026-07-08 16:31:18 +02:00 - Portail boss, shrines speciales et magnetisme global

### Contexte

De nouveaux templates Studio ont ete ajoutes : `PortalBoss`, `EliteChallengeShrine` et `MagnetShrine`. Le besoin est de les integrer dans la generation runtime sans encore ouvrir le chantier boss ou ennemis elites. Le magnet doit en revanche avoir un premier comportement jouable : attirer l'XP et les coins de toute la map vers le joueur.

### Point d'impact

- Juste : `PortalService` est isole, car le portail boss n'a pas encore d'interaction.
- Juste : `ShrineService` devient le rail commun des shrines activables : perk, elite placeholder et magnet.
- Juste : `XpService` et `CoinService` exposent maintenant une collecte globale serveur-autoritaire.
- Juste : `CombatUI` deplace l'or de run et le bouton pause/play vers le haut-centre.
- Contestable : `MagnetInitialSpawnCount = 3` est un choix V1 conservateur, car l'effet est tres fort.

### Changements

- `src/shared/PortalConfig.luau` ajoute la configuration du portail boss.
- `src/server/PortalService.luau` genere `1` instance `PortalBoss` dans `Workspace/PortalsRuntime`.
- `src/server/GameManager.server.luau` demarre `PortalService` avant `ShrineService`.
- `src/server/TemplateService.luau` gere `ServerStorage/PortalBossTemplate` et `Workspace/PortalsRuntime`.
- `src/server/TemplateService.luau` migre aussi `EliteChallengeShrine` et `MagnetShrine` vers `ServerStorage/ShrineTemplates`.
- `src/shared/ShrineConfig.luau` ajoute les templates et compteurs des shrines speciales.
- `src/server/ShrineService.luau` genere maintenant :
  - `15` shrines de perk ;
  - `5` `EliteChallengeShrine` ;
  - `3` `MagnetShrine`.
- `src/server/ShrineService.luau` ajoute un marker `!` au-dessus des shrines actives non consommees.
- `src/server/ShrineService.luau` desactive le marker `!` apres activation.
- `src/server/ShrineService.luau` bloque l'activation si une pause combat est deja active.
- `src/server/ShrineService.luau` active le magnet via `XpService.CollectAllForPlayer` et `CoinService.CollectAllForPlayer`.
- `src/server/XpService.luau` et `src/server/CoinService.luau` trient les collectibles par distance et etalent leur collecte.
- `src/client/CombatUI.client.luau` affiche le bloc golds + pause/play en haut-centre.

### Decisions

- Juste : le portail boss est volontairement non interactif pour l'instant.
- Juste : `EliteChallengeShrine` est generable et activable, mais son effet reste un placeholder tant que les ennemis elites ne sont pas implementes.
- Juste : le magnet reste serveur-autoritaire ; le client ne decide jamais des gains XP/coins.
- Juste : le systeme de level-up existant queue les choix de perks successivement, donc un gros magnet ne doit pas ouvrir plusieurs propositions en meme temps.
- Simplification : aucun service generique `InteractableService` n'est introduit maintenant ; `ShrineService` suffit pour les trois shrines proches conceptuellement.

### Proof of done local

- Juste : `rojo build -o $env:TEMP\TestRoblox_portal_shrines_magnet_build.rbxlx` passe.
- Juste : `git diff --check` sur les fichiers du chantier ne remonte que les avertissements CRLF habituels.
- Juste : aucune nouvelle utilisation brute de `print(` ou `warn(` n'est ajoutee dans les services touches.

### Angles morts

- Angle mort : les positions reelles doivent etre validees en Play Test avec les assets Studio, car les pivots et tailles des templates peuvent changer la perception du placement.
- Angle mort : le marker `!` peut etre trop haut ou trop bas selon le bounding box reel des meshes importes.
- Angle mort : le magnet peut provoquer beaucoup d'evenements d'animation si une run longue laisse trop de loot au sol.
- Angle mort : l'activation elite devra etre remplacee par un vrai spawn d'ennemis elites quand le type `Elite` existera.

### Rollback conceptuel

- Desactiver le portail revient a ne plus demarrer `PortalService`.
- Desactiver les shrines speciales revient a mettre `EliteChallengeInitialSpawnCount = 0` et `MagnetInitialSpawnCount = 0`.
- Revenir a l'ancien HUD revient a remettre `CurrencyPanel` et `PauseButton` sur leurs positions haut-gauche precedentes.

## 2026-07-08 16:38:34 +02:00 - Correction du spawn MagnetShrine apres Play Test

### Contexte

Le Play Test a montre que les `MagnetShrine` n'apparaissaient pas. Les logs indiquaient pourtant que le template `MagnetShrine` etait bien trouve dans `ServerStorage/ShrineTemplates`. Le probleme venait donc du placement runtime, pas du rangement Studio.

### Diagnostic

- Juste : les logs montrent `Template trouve` pour `MagnetShrine`.
- Juste : les logs montrent `Placement surface incomplet` puis `SpawnedCount=0` pour `TypeId=Magnet`.
- Juste : la generation des `PerkShrine`, `EliteChallengeShrine`, coffres et jarres occupe deja beaucoup de positions avant les magnets.
- Simplification : la correction ne change pas le service de spawn mondial ; elle relache uniquement les contraintes Magnet et ajoute un retry local en cas de placement incomplet.

### Changements

- `src/server/ShrineService.luau` baisse la distance minimale de placement des `MagnetShrine`.
- `src/server/ShrineService.luau` autorise les magnets a chercher un peu plus loin que les shrines standards.
- `src/server/ShrineService.luau` ajoute un retry de placement avec contraintes relachees si une definition de shrine n'obtient pas assez de positions.
- Le retry garde les positions deja trouvees et les positions occupees pour eviter de superposer les objets.

### Proof of done local

- Juste : `rojo build -o $env:TEMP\TestRoblox_magnet_spawn_fix.rbxlx` passe.
- Juste : les prochains logs attendus doivent montrer `TypeId=Magnet`, puis `SpawnedCount=3`.

### Angles morts

- Angle mort : le ressenti exact de repartition doit etre valide en Play Test, car la taille reelle des assets Magnet peut donner une impression de proximite differente de la distance entre pivots.
- Angle mort : si la map procedurale devient plus petite ou plus dense, il faudra probablement passer a un systeme de reservation de zones plutot qu'a un simple retry.

### Rollback conceptuel

- Revenir au comportement precedent revient a remettre les contraintes Magnet a `SpawnMinRadius = 30`, `SpawnMaxRadius = ShrineConfig.SpawnWorldMaxRadius`, `SpawnMinDistance = 34`, et a supprimer le retry relache.

## 2026-07-08 16:48:19 +02:00 - Charge PerkShrine par presence dans la bulle

### Contexte

Les `PerkShrine` devaient perdre l'interaction `E maintenu` pour devenir plus naturelles : le joueur entre dans la bulle, la shrine se charge, puis elle se decharge a la meme vitesse quand le joueur sort. Les shrines `Magnet` et `EliteChallenge` doivent rester activables rapidement sans changer leur logique fonctionnelle.

### Point d'impact

- Juste : `ShrineService` reste le bon point d'impact, car les trois types de shrines y sont deja centralises.
- Juste : le serveur mesure la presence du joueur dans la zone de bulle ; le client ne valide pas l'activation.
- Contestable : la charge par presence est appliquee uniquement aux `PerkShrine` pour l'instant, car `Magnet` et `EliteChallenge` ont encore des effets plus ponctuels.
- Simplification : aucune UI de jauge n'est ajoutee maintenant ; le feedback repose sur la bulle, le son et l'apparition de l'ecran de perk.

### Changements

- `src/server/ShrineService.luau` ajoute un mode `BubblePresence` pour les `PerkShrine`.
- `src/server/ShrineService.luau` supprime le `ProximityPrompt` des instances `PerkShrine` clonees.
- `src/server/ShrineService.luau` charge progressivement une `PerkShrine` quand un joueur est dans sa bulle.
- `src/server/ShrineService.luau` decharge progressivement la shrine a la meme vitesse quand aucun joueur n'est dans la bulle.
- `src/server/ShrineService.luau` divise par deux le temps de charge des shrines `Magnet` et `EliteChallenge`.
- `src/shared/ShrineConfig.luau` abaisse legerement le marker `!`.

### Proof of done local

- Juste : `rojo build -o $env:TEMP\TestRoblox_shrine_bubble_charge_build.rbxlx` passe.

### Angles morts

- Angle mort : si `Bubble` est un asset tres grand ou mal centre, la zone ressentie peut etre trop large ou trop etroite ; le Play Test doit valider la taille reelle.
- Angle mort : il n'y a pas encore de jauge visuelle de charge ; si le son ne suffit pas, une petite barre proche de la shrine deviendra utile.
- Angle mort : en multi-run futur, cette charge devra etre rattachee a une instance de run plutot qu'au monde global.

### Rollback conceptuel

- Revenir au comportement precedent revient a retirer `ActivationMode = "BubblePresence"` des `PerkShrine`, a rebrancher leur `ProximityPrompt`, et a remettre `ChargeDuration = ShrineConfig.ChargeDuration` pour `Magnet` et `EliteChallenge`.

## 2026-07-08 17:00:57 +02:00 - Analyse Play Test shrines et robustesse spawn mobs

### Contexte

Un Play Test d'environ dix minutes a ete partage apres l'ajout des shrines speciales et de la charge par presence. Le but etait de verifier si les magnets apparaissent, si les shrines s'activent correctement et si la boucle XP/perks reste stable sur une duree plus longue.

### Diagnostic logs

- Juste : aucune erreur serveur ou client n'apparait dans les logs fournis.
- Juste : les `MagnetShrine` spawnent maintenant correctement avec `SpawnedCount=3`.
- Juste : les trois `MagnetShrine` ont ete activees pendant le test.
- Juste : les `PerkShrine` par presence fonctionnent ; les logs montrent des charges, des interruptions et des validations.
- Juste : les level-ups provoques par les magnets sont bien mis en file, puis presentes successivement.
- Angle mort : 34 warnings `Aucune surface trouvee pour spawn mob` indiquent que le spawn des ennemis reste trop fragile pres des bords ou quand le point aleatoire tombe hors plateforme.

### Changements

- `src/shared/CombatConfig.luau` ajoute `MonsterSpawnSurfaceAttempts = 10`.
- `src/server/MonsterService.luau` tente maintenant plusieurs positions autour du joueur avant de declarer qu'aucune surface n'a ete trouvee.
- `src/server/MonsterService.luau` ajoute le nombre de tentatives dans le warning restant pour rendre les prochains logs plus exploitables.

### Proof of done local

- Juste : `rojo build -o $env:TEMP\TestRoblox_monster_spawn_attempts_build.rbxlx` passe.

### Angles morts

- Angle mort : cette correction reduit les echecs aleatoires, mais ne remplace pas encore un vrai systeme de spawn par zones reservees.
- Angle mort : si le joueur est vraiment au bord extreme de la plateforme, certains echecs de spawn resteront normaux.
- Angle mort : les logs restent tres bavards en fin de run, surtout autour de l'XP, des coins et des projectiles.

### Rollback conceptuel

- Revenir au comportement precedent revient a retirer `MonsterSpawnSurfaceAttempts` et a refaire un seul raycast aleatoire par tentative de spawn.

## 2026-07-09 06:34:15 +02:00 - Compatibilite assets catalogue et rotation des templates runtime

### Contexte

Le remplacement de plusieurs assets Studio a revele deux problemes distincts : l'animation d'un modele catalogue est bien appelee par le script mais bloquee par les droits Roblox, et plusieurs templates importes apparaissent couches sur le cote au moment de leur generation runtime.

### Diagnostic

- Juste : le log `Animation monstre lancee` prouve que `MonsterService` charge bien `Walk`.
- Juste : l'erreur `L'experience n'a pas le droit d'utiliser l'identifiant` signifie que Roblox refuse l'asset d'animation, pas que le script ne le joue pas.
- Juste : les objets couches viennent d'un placement runtime en `CFrame.new(position)` qui effacait la rotation du template Studio.
- Juste : `PerkShrine`, `EliteChallengeShrine` et `MagnetShrine` passent tous par `ShrineService`; une correction dans ce service couvre donc les trois types.
- Angle mort : les droits d'animation doivent etre regles dans Roblox Studio/Creator Dashboard en publiant l'animation sous le bon compte ou groupe.

### Changements

- `src/server/WorldSpawnService.luau` ajoute une aide pour replacer un template au sol en conservant sa rotation de pivot.
- `src/server/ChestService.luau` conserve maintenant la rotation du template `Chest` tout en gardant une rotation aleatoire autour de l'axe Y.
- `src/server/JarService.luau` conserve maintenant la rotation du template `Jar` tout en gardant une rotation aleatoire autour de l'axe Y.
- `src/server/PortalService.luau` conserve maintenant la rotation du template `PortalBoss`.
- `src/server/ShrineService.luau` conserve maintenant la rotation des templates `PerkShrine`, `EliteChallengeShrine` et `MagnetShrine`.
- `src/server/ShrineService.luau` cree une bulle runtime de secours si `PerkShrine` n'a plus d'enfant `Bubble`.
- `src/shared/ShrineConfig.luau` ajoute la taille et la hauteur de cette bulle de secours.
- `src/server/MonsterService.luau` conserve la rotation du template `Monster1` au spawn et pendant le mouvement procedural des monstres sans `Humanoid`.

### Proof of done local

- Juste : `rojo build -o $env:TEMP\TestRoblox_template_rotation_build.rbxlx` passe.
- Juste : `git diff --check` sur les fichiers touches ne remonte que les avertissements CRLF habituels.

### Angles morts

- Angle mort : si un asset catalogue a un pivot mal place, conserver sa rotation ne suffira pas toujours ; il faudra corriger le pivot dans Studio ou Blender.
- Angle mort : la bulle runtime de secours rend le gameplay jouable, mais ne remplace pas une vraie bulle artistique dans le template `PerkShrine`.
- Angle mort : les animations catalogue restent soumises aux droits Roblox ; aucun script serveur ne peut contourner une animation non autorisee pour l'experience.

### Rollback conceptuel

- Revenir au comportement precedent revient a replacer les clones avec `CFrame.new(position)` et a supprimer la creation runtime de bulle fallback, mais cela recreerait le risque d'assets couches apres import catalogue.

## 2026-07-10 13:03:41 +02:00 - Rebuild HUD combat MegaRoblox

### Contexte

Une reprise du chantier UI a ete necessaire apres une interruption pendant une modification precedente. En Play Test, l'utilisateur ne voyait plus de GUI principale.

### Diagnostic

- Juste : `src/client/CombatUI.client.luau` etait supprime dans l'etat Git courant, ce qui empechait le HUD combat principal d'apparaitre.
- Juste : `rojo build` passait malgre tout, car l'absence du fichier n'est pas une erreur de compilation Rojo.
- Juste : les autres GUI ne remplacent pas le HUD principal : `QuizGui` est desactive par `FeatureFlags.QuizEnabled = false`, `DebugGui` est desactive par `FeatureFlags.DebugUIEnabled = false`, `AdminGui` depend de l'attribut admin, et les UI perks/coffres ne s'affichent que lors d'une interaction.
- Contestable : une refonte purement en Frames/TextLabels ne peut pas reproduire pixel-perfect les images de reference, mais elle evite d'ajouter des assets externes ou une dependance fragile.

### Changements

- `src/client/CombatUI.client.luau` est recree comme HUD autonome.
- Le HUD affiche immediatement un etat par defaut, puis se met a jour quand les remotes serveur arrivent.
- Le style reprend la direction des references : badge `LVL`, longue barre XP bleue/violette, panneau stats sombre/neon, cartes `KILLS`, `GOLDS`, `MOBS`, cartes `WEAPON` et `PERKS`, bouton pause compact vert.
- Les remotes existants sont conserves : `Combat_UpdateStats`, `Xp_UpdateCount`, `Coin_UpdateCount`, `Perk_UpdateStats`, `Combat_PauseState`, `Combat_TogglePause`.
- La logique gameplay n'est pas modifiee.

### Proof of done local

- Juste : `rojo build -o $env:TEMP\TestRoblox_gui_rebuild.rbxlx` passe.
- Juste : `git diff --check -- src/client/CombatUI.client.luau` ne remonte que l'avertissement CRLF habituel.

### Angles morts

- Angle mort : le rendu visuel final doit etre juge en Play Test Studio, car Rojo build valide la structure mais pas la perception UI en camera reelle.
- Angle mort : le HUD est volontairement plus riche que l'ancien ; si la vue joueur est trop couverte, il faudra reduire l'echelle ou basculer certaines stats dans un panneau repliable.
- Angle mort : les icones sont des lettres stylisees pour eviter des assets externes ; une passe artistique future pourra remplacer ces placeholders par de vrais sprites.

### Budget de complexite

- Ajoute de la complexite UI locale.
- Ne deplace pas de complexite gameplay.
- Le gain utilisateur attendu est net : recuperer un HUD visible et lisible, avec une direction visuelle plus proche de MegaRoblox.

### Rollback conceptuel

- Revenir a un comportement plus simple revient a garder les memes callbacks remotes et a remplacer seulement la construction visuelle du HUD par une version compacte.

## 2026-07-10 13:22:54 +02:00 - Epuration HUD joueur

### Contexte

Le premier rebuild du HUD MegaRoblox etait fonctionnel mais trop dense en Play Test : grand panneau en bas a gauche, carte XP tres visible, compteur d'or central et nombreuses informations secondaires.

### Diagnostic

- Juste : le HUD couvrait trop l'ecran pour un survivor-like ou le joueur doit lire la scene, esquiver et continuer a agir.
- Juste : les informations `Weapon`, `Mobs`, `Perks`, `Wave` et le titre `MEGAROBLOX SURVIVOR` n'etaient pas indispensables dans le panneau principal.
- Contestable : garder les icones en fallback texte est moins beau qu'une vraie bibliotheque d'assets, mais cela evite des IDs catalogue non autorises ou introuvables.

### Changements

- `src/client/CombatUI.client.luau` retire le compteur d'or haut-centre et conserve seulement le bouton pause/play en haut.
- `src/client/CombatUI.client.luau` retire le titre, la vague, `Weapon`, `Mobs` et `Perks` du panneau bas gauche.
- `src/client/CombatUI.client.luau` reduit fortement la taille de la zone HP/Shield/Kills/Gold.
- `src/client/CombatUI.client.luau` rend le panneau bas gauche transparent et supprime les encadres de cartes.
- `src/client/CombatUI.client.luau` reduit la hauteur des barres HP, Shield et XP.
- `src/client/CombatUI.client.luau` prepare une table `ICON_IMAGES` pour brancher ensuite des icons du catalogue Roblox Studio sans changer la logique.

### Proof of done local

- Juste : `rojo build -o $env:TEMP\TestRoblox_hud_minimal_build.rbxlx` passe.

### Angles morts

- Angle mort : la lisibilite sur fond tres clair ou tres charge dependra de la scene reelle ; les textes utilisent une ombre mais pas de panneau opaque.
- Angle mort : les vrais icons catalogue doivent encore etre choisis avec des IDs fiables et autorises pour l'experience.
- Angle mort : le panneau Admin/Debug de droite n'a pas ete modifie, conformement a la demande.

### Rollback conceptuel

- Revenir a la version dense revient a restaurer les cartes `Weapon`, `Mobs`, `Perks`, le titre, la vague et le compteur d'or central, sans toucher aux callbacks remotes.

## 2026-07-10 13:38:13 +02:00 - Repositionnement HUD et timer de run

### Contexte

Apres test visuel, le HUD epure restait trop separe : HP/Shield etaient encore en bas a gauche tandis que la barre XP etait centree. La demande etait de rapprocher les jauges principales de la barre XP, de placer kills/golds autour du bouton pause, et d'ajouter un timer de run local.

### Diagnostic

- Juste : HP et Shield sont des informations de survie immediates ; les placer au-dessus de l'XP reduit les allers-retours visuels.
- Juste : le compteur de kills et les golds peuvent etre lus en haut-centre sans polluer la zone basse de deplacement.
- Contestable : le timer client local suffit pour l'affichage V1, mais il ne doit pas encore devenir une source d'autorite gameplay.

### Changements

- `src/client/CombatUI.client.luau` place HP et Shield sur une meme ligne au-dessus de la barre XP, aux limites gauche et droite du bloc XP.
- `src/client/CombatUI.client.luau` supprime les placeholders HP et Shield.
- `src/client/CombatUI.client.luau` deplace kills a gauche du bouton pause/play et golds a droite.
- `src/client/CombatUI.client.luau` ajoute un timer local de 12:00 sous le bouton pause/play.
- `src/client/CombatUI.client.luau` stoppe la descente du timer quand une pause utilisateur ou systeme est active.
- `src/client/CombatUI.client.luau` epaissit legerement les barres HP, Shield et XP.

### Proof of done local

- Juste : `rojo build -o $env:TEMP\TestRoblox_hud_timer_layout_build.rbxlx` passe.

### Angles morts

- Angle mort : le timer est volontairement client-only pour l'instant ; il ne doit pas servir a valider une victoire ou une defaite tant que le serveur ne l'autorise pas.
- Angle mort : les icones kills/golds utilisent encore les fallbacks si aucun asset catalogue fiable n'est renseigne.
- Angle mort : la lisibilite exacte dependra de la camera et du fond de map en Play Test.

### Rollback conceptuel

- Revenir a l'affichage precedent revient a remettre HP/Shield/Kills/Gold dans le bloc bas gauche et a retirer la boucle `RunService.RenderStepped` du timer.

## 2026-07-10 14:06:03 +02:00 - Proportions icones HUD et regle Gotham

### Contexte

Les icones kills/golds et leurs valeurs etaient encore trop petites par rapport au bouton pause/play. La valeur des kills devait aussi reprendre une couleur rouge coherente avec sa fonction.

### Diagnostic

- Juste : le bouton pause/play est le meilleur repere de proportion du bloc haut-centre.
- Juste : colorer la valeur kills en rouge ameliore la lecture par symetrie avec la valeur golds en jaune.
- Juste : les scripts UI client existants utilisent deja majoritairement Gotham et ses variantes ; il n'etait pas utile d'ajouter une couche globale lourde.

### Changements

- `src/client/CombatUI.client.luau` ajoute une table locale `UI_FONTS` pour declarer clairement Gotham Regular, Medium, Bold et Heavy.
- `src/client/CombatUI.client.luau` utilise cette table sur le HUD combat.
- Les icones kills/golds passent a une proportion de `1.22` fois la taille du bouton pause.
- Les valeurs kills/golds passent a une proportion de `0.66` fois la taille du bouton pause.
- La valeur kills utilise maintenant la couleur rouge de vie/combat.
- L'icone gold est encore rapprochee de sa valeur sans deplacer l'ancrage de la valeur.

### Proof of done local

- Juste : `rojo build -o $env:TEMP\TestRoblox_hud_typography_build.rbxlx` passe.

### Angles morts

- Angle mort : Gotham Italic ou Light ne sont pas utilises dans ce HUD car aucun libelle actuel ne justifie une variante decorative ou secondaire.
- Angle mort : les proportions restent a valider visuellement en Play Test, car les images importees peuvent avoir du padding transparent interne.

### Rollback conceptuel

- Revenir au rendu precedent revient a remettre les proportions `1.1` et `0.6`, puis a repasser la valeur kills en blanc.

## 2026-07-10 14:14:59 +02:00 - Regroupement responsive kills et golds

### Contexte

Le placement symetrique kills a gauche et golds a droite du bouton pause creait un probleme d'equilibre visuel. L'icone gold pouvait sembler trop eloignee de sa valeur, et les variations de longueur des nombres risquaient de deplacer la lecture du bloc.

### Diagnostic

- Juste : mettre kills et golds du meme cote reduit la complexite du bloc haut-centre.
- Juste : les valeurs doivent vivre dans des zones fixes afin qu'un score court ou long ne pousse pas les icones ni le bouton pause.
- Simplification : il vaut mieux supprimer la symetrie artificielle que compenser avec de nouveaux offsets a droite.

### Changements

- `src/client/CombatUI.client.luau` agrandit la zone logique `TopCluster` sans ajouter de fond visible.
- `src/client/CombatUI.client.luau` place kills et golds dans deux slots fixes a gauche du bouton pause/play.
- `src/client/CombatUI.client.luau` reserve une largeur stable aux valeurs kills/golds.
- `src/client/CombatUI.client.luau` active `TextScaled` sur ces deux valeurs pour absorber les montants plus longs sans deplacer le HUD.

### Proof of done local

- Juste : `rojo build -o TestRoblox.rbxlx` passe.

### Angles morts

- Angle mort : la validation exacte du ressenti visuel reste a faire en Play Test, surtout avec des valeurs tres longues comme `999,999`.
- Angle mort : le padding transparent interne des images catalogue peut encore donner une impression d'ecart meme si le slot est correctement place.

### Rollback conceptuel

- Revenir a l'etat precedent revient a remettre golds a droite du bouton pause et a supprimer les slots fixes `KillsSlot` et `GoldSlot`.

## 2026-07-10 14:29:03 +02:00 - Renforcement responsive des compteurs haut-centre

### Contexte

Avec des valeurs intermediaires comme `5,260` kills et `1,194` golds, le groupe de compteurs restait lisible mais se rapprochait deja trop du bouton pause. La demande etait de deplacer le bloc vers la gauche et de garantir une lecture stable jusqu'a un plafond visuel de `1M`.

### Diagnostic

- Juste : le risque principal n'est pas la valeur courte, mais l'accumulation icone + texte + bouton pause sur une meme ligne.
- Juste : un slot plus large et fixe est plus robuste qu'un deplacement dynamique selon la longueur du texte.
- Simplification : le format compact `1M` sur les compteurs haut-centre evite de sacrifier la lisibilite du HUD pour afficher `1,000,000`.

### Changements

- `src/client/CombatUI.client.luau` elargit la zone invisible `TopCluster` afin de reculer le groupe kills/golds vers la gauche.
- `src/client/CombatUI.client.luau` augmente la largeur reservee a chaque slot de compteur.
- `src/client/CombatUI.client.luau` ajoute `formatTopStatNumber` pour afficher `1M` a partir de `1,000,000` sur kills/golds.
- `src/client/CombatUI.client.luau` ajoute un palier responsive supplementaire pour les viewports tres etroits.

### Proof of done local

- Juste : `rojo build -o TestRoblox.rbxlx` passe.

### Angles morts

- Angle mort : le choix `1M` perd le detail exact au-dessus du million dans le HUD haut-centre ; le detail pourra rester disponible ailleurs si un ecran de stats est ajoute plus tard.
- Angle mort : la validation finale reste visuelle en Play Test, car les assets catalogue peuvent contenir du padding transparent interne.

### Rollback conceptuel

- Revenir a l'etat precedent revient a repasser `TopCluster` a `520`, les slots a `116`, et a remplacer `formatTopStatNumber` par `formatNumber` pour les deux compteurs haut-centre.

## 2026-07-10 14:47:34 +02:00 - Icones jauges et feedback de degats joueur

### Contexte

Le HUD bas devait quitter les libelles texte `HP` et `SHIELD` au profit d'icones catalogue. La barre de vie devait devenir verte, le shield bleu/vert electrique, et l'XP adopter une identite violette plus arcane. Une barre de vie native Roblox apparaissait aussi en haut a droite lors des degats.

### Diagnostic

- Juste : remplacer les libelles par des icones reduit le bruit textuel sans supprimer les valeurs importantes.
- Juste : la barre de vie native Roblox devient redondante avec le HUD custom et doit etre masquee cote client.
- Juste : un flash rouge leger au moment ou la vie ou le shield baisse donne une alerte de danger sans ajouter une nouvelle UI persistante.
- Simplification : le flash utilise les remotes de stats deja existants au lieu d'ajouter un nouveau RemoteEvent dedie aux degats.

### Changements

- `src/client/CombatUI.client.luau` desactive `Enum.CoreGuiType.Health` via `StarterGui:SetCoreGuiEnabled`.
- `src/client/CombatUI.client.luau` ajoute `Health_GUI` et `Shield_GUI` dans `ICON_IMAGES`.
- `src/client/CombatUI.client.luau` remplace les textes `HP` et `SHIELD` par les icones correspondantes.
- `src/client/CombatUI.client.luau` conserve les valeurs de vie et de shield sans prefixe texte.
- `src/client/CombatUI.client.luau` passe la vie en vert et le shield en bleu/vert electrique.
- `src/client/CombatUI.client.luau` passe les labels et la barre XP en violet arcane.
- `src/client/CombatUI.client.luau` epaissit legerement les barres vie, shield et XP.
- `src/client/CombatUI.client.luau` ajoute un overlay `DamageFlash` rouge tres transparent quand la vie ou le shield baisse.

### Proof of done local

- Juste : `rojo build -o TestRoblox.rbxlx` passe.

### Angles morts

- Angle mort : les assets `Health_GUI` et `Shield_GUI` doivent etre autorises pour l'experience, sinon Roblox affichera une erreur de chargement d'image.
- Angle mort : la suppression de la CoreGui Health doit etre confirmee en Play Test, car le comportement final depend du client Roblox Studio.
- Angle mort : le flash rouge est base sur les snapshots de stats ; il indique une baisse de vie ou de shield, mais ne distingue pas encore la source du degat.

### Rollback conceptuel

- Revenir a l'etat precedent revient a remettre les labels `HP` et `SHIELD`, a restaurer les anciennes couleurs de vie/shield/XP, a retirer `DamageFlash`, et a ne plus appeler `SetCoreGuiEnabled` pour la CoreGui Health.

## 2026-07-10 14:54:48 +02:00 - Fonds glassmorphisme HUD

### Contexte

Les elements HUD etaient lisibles sur certaines zones mais pouvaient se perdre sur la map, surtout avec le sol vert et le ciel clair. La demande etait d'ajouter un fond glassmorphisme translucide clair derriere chaque groupe important afin de mieux faire ressortir les informations sans revenir a un panneau massif.

### Diagnostic

- Juste : un fond translucide leger ameliore la lisibilite sans bloquer la vue du joueur.
- Juste : Roblox UI ne fournit pas un blur local simple comparable au CSS ; un glassmorphisme simule par transparence, gradient, stroke et brillance est plus adapte pour cette V1.
- Simplification : les fonds sont appliques aux groupes existants au lieu de restructurer toute la hierarchie HUD.

### Changements

- `src/client/CombatUI.client.luau` ajoute les couleurs `Glass`, `GlassTint` et `GlassStroke`.
- `src/client/CombatUI.client.luau` ajoute le helper `addGlassBackground`.
- `src/client/CombatUI.client.luau` applique un fond glass aux groupes kills et golds en haut.
- `src/client/CombatUI.client.luau` applique un fond glass aux groupes vie et shield.
- `src/client/CombatUI.client.luau` applique un fond glass au groupe XP bas.

### Proof of done local

- Juste : `rojo build -o TestRoblox.rbxlx` passe.

### Angles morts

- Angle mort : l'opacite exacte devra etre ajustee apres Play Test selon le fond de map reel.
- Angle mort : l'effet est un glassmorphisme simule, pas un vrai flou local du monde 3D.

### Rollback conceptuel

- Revenir a l'etat precedent revient a supprimer `addGlassBackground`, les couleurs `Glass*`, et les appels places sur les groupes HUD.

## 2026-07-10 14:58:39 +02:00 - Unification des fonds glass HUD

### Contexte

Les fonds glass etaient appliques a chaque slot separement, ce qui creait une lecture fragmentees : un fond pour kills, un fond pour golds, puis des fonds separes pour vie, shield et XP. Un trait blanc de brillance apparaissait aussi en haut de chaque fond.

### Diagnostic

- Juste : les fonds doivent suivre la localisation fonctionnelle, pas chaque element individuel.
- Juste : kills et golds forment un groupe de compteurs haut-centre et doivent partager un seul fond.
- Juste : vie, shield et XP forment le bloc d'etat principal et doivent partager un seul fond.
- Simplification : supprimer la ligne `TopShine` reduit le bruit visuel et evite l'effet de trait blanc parasite.

### Changements

- `src/client/CombatUI.client.luau` supprime la creation du sous-element `TopShine`.
- `src/client/CombatUI.client.luau` remplace les fonds separes kills/golds par `TopStatsGlassBackground`.
- `src/client/CombatUI.client.luau` remplace les fonds separes vie/shield/XP par `BarsGlassBackground`.
- `src/client/CombatUI.client.luau` force les fonds glass en `ZIndex = 0` pour rester derriere les icones, labels et barres.

### Proof of done local

- Juste : `rojo build -o TestRoblox.rbxlx` passe.
- Juste : il ne reste plus de reference `TopShine` dans `src/client/CombatUI.client.luau`.

### Angles morts

- Angle mort : la taille exacte du fond unifie devra etre ajustee visuellement si le bloc parait trop large ou trop proche du bouton pause.

### Rollback conceptuel

- Revenir a l'etat precedent revient a remettre les appels `addGlassBackground` sur chaque slot separe et a restaurer le sous-element `TopShine`.

## 2026-07-10 15:04:00 +02:00 - Ajustement icones jauges et barres pleines

### Contexte

Les icones vie et shield restaient trop petites dans le bloc bas alors que l'espace visuel existant permettait de les agrandir sans modifier la taille du fond glass ni des groupes. Les barres utilisaient aussi encore un gradient lineaire qui ajoutait du bruit visuel.

### Diagnostic

- Juste : agrandir les icones dans le meme conteneur ameliore la lecture sans impacter le layout global.
- Juste : les barres pleines sont plus nettes dans une interface deja translucide.
- Simplification : retirer le gradient des fills reduit le nombre d'effets superposes.

### Changements

- `src/client/CombatUI.client.luau` agrandit les icones `HealthIcon` et `ShieldIcon` a `28x28`.
- `src/client/CombatUI.client.luau` decale legerement les valeurs vie/shield pour conserver l'espacement avec les icones agrandies.
- `src/client/CombatUI.client.luau` augmente legerement la taille des textes vie, shield, level et XP.
- `src/client/CombatUI.client.luau` retire le gradient lineaire des fills de barres dans `createBar`.

### Proof of done local

- Juste : `rojo build -o TestRoblox.rbxlx` passe.
- Juste : les fills de barres n'appellent plus `addGradient`.

### Angles morts

- Angle mort : selon le padding interne des assets `Health_GUI` et `Shield_GUI`, les icones peuvent encore paraitre plus petites que leur conteneur reel.

### Rollback conceptuel

- Revenir a l'etat precedent revient a remettre les icones a `20x20`, les textes a leurs tailles precedentes, et a restaurer `addGradient(fill, fillColor, fillDarkColor, 0)` dans `createBar`.

## 2026-07-10 18:00:33 +02:00 - Completion tiers Coin2 Coin3

### Contexte

Une coupure est arrivee apres l'ajout partiel des tiers coins dans `GameConfig` et `TemplateService`, puis le commit `0.0.6` a ete cree. La reprise devait completer le chantier sans revenir sur ce commit : les templates `Coin2` et `Coin3` doivent se comporter comme les tiers de gemmes XP.

### Diagnostic

- Juste : `GameConfig` portait deja les noms, valeurs et seuils de fusion des coins.
- Juste : `TemplateService` migrait deja les templates `Coin`, `Coin2` et `Coin3` vers `ServerStorage/CollectibleTemplates`.
- Juste : il manquait la logique runtime : tracking serveur des tiers, valeur par tier, fusion serveur et reconnaissance client.
- Simplification : les drops existants continuent a appeler `SpawnCoin(position)` et produisent donc du tier 1 par defaut.

### Changements

- `src/server/CoinService.luau` remplace le template unique par `coinTemplatesByTier`.
- `src/server/CoinService.luau` reconnait `Coin`, `Coin2` et `Coin3` via `GameConfig.CoinTierNames`.
- `src/server/CoinService.luau` attribue les valeurs `1`, `3` et `9` via `GameConfig.CoinTierValues`.
- `src/server/CoinService.luau` ajoute la fusion serveur de coins par groupe proche, avec les memes principes que les gemmes XP.
- `src/server/CoinService.luau` conserve `SpawnCoin(position)` en tier 1 et ajoute `SpawnCoin(position, tier)` pour les usages futurs.
- `src/client/CoinClient.client.luau` anime, cull et aspire maintenant tous les tiers de coins.

### Proof of done local

- Juste : `rojo build -o TestRoblox.rbxlx` passe.
- Juste : `git diff --check` ne remonte que les warnings CRLF habituels.
- Juste : aucune reference de conflit `<<<<<<<`, `=======`, `>>>>>>>` n'est presente dans `src` ou `docs`.

### Angles morts

- Angle mort : le comportement visuel de fusion de coins doit etre valide en Play Test avec beaucoup de drops au sol.
- Angle mort : les valeurs `1/3/9` sont coherentes avec les gems mais restent a equilibrer selon la vitesse de gain d'or souhaitee.

### Rollback conceptuel

- Revenir a l'etat precedent revient a repasser `CoinService` sur un template unique `Coin`, a retirer la fusion des coins, et a limiter `CoinClient` au nom `Coin`.

## 2026-07-10 18:26:05 +02:00 - Activation EliteChallengeShrine

### Contexte

Le modele `Monster1_Elite` a ete ajoute pour donner une vraie action a `EliteChallengeShrine`. L'autel etait deja genere et chargeable avec `E`, mais son effet restait un placeholder.

### Diagnostic

- Juste : l'effet manquant devait rester serveur, car le spawn, les PV et les degats des ennemis ne doivent pas dependre du client.
- Juste : `MonsterService` savait deja porter un attribut `IsElite`, ce qui permet d'ajouter l'elite sans creer un second moteur de combat.
- Simplification : le monstre elite reutilise la vitesse et le mouvement de `Monster1`; seuls les PV et les degats sont multiplies.

### Changements

- `src/shared/CombatConfig.luau` ajoute `EliteMonsterTemplateName`, le nombre de spawn elite, le rayon de pack, et les multiplicateurs PV/degats.
- `src/shared/ShrineConfig.luau` ajoute le son de fin dedie EliteChallenge `rbxassetid://9043352093`.
- `src/server/TemplateService.luau` migre `Monster1_Elite` vers `ServerStorage/CombatTemplates` si le template est encore range ailleurs.
- `src/server/MonsterService.luau` ajoute `SpawnElitePack`, qui fait apparaitre un pack regroupe de 5 `Monster1_Elite` autour de la shrine activee.
- `src/server/MonsterService.luau` applique 2x PV et 2x degats aux elites, sans changer la vitesse de deplacement ni les stats de `Monster1`.
- `src/server/ShrineService.luau` remplace le placeholder EliteChallenge par l'appel serveur au pack elite et utilise un son de completion propre au type de shrine.

### Proof of done local

- Juste : `rojo build -o TestRoblox.rbxlx` passe.
- Juste : l'ancien log placeholder `EliteChallengeShrine activee placeholder` n'existe plus.
- Juste : le template elite n'a pas de fallback silencieux ; s'il manque, un warning explicite est logue.

### Angles morts

- Angle mort : le positionnement exact du pack elite doit etre valide en Play Test autour d'une shrine activee, surtout si la shrine est proche d'un bord ou d'une pente.
- Angle mort : l'equilibrage 2x PV / 2x degats est volontairement brut pour V1 et devra etre ajuste apres ressenti en run.

### Rollback conceptuel

- Revenir a l'etat precedent revient a retirer `SpawnElitePack`, a remettre l'effet EliteChallenge en placeholder, et a supprimer la config `EliteMonster*`.

## 2026-07-10 18:46:07 +02:00 - Reward ChestOpen et loot elite

### Contexte

Le premier test de `EliteChallengeShrine` est valide, mais les elites apparaissaient trop pres du joueur qui venait de charger l'autel. Le reward de fin de pack devait aussi devenir plus clair : a la mort du dernier elite du groupe, un coffre ouvert `ChestOpen` doit apparaitre et lancer le systeme de reward au contact.

### Diagnostic

- Juste : le centre du pack elite doit etre decale du joueur, pas seulement les monstres individuellement, sinon le joueur peut etre immediatement entoure apres l'interaction.
- Juste : `ChestOpen` doit rester un template distinct de `Chest`, car les coffres classiques ont un cout et une interaction `E`.
- Simplification : le coffre reward reutilise l'UI slot existante et les boutons Valider/Passer, sans creer une deuxieme interface.

### Changements

- `src/shared/CombatConfig.luau` ajoute `EliteMonsterPlayerSafetyDistance` et `EliteMonsterLootMultiplier`.
- `src/server/MonsterService.luau` decale le centre du pack elite si le joueur est trop proche.
- `src/server/MonsterService.luau` suit les packs elites via un `ElitePackId`.
- `src/server/MonsterService.luau` double les drops XP et coins des elites.
- `src/server/MonsterService.luau` demande un `ChestOpen` a la mort du dernier elite du pack tue par un joueur.
- `src/shared/ChestConfig.luau` ajoute `OpenChestName = "ChestOpen"`.
- `src/server/TemplateService.luau` migre `ChestOpen` vers `ServerStorage/ChestTemplates`.
- `src/server/ChestService.luau` ajoute `SpawnRewardChestAtPosition`, avec ouverture gratuite au contact et pause pendant le choix.
- `src/client/ChestClient.client.luau` affiche `Recompense elite` pour un coffre reward au lieu d'un cout a 0 coin.

### Proof of done local

- Juste : `rojo build -o TestRoblox.rbxlx` passe.
- Juste : `git diff --check` ne remonte que les warnings CRLF habituels.
- Juste : aucune reference de conflit en debut de ligne n'est presente dans `src` ou `docs`.

### Angles morts

- Angle mort : le contact de `ChestOpen` doit etre valide en Play Test avec le modele final, car certains meshes importes peuvent avoir des parties sans collision/touch selon leur configuration.
- Angle mort : la distance de securite `24` studs est un premier reglage ; elle peut etre trop courte si le pack elite a une grande taille visuelle.

### Rollback conceptuel

- Revenir a l'etat precedent revient a retirer le suivi `ElitePackId`, le spawn `ChestOpen`, le mode reward de `ChestService`, et a remettre le pack elite centre sur la shrine.

## 2026-07-10 19:05:50 +02:00 - DifficultTotem et difficulte additive

### Contexte

Un nouveau template `DifficultTotem` a ete ajoute au projet. Il doit etre genere comme les autres objets de run et permettre au joueur d'augmenter volontairement la difficulte de la run.

### Diagnostic

- Juste : le totem ne doit pas etre code dans `ShrineService`, car il ne propose pas de perk et ne suit pas la logique de charge des shrines.
- Juste : l'effet de difficulte doit rester serveur, car il impacte le spawn et la pression ennemie.
- Simplification : la V1 applique la difficulte sur deux leviers deja existants, le nombre maximal d'ennemis vivants et l'intervalle de spawn.

### Changements

- `src/shared/TotemConfig.luau` ajoute la configuration `DifficultTotem`, son dossier template, son runtime, ses distances et son bonus de difficulte `5%`.
- `src/server/TotemService.luau` genere 5 `DifficultTotem` repartis sur la surface jouable.
- `src/server/TotemService.luau` ajoute un `ProximityPrompt` serveur et desactive chaque totem apres activation.
- `src/server/MonsterService.luau` ajoute une difficulte additive globale de run.
- `src/server/MonsterService.luau` expose `AddDifficultyPercent`, puis applique le multiplicateur au max d'ennemis vivants et a l'intervalle de spawn.
- `src/server/TemplateService.luau` cree/migre `ServerStorage/TotemTemplates` et `Workspace/TotemsRuntime`.
- `src/server/WorldSpawnService.luau` exclut `TotemsRuntime` des raycasts de placement.
- `src/server/GameManager.server.luau` demarre `TotemService` apres `MonsterService`.
- `src/shared/DebugConfig.luau` active la categorie console `Totem`.

### Proof of done local

- Juste : `rojo build -o TestRoblox.rbxlx` passe.
- Juste : `git diff --check` ne remonte que les warnings CRLF habituels.
- Juste : aucune reference de conflit en debut de ligne n'est presente dans `src` ou `docs`.

### Angles morts

- Angle mort : le ressenti de +5% par totem doit etre valide en Play Test, car `math.ceil` rend le max alive visible rapidement sur les petites valeurs.
- Angle mort : le placement final depend de la taille du modele `DifficultTotem`; si le modele est tres large, `SpawnWorldMinObjectDistance` devra etre augmente.

### Rollback conceptuel

- Revenir a l'etat precedent revient a retirer `TotemService`, `TotemConfig`, le runtime `TotemsRuntime`, et l'appel `AddDifficultyPercent` dans le combat.

## 2026-07-10 19:24:38 +02:00 - Messages HUD evenementiels

### Contexte

Les activations de run commencent a avoir un poids gameplay : `DifficultTotem` augmente la difficulte et `EliteChallengeShrine` declenche un danger immediat. Le joueur doit recevoir un signal lisible sous le timer, sans melanger la presentation HUD avec les services gameplay.

### Diagnostic

- Juste : les messages doivent etre un systeme HUD dedie, car les evenements vont se multiplier.
- Juste : les styles doivent etre configures par type d'evenement, avec couleur, police, duree et message par defaut.
- Simplification : les services serveur n'envoient qu'un `StyleId` et un message optionnel ; le client garde la responsabilite du rendu.
- Budget de complexite : complexite ajoutee, mais isolee dans `HudMessageService`, `HudMessageConfig` et une zone unique de `CombatUI`.

### Changements

- `src/shared/HudMessageConfig.luau` ajoute la configuration des styles `Default`, `DifficultyTotem` et `EliteChallenge`.
- `src/server/HudMessageService.luau` cree le remote `Hud_ShowEventMessage` et expose `Show` / `Broadcast`.
- `src/server/TotemService.luau` affiche `LA DIFFICULTE AUGMENTE DE 5%` apres activation d'un `DifficultTotem`.
- `src/server/ShrineService.luau` affiche un message orange lors du declenchement effectif d'un pack elite.
- `src/client/CombatUI.client.luau` affiche les messages sous le timer, avec animation d'apparition/disparition et adaptation responsive.
- `src/shared/DebugConfig.luau` active la categorie console `HudMessage`.

### Proof of done local

- Juste : `rojo build -o TestRoblox.rbxlx` passe.
- Juste : `git diff --check` ne remonte que les warnings CRLF habituels.
- Juste : aucune reference de conflit en debut de ligne n'est presente dans `src` ou `docs`.

### Angles morts

- Angle mort : la lisibilite exacte sous le timer doit etre validee en Play Test sur plusieurs resolutions, surtout si plusieurs evenements s'enchainent vite.
- Angle mort : le service remplace le message precedent par le nouveau ; si des evenements critiques doivent etre conserves plus tard, il faudra une file de messages.

### Rollback conceptuel

- Revenir a l'etat precedent revient a retirer `HudMessageService`, `HudMessageConfig`, le bind client `Hud_ShowEventMessage`, et les appels depuis `TotemService` et `ShrineService`.

## 2026-07-10 19:37:46 +02:00 - Interaction coffre normal serveur

### Contexte

Les coffres generes payants ne montraient plus de message d'interaction, alors que les jarres restaient lisibles. Le coffre reward `ChestOpen` ne doit pas afficher de libelle : il s'ouvre au contact.

### Diagnostic

- Juste : les coffres normaux doivent suivre le meme principe robuste que les jarres avec un `ProximityPrompt` serveur.
- Juste : `ChestOpen` doit rester exclu du prompt, car son comportement est un coffre reward gratuit au contact.
- Simplification : le client conserve l'UI de slot et de choix, mais ne dessine plus de BillboardGui d'interaction pour les coffres.

### Changements

- `src/shared/ChestConfig.luau` ajoute `PromptName`, `PromptText` et `PromptObjectText`.
- `src/server/ChestService.luau` ajoute un `ProximityPrompt` aux coffres normaux `Chest` uniquement.
- `src/server/ChestService.luau` declenche l'ouverture serveur depuis le prompt, avec les validations existantes de distance, pause et cout.
- `src/client/ChestClient.client.luau` desactive le label custom cote client pour eviter un doublon avec le prompt natif.

### Proof of done local

- Juste : `rojo build -o TestRoblox.rbxlx` passe.
- Juste : `git diff --check` ne remonte que les warnings CRLF habituels.
- Juste : aucune reference de conflit en debut de ligne n'est presente dans `src` ou `docs`.

### Angles morts

- Angle mort : le prompt natif n'affiche pas le cout dynamique dans cette V1. Le cout reste applique serveur et l'UI d'echec indique les coins manquants.
- Angle mort : si plusieurs joueurs partagent un jour la meme run, un texte de prompt avec cout par joueur devra etre traite differemment.

### Rollback conceptuel

- Revenir a l'etat precedent revient a retirer le `ProximityPrompt` de `ChestService` et a reactiver `CLIENT_CHEST_PROMPTS_ENABLED` dans `ChestClient`.

## 2026-07-10 23:48:22 +02:00 - Teleport run solo reserve

### Contexte

Une plaque de teleport issue de la boutique a ete ajoutee pres du spawner. Le besoin n'est pas un simple deplacement local entre deux plaques : marcher sur `TeleportPart2` doit lancer une run solo dans un serveur reserve, puis positionner le joueur sur le point d'arrivee `TeleportPart1`.

### Diagnostic

- Juste : le lancement de run doit rester serveur, car le client ne doit jamais decider seul d'un teleport inter-serveur.
- Juste : `TeleportPart2` est le seul declencheur ; `TeleportPart1` reste un point d'arrivee pour eviter une boucle `TP1 -> TP2`.
- Simplification : la V1 utilise `TeleportAsync` avec `ShouldReserveServer = true` et des `TeleportData` non sensibles.
- Angle mort traite : en Studio, le teleport reserve n'est pas testable comme en production ; le service simule donc l'arrivee sur `TeleportPart1` pour valider le placement.

### Changements

- `src/shared/RunTeleportConfig.luau` ajoute la configuration du depart `TeleportPart2`, de l'arrivee `TeleportPart1`, du `RunPlaceId` et des donnees de run solo.
- `src/server/RunTeleportService.luau` detecte les touches serveur sur `TeleportPart2`.
- `src/server/RunTeleportService.luau` lance `TeleportService:TeleportAsync` avec `TeleportOptions.ShouldReserveServer = true`.
- `src/server/RunTeleportService.luau` repositionne le joueur sur `TeleportPart1` apres arrivee via `player:GetJoinData().TeleportData`.
- `src/server/RunTeleportService.luau` simule ce repositionnement en Studio pour permettre un Play Test local.
- `src/server/GameManager.server.luau` demarre `RunTeleportService` et le branche au setup/remove joueur.
- `src/shared/DebugConfig.luau` active la categorie console `RunTeleport`.

### Proof of done local

- Juste : `rojo build -o TestRoblox.rbxlx` passe.
- Juste : `git diff --check` ne remonte que les warnings CRLF habituels sur les fichiers touches.
- Juste : aucune reference de conflit en debut de ligne n'est presente dans `src` ou `docs`.

### Angles morts

- Angle mort : en production, le `RunPlaceId` pointe actuellement vers `game.PlaceId`. Si la run devient un autre place Roblox, il faudra remplacer cette valeur dans `RunTeleportConfig`.
- Angle mort : les scripts inclus dans le modele boutique ne sont pas modifies. S'ils continuent a faire un teleport local parasite, il faudra les desactiver dans Studio ou ajouter une neutralisation runtime ciblee.
- Angle mort : la separation lobby/run reste partielle tant que le meme place contient encore les systemes de run et les objets de gameplay.

### Rollback conceptuel

- Revenir a l'etat precedent revient a retirer `RunTeleportService`, `RunTeleportConfig`, l'appel dans `GameManager.server.luau` et la categorie `RunTeleport`.

## 2026-07-10 23:59:10 +02:00 - Etat run apres arrivee TP1

### Contexte

Le teleport reserve etait en place, mais la run pouvait encore etre consideree comme active trop tot : le joueur arrivait ou reapparaissait au `SpawnLocation`, alors que la boucle combat doit commencer seulement apres le passage par `TeleportPart2` et le placement effectif sur `TeleportPart1`.

### Diagnostic

- Juste : `TeleportData` ne doit pas suffire a demarrer la run. Il indique une intention de run, pas une arrivee gameplay validee.
- Juste : `TeleportPart2` reste le declencheur de depart ; `TeleportPart1` reste uniquement un point d'arrivee.
- Simplification : `RunStateService` garde seulement l'etat actif/inactif, et `RunTeleportService` devient responsable de demarrer la run apres placement reussi.
- Angle mort traite : les scripts et touches du modele boutique sont neutralises cote runtime pour empecher un retour parasite `TP1 -> TP2`.

### Changements

- `src/server/RunStateService.luau` n'active plus la run automatiquement avec `TeleportData`.
- `src/server/RunTeleportService.luau` demarre maintenant la run uniquement apres un `movePlayerToArrival` reussi.
- `src/server/RunTeleportService.luau` neutralise les scripts des modeles `TeleportPart1` / `TeleportPart2` et desactive le touch sur `TeleportPart1`.
- `src/server/RunTeleportService.luau` refuse un nouveau teleport si la run du joueur est deja active.
- `src/server/MonsterService.luau` et `src/server/WeaponService.luau` ignorent les joueurs dont la run n'est pas active.
- `src/client/CombatUI.client.luau` bloque le timer et le bouton pause tant que la run n'est pas active.
- `src/shared/DebugConfig.luau` active aussi la categorie console `RunState`.

### Proof of done local

- Juste : `rojo build -o TestRoblox.rbxlx` passe.
- Juste : `git diff --check` ne remonte que les warnings CRLF habituels sur les fichiers touches.
- Juste : aucune reference de conflit en debut de ligne n'est presente dans `src` ou `docs`.

### Angles morts

- Angle mort : les shrines, coffres, jarres et autres objets de map restent encore generes dans le meme place. La separation lobby/run est fonctionnelle pour le combat, mais pas encore architecturale.
- Angle mort : si un script de boutique n'est pas descendant direct d'un modele `TeleportPart1` ou `TeleportPart2`, il peut rester actif et devra etre retire manuellement ou neutralise par nom.
- Angle mort : le comportement reserve-server reel doit etre valide dans une experience publiee, car Studio ne simule pas parfaitement `TeleportAsync`.

### Rollback conceptuel

- Revenir a l'etat precedent revient a retirer `RunStateService`, les gates `IsRunActive` dans `MonsterService` / `WeaponService` / `CombatUI`, et le demarrage post-placement dans `RunTeleportService`.

## 2026-07-11 00:22:10 +02:00 - Suppression runtime de TeleportPart1

### Contexte

Malgre la neutralisation des scripts et du touch, `TeleportPart1` permettait encore un retour parasite vers `TeleportPart2` en Play Test. Le besoin produit est plus simple : `TeleportPart1` doit servir uniquement de repere d'arrivee de run, puis disparaitre de la partie courante.

### Diagnostic

- Juste : supprimer l'item runtime apres placement est plus robuste que superposer une nouvelle neutralisation sur un modele boutique opaque.
- Juste : la suppression doit arriver apres lecture de la position et deplacement du joueur, sinon le service perdrait son point d'arrivee.
- Simplification : `TeleportPart1` n'est pas un interactable ; c'est un marqueur consommable de run.
- Budget de complexite : complexite reduite cote comportement, avec une seule option de configuration `DestroyArrivalAfterUse`.

### Changements

- `src/shared/RunTeleportConfig.luau` ajoute `DestroyArrivalAfterUse = true`.
- `src/server/RunTeleportService.luau` retourne l'instance d'arrivee utilisee par `movePlayerToArrival`.
- `src/server/RunTeleportService.luau` detruit `TeleportPart1` apres deplacement reussi, en Studio comme apres un vrai teleport reserve.
- `src/server/RunTeleportService.luau` log `ArrivalDestroyed` et `Point d'arrivee run supprime apres usage` pour faciliter le Play Test.

### Proof of done local

- Juste : `rojo build -o TestRoblox.rbxlx` passe.
- Juste : `git diff --check` ne remonte que les warnings CRLF habituels sur les fichiers touches.
- Juste : aucune reference de conflit en debut de ligne n'est presente dans `src` ou `docs`.

### Angles morts

- Angle mort : en Studio, la suppression de `TeleportPart1` empeche une deuxieme run dans la meme session Play si le point d'arrivee n'est pas regenere. C'est coherent avec le test actuel, mais il faudra une generation de run propre plus tard.
- Angle mort : si plusieurs objets portent le nom `TeleportPart1`, seul le premier trouve par `Workspace:FindFirstChild(..., true)` sera consomme.

### Rollback conceptuel

- Revenir a l'etat precedent revient a remettre `DestroyArrivalAfterUse = false` ou a retirer l'appel a `destroyArrivalInstance` dans `RunTeleportService`.

## 2026-07-11 01:29:25 +02:00 - Performance V1 serveur 1000 debug

### Contexte

Le combat survivor vise un plafond debug de 1000 ennemis, mais les chemins chauds serveur faisaient encore trop de travail par frame : mouvement monstre au `Heartbeat`, grille de separation reconstruite integralement, recherche de projectile sur tous les monstres, et clonage/destruction continu de monstres, projectiles, XP et coins.

### Diagnostic

- Juste : la premiere passe devait cibler le serveur avant l'interpolation client, car les scans et allocations serveur limitaient deja la boucle de run.
- Juste : une simulation a tick fixe suffit pour la V1 ; le rendu client interpole reste un chantier separe.
- Simplification : `MonsterService` conserve la responsabilite de la grille spatiale et expose seulement une requete proche, sans ajouter un nouveau service transversal.
- Budget de complexite : complexite ajoutee localement par les pools, mais elle remplace des destructions repetees et reste limitee aux services concernes.

### Changements

- `src/shared/CombatConfig.luau` ajoute les reglages de simulation, pools, collision monstre et logs perf.
- `src/server/MonsterService.luau` passe a une simulation fixe 15 Hz, maintient une grille spatiale persistante et expose `GetMonstersNear`.
- `src/server/MonsterService.luau` recycle les monstres dans `ServerStorage/MonsterPools` au lieu de les detruire sur mort, debug clear ou fin de run.
- `src/server/MonsterService.luau` desactive par defaut les animations serveur et les collisions/touch/query des parties de monstres.
- `src/server/WeaponService.luau` passe les projectiles a une simulation fixe 30 Hz et recycle les fireballs dans `ServerStorage/ProjectilePools`.
- `src/server/XpService.luau` et `src/server/CoinService.luau` recyclent les collectibles par tier dans `ServerStorage`, apres delai d'animation de collecte.
- `src/client/CoinClient.client.luau` remet la transparence locale a zero quand un collectible recycle reapparait.
- `src/shared/DebugConfig.luau` active la categorie `Perf` pour les logs throttles.

### Proof of done local

- Juste : `rojo build -o TestRoblox.rbxlx` passe.
- Juste : `git diff --check` ne remonte que les warnings CRLF habituels sur les fichiers touches.
- Juste : aucune reference de conflit en debut de ligne n'est presente dans `src` ou `docs`.
- Juste : `GetClosestMonster` s'appuie maintenant sur `GetMonstersNear` et la grille persistante, plus sur un scan direct de toute la population.

### Angles morts

- Angle mort : le proof perf final doit encore etre fait en Play Test avec le bouton admin jusqu'a approcher 1000 ennemis.
- Angle mort : les Humanoid lourds restent plus couteux que des monstres purement ancres ; la V1 les supporte mieux, mais ne transforme pas encore les rigs en hitbox simplifiee.
- Angle mort : les animations client et l'interpolation visuelle 60 Hz ne sont pas implementees dans cette passe.
- Angle mort : les pools peuvent augmenter jusqu'au pic de population atteint pendant une session ; c'est voulu, mais il faudra surveiller l'InstanceCount.

### Rollback conceptuel

- Revenir a l'etat precedent revient a remettre les ticks Heartbeat directs, retirer les pools ServerStorage, restaurer le scan complet de `GetClosestMonster`, et remettre les destructions directes sur monstres/projectiles/collectibles.
