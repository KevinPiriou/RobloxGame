# Pipeline armes V1 - Contrat de creation, calibration et equilibrage

## 2026-07-19 23:30:34 +02:00 - Contrat produit et technique initial

## Statut du document

Ce document prepare un chantier. Il ne decrit pas une implementation deja
validee et ne doit pas etre lu comme un post-audit.

- Phase : cadrage avant implementation.
- Commit inspecte : `2f932e482e8f772958a9ba2cb18a45cf7c58f4e5`.
- Gameplay modifie par cette passe : aucun.
- GUI de progression d'arme : explicitement reporte a un chantier ulterieur.
- Source des decisions : arbitrages produit conduits le 2026-07-19.

L'objectif est d'empecher qu'une nouvelle arme entre dans les runs avec des
limites implicites, des effets non mesurables ou une calibration uniquement
fondee sur le ressenti. Le pipeline devra rester consommable par le gameplay,
les outils de validation et `MetaBuildLab_v1` sans copier les formules.

## Classification de l'etat actuel

### Juste - Le socle serveur doit rester autoritaire

Le serveur reste seul responsable des cibles, collisions, degats, critiques,
statuts, rebonds, cooldowns et recompenses. Les clients peuvent presenter et
interpoler, mais ne valident jamais un impact.

Les travaux P2 et P3 constituent une base pertinente : simulation de horde
mesuree, projectiles logiques serveur et presentation client pilotee. Ils ne
prouvent cependant que le comportement de Fireball, pas celui de toutes les
categories futures.

### Juste - Fireball possede deja certaines limites

L'affirmation initiale selon laquelle Fireball n'avait aucune limite etait trop
large. Le projet impose actuellement notamment :

- acquisition de cible a `90` studs ;
- cooldown de base `0,95` seconde ;
- vitesse de base `58` studs par seconde ;
- duree de vie de base `3,8` secondes ;
- rayon d'impact `4,25` studs ;
- nombre de projectiles effectif borne a `24`.

### Faux - La portee de ciblage n'est pas une portee de trajet

La limite de `90` studs ne borne pas la distance cumulee parcourue. La duree de
vie permet actuellement environ `220` studs en ligne droite a vitesse native,
avant courbes et rebonds. La vitesse et la duree peuvent en plus augmenter. La
future portee contractuelle ne pourra donc pas reutiliser ce champ sans
migration explicite.

### Angle mort - Duree d'effet modifie encore la vie du projectile

`PerkService.GetAttackDuration` delegue a `GetEffectDuration`. Fireball utilise
ainsi `EffectDurationPercent` pour sa duree de vol. Cela contredit le contrat
produit : `Duree` doit renforcer poison, brulure, buffs, debuffs, zones et
autres effets persistants, jamais la vitesse, la portee ou le temps de vol d'un
projectile.

Ce defaut doit etre corrige avant de qualifier Fireball de reference calibree.

### Contestable - La rarete actuelle n'est pas independante de Chance

Le systeme actuel part de poids `58 / 28 / 11 / 3` et augmente deja les poids
Rare, Epique et Legendaire avec `Luck`. Il est donc faux de dire que Chance ne
participe pas au tirage. Le vrai probleme est ailleurs :

- le taux de base Epique + Legendaire atteint deja `14 %` ;
- les ajouts de poids ne constituent pas une redistribution explicable d'une
  distribution de `100 %` ;
- aucune distribution maximale ni courbe de reponse calibree n'est declaree ;
- le meme concept `Luck` augmente aussi directement la chance de pieces ;
- l'interface ne peut pas annoncer proprement la distribution finale.

La migration de rarete devra conserver ou separer explicitement l'effet de
Chance sur les drops. Ce point ne doit pas etre modifie silencieusement par le
chantier armes.

### Angle mort - WeaponService est deja un fichier partage volumineux

`WeaponService.luau` porte actuellement environ `960` lignes et gere Fireball,
les salves, le ciblage, le pool, la simulation, les rebonds, les impacts, les
VFX et le pilote client. Ajouter chaque future arme directement dans ce fichier
violerait le contrat de sobriete architecturale.

Avant toute modification, son point d'impact devra inclure : combat reel,
items sur impact, telemetrie P3, benchmark, VFX client, audio et pause de run.

## Modele de loadout

### Composition

