# 2026-07-13 06:10 CEST - Auras de build V1

## Perimetre realise

Le joueur dispose maintenant d'un controleur d'auras exclusivement visuel, local au client. Une aura ne donne aucun bonus et ne modifie aucune statistique : elle rend lisible la direction prise par le build de la run.

Le controleur lit le payload `Perk_UpdateStats`, deja emis par `PerkService` cote serveur. Il ne cree donc pas de remote supplementaire et ne recoit aucune valeur decidable par le client.

## Familles et lecture du build

Les statistiques brutes ont des unites incompatibles. Une vitesse de deplacement de `+10 %` ne peut pas etre comparee directement a `+5 projectiles` ou `+20 degats bruts`. Chaque famille utilise donc des seuils de saturation explicites dans `src/shared/AuraConfig.luau`.

Le client garde au maximum les trois familles ayant les scores normalises les plus eleves :

- `Mobility` : vitesse de deplacement, saut et rayon de recolte, autour des pieds ;
- `AttackSpeed` : vitesse d'attaque, autour des mains ;
- `Arsenal` : projectiles, vitesse, duree et rebonds, autour du torse ;
- `Power` : degats, critiques et degats elite, autour du torse ;
- `Protection` : armure, bouclier, regeneration et vol de vie, avec particules et `Highlight` leger ;
- `Fortune` : gain XP, gain d'or et chance, au-dessus de la tete.

Une famille n'apparait pas sous un score de `0,12`. Les paliers V1 sont `1`, `2` et `3` a `0,12`, `0,36` et `0,70`. La densite et la taille montent aussi a l'interieur de chaque palier. Un joueur qui commence une run ne possede donc aucune aura.

## Cycle de vie et performances

`AuraController.client.luau` cree les `Attachment`, `ParticleEmitter` et eventuels `Highlight` seulement lorsque la signature des trois familles change : choix d'un perk, objet de run, reset ou entree de run.

Les instances sont locales au personnage du joueur et sont referencees dans `MegaRobloxAuras`. Elles sont detruites :

- a la fin de run ;
- au reset de statistiques ;
- au respawn du personnage ;
- lorsqu'aucune famille ne depasse le seuil.

Les auras passent aussi automatiquement par les reglages graphiques existants : la qualite et le curseur `EFFETS` reduisent les `ParticleEmitter` sans affecter la simulation serveur.

## Assets Studio attendus

Les six `StringValue` manuels attendus sont dans :

```text
ReplicatedStorage/VisualTemplates/AuraTemplates/ParticleTextures
```

| StringValue | Asset |
| --- | --- |
| `ArcaneGlyph` | `rbxassetid://85701068416379` |
| `HexShield` | `rbxassetid://97061127157979` |
| `SoftGlow` | `rbxassetid://106326034173369` |
| `SoftSmoke` | `rbxassetid://82629816435413` |
| `Spark` | `rbxassetid://93416665109999` |
| `WindStreak` | `rbxassetid://100405384039166` |

Les PNG sources restent aussi dans `assets/ui/aura`. Ils ne sont pas publies par Rojo et ne remplacent donc pas les IDs Roblox importes dans Studio.

## Validation technique

- `rojo build -o $env:TEMP\TestRoblox-auras-v1.rbxlx` termine avec succes ;
- `git diff --check` ne remonte pas d'erreur de contenu ;
- aucun marqueur de conflit Git n'est present dans `src` ou `docs`.

## Smoke manuel canonique bloquant

1. Dans le lobby, verifier qu'aucun dossier `MegaRobloxAuras` n'apparait sous le personnage et qu'aucune particule ne reste visible.
2. Lancer une run sans choisir de perk : le personnage doit rester sans aura.
3. Cumuler au moins deux bonus de vitesse de deplacement : verifier une aura cyan discrete aux pieds, plus dense apres de nouveaux bonus.
4. Cumuler de la vitesse d'attaque : verifier l'effet de vent autour des mains, sans changement de cadence de combat autre que celui deja donne par les perks.
5. Cumuler armure ou bouclier : verifier les hexagones et le voile bleu leger sur le personnage, sans remplacement du skin ni des accessoires.
6. Construire plus de trois familles : seules les trois scores les plus eleves doivent etre visibles.
7. Baisser `EFFETS` dans `VIDEO`, puis passer a `PERF` : les auras doivent etre reduites localement. Revenir a `QUALITE` doit les restituer.
8. Mourir ou sortir de la run, puis respawn : toutes les auras doivent disparaitre et aucune instance ne doit se cumuler au personnage suivant.

## Angles morts et budget de complexite

