# P3 - Projectiles et bande passante

Date de cloture : 2026-07-18 16:40 Europe/Paris

## Etat initial

Commit : `a940990` avant le chantier ; les modifications P3 restent dans le
working tree au moment de cette cloture, en attente du commit utilisateur.

Scenario : `projectiles_isoles_24`, huit cibles fixes, 24 tirs par seconde,
2 128 tirs emis, puis la variante `projectiles_isoles_24_client_pilot` avec
le meme seed, la meme cadence et le meme volume. Le smoke manuel final a ete
effectue en run Studio solo avec des spawns debug repetes de 100 ennemis.

Mesures de reference P3.0 :

- `WeaponService` P95 : `1.10 ms` ;
- envoi serveur P95 : `320.05 Kbps` ;
- transforms repliques : `819 872` ;
- particules, lumieres et trails actifs P95 : `210`, `54`, `66` ;
- frame client P95 : `8.32 ms`.

## Hypothese

Le cout dominant ne venait pas des degats ni de la recherche spatiale, mais
des transforms de noyaux Fireball repliques continuellement depuis le serveur.
Le serveur pouvait conserver le calcul autoritaire et remplacer uniquement la
presentation du proprietaire par un noyau local cree et termine sur ordre
serveur fiable.

## Protocole

Les deux scenarios utilisent les memes huit cibles, le meme seed, la meme
cadence et le meme nombre de tirs. Les mesures sont retenues seulement lorsque
la fenetre Studio reste focalisee. La comparaison VFX utilise un tag local
`MegaRobloxProjectileVfx`, commun aux deux presentations, et distingue les
elements alloues des elements reels actifs.

Le smoke canonique final complete la campagne : run solo, vagues reelles,
spam du bouton admin de spawn par lots de 100, projectiles, ennemis et
collectibles simultanes. Il verifie les degats, impacts, recyclages et la
stabilite percue ; il ne remplace pas le benchmark isole.

## Modification etudiee

Description technique :

- le serveur conserve etat, homing, collisions, impacts, degats, rebonds,
  duree de vie et recyclage de chaque projectile ;
- le pilote `ClientPilot` garde le template logique dans
  `ServerStorage/ProjectileSimulation`, hors replication des transforms ;
- creation, rebond et destruction sont des messages fiables bornes sur le
  remote VFX existant ;
- le client simule uniquement la presentation locale et applique le meme
  `CombatConfig` que le serveur ;
- l'interrupteur admin `P3 : pilote client` reste limite au solo et desactive
  par defaut. Le chemin normal demeure `ReplicatedCore`.

Fichiers concernes : `WeaponService`, `ProjectileVisualService`,
`ProjectileVfxController`, `PerformanceBenchmarkService`,
`PerformanceBenchmarkClient`, `VfxConfig`, `AdminService` et `AdminUI`.

Risques : divergence visuelle sur cible mobile, correction de rebond, noyaux
locaux residuels, visibilite des projectiles des autres joueurs et changement
involontaire de la logique de combat. Les deux derniers points sont isoles par
le mode solo non actif par defaut.

## Resultats

| Mesure | Avant, noyau replique | Apres, pilote local | Ecart |
| --- | ---: | ---: | ---: |
| Tirs emis | 2 128 | 2 128 | 0 % |
| Transforms repliques | 819 872 | 0 | -100 % |
| Pas logiques serveur | 819 872 | 802 194 | -2.2 %, variance |
| Tick `WeaponService` P95 | 1.10 ms | 0.24 ms | -78.2 % |
| Envoi serveur P95 | 320.05 Kbps | 18.27 Kbps | -94.3 % |
| Frame client P95 | 8.32 ms | 7.88 ms | pas de regression |
| Particules actives P95 | 210 | 209 | parite pratique |
| Lumieres actives P95 | 54 | 54 | identique |
| Trails actifs P95 | 66 | 65 | parite pratique |

Variance : impacts et expirations restent dans la dispersion deja observee
sur les repetitions (`1 692 / 380` contre `1 678 / 400`). Le pool reste
fonctionnel : 2 128 projectiles recycles dans les deux cas, avec seulement
deux clones dans le pilote chaud.

Smoke final : les logs montrent des lots debug cumules jusqu'a 270 demandes,
environ 50 projectiles actifs, plus de 400 gemmes suivies et aucun avertissement
de combat, de VFX ou de cycle projectile. Le produit est reste jouable selon
le testeur. Des pics client de 127 a 302 ms subsistent dans la session ; ils
ne sont pas correles de maniere suffisante aux projectiles et ne sont pas
masques par cette cloture.