- Une arme primaire est imposee par le personnage selectionne.
- Trois armes secondaires au maximum peuvent etre acquises pendant la run.
- Le joueur possede donc quatre armes actives au maximum.
- Les armes attaquent de maniere autonome et concurrente.
- Chaque arme possede son propre niveau, ses cooldowns et ses ameliorations.
- Une arme deja possedee n'est jamais acquise une seconde fois.

### Cycle de run

- L'arme primaire commence chaque run au niveau `1`.
- Les armes secondaires commencent au niveau `1` lors de leur acquisition.
- Armes secondaires, niveaux et ameliorations sont reinitialises en fin de run.
- Les deblocages permanents determinent seulement le catalogue accessible.
- Une arme secondaire doit etre debloquee, compatible, validee et absente du
  loadout pour entrer dans le pool d'acquisition.
- Une arme nouvellement acquise attend son cooldown complet avant sa premiere
  attaque.

### Ultimate

- L'ultimate est une capacite separee, propre a l'arme primaire.
- Il est active manuellement.
- Il possede une charge disponible ou un cooldown, pas un empilement de charges
  par defaut.
- Son cooldown avance uniquement pendant le temps actif de run.
- La vitesse d'attaque ne modifie jamais ce cooldown.
- Ses ameliorations rejoignent le pool d'ameliorations de l'arme primaire.
- Une reduction de cooldown d'ultimate respecte un minimum propre a
  l'ultimate et le minimum moteur.

## Taxonomie des armes

Chaque arme declare une categorie de livraison principale et zero ou plusieurs
comportements secondaires. Une Fireball reste par exemple `Projectile` avec
les comportements `Homing` et `Bounce`.

Categories principales :

- `Projectile` ;
- `Melee` ;
- `Zone` ;
- `Orbital`.

`Ultimate` n'est pas une cinquieme categorie d'arme. C'est une capacite de
l'arme primaire.

Comportements composables possibles, a enregistrer et valider avant usage :

- homing ;
- rebond ;
- perforation ;
- explosion ;
- multi-hit ;
- statut sur impact ;
- autres comportements futurs explicitement modelises.

Un identifiant inconnu doit echouer ferme dans le validateur et dans
MetaBuildLab. Il ne doit jamais etre ignore ou remplace par Fireball.

## Hierarchie des limites

Chaque statistique bornee suit trois niveaux :

1. securite moteur absolue ;
2. enveloppe de la categorie ;
3. cap propre a l'arme.

La valeur effective tient compte de toutes les sources : base, progression
locale, perks, objets et autres modificateurs. Le cap effectif est le plus
restrictif des trois niveaux. Une proposition locale qui n'apporte plus aucun
gain reel est retiree du pool.

Le niveau d'une arme n'a pas de cap. Lorsque tous ses axes finis sont au cap,
`DamagePercent` reste l'axe terminal. Il progresse lineairement par rapport aux
degats de base de l'arme, sans composition multiplicative. Une garde numerique
tres haute protege seulement le moteur contre `NaN`, `inf` et les valeurs
invalides ; elle ne constitue pas un niveau maximal de gameplay.

Les valeurs numeriques des enveloppes ne sont pas inventees par ce document.
Elles devront etre fixees par categorie apres benchmark et enregistrees dans
les configurations versionnees.

## Contrat des statistiques transverses

### Vitesse d'attaque

- Elle reduit le cooldown entre deux attaques ordinaires.
- Elle ne modifie pas l'intervalle interne d'une salve de projectiles.
- Une nouvelle attaque attend la fin de la salve precedente.
- Pour une melee, elle accelere `Windup`, `ActiveWindow` et `Recovery` ainsi
  que l'animation associee.
- Pour une zone, elle reduit le cooldown de creation, pas le tick des zones
  deja actives.
- Pour un orbital, elle augmente la rotation physique et reduit le cooldown de
  touche par cible dans les limites declarees.
- Elle ne modifie jamais l'ultimate.

### Vitesse de projectile

- Elle reduit le temps necessaire pour atteindre une cible.
- Elle n'augmente pas la portee.
- Elle ne modifie pas la cadence d'attaque.

### Duree d'effet

- Elle s'applique aux statuts, buffs, debuffs, zones et effets persistants
  explicitement compatibles.
- Elle ne s'applique jamais a la vitesse, la portee, la quantite ou la duree de
  vol d'un projectile.
