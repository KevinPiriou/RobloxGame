# Post-audit - Panneau de statistiques V2 en production

## 2026-07-16 20:42:59 +02:00 - Branchement du panneau de statistiques de run

### Nature du jalon

Le panneau `RunStatsDock`, concu et valide dans
`StarterGui/MegaRobloxUIV_RunLayoutDraft`, est maintenant le renderer de
statistiques de run en production. Cette passe ne transforme pas le calcul des
perks ni le cycle de pause : elle remplace exclusivement l'ancienne composition
codee du HUD par le composant du kit.

### Juste - Source visuelle unique depuis le kit

- `RunStatsUI.client.luau` clone `RunStatsDock` depuis le kit de developpement
  vers `PlayerGui/RunStatsGui`. Le layout, la hierarchie, le style, les
  contraintes de taille et les animations restent donc ceux verifies dans
  Studio, sans seconde implementation manuelle du panneau.
- L'ancien renderer a ete retire, y compris sa section `OBJETS DE RUN`. Les
  objets de run sont volontairement reserves a la bottom bar ; le panneau de
  gauche ne contient que les statistiques de run.
- La visibilite conserve exactement le contrat historique : le panneau est
  visible seulement pendant une run en pause. Il reste masque dans le lobby et
  pendant le combat actif.

### Juste - Donnees de gameplay inchangees

- Les valeurs restent alimentees par `Perk_UpdateStats`, `Combat_UpdateStats`,
  `Combat_PauseState` et `Run_StateUpdate`.
- `PerkService` reste l'unique source des statistiques derivees : PV maximum,
  bouclier, degats, cadence, projectiles, critique, mobilite, multiplicateurs
  de gain et pression ennemie. Aucune valeur client n'est renvoyee au serveur.
- Les cartes de `PerkChoiceV2` publient localement une vue de leurs deltas
  recues du serveur. Le panneau affiche les chevrons de previsualisation sans
  modifier les statistiques, les offres ni le choix definitif.

### Validation executee

- `rojo build -o $env:TEMP/TestRoblox.verify.rbxlx` reussit.
- `git diff --check` ne signale pas d'erreur de contenu. Les avertissements
  `LF -> CRLF` sont lies au contexte Windows existant.
- Aucun marqueur de conflit Git n'est present.
- Smoke manuel canonique valide par le joueur : panneau disponible pendant le
  choix de perk, donnees reelles visibles, animation de previsualisation
  fonctionnelle et absence de regression constatee sur la boucle de jeu.

### Budget de complexite et angles morts

- Simplification : le renderer historique de statistiques est retire au lieu
  d'etre maintenu en parallele du kit. Une seule hierarchie Studio definit le
  rendu du composant.
- Angle mort : `RunStatsDock` reste un asset Studio hors du mapping Rojo. Une
  modification de sa structure doit donc conserver les identifiants de lignes
  attendus par `RunStatsUI` (`MaxHealth`, `Shield`, `ProjectileCount`, etc.) ou
  etre accompagnee de l'adaptation cliente correspondante.
- Angle mort : la lisibilite sur ecran mobile et ultra-large doit encore etre
  verifiee dans le simulateur de peripheriques avant de declarer ce composant
  universellement responsive.

### Rollback conceptuel

Le rollback consiste a restaurer le renderer historique de
`RunStatsUI.client.luau`. Aucun schema serveur, RemoteEvent, profil joueur ou
service de gameplay n'a ete modifie par ce branchement.
