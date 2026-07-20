# TODO — MegaSeedValidator : smoke Studio du sas de seeds

Date : 2026-07-19 20:57:45

## Contexte

Le chantier d'integration de `MegaSeedValidator` a produit un sas serveur
deterministe, une verification de provenance et un repli explicite lorsque le
pool valide est indisponible. Les validations statiques et les tests locaux
sont verts.

Le responsable produit ouvre maintenant le chantier de fiabilisation de
`MetaBuildLab_v1`. Le smoke Roblox du sas de seeds reste donc volontairement
reporte ; il ne doit pas etre confondu avec une validation produit acquise.

## Restant a faire

- lancer plusieurs runs Studio sans forcer de seed ;
- verifier qu'une seed du pool valide est reservee puis liberee ;
- verifier le repli lorsque le fichier de pool est absent ou invalide ;
- verifier qu'aucun echec de generation ne laisse une session bloquee ;
- confirmer que les logs distinguent selection valide, repli et rejet ;
- ajouter la conclusion au document
  `post_audit_2026-07-19_194244_mega_seed_validator_integration_v1.md`.

## Proof of done manquant

Le chantier ne peut etre declare ferme qu'apres un smoke Studio canonique
reussi. Les tests Python et `rojo build` ne prouvent pas le cycle de vie reel
d'une run Roblox.
