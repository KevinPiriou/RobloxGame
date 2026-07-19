local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ChapterConfig = require(Shared:WaitForChild("ChapterConfig"))
local DebugLog = require(Shared:WaitForChild("DebugLog"))

local ChapterProgressService = require(script.Parent:WaitForChild("ChapterProgressService"))
local ProceduralMapService = require(script.Parent:WaitForChild("ProceduralMapService"))
local RunMapService = require(script.Parent:WaitForChild("RunMapService"))
local RunLoadingService = require(script.Parent:WaitForChild("RunLoadingService"))
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

local function copyCounterDictionary(rawDictionary)
	local copied = {}

	if typeof(rawDictionary) ~= "table" then
		return copied
	end

	for key, value in pairs(rawDictionary) do
		if typeof(key) == "string" then
			copied[key] = math.max(0, math.floor(tonumber(value) or 0))
		end
	end

	return copied
end

local function copyNumericDictionary(rawDictionary)
	local copied = {}

	if typeof(rawDictionary) ~= "table" then
		return copied
	end

	for key, value in pairs(rawDictionary) do
		local numberValue = tonumber(value)

		if typeof(key) == "string" and numberValue ~= nil and numberValue == numberValue then
			copied[key] = numberValue
		end
	end

	return copied
end

local function copyPerkStacks(rawPerks)
	local copied = {}

	if typeof(rawPerks) ~= "table" then
		return copied
	end

	for _, perk in ipairs(rawPerks) do
		if typeof(perk) == "table" then
			local perkId = tostring(perk.Id or "")

			if perkId ~= "" then
				table.insert(copied, {
					Id = perkId,
					Stacks = math.max(0, math.floor(tonumber(perk.Stacks) or 0)),
				})
			end
		end
	end

	return copied
end

