local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BossConfig = require(Shared:WaitForChild("BossConfig"))
local DebugLog = require(Shared:WaitForChild("DebugLog"))

local ChestService = require(script.Parent:WaitForChild("ChestService"))
local CoinService = require(script.Parent:WaitForChild("CoinService"))
local CombatStateService = require(script.Parent:WaitForChild("CombatStateService"))
local MonsterService = require(script.Parent:WaitForChild("MonsterService"))
local PerkService = require(script.Parent:WaitForChild("PerkService"))
local MetaProgressionService = require(script.Parent:WaitForChild("MetaProgressionService"))
local RunAnalyticsService = require(script.Parent:WaitForChild("RunAnalyticsService"))
local RunSessionService = require(script.Parent:WaitForChild("RunSessionService"))
local RunStateService = require(script.Parent:WaitForChild("RunStateService"))
local RunTeleportService = require(script.Parent:WaitForChild("RunTeleportService"))
local RunItemService = require(script.Parent:WaitForChild("RunItemService"))
local XpService = require(script.Parent:WaitForChild("XpService"))

local RunEndService = {}

local statesByUserId = {}
local pendingSummariesByUserId = {}
local characterConnectionsByUserId = {}
local isStarted = false

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

local summaryRemote = getOrCreateRemote(BossConfig.ResultRemoteName)
local returnToLobbyRemote = getOrCreateRemote(BossConfig.ReturnToLobbyRemoteName)

local function getOrCreateState(player)
	local state = statesByUserId[player.UserId]

	if state == nil then
		state = {
			StartedAt = nil,
			LevelValidated = false,
			RunId = nil,
			ChapterId = nil,
		}
		statesByUserId[player.UserId] = state
	end

	return state
end

local function resetRunState(player)
	XpService.ClearRunGems()
	CoinService.ClearRunCoins()
	XpService.ResetRun(player)
	CoinService.ResetRun(player)
	PerkService.ResetRun(player)
	RunItemService.ResetRun(player)
	ChestService.ResetRun(player)
	MonsterService.ResetRunStats(player)
end

local function buildSummary(player, reason)
	local state = getOrCreateState(player)
	local xpStats = XpService.GetRunStats(player)
	local session = RunSessionService.GetCurrentSession(player)
	local finalBuild = PerkService.GetRunBuild(player)
	finalBuild.RunItems = RunItemService.GetRunItems(player)
	local snapshot = {
		LevelValidated = state.LevelValidated == true,
		Level = xpStats.Level,
		TotalXp = xpStats.TotalXp,
		Coins = CoinService.GetCoins(player),
		FinalBuild = finalBuild,
		RunItems = RunItemService.GetRunItems(player),
		NewlyUnlockedChapterId = session and session.NewlyUnlockedChapterId or 0,
	}
	local runResult = RunAnalyticsService.BuildRunResult(player, reason, snapshot)
	local progressionResult = {
		Applied = false,
		Reason = "RunResultMissing",
		CompletedQuestIds = {},
		NewAchievementIds = {},
		NewUnlocks = {},
		PersonalBestChanges = {},
	}

	if runResult ~= nil then
		local applied, result = MetaProgressionService.ApplyRunResult(player, runResult)

		if applied then
			progressionResult = result
		else
			progressionResult.Reason = result and result.Reason or "ProgressionSaveFailed"
		end

		for _, achievementId in ipairs(runResult.StartNewAchievementIds or {}) do
			table.insert(progressionResult.NewAchievementIds, achievementId)
		end

		runResult.ProgressionResult = progressionResult
	end

	local combatStats = if runResult ~= nil then runResult.CombatStats else {}
	local interactionStats = if runResult ~= nil then runResult.InteractionStats else {}
	local progressionStats = if runResult ~= nil then runResult.ProgressionStats else {}
	local lifecycle = if runResult ~= nil then runResult.Lifecycle else {}

	return {
		Reason = reason,
		RunId = state.RunId,
		ChapterId = state.ChapterId,
		LevelValidated = state.LevelValidated == true,
		Kills = combatStats.Kills or MonsterService.GetKills(player),
		EliteKills = combatStats.EliteKills or 0,
		BossKills = combatStats.BossKills or 0,
		DamageDealt = combatStats.DamageDealt or 0,
		DamageTaken = combatStats.DamageTaken or 0,
		Coins = CoinService.GetCoins(player),
		CoinsEarned = progressionStats.CoinsEarned or 0,
		CoinsSpent = progressionStats.CoinsSpent or 0,
		Level = xpStats.Level,
		TotalXp = xpStats.TotalXp,
		PerkCount = PerkService.GetRunPerkCount(player),
		RunItems = RunItemService.GetRunItems(player),
		ChestsOpened = interactionStats.ChestsOpened or 0,
		JarsBroken = interactionStats.JarsBroken or 0,
		SurvivalSeconds = lifecycle.ActiveDurationSeconds
			or math.max(0, CombatStateService.GetTime() - (state.StartedAt or CombatStateService.GetTime())),
		Progression = progressionResult,
		ProgressionEligible = runResult ~= nil and runResult.Eligibility.ProgressionEligible == true,
		Outcome = lifecycle.Outcome,
		NewlyUnlockedChapterId = runResult and runResult.NewlyUnlockedChapterId or 0,
		RunResult = runResult,
	}
