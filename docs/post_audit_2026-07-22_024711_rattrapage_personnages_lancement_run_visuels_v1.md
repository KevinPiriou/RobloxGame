# Rattrapage - Personnages, lancement de run et premiers visuels V1

## 2026-07-22 02:47:11 +02:00 - Perimetre du rattrapage

Ce document reprend uniquement les travaux posterieurs a la fondation decrite
dans `post_audit_2026-07-21_223100_fondation_personnages_jouables_v1.md` qui
n'avaient pas encore recu de trace chronologique complete.

Les chantiers Aiguille de Leyde, performances P0 a P3, auras, validation des
seeds et MetaBuildLab possedent deja leurs propres audits. Ils ne sont pas
redocumentes ici afin de conserver une source lisible et non contradictoire.

Commit de reference avant ces passes : `9a26baf`.

Etat du depot au moment du rattrapage : travail non commite comprenant le
catalogue de personnages, le cycle de selection, le lancement de run V2, les
passifs, la persistance cosmetique et les assets de vetements.

## Catalogue de production Medivh et Albert

Les contrats provisoires ont ete remplaces par deux definitions activables :

- `medivh`, mage malicieux, portrait `rbxassetid://72675265292172`, arme
  principale `fireball` et passif `Volee arcanique` ;
- `albert`, savant fou, portrait `rbxassetid://76272865710318`, arme
  principale `leyden_needle` et passif `Magnetisme scientifique`.

Medivh ajoute un projectile aux armes de categorie `Projectile`. Le bonus est
applique dans `WeaponLoadoutService` apres lecture de la definition de l'arme,
et ne modifie donc ni les armes de zone ni une statistique joueur globale.

Albert multiplie par trois le rayon de collecte de base. L'operation retenue
est `MultiplyBase` : les bonus additifs acquis pendant la run ne sont pas
triples implicitement. `PerkService` consomme ce multiplicateur lors de la
construction des statistiques de collecte.

`CharacterDefinitionValidator` impose a chaque personnage de production :

- un identifiant et un nom coherents ;
- un portrait 2D ;
- une arme principale ;
- une apparence R15 avec chemin de template et vetements complets ;
- un passif declaratif dont le scope et l'operation sont connus.

## Assets et apparences R15

Les sources de production sont archivees dans le depot :

- `assets/ui/character/medivh_portrait_v1.png` ;
- `assets/ui/character/medivh_portrait_v1_cutout.png` ;
- `assets/ui/character/albert_portrait_v1.png` ;
- `assets/ui/character/albert_portrait_v1_cutout.png` ;
- `assets/character/medivh/clothing/medivh_shirt_v1.png` ;
- `assets/character/medivh/clothing/medivh_pants_v1.png` ;
- `assets/character/albert/clothing/albert_shirt_v1.png` ;
- `assets/character/albert/clothing/albert_pants_v1.png`.

Les templates Studio vivent dans `ServerStorage.CharacterTemplates.Medivh`
et `ServerStorage.CharacterTemplates.Albert`. Ils restent des rigs R15
compatibles avec les animations communes futures. Les accessoires et les
animations propres aux personnages sont volontairement reportes.

Le joueur conserve son avatar Roblox dans le lobby. Au debut d'une run,
`CharacterService` memorise les vetements courants, applique la tenue du
personnage selectionne et affiche un temoin de nom discret au-dessus du rig.
En fin de run, le temoin est retire et l'apparence precedente est restauree.

Une anomalie d'edition Studio a laisse Albert gris alors que son template,
ses objets `Shirt` et `Pants`, leurs identifiants et leurs images etaient
encore presents. `ContentProvider` indiquait un chargement reussi et aucune
erreur de contenu n'apparaissait dans la console. Un rechargement explicite
des deux proprietes de vetement a restaure l'affichage. Il s'agissait donc
d'un etat de cache ou de rafraichissement Studio, pas d'une perte d'asset ni
d'une suppression Rojo.

## Selection et lancement de run V2

`RunLauncher.client.luau` ne reconstruit plus son ecran central historique.
Il clone les composants valides de `MegaRobloxUIV_RunLayoutDraft` :

- `RunLaunchDock` pour le roster, l'apercu et les skins ;
- `MapSelectionDock` pour le choix du niveau et du chapitre.

Le flux produit est sequentiel :

1. ouvrir `LANCER UNE RUN` dans le lobby ;
2. choisir un personnage disponible ;
3. consulter son arme principale et son passif ;
4. continuer vers le choix de niveau ;
5. choisir un chapitre debloque ;
6. demander le lancement au serveur.

Les deux composants reprennent l'ancrage central et la responsivite du layout
de run. Leur fermeture passe par une croix explicite ou `Echap`. Un clic sur
le fond ne ferme plus involontairement le parcours. `Retour arriere` depuis
le choix de map est disponible avec `Backspace` tant qu'aucun lancement n'est
en cours.

Le roster et la selection sont alimentes par des remotes proprietaires du
`CharacterService`. Le client affiche les verrous distincts du personnage et
de son arme principale, mais le serveur reste seul juge de leur disponibilite.

## Persistance et snapshot immuable de run

La metaprogression est passee a la version de donnees `4`. Elle conserve :

