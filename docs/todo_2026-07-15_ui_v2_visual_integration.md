# Todo - UI V2, validation et integration visuelle

## 2026-07-15 08:10:00 +02:00 - Changement de priorite vers le feedback de collecte

La V2 a ete construite de maniere isolee dans `StarterGui/MegaRobloxUIV2` avec
le pack visuel importe. Elle reste volontairement desactivee : elle ne doit pas
remplacer le HUD courant avant un smoke visuel explicite du joueur.

Restant a faire avant toute bascule :

1. Activer la V2 dans Studio et verifier le rendu reel en 16:9, petite fenetre
   et mobile, sans chevauchement ni elements trop petits.
2. Comparer directement le board a la reference fournie, pas seulement a la
   version codee precedente. Les assets du pack doivent rester le langage
   visuel principal.
3. Decider si `StarterGui/MegaRobloxUIV2` reste une interface Studio-owned ou
   si une representation Rojo/packagee devient necessaire pour la versionner.
4. Brancher les donnees runtime seulement apres cette validation visuelle :
   profil, compteur, slots, choix de perk, inventaire, quetes et recapitulatif.
5. Conserver les drafts archives jusqu'a ce que la V2 soit validee; ils ne
   doivent pas etre supprimes comme simple nettoyage avant la preuve produit.

### Angle mort

La V2 actuelle est une base de composition visuelle, non une interface de jeu
validee. L'ajout de nouvelles features ne doit pas etre confondu avec une
validation de son ergonomie ou de sa fidelite au kit de reference.
