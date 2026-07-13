local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AudioConfig = require(Shared:WaitForChild("AudioConfig"))
local DebugLog = require(Shared:WaitForChild("DebugLog"))
local PlayerPreferencesConfig = require(Shared:WaitForChild("PlayerPreferencesConfig"))

local AudioController = {}

local isStarted = false
local remoteConnection = nil
local loopsById = {}
local activeMusic = nil
local lastMusicTemplate = nil
local settingsChanged = Instance.new("BindableEvent")
local settings = {}
local setAudioPreferencesRemote = nil
local preferenceSaveSerial = 0

for settingName, defaultValue in pairs(AudioConfig.DefaultVolumes) do
	settings[settingName] = defaultValue
end

local function getSoundGroup(category)
	local groupName = AudioConfig.SoundGroupNames[category]

	if groupName == nil then
		return nil
	end

	local soundGroup = SoundService:FindFirstChild(groupName)

	if soundGroup ~= nil and soundGroup:IsA("SoundGroup") then
		return soundGroup
	end

	return nil
end

local function applyMix()
	local masterVolume = settings.Master or 1

	for category in pairs(AudioConfig.SoundGroupNames) do
		local soundGroup = getSoundGroup(category)

		if soundGroup ~= nil then
			soundGroup.Volume = masterVolume * (settings[category] or 1)
		end
	end

	settingsChanged:Fire(AudioController.GetSettings())
end

local function applyAudioPreferences(rawAudio)
	if typeof(rawAudio) ~= "table" then
		return
	end

	for settingName, defaultValue in pairs(AudioConfig.DefaultVolumes) do
		local value = tonumber(rawAudio[settingName])
		settings[settingName] = math.clamp(value or defaultValue, 0, 1)
	end
end

local function schedulePreferencesSave()
	if setAudioPreferencesRemote == nil then
		return
	end

	preferenceSaveSerial += 1
	local scheduledSerial = preferenceSaveSerial

	task.delay(PlayerPreferencesConfig.ClientAudioDebounceSeconds, function()
		if scheduledSerial ~= preferenceSaveSerial or setAudioPreferencesRemote == nil then
			return
		end

		setAudioPreferencesRemote:FireServer(AudioController.GetSettings())
	end)
end

local function connectPreferences()
	local updateRemote = ReplicatedStorage:WaitForChild(PlayerPreferencesConfig.UpdateRemoteName, 15)

	if updateRemote ~= nil and updateRemote:IsA("RemoteEvent") then
		updateRemote.OnClientEvent:Connect(function(payload)
			if typeof(payload) == "table" and typeof(payload.Audio) == "table" then
				applyAudioPreferences(payload.Audio)
				applyMix()
			end
		end)
	end

	local setRemote = ReplicatedStorage:WaitForChild(PlayerPreferencesConfig.SetAudioRemoteName, 15)

	if setRemote ~= nil and setRemote:IsA("RemoteEvent") then
		setAudioPreferencesRemote = setRemote
	end

	local getRemote = ReplicatedStorage:WaitForChild(PlayerPreferencesConfig.GetStateRemoteName, 15)

	if getRemote == nil or not getRemote:IsA("RemoteFunction") then
		DebugLog.Warn("Preferences", "Remote de lecture preferences introuvable")
		return
	end

	local success, payload = pcall(function()
		return getRemote:InvokeServer()
	end)

	if success and typeof(payload) == "table" and typeof(payload.Audio) == "table" then
		applyAudioPreferences(payload.Audio)
	elseif not success then
		DebugLog.Warn("Preferences", "Lecture preferences client impossible", {
			Error = tostring(payload),
		})
	end
end

local function destroySound(sound)
	if sound ~= nil and sound.Parent ~= nil then
		sound:Destroy()
	end
end

local function createSound(soundKey, isLooped)
	local definition = AudioConfig.SoundEffects[soundKey]

	if definition == nil or definition.SoundId == nil or definition.SoundId == "" then
		return nil
	end

	local sound = Instance.new("Sound")
	sound.Name = "Local_" .. soundKey
	sound.SoundId = definition.SoundId
	sound.Volume = definition.Volume or 0.75
	sound.Looped = isLooped == true

	local soundGroup = getSoundGroup(definition.Category or "Effects")

	if soundGroup ~= nil then
		sound.SoundGroup = soundGroup
	end

	sound.Parent = SoundService

	return sound, definition
end