- les personnages debloques ;
- les armes debloquees ;
- le personnage selectionne ;
- une selection cosmetique par personnage, contenant `CharacterSkinId` et
  `WeaponSkinId`.

Le lancement ne lit pas cette selection en continu. `CharacterService`
capture un snapshot comprenant le personnage, l'arme principale et les deux
skins. `RunSessionService` copie uniquement des primitives compatibles avec
les DataStores et transporte ce snapshot avec les donnees de teleportation.

Le serveur d'arrivee refuse un snapshot absent, invalide ou incoherent avec
l'identite de la session. La run active publie ensuite les attributs
`RunCharacterId`, `RunPrimaryWeaponId`, `RunCharacterSkinId` et
`RunWeaponSkinId` pour les services qui en dependent.

Le loadout initial n'est plus force sur Fireball : il est construit a partir
de l'arme principale du snapshot. Un fallback Fireball existe uniquement si
une definition invalide atteint cette frontiere, avec avertissement explicite.

Le recapitulatif et l'archive de run conservent maintenant le personnage,
l'arme principale et la liste des armes finales. Cela permet aux futures
statistiques et analyses d'attribuer un resultat au build reel joue.

## Isolation des joueurs et autorite

La selection de personnage appartient au profil du joueur qui l'effectue.
Elle ne modifie pas un etat global du lobby et elle est refusee pendant une
run active.

En production, `RunTeleportService.StartSoloRun` transmet une liste contenant
uniquement le joueur demandeur a `TeleportAsync`. Lorsque la configuration le
demande, `TeleportOptions.ShouldReserveServer` reserve le serveur de run. Le
depart d'un joueur n'envoie donc pas les autres joueurs du lobby dans sa run.

La simulation Studio reste differente : elle utilise le Workspace courant
pour emuler le serveur reserve. Cette emulation est utile pour le smoke solo,
mais elle ne prouve pas l'isolation reseau d'un lobby publie multijoueur.

## Verification technique

- `rojo build -o %TEMP%\\MegaRoblox-documentation-catchup-check.rbxlx` : vert ;
- `git diff --check` : vert, hors avertissements de conversion LF/CRLF ;
- presence et dimensions des huit assets locaux : controlees ;
- templates Studio Medivh et Albert : presents avec `Shirt` et `Pants` ;
- identifiants de vetements Medivh et Albert : charges avec succes par Studio ;
- apercu d'edition final : les deux tenues sont visibles.

Ces controles prouvent la coherence des sources et des templates. Ils ne
remplacent pas le smoke produit du cycle complet deja decrit dans
`todo_2026-07-22_022516_smoke_cycle_personnages_jouables_v1.md`.

## Decisions

- `Keep` : catalogue Medivh/Albert, validation R15, passifs declaratifs et
  loadout initial derive du personnage ;
- `Keep` : parcours personnage puis chapitre base sur les composants du kit ;
- `Keep` : snapshot immuable et donnees de run individuelles ;
- `Keep` : tenues UV V1 et restauration de l'avatar du lobby ;
- `Defer` : accessoires 3D, animations propres et skins alternatifs ;
- `Defer` : validation publiee de l'isolation multijoueur.

## Budget de complexite

Cette passe ajoute de la complexite, mais elle la localise dans un service de
personnages et un snapshot de run au lieu de disperser des conditions Medivh
ou Albert dans les armes, la collecte et la teleportation. La complexite est
donc ajoutee au contrat produit mais reduite sur les chemins consommateurs.

Le parcours client reutilise les composants du kit au lieu de maintenir une
deuxieme implementation visuelle codee. La selection demeure serveur-authority
et les passifs restent des donnees interpretees par leur proprietaire.

## Angles morts et restant a faire

- le selecteur de skin de personnage est presente visuellement et la
  persistance contient `CharacterSkinId`, mais aucune route serveur ne permet
  encore de changer ce champ : seul le skin d'arme Fireball est actuellement
  selectionnable ;
- Albert et `leyden_needle` utilisent une voie de deblocage differee : leur
  smoke produit exige un moyen de deblocage ou un outil admin borne ;
- le nom au-dessus du joueur est une identification temporaire, pas le rendu
  final du personnage ;
- aucune animation specifique de Medivh ou Albert n'est consideree valide ;
- le remplacement de vetements est une V1 volontairement sobre, pas un skin
  3D final avec accessoires ;
- l'isolation solo est correcte dans le code de teleportation, mais le smoke
  multijoueur publie reste bloquant pour une preuve produit complete ;
- le rafraichissement des images de vetement dans Studio peut necessiter une
  reassignation apres un import recent, meme lorsque le chargement est annonce
  comme reussi.

## Conclusion

Le chantier a depasse la simple fondation de catalogue : Medivh et Albert ont
des contrats de production, des portraits, des tenues, des passifs, une arme
principale, une selection persistante et un snapshot individuel de run. Le
nouveau parcours de lancement relie le choix du personnage au chapitre sans
donner d'autorite au client.

Le socle technique est coherent et compilable. Le chantier personnage n'est
cependant pas declare totalement clos : le smoke multijoueur publie, la vraie
selection de skin de personnage et la voie de deblocage d'Albert restent des
preuves ou fonctionnalites manquantes explicitement tracees.
