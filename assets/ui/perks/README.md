# Icones de perks

Ces PNG sont les sources locales des icones de perk generees pour MegaRoblox.

## Import Roblox Studio

1. Importer les fichiers sans suffixe `-source` dans le gestionnaire d'assets Roblox Studio.
2. Copier les `rbxassetid` retournes par Roblox.
3. Renseigner les valeurs correspondantes dans `src/shared/PerkIconConfig.luau`.

Fichiers a importer :

- `perk-move-speed.png` -> `move_speed`
- `perk-jump-bonus.png` -> `jump_bonus`
- `perk-attack-speed.png` -> `attack_speed`
- `perk-projectile-count.png` -> `projectile_count`
- `perk-collect-radius.png` -> `collect_radius`
- `perk-damage-percent.png` -> `damage_percent`
- `perk-projectile-speed.png` -> `projectile_speed`
- `perk-effect-duration.png` -> `effect_duration`
- `perk-enemy-bounce.png` -> `enemy_bounce`
- `perk-crit-chance.png` -> `crit_chance`
- `perk-crit-multiplier.png` -> `crit_multiplier`
- `perk-life-steal.png` -> `life_steal`
- `perk-health-regen.png` -> `health_regen`
- `perk-shield.png` -> `shield`
- `perk-xp-gain.png` -> `xp_gain`
- `perk-gold-gain.png` -> `gold_gain`
- `perk-luck.png` -> `luck`
- `perk-armor.png` -> `armor`
- `perk-more-enemies.png` -> `more_enemies`
- `perk-flat-damage.png` -> `flat_damage`
- `perk-elite-flat-damage.png` -> `elite_flat_damage`

Les fichiers `-source.png` conservent le fond chroma d'origine. Les fichiers sans ce suffixe
ont deja un canal alpha et sont ceux a importer.
