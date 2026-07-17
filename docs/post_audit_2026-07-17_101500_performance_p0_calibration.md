# P0 - Calibration du protocole de baseline

## Etat initial
Commit : `88c73ca` plus worktree P0 non committe.

Scenario : premiere campagne de calibration `p0_complete`, terminee avant
cette passe, mais invalidee pour baseline car la fenetre Studio a ete
redimensionnee et a perdu le focus.

Mesures : la campagne a revele une pente de cout nette entre 25 et 1 000
monstres. Elle a aussi revele trois biais de protocole : une salve projectile
unique, une mesure collectibles dominee par la fusion initiale, et une memoire
post-nettoyage contaminer par la reprise du combat normal.

## Hypothese
Quel cout est suspecte ?

Le cout monstre est le premier candidat au chantier P1, mais P0 ne peut pas
encore isoler proprement le cout de projectiles soutenus, la memoire residuelle
ou le cout client lorsque les VFX adaptatifs changent eux-memes de qualite.

Pourquoi ?

Une baseline compare des conditions identiques. Si le rendu, la charge
projectile ou le contexte de combat changent durant la mesure, une difference
avant/apres ne peut pas etre attribuee a une modification technique precise.

## Protocole
Comment la comparaison est-elle rendue reproductible ?

- la selection Admin demarre maintenant par `p0_complete` ;
- chaque scenario conserve `15 s` de chauffe, `90 s` de mesure, `2 s` de
  nettoyage et `8 s` de repos observe ;
- le seed reste `17072026` ;
- le budget VFX adaptatif est temporairement verrouille a la qualite manuelle
  du joueur pendant P0 ; la preference n'est ni modifiee ni sauvegardee ;
- le client marque le rapport non comparable si la taille du viewport change
  ou si la fenetre perd le focus ;
- le contexte P0 reste actif jusqu'a la fin du repos observe. Les vagues
  ordinaires ne peuvent donc pas repeupler la scene avant le releve memoire ;
- les rapports sont disponibles pendant la session dans
  `ReplicatedStorage/PerformanceBaselineReports` et sont aussi imprimes sous
  le prefixe unique `[MegaRoblox][P0_EXPORT]`.

Le smoke canonique de baseline devient : lancer une run solo, ouvrir Admin,
lancer `P0 - campagne complete`, puis ne plus bouger le joueur, ne plus
redimensionner Studio, ne plus changer de fenetre ni modifier les reglages
graphiques jusqu'au statut final `Completed`.

## Modification etudiee
Description technique :

- `projectiles_24` est devenu un scenario de salves soutenues de `24/s`
  (`8` projectiles toutes les `1/3 s`) face a `48` cibles ;
- `collectibles_300` est renomme `collectibles_fusion_300`. Il mesure la
  creation et la fusion initiale, pas 300 collectibles stables ;
- les releves ajoutent physique client, instances, VFX, memoire apres
  nettoyage et memoire apres repos ;
- le rapport declare son statut de comparabilite et le motif d'invalidation ;
- les exports compacts de scenario et de campagne sont exposes comme
  `StringValue` serveur dans `ReplicatedStorage`.

Fichiers concernes :

- `src/shared/PerformanceBaselineConfig.luau` ;
- `src/server/PerformanceBenchmarkService.luau` ;
- `src/client/PerformanceBenchmarkClient.client.luau` ;
- `src/client/VfxQualityController.luau` ;
- `src/client/AdminUI.client.luau`.

Risques :

- une campagne complete dure maintenant environ `811 s` hors petites latences
  de transition, soit environ treize minutes trente ;
- le volume projectile est exprime en debit et non en nombre de projectiles
  simultanes. Le rapport `Server.Projectiles.Active` reste necessaire pour
  interpreter la charge reelle ;
- les `StringValue` de rapport sont des artefacts de session Studio. Ils ne
  remplacent pas l'archivage des resultats utiles dans `docs` apres validation.

## Resultats
Avant : campagne executable, mais VFX adaptatifs variables, projectile unique,
collectibles ambigus et nettoyage sans repos isole.

Apres : protocole calibre dans le code ; aucune mesure post-calibration n'a
encore ete prise.

Variance : inconnue. Elle devra etre estimee sur au moins trois campagnes
valides dans le meme environnement.

Regression : aucune regression de gameplay recherchee ou constatee par
verification statique ; le contexte P0 reste exclusif au benchmark.

## Decision
Adjust.

La calibration est retenue car elle reduit des biais de mesure connus. P0
reste ouvert jusqu'a l'enregistrement de la baseline validee.

## Conclusion
Gain demontre : aucun gain de performance n'est revendique. Le gain obtenu est
un protocole plus defendable.

Limites : le protocole ne detecte pas encore une interaction clavier/souris
mineure, ne mesure pas le reseau en temps reel et ne separe pas parfaitement
la memoire serveur/client dans le processus Studio unique.

Etape suivante : executer trois campagnes `p0_complete` sans changement de
focus ni de viewport, relever `LatestCampaign` et les sept rapports
`Scenario_*`, puis consigner la baseline dans un append chronologique avant
d'ouvrir P1.