- Le timeout d'un projectile est une securite derivee de sa portee, de sa
  vitesse et d'une marge moteur.

### Taille

Deux sources sont distinguees :

- `AttackSizePercent`, globale, issue notamment des perks ;
- `WeaponSizePercent`, locale a l'arme.

Chaque arme declare une `SizePolicy`. Elle precise quelles dimensions sont
modifiees : largeur, longueur, rayon, diametre du satellite, rayon orbital ou
combinaison explicite.

Un gain de `20 %` augmente les dimensions lineaires concernees de `20 %`. Il
ne signifie pas `20 %` de surface. Un disque dont le rayon augmente de `20 %`
couvre environ `44 %` de surface supplementaire. MetaBuildLab doit modeliser
la couverture au lieu de recopier le pourcentage lineaire.

### Critiques et procs

- Le critique est tire independamment pour chaque cible et chaque instance de
  degats.
- Chaque source declare un `ProcCoefficient`.
- La chance appliquee vaut `BaseEffectChance * ProcCoefficient`, puis les
  limites explicites du statut.
- Un cooldown interne peut etre declare par effet.
- Les statuts probabilistes ne sont pas comptes comme degats garantis dans le
  planificateur de cible.

## Contrat par categorie

### Projectile

Champs et limites obligatoires :

- distance cumulee maximale ;
- quantite par attaque ;
- nombre de rebonds ;
- vitesse ;
- rayon d'impact ;
- budget actif par arme et par joueur ;
- intervalle interne de salve ;
- timeout moteur derive ;
- multiplicateur de degats apres rebond propre a l'arme.

Les courbes et rebonds consomment la meme distance cumulee. Un rebond ne
reinitialise jamais la portee. Par defaut, un projectile disparait au premier
impact, sauf comportement explicite `Bounce`, `Pierce`, `Explosion` ou autre.

Quand le budget actif est sature, l'attaque attend. Aucun projectile n'est
supprime et aucune dette de tirs ne s'accumule pour produire une rafale de
rattrapage.

### Melee

Chaque arme declare :

- forme `FrontArc`, `Circle`, `Line` ou `Cone` ;
- dimensions et `SizePolicy` ;
- `Windup`, `ActiveWindow` et `Recovery` ;
- nombre maximal de cibles par attaque ;
- comportement `MultiHit` eventuel.

Sans `MultiHit`, une cible ne peut etre touchee qu'une fois par attaque.

### Zone

Chaque arme declare :

- forme et taille ;
- `SizePolicy` ;
- duree ;
- intervalle de tick ;
- degats par tick ;
- nombre maximal de cibles par tick ;
- nombre maximal d'instances actives ;
- politique de chevauchement.

Plusieurs zones d'une meme arme peuvent coexister. Une cible ne recoit que le
tick le plus fort de cette arme au meme instant. Deux armes de zone differentes
peuvent chacune infliger leur tick.

### Orbital

Un orbital persiste tant que l'arme est equipee. Il declare :

- nombre maximal de satellites ;
- taille des satellites ;
- rayon orbital ;
- `SizePolicy` ;
- vitesse de rotation ;
- cooldown de touche par cible ;
- nombre maximal de cibles traitees par pas ;
- budget orbital global du joueur.

Le serveur garde l'historique des touches. La frequence effective est le
minimum entre les contacts physiques possibles et les touches autorisees par
cooldown.

## Ciblage et reservation de degats

Toutes les armes automatiques cherchent en priorite la cible valide la plus
proche. Elles coordonnent ensuite leurs attaques afin de limiter le sur-degat.

Le planificateur serveur maintient, par joueur et par monstre :

- les degats directs non critiques garantis deja reserves ;
- l'identifiant de chaque attaque reservee ;
- son instant d'expiration ;
- son etat `Pending`, `Resolved` ou `Released`.

Une cible est consideree condamnee lorsque ses PV courants sont couverts par
les degats garantis reserves. L'arme suivante choisit alors la prochaine cible
valide la plus proche. Si Arme 1 suffit seule, Arme 2 change de cible. Si Arme 1
et Arme 2 sont toutes deux necessaires, c'est Arme 3 qui change de cible.

Une reservation reste active jusqu'a l'impact, la destruction ou l'expiration
de l'attaque. Elle est liberee exactement une fois.

Si une cible meurt avant l'impact :

