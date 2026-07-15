# Post-audit - Loader de run et generation par lots V1

## 2026-07-14 00:00:00 +02:00 - Cloture du chantier

### Objectif

Une run ne doit pas exposer au joueur la construction progressive de la map et des interactables. Le lancement doit rester simple a comprendre : preparation, generation cachee, positionnement sur le point d'arrivee, puis debut du combat.

### Comportement implemente

- `RunLoadingService` est le proprietaire serveur de l'etat de chargement. Il bloque temporairement le personnage, publie une progression fermee vers le client et le libere uniquement lorsque la run devient active.
- `RunLoadingUI.client.luau` affiche un ecran plein avec une progression etape par etape. Il repose sur le RemoteEvent `Run_LoadingState` et sur l'attribut `IsRunLoading` comme filet de synchronisation lors d'une reapparition du personnage.
- Le cycle de session est maintenant explicite : `Creating -> Generating -> Ready -> Active`. Les ennemis, tirs et interactions ne commencent qu'apres le deplacement sur le point d'arrivee de la map.
- `RunWorldService` orchestre l'ordre de generation : portail, shrines, coffres, totems, puis jarres.
- Chaque famille est generee par lots et rend la main entre les lots : portail par 1, shrines par 3, coffres par 5, totems par 2 et jarres par 5.
- La fin anticipee d'une run annule proprement le chargement afin de ne jamais laisser un personnage bloque.

### Responsabilites

- `RunLoadingConfig` contient les textes, les jalons de progression et les tailles de lots.
- `RunLoadingService` ne construit ni map ni interactable : il gere uniquement le verrouillage, la publication d'etat et la liberation du joueur.
- `RunWorldService` reste l'orchestrateur de contenu runtime.
- Les services de portail, shrine, coffre, totem et jarre restent proprietaires de leur clonage et de leur suivi, mais acceptent maintenant une option de generation par lots.

### Budget de complexite

Cette passe ajoute un petit etat transitoire et une interface dediee. En contrepartie, elle supprime l'ambiguite precedente ou `RunStateService.StartRun` pouvait demarrer le combat pendant que le joueur etait encore en transit vers le point d'arrivee.

### Validation

- `rojo build -o TestRoblox.rbxlx` : succes.
- `git diff --check` : succes.
- recherche de marqueurs de conflit dans `src` et `docs` : aucun resultat.
- Smoke Studio observe : une session atteint `Active`, `MapRuntime` contient la map clonee et le combat demarre ensuite.
- Smoke manuel produit confirme : le loader fonctionne et masque bien la construction au joueur.

### Angles morts et suite

- ◐ Les recherches de positions sur une surface sont encore calculees de maniere synchrone a l'interieur de chaque famille. Le joueur ne les voit plus, mais une map tres dense peut encore occasionner une charge serveur ponctuelle.
- ◐ Les futures plateformes et decorations doivent adopter le meme contrat `GenerateForRun(session, generationOptions)`, avec une taille de lot adaptee a leur cout de clonage.
- ~ Le prochain chantier pertinent est un `MapGenerationService` qui construit plateformes et decoration par lots, puis appelle `RunWorldService` seulement lorsque la surface jouable est complete.
- ◐ Le placement des totems reste a verifier separement : un precedent Play Test avait place 3 totems sur 5 lorsque les positions valides etaient insuffisantes. Ce loader ne modifie pas cette regle de placement.
