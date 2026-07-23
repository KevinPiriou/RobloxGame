local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))
local DebugLog = require(Shared:WaitForChild("DebugLog"))
local PerkConfig = require(Shared:WaitForChild("PerkConfig"))
local Perks = require(Shared:WaitForChild("Perks"))

local CombatStateService = require(script.Parent:WaitForChild("CombatStateService"))
local CharacterService = require(script.Parent:WaitForChild("CharacterService"))
local CommerceService = require(script.Parent:WaitForChild("CommerceService"))
local GameplayFeedbackService = require(script.Parent:WaitForChild("GameplayFeedbackService"))
local JumpBonusService = require(script.Parent:WaitForChild("JumpBonusService"))
local RunAnalyticsService = require(script.Parent:WaitForChild("RunAnalyticsService"))
local RunActionCreditService = require(script.Parent:WaitForChild("RunActionCreditService"))

local PerkService = {}

local rng = Random.new()
local profilesByUserId = {}
local characterConnectionsByUserId = {}
local baseWalkSpeedByUserId = {}
local baseMaxHealthByUserId = {}
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
local rerollChoiceRemote = getOrCreateRemote("Perk_RerollRequest")
local passChoiceRemote = getOrCreateRemote("Perk_PassRequest")
local banChoiceRemote = getOrCreateRemote("Perk_BanRequest")
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
		MaxHealthBonus = 0,
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
			RerollsUsedThisRun = 0,
			IsRerollPending = false,
			BannedPerkIds = {},
		}
		profilesByUserId[player.UserId] = profile
	end

	return profile
end

local function getRerollUsesThisRun(profile)
	return math.clamp(
		math.floor(tonumber(profile.RerollsUsedThisRun) or 0),
		0,
		PerkConfig.MaxRerollsPerRun
	)
end

local function publishRerollUsesThisRun(player, profile)
	if player.Parent ~= Players then
		return
	end

	player:SetAttribute("PerkRerollsUsedThisRun", getRerollUsesThisRun(profile))
	player:SetAttribute("PerkRerollsMaxUses", PerkConfig.MaxRerollsPerRun)
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
		baseWalkSpeedByUserId[player.UserId] = CombatConfig.PlayerBaseWalkSpeed
	end

	local profile = getOrCreateProfile(player)
	local moveMultiplier = 1 + profile.Stats.MoveSpeedPercent
	local jumpMultiplier = 1 + profile.Stats.JumpPercent

	humanoid.WalkSpeed = baseWalkSpeedByUserId[player.UserId] * moveMultiplier
	JumpBonusService.SetExternalJumpMultiplier(player, jumpMultiplier)
end

local function applyMaxHealthStats(player, restoreToMaximum: boolean?)
	local humanoid = getHumanoid(player)

	if humanoid == nil then
		return
	end

	local stats = PerkService.GetStats(player)
	local baseMaxHealth = baseMaxHealthByUserId[player.UserId]

	if baseMaxHealth == nil then
		baseMaxHealth = math.max(1, humanoid.MaxHealth)
		baseMaxHealthByUserId[player.UserId] = baseMaxHealth
	end

	local targetMaxHealth = math.max(1, baseMaxHealth + (stats.MaxHealthBonus or 0))
	humanoid.MaxHealth = targetMaxHealth
	if restoreToMaximum then
		humanoid.Health = targetMaxHealth
	else
		humanoid.Health = math.min(humanoid.Health, targetMaxHealth)
	end
end

