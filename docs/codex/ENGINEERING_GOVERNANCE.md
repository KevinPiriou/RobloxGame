# Gouvernance d'ingénierie

## Avant de modifier

- Analyser le périmètre concerné, définir un objectif et une définition de terminé vérifiable. En cas de dérive, exposer le changement de nature du chantier avant de poursuivre.
- Identifier les cas simples canoniques, le smoke manuel attendu et les chemins voisins à préserver. Un cas simple réel qui échoue invalide une couverture plus large qui serait verte.
- Pour un fichier partagé, établir l'impact : appelants, services ou routes dépendants, périmètre exclu. Si la frontière reste floue, privilégier l'isolement ou l'extraction.
- Écrire les commentaires de code en français. Pour une montée de version explicite, comparer Va et Vb avec une trace testable, documenter la validation, puis seulement nettoyer Va.

## Conception et sécurité produit

- Préserver l'autorité serveur pour les actions, dégâts, récompenses et progression sensibles. Utiliser les patterns i18n existants pour tout nouveau label.
- Préférer la simplification à une couche de correction supplémentaire. Toute complexité ajoutée sur un chemin critique doit apporter un gain utilisateur observable ; une passe structurante doit garder un retour vers un comportement plus simple.
- Une correction annoncée comme générique doit être démontrée sur le cas ciblé, un cas simple acquis et un cas voisin naturel. Ne pas modifier un test de régression pour masquer une régression du code.

## Validation et clôture

- Rapporter séparément validation statique, build Rojo et test Roblox Studio. Par défaut, le smoke Studio est manuel et réalisé par l'utilisateur. Codex ne peut l'exécuter que si Studio ou une automatisation appropriée est réellement exposé par l'environnement et si l'utilisateur l'autorise explicitement ; sans preuve d'exécution, le déclarer non exécuté.
- Hiérarchie des preuves : cas réel observé, smoke manuel canonique, intégration ciblée, corpus, puis tests unitaires. Une preuve basse ne masque pas un échec haut placé.
- Si un cas canonique échoue, requalifier le travail en redressement avant toute sophistication. Déclarer les angles morts, les limites de validation et le budget de complexité à la clôture.
