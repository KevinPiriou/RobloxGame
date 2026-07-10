local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ChestConfig = require(Shared:WaitForChild("ChestConfig"))
local DebugLog = require(Shared:WaitForChild("DebugLog"))

local CombatStateService = require(script.Parent:WaitForChild("CombatStateService"))
local CoinService = require(script.Parent:WaitForChild("CoinService"))
local TemplateService = require(script.Parent:WaitForChild("TemplateService"))
local WorldSpawnService = require(script.Parent:WaitForChild("WorldSpawnService"))

local ChestService = {}

local rng = Random.new()
local profilesByUserId = {}
local trackedChests = {}
local isStarted = false
local runtimeFolder = nil
local chestTemplate = nil
local spawnedChestCount = 0

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

local openRequestRemote = getOrCreateRemote("Chest_OpenRequest")
local openResultRemote = getOrCreateRemote("Chest_OpenResult")
local openFailedRemote = getOrCreateRemote("Chest_OpenFailed")
local choiceRequestRemote = getOrCreateRemote("Chest_ChoiceRequest")
local choiceResultRemote = getOrCreateRemote("Chest_ChoiceResult")
local priceUpdateRemote = getOrCreateRemote("Chest_PriceUpdate")

local function createFallbackChestTemplate(templateStorage)
	local model = Instance.new("Model")
	model.Name = ChestConfig.ChestName

	local base = Instance.new("Part")
	base.Name = "Base"
	base.Size = Vector3.new(4, 2.4, 3)
	base.Color = Color3.fromRGB(115, 74, 38)
	base.Material = Enum.Material.Wood
	base.Anchored = true
	base.Parent = model

	local lid = Instance.new("Part")
	lid.Name = "Lid"
	lid.Size = Vector3.new(4.2, 0.7, 3.2)
	lid.Position = Vector3.new(0, 1.55, 0)
	lid.Color = Color3.fromRGB(145, 96, 47)
	lid.Material = Enum.Material.WoodPlanks
	lid.Anchored = true
	lid.Parent = model

	local band = Instance.new("Part")
	band.Name = "Band"
	band.Size = Vector3.new(4.4, 0.25, 0.35)
	band.Position = Vector3.new(0, 0.45, -1.62)
	band.Color = Color3.fromRGB(235, 188, 82)
	band.Material = Enum.Material.Metal
	band.Anchored = true
	band.Parent = model

	model.PrimaryPart = base
	model.Parent = templateStorage

	DebugLog.Warn("Chest", "Template Chest introuvable, fallback cree")

	return model
end

local function getPauseReason(player)
	return "ChestOpening_" .. player.UserId
end

local function getOrCreateProfile(player)
	local profile = profilesByUserId[player.UserId]

	if profile == nil then
		profile = {
			NextOpenCost = ChestConfig.BaseOpenCost,
			ActiveOpening = nil,
			NextOpeningId = 0,
		}
		profilesByUserId[player.UserId] = profile
	end

	return profile
end

local function sendPrice(player)
	local profile = getOrCreateProfile(player)

	priceUpdateRemote:FireClient(player, {
		NextOpenCost = profile.NextOpenCost,
		Coins = CoinService.GetCoins(player),
	})
end

local function getChestContainer(instance)
	local current = instance

	while current ~= nil and current ~= Workspace do
		if current.Name == ChestConfig.ChestName then
			return current
		end

		current = current.Parent
	end

	return nil
end

local function findChestRoot(chest)
	if chest:IsA("BasePart") then
		return chest
	end

	if chest:IsA("Model") and chest.PrimaryPart ~= nil then
		return chest.PrimaryPart
	end

	local root = chest:FindFirstChildWhichIsA("BasePart", true)

	if root ~= nil and chest:IsA("Model") then
		chest.PrimaryPart = root
	end

	return root
end

local function resolveChest(instance)
	if typeof(instance) ~= "Instance" then
		return nil
	end

	local chest = getChestContainer(instance)

	if chest == nil or findChestRoot(chest) == nil then
		return nil
	end

	return chest
end