local function playOneShot(soundKey)
	local sound, definition = createSound(soundKey, false)

	if sound == nil then
		return
	end

	sound:Play()

	sound.Ended:Connect(function()
		destroySound(sound)
	end)

	task.delay(definition.Lifetime or 8, function()
		destroySound(sound)
	end)
end

local function startLoop(soundKey, loopId)
	local previousSound = loopsById[loopId]

	if previousSound ~= nil then
		previousSound:Stop()
		destroySound(previousSound)
	end

	local sound = createSound(soundKey, true)

	if sound == nil then
		return
	end

	loopsById[loopId] = sound
	sound:Play()
end

local function stopLoop(loopId)
	local sound = loopsById[loopId]

	if sound == nil then
		return
	end

	loopsById[loopId] = nil
	sound:Stop()
	destroySound(sound)
end

local function getMusicPool()
	local musicPool = SoundService:FindFirstChild(AudioConfig.MusicPoolFolderName)

	if musicPool ~= nil then
		return musicPool
	end

	local legacyPool = Workspace:FindFirstChild(AudioConfig.MusicPoolFolderName)

	if legacyPool ~= nil then
		DebugLog.ThrottledWarn("Audio", "music_pool_workspace", 30, "MusicPool doit etre deplace dans SoundService", {
			Pool = legacyPool,
		})
	end

	return legacyPool
end

local function getMusicTemplates()
	local musicPool = getMusicPool()

	if musicPool == nil then
		return {}
	end

	local templates = {}

	for _, descendant in ipairs(musicPool:GetDescendants()) do
		if descendant:IsA("Sound") and descendant.SoundId ~= "" then
			table.insert(templates, descendant)
		end
	end

	return templates
end

local function playNextMusic()
	local templates = getMusicTemplates()

	if #templates == 0 then
		return
	end

	if activeMusic ~= nil then
		activeMusic:Stop()
		destroySound(activeMusic)
		activeMusic = nil
	end

	local selectedTemplate = templates[math.random(1, #templates)]

	if #templates > 1 and selectedTemplate == lastMusicTemplate then
		selectedTemplate = templates[(table.find(templates, selectedTemplate) % #templates) + 1]
	end

	lastMusicTemplate = selectedTemplate

	local music = selectedTemplate:Clone()
	music.Name = "ActiveMusic"
	music.Looped = false
	music.Playing = false

	local musicGroup = getSoundGroup("Music")

	if musicGroup ~= nil then
		music.SoundGroup = musicGroup
	end

	music.Parent = SoundService
	activeMusic = music

	music.Ended:Connect(function()
		if activeMusic ~= music then
			return
		end

		activeMusic = nil
		destroySound(music)
		task.delay(0.4, playNextMusic)
	end)

	music:Play()
end

local function connectAudioRemote()
	local remote = ReplicatedStorage:WaitForChild(AudioConfig.RemoteName, 30)

	if remote == nil or not remote:IsA("RemoteEvent") then
		DebugLog.Warn("Audio", "Remote audio introuvable", {
			RemoteName = AudioConfig.RemoteName,
		})
		return
	end

	if remoteConnection ~= nil then
		remoteConnection:Disconnect()
	end

	remoteConnection = remote.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end

		if payload.Action == "Play" then
			playOneShot(payload.SoundKey)
		elseif payload.Action == "StartLoop" then
			startLoop(payload.SoundKey, payload.LoopId)
		elseif payload.Action == "StopLoop" then
			stopLoop(payload.LoopId)
		end
	end)
end

function AudioController.GetSettings()
	local copy = {}

	for settingName, value in pairs(settings) do
		copy[settingName] = value
	end

	return copy
end

function AudioController.SetVolume(settingName, value)
	if AudioConfig.DefaultVolumes[settingName] == nil then
		return
	end

	settings[settingName] = math.clamp(tonumber(value) or 0, 0, 1)
	applyMix()
	schedulePreferencesSave()
end

function AudioController.Start()
	if isStarted then
		return
	end

	isStarted = true
	connectPreferences()
	applyMix()

	task.spawn(connectAudioRemote)
	task.defer(playNextMusic)

	SoundService.ChildAdded:Connect(function(child)
		if child.Name == AudioConfig.MusicPoolFolderName or child:IsA("SoundGroup") then
			applyMix()
			playNextMusic()
		end
	end)

	Workspace.ChildAdded:Connect(function(child)
		if child.Name == AudioConfig.MusicPoolFolderName then
			playNextMusic()
		end
	end)
end

AudioController.Changed = settingsChanged

return AudioController
