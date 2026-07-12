# Interaction Prompt Da

## 2026-07-12 17:31 CEST - Prompts et temoins d'activation metalliques

### Correctif applique

- Les prompts des coffres, jarres, portail boss, totems et shrines utilisent maintenant `ProximityPromptStyle.Custom`.
- `InteractionPromptUI.client.luau` dessine une interface monde en verre sombre et metal, avec touche, nom de l'objet, action et progression de maintien.
- Les interactions restent declenchees et verifiees par les services serveur existants. Cette passe ne deplace aucune regle de gameplay vers le client.
- Le marqueur `!` des shrines utilise maintenant une coque metallee circulaire et un interieur verre sombre, avec le meme langage visuel que la top bar.

### Smoke manuel canonique

1. Approcher un coffre normal : verifier la touche `E`, le nom du coffre et l'action d'ouverture.
2. Approcher une jarre et un totem : verifier le prompt puis la disparition apres interaction.
3. Approcher une shrine elite ou magnet : maintenir `E` et verifier que la barre de progression se remplit jusqu'a l'activation.
4. Approcher le portail boss : verifier le prompt et le lancement du boss.
5. Verifier qu'une perk shrine a charge par bulle conserve seulement son `!` et sa bulle, sans prompt `E` parasite.

### Angle mort

- L'offset monde du prompt est volontairement commun a tous les interactables. Un futur modele tres haut ou tres large pourra necessiter un attribut d'offset specifique, mais aucun ajustement de map n'est requis pour les templates actuels.
