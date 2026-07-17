local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DebugLog = require(Shared:WaitForChild("DebugLog"))
local RunItemConfig = require(Shared:WaitForChild("RunItemConfig"))

local CombatStateService = require(script.Parent:WaitForChild("CombatStateService"))
local GameplayFeedbackService = require(script.Parent:WaitForChild("GameplayFeedbackService"))
local PerkService = require(script.Parent:WaitForChild("PerkService"))
local RunAnalyticsService = require(script.Parent:WaitForChild("RunAnalyticsService"))
local RunStateService = require(script.Parent:WaitForChild("RunStateService"))

local RunItemService = {}

local profilesByUserId = {}
local poisonsByMonster = {}
local rng = Random.new()
local isStarted = false
local monsterService = nil

local function getMonsterService()
	if monsterService == nil then
		monsterService = require(script.Parent:WaitForChild("MonsterService"))
	end

	return monsterService
end

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

local updateRemote = getOrCreateRemote(RunItemConfig.UpdateRemoteName)

local function createProfile()
	return {
		StacksByItemId = {},
		ItemOrder = {},
		VampireKillsSinceLastBonus = 0,
	}
end

local function getOrCreateProfile(player)
	local profile = profilesByUserId[player.UserId]

	if profile == nil then
		profile = createProfile()
		profilesByUserId[player.UserId] = profile
	end

	return profile
end

local function buildItemPayload(itemId, stacks)
	local definition = RunItemConfig.Definitions[itemId]

	if definition == nil then
		return nil
	end

	return {
		Id = definition.Id,
		Name = definition.Name,
		Description = definition.Description,
		Icon = definition.Icon,
		Accent = definition.Accent,
		Stacks = math.max(0, math.floor(stacks or 0)),
	}
end

local function getItemOrder(profile)
	if typeof(profile.ItemOrder) == "table" then
		return profile.ItemOrder
	end

	local itemOrder = {}
	for _, itemId in ipairs(RunItemConfig.ChestRewardIds) do
		local stacks = math.max(0, math.floor(profile.StacksByItemId[itemId] or 0))
		if stacks > 0 then
			table.insert(itemOrder, itemId)
		end
	end

	profile.ItemOrder = itemOrder
	return itemOrder
end

local function getMaxUniqueItems()
	return math.max(1, math.floor(RunItemConfig.MaxUniqueItems or 12))
end

local function getOwnedItemCount(profile)
	local count = 0

	for itemId, stacks in pairs(profile.StacksByItemId) do
		if RunItemConfig.Definitions[itemId] ~= nil and math.max(0, math.floor(stacks or 0)) > 0 then
			count += 1
		end
	end

	return count
end

local function buildItems(player)
	local profile = getOrCreateProfile(player)
	local items = {}
	local itemOrder = getItemOrder(profile)
	local includedItemIds = {}

	local function appendActiveItem(itemId)
		if includedItemIds[itemId] then
			return
		end

		local stacks = math.max(0, math.floor(profile.StacksByItemId[itemId] or 0))
		if stacks <= 0 then
			return
		end

		local item = buildItemPayload(itemId, stacks)
		if item == nil then
			return
		end

		includedItemIds[itemId] = true
		table.insert(items, item)
	end

	-- L'ordre est fixe au premier ramassage de chaque objet : les mises a jour
	-- suivantes ne peuvent donc jamais faire glisser les icones de la bottom bar.
	for _, itemId in ipairs(itemOrder) do
		appendActiveItem(itemId)
	end

	return items
end

local function ensureItemOrder(profile, itemId)
	local itemOrder = getItemOrder(profile)

	for _, existingItemId in ipairs(itemOrder) do
		if existingItemId == itemId then
			return
		end
	end

	table.insert(itemOrder, itemId)
end

local function sendState(player)
	updateRemote:FireClient(player, {
		Items = buildItems(player),
	})
end

local function getPoisonEffects(monster)
	local effects = poisonsByMonster[monster]

	if effects == nil then
		effects = {}
		poisonsByMonster[monster] = effects
	end

	return effects
end

