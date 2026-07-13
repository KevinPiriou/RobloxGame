local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DebugLog = require(Shared:WaitForChild("DebugLog"))
local MetaProgressionConfig = require(Shared:WaitForChild("MetaProgressionConfig"))

local RunStateService = require(script.Parent:WaitForChild("RunStateService"))

local MetaProgressionService = {}

local metaDataStore = DataStoreService:GetDataStore(MetaProgressionConfig.DataStoreName)
local profilesByUserId = {}
local founderAttributeConnectionsByUserId = {}
local isStarted = false

local function sanitizeInteger(value)
	return math.max(0, math.floor(tonumber(value) or 0))
end

local function createDefaultStats()
	return {
		RunsStarted = 0,
		RunsCompleted = 0,
		Victories = 0,
		Defeats = 0,
		ChaptersValidated = 0,
		Chapter1BossVictories = 0,
		TotalKills = 0,
		TotalEliteKills = 0,
		TotalBossKills = 0,
		TotalDamageDealt = 0,
		TotalDamageTaken = 0,
		TotalXpEarned = 0,
		TotalCoinsEarned = 0,
		TotalCoinsSpent = 0,
		TotalPerksSelected = 0,
		TotalChestsOpened = 0,
		TotalJarsBroken = 0,
		TotalShrinesActivated = 0,
		TotalPerkShrinesActivated = 0,
		TotalDifficultyTotemsActivated = 0,
		TotalActiveSeconds = 0,
		HighestLevel = 1,
		HighestKillsInRun = 0,
		LongestRunSeconds = 0,
	}
end

local function createDefaultData()
	return {
		Version = MetaProgressionConfig.DataVersion,
		Stats = createDefaultStats(),
		Daily = {
			DateKey = "",
			Kills = 0,
			RunsCompleted = 0,
			LongestRunSeconds = 0,
			CoinsEarned = 0,
		},
		CompletedQuestIds = {},
		DailyCompletedQuestIds = {},
		AchievementIds = {},
		ProcessedRunIds = {},
		StartedRunIds = {},
	}
end

local function getUtcDateKey()
	return os.date("!%Y-%m-%d")
end

local function normalizeBooleanMap(rawMap)
	local normalized = {}

	if typeof(rawMap) == "table" then
		for key, value in pairs(rawMap) do
			if value == true then
				normalized[tostring(key)] = true
			end
		end
	end

	return normalized
end

local function normalizeRunIdList(rawIds, limit)
	local normalized = {}

	if typeof(rawIds) ~= "table" then
		return normalized
	end

	local firstIndex = math.max(1, #rawIds - limit + 1)

	for index = firstIndex, #rawIds do
		local runId = tostring(rawIds[index] or "")

		if runId ~= "" then
			table.insert(normalized, runId)
		end
	end

	return normalized
end

local function normalizeData(rawData)
	local data = createDefaultData()

	if typeof(rawData) ~= "table" then
		return data
	end

	if typeof(rawData.Stats) == "table" then
		for key in pairs(data.Stats) do
			data.Stats[key] = sanitizeInteger(rawData.Stats[key])
		end
	end

	if typeof(rawData.Daily) == "table" then
		data.Daily.DateKey = tostring(rawData.Daily.DateKey or "")
		data.Daily.Kills = sanitizeInteger(rawData.Daily.Kills)
		data.Daily.RunsCompleted = sanitizeInteger(rawData.Daily.RunsCompleted)
		data.Daily.LongestRunSeconds = sanitizeInteger(rawData.Daily.LongestRunSeconds)
		data.Daily.CoinsEarned = sanitizeInteger(rawData.Daily.CoinsEarned)
	end

	data.CompletedQuestIds = normalizeBooleanMap(rawData.CompletedQuestIds)
	data.DailyCompletedQuestIds = normalizeBooleanMap(rawData.DailyCompletedQuestIds)
	data.AchievementIds = normalizeBooleanMap(rawData.AchievementIds)

	data.ProcessedRunIds = normalizeRunIdList(rawData.ProcessedRunIds, MetaProgressionConfig.ProcessedRunLimit)
	data.StartedRunIds = normalizeRunIdList(rawData.StartedRunIds, MetaProgressionConfig.StartedRunHistoryLimit)

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
		}
		profilesByUserId[player.UserId] = profile
	end

	return profile
