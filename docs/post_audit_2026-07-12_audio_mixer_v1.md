# Audio Mixer V1

## 2026-07-12 18:03 CEST - Regie locale et mixage joueur

### Correctif applique

- `AudioService` est l'unique point serveur qui autorise la lecture d'un effet pour un joueur.
- `AudioController` joue les retours importants localement dans `SoundService`. Ils ne dependent plus de la distance entre le joueur et l'objet runtime.
- Le mix local propose cinq reglages : general, musique, effets, ambiance et interface.
- Le menu `AUDIO` est disponible en haut a droite, en lobby comme pendant une run.
- Fireball utilise maintenant `rbxassetid://9117987278` une seule fois par salve, meme avec plusieurs projectiles.
- Les sons de jarre, coffre normal, coffre reward elite, charge et fin de shrine, ainsi que l'arrivee du boss, passent par la regie. Le son d'arrivee du boss reste vide tant qu'un asset n'est pas fourni.

### Rangement Studio obligatoire

Placer le pool musical ici :

```text
SoundService
`-- MusicPool
    |-- Run_01 (Sound)
    |-- Run_02 (Sound)
    `-- Run_03 (Sound)
```

Pour chaque piste :

- renseigner `SoundId` ;
- laisser `Playing = false` ;
- laisser `Looped = false` ;
- regler `Volume` comme niveau relatif de la piste.

Le client clone et enchaine les pistes aleatoirement. Aucun ID supplementaire n'est requis si les `Sound` du pool possedent deja leur `SoundId`.

### Compatibilite temporaire

- Un `MusicPool` encore place dans `Workspace` est lu temporairement, mais produit un warning Audio. Il doit etre deplace dans `SoundService` pour finaliser le rangement.

### Smoke manuel canonique

1. Lancer une run et verifier que Fireball joue le nouveau son a chaque salve.
2. Casser une jarre, ouvrir un coffre puis valider une shrine : les sons doivent etre entendus quel que soit l'eloignement visuel de l'objet.
3. Ouvrir `AUDIO`, descendre `EFFETS` a zero puis verifier que Fireball et les interactions sont muettes.
4. Remonter `EFFETS`, puis regler `MUSIQUE` et `GENERAL` pour verifier le mix.
5. Verifier que le coffre reward elite joue son son a son apparition, et non au contact.

### Angles morts

- Les reglages de mix sont pour l'instant locaux a la session du joueur. Leur persistance entre deux connexions est un chantier distinct de preferences compte.
- Aucun asset d'ambiance monde ni son d'arrivee du boss n'a encore ete fourni. Les categories et leurs sliders existent, mais ne peuvent pas creer de contenu audio sans asset.
