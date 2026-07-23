# Post-audit - Rufus et la Lame de Valorcrest : production V1

Date : 2026-07-23 05:46:44

## Etat initial

Le roster de production contenait Medivh, Albert, Shinobi et Ru's al Gale,
mais aucun personnage de melee. Les armes existantes reposaient sur des
projectiles, une zone ou une invocation. Reutiliser un de ces chemins pour une
epee aurait rendu le contrat de combat ambigu : une melee n'a ni projectile,
ni rebond, et ne doit pas dependre de leurs statistiques.

Le contrat personnage impose egalement que le personnage reste selectionnable
depuis le launcher, que son apparence de run soit issue d'un skin persistant et
que son passif soit applique uniquement pendant la run active.

## Modification appliquee

### Personnage et assets

- ajout de `rufus` au catalogue de personnages, disponible par defaut durant
  la phase de test ;
- ajout du skin de base `rufus_valorcrest` et de la Lame de Valorcrest ;
- ajout du portrait, des UV vetement et de l'icone d'arme detoures depuis des
  sources chroma conservees localement ;
- import direct des assets dans Roblox :
  - portrait : `rbxassetid://117769701520930` ;
  - chemise : `rbxassetid://128402560504693` ;
  - pantalon : `rbxassetid://112987301949770` ;
  - icone de lame : `rbxassetid://116223287361677` ;
- creation du template `ServerStorage.CharacterTemplates.Rufus` et de la carte
  `rufus` dans le draft Studio du launcher de run.

Rufus commence chaque run avec `+50` PV maximum et `50` points de bouclier
charges. Le reset de run derive maintenant ces deux valeurs depuis le passif
du personnage selectionne, puis initialise le bouclier courant une seule fois.

### Arme melee isolee

La `valorcrest_blade` est une arme de categorie `Melee` :

- portee de base `12`, angle de frappe frontal `115` degres ;
- degats de base `42`, cooldown de base `1.15` seconde ;
- progression actuelle limitee aux degats, sans plafond de niveau ;
- compteur de projectile, rebonds et duree d'effet explicitement ignores ;
- contrat `UsesSize = true` declare pour une future statistique Taille, sans
  simuler une amelioration qui n'existe pas encore.

`MeleeWeaponService` constitue un chemin serveur dedie. Il cible les monstres
dans l'arc court devant le joueur, applique les degats par `WeaponHitService`
et n'accepte aucun hit du client. `MeleeWeaponVfxController` ne recoit que les
resultats serveur et affiche localement l'arc bleu, ivoire et or a partir des
elements du pack VFX Studio `Anime`.

## Verification

- `rojo build default.project.json` : succes ;
- `git diff --check` : succes, hors avertissements LF/CRLF preexistants ;
- validateurs Studio `CharacterDefinitionValidator` et
  `WeaponDefinitionValidator` : aucune erreur pour Rufus et sa lame ;
- Studio : template R15, carte de selection et les trois couches VFX
  `Sweep`, `Edge` et `Impact` sont presentes ;
- smoke manuel canonique valide par le responsable produit : selection de
  Rufus, lancement de run, valeurs initiales de PV/bouclier et melee courte
  sont juges corrects.

## Decision

`Keep` : Rufus devient le premier personnage melee de production V1. Son arme
est isolee des routes projectile existantes et le passif est borne au cycle de
vie de sa run.

## Budget de complexite

Complexite ajoutee : un service melee et un controleur VFX client dedies.
Cette complexite est justifiee par une categorie de combat distincte et evite
de surcharger `WeaponService` avec des exceptions projectile. Aucun chemin
projectile, zone, invocation ou Shuriken n'est modifie fonctionnellement.

## Angles morts et dette explicite

- La stat Taille n'existe pas encore : elle n'augmente donc pas la portee de
  Rufus dans cette V1, malgre le contrat deja pose.
- La lame est representee par son icone HUD et son VFX de frappe. Une epee 3D
  attachee au personnage est une passe artistique distincte, non necessaire au
  comportement melee valide ici.
- La tenue UV est une V1 fonctionnelle ; la fidelite PBR, les ecarts de
  gabarit et les accessoires 3D devront etre recalibres dans une passe
  artistique dediee.
- Les runs restent solo. La replication de la presentation melee pour des
  observateurs n'est donc pas couverte par ce smoke.

## Conclusion

Le roster dispose maintenant d'une premiere melee courte, serveur-authoritative
et visuellement distincte. Le cas simple de Rufus est valide sans modifier les
regles deja maitrisees des armes a projectile, de zone ou d'invocation.
