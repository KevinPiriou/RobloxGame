# Personnages jouables V1 - Fondation de catalogue et de deblocage

## 2026-07-21 22:31:00 +02:00 - Passe fondation isolee

## Etat initial

Commit de reference : `9a26baf`.

Le jeu ne disposait pas de registre de personnages, de contrat de validation
R15, de selection serveur ou de deblocages persistants par personnage et arme.
La Fireball restait le chargement implicite de toute run. Aucun modele R15 de
Magicien et aucun portrait 2D de production n'etaient disponibles.

Un candidat `Wizard StarterCharacter` a ete audite dans Studio puis ecarte :
son rig est R6. Il est incompatible avec le contrat de personnage canonique
R15 et ne doit pas etre reutilise comme contournement visuel.

## Modification livree

- ajout de `CharacterConfig.luau`, registre declaratif du Magicien ;
- ajout de `CharacterDefinitionValidator.luau`, qui impose notamment :
  `Lifecycle = Production`, portrait 2D, apparence R15, template visuel,
  arme principale et passif declaratif valide ;
- ajout de `CharacterService.luau`, proprietaire serveur de la lecture du
  roster et de la selection future ;
- ajout des deblocages persistants `UnlockedCharacterIds` et
  `UnlockedWeaponIds` dans `MetaProgressionService`, avec migration additive
  vers la version de donnees `3` ;
- Magicien et Fireball sont marques debloques par defaut afin de ne pas exiger
  de migration manuelle lors de l'activation future ;
- les remotes de roster sont prepares, mais aucune interface ne les consomme
  encore et aucune selection ne peut modifier une run existante.

## Decision

`Keep` pour la fondation de donnees et la validation ; `Defer` pour le
personnage jouable lui-meme.

Le Magicien reste volontairement en `Draft`. Son absence de portrait et de
template R15 rend sa selection non activable par le serveur. Le comportement
canonique existant est donc preserve : avatar Roblox dans le lobby, Fireball
et combat actuels en run, sans nouvelle couche de fallback.

## Verification

- `rojo build --output %TEMP%\\MegaRoblox-character-foundation.rbxlx` : vert ;
- `git diff --check` : vert ;
- compilation des nouveaux modules et de leur branchement dans
  `GameManager.server.luau` : validee par Rojo.

## Budget de complexite

Cette passe ajoute trois modules courts et un schema de persistance. Elle ne
modifie ni le `WeaponService`, ni les degats, ni la simulation, ni le cycle de
vie des runs. La complexite gameplay est donc nulle a ce stade ; la nouvelle
complexite reste bornee au contrat et a la metaprogression.

## Angles morts

- le snapshot de personnage au lancement de run n'est pas encore construit ;
- le remplacement R15 en run et le retour a l'avatar Roblox au lobby ne sont
  pas encore implementes ;
- le passif `PrimaryWeapon` ne doit pas etre exporte a MetaBuildLab tant que
  le laboratoire ne sait pas modeliser son scope sans le transformer en bonus
  global ;
- aucune selection visuelle ne doit etre exposee avant reception d'un modele
  R15 et d'un portrait 2D valides.

## Conclusion

Le projet possede maintenant le socle necessaire pour representer et
deverrouiller des personnages sans prejuger de leur rendu. Le refus du
Wizard R6 est intentionnel : un personnage incomplet vaut mieux qu'un faux
personnage de production qui casserait le contrat de rig et les futures
animations.

## 2026-07-21 22:32:00 +02:00 - Contrats de contenu Medivh et Albert

Les deux premiers contrats de personnage sont declares dans
`CharacterConfig.luau` :

- `medivh` : arme primaire `fireball`, passif `WeaponCategory = Projectile`
  ajoutant `+1 ProjectileCount` a chaque arme projectile ;
- `albert` : arme primaire `leyden_needle`, passif joueur multipliant le
  rayon de collecte de base par `3`.

Le multiplicateur d'Albert est volontairement `MultiplyBase` : les futurs
bonus additifs de collecte gardent leur valeur propre au lieu d'etre eux aussi
triples sans contrat explicite.

Ces definitions restent en `Draft`. Medivh est le personnage de depart dans
la metaprogression ; Albert conserve un deblocage `Deferred` tant que sa voie
unique de deblocage n'a pas ete choisie. Aucun passif ne s'applique tant que
la selection, le snapshot de run et les assets R15 ne sont pas valides.
