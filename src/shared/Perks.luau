local Perks = {}

Perks.RarityOrder = {
	"Common",
	"Rare",
	"Epic",
	"Legendary",
}

Perks.Rarities = {
	Common = {
		DisplayName = "Commun",
		Color = Color3.fromRGB(80, 220, 120),
		Weight = 58,
	},
	Rare = {
		DisplayName = "Rare",
		Color = Color3.fromRGB(80, 155, 255),
		Weight = 28,
	},
	Epic = {
		DisplayName = "Epique",
		Color = Color3.fromRGB(185, 95, 255),
		Weight = 11,
	},
	Legendary = {
		DisplayName = "Legendaire",
		Color = Color3.fromRGB(255, 200, 75),
		Weight = 3,
	},
}

local function variant(description, stats)
	return {
		Description = description,
		Stats = stats,
	}
end

Perks.Definitions = {
	{
		Id = "move_speed",
		Name = "Vitesse de deplacement",
		Variants = {
			Common = variant("+8% vitesse de deplacement", { MoveSpeedPercent = 0.08 }),
			Rare = variant("+14% vitesse de deplacement", { MoveSpeedPercent = 0.14 }),
			Epic = variant("+22% vitesse de deplacement", { MoveSpeedPercent = 0.22 }),
			Legendary = variant("+35% vitesse de deplacement", { MoveSpeedPercent = 0.35 }),
		},
	},
	{
		Id = "jump_bonus",
		Name = "Saut supplementaire",
		Variants = {
			Common = variant("+10% puissance de saut", { JumpPercent = 0.1 }),
			Rare = variant("+20% puissance de saut", { JumpPercent = 0.2 }),
			Epic = variant("+35% puissance de saut", { JumpPercent = 0.35 }),
			Legendary = variant("+55% puissance de saut", { JumpPercent = 0.55 }),
		},
	},
	{
		Id = "attack_speed",
		Name = "Vitesse d'attaque",
		Variants = {
			Common = variant("+8% vitesse d'attaque", { AttackSpeedPercent = 0.08 }),
			Rare = variant("+16% vitesse d'attaque", { AttackSpeedPercent = 0.16 }),
			Epic = variant("+28% vitesse d'attaque", { AttackSpeedPercent = 0.28 }),
			Legendary = variant("+45% vitesse d'attaque", { AttackSpeedPercent = 0.45 }),
		},
	},
	{
		Id = "projectile_count",
		Name = "Nombre de projectiles",
		Variants = {
			Common = variant("+1 projectile", { ProjectileCount = 1 }),
			Rare = variant("+1 projectile et +5% degats", { ProjectileCount = 1, DamagePercent = 0.05 }),
			Epic = variant("+2 projectiles", { ProjectileCount = 2 }),
			Legendary = variant("+3 projectiles", { ProjectileCount = 3 }),
		},
	},
	{
		Id = "collect_radius",
		Name = "Rayon de recolte",
		Variants = {
			Common = variant("+2 studs de recolte XP/pieces", { CollectRadius = 2 }),
			Rare = variant("+4 studs de recolte XP/pieces", { CollectRadius = 4 }),
			Epic = variant("+7 studs de recolte XP/pieces", { CollectRadius = 7 }),
			Legendary = variant("+12 studs de recolte XP/pieces", { CollectRadius = 12 }),
		},
	},
	{
		Id = "damage_percent",
		Name = "Degats en %",
		Variants = {
			Common = variant("+10% degats", { DamagePercent = 0.1 }),
			Rare = variant("+20% degats", { DamagePercent = 0.2 }),
			Epic = variant("+35% degats", { DamagePercent = 0.35 }),
			Legendary = variant("+60% degats", { DamagePercent = 0.6 }),
		},
	},
	{
		Id = "projectile_speed",
		Name = "Vitesse des projectiles",
		Variants = {
			Common = variant("+10% vitesse projectile", { ProjectileSpeedPercent = 0.1 }),
			Rare = variant("+20% vitesse projectile", { ProjectileSpeedPercent = 0.2 }),
			Epic = variant("+35% vitesse projectile", { ProjectileSpeedPercent = 0.35 }),
			Legendary = variant("+60% vitesse projectile", { ProjectileSpeedPercent = 0.6 }),
		},
	},
	{
		Id = "effect_duration",
		Name = "Duree des attaques",
		Variants = {
			Common = variant("+10% duree des attaques", { EffectDurationPercent = 0.1 }),
			Rare = variant("+20% duree des attaques", { EffectDurationPercent = 0.2 }),
			Epic = variant("+35% duree des attaques", { EffectDurationPercent = 0.35 }),
			Legendary = variant("+55% duree des attaques", { EffectDurationPercent = 0.55 }),
		},
	},
	{
		Id = "enemy_bounce",
		Name = "Rebond sur ennemi",
		Variants = {
			Common = variant("+1 rebond projectile", { BounceCount = 1 }),
			Rare = variant("+2 rebonds projectile", { BounceCount = 2 }),
			Epic = variant("+3 rebonds projectile", { BounceCount = 3 }),
			Legendary = variant("+5 rebonds projectile", { BounceCount = 5 }),
		},
	},
	{
		Id = "crit_chance",
		Name = "Chance de critique",
		Variants = {
			Common = variant("+5% chance critique", { CritChance = 0.05 }),
			Rare = variant("+10% chance critique", { CritChance = 0.1 }),
			Epic = variant("+15% chance critique", { CritChance = 0.15 }),
			Legendary = variant("+25% chance critique", { CritChance = 0.25 }),
		},
	},
	{
		Id = "crit_multiplier",
		Name = "Multiplicateur critique",
		Variants = {
			Common = variant("+25% degats critique", { CritMultiplierBonus = 0.25 }),
			Rare = variant("+50% degats critique", { CritMultiplierBonus = 0.5 }),
			Epic = variant("+85% degats critique", { CritMultiplierBonus = 0.85 }),
			Legendary = variant("+125% degats critique", { CritMultiplierBonus = 1.25 }),
		},
	},
	{
		Id = "life_steal",
		Name = "Vol de vie",
		Variants = {
			Common = variant("+1% des degats infliges en PV", { LifeStealPercent = 0.01 }),
			Rare = variant("+2% des degats infliges en PV", { LifeStealPercent = 0.02 }),
			Epic = variant("+3.5% des degats infliges en PV", { LifeStealPercent = 0.035 }),
			Legendary = variant("+6% des degats infliges en PV", { LifeStealPercent = 0.06 }),
		},
	},
	{
		Id = "health_regen",
		Name = "Regeneration de vie",
		Variants = {
			Common = variant("+0.2 PV par seconde", { HealthRegen = 0.2 }),
			Rare = variant("+0.5 PV par seconde", { HealthRegen = 0.5 }),
			Epic = variant("+1 PV par seconde", { HealthRegen = 1 }),
			Legendary = variant("+2 PV par seconde", { HealthRegen = 2 }),
		},
	},
	{
		Id = "shield",
		Name = "Bouclier",
		Variants = {
			Common = variant("+5 bouclier", { Shield = 5 }),
			Rare = variant("+10 bouclier", { Shield = 10 }),
			Epic = variant("+20 bouclier", { Shield = 20 }),
			Legendary = variant("+40 bouclier", { Shield = 40 }),
		},
	},
	{
		Id = "xp_gain",
		Name = "Gain d'XP",
		Variants = {
			Common = variant("+10% XP gagnee", { XpGainPercent = 0.1 }),
			Rare = variant("+20% XP gagnee", { XpGainPercent = 0.2 }),
			Epic = variant("+35% XP gagnee", { XpGainPercent = 0.35 }),
			Legendary = variant("+60% XP gagnee", { XpGainPercent = 0.6 }),
		},
	},
	{
		Id = "gold_gain",
		Name = "Gain d'or",
		Variants = {
			Common = variant("+10% pieces gagnees", { GoldGainPercent = 0.1 }),
			Rare = variant("+20% pieces gagnees", { GoldGainPercent = 0.2 }),
			Epic = variant("+35% pieces gagnees", { GoldGainPercent = 0.35 }),
			Legendary = variant("+60% pieces gagnees", { GoldGainPercent = 0.6 }),
		},
	},
	{
		Id = "luck",
		Name = "Chance",
		Variants = {
			Common = variant("+5% chance", { Luck = 0.05 }),
			Rare = variant("+10% chance", { Luck = 0.1 }),
			Epic = variant("+18% chance", { Luck = 0.18 }),
			Legendary = variant("+30% chance", { Luck = 0.3 }),
		},
	},
	{
		Id = "armor",
		Name = "Armure",
		Variants = {
			Common = variant("-5% degats recus", { ArmorPercent = 0.05 }),
			Rare = variant("-10% degats recus", { ArmorPercent = 0.1 }),
			Epic = variant("-18% degats recus", { ArmorPercent = 0.18 }),
			Legendary = variant("-30% degats recus", { ArmorPercent = 0.3 }),
		},
	},
	{
		Id = "more_enemies",
		Name = "Plus d'ennemis",
		Variants = {
			Common = variant("+10% ennemis", { EnemyCountPercent = 0.1 }),
			Rare = variant("+20% ennemis", { EnemyCountPercent = 0.2 }),
			Epic = variant("+35% ennemis", { EnemyCountPercent = 0.35 }),
			Legendary = variant("+60% ennemis", { EnemyCountPercent = 0.6 }),
		},
	},
	{
		Id = "flat_damage",
		Name = "Degats bruts",
		Variants = {
			Common = variant("+2 degats bruts", { FlatDamage = 2 }),
			Rare = variant("+4 degats bruts", { FlatDamage = 4 }),
			Epic = variant("+7 degats bruts", { FlatDamage = 7 }),
			Legendary = variant("+12 degats bruts", { FlatDamage = 12 }),
		},
	},
	{
		Id = "elite_flat_damage",
		Name = "Degats bruts elite",
		Variants = {
			Common = variant("+4 degats bruts contre elites", { EliteFlatDamage = 4 }),
			Rare = variant("+8 degats bruts contre elites", { EliteFlatDamage = 8 }),
			Epic = variant("+14 degats bruts contre elites", { EliteFlatDamage = 14 }),
			Legendary = variant("+24 degats bruts contre elites", { EliteFlatDamage = 24 }),
		},
	},
}

return Perks
