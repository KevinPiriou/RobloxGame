local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local CoinService = {}

local DATASTORE_NAME = "CoinProgress_v1"
local TEMPLATE_FOLDER_NAME = "CollectibleTemplates"
local coinDataStore = DataStoreService:GetDataStore(DATASTORE_NAME)

local profilesByUserId = {}
local trackedCoins = {}
local coinTemplate = nil
local elapsedSinceScan = 0
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

local function getOrCreateFolder(parent, folderName)
	local folder = parent:FindFirstChild(folderName)

	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = folderName
		folder.Parent = parent
	end

	assert(folder:IsA("Folder"), folderName .. " doit etre un Folder.")

	return folder
end

local function getRuntimeLootFolder()
	local runtimeFolder = Workspace:FindFirstChild(CombatConfig.RuntimeFolderName)

	if runtimeFolder == nil then
		runtimeFolder = Instance.new("Folder")
		runtimeFolder.Name = CombatConfig.RuntimeFolderName
		runtimeFolder.Parent = Workspace
	end

	return getOrCreateFolder(runtimeFolder, CombatConfig.LootFolderName)
end

local function getDataStoreKey(player)
	return "Player_" .. player.UserId
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

	local data = {
		Coins = sanitizeCoinCount(profile.Coins),
	}

	local success, errorMessage = pcall(function()
		coinDataStore:SetAsync(getDataStoreKey(player), data)
	end)

	profile.LastSaveSucceeded = success

	if not success then
		warn("Impossible de sauvegarder les pieces du joueur " .. player.Name .. " : " .. tostring(errorMessage))
	end

	if shouldNotify then
		sendCoinCount(player)
	end

	return success
end

local function loadProfile(player)
	local profile = getOrCreateProfile(player)
	local success, data = pcall(function()
		return coinDataStore:GetAsync(getDataStoreKey(player))
	end)

	if success and typeof(data) == "table" then
		profile.Coins = sanitizeCoinCount(data.Coins)
	elseif not success then
		warn("Impossible de charger les pieces du joueur " .. player.Name .. " : " .. tostring(data))
	end

	profile.Loaded = true
	profile.LastSaveSucceeded = success
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

	return coin:FindFirstChildWhichIsA("BasePart", true)
end

local function hasCoinModelAncestor(instance)
	local current = instance.Parent

	while current ~= nil do
		if current:IsA("Model") and current.Name == "Coin" then
			return true
		end

		current = current.Parent
	end

	return false
end

local function isCollectableCoin(instance)
	if instance.Name ~= "Coin" then
		return false
	end

	if instance:IsA("Model") then
		return findCoinRoot(instance) ~= nil
	end

	if instance:IsA("BasePart") then
		return not hasCoinModelAncestor(instance)
	end

	return false
end

local function createFallbackCoinTemplate(templateStorage)
	local part = Instance.new("Part")
	part.Name = "Coin"
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(0.3, 1.4, 1.4)
	part.Color = Color3.fromRGB(255, 205, 70)
	part.Material = Enum.Material.Metal
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Parent = templateStorage

	warn("Template Coin introuvable. Une piece simple de secours a ete creee.")

	return part
end

local function findCoinTemplate()
	local templateStorage = getOrCreateFolder(ServerStorage, TEMPLATE_FOLDER_NAME)
	local storedTemplate = templateStorage:FindFirstChild("Coin")

	if storedTemplate ~= nil then
		return storedTemplate
	end

	for _, root in ipairs({ ServerStorage, ReplicatedStorage, Workspace }) do
		local candidate = root:FindFirstChild("Coin", true)

		if candidate ~= nil and not candidate:IsDescendantOf(templateStorage) then
			local clone = candidate:Clone()
			clone.Parent = templateStorage
			return clone
		end
	end

	return createFallbackCoinTemplate(templateStorage)
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

local function trackCoin(instance)
	if not isCollectableCoin(instance) then
		return
	end

	trackedCoins[instance] = {
		Collected = false,
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

local function awardCoin(player)
	local profile = waitForProfileLoaded(player)

	profile.Coins += GameConfig.CoinsPerPickup
	sendCoinCount(player)
	saveProfile(player, true)
end

local function collectCoin(player, coin, coinState)
	if coinState.Collected then
		return
	end

	coinState.Collected = true
	collectCoinRemote:FireAllClients(coin, player.UserId, GameConfig.CoinAttractDuration)

	task.spawn(function()
		awardCoin(player)
	end)

	task.delay(GameConfig.CoinAttractDuration + 0.1, function()
		if coin.Parent ~= nil then
			coin:Destroy()
		end
	end)
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

				if distance <= GameConfig.CoinCollectDistance then
					collectCoin(player, coin, coinState)
					break
				end
			end
		end
	end
end

function CoinService.SetupPlayer(player)
	getOrCreateProfile(player)
	loadProfile(player)
end

function CoinService.SavePlayer(player)
	saveProfile(player, false)
end

function CoinService.RemovePlayer(player)
	CoinService.SavePlayer(player)
	profilesByUserId[player.UserId] = nil
end

function CoinService.SpawnCoin(position)
	if coinTemplate == nil then
		coinTemplate = findCoinTemplate()
	end

	local coin = coinTemplate:Clone()
	coin.Name = "Coin"
	coin.Parent = getRuntimeLootFolder()

	prepareCoin(coin)
	pivotCoin(coin, position)
	trackCoin(coin)

	return coin
end

function CoinService.Start()
	coinTemplate = findCoinTemplate()
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
		elapsedSinceScan += deltaTime

		if elapsedSinceScan < GameConfig.CoinScanInterval then
			return
		end

		elapsedSinceScan = 0
		scanCoinProximity()
	end)
end

return CoinService
