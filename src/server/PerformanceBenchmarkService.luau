local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DebugLog = require(Shared:WaitForChild("DebugLog"))
local PerformanceBaselineConfig = require(Shared:WaitForChild("PerformanceBaselineConfig"))

local CoinService = require(script.Parent:WaitForChild("CoinService"))
local MonsterService = require(script.Parent:WaitForChild("MonsterService"))
local PerformanceTelemetryService = require(script.Parent:WaitForChild("PerformanceTelemetryService"))
local RunMapService = require(script.Parent:WaitForChild("RunMapService"))
local RunSessionService = require(script.Parent:WaitForChild("RunSessionService"))
local RunStateService = require(script.Parent:WaitForChild("RunStateService"))
local TemplateService = require(script.Parent:WaitForChild("TemplateService"))
local WeaponService = require(script.Parent:WaitForChild("WeaponService"))
local WorldSpawnService = require(script.Parent:WaitForChild("WorldSpawnService"))
local XpService = require(script.Parent:WaitForChild("XpService"))

local PerformanceBenchmarkService = {}

local isStarted = false
local activeBenchmark = nil
local latestReport = nil
local clientSamplesByMetric = {}
local clientSummary = nil
local serverSampleElapsed = 0

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

local clientSampleRemote = getOrCreateRemote(PerformanceBaselineConfig.ClientSampleRemoteName)
local statusRemote = getOrCreateRemote(PerformanceBaselineConfig.StatusRemoteName)

local function readNumber(reader)
	local success, value = pcall(reader)

	if success and typeof(value) == "number" then
		return value
	end

	return nil
end

local function readMemoryTag(tagName)
	return readNumber(function()
		local tag = Enum.DeveloperMemoryTag[tagName]

		if tag == nil then
			error("Tag memoire indisponible")
		end

		return Stats:GetMemoryUsageMbForTag(tag)
	end)
end

local function countRuntimeDescendants()
	local folders = {
		TemplateService.GetCombatRuntimeFolder(),
		TemplateService.GetShrinesRuntimeFolder(),
		TemplateService.GetPortalsRuntimeFolder(),
		TemplateService.GetChestsRuntimeFolder(),
		TemplateService.GetJarsRuntimeFolder(),
		TemplateService.GetTotemsRuntimeFolder(),
		TemplateService.GetMapRuntimeFolder(),
	}
	local count = 0

	for _, folder in ipairs(folders) do
		if folder ~= nil and folder.Parent ~= nil then
			count += #folder:GetDescendants()
		end
	end

	return count
end

local function countRemoteTopology()
	local events = 0
	local functions = 0

	for _, descendant in ipairs(ReplicatedStorage:GetDescendants()) do
		if descendant:IsA("RemoteEvent") then
			events += 1
		elseif descendant:IsA("RemoteFunction") then
			functions += 1
		end
	end

	return events, functions
end

local function getBenchmarkInstances()
	local root = Workspace:FindFirstChild(PerformanceBaselineConfig.BenchmarkFolderName)

	if root == nil then
		return nil, nil, nil, nil
	end

	local arena = root:FindFirstChild(PerformanceBaselineConfig.ArenaName)
	local references = root:FindFirstChild(PerformanceBaselineConfig.ReferencePointsName)
	local playerStart = references and references:FindFirstChild(PerformanceBaselineConfig.PlayerStartName)
	local simulationCenter = references and references:FindFirstChild(PerformanceBaselineConfig.SimulationCenterName)

	if arena == nil or not arena:IsA("Model") or playerStart == nil or not playerStart:IsA("BasePart")
		or simulationCenter == nil or not simulationCenter:IsA("BasePart")
	then
		return nil, nil, nil, nil
	end

	return root, arena, playerStart, simulationCenter
end

local function getCharacterRoot(player)
	local character = player.Character
	return if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
end

