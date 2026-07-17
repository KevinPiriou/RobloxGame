## 2026-07-16 04:11:24 +02:00 - Ambiance locale des mondes et chapitres v1

### Perimetre

Le chantier concerne exclusivement le rendu local de la run et sa persistance
dans Rojo :

- `src/shared/EnvironmentConfig.luau` ;
- `src/client/EnvironmentController.client.luau` ;
- `default.project.json`, pour les instances `Lighting` auteur.

Le lobby, les templates de map, la progression de chapitre et les services
serveur ne sont pas modifies. Les proprietes de rendu restent locales au client
pendant une run.

### Constat initial

Les trois chapitres utilisent actuellement `Map_Test` comme template commun et
portent leur variation dans `TerrainThemeId` : `Verdant`, `Azure`, `Ember`.
L'ancien controleur choisissait son profil uniquement a partir du nom de map.
Les profils Azure et Ember existaient donc dans `EnvironmentConfig`, mais ne
pouvaient pas etre atteints en jeu.

Les effets ajoutes dans `Lighting` etaient egalement globaux : Atmosphere,
ColorCorrection, Blur, DepthOfField et SunRays pouvaient donc etre visibles dans
le lobby. Le DepthOfField auteur avait notamment un `NearIntensity` de `1`, ce
qui produit un flou de premier plan trop agressif pour la lecture du terrain.

### Application

`EnvironmentConfig` declare maintenant :

- un profil lobby sans brouillard (`Density = 0`, `Haze = 0`) ;
- le routage `Map_Test -> chapitre 1/2/3 -> ForestVerdant/ForestAzure/ForestEmber` ;
- un vent local leger et propre a chaque variante ;
- une profondeur de champ a distance seulement (`NearIntensity = 0`) et un blur
  tres faible ;
- des seuils et multiplicateurs dedies aux trois niveaux de qualite graphique.

`EnvironmentController` prend en charge les sources Atmosphere,
ColorCorrection, Blur, DepthOfField et SunRays, desactive les effets contextuels
dans le lobby, applique le profil de chapitre lu sur `MapRuntime/ChapterId`, et
restaure le vent de base en sortie de run. Les effets couteux sont desactives en
profil Performance.

`default.project.json` declare maintenant aussi les six instances auteur de
`Lighting` : Atmosphere, Sky, ColorCorrection, Blur, DepthOfField et SunRays.
Elles sont sourcees dans un etat lobby sur afin que Rojo puisse reconstruire le
rendu sur une session propre ; les profils de run les reglent ensuite localement.

### Validation

- build Rojo valide : `rojo build default.project.json` ;
- serveur Rojo 7.7.0 actif sur `127.0.0.1:34872`, projet `TestRoblox` ;
- smoke client lobby valide : `Density = 0`, `Haze = 0`, ColorCorrection, Blur,
  DepthOfField et SunRays desactives, vent nul ;
- smoke de run valide sur le chapitre 2 : profil `ForestAzure`, `Density =
  0.130`, `Haze = 0.860`, teinte Azure, vent `Vector3(1.55, 0, 1.05)` et effets
  actifs en qualite elevee ;
- resolution statique validee pour les trois profils Verdant, Azure et Ember ;
- aucune erreur du controleur d'ambiance dans la console Studio pendant les
  transitions testees.

### Angles morts et rollback

- [Juste] les variantes chromatiques de chapitre sont enfin selectionnees par
  le vrai signal runtime, sans dupliquer les maps.
- [Simplification] aucun nouveau service serveur ni RemoteEvent n'est ajoute :
  `ChapterId` deja porte par la map runtime est la source suffisante.
- [Angle mort] un seul Skybox est fourni. Le Sky est donc commun au monde ; une
  variation par chapitre requerra de vrais assets Sky distincts, pas une
  heuristique de teinte supplementaire.
- [Angle mort] le rendu exact doit encore etre juge dans les trois chapitres par
  un test visuel humain sur les plateformes ciblees, particulierement pour la
  lisibilite dans le brouillard.

La passe ajoute une complexite locale mesuree : deux profils visuels
supplementaires et cinq effets explicitement geres. Elle retire surtout le
comportement implicite et global du lobby. Le rollback conceptuel consiste a
supprimer `ChapterProfileIdsByWorld` et les blocs Blur/DepthOfField/Wind, puis a
revenir au seul profil de map sans toucher aux services de run.

---

## 2026-07-16 04:12:21 +02:00 - Verification de persistance Rojo

Le serveur Rojo actif est confirme sur `127.0.0.1:34872` et sert le projet
`Z:\Projet de dévelloppement\TestRoblox`. Les deux scripts et les declarations
`Lighting` sont maintenant presents dans la source surveillee. Le build Rojo est
vert apres la declaration des six instances auteur.

L'etat ouvert de Studio a aussi ete aligne sur le preset lobby source :

- Atmosphere : `Density = 0`, `Haze = 0` ;
- ColorCorrection, Blur, DepthOfField et SunRays : desactives ;
- DepthOfField : focus a `34`, rayon net `26`, aucune intensite proche.

Cette verification ferme le risque de divergence immediate entre l'etat Studio
et les fichiers Rojo. Le `Sky` reste persiste dans `default.project.json` avec
les assets actuellement presents dans Lighting.