end

local function ensureDailyData(data)
	local dayKey = getUtcDateKey()

	if data.Daily.DateKey == dayKey then
		return
	end

	data.Daily = {
		DateKey = dayKey,
		Kills = 0,
		RunsCompleted = 0,
		LongestRunSeconds = 0,
		CoinsEarned = 0,
	}
	data.DailyCompletedQuestIds = {}
end

local function hasProcessedRun(data, runId)
	for _, processedRunId in ipairs(data.ProcessedRunIds) do
		if processedRunId == runId then
			return true
		end
	end

	return false
end

local function rememberProcessedRun(data, runId)
	table.insert(data.ProcessedRunIds, runId)

	while #data.ProcessedRunIds > MetaProgressionConfig.ProcessedRunLimit do
		table.remove(data.ProcessedRunIds, 1)
	end
end

local function hasRunId(runIds, runId)
	for _, existingRunId in ipairs(runIds) do
		if existingRunId == runId then
			return true
		end
	end

	return false
end

local function rememberRunId(runIds, runId, limit)
	table.insert(runIds, runId)

	while #runIds > limit do
		table.remove(runIds, 1)
	end
end

local function getProgressValue(data, source)
	if source == "RunsStarted" then
		return data.Stats.RunsStarted
	elseif source == "RunsCompleted" then
		return data.Stats.RunsCompleted
	elseif source == "Chapter1BossVictories" then
		return data.Stats.Chapter1BossVictories
	elseif source == "TotalPerkShrinesActivated" then
		return data.Stats.TotalPerkShrinesActivated
	elseif source == "TotalKills" then
		return data.Stats.TotalKills
	elseif source == "TotalCoinsEarned" then
		return data.Stats.TotalCoinsEarned
	elseif source == "TotalChestsOpened" then
		return data.Stats.TotalChestsOpened
	elseif source == "HighestKillsInRun" then
		return data.Stats.HighestKillsInRun
	elseif source == "ChaptersValidated" then
		return data.Stats.ChaptersValidated
	elseif source == "LongestRunSeconds" then
		return data.Daily.LongestRunSeconds
	elseif source == "CoinsEarned" then
		return data.Daily.CoinsEarned
	elseif source == "DailyKills" then
		return data.Daily.Kills
	end

	return 0
end

local function createPublicEntries(data, definitions, completedIds)
	local entries = {}

	for _, definition in ipairs(definitions) do
		local progress = getProgressValue(data, definition.Source)
		local completed = completedIds[definition.Id] == true

		table.insert(entries, {
			Id = definition.Id,
			Label = definition.Label,
			Progress = math.min(progress, definition.Target),
			Target = definition.Target,
			Completed = completed,
		})
	end

	return entries
end

local function createPublicState(profile)
	local data = profile.Data
	ensureDailyData(data)

	return {
		Loaded = profile.Loaded,
		Stats = table.clone(data.Stats),
		Quests = createPublicEntries(data, MetaProgressionConfig.Quests, data.CompletedQuestIds),
		DailyQuests = createPublicEntries(data, MetaProgressionConfig.DailyQuests, data.DailyCompletedQuestIds),
		Achievements = createPublicEntries(data, MetaProgressionConfig.Achievements, data.AchievementIds),
	}
end

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

local getStateRemote = getOrCreateRemote("MetaProgression_GetState", "RemoteFunction")
local updateStateRemote = getOrCreateRemote("MetaProgression_Update", "RemoteEvent")

local function publishState(player, profile)
	if player.Parent == Players then
		updateStateRemote:FireClient(player, createPublicState(profile))
	end
end

local function commitProfileMutation(player, profile, mutation)
	if profile.SessionOnly then
		local result = nil
		profile.Data, result = mutation(profile.Data)
		publishState(player, profile)
		return true, result
	end

	local success, updatedData, result = pcall(function()
		local mutationResult = nil
		local savedData = metaDataStore:UpdateAsync(getDataStoreKey(player), function(rawData)
			local data = normalizeData(rawData)
			data, mutationResult = mutation(data)
			return data
		end)

		return savedData, mutationResult
	end)

	if not success then
		return false, updatedData
	end

	profile.Data = normalizeData(updatedData)
	publishState(player, profile)
	return true, result
end