Regression : aucune regression de degats, d'impacts, de recyclage ou de rendu
VFX n'a ete constatee dans les scenarios comparables et le smoke solo.

## Decision

Keep pour l'architecture et le pilote solo de P3. Defer pour l'activation
globale de `ClientPilot` en production multijoueur.

## Conclusion

Gain demontre : la replication continue des transforms etait bien le cout
dominant du scenario Fireball isole. Le pilote local elimine cette charge sans
deplacer l'autorite de combat hors serveur et sans reduire artificiellement la
densite VFX du joueur.

Limites : aucune preuve a deux clients, aucune mesure de perte ou de retard
reseau, et aucune presentation definie pour les projectiles appartenant a un
autre joueur. Les pics client de run reelle restent un sujet d'observabilite
pour une phase ulterieure.

Etape suivante : ouvrir la phase P4 choisie par le responsable produit. La
future migration multijoueur du pilote P3 devra commencer par le todo associe,
pas par l'activation implicite du flag solo.

## Classification de cloture

Juste : P3 est clos comme chantier de mesure et de reduction du cout de
representation des projectiles. Le gain reseau et CPU est quantifie et le
chemin normal reste reversible.

Contestable : qualifier le smoke de preuve de performance globale serait trop
large ; il valide la stabilite produit en solo sous charge, pas chaque appareil
ni chaque topologie reseau.

Simplification : aucun package de buffers, de serialization ou de transport
non fiable n'est retenu. Supprimer les transforms repliques traite directement
la cause mesuree.

Angle mort : le multijoueur est volontairement reporte et reste bloquant avant
toute bascule globale du pilote.

## Addendum - Promotion production solo - 2026-07-18 16:52 Europe/Paris

Le responsable produit a confirme que les runs actuelles sont strictement
solo. Il n'existe donc pas de spectateur de projectile pendant une run : la
limite de presentation des projectiles d'autrui ne bloque pas ce produit tel
qu'il existe aujourd'hui.

La production bascule donc par defaut vers `ClientPilot` via
`CombatConfig.ProjectilePresentationMode`. Le serveur reste seul responsable
de la trajectoire, du homing, des rebonds, des collisions, des degats, des
recompenses, de la duree de vie et du recyclage. Le client ne recoit que les
ordres fiables et bornes de creation, retarget, impact et destruction de son
propre projectile visuel.

L'ancien interrupteur admin de P3 est retire : il devenait une seconde verite
de production inutile. Le rollback demeure explicite et localise : fixer
`ProjectilePresentationMode` a `ReplicatedCore` restaure les noyaux repliques.
Le scenario P3.0 de reference fixe lui-meme `ReplicatedCore`, afin de garder
la comparaison historique valide malgre le nouveau defaut de jeu.

Le todo multijoueur associe est conserve comme archive de decision pour le
jour ou un mode cooperatif sera introduit. Il ne constitue plus une dette
bloquante pour les runs solo.

Statut de cet addendum : build Rojo, `git diff --check` et recherche de
conflits valides ; smoke canonique de production solo encore requis avant de
qualifier cette promotion de definitivement validee.

## Append - Smoke production solo valide - 2026-07-18 16:57 Europe/Paris

Le responsable produit a lance une run solo normale, sans cliquer ni activer
de commande P3. Le chemin de production passe directement par
`CombatConfig.ProjectilePresentationMode = "ClientPilot"` ; l'ancien attribut
et son remote admin n'existent plus.

Le log de run confirme la creation et le nettoyage normaux : entre un et quatre
projectiles actifs pendant le combat, puis `Active=0`, `ActiveVolleys=0`,
`PendingVolleyShots=0` et `Pool=24` apres le combat. Aucun avertissement de
combat, de VFX ou de cycle projectile ne figure dans la capture. La fin de run
ramene aussi les monstres a `Alive=0`, les collectables a `Tracked=0` et le
pool monstre a `33` instances reutilisables.

Decision : `Keep`. La promotion `ClientPilot` est validee pour les runs solo
actuelles. La cloture P3 est donc complete dans ce perimetre.

Angle mort conserve : trois pics client de `153`, `278` et `126 ms` ont ete
releves pendant la session. Ils ne sont pas correles aux projectiles par ce
log et ne doivent pas etre attribues a P3. Ils restent une piste de mesure
pour une future phase, pas une regression masquee par cette cloture.
