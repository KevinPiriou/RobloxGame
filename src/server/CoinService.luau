local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))
local DebugLog = require(Shared:WaitForChild("DebugLog"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local CombatStateService = require(script.Parent:WaitForChild("CombatStateService"))
local PerkService = require(script.Parent:WaitForChild("PerkService"))
local RunAnalyticsService = require(script.Parent:WaitForChild("RunAnalyticsService"))
local TemplateService = require(script.Parent:WaitForChild("TemplateService"))

local CoinService = {}

local TEMPLATE_FOLDER_NAME = "CollectibleTemplates"
local COIN_TIER_NAMES = GameConfig.CoinTierNames or { "Coin" }
local COIN_TIER_VALUES = GameConfig.CoinTierValues or { GameConfig.CoinsPerPickup }

local profilesByUserId = {}
local trackedCoins = {}
local coinTemplatesByTier = {}
local coinPoolFolder = nil
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

local updateCoinsRemote = getOrCreateRemote("Coin_UpdateCount")
local collectCoinRemote = getOrCreateRemote("Coin_PlayCollect")
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

local function getCoinPoolFolder()
	if coinPoolFolder == nil then
		coinPoolFolder = getOrCreateFolder(ServerStorage, "CoinPools")
	end

	return coinPoolFolder
end

local function getTierName(tier)
	return COIN_TIER_NAMES[tier] or COIN_TIER_NAMES[1] or "Coin"
end

local function getTierPoolFolder(tier)
	return getOrCreateFolder(getCoinPoolFolder(), getTierName(tier))
end

local function getTierValue(tier)
	return COIN_TIER_VALUES[tier] or COIN_TIER_VALUES[1] or GameConfig.CoinsPerPickup
end

local function getCoinTierByName(name)
	for tier, tierName in ipairs(COIN_TIER_NAMES) do
		if name == tierName then
			return tier
		end
	end

	return nil
end

local function sanitizeCoinCount(value)
	if typeof(value) ~= "number" then
		return 0
	end

	return math.max(0, math.floor(value))
end

local function getOrCreateProfile(player)
	local userId = player.UserId
	local profile = profilesByUserId[userId]

	if profile == nil then
		profile = {
			Coins = 0,
			Loaded = false,
			LastSaveSucceeded = false,
		}
		profilesByUserId[userId] = profile
	end

	return profile
end

local function waitForProfileLoaded(player)
	local profile = getOrCreateProfile(player)
	local startedAt = os.clock()

	while not profile.Loaded and player.Parent ~= nil and os.clock() - startedAt < 5 do
		task.wait(0.1)
	end

	return profile
end

local function sendCoinCount(player)
	local profile = getOrCreateProfile(player)

	updateCoinsRemote:FireClient(player, {
		Coins = profile.Coins,
		Loaded = profile.Loaded,
		LastSaveSucceeded = profile.LastSaveSucceeded,
	})
end

local function saveProfile(player, shouldNotify)
	local profile = profilesByUserId[player.UserId]

	if profile == nil then
		return false
	end

	profile.Coins = sanitizeCoinCount(profile.Coins)
	profile.LastSaveSucceeded = true

	if shouldNotify then
		sendCoinCount(player)
	end

	return true
end

local function loadProfile(player)
	local profile = getOrCreateProfile(player)

	profile.Coins = 0
	profile.Loaded = true
	profile.LastSaveSucceeded = true
	sendCoinCount(player)
end

local function findCoinRoot(coin)
	if coin:IsA("BasePart") then
		return coin
	end

	if not coin:IsA("Model") then
		return nil
	end

	if coin.PrimaryPart ~= nil then
		return coin.PrimaryPart
	end

	local firstPart = coin:FindFirstChildWhichIsA("BasePart", true)

	if firstPart ~= nil then
		coin.PrimaryPart = firstPart
	end

	return firstPart
end

local function hasCoinModelAncestor(instance, coinName)
	local current = instance.Parent

	while current ~= nil do
		if current:IsA("Model") and current.Name == coinName then
			return true
		end

		current = current.Parent
	end

	return false
end

local function isCollectableCoin(instance)
	local tier = getCoinTierByName(instance.Name)

	if tier == nil then
		return false
	end

	if instance:IsA("Model") then
		return findCoinRoot(instance) ~= nil
	end

	if instance:IsA("BasePart") then
		return not hasCoinModelAncestor(instance, instance.Name)
	end

	return false
end

local function createFallbackCoinTemplate(templateStorage, tier)
	local part = Instance.new("Part")
	part.Name = getTierName(tier)
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(0.3, 1.4, 1.4) * (1 + ((tier - 1) * 0.25))
	part.Color = ({
		Color3.fromRGB(255, 205, 70),
		Color3.fromRGB(255, 235, 110),
		Color3.fromRGB(255, 175, 55),
	})[tier] or Color3.fromRGB(255, 205, 70)
	part.Material = Enum.Material.Metal
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Parent = templateStorage

	DebugLog.Warn("Coin", "Template coin introuvable, fallback cree", {
		Template = getTierName(tier),
		Tier = tier,
	})

	return part
end

local function findCoinTemplate(tier)
	local tierName = getTierName(tier)

	return TemplateService.GetTemplate(TEMPLATE_FOLDER_NAME, tierName, function(templateStorage)
		return createFallbackCoinTemplate(templateStorage, tier)
	end)
end

local function prepareCoin(coin)
	if coin:IsA("BasePart") then
		coin.Anchored = true
		coin.CanCollide = false
		coin.CanTouch = false
	end

	for _, descendant in ipairs(coin:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
		end
	end
end

local function pivotCoin(coin, position)
	if coin:IsA("Model") or coin:IsA("BasePart") then
		coin:PivotTo(CFrame.new(position))
	end
end

local function acquireCoin(tier)
	local tierPoolFolder = getTierPoolFolder(tier)
	local coin = tierPoolFolder:FindFirstChild(getTierName(tier))

	if coin == nil then
		coin = tierPoolFolder:FindFirstChildWhichIsA("Model") or tierPoolFolder:FindFirstChildWhichIsA("BasePart")
	end

	if coin ~= nil then
		coin.Parent = getRuntimeLootFolder()
		return coin, true
	end

	coin = coinTemplatesByTier[tier]:Clone()
	coin.Parent = getRuntimeLootFolder()

	return coin, false
end

local function releaseCoin(coin, tier)
	if coin == nil or coin.Parent == nil then
		return
	end

	trackedCoins[coin] = nil
	coin.Name = getTierName(tier or getCoinTierByName(coin.Name) or 1)
	coin.Parent = getTierPoolFolder(tier or getCoinTierByName(coin.Name) or 1)
end

local function prewarmCoinPool(tier, count)
	local prewarmCount = math.max(0, math.floor(count or 0))

	if coinTemplatesByTier[tier] == nil or prewarmCount <= 0 then
		return
	end

	local tierPoolFolder = getTierPoolFolder(tier)

	for _ = 1, prewarmCount do
		local coin = coinTemplatesByTier[tier]:Clone()
		coin.Name = getTierName(tier)
		prepareCoin(coin)
		coin.Parent = tierPoolFolder
	end
end

local function getCoinPoolSize()
	local total = 0

	if coinPoolFolder == nil then
		return total
	end

	for _, folder in ipairs(coinPoolFolder:GetChildren()) do
		total += #folder:GetChildren()
	end

	return total
end

local function getTrackedCoinCount()
	local total = 0

	for _ in pairs(trackedCoins) do
		total += 1
	end

	return total
end

local function trackCoin(instance)
	if not isCollectableCoin(instance) then
		return
	end

	local tier = getCoinTierByName(instance.Name) or 1

	trackedCoins[instance] = {
		Collected = false,
		Tier = tier,
		CoinValue = getTierValue(tier),
	}
end

local function scanExistingCoins()
	for _, descendant in ipairs(Workspace:GetDescendants()) do
		trackCoin(descendant)
	end
end

local function getPlayerRoot(player)
	local character = player.Character

	if character == nil then
		return nil
	end

	return character:FindFirstChild("HumanoidRootPart")
end

local function awardCoin(player, coinValue)
	local profile = waitForProfileLoaded(player)
	local finalCoinValue = PerkService.GetGoldAmount(player, coinValue or GameConfig.CoinsPerPickup)

	profile.Coins += finalCoinValue
	RunAnalyticsService.RecordCoinsEarned(player, finalCoinValue)
	sendCoinCount(player)
	DebugLog.ThrottledInfo("Coin", "coin_award_" .. player.UserId, 0.5, "Coin attribue", {
		Player = player.Name,
		Coins = profile.Coins,
		Value = finalCoinValue,
	})

	return finalCoinValue
end

local function finishCoinCollection(player, coin, coinState, attractDuration)
	if coinState.Cancelled or player.Parent ~= Players or coin.Parent == nil then
		if coin.Parent ~= nil then
			coinState.Collected = false
		end
		return
	end

	local arrivalTime = Workspace:GetServerTimeNow() + math.max(0, attractDuration)

	collectCoinRemote:FireAllClients(coin, player.UserId, attractDuration)
	DebugLog.ThrottledInfo("Coin", "coin_collect_" .. player.UserId, 0.5, "Coin collecte", {
		Player = player.Name,
		Coin = coin,
		Tier = coinState.Tier,
		CoinValue = coinState.CoinValue,
	})

	task.spawn(function()
		local finalCoinValue = awardCoin(player, coinState.CoinValue or GameConfig.CoinsPerPickup)

		pickupFeedbackRemote:FireClient(player, {
			Kind = "Coin",
			Amount = finalCoinValue,
			ArrivalTime = arrivalTime,
		})

		-- La persistance ne doit pas retarder le retour visuel de la collecte.
		saveProfile(player, true)
	end)

	task.delay(attractDuration + 0.1, function()
		if coin.Parent ~= nil then
			releaseCoin(coin, coinState.Tier)
		end
	end)
end

local function collectCoin(player, coin, coinState, attractDuration)
	if coinState.Collected then
		return false
	end

	coinState.Collected = true
	finishCoinCollection(player, coin, coinState, attractDuration or GameConfig.CoinAttractDuration)

	return true
end

local function scheduleCoinCollection(player, coin, coinState, attractDuration, delaySeconds)
	if coinState.Collected then
		return false
	end

	coinState.Collected = true

	task.delay(delaySeconds, function()
		finishCoinCollection(player, coin, coinState, attractDuration)
	end)

	return true
end

local function scanCoinProximity()
	for coin, coinState in pairs(trackedCoins) do
		if coin.Parent == nil then
			trackedCoins[coin] = nil
			continue
		end

		if coinState.Collected then
			continue
		end

		local coinRoot = findCoinRoot(coin)

		if coinRoot == nil then
			continue
		end

		for _, player in ipairs(Players:GetPlayers()) do
			local playerRoot = getPlayerRoot(player)

			if playerRoot ~= nil then
				local distance = (playerRoot.Position - coinRoot.Position).Magnitude

				if distance <= PerkService.GetCollectDistance(player, GameConfig.CoinCollectDistance) then
					collectCoin(player, coin, coinState)
					break
				end
			end
		end
	end
end

local function getMergeGridKey(cellX, cellZ)
	return tostring(cellX) .. ":" .. tostring(cellZ)
end

local function getCoinPosition(coin)
	local root = findCoinRoot(coin)

	if root == nil then
		return nil
	end

	return root.Position
end

local function buildMergeGrid(tier)
	local grid = {}
	local cellSize = GameConfig.CoinMergeRadius

	for coin, coinState in pairs(trackedCoins) do
		if coin.Parent == nil then
			trackedCoins[coin] = nil
			continue
		end

		if not coinState.Collected and coinState.Tier == tier then
			local position = getCoinPosition(coin)

			if position ~= nil then
				local cellX = math.floor(position.X / cellSize)
				local cellZ = math.floor(position.Z / cellSize)
				local key = getMergeGridKey(cellX, cellZ)

				if grid[key] == nil then
					grid[key] = {}
				end

				table.insert(grid[key], {
					Coin = coin,
					State = coinState,
					Position = position,
					CellX = cellX,
					CellZ = cellZ,
				})
			end
		end
	end

	return grid
end

local function findMergeGroup(seedEntry, grid, usedCoins)
	local group = {}
	local radius = GameConfig.CoinMergeRadius

	for offsetX = -1, 1 do
		for offsetZ = -1, 1 do
			local key = getMergeGridKey(seedEntry.CellX + offsetX, seedEntry.CellZ + offsetZ)
			local cell = grid[key]

			if cell ~= nil then
				for _, entry in ipairs(cell) do
					if not usedCoins[entry.Coin] and not entry.State.Collected then
						local distance = (entry.Position - seedEntry.Position).Magnitude

						if distance <= radius then
							table.insert(group, entry)

							if #group >= GameConfig.CoinMergeCount then
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
		trackedCoins[entry.Coin] = nil

		if entry.Coin.Parent ~= nil then
			releaseCoin(entry.Coin, entry.State.Tier)
		end
	end

	center /= #group
	DebugLog.ThrottledInfo("Coin", "coin_merge", 1, "Fusion de coins", {
		Count = #group,
		NextTier = nextTier,
		Position = center,
	})
	CoinService.SpawnCoin(center, nextTier)
end

local function mergeNearbyCoins()
	local maxTier = #COIN_TIER_NAMES
	local mergedGroups = 0

	for tier = 1, maxTier - 1 do
		local grid = buildMergeGrid(tier)
		local usedCoins = {}

		for _, cell in pairs(grid) do
			for _, entry in ipairs(cell) do
				if mergedGroups >= GameConfig.CoinMergeMaxGroupsPerScan then
					return
				end

				if not usedCoins[entry.Coin] and not entry.State.Collected then
					local group = findMergeGroup(entry, grid, usedCoins)

					if #group >= GameConfig.CoinMergeCount then
						for _, groupEntry in ipairs(group) do
							usedCoins[groupEntry.Coin] = true
						end

						mergeGroup(group, tier + 1)
						mergedGroups += 1
					end
				end
			end
		end
	end
end

function CoinService.SetupPlayer(player)
	DebugLog.Info("Coin", "Setup joueur coins", {
		Player = player.Name,
	})
	getOrCreateProfile(player)
	loadProfile(player)
end

function CoinService.SavePlayer(player)
	saveProfile(player, false)
end

function CoinService.GetCoins(player)
	local profile = waitForProfileLoaded(player)

	return profile.Coins
end

function CoinService.TrySpendCoins(player, amount)
	local coinAmount = sanitizeCoinCount(amount)

	if coinAmount <= 0 then
		return true, CoinService.GetCoins(player)
	end

	local profile = waitForProfileLoaded(player)

	if profile.Coins < coinAmount then
		DebugLog.Info("Coin", "Depense coins refusee", {
			Player = player.Name,
			Requested = coinAmount,
			Coins = profile.Coins,
		})
		return false, profile.Coins
	end

	profile.Coins -= coinAmount
	RunAnalyticsService.RecordCoinsSpent(player, coinAmount)
	saveProfile(player, true)

	DebugLog.Info("Coin", "Depense coins validee", {
		Player = player.Name,
		Spent = coinAmount,
		Remaining = profile.Coins,
	})

	return true, profile.Coins
end

function CoinService.RemovePlayer(player)
	CoinService.SavePlayer(player)
	profilesByUserId[player.UserId] = nil
end

function CoinService.SpawnCoin(position, tier)
	local coinTier = math.clamp(tier or 1, 1, #COIN_TIER_NAMES)

	if coinTemplatesByTier[coinTier] == nil then
		coinTemplatesByTier[coinTier] = findCoinTemplate(coinTier)
	end

	local coin = acquireCoin(coinTier)
	coin.Name = getTierName(coinTier)

	prepareCoin(coin)
	pivotCoin(coin, position)
	trackCoin(coin)

	DebugLog.ThrottledInfo("Coin", "coin_spawn", 1, "Coin genere", {
		Coin = coin,
		Tier = coinTier,
		CoinValue = getTierValue(coinTier),
		Position = position,
	})

	return coin
end

function CoinService.CollectAllForPlayer(player, attractDuration, spreadDuration)
	local playerRoot = getPlayerRoot(player)

	if playerRoot == nil then
		return 0
	end

	local candidates = {}

	for coin, coinState in pairs(trackedCoins) do
		if coin.Parent == nil then
			trackedCoins[coin] = nil
			continue
		end

		if coinState.Collected then
			continue
		end

		local coinRoot = findCoinRoot(coin)

		if coinRoot ~= nil then
			table.insert(candidates, {
				Coin = coin,
				State = coinState,
				Distance = (playerRoot.Position - coinRoot.Position).Magnitude,
			})
		end
	end

	table.sort(candidates, function(left, right)
		return left.Distance < right.Distance
	end)

	local collectedCount = 0
	local duration = attractDuration or GameConfig.CoinAttractDuration
	local spread = spreadDuration or 0
	local delayStep = 0

	if #candidates > 1 then
		delayStep = spread / (#candidates - 1)
	end

	for index, candidate in ipairs(candidates) do
		local delaySeconds = math.min(spread, (index - 1) * delayStep)

		if scheduleCoinCollection(player, candidate.Coin, candidate.State, duration, delaySeconds) then
			collectedCount += 1
		end
	end

	DebugLog.Info("Coin", "Magnetisme global coins demande", {
		Player = player.Name,
		CollectedCount = collectedCount,
		Duration = duration,
		Spread = spread,
	})

	return collectedCount
end

function CoinService.ClearRunCoins()
	local coinsToRelease = {}

	for coin, coinState in pairs(trackedCoins) do
		table.insert(coinsToRelease, {
			Coin = coin,
			State = coinState,
		})
	end

	for _, entry in ipairs(coinsToRelease) do
		entry.State.Cancelled = true
		trackedCoins[entry.Coin] = nil

		if entry.Coin.Parent ~= nil then
			releaseCoin(entry.Coin, entry.State.Tier)
		end
	end
end

function CoinService.ResetRun(player)
	local profile = getOrCreateProfile(player)

	profile.Coins = 0
	sendCoinCount(player)
end

function CoinService.Start()
	for tier = 1, #COIN_TIER_NAMES do
		coinTemplatesByTier[tier] = findCoinTemplate(tier)
		prewarmCoinPool(tier, (GameConfig.CoinPoolPrewarmPerTier or {})[tier])
	end

	DebugLog.Info("Coin", "CoinService demarre", {
		Tiers = COIN_TIER_NAMES,
		LootFolder = getRuntimeLootFolder(),
		CollectDistance = GameConfig.CoinCollectDistance,
		MergeRadius = GameConfig.CoinMergeRadius,
		Pool = getCoinPoolSize(),
	})
	scanExistingCoins()

	Workspace.DescendantAdded:Connect(function(descendant)
		task.defer(function()
			trackCoin(descendant)
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

		if elapsedSinceScan >= GameConfig.CoinScanInterval then
			elapsedSinceScan = 0
			local startedAt = os.clock()
			scanCoinProximity()
			maxScanMilliseconds = math.max(maxScanMilliseconds, (os.clock() - startedAt) * 1000)
		end

		if elapsedSinceMerge >= GameConfig.CoinMergeScanInterval then
			elapsedSinceMerge = 0
			local startedAt = os.clock()
			mergeNearbyCoins()
			maxMergeMilliseconds = math.max(maxMergeMilliseconds, (os.clock() - startedAt) * 1000)
		end

		if elapsedSincePerfLog >= (CombatConfig.PerfLogInterval or 5) then
			DebugLog.Info("Perf", "Perf coins serveur", {
			Tracked = getTrackedCoinCount(),
			Pool = getCoinPoolSize(),
			MaxScanMs = maxScanMilliseconds,
			MaxMergeMs = maxMergeMilliseconds,
		})
			elapsedSincePerfLog = 0
			maxScanMilliseconds = 0
			maxMergeMilliseconds = 0
		end
	end)
end

return CoinService