local function getDisplayStatsSnapshot(player, profile)
	local stats = PerkService.GetStats(player)
	local humanoid = getHumanoid(player)
	local damageMultiplier = 1 + (stats.DamagePercent or 0)
	local attackCooldown = math.max(
		0.08,
		CombatConfig.FireballCooldown / math.max(0.1, 1 + (stats.AttackSpeedPercent or 0))
	)
	local baseDamage = (CombatConfig.FireballDamage + (stats.FlatDamage or 0)) * damageMultiplier
	local eliteDamage = (CombatConfig.FireballDamage + (stats.FlatDamage or 0) + (stats.EliteFlatDamage or 0))
		* damageMultiplier

	return {
		MaxHealth = if humanoid ~= nil then humanoid.MaxHealth else 100,
		MoveSpeed = if humanoid ~= nil then humanoid.WalkSpeed else CombatConfig.PlayerBaseWalkSpeed,
		JumpMode = if humanoid == nil or humanoid.UseJumpPower then "Power" else "Height",
		JumpValue = if humanoid ~= nil
			then (if humanoid.UseJumpPower then humanoid.JumpPower else humanoid.JumpHeight)
			else CombatConfig.PlayerBaseJumpPower,
		CurrentShield = profile.CurrentShield,
		MaxShield = stats.Shield or 0,
		HealthRegen = stats.HealthRegen or 0,
		ArmorPercent = math.clamp(stats.ArmorPercent or 0, 0, 0.8),
		LifeStealPercent = stats.LifeStealPercent or 0,
		CritChance = math.clamp(stats.CritChance or 0, 0, 1),
		CritDamageMultiplier = 1.5 + (stats.CritMultiplierBonus or 0),
		BaseDamage = baseDamage,
		EliteDamage = eliteDamage,
		AttackRate = 1 / attackCooldown,
		ProjectileCount = math.clamp(1 + math.floor(stats.ProjectileCount or 0), 1, 24),
		BounceCount = math.max(0, math.floor(stats.BounceCount or 0)),
		ProjectileSpeed = CombatConfig.FireballSpeed * (1 + (stats.ProjectileSpeedPercent or 0)),
		ProjectileDuration = CombatConfig.FireballLifetime * (1 + (stats.EffectDurationPercent or 0)),
		CollectRadius = (CombatConfig.XpCollectDistance * CharacterService.GetPlayerStatBaseMultiplier(player, "CollectRadius"))
			+ (stats.CollectRadius or 0),
		XpMultiplier = 1 + (stats.XpGainPercent or 0),
		GoldMultiplier = 1 + (stats.GoldGainPercent or 0),
		Luck = stats.Luck or 0,
		EnemyMultiplier = math.max(1, 1 + (stats.EnemyCountPercent or 0)),
	}
end

local function sendPerkStats(player)
	local profile = getOrCreateProfile(player)

	updatePerksRemote:FireClient(player, {
		Stats = PerkService.GetStats(player),
		DisplayStats = getDisplayStatsSnapshot(player, profile),
		CurrentShield = profile.CurrentShield,
		MaxShield = PerkService.GetStats(player).Shield or 0,
		StacksByPerkId = profile.StacksByPerkId,
	})
end

local function applyHealing(player, amount, feedbackKind)
	local humanoid = getHumanoid(player)

	if humanoid == nil or humanoid.Health <= 0 then
		return 0
	end

	local previousHealth = humanoid.Health
	humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + math.max(0, amount))
	local healedAmount = humanoid.Health - previousHealth

	if healedAmount > 0 then
		RunAnalyticsService.RecordHealing(player, healedAmount)
		GameplayFeedbackService.Queue(player, feedbackKind, healedAmount)
	end

	return healedAmount
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

	applyHealing(player, healthRegen * deltaTime, "HealRegen")
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

local PREVIEW_RULES = {
	{ StatName = "MoveSpeedPercent", Label = "Bonus vitesse", Format = "Percent" },
	{ StatName = "JumpPercent", Label = "Puissance saut", Format = "Percent" },
	{ StatName = "AttackSpeedPercent", Label = "Vitesse attaque", Format = "AttackRate" },
	{ StatName = "ProjectileCount", Label = "Projectiles", Format = "ProjectileCount" },
	{ StatName = "CollectRadius", Label = "Rayon recolte", Format = "CollectRadius" },
	{ StatName = "DamagePercent", Label = "Degats", Format = "Damage" },
	{ StatName = "ProjectileSpeedPercent", Label = "Vitesse projectile", Format = "ProjectileSpeed" },
	{ StatName = "EffectDurationPercent", Label = "Duree projectile", Format = "EffectDuration" },
	{ StatName = "BounceCount", Label = "Rebonds", Format = "Integer" },
	{ StatName = "CritChance", Label = "Chance critique", Format = "CritChance" },
	{ StatName = "CritMultiplierBonus", Label = "Degats critiques", Format = "CritMultiplier" },
	{ StatName = "LifeStealPercent", Label = "Vol de vie", Format = "Percent" },
	{ StatName = "HealthRegen", Label = "Regen PV", Format = "Regen" },
	{ StatName = "MaxHealthBonus", Label = "PV maximum", Format = "Integer" },
	{ StatName = "Shield", Label = "Bouclier", Format = "Shield" },
	{ StatName = "XpGainPercent", Label = "Gain XP", Format = "Multiplier" },
	{ StatName = "GoldGainPercent", Label = "Gain or", Format = "Multiplier" },
	{ StatName = "Luck", Label = "Chance", Format = "Percent" },
	{ StatName = "ArmorPercent", Label = "Armure", Format = "Armor" },
	{ StatName = "EnemyCountPercent", Label = "Plus d'ennemis", Format = "Multiplier" },
	{ StatName = "FlatDamage", Label = "Degats bruts", Format = "Integer" },
	{ StatName = "EliteFlatDamage", Label = "Degats elites", Format = "Integer" },
}

