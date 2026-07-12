# Commerce Robux V1

## 2026-07-12 12:25 CEST - Produit achetable de reroll de perk

### Objectif tenu

- ✓ Les rerolls de perks utilisent maintenant le flux officiel Roblox des Developer Products : le client demande un achat, le serveur valide l'offre puis le client ouvre le prompt Roblox.
- ✓ L'avantage est attribue uniquement par `MarketplaceService.ProcessReceipt` sur le serveur. Le client ne peut ni ajouter ni consommer un credit sans validation serveur.
- ✓ Les credits de reroll sont persistants par joueur dans `MegaRobloxCommerce_v1`, hors statistiques de run. Un reroll consomme un credit uniquement lorsqu'un choix de perk actif est remplace.
- ✓ Le traitement d'un receipt est idempotent : le meme `PurchaseId` n'ajoute pas plusieurs fois les credits.

### Fichiers concernes

- `src/shared/CommerceConfig.luau` : identifiants des offres, activations et quantites accordees.
- `src/server/CommerceService.luau` : stockage, `ProcessReceipt`, verification du pass et remotes de commerce.
- `src/server/GameManager.server.luau` : cycle de vie du service Commerce.
- `src/server/PerkService.luau` : consomme un credit serveur et regenere le choix actif.
- `src/client/PerkUI.client.luau` : bouton `RELANCER (n)` durant un choix de perk.
- `src/client/LobbyPanels.client.luau` : cartes Boutique et prompt Roblox cote client.

### Configuration Creator Hub requise

L'experience doit etre publiee et accessible avant de creer les offres.

1. Dans Creator Hub, ouvrir l'experience puis `Monetization > Developer Products`.
2. Creer `Reroll perk x1` au prix de `50 Robux`.
3. Creer `Reroll perk x3` au prix de `125 Robux`.
4. Copier les deux identifiants dans `src/shared/CommerceConfig.luau` :

```luau
PerkRerollOne.ProductId = 123456789
PerkRerollThree.ProductId = 987654321
```

5. Laisser `Enabled = true` pour ces deux offres, puis relancer le Play Test ou laisser Rojo synchroniser le script avant de le relancer.

Le prix affiche dans la boutique est volontairement une valeur de presentation. ✓ Le prix reel est celui configure dans Creator Hub ; il doit donc rester aligne manuellement avec les libelles `50 ROBUX` et `125 ROBUX`.

### Test manuel canonique

1. Lancer l'experience dans Studio, ouvrir `Boutique > Boutique` et verifier que les deux cartes de reroll perk affichent `ACHETER` une fois les `ProductId` renseignes.
2. Acheter `Reroll perk x1` dans le prompt Studio, puis verifier le log `Developer Product accorde` et l'attribut joueur `PerkRerollCredits = 1`.
3. Declencher un level-up ou un autel de perk : le bouton affiche `RELANCER (1)`.
4. Cliquer le bouton : les trois offres changent, le jeu reste en pause, puis le bouton affiche `RELANCER (0)`.
5. Acheter `Reroll perk x3`, verifier trois relances consecutives, puis quitter et rejoindre a nouveau pour verifier la persistance en environnement publie.
6. Verifier qu'un achat sans choix de perk actif ne peut pas retirer de credit.

### Etat des autres offres

- ⚡ `Reroll item x1/x3` reste desactive. Le jeu ne possede pas encore de systeme de choix d'objets rerollable ; vendre cette offre maintenant attribuerait un credit inutilisable.
- ⚡ `Pack Fondateur` reste desactive. Le badge, la couleur de pseudo, l'aura et le titre de profil ne sont pas encore appliques par un service de profil. Le futur produit devra etre un Game Pass et activer ces avantages de maniere serveur.
- ◐ Studio peut simuler un achat de Developer Product, mais la persistance depend de l'acces API Studio. Si elle est indisponible, `CommerceService` utilise un profil de test en memoire afin de tester le receipt et le reroll sans faux avantage durable.

### Contraintes a conserver

