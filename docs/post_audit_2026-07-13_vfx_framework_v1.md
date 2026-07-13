# Chantier VFX V1 - Implementation technique

Horodatage : 2026-07-13 19:34 CEST

## Etat du chantier

Cette passe migre la presentation de la Fireball vers un rendu client local budgete et stabilise le cycle de vie des auras de perks. Le serveur reste la seule source de verite pour le deplacement logique, les cibles, les collisions, les degats, les rebonds et les statuts.

Cette note valide l'integration technique. Elle ne valide pas encore le rendu final en Play Test Studio : le smoke manuel ci-dessous reste bloquant avant de considerer la qualite visuelle comme tenue.

## Contrat VFX V1

### Fireball

Le chemin est maintenant volontairement court :

1. `WeaponService` conserve le projectile logique poolé et applique le gameplay serveur.
2. `ProjectileVisualService` desactive les effets legacy presents dans le template, conserve le noyau Neon et publie seulement les attributs de presentation (`WeaponId`, `VfxProfileId`, skin, proprietaire et serial runtime).
3. `ProjectileVfxController.client.luau` observe les projectiles du proprietaire local et attache des packages VFX locaux reutilisables.
4. Au contact, le serveur envoie uniquement `ProfileId`, `Position` et `Seed` au proprietaire via `CombatVfx_Play`. Le client ne peut ni declarer un impact, ni transmettre des degats.

Les autres joueurs voient donc toujours le noyau de projectile replique, mais pas les couches couteuses du joueur courant. Aucun deplacement visuel client divergent n'est introduit : le projectile conserve la simulation serveur existante.

### Qualite et budgets

`VfxConfig.luau` est la source unique des profils visuels :

| Profil | Projectiles complets | Projectiles reduits | Impacts complets | Familles d'aura |
| --- | ---: | ---: | ---: | ---: |
| `Performance` | 8 | 24 | 6 | 2 |
| `Balanced` | 24 | 56 | 16 | 3 |
| `Quality` | 48 | 96 | 32 | 3 |

Un projectile complet porte noyau, trail, flamme, fumee, etincelles et lumiere. Le niveau reduit garde noyau, trail court et flamme legere. Le niveau minimal garde le noyau. A `EffectsIntensity = 0`, les couches decoratives disparaissent mais un impact Neon minimal, tres court et budgete, demeure pour la lisibilite du combat.

Le budget adaptatif lit le temps de frame client : baisse apres trois secondes sous 45 FPS, restauration apres dix secondes au-dessus de 55 FPS. Cette baisse ne peut pas depasser la qualite manuelle choisie, n'est jamais sauvegardee et ne modifie aucune regle de combat.

### Auras

`AuraController.client.luau` ne reconstruit plus toutes les auras quand une statistique varie. Chaque famille cree ses attachments et emitters une seule fois par personnage, puis les active, desactive ou met a jour selon les trois familles dominantes et leur tier.

Les attachments sont references explicitement et detruits au reset du personnage ou a la sortie de run. Aucun `Beam` circulaire n'est reintroduit. Les effets restent locaux et utilisent les profils existants : flammes de contour, particules, glyphes, highlights et pulsations selon la famille.

### GraphicsController

`GraphicsController` garde l'hydratation et la persistance des preferences, mais ne parcourt plus les descendants de `Workspace`. Il ne modifie donc plus les `ParticleEmitter`, `Trail`, `Beam` ou lumieres de la map. Les controleurs VFX consomment explicitement ses reglages.

## Assets VFX

Les prochains assets 2D VFX doivent etre ranges dans :

```text
assets/ui/vfx/
```

Apres import Studio, le `StringValue` correspondant doit etre place dans :

```text
ReplicatedStorage/VisualTemplates/ParticleTextures
```

Le chemin historique `ReplicatedStorage/VisualTemplates/AuraTemplates/ParticleTextures` reste lu temporairement pour conserver les textures deja importees. Les templates de combat dans `ServerStorage/CombatTemplates` ne doivent plus porter de `Fire`, `Smoke`, `Sparkles`, `Trail` ou lumiere comme source de rendu active.

## Instrumentation

La categorie `Vfx` du `DebugConfig` emet, avec limitation :

- la repartition complete, reduite et minimale des projectiles ;
- les impacts refuses par budget ;
- les auras actives, packages crees et profil de qualite ;
- les changements de niveau adaptatif.

## Validation technique

- `rojo build -o $env:TEMP\TestRoblox-vfx-framework-v1.rbxlx` termine avec succes ;
- `git diff --check` ne remonte aucune erreur de contenu ;
- aucun marqueur de conflit Git n'est present dans `src` ou `docs` ;
- verification ciblee : `GraphicsController` n'itere plus sur les descendants de `Workspace`.

