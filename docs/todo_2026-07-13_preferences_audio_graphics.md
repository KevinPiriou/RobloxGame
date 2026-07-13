# TODO preferences audio et graphiques

## 2026-07-13 04:13 CEST - Preferences joueur persistantes a planifier

### Constat actuel

Le mixeur audio V1 applique correctement les volumes de session dans `AudioController` : general, musique, effets, ambiance et interface. Ces valeurs sont cependant perdues a la deconnexion.

Les futurs reglages graphiques doivent concerner uniquement les options controlees par MegaRoblox : intensite des VFX, culling des collectibles, densite visuelle et distances d'animation. Le jeu ne doit pas ecraser le niveau graphique global choisi par le joueur dans les reglages Roblox natifs.

### Cible V1

- creer un `PlayerPreferencesService` serveur avec un DataStore dedie aux preferences, distinct de la meta progression ;
- charger les preferences au debut de session et envoyer un etat valide au client ;
- enregistrer les cinq volumes du mixeur avec une validation serveur `0..1` ;
- ajouter des options graphiques propres au jeu sous forme de profils `Bas`, `Moyen`, `Eleve` ;
- sauvegarder avec debounce et sur `PlayerRemoving`, sans ecrire le DataStore a chaque mouvement de slider ;
- appliquer les preferences audio localement dans `AudioController` apres rehydratation ;
- appliquer les preferences graphiques uniquement aux systemes MegaRoblox qui les prennent en charge.

### Contrat de donnees envisage

```text
Audio
|- Master
|- Music
|- Effects
|- Environment
`- Interface

Graphics
|- Profile
|- EffectsEnabled
|- CollectibleCullingDistance
`- EnemyAnimationDistance
```

Les valeurs restent bornees, serialisables et independantes de l'etat temporaire d'une run.

### Non-objectifs

- ne pas sauvegarder les reglages Roblox natifs de qualite graphique ;
- ne pas modifier les volumes partages d'autres joueurs ;
- ne pas melanger ces preferences avec DataStore de run, quetes, hauts faits ou commerce ;
- ne pas exposer un RemoteEvent qui accepte des cles de preference arbitraires du client.

### Smoke manuel attendu

1. Regler les cinq curseurs audio, quitter puis revenir : les valeurs doivent etre restaurees avant la premiere musique jouee.
2. Mettre `EFFETS` a zero, relancer une run : Fireball et interactions doivent rester muettes apres reconnexion.
3. Changer le profil graphique MegaRoblox, quitter puis revenir : seuls les VFX et culling du jeu doivent changer ; le reglage graphique Roblox du client ne doit pas etre force.
4. Faire bouger rapidement un slider : verifier que le mix reagit immediatement mais que les logs DataStore ne montrent pas une ecriture par frame.

### Angles morts et budget de complexite

- Juste : audio et qualite visuelle sont des preferences de compte, pas des ressources de run.
- Contestable : un DataStore dedie simplifie les migrations et les limites de responsabilite, mais ajoute une lecture/ecriture de profil. Cette separation est preferable au couplage avec la progression deja dense.
- Angle mort : les options graphiques ne pourront agir que sur les systemes qui offrent deja un vrai niveau de qualite configurable. Il faudra d'abord identifier ces leviers dans les VFX et le culling existants.
- Simplification : commencer par les cinq volumes et un profil graphique unique avant de proposer des dizaines de toggles individuels.

## Addendum - 2026-07-13 04:26 CEST - Audio implemente, graphique conserve

La persistance des cinq reglages audio est maintenant implementee dans `PlayerPreferencesService` et documentee dans `post_audit_2026-07-13_audio_preferences_persistence_v1.md`.

Le restant de ce TODO concerne exclusivement les preferences graphiques MegaRoblox : profil visuel, intensite VFX, culling et distances d'animation. Cette partie reste volontairement en attente d'un audit des leviers graphiques existants.