- `MarketplaceService.ProcessReceipt` ne doit etre defini qu'une seule fois dans l'experience. Tout futur Developer Product doit etre ajoute dans `CommerceConfig` et traite par `CommerceService`, jamais par un second callback.
- Ne jamais attribuer un achat depuis `PromptProductPurchaseFinished` ou depuis un RemoteEvent client.
- Si le DataStore echoue en production, le receipt retourne `NotProcessedYet` : Roblox le rejouera plus tard au lieu de perdre l'achat.

### Angles morts restants

- ◐ Il manque encore un retour visuel explicite dans la boutique pour un prompt annule ou indisponible. Le credit reste toutefois fiable car seul le receipt serveur le decide.
- ◐ Aucun test d'achat reel ne peut etre valide depuis ce chantier local : il doit etre realise sur l'experience publiee avec les produits Creator Hub exacts.

## 2026-07-12 12:28 CEST - Correctif ProcessReceipt Studio

- ✓ Le demarrage ne lit plus `MarketplaceService.ProcessReceipt`. Cette propriete Roblox est un callback inscriptible mais non lisible, ce qui provoquait l'erreur de lancement.
- ⚡ Roblox ne fournit pas de moyen pour verifier si une autre partie de l'experience a deja affecte ce callback. La regle a respecter reste donc : `CommerceService` est l'unique proprietaire de `ProcessReceipt` dans ce projet.

## 2026-07-12 12:34 CEST - Correctif de disponibilite du menu slide

- ✓ `LobbyPanels` ne bloque plus sa creation en attendant les remotes Commerce. Les panneaux et le lien avec `LobbyShortcutMenu` sont initialises immediatement.
- ✓ Les remotes d'achat sont maintenant recherches en arriere-plan. Une indisponibilite temporaire du serveur Commerce ne peut donc plus rendre le slide menu inutilisable.

## 2026-07-12 12:38 CEST - Isolation du client Commerce

- ✓ La presentation et les interactions de navigation sont a nouveau entierement contenues dans `LobbyPanels` et `LobbyShortcutMenu`.
- ✓ `CommerceClient` ajoute les boutons d'achat et gere les prompts Roblox apres la creation du menu. Une erreur Commerce est ainsi isolee et ne peut plus interrompre le menu slide.
- ◐ Le smoke manuel restant est : entrer dans le lobby, ouvrir `Boutique`, fermer, puis ouvrir `Quetes`. Ce test doit etre confirme dans Studio car Rojo valide la structure mais n'execute pas les LocalScripts.

## 2026-07-12 12:45 CEST - Activation des produits de reroll perk

- ✓ `PerkRerollOne` utilise le Developer Product `3609427860` et accorde un credit.
- ✓ `PerkRerollThree` utilise le Developer Product `3609427919` et accorde trois credits.
- ✓ Les deux produits sont inclus dans le build Rojo. Le smoke Studio est : ouvrir Boutique, acheter un reroll simule, declencher un choix de perk, puis verifier que `RELANCER (1)` ou `RELANCER (3)` apparait.

## 2026-07-12 12:54 CEST - Fiabilisation des cartes d'achat

- ✓ Chaque carte est desormais liee une seule fois par l'attribut `CommerceBound`. Le prix est reconstruit depuis `CommerceBaseValue`, ce qui empeche les libelles du type `ACHETER - ACHETER`.
- ✓ Un clic effectue avant la replication de `Commerce_RequestPurchase` est mis en attente, puis envoye une fois le RemoteEvent disponible. La validation de l'offre reste exclusivement serveur.
- ⚡ Les cartes de reroll d'objet suivent deja la meme architecture d'achat et de stockage de credits. Elles restent desactivees : les recompenses de coffre sont encore des placeholders et aucun service ne consomme `ItemRerollCredits`. Les activer avant ce gameplay vendrait un produit sans effet.

## 2026-07-12 12:59 CEST - Enregistrement des produits de reroll d'objet

- ✓ `ItemRerollOne` reference le Developer Product `3609429613`.
- ✓ `ItemRerollThree` reference le Developer Product `3609429674`.
- ✓ Les deux offres restent a `Enabled = false` jusqu'a l'implementation de la consommation serveur pendant un choix d'objet. Elles ne peuvent donc pas etre achetees par erreur.
