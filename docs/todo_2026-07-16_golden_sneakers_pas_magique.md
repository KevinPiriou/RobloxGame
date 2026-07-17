# TODO Golden Sneakers et pas magique

## 2026-07-16 16:34:47 +02:00 - Effet a definir avant mise en recompense

### Constat

Le catalogue contient l'objet `golden_sneakers` avec le texte `+5% de frequence de pas magique`.
La recherche des scripts serveur, client et partages ne trouve aucun systeme nomme
pas magique, magic step, ni aucun declencheur equivalent. Il n'existe donc aucune
frequence actuelle a augmenter ni comportement de jeu auquel relier ce bonus.

L'objet reste visible dans le catalogue, mais est volontairement absent de
`ChestRewardIds`. Le laisser tomber dans un coffre sans effet serait une dette
produit visible et un faux objet implemente.

### Decision de perimetre

Les douze autres objets du catalogue sont raccordes : bonus de statistiques,
cartes qui progressent a chaque coffre, et dent de vampire qui progresse a
chaque elimination. Golden Sneakers attend la definition explicite du pas
magique avant d'etre ajoute au pool de recompenses.

### Informations necessaires

- Declencheur : distance parcourue, pas physiques, temps de course, ou autre evenement.
- Effet d'un pas magique : degats, soin, collecte, projectile, gain de ressource, ou VFX seulement.
- Cible et rayon eventuels, cooldown de base et conditions d'annulation.
- Interpretation du `+5%` : multiplicateur de frequence, reduction de cooldown,
  ou ajout de probabilite par pas.

### Proof of done attendu

1. Golden Sneakers apparait dans les coffres uniquement apres qu'un pas magique
   produise un effet serveur observable.
2. Un exemplaire augmente sa frequence selon la regle choisie ; plusieurs
   exemplaires s'empilent sans provoquer de declenchements en rafale.
3. Le reset de run retire integralement le bonus et un respawn pendant la run
   conserve le bonus actif.

### Angle mort et budget de complexite

- Angle mort : inventer l'effet a partir du seul nom risquerait de dupliquer la
  vitesse de deplacement, les gemmes arcaniques ou une autre mecanique future.
- Simplification : un point d'extension isole dans le futur systeme de pas
  magique est preferable a l'ajout d'une statistique non consommee dans
  `PerkService`.

## Addendum - 2026-07-16 16:39:26 +02:00 - Raccorde au score de pas courant

La direction produit precise que Golden Sneakers doit, pour l'instant, agir
sur les pas normaux. L'objet est donc reintegre dans `ChestRewardIds` et ajoute
un multiplicateur de `+5 %` par exemplaire au score produit par la distance
parcourue a pied dans `RunScoreService`.

Cette integration conserve le rail futur : les zones de pas pourront appeler
`RunScoreService.GetStepScoreMultiplier` sans redefinir le comportement de
Golden Sneakers.
Le bonus ne touche ni les coins, ni l'XP, ni la vitesse de deplacement.
