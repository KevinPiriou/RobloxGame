local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DebugLog = require(Shared:WaitForChild("DebugLog"))

local CombatStateService = require(script.Parent:WaitForChild("CombatStateService"))
local MetaProgressionService = require(script.Parent:WaitForChild("MetaProgressionService"))
local RunStateService = require(script.Parent:WaitForChild("RunStateService"))

local RunAnalyticsService = {}

local runsByUserId = {}
local isStarted = false

local function copyDictionary(source)
	local copy = {}

	for key, value in pairs(source or {}) do
		copy[key] = value
	end

	return copy
end

local function createCounters()
	return {
		DamageDealt = 0,
		DamageTaken = 0,
		ShieldDamageAbsorbed = 0,
		HealingReceived = 0,
		Kills = 0,
		EliteKills = 0,
		BossKills = 0,
		KillsByEnemyId = {},
		DamageByWeaponId = {},
		RunItemsById = {},
		XpEarned = 0,
		CoinsEarned = 0,
		CoinsSpent = 0,
		PerksSelected = 0,
		MaxDifficultyPercent = 0,
		ChestsOpened = 0,
		RewardChestsOpened = 0,
		JarsBroken = 0,
		DifficultyTotemsActivated = 0,
		ShrinesActivated = {
			Perk = 0,
			EliteChallenge = 0,
			Magnet = 0,
		},
		EliteChallengesStarted = 0,
		PortalsActivated = 0,
		StartNewAchievementIds = {},
	}
end

local function getActiveRun(player)
	if player == nil then
		return nil
	end

	local run = runsByUserId[player.UserId]

	if run == nil or run.RunId == "" then
		return nil
	end

	return run
end

local function getOutcome(reason, levelValidated)
	if reason == "Death" then
		return "Defeat"
	end

	if levelValidated then
		return "Victory"
	end

	return "Abandoned"
end

local function beginRun(player)
	local runId = tostring(player:GetAttribute("RunId") or "")

	if runId == "" then
		DebugLog.Warn("RunAnalytics", "Run active sans RunId, capture ignoree", {
			Player = player.Name,
		})
		return
	end

	local _, startProgression = MetaProgressionService.RecordRunStarted(player, runId)

	runsByUserId[player.UserId] = {
		RunId = runId,
		Context = {
			ChapterId = math.floor(tonumber(player:GetAttribute("RunChapterId")) or 0),
			MapId = tostring(player:GetAttribute("RunMapId") or ""),
			Seed = math.floor(tonumber(player:GetAttribute("RunSeed")) or 0),
		},
		CreatedAt = math.floor(tonumber(player:GetAttribute("RunCreatedAt")) or os.time()),
		StartedAt = os.time(),
		StartedClock = os.clock(),
		StartedCombatTime = CombatStateService.GetTime(),
		AdminCommandsUsed = false,
		Counters = createCounters(),
	}

	if startProgression ~= nil and typeof(startProgression.NewAchievementIds) == "table" then
		for _, achievementId in ipairs(startProgression.NewAchievementIds) do
			table.insert(runsByUserId[player.UserId].Counters.StartNewAchievementIds, achievementId)
		end
	end

	DebugLog.Info("RunAnalytics", "Capture de run initialisee", {
		Player = player.Name,
		RunId = runId,
		ChapterId = player:GetAttribute("RunChapterId"),
	})
end

function RunAnalyticsService.RecordDamageDealt(player, amount, weaponId)
	local run = getActiveRun(player)
	local dealt = math.max(0, tonumber(amount) or 0)

	if run == nil or dealt <= 0 then
		return
	end

	run.Counters.DamageDealt += dealt
	local id = tostring(weaponId or "Unknown")
	run.Counters.DamageByWeaponId[id] = (run.Counters.DamageByWeaponId[id] or 0) + dealt
end

function RunAnalyticsService.RecordDamageTaken(player, amount, shieldAbsorbed)
	local run = getActiveRun(player)

	if run == nil then
		return
	end

	run.Counters.DamageTaken += math.max(0, tonumber(amount) or 0)
	run.Counters.ShieldDamageAbsorbed += math.max(0, tonumber(shieldAbsorbed) or 0)
