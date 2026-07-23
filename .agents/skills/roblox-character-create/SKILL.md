---
name: roblox-character-create
description: Crée et intègre un nouveau personnage Roblox de bout en bout à partir d'un prompt court décrivant ses caractéristiques. Utiliser après, ou dans le même message que, roblox-session-start pour ajouter un personnage jouable, son arme, passif, assets, VFX, UI et i18n en réemployant les pipelines existants.
---

# Création d'un personnage Roblox

Appliquer `AGENTS.md` et les politiques `docs/codex/` référencées par ce guide. Ce Skill précise le flux personnage ; il ne duplique pas leurs règles.

## Préconditions et cadrage

1. Extraire du prompt, quand ils sont présents : nom, direction artistique, arme primaire et comportement d'attaque, passif et statistiques, condition de déblocage, assets, fonctionnalités différées et contraintes particulières.
2. Si `roblox-session-start` est explicitement invoqué dans le même message, ne pas exiger que `ACTIVE_TASK.md` soit déjà actif. Fournir au Skill de session le système concerné, l'objectif et une proposition de définition de terminé issue de ce cadrage ; le laisser initialiser la photographie Git et `ACTIVE_TASK.md` avant toute implémentation.
3. Si aucun chantier n'est actif et que `roblox-session-start` n'est pas invoqué dans le message courant, demander son invocation avant toute inspection ou modification de code.
4. Demander seulement ce qui bloque une décision irréversible : identité ou nom unique, contrat d'attaque primaire, ou décision produit sans défaut existant. Utiliser le pattern le plus proche pour les détails non fournis et annoncer ces hypothèses dans le plan.

## Inspection ciblée

1. Lire `docs/codex/PROJECT_MAP.md`, le handoff pertinent et les documents historiques les plus récents du personnage ou de l'arme comparable.
2. Inspecter seulement les entrées du pipeline existant : définitions et configurations shared, service serveur, contrôleur client, sélection de personnage, statistiques, arme et hit detection, VFX, UI et i18n.
3. Choisir et réemployer le pipeline déjà adapté. Ne pas créer un pipeline parallèle lorsqu'un chemin existant couvre le contrat demandé.

## Plan et définition de terminé

Présenter un plan court avant de modifier. Préparer une définition de terminé couvrant au minimum :

- sélection du personnage ;
- statistiques et passif ;
- arme et validation serveur ;
- VFX et assets ;
- UI et i18n ;
- absence de régression évidente sur le chemin comparable ;
- build Rojo et smoke Studio restant, avec leur statut réel.

## Intégration

1. Après la confirmation explicite suivant le checkpoint de `roblox-session-start`, réaliser l'intégration de bout en bout sans demander de validation intermédiaire, sauf blocage technique, MCP indisponible ou décision produit impossible à déduire.
2. Conserver côté serveur la validation des dégâts, cibles, statistiques, récompenses et progression. Réutiliser les patterns i18n du dépôt.
3. Pour les assets demandés, utiliser le MCP de génération/import effectivement disponible et intégrer le résultat dans le même chantier. Employer un chroma key pour les images à détourer, le template Roblox pour les vêtements UV, et vérifier échelle, orientation et attaches des armes. Si le MCP ou l'accès nécessaire manque, le déclarer comme blocage plutôt que simuler l'import.
4. Signaler les fonctionnalités différées, ne pas les implémenter hors périmètre et ne poser que les points d'extension nécessaires.

## Validation et état prêt

1. Exécuter les validations disponibles dans le périmètre et rapporter distinctement validation statique, build Rojo et smoke Studio, avec leur résultat réel ou leur absence d'exécution.
2. Ne pas créer le handoff final, ne pas réinitialiser `ACTIVE_TASK.md` et ne pas déclencher implicitement `roblox-session-close`.
3. Lorsque le personnage est prêt pour validation, terminé ou suspendu, rappeler simplement à l'utilisateur d'invoquer `$roblox-session-close`.
