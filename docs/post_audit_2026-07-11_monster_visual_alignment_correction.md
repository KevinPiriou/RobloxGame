# 2026-07-11 - Correction d'alignement visuel des monstres

## Constat produit

Le lissage client ajoute apres le chantier performance a ete invalide par un Play Test : les
monstres apparaissaient en retard par rapport a leur position autoritaire serveur. Le joueur
pouvait donc subir un coup avant de percevoir correctement la proximite de l'ennemi.

Ce comportement casse le cas fondateur du combat : une collision doit correspondre a une
position lisible a l'ecran. Le chantier a donc ete requalifie en redressement plutot que de
conserver une interpolation plus complexe.

## Correction

- Suppression de `MonsterVisualInterpolation.client.luau`.
- `MonsterSimulationHz = 0` signifie maintenant que `MonsterService` execute directement son
  mouvement sur chaque `Heartbeat`, comme avant la simulation fixe a 15 Hz.
- La grille spatiale, les pools, les collisions desactivees et les optimisations de loot restent
  actives. Seule la cadence de mouvement des monstres est restauree pour realigner visuel,
  hitbox et degats.
- Le log `Perf` indique explicitement `SimulationMode = Heartbeat` afin que ce choix reste
  observable pendant les tests.

## Validation

- `rojo build -o TestRoblox.rbxlx` termine avec succes.
- `git diff --check` ne remonte aucune erreur de contenu.

## Angle mort

- Angle mort : cette correction remonte le cout serveur du deplacement des monstres. Les
  mesures `MaxTickMs`, `MaxScanMs`, `MaxMergeMs` et les pics de frame client doivent guider une
  future optimisation qui ne desynchronise jamais le modele affiche de la collision.