end

function RunAnalyticsService.RecordHealing(player, amount)
	local run = getActiveRun(player)

	if run ~= nil then
		run.Counters.HealingReceived += math.max(0, tonumber(amount) or 0)
	end
end

function RunAnalyticsService.RecordMonsterKill(player, monster)
	local run = getActiveRun(player)

	if run == nil or monster == nil then
		return
	end

	run.Counters.Kills += 1

	if monster:GetAttribute("IsElite") == true then
		run.Counters.EliteKills += 1
	end

	if monster:GetAttribute("IsBoss") == true then
		run.Counters.BossKills += 1
	end

	local enemyId = tostring(monster:GetAttribute("EnemyId") or monster.Name)
	run.Counters.KillsByEnemyId[enemyId] = (run.Counters.KillsByEnemyId[enemyId] or 0) + 1
end

function RunAnalyticsService.RecordXpEarned(player, amount)
	local run = getActiveRun(player)

	if run ~= nil then
		run.Counters.XpEarned += math.max(0, math.floor(tonumber(amount) or 0))
	end
end

function RunAnalyticsService.RecordCoinsEarned(player, amount)
	local run = getActiveRun(player)

	if run ~= nil then
		run.Counters.CoinsEarned += math.max(0, math.floor(tonumber(amount) or 0))
	end
end

function RunAnalyticsService.RecordCoinsSpent(player, amount)
	local run = getActiveRun(player)

	if run ~= nil then
		run.Counters.CoinsSpent += math.max(0, math.floor(tonumber(amount) or 0))
	end
end

function RunAnalyticsService.RecordPerkSelected(player)
	local run = getActiveRun(player)

	if run ~= nil then
		run.Counters.PerksSelected += 1
	end
end

function RunAnalyticsService.RecordRunItemAdded(player, itemId, amount)
	local run = getActiveRun(player)

	if run == nil then
		return
	end

	local id = tostring(itemId or "Unknown")
	run.Counters.RunItemsById[id] = (run.Counters.RunItemsById[id] or 0)
		+ math.max(0, math.floor(tonumber(amount) or 0))
end

function RunAnalyticsService.RecordDifficultyPercent(player, percent)
	local run = getActiveRun(player)

	if run ~= nil then
		run.Counters.MaxDifficultyPercent = math.max(
			run.Counters.MaxDifficultyPercent,
			math.max(0, math.floor(tonumber(percent) or 0))
		)
	end
end

function RunAnalyticsService.RecordChestOpened(player, isRewardChest)
	local run = getActiveRun(player)

	if run == nil then
		return
	end

	run.Counters.ChestsOpened += 1

	if isRewardChest then
		run.Counters.RewardChestsOpened += 1
	end
end

function RunAnalyticsService.RecordJarBroken(player)
	local run = getActiveRun(player)

	if run ~= nil then
		run.Counters.JarsBroken += 1
	end
end

function RunAnalyticsService.RecordShrineActivated(player, shrineType)
	local run = getActiveRun(player)

	if run == nil then
		return
	end

	local normalizedType = tostring(shrineType or "")

	if run.Counters.ShrinesActivated[normalizedType] == nil then
		return
	end

	run.Counters.ShrinesActivated[normalizedType] += 1

	if normalizedType == "EliteChallenge" then
		run.Counters.EliteChallengesStarted += 1
	end
end

function RunAnalyticsService.RecordDifficultyTotemActivated(player)
	local run = getActiveRun(player)

	if run ~= nil then
		run.Counters.DifficultyTotemsActivated += 1
	end
end

function RunAnalyticsService.RecordPortalActivated(player)
	local run = getActiveRun(player)

	if run ~= nil then
		run.Counters.PortalsActivated += 1
	end
end

function RunAnalyticsService.RecordAdminCommand(player)
	local run = getActiveRun(player)

	if run ~= nil then
		run.AdminCommandsUsed = true
	end
end

