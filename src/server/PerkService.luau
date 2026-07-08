local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Perks = require(Shared:WaitForChild("Perks"))

local CombatStateService = require(script.Parent:WaitForChild("CombatStateService"))
local JumpBonusService = require(script.Parent:WaitForChild("JumpBonusService"))

local PerkService = {}

local rng = Random.new()
local profilesByUserId = {}
local characterConnectionsByUserId = {}
local baseWalkSpeedByUserId = {}
local isStarted = false

local function getOrCreateRemote(remoteName)
	local remote = ReplicatedStorage:FindFirstChild(remoteName)

	if remote == nil then
		remote = Instance.new("RemoteEvent")
		remote.Name = remoteName
		remote.Parent = ReplicatedStorage
	end

	assert(remote:IsA("RemoteEvent"), remoteName .. " doit etre un RemoteEvent.")

	return remote
end

local showChoicesRemote = getOrCreateRemote("Perk_ShowChoices")
local hideChoicesRemote = getOrCreateRemote("Perk_HideChoices")
local selectChoiceRemote = getOrCreateRemote("Perk_SelectChoice")
local updatePerksRemote = getOrCreateRemote("Perk_UpdateStats")

local function createEmptyStats()
	return {
		MoveSpeedPercent = 0,
		JumpPercent = 0,
		AttackSpeedPercent = 0,
		ProjectileCount = 0,
		CollectRadius = 0,
		DamagePercent = 0,
		ProjectileSpeedPercent = 0,
		EffectDurationPercent = 0,
		BounceCount = 0,
		CritChance = 0,
		CritMultiplierBonus = 0,
		LifeStealPercent = 0,
		HealthRegen = 0,
		Shield = 0,
		XpGainPercent = 0,
		GoldGainPercent = 0,
		Luck = 0,
		ArmorPercent = 0,
		EnemyCountPercent = 0,
		FlatDamage = 0,
		EliteFlatDamage = 0,
	}
end

local function getPauseReason(player)
	return "PerkChoice_" .. player.UserId
end

local function getOrCreateProfile(player)
	local profile = profilesByUserId[player.UserId]

	if profile == nil then
		profile = {
			Stats = createEmptyStats(),
			StacksByPerkId = {},
			PendingLevels = {},
			ActiveChoice = nil,
			NextChoiceId = 0,
			CurrentShield = 0,
			XpRemainder = 0,
			GoldRemainder = 0,
		}
		profilesByUserId[player.UserId] = profile
	end

	return profile
end

local function getHumanoid(player)
	local character = player.Character

	if character == nil then
		return nil
	end

	return character:FindFirstChildOfClass("Humanoid")
end

local function disableNativeHealthRegen(character)
	task.defer(function()
		local healthScript = character:FindFirstChild("Health")

		if healthScript == nil then
			healthScript = character:WaitForChild("Health", 2)
		end

		if healthScript ~= nil and (healthScript:IsA("Script") or healthScript:IsA("LocalScript")) then
			healthScript.Disabled = true
		end
	end)
end

local function applyMovementStats(player)
	local humanoid = getHumanoid(player)

	if humanoid == nil then
		return
	end

	if baseWalkSpeedByUserId[player.UserId] == nil then
		baseWalkSpeedByUserId[player.UserId] = humanoid.WalkSpeed
	end

	local profile = getOrCreateProfile(player)
	local moveMultiplier = 1 + profile.Stats.MoveSpeedPercent
	local jumpMultiplier = 1 + profile.Stats.JumpPercent

	humanoid.WalkSpeed = baseWalkSpeedByUserId[player.UserId] * moveMultiplier
	JumpBonusService.SetExternalJumpMultiplier(player, jumpMultiplier)
end

local function sendPerkStats(player)
	local profile = getOrCreateProfile(player)

	updatePerksRemote:FireClient(player, {
		Stats = profile.Stats,
		CurrentShield = profile.CurrentShield,
		MaxShield = profile.Stats.Shield,
		StacksByPerkId = profile.StacksByPerkId,
	})
end

local function applyHealthRegen(player, deltaTime)
	local profile = profilesByUserId[player.UserId]

	if profile == nil then
		return
	end

	local healthRegen = profile.Stats.HealthRegen or 0

	if healthRegen <= 0 then
		return
	end

	local humanoid = getHumanoid(player)

	if humanoid == nil or humanoid.Health <= 0 or humanoid.Health >= humanoid.MaxHealth then
		return
	end

	humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + (healthRegen * deltaTime))
end

local function getDefinitionById(perkId)
	for _, definition in ipairs(Perks.Definitions) do
		if definition.Id == perkId then
			return definition
		end
	end

	return nil
end

local function addStats(targetStats, addedStats)
	for statName, value in pairs(addedStats) do
		targetStats[statName] = (targetStats[statName] or 0) + value
	end
end