## Smoke manuel canonique bloquant

1. En lobby, verifier l'absence d'aura et de VFX d'arme.
2. Lancer une run puis tirer avec 1, 8 et 24 Fireballs : les degats, cibles et rebonds doivent etre identiques, tandis que la densite VFX respecte le budget.
3. Verifier les skins classique et arcane : rendu distinct, sans eclairage excessif.
4. Mettre en pause, ouvrir un choix de perk et un coffre : aucun nouveau tir ou impact ne doit etre cree pendant la pause gameplay.
5. Tester `Performance`, `Balanced`, `Quality` puis `EffectsIntensity = 0` : le noyau et l'impact minimal restent lisibles, les couches decoratives se reduisent.
6. Modifier les stats d'aura dans une meme tranche puis franchir un tier : pas de flash blanc, cercle ni reconstruction visible ; la transition de tier reste lisible.
7. Verifier une particule decorative de map avant et apres un changement graphique : elle doit rester inchangee.
8. Avec `Spawn 100 ennemis`, ouvrir MicroProfiler et verifier les logs `Vfx` pour comparer le nombre de packages et le niveau adaptatif.

## Angles morts et budget de complexite

- ✓ Juste : les decisions de combat restent cote serveur ; aucun remote client-vers-serveur n'est ajoute pour les impacts.
- ✓ Juste : les couches VFX couteuses sont recyclees cote client pour les projectiles et les impacts ; les auras conservent leurs instances par personnage.
- ⚡ Simplification : un seul profil VFX par skin et quatre types de presentation prevus (`Projectile`, `Persistant`, `Instantane`, `Zone`) remplacent un moteur universel premature.
- ~ Contestable : voir uniquement le noyau des projectiles des autres joueurs est un compromis V1. Un rendu reduit pour les autres joueurs pourra etre ajoute apres une mesure reelle des couts client.
- ◐ Angle mort : Rojo valide le mapping et l'integration des fichiers, pas l'execution Luau, l'esthetique, les taux reels d'emission ni le cout GPU sur les appareils cibles. Le Play Test et MicroProfiler restent les preuves prioritaires.
- ◐ Angle mort : les effets de poison, les armes persistantes, les zones et les VFX spectateur sont prepares par contrat mais ne sont pas produits dans cette V1.

## Addendum - 2026-07-13 20:34 CEST - Lisibilite des auras et controles de logs

Le retour de test indique que les auras restent trop discretes. La taille native est donc portee de `1,35` a `2,70` dans `AuraConfig`, soit un x2 applique aux tailles de particules de toutes les familles. Les taux d'emission, la logique des trois familles dominantes et les budgets VFX ne changent pas : la correction augmente la presence visuelle sans doubler directement le volume de particules creees.

Le panneau `ADMIN` comporte maintenant une section scrollable `JOURNAUX DEBUG` :

- une case `Console globale` active ou coupe toutes les sorties de `DebugLog` ;
- 33 categories correspondent aux categories effectivement utilisees dans le projet ;
- chaque changement est demande au serveur, valide par les droits admin puis republie a tous les clients ;
- les changements de logs ne marquent pas la run comme commande debug gameplay dans `RunAnalyticsService`.

Les remotes `Admin_GetDebugLogState`, `Admin_SetDebugLogSetting` et `Admin_DebugLogState` ne pilotent que la verbosite. Ils ne donnent aucune capacite gameplay additionnelle au client.

### Validation technique

- `rojo build -o $env:TEMP\TestRoblox-aura-debug-controls-final.rbxlx` termine avec succes ;
- `git diff --check` ne remonte aucune erreur de contenu ;
- aucun marqueur de conflit Git n'est present dans `src` ou `docs`.

### Smoke manuel cible

1. Lancer une run, construire une famille d'aura, puis verifier que ses particules sont deux fois plus lisibles sans surexposer le personnage.
2. Ouvrir `ADMIN`, couper `Console globale`, puis verifier que les nouveaux logs Output cessent tout en conservant le combat, les pickups et les VFX.
3. Reactiver uniquement `Performance` et `VFX`, lancer `Spawn 100 ennemis` et comparer les logs utiles avec MicroProfiler.
4. Verifier qu'une bascule de journal ne fait pas apparaitre le drapeau de run debug dans le recap.

### Angles morts

- ✓ Juste : des logs actifs ont un cout mesurable en serialisation et ecriture Output ; les couper rend le profilage plus representatif.
- ⚡ Simplification : les options de logs sont volatiles par session. Les persister aurait ajoute une ecriture DataStore sans gain produit pour un outil admin.
- ◐ Angle mort : la creation des tables de contexte juste avant l'appel de `DebugLog` subsiste dans certains chemins chauds. Le gain principal vient de la suppression des `print`/`warn` et de leur serialisation ; un chantier de micro-optimisation ne devra etre ouvert qu'apres une mesure MicroProfiler reelle.

