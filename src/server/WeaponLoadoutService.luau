--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DebugLog = require(Shared:WaitForChild("DebugLog"))
local WeaponConfig = require(Shared:WaitForChild("WeaponConfig"))
local WeaponDefinitionValidator = require(Shared:WaitForChild("WeaponDefinitionValidator"))
local CharacterService = require(script.Parent:WaitForChild("CharacterService"))
local RunStateService = require(script.Parent:WaitForChild("RunStateService"))

local WeaponLoadoutService = {}

local profilesByUserId = {}
local validDefinitions, validationErrors = WeaponDefinitionValidator.ValidateAll()
local updateRemote = ReplicatedStorage:FindFirstChild("Weapon_LoadoutUpdate")

if updateRemote == nil then
	updateRemote = Instance.new("RemoteEvent")
	updateRemote.Name = "Weapon_LoadoutUpdate"
	updateRemote.Parent = ReplicatedStorage
end

assert(updateRemote:IsA("RemoteEvent"), "Weapon_LoadoutUpdate doit etre un RemoteEvent")
local getLoadoutRemote = ReplicatedStorage:FindFirstChild("Weapon_GetLoadout")
if getLoadoutRemote == nil then
	getLoadoutRemote = Instance.new("RemoteFunction")
	getLoadoutRemote.Name = "Weapon_GetLoadout"
	getLoadoutRemote.Parent = ReplicatedStorage
end
assert(getLoadoutRemote:IsA("RemoteFunction"), "Weapon_GetLoadout doit etre un RemoteFunction")

local function getProfile(player: Player)
	local profile = profilesByUserId[player.UserId]
	if profile == nil then
		profile = {
			Weapons = { fireball = 1 },
			Order = { "fireball" },
			Bonuses = { fireball = {} },
		}
		profilesByUserId[player.UserId] = profile
	end
	return profile
end

local function copyDictionary(source)
	local result = {}
	for key, value in pairs(source or {}) do
		result[key] = value
	end
	return result
end

local function buildSnapshot(player: Player)
	local profile = getProfile(player)
	local weapons = {}

	for _, weaponId in ipairs(profile.Order) do
		local definition = validDefinitions[weaponId]
		if definition ~= nil then
			table.insert(weapons, {
				Id = weaponId,
				Name = definition.Name,
				Category = definition.Category,
				Icon = definition.Icon,
				Level = profile.Weapons[weaponId],
				Lifecycle = definition.Lifecycle,
			})
		end
	end

	return { Weapons = weapons, MaxWeapons = 4 }
end

local function sendSnapshot(player: Player)
	updateRemote:FireClient(player, buildSnapshot(player))
end

function WeaponLoadoutService.SetupPlayer(player: Player)
	getProfile(player)
	sendSnapshot(player)
end

function WeaponLoadoutService.RemovePlayer(player: Player)
	profilesByUserId[player.UserId] = nil
end

function WeaponLoadoutService.ResetRun(player: Player)
	local characterSnapshot = CharacterService.GetActiveRunSnapshot(player)
	local primaryWeaponId = if characterSnapshot ~= nil then characterSnapshot.PrimaryWeaponId else "fireball"
	if validDefinitions[primaryWeaponId] == nil then
		DebugLog.Warn("Weapon", "Arme principale invalide, fallback Fireball", {
			Player = player.Name,
			PrimaryWeaponId = primaryWeaponId,
		})
		primaryWeaponId = "fireball"
	end
	profilesByUserId[player.UserId] = {
		Weapons = { [primaryWeaponId] = 1 },
		Order = { primaryWeaponId },
		Bonuses = { [primaryWeaponId] = {} },
	}
	sendSnapshot(player)
end

function WeaponLoadoutService.HasWeapon(player: Player, weaponId: string)
	local profile = profilesByUserId[player.UserId]
	return profile ~= nil and profile.Weapons[weaponId] ~= nil
end

function WeaponLoadoutService.GetWeaponLevel(player: Player, weaponId: string): number
	local profile = getProfile(player)
	return math.max(0, math.floor(tonumber(profile.Weapons[weaponId]) or 0))