-- Cette archive ne contient que des primitives DataStore. Le recapitulatif UI peut contenir Color3 et icones.
local function copyPersistentResultSummary(result)
	if typeof(result) ~= "table" then
		return nil
	end

	local context = if typeof(result.Context) == "table" then result.Context else {}
	local lifecycle = if typeof(result.Lifecycle) == "table" then result.Lifecycle else {}
	local progression = if typeof(result.ProgressionStats) == "table" then result.ProgressionStats else {}
	local combat = if typeof(result.CombatStats) == "table" then result.CombatStats else {}
	local interactions = if typeof(result.InteractionStats) == "table" then result.InteractionStats else {}
	local items = if typeof(result.ItemStats) == "table" then result.ItemStats else {}
	local build = if typeof(result.FinalBuild) == "table" then result.FinalBuild else {}
	local eligibility = if typeof(result.Eligibility) == "table" then result.Eligibility else {}

	return {
		Version = math.max(1, math.floor(tonumber(result.Version) or 1)),
		RunId = tostring(result.RunId or ""),
		UserId = math.max(0, math.floor(tonumber(result.UserId) or 0)),
		Context = {
			ChapterId = math.max(0, math.floor(tonumber(context.ChapterId) or 0)),
			MapId = tostring(context.MapId or ""),
			Seed = math.max(0, math.floor(tonumber(context.Seed) or 0)),
		},
		Lifecycle = {
			Status = tostring(lifecycle.Status or "Completed"),
			Outcome = tostring(lifecycle.Outcome or "Unknown"),
			EndReason = tostring(lifecycle.EndReason or "Unknown"),
			CreatedAt = math.max(0, math.floor(tonumber(lifecycle.CreatedAt) or 0)),
			StartedAt = math.max(0, math.floor(tonumber(lifecycle.StartedAt) or 0)),
			EndedAt = math.max(0, math.floor(tonumber(lifecycle.EndedAt) or 0)),
			ActiveDurationSeconds = math.max(0, math.floor(tonumber(lifecycle.ActiveDurationSeconds) or 0)),
			PausedDurationSeconds = math.max(0, math.floor(tonumber(lifecycle.PausedDurationSeconds) or 0)),
		},
		ProgressionStats = {
			FinalLevel = math.max(1, math.floor(tonumber(progression.FinalLevel) or 1)),
			XpEarned = math.max(0, math.floor(tonumber(progression.XpEarned) or 0)),
			CoinsEarned = math.max(0, math.floor(tonumber(progression.CoinsEarned) or 0)),
			CoinsSpent = math.max(0, math.floor(tonumber(progression.CoinsSpent) or 0)),
			CoinsRemaining = math.max(0, math.floor(tonumber(progression.CoinsRemaining) or 0)),
			PerksSelected = math.max(0, math.floor(tonumber(progression.PerksSelected) or 0)),
			MaxDifficultyPercent = math.max(0, math.floor(tonumber(progression.MaxDifficultyPercent) or 0)),
			RunScore = math.max(0, math.floor(tonumber(progression.RunScore) or 0)),
		},
		CombatStats = {
			Kills = math.max(0, math.floor(tonumber(combat.Kills) or 0)),
			EliteKills = math.max(0, math.floor(tonumber(combat.EliteKills) or 0)),
			BossKills = math.max(0, math.floor(tonumber(combat.BossKills) or 0)),
			DamageDealt = math.max(0, math.floor(tonumber(combat.DamageDealt) or 0)),
			DamageTaken = math.max(0, math.floor(tonumber(combat.DamageTaken) or 0)),
			ShieldDamageAbsorbed = math.max(0, math.floor(tonumber(combat.ShieldDamageAbsorbed) or 0)),
			HealingReceived = math.max(0, math.floor(tonumber(combat.HealingReceived) or 0)),
			KillsByEnemyId = copyCounterDictionary(combat.KillsByEnemyId),
			DamageByWeaponId = copyCounterDictionary(combat.DamageByWeaponId),
		},
		InteractionStats = {
			ChestsOpened = math.max(0, math.floor(tonumber(interactions.ChestsOpened) or 0)),
			RewardChestsOpened = math.max(0, math.floor(tonumber(interactions.RewardChestsOpened) or 0)),
			JarsBroken = math.max(0, math.floor(tonumber(interactions.JarsBroken) or 0)),
			DifficultyTotemsActivated = math.max(0, math.floor(tonumber(interactions.DifficultyTotemsActivated) or 0)),
			ShrinesActivated = copyCounterDictionary(interactions.ShrinesActivated),
			EliteChallengesStarted = math.max(0, math.floor(tonumber(interactions.EliteChallengesStarted) or 0)),
			PortalsActivated = math.max(0, math.floor(tonumber(interactions.PortalsActivated) or 0)),
		},
		ItemStats = {
			RunItemsById = copyCounterDictionary(items.RunItemsById),
		},
		FinalBuild = {
			WeaponId = tostring(build.WeaponId or ""),
			Perks = copyPerkStacks(build.Perks),
			Stats = copyNumericDictionary(build.Stats),
		},
		ChapterValidated = result.ChapterValidated == true,
		NewlyUnlockedChapterId = math.max(0, math.floor(tonumber(result.NewlyUnlockedChapterId) or 0)),
		Eligibility = {
			ProgressionEligible = eligibility.ProgressionEligible ~= false,
			LeaderboardEligible = eligibility.LeaderboardEligible ~= false,
			AdminCommandsUsed = eligibility.AdminCommandsUsed == true,
		},
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
		EndReason = session.EndReason and tostring(session.EndReason) or nil,
		CreatedAt = math.floor(tonumber(session.CreatedAt) or 0),
		StartedAt = session.StartedAt and math.floor(tonumber(session.StartedAt) or 0) or nil,
		EndedAt = session.EndedAt and math.floor(tonumber(session.EndedAt) or 0) or nil,
		DestroyedAt = session.DestroyedAt and math.floor(tonumber(session.DestroyedAt) or 0) or nil,
		ChapterValidated = session.ChapterValidated == true,
		NewlyUnlockedChapterId = math.floor(tonumber(session.NewlyUnlockedChapterId) or 0),
		ResultSummary = copyPersistentResultSummary(session.ResultSummary),
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
	player:SetAttribute("RunCreatedAt", session and session.CreatedAt or nil)
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

local function finalizeSession(player, outcome, resultSummary)
	local profile = profilesByUserId[player.UserId]
	local session = profile and profile.Data.CurrentRun

	if session == nil then
		return false
	end

	local cleanupFailures = {}

	-- La persistance d'une run ne doit jamais rester bloquee par le nettoyage d'un sous-systeme runtime.
	local function cleanupStep(name, callback)
		local success, errorMessage = pcall(callback)

		if not success then
			table.insert(cleanupFailures, {
				Step = name,
				Error = tostring(errorMessage),
			})
		end
	end

	cleanupStep("RunLoading", function()
		RunLoadingService.Cancel(player, outcome)
	end)

	session.Outcome = outcome or "Unknown"
	session.EndReason = outcome or "Unknown"
	session.ResultSummary = copyPersistentResultSummary(resultSummary)
	session.EndedAt = os.time()
	transition(player, session, "Saving")
	saveProfile(player)

	if worldOwnerUserId == player.UserId then
		cleanupStep("RunWorld", function()
			if runWorldService ~= nil then
				runWorldService.Clear()
			end
		end)

		cleanupStep("RunMap", function()
			RunMapService.Destroy(session.RunId)
		end)
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
		CleanupFailureCount = #cleanupFailures,
	})

	if #cleanupFailures > 0 then
		DebugLog.Warn("RunSession", "Nettoyage runtime partiellement en erreur, session liberee", {
			Player = player.Name,
			RunId = session.RunId,
			Failures = cleanupFailures,
		})
	end

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
	RunLoadingService.Begin(player)
	RunLoadingService.Update(player, "Map")

	local mapGenerated, arrivalOrReason = RunMapService.Generate(session)

	if not mapGenerated then
		finalizeSession(player, tostring(arrivalOrReason))
		return false, arrivalOrReason, nil
	end

	local terrainGenerated, terrainReason = ProceduralMapService.Generate(
		session,
		RunMapService.GetActiveMap(),
		arrivalOrReason,
		function(stage, detail)
			RunLoadingService.Update(player, stage, detail)
		end
	)

	if not terrainGenerated then
		finalizeSession(player, tostring(terrainReason))
		return false, terrainReason, nil
	end

	if runWorldService == nil then
		finalizeSession(player, "WorldServiceMissing")
		return false, "WorldServiceMissing", nil
	end

	local worldGenerated, worldReason = runWorldService.Generate(session, function(stage, detail)
		RunLoadingService.Update(player, stage, detail)
	end)

	if not worldGenerated then
		finalizeSession(player, tostring(worldReason))
		return false, worldReason, nil
	end

	transition(player, session, "Ready")
	saveProfile(player)

	return true, "Ok", arrivalOrReason