local function updatePoisonStackAttribute(monster, effects)
	if monster == nil or monster.Parent == nil then
		return
	end

	monster:SetAttribute("PoisonStacks", #effects)
end

local function clearPoisonEffects(monster)
	poisonsByMonster[monster] = nil

	if monster ~= nil and monster.Parent ~= nil then
		monster:SetAttribute("PoisonStacks", 0)
	end
end

function RunItemService.SetupPlayer(player)
	getOrCreateProfile(player)
	sendState(player)
end

function RunItemService.RemovePlayer(player)
	RunItemService.RemovePlayerEffects(player)
	profilesByUserId[player.UserId] = nil
end

function RunItemService.ResetRun(player)
	local profile = getOrCreateProfile(player)
	profile.StacksByItemId = {}
	profile.ItemOrder = {}
	profile.VampireKillsSinceLastBonus = 0
	RunItemService.RemovePlayerEffects(player)
	sendState(player)
end

function RunItemService.RemovePlayerEffects(player)
	for monster, effects in pairs(poisonsByMonster) do
		local retained = {}

		for _, effect in ipairs(effects) do
			if effect.Player ~= player then
				table.insert(retained, effect)
			end
		end

		if #retained == 0 then
			clearPoisonEffects(monster)
		else
			poisonsByMonster[monster] = retained
			updatePoisonStackAttribute(monster, retained)
		end
	end
end

function RunItemService.GetItemCount(player, itemId)
	local profile = profilesByUserId[player.UserId]

	if profile == nil then
		return 0
	end

	return math.max(0, math.floor(profile.StacksByItemId[itemId] or 0))
end

function RunItemService.GetRunItems(player)
	return buildItems(player)
end

function RunItemService.GetEligibleRewardItemIds(player, candidateItemIds)
	if player == nil or typeof(candidateItemIds) ~= "table" then
		return {}
	end

	local profile = getOrCreateProfile(player)
	local inventoryIsFull = getOwnedItemCount(profile) >= getMaxUniqueItems()
	local eligibleItemIds = {}
	local includedItemIds = {}

	for _, itemId in ipairs(candidateItemIds) do
		local stacks = math.max(0, math.floor(profile.StacksByItemId[itemId] or 0))

		if
			not includedItemIds[itemId]
			and RunItemConfig.Definitions[itemId] ~= nil
			and (not inventoryIsFull or stacks > 0)
		then
			includedItemIds[itemId] = true
			table.insert(eligibleItemIds, itemId)
		end
	end

	return eligibleItemIds
end

function RunItemService.AddItem(player, itemId)
	if not RunStateService.IsRunActive(player) then
		return false, "RunInactive"
	end

	local definition = RunItemConfig.Definitions[itemId]

	if definition == nil then
		return false, "ItemUnknown"
	end

	local profile = getOrCreateProfile(player)
	local currentStacks = math.max(0, math.floor(profile.StacksByItemId[itemId] or 0))

	if currentStacks <= 0 and getOwnedItemCount(profile) >= getMaxUniqueItems() then
		return false, "ItemSlotsFull"
	end

	if currentStacks <= 0 then
		ensureItemOrder(profile, itemId)
	end

	local nextStacks = currentStacks + 1
	profile.StacksByItemId[itemId] = nextStacks

	local statsPerStack = definition.StatsPerStack

	if
		statsPerStack == nil
		and (
			definition.MoveSpeedPercentPerStack ~= nil
			or definition.AttackSpeedPercentPerStack ~= nil
			or definition.ProjectileSpeedPercentPerStack ~= nil
		)
	then
		statsPerStack = {
			MoveSpeedPercent = definition.MoveSpeedPercentPerStack or 0,
			AttackSpeedPercent = definition.AttackSpeedPercentPerStack or 0,
			ProjectileSpeedPercent = definition.ProjectileSpeedPercentPerStack or 0,
		}
	end

	if statsPerStack ~= nil then
		PerkService.ApplyRunItemStats(player, statsPerStack)
	end

	RunAnalyticsService.RecordRunItemAdded(player, itemId, 1)
	sendState(player)

	local item = buildItemPayload(itemId, nextStacks)
	DebugLog.Info("RunItems", "Objet de run ajoute", {
		Player = player.Name,
		ItemId = itemId,
		Stacks = nextStacks,
	})

	return true, item
end

function RunItemService.OnChestOpened(player)
	if player == nil or not RunStateService.IsRunActive(player) then
		return
	end

	local profile = getOrCreateProfile(player)
	local addedStats = {}

	for itemId, stacks in pairs(profile.StacksByItemId) do
		local definition = RunItemConfig.Definitions[itemId]
		local statsPerChestOpened = definition and definition.StatsPerChestOpened

		if statsPerChestOpened ~= nil then
			for statName, value in pairs(statsPerChestOpened) do
				addedStats[statName] = (addedStats[statName] or 0) + (value * stacks)
			end
		end
	end

	if next(addedStats) ~= nil then
		PerkService.ApplyRunItemStats(player, addedStats)
	end
end

function RunItemService.OnMonsterKilled(player)
	if player == nil or not RunStateService.IsRunActive(player) then
		return
	end

	local definition = RunItemConfig.Definitions.vampire_tooth
	local stacks = RunItemService.GetItemCount(player, definition.Id)

	if stacks <= 0 then
		return
	end

	local profile = getOrCreateProfile(player)
	profile.VampireKillsSinceLastBonus += 1

	local baseThreshold = math.max(1, math.floor(definition.KillsPerMaxHealth or 50))
	local stackMultiplier = math.clamp(definition.KillThresholdStackMultiplier or 1, 0.1, 1)
	local threshold = math.max(1, math.ceil(baseThreshold * (stackMultiplier ^ math.max(0, stacks - 1))))
	local maxHealthPerThreshold = math.max(1, math.floor(definition.MaxHealthPerThreshold or 1))

	while profile.VampireKillsSinceLastBonus >= threshold do
		profile.VampireKillsSinceLastBonus -= threshold
		PerkService.GrantMaxHealth(player, maxHealthPerThreshold)
	end
end

function RunItemService.TryApplyOnWeaponHit(player, monster, weaponId)
	if player == nil or monster == nil or not RunStateService.IsRunActive(player) then
		return false
	end

	if not getMonsterService().IsMonsterAlive(monster) then
		return false
	end

	local camembert = RunItemConfig.Definitions.camembert
	local stacks = RunItemService.GetItemCount(player, camembert.Id)

	if stacks <= 0 then
		return false
	end

	local chance = math.clamp((camembert.PoisonChancePerStack or 0) * stacks, 0, 1)

	if rng:NextNumber() > chance then
		return false
	end

	local duration = PerkService.GetEffectDuration(player, camembert.PoisonBaseDuration)
	local effects = getPoisonEffects(monster)
	table.insert(effects, {
		Player = player,
		MonsterRuntimeId = monster:GetAttribute("RuntimeMonsterId"),
		RemainingSeconds = duration,
		TickAccumulator = 0,
		TickInterval = camembert.PoisonTickInterval,
		TickDamage = camembert.PoisonTickDamage,
		FlashColor = camembert.PoisonFlashColor,
		SourceWeaponId = weaponId,
	})
	updatePoisonStackAttribute(monster, effects)
	GameplayFeedbackService.Queue(player, "Poison", 1)

	DebugLog.ThrottledInfo("RunItems", "poison_applied_" .. player.UserId, 0.5, "Poison applique", {
		Player = player.Name,
		Monster = monster,
		Stacks = #effects,
		Chance = chance,
		Duration = duration,
	})

	return true
end

local function updatePoisonEffects(deltaTime)
	if CombatStateService.IsPaused() then
		return
	end

	for monster, effects in pairs(poisonsByMonster) do
		local retained = {}

		for _, effect in ipairs(effects) do
			local isSameRuntimeMonster = monster:GetAttribute("RuntimeMonsterId") == effect.MonsterRuntimeId
			local isValid = isSameRuntimeMonster and getMonsterService().IsMonsterAlive(monster)

			if isValid then
				effect.RemainingSeconds -= deltaTime
				effect.TickAccumulator += deltaTime

				while effect.TickAccumulator >= effect.TickInterval and effect.RemainingSeconds >= 0 do
					effect.TickAccumulator -= effect.TickInterval
					local didDamage, damageDealt = getMonsterService().DamageMonster(monster, effect.TickDamage, effect.Player, {
						FlashColor = effect.FlashColor,
					})

					if not didDamage then
						isValid = false
						break
					end

					PerkService.ApplyLifeSteal(effect.Player, damageDealt or 0, "Dot")
					RunAnalyticsService.RecordDamageDealt(effect.Player, damageDealt or 0, "CamembertPoison")
				end
			end

			if isValid and effect.RemainingSeconds > 0 and getMonsterService().IsMonsterAlive(monster) then
				table.insert(retained, effect)
			end
		end

		if #retained == 0 then
			clearPoisonEffects(monster)
		else
			poisonsByMonster[monster] = retained
			updatePoisonStackAttribute(monster, retained)
		end
	end
end

function RunItemService.Start()
	if isStarted then
		return
	end

	isStarted = true
	RunService.Heartbeat:Connect(updatePoisonEffects)
	DebugLog.Info("RunItems", "RunItemService demarre")
end

return RunItemService
