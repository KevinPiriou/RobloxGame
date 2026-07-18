# Mega Seed Validator

Programme préparé pour le générateur procédural actuel de
`KevinPiriou/RobloxGame`, branche `Mymain`, snapshot
`88c73cac324f733d3603c5c707b838a08a0c1a9f`.

## Ce que le programme vérifie

- sélection pondérée des layouts ;
- rotations cardinales ;
- élévations et emprises des rampes ;
- minimum de 6 layouts, maximum de 18 ;
- plafond de 56 plateformes ;
- objectif de couverture de 38 % ;
- limites jouables et zone libre autour de l'arrivée ;
- espacement entre layouts ;
- construction actuelle des links orthogonaux ;
- placement approximatif des décorations ;
- grille de navigation 2D de la base ;
- accessibilité de chaque entrée de rampe et de chaque plateforme ;
- pentes trop fortes ;
- links sans blocs, intersections et blocage de l'arrivée ;
- score de qualité sur 100.

Le score ne rend jamais valide une seed qui échoue à une règle éliminatoire.

## Lancement sous Windows

Python 3.11 ou plus récent est recommandé. Aucune dépendance externe.

Double-cliquer sur :

```text
Lancer_GUI.bat
```

Ou dans PowerShell :

```powershell
py -3 seed_validator.py gui
```

## Vérifier une seed

```powershell
py -3 seed_validator.py seed 123456
```

Le programme crée :

```text
seed_results/single/seed_123456.json
seed_results/single/seed_123456.svg
```

## Lancer 10 000 seeds

```powershell
py -3 seed_validator.py batch `
  --start 1 `
  --count 10000 `
  --workers 0 `
  --top 100 `
  --render-top 20 `
  --output seed_results
```

Ou double-cliquer sur `Lancer_10000_Seeds.bat`.

## Résultats

```text
seed_results/results.csv
seed_results/results.sqlite
seed_results/top_seeds.txt
seed_results/top_results.json
seed_results/report.html
seed_results/previews/*.svg
seed_results/plans/*.json
```

## Calibrage de la map

Le dépôt ne versionne pas intégralement `Map_Test` et son point d'arrivée Studio.
Le profil fourni suppose une surface 512 × 512 studs et une arrivée en `(0, 0)`.

Vérifier ces valeurs dans `config/current_project.json` avant une sélection
officielle :

```json
"map_profile": {
  "min_x": -256,
  "max_x": 256,
  "min_z": -256,
  "max_z": 256,
  "arrival_x": 0,
  "arrival_z": 0
}
```

## Parité exacte des seeds

Le projet Roblox actuel utilise `Random.new(seed)`. L'API publique garantit la
reproductibilité dans Roblox, mais ne publie pas l'algorithme interne. Le mode
externe est donc un **préfiltre structurel** tant que Roblox conserve
`Random.new`.

Le dossier `roblox_optional` contient un RNG portable identique au programme.
Après intégration de ce RNG dans Roblox, les mêmes seeds produisent la même
suite aléatoire dans les deux environnements.

Attention : appliquer ce patch change les anciennes maps générées. Il doit être
traité comme une nouvelle version du générateur.

## Alertes importantes

`link_connections_without_blocks`

Le service courant marque le layout suivant comme lié même lorsque la création
de la liaison produit zéro bloc.

`raised_links_without_explicit_vertical_transition`

Les links sont créés à une élévation fixe de 10 studs depuis des positions
calculées à partir de `GroundPosition`. Le validateur ne les considère donc pas
comme une transition verticale garantie vers le sommet des plateformes.

## Limites de la V1

- pas de simulation complète du Humanoid ;
- pas de lecture des collisions MeshPart conservées uniquement dans Studio ;
- surface principale modélisée comme une grande base horizontale ;
- décorations reproduites par leur empreinte configurée, pas leur mesh exact ;
- les meilleures seeds doivent encore subir une confirmation dans Studio tant
  que le RNG portable n'est pas utilisé dans le jeu.
