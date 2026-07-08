# TODO run/lobby et reset de run

## 2026-07-08 04:11:35 +02:00 - Dette bloquante avant lobby/procgen

### Restant a faire

- Creer une separation claire entre lobby et run.
- Introduire un etat de run serveur explicite.
- Reset XP, niveau de run, perks temporaires et coins de run a la mort.
- Reset XP, niveau de run, perks temporaires et coins de run a la victoire.
- Teleporter le joueur vers le lobby apres mort ou victoire.
- Remplacer le leaderstat de niveau de run par une progression de run non permanente.
- Ajouter une progression permanente `niveaux valides`.
- Clarifier le compteur de kills permanent vs kills de run.
- Faire en sorte que les classements globaux utilisent seulement kills et niveaux valides.

### Non-objectifs immediats

- Ne pas ajouter de generation procedurale maintenant.
- Ne pas ajouter de boss maintenant.
- Ne pas ajouter de boutique ou microtransactions maintenant.
- Ne pas creer une deuxieme monnaie permanente tant que la boucle run n'est pas stable.

### Proof of done attendu plus tard

- Mourir remet XP, niveau et coins de run a zero.
- Gagner remet XP, niveau et coins de run a zero.
- Le joueur revient au lobby apres mort ou victoire.
- Les coins de run ne survivent pas a la run.
- Le classement n'affiche pas le score quiz.
