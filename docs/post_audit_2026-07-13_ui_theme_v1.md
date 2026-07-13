# 2026-07-13 02:25 CEST - UiTheme V1 et finitions metal-verre

## Objectif realise

La DA actuelle est centralisee sans changement volontaire de geometrie, de contenu ou de logique d'interface.

Le nouveau module partage `src/shared/UiTheme.luau` regroupe :

- la palette commune, les polices Gotham, les icones HUD et les couleurs de rarete ;
- les contextes historiques par ecran pour conserver les nuances deja reglees du HUD, des perks, des coffres, des prompts, du lobby, de l'audio, des statistiques et du launcher ;
- les primitives `AddCorner`, `AddStroke` et `AddGradient` ;
- la finition optionnelle `AddSurfaceFinish`.

Cette finition ajoute un reflet vitre, une ligne metallique haute, une ombre basse et trois micro-reflets colores. Elle reste non interactive et est placee sous les contenus afin de ne pas intercepter les boutons.

## Ecrans relies au theme

- HUD de combat : top bar, panneaux PV/bouclier/XP et surfaces de run ;
- choix de perks ;
- ouverture de coffre ;
- prompts d'interaction ;
- panneaux lobby et raccourcis du menu lateral ;
- launcher de chapitre ;
- statistiques de run, recapitulatif de fin, panneau audio, panneau admin et interface boss.

## Contrat preserve

- aucun RemoteEvent, RemoteFunction, service serveur ou calcul de combat n'a ete modifie ;
- les dispositions, tailles et comportements des panneaux existants sont conserves ;
- les nuances deja utilisees par chaque ecran restent disponibles dans `UiTheme.Contexts`, ce qui evite une recolorisation involontaire de la DA ;
- aucune map, aucun asset 3D et aucun fichier `default.project.json` n'a ete modifie.

## Validation technique

- `rojo build -o $env:TEMP\\TestRoblox-ui-theme.rbxlx` termine avec succes ;
- `git diff --check` ne remonte pas d'erreur de contenu ;
- aucun marqueur de conflit Git n'est present dans `src` ou `docs` ;
- aucun analyseur Luau autonome n'est installe localement. Le build Rojo valide la structure, mais le smoke Studio reste requis pour le rendu effectif.

## Smoke manuel canonique bloquant

1. Depuis le lobby, ouvrir puis fermer chaque panneau lateral, puis le launcher de chapitre.
2. Lancer une run : verifier la top bar, les surfaces PV/bouclier/XP et le bouton pause sur une zone claire puis sombre.
3. Declencher un prompt d'interaction, un choix de perk et un coffre ; verifier que les clics et le maintien de touche restent actifs.
4. Ouvrir le panneau audio et le panneau admin ; verifier que les reflets ne masquent aucun texte ni bouton.
5. Terminer ou perdre une run et verifier le recapitulatif puis la barre de boss lors d'une run avec portail.

## Angles morts et budget de complexite

- ~ Les effets de texture sont proceduraux : Roblox ne fournit pas de bruit bitmap, de flou spatial ni de materiau metal UI natif sur les `Frame`.
- ◐ Une texture bitmap transparente importee plus tard peut etre branchee dans le theme, mais ne doit etre ajoutee qu'apres verification de son cout de rendu sur mobile.
- ✓ La passe ajoute une petite complexite centralisee dans un seul module et retire des duplications dans les ecrans clients ; elle ne modifie aucun chemin gameplay.
- ◐ Le rendu reel depend de l'eclairage des maps et doit etre valide dans Roblox Studio avant de considerer le chantier visuel clos.
