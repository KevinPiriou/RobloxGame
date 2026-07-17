# Item Reveal V2 et credits de choix communs

Date de cloture de la passe : 2026-07-17 06:15 Europe/Paris

## Objet du chantier

Unifier les actions `Passer` et `Bannir` des ecrans de choix de run, puis
remplacer la presentation historique des coffres par le composant central V2.

Le contrat retenu est volontairement simple : les credits sont communs a tous
les choix d'une run, temporaires, attribues par le jeu et remis a leur quota au
depart de chaque nouvelle run. Ils ne sont ni des achats ni une seconde monnaie
persistante. Les rerolls de perks restent un rail distinct, lie aux credits de
reroll existants et a la boutique.

## Realisation

- `RunActionCreditService` porte une reserve serveur unique de trois credits
  `Passer` et trois credits `Bannir` par run.
- Le service publie uniquement un reflet visuel des valeurs sur le joueur ;
  les remotes ne peuvent pas decrementar directement ces valeurs cote client.
- Le debut de run initialise les deux reserves. La fin de run les remet a zero
  dans le lobby ; une nouvelle run repart donc avec le quota complet.
- `PerkService` consomme cette reserve commune :
  - `Passer` clot l'offre sans selection ;
  - `Bannir` retire le perk de la table d'offres de la run puis presente une
    offre de remplacement.
- `ChestService` consomme strictement la meme reserve :
  - `Passer` clot le coffre sans recompense ;
  - `Bannir` retire l'objet des recompenses proposables pendant la run.
- Les objets de run conservent leur regle existante de capacite : lorsque les
  douze emplacements sont remplis, seuls les objets deja possedes peuvent etre
  de nouveau proposes et cumules.
- `ItemRevealV2Adapter.client.luau` clone le composant `ItemRevealDock` depuis
  le template de production, emploie les remotes existants de coffre et laisse
  le serveur valider chaque action.
- L'ancien `ChestClient` reste un fallback de demarrage. Des que l'adaptateur
  V2 est pret, il ne construit plus le rendu historique du coffre.
- Le layout V2 traite `ItemRevealDockV2` comme un panneau central au meme titre
  que `PerkChoiceDockV2`.
- Le reel n'est visible que pendant le tirage. La carte de recompense devient
  ensuite l'unique element central, avec l'etat `NOUVEL OBJET` ou `OBJET
  CUMULE` confirme par le serveur.

## Validation

- `rojo build -o TestRoblox_run_action_credits.rbxlx` : valide.
- `git diff --check` : valide.
- Recherche de marqueurs de conflit Git : valide.
- Smoke manuel canonique du cycle visuel coffre realise par le joueur : le
  reel s'arrete puis disparait, laissant uniquement la carte finale. Validation
  utilisateur recue.

## Budget de complexite

Complexite ajoutee mais bornee : un seul petit service serveur et deux
attributs de presentation par action. Aucun DataStore, achat, nouveau format de
profil ou systeme de monnaie n'est introduit.

## Rollback

Le retour visuel peut se faire en retirant `ItemRevealV2Adapter.client.luau`
et son entree de layout : `ChestClient` reprend alors automatiquement son
affichage historique. Le retrait du service de credits et des deux routes de
remote restaure l'ancien comportement des choix, sans migration de donnees.

## Angles morts connus

- Le smoke manuel complet des credits communs reste a realiser : depenser une
  charge de `Passer` dans un choix de perk, ouvrir ensuite un coffre et verifier
  que son compteur affiche la reserve restante ; repeter le scenario pour
  `Bannir`.
- Si le joueur remplit tous ses emplacements avec une seule famille d'objet et
  bannit cette derniere recompense eligible, le pool de coffre peut devenir
  vide. Le serveur refuse alors une nouvelle ouverture. Cette situation devra
  recevoir une regle produit explicite avant l'equilibrage final des objets.
- Les actions `Passer` et `Bannir` ne montrent pas encore de retour client
  explicite lorsque le serveur les refuse (credit epuise, run inactive ou choix
  devenu obsolete). Le serveur reste protege, mais le feedback UX devra etre
  ajoute lors de la prochaine passe de robustesse.
