# Run Bars V2 - Promotion finale des barres

Date de cloture : 2026-07-17 00:46 Europe/Paris

## Objet du chantier

Promouvoir vers la production les versions validees dans
`MegaRobloxUIV_RunLayoutDraft` de la top bar et de la bottom bar, sans
reimplementer leur direction artistique dans les adaptateurs de jeu.

## Realisation

- La snapshot de production `MegaRobloxUIV_RunLayoutProductionTemplate` est
  passee en version 2 avec les composants `TopDock` et `BottomDock` issus du
  brouillon valide.
- La top bar se compose maintenant de deux clusters lateraux independants et
  d'un bloc temps centre. Le bloc temps conserve le chrono, le libelle et le
  bouton pause sans deplacer les valeurs laterales.
- `RunBarsV2Adapter.client.luau` recherche les slots dans les clusters et
  applique les echelles laterales a partir de la largeur reellement disponible.
  L'ancienne echelle globale du contenu de top bar a ete retiree pour ne plus
  decaler le centre.
- Le bouton pause de production garde son remote `Combat_TogglePause`. Le
  comportement visuel de bascule du brouillon reste limite a l'apercu admin.
- La bottom bar promue inclut l'encadre du portrait rectangulaire et les
  accents magenta/cyan coherents avec les bordures des panneaux.

## Validation

- `rojo build default.project.json -o TestRoblox.ui-promotion-check.rbxlx` :
  valide avant suppression de l'artefact de verification.
- `git diff --check` : valide. Les seuls messages observes concernaient des
  fins de ligne deja presentes.
- Verification Studio de la snapshot : version 2, groupes de top bar,
  controle pause, encadre portrait et archive de rollback presents ; aucun
  script n'est embarque dans les composants copies.
- Smoke manuel canonique et Play test realises par le joueur : valides.
  Le retour final confirme que tout semble correct.

## Rollback

La version precedente de `TopDock` et `BottomDock` est archivee dans
`ServerStorage/UiTemplateArchives/RunBarsV2_Previous`. Revenir en arriere ne
necessite pas de modifier les remotes ni les services de combat.

## Budget de complexite

Complexite deplacee puis reduite : la geometrie de la top bar est centralisee
dans un seul helper de l'adaptateur, au lieu de superposer une echelle globale
et des positions correctives sur les elements centraux.

## Angles morts connus

- La validation reelle effectuee concerne le format desktop. Le comportement
  mobile et les tres petites largeurs restent a valider lors d'une passe
  dediee.
- La preview admin reste une demonstration locale de layout. Le bouton pause
  de cette preview ne doit pas devenir une deuxieme implementation de la
  pause de run.
