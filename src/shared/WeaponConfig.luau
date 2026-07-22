--!strict

local CombatConfig = require(script.Parent:WaitForChild("CombatConfig"))

local WeaponConfig = {}

WeaponConfig.Categories = {
	Projectile = true,
	Melee = true,
	Zone = true,
	Orbital = true,
}

WeaponConfig.Definitions = {
	fireball = {
		Id = "fireball",
		Name = "Boule de feu",
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
}

WeaponConfig.Evolutions = {
	fireball = {
		{ StatId = "Damage", Label = "Degats de l'arme", Amount = 4, Cap = nil },
		{ StatId = "ProjectileCount", Label = "Projectile supplementaire", Amount = 1, Cap = 24 },
		{ StatId = "BounceCount", Label = "Rebond supplementaire", Amount = 1, Cap = 12 },
	},
	leyden_needle = {
		{ StatId = "Damage", Label = "Degats de l'arme", Amount = 5, Cap = nil },
		{ StatId = "ZoneRadius", Label = "Rayon de la zone", Amount = 2, Cap = 26 },
		{ StatId = "BounceCount", Label = "Arc electrique supplementaire", Amount = 1, Cap = 8 },
	},
}

function WeaponConfig.GetDefinition(weaponId: string)
	return WeaponConfig.Definitions[weaponId]
end

return WeaponConfig
