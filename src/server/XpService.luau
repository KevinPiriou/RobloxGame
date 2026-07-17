local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))
local DebugLog = require(Shared:WaitForChild("DebugLog"))

local CombatStateService = require(script.Parent:WaitForChild("CombatStateService"))
local PerkService = require(script.Parent:WaitForChild("PerkService"))
local RunAnalyticsService = require(script.Parent:WaitForChild("RunAnalyticsService"))
local TemplateService = require(script.Parent:WaitForChild("TemplateService"))
local PerformanceTelemetryService = require(script.Parent:WaitForChild("PerformanceTelemetryService"))

local XpService = {}

local TEMPLATE_FOLDER_NAME = "CollectibleTemplates"
local profilesByUserId = {}
local trackedGems = {}
local xpGemTemplatesByTier = {}
local xpGemPoolFolder = nil
local elapsedSinceScan = 0
local elapsedSinceMerge = 0
local elapsedSincePerfLog = 0
local maxScanMilliseconds = 0
local maxMergeMilliseconds = 0
local heartbeatConnection = nil

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

local updateXpRemote = getOrCreateRemote("Xp_UpdateCount")
local collectXpRemote = getOrCreateRemote("Xp_PlayCollect")
local pickupFeedbackRemote = getOrCreateRemote("PickupFeedback_Show")

local function getOrCreateFolder(parent, folderName)
	local folder = parent:FindFirstChild(folderName)

	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = folderName
		folder.Parent = parent
	end

	return folder
end

local function getRuntimeLootFolder()
	return TemplateService.GetCombatLootFolder()
end

local function getXpGemPoolFolder()
	if xpGemPoolFolder == nil then
		xpGemPoolFolder = getOrCreateFolder(ServerStorage, "XpGemPools")
	end

	return xpGemPoolFolder
end

local function getTierName(tier)
	return CombatConfig.XpGemTierNames[tier] or CombatConfig.XpGemTemplateName
end

local function getTierPoolFolder(tier)
	return getOrCreateFolder(getXpGemPoolFolder(), getTierName(tier))
end

local function getTierValue(tier)
	return CombatConfig.XpGemTierValues[tier] or CombatConfig.XpPerGem
end

local function getGemTierByName(name)
	for tier, tierName in ipairs(CombatConfig.XpGemTierNames) do
		if name == tierName then
			return tier
		end
	end

	return nil
end

local function getOrCreateXpValue(player)
	local leaderstats = player:FindFirstChild("leaderstats")

	if leaderstats == nil then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	local xpValue = leaderstats:FindFirstChild("XP")

	if xpValue == nil then
		xpValue = Instance.new("IntValue")
		xpValue.Name = "XP"
		xpValue.Parent = leaderstats
	end

	return xpValue
end

local function getOrCreateLevelValue(player)
	local leaderstats = player:FindFirstChild("leaderstats")

	if leaderstats == nil then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	local levelValue = leaderstats:FindFirstChild("Level")

	if levelValue == nil then
		levelValue = Instance.new("IntValue")
		levelValue.Name = "Level"
		levelValue.Parent = leaderstats
	end

	return levelValue
end

local function getRequiredXpForLevel(level)
	return CombatConfig.LevelBaseXp + ((math.max(1, level) - 1) * CombatConfig.LevelXpIncrease)
end

local function getOrCreateProfile(player)
	local profile = profilesByUserId[player.UserId]

	if profile == nil then
		profile = {
			Xp = 0,
			TotalXp = 0,
			Level = 1,
		}
		profilesByUserId[player.UserId] = profile
	end

	profile.Xp = profile.Xp or 0
	profile.TotalXp = profile.TotalXp or 0
	profile.Level = profile.Level or 1

	return profile
end

local function sendXpCount(player)
	local profile = getOrCreateProfile(player)

	updateXpRemote:FireClient(player, {
		Xp = profile.Xp,
		TotalXp = profile.TotalXp,
		Level = profile.Level,
		XpRequired = getRequiredXpForLevel(profile.Level),
	})
end

local function findGemRoot(gem)
	if gem:IsA("BasePart") then
		return gem
	end

	if not gem:IsA("Model") then
		return nil
	end

	if gem.PrimaryPart ~= nil then
		return gem.PrimaryPart
	end

	local firstPart = gem:FindFirstChildWhichIsA("BasePart", true)

	if firstPart ~= nil then
		gem.PrimaryPart = firstPart
	end

	return firstPart
