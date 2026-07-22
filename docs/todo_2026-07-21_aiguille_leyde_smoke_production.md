# Aiguille de Leyde - Smoke de production restant

## 2026-07-21 20:43:41 +02:00 - Validation produit reportee apres activation

L'activation en production de l'Aiguille de Leyde a ete autorisee avant la
derniere passe de smoke visuel complete. Cette dette est volontairement
explicite : elle ne doit pas etre absorbee par une future passe d'equilibrage.

## Cas a verifier

1. rayon de base : zone visible, un eclair, une application de degats par
   cible ;
2. rayon maximal : cinq eclairs repartis dans la zone agrandie ;
3. rebond : arc Lightning visible entre cibles distinctes, sans double degat
   sur une cible deja resolue par le meme impact ;
4. HUD : icone de l'arme, niveau et dock sans regression avec Fireball.

## Condition de fermeture

Un Play Test de run normale valide les quatre cas sans anomalie visuelle,
collision, ciblage ou accumulation de degats inattendue. Le resultat devra
etre ajoute en append-only au post-audit de livraison.
