# 2026-07-11 - Boss de niveau et cloture de run V1

## Objectif realise

La run dispose maintenant d'un evenement boss declenche depuis `PortalBoss` :

- le portail propose une interaction `E` uniquement pendant une run active ;
- le combat est mis en pause pendant l'annonce HUD du boss ;
- le boss apparait apres l'annonce, a une distance de securite du joueur et sur la surface raycastee ;
- sa barre de vie remplace l'emplacement du message HUD apres l'annonce ;
- le boss utilise provisoirement le comportement de poursuite et de contact d'un monstre classique ;
- ses statistiques V1 sont de `1000` PV et `3x` les degats d'un monstre normal ;
- sa mort valide le niveau pour la run et propose soit la survie pour le score, soit la sortie du niveau.

## Architecture ajoutee

- `BossService` possede l'etat du boss, le delai d'annonce, la pause, le choix post-victoire et les remotes client.
- `RunEndService` capture le resultat avant de reinitialiser XP, niveau, coins, perks, cout des coffres, kills, difficulte et collectibles de run.
- `MonsterService` accepte maintenant les valeurs de vie et de degats explicites pour un monstre special, sans dupliquer sa boucle de deplacement.
- `RunTeleportService` retourne vers le lobby public apres une mort. En Studio, le retour est simule par un respawn local afin de rester testable.
- `BossUI.client.luau` affiche la barre et les deux choix post-boss. `RunSummaryUI.client.luau` affiche le resultat final.

## Regle de template

Le boss cherche `ServerStorage/CombatTemplates/Boss1` en premier. Tant que ce modele n'existe pas, il utilise `Monster1_Elite` en fallback avec un warning serveur explicite. Le son du boss reste configure mais vide dans `BossConfig` tant que son asset Roblox n'est pas importe.

## Validation technique

- `rojo build -o TestRoblox.rbxlx` termine avec succes.
- `git diff --check` ne remonte pas d'erreur de contenu.
- Aucun marqueur de conflit Git n'est present dans `src` ou `docs`.

## Smoke manuel canonique

1. Lancer une run puis atteindre le portail : `E` doit afficher l'annonce, suspendre le combat puis faire apparaitre le boss hors de la zone de contact immediate.
2. Infliger des degats : la barre doit passer de `1000 / 1000` a `0 / 1000` sans desynchroniser le monstre et les coups recus.
3. Tuer le boss : choisir `Continuer` doit reprendre les ennemis ; choisir `Quitter le niveau` doit afficher le resultat puis renvoyer au lobby.
4. Mourir avant ou apres le boss : le lobby et le resultat doivent apparaitre avec des statistiques de run figees, puis une nouvelle run doit repartir au niveau 1, zero coin, zero perk et zero kill.

## Angles morts

- La validation du niveau est actuellement garantie pour la run et affichee dans le resultat, mais le compteur persistant de niveaux valides et son leaderboard ne sont pas encore implementes. Ils devront etre ajoutes dans un service de progression dedie, pas dans `BossService`.
- Les objets de la map runtime ne sont pas regeneres dans une meme session Studio apres une run. En production, chaque run reservee est une nouvelle session et repart donc avec ses objets generes. Un futur mode de re-run Studio pourra ajouter un reset complet du monde runtime.
- Le boss n'a intentionnellement ni pattern, ni drop special, ni modele `Boss1` impose dans cette V1.

## Ajustement - barre et statistiques du boss

Suite au premier retour de Play Test :

- la barre de vie du boss est decalee a `96` pixels depuis le haut afin de laisser la top bar visible ;
- l'activation du portail ne met plus le combat en pause ; seule la decision apres la mort du boss conserve une pause ;
- la distance de securite du spawn reste celle configuree pour les elites ;
- le boss passe a `7500` PV ;
- sa vitesse est multipliee par `1,2`, aussi bien pour les rigs Humanoid que pour les modeles deplaces directement.

## Pattern V1 - cone de bulles

Le premier pattern du boss est implemente dans `BossAttackService` :

- apres quatre secondes, puis toutes les huit secondes, le boss forme un cone devant sa direction de regard ;
- le cone contient six rangees de `1` a `6` bulles, soit vingt-et-une bulles au maximum ;
- chaque position est raycastee avec `WorldSpawnService` afin de rester sur le sol jouable ;
- les bulles rouges telegraphient pendant `2,2` secondes, puis explosent ;
- le serveur evalue la presence du joueur a l'explosion et limite la salve a un impact maximum ;
- le pattern est annule immediatement a la mort du boss ou a la fin de la run.

Les degats du cone sont actuellement egaux aux degats de contact du boss, donc `24` avant armure. Tous les reglages sont centralises dans `BossConfig` pour l'equilibrage.

## Ajustement - portee et lisibilite du cone

- Les six rangees sont conservees, mais leur profondeur est doublee : la derniere rangee est maintenant a environ `66` studs du boss au lieu de `33`.
- La largeur du cone et le nombre de bulles restent inchanges.
- Le telegraphe visuel devient plus translucide afin de mieux laisser lire le terrain et le personnage.

## Ajustement - degats et cadence aleatoire

- Les degats des bulles sont doubles par rapport au contact du boss : `48` avant armure.
- Le delai avant la premiere salve et entre chaque salve est tire aleatoirement entre `4` et `10` secondes cote serveur.

## Pattern V2 - cone sequentiel

Une seconde variante du cone est selectionnee aleatoirement a chaque attaque :

- les six rangees apparaissent dans l'ordre, avec `0,3` seconde entre deux rangees ;
- chaque rangee explose `2,2` secondes apres sa propre apparition, dans le meme ordre ;
- la direction et l'origine sont figees au lancement pour garder une forme de cone coherente pendant le deplacement du boss ;
- les deux variantes peuvent se repeter aleatoirement, mais le delai aleatoire minimum de quatre secondes entre les debuts de patterns reste garanti.

## Pattern V3 - serie ciblee

Une troisieme variante est maintenant possible :

- entre deux et cinq bulles apparaissent successivement sur les coordonnees au sol de la position courante du joueur ;
- l'intervalle entre deux apparitions est tire aleatoirement entre `0,2` et `0,8` seconde ;
- chaque bulle possede son propre delai de `2,2` secondes avant explosion, calcule au moment de son apparition ;
- chaque explosion peut toucher le joueur independamment, ce qui rend le deplacement entre les impacts necessaire ;
- les bulles passent a un rayon de `2,5` et a un telegraphe plus translucide.

## Ajustement - ciblage vertical de la serie

La serie ciblee ne raycaste plus le sol. Chaque nouvelle bulle est creee aux coordonnees 3D exactes du `HumanoidRootPart` au moment de son apparition, ce qui inclut la hauteur de saut du joueur. Les bulles deja creees restent en place afin de conserver une zone a eviter lisible.