end

local function hasGemModelAncestor(instance, gemName)
	local current = instance.Parent

	while current ~= nil do
		if current:IsA("Model") and current.Name == gemName then
			return true
		end

		current = current.Parent
	end

	return false
end

local function isCollectableGem(instance)
	local tier = getGemTierByName(instance.Name)

	if tier == nil then
		return false
	end

	if instance:IsA("Model") then
		return findGemRoot(instance) ~= nil
	end

	if instance:IsA("BasePart") then
		return not hasGemModelAncestor(instance, instance.Name)
	end

	return false
end

local function createFallbackGemTemplate(templateStorage, tier)
	local part = Instance.new("Part")
	part.Name = getTierName(tier)
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(1, 1, 1) * (1 + ((tier - 1) * 0.35))
	part.Color = ({
		Color3.fromRGB(80, 210, 255),
		Color3.fromRGB(120, 255, 150),
		Color3.fromRGB(190, 120, 255),
	})[tier] or Color3.fromRGB(80, 210, 255)
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Parent = templateStorage

	DebugLog.Warn("Xp", "Template gemme XP introuvable, fallback cree", {
		Template = getTierName(tier),
		Tier = tier,
	})

	return part
end

local function findGemTemplate(tier)
	local tierName = getTierName(tier)

	return TemplateService.GetTemplate(TEMPLATE_FOLDER_NAME, tierName, function(templateStorage)
		return createFallbackGemTemplate(templateStorage, tier)
	end)
end

local function pivotCollectible(instance, position)
	if instance:IsA("Model") or instance:IsA("BasePart") then
		instance:PivotTo(CFrame.new(position))
	end
end

local function prepareCollectible(instance)
	if instance:IsA("BasePart") then
		instance.Anchored = true
		instance.CanCollide = false
		instance.CanTouch = false
	end

	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
		end
	end
end

local function acquireGem(tier)
	local tierPoolFolder = getTierPoolFolder(tier)
	local gem = tierPoolFolder:FindFirstChild(getTierName(tier))

	if gem == nil then
		gem = tierPoolFolder:FindFirstChildWhichIsA("Model") or tierPoolFolder:FindFirstChildWhichIsA("BasePart")
	end

	if gem ~= nil then
		gem.Parent = getRuntimeLootFolder()
		return gem, true
	end

	gem = xpGemTemplatesByTier[tier]:Clone()
	gem.Parent = getRuntimeLootFolder()

	return gem, false
end

local function releaseGem(gem, tier)
	if gem == nil or gem.Parent == nil then
		return
	end

	trackedGems[gem] = nil
	gem.Name = getTierName(tier or getGemTierByName(gem.Name) or 1)
	gem.Parent = getTierPoolFolder(tier or getGemTierByName(gem.Name) or 1)
end

local function prewarmGemPool(tier, count)
	local prewarmCount = math.max(0, math.floor(count or 0))

	if xpGemTemplatesByTier[tier] == nil or prewarmCount <= 0 then
		return
	end

	local tierPoolFolder = getTierPoolFolder(tier)

	for _ = 1, prewarmCount do
		local gem = xpGemTemplatesByTier[tier]:Clone()
		gem.Name = getTierName(tier)
		prepareCollectible(gem)
		gem.Parent = tierPoolFolder
	end
end

local function getGemPoolSize()
	local total = 0

	if xpGemPoolFolder == nil then
		return total
	end

	for _, folder in ipairs(xpGemPoolFolder:GetChildren()) do
		total += #folder:GetChildren()
	end

	return total
end

local function getTrackedGemCount()
	local total = 0

	for _ in pairs(trackedGems) do
		total += 1
	end

	return total
end

local function trackGem(instance)
	if not isCollectableGem(instance) then
		return
	end

	local tier = getGemTierByName(instance.Name) or 1

	trackedGems[instance] = {
		Collected = false,
		Tier = tier,
		XpValue = getTierValue(tier),
	}
end

local function scanExistingGems()
	for _, descendant in ipairs(Workspace:GetDescendants()) do
		trackGem(descendant)
	end
end

local function getPlayerRoot(player)
	local character = player.Character

	if character == nil then
		return nil
	end

	return character:FindFirstChild("HumanoidRootPart")
