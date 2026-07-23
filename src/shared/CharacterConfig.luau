--!strict

local CharacterConfig = {}

CharacterConfig.SchemaVersion = 4
CharacterConfig.DefaultCharacterId = "medivh"

CharacterConfig.Definitions = {
	medivh = {
		Id = "medivh",
		Name = "Medivh",
		NameKey = "character.medivh.name",
		Description = "Mage malicieux qui amplifie les salves de projectiles.",
		DescriptionKey = "character.medivh.description",
		Lifecycle = "Production",
		Portrait = "rbxassetid://72675265292172",
		PrimaryWeaponId = "fireball",
		Appearance = {
			RigType = "R15",
			TemplatePath = "ServerStorage.CharacterTemplates.Medivh",
			Clothing = {
				ShirtTemplate = "rbxassetid://109688448865927",
				PantsTemplate = "rbxassetid://105765423035091",
				MaterialSet = "MedivhArcaneV1",
			},
		},
		Animations = {
			Overrides = {},
		},
		Passive = {
			Id = "arcane_volley",
			Name = "Volee arcanique",
			NameKey = "character.medivh.passive",
			Scope = "WeaponCategory",
			WeaponCategory = "Projectile",
			Modifiers = {
				{
					StatId = "ProjectileCount",
					Operation = "Add",
					Amount = 1,
				},
			},
		},
		Unlock = {
			Type = "Default",
		},
	},
	
	albert = {
		Id = "albert",
		Name = "Albert",
		NameKey = "character.albert.name",
		Description = "Savant fou dont les instruments attirent les collectibles.",
		DescriptionKey = "character.albert.description",
		Lifecycle = "Production",
		Portrait = "rbxassetid://76272865710318",
		PrimaryWeaponId = "leyden_needle",
		Appearance = {
			RigType = "R15",
			TemplatePath = "ServerStorage.CharacterTemplates.Albert",
			Clothing = {
				ShirtTemplate = "rbxassetid://100088502706587",
				PantsTemplate = "rbxassetid://123980013567477",
				MaterialSet = "AlbertLaboratoryV1",
			},
		},
		Animations = {
			Overrides = {},
		},
		Passive = {
			Id = "scientific_magnetism",
			Name = "Magnetisme scientifique",
			NameKey = "character.albert.passive",
			Scope = "Player",
			Modifiers = {
				{
					StatId = "CollectRadius",
					Operation = "MultiplyBase",
					Amount = 3,
				},
			},
		},
		Unlock = {
			Type = "Default",
		},
	},

	shinobi = {
		Id = "shinobi",
		Name = "Shinobi",
		NameKey = "character.shinobi.name",
		Description = "Ninja precis qui accelere sa cadence a chaque niveau.",
		DescriptionKey = "character.shinobi.description",
		Lifecycle = "Production",
		Portrait = "rbxassetid://104698571348162",
		PrimaryWeaponId = "shuriken",
		Appearance = {
			RigType = "R15",
			TemplatePath = "ServerStorage.CharacterTemplates.Shinobi",
			Clothing = {
				ShirtTemplate = "rbxassetid://81502804062973",
				PantsTemplate = "rbxassetid://127826973384729",
				MaterialSet = "ShinobiShadowV1",
			},
		},
		Animations = {
			Overrides = {},
		},
		Passive = {
			Id = "shadow_training",
			Name = "Entrainement de l'ombre",
			NameKey = "character.shinobi.passive",
			Scope = "Player",
			Modifiers = {
				{
					StatId = "AttackSpeedPercent",
					Operation = "AddPerLevel",
					Amount = 0.05,
				},
			},
		},
		Unlock = {
			Type = "Default",
		},
	},

	rusal_gale = {
		Id = "rusal_gale",
		Name = "Ru's al Gale",
		NameKey = "character.rusal_gale.name",
		Description = "Necromancien qui rallie les morts sous une lanterne spectrale.",
		DescriptionKey = "character.rusal_gale.description",
		Lifecycle = "Production",
		Portrait = "rbxassetid://111222772217752",
		PrimaryWeaponId = "soul_lantern",
		Appearance = {
			RigType = "R15",
			TemplatePath = "ServerStorage.CharacterTemplates.RusalGale",
			Clothing = {
				ShirtTemplate = "rbxassetid://140150101017634",
				PantsTemplate = "rbxassetid://88177762501851",
				MaterialSet = "RusalGaleNecromanticV1",
			},
		},
		Animations = {
			Overrides = {},
		},
		Passive = {
			Id = "funeral_insight",
			Name = "Instinct funeraire",
			NameKey = "character.rusal_gale.passive",
			Scope = "Player",
			Modifiers = {
				{
					StatId = "CritChance",
					Operation = "AddPerLevel",
					Amount = 0.05,
				},
			},
		},
		Unlock = {
			Type = "Default",
		},
	},

	rufus = {
		Id = "rufus",
		Name = "Rufus",
		NameKey = "character.rufus.name",
		Description = "Chevalier de l'Alliance qui tient la ligne au corps a corps.",
		DescriptionKey = "character.rufus.description",
		Lifecycle = "Production",
		Portrait = "rbxassetid://117769701520930",
		PrimaryWeaponId = "valorcrest_blade",
		Appearance = {
			RigType = "R15",
			TemplatePath = "ServerStorage.CharacterTemplates.Rufus",
			Clothing = {
				ShirtTemplate = "rbxassetid://128402560504693",
				PantsTemplate = "rbxassetid://112987301949770",
				MaterialSet = "RufusValorcrestV1",
			},
		},
		Animations = {
			Overrides = {},
		},
		Passive = {
			Id = "valorcrest_bulwark",
			Name = "Bastion de Valorcrest",
			NameKey = "character.rufus.passive",
			Scope = "Player",
			Modifiers = {
				{
					StatId = "MaxHealthBonus",
					Operation = "Add",
					Amount = 50,
				},
				{
					StatId = "Shield",
					Operation = "Add",
					Amount = 50,
				},
			},
		},
		Unlock = {
			Type = "Default",
		},
	},

	lorelei = {
		Id = "lorelei",
		Name = "Lorelei",
		NameKey = "character.lorelei.name",
		Description = "Succube qui lie son essence a celle de ses proies pour leur derober la vie.",
		DescriptionKey = "character.lorelei.description",
		Lifecycle = "Production",
		Portrait = "rbxassetid://110000926797342",
		PrimaryWeaponId = "soulthorn_drain",
		Appearance = {
			RigType = "R15",
			TemplatePath = "ServerStorage.CharacterTemplates.Lorelei",
			Clothing = {
				ShirtTemplate = "rbxassetid://73217425125133",
				PantsTemplate = "rbxassetid://73217425125133",
				MaterialSet = "LoreleiNightveilV1",
			},
		},
		Animations = {
			Overrides = {},
		},
		Passive = {
			Id = "nightveil_harvest",
			Name = "Moisson du Voile",
			NameKey = "character.lorelei.passive",
			Scope = "Player",
			Modifiers = {
				{
					StatId = "MaxHealthBonus",
					Operation = "AddPerKillThreshold",
					Amount = 0.2,
					Threshold = 50,
				},
				{
					StatId = "HealthRegen",
					Operation = "Add",
					Amount = 0.2,
				},
			},
		},
		Unlock = {
			Type = "Default",
		},
	},
}

function CharacterConfig.GetDefinition(characterId: string)
	return CharacterConfig.Definitions[characterId]
end

return CharacterConfig
