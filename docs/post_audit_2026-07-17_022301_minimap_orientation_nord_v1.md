# Minimap V2 - Orientation nord et cible centrale

Date de cloture : 2026-07-17 02:23 Europe/Paris

## Objet du chantier

Stabiliser la lecture de la minimap V2 apres une premiere tentative de vue
orientee par le joueur. Le comportement observe faisait pivoter les reperes,
la carte et les cardinalites ensemble, ce qui rendait la lecture instable.

## Realisation

- `MiniMapUI.client.luau` emploie maintenant une projection classique
  orientee nord : les points cardinaux et les reperes du monde restent fixes.
- Le joueur reste au centre de la minimap. Seul son triangle pivote selon le
  `LookVector` du `HumanoidRootPart`.
- Les cibles ne sont plus rabattues sur les anneaux de portee. Elles sont
  masquees lorsqu'elles sortent du disque central de lecture.
- Les anneaux et les points cardinaux conservent donc leur role de repere
  visuel, sans etre confondus avec la zone de cibles actives.

## Validation

- `rojo build -o TestRoblox.minimap-check.rbxlx` : valide avant suppression
  de l'artefact de verification.
- `git diff --check -- src/client/MiniMapUI.client.luau` : valide.
- Smoke manuel canonique realise par le joueur : tourner sur place, puis se
  deplacer dans les directions cardinales. Validation utilisateur recue :
  le comportement semble correct.

## Rollback

Le retour a la version precedente consiste a restaurer uniquement la
projection orientee joueur dans `MiniMapUI.client.luau`. Aucun service serveur,
remote, marqueur runtime ou template de minimap n'a ete modifie.

## Budget de complexite

Complexite reduite : les vecteurs de base locale et la rotation dynamique des
cardinalites ont ete retires. La minimap utilise une projection monde fixe et
une seule rotation, celle du triangle joueur.

## Angles morts connus

- Le rayon du disque central est calibre visuellement a 46 % du rayon logique
  de minimap. Il pourra etre ajuste apres une session de jeu longue si la zone
  de lecture est trop courte ou trop large.
- Les marqueurs ne representent pas encore les ennemis, les projectiles ni le
  relief procedural ; ce choix reste volontaire pour proteger la lisibilite.
- La validation actuelle concerne le format desktop. Une verification mobile
  reste necessaire avant de declarer la minimap pleinement responsive.
