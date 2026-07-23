# Statut courant Codex

Journal compact append-only. Le dernier bloc daté décrit l'état de référence ; les affirmations historiques indiquent leur source et ne valent pas comme revalidation de session.

## 2026-07-23 07:59:42 +02:00 — initialisation de la mémoire

- Configuration observée : Rojo relie `src/shared`, `src/server` et `src/client` aux emplacements Roblox indiqués dans `default.project.json`.
- Dernier chantier documenté : `post_audit_2026-07-23_054644_rufus_valorcrest_production_v1.md`. Il rapporte la promotion de Rufus et de `valorcrest_blade`, avec un chemin melee serveur dédié ; son smoke Studio est une déclaration historique du responsable produit, non rejouée dans cette session.
- Suivi à vérifier : `todo_2026-07-22_022516_smoke_cycle_personnages_jouables_v1.md` porte encore un smoke manuel du cycle de personnages. Aucun document de clôture correspondant n'a été confirmé durant l'inspection ciblée.
- Aucun chantier de code n'est actif dans cette mémoire. Cette session ne modifie que le workflow Codex.
- Validations de cette session : aucune validation statique, aucun build Rojo et aucun test Roblox Studio exécutés à ce stade.

## 2026-07-23 08:16:39 +02:00 — gouvernance extraite des instructions historiques

- Les règles permanentes sont désormais séparées entre politique documentaire, gouvernance d'ingénierie, revue et sous-agents afin d'éviter leur répétition dans `AGENTS.md` et les Skills.
- Source analysée : `docs/codex/legacy/HOST_CUSTOM_INSTRUCTIONS_2026-07-23.md`. Le fichier historique est conservé comme référence ; il n'est pas recopié.
- Cette session reste documentaire : aucun fichier Roblox de production, build Rojo ou test Studio n'a été exécuté.

## 2026-07-23 08:30:35 +02:00 — correction ciblée du workflow

- La photographie Git de début de session est désormais obligatoire dans `ACTIVE_TASK.md` et comparée à la clôture ; les changements préexistants ne sont pas attribués au chantier.
- La carte de projet contient des entrées principales non exhaustives par système, fondées sur les noms de fichiers et des références historiques ciblées.
- La politique Studio est conditionnelle : smoke manuel utilisateur par défaut, exécution Codex seulement si l'environnement l'expose réellement et après autorisation explicite.
- Aucun fichier Roblox de production, build Rojo ou test Studio n'a été exécuté pendant cette correction documentaire.

## 2026-07-23 08:46:31 +02:00 — clôture de la configuration du workflow Codex

- Le chantier documentaire est clos et son handoff de configuration est disponible dans `docs/codex/handoffs/2026-07-23_084632_codex_workflow_configuration.md`.
- La photographie Git de départ n'avait pas été remplie dans `ACTIVE_TASK.md`. L'état final observé ne permet donc pas d'attribuer de façon fiable les modifications préexistantes à ce chantier.
- Aucun fichier Roblox, build Rojo ni test Roblox Studio n'a été exécuté pendant la clôture.

## 2026-07-23 12:00:50 +02:00 — clôture de Lorelei

- Lorelei est intégrée comme personnage sélectionnable par défaut, avec son arme canalisée Soulthorn, son passif de seuils de kills, ses textes FR/en-US, ses VFX locaux et les références d'assets Roblox fournies.
- Le sélecteur pré-run réutilise désormais les cartes existantes sans tenir compte de la casse de leur nom ; Lorelei est créée dynamiquement seulement si sa carte est absente du template.
- Validations : analyse statique (`git diff --check`) et build Rojo réussis ; smoke Roblox Studio validé par le responsable produit. Le multijoueur n'a pas été exécuté.
- Passation : `docs/codex/handoffs/2026-07-23_120050_lorelei.md`.
