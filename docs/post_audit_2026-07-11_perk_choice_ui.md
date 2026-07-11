# 2026-07-11 - Previsualisation et interface des choix de perks

## Objectif

Faire passer les choix de perks d'une liste de cartes generiques a une interface de jeu
lisible : rarete visible, niveau de stack, effet choisi et resultat avant/apres.

## Implementation

- `PerkService` construit les lignes de previsualisation avant d'envoyer les trois choix.
- Chaque ligne est calculee cote serveur a partir des statistiques actuelles et de la variante
  proposee. Les choix a effets multiples produisent plusieurs lignes.
- Les valeurs derivees utilisent les formules du gameplay : cadence reelle, degats de base,
  vitesse et duree des projectiles, rayon de collecte, multiplicateurs et plafonds de critique
  ou d'armure.
- `PerkUI.client.luau` remplace le panneau precedent par trois cartes de perk colorees selon la
  rarete, avec le niveau actuel, le niveau apres choix et les lignes `actuel -> apres`.
- La version etroite bascule les cartes dans une liste verticale scrollable.

## Validation

- `rojo build -o TestRoblox.rbxlx` termine avec succes.
- `git diff --check` ne remonte aucune erreur de contenu.
- Aucun marqueur de conflit n'est present dans `src` ou `docs`.

## Angles morts

- Angle mort : la taille et le positionnement des cartes doivent etre observes en Play Studio
  avec le panneau de statistiques de run affiche simultanement.
- Angle mort : lors de l'ajout de nouvelles armes, les lignes de degats et de cadence devront
  indiquer clairement l'arme concernee au lieu de supposer la Fireball actuelle.

## Mise a jour DA - HUD et cartes de perk

- Le HUD haut est maintenant un bloc metallique compact : kills, or, temps et pause y sont
  regroupes dans une seule barre.
- Le panneau de statistiques de run adopte une bordure cyan, des sections colorees et des
  marqueurs par famille de statistiques.
- Le panneau de choix de perks adopte un cadre sombre a accents violets, un diamant central,
  un medaillon d'icone, une bordure de rarete et un bouton visuel `Choisir` par carte.
- Trois icones locales ont ete generees et detourees : horde, chance et regeneration de vie.
  Elles sont rangees dans `assets/ui/perks/` avec leur procedure d'import dans Roblox Studio.
- `PerkIconConfig.luau` centralise les futurs `rbxassetid` sans toucher a la logique serveur.

## Validation complementaire

- Les trois PNG finaux sont des fichiers RGBA de 1254 x 1254 avec des coins transparents.
- `rojo build -o TestRoblox.rbxlx` termine avec succes apres la refonte.

## Angle mort complementaire

- Angle mort : Roblox ne permet pas a Rojo de transformer automatiquement les PNG locaux en
  `rbxassetid`. Les trois images doivent etre importees dans Roblox Studio, puis leurs IDs
  renseignes dans `src/shared/PerkIconConfig.luau` avant que les medaillons affichent les
  illustrations generees en Play Test.

## 2026-07-11 - Catalogue complet d'icones de perks

### Implementation

- Les 21 perks actuellement definis dans `src/shared/Perks.luau` possedent maintenant une
  illustration locale dediee dans `assets/ui/perks/`.
- Chaque illustration existe en deux variantes : `-source.png` avec fond chroma pour une
  regeneration eventuelle, et le PNG final detoure avec canal alpha pour l'import Studio.
- `PerkIconConfig.luau` declare maintenant la cle du perk elite afin que le catalogue couvre
  toutes les definitions de perks existantes.

### Validation

- 21 PNG finaux et 21 sources sont presents dans `assets/ui/perks/`.
- Le retrait de fond chroma a produit des pixels transparents et semi-transparents pour chaque
  image finale, preserves afin de garder des contours doux sur les medaillons.

### Angles morts

- Angle mort : l'import dans l'Asset Manager Roblox reste une etape manuelle et externe a
  Rojo. Tant que l'ID de `elite_flat_damage` ne sera pas renseigne, cette carte affichera son
  fallback colore au lieu de son illustration.
- Angle mort : les icones doivent etre observees dans les cartes de perk au format mobile et
  desktop, car leur lisibilite finale depend aussi de la taille effective du medaillon.