end

local function awardXp(player, xpValue)
	local profile = getOrCreateProfile(player)
	local finalXpValue = PerkService.GetXpAmount(player, xpValue)

	profile.Xp += finalXpValue
	profile.TotalXp += finalXpValue
	RunAnalyticsService.RecordXpEarned(player, finalXpValue)

	local requiredXp = getRequiredXpForLevel(profile.Level)

	while profile.Xp >= requiredXp do
		profile.Xp -= requiredXp
		profile.Level += 1
		DebugLog.Info("Xp", "Level up joueur", {
			Player = player.Name,
			Level = profile.Level,
			RemainingXp = profile.Xp,
			NextRequiredXp = getRequiredXpForLevel(profile.Level),
		})
		PerkService.QueueLevelUp(player, profile.Level)
		requiredXp = getRequiredXpForLevel(profile.Level)
	end

	getOrCreateXpValue(player).Value = profile.TotalXp
	getOrCreateLevelValue(player).Value = profile.Level
	sendXpCount(player)

	return finalXpValue
end

local function finishGemCollection(player, gem, gemState, attractDuration)
	if gemState.Cancelled or player.Parent ~= Players or gem.Parent == nil then
		if gem.Parent ~= nil then
			gemState.Collected = false
		end
		return
	end

	local arrivalTime = Workspace:GetServerTimeNow() + math.max(0, attractDuration)

	collectXpRemote:FireAllClients(gem, player.UserId, attractDuration)
	DebugLog.ThrottledInfo("Xp", "xp_collect_" .. player.UserId, 0.5, "Gemme XP collectee", {
		Player = player.Name,
		Gem = gem,
		Tier = gemState.Tier,
		XpValue = gemState.XpValue,
	})
	local finalXpValue = awardXp(player, gemState.XpValue or CombatConfig.XpPerGem)
	pickupFeedbackRemote:FireClient(player, {
		Kind = "Xp",
		Amount = finalXpValue,
		ArrivalTime = arrivalTime,
	})

	task.delay(attractDuration + 0.1, function()
		if gem.Parent ~= nil then
			releaseGem(gem, gemState.Tier)
		end
	end)
end

local function collectGem(player, gem, gemState, attractDuration)
	if gemState.Collected then
		return false
	end

	gemState.Collected = true
	finishGemCollection(player, gem, gemState, attractDuration or CombatConfig.XpAttractDuration)

	return true
end

local function scheduleGemCollection(player, gem, gemState, attractDuration, delaySeconds)
	if gemState.Collected then
		return false
	end

	gemState.Collected = true

	task.delay(delaySeconds, function()
		finishGemCollection(player, gem, gemState, attractDuration)
	end)

	return true
end

local function scanGemProximity()
	for gem, gemState in pairs(trackedGems) do
		if gem.Parent == nil then
			trackedGems[gem] = nil
			continue
		end

		if gemState.Collected then
			continue
		end

		local gemRoot = findGemRoot(gem)

		if gemRoot == nil then
			continue
		end

		for _, player in ipairs(Players:GetPlayers()) do
			local playerRoot = getPlayerRoot(player)

			if playerRoot ~= nil then
				local distance = (playerRoot.Position - gemRoot.Position).Magnitude

				if distance <= PerkService.GetCollectDistance(player, CombatConfig.XpCollectDistance) then
					collectGem(player, gem, gemState)
					break
				end
			end
		end
	end
end

local function getMergeGridKey(cellX, cellZ)
	return tostring(cellX) .. ":" .. tostring(cellZ)
end

local function getGemPosition(gem)
	local root = findGemRoot(gem)

	if root == nil then
		return nil
	end

	return root.Position
end

local function buildMergeGrid(tier)
	local grid = {}
	local cellSize = CombatConfig.XpMergeRadius

	for gem, gemState in pairs(trackedGems) do
		if gem.Parent == nil then
			trackedGems[gem] = nil
			continue
		end

		if not gemState.Collected and gemState.Tier == tier then
			local position = getGemPosition(gem)

			if position ~= nil then
				local cellX = math.floor(position.X / cellSize)
				local cellZ = math.floor(position.Z / cellSize)
				local key = getMergeGridKey(cellX, cellZ)

				if grid[key] == nil then
					grid[key] = {}
				end

				table.insert(grid[key], {
					Gem = gem,
					State = gemState,
					Position = position,
					CellX = cellX,
					CellZ = cellZ,
				})
			end
		end
	end

	return grid
