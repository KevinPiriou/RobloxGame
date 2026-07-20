# Meta Build Lab V1

Outil local d'analyse combinatoire pour MegaRoblox.

Le laboratoire génère des builds composés de personnages, armes, perks,
objets et, lorsqu'ils existent, reliques et malédictions. Il évalue d'abord
leurs formules, puis confirme un sous-ensemble avec une simulation
événementielle abstraite de run.

## Ce que prouve l'outil

Le laboratoire produit une preuve théorique bornée, pas une vérité de
gameplay. Une analyse probante exige simultanément :

- un catalogue structurellement valide ;
- des empreintes SHA-256 identiques aux sources Roblox suivies ;
- aucun effet, trigger ou stat silencieusement ignoré ;
- une couverture complète du contenu catalogué ;
- des simulations déterministes à seed fixe ;
- des tests métamorphiques, par exemple plus de dégâts doit augmenter le DPS.

Le rapport sépare les stats calculées directement des proxies théoriques. Les
proxies doivent être calibrés plus tard avec des runs réelles avant de servir à
une décision d'équilibrage définitive.

## Démarrage Windows

```powershell
py -3 meta_build_lab.py gui
```

Ou double-cliquer sur `Lancer_MetaBuildLab.bat`.

Aucune dépendance Python externe n'est requise.

## Contrôle obligatoire

Avant chaque campagne :

```powershell
py -3 meta_build_lab.py doctor
py -3 -m unittest discover -s tests -v
```

`doctor` échoue si le catalogue ne correspond plus aux fichiers Roblox qui
définissent le combat et les acquisitions. Une analyse normale refuse aussi un
catalogue périmé.

## Analyse standard

```powershell
py -3 meta_build_lab.py analyze `
  --candidates 600 `
  --top-event 40 `
  --repetitions 8 `
  --output meta_results
```

Analyse rapide, actuellement suffisante pour couvrir le catalogue :

```powershell
py -3 meta_build_lab.py analyze `
  --candidates 120 `
  --top-event 12 `
  --repetitions 3 `
  --output test_results
```

Le nombre minimal de candidats est calculé depuis le contenu. Si le catalogue
grandit, une commande devenue trop courte échoue au lieu de produire un rapport
présenté à tort comme complet.

`--allow-partial-coverage` existe uniquement pour un diagnostic rapide. Le
rapport obtenu est explicitement incomplet et ne constitue pas une preuve.

## Résultats

```text
meta_results/meta_report.html
meta_results/meta_results.json
meta_results/meta_results.sqlite
meta_results/builds.csv
meta_results/component_impacts.csv
meta_results/pair_synergies.csv
```

Le rapport contient notamment :

- la provenance et l'état des sources ;
- la couverture par personnage, arme, perk, variante de rareté et objet ;
- les scores par profil joueur ;
- les impacts par ablation de composant ;
- les interactions de paires ;
- les saturations du budget projectile ;
- les limites et proxies du modèle.

## Sources de contenu

Le catalogue JSON n'est plus la source primaire à éditer à la main.

- `src/shared/Perks.luau` alimente les perks et leurs variantes ;
- `src/shared/RunItemConfig.luau` alimente les objets de run ;
- `src/shared/CombatConfig.luau` alimente les constantes de combat ;
- `src/shared/BuildMetaConfig.luau` expose les personnages et armes au
  laboratoire sans rendre le laboratoire autoritaire sur le gameplay.

Lors de l'ajout d'un personnage ou d'une arme, son contrat théorique doit être
ajouté à `BuildMetaConfig`. Les valeurs déjà possédées par `CombatConfig` doivent
être référencées depuis ce module, pas recopiées librement.

## Synchronisation Roblox

1. Exécuter `roblox_optional/BuildCatalogExporter.server.luau` dans Studio.
2. Copier la valeur JSON de `ReplicatedStorage/BuildMetaExports/LatestJson` dans
   un fichier local.
3. Importer ce snapshot :

```powershell
py -3 meta_build_lab.py import-roblox `
  --export mon_export_roblox.json `
  --output catalogs/current_project.json
```

4. Relancer `doctor`, les tests, puis l'analyse.

L'import consomme génériquement les futurs personnages et armes exposés par
`BuildMetaConfig`, ainsi que les perks et objets exposés par leurs modules
existants. Les empreintes des services consommateurs sont enregistrées pour
détecter une évolution de logique que le catalogue n'aurait pas encore suivie.

## Contrat pris en charge

Effets modélisés :

```text
stat
counter_reward
apply_status
proc_multiplier
```

Triggers modélisés :

```text
OnRunStart
OnAcquire
OnAttack
OnProjectileCreated
OnHit
OnCrit
OnBounce
OnKill
OnEliteKill
OnDamageTaken
OnHeal
OnLowHealth
OnChestOpened
OnLevelUp
OnWaveStart
OnWaveEnd
```

Un nouveau type, trigger, comportement d'arme ou stat inconnu bloque la
validation. Il doit d'abord recevoir une formule, un test et une qualification
directe ou proxy. Cette erreur volontaire évite qu'un futur contenu soit
présent dans le catalogue mais absent des calculs.

Le détail complet du schéma est dans
`catalogs/future_content_template.json`.

## Lecture d'un score

Le score est relatif à la campagne courante. Il combine dégâts, éliminations,
survie, progression, régularité et robustesse entre profils.

Un score élevé désigne un candidat prioritaire à reproduire dans Roblox. Il ne
prouve pas à lui seul qu'un build est trop fort. Les comparaisons entre deux
campagnes ne sont recevables que si le catalogue, la seed, les profils, les
scénarios et le protocole sont identiques.

## Limites

- aucune position 3D, animation ou collision Roblox n'est simulée ;
- précision, esquive, collecte et intérêt pour les coffres restent des
  hypothèses configurables ;
- les stats de mobilité, collecte, pas et chance utilisent des proxies déclarés
  tant qu'elles ne sont pas calibrées avec de la télémétrie réelle ;
- la simulation d'un comportement d'arme est une approximation explicite de sa
  valeur, pas sa géométrie réelle ;
- les synergies découvertes sont sensibles au corpus de builds ;
- une couverture complète prouve que le contenu a été exercé, pas que toutes
  les interactions d'ordre supérieur ont été exhaustivement testées ;
- les résultats ne remplacent jamais un smoke canonique dans Roblox.

## Rollback conceptuel

Si le modèle devient moins défendable qu'une comparaison simple, conserver le
catalogue et les preuves de provenance, puis désactiver la confirmation
événementielle concernée. Il vaut mieux déclarer un contenu non modélisé que
produire un classement précis en apparence mais faux dans sa logique.
