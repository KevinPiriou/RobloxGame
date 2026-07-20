# MegaSeedValidator - Audit et integration projet V1

Date : 2026-07-19 19:42 Europe/Paris

## Statut du chantier

Decision : `Adjust`.

L'outil est conserve et integre comme prefiltre structurel externe. Il est
deterministe, rapide et utile pour analyser les distributions du generateur,
mais il ne classe pas encore les identites de seeds reellement produites par
Roblox. La raison est structurelle : la production utilise `Random.new`, dont
l'algorithme interne n'est pas publie, alors que l'outil emploie par defaut un
Xorshift32 portable.

Cette passe ne modifie ni le generateur Roblox, ni les seeds existantes, ni le
gameplay. Elle rend la limite explicite et empeche qu'un resultat synthetique
soit presente comme une preuve de validite produit.

## Etat initial

`MegaSeedValidator` etait deja versionne dans le depot. Il contenait :

- un moteur Python sans dependance externe ;
- une reproduction des layouts, rotations, elevations, rampes, links et
  decorations du generateur ;
- une grille 2D d'accessibilite ;
- un score sur 100 et des erreurs eliminatoires ;
- des exports CSV, SQLite, JSON, SVG et HTML ;
- une interface Tkinter et des lanceurs Windows ;
- un RNG portable optionnel destine a Roblox.

Trois risques importants etaient presents :

1. le snapshot annoncait le commit `88c73cac...`, alors que le projet avait
   evolue jusqu'au commit `2f932e48...` ;
2. le rapport pouvait laisser croire que les numeros classes correspondaient
   directement aux seeds de production ;
3. plusieurs campagnes dans le meme dossier conservaient des lignes SQLite,
   plans ou apercus provenant d'un ancien batch.

Le bouton GUI pouvait egalement lancer plusieurs threads concurrents vers le
meme dossier. Les caches Python et les futures sorties n'etaient pas ignores.

## Analyse de parite

### Configuration procedurale

Le blob Git courant de `ProceduralMapConfig.luau` est :

```text
4f4722884ff33c9563b8a46ad31281c0b1110082
```

Il est identique au snapshot de l'outil. Les constantes structurantes copiees
dans `current_project.json` restent donc alignees avec la configuration du jeu.

### Service de generation

Le blob Git courant de `ProceduralMapService.luau` est :

```text
8cc6873cc11d432978a074d0a0dcd518a6983f3f
```

La difference avec l'ancien snapshot concerne les proprietes physiques P1 du
relief genere, pas l'algorithme de selection des layouts. Le snapshot a ete mis
a jour pour conserver une tracabilite conservatrice.

### RNG

Le service Roblox consomme `Random.new(seed + 413)` pour le plan et les
decorations. Le validateur consomme le meme flux logique, mais avec un
Xorshift32 en mode `portable`. Les distributions peuvent etre comparees ; les
numeros de seeds ne peuvent pas etre declares identiques.

Adopter `PortableRandom.luau` dans le jeu rendrait la parite exacte, mais
changerait toutes les maps generees. Cette migration est reportee : elle exige
une version explicite du generateur, une comparaison Va/Vb et une validation
produit.

## Modifications retenues

### Controle de derive

La commande suivante compare maintenant les Git blob hashes des deux sources
Roblox avec le snapshot attendu :

```powershell
py -3 MegaSeedValidator/seed_validator.py doctor
```

Un batch ou une verification unitaire refuse un snapshot perime. L'option
`--allow-stale-config` reste disponible uniquement pour diagnostiquer une
ancienne campagne.

### Contrat de resultat

Chaque campagne enregistre maintenant :

- le mode RNG ;
- le RNG de production ;
- la parite exacte ou non ;
- `seed_identity = synthetic` tant que `Random.new` reste en production ;
- le message imposant une confirmation dans Roblox Studio ;
- les hashes attendus et observes des sources.

Le rapport HTML affiche cet avertissement dans son en-tete. Une verification de
seed unique embarque le meme contrat dans son JSON.

### Cycle de campagne

Avant un nouveau batch, seuls les artefacts connus du dossier cible sont
nettoyes : CSV, SQLite, top, metadata, rapport, plans et apercus `seed_*`.
Une campagne ne peut donc plus heriter silencieusement d'un ancien classement.

Un verrou de dossier bloque deux processus de batch concurrents. Le bouton GUI
est desactive pendant son propre batch puis restaure, y compris apres erreur.

### Hygiene du depot

Les nouvelles sorties vivent par defaut sous :

```text
MegaSeedValidator/output/seed_results
```

Ce dossier et les caches Python sont ignores. Les anciens `seed_results` ont
ete preserves afin de ne pas supprimer une campagne utilisateur existante.
`sample_results` demeure la fixture versionnee de demonstration.

