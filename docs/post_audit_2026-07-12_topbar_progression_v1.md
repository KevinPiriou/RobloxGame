# Top Bar Et Progression Arcane

## 2026-07-12 19:07 CEST - Top barre et gemmes arcaniques V1

### Correctif applique

- La top barre de run affiche desormais, de gauche a droite : le solde permanent de gemmes arcaniques, les kills, les coins de run, le cout du prochain coffre, le chrono et le bouton pause/reprise.
- Le cout du prochain coffre est alimente par le RemoteEvent serveur `Chest_PriceUpdate`. Les coins de run et le cout du coffre restent donc deux valeurs distinctes.
- Les icones de gemme arcanique, coffre, chrono, pause et reprise utilisent les assets Roblox fournis et conservent leurs couleurs originales.
- La top barre reste visible uniquement pendant une run et son echelle est limitee par la largeur reelle du viewport afin de ne pas depasser sur mobile.

### Contrat de progression

- `ArcaneGemService` est l'unique autorite serveur du solde `ArcaneGems`.
- Le solde est stocke dans le DataStore `MegaRobloxProgression_v1` et replique au client par l'attribut joueur `ArcaneGems`.
- Les clients ne disposent d'aucun RemoteEvent pour modifier cette monnaie. Les futurs gains de run devront appeler `ArcaneGemService.AwardArcaneGems(player, amount, source)` cote serveur.
- Aucun gain n'est attribue dans cette V1 : le solde commence donc a `0` tant que la regle de recompense de fin de run n'est pas definie.

### Smoke manuel canonique

1. Lancer une run et verifier les six elements de la top barre : gemme, kills, coins, cout coffre, chrono, pause.
2. Ramasser des coins puis verifier que seul le bloc coin de run change.
3. Ouvrir un coffre normal puis verifier que le bloc avec coin et coffre affiche le nouveau cout du prochain coffre.
4. Mettre la run en pause puis verifier que l'icone devient lecture et que le chrono s'arrete.
5. Reprendre la run puis verifier le retour de l'icone pause et la reprise du chrono.
6. Tester une largeur de fenetre reduite pour verifier que la top barre ne sort pas de l'ecran.

### Angles morts

- Le DataStore de progression utilisera un profil de session dans Studio lorsque les API Services ne sont pas activees. La persistance reelle doit donc etre verifiee dans une experience publiee ou avec les API Studio activees.
- La regle qui attribuera des gemmes arcaniques apres une run reste volontairement hors de cette passe : elle doit etre decidee avec l'economie de progression, pas deduite des coins temporaires.

## 2026-07-12 19:30 CEST - Top barre a deux niveaux

### Correctif applique

- La top barre est etendue a 960 pixels de reference, avec une echelle bornee par le viewport. Elle est donc plus large que le panneau de vie, bouclier et XP sur les resolutions desktop de reference tout en restant dans l'ecran sur mobile.
- Le chrono est centre dans la premiere ligne.
- Le groupe du prochain coffre est place a droite du chrono : icone coin, icone coffre, niveau actuel en `LVL` majuscule et cout du prochain coffre.
- Le bouton pause ou reprise est maintenant centre sous le chrono et repose sur un fond en losange metallique.
- La barre de boss est abaissee a `132` pixels pour ne pas masquer la top barre agrandie.

### Smoke manuel canonique

1. Lancer une run desktop et verifier que la top barre est au moins aussi large que le panneau de vie, bouclier et XP.
2. Verifier l'ordre visuel : gemmes, kills, coins de run, chrono, coffre, `LVL`, cout.
3. Mettre en pause puis verifier que le losange passe a l'icone lecture sans bouger le chrono.
4. Faire apparaitre le boss et verifier que sa barre de vie reste sous la top barre, sans recouvrement.
5. Reduire la largeur de la fenetre et verifier que la top barre reste entierement a l'ecran.

### Angle mort

- Sur un telephone tres etroit, la top barre privilegie le maintien de tous les indicateurs et reduit son echelle. La lisibilite reelle devra etre controlee dans le simulateur mobile Studio avant de figer les tailles minimales.