local function applyArenaSurfaceState(root, arena, isActive)
	local floor = arena:FindFirstChild("Floor")

	if floor == nil or not floor:IsA("BasePart") then
		return nil
	end

	if isActive then
		local state = {
			RootIgnore = root:GetAttribute("MegaRobloxIgnoreAsSpawnSurface"),
			ArenaIgnore = arena:GetAttribute("MegaRobloxIgnoreAsSpawnSurface"),
			FloorIgnore = floor:GetAttribute("MegaRobloxIgnoreAsSpawnSurface"),
			FloorCanQuery = floor.CanQuery,
		}
		root:SetAttribute("MegaRobloxIgnoreAsSpawnSurface", false)
		arena:SetAttribute("MegaRobloxIgnoreAsSpawnSurface", false)
		floor:SetAttribute("MegaRobloxIgnoreAsSpawnSurface", false)
		floor.CanQuery = true
		return state
	end

	return nil
end

local function restoreArenaSurfaceState(root, arena, state)
	if state == nil then
		return
	end

	local floor = arena:FindFirstChild("Floor")

	root:SetAttribute("MegaRobloxIgnoreAsSpawnSurface", state.RootIgnore)
	arena:SetAttribute("MegaRobloxIgnoreAsSpawnSurface", state.ArenaIgnore)

	if floor ~= nil and floor:IsA("BasePart") then
		floor:SetAttribute("MegaRobloxIgnoreAsSpawnSurface", state.FloorIgnore)
		floor.CanQuery = state.FloorCanQuery == true
	end
end

local function publishStatus(benchmark, phase, extra)
	if benchmark == nil or benchmark.Owner.Parent ~= Players then
		return
	end

	local payload = {
		Active = phase ~= "Completed" and phase ~= "Idle",
		BenchmarkId = benchmark.Id,
		ScenarioId = benchmark.Scenario.Id,
		ScenarioLabel = benchmark.Scenario.Label,
		Phase = phase,
		ElapsedSeconds = os.clock() - benchmark.StartedAt,
		WarmupSeconds = PerformanceBaselineConfig.WarmupSeconds,
		MeasurementSeconds = PerformanceBaselineConfig.MeasurementSeconds,
	}

	for key, value in pairs(extra or {}) do
		payload[key] = value
	end

	statusRemote:FireClient(benchmark.Owner, payload)
end

local function recordServerSample()
	if activeBenchmark == nil or activeBenchmark.Phase ~= "Measuring" then
		return
	end

	local monsterSnapshot = MonsterService.GetPerformanceSnapshot()
	local weaponSnapshot = WeaponService.GetPerformanceSnapshot()
	local xpSnapshot = XpService.GetPerformanceSnapshot()
	local coinSnapshot = CoinService.GetPerformanceSnapshot()

	PerformanceTelemetryService.Record("Server.Memory.TotalMb", readNumber(function()
		return Stats:GetTotalMemoryUsageMb()
	end) or -1)
	PerformanceTelemetryService.Record("Server.Memory.InstancesMb", readMemoryTag("Instances") or -1)
	PerformanceTelemetryService.Record("Server.Memory.LuaHeapMb", readMemoryTag("LuaHeap") or -1)
	PerformanceTelemetryService.Record("Server.Memory.GraphicsTextureMb", readMemoryTag("GraphicsTexture") or -1)
	PerformanceTelemetryService.Record("Server.Memory.SoundsMb", readMemoryTag("Sounds") or -1)
	PerformanceTelemetryService.Record("Server.Memory.PhysicsCollisionMb", readMemoryTag("PhysicsCollision") or -1)
	PerformanceTelemetryService.Record("Server.Instances.Runtime", countRuntimeDescendants())
	PerformanceTelemetryService.Record("Server.Instances.Total", readNumber(function()
		return Stats.InstanceCount
	end) or -1)
	PerformanceTelemetryService.Record("Server.Monsters.Active", monsterSnapshot.Active)
	PerformanceTelemetryService.Record("Server.Monsters.Pool", monsterSnapshot.Pool)
	PerformanceTelemetryService.Record("Server.Projectiles.Active", weaponSnapshot.Active)
	PerformanceTelemetryService.Record("Server.Projectiles.Pool", weaponSnapshot.Pool)
	PerformanceTelemetryService.Record("Server.Xp.Tracked", xpSnapshot.Tracked)
	PerformanceTelemetryService.Record("Server.Xp.Pool", xpSnapshot.Pool)
	PerformanceTelemetryService.Record("Server.Coins.Tracked", coinSnapshot.Tracked)
	PerformanceTelemetryService.Record("Server.Coins.Pool", coinSnapshot.Pool)
	PerformanceTelemetryService.Record("Server.Remotes.Events", activeBenchmark.RemoteEvents)
	PerformanceTelemetryService.Record("Server.Remotes.Functions", activeBenchmark.RemoteFunctions)
