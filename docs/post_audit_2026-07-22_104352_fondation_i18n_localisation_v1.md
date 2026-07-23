# Fondation i18n et localisation V1

Date : 2026-07-22 10:43:52

## Etat initial

Le projet affichait ses textes joueurs directement depuis les adaptateurs UI et les
configurations partagees. Il n'existait ni cle de traduction stable, ni table de
localisation, ni convention pour les futurs contenus configures.

Les ecrans les plus recents etaient particulierement exposes : lancement de run,
selection de chapitre et choix/evolution d'arme. Leur contenu produit venait deja
de definitions identifiees (`medivh`, `fireball`, `leyden_needle`, chapitres), ce
qui permet une migration progressive sans modifier les regles de jeu.

## Decision retenue

Une fondation hybride est introduite :

- francais comme langue source produit ;
- anglais explicite livre pour le premier flux migre ;
- `LocalizationTable` locale creee au client pour exploiter le mecanisme Roblox ;
- cle stable dans les configurations et payloads, avec texte historique conserve
  comme fallback de compatibilite ;
- migration progressive par composant, plutot qu'une reecriture massive du HUD.

Cette direction respecte le principe de sobriete : le serveur continue de fournir
les donnees de gameplay brutes et n'a aucune responsabilite de rendu localise.
Les degats, recompenses, choix et verifications restent strictement autoritaires.

## Implementation

Ajouts :

- `src/shared/I18n.luau` : referentiel de cles, valeurs francaises et anglaises,
  normalisation de locale et interpolation `{parametre}` ;
- `src/client/I18nClient.luau` : creation unique de la `LocalizationTable`, choix
  de la locale joueur et fallback robuste ;
- `src/client/I18nBootstrap.client.luau` : initialisation avant les adaptateurs UI.

Premiers contenus migres :

- actions communes, raretes, statuts de chapitre et lancement de run ;
- selection de personnage, chapitre et map dans `RunLauncher` ;
- choix/evolution d'arme, compteurs de credits et effets dans
  `WeaponChoiceV2Adapter` ;
- definitions Medivh, Albert, Fireball, Aiguille de Leyde et chapitres enrichies
  de `NameKey`, `DescriptionKey`, `DisplayNameKey` ou `LabelKey` selon leur role ;
- les services serveur transmettent ces cles en supplement de leurs champs texte
  existants, sans rupture de contrat pour les consommateurs non migres.

## Validation technique

- `rojo build default.project.json --output build-i18n-test.rbxlx` : succes ;
- `git diff --check` : aucune erreur de whitespace ;
- execution Studio en mode edition de `I18n.Format` :
  - FR : `EVOLUTION  NIV. 2 > 3` ;
  - EN : `EVOLUTION  LVL 2 > 3` ;
  - Fireball EN : `Fireball` ;
  - cle inconnue : fallback explicite vers la cle, jamais un silence ;
- un doublon strictement identique de `ReplicatedStorage.Shared.I18n`, cree lors
  de la synchronisation, a ete retire dans Studio. Une seule instance demeure.

## Proof of done V1

La base est consideree en place lorsque :

- un texte dynamique peut etre adresse par une cle stable ;
- la locale joueur peut choisir FR ou EN sans modifier le gameplay ;
- une cle ou une traduction indisponible laisse un fallback lisible ;
- les nouveaux contenus armes/personnages/chapitres peuvent declarer leurs cles
  au moment de leur creation ;
- le flux lancement de run et progression d'arme reste fonctionnel dans son
  comportement initial.

## Angles morts et suite

- Cette passe ne pretend pas avoir localise tout le HUD historique, les quetes,
  les prompts, les notifications, les objets et les perks. Ils sont encore en
  francais et doivent etre migres composant par composant.
- L'anglais est editorialement defini. Les autres langues doivent etre valides
  dans le tableau de localisation de l'experience publiee avant de leur confier
  une traduction automatique Roblox ; une traduction automatique ne remplace pas
  une relecture de noms, ton de jeu, raretes ou phrases a variables.
- Un smoke manuel reste requis : forcer `LocalPlayer.I18nLocaleOverride` a
  `"en-us"`, ouvrir le lanceur, puis obtenir une proposition d'arme. Les textes
  doivent etre anglais, les choix et credits identiques, et aucun message ne doit
  afficher une cle brute.

Prochaine passe recommandee : migrer `PerkChoiceV2Adapter` et
`ItemRevealV2Adapter`, puis les messages de quetes et prompts. Chaque passe devra
etre validee independamment afin de ne pas melanger localisation et refonte UI.

## Correctif 2026-07-22 18:15

Un test runtime a revele une erreur de `Translator` sur les entrees comportant
des jetons de parametres, notamment les compteurs de credits :
`Found parameter token, but had no parameters`.

La cause etait localisee dans `I18nClient` : le chemin Roblox appelait
`FormatByKey` sans lui transmettre le dictionnaire de parametres, alors que le
fallback local les recevait correctement. Le client transmet maintenant
`parameters or {}` a `FormatByKey`.

Cette correction conserve les deux niveaux de secours existants et ne modifie
ni les cles, ni les valeurs de credits, ni les choix de gameplay. Le smoke
manuel a refaire couvre une offre d'arme avec les boutons `PASSER` et `BANNIR`
afin de verifier que leurs compteurs s'affichent sans erreur.
