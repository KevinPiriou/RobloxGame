## 2026-07-16 07:20:42 +02:00 - Foliage procedural coherent v1

### Perimetre

Cette passe concerne exclusivement le decor runtime produit par le generateur
procedural :

- `src/shared/ProceduralMapConfig.luau` ;
- `src/server/ProceduralMapService.luau` ;
- le dossier Studio `ServerStorage.MapTemplates.ProceduralKit.Decorations`.

Elle ne modifie ni le lobby, ni les regles de run, ni les trajectoires de
generation des plateformes. Le joueur conserve la validation finale des smokes
Play ; aucun Play n'a ete lance par Codex.

### Application

Le generateur n'utilise plus les deux decorations historiques `Tronc/Boule`.
Il construit un catalogue a partir de `Decorations` et peuple les familles
suivantes avec des poids, tailles, plages d'altitude, densites et rayons
d'ecartement explicites :

- arbres verticaux `arbre`, frequents mais limites a un par grande plateforme ;
- herbes, fleurs, champignons, rochers, buissons et troncs horizontaux ;
- `CrateDecors`, traite comme un set rare et plafonne a deux occurrences par
  map.

Le dossier d'edition `Workspace.ProceduralKit.Decorations` a ete clone dans le
kit serveur runtime. Il contient 18 assets et 859 descendants apres l'ajout de
`arbre` et `CrateDecors`.

Les instances generees sont ancrees et marquees comme decorations afin qu'elles
ne servent jamais de surface de spawn. Les collisions sont intentionnellement
selectives :

- tous les rochers sont solides ;
- seul le tronc physique de `arbre` est solide ; la canopee reste traversable ;
- `CrateDecors` utilise un unique volume de collision invisible, plutot que ses
  231 micro-pieces, afin d'eviter les accroches physiques.

Le sol libre de la base est maintenant peuple en complement des plateformes.
Il reutilise les memes familles et les memes regles de tailles, de poids et de
collision, avec une densite additionnelle bornee. Toute candidate au sol est
refusee si elle tombe dans une plateforme, une rampe, un lien ou dans une marge
de 7 studs autour de leur volume. Une marge de 10 studs est aussi gardee sur le
bord de la zone jouable. Cela evite notamment qu'un arbre soit ancre dans la
tranche verticale d'une plateforme.

### Validation

- build statique valide : `rojo build default.project.json` ;
- verification de format validee : `git diff --check` ;
- smoke Play manuel valide par l'utilisateur apres ajout du peuplement au sol.

### Angles morts et rollback

- [Juste] le peuplement repose sur une seule source de verite configurable ;
  aucun nouveau service, event ou script de placement parallele n'est ajoute.
- [Simplification] les caisses n'ont qu'un seul collider. Cela preserve un
  obstacle fiable sans transformer un set de decor en maillage physique lourd.
- [Angle mort] le dossier `Decorations` est actuellement un asset Studio dans
  `ServerStorage`, et non un dossier mappe par `default.project.json`. Toute
  modification future des assets dans `Workspace.ProceduralKit.Decorations`
  doit etre resynchronisee vers le kit serveur avant validation.
- [Angle mort] la detection du tronc de `arbre` est geometrique car les huit
  pieces de l'asset portent le meme nom. Si le mesh est remplace, le seuil de
  collision devra etre revalide visuellement.

La passe ajoute une complexite locale mesuree : un catalogue de familles et un
second echantillonnage du sol, tous deux soumis au plafond global de 280
instances. Le rollback conceptuel du peuplement au sol est immediat : fixer
`Decorations.Ground.DensityMultiplier` a `0`. Le rollback complet consiste a
retirer les familles du catalogue et a revenir aux anciennes decorations, sans
modifier la generation de terrain elle-meme.

