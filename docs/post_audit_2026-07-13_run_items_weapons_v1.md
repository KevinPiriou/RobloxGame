# 2026-07-13 03:16 CEST - Objets de run et premier panneau d'armes

## Perimetre realise

Les coffres ne reposent plus sur une liste de recompenses placeholder. Ils proposent maintenant les deux premiers objets de run definis dans `src/shared/RunItemConfig.luau` :

- Camembert : chaque stack ajoute 5% de chance d'empoisonner une cible lors d'un impact d'arme valide par le serveur ;
- EnergyDrink : chaque stack ajoute 5% de vitesse de deplacement et 5% de vitesse d'attaque.

Les deux objets sont propres a une run. Ils sont remis a zero a la fin de run avec les perks, XP et coins de run.

## Contrat de poison

Chaque proc de Camembert cree un effet de poison independant. Plusieurs procs sur le meme monstre restent donc actifs et tickent separement.

Les reglages V1 sont centralises dans `RunItemConfig` :

- chance par stack : 5% ;
- duree de base : 4 secondes ;
- tick : 1 seconde ;
- degats par tick : 4.

Le perk `Duree des attaques` augmente la duree de chaque poison via `PerkService.GetEffectDuration`. Les ticks affichent un flash vert sur le monstre, alors que les impacts directs gardent le flash rouge existant.

La simulation et les degats restent serveur. Un identifiant runtime est attribue a chaque monstre pour qu'un poison ne puisse jamais continuer sur une instance recyclee par le pool.

## Affichage joueur

- le reel des coffres affiche l'icone reelle de chaque objet pendant le tirage ;
- apres validation, le coffre confirme le stack obtenu ;
- le panneau Statistiques de run affiche Camembert et EnergyDrink avec leur valeur `xN` pendant les pauses.

## Premier panneau d'armes

L'onglet Armes du lobby utilise desormais un double panneau :

- a gauche : Fireball et son icone de base ;
- a droite : les apparences de projectile classique et Boule de feu arcanique avec les images fournies ;
- le choix est actuellement un apercu local de l'interface.

Les assets de skin sont centralises dans `src/shared/WeaponSkinConfig.luau` pour preparer la future persistance et les offres Robux.

## Contrat explicitement non realise

- le choix de skin n'est pas encore persiste ;
- le choix de skin ne remplace pas encore le modele ou VFX 3D de Fireball en run ;
- aucun achat Robux n'est ajoute pour ces skins, car aucun ProductId ni contrat d'ownership n'est encore defini.

Ces limites evitent de presenter comme achetable ou equipe un contenu qui ne dispose pas encore de l'asset de projectile correspondant.

## Validation technique

- `rojo build -o $env:TEMP\\TestRoblox-run-items-weapons-final.rbxlx` termine avec succes ;
- `git diff --check` ne remonte pas d'erreur de contenu ;
- aucun marqueur de conflit Git n'est present dans `src` ou `docs`.

## Smoke manuel canonique bloquant

1. Depuis le lobby, ouvrir Deblocages puis Armes : Fireball et les deux visuels de projectile doivent etre visibles et selectionnables.
2. Lancer une run, ouvrir un coffre et verifier que Camembert ou EnergyDrink apparait avec son icone pendant le reel.
3. Valider deux exemplaires d'EnergyDrink : mettre en pause et verifier les valeurs de vitesse de deplacement et de vitesse d'attaque, ainsi que `EnergyDrink x2`.
4. Valider un ou plusieurs Camemberts : attaquer une cible assez longtemps et verifier des ticks de degats verts apres des impacts Fireball.
5. Pendant un poison actif, terminer une run puis en lancer une autre : verifier que le panneau de stats revient a `x0` et qu'aucun tick ne subsiste sur les monstres de la nouvelle run.

## Angles morts et budget de complexite

- Contestable : les valeurs de poison sont des reglages V1, pas un equilibrage final. Elles sont volontairement dans un module de configuration court.
- Angle mort : le poison n'a pas encore de VFX ou particule dediee ; le flash vert rend les ticks observables sans ajouter de nouvel asset 3D.
- Juste : la passe ajoute un service de run cible et une petite extension de l'interface, sans toucher aux maps ni aux regles de spawn.

## Addendum - 2026-07-13 03:33 CEST - Visuel Fireball V1

La Fireball est maintenant mise en forme au moment de sa creation par `ProjectileVisualService`. Le service travaille sur le projectile clone et ses enfants existants, sans demander de modifier le modele source dans Studio :

- coeur Neon orange, plus opaque et plus lumineux ;
- trainage court rouge-orange, ajoute seulement s'il n'existe pas deja ;
- lumiere ponctuelle chaude autour du projectile ;
- particules Fire, Smoke et Sparkles recolorees et ralenties pour mieux separer le coeur, les etincelles et la fumee ;
- VFX classique et arcane centralises dans `WeaponSkinConfig`.

Le pool ne reconfigure pas le projectile a chaque tir : le skin applique est memorise sur l'instance recyclee. Les degats, la hitbox, la cadence et les regles de collision ne sont pas modifies par cette passe.

## Validation technique de l'addendum