local function pickRarity(player)
	local profile = getOrCreateProfile(player)
	local luck = math.max(0, profile.Stats.Luck or 0)
	local weightedRarities = {}
	local totalWeight = 0

	for _, rarityId in ipairs(Perks.RarityOrder) do
		local rarity = Perks.Rarities[rarityId]
		local weight = rarity.Weight

		if rarityId == "Rare" then
			weight += luck * 80
		elseif rarityId == "Epic" then
			weight += luck * 45
		elseif rarityId == "Legendary" then
			weight += luck * 20
		end

		totalWeight += weight
		table.insert(weightedRarities, {
			Id = rarityId,
			Weight = weight,
		})
	end

	local roll = rng:NextNumber(0, totalWeight)
	local cursor = 0

	for _, entry in ipairs(weightedRarities) do
		cursor += entry.Weight

		if roll <= cursor then
			return entry.Id
		end
	end

	return "Common"
end

local function createChoiceOption(definition, rarityId, optionIndex)
	local rarity = Perks.Rarities[rarityId]
	local variant = definition.Variants[rarityId]

	return {
		OptionId = tostring(optionIndex),
		PerkId = definition.Id,
		Name = definition.Name,
		Description = variant.Description,
		Rarity = rarityId,
		RarityName = rarity.DisplayName,
		RarityColor = rarity.Color,
		Stats = variant.Stats,
	}
end

