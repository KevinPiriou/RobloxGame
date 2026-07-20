--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DebugLog = require(Shared:WaitForChild("DebugLog"))
local Perks = require(Shared:WaitForChild("Perks"))
local WeaponConfig = require(Shared:WaitForChild("WeaponConfig"))

local CombatStateService = require(script.Parent:WaitForChild("CombatStateService"))
local PerkService = require(script.Parent:WaitForChild("PerkService"))
local RunActionCreditService = require(script.Parent:WaitForChild("RunActionCreditService"))
local RunStateService = require(script.Parent:WaitForChild("RunStateService"))
local WeaponLoadoutService = require(script.Parent:WaitForChild("WeaponLoadoutService"))

local WeaponProgressionService = {}
local rng = Random.new()
local profilesByUserId = {}
local isStarted = false

local function remote(name: string): RemoteEvent
	local existing = ReplicatedStorage:FindFirstChild(name)
	if existing == nil then
		existing = Instance.new("RemoteEvent")
		existing.Name = name
		existing.Parent = ReplicatedStorage
	end
	assert(existing:IsA("RemoteEvent"), name .. " doit etre un RemoteEvent")
	return existing
end

local showRemote = remote("WeaponProgression_Show")
local hideRemote = remote("WeaponProgression_Hide")
local selectRemote = remote("WeaponProgression_Select")
local passRemote = remote("WeaponProgression_Pass")
local banRemote = remote("WeaponProgression_Ban")

local function profile(player: Player)
	local value = profilesByUserId[player.UserId]
	if value == nil then
		value = { PendingLevels = {}, ActiveChoice = nil, NextChoiceId = 0, BannedWeapons = {} }
		profilesByUserId[player.UserId] = value
	end
	return value
end

local function pauseReason(player: Player): string
	return "WeaponChoice_" .. tostring(player.UserId)
end

local function pickRarity(player: Player): string
	local luck = math.max(0, tonumber(PerkService.GetStats(player).Luck) or 0)
	local total = 0
	local entries = {}
	for _, rarityId in ipairs(Perks.RarityOrder) do
		local weight = Perks.Rarities[rarityId].Weight
		if rarityId == "Rare" then weight += luck * 80 end
		if rarityId == "Epic" then weight += luck * 45 end
		if rarityId == "Legendary" then weight += luck * 20 end
		total += weight
		table.insert(entries, { Id = rarityId, Weight = weight })
	end
	local roll = rng:NextNumber(0, total)
	local cursor = 0
	for _, entry in ipairs(entries) do
		cursor += entry.Weight
		if roll <= cursor then return entry.Id end
	end
	return "Common"
end

local RARITY_MULTIPLIER = { Common = 1, Rare = 1.5, Epic = 2.25, Legendary = 3.5 }

local function amountFor(evolution, rarityId: string): number
	local raw = evolution.Amount * (RARITY_MULTIPLIER[rarityId] or 1)
	if evolution.StatId == "ProjectileCount" or evolution.StatId == "BounceCount" or evolution.StatId == "ZoneRadius" then
		return math.max(1, math.floor(raw + 0.5))
	end
	return math.floor(raw * 10 + 0.5) / 10
end

local function formatEffect(statId: string, amount: number): string
	if statId == "ProjectileCount" then return "+" .. amount .. " projectile" .. (amount > 1 and "s" or "") end
	if statId == "BounceCount" then return "+" .. amount .. " rebond" .. (amount > 1 and "s" or "") end
	if statId == "ZoneRadius" then return "+" .. amount .. " studs de rayon" end
	return "+" .. amount .. " degats de l'arme"
end

local function candidatePool(player: Player, state)
	local candidates = {}
	local equipped = WeaponLoadoutService.GetEquippedWeaponIds(player)
	if #equipped < 4 then
		for weaponId, definition in pairs(WeaponConfig.Definitions) do
			if definition.Lifecycle == "Production"
				and not WeaponLoadoutService.HasWeapon(player, weaponId)
				and state.BannedWeapons[weaponId] ~= true
			then
				table.insert(candidates, { Key = "new:" .. weaponId, WeaponId = weaponId, Kind = "New" })
			end
		end
	end

	for _, weaponId in ipairs(equipped) do
		if state.BannedWeapons[weaponId] ~= true then
			local stats = WeaponLoadoutService.GetRuntimeStats(player, weaponId)
			for _, evolution in ipairs(WeaponConfig.Evolutions[weaponId] or {}) do
				local current = stats and tonumber(stats[evolution.StatId]) or 0
				if evolution.Cap == nil or current < evolution.Cap then
				table.insert(candidates, {
						Key = weaponId .. ":" .. evolution.StatId,
						WeaponId = weaponId,
						Kind = "Evolution",
					Evolution = evolution,
					Current = current,
					})
				end
			end
		end
	end
	return candidates