end

local function findMergeGroup(seedEntry, grid, usedGems)
	local group = {}
	local radius = CombatConfig.XpMergeRadius

	for offsetX = -1, 1 do
		for offsetZ = -1, 1 do
			local key = getMergeGridKey(seedEntry.CellX + offsetX, seedEntry.CellZ + offsetZ)
			local cell = grid[key]

			if cell ~= nil then
				for _, entry in ipairs(cell) do
					if not usedGems[entry.Gem] and not entry.State.Collected then
						local distance = (entry.Position - seedEntry.Position).Magnitude

						if distance <= radius then
							table.insert(group, entry)

							if #group >= CombatConfig.XpMergeCount then
								return group
							end
						end
					end
				end
			end
		end
	end

	return group
end

local function mergeGroup(group, nextTier)
	local center = Vector3.zero

	for _, entry in ipairs(group) do
		center += entry.Position
		entry.State.Collected = true
		trackedGems[entry.Gem] = nil

		if entry.Gem.Parent ~= nil then
			releaseGem(entry.Gem, entry.State.Tier)
		end
	end

	center /= #group
	DebugLog.ThrottledInfo("Xp", "xp_merge", 1, "Fusion de gemmes XP", {
		Count = #group,
		NextTier = nextTier,
		Position = center,
	})
	XpService.SpawnXpGem(center, nextTier)
end

local function mergeNearbyGems()
	local maxTier = #CombatConfig.XpGemTierNames
	local mergedGroups = 0

	for tier = 1, maxTier - 1 do
		local grid = buildMergeGrid(tier)
		local usedGems = {}

		for _, cell in pairs(grid) do
			for _, entry in ipairs(cell) do
				if mergedGroups >= CombatConfig.XpMergeMaxGroupsPerScan then
					return
				end

				if not usedGems[entry.Gem] and not entry.State.Collected then
					local group = findMergeGroup(entry, grid, usedGems)

					if #group >= CombatConfig.XpMergeCount then
						for _, groupEntry in ipairs(group) do
							usedGems[groupEntry.Gem] = true
						end

						mergeGroup(group, tier + 1)
						mergedGroups += 1
					end
				end
			end
		end
	end
end

function XpService.SetupPlayer(player)
	local profile = getOrCreateProfile(player)
	DebugLog.Info("Xp", "Setup joueur XP", {
		Player = player.Name,
		Level = profile.Level,
		TotalXp = profile.TotalXp,
	})
	getOrCreateXpValue(player).Value = profile.TotalXp
	getOrCreateLevelValue(player).Value = profile.Level
	sendXpCount(player)
end

function XpService.RemovePlayer(player)
	profilesByUserId[player.UserId] = nil
end

