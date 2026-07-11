# 2026-07-12 00:41 CEST - Onglets du menu lobby

## Perimetre realise

`LobbyPanels` est passe d'une liste statique a une surface de lobby a onglets, sans modifier le contrat deja en place avec `LobbyShortcutMenu`.

- Boutique : Boutique, Soutenir le studio, Token de temps et Roue de la chance ;
- Quetes : Quetes et Quetes journalieres ;
- Deblocages : Personnages, Armes, Gemmes et Capacites ;
- Refuge : Hauts faits, Statistiques et Nourrice.

Les onglets Boutique et Deblocages utilisent des cartes carrees en grille. Les Quetes et Hauts faits utilisent des cartes rectangulaires en colonne. L'onglet Statistiques est une carte double avec l'avatar Roblox du joueur a gauche et des compteurs cumules placeholders a droite.

## Direction visuelle

La surface reprend les conventions du choix de perks : cadre double, gemme decorative, titre centre, accent propre a chaque section et cartes a bord colore. Le panneau, ses cartes et son en-tete sont maintenant translucides et legerement sombres pour conserver la lisibilite tout en laissant apparaitre le lobby derriere.

## Contrat fonctionnel

- les onglets sont interactifs uniquement localement ;
- les items ne declenchent aucun achat ni aucune transaction Robux ;
- les prix Robux, tokens, progressions, statistiques et recompenses sont des placeholders d'interface ;
- le menu reste masque pendant une run, selon la regle deja portee par `LobbyShortcutMenu`.

## Validation technique

- `rojo build -o TestRoblox.rbxlx` termine avec succes ;
- `git diff --check` ne remonte aucune erreur de contenu ;
- aucune marque de conflit Git n'est presente dans `src` et `docs`.

## Smoke manuel canonique a effectuer dans Studio

1. Hors run, ouvrir chacun des quatre raccourcis lobby et parcourir tous leurs onglets.
2. Verifier que les cartes Boutique et Deblocages restent carrees sur une fenetre large et sur une petite fenetre.
3. Verifier que les Quetes et Hauts faits defilent verticalement si leur contenu depasse.
4. Ouvrir Statistiques et verifier que l'avatar charge ou que le placeholder reste present sans erreur.
5. Lancer une run avec un panneau ouvert : aucun panneau lobby ne doit rester visible.

## Angles morts

- Le flou spatial de type glassmorphism n'existe pas nativement pour une Frame Roblox ; cette passe emploie donc une transparence et des teintes sombres, sans effet de blur trompeur.
- Les achats Robux devront etre relies plus tard a des Developer Products, avec validation serveur et gestion des echecs.
- Les statistiques, quetes, hauts faits et la Nourrice exigent encore leurs sources de donnees serveur et leur persistance.

## Addendum - 2026-07-12 01:08 CEST

Les panneaux Boutique, Quetes, Deblocages et Refuge sont maintenant ancres au centre de l'ecran sur desktop comme sur mobile. Leur dimension reste responsive, mais le menu lateral ne decale plus la fenetre ouverte.
