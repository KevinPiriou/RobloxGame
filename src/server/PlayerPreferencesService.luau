local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AudioConfig = require(Shared:WaitForChild("AudioConfig"))
local DebugLog = require(Shared:WaitForChild("DebugLog"))
local GraphicsConfig = require(Shared:WaitForChild("GraphicsConfig"))
local PlayerPreferencesConfig = require(Shared:WaitForChild("PlayerPreferencesConfig"))

local PlayerPreferencesService = {}

local preferencesDataStore = DataStoreService:GetDataStore(PlayerPreferencesConfig.DataStoreName)
local profilesByUserId = {}
local isStarted = false

local function getOrCreateRemote(remoteName, className)
	local remote = ReplicatedStorage:FindFirstChild(remoteName)

	if remote == nil then
		remote = Instance.new(className)
		remote.Name = remoteName
		remote.Parent = ReplicatedStorage
	end

	assert(remote.ClassName == className, remoteName .. " doit etre un " .. className .. ".")
	return remote
end

local getStateRemote = getOrCreateRemote(PlayerPreferencesConfig.GetStateRemoteName, "RemoteFunction")
local setAudioRemote = getOrCreateRemote(PlayerPreferencesConfig.SetAudioRemoteName, "RemoteEvent")
local setGraphicsRemote = getOrCreateRemote(PlayerPreferencesConfig.SetGraphicsRemoteName, "RemoteEvent")
local updateRemote = getOrCreateRemote(PlayerPreferencesConfig.UpdateRemoteName, "RemoteEvent")

local function createDefaultAudio()
	local audio = {}

	for settingName, defaultValue in pairs(AudioConfig.DefaultVolumes) do
		audio[settingName] = defaultValue
	end

	return audio
end

local function createDefaultData()
	return {
		Version = PlayerPreferencesConfig.DataVersion,
		Audio = createDefaultAudio(),
		Graphics = table.clone(GraphicsConfig.DefaultSettings),
	}
end

local function normalizeGraphics(rawGraphics)
	local graphics = table.clone(GraphicsConfig.DefaultSettings)

	if typeof(rawGraphics) ~= "table" then
		return graphics
	end

	if typeof(rawGraphics.Quality) == "string" and GraphicsConfig.QualityProfiles[rawGraphics.Quality] ~= nil then
		graphics.Quality = rawGraphics.Quality
	end

	graphics.EffectsIntensity = math.clamp(
		tonumber(rawGraphics.EffectsIntensity) or graphics.EffectsIntensity,
		0,
		1
	)
	graphics.ShadowsEnabled = rawGraphics.ShadowsEnabled ~= false

	return graphics
end

local function normalizeAudio(rawAudio)
	local audio = createDefaultAudio()

	if typeof(rawAudio) ~= "table" then
		return audio
	end

	for settingName, defaultValue in pairs(AudioConfig.DefaultVolumes) do
		local value = tonumber(rawAudio[settingName])
		audio[settingName] = math.clamp(value or defaultValue, 0, 1)
	end

	return audio
end

local function normalizeData(rawData)
	local data = createDefaultData()

	if typeof(rawData) ~= "table" then
		return data
	end

	data.Audio = normalizeAudio(rawData.Audio)
	data.Graphics = normalizeGraphics(rawData.Graphics)
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
			Revision = 0,
			SaveScheduled = false,
		}
		profilesByUserId[player.UserId] = profile
	end

	return profile
end

local function buildPublicState(profile)
	return {
		Loaded = profile.Loaded,
		Audio = table.clone(profile.Data.Audio),
		Graphics = table.clone(profile.Data.Graphics),
	}
end

local function publishState(player, profile)
	if player.Parent == Players then
		updateRemote:FireClient(player, buildPublicState(profile))
	end
end

local function saveProfile(player, profile)
	if not profile.Loaded or profile.SessionOnly or not profile.Dirty then
		return true
	end

	local savedRevision = profile.Revision
	local audioSnapshot = table.clone(profile.Data.Audio)
	local graphicsSnapshot = table.clone(profile.Data.Graphics)
	local success, result = pcall(function()
		return preferencesDataStore:UpdateAsync(getDataStoreKey(player), function(rawData)
			local data = normalizeData(rawData)
			data.Version = PlayerPreferencesConfig.DataVersion
			data.Audio = audioSnapshot
			data.Graphics = graphicsSnapshot
			return data
		end)
	end)

	if not success then
		DebugLog.Warn("Preferences", "Sauvegarde preferences impossible", {
			Player = player.Name,
			Error = tostring(result),
		})
		return false
	end

	if profile.Revision == savedRevision then
		profile.Dirty = false
	end

	return true
