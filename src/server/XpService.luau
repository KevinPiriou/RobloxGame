local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))

local XpService = {}

local TEMPLATE_FOLDER_NAME = "CollectibleTemplates"
local profilesByUserId = {}
local trackedGems = {}
local xpGemTemplate = nil
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

local updateXpRemote = getOrCreateRemote("Xp_UpdateCount")
local collectXpRemote = getOrCreateRemote("Xp_PlayCollect")

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

local function getOrCreateProfile(player)
	local profile = profilesByUserId[player.UserId]

	if profile == nil then
		profile = {
			Xp = 0,
		}
		profilesByUserId[player.UserId] = profile
	end

	return profile
end

local function sendXpCount(player)
	local profile = getOrCreateProfile(player)

	updateXpRemote:FireClient(player, {
		Xp = profile.Xp,
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

local function hasGemModelAncestor(instance)
	local current = instance.Parent

	while current ~= nil do
		if current:IsA("Model") and current.Name == CombatConfig.XpGemTemplateName then
			return true
		end

		current = current.Parent
	end

	return false
end

local function isCollectableGem(instance)
	if instance.Name ~= CombatConfig.XpGemTemplateName then
		return false
	end

	if instance:IsA("Model") then
		return findGemRoot(instance) ~= nil
	end

	if instance:IsA("BasePart") then
		return not hasGemModelAncestor(instance)
	end

	return false
end

local function createFallbackGemTemplate(templateStorage)
	local part = Instance.new("Part")
	part.Name = CombatConfig.XpGemTemplateName
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(1, 1, 1)
	part.Color = Color3.fromRGB(80, 210, 255)
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Parent = templateStorage

	warn("Template XpGem introuvable. Une gemme XP simple de secours a ete creee.")

	return part
end

local function findGemTemplate()
	local templateStorage = getOrCreateFolder(ServerStorage, TEMPLATE_FOLDER_NAME)
	local storedTemplate = templateStorage:FindFirstChild(CombatConfig.XpGemTemplateName)

	if storedTemplate ~= nil then
		return storedTemplate
	end

	for _, root in ipairs({ ServerStorage, ReplicatedStorage, Workspace }) do
		local candidate = root:FindFirstChild(CombatConfig.XpGemTemplateName, true)

		if candidate ~= nil and not candidate:IsDescendantOf(templateStorage) then
			local clone = candidate:Clone()
			clone.Parent = templateStorage
			return clone
		end
	end

	return createFallbackGemTemplate(templateStorage)
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

local function trackGem(instance)
	if not isCollectableGem(instance) then
		return
	end

	trackedGems[instance] = {
		Collected = false,
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

local function awardXp(player)
	local profile = getOrCreateProfile(player)

	profile.Xp += CombatConfig.XpPerGem
	getOrCreateXpValue(player).Value = profile.Xp
	sendXpCount(player)
end

local function collectGem(player, gem, gemState)
	if gemState.Collected then
		return
	end

	gemState.Collected = true
	collectXpRemote:FireAllClients(gem, player.UserId, CombatConfig.XpAttractDuration)
	awardXp(player)

	task.delay(CombatConfig.XpAttractDuration + 0.1, function()
		if gem.Parent ~= nil then
			gem:Destroy()
		end
	end)
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

				if distance <= CombatConfig.XpCollectDistance then
					collectGem(player, gem, gemState)
					break
				end
			end
		end
	end
end

function XpService.SetupPlayer(player)
	local profile = getOrCreateProfile(player)
	getOrCreateXpValue(player).Value = profile.Xp
	sendXpCount(player)
end

function XpService.RemovePlayer(player)
	profilesByUserId[player.UserId] = nil
end

function XpService.SpawnXpGem(position)
	if xpGemTemplate == nil then
		xpGemTemplate = findGemTemplate()
	end

	local gem = xpGemTemplate:Clone()
	gem.Name = CombatConfig.XpGemTemplateName
	gem.Parent = getRuntimeLootFolder()

	prepareCollectible(gem)
	pivotCollectible(gem, position)
	trackGem(gem)

	return gem
end

function XpService.Start()
	xpGemTemplate = findGemTemplate()
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
		elapsedSinceScan += deltaTime

		if elapsedSinceScan < 0.15 then
			return
		end

		elapsedSinceScan = 0
		scanGemProximity()
	end)
end

return XpService