end

local function getCircularPosition(center, index, total, radius)
	local angle = ((index - 1) / math.max(1, total)) * math.pi * 2
	return center + Vector3.new(math.cos(angle) * radius, 1.5, math.sin(angle) * radius)
end

local function spawnCollectibles(benchmark)
	local center = benchmark.SimulationCenter.Position

	for index = 1, benchmark.Scenario.XpGemCount or 0 do
		XpService.SpawnXpGem(getCircularPosition(center, index, benchmark.Scenario.XpGemCount, 42), 1)
	end

	for index = 1, benchmark.Scenario.CoinCount or 0 do
		CoinService.SpawnCoin(getCircularPosition(center + Vector3.new(0, 0, -88), index, benchmark.Scenario.CoinCount, 42), 1)
	end
end

local function restoreRunContext(benchmark)
	local originalMap = benchmark.OriginalMap

	if originalMap ~= nil and originalMap.Parent ~= nil then
		local center = originalMap:GetBoundingBox().Position
		WorldSpawnService.SetRunContext(originalMap, benchmark.Session.Seed, center)
	else
		WorldSpawnService.ClearRunContext(benchmark.Arena)
	end
end

local function cleanupBenchmark(benchmark)
	MonsterService.SetBenchmarkMode(false)
	MonsterService.SetBenchmarkSeed(nil)
	WeaponService.ClearProjectilesForBenchmark()
	MonsterService.ClearAllMonsters("PerformanceBaseline")
	XpService.ClearRunGems()
	CoinService.ClearRunCoins()
	restoreArenaSurfaceState(benchmark.BenchmarkRoot, benchmark.Arena, benchmark.ArenaSurfaceState)
	restoreRunContext(benchmark)

	local root = getCharacterRoot(benchmark.Owner)

	if root ~= nil and benchmark.OriginalCharacterCFrame ~= nil then
		root:PivotTo(benchmark.OriginalCharacterCFrame)
	end
end

