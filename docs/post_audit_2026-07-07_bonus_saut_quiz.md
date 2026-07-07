# post_audit - Bonus saut quiz

Date: 2026-07-07 15:45:39 +02:00

## Contexte

Cette passe transforme le quiz en declencheur de bonus gameplay. La recompense visee est simple: une bonne reponse donne un saut double temporaire, une mauvaise reponse ne donne aucun nouveau bonus.

## Changements appliques

- Le corpus de questions est reduit a une seule question de test.
- Le serveur applique un bonus de saut x2 pendant 20 secondes en cas de bonne reponse.
- Le client affiche le resultat du bonus sans decider de la recompense.
- Le score existant est conserve pour ne pas casser la boucle precedente, mais la recompense gameplay principale devient le saut double.

## Proof of done

- `rojo build -o "$env:TEMP\TestRoblox_quiz_build.rbxlx"` passe.
- La validation de la reponse reste faite cote serveur.
- Le client transmet uniquement un index de reponse.
- La mauvaise reponse produit un message "Pas de bonus." et n'appelle pas le service de bonus.

## Angles morts

- Le saut double doit encore etre verifie en Play dans Roblox Studio.
- Le bonus est temporaire et ne se cumule pas au-dela de x2; une nouvelle bonne reponse rafraichit la duree.
- Le score visible existe encore, mais il n'est plus le coeur de la recompense.

## Budget de complexite

Cette passe ajoute une petite complexite isolee dans `JumpBonusService.luau`. Elle evite de surcharger `RoundService.luau` avec la manipulation directe du `Humanoid`, ce qui garde le chemin critique du quiz lisible.

---

## Append - 2026-07-07 15:52:08 +02:00 - Effets cumulables

### Contexte

Un defaut produit a ete observe en Play: l'expiration d'un bonus pouvait annuler l'effet attendu d'une reponse suivante. Le modele precedent etait insuffisant car il representait le bonus comme un etat unique par joueur, au lieu de representer des effets temporaires independants.

### Changements appliques

- `JumpBonusService.luau` gere maintenant une liste d'effets actifs par joueur.
- Chaque effet possede sa propre expiration et son propre identifiant.
- Quand un effet expire, le serveur retire seulement cet effet puis recalcule le saut avec les effets restants.
- Les bonnes reponses ajoutent un bonus de saut `+100%`.
- Les mauvaises reponses ajoutent un malus de saut `-50%`.
- Les effets actifs sont envoyes au client via `Quiz_UpdateEffects`.
- L'UI affiche les stacks actifs sous la forme `Effets : +N saut (...) | -N saut (...)`.

### Proof of done

- `rojo build -o "$env:TEMP\TestRoblox_quiz_build.rbxlx"` passe.
- Les anciens marqueurs de bonus unique (`bonusToken`, `ClearBonus`) ne sont plus presents.
- Le score reste serveur, et les effets de saut restent appliques uniquement cote serveur.

### Angles morts

- Le cumul est additif sur la base du saut: un bonus donne x2, deux bonus donnent environ x3, pas x4.
- Le malus est borne par `MinimumJumpMultiplier` pour eviter un saut nul ou injouable.
- Le comportement exact doit encore etre valide dans Roblox Studio en enchainant plusieurs bonnes et mauvaises reponses.

### Budget de complexite

Cette passe ajoute de la complexite utile: elle remplace un etat unique fragile par une liste d'effets temporaires independants. La complexite reste localisee dans `JumpBonusService.luau`; `RoundService.luau` ne fait que demander un bonus ou un malus selon le resultat.

---

## Append - 2026-07-07 15:59:47 +02:00 - Bonus permanents persistants

### Contexte

Le modele d'effets temporaires ne correspond plus a la cible produit. Les bonus de saut doivent etre cumulables sans timer, rester actifs pendant toute la duree de vie du joueur, et survivre a une deconnexion. Les malus ne doivent pas creer un etat negatif autonome: ils servent uniquement a reduire ou desactiver des bonus deja gagnes.

### Changements appliques

- Suppression du modele d'effets a expiration.
- `JumpBonusService.luau` stocke maintenant un nombre persistant de stacks de bonus saut par joueur.
- Une bonne reponse ajoute `+1` stack de bonus saut.
- Une mauvaise reponse retire `1` stack de bonus saut si le joueur en possede deja.
- Aucune reponse ne modifie pas les stacks.
- Les stacks sont sauvegardes via `DataStoreService` dans `QuizJumpBonusProgress_v1`.
- Le serveur sauvegarde aussi les stacks au depart du joueur et au `BindToClose`.
- L'UI affiche maintenant `Bonus saut : N stacks | xM` sans duree restante.

### Proof of done

- `rojo build -o "$env:TEMP\TestRoblox_quiz_build.rbxlx"` passe.
- Les anciens champs temporaires (`ExpiresAt`, `RemainingSeconds`, `JumpBonusDuration`, `JumpMalusDuration`) ne sont plus presents dans `src`.
- Le client n'envoie toujours qu'un index de reponse.
- Le serveur reste seul responsable de modifier, appliquer et sauvegarder les bonus.

### Angles morts

- La persistance apres deconnexion depend de DataStore. En Studio, il faut activer l'acces aux API Roblox pour tester cette partie.
- Le cumul reste additif: avec le reglage actuel, `1` stack donne environ `x2`, `2` stacks donnent environ `x3`.
- Il faudra verifier en Play que les stacks sont bien conserves apres reconnexion sur une experience publiee ou avec DataStore accessible.

### Budget de complexite

Cette passe deplace la complexite depuis des timers d'effets vers un contrat de persistance joueur. C'est une complexite necessaire pour respecter le comportement voulu, mais elle reste concentree dans `JumpBonusService.luau`.

---

## Append - 2026-07-07 16:02:12 +02:00 - Redressement demarrage quiz

### Contexte

Apres l'ajout de la persistance DataStore, le quiz pouvait ne plus apparaitre en Play. Le probleme probable etait un couplage de demarrage: `GameManager.server.luau` chargeait les donnees persistantes du joueur avant de lancer `RoundService.Start()`. Si DataStore etait lent ou indisponible en Studio, les remotes de quiz n'etaient pas crees assez vite et le client restait en attente.

### Changement applique

- `JumpBonusService.SetupPlayer(player)` est maintenant lance dans une coroutine via `task.spawn`.
- `ScoreService.SetupPlayer(player)` reste immediat.
- `RoundService.Start()` peut donc creer les remotes et lancer la boucle de quiz sans attendre le chargement DataStore.

### Proof of done

- `rojo build -o "$env:TEMP\TestRoblox_quiz_build.rbxlx"` passe.
- Les anciens timers d'effets ne sont pas revenus.
- Le quiz ne depend plus du chargement synchrone du profil bonus pour demarrer.

### Angle mort

- La verification finale doit etre faite en relancant une session Play complete dans Roblox Studio. Une simple synchro Rojo pendant une session deja lancee peut laisser un ancien etat serveur/client en memoire.
