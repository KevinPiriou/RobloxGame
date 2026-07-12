# HUD Lobby, Prompts Et Admin

## 2026-07-12 23:05 CEST - Separation lobby/run et surfaces UI

### Correctifs appliques

- Le panneau de vie, bouclier et XP est maintenant visible uniquement pendant une run.
- Le solde permanent de gemmes arcaniques reste visible dans le lobby via une puce dediee, separee de la top barre de run.
- La top barre ignore maintenant l'inset Roblox et est positionnee au plus haut de l'ecran. Sa hauteur est reduite, tandis que le bouton pause ou reprise conserve une surface losange sous le chrono.
- Le cout du prochain coffre est replace immediatement a droite du chrono. L'ordre du groupe devient : coin, cout, coffre, `LVL`.
- La barre de boss est replacee sous la top barre compacte pour eviter tout recouvrement.
- Le recapitulatif de run reprend les surfaces metal et verre, les contours fins, les accents cyan et violets, ainsi que les lignes de statistiques lisibles.
- L'admin est transforme en bouton `ADMIN` et panneau repliable, avec les memes conventions que le panneau audio. Les commandes serveur existantes sont conservees.

### Correctif prompt

- Les prompts custom construisaient leur `BillboardGui` sous un `ScreenGui`. Ce parentage ne garantit pas le rendu d'un BillboardGui.
- Le BillboardGui est maintenant parent directement a `PlayerGui`, qui est le conteneur de rendu adapte. Les callbacks de maintien suivent aussi les signatures de `ProximityPromptService` sans attendre un joueur absent de ces evenements.
- Un log throttle `Prompt custom affiche` est ajoute afin de distinguer a l'avenir un prompt non genere d'un probleme de rendu.

### Smoke manuel canonique

1. En lobby, verifier que le panneau vie, bouclier et XP est absent et que la puce gemmes arcaniques est visible.
2. Demarrer une run : verifier que la top barre arrive au bord superieur utile, que le panneau de vie reapparait et que la puce lobby disparait.
3. Verifier le groupe a droite du chrono : valeur du coffre, icone coffre, `LVL` courant.
4. Faire varier le niveau puis ouvrir un coffre normal pour verifier que `LVL` et cout evoluent independamment.
5. S'approcher d'une jarre, d'un coffre ou d'un shrine : le prompt custom doit etre visible et l'action E doit encore fonctionner.
6. Terminer une run : verifier le recapitulatif metal-verre et le bouton retour au lobby.
7. Avec un compte admin, ouvrir `ADMIN`, executer les trois commandes et verifier que le panneau reste repliable.

### Angles morts

- La top barre est volontairement compressee sur les resolutions tres etroites pour rester entiere a l'ecran. La lisibilite sur telephone doit etre controlee dans le simulateur mobile Studio.
- Les panneaux audio et admin peuvent etre ouverts en meme temps. Ils sont decales, mais une future passe pourra fermer automatiquement l'un quand l'autre s'ouvre si cela devient une friction observee.

## 2026-07-12 23:12 CEST - Alignement vertical de la top barre

### Correctif applique

- Les icones et valeurs de la top barre utilisent maintenant un ancrage vertical centre dans leur slot, plutot que des offsets superieurs differents selon chaque element.
- Le groupe du prochain coffre suit l'ordre visuel `coin + coffre + cout`, avec les deux icones volontairement proches. Le niveau `LVL` vient ensuite dans un slot distinct.

### Smoke manuel canonique

1. Lancer une run et verifier que chaque icone est centree verticalement par rapport a sa valeur.
2. Verifier que le groupe coffre est lu sans ambiguite comme une valeur de cout : coin, coffre, nombre.
3. Monter de niveau puis ouvrir un coffre pour verifier que `LVL` et le cout continuent de changer independamment.