local function getClientMetricsSummary()
	local metrics = {}

	for metricName, samples in pairs(clientSamplesByMetric) do
		if #samples > 0 then
			local values = table.clone(samples)
			table.sort(values)
			local total = 0

			for _, value in ipairs(values) do
				total += value
			end

			local function percentile(percent)
				return values[math.clamp(math.ceil(#values * percent), 1, #values)]
			end

			metrics[metricName] = {
				Count = #values,
				Min = values[1],
				Average = total / #values,
				Max = values[#values],
				P50 = percentile(0.5),
				P95 = percentile(0.95),
				P99 = percentile(0.99),
			}
		end
	end

	return metrics
end

local function getMetricValue(telemetry, metricName, fieldName)
	if telemetry == nil or telemetry.Metrics == nil then
		return nil
	end

	local metric = telemetry.Metrics[metricName]
	return if metric ~= nil then metric[fieldName] else nil
end

local function secondsToMilliseconds(value)
	return if typeof(value) == "number" then value * 1000 else nil
end

local function finishBenchmark(benchmark, reason)
	if activeBenchmark ~= benchmark then
		return
	end

	benchmark.Phase = "Cleanup"
	cleanupBenchmark(benchmark)
	benchmark.ServerMemoryAfterCleanupMb = readNumber(function()
		return Stats:GetTotalMemoryUsageMb()
	end)
	publishStatus(benchmark, "Cleanup", { Reason = reason })

	task.delay(PerformanceBaselineConfig.CleanupSeconds, function()
		if activeBenchmark ~= benchmark then
			return
		end

		local telemetry = PerformanceTelemetryService.Finish()
		local report = {
			Version = "P0.2",
			FinishedAtUnix = os.time(),
			Reason = reason,
			Scenario = table.clone(benchmark.Scenario),
			RunId = benchmark.Session.RunId,
			Seed = benchmark.Session.Seed,
			Environment = if RunService:IsStudio() then "Studio" else "Published",
			Server = telemetry,
			Client = {
				Metrics = getClientMetricsSummary(),
				Summary = clientSummary,
			},
			Network = {
				RealtimeBytesAvailable = false,
				RequiredCapture = "MicroProfiler network or Developer Console",
			},
			Memory = {
				ServerBeforeMb = benchmark.ServerMemoryBeforeMb,
				ServerPeakMb = getMetricValue(telemetry, "Server.Memory.TotalMb", "Max"),
				ServerAfterCleanupMb = benchmark.ServerMemoryAfterCleanupMb,
			},
		}

		latestReport = report
		activeBenchmark = nil
		clientSamplesByMetric = {}
		clientSummary = nil
		publishStatus(benchmark, "Completed", {
			Reason = reason,
			ReportReady = true,
		})

		DebugLog.Info("Perf", "Rapport P0 serveur", {
			Scenario = benchmark.Scenario.Id,
			Reason = reason,
			HeartbeatP95Ms = secondsToMilliseconds(getMetricValue(telemetry, "Server.HeartbeatSeconds", "P95")),
			MonsterP95Ms = secondsToMilliseconds(getMetricValue(telemetry, "Monster.TickSeconds", "P95")),
			WeaponP95Ms = secondsToMilliseconds(getMetricValue(telemetry, "Weapon.TickSeconds", "P95")),
			RaycastP95Ms = secondsToMilliseconds(getMetricValue(telemetry, "WorldSpawn.RaycastSeconds", "P95")),
			Raycasts = telemetry and telemetry.Counters.WorldSpawn.RaycastCount or 0,
			MonsterRaycastP95Ms = secondsToMilliseconds(getMetricValue(telemetry, "Monster.RaycastSeconds", "P95")),
			MonsterRaycasts = telemetry and telemetry.Counters.Monster.RaycastCount or 0,
			XpMergeP95Ms = secondsToMilliseconds(getMetricValue(telemetry, "Xp.MergeSeconds", "P95")),
			CoinMergeP95Ms = secondsToMilliseconds(getMetricValue(telemetry, "Coin.MergeSeconds", "P95")),
		})
		DebugLog.Info("Perf", "Rapport P0 client", {
			Scenario = benchmark.Scenario.Id,
			FrameP50Ms = secondsToMilliseconds(report.Client.Summary and report.Client.Summary.FrameP50Seconds),
			FrameP95Ms = secondsToMilliseconds(report.Client.Summary and report.Client.Summary.FrameP95Seconds),
			FrameP99Ms = secondsToMilliseconds(report.Client.Summary and report.Client.Summary.FrameP99Seconds),
			FrameSpikes = report.Client.Summary and report.Client.Summary.FrameSpikeCount or 0,
			DrawCallsAverage = getMetricValue({ Metrics = report.Client.Metrics }, "Client.DrawCalls", "Average"),
			TrianglesAverage = getMetricValue({ Metrics = report.Client.Metrics }, "Client.Triangles", "Average"),
			RenderCpuP95Ms = secondsToMilliseconds(getMetricValue({ Metrics = report.Client.Metrics }, "Client.RenderCpuSeconds", "P95")),
			RenderGpuP95Ms = secondsToMilliseconds(getMetricValue({ Metrics = report.Client.Metrics }, "Client.RenderGpuSeconds", "P95")),
		})
		DebugLog.Info("Perf", "Rapport P0 memoire", {
			Scenario = benchmark.Scenario.Id,
			ServerBeforeMb = report.Memory.ServerBeforeMb,
			ServerPeakMb = report.Memory.ServerPeakMb,
			ServerAfterCleanupMb = report.Memory.ServerAfterCleanupMb,
			ClientBeforeMb = report.Client.Summary and report.Client.Summary.MemoryBeforeMb,
			ClientPeakMb = report.Client.Summary and report.Client.Summary.MemoryPeakMb,
			ClientAfterCleanupMb = report.Client.Summary and report.Client.Summary.MemoryAfterCleanupMb,
			Network = "Capture MicroProfiler requise",
		})
	end)
end

local function beginMeasurement(benchmark)
	if activeBenchmark ~= benchmark then
		return
	end

	benchmark.Phase = "Measuring"
	PerformanceTelemetryService.Reset()
	clientSamplesByMetric = {}
	clientSummary = nil
	serverSampleElapsed = 0
	publishStatus(benchmark, "Measuring")

	if (benchmark.Scenario.ProjectileBurst or 0) > 0 then
		WeaponService.DebugFireballBurst(benchmark.Owner, benchmark.Scenario.ProjectileBurst)
	end

	task.delay(PerformanceBaselineConfig.MeasurementSeconds, function()
		finishBenchmark(benchmark, "Completed")
	end)
end

local function startBenchmark(player, scenarioId)
	if activeBenchmark ~= nil then
		return false, "Un benchmark P0 est deja en cours"
	end

	if #Players:GetPlayers() ~= 1 then
		return false, "P0 exige une session solo pour conserver une baseline comparable"
	end

	if not RunStateService.IsRunActive(player) then
		return false, "Lance d'abord une run avant le benchmark P0"
	end

	local scenario = PerformanceBaselineConfig.GetScenario(scenarioId)
	local session = RunSessionService.GetCurrentSession(player)
	local benchmarkRoot, arena, playerStart, simulationCenter = getBenchmarkInstances()
	local root = getCharacterRoot(player)
	local remoteEvents, remoteFunctions = countRemoteTopology()

	if scenario == nil or session == nil or benchmarkRoot == nil or root == nil then
		return false, "Configuration P0 incomplete"
	end

	local benchmark = {
		Id = ("P0-%d-%d"):format(player.UserId, math.floor(os.clock() * 1000)),
		Owner = player,
		Scenario = scenario,
		Session = session,
		BenchmarkRoot = benchmarkRoot,
		Arena = arena,
		SimulationCenter = simulationCenter,
		OriginalMap = RunMapService.GetActiveMap(),
		OriginalCharacterCFrame = root.CFrame,
		ServerMemoryBeforeMb = readNumber(function()
			return Stats:GetTotalMemoryUsageMb()
		end),
		RemoteEvents = remoteEvents,
		RemoteFunctions = remoteFunctions,
		LastClientSampleAt = 0,
		StartedAt = os.clock(),
		Phase = "Warmup",
	}

	benchmark.ArenaSurfaceState = applyArenaSurfaceState(benchmarkRoot, arena, true)
	if benchmark.ArenaSurfaceState == nil then
		return false, "Sol P0 introuvable"
	end

	MonsterService.ClearAllMonsters("PerformanceBaselinePreparation")
	WeaponService.ClearProjectilesForBenchmark()
	XpService.ClearRunGems()
	CoinService.ClearRunCoins()
	MonsterService.SetBenchmarkMode(true)
	MonsterService.SetBenchmarkSeed(PerformanceBaselineConfig.Seed)
	WorldSpawnService.SetRunContext(arena, PerformanceBaselineConfig.Seed, simulationCenter.Position)
	root:PivotTo(playerStart.CFrame + Vector3.new(0, 3, 0))

	local spawnedCount = 0
	if (scenario.MonsterCount or 0) > 0 then
		spawnedCount = select(1, MonsterService.DebugSpawnMonstersNearPlayer(player, scenario.MonsterCount))
	end

	spawnCollectibles(benchmark)
	activeBenchmark = benchmark
	PerformanceTelemetryService.Begin(benchmark.Id)
	publishStatus(benchmark, "Warmup", {
		RequestedMonsters = scenario.MonsterCount or 0,
		SpawnedMonsters = spawnedCount,
	})

	DebugLog.Info("Perf", "Benchmark P0 demarre", {
		Scenario = scenario.Id,
		RequestedMonsters = scenario.MonsterCount or 0,
		SpawnedMonsters = spawnedCount,
		Projectiles = scenario.ProjectileBurst or 0,
		XpGems = scenario.XpGemCount or 0,
		Coins = scenario.CoinCount or 0,
		Seed = PerformanceBaselineConfig.Seed,
	})

	task.delay(PerformanceBaselineConfig.WarmupSeconds, function()
		beginMeasurement(benchmark)
	end)

	return true, ("P0 %s : chauffe %ds, mesure %ds"):format(
		scenario.Label,
		PerformanceBaselineConfig.WarmupSeconds,
		PerformanceBaselineConfig.MeasurementSeconds
	)
end

function PerformanceBenchmarkService.StartScenario(player, scenarioId)
	return startBenchmark(player, scenarioId)
end

function PerformanceBenchmarkService.StopScenario(player)
	if activeBenchmark == nil then
		return false, "Aucun benchmark P0 actif"
	end

	if activeBenchmark.Owner ~= player then
		return false, "Seul le lanceur peut arreter le benchmark P0"
	end

	finishBenchmark(activeBenchmark, "StoppedByAdmin")
	return true, "Arret P0 demande, nettoyage puis rapport"
end

function PerformanceBenchmarkService.GetLatestReport()
	return latestReport
end

function PerformanceBenchmarkService.Start()
	if isStarted then
		return
	end

	isStarted = true
	RunService.Heartbeat:Connect(function(deltaTime)
		if activeBenchmark == nil or activeBenchmark.Phase ~= "Measuring" then
			return
		end

		PerformanceTelemetryService.Record("Server.HeartbeatSeconds", deltaTime, PerformanceBaselineConfig.MaximumSamplesPerMetric)
		serverSampleElapsed += deltaTime

		if serverSampleElapsed >= PerformanceBaselineConfig.SampleInterval then
			serverSampleElapsed = 0
			recordServerSample()
		end
	end)

	clientSampleRemote.OnServerEvent:Connect(function(player, payload)
		local benchmark = activeBenchmark
		if benchmark == nil or benchmark.Owner ~= player or typeof(payload) ~= "table" then
			return
		end

		if payload.BenchmarkId ~= benchmark.Id then
			return
		end

		if payload.Kind == "Summary" and typeof(payload.Summary) == "table" then
			clientSummary = payload.Summary
			return
		end

		if benchmark.Phase ~= "Measuring" or payload.Kind ~= "Sample" or typeof(payload.Metrics) ~= "table" then
			return
		end

		local now = os.clock()
		if now - benchmark.LastClientSampleAt < PerformanceBaselineConfig.SampleInterval * 0.8 then
			return
		end
		benchmark.LastClientSampleAt = now

		for metricName, value in pairs(payload.Metrics) do
			if typeof(metricName) == "string" and typeof(value) == "number" and value == value
				and math.abs(value) < 100000000
			then
				local samples = clientSamplesByMetric[metricName]
				if samples == nil then
					samples = {}
					clientSamplesByMetric[metricName] = samples
				end

				if #samples < PerformanceBaselineConfig.MeasurementSeconds + 8 then
					table.insert(samples, value)
				end
			end
		end
	end)

	RunStateService.RunEnded:Connect(function(player)
		if activeBenchmark ~= nil and activeBenchmark.Owner == player then
			finishBenchmark(activeBenchmark, "RunEnded")
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		if activeBenchmark ~= nil and activeBenchmark.Owner == player then
			cleanupBenchmark(activeBenchmark)
			PerformanceTelemetryService.Finish()
			activeBenchmark = nil
		end
	end)

	DebugLog.Info("Perf", "PerformanceBenchmarkService demarre", {
		Scenarios = #PerformanceBaselineConfig.Scenarios,
		WarmupSeconds = PerformanceBaselineConfig.WarmupSeconds,
		MeasurementSeconds = PerformanceBaselineConfig.MeasurementSeconds,
	})
end

return PerformanceBenchmarkService