- Juste : la selection des familles est derivee de statistiques deja validees serveur ; le client ne peut pas demander une aura plus forte.
- Simplification : les six familles reemploient six textures communes colorees dynamiquement. Aucun pack distinct par couleur ou par rarete n'est ajoute.
- Contestable : les seuils de saturation sont une premiere lecture du build. Ils devront etre ajustes apres une vraie run longue, pas avant.
- Angle mort : le `Highlight` de protection suggere une armure metallique, mais ne remplace pas encore le materiau des membres. Modifier les materiaux locaux serait fragile avec les skins et accessoires ; un vrai shader de metal releve d'un chantier visuel ulterieur.
- Angle mort : V1 ne montre que les auras du joueur local. La replication et le culling des auras des autres joueurs ne sont pas utiles tant que les runs restent solo.

## Addendum - 2026-07-13 06:24 CEST - Lisibilite et couleurs de categorie

La premiere version appliquait une sequence de couleur commencant en blanc. Les textures restaient donc trop proches les unes des autres et le premier palier etait difficile a lire, particulierement aux pieds.

Chaque famille utilise maintenant sa couleur des l'emission :

- Mobilite : cyan ;
- Vitesse d'attaque : vert electrique ;
- Arsenal : violet ;
- Puissance : orange-rouge ;
- Protection : bleu ;
- Fortune : or.

Le multiplicateur de taille natif est porte a `x1,35`. Les paliers de base passent de `0,56 / 0,80 / 1,00` a `0,75 / 1,00 / 1,15`. Le premier effet reste leger, mais il devient observable apres les premiers bonus au lieu d'attendre une build deja tres avancee.

`rojo build -o $env:TEMP\TestRoblox-auras-visibility-v1.rbxlx` termine avec succes apres cette passe.

## Addendum - 2026-07-13 06:38 CEST - Magnetisme et Sustain

Deux familles supplementaires rendent maintenant deux axes de build qui etaient auparavant noyes dans les familles generalistes :

- `Magnetism` : le rayon de recolte quitte `Mobility`. Les glyphes et etincelles vert menthe apparaissent pres de la taille pour indiquer la zone de recolte accrue, sans imiter ni modifier le vrai mouvement des loots ;
- `Sustain` : regeneration et vol de vie quittent `Protection`. Une brume lente et une pulsation entourent le torse. La couleur est verte si la regeneration domine, rouge si le vol de vie domine, et intermediaire lorsque les deux se cumulent.

`Protection` ne represente donc plus que l'armure et le bouclier. Cette separation garde un signal different entre encaisser les degats, les restaurer, et attirer le loot.

Les deux familles restent en concurrence avec les autres pour les trois emplacements d'aura visibles. Les six textures existantes sont reutilisees : aucun nouvel asset n'est necessaire pour cette passe.

## Smoke manuel de l'addendum

1. Choisir un perk `Rayon de recolte` commun : une premiere signature menthe doit apparaitre legerement a la taille, sans changer la vitesse de deplacement.
2. Cumuler `Rayon de recolte` et `Vitesse de deplacement` : les deux familles peuvent coexister, le champ de magnetisme restant au torse et le vent aux pieds.
3. Cumuler de la regeneration : verifier une aura verte lente au torse.
4. Cumuler du vol de vie : verifier que cette aura se teinte progressivement rouge.
5. Cumuler armure, bouclier, regeneration et vol de vie : `Protection` et `Sustain` doivent rester visuellement distinctes, mais ne jamais depasser le plafond global de trois familles.

## Angles morts de l'addendum

- Juste : Magnétisme est un signal visuel, pas une seconde implementation locale de l'attraction des loots. La collecte reste serveur.
- Simplification : Sustain reemploie `SoftSmoke` et `SoftGlow`; un asset de coeur ou de goutte serait decoratif a ce stade et ne justifie pas encore une nouvelle dependance visuelle.
- Angle mort : la limite de trois familles peut cacher une famille faible mais interessante. C'est volontaire pour le rendu V1 ; un futur ecran de build pourra presenter la liste exhaustive sans surcharger le personnage.

`rojo build -o $env:TEMP\TestRoblox-auras-magnetism-sustain-v1.rbxlx` termine avec succes apres cette passe.

## Addendum - 2026-07-13 17:20 CEST - Redressement des auras liees au rig

Le retour de play test a revele une faiblesse reelle de la premiere lecture visuelle : les particules suivaient les directions de stat, mais elles etaient percues comme un nuage qui vole derriere le personnage. Cela ne communiquait pas une aura de puissance, de protection ou de sustain.

Les familles corporelles `Power`, `Protection` et `Sustain` sont maintenant distribuees sur le contour du rig :