## Validation effectuee

### Smoke automatise

```text
test_portable_generation_is_deterministic ... ok
test_project_snapshot_is_current ........... ok
test_output_directory_rejects_a_concurrent_batch ok
test_second_batch_replaces_previous_campaign ok
test_stale_snapshot_is_rejected ............ ok
Ran 5 tests - OK
```

Le test de remplacement execute deux campagnes dans le meme dossier. Apres la
seconde, SQLite contient uniquement les deux seeds attendues et aucun plan ou
apercu surnumeraire ne subsiste.

### Campagne courte

Protocole : seeds 1 a 100, deux workers, top 10, trois SVG.

Resultat :

- duree : 1,822 s ;
- valides structurels : 10 ;
- invalides structurels : 90 ;
- erreurs d'execution : 0 ;
- snapshot source : courant ;
- identite de seed : `synthetic`.

Le classement est identique a la fixture historique sur ce palier : 53, 31,
70, 44, 93, 21, 43, 22, 49 et 45.

### Verification projet

- `rojo build -o TestRoblox.rbxlx` : succes ;
- `git diff --check` : aucune erreur de contenu ;
- recherche de marqueurs de conflit : aucun marqueur detecte ;
- manifeste SHA-256 : 21 fichiers sources et fixtures verifies ;
- aucun Play Test n'a ete lance par l'agent.

## Smoke manuel canonique

Avant d'utiliser une campagne pour orienter le produit :

1. executer `doctor` et exiger `source_snapshot.ok = true` ;
2. lancer un petit batch et verifier l'avertissement de parite dans le rapport ;
3. ouvrir plusieurs SVG du top et plusieurs invalides proches du seuil ;
4. ne pas appeler ces numeros des seeds Roblox tant que l'identite reste
   `synthetic` ;
5. pour une selection officielle, reproduire le candidat avec le generateur
   Roblox reel ou mettre en place une parite RNG versionnee ;
6. verifier en Studio l'arrivee, les rampes, les links, le portail, les shrines,
   les coffres, les surfaces raycastees et la navigation des monstres.

## Classification des constats

- [Juste] Le coeur de l'outil est deterministe, rapide et suffisamment riche
  pour detecter de nombreux defauts geometriques avant un test Studio.
- [Juste] Le spatial grid externe et le score sont adaptes a un prefiltrage de
  masse ; ils ne doivent pas etre confondus avec une simulation Roblox.
- [Simplification] Aucun framework ni parseur Luau supplementaire n'a ete
  introduit. Deux hashes de sources et un contrat de metadata suffisent a
  bloquer les derives silencieuses les plus dangereuses.
- [Contestable] Le statut `VALID` signifie absence d'erreur eliminatoire dans
  le modele synthetique. Il ne signifie pas que la map est bonne, amusante ou
  valide dans Studio. Le score sert a ordonner, pas a certifier le produit.
- [Angle mort] Le profil 512 x 512 et l'arrivee `(0, 0)` restent des hypotheses
  configurees. L'outil ne lit pas la map instanciee ni ses limites reelles.
- [Angle mort] Les raycasts, les refus de surface, les collisions MeshPart et
  les assets Studio ne sont pas simules exactement.
- [Angle mort] L'objectif de couverture de 38 % est souvent plafonne par la
  surface disponible. Les meilleurs candidats courts observes restent autour
  de 14 a 19 % et portent des warnings. Ce signal doit nourrir un futur audit
  du generateur ; il ne faut pas simplement abaisser le seuil pour embellir le
  taux de validation.
- [Angle mort] Le manifest de distribution initial incluait un bytecode Python
  genere. Il doit rester limite aux sources et fixtures stables.

## Budget de complexite et rollback

La passe ajoute une petite complexite de garde-fou autour d'un moteur existant :
verification de snapshot, metadata de parite, verrou et nettoyage borne. Elle
ne complexifie pas le generateur du jeu.

Rollback conceptuel : retirer ces garde-fous rendrait les commandes plus
courtes, mais restaurerait les deux risques critiques, classement perime et
resultats melanges. Le generateur Roblox n'a besoin d'aucun rollback puisque
aucun de ses fichiers n'a ete modifie.

## Conclusion

Gain demontre : l'outil produit des campagnes reproductibles, isolees et
tracables, sans presenter un candidat synthetique comme une seed Roblox exacte.

Limite bloquante pour le classement de production : absence de parite avec
`Random.new`. Le prochain chantier pertinent n'est pas d'ajouter davantage de
regles de score ; il est de choisir explicitement entre un validateur Roblox
utilisant le vrai RNG et une migration versionnee vers le RNG portable.