- un projectile autorise a reacquerir cherche la cible valide la plus proche ;
- sa portee cumulee restante continue de s'appliquer ;
- une attaque qui ne sait pas reacquerir ne change pas magiquement de cible.

Les critiques, procs et statuts ne participent jamais a la prediction de mort.

## Ordonnancement et pause

- Cooldowns, salves, attaques et ultimate utilisent le temps actif de run.
- Une pause, un autel, un coffre ou un choix de niveau fige ces horloges.
- Aucun rattrapage n'est emis a la reprise.
- Plusieurs armes pretes au meme instant utilisent un leger decalage
  deterministe d'ordonnancement.
- Ce decalage ne modifie pas la cadence individuelle ni le DPS theorique.

Les projectiles d'une meme salve visent d'abord des cibles distinctes. Ils se
concentrent seulement lorsqu'il reste moins de cibles valides que de
projectiles utiles.

## Progression pendant la run

La source d'une proposition est fixee :

- autel de perk : choix de perk ;
- coffre ou coffre elite : objet de run ;
- montee de niveau du personnage : acquisition ou amelioration d'arme.

Le choix d'arme contient jusqu'a trois cartes. Une carte represente exactement
un axe et une valeur, par exemple `Fireball - Projectiles +1`.

Le tirage se fait en deux etapes :

1. groupe `NewWeapon` ou `WeaponUpgrade` selon des poids configures ;
2. contenu eligible dans le groupe retenu.

Il n'existe aucune garantie de nouvelle arme lorsqu'un emplacement est libre.
Si un groupe est vide, ses poids sont renormalises entre les groupes encore
valides. Aucun choix n'est consomme et aucune carte vide n'est produite.

Quand les quatre emplacements sont occupes, seules les ameliorations des armes
possedees restent eligibles. Un axe fini au cap disparait. Lorsque moins de
trois signatures distinctes restent disponibles, plusieurs cartes de degats de
raretes differentes peuvent remplir l'offre.

Cette exception terminale conserve trois cartes mais produit parfois un choix
domine : la rarete de degats la plus elevee est rationnellement superieure aux
autres. Cette limite produit est acceptee explicitement ; elle ne doit pas etre
presentee comme une diversite strategique.

## Perks globaux et compatibilite future

- Une arme acquise recoit immediatement tous les bonus globaux compatibles
  deja accumules.
- Un perk peut rester propose sans beneficiaire actuel, y compris lorsque le
  loadout est complet et qu'il ne pourra plus devenir utile pendant la run.
- L'interface doit alors afficher `Bonus en reserve` et les familles
  compatibles, sans inventer une valeur apres choix.
- `Duree` reste eligible sans source actuelle seulement si le catalogue encore
  accessible pendant la run contient une source de statut compatible.

La derniere regle est une exception volontaire au comportement general. Elle
ajoute de la complexite et devra posseder un test cible ; elle ne doit pas etre
qualifiee de regle generique.

## Passer et Bannir

Les credits `Pass` et `Ban` sont communs a tous les choix : perks, objets,
armes et futures gemmes. Ils sont temporaires, non achetables et reinitialises
a chaque run. Le projet utilise actuellement trois credits de chaque type.

`Passer` ferme l'offre sans recompense.

`Bannir` consomme un credit, applique le bannissement pour le reste de la run,
puis ferme l'offre sans remplacement ni recompense :

- perk : `PerkId` entier ;
- objet : `ItemId` entier ;
- acquisition : `WeaponId` entier ;
- amelioration : couple `WeaponId + UpgradeId` ;
- amelioration terminale de degats : non bannissable.

Le comportement actuel des perks regenere trois propositions apres un
bannissement. Il offre donc un reroll complet indirect et devra etre aligne sur
ce contrat. Le comportement actuel des coffres, qui ferme l'offre, est la
reference correcte.

## Rarete des ameliorations et Chance

### Regles

- Une acquisition d'arme n'a pas de rarete : elle fournit l'arme au niveau 1.
- Une amelioration utilise `Common`, `Rare`, `Epic` ou `Legendary`.
- Chaque axe declare explicitement sa valeur pour les quatre raretes.
- Les trois cartes tirent leur rarete independamment.
- Une variante qui depasserait un cap est retiree avant tirage ; aucun clamp
  silencieux, aucune perte et aucune conversion implicite ne sont autorises.
