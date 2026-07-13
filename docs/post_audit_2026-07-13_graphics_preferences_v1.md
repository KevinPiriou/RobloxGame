# 2026-07-13 05:18 CEST - Preferences graphiques V1

## Perimetre realise

Les preferences graphiques MegaRoblox sont maintenant disponibles dans un panneau `VIDEO`, place a gauche du bouton `AUDIO`. Les deux panneaux sont exclusifs : l'ouverture de l'un ferme l'autre, sans modifier le menu de lobby ni le HUD de run.

Le panneau applique et sauvegarde trois reglages avec un effet reel :

- `QUALITE` : profil `PERF`, `EQUILIBRE` ou `QUALITE` ;
- `EFFETS` : curseur de densite locale des particules, traineaux, faisceaux et lumieres ;
- `OMBRES` : activation locale de `Lighting.GlobalShadows`.

Le profil de qualite pilote egalement les collectibles cotes client : distance maximale visible, marge d'ecran du culling, intervalle de mise a jour du culling et cadence de rotation inactive.

| Profil | Loot visible | Cadence inactive | Multiplicateur VFX |
| --- | ---: | ---: | ---: |
| `PERF` | 180 studs | 12 Hz | x0,45 |
| `EQUILIBRE` | 360 studs | 30 Hz | x0,75 |
| `QUALITE` | 640 studs | 45 Hz | x1,00 |

## Contrat de persistance

`PlayerPreferencesService` conserve maintenant un schema version 2 :

```text
Audio
|- Master
|- Music
|- Effects
|- Environment
`- Interface

Graphics
|- Quality            -- "Performance" | "Balanced" | "Quality"
|- EffectsIntensity   -- nombre borne de 0 a 1
`- ShadowsEnabled     -- boolean
```

Chaque valeur est un `string`, `number` ou `boolean`. Aucun `Color3`, `Instance`, tableau UI ou dictionnaire non serialisable n'entre dans ce DataStore. Les profils audio precedents sans cle `Graphics` sont normalises avec les valeurs par defaut lors de leur prochaine sauvegarde.

## Fichiers concernes

- `src/shared/GraphicsConfig.luau` : profils de qualite et valeurs par defaut ;
- `src/client/GraphicsController.luau` : application locale, hydratation et debounce client ;
- `src/client/GraphicsSettingsUI.client.luau` : panneau `VIDEO` ;
- `src/client/CoinClient.client.luau` : consommation des reglages de culling/animation ;
- `src/shared/PlayerPreferencesConfig.luau` : contrat de remote et version de donnees ;
- `src/server/PlayerPreferencesService.luau` : validation, publication et sauvegarde des preferences graphiques ;
- `src/client/AudioSettingsUI.client.luau` : coordination d'ouverture avec le panneau `VIDEO`.

## Validation technique

- `rojo build -o $env:TEMP\\TestRoblox-graphics-preferences-verified.rbxlx` termine avec succes ;
- `git diff --check` ne remonte pas d'erreur de contenu ;
- la verification ciblee ne detecte aucun marqueur de conflit Git dans `src` ou `docs`.

## Smoke manuel canonique bloquant

1. Dans Studio, activer `Game Settings > Security > Enable Studio Access to API Services`.
2. Lancer Play, ouvrir `VIDEO`, choisir `PERF`, mettre `EFFETS` a 25 % et couper `OMBRES`.
3. Verifier dans une run : les loots lointains disparaissent plus tot, leurs rotations sont moins frequentes, les particules/traineaux/lumieres sont visiblement reduits et les ombres ne sont plus rendues.
4. Passer a `QUALITE`, `EFFETS` 100 %, ombres actives : les loots restent visibles plus loin, les effets retrouvent leur densite et les ombres reviennent.
5. Fermer Play puis relancer avec le meme compte : les trois valeurs doivent etre restaurees.
6. Ouvrir `AUDIO`, puis `VIDEO` : un seul panneau doit etre visible a la fois.
7. Consulter Output : aucune erreur `Preferences`, `DataStore` ou `Graphics` ne doit apparaitre.

## Angles morts et budget de complexite

- Juste : les reglages agissent uniquement sur le rendu client ; la simulation, les degats, le loot et les choix de gameplay restent entierement serveur.
- Simplification : trois leviers concrets remplacent une fausse liste exhaustive de reglages. Ils couvrent les postes deja configurables sans ajouter de systeme de qualite global parallele a Roblox.
- Contestable : le profil modifie la distance de rendu des collectibles, mais pas encore les animations des monstres ni le rendu des meshes lointains. Ces deux sujets doivent etre traites ensemble dans un futur chantier de LOD, pas par des toggles superficiels.
- Angle mort : certains emitters declenches ponctuellement via `:Emit()` peuvent rester visibles meme avec une intensite tres basse ; le curseur reduit les emitters continus, traineaux, beams et lumieres locaux, mais n'intercepte pas l'API Roblox elle-meme.

## Addendum - 2026-07-13 05:24 CEST - Redressement du raccourci admin

Le premier placement du bouton `VIDEO` reutilisait par erreur l'offset historique du bouton `ADMIN` (`-92` depuis le bord droit). Le bouton admin etait donc rendu derriere le nouveau raccourci graphique.

Le contrat de placement est maintenant :

- `VIDEO` : `-166` ;
- `ADMIN` : `-92` ;
- `AUDIO` : `-18`.

`ADMIN` garde ainsi sa position et son comportement preexistants. `rojo build -o $env:TEMP\\TestRoblox-graphics-preferences-admin-layout-verified.rbxlx` a termine avec succes apres ce redressement.
