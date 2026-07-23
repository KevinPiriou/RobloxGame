# Politique documentaire

## Objet

Conserver une mémoire courte, fiable et chronologique sans dupliquer les handoffs, les décisions et l'historique existant de `docs/`.

## Règles

- Rechercher l'historique par sujet et date ; ne pas relire tous les anciens `audit_`, `post_audit_` ou `todo_`.
- Ajouter les entrées durables à la fin, avec date et heure. Vérifier l'append avant de clôturer l'écriture.
- Écrire après un chantier significatif réellement clos ou lorsqu'une dette, une décision ou un état durable doit guider le fil suivant. Éviter les documents pour une modification triviale.
- `CURRENT_STATUS.md`, `DECISIONS.md`, `KNOWN_ISSUES.md` et les handoffs sont append-only. `ACTIVE_TASK.md` est l'unique état de travail réinitialisable.
- Utiliser `audit_` uniquement pour un audit explicite ou un document de préparation d'audit. Ne créer un `post_audit_` que sur demande explicite ; un handoff clôt normalement une passation.
- Si un plan est abandonné ou requalifié, consigner le restant utile dans le handoff et `KNOWN_ISSUES.md`. Créer un `todo_` seulement lorsqu'un plan de reprise autonome est réellement demandé.
- Ne répéter ni le diff ni les décisions dans plusieurs documents : le handoff résume et lie, les journaux conservent le fait durable.
- Lorsque `CURRENT_STATUS.md` dépasse 15 blocs datés ou environ 300 lignes, créer un archive datée dans `docs/codex/archive/`, y déplacer verbatim les blocs clos les plus anciens et laisser dans `CURRENT_STATUS.md` une entrée datée de synthèse avec le lien vers l'archive. Cette exception d'archivage préserve l'historique ; aucun bloc n'est supprimé.
