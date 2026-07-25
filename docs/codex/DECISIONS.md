# Décisions durables Codex

Journal append-only. Ajouter une décision seulement lorsqu'elle doit guider un futur fil ; ne pas y recopier un handoff complet.

## 2026-07-23 07:59:42 +02:00 — mémoire et passation légères

- La mémoire transversale est limitée à `docs/codex/` : carte, statut, tâche active, décisions, problèmes et handoffs.
- Le test Roblox Studio reste exclusivement un smoke manuel de l'utilisateur. Les validations statiques et le build Rojo doivent être rapportés séparément, avec leur résultat réel.
- Un `post_audit` daté n'est pas créé automatiquement par ce workflow ; un handoff daté suffit pour la passation, sauf demande explicite de chantier documentaire.

## 2026-07-23 08:16:39 +02:00 — gouvernance non dupliquée

- `AGENTS.md` reste une porte d'entrée courte ; il oriente vers la politique adaptée au contexte au lieu d'en recopier les détails.
- Les procédures de démarrage et de clôture restent dans les Skills. Les contraintes permanentes vivent dans les politiques de gouvernance, et les règles d'hôte ne sont pas dupliquées dans le dépôt.

## 2026-07-23 08:28:56 +02:00 — politique Studio conditionnelle

- Le smoke Roblox Studio est manuel par défaut et réalisé par l'utilisateur.
- Codex peut l'exécuter uniquement si l'environnement expose réellement Studio ou une automatisation adaptée, et après autorisation explicite de l'utilisateur. Sans preuve d'exécution, le test est déclaré non exécuté.

## 2026-07-23 12:00:50 +02:00 — arme canalisée serveur et cartes de sélection dynamiques

- La catégorie `Channel` conserve côté serveur la sélection des cibles, les ticks de dégâts, le soin et l'arrêt du canal. Le client ne reçoit que la présentation VFX.
- Le sélecteur de personnages compare les IDs sans tenir compte de la casse et ne clone une carte qu'en l'absence d'une carte template correspondante.

## 2026-07-26 00:54:23 +02:00 — échelle de combat de Wukong

- Wukong gagne 5 % de vitesse de déplacement par niveau, et son bâton reçoit 1 % de dégâts supplémentaires pour chaque 1 % de vitesse de déplacement effective. Le calcul s'effectue côté serveur à partir des statistiques de perks ; le client ne détermine ni le bonus ni les dégâts.
