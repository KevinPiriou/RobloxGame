# post_audit - Collection de pieces

Date: 2026-07-07 16:13:43 +02:00

## Contexte

Cette passe ajoute une premiere boucle de collection de pieces a partir d'un asset 3D nomme `Coin` place dans l'arborescence Roblox. L'objectif est de conserver la map construite dans Roblox Studio et d'ajouter uniquement la logique Rojo necessaire.

## Changements appliques

- Ajout de `CoinService.luau` cote serveur.
- Ajout de `CoinClient.client.luau` cote client.
- Detection serveur des pieces nommees exactement `Coin` dans `Workspace`.
- Support des pieces sous forme de `BasePart` ou de `Model`.
- Rotation visuelle des pieces cote client.
- Detection serveur de proximite joueur/piece.
- Animation locale d'attraction vers le joueur lors de la collecte.
- Suppression serveur de la piece apres collecte.
- Attribution serveur de `CoinsPerPickup` pieces au joueur.
- Compteur `Pieces : N` ajoute dans l'UI.
- Sauvegarde DataStore des pieces dans `CoinProgress_v1`.

## Proof of done

- `rojo build -o "$env:TEMP\TestRoblox_quiz_build.rbxlx"` passe.
- Le client ne peut pas s'attribuer une piece.
- La proximite et l'attribution sont decidees cote serveur.
- Les remotes utilises sont `Coin_UpdateCount` et `Coin_PlayCollect`.

## Angles morts

- L'asset doit etre visible dans `Workspace` et porter exactement le nom `Coin`.
- Si l'asset est un `Model`, il doit contenir au moins un `BasePart`.
- La collection supprime la piece de la session serveur. Il n'y a pas encore de respawn automatique.
- La persistance des pieces depend de DataStore, donc de l'acces API en Studio ou d'une experience publiee.
- Le compteur affiche `*` si la derniere sauvegarde a echoue.

## Budget de complexite

Cette passe ajoute de la complexite, mais elle est separee en deux responsabilites simples: `CoinService.luau` garde l'autorite gameplay et `CoinClient.client.luau` gere uniquement le rendu local. La map reste hors Rojo.
