# MetaBuildLab V2 - Fiabilisation du laboratoire combinatoire

Date : 2026-07-19 21:56 Europe/Paris

## Statut du chantier

Decision : `Keep` pour le laboratoire theorique et son pipeline de preuve.

Le chantier rend `MetaBuildLab_v1` exploitable comme outil de comparaison
theorique de builds. Il ne transforme pas ses scores en verite d'equilibrage
reel. Les sorties restent des hypotheses quantitatives a confronter plus tard
aux telemetries de runs et aux retours produit.

Le smoke Studio en Play de `MegaSeedValidator` reste un chantier distinct et
est conserve dans
`todo_2026-07-19_205745_mega_seed_validator_smoke_studio.md`.

## Etat initial

Commit de reference : `2f932e482e8f772958a9ba2cb18a45cf7c58f4e5`.

Le paquet V1 savait generer et classer des builds, mais plusieurs proprietes
interdisaient de le qualifier de preuve fiable :

- le catalogue pouvait devenir obsolete sans bloquer une analyse ;
- le personnage et l'arme etaient implicitement fixes au premier contenu ;
- les effets imbriques, triggers et comportements d'arme inconnus pouvaient
  etre ignores ou insuffisamment valides ;
- les reliques et maledictions etaient acceptees sans etre appliquees par le
  modele evenementiel ;
- les impacts et paires etaient trop dependants des seuls meilleurs builds ;
- une analyse courte pouvait etre presentee sans prouver sa couverture ;
- les tests ne prouvaient ni l'extension future du catalogue ni la monotonie
  de mecanismes elementaires.

Baseline courte V1 : 60 candidats, 16 confirmations evenementielles,
1 repetition, 4,433 secondes. Cette baseline mesurait une execution, mais ne
portait aucune preuve de couverture du catalogue.

## Hypothese

Le risque principal n'etait pas un temps d'execution trop eleve. Il etait la
production d'un rapport coherent en apparence a partir d'un catalogue incomplet,
obsolete ou partiellement interprete.

La passe vise donc la fiabilite du contrat avant l'optimisation locale :

1. prouver l'origine des donnees ;
2. echouer explicitement sur toute mecanique inconnue ;
3. mesurer la couverture du contenu ;
4. prouver que le pipeline consomme de futurs contenus ;
5. conserver des sorties deterministes et auditables.

## Contrat de donnees

### Source Roblox declarative

`src/shared/BuildMetaConfig.luau` decrit les personnages et les armes a
exporter. Les perks et objets continuent de provenir respectivement de
`Perks.luau` et `RunItemConfig.luau`.

Le script optionnel `BuildCatalogExporter.server.luau` exporte ces sources vers
le snapshot Roblox. L'adaptateur Python consomme ensuite les groupes de maniere
generique. Ajouter un second personnage ou une seconde arme ne demande donc
plus de modifier le generateur de builds.

### Provenance

Le catalogue enregistre le commit et les empreintes SHA-256 de onze sources de
configuration et de gameplay. La commande `doctor` bloque l'analyse si une
source suivie a change, disparu ou n'est plus representee dans le snapshot.

Cette preuve par hash reste valable lorsque le worktree contient des fichiers
non commits. Le commit seul n'est donc pas presente comme une preuve suffisante.

### Validation fermee

Le schema V2 valide les structures imbriquees, les identifiants, les variantes
de rarete, les effets, les triggers, les statistiques et les comportements
d'armes. Une mecanique future inconnue provoque une erreur explicite. Elle ne
recoit jamais silencieusement un score nul ou un comportement arbitraire.

Les types d'effets actuellement modelises sont :

- `stat` ;
- `counter_reward` ;
- `apply_status` ;
- `proc_multiplier`.

Les dix-sept familles de comportement d'arme declarees par le laboratoire sont
exercees dans les deux modeles, analytique et evenementiel. Leur statut reste
celui d'un proxy theorique tant qu'une calibration en run ne les relie pas a la
production.

## Couverture combinatoire

Le generateur varie maintenant les personnages, armes, niveaux, perks,
variantes de rarete, objets, reliques et maledictions disponibles. Le seuil
minimal de candidats est derive du catalogue, et non d'une constante adaptee au
contenu actuel.

Une analyse de preuve refuse de se terminer si elle ne couvre pas toutes les
categories attendues. L'option `--allow-partial-coverage` existe uniquement
pour un diagnostic volontaire et marque la sortie comme partielle.

Les impacts unitaires et les paires utilisent un echantillon couvrant les rangs,
au lieu de ne mesurer que les gagnants. Un cache des evaluations analytiques
evite de recalculer les memes builds pendant les ablations.

## Resultats

### Comparaison V1 / V2

| Passe | Candidats | Events | Repetitions | Couverture | Temps |
| --- | ---: | ---: | ---: | ---: | ---: |
| Baseline V1 | 60 | 16 | 1 | non mesuree | 4,433 s |
| V2 initiale | 60 | 16 | 1 | 99,17 %, incomplete | 13,728 s |
| V2 avec cache | 60 | 16 | 1 | 99,17 %, incomplete | 5,417 s |
| V2 preuve complete | 96 | 18 | 1 | 100 % | 8,162 s |
| Echantillon livre | 120 | 22 | 3 | 100 % | 14,975 s |

