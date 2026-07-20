--!strict

local CombatConfig = require(script.Parent.CombatConfig)

-- Contrat descriptif exporte vers MetaBuildLab. Il ne pilote aucun gameplay.
return {
	SchemaVersion = 1,
	Characters = {
		{
			id = "default_character",
			name = "Personnage actuel",
			category = "character",
			tags = { "character" },
			base_stats = {
				MaxHealth = 100,
				MoveSpeed = CombatConfig.PlayerBaseWalkSpeed,
				JumpPower = CombatConfig.PlayerBaseJumpPower,
			},
			effects = {},
		},
	},
	Weapons = {
		{
			id = "fireball",
			name = "Fireball",
			category = "weapon",
			rarity = "Starter",
			tags = { "weapon", "projectile", "homing", "bounce" },
			base = {
				damage = CombatConfig.FireballDamage,
				cooldown = CombatConfig.FireballCooldown,
				range = CombatConfig.FireballRange,
				speed = CombatConfig.FireballSpeed,
				lifetime = CombatConfig.FireballLifetime,
				hit_radius = CombatConfig.FireballHitRadius,
				projectiles = 1,
				crit_enabled = true,
			},
			behaviors = {
				{ type = "projectile" },
				{ type = "homing", accuracy_bonus = 0.14 },
				{ type = "bounce", count_stat = "BounceCount" },
			},
			levels = {
				{ level = 1, effects = {} },
				{
					level = 2,
					effects = {
						{
							type = "stat",
							stat = "DamagePercent",
							operation = "add",
							value = 0.1,
						},
					},
				},
				{
					level = 3,
					effects = {
						{
							type = "stat",
							stat = "ProjectileSpeedPercent",
							operation = "add",
							value = 0.12,
						},
					},
				},
				{
					level = 4,
					effects = {
						{
							type = "stat",
							stat = "AttackSpeedPercent",
							operation = "add",
							value = 0.12,
						},
					},
				},
				{
					level = 5,
					effects = {
						{
							type = "stat",
							stat = "DamagePercent",
							operation = "add",
							value = 0.18,
						},
					},
				},
			},
		},
	},
}