local function applyResultToData(data, result)
	ensureDailyData(data)

	local progression = result.ProgressionStats or {}
	local combat = result.CombatStats or {}
	local interactions = result.InteractionStats or {}
	local lifecycle = result.Lifecycle or {}
	local stats = data.Stats
	local activeSeconds = sanitizeInteger(lifecycle.ActiveDurationSeconds)
	local kills = sanitizeInteger(combat.Kills)
	local finalLevel = math.max(1, sanitizeInteger(progression.FinalLevel))

	stats.RunsCompleted += 1
	stats.TotalKills += kills
	stats.TotalEliteKills += sanitizeInteger(combat.EliteKills)
	stats.TotalBossKills += sanitizeInteger(combat.BossKills)
	stats.TotalDamageDealt += sanitizeInteger(combat.DamageDealt)
	stats.TotalDamageTaken += sanitizeInteger(combat.DamageTaken)
	stats.TotalXpEarned += sanitizeInteger(progression.XpEarned)
	stats.TotalCoinsEarned += sanitizeInteger(progression.CoinsEarned)
	stats.TotalCoinsSpent += sanitizeInteger(progression.CoinsSpent)
	stats.TotalPerksSelected += sanitizeInteger(progression.PerksSelected)
	stats.TotalChestsOpened += sanitizeInteger(interactions.ChestsOpened)
	stats.TotalJarsBroken += sanitizeInteger(interactions.JarsBroken)
	stats.TotalDifficultyTotemsActivated += sanitizeInteger(interactions.DifficultyTotemsActivated)
	stats.TotalActiveSeconds += activeSeconds

	local shrineCount = 0

	for _, count in pairs(interactions.ShrinesActivated or {}) do
		shrineCount += sanitizeInteger(count)
	end

	stats.TotalShrinesActivated += shrineCount
	stats.TotalPerkShrinesActivated += sanitizeInteger((interactions.ShrinesActivated or {}).Perk)

	if lifecycle.Outcome == "Victory" then
		stats.Victories += 1
	elseif lifecycle.Outcome == "Defeat" then
		stats.Defeats += 1
	end

	if result.ChapterValidated == true then
		stats.ChaptersValidated += 1

		if math.floor(tonumber((result.Context or {}).ChapterId) or 0) == 1 then
			stats.Chapter1BossVictories += 1
		end
	end

	local personalBests = {}

	local function updatePersonalBest(statId, currentValue, candidateValue)
		if candidateValue > currentValue then
			table.insert(personalBests, {
				StatId = statId,
				PreviousValue = currentValue,
				NewValue = candidateValue,
			})
			return candidateValue
		end

		return currentValue
	end

	stats.HighestLevel = updatePersonalBest("HighestLevel", stats.HighestLevel, finalLevel)
	stats.HighestKillsInRun = updatePersonalBest("HighestKillsInRun", stats.HighestKillsInRun, kills)
	stats.LongestRunSeconds = updatePersonalBest("LongestRunSeconds", stats.LongestRunSeconds, activeSeconds)

	data.Daily.Kills += kills
	data.Daily.RunsCompleted += 1
	data.Daily.CoinsEarned += sanitizeInteger(progression.CoinsEarned)
	data.Daily.LongestRunSeconds = math.max(data.Daily.LongestRunSeconds, activeSeconds)

	local completedQuestIds = {}

	for _, definition in ipairs(MetaProgressionConfig.Quests) do
		if data.CompletedQuestIds[definition.Id] ~= true and getProgressValue(data, definition.Source) >= definition.Target then
			data.CompletedQuestIds[definition.Id] = true
			table.insert(completedQuestIds, definition.Id)
		end
	end

	for _, definition in ipairs(MetaProgressionConfig.DailyQuests) do
		if data.DailyCompletedQuestIds[definition.Id] ~= true and getProgressValue(data, definition.Source) >= definition.Target then
			data.DailyCompletedQuestIds[definition.Id] = true
			table.insert(completedQuestIds, definition.Id)
		end
	end

	local newAchievementIds = {}

	for _, definition in ipairs(MetaProgressionConfig.Achievements) do
		if data.AchievementIds[definition.Id] ~= true and getProgressValue(data, definition.Source) >= definition.Target then
			data.AchievementIds[definition.Id] = true
			table.insert(newAchievementIds, definition.Id)
		end
	end

	return {
		CompletedQuestIds = completedQuestIds,
		NewAchievementIds = newAchievementIds,
		PersonalBestChanges = personalBests,
	}