- torse : bord gauche, bord droit et haut ;
- bras et jambes : bord gauche et bord droit ;
- particules : `LockedToPart`, vitesse locale tres faible, trainee nulle et dispersion resserree.

Les effets restent donc visibles quand le joueur est immobile et accompagnent le personnage lorsqu'il court, au lieu de rester dans l'espace apres son passage. `Protection` conserve un unique hexagone au torse et `Sustain` conserve une unique pulsation, afin de ne pas noyer les flammes corporelles sous des doublons.

La texture neutre `assets/ui/aura/AuraFlame.png` est preparee pour ce rendu. Tant qu'elle n'est pas importee dans Roblox Studio, le controleur retombe automatiquement sur `SoftGlow` ou `SoftSmoke` : la correction de mouvement et de contour fonctionne donc deja sans rendre la run indisponible.

Apres import Roblox de `AuraFlame.png`, creer ou mettre a jour le `StringValue` suivant :

```text
ReplicatedStorage/VisualTemplates/AuraTemplates/ParticleTextures/AuraFlame
```

Sa valeur doit etre l'ID publie sous la forme `rbxassetid://...`.

## Validation technique

- `rojo build -o $env:TEMP\TestRoblox-auras-contour-v1.rbxlx` termine avec succes ;
- `git diff --check` ne remonte aucune erreur de contenu ;
- aucun marqueur de conflit Git n'est present dans `src`, `docs` ou `default.project.json`.

## Smoke manuel canonique de redressement

1. Lancer une run, cumuler des degats ou critiques, puis rester immobile : des flammes doivent etre visibles autour du torse, des bras et des jambes.
2. Courir puis s'arreter : les flammes doivent rester collees au personnage et ne pas former une trainee persistante derriere lui.
3. Cumuler armure ou bouclier : le contour doit devenir bleu, avec un seul motif de bouclier complementaire au torse.
4. Cumuler regeneration ou vol de vie : le contour doit rester proche du corps, vert si la regeneration domine et rouge si le vol de vie domine.
5. Repasser dans le lobby : le dossier `MegaRobloxAuras` et toutes les emissions locales doivent disparaitre.

## Angles morts et budget de complexite

- Juste : ce redressement ne modifie ni les stats, ni les remotes, ni la simulation serveur. Il corrige uniquement le rendu local auquel le joueur est expose.
- Simplification : une unique texture de flamme neutre est teintee selon la famille. Huit packs de flammes differents ne donneraient pas un meilleur signal de gameplay a ce stade.
- Angle mort : le rendu exact de la flamme ne peut pas etre valide avant que `AuraFlame` soit publie et renseigne dans Studio. Le fallback garantit la robustesse, mais ne peut pas reproduire le dessin de flamme final.
- Angle mort : les corps R6 ont moins de segments que les corps R15. Ils gardent une aura visible grace au fallback vers `HumanoidRootPart`, mais le contour sera moins precis que sur un avatar R15.

## Addendum - 2026-07-13 17:32 CEST - Mix de VFX par famille de build

La texture de flamme est maintenant branchee avec `rbxassetid://72782845967015`. Son ID est conserve dans `AuraConfig.BuiltinTextureIds`, ce qui evite de bloquer le rendu si le `StringValue` Studio est absent. Un `StringValue` `AuraFlame` reste prioritaire lorsqu'il existe : il peut donc servir plus tard a remplacer l'asset sans modifier le code.

Les familles n'utilisent pas toutes une flamme. Le mix V1 suit la signification du build :

- `Power` : flammes orange-rouge sur le contour du corps ;
- `Sustain` : flammes corporelles vertes ou rouges selon regeneration et vol de vie ;
- `Mobility` : train de vent cyan aux pieds ;
- `AttackSpeed` : etincelles et courts arcs electriques autour des mains et avant-bras ;
- `Arsenal` : glyphes violets, etincelles et deux arcs entre torse et mains ;
- `Protection` : voile bleu discret, motif de bouclier et arcs entre torse et bras ;
- `Magnetism` : glyphes et etincelles menthe a la taille ;
- `Fortune` : glyphes dores au-dessus de la tete.

Les arcs sont des `Beam` locaux, crees une seule fois quand le build change. Ils ne possedent aucun `Heartbeat`, aucune logique de degat et aucun appel serveur. Leur cout reste donc borne au personnage local et ils sont detruits avec `MegaRobloxAuras`.

## Smoke manuel de l'addendum

