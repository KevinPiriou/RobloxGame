# Auras VFX V2 - Compositions issues du pack Studio

Date : 2026-07-19 03:57 Europe/Paris

## Statut du chantier

Decision provisoire : `Adjust`.

La nouvelle architecture et les cinq compositions prioritaires sont integrees.
La compilation et la verification structurelle sont vertes. Le chantier n'est
pas encore clos : le smoke visuel dans une vraie run reste la preuve bloquante
pour valider la lisibilite, le gout artistique et le cout GPU reel.

## Etat initial

La V1 rendait deja les trois familles de statistiques dominantes, localement,
sans modifier le gameplay. Elle reposait cependant principalement sur des
`ParticleEmitter`, textures simples, offsets et formes assembles par code dans
`AuraController.client.luau`.

Cette approche etait utile pour prouver la mecanique, mais elle produisait des
effets souvent plats, generiques ou trop proches d'un nuage de particules. Les
familles `Protection` et `Magnetism` donnaient une direction visuelle plus
convaincante que `Mobility`, `AttackSpeed`, `Arsenal`, `Power` et `Sustain`.

## Objectif de la passe

- conserver la selection des trois statistiques dominantes et les paliers V1 ;
- conserver un rendu exclusivement local et sans autorite gameplay ;
- remplacer les visuels proceduraux des cinq familles prioritaires par de
  vraies compositions construites a partir du pack `Workspace/VFX PACK` ;
- pouvoir calibrer les combinaisons sans lancer une run ;
- laisser `Protection` et `Magnetism` inchanges pendant cette passe afin de
  preserver les deux references visuelles deja appreciees.

## Architecture retenue

### Contrat de composition Studio

Le dossier suivant est maintenant la source des cinq compositions :

```text
ReplicatedStorage
`-- VisualTemplates
    `-- AuraTemplates
        `-- CompositionTemplates
            |-- MobilityV2
            |-- AttackSpeedV2
            |-- ArsenalV2
            |-- PowerV2
            `-- SustainV2
```

Chaque composition contient des `Attachment` servant de sockets et des
`ParticleEmitter` clones depuis le pack VFX importe. Les attributs `TargetSlot`
indiquent la partie du rig visee : racine, torse, tete, mains, bras, pieds ou
jambes. Le controleur resout ces slots sur les rigs R15 et conserve des
fallbacks vers les noms R6 pertinents.

Pour ces cinq familles, aucun visuel n'est dessine par code. Le code cree ou
clone uniquement la structure necessaire pour attacher les compositions au
personnage. Les textures, formes, sequences, accelerations et couleurs
artistiques proviennent des emitters du pack Studio.

### Chargement runtime

`AuraConfig.luau` declare le nom de composition de chaque famille. Le client :

1. resout la composition demandee dans `CompositionTemplates` ;
2. clone chaque socket sur la partie correspondante du personnage ;
3. capture les proprietes originales de chaque emitter comme baseline ;
4. applique uniquement les multiplicateurs de tier, de score et de qualite ;
5. active les trois familles dominantes pendant la run ;
6. desactive et nettoie les instances a la sortie de run ou au respawn.

La couleur authored du pack est preservee lorsque l'attribut
`AuraPreserveColor` n'est pas explicitement desactive. Des attributs optionnels
permettent de calibrer un emitter sans modifier le controleur :

- `AuraRateMultiplier` ;
- `AuraSizeMultiplier` ;
- `AuraLifetimeMultiplier` ;
- `AuraSpeedMultiplier`.

### Compatibilite graphique

Les niveaux graphiques existants restent le plafond du rendu. Le controleur
continue d'appliquer `EffectsIntensity` et le multiplicateur de couche d'aura
du profil graphique. Aucun changement n'est apporte aux statistiques, aux
degats, aux remotes ou a la simulation serveur.

## Compositions produites

| Famille | Composition | Intention visuelle | Contenu |
| --- | --- | --- | --- |
| Mobilite | `MobilityV2` | jets directionnels cyan, bleu et blanc, brume et sillage ascendant aux pieds | 2 sockets, 8 emitters |
| Vitesse d'attaque | `AttackSpeedV2` | conduits lime/cyan/blanc, flux, eclairs, vent et filaments cinetiques aux mains | 2 sockets, 12 emitters |
| Arsenal | `ArsenalV2` | trois foyers d'arme asymetriques violet, magenta et cyan autour du haut du corps | 4 sockets, 16 emitters |
| Puissance | `PowerV2` | flammes corporelles rouge, orange, or et blanc, combustion centrale et montee d'energie | 8 sockets, 11 emitters |
| Sustain | `SustainV2` | courants emeraude, aqua, rose et blanc, enveloppe de regeneration et puits vital | 8 sockets, 13 emitters |

Total authored pour cette passe : 24 sockets et 60 `ParticleEmitter`.

Les sources reutilisees appartiennent notamment aux familles suivantes du pack :

- `Anime/Wind-01` et `Anime/Wind-02` ;
- `Anime/Charge-01` ;
- `Anime/Lighting-03` ;
- `Anime/Fire-01` ;
- `Anime/ForceField-01` ;
- `Anime/Water-02` ;
- `Anime/Shiny-01` ;
- `Auras/Fire-Aura-01` ;
- `Auras/Water-Aura-01` ;
- `Auras/RNG-Aura-02` et `Auras/RNG-Aura-03`.

