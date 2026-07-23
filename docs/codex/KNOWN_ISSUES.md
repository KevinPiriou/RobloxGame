# Problèmes connus Codex

Journal append-only. Inscrire uniquement un problème confirmé, son impact et sa source ; marquer « à vérifier » lorsqu'il n'a pas été revalidé.

## 2026-07-23 07:59:42 +02:00 — éléments historiques à vérifier

- À vérifier — le smoke manuel complet du cycle de personnages est encore listé comme restant dans `todo_2026-07-22_022516_smoke_cycle_personnages_jouables_v1.md`. Impact : la clôture globale de ce cycle ne peut pas être inférée de documents plus récents ciblant d'autres personnages.
- À vérifier — la statistique Taille de Rufus n'augmente pas encore la portée de sa lame, selon `post_audit_2026-07-23_054644_rufus_valorcrest_production_v1.md`. Impact : fonctionnalité explicitement différée, sans incidence déclarée sur le smoke historique validé.
- À vérifier — la validation multijoueur reste hors du smoke solo rapporté pour Rufus et Ru's al Gale. Impact : la présentation et l'isolation en situation multi ne sont pas établies par les documents ciblés.

## 2026-07-23 08:46:31 +02:00 — photographie Git absente pour cette clôture

- À vérifier — `ACTIVE_TASK.md` ne contenait pas la photographie Git de départ de ce chantier. L'état final observé comprend `.gitignore` modifié et `.agents/`, `AGENTS.md`, `docs/codex/` non suivis ; leur attribution historique est donc impossible. Impact : le handoff distingue explicitement le périmètre déclaré des changements que Git ne peut pas répartir. La procédure de démarrage doit être exécutée avant le prochain chantier.