end

function MetaProgressionService.SetupPlayer(player)
	local profile = getOrCreateProfile(player)
	local success, rawData = pcall(function()
		return metaDataStore:GetAsync(getDataStoreKey(player))
	end)

	if success then
		profile.Data = normalizeData(rawData)
		profile.Loaded = true
		profile.SessionOnly = false
	elseif RunService:IsStudio() then
		profile.Data = createDefaultData()
		profile.Loaded = true
		profile.SessionOnly = true
		DebugLog.Warn("MetaProgression", "DataStore meta indisponible dans Studio", {
			Player = player.Name,
			Error = tostring(rawData),
		})
	else
		profile.Loaded = false
		DebugLog.Warn("MetaProgression", "Chargement profil meta impossible", {
			Player = player.Name,
			Error = tostring(rawData),
		})
	end

	publishState(player, profile)

	if founderAttributeConnectionsByUserId[player.UserId] ~= nil then
		founderAttributeConnectionsByUserId[player.UserId]:Disconnect()
	end

	founderAttributeConnectionsByUserId[player.UserId] = player:GetAttributeChangedSignal("HasFounderPass"):Connect(function()
		if player:GetAttribute("HasFounderPass") == true then
			MetaProgressionService.RecordFounderPass(player)
		end
	end)

	if player:GetAttribute("HasFounderPass") == true then
		MetaProgressionService.RecordFounderPass(player)
	end
end

function MetaProgressionService.RecordRunStarted(player, runId)
	local profile = getOrCreateProfile(player)
	local normalizedRunId = tostring(runId or "")

	if not profile.Loaded or normalizedRunId == "" then
		return false, nil
	end

	local success, result = commitProfileMutation(player, profile, function(data)
		if hasRunId(data.StartedRunIds, normalizedRunId) then
			return data, {
				Recorded = false,
				NewAchievementIds = {},
			}
		end

		data.Stats.RunsStarted += 1
		rememberRunId(data.StartedRunIds, normalizedRunId, MetaProgressionConfig.StartedRunHistoryLimit)

		local newAchievementIds = {}

		for _, definition in ipairs(MetaProgressionConfig.Achievements) do
			if definition.Source == "RunsStarted"
				and data.AchievementIds[definition.Id] ~= true
				and getProgressValue(data, definition.Source) >= definition.Target
			then
				data.AchievementIds[definition.Id] = true
				table.insert(newAchievementIds, definition.Id)
			end
		end

		return data, {
			Recorded = true,
			NewAchievementIds = newAchievementIds,
		}
	end)

	if not success then
		DebugLog.Warn("MetaProgression", "Lancement de run non enregistre", {
			Player = player.Name,
			RunId = normalizedRunId,
			Error = tostring(result),
		})
		return false
	end

	if result.Recorded == true then
		DebugLog.Info("MetaProgression", "Lancement de run enregistre", {
			Player = player.Name,
			RunId = normalizedRunId,
		})
	end

	return result.Recorded == true, result
end

function MetaProgressionService.RecordFounderPass(player)
	local profile = getOrCreateProfile(player)

	if not profile.Loaded or player:GetAttribute("HasFounderPass") ~= true then
		return false
	end

	local success, result = commitProfileMutation(player, profile, function(data)
		if data.AchievementIds.founder == true then
			return data, {
				Unlocked = false,
			}
		end

		data.AchievementIds.founder = true
		return data, {
			Unlocked = true,
		}
	end)

	if not success then
		DebugLog.Warn("MetaProgression", "Titre Fondateur non enregistre", {
			Player = player.Name,
			Error = tostring(result),
		})
		return false
	end

	if result.Unlocked == true then
		DebugLog.Info("MetaProgression", "Haut fait Fondateur debloque", {
			Player = player.Name,
		})
	end

	return result.Unlocked == true
end

