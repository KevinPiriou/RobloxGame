# Post-audit - Resultat de run et meta-progression V1

## 2026-07-13 01:41:10 +02:00 - Application du chantier

### Intention

Le projet avait deja trois verites distinctes a conserver : les gemmes arcaniques permanentes, la progression de chapitres et l'historique de sessions de run. En revanche, la fin de run ne conservait qu'un petit resume d'interface, puis reinitialisait XP, or, perks et monstres. Les quetes, hauts faits et statistiques cumulees du lobby restaient donc a l'etat de placeholders.

La V1 introduit une frontiere explicite :

1. `RunAnalyticsService` agrege uniquement les evenements de la run active.
2. `RunEndService` produit un `RunResult` immuable avant tout nettoyage runtime.
3. `MetaProgressionService` applique le resultat une seule fois au profil persistant avec `RunId`.
4. `RunSessionService` conserve le resultat agrege dans les 20 dernieres sessions afin de pouvoir reessayer une attribution qui aurait echoue.
5. L'ecran de fin et les panneaux lobby lisent le resultat serveur, sans recalcul client.

### Contrat de donnees retenu

Le `RunResult` V1 persiste un contexte reproductible minimal : `RunId`, chapitre, map, seed et cycle de vie. Il contient ensuite des deltas agreges et non des traces de simulation :

- progression de run : niveau final, XP, or gagne/depense/restant, perks choisis et difficulte maximale ;
- combat : kills, elites, boss, degats infliges/recus, bouclier absorbe, soins, repartitions par ennemi et arme ;
- interactions : coffres normaux ou reward, jarres, shrines par type, totems, portail ;
- build final reel : Fireball et stacks/valeurs de perks presentes dans `PerkService` ;
- resultat de progression : quetes terminees, hauts faits, records et chapitre nouvellement debloque.

Les positions, projectiles, raycasts, animations, collectibles individuels et donnees HUD ne sont pas enregistres. Ils ne constituent pas un resultat de joueur durable et alourdiraient le DataStore sans servir les ecrans actuels.

### Sources de verite et responsabilites

- `RunAnalyticsService` n'accorde rien ; il enregistre les faits serveur.
- `MetaProgressionService` est la seule couche qui incremente les statistiques cumulees, quetes et hauts faits.
- `ChapterProgressService` reste proprietaire des chapitres debloques. La meta-progression ne duplique pas ce store ; elle expose seulement le nouveau chapitre dans le resultat de run.
- `ArcaneGemService` reste proprietaire des gemmes arcaniques. Aucune gemme n'est attribuee par cette V1, car aucune regle d'economie de run n'est encore definie.
- `RunSessionService` conserve un historique borne a 20 resultats agreges et sert de filet de reprise apres une erreur temporaire de `MetaProgressionService`.

### Regles de progression actuelles

Les regles sont dans `MetaProgressionConfig.luau` afin d'etre ajustables sans reouvrir les services :

- quetes permanentes : premiere run, 100 kills cumules, 50 or cumule ;
- quetes quotidiennes UTC : terminer une run, survivre 180 secondes, collecter 250 or ;
- hauts faits : premiere run, 100 kills dans une seule run, 10 coffres cumules, premiere validation de chapitre ;
- records : meilleur niveau, meilleur nombre de kills sur une run, plus longue duree active.

Ces valeurs sont les seules qui correspondent aux placeholders deja visibles dans le lobby. Elles n'accordent pas encore de monnaie ou de contenu futur.

### Idempotence et reprise

Chaque profil meta garde les 40 derniers `ProcessedRunIds`. Une nouvelle application avec le meme `RunId` devient un no-op. L'attribution utilise `UpdateAsync`, donc le test et l'ecriture du recu se produisent dans la meme operation DataStore.

Si le DataStore meta echoue a la fin de run, le resultat complet est tout de meme sauvegarde dans l'historique de session. Au prochain chargement du joueur, `MetaProgressionService.ReconcileRunHistory` rejoue les resultats non traites. Ce mecanisme ne multiplie pas les gains grace a `ProcessedRunIds`.

### Interface raccordee

- `RunSummaryUI` affiche maintenant les kills elites/boss, coffres, jarres et une section de progression debloquee.
- `MetaProgressionUI` hydrate les valeurs deja affichees par les onglets Quetes, Hauts faits et Statistiques du lobby.
- Une commande admin pendant une run la marque comme debug : le recap l'indique et aucune statistique, quete ou haut fait permanent n'est attribue. Cela evite que les boutons de test polluent les records reellement joues.

### Verification statique effectuee

- `rojo build -o TestRoblox.rbxlx` : succes.
- `git diff --check` : pas d'erreur d'espacement ; avertissements CRLF preexistants de Git uniquement.
- recherche des marqueurs de conflit Git dans `src` et `docs` : aucun marqueur trouve.

### Smoke manuel canonique a effectuer dans Studio

1. Lancer une run sans admin, tuer au moins un monstre, prendre XP/or, ouvrir un coffre et casser une jarre, puis mourir : le recap doit montrer les valeurs et le lobby doit les cumuler apres retour.
2. Relancer une run avec le bouton admin : le recap doit annoncer que la progression est ignoree et les compteurs du lobby ne doivent pas augmenter.
3. Vaincre le boss du chapitre 1 et quitter : le recap doit montrer la validation, et le chapitre 2 doit etre debloque sans doubler le total des chapitres lors d'une reconnexion.
4. Avec l'API Studio activee, interrompre volontairement la sauvegarde meta puis rejoindre a nouveau : l'historique de run doit etre reconcilie une seule fois.

