local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ChapterConfig = require(Shared:WaitForChild("ChapterConfig"))
local DebugLog = require(Shared:WaitForChild("DebugLog"))

local ChapterProgressService = require(script.Parent:WaitForChild("ChapterProgressService"))
local RunMapService = require(script.Parent:WaitForChild("RunMapService"))
local RunStateService = require(script.Parent:WaitForChild("RunStateService"))

local RunSessionService = {}

local runDataStore = DataStoreService:GetDataStore(ChapterConfig.RunDataStoreName)
local profilesByUserId = {}
local worldOwnerUserId = nil
local isStarted = false
local runWorldService = nil

local function createDefaultData()
	return {
		Version = ChapterConfig.DataVersion,
		CurrentRun = nil,
		History = {},
	}
end

local function copySession(session)
	if typeof(session) ~= "table" then
		return nil
	end

	return {
		Version = ChapterConfig.DataVersion,
		RunId = tostring(session.RunId or ""),
		Seed = math.floor(tonumber(session.Seed) or 0),
		UserId = math.floor(tonumber(session.UserId) or 0),
		ChapterId = math.floor(tonumber(session.ChapterId) or 0),
		MapId = tostring(session.MapId or ""),
		LifecycleStatus = tostring(session.LifecycleStatus or "Unknown"),
		Outcome = session.Outcome and tostring(session.Outcome) or nil,
		CreatedAt = math.floor(tonumber(session.CreatedAt) or 0),
		StartedAt = session.StartedAt and math.floor(tonumber(session.StartedAt) or 0) or nil,
		EndedAt = session.EndedAt and math.floor(tonumber(session.EndedAt) or 0) or nil,
		DestroyedAt = session.DestroyedAt and math.floor(tonumber(session.DestroyedAt) or 0) or nil,
		ChapterValidated = session.ChapterValidated == true,
	}
end

local function normalizeData(rawData)
	local data = createDefaultData()

	if typeof(rawData) ~= "table" then
		return data
	end

	data.CurrentRun = copySession(rawData.CurrentRun)

	if typeof(rawData.History) == "table" then
		local firstIndex = math.max(1, #rawData.History - ChapterConfig.MaxRunHistory + 1)

		for index = firstIndex, #rawData.History do
			local session = copySession(rawData.History[index])

			if session ~= nil and session.RunId ~= "" then
				table.insert(data.History, session)
			end
		end
	end

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
			Transferring = false,
		}
		profilesByUserId[player.UserId] = profile
	end

	return profile
end

local function publishSession(player, session)
	player:SetAttribute("RunId", session and session.RunId or nil)
	player:SetAttribute("RunSeed", session and session.Seed or nil)
	player:SetAttribute("RunChapterId", session and session.ChapterId or nil)
	player:SetAttribute("RunMapId", session and session.MapId or nil)
	player:SetAttribute("RunLifecycleStatus", session and session.LifecycleStatus or "Idle")
end

local function appendHistory(data, session)
	table.insert(data.History, copySession(session))

	while #data.History > ChapterConfig.MaxRunHistory do
		table.remove(data.History, 1)
	end
end

local function saveProfile(player)
	local profile = profilesByUserId[player.UserId]

	if profile == nil or not profile.Loaded or not profile.Dirty then
		return true
	end

	if profile.SessionOnly then
		profile.Dirty = false
		return true
	end

	local snapshot = normalizeData(profile.Data)
	local success, errorMessage = pcall(function()
		runDataStore:SetAsync(getDataStoreKey(player), snapshot)
	end)

	if not success then
		DebugLog.Warn("RunSession", "Sauvegarde de session impossible", {
			Player = player.Name,
			Error = tostring(errorMessage),
		})
		return false
	end

	profile.Dirty = false
	return true
end

local function transition(player, session, lifecycleStatus)
	session.LifecycleStatus = lifecycleStatus
	local profile = getOrCreateProfile(player)
	profile.Data.CurrentRun = session
	profile.Dirty = true
	publishSession(player, session)

	DebugLog.Info("RunSession", "Transition de run", {
		Player = player.Name,
		RunId = session.RunId,
		ChapterId = session.ChapterId,
		Status = lifecycleStatus,
	})
end