end

local function makeChoice(player: Player, level: number)
	local state = profile(player)
	local pool = candidatePool(player, state)
	local choices = {}
	local byId = {}
	for optionIndex = 1, math.min(3, #pool) do
		local source = table.remove(pool, rng:NextInteger(1, #pool))
		local definition = WeaponConfig.GetDefinition(source.WeaponId)
		local rarityId = if source.Kind == "New" then "Common" else pickRarity(player)
		local rarity = Perks.Rarities[rarityId]
		local amount = 0
		local statId = nil
		local effect = "AJOUTE L'ARME AU LOADOUT"
		if source.Evolution then
			statId = source.Evolution.StatId
			amount = amountFor(source.Evolution, rarityId)
			if source.Evolution.Cap ~= nil then
				amount = math.max(0, math.min(amount, source.Evolution.Cap - source.Current))
			end
			effect = formatEffect(statId, amount)
		end
		local option = {
			OptionId = tostring(optionIndex), WeaponId = source.WeaponId, Name = definition.Name,
			Icon = definition.Icon, Rarity = rarityId, RarityName = rarity.DisplayName,
			RarityColor = rarity.Color, Kind = source.Kind, StatId = statId, Amount = amount,
			Effect = effect, CurrentLevel = WeaponLoadoutService.GetWeaponLevel(player, source.WeaponId),
		}
		table.insert(choices, option)
		byId[option.OptionId] = option
	end
	state.NextChoiceId += 1
	return { ChoiceId = tostring(player.UserId) .. "_W_" .. state.NextChoiceId, Level = level, Choices = choices, ById = byId }
end

local function showNext(player: Player)
	local state = profile(player)
	if state.ActiveChoice ~= nil then return end
	local level = table.remove(state.PendingLevels, 1)
	if level == nil then
		CombatStateService.Resume(pauseReason(player))
		hideRemote:FireClient(player)
		return
	end
	local choice = makeChoice(player, level)
	if #choice.Choices == 0 then
		DebugLog.Warn("Weapon", "Aucune evolution d'arme disponible", { Player = player.Name, Level = level })
		task.defer(showNext, player)
		return
	end
	state.ActiveChoice = choice
	CombatStateService.Pause(pauseReason(player))
	showRemote:FireClient(player, { ChoiceId = choice.ChoiceId, Level = level, Choices = choice.Choices })
end

local function resolve(player: Player)
	local state = profile(player)
	state.ActiveChoice = nil
	task.defer(showNext, player)
end

local function activeOption(player: Player, choiceId, optionId)
	local choice = profile(player).ActiveChoice
	if choice == nil or choice.ChoiceId ~= choiceId then return nil end
	return choice.ById[tostring(optionId)]
end

function WeaponProgressionService.SetupPlayer(player: Player)
	profile(player)
end

function WeaponProgressionService.RemovePlayer(player: Player)
	CombatStateService.Resume(pauseReason(player))
	profilesByUserId[player.UserId] = nil
end

function WeaponProgressionService.QueueLevelUp(player: Player, level: number)
	local state = profile(player)
	table.insert(state.PendingLevels, level)
	showNext(player)
end

function WeaponProgressionService.Start()
	if isStarted then return end
	isStarted = true
	selectRemote.OnServerEvent:Connect(function(player, choiceId, optionId)
		local option = activeOption(player, choiceId, optionId)
		if option == nil then return end
		local success = WeaponLoadoutService.ApplyProgression(player, option.WeaponId, option.StatId, option.Amount)
		if success then resolve(player) end
	end)
	passRemote.OnServerEvent:Connect(function(player, choiceId)
		local choice = profile(player).ActiveChoice
		if choice == nil or choice.ChoiceId ~= choiceId then return end
		if RunActionCreditService.TryConsume(player, "Pass") then resolve(player) end
	end)
	banRemote.OnServerEvent:Connect(function(player, choiceId, optionId)
		local option = activeOption(player, choiceId, optionId)
		if option == nil then return end
		if RunActionCreditService.TryConsume(player, "Ban") then
			local state = profile(player)
			state.BannedWeapons[option.WeaponId] = true
			resolve(player)
		end
	end)
	RunStateService.RunStarted:Connect(function(player)
		local state = profile(player)
		state.PendingLevels = {}
		state.ActiveChoice = nil
		state.BannedWeapons = {}
	end)
	RunStateService.RunEnded:Connect(WeaponProgressionService.RemovePlayer)
	DebugLog.Info("Weapon", "Progression d'armes demarree")
end

return WeaponProgressionService
