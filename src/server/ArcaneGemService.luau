local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DebugLog = require(Shared:WaitForChild("DebugLog"))
local PickupFeedbackConfig = require(Shared:WaitForChild("PickupFeedbackConfig"))
local ProgressionConfig = require(Shared:WaitForChild("ProgressionConfig"))

local ArcaneGemService = {}

local progressionDataStore = DataStoreService:GetDataStore(ProgressionConfig.DataStoreName)
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

local pickupFeedbackRemote = getOrCreateRemote(PickupFeedbackConfig.RemoteName)

local function sanitizeAmount(value)
	return math.max(0, math.floor(tonumber(value) or 0))
end

local function createDefaultData()
	return {
		Version = 1,
		ArcaneGems = ProgressionConfig.DefaultArcaneGems,
	}
end

local function normalizeData(rawData)
	local data = createDefaultData()

	if typeof(rawData) ~= "table" then
		return data
	end

	data.ArcaneGems = sanitizeAmount(rawData.ArcaneGems)

	return data
end

local function getDataStoreKey(player)
	return "Player_" .. player.UserId
end

local function getOrCreateProfile(player)
	local profile = profilesByUserId[player.UserId]

	if profile == nil then
		profile = {
			Data = createDefaultData(),
			Loaded = false,
			SessionOnly = false,
			Dirty = false,
		}
		profilesByUserId[player.UserId] = profile
	end

	return profile
end

local function publishProfile(player, profile)
	player:SetAttribute(ProgressionConfig.ArcaneGemsAttributeName, profile.Data.ArcaneGems)
end

local function loadProfile(player)
	local profile = getOrCreateProfile(player)
	local success, rawData = pcall(function()
		return progressionDataStore:GetAsync(getDataStoreKey(player))
	end)

	if success then
		profile.Data = normalizeData(rawData)
		profile.Loaded = true
		profile.SessionOnly = false
	elseif RunService:IsStudio() then
		profile.Data = createDefaultData()
		profile.Loaded = true
		profile.SessionOnly = true
		DebugLog.Warn("Progression", "DataStore de progression indisponible dans Studio", {
			Player = player.Name,
			Error = tostring(rawData),
		})
	else
		profile.Loaded = false
		DebugLog.Warn("Progression", "Chargement des gemmes arcaniques impossible", {
			Player = player.Name,
			Error = tostring(rawData),
		})
	end

	publishProfile(player, profile)
end

function ArcaneGemService.GetArcaneGems(player)
	if player == nil then
		return 0
	end

	return getOrCreateProfile(player).Data.ArcaneGems
end

function ArcaneGemService.AwardArcaneGems(player, amount, source, showFeedback)
	if player == nil or player.Parent ~= Players then
		return false, "InvalidPlayer"
	end

	local profile = getOrCreateProfile(player)
	local sanitizedAmount = sanitizeAmount(amount)

	if not profile.Loaded then
		return false, "ProfileNotLoaded"
	end

	if sanitizedAmount <= 0 then
		return false, "InvalidAmount"
	end

	profile.Data.ArcaneGems += sanitizedAmount
	profile.Dirty = true
	publishProfile(player, profile)

	if showFeedback == true then
		pickupFeedbackRemote:FireClient(player, {
			Kind = "ArcaneGem",
			Amount = sanitizedAmount,
		})
	end

	DebugLog.Info("Progression", "Gemmes arcaniques attribuees", {
		Player = player.Name,
		Amount = sanitizedAmount,
		Total = profile.Data.ArcaneGems,
		Source = source or "Unknown",
	})

	return true
end

function ArcaneGemService.SavePlayer(player)
	if player == nil then
		return false
	end

	local profile = profilesByUserId[player.UserId]

	if profile == nil or not profile.Loaded or not profile.Dirty then
		return true
	end

	if profile.SessionOnly then
		profile.Dirty = false
		return true
	end

	local success, updatedData = pcall(function()
		return progressionDataStore:UpdateAsync(getDataStoreKey(player), function(rawData)
			local data = normalizeData(rawData)
			data.ArcaneGems = profile.Data.ArcaneGems
			return data
		end)
	end)

	if not success then
		DebugLog.Warn("Progression", "Sauvegarde des gemmes arcaniques impossible", {
			Player = player.Name,
			Error = tostring(updatedData),
		})
		return false
	end

	profile.Data = normalizeData(updatedData)
	profile.Dirty = false
	publishProfile(player, profile)

	return true
end

function ArcaneGemService.SetupPlayer(player)
	loadProfile(player)

	DebugLog.Info("Progression", "Profil de gemmes arcaniques initialise", {
		Player = player.Name,
		ArcaneGems = ArcaneGemService.GetArcaneGems(player),
	})
end

function ArcaneGemService.RemovePlayer(player)
	ArcaneGemService.SavePlayer(player)
	profilesByUserId[player.UserId] = nil
end

return ArcaneGemService
