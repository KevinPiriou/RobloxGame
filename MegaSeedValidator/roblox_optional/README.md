# Parité Python ↔ Roblox

1. Copier `PortableRandom.luau` dans `src/shared/PortableRandom.luau`.
2. Dans `src/server/ProceduralMapService.luau`, ajouter :

```luau
local PortableRandom = require(Shared:WaitForChild("PortableRandom"))
```

3. Remplacer :

```luau
local random = Random.new(seed + 413)
local styleRandom = Random.new(seed + 977)
```

par :

```luau
local random = PortableRandom.new(seed + 413)
local styleRandom = PortableRandom.new(seed + 977)
```

Cette modification doit être versionnée comme une rupture du générateur. Elle
change le résultat des anciennes seeds.
