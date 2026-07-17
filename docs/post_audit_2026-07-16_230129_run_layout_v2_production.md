# Run Layout V2 - Raccordement production

Date de cloture : 2026-07-16 23:01 Europe/Paris

## Objet du chantier

Raccorder en production le layout V2 valide depuis le brouillon
`MegaRobloxUIV_RunLayoutDraft`, sans modifier les remotes, les donnees de combat,
ni la direction artistique des composants deja construits.

## Realisation

- Ajout de `RunHudLayout.luau` dans `ReplicatedStorage/Shared` : calcul unique
  des dimensions, marges, gutters et contraintes de la HUD V2 de production.
- Ajout de `RunLayoutV2Controller.client.luau` : application du contrat aux
  composants existants `TopBarV2`, `BottomBarV2`, `PerkChoiceDockV2` et
  `StatsPanel`.
- Les adaptateurs conservent leur responsabilite : donnees, remotes, feedbacks,
  animation des cartes et des barres. Le nouveau controleur ne gere que les
  ancres et tailles.
- La top bar calcule desormais son echelle a partir de sa largeur utile interne,
  ce qui evite de reintroduire une largeur derivee differente du brouillon.
- Le controleur observe les nouveaux descendants de `PlayerGui` afin de
  reappliquer le layout quand un adaptateur cree son dock apres son ScreenGui.

## Validation

- `rojo build default.project.json -o TestRoblox.layout-check.rbxlx` : valide.
- `git diff --check` : valide.
- Recherche de marqueurs de conflit Git : valide.
- Smoke manuel canonique et Play test utilisateur : valides. Les composants
  restent ancres, alignes et correctement repondent a la taille de l'ecran.

## Pipeline UI retenu

1. Le kit visuel statique sert a composer les composants.
2. L'apercu runtime admin sert a valider le layout, les animations et la
   responsivite.
3. La production consomme ensuite les composants et le contrat valides, sans
   reimplementation visuelle parallele.

## Angles morts connus

- Le dock de toasts de quetes est present dans le brouillon mais ne possede pas
  encore de flux de donnees de production. Aucun faux toast statique n'a ete
  introduit dans une run.
- Les seuils minimaux actuels privilegient la lisibilite desktop. Une passe
  mobile dediee devra definir la regle de repli des rails lateraux au lieu de
  laisser des composants devenir trop etroits.
