# Pipeline personnages jouables V1 - Contrat de creation, selection et validation

Date : 2026-07-21 21:28 Europe/Paris

## Statut du document

Ce document prepare le chantier des personnages jouables. Il fixe un contrat
produit et technique avant implementation.

- Phase : cadrage avant implementation.
- Gameplay modifie par cette passe : aucun.
- Source des decisions : arbitrages produit conduits le 2026-07-21.
- Contrat associe : `audit_2026-07-19_233034_pipeline_armes_creation_calibration_equilibrage_v1.md`.

L'objectif est de permettre l'ajout de personnages sans dupliquer les
controleurs, modifier les hitbox, contourner les validateurs d'armes ou
introduire des bonus opaques dans les runs.

## Principes verrouilles

### Personnage de lobby et personnage de run

- Le joueur conserve son avatar Roblox personnel dans le lobby.
- Il choisit son personnage au moment d'entrer dans chaque run.
- Ce choix n'est pas une selection persistante de profil.
- Le serveur valide ce choix puis fige un snapshot de personnage pour toute la
  run. Aucun changement de personnage ou de skin n'est possible pendant la
  run.
- Au lancement, le rig R15 canonique recoit l'apparence du personnage choisi.
- A la mort ou au retour lobby, le joueur revient a son avatar Roblox.
- Les hitbox, le HumanoidRootPart, les joints R15 et les regles de collision
  restent identiques pour tous les personnages.

Le modele 3D propre a un personnage est donc une apparence sur le rig R15
canonique, pas un rig de gameplay libre. Cette contrainte protege les
animations generiques, les auras, le controle joueur, les teleportations et
les comportements de combat existants.

### Arme primaire et loadout

- Chaque personnage declare une arme primaire propre.
- L'arme primaire est equipee au niveau 1 au lancement de la run.
- Elle est permanente pendant la run et ne peut pas etre retiree.
- Son ultimate est l'unique ultimate disponible : elle appartient a l'arme
  primaire du personnage.
- L'arme primaire peut aussi etre acquise comme arme secondaire par un autre
  personnage lorsqu'elle est debloquee et compatible.
- Une arme ne peut jamais exister deux fois dans un meme loadout.
- Les armes secondaires, leurs niveaux et leurs bonus restent des donnees de
  run, conformement au contrat armes.

L'ultimate ne voyage jamais avec une arme acquise secondairement. L'arme
secondaire conserve son attaque ordinaire et ses evolutions, sans ajouter une
seconde ultimate.

### Statistiques et passif

- Tous les personnages commencent avec les memes statistiques de base.
- Chaque personnage possede un unique passif permanent, actif pendant toute la
  run et absent des offres de niveau.
- Le passif est declaratif : il reference un `PassiveId` connu avec des
  parametres valides.
- Il peut appliquer plusieurs modificateurs fixes de statistiques ou de
  mecanismes transverses deja contractuels.
- Il ne contient ni script arbitraire, ni timer, ni condition, ni
  declenchement en V1.
- Chaque modificateur declare explicitement sa portee :
  `Player`, `PrimaryWeapon`, `AllWeapons` ou une categorie d'arme.
- Le passif reste dynamique : une arme acquise apres le lancement recoit tout
  modificateur dont elle est compatible.
- L'ultimate est exclue par defaut. Un modificateur de passif ne peut
  l'influencer que si sa compatibilite ultimate est explicitement declaree.

Le passif n'exige pas de VFX propre en V1. Il peut modifier indirectement les
auras existantes par les statistiques qu'il affecte, sans ajouter un systeme
visuel parallele.

### Animations

- Une bibliotheque generique partagee couvre les etats locomotion et vie
  communs.
- Un personnage peut surcharger facultativement une animation precise.
- Toute animation propre doit etre compatible avec le rig R15 canonique.
- Une surcharge n'autorise ni modification de hitbox, ni changement de timing
  de degats, ni logique de gameplay differente.

### Skins

- Un skin est strictement cosmetique.
- Il peut modifier apparence 3D, vetements, accessoires, portrait, VFX et
  audio de presentation.
- Il ne modifie jamais rig, hitbox, arme primaire, ultimate, passif,
  statistiques ou mecanique.
- Un skin est debloque independamment.
- Il ne peut etre selectionne que si son personnage est deja debloque.
- Son identifiant est fige dans le snapshot de run avec le personnage.

## Roster, deblocages et catalogue

### Etats de deblocage

Les personnages et les armes sont deux catalogues persistants et independants.

- Debloquer une arme ne debloque pas son personnage.
- Debloquer un personnage ne debloque pas son arme primaire.
- Une arme debloquee peut etre proposee comme arme secondaire, meme si son
  personnage est encore verrouille.
- Lancer une run avec un personnage exige que le personnage et son arme
  primaire soient tous deux debloques.
- Lorsqu'une condition manque, le personnage reste visible mais non
  selectionnable. L'interface devra afficher la condition exacte, par exemple
  `Arme requise : Boule de feu`.