### Classification et angles morts

- ✓ Juste : la capture est serveur, la synthese intervient avant nettoyage, et le `RunId` protege l'attribution contre le double traitement.
- ✓ Juste : les valeurs de l'ecran de fin viennent de faits serveur agreges, pas d'un recalcul client apres destruction de la run.
- ⚡ Simplification : il n'existe pas encore de profil unique monolithique. Les chapitres, gemmes arcaniques et meta-statistiques gardent leurs stores existants, ce qui evite une migration risquee pendant ce chantier.
- ◐ Angle mort : une deconnexion pendant une run ferme actuellement la session comme abandonnee mais ne produit pas encore de `RunResult` meta complet. La persistence post-fin normale est robuste ; ce cas devra etre traite dans une passe specifique de reprise de run/disconnexion.
- ◐ Angle mort : les quetes et hauts faits V1 n'accordent aucune recompense, car aucune table de recompenses permanente n'a ete validee. Ajouter une monnaie ou un unlock fictif ici serait incoherent avec l'economie actuelle.
- ◐ Angle mort bloquant avant extension : le smoke Play des spawns elite et boss recemment corriges doit encore etre rejoue. Ce chantier de donnees ne doit pas etre interprete comme validation de cette boucle combat.

## 2026-07-13 02:02:50 +02:00 - Quetes et hauts faits V1 cibles

### Definitions remplacees

Les definitions precedentes de quetes et hauts faits etaient de simples exemples de V1. Elles sont remplacees par les objectifs reellement demandes :

- quetes normales : terminer une run, vaincre le gardien du chapitre 1, activer 10 autels de perk ;
- quetes quotidiennes UTC : vaincre 100, 250 et 500 ennemis ;
- hauts faits : `FONDATEUR` apres possession du Game Pass Fondateur, puis `ON DEBUTE TOUS UN JOUR ..` des le lancement d'une premiere run.

### Compteurs ajoutes

Le profil meta version 2 ajoute des compteurs sans retroactivite artificielle :

- `RunsStarted`, protege par une liste bornee de `StartedRunIds` ;
- `Chapter1BossVictories`, incremente seulement lorsqu'une run du chapitre 1 valide effectivement le niveau ;
- `TotalPerkShrinesActivated`, incremente seulement a la fin d'une activation complete de shrine de type `Perk` ;
- `Daily.Kills`, reinitialise a la date UTC et incremente avec les kills d'une run eligible.

La quete `FAIRE UNE RUN` est validee a la cloture de la run, puisqu'elle correspond a une run effectivement jouee. Le haut fait de debut est, lui, applique au lancement : une mort ou une sortie ulterieure ne peut pas retirer ce premier pas.

### Fondateur et securite commerce

Le titre Fondateur ne depend ni d'un RemoteEvent client ni d'un bouton UI. `CommerceService` valide deja le Game Pass avec `MarketplaceService:UserOwnsGamePassAsync`, puis publie l'attribut serveur `HasFounderPass`. `MetaProgressionService` observe cet attribut et persiste le haut fait.

`CommerceConfig.Offers.FounderPass.ProductId` vaut encore `0` et son offre est desactivee. Le titre restera donc volontairement verrouille jusqu'au renseignement du vrai identifiant Game Pass et l'activation de cette offre. Aucun faux achat Studio n'est introduit.

### Verification statique effectuee

- `rojo build -o TestRoblox.rbxlx` : succes apres evolution du schema.
- `git diff --check` : pas d'erreur ; avertissements CRLF Git uniquement.

### Smoke manuel additionnel

1. Lancer puis terminer une premiere run sans admin : `ON DEBUTE TOUS UN JOUR ..` et `FAIRE UNE RUN` doivent etre termines.
2. Vaincre le boss de la map du chapitre 1 puis quitter : `GARDIEN DU CHAPITRE 1` doit passer a `TERMINE`.
3. Activer dix PerkShrines reelles : `AUTELS DE PERK` doit progresser exactement d'une unite par shrine terminee.
4. Tuer 100 ennemis durant la journee UTC : les trois quetes quotidiennes doivent afficher respectivement `TERMINE`, `100 / 250` et `100 / 500`.
5. Configurer le vrai Game Pass Fondateur, acheter le pass, puis rouvrir le refuge : `FONDATEUR` doit etre marque `TERMINE` apres verification serveur.

### Classification et angles morts

- ✓ Juste : les kills journaliers ne sont comptes qu'a la fin d'une run eligible, donc les commandes admin ne gonflent pas les quetes quotidiennes.
- ✓ Juste : la possession Fondateur est verifiee par le serveur via MarketplaceService ; le client ne decide jamais le haut fait.
- ⚡ Simplification : les quetes n'ont pas encore de recompense. Elles sont des objectifs persistants et affichables, sans introduire une economie fictive.
- ◐ Angle mort : les compteurs existants avant cette migration ne sont pas reconstruits retrospectivement. Une ancienne victoire de boss ou activation de shrine ne peut pas etre inferee sans historique d'evenements fiable.