local function formatPreviewDecimal(value, decimals)
	local text = string.format("%." .. tostring(decimals) .. "f", value)

	return string.gsub(text, "%.", ",")
end

local function getPreviewValue(rule, stats, currentShield)
	local value = stats[rule.StatName] or 0

	if rule.Format == "ProjectileCount" then
		return math.clamp(1 + math.floor(value), 1, 24)
	end

	if rule.Format == "CollectRadius" then
		return CombatConfig.XpCollectDistance + value
	end

	if rule.Format == "AttackRate" then
		local cooldown = math.max(0.08, CombatConfig.FireballCooldown / math.max(0.1, 1 + value))

		return 1 / cooldown
	end

	if rule.Format == "Damage" then
		return (CombatConfig.FireballDamage + (stats.FlatDamage or 0)) * (1 + value)
	end

	if rule.Format == "ProjectileSpeed" then
		return CombatConfig.FireballSpeed * (1 + value)
	end

	if rule.Format == "EffectDuration" then
		return CombatConfig.FireballLifetime * (1 + value)
	end

	if rule.Format == "CritChance" then
		return math.clamp(value, 0, 1)
	end

	if rule.Format == "CritMultiplier" then
		return 1.5 + value
	end

	if rule.Format == "Shield" then
		return currentShield
	end

	if rule.Format == "Multiplier" then
		return 1 + value
	end

	if rule.Format == "Armor" then
		return math.clamp(value, 0, 0.8)
	end

	return value
end

local function formatPreviewValue(rule, value)
	if rule.Format == "Percent" or rule.Format == "CritChance" or rule.Format == "Armor" then
		return tostring(math.floor((value * 100) + 0.5)) .. "%"
	end

	if rule.Format == "CritMultiplier" then
		return tostring(math.floor((value * 100) + 0.5)) .. "%"
	end

	if rule.Format == "Multiplier" then
		return "x" .. formatPreviewDecimal(value, 2)
	end

	if rule.Format == "Regen" then
		return formatPreviewDecimal(value, 1) .. "/s"
	end

	if rule.Format == "CollectRadius" then
		return formatPreviewDecimal(value, 1)
	end

	if rule.Format == "AttackRate" then
		return formatPreviewDecimal(value, 2) .. "/s"
	end

	if rule.Format == "Damage" then
		return formatPreviewDecimal(value, 1)
	end

	if rule.Format == "ProjectileSpeed" then
		return tostring(math.floor(value + 0.5))
	end

	if rule.Format == "EffectDuration" then
		return formatPreviewDecimal(value, 1) .. "s"
	end

	return tostring(math.floor(value + 0.5))
end

local function createChoicePreview(profile, addedStats)
	local nextStats = table.clone(profile.Stats)
	addStats(nextStats, addedStats)

	local currentShield = profile.CurrentShield
	local nextShield = currentShield + (addedStats.Shield or 0)
	local previewLines = {}

	for _, rule in ipairs(PREVIEW_RULES) do
		if addedStats[rule.StatName] ~= nil then
			local currentValue = getPreviewValue(rule, profile.Stats, currentShield)
			local nextValue = getPreviewValue(rule, nextStats, nextShield)

			table.insert(previewLines, {
				Label = rule.Label,
				Current = formatPreviewValue(rule, currentValue),
				Next = formatPreviewValue(rule, nextValue),
			})
		end
	end

	return previewLines
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

