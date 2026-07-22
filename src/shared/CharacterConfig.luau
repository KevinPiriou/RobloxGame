--!strict

local CharacterConfig = {}

CharacterConfig.SchemaVersion = 2
CharacterConfig.DefaultCharacterId = "medivh"

CharacterConfig.Definitions = {
	medivh = {
		Id = "medivh",
		Name = "Medivh",
		Description = "Mage malicieux qui amplifie les salves de projectiles.",
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
		Description = "Savant fou dont les instruments attirent les collectibles.",
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
			Type = "Deferred",
		},
	},
}

function CharacterConfig.GetDefinition(characterId: string)
	return CharacterConfig.Definitions[characterId]
end

return CharacterConfig