local function getChestPosition(chest)
	if chest:IsA("Model") then
		local cframe = chest:GetBoundingBox()

		return cframe.Position
	end

	if chest:IsA("BasePart") then
		return chest.Position
	end

	local root = findChestRoot(chest)

	if root == nil then
		return nil
	end

	return root.Position
end

local function trackChest(instance)
	local chest = resolveChest(instance)

	if chest == nil then
		return
	end

	trackedChests[chest] = {
		Opened = chest:GetAttribute("ChestOpened") == true,
	}

	if chest:GetAttribute("ChestOpened") == nil then
		chest:SetAttribute("ChestOpened", false)
	end

	if chest:GetAttribute("ChestOpening") == nil then
		chest:SetAttribute("ChestOpening", false)
	end
end

local function scanExistingChests()
	for _, descendant in ipairs(Workspace:GetDescendants()) do
		trackChest(descendant)
	end
end

local function pivotInstance(instance, cframe)
	if instance:IsA("Model") or instance:IsA("BasePart") then
		instance:PivotTo(cframe)
	end
end

local function prepareChestInstance(chest)
	for _, descendant in ipairs(chest:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
		end
	end

	if chest:IsA("BasePart") then
		chest.Anchored = true
	end

	if chest:GetAttribute("ChestOpened") == nil then
		chest:SetAttribute("ChestOpened", false)
	end

	if chest:GetAttribute("ChestOpening") == nil then
		chest:SetAttribute("ChestOpening", false)
	end
end

local function getOccupiedSurfacePositions()
	local occupiedPositions = WorldSpawnService.GetPositionsFromFolder(runtimeFolder)

	for _, position in ipairs(WorldSpawnService.GetPositionsFromFolder(TemplateService.GetShrinesRuntimeFolder())) do
		table.insert(occupiedPositions, position)
	end

	for chest in pairs(trackedChests) do
		local position = WorldSpawnService.GetInstancePosition(chest)

		if position ~= nil then
			table.insert(occupiedPositions, position)
		end
	end

	return occupiedPositions
end

local function spawnChestAtSurface(surfacePosition)
	if chestTemplate == nil then
		return nil
	end

	local chest = chestTemplate:Clone()
	chest.Name = ChestConfig.ChestName
	chest.Parent = runtimeFolder
	prepareChestInstance(chest)

	local root = findChestRoot(chest)

	if root == nil then
		DebugLog.Warn("Chest", "Chest sans BasePart, generation annulee", {
			Chest = chest,
		})
		chest:Destroy()
		return nil
	end

	local pivotPosition = WorldSpawnService.GetSurfacePivotPosition(
		chest,
		surfacePosition,
		ChestConfig.SpawnSurfaceOffset
	)

	pivotInstance(chest, WorldSpawnService.GetPivotCFrameAtPosition(chest, pivotPosition, rng:NextNumber(0, math.pi * 2)))
	trackChest(chest)
	spawnedChestCount += 1

	DebugLog.Info("Chest", "Chest genere", {
		Chest = chest,
		SurfacePosition = surfacePosition,
		PivotPosition = pivotPosition,
		SpawnedCount = spawnedChestCount,
	})

	return chest
end

local function spawnInitialChests()
	if chestTemplate == nil then
		DebugLog.Warn("Chest", "Generation coffres impossible, template absent")
		return
	end

	local neededCount = math.max(0, ChestConfig.InitialSpawnCount - spawnedChestCount)

	if neededCount <= 0 then
		DebugLog.Info("Chest", "Generation coffres ignoree, limite deja atteinte", {
			SpawnedCount = spawnedChestCount,
			Limit = ChestConfig.InitialSpawnCount,
		})
		return
	end

	DebugLog.Info("Chest", "Generation coffres repartis demandee", {
		Requested = neededCount,
		MaxRadius = ChestConfig.SpawnWorldMaxRadius,
		MinDistance = ChestConfig.SpawnWorldMinObjectDistance,
	})

	local surfacePositions = WorldSpawnService.FindDistributedSurfacePositions({
		Count = neededCount,
		Center = ChestConfig.SpawnWorldCenter,
		MinRadius = ChestConfig.SpawnWorldMinRadius,
		MaxRadius = ChestConfig.SpawnWorldMaxRadius,
		MinDistance = ChestConfig.SpawnWorldMinObjectDistance,
		AttemptsPerPoint = ChestConfig.SpawnWorldAttemptsPerChest,
		JitterRadius = ChestConfig.SpawnWorldJitterRadius,
		RaycastHeight = ChestConfig.SpawnRaycastHeight,
		RaycastDepth = ChestConfig.SpawnRaycastDepth,
		RejectedSurfaceNameContains = ChestConfig.RejectedSurfaceNameContains,
		OccupiedPositions = getOccupiedSurfacePositions(),
		LogCategory = "Chest",
		LogLabel = "coffres",
	})

	for _, surfacePosition in ipairs(surfacePositions) do
		if spawnedChestCount >= ChestConfig.InitialSpawnCount then
			break
		end

		spawnChestAtSurface(surfacePosition)
	end

	DebugLog.Info("Chest", "Generation coffres initiale terminee", {
		Requested = ChestConfig.InitialSpawnCount,
		SpawnedCount = spawnedChestCount,
	})
end

local function getPlayerRoot(player)
	local character = player.Character

	if character == nil then
		return nil
	end

	return character:FindFirstChild("HumanoidRootPart")
end

local function getRewardOptions()
	if #ChestConfig.PlaceholderRewards > 0 then
		return ChestConfig.PlaceholderRewards
	end

	return {
		{
			Id = "placeholder",
			Name = "Objet mystere",
			Description = "Objet a venir",
		},
	}
end

local function pickReward()
	local rewards = getRewardOptions()
	local index = rng:NextInteger(1, #rewards)
	local reward = rewards[index]

	return {
		Id = reward.Id,
		Name = reward.Name,
		Description = reward.Description,
	}
end

local function createSpinItems(finalReward)
	local rewards = getRewardOptions()
	local spinItems = {}

	for index = 1, 18 do
		local reward = rewards[rng:NextInteger(1, #rewards)]

		spinItems[index] = reward.Name
	end

	spinItems[#spinItems + 1] = finalReward.Name

	return spinItems
end

local function sendOpenFailed(player, reason)
	local profile = getOrCreateProfile(player)

	DebugLog.Info("Chest", "Ouverture coffre refusee", {
		Player = player.Name,
		Reason = reason,
		NextOpenCost = profile.NextOpenCost,
		Coins = CoinService.GetCoins(player),
	})

	openFailedRemote:FireClient(player, {
		Reason = reason,
		NextOpenCost = profile.NextOpenCost,
		Coins = CoinService.GetCoins(player),
	})
end

local function applyReward(player, reward)
	-- Les objets reels arriveront plus tard. Pour l'instant le serveur garde seulement le choix valide.
	if reward == nil then
		return
	end

	DebugLog.Info("Chest", "Recompense coffre validee", {
		Player = player.Name,
		Reward = reward.Name,
	})
end

local function destroyChest(chest)
	if chest ~= nil and chest.Parent ~= nil then
		trackedChests[chest] = nil
		chest:Destroy()
	end
end

local function finishOpening(player, accepted)
	local profile = getOrCreateProfile(player)
	local activeOpening = profile.ActiveOpening

	if activeOpening == nil then
		return
	end

	profile.ActiveOpening = nil
	CombatStateService.Resume(getPauseReason(player))

	if accepted then
		applyReward(player, activeOpening.Reward)
	end

	destroyChest(activeOpening.Chest)
	DebugLog.Info("Chest", "Ouverture coffre terminee", {
		Player = player.Name,
		Accepted = accepted,
		NextOpenCost = profile.NextOpenCost,
	})

	choiceResultRemote:FireClient(player, {
		Accepted = accepted,
		Reward = activeOpening.Reward,
		NextOpenCost = profile.NextOpenCost,
	})
end

local function canOpenChest(player, chest, chestState)
	if CombatStateService.IsPaused() then
		return false
	end

	if chest == nil or chest.Parent == nil then
		return false
	end

	if chestState == nil or chestState.Opened or chest:GetAttribute("ChestOpened") == true then
		return false
	end

	local playerRoot = getPlayerRoot(player)
	local chestPosition = getChestPosition(chest)

	if playerRoot == nil or chestPosition == nil then
		return false
	end

	local distance = (playerRoot.Position - chestPosition).Magnitude

	return distance <= ChestConfig.OpenDistance
end

local function onOpenRequested(player, chest)
	local profile = getOrCreateProfile(player)

	if profile.ActiveOpening ~= nil then
		sendOpenFailed(player, "OpeningAlreadyActive")
		return
	end

	chest = resolveChest(chest)

	if chest == nil then
		sendOpenFailed(player, "ChestMissing")
		return
	end

	if trackedChests[chest] == nil then
		trackChest(chest)
	end

	local chestState = trackedChests[chest]

	if not canOpenChest(player, chest, chestState) then
		sendOpenFailed(player, "TooFarOrUnavailable")
		return
	end

	local currentCost = profile.NextOpenCost
	local didSpend = CoinService.TrySpendCoins(player, currentCost)

	if not didSpend then
		sendOpenFailed(player, "NotEnoughCoins")
		return
	end

	chestState.Opened = true
	chest:SetAttribute("ChestOpening", true)
	chest:SetAttribute("ChestOpened", true)

	local reward = pickReward()

	profile.NextOpeningId += 1
	profile.NextOpenCost += ChestConfig.OpenCostIncrease
	profile.ActiveOpening = {
		OpeningId = tostring(player.UserId) .. "_" .. tostring(profile.NextOpeningId),
		Chest = chest,
		Reward = reward,
	}

	CombatStateService.Pause(getPauseReason(player))
	sendPrice(player)

	DebugLog.Info("Chest", "Ouverture coffre demarree", {
		Player = player.Name,
		Chest = chest,
		Cost = currentCost,
		NextOpenCost = profile.NextOpenCost,
		Reward = reward.Name,
	})

	openResultRemote:FireClient(player, {
		OpeningId = profile.ActiveOpening.OpeningId,
		Chest = chest,
		Reward = reward,
		SpinItems = createSpinItems(reward),
		Duration = ChestConfig.SlotDuration,
		Cost = currentCost,
		NextOpenCost = profile.NextOpenCost,
	})
end

local function onChoiceRequested(player, openingId, action)
	local profile = getOrCreateProfile(player)
	local activeOpening = profile.ActiveOpening

	if activeOpening == nil or activeOpening.OpeningId ~= tostring(openingId) then
		return
	end

	if action == "Accept" then
		finishOpening(player, true)
	elseif action == "Skip" then
		finishOpening(player, false)
	end
end

function ChestService.SetupPlayer(player)
	DebugLog.Info("Chest", "Setup joueur coffre", {
		Player = player.Name,
	})
	getOrCreateProfile(player)
	sendPrice(player)
end

function ChestService.RemovePlayer(player)
	local profile = profilesByUserId[player.UserId]

	if profile ~= nil and profile.ActiveOpening ~= nil then
		finishOpening(player, false)
	end

	CombatStateService.Resume(getPauseReason(player))
	profilesByUserId[player.UserId] = nil
end

function ChestService.Start()
	if isStarted then
		return
	end

	isStarted = true
	runtimeFolder = TemplateService.GetChestsRuntimeFolder()
	chestTemplate = TemplateService.GetTemplate(
		ChestConfig.TemplateFolderName,
		ChestConfig.ChestName,
		createFallbackChestTemplate
	)
	scanExistingChests()
	spawnInitialChests()
	DebugLog.Info("Chest", "ChestService demarre", {
		RuntimeFolder = runtimeFolder,
		Template = chestTemplate,
		TrackedChests = "scan et generation termines",
		SpawnedChestCount = spawnedChestCount,
		BaseOpenCost = ChestConfig.BaseOpenCost,
		OpenCostIncrease = ChestConfig.OpenCostIncrease,
	})

	Workspace.DescendantAdded:Connect(function(descendant)
		task.defer(function()
			trackChest(descendant)
		end)
	end)

	Workspace.DescendantRemoving:Connect(function(descendant)
		trackedChests[descendant] = nil
	end)

	openRequestRemote.OnServerEvent:Connect(onOpenRequested)
	choiceRequestRemote.OnServerEvent:Connect(onChoiceRequested)
end

return ChestService
