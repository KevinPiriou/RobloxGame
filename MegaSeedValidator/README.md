# Mega Seed Validator

Outil externe de préfiltrage structurel pour le générateur procédural de MegaRoblox.
Il classe rapidement de grands volumes de plans synthétiques, détecte les défauts
géométriques évidents et produit des candidats à confirmer dans Roblox Studio.

## Contrat de vérité

Le jeu utilise actuellement `Random.new(seed)`. Roblox ne publie pas l'algorithme
interne de ce générateur. Le mode `portable` de cet outil est donc déterministe,
mais ses numéros de seeds ne désignent pas encore les mêmes plans que dans le jeu.

Les résultats sont explicitement marqués :

- `seed_identity = synthetic` : candidat structurel, confirmation Studio requise ;
- `seed_identity = production` : réservé à une future parité RNG démontrée.

Le dossier `roblox_optional` contient un RNG portable compatible avec l'outil.
Son adoption changerait toutes les maps générées et constitue une nouvelle version
du générateur. Elle ne doit pas être appliquée comme une simple correction locale.

### Barrière de production exacte

Le préfiltre Python n'est pas la barrière qui autorise une run. Le jeu possède un
sas serveur qui utilise le vrai `Random.new`, génère les instances réelles, puis
contrôle le relief et les familles de contenu essentielles avant l'état `Ready`.

Une tentative refusée est entièrement nettoyée. Une nouvelle seed déterministe est
essayée dans un budget maximal de quatre tentatives. Seule la seed acceptée devient
la `RunSeed` autoritative et persistée. Les seeds refusées sont tracées dans la
catégorie `Perf` avec leur étape et leur raison.

Cette séparation est volontaire :

- Python explore vite et détecte des familles de défauts théoriques ;
- Roblox décide exactement si la génération réelle peut être exposée au joueur.
- aucune liste issue du RNG synthétique ne doit être copiée comme blacklist de prod.

## Ce que le programme vérifie

- sélection pondérée des layouts et rotations cardinales ;
- élévations, emprises et pentes des rampes ;
- limites de layouts et de plateformes ;
- couverture, limites jouables et zone libre autour de l'arrivée ;
- espacement entre layouts ;
- links orthogonaux, links sans blocs et intersections ;
- placement approximatif des décorations ;
- accessibilité de la base, des rampes et des plateformes sur une grille 2D ;
- score de qualité sur 100.

Le score ne rend jamais valide une seed qui échoue à une règle éliminatoire.

## Vérifier le snapshot source

Avant un classement, l'outil compare les Git blob hashes de sa configuration avec :

- `src/shared/ProceduralMapConfig.luau` ;
- `src/server/ProceduralMapService.luau` ;
- `src/shared/RunGenerationConfig.luau` ;
- `src/server/RunSeedValidationService.luau` ;
- `src/server/RunSessionService.luau`.

Le dernier fichier est volontairement surveillé : le validateur de seed ne suffit pas
s'il existe sans être branché au cycle de vie qui autorise l'état `Ready`.

```powershell
py -3 seed_validator.py doctor
```

Un batch ou une vérification unitaire refuse par défaut un snapshot périmé.
`--allow-stale-config` existe uniquement pour diagnostiquer une ancienne campagne ;
ses résultats ne doivent pas être utilisés pour sélectionner une seed.

## Lancement sous Windows

Python 3.11 ou plus récent est recommandé. Aucune dépendance externe.

```text
Lancer_GUI.bat
```

Ou :

```powershell
py -3 seed_validator.py gui
```

L'interface empêche deux batchs concurrents d'écrire dans le même dossier.

## Vérifier un candidat

```powershell
py -3 seed_validator.py seed 123456
```

Les fichiers sont créés dans :

```text
output/seed_results/single/seed_123456.json
output/seed_results/single/seed_123456.svg
```

## Lancer 10 000 seeds

```powershell
py -3 seed_validator.py batch `
  --start 1 `
  --count 10000 `
  --workers 0 `
  --top 100 `
  --render-top 20
```

Chaque lancement nettoie seulement les artefacts connus de la campagne précédente
dans son dossier de sortie. La base SQLite, les aperçus et les plans ne peuvent donc
plus conserver silencieusement des seeds d'un ancien batch.

## Résultats

```text
output/seed_results/results.csv
output/seed_results/results.sqlite
output/seed_results/top_seeds.txt
output/seed_results/top_results.json
output/seed_results/report.html
output/seed_results/previews/*.svg
output/seed_results/plans/*.json
```

`run_metadata.json` enregistre le snapshot source, le mode RNG, le contrat de parité
et l'interprétation autorisée des résultats.

## Calibrage de la map

Le profil fourni suppose une surface 512 x 512 studs et une arrivée en `(0, 0)`.
Ces valeurs sont des hypothèses externes, pas une lecture directe de la map Studio.
Elles doivent être vérifiées avant toute campagne officielle dans
`config/current_project.json`.

## Limites connues

- pas de simulation complète du Humanoid ;
- pas de lecture des collisions MeshPart conservées uniquement dans Studio ;
- surface principale modélisée comme une grande base horizontale ;
- décorations reproduites par leur empreinte configurée, pas leur mesh exact ;
- les raycasts et refus de surface du générateur Roblox ne sont pas reproduits ;
- `coverage_capped_by_available_surface` peut subsister sur les meilleurs candidats ;
- les links élevés ne garantissent pas une transition verticale praticable ;
- tant que le jeu conserve `Random.new`, un candidat doit être rejoué et validé dans
  Studio avant d'être classé comme seed jouable du produit.
- le sas de production élimine les échecs structurels observables ; il ne note pas
  l'intérêt ludique d'une map et ne prouve pas toute sa navigabilité au Humanoid.

## Tests rapides

```powershell
py -3 MegaSeedValidator/tests/test_smoke.py
```

Le smoke protège le déterminisme, la synchronisation des sources, les métadonnées
de parité et l'absence de contamination entre deux campagnes successives.
