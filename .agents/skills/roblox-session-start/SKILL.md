---
name: roblox-session-start
description: Démarre un chantier Roblox de façon ciblée et consigne le contexte minimal de passation.
---

# Démarrage de session Roblox

Utiliser ce skill avant de modifier du code Roblox.

1. Demander le système concerné, l'objectif et la définition de terminé si l'un de ces éléments n'est pas fourni. Ne pas inventer de critère de clôture important.
2. Lire, dans cet ordre, `AGENTS.md`, `docs/codex/PROJECT_MAP.md`, `docs/codex/CURRENT_STATUS.md` et le dernier handoff pertinent dans `docs/codex/handoffs/`. Lire ensuite `docs/codex/ENGINEERING_GOVERNANCE.md` avant tout changement de code. Rechercher l'historique par sujet et date uniquement si nécessaire.
3. Avant toute modification, exécuter `git branch --show-current`, `git rev-parse HEAD` et `git status --short`. Relever aussi le worktree avec `git rev-parse --show-toplevel`. Distinguer dans le statut les fichiers déjà modifiés et les fichiers non suivis.
4. Identifier les fichiers d'entrée probables à partir de la carte, de `default.project.json` et de recherches ciblées. Ne pas scanner tout le dépôt, ni parcourir les assets ou dossiers générés sans nécessité explicite.
5. Si docs/codex/ACTIVE_TASK.md n'existe pas, le créer à partir de
   docs/codex/ACTIVE_TASK.template.md.
6. Remplir `docs/codex/ACTIVE_TASK.md` avec la date, le système, l'objectif, la définition de terminé, la photographie Git complète, le périmètre, les entrées probables, les risques d'autorité serveur et le plan.
7. Présenter ce plan court à l'utilisateur avant toute modification de code.

Appliquer les politiques référencées par `AGENTS.md` sans les recopier dans ce skill.
