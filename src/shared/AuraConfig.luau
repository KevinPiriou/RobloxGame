-- Reglages visuels des auras de run. Les valeurs de stats restent calculees par le serveur.

local AuraConfig = {
	VisualTemplatesFolderName = "VisualTemplates",
	AuraTemplatesFolderName = "AuraTemplates",
	EffectTemplatesFolderName = "EffectTemplates",
	CompositionTemplatesFolderName = "CompositionTemplates",
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
			Style = "Composition",
			CompositionTemplate = "MobilityV2",
			Color = Color3.fromRGB(54, 220, 255),
			TemplateRateMultiplier = 1,
			TemplateSizeMultiplier = 1,
			Stats = {
				{ Name = "MoveSpeedPercent", Saturation = 0.55, Weight = 0.85 },
				{ Name = "JumpPercent", Saturation = 0.5, Weight = 0.15 },
			},
		},
		Magnetism = {
			DisplayName = "Magnetisme",
			Style = "Magnetism",
			Color = Color3.fromRGB(55, 255, 188),
			-- Effet de traction horizontal : les flux convergent vers le personnage.
			-- Il ne partage pas le template d'orbite de l'arsenal afin de garder
			-- une lecture spatiale propre a la collecte.
			EffectTemplates = { Primary = "MagnetismInwardSpiral", Secondary = "MagnetismGroundCore" },
			TemplateRateMultiplier = 0.78,
			TemplateSizeMultiplier = 0.92,
			PrimaryTexture = "ArcaneGlyph",
			SecondaryTexture = "Spark",
			Stats = {
				{ Name = "CollectRadius", Saturation = 16, Weight = 1 },
			},
		},
		AttackSpeed = {
			DisplayName = "Vitesse d'attaque",
			Style = "Composition",
			CompositionTemplate = "AttackSpeedV2",
			Color = Color3.fromRGB(227, 255, 122),
			TemplateRateMultiplier = 1,
			TemplateSizeMultiplier = 1,
			Stats = {
				{ Name = "AttackSpeedPercent", Saturation = 0.6, Weight = 1 },
			},
		},
		Arsenal = {
			DisplayName = "Arsenal",
			Style = "Composition",
			CompositionTemplate = "ArsenalV2",
			Color = Color3.fromRGB(160, 92, 255),
			TemplateRateMultiplier = 1,
			TemplateSizeMultiplier = 1,
			Stats = {
				{ Name = "ProjectileCount", Saturation = 6, Weight = 0.4 },
				{ Name = "ProjectileSpeedPercent", Saturation = 0.75, Weight = 0.3 },
				{ Name = "EffectDurationPercent", Saturation = 0.75, Weight = 0.15 },
				{ Name = "BounceCount", Saturation = 5, Weight = 0.15 },
			},
		},
		Power = {
			DisplayName = "Puissance",
			Style = "Composition",
			CompositionTemplate = "PowerV2",
			Color = Color3.fromRGB(255, 88, 74),
			TemplateRateMultiplier = 1,
			TemplateSizeMultiplier = 1,
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
			EffectTemplates = { Primary = "ShieldField", Secondary = "ShieldSpecs" },
			TemplateRateMultiplier = 0.2,
			TemplateSizeMultiplier = 1.0,
			PrimaryTexture = "SoftGlow",
			SecondaryTexture = "HexShield",
			Stats = {
				{ Name = "ArmorPercent", Saturation = 0.6, Weight = 0.34 },
				{ Name = "Shield", Saturation = 100, Weight = 0.66 },
			},
		},
		Sustain = {
			DisplayName = "Sustain",
			Style = "Composition",
			CompositionTemplate = "SustainV2",
			Color = Color3.fromRGB(76, 255, 147),
			SecondaryColor = Color3.fromRGB(246, 66, 90),
			TemplateRateMultiplier = 1,
			TemplateSizeMultiplier = 1,
			Stats = {
				{ Name = "HealthRegen", Saturation = 1, Weight = 0.5 },
				{ Name = "LifeStealPercent", Saturation = 0.12, Weight = 0.5 },
			},
		},
		Fortune = {
			DisplayName = "Fortune",
			Style = "Fortune",
			Color = Color3.fromRGB(255, 188, 54),
			-- La fortune est une lecture de richesse : sceau au sol et eclats
			-- precieux. Ce vocabulaire reste distinct du simple arcane.
			EffectTemplates = {
				FloorInner = "FortuneFloorInner",
				FloorCore = "FortuneFloorCore",
				FloorOuter = "FortuneFloorOuter",
				Spark = "FortuneStar",
			},
			TemplateRateMultiplier = 0.58,
			TemplateSizeMultiplier = 0.94,
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