local function finalizeSession(player, outcome)
	local profile = profilesByUserId[player.UserId]
	local session = profile and profile.Data.CurrentRun

	if session == nil then
		return false
	end

	session.Outcome = outcome or "Unknown"
	session.EndedAt = os.time()
	transition(player, session, "Saving")
	saveProfile(player)

	if worldOwnerUserId == player.UserId then
		if runWorldService ~= nil then
			runWorldService.Clear()
		end

		RunMapService.Destroy(session.RunId)
		worldOwnerUserId = nil
	end

	session.DestroyedAt = os.time()
	session.LifecycleStatus = "Destroyed"
	appendHistory(profile.Data, session)
	profile.Data.CurrentRun = nil
	profile.Dirty = true
	publishSession(player, nil)
	saveProfile(player)

	DebugLog.Info("RunSession", "Cycle de run termine", {
		Player = player.Name,
		RunId = session.RunId,
		Outcome = session.Outcome,
		ChapterValidated = session.ChapterValidated,
	})

	return true
end

function RunSessionService.SetupPlayer(player)
	local profile = getOrCreateProfile(player)
	local success, rawData = pcall(function()
		return runDataStore:GetAsync(getDataStoreKey(player))
	end)

	if success then
		profile.Data = normalizeData(rawData)
		profile.Loaded = true
		profile.SessionOnly = false
	elseif RunService:IsStudio() then
		profile.Data = createDefaultData()
		profile.Loaded = true
		profile.SessionOnly = true
		DebugLog.Warn("RunSession", "DataStore des runs indisponible dans Studio", {
			Player = player.Name,
			Error = tostring(rawData),
		})
	else
		profile.Loaded = false
		DebugLog.Warn("RunSession", "Chargement des runs impossible", {
			Player = player.Name,
			Error = tostring(rawData),
		})
	end

	publishSession(player, profile.Data.CurrentRun)
end

function RunSessionService.PrepareRun(player, chapterId)
	local profile = getOrCreateProfile(player)
	local chapter = ChapterConfig.GetChapter(chapterId)

	if not profile.Loaded then
		return false, "ProfileNotLoaded"
	end

	if chapter == nil then
		return false, "UnknownChapter"
	end

	if not ChapterProgressService.IsChapterUnlocked(player, chapter.Id) then
		return false, "ChapterLocked"
	end

	if profile.Data.CurrentRun ~= nil or RunStateService.IsRunActive(player) then
		return false, "RunAlreadyExists"
	end

	if worldOwnerUserId ~= nil and worldOwnerUserId ~= player.UserId then
		return false, "WorldAlreadyInUse"
	end

	local session = {
		Version = ChapterConfig.DataVersion,
		RunId = HttpService:GenerateGUID(false),
		Seed = Random.new():NextInteger(1, 2147483646),
		UserId = player.UserId,
		ChapterId = chapter.Id,
		MapId = chapter.MapTemplateName,
		LifecycleStatus = "Creating",
		CreatedAt = os.time(),
		ChapterValidated = false,
	}

	transition(player, session, "Creating")
	saveProfile(player)

	return true, session
end

function RunSessionService.GetTeleportData(player)
	local profile = profilesByUserId[player.UserId]
	local session = profile and profile.Data.CurrentRun

	if session == nil then
		return nil
	end

	return {
		runId = session.RunId,
		runSeed = session.Seed,
		chapterId = session.ChapterId,
		mapId = session.MapId,
	}
end

function RunSessionService.MarkTeleporting(player)
	getOrCreateProfile(player).Transferring = true
end

function RunSessionService.ActivatePreparedRun(player, expectedRunId, reason)
	local profile = getOrCreateProfile(player)
	local session = profile.Data.CurrentRun

	if session == nil or (expectedRunId ~= nil and session.RunId ~= expectedRunId) then
		return false, "RunSessionMissing", nil
	end

	if worldOwnerUserId ~= nil and worldOwnerUserId ~= player.UserId then
		return false, "WorldAlreadyInUse", nil
	end

	worldOwnerUserId = player.UserId
	profile.Transferring = false
	transition(player, session, "Generating")
	saveProfile(player)

	local mapGenerated, arrivalOrReason = RunMapService.Generate(session)

	if not mapGenerated then
		finalizeSession(player, tostring(arrivalOrReason))
		return false, arrivalOrReason, nil
	end

	if runWorldService == nil then
		finalizeSession(player, "WorldServiceMissing")
		return false, "WorldServiceMissing", nil
	end

	local worldGenerated, worldReason = runWorldService.Generate(session)

	if not worldGenerated then
		finalizeSession(player, tostring(worldReason))
		return false, worldReason, nil
	end

	session.StartedAt = os.time()
	transition(player, session, "Active")
	saveProfile(player)
	RunStateService.StartRun(player, reason or "RunSessionActive")

	return true, "Ok", arrivalOrReason
