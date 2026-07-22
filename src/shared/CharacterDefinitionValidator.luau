--!strict

local CharacterConfig = require(script.Parent:WaitForChild("CharacterConfig"))

local CharacterDefinitionValidator = {}

local VALID_SCOPES = {
	Player = true,
	PrimaryWeapon = true,
	AllWeapons = true,
	WeaponCategory = true,
}

local VALID_OPERATIONS = {
	Add = true,
	MultiplyBase = true,
}

local function isNonEmptyString(value): boolean
	return typeof(value) == "string" and value ~= ""
end

local function validateDefinition(characterId: string, definition)
	local errors = {}

	if not isNonEmptyString(definition.Id) or definition.Id ~= characterId then
		table.insert(errors, "Id invalide")
	end

	if not isNonEmptyString(definition.Name) then
		table.insert(errors, "Nom manquant")
	end

	if definition.Lifecycle ~= "Production" then
		table.insert(errors, "Lifecycle non production")
	end

	if not isNonEmptyString(definition.Portrait) then
		table.insert(errors, "Portrait 2D manquant")
	end

	if not isNonEmptyString(definition.PrimaryWeaponId) then
		table.insert(errors, "Arme principale manquante")
	end

	local appearance = definition.Appearance
	if typeof(appearance) ~= "table" or appearance.RigType ~= "R15" then
		table.insert(errors, "Apparence R15 requise")
	elseif not isNonEmptyString(appearance.TemplatePath) then
		table.insert(errors, "Template visuel manquant")
	else
		local clothing = appearance.Clothing
		if typeof(clothing) ~= "table"
			or not isNonEmptyString(clothing.ShirtTemplate)
			or not isNonEmptyString(clothing.PantsTemplate)
			or not isNonEmptyString(clothing.MaterialSet)
		then
			table.insert(errors, "Vêtements UV incomplets")
		end
	end

	local passive = definition.Passive
	if typeof(passive) ~= "table" or not isNonEmptyString(passive.Id) then
		table.insert(errors, "Passif declaratif manquant")
	elseif not VALID_SCOPES[passive.Scope] then
		table.insert(errors, "Scope de passif invalide")
	elseif passive.Scope == "WeaponCategory" and not isNonEmptyString(passive.WeaponCategory) then
		table.insert(errors, "Categorie d'arme du passif manquante")
	elseif typeof(passive.Modifiers) ~= "table" or #passive.Modifiers == 0 then
		table.insert(errors, "Modificateur de passif manquant")
	else
		for modifierIndex, modifier in ipairs(passive.Modifiers) do
			if typeof(modifier) ~= "table"
				or not isNonEmptyString(modifier.StatId)
				or not VALID_OPERATIONS[modifier.Operation]
				or typeof(modifier.Amount) ~= "number"
			then
				table.insert(errors, "Modificateur invalide #" .. tostring(modifierIndex))
			end
		end
	end

	return #errors == 0, errors
end

function CharacterDefinitionValidator.ValidateAll()
	local runnable = {}
	local diagnostics = {}

	for characterId, definition in pairs(CharacterConfig.Definitions) do
		local valid, errors = validateDefinition(characterId, definition)
		diagnostics[characterId] = errors
		if valid then
			runnable[characterId] = definition
		end
	end

	return runnable, diagnostics
end

function CharacterDefinitionValidator.IsRunnable(characterId: string)
	local definition = CharacterConfig.GetDefinition(characterId)
	if definition == nil then
		return false, { "Personnage inconnu" }
	end
	return validateDefinition(characterId, definition)
end

return CharacterDefinitionValidator
