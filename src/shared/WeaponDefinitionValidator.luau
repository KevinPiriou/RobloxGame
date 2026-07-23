--!strict

local WeaponConfig = require(script.Parent:WaitForChild("WeaponConfig"))

local WeaponDefinitionValidator = {}

local REQUIRED_BASE_FIELDS = {
	"Damage",
	"Cooldown",
	"Range",
}

local VALID_LIFECYCLES = {
	Calibration = true,
	Validated = true,
	Production = true,
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

	if VALID_LIFECYCLES[definition.Lifecycle] ~= true then
		addError(errors, weaponId, "Lifecycle", "cycle de validation inconnu")
	end

	if definition.Lifecycle == "Production"
		and (typeof(definition.Icon) ~= "string" or definition.Icon == "")
	then
		addError(errors, weaponId, "Icon", "asset 2D requis avant passage en production")
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

		if typeof(definition.VfxProfileId) ~= "string" or definition.VfxProfileId == "" then
			addError(errors, weaponId, "VfxProfileId", "profil VFX requis pour une arme de zone")
		end

		if typeof(definition.Caps) ~= "table"
			or typeof(definition.Caps.ZoneRadius) ~= "number"
			or definition.Caps.ZoneRadius < definition.Base.ZoneRadius
		then
			addError(errors, weaponId, "Caps.ZoneRadius", "doit etre superieur ou egal au rayon de base")
		end

		if typeof(definition.Caps) ~= "table"
			or typeof(definition.Caps.StrikeCount) ~= "number"
			or definition.Caps.StrikeCount < definition.Base.StrikeCount
		then
			addError(errors, weaponId, "Caps.StrikeCount", "doit etre superieur ou egal au nombre d'eclairs de base")
		end
	end

	if definition.Category == "Projectile" and definition.Rules and definition.Rules.RequiresProjectileBase == true then
		for _, field in ipairs({ "ProjectileCount", "ProjectileSpeed", "Lifetime", "HitRadius", "ConeAngleDegrees" }) do
			if typeof(definition.Base[field]) ~= "number" or definition.Base[field] <= 0 then
				addError(errors, weaponId, "Base." .. field, "requis pour ce projectile")
			end
		end

		if typeof(definition.Caps) ~= "table"
			or typeof(definition.Caps.ProjectileCount) ~= "number"
			or definition.Caps.ProjectileCount < definition.Base.ProjectileCount
		then
			addError(errors, weaponId, "Caps.ProjectileCount", "doit etre superieur ou egal a la quantite de base")
		end

		if definition.Rules.UsesBounceCount ~= false then
			addError(errors, weaponId, "Rules.UsesBounceCount", "doit etre false pour ce projectile sans rebond")
		end
	end

	if definition.Category == "Invocation" then
		for _, field in ipairs({ "MinionCount", "MinionLifetime", "MinionAttackCooldown", "MinionTargetRange", "MinionMoveSpeed" }) do
			if typeof(definition.Base[field]) ~= "number" or definition.Base[field] <= 0 then
				addError(errors, weaponId, "Base." .. field, "requis pour une invocation")
			end
		end

		if definition.Rules == nil or definition.Rules.UsesProjectileCount ~= false then
			addError(errors, weaponId, "Rules.UsesProjectileCount", "doit etre false pour une invocation")
		end

		if definition.Rules == nil or definition.Rules.UsesEffectDuration ~= true then
			addError(errors, weaponId, "Rules.UsesEffectDuration", "doit etre true pour la duree des serviteurs")
		end

		if typeof(definition.VfxProfileId) ~= "string" or definition.VfxProfileId == "" then
			addError(errors, weaponId, "VfxProfileId", "profil VFX requis pour une invocation")
		end

		if typeof(definition.Caps) ~= "table"
			or typeof(definition.Caps.MinionCount) ~= "number"
			or definition.Caps.MinionCount < definition.Base.MinionCount
		then
			addError(errors, weaponId, "Caps.MinionCount", "doit etre superieur ou egal au nombre de base")
		end

		if typeof(definition.Caps) ~= "table"
			or typeof(definition.Caps.MinionLifetime) ~= "number"
			or definition.Caps.MinionLifetime < definition.Base.MinionLifetime
		then
			addError(errors, weaponId, "Caps.MinionLifetime", "doit etre superieur ou egal a la duree de base")
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

	for weaponId, evolutions in pairs(WeaponConfig.Evolutions) do
		if WeaponConfig.Definitions[weaponId] == nil then
			addError(errors, weaponId, "Evolutions", "arme associee introuvable")
		elseif typeof(evolutions) ~= "table" or #evolutions == 0 then
			addError(errors, weaponId, "Evolutions", "au moins une evolution est requise")
		else
			for index, evolution in ipairs(evolutions) do
				if typeof(evolution.StatId) ~= "string" or evolution.StatId == "" then
					addError(errors, weaponId, "Evolutions." .. index .. ".StatId", "statistique requise")
				end
				if typeof(evolution.Amount) ~= "number" or evolution.Amount <= 0 then
					addError(errors, weaponId, "Evolutions." .. index .. ".Amount", "gain positif requis")
				end
			end
		end
	end

	return valid, errors
end

return WeaponDefinitionValidator