- Aucun pity system n'est retenu. Les longues series restent possibles.

### Profils de distribution

Un service central de rarete devra exposer au minimum les profils :

- `Perks` ;
- `WeaponUpgrade` ;
- `Chests`.

Chaque profil declare :

- `BaseDistribution` ;
- `MaximumDistribution` ;
- `LuckResponse` ;
- `LuckHardCap` ;
- version du profil.

La somme de chaque distribution vaut `100 %`. Chance produit une interpolation
exponentielle normalisee et a rendement decroissant entre la base et le
maximum. Le maximum est atteint exactement au cap. Les valeurs finales doivent
etre affichees au joueur.

Les valeurs numeriques donnees pendant le cadrage etaient illustratives et ne
doivent pas etre reprises. Les distributions seront calibrees et validees
statistiquement avant production.

### Aleatoire de production

Decision corrigee et definitive : les offres de perks, objets et armes ne sont
pas derivees de la seed de run. Elles utilisent un aleatoire de production non
reproductible par `RunSeed`.

Consequences :

- rejouer la meme seed de map ne reproduit pas les offres ;
- la seed de run reste reservee a la generation et au cycle de la run ;
- aucune promesse de replay exact des recompenses n'est faite ;
- les rapports de run enregistrent les choix observes, pas une sequence
  reconstructible a partir de la seed.

Les tests statistiques peuvent injecter un RNG seede dans le service de rarete
et le generateur d'offres. Cette injection est un outil de test uniquement et
ne change pas le hasard de production.

## Snapshot des attaques

Projectiles, melees et zones finies capturent leurs statistiques a leur
creation. Une amelioration selectionnee ensuite ne les modifie pas
retroactivement.

Les nouvelles attaques utilisent les nouvelles valeurs. Les orbitaux
persistants mettent a jour leurs proprietes a une frontiere sure sans etre
detruits, dupliques ou autorises a retoucher immediatement une cible par remise
a zero de leur historique.

## Contrat d'assets et de contenu

### Requis pour toute arme

- identifiant stable ;
- statut de cycle de vie ;
- categorie principale et comportements ;
- icone 2D ;
- VFX de gameplay ;
- audio applicable : cast, boucle, impact, fin, equipement, ultimate ;
- animation visuelle applicable ;
- identifiants i18n ;
- statistiques de base ;
- caps moteur, categorie et arme ;
- axes d'amelioration et valeurs par rarete ;
- ciblage et reservation ;
- degats, critique et proc ;
- budget de performance ;
- scenarios de validation.

### Arme primaire

- modele 3D equipe obligatoire ;
- socket declare : main, dos, corps, orbite ou autre socket valide ;
- ultimate obligatoire.

### Arme secondaire

- modele 3D equipe facultatif ;
- icone, logique et presentation d'attaque obligatoires.

## Cycle de vie d'une definition

Etats autorises :

1. `Development` ;
2. `Calibrating` ;
3. `Validated` ;
4. `Production`.

Une arme incomplete peut etre enregistree en `Development`. Elle ne peut pas
entrer dans un pool de run. Une definition invalide est exclue. Si l'arme
primaire obligatoire du personnage est invalide, le lancement de la run doit
echouer explicitement ; aucun fallback silencieux vers Fireball n'est permis.

## Architecture cible minimale

Le pipeline cible repose sur des definitions declaratives par arme, des
executeurs communs par categorie et un registre ferme de comportements. Il ne
repose ni sur un service complet par arme ni sur l'ajout de toutes les armes
dans `WeaponService`.

Responsabilites a isoler lors de l'implementation :

- catalogue et validation des definitions ;
- loadout et progression temporaire ;
- generation des offres ;
- rarete et Chance ;
- ordonnancement des armes ;
- ciblage et reservation de degats ;
- executeurs Projectile, Melee, Zone et Orbital ;
- ultimate primaire ;
- presentation client ;
- telemetrie et calibration.

Les noms de modules ne sont pas imposes par ce document. La frontiere de
responsabilite l'est.

`BuildMetaConfig` est actuellement descriptif et ne pilote aucun gameplay. A
terme, gameplay, export MetaBuild et validation devront consommer une source
de definitions commune ou un export genere. Copier les statistiques entre
deux catalogues est interdit.

## Pipeline de calibration

### Porte 1 - Schema et contenu

