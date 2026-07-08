# Vision long terme Megabonk-like

## 2026-07-08 02:35:28 +02:00 - Capture initiale de vision

### Intention produit

Le projet vise une boucle roguelite/survivor inspiree fortement de Megabonk : un lobby social, puis des runs solo instanciees ou le joueur augmente sa puissance, explore une map procedurale, collecte des ressources, ouvre des coffres, active des autels, survit sous pression ennemie et doit battre un boss pour valider le niveau.

### Structure cible

- Lobby commun avec classements globaux.
- Lobby avec changement de skin.
- Lobby avec microtransactions.
- Lobby avec selection de niveau selon les niveaux deja termines.
- Run instanciee solo : un seul joueur dans la run.
- Generation procedurale de la map au lancement de run.
- Validation du niveau via boss obligatoire.
- Progression de puissance pendant la run via XP, perks, autels, coffres, armes et gemmes.

### Elements de map cibles

- Blocs carres et rectangles.
- Pentes.
- Hauteurs differentes.
- Autel du boss de niveau.
- Autels de perks.
- Coffres.
- Totems, dont un totem de difficulte et un totem de magnetisme XP/pieces.
- Petites jarres.
- Decorations : arbres, cailloux et autres elements de lisibilite.

### Contrat d'interaction cible

- Les autels, totems boss, autels perks et coffres doivent afficher un `!` visible de loin tant qu'ils sont activables.
- Les coffres disparaissent apres ouverture.
- Les jarres disparaissent apres destruction/ouverture.
- Les autels perks restent en place.
- Les autels boss restent en place.

### Build joueur cible

- Le joueur peut cumuler jusqu'a 4 armes.
- Les armes agissent de maniere independante, pas en succession.
- Le joueur peut cumuler jusqu'a 4 gemmes thematiques.
- Les gemmes sont des accelerateurs de perks.
- Le jeu proposera 10 personnages jouables.
- Chaque personnage aura une evolution differente.

### Boucle de run cible

- Le joueur spawn dans une map generee.
- Un minuteur de survie cadence la run.
- Les ennemis mettent une pression croissante.
- Le joueur doit augmenter sa puissance via leveling, perks, coffres et autels.
- Le joueur doit battre le boss du niveau pour valider le niveau.

### Decisions de cadrage

- Juste : la run solo instanciee simplifie fortement les problemes de pause, coffres consommes, autels et progression temporaire.
- Juste : les interactables doivent partager un contrat commun plus tard : detection, `!` de loin, prompt proche, activation serveur, consommation ou maintien.
- Simplification : les coffres actuels sont une premiere brique d'interactable, pas encore le systeme generique final.
- Contestable : lobby social et microtransactions changent fortement le scope backend/persistance. Cela devra etre separe du gameplay de run.

### Angles morts

- Angle mort : la generation procedurale de map aura besoin d'un contrat de navigation ennemie, spawn joueur, spawn loot et surface valide.
- Angle mort : le systeme de sauvegarde devra separer clairement progression permanente, progression de run et achats.
- Angle mort : les microtransactions impliquent des contraintes Roblox et produit qui ne doivent pas etre melangees trop tot avec le combat.
- Angle mort : 4 armes independantes peuvent devenir couteuses avec beaucoup d'ennemis ; il faudra cadrer projectiles, tick rate et culling.
- Angle mort : les personnages jouables demandent un modele de stats/evolution qui ne doit pas etre code en dur dans les services de combat.

### Decoupe conseillee future

- Definir un `RunService` serveur qui porte l'etat d'une run solo.
- Definir un contrat `InteractableService` avant de multiplier coffres, autels, totems et jarres.
- Definir un schema de recompenses avant de rendre `Valider` fonctionnel sur les coffres.
- Stabiliser la boucle ennemis/XP/perks avant de lancer la generation procedurale.
- Construire les assets simples de map en Studio avant de generer proceduralement leur placement.

### Budget de complexite

- Complexite future : elevee.
- Point de vigilance : ne pas transformer les services actuels en mega-scripts. Les coffres, autels, totems, armes, gemmes, personnages et runs devront rester des modules separes avec des contrats simples.
- Voie de simplification : conserver une run solo canonique sans lobby complet jusqu'a ce que combat, XP, perks, coffres et boss soient robustes.