function XpService.SpawnXpGem(position, tier)
	local gemTier = math.clamp(tier or 1, 1, #CombatConfig.XpGemTierNames)

	if xpGemTemplatesByTier[gemTier] == nil then
		xpGemTemplatesByTier[gemTier] = findGemTemplate(gemTier)
	end

	local gem = acquireGem(gemTier)
	gem.Name = getTierName(gemTier)

	prepareCollectible(gem)
	pivotCollectible(gem, position)
	trackGem(gem)

	DebugLog.ThrottledInfo("Xp", "xp_spawn", 1, "Gemme XP generee", {
		Gem = gem,
		Tier = gemTier,
		Position = position,
	})

	return gem
end

function XpService.CollectAllForPlayer(player, attractDuration, spreadDuration)
	local playerRoot = getPlayerRoot(player)

	if playerRoot == nil then
		return 0
	end

	local candidates = {}

	for gem, gemState in pairs(trackedGems) do
		if gem.Parent == nil then
			trackedGems[gem] = nil
			continue
		end

		if gemState.Collected then
			continue
		end

		local gemRoot = findGemRoot(gem)

		if gemRoot ~= nil then
			table.insert(candidates, {
				Gem = gem,
				State = gemState,
				Distance = (playerRoot.Position - gemRoot.Position).Magnitude,
			})
		end
	end

	table.sort(candidates, function(left, right)
		return left.Distance < right.Distance
	end)

	local collectedCount = 0
	local duration = attractDuration or CombatConfig.XpAttractDuration
	local spread = spreadDuration or 0
	local delayStep = 0

	if #candidates > 1 then
		delayStep = spread / (#candidates - 1)
	end

	for index, candidate in ipairs(candidates) do
		local delaySeconds = math.min(spread, (index - 1) * delayStep)

		if scheduleGemCollection(player, candidate.Gem, candidate.State, duration, delaySeconds) then
			collectedCount += 1
		end
	end

	DebugLog.Info("Xp", "Magnetisme global XP demande", {
		Player = player.Name,
		CollectedCount = collectedCount,
		Duration = duration,
		Spread = spread,
	})

	return collectedCount
end

function XpService.ClearRunGems()
	local gemsToRelease = {}

	for gem, gemState in pairs(trackedGems) do
		table.insert(gemsToRelease, {
			Gem = gem,
			State = gemState,
		})
	end

	for _, entry in ipairs(gemsToRelease) do
		entry.State.Cancelled = true
		trackedGems[entry.Gem] = nil

		if entry.Gem.Parent ~= nil then
			releaseGem(entry.Gem, entry.State.Tier)
		end
	end
end

function XpService.GetPerformanceSnapshot()
	return {
		Tracked = getTrackedGemCount(),
		Pool = getGemPoolSize(),
	}
end

function XpService.GetRunStats(player)
	local profile = getOrCreateProfile(player)

	return {
		Xp = profile.Xp,
		TotalXp = profile.TotalXp,
		Level = profile.Level,
		XpRequired = getRequiredXpForLevel(profile.Level),
	}
end

function XpService.ResetRun(player)
	local profile = getOrCreateProfile(player)

	profile.Xp = 0
	profile.TotalXp = 0
	profile.Level = 1
	getOrCreateXpValue(player).Value = profile.TotalXp
	getOrCreateLevelValue(player).Value = profile.Level
	sendXpCount(player)
end

function XpService.Start()
	DebugLog.Info("Xp", "XpService demarre", {
		LootFolder = getRuntimeLootFolder(),
		Tiers = CombatConfig.XpGemTierNames,
		MergeRadius = CombatConfig.XpMergeRadius,
	})

	for tier = 1, #CombatConfig.XpGemTierNames do
		xpGemTemplatesByTier[tier] = findGemTemplate(tier)
		prewarmGemPool(tier, (CombatConfig.XpGemPoolPrewarmPerTier or {})[tier])
	end

	DebugLog.Info("Perf", "Pool XP prechauffe", {
		Pool = getGemPoolSize(),
	})

	scanExistingGems()

	Workspace.DescendantAdded:Connect(function(descendant)
		task.defer(function()
			trackGem(descendant)
		end)
	end)

	if heartbeatConnection ~= nil then
		return
	end

	heartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime)
		if CombatStateService.IsPaused() then
			return
		end

		elapsedSinceScan += deltaTime
		elapsedSinceMerge += deltaTime
		elapsedSincePerfLog += deltaTime

		if elapsedSinceScan >= 0.15 then
			elapsedSinceScan = 0
			local startedAt = os.clock()
			scanGemProximity()
			local scanDuration = os.clock() - startedAt
			PerformanceTelemetryService.Record("Xp.ScanSeconds", scanDuration)
			maxScanMilliseconds = math.max(maxScanMilliseconds, scanDuration * 1000)
		end

		if elapsedSinceMerge >= CombatConfig.XpMergeScanInterval then
			elapsedSinceMerge = 0
			local startedAt = os.clock()
			mergeNearbyGems()
			local mergeDuration = os.clock() - startedAt
			PerformanceTelemetryService.Record("Xp.MergeSeconds", mergeDuration)
			maxMergeMilliseconds = math.max(maxMergeMilliseconds, mergeDuration * 1000)
		end

		if elapsedSincePerfLog >= (CombatConfig.PerfLogInterval or 5) then
			DebugLog.Info("Perf", "Perf XP serveur", {
			Tracked = getTrackedGemCount(),
			Pool = getGemPoolSize(),
			MaxScanMs = maxScanMilliseconds,
			MaxMergeMs = maxMergeMilliseconds,
		})
			elapsedSincePerfLog = 0
			maxScanMilliseconds = 0
			maxMergeMilliseconds = 0
		end
	end)
end

return XpService
