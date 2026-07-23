# Post-audit - Ru's al Gale : promotion production V1

Date : 2026-07-23 03:00:53

## Etat initial

Ru's al Gale et la Lanterne des ames disposaient deja d'une boucle de combat
validee : les revenants etaient lus comme des invocations, la fumee enveloppait
les ames et le comportement ne ressemblait plus a un projectile ou a une zone
mobile. Le personnage n'etait toutefois pas encore completement raccorde au
roster de production : son portrait et l'icone de la lanterne conservaient un
damier blanc/gris incruste, rendu visible comme un rectangle blanc dans les
cartes de selection.

## Modification appliquee

- `rusal_gale` et `soul_lantern` sont exposes avec `Lifecycle = "Production"` ;
- ils sont inclus dans les contenus debloques par defaut de la progression V1 ;
- la configuration de personnage, le skin par defaut, la definition de l'arme
  et le skin de l'arme utilisent les assets transparents suivants :
  - portrait : `rbxassetid://111222772217752` ;
  - icone de lanterne : `rbxassetid://97347879630224` ;
- le template GUI Studio de selection a ete aligne sur les memes references.

Le detourage a ete realise localement depuis les deux images source existantes,
sans regeneration d'image. Seul le fond clair connecte aux bords a ete retire ;
les elements artistiques clairs, les os et les flammes vertes restent opaques.

## Verification

- verification alpha locale : les coins des deux PNG sont transparents ;
- aucune reference texte aux anciens assets non detoures ne subsiste dans le
  projet ;
- `rojo build default.project.json` : succes ;
- `git diff --check` : succes, hors avertissements LF/CRLF existants ;
- validation visuelle du responsable produit recue avant promotion.

## Decision

`Keep` : Ru's al Gale est disponible dans le roster de production V1 avec sa
Lanterne des ames et son passif de chance critique par niveau.

## Budget de complexite

Cette promotion ne change pas la simulation des revenants, les degats ni les
regles de progression. Elle remplace uniquement des references d'assets
defectueuses et active le contenu deja prepare. Complexite ajoutee : nulle sur
le chemin de combat.

## Angles morts et dette explicite

- Les vetements UV et les visuels d'armes restent une V1 fonctionnelle ; leur
  passe artistique devra etre reprise sans bloquer la jouabilite actuelle.
- Le roster n'est pas encore lie a son futur systeme de deblocage permanent ;
  l'ouverture par defaut est volontaire durant la phase de test.
- La validation multijoueur reste hors perimetre : les runs sont actuellement
  solo et aucune replication de projectile entre joueurs n'est attendue.

