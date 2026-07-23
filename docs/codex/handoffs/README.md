# Handoffs Codex

Un handoff est le paquet de passation d'un chantier significatif entre fils Codex. Il remplace une relecture large et ne crée pas automatiquement de `post_audit`.

## Nom et conservation

Créer un fichier `YYYY-MM-DD_HHMMSS_<sujet-court>.md`. Ne pas réécrire un handoff clos : ajouter un nouveau fichier pour le chantier suivant.

## Contenu minimal

1. Date, fil source et système concerné.
2. Photographie Git de départ : branche, racine du worktree, commit de référence, état initial, fichiers modifiés et non suivis avant session.
3. Objectif, définition de terminé et périmètre réellement traité.
4. Modifications réalisées et motivations, avec fichiers clés ; distinguer explicitement les modifications préexistantes. Si cette distinction est impossible, le déclarer.
5. Validations réellement exécutées, résultat et ce qui n'a pas été exécuté.
6. Validations restantes, avec leur responsable : utilisateur, Codex ou environnement externe.
7. Décisions prises, problèmes non résolus, risques et prochaines actions.

Le fil repreneur lit d'abord le handoff lié à son sujet, puis cible les documents historiques par date et mot-clé si un contexte manque.
