# TODO - Pipeline personnages jouables V1

## Suite bloquee par les assets canoniques

Le chantier personnages ne peut pas passer a la selection et a la production
tant que le Magicien ne dispose pas des deux assets suivants :

1. un modele visuel R15 valide, destine a etre applique au rig joueur
   canonique sans modifier hitbox, joints ni collisions ;
2. un portrait 2D de production pour le roster et les interfaces futures.

Les contrats de contenu deja declares sont :

- Medivh : Fireball et `+1` projectile par arme de categorie Projectile ;
- Albert : Aiguille de Leyde et rayon de collecte de base `x3`.

Albert reste sans voie de deblocage definitive (`Deferred`) ; cette voie doit
etre arretee avant son passage en `Production`.

## Reprise prevue

1. placer le template R15 dans `ServerStorage.CharacterTemplates.Magician` ;
2. renseigner le portrait et passer la definition de `Draft` a `Production` ;
3. ajouter un point d'entree de selection dans le lobby ;
4. capturer le personnage selectionne dans `RunSessionService` avant la
   generation, puis verifier personnage et arme principale cote serveur ;
5. appliquer l'apparence R15 au lancement de run et restaurer l'avatar Roblox
   au retour lobby ;
6. brancher le passif declaratif sur les statistiques existantes, avec son
   scope exact ;
7. etendre MetaBuildLab uniquement apres avoir modelise les scopes de passif
   sans approximation silencieuse ;
8. realiser le smoke canonique : selection, lancement, mort, retour lobby,
   relance, refus d'un personnage verrouille et conservation des regles de
   combat Fireball.
