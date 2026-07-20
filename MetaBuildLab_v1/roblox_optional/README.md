# Export Roblox vers Meta Build Lab

`BuildCatalogExporter.server.luau` lit les modules du projet et écrit un
snapshot JSON dans :

```text
ReplicatedStorage/BuildMetaExports/LatestJson
```

Le script n'altère pas le gameplay. Il doit être utilisé ponctuellement pour
rafraîchir le catalogue du laboratoire.

## Modules exportés

- `CombatConfig`
- `Perks`
- `RunItemConfig`
- `BuildMetaConfig`

`BuildMetaConfig` est le contrat extensible pour les personnages et les armes.
Un futur contenu absent de ce module ne peut pas être inventé de manière fiable
par l'outil Python.

## Procédure

1. Vérifier que Rojo a synchronisé les modules dans `ReplicatedStorage`.
2. Exécuter le script exporteur côté serveur dans Studio.
3. Copier `LatestJson` dans un fichier local UTF-8.
4. Depuis `MetaBuildLab_v1`, exécuter :

```powershell
py -3 meta_build_lab.py import-roblox `
  --export mon_export_roblox.json `
  --output catalogs/current_project.json
```

5. Vérifier la preuve de provenance :

```powershell
py -3 meta_build_lab.py doctor
py -3 -m unittest discover -s tests -v
```

L'import échoue si `BuildMetaConfig` manque, si sa version est inconnue ou si
le catalogue généré contient un effet non modélisé. C'est un garde-fou : aucun
contenu ne doit être accepté puis ignoré silencieusement.
