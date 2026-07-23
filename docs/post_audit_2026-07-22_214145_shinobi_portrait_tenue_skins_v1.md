# Post-audit - Shinobi : portrait, tenue UV et skins V1

Date : 2026-07-22 21:41:45

## Etat initial

Le catalogue personnage disposait de Shinobi et de son arme primaire Shuriken,
mais son portrait restait provisoire, son apparence de run n'etait pas definie
par un skin selectionnable et l'infrastructure de skins d'arme ne couvrait que
Fireball.

Le contrat personnage V1 impose que le lobby conserve l'avatar Roblox du
joueur, puis que la run applique une apparence propre a son personnage a partir
d'un snapshot individuel et immuable.

## Modification appliquee

### Assets

Les assets locaux suivants sont maintenant versionnes dans le projet :

- `assets/ui/character/shinobi_portrait_v1.png` ;
- `assets/character/shinobi/clothing/shinobi_shirt_v1.png` ;
- `assets/character/shinobi/clothing/shinobi_pants_v1.png` ;
- `assets/ui/weapon/shuriken_shadowspin_v1.png` ;
- `assets/ui/weapon/shuriken_moonveil_v1.png`.

Les identifiants Roblox retenus sont :

- portrait Shinobi : `rbxassetid://104698571348162` ;
- chemise Shinobi : `rbxassetid://81502804062973` ;
- pantalon Shinobi : `rbxassetid://127826973384729` ;
- Shuriken Shadowspin : `rbxassetid://82295159291408` ;
- Shuriken Moonveil : `rbxassetid://137477216660458`.

### Contrats et services

`CharacterSkinConfig` devient le catalogue declaratif des skins de personnage.
Il contient un skin de base reel pour Medivh, Albert et Shinobi. Aucun faux
skin alternatif de personnage n'est expose : Shinobi possede actuellement son
skin `shinobi_shadow` unique, car une seule tenue UV a ete produite.

`CharacterSkinService` fournit la selection serveur-authoritative du skin de
personnage et la persiste dans le couple cosmetique du profil. Au lancement,
`CharacterService` applique les vetements definis par le skin capture dans le
snapshot de run, avec repli sur l'apparence de base du personnage.

`WeaponSkinService` est devenu generique par `WeaponId`, tout en gardant le
point d'entree historique Fireball pour ne pas casser son comportement. Le
catalogue Shuriken expose les deux skins starter Shadowspin et Moonveil. Le
choix est persistant, borne au personnage et a son arme primaire, et demeure
strictement visuel.

`ShurikenWeaponService` transmet le skin selectionne au controleur VFX client.
Ce dernier adapte uniquement sa palette : Shadowspin conserve le noir/violet,
Moonveil utilise argent/cyan. Les dommages, le cone, les caps et les collisions
ne changent pas.

`RunLauncher.client.luau` alimente maintenant les slots du selectionneur a
partir des catalogues reels, rend les emplacements absents inactifs et remet a
jour l'interface apres toute selection serveur. Cela evite les slots de skin
decoratifs sans contenu valide.

## Verification

- `rojo build default.project.json` : succes ;
- `git diff --check` : aucun probleme de whitespace, hors avertissements
  existants LF/CRLF ;
- le serveur Rojo actif pointe bien sur
  `Z:\Projet de develloppement\TestRoblox\default.project.json` ;
- Studio contient les nouveaux modules et services dans les racines Rojo ;
- les sources Studio contiennent les trois identifiants Shinobi importes ;
- smoke manuel valide par le responsable produit : selection, lancement et
  affichage V1 sont juges viables, jouables et testables.

## Decision

`Keep` pour le pipeline V1 : portrait, tenue UV, skin personnage persistant et
skins Shuriken persistants.

## Budget de complexite

La passe ajoute deux petits catalogues declaratifs et un service dedie plutot
que d'ajouter des exceptions Shinobi dans le launcher ou les armes. La
complexite est concentree dans les contrats cosmetiques et reste reversible :
un futur skin est une entree de configuration et un asset, sans mutation du
combat.

## Angles morts et dette explicite

- Les UV de la tenue Shinobi presentent des ecarts visuels. Ils sont acceptes
  pour une V1 jouable, mais pas comme rendu final ; une passe de retouche UV est
  necessaire avant une validation artistique definitive.
- Aucun skin alternatif de personnage n'est encore produit. Le selecteur le
  supporte, mais Shinobi n'affiche volontairement qu'un skin reel.
- Les accessoires 3D, animations propres aux personnages et variations de
  visage restent hors scope.
- Le smoke multijoueur publie du cycle lobby/run reste une preuve distincte du
  smoke local valide ici.

## Conclusion

Le personnage Shinobi dispose maintenant d'une identite visuelle V1 coherente
dans le cycle reel : portrait, tenue R15 de run, selection persistante et
skins Shuriken. Le systeme ne change pas le gameplay de l'arme et ne touche
pas aux autres joueurs du lobby. La dette restante est artistique et localisee
aux UV, pas une ambiguite du pipeline produit.
