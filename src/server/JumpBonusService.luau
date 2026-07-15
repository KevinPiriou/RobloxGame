local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))
local DebugLog = require(Shared:WaitForChild("DebugLog"))
local FeatureFlags = require(Shared:WaitForChild("FeatureFlags"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local JumpBonusService = {}

local DATASTORE_NAME = "QuizJumpBonusProgress_v1"
local bonusDataStore = DataStoreService:GetDataStore(DATASTORE_NAME)

local baseJumpByUserId = {}
local characterConnectionsByUserId = {}
local externalJumpMultipliersByUserId = {}
local profilesByUserId = {}

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

local updateEffectsRemote = getOrCreateRemote("Quiz_UpdateEffects")

local function getDataStoreKey(player)
	return "Player_" .. player.UserId
end

local function sanitizeStackCount(value)
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
			JumpBonusStacks = 0,
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

local function getHumanoid(player)
	local character = player.Character

	if character == nil then
		return nil
	end

	return character:FindFirstChildOfClass("Humanoid")
end

local function rememberBaseJump(player, humanoid)
	if baseJumpByUserId[player.UserId] ~= nil then
		return
	end

	baseJumpByUserId[player.UserId] = {
		UseJumpPower = humanoid.UseJumpPower,
		JumpPower = CombatConfig.PlayerBaseJumpPower,
		JumpHeight = CombatConfig.PlayerBaseJumpHeight,
	}
end

local function getJumpMultiplierFromStacks(stackCount)
	return math.max(
		GameConfig.MinimumJumpMultiplier,
		1 + (stackCount * (GameConfig.JumpBonusMultiplier - 1))
	)
end

local function getJumpMultiplier(player)
	local profile = getOrCreateProfile(player)
	local externalMultiplier = externalJumpMultipliersByUserId[player.UserId] or 1
	local stackCount = profile.JumpBonusStacks

	if not FeatureFlags.QuizEnabled then
		stackCount = 0
	end

	return getJumpMultiplierFromStacks(stackCount) * externalMultiplier
end

local function applyJumpMultiplier(player)
	local humanoid = getHumanoid(player)

	if humanoid == nil then
		return
	end

	rememberBaseJump(player, humanoid)

	local baseJump = baseJumpByUserId[player.UserId]
	local multiplier = getJumpMultiplier(player)

	if humanoid.UseJumpPower then
		humanoid.JumpPower = baseJump.JumpPower * multiplier
	else
		humanoid.JumpHeight = baseJump.JumpHeight * multiplier
	end
end

local function sendBonusState(player)
	local profile = getOrCreateProfile(player)

	updateEffectsRemote:FireClient(player, {
		JumpBonusStacks = profile.JumpBonusStacks,
		JumpMultiplier = getJumpMultiplier(player),
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
		JumpBonusStacks = sanitizeStackCount(profile.JumpBonusStacks),
	}

	local success, errorMessage = pcall(function()
		bonusDataStore:SetAsync(getDataStoreKey(player), data)
	end)

	profile.LastSaveSucceeded = success

	if not success then
		DebugLog.Warn("Perks", "Sauvegarde bonus saut impossible", {
			Player = player.Name,
			Error = tostring(errorMessage),
		})
	end

	if shouldNotify then
		sendBonusState(player)
	end

	return success
end

local function loadProfile(player)
	local profile = getOrCreateProfile(player)
	local success, data = pcall(function()
		return bonusDataStore:GetAsync(getDataStoreKey(player))
	end)

	if success and typeof(data) == "table" then
		profile.JumpBonusStacks = sanitizeStackCount(data.JumpBonusStacks)
	elseif not success then
		DebugLog.Warn("Perks", "Chargement bonus saut impossible", {
			Player = player.Name,
			Error = tostring(data),
		})
	end

	profile.Loaded = true
	profile.LastSaveSucceeded = success
end

local function updateBonusStacks(player, nextStackCount)
	local profile = getOrCreateProfile(player)

	profile.JumpBonusStacks = sanitizeStackCount(nextStackCount)

	applyJumpMultiplier(player)
	saveProfile(player, true)
end

function JumpBonusService.SetupPlayer(player)
	DebugLog.Info("Perks", "Setup joueur bonus saut", {
		Player = player.Name,
		QuizEnabled = FeatureFlags.QuizEnabled,
	})
	getOrCreateProfile(player)

	characterConnectionsByUserId[player.UserId] = player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid", 5)

		if humanoid ~= nil then
			baseJumpByUserId[player.UserId] = nil
			applyJumpMultiplier(player)
			sendBonusState(player)
		end
	end)

	if FeatureFlags.QuizEnabled then
		loadProfile(player)
	else
		local profile = getOrCreateProfile(player)

		profile.JumpBonusStacks = 0
		profile.Loaded = true
		profile.LastSaveSucceeded = true
	end

	applyJumpMultiplier(player)
	sendBonusState(player)
end

function JumpBonusService.GrantDoubleJump(player)
	if not FeatureFlags.QuizEnabled then
		return "Quiz desactive : aucun bonus applique."
	end

	local profile = waitForProfileLoaded(player)
	local nextStackCount = profile.JumpBonusStacks + 1

	updateBonusStacks(player, nextStackCount)

	return ("Bonus permanent : saut +1 stack, total x%.1f."):format(getJumpMultiplier(player))
end

function JumpBonusService.ApplyJumpMalus(player)
	if not FeatureFlags.QuizEnabled then
		return "Quiz desactive : aucun malus applique."
	end

	local profile = waitForProfileLoaded(player)

	if profile.JumpBonusStacks <= 0 then
		sendBonusState(player)
		return "Malus sans effet : aucun bonus saut a reduire."
	end

	local nextStackCount = profile.JumpBonusStacks - GameConfig.JumpMalusStacksRemoved
	updateBonusStacks(player, nextStackCount)

	return ("Malus : -%d bonus saut, total x%.1f."):format(
		GameConfig.JumpMalusStacksRemoved,
		getJumpMultiplier(player)
	)
end

function JumpBonusService.ResetPowerUps(player)
	local profile = waitForProfileLoaded(player)

	if not profile.Loaded then
		sendBonusState(player)
		return "Bonus pas encore charges, reessaie"
	end

	updateBonusStacks(player, 0)

	return "PowerUps bonus/malus reinitialises"
end

function JumpBonusService.SetExternalJumpMultiplier(player, multiplier)
	externalJumpMultipliersByUserId[player.UserId] = math.max(1, multiplier or 1)
	applyJumpMultiplier(player)
	sendBonusState(player)
	DebugLog.ThrottledInfo("Perks", "jump_external_" .. player.UserId, 1, "Multiplicateur saut externe applique", {
		Player = player.Name,
		Multiplier = externalJumpMultipliersByUserId[player.UserId],
	})
end

function JumpBonusService.SavePlayer(player)
	if not FeatureFlags.QuizEnabled then
		return
	end

	saveProfile(player, false)
end

function JumpBonusService.RemovePlayer(player)
	JumpBonusService.SavePlayer(player)

	local characterConnection = characterConnectionsByUserId[player.UserId]

	if characterConnection ~= nil then
		characterConnection:Disconnect()
	end

	characterConnectionsByUserId[player.UserId] = nil
	baseJumpByUserId[player.UserId] = nil
	externalJumpMultipliersByUserId[player.UserId] = nil
	profilesByUserId[player.UserId] = nil
end

return JumpBonusService
