# 2026-07-11 - Lissage visuel et reduction des hitches

## Objectif

Conserver la simulation serveur de monstres a 15 Hz, choisie pour rendre le plafond de debug
de 1000 ennemis plus accessible, sans laisser ce pas de simulation apparaitre comme un
mouvement a 15 FPS cote joueur. Reduire egalement les pics locaux lies aux nombreux collectibles.

## Implementation

- Ajout de `MonsterVisualInterpolation.client.luau` : seuls les monstres runtime proches et
  visibles sont interpolés a chaque frame cote client entre deux positions serveur. Le serveur
  garde l'autorite complete sur les positions, spawns, degats et morts.
- La zone de lissage est volontairement bornee par `MonsterVisualMaxDistance = 170` et mise a
  jour toutes les `0.2` secondes. Les centaines de monstres hors champ ne recoivent donc pas
  de `PivotTo` local par frame.
- Les rotations passives des coins et gemmes passent de chaque frame a 30 Hz.
- Les animations d'attraction XP/coin sont centralisees dans une seule boucle client et
  plafonnees a 72 simultanees. Au-dela du plafond, le collectible reste gagne cote serveur mais
  disparait localement sans animation individuelle supplementaire.
- Les logs `Perf` exposent maintenant le maximum de tick monstre, de scan/fusion XP et de
  scan/fusion coin sur chaque fenetre de cinq secondes. Les pics de frame client superieurs a
  120 ms sont egalement journalises avec le nombre de monstres lisses.

## Parametres a tester

- `MonsterVisualInterpolationDuration = 0.065` : augmenter legerement vers `0.075` si le
  mouvement reste trop sec; reduire vers `0.05` si les monstres semblent en retard.
- `MonsterVisualMaxDistance = 170` : baisser vers `140` si le client doit privilegier les
  performances, augmenter si la transition de lissage est trop visible au loin.
- `CollectibleIdleAnimationHz = 30` et `CollectibleMaxConcurrentAttractAnimations = 72` :
  diminuer ces valeurs si un aimant provoque encore un hitch.

## Validation

- `rojo build -o TestRoblox.rbxlx` termine avec succes.
- `git diff --check` ne remonte aucune erreur de contenu.
- Aucun marqueur de conflit n'est present dans `src` ou `docs`.

## Angles morts

- Angle mort : l'interpolation doit etre verifiee en Play Studio avec Monster1 et Monster1_Elite,
  car la structure d'un futur monstre avec Humanoid ou pivot atypique peut demander une branche
  visuelle specifique.
- Angle mort : les fusions de loot restent des operations serveur par lot. Les nouveaux champs
  `MaxMergeMs` permettront de confirmer ou non qu'elles contribuent encore aux micro-freezes
  avant une eventuelle optimisation incrementale.
