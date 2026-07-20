--!strict

local WeaponConfig = require(script.Parent:WaitForChild("WeaponConfig"))

local WeaponDefinitionValidator = {}

local REQUIRED_BASE_FIELDS = {
	"Damage",
	"Cooldown",
	"Range",
}

local function addError(errors, weaponId, field, message)
	table.insert(errors, ("%s.%s: %s"):format(weaponId, field, message))
end

function WeaponDefinitionValidator.Validate(definition)
	local errors = {}
	local weaponId = tostring(definition and definition.Id or "Unknown")

	if typeof(definition) ~= "table" then
		return false, { weaponId .. ": definition invalide" }
	end

	if definition.Id ~= weaponId or weaponId == "" then
		addError(errors, weaponId, "Id", "identifiant requis")
	end

	if typeof(definition.Name) ~= "string" or definition.Name == "" then
		addError(errors, weaponId, "Name", "nom requis")
	end

	if WeaponConfig.Categories[definition.Category] ~= true then
		addError(errors, weaponId, "Category", "categorie inconnue")
	end

	if typeof(definition.Base) ~= "table" then
		addError(errors, weaponId, "Base", "table requise")
	else
		for _, field in ipairs(REQUIRED_BASE_FIELDS) do
			if typeof(definition.Base[field]) ~= "number" or definition.Base[field] <= 0 then
				addError(errors, weaponId, "Base." .. field, "nombre strictement positif requis")
			end
		end
	end

	if definition.Category == "Zone" then
		for _, field in ipairs({ "ZoneRadius", "ChargeDuration", "StrikeCount", "BounceRange" }) do
			if typeof(definition.Base[field]) ~= "number" or definition.Base[field] <= 0 then
				addError(errors, weaponId, "Base." .. field, "requis pour une arme de zone")
			end
		end

		if definition.Rules == nil or definition.Rules.UsesProjectileCount ~= false then
			addError(errors, weaponId, "Rules.UsesProjectileCount", "doit etre false pour cette zone")
		end
	end

	return #errors == 0, errors
end

function WeaponDefinitionValidator.ValidateAll()
	local valid = {}
	local errors = {}

	for weaponId, definition in pairs(WeaponConfig.Definitions) do
		local isValid, definitionErrors = WeaponDefinitionValidator.Validate(definition)
		if isValid then
			valid[weaponId] = definition
		else
			for _, message in ipairs(definitionErrors) do
				table.insert(errors, message)
			end
		end
	end

	return valid, errors
end

return WeaponDefinitionValidator
