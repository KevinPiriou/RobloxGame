# Aiguille de Leyde - Passage en production

## 2026-07-21 20:43:41 +02:00 - Livraison initiale de l'arme de zone

## Statut

Decision : `Keep` - l'Aiguille de Leyde est disponible dans le catalogue de
production. Elle reste une arme de zone autonome, validee par le serveur.

Commit de reference avant livraison :
`9a26baf25d7a1ae5e297ae80b503d3e84ac2eb85`.

## Etat livre

- `leyden_needle` declare `Lifecycle = "Production"` dans
  `src/shared/WeaponConfig.luau` ;
- l'icone de production est `rbxassetid://71972739531178` ;
- l'arme ne consomme pas le nombre de projectiles ;
- elle cree une zone electrique, applique les degats par le serveur aux cibles
  presentes lors de l'impact, puis propage ses rebonds vers des cibles encore
  non frappees ;
- le client ne fait que presenter la charge, les impacts et les arcs. Il ne
  peut ni choisir une cible, ni declarer un impact, ni attribuer des degats ;
- le nombre d'eclairs de presentation est derive du rayon effectif : `1` au
  rayon natif de `14`, jusqu'a `5` au cap de rayon `26`. Cette progression ne
  multiplie pas les degats d'une cible : chaque cible de la zone ne recoit
  qu'une application de l'arme par impact ;
- les rebonds visibles sont composes a partir du template VFX existant
  `ChainArcTemplate`, sur deux plans et avec faces avant/arriere, afin de
  rester lisibles autour des cibles sans creer de VFX proceduraux hors pack ;
- le decal d'impact noir retire du template n'est plus utilise. Le rendu
  conserve les effets Lightning du pack VFX deja valide par le projet.

## Contrat et validation

Le validateur des definitions d'armes impose maintenant pour une arme de zone :

- un `VfxProfileId` ;
- un rayon maximal coherent ;
- un nombre d'eclairs maximal coherent ;
- une icone 2D non vide avant le passage en production ;
- des evolutions declaratives valides.

Verifications techniques de livraison :

- `rojo build -o %TEMP%\\megroblox-aiguille-leyde-production-check.rbxlx` :
  vert ;
- `git diff --check` : vert ;
- les modifications precedentes ont ete observees manuellement : disparition du
  decal noir, impact Lightning actif et agrandissement valide des icones dans
  le dock d'armes.

## Budget de complexite

La passe ajoute une formule courte de presentation pour convertir le rayon de
zone en nombre d'eclairs et un affichage d'arc plus robuste. Elle ne rajoute
aucune regle de degats, aucune nouvelle autorite client et aucune couche de
collision.

La complexite est donc localisee aux adaptateurs VFX et au contrat declaratif
de l'arme. Le chemin serveur reste : choisir la zone, resoudre les cibles,
appliquer les degats, notifier la presentation.

## Angles morts et smoke bloquant reporte

Le produit a autorise ce passage en production avant une observation manuelle
complete de la derniere variation visuelle. Il reste a jouer le smoke suivant
en run normale :

1. acquisition de l'Aiguille de Leyde au rayon de base : une zone, un eclair,
   degats uniques par cible ;
2. montee du rayon jusqu'au cap : expansion de la zone et progression visible
   de un a cinq eclairs, sans multiplication non voulue des degats ;
3. au moins un rebond valide : arc electrique lisible entre deux cibles et
   aucune cible frappee deux fois par le meme impact ;
4. verification du dock : icone visible, niveau correct, pas de regression
   Fireball.

Ce smoke ne remet pas en cause l'activation demandee, mais il est necessaire
pour qualifier le rendu final comme valide produit et non seulement compile.

## Conclusion

L'Aiguille de Leyde entre dans le catalogue de production avec son contrat de
zone, son asset 2D, sa presentation Lightning et ses bornes explicites. Les
futures valeurs d'equilibrage restent a calibrer dans le pipeline armes et
MetaBuildLab ; cette livraison ne les presente pas comme definitives.

## 2026-07-21 20:43:41 +02:00 - Verification Studio en mode Edition

La source de `ReplicatedStorage.Shared.WeaponConfig` ouverte dans Studio a ete
relue directement. Elle contient bien `Lifecycle = "Production"`, l'icone
`rbxassetid://71972739531178`, `StrikeCount = 1` et le cap `StrikeCount = 5`.

Une premiere lecture via `require` avait retourne une ancienne table en cache
du mode Edition. Elle n'etait pas une divergence entre le depot et Studio. La
verification a donc porte sur `ModuleScript.Source`, la source qui sera chargee
fraichement au prochain Play Test.

Le template `ReplicatedStorage.VisualTemplates.WeaponVfx.LeydenNeedleZone` a
egalement ete controle : aucun enfant `Impact` ne subsiste ; `Strikes` contient
cinq positions de presentation et `ChainArcTemplate` est present.
