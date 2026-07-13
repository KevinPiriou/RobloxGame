# 2026-07-13 04:26 CEST - Preferences audio persistantes V1

## Perimetre realise

Les cinq reglages du mixeur audio sont maintenant sauvegardes par joueur :

- general ;
- musique ;
- effets ;
- ambiance ;
- interface.

`PlayerPreferencesService` possede un DataStore dedie `MegaRobloxPlayerPreferences_v1`. Il est separe de la progression meta, des statistiques, des quetes et des donnees temporaires de run.

## Cycle de vie

1. Le serveur charge le profil dans `SetupPlayer`.
2. `AudioController` demande l'etat valide avant de lancer la musique.
3. Un slider applique le mix local immediatement.
4. Le client envoie le mix complet apres 0,65 seconde sans nouveau mouvement.
5. Le serveur valide les cinq cles connues dans l'intervalle `0..1` et sauvegarde apres une seconde de debounce.
6. `PlayerRemoving` et `BindToClose` forcent une derniere sauvegarde si le profil est dirty.

Le serveur ne fait confiance a aucune cle arbitraire ou valeur hors borne envoyee par le client.

## Fichiers concernes

- `src/shared/PlayerPreferencesConfig.luau` : contrat du DataStore et des remotes ;
- `src/server/PlayerPreferencesService.luau` : chargement, validation, debounce et sauvegarde ;
- `src/client/AudioController.luau` : hydratation et envoi differe ;
- `src/server/GameManager.server.luau` : cycle de vie du service.

## Validation technique

- `rojo build -o $env:TEMP\TestRoblox-audio-preferences-v1.rbxlx` termine avec succes ;
- `git diff --check` ne remonte pas d'erreur de contenu ;
- aucun marqueur de conflit Git n'est present dans `src` ou `docs`.

## Smoke manuel canonique bloquant

1. Dans Studio, activer `Game Settings > Security > Enable Studio Access to API Services` pour ce test.
2. Lancer Play, regler `MUSIQUE` a 23% et `EFFETS` a 61%, puis attendre au moins deux secondes.
3. Arreter Play, relancer Play avec le meme compte : les deux sliders doivent revenir a 23% et 61% avant la musique.
4. Mettre `GENERAL` a 0%, quitter immediatement, puis relancer : tous les groupes doivent rester muets.
5. Consulter Output : aucune erreur `Preferences` ou DataStore ne doit apparaitre.

## Angles morts et budget de complexite

- Juste : les preferences audio sont persistantes et independantes de la run.
- Angle mort : si Studio API Services est desactive, le service bascule explicitement en session-only. Une relance Play ne peut alors pas prouver la persistance DataStore.
- Contestable : le client envoie le mix complet plutot qu'une seule cle. Avec cinq valeurs bornees et un debounce, ce contrat reste plus robuste et plus simple a migrer.
- Simplification : les reglages graphiques ne sont pas implementes dans cette passe. Aucun faux profil graphique ne doit etre sauvegarde tant que les systemes VFX/culling correspondants ne savent pas encore le consommer.