## Addendum - 2026-07-13 20:42 CEST - Fireball de flamme texturee

Le retour visuel est fonde : le profile `Quality` faisait encore surtout lire la Fireball comme une comete. La texture de flamme existait, mais une seule emission courte a l'avant du noyau ne pouvait pas rivaliser avec le trail.

Le package VFX local possede maintenant deux couches de flamme recyclees :

- une enveloppe dense qui tourne autour du noyau et donne le volume de boule de feu ;
- une queue de flamme texturee, activee uniquement en LOD `Full`, qui part de l'arriere du projectile.

Le trail est plus court, plus fin et plus transparent. Il conserve la lecture du mouvement mais n'est plus la forme dominante. Les deux profiles `fireball_default` et `fireball_arcane` reglent leurs taux et tailles de flamme dans `VfxConfig`, sans modifier la simulation serveur, les impacts, les degats ou le pool de projectiles.

### Validation technique

- `rojo build -o $env:TEMP\TestRoblox-fireball-flame-v1.rbxlx` termine avec succes ;
- `git diff --check` ne remonte aucune erreur de contenu ;
- la recherche ciblee ne trouve plus de reference au champ VFX historique `package.Flame`.

### Smoke manuel cible

1. Lancer une run en `Quality` avec l'intensite des effets au maximum : une Fireball doit lire comme une boule de feu texturee, avec une enveloppe orange/jaune et une queue de flamme courte.
2. Tirer avec les skins classique puis arcane : le volume reste identique, tandis que les couleurs restent distinctes.
3. Passer en `Balanced` puis `Performance` : la flamme doit se simplifier progressivement, mais le noyau et le trail ne doivent jamais devenir trompeurs pour le combat.
4. Avec `Spawn 100 ennemis`, verifier que le budget VFX limite toujours les packages `Full` sans modifier les cibles ni les degats.

### Angles morts

- Juste : les deux nouvelles couches sont locales, poolees et reservees au projectile du joueur courant ; elles ne sont pas repliquees a tous les clients.
- Simplification : aucun nouvel asset n'est ajoute. La texture de flamme deja importee est exploitee deux fois avec des parametres differents plutot que d'introduire une nouvelle chaine d'import.
- Angle mort : la taille et la densite ideales dependent de la texture importee, de la luminosite de la map et de la distance camera. Le smoke manuel Studio est la preuve produit bloquante avant toute nouvelle sophistication du projectile.

## Addendum - 2026-07-13 20:48 CEST - Cadence des projectiles repliquees

Le ressenti de saccade de la Fireball avait une cause directe : `WeaponService` appliquait le mouvement et les pivots de projectile a 30 Hz. Les VFX locaux, attaches au projectile replique, ne pouvaient pas lisser cette cadence sans introduire un second chemin de mouvement client.

`CombatConfig.ProjectileSimulationHz` est maintenant regle a `0`, une valeur explicitement interpretee comme une mise a jour au `Heartbeat` dans `WeaponService`. Les projectiles, leurs trajectoires, collisions, rebonds et degats restent calcules par le serveur ; seule la frequence de mise a jour revient au rythme normal du jeu.

### Validation technique

- `rojo build -o $env:TEMP\TestRoblox-projectile-heartbeat-v1.rbxlx` termine avec succes ;
- `git diff --check` ne remonte aucune erreur de contenu ;
- aucun marqueur de conflit Git n'est present dans `src` ou `docs`.

### Smoke manuel cible

1. En `Quality`, tirer plusieurs Fireballs lentes : leur position, flamme de contour et queue doivent suivre le mouvement sans pas regulier visible.
2. Verifier un tir courbe, un rebond et un impact : le projectile visible doit encore atteindre la cible qui recoit effectivement les degats.
3. Avec `Spawn 100 ennemis`, consulter `Perf` dans le panneau admin puis MicroProfiler : verifier que le cout projectile reste acceptable en situation dense.

### Angles morts

- Juste : cette correction supprime le decalage perceptible entre le CFrame serveur replique et les VFX attaches, sans inventer de position client.
- Simplification : la valeur `0` reutilise la convention deja utilisee pour `MonsterSimulationHz`, au lieu d'ajouter un nouveau mode de simulation.
- Angle mort : le cout serveur de la boucle projectile augmente approximativement avec le passage de 30 Hz au rythme Heartbeat. Si les mesures reelles revelent un cout trop important avec de tres nombreux projectiles, le prochain chantier devra etre une presentation client interpolee isolee, pas un nouveau compromis visuel invisible.