end

function WeaponLoadoutService.GetRuntimeStats(player: Player, weaponId: string)
	local definition = validDefinitions[weaponId]
	if definition == nil then return nil end
	local stats = copyDictionary(definition.Base)
	local characterDefinition = CharacterService.GetActiveDefinition(player)
	local passive = characterDefinition and characterDefinition.Passive
	local passiveApplies = passive ~= nil and (
		passive.Scope == "AllWeapons"
		or (passive.Scope == "PrimaryWeapon" and characterDefinition.PrimaryWeaponId == weaponId)
		or (passive.Scope == "WeaponCategory" and passive.WeaponCategory == definition.Category)
	)
	if passiveApplies then
		for _, modifier in ipairs(passive.Modifiers or {}) do
			local currentValue = tonumber(stats[modifier.StatId]) or 0
			if modifier.Operation == "Add" then
				stats[modifier.StatId] = currentValue + modifier.Amount
			elseif modifier.Operation == "MultiplyBase" then
				stats[modifier.StatId] = currentValue * modifier.Amount
			end
		end
	end
	local bonuses = getProfile(player).Bonuses[weaponId] or {}
	for statId, amount in pairs(bonuses) do
		stats[statId] = (tonumber(stats[statId]) or 0) + (tonumber(amount) or 0)
	end
	return stats
end

function WeaponLoadoutService.GetEquippedWeaponIds(player: Player)
	return table.clone(getProfile(player).Order)
end

function WeaponLoadoutService.ApplyProgression(player: Player, weaponId: string, statId: string?, amount: number?)
	local definition = validDefinitions[weaponId]
	if definition == nil then return false, "Arme inconnue" end
	local profile = getProfile(player)
	if profile.Weapons[weaponId] == nil then
		if #profile.Order >= 4 then return false, "Les quatre emplacements d'arme sont occupes" end
		profile.Weapons[weaponId] = 1
		profile.Bonuses[weaponId] = {}
		table.insert(profile.Order, weaponId)
	else
		profile.Weapons[weaponId] += 1
		if statId ~= nil then
			local bonuses = profile.Bonuses[weaponId] or {}
			profile.Bonuses[weaponId] = bonuses
			bonuses[statId] = (tonumber(bonuses[statId]) or 0) + (tonumber(amount) or 0)
		end
	end
	sendSnapshot(player)
	return true
end

function WeaponLoadoutService.SetDevelopmentWeapon(player: Player, weaponId: string, enabled: boolean)
	local definition = validDefinitions[weaponId]
	if definition == nil then
		return false, "Arme de calibration invalide"
	end

	local profile = getProfile(player)
	local isEquipped = profile.Weapons[weaponId] ~= nil
	if enabled and not isEquipped then
		if #profile.Order >= 4 then
			return false, "Les quatre emplacements d'arme sont occupes"
		end
		profile.Weapons[weaponId] = 1
		profile.Bonuses[weaponId] = {}
		table.insert(profile.Order, weaponId)
	elseif not enabled and isEquipped then
		profile.Weapons[weaponId] = nil
		profile.Bonuses[weaponId] = nil
		local index = table.find(profile.Order, weaponId)
		if index then
			table.remove(profile.Order, index)
		end
	end

	sendSnapshot(player)
	return true, if enabled then "Aiguille de Leyde equipee" else "Aiguille de Leyde retiree"
end

function WeaponLoadoutService.Start()
	getLoadoutRemote.OnServerInvoke = function(player)
		return buildSnapshot(player)
	end
	RunStateService.RunStarted:Connect(WeaponLoadoutService.ResetRun)

	for _, message in ipairs(validationErrors) do
		DebugLog.Warn("Weapon", "Definition d'arme exclue", { Error = message })
	end

	DebugLog.Info("Weapon", "Catalogue d'armes valide", {
		Definitions = (function()
			local count = 0
			for _ in pairs(validDefinitions) do count += 1 end
			return count
		end)(),
	})
end

return WeaponLoadoutService
