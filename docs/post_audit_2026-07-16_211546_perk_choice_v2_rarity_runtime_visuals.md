# Post-audit - PerkChoice V2 : rarete runtime et cycles de particules

## 2026-07-16 21:15:46 +02:00 - Redressement de l'integration visuelle en production

### Nature du jalon

Le panneau `PerkChoiceDock` est clone depuis
`StarterGui/MegaRobloxUIV_RunLayoutDraft` par
`PerkChoiceV2Adapter.client.luau`. Cette passe corrige l'ecart entre la
maquette validee et les offres affichees en run : certaines couches conservaient
la couleur des slots de demonstration `Offer1`, `Offer2` et `Offer3` alors que
la rarete venait des offres serveur runtime.

### Juste - Une rarete runtime par carte

- Le titre du perk utilise a nouveau la couleur primaire ivoire du contrat de
  design. Le libelle de rarete et la description gardent la couleur de rarete.
- Les couches de surface qui portent une teinte sont maintenant explicitement
  colorees avec la rarete de l'offre : `MaterialLayer`, `PatternCanvas`,
  `GlassSurface`, `HoverWash`, bordure et accent.
- Les gradients nommes de la carte (`DA_CardGradient`, `MaterialGradient`,
  `GlassGradient`, `AuraGradient`, `WashGradient` et `SheenGradient`) gardent
  leur role visuel propre. Ils ne sont plus tous ecrases par une meme recette
  de couleur sombre.
- L'intensite du reflet au survol depend de la rarete runtime, et non plus de
  l'index du slot de demonstration utilise comme template.

### Juste - Cycle de vie deterministe des particules

- Chaque carte possede un compteur de cycle et suit ses tweens de particules.
  Une nouvelle proposition, un reroll ou la fermeture du panneau annule les
  tweens precedents puis masque les particules avant tout nouveau depart.
- Les particules initiales du template sont uniquement des prototypes. Elles ne
  restent plus visibles entre deux propositions et ne peuvent plus conserver
  une ancienne couleur ou une ancienne position.
- Cette correction reste locale au client : elle ne modifie ni les offres, ni
  les rares, ni les choix definitifs envoyes au serveur.

### Validation executee

- `rojo build -o $env:TEMP/TestRoblox.verify.rbxlx` reussit.
- `git diff --check` ne signale pas d'erreur de contenu. Les avertissements
  `LF -> CRLF` proviennent du contexte Windows existant.
- Aucun marqueur de conflit Git n'est present.
- Smoke manuel canonique valide par le joueur : effets de particules et
  animations corrects, couleurs de surface liees a la rarete runtime, titre
  ivoire et absence de particule residuelle apres changement d'offres.

### Budget de complexite et angles morts

- Simplification : le cycle de particules precedent pouvait survivre a une
  nouvelle offre. Il est remplace par un seul cycle annulable par carte ; aucun
  controleur supplementaire n'est introduit.
- Angle mort : les recettes reposent sur les noms des couches visuelles du kit.
  Renommer un gradient ou une surface Studio doit etre accompagne de la mise a
  jour ciblee de `PerkChoiceV2Adapter.client.luau`.
- Angle mort : la validation a porte sur le flux desktop de run. Les memes
  cartes doivent etre inspectees sur ecran tactile et faible resolution avant
  de considerer la presentation universelle.

### Rollback conceptuel

Le rollback consiste a retirer le mapping runtime des surfaces et a restaurer
la version precedente de `PerkChoiceV2Adapter.client.luau`. Le kit Studio, les
services serveur et le contrat de gameplay ne sont pas affectes.
