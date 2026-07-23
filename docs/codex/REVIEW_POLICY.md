# Politique de revue et d'audit

Lire cette politique pour un audit explicite ou une revue d'architecture. Elle ne transforme pas un chantier courant en audit complet.

## Méthode

- Examiner d'abord le périmètre réel, les dépendances, les frontières de responsabilité et les preuves disponibles ; distinguer faits observés, inférences et éléments non vérifiés.
- Évaluer la sobriété des chemins critiques, la concentration de responsabilités, le sens des dépendances, l'isolement des sous-systèmes et la possibilité de retour à un comportement plus simple.
- Mesurer la valeur des validations par leur corrélation avec le comportement utilisateur. Une suite verte sans couverture des cas simples est une couverture incomplète, pas une preuve de qualité.

## Restitution

- Reformuler loyalement la position examinée avant de la critiquer. Séparer : `Juste`, `Contestable`, `Simplification`, `Angle mort` et `Faux` lorsque cette distinction améliore une décision.
- Donner les impacts, preuves, limites et priorité. Un problème qui compromet un cas canonique ou la sécurité produit est bloquant ; les autres écarts sont hiérarchisés sans dramatisation.
- Une revue signale les correctifs possibles mais ne les applique pas sans demande de modification distincte.
