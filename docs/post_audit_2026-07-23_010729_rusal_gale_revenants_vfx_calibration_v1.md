# Post-audit - Ru's al Gale : calibration VFX des revenants V1

Date : 2026-07-23 01:07:29

## Etat initial

La premiere presentation de la Lanterne des ames reutilisait un noyau VFX
mobile et un impact large. Le comportement logique etait bien celui d'une
invocation, mais la lecture produit etait celle d'une zone qui se deplace puis
eclate. Ce rendu ne remplissait pas le cas canonique : comprendre immediatement
que le necromancien commande des morts qui harcelent une cible.

Le premier essai de silhouette avec le template `Monster1` a egalement ete
ecarte. Le teintage d'un monstre existant ne produisait pas une identite
artistique propre et donnait une impression de recyclage technique.

## Modification appliquee

### Presentation retenue

La Lanterne des ames conserve une simulation serveur-authoritative : duree de
vie, acquisition de cible, deplacement logique, coups et degats ne sont jamais
decides par le client. La couche cliente ne represente plus ce deplacement sous
la forme d'un projectile.

Chaque invocation se materialise directement au voisinage de sa cible, emerge
depuis le sol, puis orbite lentement autour d'elle. Elle est composee dans
Studio a partir du pack VFX deja present :

- `WraithMist`, fumee basse, dense et vert emeraude ;
- `WraithShroud`, seconde fumee plus haute qui enveloppe le corps ;
- `WraithSoul`, flamme d'ame discrete servant de coeur ;
- `WraithFace`, tete ForceField tres translucide et yeux verts lumineux.

La couche `FireSpecs1` est desactivee. Les etincelles etaient lues comme un
sort de feu et detournaient l'attention de la presence spectrale. Les impacts
sont restreints a un eclat d'ame local sur la cible et ne constituent plus le
corps du serviteur.

### Contrat de mouvement visuel

Le client suit une position d'ancrage transmise par le serveur. La presentation
utilise une montee courte depuis le sol, une oscillation verticale et une orbite
locale. Elle ne montre ni trajectoire rectiligne joueur-cible, ni trail
directionnel, ni collision visuelle en vol. Le gameplay reste inchange.

La recherche de cible des invocations est cadensee a 8 Hz par serviteur. Une
invocation ne nait que lorsqu'une cible est disponible. Cette borne conserve une
lecture reactive tout en evitant une recherche de cible a chaque Heartbeat pour
chaque serviteur.

## Verification

- `rojo build default.project.json` : succes ;
- `git diff --check` : aucun probleme de whitespace, hors avertissements
  existants LF/CRLF ;
- templates Studio verifies dans
  `ReplicatedStorage.VisualTemplates.WeaponVfx.SoulLanternSummon` ;
- smoke manuel valide par le responsable produit : le principe d'ame orbitale
  est retenu et la passe finale de fumee, de transparence et d'yeux est jugee
  satisfaisante.

## Decision

`Keep` pour la presentation V1 des serviteurs de Ru's al Gale.

## Budget de complexite

La passe supprime la tentative de reutilisation du modele de monstre et la
remplace par un unique template VFX local compose dans Studio. Elle ajoute une
orbite cliente tres bornee, sans nouvelle physique, sans NPC replique et sans
autorite cliente sur le combat. La complexite gameplay est inchangee et la
charge visuelle reste proportionnelle au cap existant de six invocations.

## Angles morts et dette explicite

- Le revenant est une presence abstraite, pas encore un modele 3D de squelette
  ou de fantassin mort-vivant dedie. C'est un choix V1 visuel, pas la forme
  finale de l'armee des morts.
- La lanterne 3D et les skins de l'arme restent a produire avant que Ru's al
  Gale soit promu au roster de production.
- La calibration a ete validee en solo. La perception visuelle avec plusieurs
  joueurs et plusieurs necromanciens doit etre verifiee avant toute ouverture
  multijoueur.

## Conclusion

La Lanterne des ames cesse d'etre lue comme une arme de zone ou un projectile.
Elle utilise maintenant une grammaire visuelle de revenants : fumee dense,
corps presque immateriel, yeux comme point de lecture et harcelement orbital
des ennemis. Les regles de combat ne sont pas modifiees.