end

function RunSessionService.ResolveArrival(player, teleportData)
	local profile = getOrCreateProfile(player)
	local currentRun = profile.Data.CurrentRun

	if typeof(teleportData) == "table" and typeof(teleportData.runId) == "string" then
		if currentRun == nil then
			local chapter = ChapterConfig.GetChapter(teleportData.chapterId)

			local teleportSeed = math.floor(tonumber(teleportData.runSeed) or 0)

			if chapter == nil
				or teleportData.mapId ~= chapter.MapTemplateName
				or teleportSeed <= 0
				or not ChapterProgressService.IsChapterUnlocked(player, chapter.Id)
			then
				return false, "InvalidTeleportData", nil
			end

			currentRun = {
				Version = ChapterConfig.DataVersion,
				RunId = teleportData.runId,
				Seed = teleportSeed,
				UserId = player.UserId,
				ChapterId = chapter.Id,
				MapId = chapter.MapTemplateName,
				LifecycleStatus = "Creating",
				CreatedAt = os.time(),
				ChapterValidated = false,
			}
			profile.Data.CurrentRun = currentRun
			profile.Dirty = true
		end

		if currentRun.RunId ~= teleportData.runId or currentRun.UserId ~= player.UserId then
			return false, "RunIdentityMismatch", nil
		end

		return RunSessionService.ActivatePreparedRun(player, teleportData.runId, "TeleportArrival")
	end

	if currentRun ~= nil then
		finalizeSession(player, "Abandoned")
	end

	return false, "NoRunArrival", nil
end

function RunSessionService.CancelPreparedRun(player, reason)
	local profile = profilesByUserId[player.UserId]

	if profile ~= nil then
		profile.Transferring = false
	end

	return finalizeSession(player, reason or "Cancelled")
end

function RunSessionService.MarkChapterValidated(player)
	local profile = profilesByUserId[player.UserId]
	local session = profile and profile.Data.CurrentRun

	if session == nil or session.LifecycleStatus ~= "Active" then
		return false
	end

	session.ChapterValidated = true
	profile.Dirty = true
	publishSession(player, session)
	ChapterProgressService.MarkChapterCompleted(player, session.ChapterId)
	ChapterProgressService.SavePlayer(player)
	saveProfile(player)
	return true
end

function RunSessionService.GetCurrentSession(player)
	local profile = player and profilesByUserId[player.UserId]
	return profile and profile.Data.CurrentRun or nil
end

function RunSessionService.RemovePlayer(player)
	local profile = profilesByUserId[player.UserId]

	if profile ~= nil and not profile.Transferring and profile.Data.CurrentRun ~= nil then
		finalizeSession(player, "Abandoned")
	else
		saveProfile(player)
	end

	if worldOwnerUserId == player.UserId and (profile == nil or not profile.Transferring) then
		worldOwnerUserId = nil
	end

	profilesByUserId[player.UserId] = nil
end

function RunSessionService.SavePlayer(player)
	return saveProfile(player)
end

function RunSessionService.SetWorldService(service)
	runWorldService = service
end

function RunSessionService.Start()
	if isStarted then
		return
	end

	isStarted = true
	RunStateService.RunEnded:Connect(function(player, reason)
		finalizeSession(player, reason)
	end)

	RunStateService.LevelValidated:Connect(function(player)
		RunSessionService.MarkChapterValidated(player)
	end)

	DebugLog.Info("RunSession", "RunSessionService demarre", {
		DataStore = ChapterConfig.RunDataStoreName,
		HistoryLimit = ChapterConfig.MaxRunHistory,
	})
end

return RunSessionService
