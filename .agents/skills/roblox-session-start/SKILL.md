---
name: roblox-session-start
description: Démarre un chantier Roblox de façon ciblée et consigne le contexte minimal de passation.
---

# Démarrage de session Roblox

Utiliser ce skill avant de modifier du code Roblox.

1. Lorsqu'un Skill métier est explicitement invoqué dans le même message, utiliser son cadrage spécialisé — système, objectif et proposition de définition de terminé — comme base. Ne pas demander à l'utilisateur une définition de terminé exhaustive ; poser une question seulement si un critère déterminant et irréversible reste réellement impossible à déduire. Sans Skill métier, demander le système et l'objectif manquants selon la même règle.
2. Lire, dans cet ordre, `AGENTS.md`, `docs/codex/PROJECT_MAP.md`, `docs/codex/CURRENT_STATUS.md` et le dernier handoff pertinent dans `docs/codex/handoffs/`. Lire ensuite `docs/codex/ENGINEERING_GOVERNANCE.md` avant tout changement de code. Rechercher l'historique par sujet et date uniquement si nécessaire.
3. Avant toute modification, exécuter `git branch --show-current`, `git rev-parse HEAD` et `git status --short`. Relever aussi le worktree avec `git rev-parse --show-toplevel`. Distinguer dans le statut les fichiers déjà modifiés et les fichiers non suivis.
4. Identifier les fichiers d'entrée probables à partir de la carte, de `default.project.json` et de recherches ciblées. Ne pas scanner tout le dépôt, ni parcourir les assets ou dossiers générés sans nécessité explicite.
5. Évaluer le coût cognitif réel du chantier et recommander `Moyen`, `Élevé` ou `Très élevé` avec une justification d'une ou deux phrases. Évaluer d'abord l'incertitude, la transversalité, le risque de régression, la nouveauté architecturale et la qualité des patterns disponibles, jamais le seul nombre de fichiers.
6. Si `docs/codex/ACTIVE_TASK.md` n'existe pas, le créer à partir de
   docs/codex/ACTIVE_TASK.template.md.
7. Remplir `docs/codex/ACTIVE_TASK.md` avec la date, le système, l'objectif, la définition de terminé, le niveau et sa justification, la photographie Git complète, le périmètre, les entrées probables, les risques d'autorité serveur et le plan.
8. Avant le plan, afficher :

   ```text
   Niveau de raisonnement recommandé : <Moyen | Élevé | Très élevé>

   Justification : <une ou deux phrases>
   ```

   Si le niveau sélectionné dans l'application est réellement visible, signaler seulement un écart manifeste et demander son ajustement avant mise en œuvre lorsqu'il est clairement sous-dimensionné ou très surdimensionné. S'il n'est pas visible, ne pas prétendre le connaître : afficher la recommandation puis présenter le plan afin que l'utilisateur puisse ajuster le réglage avant de continuer.
9. Présenter ce plan court à l'utilisateur avant toute modification de code.

## Référentiel de recommandation

- `Moyen` : modification mécanique ou localisée ; valeur, configuration, texte, identifiant d'asset ou i18n ; documentation ou handoff ; cause et fichiers déjà connus ; ajustement visuel sans architecture ; application d'un pattern existant sans impact transverse.
- `Élevé` : feature complète fondée surtout sur les patterns existants ; personnage, arme ou UI sur l'infrastructure actuelle ; intégration dans plusieurs fichiers connus ; débogage borné sur plusieurs fichiers ; service aux dépendances identifiées ; risque de régression modéré et contrôlable.
- `Très élevé` : architecture ou refonte transverse ; nouveau pipeline central ; cause inconnue répartie entre systèmes ; plusieurs services partagés critiques ; migration importante ; contrat structurant ; arbitrage complexe entre sécurité, performances, compatibilité et dette ; risque de dégrader plusieurs systèmes déjà maîtrisés.

Ne jamais recommander `Très élevé` par précaution générale ni parce que l'utilisateur l'utilise habituellement. Une feature volumineuse fondée sur des patterns éprouvés peut rester `Élevé` ; une petite modification de contrat partagé critique peut être `Très élevé`. En cas d'hésitation, choisir le niveau inférieur sauf risque produit ou architectural clairement identifié.

## Réévaluation

Si l'exploration révèle un changement de nature réel — feature locale devenue refonte transverse, rupture de contrat partagé ou migration importante — interrompre avant la modification structurante, expliquer brièvement le changement, recommander le nouveau niveau et attendre la décision de l'utilisateur. Ne pas interrompre pour une variation mineure de complexité.

Appliquer les politiques référencées par `AGENTS.md` sans les recopier dans ce skill.
