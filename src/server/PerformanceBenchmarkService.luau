local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))
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
local activeCampaign = nil
local latestReport = nil
local latestCampaignReport = nil
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

local function getOrCreateReportFolder()
	local folder = ReplicatedStorage:FindFirstChild(PerformanceBaselineConfig.ReportFolderName)

	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = PerformanceBaselineConfig.ReportFolderName
		folder.Parent = ReplicatedStorage
	end

	assert(folder:IsA("Folder"), PerformanceBaselineConfig.ReportFolderName .. " doit etre un Folder.")
	return folder
end

local reportFolder = getOrCreateReportFolder()

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

	local campaign = benchmark.Campaign
	local payload = {
		Active = phase ~= "Completed" and phase ~= "Idle",
		BenchmarkId = benchmark.Id,
		ScenarioId = benchmark.Scenario.Id,
		ScenarioLabel = benchmark.Scenario.Label,
		Phase = phase,
		ElapsedSeconds = os.clock() - benchmark.StartedAt,
		WarmupSeconds = PerformanceBaselineConfig.WarmupSeconds,
		MeasurementSeconds = PerformanceBaselineConfig.MeasurementSeconds,
		CampaignId = if campaign ~= nil then campaign.Id else nil,
		CampaignLabel = if campaign ~= nil then campaign.Config.Label else nil,
		CampaignIndex = if campaign ~= nil then benchmark.CampaignIndex else nil,
		CampaignTotal = if campaign ~= nil then #campaign.Config.ScenarioIds else nil,
		VfxBenchmarkLock = PerformanceBaselineConfig.LockAdaptiveVfx == true and phase ~= "Completed",
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
	PerformanceTelemetryService.Record("Server.Memory.PhysicsPartsMb", readMemoryTag("PhysicsParts") or -1)
	PerformanceTelemetryService.Record("Server.Memory.PhysicsCollisionMb", readMemoryTag("PhysicsCollision") or -1)
	PerformanceTelemetryService.Record("Server.Instances.Runtime", countRuntimeDescendants())
	PerformanceTelemetryService.Record("Server.Instances.Total", readNumber(function()
		return Stats.InstanceCount
	end) or -1)
	PerformanceTelemetryService.Record("Server.Monsters.Active", monsterSnapshot.Active)
	PerformanceTelemetryService.Record("Server.Monsters.Pool", monsterSnapshot.Pool)
	PerformanceTelemetryService.Record("Server.Projectiles.Active", weaponSnapshot.Active)
	PerformanceTelemetryService.Record("Server.Projectiles.Pool", weaponSnapshot.Pool)
	PerformanceTelemetryService.Record("Server.Network.DataSendKbps", readNumber(function()
		return Stats.DataSendKbps
	end) or -1)
	PerformanceTelemetryService.Record("Server.Network.DataReceiveKbps", readNumber(function()
		return Stats.DataReceiveKbps
	end) or -1)
	PerformanceTelemetryService.Record("Server.Network.PhysicsSendKbps", readNumber(function()
		return Stats.PhysicsSendKbps
	end) or -1)
	PerformanceTelemetryService.Record("Server.Network.PhysicsReceiveKbps", readNumber(function()
		return Stats.PhysicsReceiveKbps
	end) or -1)
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

local function clearProjectileTargets(benchmark)
	local targetFolder = benchmark.ProjectileTargetFolder

	if targetFolder ~= nil and targetFolder.Parent ~= nil then
		targetFolder:Destroy()
	end

	benchmark.ProjectileTargetFolder = nil
	benchmark.ProjectileTargetPositions = nil
end

local function spawnProjectileTargets(benchmark, root)
	local targetCount = math.max(0, math.floor(benchmark.Scenario.ProjectileTargetCount or 0))

	if targetCount <= 0 or root == nil then
		return
	end

	local targetDistance = math.clamp(tonumber(benchmark.Scenario.ProjectileTargetDistance) or 54, 18, 120)
	local targetFolder = Instance.new("Folder")
	targetFolder.Name = "ProjectileBenchmarkTargets"
	targetFolder.Parent = benchmark.Arena

	local positions = {}
	local origin = root.Position + Vector3.new(0, CombatConfig.FireballSpawnHeightOffset, 0)
	local forward = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	local right = Vector3.new(root.CFrame.RightVector.X, 0, root.CFrame.RightVector.Z)

	if forward.Magnitude <= 0.001 then
		forward = Vector3.new(0, 0, -1)
	else
		forward = forward.Unit
	end

	if right.Magnitude <= 0.001 then
		right = Vector3.new(1, 0, 0)
	else
		right = right.Unit
	end

	for index = 1, targetCount do
		local progress = if targetCount <= 1 then 0.5 else (index - 1) / (targetCount - 1)
		local angle = (progress - 0.5) * math.rad(120)
		local direction = ((forward * math.cos(angle)) + (right * math.sin(angle))).Unit
		local position = origin + (direction * targetDistance)
		local target = Instance.new("Part")
		target.Name = "ProjectileBenchmarkTarget"
		target.Anchored = true
		target.CanCollide = false
		target.CanTouch = false
		target.CanQuery = false
		target.CastShadow = false
		target.Material = Enum.Material.Neon
		target.Color = Color3.fromRGB(120, 220, 255)
		target.Transparency = 0.12
		target.Size = Vector3.new(4.5, 4.5, 0.4)
		target.CFrame = CFrame.lookAt(position, origin)
		target.Parent = targetFolder
		table.insert(positions, position)
	end

	benchmark.ProjectileTargetFolder = targetFolder
	benchmark.ProjectileTargetPositions = positions
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

local function cleanupBenchmark(benchmark, preserveArenaContext)
	if preserveArenaContext then
		-- Entre deux scenarios P0, les vagues ordinaires doivent rester suspendues.
		MonsterService.SetBenchmarkMode(true)
		MonsterService.SetBenchmarkSeed(PerformanceBaselineConfig.Seed)
	else
		MonsterService.SetBenchmarkMode(false)
		MonsterService.SetBenchmarkSeed(nil)
	end
	WeaponService.ClearProjectilesForBenchmark()
	clearProjectileTargets(benchmark)
	MonsterService.ClearAllMonsters("PerformanceBaseline")
	XpService.ClearRunGems()
	CoinService.ClearRunCoins()

	if preserveArenaContext then
		return
	end

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

local function getCounterValue(telemetry, counterName)
	if telemetry == nil or telemetry.Counters == nil then
		return 0
	end

	local value = telemetry.Counters[counterName]
	return if typeof(value) == "number" then value else 0
end

local function secondsToMilliseconds(value)
	return if typeof(value) == "number" then value * 1000 else nil
end

local function formatNumber(value, decimals)
	if typeof(value) ~= "number" then
		return "n/a"
	end

	return string.format("%." .. tostring(decimals or 2) .. "f", value)
end

local function getClientMetric(report, metricName, fieldName)
	return getMetricValue({ Metrics = report.Client.Metrics }, metricName, fieldName)
end

local function getReportReproducibility(report)
	local summary = report.Client.Summary

	if summary == nil then
		return false, "client_absent"
	end

	if summary.ViewportChanged == true then
		return false, "viewport_modifie"
	end

	if (tonumber(summary.FocusLostCount) or 0) > 0 then
		return false, "fenetre_non_focalisee"
	end

	return true, "ok"
end

local function buildScenarioExport(report)
	local clientSummary = report.Client.Summary or {}
	local comparable, reason = getReportReproducibility(report)

	return table.concat({
		"P0_SCENARIO",
		"id=" .. report.Scenario.Id,
		"raison=" .. report.Reason,
		"comparable=" .. tostring(comparable),
		"validation=" .. reason,
		"seed=" .. tostring(report.Seed),
		"run_seed=" .. tostring(report.RunSeed),
		"coeur_ms_p95=" .. formatNumber(secondsToMilliseconds(getMetricValue(report.Server, "Server.HeartbeatSeconds", "P95"))),
		"monstres_ms_p95=" .. formatNumber(secondsToMilliseconds(getMetricValue(report.Server, "Monster.TickSeconds", "P95"))),
		"projectiles_ms_p95=" .. formatNumber(secondsToMilliseconds(getMetricValue(report.Server, "Weapon.TickSeconds", "P95"))),
		"client_frame_ms_p95=" .. formatNumber(secondsToMilliseconds(clientSummary.FrameP95Seconds)),
		"client_physics_ms_p95=" .. formatNumber(secondsToMilliseconds(getClientMetric(report, "Client.PhysicsSeconds", "P95"))),
		"draw_calls_moy=" .. formatNumber(getClientMetric(report, "Client.DrawCalls", "Average"), 0),
		"triangles_moy=" .. formatNumber(getClientMetric(report, "Client.Triangles", "Average"), 0),
		"instances_client_p95=" .. formatNumber(getClientMetric(report, "Client.Instances", "P95"), 0),
		"vfx_particules_allouees_p95=" .. formatNumber(getClientMetric(report, "Client.Vfx.ParticleEmitters", "P95"), 0),
		"vfx_particules_actives_p95=" .. formatNumber(getClientMetric(report, "Client.Vfx.ActiveParticleEmitters", "P95"), 0),
		"vfx_lumieres_allouees_p95=" .. formatNumber(getClientMetric(report, "Client.Vfx.Lights", "P95"), 0),
		"vfx_lumieres_actives_p95=" .. formatNumber(getClientMetric(report, "Client.Vfx.ActiveLights", "P95"), 0),
		"vfx_trails_actifs_p95=" .. formatNumber(getClientMetric(report, "Client.Vfx.ActiveTrails", "P95"), 0),
		"memoire_serveur_avant_mb=" .. formatNumber(report.Memory.ServerBeforeMb),
		"memoire_serveur_pic_mb=" .. formatNumber(report.Memory.ServerPeakMb),
		"memoire_serveur_cleanup_mb=" .. formatNumber(report.Memory.ServerAfterCleanupMb),
		"memoire_serveur_repos_mb=" .. formatNumber(report.Memory.ServerAfterIdleMb),
		"memoire_client_avant_mb=" .. formatNumber(clientSummary.MemoryBeforeMb),
		"memoire_client_pic_mb=" .. formatNumber(clientSummary.MemoryPeakMb),
		"memoire_client_cleanup_mb=" .. formatNumber(clientSummary.MemoryAfterCleanupMb),
		"memoire_client_repos_mb=" .. formatNumber(clientSummary.MemoryAfterIdleMb),
		"vfx_verrouille=" .. tostring(clientSummary.Vfx and clientSummary.Vfx.BenchmarkLockEnabled == true),
	}, "\n")
end

local function buildMonsterSimulationExport(report)
	local visitedStates = getMetricValue(report.Server, "Monster.VisitedStatesPerTick", "P95")

	if visitedStates == nil then
		return nil
	end

	return table.concat({
		"scenario=" .. report.Scenario.Id,
		"presentation=" .. tostring(report.Scenario.ProjectilePresentationMode or "ReplicatedCore"),
		"visites_p95=" .. formatNumber(visitedStates, 0),
		"joueurs_ms_p95=" .. formatNumber(secondsToMilliseconds(getMetricValue(report.Server, "Monster.PlayerTargetCollectionSeconds", "P95"))),
		"ciblage_ms_p95=" .. formatNumber(secondsToMilliseconds(getMetricValue(report.Server, "Monster.TargetingSeconds", "P95"))),
		"lod_ms_p95=" .. formatNumber(secondsToMilliseconds(getMetricValue(report.Server, "Monster.LodSeconds", "P95"))),
		"lod_full_p95=" .. formatNumber(getMetricValue(report.Server, "Monster.LodFullStatesPerTick", "P95"), 0),
		"lod_reduit_p95=" .. formatNumber(getMetricValue(report.Server, "Monster.LodReducedStatesPerTick", "P95"), 0),
		"lod_lointain_p95=" .. formatNumber(getMetricValue(report.Server, "Monster.LodDistantStatesPerTick", "P95"), 0),
		"pas_full_p95=" .. formatNumber(getMetricValue(report.Server, "Monster.LodFullStepsPerTick", "P95"), 0),
		"pas_reduit_p95=" .. formatNumber(getMetricValue(report.Server, "Monster.LodReducedStepsPerTick", "P95"), 0),
		"pas_lointain_p95=" .. formatNumber(getMetricValue(report.Server, "Monster.LodDistantStepsPerTick", "P95"), 0),
		"mouvement_ms_p95=" .. formatNumber(secondsToMilliseconds(getMetricValue(report.Server, "Monster.MovementSeconds", "P95"))),
		"direction_ms_p95=" .. formatNumber(secondsToMilliseconds(getMetricValue(report.Server, "Monster.MoveDirectionSeconds", "P95"))),
		"separation_ms_p95=" .. formatNumber(secondsToMilliseconds(getMetricValue(report.Server, "Monster.SeparationSeconds", "P95"))),
		"separation_voisins_p95=" .. formatNumber(getMetricValue(report.Server, "Monster.SeparationNeighborCandidatesPerTick", "P95"), 0),
		"separation_proches_p95=" .. formatNumber(getMetricValue(report.Server, "Monster.SeparationNeighborsInRadiusPerTick", "P95"), 0),
		"sol_ms_p95=" .. formatNumber(secondsToMilliseconds(getMetricValue(report.Server, "Monster.GroundFollowSeconds", "P95"))),
		"sol_echantillons_p95=" .. formatNumber(getMetricValue(report.Server, "Monster.GroundSamplesPerTick", "P95"), 0),
		"sol_cache_p95=" .. formatNumber(getMetricValue(report.Server, "Monster.GroundCacheHitsPerTick", "P95"), 0),
		"sol_cache_partage_p95=" .. formatNumber(getMetricValue(report.Server, "Monster.GroundSharedSurfaceCacheHitsPerTick", "P95"), 0),
		"sol_raycasts=" .. formatNumber(getCounterValue(report.Server, "Monster.Ground.RaycastCount"), 0),
		"evitement_ms_p95=" .. formatNumber(secondsToMilliseconds(getMetricValue(report.Server, "Monster.TerrainAvoidanceSeconds", "P95"))),
		"evitement_echantillons_p95=" .. formatNumber(getMetricValue(report.Server, "Monster.TerrainAvoidanceSamplesPerTick", "P95"), 0),
		"evitement_raycasts=" .. formatNumber(getCounterValue(report.Server, "Monster.Avoidance.RaycastCount"), 0),
		"transform_ms_p95=" .. formatNumber(secondsToMilliseconds(getMetricValue(report.Server, "Monster.VisualTransformSeconds", "P95"))),
		"pivot_ms_p95=" .. formatNumber(secondsToMilliseconds(getMetricValue(report.Server, "Monster.PivotSeconds", "P95"))),
		"grille_ms_p95=" .. formatNumber(secondsToMilliseconds(getMetricValue(report.Server, "Monster.SpatialGridUpdateSeconds", "P95"))),
		"degats_ms_p95=" .. formatNumber(secondsToMilliseconds(getMetricValue(report.Server, "Monster.DamageSeconds", "P95"))),
		"spawn_ms_p95=" .. formatNumber(secondsToMilliseconds(getMetricValue(report.Server, "Monster.SpawnSeconds", "P95"))),
		"vague_spawn_ms_p95=" .. formatNumber(secondsToMilliseconds(getMetricValue(report.Server, "Monster.WaveSpawnSeconds", "P95"))),
		"recyclage_ms_p95=" .. formatNumber(secondsToMilliseconds(getMetricValue(report.Server, "Monster.RecycleSeconds", "P95"))),
	}, "\n")
end

local function buildProjectileP3Export(report)
	if (report.Scenario.ProjectileTargetCount or 0) <= 0 then
		return nil
	end

	return table.concat({
		"scenario=" .. report.Scenario.Id,
		"cibles=" .. formatNumber(report.Scenario.ProjectileTargetCount, 0),
		"tirs_demandes=" .. formatNumber(getCounterValue(report.Server, "Weapon.Projectiles.BenchmarkShotsRequested"), 0),
		"tirs_emis=" .. formatNumber(getCounterValue(report.Server, "Weapon.Projectiles.BenchmarkShotsEmitted"), 0),
		"projectiles_crees=" .. formatNumber(getCounterValue(report.Server, "Weapon.Projectiles.Created"), 0),
		"projectiles_reutilises=" .. formatNumber(getCounterValue(report.Server, "Weapon.Projectiles.ReusedFromPool"), 0),
		"projectiles_clones=" .. formatNumber(getCounterValue(report.Server, "Weapon.Projectiles.Cloned"), 0),
		"projectiles_recycles=" .. formatNumber(getCounterValue(report.Server, "Weapon.Projectiles.BenchmarkReleased"), 0),
		"transforms_repliques=" .. formatNumber(getCounterValue(report.Server, "Weapon.Projectiles.TransformUpdates"), 0),
		"transforms_logiques=" .. formatNumber(getCounterValue(report.Server, "Weapon.Projectiles.LogicalUpdates"), 0),
		"pilot_spawns=" .. formatNumber(getCounterValue(report.Server, "Weapon.Projectiles.ClientPilotSpawns"), 0),
		"pilot_destroys=" .. formatNumber(getCounterValue(report.Server, "Weapon.Projectiles.ClientPilotDestroys"), 0),
		"impacts=" .. formatNumber(getCounterValue(report.Server, "Weapon.Projectiles.BenchmarkImpacts"), 0),
		"expires=" .. formatNumber(getCounterValue(report.Server, "Weapon.Projectiles.BenchmarkExpired"), 0),
		"audio_cast=" .. formatNumber(getCounterValue(report.Server, "Weapon.Projectiles.CastAudioEvents"), 0),
		"actifs_p95=" .. formatNumber(getMetricValue(report.Server, "Server.Projectiles.Active", "P95"), 0),
		"pool_p95=" .. formatNumber(getMetricValue(report.Server, "Server.Projectiles.Pool", "P95"), 0),
		"tick_ms_p95=" .. formatNumber(secondsToMilliseconds(getMetricValue(report.Server, "Weapon.TickSeconds", "P95"))),
		"serveur_envoi_kbps_p95=" .. formatNumber(getMetricValue(report.Server, "Server.Network.DataSendKbps", "P95")),
		"serveur_recoit_kbps_p95=" .. formatNumber(getMetricValue(report.Server, "Server.Network.DataReceiveKbps", "P95")),
		"client_recoit_kbps_p95=" .. formatNumber(getClientMetric(report, "Client.Network.DataReceiveKbps", "P95")),
		"client_envoi_kbps_p95=" .. formatNumber(getClientMetric(report, "Client.Network.DataSendKbps", "P95")),
		"client_frame_ms_p95=" .. formatNumber(secondsToMilliseconds(report.Client.Summary and report.Client.Summary.FrameP95Seconds)),
	}, "\n")
end

local function writeReportValue(name, value)
	local reportValue = reportFolder:FindFirstChild(name)

	if reportValue == nil then
		reportValue = Instance.new("StringValue")
		reportValue.Name = name
		reportValue.Parent = reportFolder
	end

	assert(reportValue:IsA("StringValue"), name .. " doit etre un StringValue.")
	reportValue.Value = value
end

local finishCampaign
local startCampaignNextScenario

local function finishBenchmark(benchmark, reason)
	if activeBenchmark ~= benchmark then
		return
	end

	benchmark.Phase = "Cleanup"
	-- Le contexte P0 reste actif jusqu'au rapport final. Sans cela, les
	-- vagues ordinaires faussent immediatement la mesure de memoire residuelle.
	cleanupBenchmark(benchmark, true)
	benchmark.ServerMemoryAfterCleanupMb = readNumber(function()
		return Stats:GetTotalMemoryUsageMb()
	end)
	publishStatus(benchmark, "Cleanup", { Reason = reason })

	task.delay(PerformanceBaselineConfig.CleanupSeconds, function()
		if activeBenchmark ~= benchmark then
			return
		end

		benchmark.Phase = "IdleObservation"
		publishStatus(benchmark, "IdleObservation", { Reason = reason })

		task.delay(PerformanceBaselineConfig.IdleObservationSeconds, function()
			if activeBenchmark ~= benchmark then
				return
			end

			benchmark.ServerMemoryAfterIdleMb = readNumber(function()
				return Stats:GetTotalMemoryUsageMb()
			end)

			local telemetry = PerformanceTelemetryService.Finish()
			local report = {
				Version = "P0.4",
				FinishedAtUnix = os.time(),
				Reason = reason,
				Scenario = table.clone(benchmark.Scenario),
				Campaign = if benchmark.Campaign ~= nil
					then {
						Id = benchmark.Campaign.Id,
						Label = benchmark.Campaign.Config.Label,
						Index = benchmark.CampaignIndex,
						Total = #benchmark.Campaign.Config.ScenarioIds,
					}
					else nil,
				RunId = benchmark.Session.RunId,
				-- Le seed de benchmark pilote la population, les positions et les tirs
				-- synthetiques. Le seed de run reste trace separatement pour retrouver
				-- la session Roblox qui a porte la campagne.
				Seed = PerformanceBaselineConfig.Seed,
				RunSeed = benchmark.Session.Seed,
				Environment = if RunService:IsStudio() then "Studio" else "Published",
				Server = telemetry,
				Client = {
					Metrics = getClientMetricsSummary(),
					Summary = clientSummary,
				},
		Network = {
			RealtimeKbpsAvailable = true,
			RequiredAttributionCapture = "MicroProfiler network or Developer Console",
				},
				Memory = {
					ServerBeforeMb = benchmark.ServerMemoryBeforeMb,
					ServerPeakMb = getMetricValue(telemetry, "Server.Memory.TotalMb", "Max"),
					ServerAfterCleanupMb = benchmark.ServerMemoryAfterCleanupMb,
					ServerAfterIdleMb = benchmark.ServerMemoryAfterIdleMb,
				},
				BenchmarkPolicy = {
					AdaptiveVfxLocked = PerformanceBaselineConfig.LockAdaptiveVfx == true,
					IdleObservationSeconds = PerformanceBaselineConfig.IdleObservationSeconds,
				},
			}

			local comparable, validationReason = getReportReproducibility(report)
			report.Reproducibility = {
				Comparable = comparable,
				ValidationReason = validationReason,
			}

			local export = buildScenarioExport(report)
			writeReportValue("LatestScenario", export)
			writeReportValue("Scenario_" .. benchmark.Scenario.Id, export)
			print("[MegaRoblox][P0_EXPORT] " .. export:gsub("\n", " | "))

			local monsterSimulationExport = buildMonsterSimulationExport(report)
			if monsterSimulationExport ~= nil then
				print("[MegaRoblox][P2_SIMULATION] " .. monsterSimulationExport:gsub("\n", " | "))
			end

			local projectileP3Export = buildProjectileP3Export(report)
			if projectileP3Export ~= nil then
				print("[MegaRoblox][P3_PROJECTILES] " .. projectileP3Export:gsub("\n", " | "))
			end

			latestReport = report
			activeBenchmark = nil
			clientSamplesByMetric = {}
			clientSummary = nil

			DebugLog.Info("Perf", "Rapport P0 serveur", {
				Scenario = benchmark.Scenario.Id,
				Reason = reason,
				Comparable = comparable,
				Validation = validationReason,
				HeartbeatP95Ms = secondsToMilliseconds(getMetricValue(telemetry, "Server.HeartbeatSeconds", "P95")),
				MonsterP95Ms = secondsToMilliseconds(getMetricValue(telemetry, "Monster.TickSeconds", "P95")),
				WeaponP95Ms = secondsToMilliseconds(getMetricValue(telemetry, "Weapon.TickSeconds", "P95")),
				RaycastP95Ms = secondsToMilliseconds(getMetricValue(telemetry, "WorldSpawn.RaycastSeconds", "P95")),
				Raycasts = getCounterValue(telemetry, "WorldSpawn.RaycastCount"),
				MonsterRaycastP95Ms = secondsToMilliseconds(getMetricValue(telemetry, "Monster.RaycastSeconds", "P95")),
				MonsterRaycasts = getCounterValue(telemetry, "Monster.RaycastCount"),
				XpMergeP95Ms = secondsToMilliseconds(getMetricValue(telemetry, "Xp.MergeSeconds", "P95")),
				CoinMergeP95Ms = secondsToMilliseconds(getMetricValue(telemetry, "Coin.MergeSeconds", "P95")),
			})
			DebugLog.Info("Perf", "Rapport P0 client", {
				Scenario = benchmark.Scenario.Id,
				FrameP50Ms = secondsToMilliseconds(report.Client.Summary and report.Client.Summary.FrameP50Seconds),
				FrameP95Ms = secondsToMilliseconds(report.Client.Summary and report.Client.Summary.FrameP95Seconds),
				FrameP99Ms = secondsToMilliseconds(report.Client.Summary and report.Client.Summary.FrameP99Seconds),
				FrameSpikes = report.Client.Summary and report.Client.Summary.FrameSpikeCount or 0,
				PhysicsP95Ms = secondsToMilliseconds(getClientMetric(report, "Client.PhysicsSeconds", "P95")),
				DrawCallsAverage = getClientMetric(report, "Client.DrawCalls", "Average"),
				TrianglesAverage = getClientMetric(report, "Client.Triangles", "Average"),
				InstancesP95 = getClientMetric(report, "Client.Instances", "P95"),
				RenderCpuP95Ms = secondsToMilliseconds(getClientMetric(report, "Client.RenderCpuSeconds", "P95")),
				RenderGpuP95Ms = secondsToMilliseconds(getClientMetric(report, "Client.RenderGpuSeconds", "P95")),
				VfxParticlesP95 = getClientMetric(report, "Client.Vfx.ParticleEmitters", "P95"),
				VfxLightsP95 = getClientMetric(report, "Client.Vfx.Lights", "P95"),
			})
			DebugLog.Info("Perf", "Rapport P0 memoire", {
				Scenario = benchmark.Scenario.Id,
				ServerBeforeMb = report.Memory.ServerBeforeMb,
				ServerPeakMb = report.Memory.ServerPeakMb,
				ServerAfterCleanupMb = report.Memory.ServerAfterCleanupMb,
				ServerAfterIdleMb = report.Memory.ServerAfterIdleMb,
				ClientBeforeMb = report.Client.Summary and report.Client.Summary.MemoryBeforeMb,
				ClientPeakMb = report.Client.Summary and report.Client.Summary.MemoryPeakMb,
				ClientAfterCleanupMb = report.Client.Summary and report.Client.Summary.MemoryAfterCleanupMb,
				ClientAfterIdleMb = report.Client.Summary and report.Client.Summary.MemoryAfterIdleMb,
				Network = "Capture MicroProfiler requise",
			})

			local campaign = benchmark.Campaign
			if campaign ~= nil and activeCampaign == campaign then
				table.insert(campaign.Reports, report)
				campaign.LastBenchmark = benchmark

				if campaign.StopRequested then
					finishCampaign(campaign, reason, benchmark)
				else
					publishStatus(benchmark, "CampaignTransition", {
						Reason = reason,
						ReportReady = true,
					})

					task.delay(PerformanceBaselineConfig.InterScenarioSeconds, function()
						startCampaignNextScenario(campaign)
					end)
				end
			else
				cleanupBenchmark(benchmark, false)
				publishStatus(benchmark, "Completed", {
					Reason = reason,
					ReportReady = true,
				})
			end
		end)
	end)
end

local function startProjectileCadence(benchmark)
	local burstCount = math.max(0, math.floor(benchmark.Scenario.ProjectileBurst or 0))
	local intervalSeconds = tonumber(benchmark.Scenario.ProjectileBurstIntervalSeconds)

	if burstCount <= 0 then
		return
	end

	local function fireBurst()
		if activeBenchmark ~= benchmark or benchmark.Phase ~= "Measuring" then
			return false
		end

		local targetPositions = benchmark.ProjectileTargetPositions

		if targetPositions ~= nil and #targetPositions > 0 then
			WeaponService.DebugFireballBurstAtPositions(
				benchmark.Owner,
				targetPositions,
				burstCount,
				benchmark.Scenario.ProjectilePresentationMode
			)
		else
			WeaponService.DebugFireballBurst(benchmark.Owner, burstCount)
		end

		return true
	end

	if not fireBurst() or intervalSeconds == nil or intervalSeconds <= 0 then
		return
	end

	task.spawn(function()
		while activeBenchmark == benchmark and benchmark.Phase == "Measuring" do
			task.wait(intervalSeconds)

			if not fireBurst() then
				return
			end
		end
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

	startProjectileCadence(benchmark)

	task.delay(PerformanceBaselineConfig.MeasurementSeconds, function()
		finishBenchmark(benchmark, "Completed")
	end)
end

local function startBenchmark(player, scenarioId, campaign)
	if activeBenchmark ~= nil then
		return false, "Un benchmark P0 est deja en cours"
	end

	if campaign == nil and activeCampaign ~= nil then
		return false, "Une campagne P0 est deja en cours"
	end

	if campaign ~= nil and activeCampaign ~= campaign then
		return false, "Campagne P0 invalide"
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

	local originalMap = if campaign ~= nil and campaign.OriginalMap ~= nil then campaign.OriginalMap else RunMapService.GetActiveMap()
	local originalCharacterCFrame = if campaign ~= nil and campaign.OriginalCharacterCFrame ~= nil
		then campaign.OriginalCharacterCFrame
		else root.CFrame
	local benchmark = {
		Id = ("P0-%d-%d"):format(player.UserId, math.floor(os.clock() * 1000)),
		Owner = player,
		Scenario = scenario,
		Campaign = campaign,
		CampaignIndex = if campaign ~= nil then campaign.NextScenarioIndex else nil,
		Session = session,
		BenchmarkRoot = benchmarkRoot,
		Arena = arena,
		SimulationCenter = simulationCenter,
		OriginalMap = originalMap,
		OriginalCharacterCFrame = originalCharacterCFrame,
		ServerMemoryBeforeMb = readNumber(function()
			return Stats:GetTotalMemoryUsageMb()
		end),
		RemoteEvents = remoteEvents,
		RemoteFunctions = remoteFunctions,
		LastClientSampleAt = 0,
		StartedAt = os.clock(),
		Phase = "Warmup",
	}

	benchmark.ArenaSurfaceState = if campaign ~= nil then campaign.ArenaSurfaceState else nil
	if benchmark.ArenaSurfaceState == nil then
		benchmark.ArenaSurfaceState = applyArenaSurfaceState(benchmarkRoot, arena, true)
	end
	if benchmark.ArenaSurfaceState == nil then
		return false, "Sol P0 introuvable"
	end

	if campaign ~= nil then
		campaign.ArenaSurfaceState = benchmark.ArenaSurfaceState
		campaign.OriginalMap = originalMap
		campaign.OriginalCharacterCFrame = originalCharacterCFrame
		campaign.LastBenchmark = benchmark
	end

	MonsterService.ClearAllMonsters("PerformanceBaselinePreparation")
	WeaponService.ClearProjectilesForBenchmark()
	XpService.ClearRunGems()
	CoinService.ClearRunCoins()
	MonsterService.SetBenchmarkMode(true)
	MonsterService.SetBenchmarkSeed(PerformanceBaselineConfig.Seed)
	WorldSpawnService.SetRunContext(arena, PerformanceBaselineConfig.Seed, simulationCenter.Position)
	root:PivotTo(playerStart.CFrame + Vector3.new(0, 3, 0))
	spawnProjectileTargets(benchmark, root)

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
		ProjectileBurst = scenario.ProjectileBurst or 0,
		ProjectileBurstIntervalSeconds = scenario.ProjectileBurstIntervalSeconds,
		ProjectileTargets = scenario.ProjectileTargetCount or 0,
		XpGems = scenario.XpGemCount or 0,
		Coins = scenario.CoinCount or 0,
		Seed = PerformanceBaselineConfig.Seed,
		CampaignId = if campaign ~= nil then campaign.Id else nil,
		CampaignIndex = if campaign ~= nil then benchmark.CampaignIndex else nil,
		CampaignTotal = if campaign ~= nil then #campaign.Config.ScenarioIds else nil,
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

finishCampaign = function(campaign, reason, benchmark)
	if activeCampaign ~= campaign then
		return
	end

	local cleanupSource = benchmark or campaign.LastBenchmark
	if cleanupSource ~= nil then
		cleanupBenchmark(cleanupSource, false)
	end

	campaign.FinishedAt = os.clock()
	campaign.ServerMemoryAfterCampaignMb = readNumber(function()
		return Stats:GetTotalMemoryUsageMb()
	end)
	latestCampaignReport = {
		Version = "P0.4",
		CampaignId = campaign.Id,
		CampaignLabel = campaign.Config.Label,
		RunId = campaign.Session and campaign.Session.RunId or nil,
		Seed = PerformanceBaselineConfig.Seed,
		Environment = if RunService:IsStudio() then "Studio" else "Published",
		Reason = reason,
		StartedAtUnix = campaign.StartedAtUnix,
		FinishedAtUnix = os.time(),
		ScenarioCount = #campaign.Config.ScenarioIds,
		CompletedScenarioCount = #campaign.Reports,
		DurationSeconds = campaign.FinishedAt - campaign.StartedAt,
		Memory = {
			ServerBeforeCampaignMb = campaign.ServerMemoryBeforeCampaignMb,
			ServerAfterCampaignMb = campaign.ServerMemoryAfterCampaignMb,
		},
		Reports = table.clone(campaign.Reports),
	}
	activeCampaign = nil

	local campaignLines = {
		"P0_CAMPAGNE",
		"id=" .. campaign.Id,
		"raison=" .. reason,
		"scenarios=" .. tostring(#campaign.Reports) .. "/" .. tostring(#campaign.Config.ScenarioIds),
		"duree_s=" .. formatNumber(latestCampaignReport.DurationSeconds),
		"memoire_serveur_avant_mb=" .. formatNumber(campaign.ServerMemoryBeforeCampaignMb),
		"memoire_serveur_apres_mb=" .. formatNumber(campaign.ServerMemoryAfterCampaignMb),
	}

	for _, report in ipairs(campaign.Reports) do
		local comparable, validationReason = getReportReproducibility(report)
		table.insert(campaignLines, table.concat({
			"scenario=" .. report.Scenario.Id,
			"comparable=" .. tostring(comparable),
			"validation=" .. validationReason,
			"frame_p95_ms=" .. formatNumber(secondsToMilliseconds(report.Client.Summary and report.Client.Summary.FrameP95Seconds)),
			"monstre_p95_ms=" .. formatNumber(secondsToMilliseconds(getMetricValue(report.Server, "Monster.TickSeconds", "P95"))),
		}, " "))
	end

	local campaignExport = table.concat(campaignLines, "\n")
	writeReportValue("LatestCampaign", campaignExport)
	writeReportValue("Campaign_" .. campaign.Id, campaignExport)
	print("[MegaRoblox][P0_EXPORT] " .. campaignExport:gsub("\n", " | "))

	if cleanupSource ~= nil then
		publishStatus(cleanupSource, "Completed", {
			Reason = reason,
			ReportReady = true,
			CampaignCompleted = true,
			CampaignCompletedScenarios = #campaign.Reports,
		})
	end

	DebugLog.Info("Perf", "Rapport campagne P0", {
		Campaign = campaign.Id,
		Reason = reason,
		CompletedScenarios = #campaign.Reports,
		RequestedScenarios = #campaign.Config.ScenarioIds,
		DurationSeconds = latestCampaignReport.DurationSeconds,
		ServerBeforeMb = campaign.ServerMemoryBeforeCampaignMb,
		ServerAfterMb = campaign.ServerMemoryAfterCampaignMb,
		ExplorerReport = PerformanceBaselineConfig.ReportFolderName .. "/LatestCampaign",
	})
end

startCampaignNextScenario = function(campaign)
	if activeCampaign ~= campaign or campaign.StopRequested then
		return
	end

	if campaign.NextScenarioIndex > #campaign.Config.ScenarioIds then
		finishCampaign(campaign, "Completed", campaign.LastBenchmark)
		return
	end

	local scenarioId = campaign.Config.ScenarioIds[campaign.NextScenarioIndex]
	local success, message = startBenchmark(campaign.Owner, scenarioId, campaign)

	if not success then
		campaign.StopRequested = true
		DebugLog.Warn("Perf", "Campagne P0 interrompue", {
			Campaign = campaign.Id,
			ScenarioId = scenarioId,
			Reason = message,
		})
		finishCampaign(campaign, "ScenarioStartFailed", campaign.LastBenchmark)
		return
	end

	campaign.NextScenarioIndex += 1
end

function PerformanceBenchmarkService.StartCampaign(player, campaignId)
	if activeBenchmark ~= nil or activeCampaign ~= nil then
		return false, "Un benchmark P0 est deja en cours"
	end

	local campaignConfig = PerformanceBaselineConfig.GetCampaign(campaignId)
	if campaignConfig == nil or #campaignConfig.ScenarioIds == 0 then
		return false, "Campagne P0 inconnue ou vide"
	end

	for _, scenarioId in ipairs(campaignConfig.ScenarioIds) do
		if PerformanceBaselineConfig.GetScenario(scenarioId) == nil then
			return false, "Campagne P0 invalide : scenario absent " .. scenarioId
		end
	end

	local session = RunSessionService.GetCurrentSession(player)
	if session == nil or not RunStateService.IsRunActive(player) then
		return false, "Lance d'abord une run avant la campagne P0"
	end

	activeCampaign = {
		Id = ("P0C-%d-%d"):format(player.UserId, math.floor(os.clock() * 1000)),
		Config = campaignConfig,
		Owner = player,
		Session = session,
		StartedAt = os.clock(),
		StartedAtUnix = os.time(),
		NextScenarioIndex = 1,
		Reports = {},
		ServerMemoryBeforeCampaignMb = readNumber(function()
			return Stats:GetTotalMemoryUsageMb()
		end),
		StopRequested = false,
	}

	startCampaignNextScenario(activeCampaign)

	if activeBenchmark == nil then
		return false, "Campagne P0 impossible a demarrer"
	end

	return true, ("%s : %d scenarios enchaines"):format(campaignConfig.Label, #campaignConfig.ScenarioIds)
end

function PerformanceBenchmarkService.StartSelection(player, selectionId)
	if PerformanceBaselineConfig.GetScenario(selectionId) ~= nil then
		return PerformanceBenchmarkService.StartScenario(player, selectionId)
	end

	if PerformanceBaselineConfig.GetCampaign(selectionId) ~= nil then
		return PerformanceBenchmarkService.StartCampaign(player, selectionId)
	end

	return false, "Selection P0 inconnue"
end

function PerformanceBenchmarkService.StopScenario(player)
	if activeBenchmark == nil and activeCampaign == nil then
		return false, "Aucun benchmark P0 actif"
	end

	local owner = if activeBenchmark ~= nil then activeBenchmark.Owner else activeCampaign.Owner
	if owner ~= player then
		return false, "Seul le lanceur peut arreter le benchmark P0"
	end

	if activeCampaign ~= nil then
		activeCampaign.StopRequested = true
	end

	if activeBenchmark ~= nil then
		finishBenchmark(activeBenchmark, "StoppedByAdmin")
	else
		finishCampaign(activeCampaign, "StoppedByAdmin", activeCampaign.LastBenchmark)
	end
	return true, "Arret P0 demande, nettoyage puis rapport"
end

function PerformanceBenchmarkService.GetLatestReport()
	return latestReport
end

function PerformanceBenchmarkService.GetLatestCampaignReport()
	return latestCampaignReport
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
		if activeCampaign ~= nil and activeCampaign.Owner == player then
			activeCampaign.StopRequested = true
		end

		if activeBenchmark ~= nil and activeBenchmark.Owner == player then
			finishBenchmark(activeBenchmark, "RunEnded")
		elseif activeCampaign ~= nil and activeCampaign.Owner == player then
			finishCampaign(activeCampaign, "RunEnded", activeCampaign.LastBenchmark)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		if activeBenchmark ~= nil and activeBenchmark.Owner == player then
			cleanupBenchmark(activeBenchmark, false)
			PerformanceTelemetryService.Finish()
			activeBenchmark = nil
			activeCampaign = nil
		elseif activeCampaign ~= nil and activeCampaign.Owner == player then
			activeCampaign = nil
		end
	end)

	DebugLog.Info("Perf", "PerformanceBenchmarkService demarre", {
		Scenarios = #PerformanceBaselineConfig.Scenarios,
		Campaigns = #PerformanceBaselineConfig.Campaigns,
		WarmupSeconds = PerformanceBaselineConfig.WarmupSeconds,
		MeasurementSeconds = PerformanceBaselineConfig.MeasurementSeconds,
		IdleObservationSeconds = PerformanceBaselineConfig.IdleObservationSeconds,
	})
end

return PerformanceBenchmarkService
