# Guide Codex du dépôt

- Commencer par une exploration ciblée : lire ce guide, `docs/codex/PROJECT_MAP.md`, `docs/codex/CURRENT_STATUS.md`, le handoff pertinent dans `docs/codex/handoffs/`, puis les seules entrées du système. Ne jamais charger tout `src` ni l'historique complet.
- La synchronisation Rojo est définie par `default.project.json` : `src/shared` vers `ReplicatedStorage.Shared`, `src/server` vers `ServerScriptService.Server` et `src/client` vers `StarterPlayerScripts.Client`.
- Éviter `assets/`, `MegaSeedValidator/output/`, les résultats `MetaBuildLab_v1/` et les caches, sauf nécessité explicite. Rechercher l'historique par sujet et date.
- Avant toute modification de code ou de comportement, lire `docs/codex/ENGINEERING_GOVERNANCE.md` ; il fixe la définition de terminé, les preuves, l'autorité serveur et la règle Studio.
- Avant un ajout durable dans `docs/` ou un handoff, lire `docs/codex/DOCUMENTATION_POLICY.md`.
- Lire `docs/codex/REVIEW_POLICY.md` uniquement pour un audit explicite ou une revue d'architecture.
- Avant toute délégation, obtenir l'accord utilisateur puis lire `docs/codex/SUBAGENT_POLICY.md`. Les choix produit et l'intégration restent centralisés.
- Les Skills de session décrivent le déroulé de démarrage et de clôture ; ils appliquent ces politiques sans les recopier.

## Rappel du workflow de session

- Au premier message d'un nouveau fil concernant une modification, si
  `docs/codex/ACTIVE_TASK.md` indique qu'aucun chantier n'est actif,
  rappeler à l'utilisateur d'invoquer `$roblox-session-start` avant de
  modifier le projet.

- Lorsque l'utilisateur indique que le chantier est terminé, validé,
  suspendu, qu'il souhaite changer de système ou ouvrir un nouveau fil,
  rappeler d'invoquer `$roblox-session-close`.

- Avant le plan, `$roblox-session-start` recommande un niveau de raisonnement
  adapté au coût cognitif réel du chantier.

- `$roblox-session-start` et un Skill métier peuvent être invoqués ensemble :
  le Skill métier fournit le cadrage spécialisé, puis la session initialise le
  chantier avant l'implémentation.

- Après le démarrage de session, utiliser `$roblox-character-create` pour
  intégrer un nouveau personnage Roblox complet à partir de ses caractéristiques.

- Ne jamais activer un Skill sans demande explicite de l'utilisateur.
  Le rappel ne constitue pas une activation.

- Si un chantier actif existe déjà, signaler son système et son objectif
  avant d'en démarrer un autre.