local function createChoice(player, level)
	local availableDefinitions = table.clone(Perks.Definitions)
	local choices = {}
	local choicesByOptionId = {}

	for optionIndex = 1, 3 do
		if #availableDefinitions <= 0 then
			break
		end

		local definitionIndex = rng:NextInteger(1, #availableDefinitions)
		local definition = table.remove(availableDefinitions, definitionIndex)
		local rarityId = pickRarity(player)
		local option = createChoiceOption(definition, rarityId, optionIndex)

		table.insert(choices, option)
		choicesByOptionId[option.OptionId] = option
	end

	local profile = getOrCreateProfile(player)
	profile.NextChoiceId += 1

	return {
		ChoiceId = tostring(player.UserId) .. "_" .. tostring(profile.NextChoiceId),
		Level = level,
		Choices = choices,
		ChoicesByOptionId = choicesByOptionId,
	}
end

local function showNextChoice(player)
	if player.Parent ~= Players then
		return
	end

	local profile = getOrCreateProfile(player)

	if profile.ActiveChoice ~= nil then
		return
	end

	local nextLevel = table.remove(profile.PendingLevels, 1)

	if nextLevel == nil then
		CombatStateService.Resume(getPauseReason(player))
		hideChoicesRemote:FireClient(player)
		return
	end

	local choice = createChoice(player, nextLevel)
	profile.ActiveChoice = choice

	CombatStateService.Pause(getPauseReason(player))
	showChoicesRemote:FireClient(player, {
		ChoiceId = choice.ChoiceId,
		Level = choice.Level,
		Choices = choice.Choices,
	})
end

local function applyChoice(player, option)
	local profile = getOrCreateProfile(player)
	local definition = getDefinitionById(option.PerkId)

	if definition == nil then
		return
	end

	addStats(profile.Stats, option.Stats)
	profile.StacksByPerkId[option.PerkId] = (profile.StacksByPerkId[option.PerkId] or 0) + 1

	if option.Stats.Shield ~= nil then
		profile.CurrentShield += option.Stats.Shield
	end

	applyMovementStats(player)
	sendPerkStats(player)
end

local function onChoiceSelected(player, choiceId, optionId)
	local profile = getOrCreateProfile(player)
	local activeChoice = profile.ActiveChoice

	if activeChoice == nil or activeChoice.ChoiceId ~= choiceId then
		return
	end

	local option = activeChoice.ChoicesByOptionId[tostring(optionId)]

	if option == nil then
		return
	end

	applyChoice(player, option)
	profile.ActiveChoice = nil

	if #profile.PendingLevels > 0 then
		task.defer(function()
			showNextChoice(player)
		end)
	else
		CombatStateService.Resume(getPauseReason(player))
		hideChoicesRemote:FireClient(player)
	end
end

function PerkService.SetupPlayer(player)
	getOrCreateProfile(player)

	if characterConnectionsByUserId[player.UserId] ~= nil then
		characterConnectionsByUserId[player.UserId]:Disconnect()
	end

	characterConnectionsByUserId[player.UserId] = player.CharacterAdded:Connect(function(character)
		baseWalkSpeedByUserId[player.UserId] = nil
		disableNativeHealthRegen(character)
		character:WaitForChild("Humanoid", 5)
		applyMovementStats(player)
		sendPerkStats(player)
	end)

	if player.Character ~= nil then
		disableNativeHealthRegen(player.Character)
	end

	applyMovementStats(player)
	sendPerkStats(player)
end

function PerkService.RemovePlayer(player)
	CombatStateService.Resume(getPauseReason(player))
	hideChoicesRemote:FireClient(player)
	JumpBonusService.SetExternalJumpMultiplier(player, 1)

	local connection = characterConnectionsByUserId[player.UserId]

	if connection ~= nil then
		connection:Disconnect()
	end

	characterConnectionsByUserId[player.UserId] = nil
	baseWalkSpeedByUserId[player.UserId] = nil
	profilesByUserId[player.UserId] = nil
end

function PerkService.QueueLevelUp(player, level)
	local profile = getOrCreateProfile(player)

	table.insert(profile.PendingLevels, level)
	showNextChoice(player)
end

function PerkService.GetStats(player)
	local profile = profilesByUserId[player.UserId]

	if profile == nil then
		return createEmptyStats()
	end

	return profile.Stats
end

function PerkService.GetProjectileCount(player)
	local stats = PerkService.GetStats(player)

	return math.clamp(1 + math.floor(stats.ProjectileCount or 0), 1, 24)
end

function PerkService.GetAttackCooldown(player, baseCooldown)
	local stats = PerkService.GetStats(player)
	local attackSpeedMultiplier = math.max(0.1, 1 + (stats.AttackSpeedPercent or 0))

	return math.max(0.08, baseCooldown / attackSpeedMultiplier)
end

function PerkService.GetProjectileSpeed(player, baseSpeed)
	local stats = PerkService.GetStats(player)

	return baseSpeed * (1 + (stats.ProjectileSpeedPercent or 0))
end

function PerkService.GetAttackDuration(player, baseDuration)
	local stats = PerkService.GetStats(player)

	return baseDuration * (1 + (stats.EffectDurationPercent or 0))
end

function PerkService.GetBounceCount(player)
	local stats = PerkService.GetStats(player)

	return math.max(0, math.floor(stats.BounceCount or 0))
end

function PerkService.GetCollectDistance(player, baseDistance)
	local stats = PerkService.GetStats(player)

	return baseDistance + (stats.CollectRadius or 0)
end

function PerkService.GetXpAmount(player, baseAmount)
	local profile = getOrCreateProfile(player)
	local stats = PerkService.GetStats(player)
	local exactAmount = (baseAmount * (1 + (stats.XpGainPercent or 0))) + profile.XpRemainder
	local amount = math.floor(exactAmount)

	profile.XpRemainder = exactAmount - amount

	return math.max(1, amount)
end

function PerkService.GetGoldAmount(player, baseAmount)
	local profile = getOrCreateProfile(player)
	local stats = PerkService.GetStats(player)
	local exactAmount = (baseAmount * (1 + (stats.GoldGainPercent or 0))) + profile.GoldRemainder
	local amount = math.floor(exactAmount)

	profile.GoldRemainder = exactAmount - amount

	return math.max(1, amount)
end

function PerkService.GetCoinDropChance(player, baseChance)
	local stats = PerkService.GetStats(player)

	return math.clamp(baseChance + (stats.Luck or 0), 0, 1)
end

function PerkService.GetEnemyCountMultiplier(player)
	local stats = PerkService.GetStats(player)

	return math.max(1, 1 + (stats.EnemyCountPercent or 0))
end

function PerkService.CalculateOutgoingDamage(player, baseDamage, monster)
	local stats = PerkService.GetStats(player)
	local damage = baseDamage + (stats.FlatDamage or 0)

	if monster ~= nil and monster:GetAttribute("IsElite") == true then
		damage += stats.EliteFlatDamage or 0
	end

	damage *= 1 + (stats.DamagePercent or 0)

	local critChance = math.clamp(stats.CritChance or 0, 0, 1)

	if critChance > 0 and rng:NextNumber() <= critChance then
		damage *= 1.5 + (stats.CritMultiplierBonus or 0)
	end

	return damage
end

function PerkService.CalculateIncomingDamage(player, baseDamage)
	local profile = getOrCreateProfile(player)
	local armorPercent = math.clamp(profile.Stats.ArmorPercent or 0, 0, 0.8)
	local damage = baseDamage * (1 - armorPercent)

	if profile.CurrentShield > 0 then
		local absorbed = math.min(profile.CurrentShield, damage)

		profile.CurrentShield -= absorbed
		damage -= absorbed
		sendPerkStats(player)
	end

	return math.max(0, damage)
end

function PerkService.ApplyLifeSteal(player, damageDealt)
	local stats = PerkService.GetStats(player)
	local lifeStealPercent = stats.LifeStealPercent or 0

	if lifeStealPercent <= 0 or damageDealt <= 0 then
		return
	end

	local humanoid = getHumanoid(player)

	if humanoid == nil or humanoid.Health <= 0 then
		return
	end

	local healAmount = damageDealt * lifeStealPercent

	humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + healAmount)
end

function PerkService.GetShieldState(player)
	local profile = profilesByUserId[player.UserId]

	if profile == nil then
		return 0, 0
	end

	return profile.CurrentShield, profile.Stats.Shield or 0
end

function PerkService.Start()
	if isStarted then
		return
	end

	isStarted = true
	selectChoiceRemote.OnServerEvent:Connect(onChoiceSelected)

	RunService.Heartbeat:Connect(function(deltaTime)
		if CombatStateService.IsPaused() then
			return
		end

		for _, player in ipairs(Players:GetPlayers()) do
			applyHealthRegen(player, deltaTime)
		end
	end)
end

return PerkService