end

local function showSummary(player, payload)
	if player.Parent ~= Players then
		return
	end

	summaryRemote:FireClient(player, payload)
	DebugLog.Info("RunEnd", "Resultat de run envoye", {
		Player = player.Name,
		Reason = payload.Reason,
		LevelValidated = payload.LevelValidated,
		Kills = payload.Kills,
		Coins = payload.Coins,
	})
end

function RunEndService.MarkLevelValidated(player)
	if player == nil then
		return
	end

	local state = getOrCreateState(player)
	state.LevelValidated = true
	player:SetAttribute("RunLevelValidated", true)
	RunStateService.NotifyLevelValidated(player)

	DebugLog.Info("RunEnd", "Niveau valide pour la run", {
		Player = player.Name,
	})
end

function RunEndService.IsLevelValidated(player)
	local state = statesByUserId[player.UserId]

	return state ~= nil and state.LevelValidated == true
end

function RunEndService.SetupPlayer(player)
	getOrCreateState(player)

	if characterConnectionsByUserId[player.UserId] ~= nil then
		characterConnectionsByUserId[player.UserId]:Disconnect()
	end

	characterConnectionsByUserId[player.UserId] = player.CharacterAdded:Connect(function()
		local payload = pendingSummariesByUserId[player.UserId]

		if payload == nil then
			return
		end

		task.delay(0.45, function()
			if pendingSummariesByUserId[player.UserId] == payload then
				pendingSummariesByUserId[player.UserId] = nil
				showSummary(player, payload)
			end
		end)
	end)
end

function RunEndService.RemovePlayer(player)
	pendingSummariesByUserId[player.UserId] = nil
	statesByUserId[player.UserId] = nil

	if characterConnectionsByUserId[player.UserId] ~= nil then
		characterConnectionsByUserId[player.UserId]:Disconnect()
		characterConnectionsByUserId[player.UserId] = nil
	end
end

function RunEndService.Start()
	if isStarted then
		return
	end

	isStarted = true

	RunStateService.RunStarted:Connect(function(player, reason)
		local state = getOrCreateState(player)
		state.StartedAt = CombatStateService.GetTime()
		state.LevelValidated = false
		state.RunId = player:GetAttribute("RunId")
		state.ChapterId = player:GetAttribute("RunChapterId")
		player:SetAttribute("RunLevelValidated", false)
		pendingSummariesByUserId[player.UserId] = nil
		resetRunState(player)

		DebugLog.Info("RunEnd", "Etat de run initialise", {
			Player = player.Name,
			Reason = reason,
		})
	end)

	RunStateService.RunEnded:Connect(function(player, reason)
		local summary = buildSummary(player, reason)
		local state = getOrCreateState(player)
		RunSessionService.CompleteRun(player, reason, summary.RunResult)
		RunAnalyticsService.ClearRun(player)
		summary.RunResult = nil

		resetRunState(player)
		state.StartedAt = nil
		state.LevelValidated = false
		state.RunId = nil
		state.ChapterId = nil
		player:SetAttribute("RunLevelValidated", false)

		if reason == "Death" and RunTeleportService.ReturnToLobby(player, summary) then
			return
		end

		pendingSummariesByUserId[player.UserId] = summary
		player:LoadCharacter()

		DebugLog.Info("RunEnd", "Etat de run reinitialise", {
			Player = player.Name,
			Reason = reason,
			LevelValidated = summary.LevelValidated,
		})
	end)

	returnToLobbyRemote.OnServerEvent:Connect(function(player)
		if RunStateService.IsRunActive(player) then
			return
		end

		pendingSummariesByUserId[player.UserId] = nil
		summaryRemote:FireClient(player, {
			Visible = false,
		})
		if not RunTeleportService.ReturnToLobby(player) then
			player:LoadCharacter()
		end
	end)

	DebugLog.Info("RunEnd", "RunEndService demarre")
end

return RunEndService
