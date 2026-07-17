# P1.2 - Normalisation physique des collectables

## Etat initial

Commit : `88c73ca`.

Scenario : run standard, map generee, dix collectables maintenus dans `Workspace/CombatRuntime/Loot`, puis audit `P1 : inventaire physique`.

Mesures avant :

- audit `P1-Physics-24595075` ;
- `CombatLoot` : `2` MeshParts ancres, `CanCollide=0`, `CanTouch=0`, `CanQuery=2` ;
- memoire totale : `2942.14 MB` avant / `2942.17 MB` apres ;
- `PhysicsParts` : `138.35 MB` stable ;
- `PhysicsCollision` : `1.61 MB` stable.

## Hypothese

Les pieces et gemmes ne dependent ni de collision, ni de contact, ni de requete physique : leur attraction, collecte et fusion sont gerees par les services dedies. La propriete `CanQuery=true` est donc une participation physique sans usage fonctionnel.

## Protocole

1. Demarrer une run et laisser des pieces/gemmes runtime au sol.
2. Lancer l'audit P1 et verifier le record `CombatLoot`.
3. Appliquer la normalisation runtime des clones de pieces et gemmes.
4. Rejouer le meme audit avec du loot au sol.
5. Verifier manuellement attraction, collecte et fusion XP.

## Modification etudiee

Description technique : `CoinService.prepareCoin` et `XpService.prepareCollectible` imposent maintenant `CanQuery=false` sur la racine `BasePart` et sur tous les descendants `BasePart`. La preparation gerera donc aussi un futur collectable fourni comme `Model`.

Fichiers concernes :

- `src/server/CoinService.luau`
- `src/server/XpService.luau`

Risques : faible. Le changement ne modifie ni l'autorite serveur, ni les recompenses, ni la position, ni l'attraction, ni la fusion. Le risque residuel est une dependance Studio implicite a une requete physique non presente dans le code actuel.

## Resultats

Apres : audit `P1-Physics-25328165`.

- `CombatLoot` : `10` MeshParts ancres, `CanCollide=0`, `CanTouch=0`, `CanQuery=0` ;
- memoire totale : `2895.32 MB` avant / `2895.34 MB` apres ;
- `PhysicsParts` : `145.51 MB` stable ;
- `PhysicsCollision` : `1.61 MB` stable.

Variance : les maps runtime ne contiennent pas le meme nombre de parties entre les deux releves (`2 970` puis `3 689` pour `MapRuntime`). Les totaux memoire ne sont donc pas une comparaison de gain exploitable.

Regression : aucune regression fonctionnelle rapportee lors du smoke de pieces, gemmes, attraction, collecte et fusion.

## Decision

`Keep`.

## Conclusion

Gain demontre : suppression verifiee de toute participation aux requetes physiques pour les collectables runtime (`CanQuery: 10 -> 0`).

Limites : aucun gain global de memoire ou de frame n'est demontre a cette echelle ; ce n'etait pas un resultat attendu avec dix MeshParts.

Etape suivante : P1.3, normaliser `CanTouch=false` et `CanQuery=false` sur les interactables ordinaires, puis verifier les `ProximityPrompt` et le coffre elite base sur `Touched`.