end

function RunSessionService.StartGeneratedRun(player, expectedRunId, reason)
	local profile = getOrCreateProfile(player)
	local session = profile.Data.CurrentRun

	if session == nil or (expectedRunId ~= nil and session.RunId ~= expectedRunId) then
		return false, "RunSessionMissing"
	end

	if session.LifecycleStatus ~= "Ready" then
		return false, "RunNotReady"
	end

	session.StartedAt = os.time()
	transition(player, session, "Active")
	saveProfile(player)

	if not RunStateService.StartRun(player, reason or "RunSessionActive") then
		finalizeSession(player, "RunStateRejected")
		return false, "RunStateRejected"
	end

	RunLoadingService.Complete(player)
	return true, "Ok"
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
	local marked, progression = ChapterProgressService.MarkChapterCompleted(player, session.ChapterId)

	if marked and progression ~= nil then
		session.NewlyUnlockedChapterId = progression.NewlyUnlockedChapterId
	end
	ChapterProgressService.SavePlayer(player)
	saveProfile(player)
	return true
end

function RunSessionService.GetCurrentSession(player)
	local profile = player and profilesByUserId[player.UserId]
	return profile and profile.Data.CurrentRun or nil
end

function RunSessionService.GetHistory(player)
	local profile = player and profilesByUserId[player.UserId]

	if profile == nil then
		return {}
	end

	local history = {}

	for _, session in ipairs(profile.Data.History) do
		table.insert(history, copySession(session))
	end

	return history
end

function RunSessionService.CompleteRun(player, endReason, resultSummary)
	return finalizeSession(player, endReason, resultSummary)
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
	RunStateService.LevelValidated:Connect(function(player)
		RunSessionService.MarkChapterValidated(player)
	end)

	DebugLog.Info("RunSession", "RunSessionService demarre", {
		DataStore = ChapterConfig.RunDataStoreName,
		HistoryLimit = ChapterConfig.MaxRunHistory,
	})
end

return RunSessionService