- champs obligatoires presents ;
- aucune categorie, statistique ou comportement inconnu ;
- valeurs finies et non negatives lorsque requis ;
- distributions de rarete valides ;
- caps ordonnes et coherents ;
- references i18n et assets resolues ;
- aucun axe sans variante de rarete ;
- aucune proposition impossible ou entierement sans effet.

### Porte 2 - Simulation deterministe

Le banc de test injecte des RNG seedes, sans modifier le hasard de production.
Il controle formules, caps, cooldowns, snapshots, reservations, procs et
invariants. Les resultats deterministes doivent correspondre au runtime a un
pas de simulation pres.

Les resultats aleatoires sont mesures sur plusieurs seeds de test et valides
par intervalle statistique. Une tolerance universelle arbitraire de `5 %` n'est
pas retenue.

### Porte 3 - Scenarios communs

Chaque arme est testee au minimum sur :

- cible immobile ;
- cible mobile ;
- horde dense ;
- elite ;
- boss ;
- stress aux caps ;
- loadout complet de quatre armes.

Les dummies et scenarios doivent etre reutilisables et ne pas dependre d'une
improvisation manuelle differente pour chaque arme.

### Porte 4 - Equilibrage multidimensionnel

Fireball est une reference de regression, pas une verite absolue d'equilibrage.
La comparaison utilise un vecteur :

- DPS mono-cible ;
- DPS horde ;
- couverture ;
- fiabilite ;
- risque et exposition ;
- controle ;
- frequence de proc ;
- cout technique.

Une arme de controle n'a pas a egaler le DPS brut d'une arme de burst. Chaque
role possede une enveloppe calibree. Aucun score unique ne peut, seul, valider
une arme.

### Porte 5 - Performance

Le budget couvre au minimum :

- temps serveur P50/P95/P99 ;
- instances logiques et visuelles actives ;
- bande passante ;
- projectiles, zones ou orbitaux simultanes ;
- raycasts et requetes spatiales ;
- particules, trails et lumieres ;
- memoire avant, pic, nettoyage et multi-run ;
- frame client et pics.

Une arme equilibree mais hors budget est bloquee. Les couches VFX decoratives
peuvent etre degradees selon les reglages graphiques. La simulation, les
degats, la quantite et la portee ne sont jamais diminues silencieusement pour
faire passer le budget.

### Porte 6 - Smoke manuel canonique

Le responsable produit valide au minimum :

1. acquisition et premiere attaque apres cooldown complet ;
2. amelioration de chaque axe ;
3. disparition des axes au cap ;
4. progression terminale de degats ;
5. ciblage nearest et limitation du sur-degat ;
6. reacquisition autorisee ;
7. pause sans rattrapage ;
8. Passer et Bannir ;
9. quatre armes simultanees ;
10. ultimate de l'arme primaire ;
11. reset complet apres fin de run ;
12. aucune regression du cas simple Fireball.

Un echec de ce smoke bloque `Validated` et `Production`, meme si MetaBuild ou
les tests internes sont verts.

## Invalidation ciblee

Une definition validee porte une version de contrat et une version d'equilibre.

- modification de gameplay ou statistiques : schema, simulation, equilibre,
  performance et smoke concernes ;
- modification VFX : performance et smoke visuel ;
- modification audio : smoke audio et cout applicable ;
- modification de texte : schema i18n et lecture UI ;
- modification structurelle : protocole complet.

La validation precedente reste archivee ; elle n'est pas reecrite.

## Comparaison Va / Vb requise pour Fireball

La migration de Fireball vers ce contrat devra conserver une Va testable et
une Vb activable. La comparaison couvrira au minimum :

- degats et critiques ;
- cadence et salve ;
- ciblage ;
- trajectoire et ressenti ;
- rebonds ;
- VFX et audio ;
- CPU, client et bande passante ;
- correction de `Duree` ;
- nouvelle distance cumulee.

Vb ne remplacera Va qu'apres smoke canonique valide et rapport avant/apres.

## Phasage recommande

### W0 - Baseline et contrat

- figer ce document ;
- capturer les valeurs et comportements Fireball actuels ;
- definir les smokes canoniques ;
- ne modifier aucun gameplay.

### W1 - Definitions et validateur fermes

