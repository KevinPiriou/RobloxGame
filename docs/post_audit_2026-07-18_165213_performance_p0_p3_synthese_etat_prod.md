# Performance P0 a P3 - Synthese et etat de production

Date : 2026-07-18 16:52 Europe/Paris

## Etat initial

Commit de reference : `a940990`, avec le worktree Performance P0 a P3 non
encore committe au moment de cette synthese.

Perimetre : P0 observabilite, P1 physique runtime, P2 simulation de horde et
P3 projectiles. Les runs actuelles sont instanciees en solo. Cette contrainte
produit est importante : aucun autre joueur ne doit voir les projectiles du
proprietaire pendant une run.

## Hypothese

Le chantier devait separer les couts mesurables avant de les modifier :

- P0 : construire une reference locale reproductible ;
- P1 : retirer les participations physiques sans usage produit ;
- P2 : reduire le CPU de la horde sans changer les regles de combat ;
- P3 : supprimer la replication continue des transforms de projectile sans
  sortir les decisions de combat du serveur.

## Protocole

La reference est la campagne Admin P0 a seed `17072026`, avec chauffe,
fenetre de mesure, nettoyage et repos fixes. Les paliers monstres sont 25,
100, 250, 500 et 1 000 ; les scenarios isoles couvrent aussi 24 tirs par
seconde et 300 collectables. Les mesures non focalisees sont exclues des
comparaisons. Chaque phase conserve aussi un smoke manuel produit, plus fort
qu'une campagne lorsqu'il revele un defaut visible.

## Modification etudiee

### P0 - Baseline et observabilite

- `PerformanceBenchmarkService` et son client associe structurent les
  scenarios, l'export P0, les percentiles et les nettoyages ;
- les compteurs distinguent simulation monstre, projectile, VFX, pools,
  memoire Studio et reseau disponible ;
- la charte append-only et le journal de pilotage sont dans
  `audit_2026-07-17_074825_charte_pilotage_performance.md`.

### P1 - Physique et sous-chantiers P1.2 a P1.4

- `PhysicsAuditService` inventorie templates et runtime : parties, meshes,
  ancrage, collision, touch, query, contraintes, joints et colliders
  invisibles ;
- les collectables runtime sont prepares sans collision, touch ni query ;
- les interactivables ordinaires gardent la collision de parcours mais
  retirent touch/query ; `ChestOpen` conserve explicitement le contact dont il
  depend ;
- le relief genere garde collision/query necessaires au parcours et aux
  raycasts, mais retire touch ;
- le cycle de vie de run detruit bien le runtime avant une relance, sans
  bloquer les runs suivantes.

### P2 - Simulation des monstres

- grille de separation persistante et requetes locales ;
- cache de sol partage limite aux surfaces planes valides ;
- LOD existant conserve, telemetrie detaillee de mouvement, separation, sol,
  evitement, spawn et recyclage ;
- vagues ordinaires bornees a quatre creations par frame et spawn admin mis
  en file ;
- recyclage etale, sans creer de nouvelle instance pour reconstituer une
  menace devant le joueur.

### P3 - Projectiles et bande passante

- le serveur garde la simulation complete de Fireball : cible, homing,
  collision, rebond, degat, impact, expiration et recyclage ;
- le noyau visuel du proprietaire est cree localement par
  `ProjectileVfxController`, a partir d'ordres fiables bornes ;
- les noyaux logiques `ClientPilot` vivent dans
  `ServerStorage/ProjectileSimulation`, donc leurs transforms ne sont plus
  repliques ;
- `CombatConfig.ProjectilePresentationMode = "ClientPilot"` est le defaut
  de production des runs solo ; `ReplicatedCore` reste le rollback immediat ;
- le scenario P3.0 fixe explicitement `ReplicatedCore` pour conserver une
  reference avant/apres stable ; P3.1 fixe `ClientPilot`.

## Resultats

### P0 et P2 - Cout de horde

| Palier | Tick monstre P95 P0 | Tick monstre P95 P2 | Ecart |
| --- | ---: | ---: | ---: |
| 25 | 1.16 ms | 1.00 ms | -13.8 % |
| 100 | 6.47 ms | 3.40 ms | -47.4 % |
| 250 | 20.69 ms | 11.18 ms | -45.9 % |
| 500 | 52.51 ms | 30.81 ms | -41.3 % |
| 1 000 | 134.31 ms | 90.86 ms | -32.3 % |