La comparaison brute de temps ne constitue pas un gain produit : la V2 effectue
plus de validations et produit une preuve que la V1 ne calculait pas. Le cache
ramene toutefois la passe equivalente de 13,728 a 5,417 secondes sans diminuer
sa couverture.

### Preuves automatisees

- 16 tests `unittest` verts ;
- determinisme du draft et de la simulation evenementielle ;
- monotonie du DPS pour une augmentation de degats ;
- monotonie du proxy de mobilite pour une augmentation de saut ;
- rejet d'un trigger, effet, comportement d'arme ou champ mecanique inconnu ;
- rejet d'une analyse de preuve a couverture incomplete ;
- consommation testee d'un futur personnage, d'une future arme, d'un futur
  perk, d'un futur objet et d'une future relique ;
- execution des 17 familles d'armes dans les deux modeles ;
- verification du manifeste de distribution ;
- `selftest.py` vert ;
- `compileall` vert ;
- `doctor` vert, sans source modifiee ni manquante.

### Verification Studio

Une lecture en mode Edition, sans lancement de Play, a confirme que le projet
Studio expose exactement :

- 1 personnage ;
- 1 arme ;
- 21 perks ;
- 13 objets de run.

Les identifiants observes dans Studio correspondent exactement au catalogue
genere. Cette verification protege l'inventaire actuel, mais elle ne remplace
pas le controle `doctor` apres chaque ajout futur.

### Verification projet

- `rojo build -o TestRoblox.rbxlx` : vert ;
- `git diff --check` : vert, hors avertissements de normalisation CRLF ;
- marqueurs de conflit Git : aucun.

## Fichiers structurants

- `src/shared/BuildMetaConfig.luau` : source declarative personnages/armes ;
- `MetaBuildLab_v1/meta_lab/evidence.py` : provenance et empreintes ;
- `MetaBuildLab_v1/meta_lab/catalog.py` : contrat strict du catalogue ;
- `MetaBuildLab_v1/meta_lab/roblox_adapter.py` : import extensible et ferme ;
- `MetaBuildLab_v1/meta_lab/engine.py` : modeles analytique/evenementiel ;
- `MetaBuildLab_v1/meta_lab/analyzer.py` : couverture, ablations et preuves ;
- `MetaBuildLab_v1/meta_lab/report.py` : restitution de la provenance et des
  limites ;
- `MetaBuildLab_v1/tests/test_meta_lab.py` : preuves de non-regression ;
- `MetaBuildLab_v1/sample_results/` : echantillon complet livre.

## Budget de complexite

La passe ajoute de la complexite au laboratoire, mais l'isole dans le paquet
MetaBuildLab et dans un unique module declaratif partage. Aucun service de
gameplay n'est modifie par ce chantier.

La complexite implicite diminue : les comportements inconnus, les sources
obsoletes et les categories non couvertes ne sont plus dissimules par des
valeurs par defaut.

## Angles morts

- Les poids, profils et coefficients proxy ne sont pas calibres par des runs
  reels. Un score de 90 n'est pas une prediction de victoire ou de plaisir.
- La couverture prouve que chaque contenu est visite, pas que toutes les
  combinaisons d'ordre eleve sont exhaustivement enumerees.
- Le projet ne contient encore qu'un personnage et une arme. L'extensibilite
  future est prouvee par fixtures et par le contrat d'export, pas par un second
  contenu de production.
- Toute nouvelle semantique doit etre modelisee puis accompagnee d'un test. Le
  rejet ferme est volontaire : l'outil prefere ne pas repondre plutot que
  produire un faux classement.
- `MaxHealth = 100` reste une donnee descriptive explicite dans
  `BuildMetaConfig`, faute de source unique equivalente dans `CombatConfig`.
- L'export Roblox reste une etape explicite. Le laboratoire ne lit pas
  directement une session Studio en cours.

## Smoke canonique

Apres toute modification de contenu :

1. exporter le snapshot Roblox avec `BuildCatalogExporter.server.luau` ;
2. importer le snapshot avec `meta_build_lab.py import-roblox` ;
3. executer `meta_build_lab.py --catalog catalogs/current_project.json doctor` ;
4. executer `py -3 -m unittest discover -s tests -v` ;
5. lancer l'analyse standard et verifier `sampling_coverage.complete = true` ;
6. ouvrir `sample_results/meta_report.html` pour la lecture humaine.

Un echec a l'une de ces etapes bloque la qualification de preuve.

## Rollback

Le chantier est isolable : supprimer `BuildMetaConfig` de l'export et revenir
au catalogue V1 restaure l'ancien outil sans modifier les regles du jeu. Ce
rollback ferait cependant perdre la provenance, la validation fermee et la
preuve de couverture ; il ne doit donc servir qu'a diagnostiquer une regression,
pas a contourner une erreur de catalogue.

## Conclusion

`MetaBuildLab_v1` est maintenant fiable pour ce qu'il declare : comparer des
builds dans un modele theorique versionne, reproductible, extensible et ferme
aux mecanismes inconnus.

Il n'est pas encore fiable pour decider seul de l'equilibrage. La prochaine
evolution legitime sera une calibration explicite contre des telemetries de
runs reelles, avec comparaison des predictions et des resultats observes.