end

local function scheduleSave(player, profile)
	if profile.SessionOnly or profile.SaveScheduled then
		return
	end

	profile.SaveScheduled = true
	task.delay(PlayerPreferencesConfig.SaveDebounceSeconds, function()
		profile.SaveScheduled = false

		if player.Parent == Players then
			saveProfile(player, profile)
		end
	end)
end

function PlayerPreferencesService.SetupPlayer(player)
	local profile = getOrCreateProfile(player)
	local success, rawData = pcall(function()
		return preferencesDataStore:GetAsync(getDataStoreKey(player))
	end)

	if success then
		profile.Data = normalizeData(rawData)
		profile.Loaded = true
		profile.SessionOnly = false
	elseif RunService:IsStudio() then
		profile.Data = createDefaultData()
		profile.Loaded = true
		profile.SessionOnly = true
		DebugLog.Warn("Preferences", "DataStore preferences indisponible dans Studio", {
			Player = player.Name,
			Error = tostring(rawData),
		})
	else
		profile.Loaded = false
		DebugLog.Warn("Preferences", "Chargement preferences impossible", {
			Player = player.Name,
			Error = tostring(rawData),
		})
	end

	publishState(player, profile)
end

function PlayerPreferencesService.GetPublicState(player)
	return buildPublicState(getOrCreateProfile(player))
end

function PlayerPreferencesService.SetAudio(player, rawAudio)
	if typeof(rawAudio) ~= "table" then
		return false
	end

	local profile = getOrCreateProfile(player)

	if not profile.Loaded then
		return false
	end

	local nextAudio = table.clone(profile.Data.Audio)
	local changed = false

	for settingName, defaultValue in pairs(AudioConfig.DefaultVolumes) do
		if rawAudio[settingName] ~= nil then
			local value = tonumber(rawAudio[settingName])
			local normalizedValue = math.clamp(value or defaultValue, 0, 1)

			if nextAudio[settingName] ~= normalizedValue then
				nextAudio[settingName] = normalizedValue
				changed = true
			end
		end
	end

	if not changed then
		return true
	end

	profile.Data.Audio = nextAudio
	profile.Dirty = true
	profile.Revision += 1

	publishState(player, profile)
	scheduleSave(player, profile)

	return true
end

function PlayerPreferencesService.SetGraphics(player, rawGraphics)
	if typeof(rawGraphics) ~= "table" then
		return false
	end

	local profile = getOrCreateProfile(player)

	if not profile.Loaded then
		return false
	end

	local nextGraphics = normalizeGraphics(rawGraphics)
	local currentGraphics = profile.Data.Graphics
	local changed = currentGraphics.Quality ~= nextGraphics.Quality
		or currentGraphics.EffectsIntensity ~= nextGraphics.EffectsIntensity
		or currentGraphics.ShadowsEnabled ~= nextGraphics.ShadowsEnabled

	if not changed then
		return true
	end

	profile.Data.Graphics = nextGraphics
	profile.Dirty = true
	profile.Revision += 1

	publishState(player, profile)
	scheduleSave(player, profile)

	return true
end

function PlayerPreferencesService.SavePlayer(player)
	local profile = profilesByUserId[player.UserId]

	if profile == nil then
		return true
	end

	return saveProfile(player, profile)
end

function PlayerPreferencesService.RemovePlayer(player)
	profilesByUserId[player.UserId] = nil
end

function PlayerPreferencesService.Start()
	if isStarted then
		return
	end

	isStarted = true
	getStateRemote.OnServerInvoke = function(player)
		return PlayerPreferencesService.GetPublicState(player)
	end
	setAudioRemote.OnServerEvent:Connect(function(player, rawAudio)
		PlayerPreferencesService.SetAudio(player, rawAudio)
	end)
	setGraphicsRemote.OnServerEvent:Connect(function(player, rawGraphics)
		PlayerPreferencesService.SetGraphics(player, rawGraphics)
	end)

	DebugLog.Info("Preferences", "PlayerPreferencesService demarre", {
		DataStore = PlayerPreferencesConfig.DataStoreName,
	})
end

return PlayerPreferencesService