Le frame P95 passe de 28.79 a 18.58 ms a 250 monstres, de 69.78 a
46.43 ms a 500 et de 185.12 a 131.78 ms a 1 000. A 1 000, la separation P95
descend de 100.87 a 44.68 ms et le suivi de sol de 15.41 a 2.73 ms apres
chauffe du cache partage.

### P1 - Physique

Le gain mesure est structurel, pas un delta MB universel : les scenes
procedurales n'ont pas toutes le meme volume. Les audits prouvent neanmoins
la disparition des touches/requetes inutiles sur collectables et
interactivables, avec conservation des exceptions fonctionnelles. Le retour
lobby apres run donne `runtimeParts=0`, `unanchored=0`, `constraints=0` et
`joints=0` dans les dossiers runtime inspectes.

### P3 - Projectile isole a 24 tirs/s

| Mesure | Noyau replique P3.0 | Pilote local P3.1 | Ecart |
| --- | ---: | ---: | ---: |
| Tirs emis | 2 128 | 2 128 | 0 % |
| Transforms repliques | 819 872 | 0 | -100 % |
| Tick WeaponService P95 | 1.10 ms | 0.24 ms | -78.2 % |
| Envoi serveur P95 | 320.05 Kbps | 18.27 Kbps | -94.3 % |
| Frame client P95 | 8.32 ms | 7.88 ms | pas de regression |
| Particules actives P95 | 210 | 209 | parite pratique |
| Lumieres actives P95 | 54 | 54 | identique |
| Trails actifs P95 | 66 | 65 | parite pratique |

Les tirs, impacts, expirations et recyclages restent dans la variance des
repetitions comparables. Le smoke lourd avec spawns admin repetes a valide les
projectiles, ennemis, collectables et VFX sans erreur de combat ou de cycle.

## Decision

- P0 : `Keep` comme baseline locale CPU/frame et reseau Studio. P0-complet
  reste explicitement reporte ;
- P1 : `Keep` pour l'inventaire, la normalisation runtime et le cycle de vie ;
- P2 : `Keep` en production ;
- P3 : `Keep` en production solo par configuration. Le code est compile et
  verifie statiquement ; le smoke de branchement par defaut est valide.

## Conclusion

Gain demontre : P2 retire une part importante du cout CPU de horde aux
densites elevees. P3 retire le cout dominant de replication des transforms de
Fireball tout en gardant la logique autoritaire serveur. P1 rend visibles et
maitrisees les participations physiques runtime qui etaient auparavant
implicites.

Limites : ni le MicroProfiler detaille, ni une campagne multi-client, ni une
preuve de memoire de longue duree publiee ne sont disponibles. Les pics client
de run reelle restent non attribues. Ils ne doivent pas etre rattaches aux
projectiles sans nouvelle mesure ciblee.

Etape suivante : les futures phases Performance pourront reouvrir une
investigation ciblee. Elles devront partir de ce referentiel et ne pas
attribuer les pics client restants a un sous-systeme sans mesure isolee.

## Classification de l'etat

Juste : le contrat solo autorise la presentation locale de tous les
projectiles de run ; aucun observateur n'est prive d'une information utile.

Contestable : la performance P3 est prouvee en Studio local et sur un scenario
Fireball. Elle n'est pas automatiquement transferable a toute future arme.

Simplification : le toggle admin P3 est retire. Une seule configuration de
production et un seul rollback sont plus lisibles que deux chemins actifs.

Angle mort : si une run cooperative, un spectateur ou un mode partage est
ajoute, il faut reouvrir le todo multijoueur P3 avant d'activer ce mode pour
ces joueurs. Le parametre `ReplicatedCore` existe precisement pour ne pas
masquer cette dette.

## Append - Validation du branchement P3 par defaut - 2026-07-18 16:57 Europe/Paris

Le smoke de production solo a ete execute sans activer de commande P3. Il
montre des projectiles actifs pendant le combat puis un retour propre a
`Active=0`, `ActiveVolleys=0`, `PendingVolleyShots=0` et `Pool=24`. Les pools
de monstres et collectables reviennent egalement a leur repos apres la run.

La promotion P3 est donc validee dans le perimetre declare : runs solo,
presentation locale du proprietaire et serveur autoritaire. Trois pics client
(`153`, `278`, `126 ms`) restent observes mais non attribues ; ils sont une
donnee de depart, pas une conclusion causale.
