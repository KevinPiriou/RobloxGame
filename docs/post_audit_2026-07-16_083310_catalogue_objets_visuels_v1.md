# Catalogue visuel des objets de run — v1

Date : 2026-07-16 08:33:10

## Portée clôturée

Les onze icônes manquantes du set Trello « Set d'objet complet » ont été régénérées dans la direction artistique des icônes Camembert et EnergyDrink. Elles sont présentes dans `assets/ui/object`, importées dans Roblox puis déclarées dans `RunItemConfig`.

## Choix d'implémentation

- Génération sur chroma vert ; chroma magenta pour le trèfle afin de préserver son vert.
- Détourage déterministe local avec décontamination des franges chroma avant import Roblox.
- Les onze définitions enrichissent `CatalogIds`, mais restent exclues de `ChestRewardIds` : aucun effet non implémenté ne peut apparaître pendant une run.

## Assets Roblox

- Trèfle à 3 feuilles — `rbxassetid://136642568746360`
- Main de Midas — `rbxassetid://103545854645957`
- Seringue — `rbxassetid://106285487760418`
- Boîte de conserve — `rbxassetid://124080032158490`
- Sneakers — `rbxassetid://95090721230008`
- Fiole corrompue — `rbxassetid://92339026927957`
- Carte d'accès rouge — `rbxassetid://123467944502862`
- Carte d'accès bleue — `rbxassetid://117598768761001`
- Dent de vampire — `rbxassetid://119085004302459`
- Golden Sneakers — `rbxassetid://117696542624948`
- Perfusion sanguine — `rbxassetid://72718513396654`

## Vérification

- Les treize PNG du dossier d'objets sont carrés, 1254 × 1254, RGBA et transparents aux quatre coins.
- `rojo build default.project.json` est valide.
- `git diff --check` est propre.
- Aucun Play ni smoke Studio n'a été lancé par Codex.

## Angles morts restants

- Les effets des onze nouveaux objets ne sont pas encore implémentés ni équilibrés ; seules leurs fiches de catalogue et leurs icônes sont prêtes.
- La lisibilité dans l'UI de coffre devra être validée par un smoke manuel lorsque ces objets seront introduits dans le pool.
