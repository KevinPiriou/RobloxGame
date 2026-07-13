-- Reglages visuels des auras de run. Les valeurs de stats restent calculees par le serveur.

local AuraConfig = {
	VisualTemplatesFolderName = "VisualTemplates",
	AuraTemplatesFolderName = "AuraTemplates",
	ParticleTexturesFolderName = "ParticleTextures",
	RuntimeFolderName = "MegaRobloxAuras",
	BuiltinTextureIds = {
		AuraFlame = "rbxassetid://72782845967015",
	},
	MaxActiveFamilies = 3,
	MinimumScore = 0.12,
	NativeSizeMultiplier = 2.7,
	TierThresholds = {
		0.12,
		0.36,
		0.7,
	},
	TierScales = {
		[1] = 0.75,
		[2] = 1,
		[3] = 1.15,
	},

	Families = {
		Mobility = {
			DisplayName = "Mobilite",
			Style = "Feet",
			Color = Color3.fromRGB(54, 220, 255),
			PrimaryTexture = "WindStreak",
			SecondaryTexture = "SoftGlow",
			Stats = {
				{ Name = "MoveSpeedPercent", Saturation = 0.55, Weight = 0.85 },
				{ Name = "JumpPercent", Saturation = 0.5, Weight = 0.15 },
			},
		},
		Magnetism = {
			DisplayName = "Magnetisme",
			Style = "Magnetism",
			Color = Color3.fromRGB(55, 255, 188),
			PrimaryTexture = "ArcaneGlyph",
			SecondaryTexture = "Spark",
			Stats = {
				{ Name = "CollectRadius", Saturation = 16, Weight = 1 },
			},
		},
		AttackSpeed = {
			DisplayName = "Vitesse d'attaque",
			Style = "Hands",
			Color = Color3.fromRGB(227, 255, 122),
			PrimaryTexture = "Spark",
			SecondaryTexture = "WindStreak",
			Stats = {
				{ Name = "AttackSpeedPercent", Saturation = 0.6, Weight = 1 },
			},
		},
		Arsenal = {
			DisplayName = "Arsenal",
			Style = "Orbit",
			Color = Color3.fromRGB(160, 92, 255),
			PrimaryTexture = "ArcaneGlyph",
			SecondaryTexture = "Spark",
			Stats = {
				{ Name = "ProjectileCount", Saturation = 6, Weight = 0.4 },
				{ Name = "ProjectileSpeedPercent", Saturation = 0.75, Weight = 0.3 },
				{ Name = "EffectDurationPercent", Saturation = 0.75, Weight = 0.15 },
				{ Name = "BounceCount", Saturation = 5, Weight = 0.15 },
			},
		},
		Power = {
			DisplayName = "Puissance",
			Style = "BodyFlame",
			Color = Color3.fromRGB(255, 88, 74),
			PrimaryTexture = "AuraFlame",
			FallbackPrimaryTexture = "SoftGlow",
			SecondaryTexture = "Spark",
			Stats = {
				{ Name = "DamagePercent", Saturation = 0.75, Weight = 0.4 },
				{ Name = "FlatDamage", Saturation = 30, Weight = 0.2 },
				{ Name = "EliteFlatDamage", Saturation = 30, Weight = 0.1 },
				{ Name = "CritChance", Saturation = 0.5, Weight = 0.15 },
				{ Name = "CritMultiplierBonus", Saturation = 0.75, Weight = 0.15 },
			},
		},
		Protection = {
			DisplayName = "Protection",
			Style = "Armor",
			Color = Color3.fromRGB(62, 177, 255),
			PrimaryTexture = "SoftGlow",
			SecondaryTexture = "HexShield",
			Stats = {
				{ Name = "ArmorPercent", Saturation = 0.6, Weight = 0.34 },
				{ Name = "Shield", Saturation = 100, Weight = 0.66 },
			},
		},
		Sustain = {
			DisplayName = "Sustain",
			Style = "Sustain",
			Color = Color3.fromRGB(76, 255, 147),
			SecondaryColor = Color3.fromRGB(246, 66, 90),
			PrimaryTexture = "SoftSmoke",
			SecondaryTexture = "SoftGlow",
			Stats = {
				{ Name = "HealthRegen", Saturation = 1, Weight = 0.5 },
				{ Name = "LifeStealPercent", Saturation = 0.12, Weight = 0.5 },
			},
		},
		Fortune = {
			DisplayName = "Fortune",
			Style = "Head",
			Color = Color3.fromRGB(255, 188, 54),
			PrimaryTexture = "ArcaneGlyph",
			SecondaryTexture = "Spark",
			Stats = {
				{ Name = "XpGainPercent", Saturation = 0.75, Weight = 0.35 },
				{ Name = "GoldGainPercent", Saturation = 0.75, Weight = 0.35 },
				{ Name = "Luck", Saturation = 0.5, Weight = 0.3 },
			},
		},
	},
}

return AuraConfig
