# 2026-07-12 00:49 CEST - DA vitree des interfaces de run

## Perimetre realise

La nouvelle direction vitree legere du menu lobby est appliquee aux quatre surfaces de run demandees :

- choix de perks ;
- ouverture de coffre ;
- panneau Statistiques de run ;
- top bar avec kills, or, pause et temps.

Les panneaux utilisent maintenant des teintes bleu-noir translucides, une variation verticale discrete, un cadre sombre fin et un accent conserve par surface. Les cartes de perks et les lignes de statistiques laissent davantage apparaitre le monde 3D sans perdre leur contraste de lecture.

## Contrat preserve

Cette passe est strictement visuelle :

- aucun RemoteEvent, callback ou calcul serveur n'a ete modifie ;
- la pause, le timer, les choix de perks et les choix de coffre gardent leurs comportements existants ;
- la top bar conserve ses icones, son formatage de compteurs et sa responsivite existante.

## Validation technique

- `rojo build -o TestRoblox.rbxlx` termine avec succes ;
- `git diff --check` ne remonte aucune erreur de contenu.

## Smoke manuel canonique a effectuer dans Studio

1. Mettre la run en pause et verifier que le panneau Statistiques reste lisible sur une scene claire et sur une scene sombre.
2. Monter de niveau, ouvrir le choix de perks et verifier que les trois cartes restent faciles a distinguer avec une rarete commune, rare, epique et legendaire.
3. Ouvrir un coffre normal puis un coffre de recompense elite ; verifier le reel, Passer et Valider.
4. Demarrer une run, puis verifier les compteurs kills, or, temps et le bouton pause a plusieurs resolutions.
5. Rejouer le cas simple deja maitrise : lancer une run, tuer un monstre, collecter son drop, monter de niveau et reprendre le combat apres le choix.

## Angles morts

- Roblox ne propose pas de flou spatial natif pour une Frame ; l'effet repose donc sur la transparence et les gradients, pas sur un blur reel.
- La validation produit visuelle dans Roblox Studio reste necessaire : le build Rojo ne peut pas juger le contraste reel selon les maps et l'eclairage.

## Addendum - 2026-07-12 00:54 CEST

Le groupe bas du HUD a ete aligne sur cette DA : les lectures PV, bouclier et XP disposent desormais chacune de leur propre surface vitree, avec un accent vert, cyan ou violet. Les dimensions, valeurs, animations de remplissage et regles responsive n'ont pas ete modifiees.

## Addendum - 2026-07-12 01:14 CEST

Le HUD PV, bouclier et XP a ete reequilibre : hauteur portee a 80 pixels, icones agrandies, icone de bouclier alignee au debut de sa barre, cadre general neutralise et surfaces individuelles conservees par couleur. Un losange central cyan-violet-ivoire separe les lectures PV et bouclier sans modifier les donnees de combat.