Cette regle de paire est volontairement exigeante. Elle ne doit pas etre
masquee : son cout UX est acceptable seulement si la raison du verrou est
immediate et actionnable.

### Source de deblocage V1

Chaque personnage, arme ou skin declare une unique source de deblocage :

- gemmes arcaniques ;
- quete ;
- haut fait.

Les voies alternatives et les conditions cumulatives sont reportees. Elles
pourront etre ajoutees lorsqu'un besoin produit les justifiera, sans changer
le modele initial de contenu.

### Progression permanente

Les personnages n'ont ni niveau, ni maitrise, ni bonus permanent en V1.
Leur progression permanente se limite aux deblocages et aux skins. Leur
differenciation de run reste exclusivement leur passif et leur arme primaire.

## Definition de contenu obligatoire

Un personnage ne peut entrer en production que si sa definition declare au
minimum :

- `Id` stable, non derive du nom affiche ;
- cles i18n de nom, description et passif ;
- portrait 2D ;
- apparence R15 par defaut et skin par defaut valide ;
- `PrimaryWeaponId` qui reference une arme valide ;
- `PassiveId` connu et parametres valides ;
- source unique de deblocage ;
- references de presentation necessaires ;
- surcharges d'animation facultatives et valides.

Le validateur doit echouer ferme pour un identifiant, une arme, un passif, une
apparence, une skin ou une source de deblocage inconnus. Il ne doit jamais
remplacer silencieusement le personnage par le Magicien.

## Cycle de vie autoritaire

1. Le client demande le lancement de run et transmet le personnage et le skin
   choisis.
2. Le serveur verifie le roster, la paire personnage-arme primaire, le skin et
   l'etat de lancement.
3. Le serveur cree le snapshot de run immuable.
4. L'apparence R15 est appliquee pour la run.
5. Le loadout recoit l'arme primaire au niveau 1, puis les armes secondaires
   suivent le contrat armes.
6. Le passif declaratif est applique aux statistiques compatibles, y compris
   aux armes acquises apres le lancement.
7. A la fin de run, le snapshot, le loadout et les bonus de run sont detruits ;
   le joueur revient a son avatar Roblox de lobby.

Le client presente le resultat mais ne valide jamais le deblocage, le passif,
l'arme primaire, le skin ou les statistiques effectives.

## Outillage et equilibrage

- Le validateur de personnages doit etre consomme au lancement du serveur et
  par les outils de developpement.
- MetaBuildLab devra choisir un personnage, reconstruire son arme primaire et
  son passif depuis les memes definitions que le serveur.
- Toute nouvelle portee de passif doit etre interpretee dans un point unique ;
  aucune UI, arme ou simulation ne doit recopier ses formules.
- Le contrat armes reste la source des caps d'armes. Un personnage ne peut pas
  contourner les caps de categorie, les caps d'arme ou les securites moteur.
- Les skins ne produisent aucune entree d'equilibrage.

## Smoke manuel canonique avant promotion

1. Lobby : l'avatar Roblox personnel reste visible.
2. Selection : un personnage sans arme primaire debloquee reste visible,
   desactive et explique la condition manquante.
3. Run : une paire valide lance une run avec l'apparence R15 attendue, l'arme
   primaire au niveau 1 et le passif applique.
4. Acquisition : une arme secondaire compatible obtenue plus tard recoit les
   modificateurs de passif declares.
5. Ultimate : seule l'ultimate de l'arme primaire est disponible.
6. Skin : un skin change seulement la presentation ; aucun changement de
   hitbox, stats, passif, arme ou ultimate.
7. Fin de run : retour a l'avatar Roblox, destruction du snapshot et absence
   de fuite du passif ou du loadout dans la run suivante.

## Classification et angles morts

### Juste

Le rig R15 canonique, le passif declaratif et le snapshot serveur reduisent
fortement les risques de divergence entre personnages. Ils sont compatibles
avec les services actuels de joueur, auras, armes et teleports.

### Contestable

Le verrou de paire personnage-arme enrichit la progression mais ajoute de la
friction. Il devra etre observe en usage reel : si les joueurs accumulent des
personnages non jouables, le probleme sera de design de progression, pas un
probleme d'interface a masquer.

### Simplification

V1 ne cree ni mastery, ni scripts de passif, ni rig par personnage, ni skins
gameplay, ni multiple ultimate. Ces absences sont volontaires et protegent le
chemin de run simple.

### Angle mort

Le projet ne possede pas encore de pipeline d'application d'apparence de run,
de registre de passifs, de validateur de personnages ou de selection lobby.
Ce document decrit le contrat cible, pas une implementation existante.

### Budget de complexite

Le futur chantier ajoute des definitions de contenu, un validateur, un snapshot
de run et une application d'apparence. Il evite volontairement un controleur
par personnage, des branches de combat par hero et toute logique de passif
arbitraire. La complexite ajoutee est donc centralisee et testable.

## Decision

Contrat V1 accepte pour implementation ulterieure. Aucun chantier
d'implementation ne doit demarrer sans audit de l'impact sur le cycle de vie
de run, le loadout existant actuellement initialise avec Fireball et le
controleur de personnage.