function RunAnalyticsService.BuildRunResult(player, reason, snapshot)
	local run = getActiveRun(player)

	if run == nil then
		return nil
	end

	snapshot = snapshot or {}
	local now = os.time()
	local activeSeconds = math.max(0, CombatStateService.GetTime() - run.StartedCombatTime)
	local elapsedSeconds = math.max(0, os.clock() - run.StartedClock)
	local pausedSeconds = math.max(0, elapsedSeconds - activeSeconds)
	local counters = run.Counters
	local levelValidated = snapshot.LevelValidated == true

	return {
		Version = 1,
		RunId = run.RunId,
		UserId = player.UserId,
		Context = {
			ChapterId = run.Context.ChapterId,
			MapId = run.Context.MapId,
			Seed = run.Context.Seed,
		},
		Lifecycle = {
			Status = "Completed",
			Outcome = getOutcome(reason, levelValidated),
			EndReason = tostring(reason or "Unknown"),
			CreatedAt = run.CreatedAt,
			StartedAt = run.StartedAt,
			EndedAt = now,
			ActiveDurationSeconds = math.floor(activeSeconds),
			PausedDurationSeconds = math.floor(pausedSeconds),
		},
		ProgressionStats = {
			FinalLevel = math.max(1, math.floor(tonumber(snapshot.Level) or 1)),
			XpEarned = math.max(0, math.floor(tonumber(snapshot.TotalXp) or counters.XpEarned)),
			CoinsEarned = counters.CoinsEarned,
			CoinsSpent = counters.CoinsSpent,
			CoinsRemaining = math.max(0, math.floor(tonumber(snapshot.Coins) or 0)),
			PerksSelected = counters.PerksSelected,
			MaxDifficultyPercent = math.max(
				counters.MaxDifficultyPercent,
				math.max(0, math.floor(tonumber(snapshot.DifficultyPercent) or 0))
			),
		},
		CombatStats = {
			Kills = counters.Kills,
			EliteKills = counters.EliteKills,
			BossKills = counters.BossKills,
			DamageDealt = math.floor(counters.DamageDealt + 0.5),
			DamageTaken = math.floor(counters.DamageTaken + 0.5),
			ShieldDamageAbsorbed = math.floor(counters.ShieldDamageAbsorbed + 0.5),
			HealingReceived = math.floor(counters.HealingReceived + 0.5),
			KillsByEnemyId = copyDictionary(counters.KillsByEnemyId),
			DamageByWeaponId = copyDictionary(counters.DamageByWeaponId),
		},
		InteractionStats = {
			ChestsOpened = counters.ChestsOpened,
			RewardChestsOpened = counters.RewardChestsOpened,
			JarsBroken = counters.JarsBroken,
			DifficultyTotemsActivated = counters.DifficultyTotemsActivated,
			ShrinesActivated = copyDictionary(counters.ShrinesActivated),
			EliteChallengesStarted = counters.EliteChallengesStarted,
			PortalsActivated = counters.PortalsActivated,
		},
		ItemStats = {
			RunItemsById = copyDictionary(counters.RunItemsById),
		},
		FinalBuild = snapshot.FinalBuild or {},
		ChapterValidated = levelValidated,
		NewlyUnlockedChapterId = math.floor(tonumber(snapshot.NewlyUnlockedChapterId) or 0),
		StartNewAchievementIds = copyDictionary(counters.StartNewAchievementIds),
		Eligibility = {
			ProgressionEligible = not run.AdminCommandsUsed,
			LeaderboardEligible = not run.AdminCommandsUsed,
			AdminCommandsUsed = run.AdminCommandsUsed,
		},
	}
end

function RunAnalyticsService.ClearRun(player)
	if player ~= nil then
		runsByUserId[player.UserId] = nil
	end
end

function RunAnalyticsService.RemovePlayer(player)
	RunAnalyticsService.ClearRun(player)
end

function RunAnalyticsService.Start()
	if isStarted then
		return
	end

	isStarted = true

	RunStateService.RunStarted:Connect(beginRun)

	DebugLog.Info("RunAnalytics", "RunAnalyticsService demarre")
end

return RunAnalyticsService