local function createChoiceOption(definition, rarityId, optionIndex, profile)
	local rarity = Perks.Rarities[rarityId]
	local variant = definition.Variants[rarityId]
	local currentStacks = profile.StacksByPerkId[definition.Id] or 0

	return {
		OptionId = tostring(optionIndex),
		PerkId = definition.Id,
		Name = definition.Name,
		Description = variant.Description,
		Rarity = rarityId,
		RarityName = rarity.DisplayName,
		RarityColor = rarity.Color,
		Stats = variant.Stats,
		PreviewLines = createChoicePreview(profile, variant.Stats),
		CurrentStacks = currentStacks,
		NextStacks = currentStacks + 1,
	}
end

local function createChoice(player, level, title)
	local choices = {}
	local choicesByOptionId = {}
	local profile = getOrCreateProfile(player)
	local availableDefinitions = {}

	for _, definition in ipairs(Perks.Definitions) do
		if profile.BannedPerkIds[definition.Id] ~= true then
			table.insert(availableDefinitions, definition)
		end
	end

	for optionIndex = 1, 3 do
		if #availableDefinitions <= 0 then
			break
		end

		local definitionIndex = rng:NextInteger(1, #availableDefinitions)
		local definition = table.remove(availableDefinitions, definitionIndex)
		local rarityId = pickRarity(player)
		local option = createChoiceOption(definition, rarityId, optionIndex, profile)

		table.insert(choices, option)
		choicesByOptionId[option.OptionId] = option
	end

	profile.NextChoiceId += 1

	return {
		ChoiceId = tostring(player.UserId) .. "_" .. tostring(profile.NextChoiceId),
		Level = level,
		Title = title,
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

	local nextRequest = table.remove(profile.PendingLevels, 1)

	if nextRequest == nil then
		CombatStateService.Resume(getPauseReason(player))
		hideChoicesRemote:FireClient(player)
		return
	end

	local nextLevel = nextRequest
	local title = nil

	if typeof(nextRequest) == "table" then
		nextLevel = nextRequest.Level
		title = nextRequest.Title
	end

	local choice = createChoice(player, nextLevel, title)
	profile.ActiveChoice = choice

	CombatStateService.Pause(getPauseReason(player))
	DebugLog.Info("Perks", "Choix de perk affiche", {
		Player = player.Name,
		Level = choice.Level,
		Title = choice.Title,
		ChoiceId = choice.ChoiceId,
		Choices = #choice.Choices,
	})
	showChoicesRemote:FireClient(player, {
		ChoiceId = choice.ChoiceId,
		Level = choice.Level,
		Title = choice.Title,
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
	RunAnalyticsService.RecordPerkSelected(player)
	DebugLog.Info("Perks", "Perk applique", {
		Player = player.Name,
		PerkId = option.PerkId,
		Name = option.Name,
		Rarity = option.Rarity,
		Stacks = profile.StacksByPerkId[option.PerkId],
	})

	if option.Stats.Shield ~= nil then
		local shieldGained = math.max(0, option.Stats.Shield)
		profile.CurrentShield += shieldGained

		if shieldGained > 0 then
			GameplayFeedbackService.Queue(player, "Shield", shieldGained)
		end
	end

	applyMovementStats(player)
	sendPerkStats(player)
end

local function resolveActiveChoiceWithoutSelection(player, profile)
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

local function onChoiceSelected(player, choiceId, optionId)
	local profile = getOrCreateProfile(player)
	local activeChoice = profile.ActiveChoice

	if activeChoice == nil or activeChoice.ChoiceId ~= choiceId then
		return
	end

	local option = activeChoice.ChoicesByOptionId[tostring(optionId)]

	if option == nil then
		DebugLog.Warn("Perks", "Choix perk refuse, option inconnue", {
			Player = player.Name,
			ChoiceId = choiceId,
			OptionId = optionId,
		})
		return
	end

	DebugLog.Info("Perks", "Choix perk selectionne", {
		Player = player.Name,
		ChoiceId = choiceId,
		OptionId = optionId,
		PerkId = option.PerkId,
	})

	applyChoice(player, option)
	resolveActiveChoiceWithoutSelection(player, profile)
end

local function onPassRequested(player, choiceId)
	if typeof(choiceId) ~= "string" then
		return
	end

	local profile = getOrCreateProfile(player)
	local activeChoice = profile.ActiveChoice

	if activeChoice == nil or activeChoice.ChoiceId ~= choiceId then
		return
	end

	local consumed, reason = RunActionCreditService.TryConsume(player, "Pass")

	if not consumed then
		DebugLog.Warn("Perks", "Passer perk refuse", {
			Player = player.Name,
			ChoiceId = choiceId,
			Reason = reason,
		})
		return
	end

	DebugLog.Info("Perks", "Choix de perk passe", {
		Player = player.Name,
		ChoiceId = choiceId,
	})
	resolveActiveChoiceWithoutSelection(player, profile)
end

local function onBanRequested(player, choiceId, optionId)
	if typeof(choiceId) ~= "string" then
		return
	end

	local profile = getOrCreateProfile(player)
	local activeChoice = profile.ActiveChoice

	if activeChoice == nil or activeChoice.ChoiceId ~= choiceId then
		return
	end

	local option = activeChoice.ChoicesByOptionId[tostring(optionId)]

	if option == nil then
		DebugLog.Warn("Perks", "Bannissement perk refuse, option inconnue", {
			Player = player.Name,
			ChoiceId = choiceId,
			OptionId = optionId,
		})
		return
	end

	local consumed, reason = RunActionCreditService.TryConsume(player, "Ban")

	if not consumed then
		DebugLog.Warn("Perks", "Bannissement perk refuse", {
			Player = player.Name,
			ChoiceId = choiceId,
			PerkId = option.PerkId,
			Reason = reason,
		})
		return
	end

	profile.BannedPerkIds[option.PerkId] = true
	local replacementChoice = createChoice(player, activeChoice.Level, activeChoice.Title)

	if #replacementChoice.Choices == 0 then
		DebugLog.Warn("Perks", "Bannissement perk termine sans offre de remplacement", {
			Player = player.Name,
			PerkId = option.PerkId,
		})
		resolveActiveChoiceWithoutSelection(player, profile)
		return
	end

	profile.ActiveChoice = replacementChoice
	DebugLog.Info("Perks", "Perk banni pour la run", {
		Player = player.Name,
		PerkId = option.PerkId,
		PreviousChoiceId = choiceId,
		ChoiceId = replacementChoice.ChoiceId,
	})
	showChoicesRemote:FireClient(player, {
		ChoiceId = replacementChoice.ChoiceId,
		Level = replacementChoice.Level,
		Title = replacementChoice.Title,
		Choices = replacementChoice.Choices,
	})
end

local function onRerollRequested(player, choiceId)
	if typeof(choiceId) ~= "string" then
		return
	end

	local profile = getOrCreateProfile(player)
	local activeChoice = profile.ActiveChoice

	if activeChoice == nil or activeChoice.ChoiceId ~= choiceId then
		DebugLog.Warn("Perks", "Reroll perk refuse, choix inactif", {
			Player = player.Name,
			ChoiceId = choiceId,
		})
		return
	end

	if profile.IsRerollPending then
		return
	end

	if getRerollUsesThisRun(profile) >= PerkConfig.MaxRerollsPerRun then
		DebugLog.Warn("Perks", "Reroll perk refuse, limite de run atteinte", {
			Player = player.Name,
			ChoiceId = choiceId,
			MaxUses = PerkConfig.MaxRerollsPerRun,
		})
		return
	end

	-- Le verrou est pose avant la lecture DataStore. Il empeche trois requetes
	-- rapides du meme choix de consommer plusieurs credits en parallele.
	profile.IsRerollPending = true

	local consumed, reason = CommerceService.TryConsumePerkReroll(player)
	profile.IsRerollPending = false

	if not consumed then
		DebugLog.Warn("Perks", "Reroll perk refuse", {
			Player = player.Name,
			ChoiceId = choiceId,
			Reason = reason,
		})
		return
	end

	profile.RerollsUsedThisRun = getRerollUsesThisRun(profile) + 1
	publishRerollUsesThisRun(player, profile)

	local rerolledChoice = createChoice(player, activeChoice.Level, activeChoice.Title)
	profile.ActiveChoice = rerolledChoice

	DebugLog.Info("Perks", "Offre de perk relancee", {
		Player = player.Name,
		PreviousChoiceId = choiceId,
		ChoiceId = rerolledChoice.ChoiceId,
		Level = rerolledChoice.Level,
	})
	showChoicesRemote:FireClient(player, {
		ChoiceId = rerolledChoice.ChoiceId,
		Level = rerolledChoice.Level,
		Title = rerolledChoice.Title,
		Choices = rerolledChoice.Choices,
	})
end

function PerkService.SetupPlayer(player)
	DebugLog.Info("Perks", "Setup joueur perks", {
		Player = player.Name,
	})
	local profile = getOrCreateProfile(player)
	publishRerollUsesThisRun(player, profile)

	if characterConnectionsByUserId[player.UserId] ~= nil then
		characterConnectionsByUserId[player.UserId]:Disconnect()
	end

	characterConnectionsByUserId[player.UserId] = player.CharacterAdded:Connect(function(character)
		baseWalkSpeedByUserId[player.UserId] = nil
		baseMaxHealthByUserId[player.UserId] = nil
		disableNativeHealthRegen(character)
		character:WaitForChild("Humanoid", 5)
		applyMovementStats(player)
		applyMaxHealthStats(player)
		sendPerkStats(player)
	end)

	if player.Character ~= nil then
		disableNativeHealthRegen(player.Character)
	end

	applyMovementStats(player)
	applyMaxHealthStats(player)
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
	baseMaxHealthByUserId[player.UserId] = nil
	profilesByUserId[player.UserId] = nil
end

function PerkService.ResetRun(player)
	local profile = getOrCreateProfile(player)

	CombatStateService.Resume(getPauseReason(player))
	profile.Stats = createEmptyStats()
	profile.StacksByPerkId = {}
	profile.PendingLevels = {}
	profile.ActiveChoice = nil
	profile.NextChoiceId = 0
	profile.CurrentShield = 0
	profile.XpRemainder = 0
	profile.GoldRemainder = 0
	profile.RerollsUsedThisRun = 0
	profile.IsRerollPending = false
	profile.BannedPerkIds = {}
	publishRerollUsesThisRun(player, profile)
	hideChoicesRemote:FireClient(player)
	applyMovementStats(player)
	applyMaxHealthStats(player, true)
	profile.CurrentShield = math.max(0, PerkService.GetStats(player).Shield or 0)
	sendPerkStats(player)
end

function PerkService.QueueLevelUp(player, level)
	local profile = getOrCreateProfile(player)

	table.insert(profile.PendingLevels, level)
	DebugLog.Info("Perks", "Level-up ajoute a la file perks", {
		Player = player.Name,
		Level = level,
		PendingCount = #profile.PendingLevels,
	})
	showNextChoice(player)
end

function PerkService.QueueBonusChoice(player, title)
	local profile = getOrCreateProfile(player)

	table.insert(profile.PendingLevels, {
		Level = title or "Bonus",
		Title = title or "Choix de perk",
	})
	DebugLog.Info("Perks", "Choix bonus ajoute a la file perks", {
		Player = player.Name,
		Title = title,
		PendingCount = #profile.PendingLevels,
	})
	showNextChoice(player)
end

function PerkService.GetStats(player)
	local profile = profilesByUserId[player.UserId]

	if profile == nil then
		return createEmptyStats()
	end

	local stats = table.clone(profile.Stats)
	stats.MaxHealthBonus = (stats.MaxHealthBonus or 0)
		+ CharacterService.GetPlayerStatAdditiveBonus(player, "MaxHealthBonus")
	stats.Shield = (stats.Shield or 0)
		+ CharacterService.GetPlayerStatAdditiveBonus(player, "Shield")
	stats.AttackSpeedPercent = (stats.AttackSpeedPercent or 0)
		+ CharacterService.GetPlayerStatAdditiveBonus(player, "AttackSpeedPercent")
	stats.CritChance = (stats.CritChance or 0)
		+ CharacterService.GetPlayerStatAdditiveBonus(player, "CritChance")
	stats.HealthRegen = (stats.HealthRegen or 0)
		+ CharacterService.GetPlayerStatAdditiveBonus(player, "HealthRegen")
	return stats
end

function PerkService.RefreshCharacterDerivedStats(player)
	if profilesByUserId[player.UserId] ~= nil then
		sendPerkStats(player)
	end
end

function PerkService.GetRunPerkCount(player)
	local profile = profilesByUserId[player.UserId]

	if profile == nil then
		return 0
	end

	local count = 0

	for _, stackCount in pairs(profile.StacksByPerkId) do
		count += math.max(0, math.floor(stackCount or 0))
	end

	return count
end

function PerkService.GetRunBuild(player)
	local profile = profilesByUserId[player.UserId]

	if profile == nil then
		return {
			WeaponId = CombatConfig.FireballTemplateName,
			Perks = {},
			Stats = createEmptyStats(),
		}
	end

	local perks = {}

	for perkId, stacks in pairs(profile.StacksByPerkId) do
		table.insert(perks, {
			Id = tostring(perkId),
			Stacks = math.max(0, math.floor(stacks or 0)),
		})
	end

	table.sort(perks, function(left, right)
		return left.Id < right.Id
	end)

	return {
		WeaponId = CombatConfig.FireballTemplateName,
		Perks = perks,
		Stats = table.clone(profile.Stats),
	}
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
	return PerkService.GetEffectDuration(player, baseDuration)
end

function PerkService.GetEffectDuration(player, baseDuration)
	local stats = PerkService.GetStats(player)

	return baseDuration * (1 + (stats.EffectDurationPercent or 0))
end

function PerkService.ApplyRunItemStats(player, addedStats)
	if player == nil or typeof(addedStats) ~= "table" then
		return
	end

	local profile = getOrCreateProfile(player)
	addStats(profile.Stats, addedStats)
	applyMovementStats(player)
	applyMaxHealthStats(player)
	sendPerkStats(player)
end

function PerkService.GetBounceCount(player)
	local stats = PerkService.GetStats(player)

	return math.max(0, math.floor(stats.BounceCount or 0))
end

function PerkService.GetCollectDistance(player, baseDistance)
	local stats = PerkService.GetStats(player)

	return (baseDistance * CharacterService.GetPlayerStatBaseMultiplier(player, "CollectRadius"))
		+ (stats.CollectRadius or 0)
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

	local isCritical = critChance > 0 and rng:NextNumber() <= critChance

	if isCritical then
		damage *= 1.5 + (stats.CritMultiplierBonus or 0)
	end

	return damage, isCritical
end

function PerkService.CalculateIncomingDamage(player, baseDamage)
	local profile = getOrCreateProfile(player)
	local armorPercent = math.clamp(profile.Stats.ArmorPercent or 0, 0, 0.8)
	local damage = baseDamage * (1 - armorPercent)
	local absorbed = 0

	if profile.CurrentShield > 0 then
		absorbed = math.min(profile.CurrentShield, damage)

		profile.CurrentShield -= absorbed
		damage -= absorbed
		sendPerkStats(player)
	end

	return math.max(0, damage), absorbed
end

function PerkService.ApplyInstantHeal(player, amount)
	return applyHealing(player, amount, "HealInstant")
end

function PerkService.ApplyDirectLifeDrain(player, amount)
	return applyHealing(player, amount, "LifeStealDot")
end

function PerkService.GrantMaxHealth(player, amount)
	local addedAmount = math.max(0, amount)

	if player == nil or addedAmount <= 0 then
		return 0
	end

	local profile = getOrCreateProfile(player)
	profile.Stats.MaxHealthBonus = (profile.Stats.MaxHealthBonus or 0) + addedAmount
	applyMaxHealthStats(player)
	sendPerkStats(player)
	GameplayFeedbackService.Queue(player, "MaxHealth", addedAmount)

	return addedAmount
end

function PerkService.ApplyLifeSteal(player, damageDealt, source)
	local stats = PerkService.GetStats(player)
	local lifeStealPercent = stats.LifeStealPercent or 0

	if lifeStealPercent <= 0 or damageDealt <= 0 then
		return
	end

	local healAmount = damageDealt * lifeStealPercent
	return applyHealing(player, healAmount, if source == "Dot" then "LifeStealDot" else "LifeStealHit")
end

function PerkService.GetShieldState(player)
	local profile = profilesByUserId[player.UserId]

	if profile == nil then
		return 0, 0
	end

	return profile.CurrentShield, PerkService.GetStats(player).Shield or 0
end

function PerkService.Start()
	if isStarted then
		DebugLog.Info("Perks", "Start ignore, service deja demarre")
		return
	end

	isStarted = true
	DebugLog.Info("Perks", "PerkService demarre")
	selectChoiceRemote.OnServerEvent:Connect(onChoiceSelected)
	rerollChoiceRemote.OnServerEvent:Connect(onRerollRequested)
	passChoiceRemote.OnServerEvent:Connect(onPassRequested)
	banChoiceRemote.OnServerEvent:Connect(onBanRequested)

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