function MetaProgressionService.ApplyRunResult(player, result)
	local profile = getOrCreateProfile(player)
	local runId = tostring(result and result.RunId or "")

	if not profile.Loaded then
		return false, {
			Reason = "ProfileNotLoaded",
		}
	end

	if runId == "" then
		return false, {
			Reason = "RunIdMissing",
		}
	end

	if hasProcessedRun(profile.Data, runId) then
		return true, {
			Applied = false,
			Reason = "AlreadyProcessed",
			CompletedQuestIds = {},
			NewAchievementIds = {},
			NewUnlocks = {},
			PersonalBestChanges = {},
		}
	end

	if result.Eligibility == nil or result.Eligibility.ProgressionEligible ~= true then
		return true, {
			Applied = false,
			Reason = "RunNotEligible",
			CompletedQuestIds = {},
			NewAchievementIds = {},
			NewUnlocks = {},
			PersonalBestChanges = {},
		}
	end

	local progressionResult = nil

	local function apply(data)
		if hasProcessedRun(data, runId) then
			return data, {
				Applied = false,
				Reason = "AlreadyProcessed",
				CompletedQuestIds = {},
				NewAchievementIds = {},
				NewUnlocks = {},
				PersonalBestChanges = {},
			}
		end

		local applied = applyResultToData(data, result)
		rememberProcessedRun(data, runId)

		local newUnlocks = {}
		local chapterId = sanitizeInteger(result.NewlyUnlockedChapterId)

		if chapterId > 0 then
			table.insert(newUnlocks, {
				Type = "Chapter",
				Id = chapterId,
			})
		end

		return data, {
			Applied = true,
			Reason = "Applied",
			CompletedQuestIds = applied.CompletedQuestIds,
			NewAchievementIds = applied.NewAchievementIds,
			NewUnlocks = newUnlocks,
			PersonalBestChanges = applied.PersonalBestChanges,
		}
	end

	if profile.SessionOnly then
		profile.Data, progressionResult = apply(profile.Data)
	else
		local success, updatedData, appliedResult = pcall(function()
			local resultFromUpdate = nil
			local savedData = metaDataStore:UpdateAsync(getDataStoreKey(player), function(rawData)
				local data = normalizeData(rawData)
				data, resultFromUpdate = apply(data)
				return data
			end)

			return savedData, resultFromUpdate
		end)

		if not success then
			DebugLog.Warn("MetaProgression", "Application resultat run impossible", {
				Player = player.Name,
				RunId = runId,
				Error = tostring(updatedData),
			})
			return false, {
				Reason = "DataStoreFailure",
			}
		end

		profile.Data = normalizeData(updatedData)
		progressionResult = appliedResult
	end

	publishState(player, profile)

	DebugLog.Info("MetaProgression", "Resultat de run applique", {
		Player = player.Name,
		RunId = runId,
		Applied = progressionResult.Applied,
		Reason = progressionResult.Reason,
	})

	return true, progressionResult
end

function MetaProgressionService.ReconcileRunHistory(player, history)
	local profile = getOrCreateProfile(player)

	if not profile.Loaded or typeof(history) ~= "table" then
		return 0
	end

	local appliedCount = 0

	for _, session in ipairs(history) do
		local result = session and session.ResultSummary

		if typeof(result) == "table" and result.Version == 1 and tostring(result.RunId or "") ~= "" then
			local applied, progression = MetaProgressionService.ApplyRunResult(player, result)

			if applied and progression.Applied == true then
				appliedCount += 1
			end
		end
	end

	if appliedCount > 0 then
		DebugLog.Info("MetaProgression", "Historique de run reconcilie", {
			Player = player.Name,
			AppliedCount = appliedCount,
		})
	end

	return appliedCount
end

function MetaProgressionService.GetPublicState(player)
	local profile = getOrCreateProfile(player)
	return createPublicState(profile)
end

function MetaProgressionService.SavePlayer(player)
	return true
end

function MetaProgressionService.RemovePlayer(player)
	if founderAttributeConnectionsByUserId[player.UserId] ~= nil then
		founderAttributeConnectionsByUserId[player.UserId]:Disconnect()
		founderAttributeConnectionsByUserId[player.UserId] = nil
	end

	profilesByUserId[player.UserId] = nil
end

function MetaProgressionService.Start()
	if isStarted then
		return
	end

	isStarted = true
	getStateRemote.OnServerInvoke = function(player)
		return MetaProgressionService.GetPublicState(player)
	end
	DebugLog.Info("MetaProgression", "MetaProgressionService demarre", {
		DataStore = MetaProgressionConfig.DataStoreName,
	})
end

return MetaProgressionService