1. Cumuler de la puissance : verifier des flammes orange-rouge, visibles a l'arret, sur le contour du rig.
2. Cumuler de la vitesse d'attaque : sur un avatar R15, verifier deux courts arcs electriques entre mains et avant-bras.
3. Cumuler de l'arsenal : verifier deux arcs violets du torse vers les mains, sans projectile ni degat supplementaire.
4. Cumuler protection : verifier les deux arcs bleus et un unique motif de bouclier au torse.
5. Reinitialiser la run ou revenir au lobby : verifier la disparition des `Beam`, des `Attachment` et des particules.

## Angles morts et budget de complexite

- Juste : la flamme est disponible immediatement avec l'ID confirme. Le `StringValue` Studio n'est plus un pre-requis pour cette texture precise.
- Simplification : les eclairs sont limites a trois familles ou ils decrivent une vitesse, une energie ou un bouclier. Les appliquer aux huit familles creerait du bruit et affaiblirait le signal de build.
- Angle mort : sur un rig R6, une main et son avant-bras peuvent etre la meme piece. Le controleur evite alors de creer un Beam de longueur nulle ; les etincelles restent visibles, mais l'arc est reserve au R15.

## Addendum - 2026-07-13 17:57 CEST - Redressement du mix aura et Fireball

Le play test a montre que la passe precedente ne tenait pas encore la qualite visuelle attendue : les bras et les jambes pouvaient etre satures de blanc, les familles se ressemblaient trop et la Fireball eclairait excessivement la scene proche du joueur.

La direction retenue reprend des principes d'aura d'energie animee : silhouette lisible, energie coloree, et un effet dominant qui ne masque pas le personnage. Elle ne cherche pas a reproduire des assets ou animations externes.

Le mix est maintenant simplifie :

- `Power` est la seule famille a employer la nouvelle flamme de contour ;
- `Sustain` utilise une brume et une pulsation verte ou rouge ;
- `Protection` limite son voile bleu aux torse et bras, avec un bouclier et des arcs discrets ;
- `AttackSpeed` garde de petites etincelles et du vent aux mains ;
- `Arsenal`, `Mobility`, `Magnetism` et `Fortune` gardent glyphes, vent ou etincelles selon leur sens gameplay.

Les emissions d'aura ont ete diminuees : taille native, taux, blancheur initiale, luminosite et opacite. Les arcs electriques deviennent plus fins et moins lumineux. Le personnage reste donc la forme principale du rendu.

La Fireball a aussi ete recalibree sans toucher a ses degats, sa vitesse ou sa logique de ciblage :

- luminosite de la source, trail et impact reduite ;
- feu legacy moins grand et moins chaud ;
- taux de feu et d'etincelles reduits ;
- les `Sparkles` Roblox, dont la taille n'est pas reglable, sont desactives et remplaces par `MegaRobloxControlledSparkles`, un petit `ParticleEmitter` attache au projectile avec la texture `Spark` deja utilisee par le projet.

## Smoke manuel de l'addendum

1. Construire `Power` seul : la flamme doit souligner le corps sans blanchir les mains, le visage ou les jambes.
2. Construire `Sustain` seul : verifier une brume coloree et non une seconde aura de flammes.
3. Construire `AttackSpeed` ou `Arsenal` : les eclairs doivent etre des accents fins, visibles sans couper la silhouette du joueur.
4. Tirer plusieurs Fireball pres du personnage : le sol et les membres ne doivent plus etre surexposes ; les etincelles doivent rester petites et attachees au projectile.
5. Verifier les deux skins Fireball : le skin arcane peut rester plus lumineux, mais ne doit pas eclairer davantage que le classique de maniere disproportionnee.

## Validation technique et angles morts

- `rojo build -o $env:TEMP\TestRoblox-aura-dbz-vfx-v1.rbxlx` termine avec succes ;
- `git diff --check` ne remonte aucune erreur de contenu ;
- aucun marqueur de conflit Git n'est present.
- Juste : les reglages modifies sont visuels. Le gameplay de combat reste autoritaire serveur et inchange.
- Simplification : la flamme n'est plus appliquee a toutes les familles. Un effet principal par famille donne une lecture plus forte qu'une superposition de cinq effets similaires.
- Angle mort : ce chantier requiert encore le smoke manuel ci-dessus sur la vraie camera de jeu. La compilation garantit les contrats Luau, pas le gout ni le rendu final des assets Roblox.

## Addendum - 2026-07-13 18:20 CEST - Fireball entierement pilotee

La Fireball ne depend plus des instances visuelles importees dans son template. Le modele peut encore contenir `Fire`, `Smoke`, `Sparkles`, `ParticleEmitter`, `Trail` ou lumiere legacy, mais ils sont desactives au spawn par `ProjectileVisualService`.