Chaque emitter de composition possede un attribut `AuraSourcePath` commencant
par `Workspace.VFX PACK`. Les emitters stockes dans les templates restent
desactives ; ils ne deviennent actifs que sur le package runtime selectionne.

## Scene de calibration

`Workspace/AuraAuthoringPreview/Combinations` contient 56 mannequins, soit les
combinaisons de trois familles parmi les huit familles actuelles. Les cinq
compositions V2 ont ete reconnectees a chacun des mannequins concernes.

La scene permet de comparer simultanement :

- la silhouette et le volume de chaque composition ;
- les conflits de couleur entre trois familles ;
- les recouvrements au niveau du torse, des mains et des pieds ;
- la coherence de `Protection` et `Magnetism` avec les nouvelles familles.

`AuraAuthoringGuard.server.luau` retire cette scene de `Workspace` au runtime en
la deplacant dans `ServerStorage`. La calibration reste donc visible en mode
edition sans polluer une run ou le lobby.

## Fichiers et donnees concernes

- `src/shared/AuraConfig.luau` : contrat `CompositionTemplates`, association
  famille vers composition et multiplicateurs de base ;
- `src/client/AuraController.client.luau` : resolution des compositions,
  mapping des sockets vers le rig, capture des proprietes authored et pilotage
  par score, tier et qualite ;
- `src/server/AuraAuthoringGuard.server.luau` : isolation de la scene de
  calibration pendant l'execution ;
- donnees Studio sous
  `ReplicatedStorage/VisualTemplates/AuraTemplates/CompositionTemplates` ;
- scene Studio sous `Workspace/AuraAuthoringPreview/Combinations`.

## Validation effectuee

- `rojo build -o TestRoblox.rbxlx` : succes ;
- `git diff --check` : aucune erreur de contenu, avertissements de fin de ligne
  uniquement ;
- recherche de marqueurs de conflit : aucun marqueur detecte ;
- verification Studio : 60 emitters, tous relies au pack par `AuraSourcePath` ;
- verification Studio : aucun emitter de template laisse actif ;
- verification visuelle en edition sur les mannequins de combinaison.

## Smoke manuel canonique restant

1. Lancer une run sans bonus : aucune aura ne doit etre visible.
2. Faire dominer `Mobility` puis courir, sauter et rester immobile : le sillage
   doit lire comme une vitesse attachee aux pieds, sans cacher le terrain.
3. Faire dominer `AttackSpeed` : les mains doivent porter le signal principal,
   sans anneau plat colle au torse.
4. Faire dominer `Arsenal` : les trois foyers doivent rester asymetriques et ne
   pas former une sphere ou un disque face camera.
5. Faire dominer `Power` : les flammes doivent donner du volume sans blanchir le
   personnage ni masquer ses animations.
6. Faire dominer `Sustain` : les courants doivent suggerer regeneration et vie,
   sans etre confondus avec `Protection`.
7. Tester trois familles simultanees, notamment avec `Protection` ou
   `Magnetism`, puis verifier que la silhouette reste lisible.
8. Tester `PERFORMANCE`, `EQUILIBRE`, `QUALITE` et `EffectsIntensity = 0`.
9. Mourir, sortir de run et respawn : aucun socket ni emitter ne doit rester ou
   se dupliquer.

## Classification des constats

- [Juste] La separation gameplay/visuel est preservee. Les auras restent une
  interpretation locale de statistiques deja validees par le serveur.
- [Juste] Les cinq familles prioritaires emploient des effets authored issus du
  pack, au lieu de recreer leurs visuels par primitives codees.
- [Simplification] Un chargeur generique de compositions remplace la croissance
  d'une branche Lua particuliere par famille. Les differences artistiques
  vivent dans les templates Studio.
- [Contestable] Soixante emitters authored ne signifient pas soixante emitters
  actifs : seules trois familles dominantes peuvent etre actives. Le cout reste
  toutefois a mesurer sur les appareils cibles avant de qualifier la densite de
  raisonnable.
- [Angle mort] Les compositions Studio ne sont pas mappees par Rojo dans
  `default.project.json`. Elles doivent etre sauvegardees avec le place Roblox ;
  un build Rojo seul ne peut pas les reconstruire.
- [Angle mort] Les anciennes branches procedurales des cinq familles restent
  presentes mais inactives comme rollback. Les supprimer avant le smoke serait
  premature ; les conserver apres validation ajouterait une dette inutile.
- [Angle mort] La scene statique valide les volumes, pas la lecture en mouvement,
  le clipping avec les accessoires ni le cout GPU reel en camera de jeu.

## Budget de complexite et rollback

Cette passe deplace la complexite artistique du code vers les assets Studio et
ajoute un chargeur generique de compositions. Elle reduit la necessite de coder
chaque nouvelle aura, mais augmente la dependance au contenu du place.

Rollback immediat : retirer `CompositionTemplate` d'une famille dans
`AuraConfig.luau` pour retomber sur son ancienne branche procedurale. Apres un
smoke manuel valide, la direction recommandee est au contraire de supprimer les
branches devenues mortes et de conserver un seul rail de rendu par famille.

## Conclusion provisoire

Gain produit vise : meilleure identite artistique, volumes plus lisibles et
composition differenciee par axe de build, sans changement de gameplay.

Preuve obtenue : integration structurelle, source VFX controlee, calibration en
edition et build valides.

Preuve manquante : smoke reel en run et observation du cout GPU. Le chantier ne
doit pas etre declare clos avant cette validation.