- introduire le schema declaratif ;
- enregistrer Fireball en `Development` puis `Calibrating` ;
- brancher l'export MetaBuild sans dupliquer les valeurs ;
- verifier que les armes invalides restent hors pool.

### W2 - Rarete et offres

- centraliser les profils ;
- implementer Chance comme redistribution exponentielle ;
- conserver un aleatoire de production independant de `RunSeed` ;
- fournir une injection seede aux tests ;
- aligner Passer et Bannir entre perks, objets et armes.

### W3 - Runtime de categorie

- extraire progressivement les responsabilites de Fireball ;
- introduire ciblage, reservations, caps et temps actif ;
- corriger la semantique de `Duree` ;
- ajouter la portee cumulee ;
- comparer Va et Vb.

### W4 - Progression d'arme

- loadout temporaire ;
- acquisition et ameliorations ;
- filtres de cap ;
- reset de run ;
- remotes serveur fermes.

Le GUI reste un chantier separe. W4 peut etre valide avec un outil Admin ou une
interface technique avant integration visuelle.

### W5 - Premiere nouvelle arme

- choisir une categorie autre que Projectile si les executeurs correspondants
  sont prets ;
- produire assets, definition et ultimate requis ;
- traverser les six portes ;
- confronter MetaBuild au runtime.

### W6 - Production et documentation

- smoke final ;
- rapport avant/apres ;
- promotion en `Production` ;
- post-audit append-only ;
- archivage des preuves et versions.

## Proof of done du pipeline

Le pipeline n'est pas termine tant que :

- une definition invalide ne peut pas entrer en run ;
- Fireball Vb respecte le contrat sans regression canonique ;
- une seconde arme reelle traverse toutes les portes ;
- quatre armes peuvent fonctionner ensemble dans les budgets ;
- Chance produit des distributions mesurees et affichables ;
- les offres de production restent aleatoires et independantes de `RunSeed` ;
- les tests peuvent injecter leur propre RNG reproductible ;
- MetaBuild et runtime lisent la meme source ;
- prediction et observation sont comparees ;
- le reset de run ne conserve aucun niveau ou bannissement temporaire ;
- les rapports de validation sont versionnes et append-only.

## Budget de complexite

Le chantier ajoutera de la complexite explicite : quatre executeurs de
categorie, progression, offres, rarete et validation. Cette complexite est
justifiee par quatre armes simultanees et plusieurs familles de gameplay.

La contrepartie obligatoire est une reduction de la complexite implicite :

- pas de logique d'arme dispersee dans `WeaponService` ;
- pas de valeurs dupliquees dans MetaBuild ;
- pas de fallback silencieux ;
- pas de cap cache ;
- pas de seed de map reutilisee pour les offres ;
- pas de comportement inconnu ignore.

## Angles morts assumes

- Les valeurs numeriques de caps, distributions et enveloppes restent a
  calibrer.
- Les armes de Melee, Zone et Orbital n'ont pas encore de reference runtime
  reelle.
- Le GUI de progression d'arme n'est pas couvert par ce chantier initial.
- Le choix de garder certains perks sans beneficiaire peut produire des choix
  morts et devra etre clairement affiche.
- Les trois cartes terminales de degats peuvent contenir une option dominee.
- La relation actuelle entre Chance et drops de pieces n'est pas tranchee.
- Le planificateur de reservation devra gerer les impacts sur une cible autre
  que la cible initialement assignee.
- Les valeurs MetaBuild restent des proxies jusqu'a calibration runtime.
- Les animations, VFX et sons requis n'ont pas encore de protocole artistique
  chiffre au-dela des budgets techniques et du smoke produit.

## Rollback conceptuel

Chaque phase doit rester desactivable. Fireball Va demeure le rail simple tant
que Vb n'est pas validee. Les nouvelles definitions restent hors pool tant
qu'elles ne sont pas `Production`. Une regression du nouveau scheduler, du
planificateur ou des executeurs doit pouvoir revenir au chemin Fireball actuel
sans ajouter une couche de recuperation supplementaire.

## Decision

Le contrat est suffisamment ferme pour passer a W0 puis W1 sans nouvelle
boucle de questions produit. Les inconnues restantes sont des valeurs de
calibration ou des preuves runtime, pas des permissions d'inventer le
gameplay.

La prochaine action legitime est une baseline Fireball Va accompagnee du
schema declaratif et de son validateur, pas l'ajout immediat d'une nouvelle
arme.