- `rojo build -o $env:TEMP\TestRoblox-fireball-visual-v1.rbxlx` termine avec succes ;
- `git diff --check` ne remonte pas d'erreur de contenu.

## Smoke manuel a faire dans Studio

1. Lancer une run et observer plusieurs Fireballs en mouvement : le coeur doit rester lisible, orange et Neon.
2. Verifier que le trainage part bien derriere la boule et ne traverse pas visuellement le projectile.
3. Observer un tir devant un fond clair puis sombre : la fumee doit rester discrete et les etincelles ne doivent pas masquer le coeur.
4. Verifier que le comportement de combat reste identique : cadence, impacts et degats ne doivent pas changer.

## Angles morts de l'addendum

- Angle mort : le rendu final depend aussi des textures, tailles et emissions deja presentes dans le template Fireball Studio. Cette passe les harmonise mais ne remplace pas encore leurs textures par un VFX entierement nouveau.
- Simplification : aucun VFX d'impact dedie n'est ajoute ici. Le chantier reste limite au projectile en vol pour eviter de melanger rendu et gameplay.

## Addendum - 2026-07-13 04:06 CEST - Comportement Fireball et skins V1

La Fireball devient une arme a trajectoire guidee plutot qu'un projectile strictement rectiligne :

- vitesse native ramenee de 100 a 58 ;
- duree de vie portee a 3,8 secondes pour garder une marge pendant les virages ;
- quatre profils de vol donnent un depart lateral ou montant, puis une convergence progressive vers la cible ;
- la direction verticale est limitee pour eviter qu'un projectile parte sous la map ;
- la vitesse de projectile reduit la duree de la courbe et augmente la reactivite du guidage.

Lors d'une salve, les projectiles couvrent les ennemis proches tries par distance. Un second projectile vise donc une autre cible tant qu'il en reste une ; au-dela du nombre de cibles, la salve recommence a les concentrer.

Chaque impact cree aussi une petite sphere Neon qui s'etend puis disparait. Les spheres sont retournees dans un pool serveur tres court au lieu d'etre detruites a chaque contact.

## Vitesse et objets de run

EnergyDrink garde ses bonus existants et ajoute maintenant `+5% vitesse projectile` par stack. Le bonus passe par les statistiques de perk existantes : il est donc applique serveur, cumule avec les perks, et visible dans la ligne `Vitesse projectile` du panneau de statistiques.

## Skin arcane actif

Le choix de skin dans le panneau Armes envoie desormais une demande au serveur. `WeaponSkinService` n'accepte que les IDs declares et les skins starter, puis stocke le choix dans l'attribut serveur de session `FireballSkinId`. Les Fireballs suivantes utilisent donc aussi les couleurs arcaniques lorsque le joueur selectionne `Boule de feu arcanique`.

La persistance des skins et la verification d'ownership pour les futurs skins Robux restent volontairement hors de cette passe.

## Assets PNG detoures

Les quatre fichiers de `assets/ui/object` ont ete traites sans regeneration : le damier clair opaque connecte aux bords est devenu transparent, tout en conservant les zones blanches internes aux objets.

`assets` n'est pas mappe par `default.project.json` et Rojo ne publie pas les images Roblox. Les PNG corriges doivent donc etre reimportes dans Creator Dashboard ou Studio, puis leurs nouveaux `rbxassetid` devront remplacer les IDs de configuration concernes.

## Validation technique de l'addendum

- `rojo build -o $env:TEMP\TestRoblox-fireball-behavior-v1.rbxlx` termine avec succes ;
- les quatre PNG contiennent maintenant des pixels transparents verifies ;
- `git diff --check` ne remonte pas d'erreur de contenu.

## Smoke manuel canonique bloquant

1. Lancer une run avec une seule cible proche : la Fireball doit faire une courbe visible, revenir sur la cible et ne pas descendre sous le sol.
2. Ajouter de la vitesse projectile : le projectile doit atteindre la cible plus vite et courber sur une duree plus courte.
3. Ajouter un EnergyDrink : la ligne `Vitesse projectile` doit augmenter de 58 a environ 61, puis continuer a augmenter par stack.
4. Ajouter plusieurs projectiles avec au moins trois monstres proches : chaque tir de la salve doit partir vers une cible differente.
5. Refaire le test avec moins de monstres que de projectiles : les tirs excedentaires doivent se concentrer sur les cibles existantes.
6. Selectionner `Boule de feu arcanique` dans le lobby, lancer une run, et verifier les couleurs violet/cyan ainsi que l'impact associe.

## Angles morts et budget de complexite

- Juste : le serveur garde l'autorite du ciblage, de la vitesse, des impacts et du choix de skin valide.
- Contestable : 58 de vitesse native et un angle maximal de 115 degres sont des valeurs de ressenti V1. Elles sont centralisees dans `CombatConfig` pour un equilibrage court apres le smoke.
- Angle mort : la selection arcane est une selection de session. Elle reviendra au skin classique apres reconnexion tant que le futur contrat de cosmethiques persistants n'existe pas.
- Simplification : aucun raycast ou prediction client n'est ajoute au guidage. Le clamp vertical et la convergence douce resolvent le besoin actuel sans creer un second systeme de trajectoire.
