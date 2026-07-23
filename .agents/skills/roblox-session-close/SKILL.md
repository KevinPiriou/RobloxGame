---
name: roblox-session-close
description: Clôture un chantier Roblox en laissant une passation compacte, factuelle et exploitable.
---

# Clôture de session Roblox

Utiliser ce skill après un chantier significatif ou avant une passation vers un autre fil.

1. Relire la photographie Git dans `docs/codex/ACTIVE_TASK.md`, puis inspecter `git status --short` et le diff final (statistiques et contenu des fichiers concernés). Comparer l'état final au commit, aux fichiers modifiés et aux fichiers non suivis relevés au démarrage.
2. Ne pas attribuer au chantier les modifications préexistantes. Si l'absence de base comparable ou le mélange de changements empêche la distinction, le signaler explicitement dans le handoff et le statut.
3. Résumer les modifications réellement effectuées et leur motivation. Ne pas déduire un comportement non observé.
4. Enregistrer les validations réellement exécutées avec leur résultat, selon `docs/codex/ENGINEERING_GOVERNANCE.md`.
5. Lire `docs/codex/DOCUMENTATION_POLICY.md`, puis ajouter un bloc daté à la fin de `docs/codex/CURRENT_STATUS.md`. Ajouter les choix qui guident durablement les futurs fils à `DECISIONS.md`, et les problèmes non résolus confirmés à `KNOWN_ISSUES.md`.
6. Créer `docs/codex/handoffs/YYYY-MM-DD_HHMMSS_<sujet-court>.md` en suivant `docs/codex/handoffs/README.md` : contexte, définition de terminé, photographie Git, périmètre, fichiers clés, validations, risques et prochaine action.
7. Remplacer `docs/codex/ACTIVE_TASK.md` par une copie exacte de `docs/codex/ACTIVE_TASK.template.md`.

Appliquer les politiques référencées par `AGENTS.md` sans les recopier dans ce skill.