Le service cree et reutilise seulement les instances dont le nom commence par `MegaRoblox` :

- coeur Neon et `MegaRobloxCoreLight` ;
- `MegaRobloxFireballTrail` ;
- `MegaRobloxControlledFlame` ;
- `MegaRobloxControlledSmoke` ;
- `MegaRobloxControlledSparkles` ;
- impact temporaire issu du pool existant.

Les trois textures de particules sont maintenant declarees par skin dans `WeaponSkinConfig` : flamme, fumee et etincelle. Une prochaine variante de projectile peut donc modifier couleur, luminosite, densite, trail et textures par code, sans changer le contenu du template 3D.

Le choix de desactiver `Sparkles` est volontaire : cette instance Roblox ne permet pas de regler finement la taille. Son remplacement controle emet de petites particules attachees au projectile, avec une vitesse et une duree courtes.

## Smoke manuel de l'addendum

1. Tirer une Fireball classique et verifier que les anciens `Fire`, `Smoke` et `Sparkles` du template ne sont plus les sources du rendu.
2. Verifier une flamme courte autour du coeur, une fumee discrete et de petites etincelles attachees a la boule.
3. Tirer rapidement puis laisser le projectile retourner dans son pool : aucun effet legacy ne doit reapparaitre lors du tir suivant.
4. Selectionner la skin arcanique : elle doit reutiliser les memes controles avec ses propres couleurs, sans dupliquer les emitters.

## Validation technique et angles morts

- `rojo build -o $env:TEMP\TestRoblox-fireball-controlled-vfx-v1.rbxlx` termine avec succes ;
- Juste : aucun changement de degat, de trajectoire, de cible ou de cadence n'est realise dans cette passe ;
- Simplification : le template devient une source de forme et de son, non un second systeme VFX concurrent ;
- Angle mort : les trois IDs de textures sont valides dans le projet actuel. Une future skin qui omet un ID conservera coeur et trail mais n'aura pas la couche de particules concernee, ce qui devra etre renseigne explicitement.

## Addendum - 2026-07-13 18:27 CEST - Densite Fireball

Apres validation visuelle du passage aux effets controles, la densite de flamme, fumee, etincelles et trail est relevee legerement pour les deux skins. La luminosite centrale, les tailles d'etincelles et les limites de duree restent inchangees.

Le rendu gagne donc de la presence sans revenir a la surexposition precedente. `Explosion` n'est pas reference dans le code de combat : l'impact est cree par `ProjectileVisualService`. Il peut etre retire du template uniquement apres verification qu'il est un effet visuel et non une instance utile au modele importe.

`rojo build -o $env:TEMP\TestRoblox-fireball-density-v1.rbxlx` termine avec succes.

## Addendum - 2026-07-13 18:38 CEST - Flamme Fireball et retrait des faux eclairs

Le smoke visuel a revele deux regressions : la flamme Fireball etait devenue trop discrete face au trail, et les `Beam` d'aura reliant des segments proches du rig etaient lus comme des cercles colles au personnage.

La correction simplifie le rendu :

- les `Beam` et les options `UseLightning` sont retires entierement des auras ;
- la Fireball garde son trail, mais la flamme redevient la lecture principale grace a une emission plus dense, plus grande et diffusee autour du coeur ;
- les auras remontent en taille, densite et emission coloree, sans reintroduire la blancheur precedente ;
- fumee et etincelles restent des accents secondaires.

Un futur eclair ne devra pas reutiliser des `Beam` permanents entre deux segments du corps. Il devra etre implemente comme une decharge courte ou une texture adaptee, apres un test visuel isole.

## Smoke manuel de l'addendum

1. Tirer une Fireball sans perks : la boule doit etre lue comme une flamme mobile avec un trail secondaire, pas comme une comete seule.
2. Verifier une aura `Power` : elle doit etre plus presente, coloree et visible a l'arret, sans eblouir les membres.
3. Verifier `AttackSpeed`, `Arsenal` et `Protection` : aucun cercle ou arc continu ne doit rester colle au rig.
4. Tirer plusieurs projectiles et verifier que la densite supplementaire ne provoque pas de surexposition proche du joueur.

## Validation et angle mort

- `rojo build -o $env:TEMP\TestRoblox-fireball-flame-aura-v2.rbxlx` termine avec succes ;
- Juste : retirer les faux eclairs reduit la complexite et supprime directement le defaut percu ;
- Angle mort : la qualite de la texture de flamme reste dependante de son rendu Roblox en mouvement. Le smoke manuel reste la preuve prioritaire pour ce chantier visuel.
