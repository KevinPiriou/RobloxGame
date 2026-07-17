# Charte de pilotage du chantier Performance P0 a P12

Statut : active a partir du 2026-07-17 07:48 Europe/Paris.

Cette charte gouverne la baseline P0 et toutes les phases ulterieures du
chantier Performance. Elle ne remplace pas les regles de securite ou
d'autorite serveur du projet : les degats, recompenses, drops et regles de
combat restent decideres cote serveur.

## Finalite du chantier

L'objectif n'est pas de rendre le code "plus optimise" de maniere abstraite.
L'objectif est de construire un jeu :

- mesurable et reproductible ;
- scalable sans introduire de comportement de combat divergent ;
- stable apres plusieurs runs ;
- compatible avec plusieurs niveaux graphiques ;
- defensible par une comparaison avant / apres ;
- modifie sans effet de gameplay non maitrise.

Une phase qui ne produit aucun gain significatif peut se terminer par
`Defer`, `Revert` ou `aucune modification retenue`. Ce n'est pas un echec :
c'est une decision fondee sur les donnees.

## Regles de preuve

1. L'agent commence par etablir ce qui est mesure, connu et encore incertain.
   Il ne commence pas par annoncer une optimisation.
2. Toute modification significative exige un etat de reference comparable.
3. Toute affirmation de gain exige une mesure avant / apres, avec le meme
   scenario, la meme seed lorsque possible, le meme environnement et des
   repetitions suffisantes.
4. Les cas reels simples et le smoke manuel canonique priment sur un test
   synthetique vert. Une campagne de mesures ne peut pas masquer une
   degradation visible du jeu.
5. Les preferences graphiques manuelles du joueur sont un plafond de qualite.
   Elles ne forcent pas le maintien d'effets couteux si une degradation grave
   est constatee ; toute adaptation doit cependant preserver la lisibilite du
   combat et etre signalee.
6. Les changements de rendu ou de sensation doivent etre signales au
   responsable produit avant validation definitive.
7. Une dependance externe, une bibliotheque de type Maid, Octree, Packet,
   Sera ou equivalente n'est jamais une optimisation par elle-meme. Son cout,
   son role et le gain attendu doivent etre demontres avant adoption.
8. Les systemes existants ne sont pas reecrits integralement si une evolution
   progressive, mesurable et reversible suffit.
9. Lorsqu'une API Roblox, une limite moteur ou une bibliotheque est incertaine,
   une recherche ciblee est autorisee. La conclusion doit etre reliee au
   probleme du projet et sourcee, jamais recopier une recommandation generique.

## Hierarchie des artefacts

1. Le document `audit_2026-07-17_063729_p0_baseline_observabilite.md`
   decrit le protocole, l'arene et les limites de P0.
2. Ce document fixe le contrat transversal de pilotage et le journal.
3. Chaque phase terminee produit un fichier
   `post_audit_YYYY-MM-DD_HHMMSS_performance_pN_nom.md`.
4. Chaque entree de resultat est ajoutee a la fin du journal ci-dessous. Les
   entrees anterieures ne sont jamais modifiees ni remplacees.

## Format obligatoire du rapport de phase

Chaque `post_audit` Performance reprend exactement cette structure :

```md
# Pn - Nom de la phase

## Etat initial
Commit :
Scenario :
Mesures :

## Hypothese
Quel cout est suspecte ?
Pourquoi ?

## Protocole
Comment la comparaison est-elle rendue reproductible ?

## Modification etudiee
Description technique :
Fichiers concernes :
Risques :

## Resultats
Avant :
Apres :
Variance :
Regression :

## Decision
Keep / Adjust / Revert / Defer

## Conclusion
Gain demontre :
Limites :
Etape suivante :
```

Le rapport doit aussi declarer le budget de complexite de la phase :
complexite ajoutee, reduite ou seulement deplacee. Une phase qui ajoute de la
complexite sans gain utilisateur mesurable est rejetee.

## Journal versionne append-only

Chaque entree ajoutee a la suite de cette section contient au minimum :

- phase ;
- commit avant et commit apres ;
- scenario ;
- appareil ou environnement ;
- mesures avant et apres ;
- ecart et variance ;
- decision ;
- commentaires, y compris regressions et angles morts.

### Entree J-000 - P0 baseline - en attente

- Phase : `P0.5 - campagne initiale`.
- Commit avant : a relever juste avant la premiere repetition.
- Commit apres : identique au commit avant, puisque la baseline ne modifie
  pas le code.
- Scenario : `monsters_25`, `monsters_100`, `monsters_250`, `monsters_500`,
  `monsters_1000`, `projectiles_24`, `collectibles_300`.
- Environnement : Studio et appareil reel a renseigner, avec resolution,
  profil graphique, qualite VFX et date.
- Mesures avant / apres : non applicable pour la baseline ; la baseline sera
  le referentiel `avant` des phases suivantes.
- Ecart / variance : a calculer apres trois repetitions minimum par scenario.
- Decision : `Pending`.
- Commentaires : P0 ne peut pas etre clos avant une serie de mesures serveur,
  client, memoire et une capture reseau MicroProfiler par environnement.

## Criteres de fermeture P0

P0 est ferme uniquement lorsque l'entree J-000 est completee par des donnees
reelles, que la variance est connue et que le smoke manuel canonique est
valide. Les scenarios synthetiques et le scenario de run a seed fixe doivent
alors etre etiquetes separement. Aucun passage vers P1 ne doit etre presente
comme valide tant que ce referentiel manque.

## Angles morts structurels

- Une baseline Studio ne prouve pas a elle seule le comportement publie.
- Une moyenne masque les pointes ; les P95, P99 et les freezes observes sont
  obligatoires dans les decisions.
- Une baisse de CPU serveur peut deplacer le cout vers GPU, reseau ou memoire.
  Une decision ne peut donc etre fondee sur une seule metrique.
- Un benchmark isole la charge, mais il ne remplace pas une verification de
  sensation de jeu en run reelle.

## Appendice chronologique - Requalification P0 locale le 2026-07-17 10:49 Europe/Paris

Le responsable produit a choisi de ne pas attendre la capture MicroProfiler
reseau ni trois campagnes integralement comparables avant de commencer P1.
Cette decision ne transforme pas retroactivement P0 en baseline complete.

### Entree J-000 - P0 baseline locale

- Phase : `P0-local`.
- Commit avant : `88c73ca` plus worktree P0 non committe.
- Commit apres : identique ; aucune optimisation runtime n'est incluse.
- Scenario : campagne P0 complete, avec reference canonique
  `P0C-7883142449-17802070`.
- Environnement : Studio local, un joueur, seed `17072026`, VFX adaptatifs
  verrouilles pendant la mesure.
- Mesures de reference : frame P95 client / tick monstre P95 de
  `7,57 / 1,16 ms` a 25, `9,13 / 6,47 ms` a 100,
  `28,79 / 20,69 ms` a 250, `69,78 / 52,51 ms` a 500 et
  `185,12 / 134,31 ms` a 1 000.
- Ecart / variance : seconde campagne coherente pour les monstres et les
  collectibles ; `projectiles_24` exclu, car non comparable.
- Decision : `Keep - P0-local clos ; P0-complet defer`.
- Commentaires : le reseau, la variance globale et la memoire residuelle sont
  reportes dans `todo_2026-07-17_performance_p0_observabilite_reportee.md`.

P1 est autorise uniquement dans le perimetre CPU/frame local soutenu par cette
baseline. Toute affirmation sur le reseau, la memoire de longue duree ou la
performance publiee devra reouvrir les travaux P0-complet.
