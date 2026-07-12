local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AudioConfig = require(Shared:WaitForChild("AudioConfig"))
local DebugLog = require(Shared:WaitForChild("DebugLog"))

local AudioService = {}

local isStarted = false
local soundGroupsByCategory = {}

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

local audioRemote = getOrCreateRemote(AudioConfig.RemoteName)

local function getOrCreateSoundGroup(category)
	local groupName = AudioConfig.SoundGroupNames[category]
	assert(groupName ~= nil, "Categorie audio inconnue : " .. tostring(category))

	local soundGroup = SoundService:FindFirstChild(groupName)

	if soundGroup == nil then
		soundGroup = Instance.new("SoundGroup")
		soundGroup.Name = groupName
		soundGroup.Parent = SoundService
	end

	assert(soundGroup:IsA("SoundGroup"), groupName .. " doit etre un SoundGroup.")
	soundGroup.Volume = 1
	soundGroupsByCategory[category] = soundGroup

	return soundGroup
end

local function configureMusicPool()
	local musicPool = SoundService:FindFirstChild(AudioConfig.MusicPoolFolderName)

	if musicPool == nil then
		local legacyPool = Workspace:FindFirstChild(AudioConfig.MusicPoolFolderName)

		if legacyPool ~= nil then
			DebugLog.Warn("Audio", "MusicPool encore dans Workspace", {
				ExpectedParent = SoundService,
				Pool = legacyPool,
			})
		end

		return
	end

	local musicGroup = soundGroupsByCategory.Music

	for _, descendant in ipairs(musicPool:GetDescendants()) do
		if descendant:IsA("Sound") then
			descendant.Playing = false
			descendant.Looped = false
			descendant.SoundGroup = musicGroup
		end
	end
end

local function canPlayForPlayer(player, soundKey)
	if player == nil or player.Parent ~= Players then
		return nil
	end

	local definition = AudioConfig.SoundEffects[soundKey]

	if definition == nil then
		DebugLog.ThrottledWarn("Audio", "unknown_" .. tostring(soundKey), 10, "Effet audio inconnu", {
			SoundKey = soundKey,
		})
		return nil
	end

	if definition.SoundId == nil or definition.SoundId == "" then
		return nil
	end

	return definition
end

function AudioService.PlayForPlayer(player, soundKey)
	if canPlayForPlayer(player, soundKey) == nil then
		return false
	end

	audioRemote:FireClient(player, {
		Action = "Play",
		SoundKey = soundKey,
	})

	return true
end

function AudioService.StartLoopForPlayer(player, soundKey, loopId)
	local definition = canPlayForPlayer(player, soundKey)

	if definition == nil or definition.Looped ~= true or loopId == nil or loopId == "" then
		return false
	end

	audioRemote:FireClient(player, {
		Action = "StartLoop",
		SoundKey = soundKey,
		LoopId = tostring(loopId),
	})

	return true
end

function AudioService.StopLoopForPlayer(player, loopId)
	if player == nil or player.Parent ~= Players or loopId == nil or loopId == "" then
		return false
	end

	audioRemote:FireClient(player, {
		Action = "StopLoop",
		LoopId = tostring(loopId),
	})

	return true
end

function AudioService.Start()
	if isStarted then
		return
	end

	isStarted = true

	for category in pairs(AudioConfig.SoundGroupNames) do
		getOrCreateSoundGroup(category)
	end

	configureMusicPool()

	DebugLog.Info("Audio", "Regie audio demarree", {
		MusicPoolParent = SoundService,
		MusicPoolName = AudioConfig.MusicPoolFolderName,
		Groups = soundGroupsByCategory,
	})
end

return AudioService
