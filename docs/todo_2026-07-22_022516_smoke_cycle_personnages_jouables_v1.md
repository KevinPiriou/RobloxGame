# TODO - Smoke du cycle des personnages jouables V1

Date : 2026-07-22 02:25:16

## Etat technique

- La selection du personnage est stockee dans le profil du joueur concerne.
- Le lancement capture un snapshot immuable contenant le personnage, son arme principale et ses skins.
- Le snapshot voyage avec la session et les donnees de teleportation du joueur uniquement.
- Le serveur de run initialise l'arme principale et les passifs depuis ce snapshot.
- L'apparence de run est appliquee au personnage du joueur puis l'apparence Roblox precedente est restauree en fin de run.
- Le skin d'arme est persiste par personnage dans le profil meta existant.
- Le teleport de production conserve une liste d'un seul joueur et demande un serveur reserve.

## Smoke manuel canonique restant

1. Depuis le lobby, selectionner Medivh puis lancer une run.
2. Verifier que Fireball est la seule arme initiale et que la salve de base profite de son projectile supplementaire.
3. Verifier le nom Medivh, les vetements de run et un rayon de collecte normal.
4. Terminer la run, revenir au lobby et verifier la restauration de l'avatar Roblox.
5. Relancer une run sans refaire la selection et verifier que Medivh et son skin d'arme persistent.
6. Avec Albert et Aiguille de Leyde debloques independamment, verifier l'arme initiale unique et le rayon de collecte de base multiplie par trois.
7. Verifier qu'un skin Fireball ne peut pas etre selectionne pour Albert.
8. En test multijoueur publie, verifier que le depart d'un joueur ne modifie ni la selection ni le monde des autres joueurs restes au lobby.

## Angle mort explicite

La simulation Studio d'une run utilise un Workspace partage et masque le lobby globalement pour rendre le test solo possible. Elle ne reproduit donc pas a elle seule l'isolation entre un serveur lobby public et un serveur de run reserve. Le cas multijoueur doit etre valide sur un serveur publie.

## Critere de cloture

Le chantier pourra recevoir un `post_audit` uniquement apres validation des cas ci-dessus ou apres consignation explicite des cas bloques par l'absence temporaire d'une route de deblocage pour Albert.
