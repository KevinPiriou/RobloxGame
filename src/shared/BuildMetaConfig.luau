--!strict

local CombatConfig = require(script.Parent.CombatConfig)
local WeaponConfig = require(script.Parent.WeaponConfig)

local META_BEHAVIOR_BY_CATEGORY = {
	Projectile = "projectile",
	Melee = "contact",
	Zone = "explosion",
	Orbital = "orbital",
}

local function buildWeaponCatalog()
	local weapons = {}

	for weaponId, definition in pairs(WeaponConfig.Definitions) do
		local tags = { "weapon", string.lower(definition.Category) }
		local behaviors = {
			{ type = META_BEHAVIOR_BY_CATEGORY[definition.Category] or "contact" },
		}

		if definition.Rules and definition.Rules.UsesBounceCount then
			table.insert(tags, "bounce")
			table.insert(behaviors, { type = "bounce", count_stat = "BounceCount" })
		end

		local base = {
			damage = definition.Base.Damage,
			cooldown = definition.Base.Cooldown,
			range = definition.Base.Range,
			crit_enabled = true,
		}

		if definition.Category == "Projectile" then
			base.speed = CombatConfig.FireballSpeed
			base.lifetime = CombatConfig.FireballLifetime
			base.hit_radius = CombatConfig.FireballHitRadius
			base.projectiles = 1
			table.insert(tags, "homing")
			table.insert(behaviors, { type = "homing", accuracy_bonus = 0.14 })
		elseif definition.Category == "Zone" then
			base.zone_radius = definition.Base.ZoneRadius
			base.charge_duration = definition.Base.ChargeDuration
			base.strike_count = definition.Base.StrikeCount
			base.bounce_range = definition.Base.BounceRange
			behaviors[1].targets = math.clamp(math.floor(definition.Base.ZoneRadius / 5), 1, 8)
			behaviors[1].damage_multiplier = 1
		end

		table.insert(weapons, {
			id = weaponId,
			name = definition.Name,
			category = "weapon",
			rarity = if weaponId == "fireball" then "Starter" else "Standard",
			tags = tags,
			base = base,
			behaviors = behaviors,
			levels = {
				{ level = 1, effects = {} },
			},
		})
	end

	table.sort(weapons, function(left, right)
		return left.id < right.id
	end)

	return weapons
end

-- Contrat descriptif exporte vers MetaBuildLab. Il ne pilote aucun gameplay.
return {
	SchemaVersion = 1,
	-- Le laboratoire ne modele pas encore le scope PrimaryWeapon des passifs.
	-- Le personnage canonique reste donc neutre jusqu'a ce que ce contrat soit pris en charge.
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
	Weapons = buildWeaponCatalog(),
}
