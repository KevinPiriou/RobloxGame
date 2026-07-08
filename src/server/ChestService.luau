local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ChestConfig = require(Shared:WaitForChild("ChestConfig"))

local CombatStateService = require(script.Parent:WaitForChild("CombatStateService"))
local CoinService = require(script.Parent:WaitForChild("CoinService"))

local ChestService = {}

local rng = Random.new()
local profilesByUserId = {}
local trackedChests = {}
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

local openRequestRemote = getOrCreateRemote("Chest_OpenRequest")
local openResultRemote = getOrCreateRemote("Chest_OpenResult")
local openFailedRemote = getOrCreateRemote("Chest_OpenFailed")
local choiceRequestRemote = getOrCreateRemote("Chest_ChoiceRequest")
local choiceResultRemote = getOrCreateRemote("Chest_ChoiceResult")
local priceUpdateRemote = getOrCreateRemote("Chest_PriceUpdate")

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

	return chest:FindFirstChildWhichIsA("BasePart", true)
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

	print(player.Name .. " a valide le coffre : " .. tostring(reward.Name))
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
	scanExistingChests()

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
