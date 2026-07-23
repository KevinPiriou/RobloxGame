--!strict

local CombatConfig = require(script.Parent:WaitForChild("CombatConfig"))

local WeaponConfig = {}

WeaponConfig.Categories = {
	Projectile = true,
	Melee = true,
	Zone = true,
	Orbital = true,
	Invocation = true,
}

WeaponConfig.Definitions = {
	fireball = {
		Id = "fireball",
		Name = "Boule de feu",
		NameKey = "weapon.fireball.name",
		Category = "Projectile",
		Lifecycle = "Production",
		Icon = "rbxassetid://91848234123005",
		Base = {
			Damage = CombatConfig.FireballDamage,
			Cooldown = CombatConfig.FireballCooldown,
			Range = CombatConfig.FireballRange,
		},
		Caps = {
			ProjectileCount = 24,
			BounceCount = 12,
		},
	},
	leyden_needle = {
		Id = "leyden_needle",
		Name = "Aiguille de Leyde",
		NameKey = "weapon.leyden_needle.name",
		Category = "Zone",
		Lifecycle = "Production",
		Icon = "rbxassetid://71972739531178",
		VfxProfileId = "LeydenNeedleZone",
		Base = {
			Damage = 32,
			Cooldown = 4.5,
			Range = 72,
			ZoneRadius = 14,
			ChargeDuration = 1.15,
			StrikeCount = 1,
			BounceRange = 20,
		},
		Caps = {
			ZoneRadius = 26,
			StrikeCount = 5,
			BounceCount = 8,
			MinimumCooldown = 0.7,
		},
		Rules = {
			UsesProjectileCount = false,
			UsesBounceCount = true,
			UsesEffectDuration = false,
			SnapshotTargetPosition = true,
		},
	},
	shuriken = {
		Id = "shuriken",
		Name = "Shuriken",
		NameKey = "weapon.shuriken.name",
		Category = "Projectile",
		Lifecycle = "Production",
		Icon = "rbxassetid://82295159291408",
		VfxProfileId = "ShurikenCone",
		Base = {
			Damage = 17,
			Cooldown = 1.1,
			Range = 72,
			ProjectileCount = 3,
			ProjectileSpeed = 100,
			Lifetime = 1.05,
			HitRadius = 2.75,
			ConeAngleDegrees = 30,
		},
		Caps = {
			ProjectileCount = 24,
			MinimumCooldown = 0.25,
		},
		Rules = {
			UsesProjectileCount = true,
			UsesBounceCount = false,
			UsesEffectDuration = false,
			RequiresProjectileBase = true,
			Homing = false,
		},
	},
	soul_lantern = {
		Id = "soul_lantern",
		Name = "Lanterne des ames",
		NameKey = "weapon.soul_lantern.name",
		Category = "Invocation",
		Lifecycle = "Production",
		Icon = "rbxassetid://97347879630224",
		VfxProfileId = "SoulLanternSummon",
		Base = {
			Damage = 22,
			Cooldown = 2.8,
			Range = 70,
			MinionCount = 1,
			MinionLifetime = 6,
			MinionAttackCooldown = 0.9,
			MinionTargetRange = 38,
			MinionMoveSpeed = 24,
		},
		Caps = {
			MinionCount = 6,
			MinionLifetime = 14,
			MinimumCooldown = 0.55,
			MinimumAttackCooldown = 0.2,
		},
		Rules = {
			UsesProjectileCount = false,
			UsesBounceCount = false,
			UsesEffectDuration = true,
			ServerAuthoritative = true,
		},
	},
	valorcrest_blade = {
		Id = "valorcrest_blade",
		Name = "Lame de Valorcrest",
		NameKey = "weapon.valorcrest_blade.name",
		Category = "Melee",
		Lifecycle = "Production",
		Icon = "rbxassetid://116223287361677",
		VfxProfileId = "ValorcrestSlash",
		Base = {
			Damage = 42,
			Cooldown = 1.15,
			Range = 12,
			ArcAngleDegrees = 115,
		},
		Caps = {
			Range = 24,
			MinimumCooldown = 0.32,
		},
		Rules = {
			UsesProjectileCount = false,
			UsesBounceCount = false,
			UsesEffectDuration = false,
			UsesSize = true,
			ServerAuthoritative = true,
		},
	},
}

WeaponConfig.Evolutions = {
	fireball = {
		{ StatId = "Damage", Label = "Degats de l'arme", LabelKey = "weapon.evolution.damage", Amount = 4, Cap = nil },
		{ StatId = "ProjectileCount", Label = "Projectile supplementaire", LabelKey = "weapon.evolution.projectile_count", Amount = 1, Cap = 24 },
		{ StatId = "BounceCount", Label = "Rebond supplementaire", LabelKey = "weapon.evolution.bounce_count", Amount = 1, Cap = 12 },
	},
	leyden_needle = {
		{ StatId = "Damage", Label = "Degats de l'arme", LabelKey = "weapon.evolution.damage", Amount = 5, Cap = nil },
		{ StatId = "ZoneRadius", Label = "Rayon de la zone", LabelKey = "weapon.evolution.zone_radius", Amount = 2, Cap = 26 },
		{ StatId = "BounceCount", Label = "Arc electrique supplementaire", LabelKey = "weapon.evolution.bounce_count", Amount = 1, Cap = 8 },
	},
	shuriken = {
		{ StatId = "Damage", Label = "Degats de l'arme", LabelKey = "weapon.evolution.damage", Amount = 3, Cap = nil },
		{ StatId = "ProjectileCount", Label = "Shuriken supplementaire", LabelKey = "weapon.evolution.projectile_count", Amount = 1, Cap = 24 },
	},
	soul_lantern = {
		{ StatId = "Damage", Label = "Degats de l'arme", LabelKey = "weapon.evolution.damage", Amount = 4, Cap = nil },
		{ StatId = "MinionCount", Label = "Serviteur supplementaire", LabelKey = "weapon.evolution.minion_count", Amount = 1, Cap = 6 },
		{ StatId = "MinionLifetime", Label = "Duree d'invocation", LabelKey = "weapon.evolution.minion_duration", Amount = 1.5, Cap = 14 },
	},
	valorcrest_blade = {
		{ StatId = "Damage", Label = "Degats de l'arme", LabelKey = "weapon.evolution.damage", Amount = 6, Cap = nil },
	},
}

function WeaponConfig.GetDefinition(weaponId: string)
	return WeaponConfig.Definitions[weaponId]
end

return WeaponConfig
