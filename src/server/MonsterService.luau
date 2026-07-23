local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))
local DebugLog = require(Shared:WaitForChild("DebugLog"))
local PickupFeedbackConfig = require(Shared:WaitForChild("PickupFeedbackConfig"))

local CombatStateService = require(script.Parent:WaitForChild("CombatStateService"))
local ChestService = require(script.Parent:WaitForChild("ChestService"))
local CoinService = require(script.Parent:WaitForChild("CoinService"))
local PerkService = require(script.Parent:WaitForChild("PerkService"))
local RunAnalyticsService = require(script.Parent:WaitForChild("RunAnalyticsService"))
local RunStateService = require(script.Parent:WaitForChild("RunStateService"))
local TemplateService = require(script.Parent:WaitForChild("TemplateService"))
local PerformanceTelemetryService = require(script.Parent:WaitForChild("PerformanceTelemetryService"))
local WorldSpawnService = require(script.Parent:WaitForChild("WorldSpawnService"))
local XpService = require(script.Parent:WaitForChild("XpService"))

local MonsterService = {}
local monsterKilledEvent = Instance.new("BindableEvent")

MonsterService.MonsterKilled = monsterKilledEvent.Event

local rng = Random.new()
local runtimeFolder = nil
local monsterFolder = nil
local monsterTemplate = nil
local eliteMonsterTemplate = nil
local poolFolder = nil
local heartbeatConnection = nil
local elapsedStatsUpdate = 0
local simulationAccumulator = 0
local monsterTickTimeTotal = 0
local monsterTickSampleCount = 0
local monsterTickMaxSeconds = 0
local elapsedSincePerfLog = 0
local waveStartedAt = CombatStateService.GetTime()
local monstersByInstance = {}
local monsterSpatialGrid = {}
local monsterSeparationGrid = {}
local groundSurfaceCellCache = {}
local killsByUserId = {}
local lastSpawnAtByUserId = {}
local lastRecycleCheckAtByUserId = {}
local lastRecycleAtByUserId = {}
local groundedSinceByUserId = {}
local characterConnectionsByUserId = {}
local healthConnectionsByUserId = {}
local elitePacksById = {}
local nextElitePackId = 0
local difficultyPercent = 0
local runItemService = nil
local benchmarkMode = false
local activeSimulationTelemetry = nil
local pendingDebugSpawnsByUserId = {}
local pendingWaveSpawnsByUserId = {}
local waveSpawnDispatchAllowance = 0

local function addSimulationTelemetry(metricName, amount)
	if activeSimulationTelemetry == nil then
		return
	end

	activeSimulationTelemetry[metricName] = (activeSimulationTelemetry[metricName] or 0) + (amount or 0)
end

local function getRunItemService()
	if runItemService == nil then
		runItemService = require(script.Parent:WaitForChild("RunItemService"))
	end

	return runItemService
end

local function createSpawnActivity()
	return {
		Batches = 0,
		Requested = 0,
		Spawned = 0,
		Failed = 0,
		LargestRequestedBatch = 0,
		LargestSpawnedBatch = 0,
		TotalBatchSeconds = 0,
		MaxBatchSeconds = 0,
		DebugBatches = 0,
		DebugRequested = 0,
		DebugSpawned = 0,
		DebugTotalSeconds = 0,
		DebugMaxSeconds = 0,
		Fallbacks = 0,
		Recycled = 0,
		RecycleCandidates = 0,
	}
end

local spawnActivity = createSpawnActivity()

local function getPendingDebugSpawnCount()
	local pendingCount = 0

	for _, request in pairs(pendingDebugSpawnsByUserId) do
		pendingCount += math.max(0, request.Remaining or 0)
	end

	return pendingCount
end

local function getPendingWaveSpawnCount()
	local pendingCount = 0

	for _, request in pairs(pendingWaveSpawnsByUserId) do
		pendingCount += math.max(0, request.Remaining or 0)
	end

	return pendingCount
end

local function recordWaveSpawnBatch(requestedCount, spawnedCount, elapsedSeconds)
	spawnActivity.Batches += 1
	spawnActivity.Requested += requestedCount
	spawnActivity.Spawned += spawnedCount
	spawnActivity.LargestRequestedBatch = math.max(spawnActivity.LargestRequestedBatch, requestedCount)
	spawnActivity.LargestSpawnedBatch = math.max(spawnActivity.LargestSpawnedBatch, spawnedCount)
	spawnActivity.TotalBatchSeconds += elapsedSeconds
	spawnActivity.MaxBatchSeconds = math.max(spawnActivity.MaxBatchSeconds, elapsedSeconds)
end

local function recordDebugSpawnBatch(requestedCount, spawnedCount, elapsedSeconds)
	spawnActivity.DebugBatches += 1
	spawnActivity.DebugRequested += requestedCount
	spawnActivity.DebugSpawned += spawnedCount
	spawnActivity.DebugTotalSeconds += elapsedSeconds
	spawnActivity.DebugMaxSeconds = math.max(spawnActivity.DebugMaxSeconds, elapsedSeconds)
end

local function createSimulationLodCounts(playerTargetCount)
	return {
		Full = 0,
		Reduced = 0,
		Distant = 0,
		Despawned = 0,
		FullSteps = 0,
		ReducedSteps = 0,
		DistantSteps = 0,
		PlayerTargets = playerTargetCount or 0,
	}
end

local lastSimulationLodCounts = createSimulationLodCounts()

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

local statsRemote = getOrCreateRemote("Combat_UpdateStats")
local pickupFeedbackRemote = getOrCreateRemote(PickupFeedbackConfig.RemoteName)

local function getOrCreateFolder(parent, folderName)
	local folder = parent:FindFirstChild(folderName)

	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = folderName
		folder.Parent = parent
	end

	return folder
end

local function setupFolders()
	runtimeFolder = TemplateService.GetCombatRuntimeFolder()
	monsterFolder = TemplateService.GetCombatMonsterFolder()
	poolFolder = getOrCreateFolder(ServerStorage, "MonsterPools")
end

local function createFallbackMonsterTemplate(templateStorage, templateName)
	local part = Instance.new("Part")
	part.Name = templateName or CombatConfig.MonsterTemplateName
	part.Size = Vector3.new(3, 4, 3)
	part.Color = Color3.fromRGB(190, 55, 55)
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = CombatConfig.MonsterPartsCanCollide == true
	part.CanTouch = CombatConfig.MonsterPartsCanTouch == true
	part.CanQuery = CombatConfig.MonsterPartsCanQuery == true
	part.Parent = templateStorage

	DebugLog.Warn("Combat", "Template monstre introuvable, fallback cree", {
		Template = part.Name,
	})

	return part
end

local function findTemplate(templateName, shouldCreateFallback)
	local fallbackFactory = nil

	if shouldCreateFallback then
		fallbackFactory = function(templateStorage)
			return createFallbackMonsterTemplate(templateStorage, templateName)
		end
	end

	return TemplateService.GetTemplate(CombatConfig.TemplateFolderName, templateName, fallbackFactory)
end

local function findRoot(instance)
	if instance:IsA("BasePart") then
		return instance
	end

	if not instance:IsA("Model") then
		return nil
	end

	if instance.PrimaryPart ~= nil then
		return instance.PrimaryPart
	end

	local humanoidRoot = instance:FindFirstChild("HumanoidRootPart", true)

	if humanoidRoot ~= nil and humanoidRoot:IsA("BasePart") then
		instance.PrimaryPart = humanoidRoot
		return humanoidRoot
	end

	local configuredRoot = instance:FindFirstChild(CombatConfig.MonsterRootPartName, true)

	if configuredRoot ~= nil and configuredRoot:IsA("BasePart") then
		instance.PrimaryPart = configuredRoot
		return configuredRoot
	end

	local firstPart = instance:FindFirstChildWhichIsA("BasePart", true)

	if firstPart ~= nil then
		instance.PrimaryPart = firstPart
	end

	return firstPart
end

local function findHumanoid(instance)
	if instance:IsA("Model") then
		return instance:FindFirstChildWhichIsA("Humanoid", true)
	end

	return nil
end

local function findAnimationController(instance)
	if instance:IsA("Model") then
		return instance:FindFirstChildWhichIsA("AnimationController", true)
	end

	return nil
end

local function findAnimationHost(instance)
	local humanoid = findHumanoid(instance)

	if humanoid ~= nil then
		return humanoid
	end

	return findAnimationController(instance)
end

local function findAnimation(instance)
	local configuredAnimation = instance:FindFirstChild(CombatConfig.MonsterAnimationName, true)

	if configuredAnimation ~= nil and configuredAnimation:IsA("Animation") and configuredAnimation.AnimationId ~= "" then
		return configuredAnimation
	end

	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("Animation") and descendant.AnimationId ~= "" then
			return descendant
		end
	end

	return nil
end

local function hasModelAnimationScript(instance)
	local animationScript = instance:FindFirstChild("PlayAnimation", true)

	return animationScript ~= nil and animationScript:IsA("BaseScript")
end

local function resolveProceduralMotion(instance, requestedValue)
	if requestedValue ~= nil then
		return requestedValue == true
	end

	-- Les templates qui portent leur propre script d'animation ne doivent pas etre combines
	-- avec le balancement procedural historique du combat.
	return not hasModelAnimationScript(instance)
end

local function playMonsterAnimation(monster)
	if CombatConfig.MonsterServerAnimationsEnabled ~= true then
		return nil
	end

	local animationHost = findAnimationHost(monster)
	local animation = findAnimation(monster)

	if animation == nil then
		DebugLog.ThrottledWarn("Combat", "monster_animation_missing", 8, "Animation monstre introuvable", {
			Monster = monster,
			ExpectedName = CombatConfig.MonsterAnimationName,
		})
		return nil
	end

	if animationHost == nil then
		DebugLog.ThrottledWarn("Combat", "monster_animation_host_missing", 8, "Support animation monstre introuvable", {
			Monster = monster,
			Expected = "Humanoid ou AnimationController",
		})
		return nil
	end

	local animator = animationHost:FindFirstChildWhichIsA("Animator")

	if animator == nil then
		animator = Instance.new("Animator")
		animator.Parent = animationHost
	end

	local success, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)

	if not success then
		DebugLog.Warn("Combat", "Impossible de charger l'animation du monstre", {
			Error = tostring(track),
			Monster = monster,
			AnimationId = animation.AnimationId,
		})
		return nil
	end

	track.Priority = CombatConfig.MonsterAnimationPriority or Enum.AnimationPriority.Action
	track.Looped = true
	track:Play(0.15, 1, 1)

	DebugLog.Info("Combat", "Animation monstre lancee", {
		Monster = monster,
		Animation = animation,
		AnimationId = animation.AnimationId,
		Priority = tostring(track.Priority),
	})

	return track
end

local function pivotInstance(instance, cframe)
	if instance:IsA("Model") or instance:IsA("BasePart") then
		instance:PivotTo(cframe)
	end
end

local function prepareMonsterInstance(monster, maxHealth)
	local humanoid = findHumanoid(monster)
	local root = findRoot(monster)
	local resolvedMaxHealth = maxHealth or CombatConfig.MonsterHealth

	for _, descendant in ipairs(monster:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = CombatConfig.MonsterPartsCanCollide == true
			descendant.CanTouch = CombatConfig.MonsterPartsCanTouch == true
			descendant.CanQuery = CombatConfig.MonsterPartsCanQuery == true

			-- Le combat deplace les ennemis par PivotTo ; un Humanoid ne doit pas les soumettre a la gravite.
			descendant.Anchored = true
		end
	end

	if monster:IsA("BasePart") then
		monster.Anchored = true
		monster.CanCollide = CombatConfig.MonsterPartsCanCollide == true
		monster.CanTouch = CombatConfig.MonsterPartsCanTouch == true
		monster.CanQuery = CombatConfig.MonsterPartsCanQuery == true
	end

	if humanoid ~= nil then
		humanoid.BreakJointsOnDeath = false
		humanoid.MaxHealth = resolvedMaxHealth
		humanoid.Health = resolvedMaxHealth
		humanoid.WalkSpeed = CombatConfig.MonsterWalkSpeed
		humanoid.AutoRotate = false
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end

	return humanoid, root
end

local function captureOriginalPartColors(monster)
	local originalColors = {}

	if monster:IsA("BasePart") then
		originalColors[monster] = monster.Color
	end

	for _, descendant in ipairs(monster:GetDescendants()) do
		if descendant:IsA("BasePart") then
			originalColors[descendant] = descendant.Color
		end
	end

	return originalColors
end

local function setMonsterPartsColor(monsterState, color)
	for part in pairs(monsterState.OriginalPartColors) do
		if part.Parent ~= nil then
			part.Color = color
		end
	end
end

local function restoreMonsterPartColors(monsterState, flashId)
	if monsterState.IsDead or monsterState.DamageFlashId ~= flashId then
		return
	end

	for part, originalColor in pairs(monsterState.OriginalPartColors) do
		if part.Parent ~= nil then
			part.Color = originalColor
		end
	end
end

local function flashMonsterDamage(monsterState, flashColor)
	if monsterState.OriginalPartColors == nil then
		return
	end

	monsterState.DamageFlashId += 1

	local flashId = monsterState.DamageFlashId

	setMonsterPartsColor(monsterState, flashColor or CombatConfig.MonsterDamageFlashColor)

	task.delay(CombatConfig.MonsterDamageFlashDuration, function()
		restoreMonsterPartColors(monsterState, flashId)
	end)
end

local function getCharacterRoot(player)
	local character = player.Character

	if character == nil then
		return nil
	end

	return character:FindFirstChild("HumanoidRootPart")
end

local function getCharacterHumanoid(player)
	local character = player.Character

	if character == nil then
		return nil
	end

	return character:FindFirstChildOfClass("Humanoid")
end

local function isPlayerGrounded(player)
	local humanoid = getCharacterHumanoid(player)

	if humanoid == nil then
		return false
	end

	return humanoid.FloorMaterial ~= Enum.Material.Air
end

local function hasPlayerBeenGroundedLongEnough(player, now)
	if not isPlayerGrounded(player) then
		groundedSinceByUserId[player.UserId] = nil
		DebugLog.ThrottledInfo("Combat", "mob_ground_wait_" .. player.UserId, 2, "Spawn mob en attente sol joueur", {
			Player = player.Name,
		})
		return false
	end

	if groundedSinceByUserId[player.UserId] == nil then
		groundedSinceByUserId[player.UserId] = now
	end

	return now - groundedSinceByUserId[player.UserId] >= CombatConfig.MonsterSpawnGroundedDelay
end

local function isPlayerAlive(player)
	if not RunStateService.IsRunActive(player) then
		return false
	end

	local humanoid = getCharacterHumanoid(player)
	local root = getCharacterRoot(player)

	return humanoid ~= nil and root ~= nil and humanoid.Health > 0
end

local function getAliveMonsterCount()
	local count = 0

	for _, monsterState in pairs(monstersByInstance) do
		if not monsterState.IsDead then
			count += 1
		end
	end

	return count
end

local function getAlivePlayerCount()
	local count = 0

	for _, player in ipairs(Players:GetPlayers()) do
		if isPlayerAlive(player) then
			count += 1
		end
	end

	return count
end

local function getRunElapsed()
	return math.max(0, CombatStateService.GetTime() - waveStartedAt)
end

local function isInCalmDifficultyWindow()
	local calmDuration = CombatConfig.DifficultyCalmDuration or 0

	return getRunElapsed() < calmDuration
end

local function getDifficultyMultiplier()
	return math.max(1, 1 + difficultyPercent)
end

local function getCurrentWaveNumber()
	local elapsed = getRunElapsed()

	return math.floor(elapsed / CombatConfig.WaveDuration) + 1
end

local function getCurrentWaveMaxAlive()
	local waveNumber = getCurrentWaveNumber()
	local waveMaxAlive = CombatConfig.WaveBaseMaxAlive
		+ ((waveNumber - 1) * CombatConfig.WaveMaxAliveIncrease)
	local totalPlayerMultiplier = 0
	local activePlayerCount = 0

	for _, player in ipairs(Players:GetPlayers()) do
		if isPlayerAlive(player) then
			activePlayerCount += 1
			totalPlayerMultiplier += PerkService.GetEnemyCountMultiplier(player)
		end
	end

	if activePlayerCount <= 0 then
		return 0
	end

	totalPlayerMultiplier = math.max(1, totalPlayerMultiplier)

	local finalMaxAlive = math.floor(waveMaxAlive * totalPlayerMultiplier)

	if isInCalmDifficultyWindow() then
		finalMaxAlive = math.min(finalMaxAlive, CombatConfig.DifficultyCalmMaxAlive or finalMaxAlive)
	end

	finalMaxAlive = math.ceil(finalMaxAlive * getDifficultyMultiplier())

	return math.min(CombatConfig.MonsterMaxAlive, finalMaxAlive)
end

local function getCurrentWaveSpawnBatch()
	local waveNumber = getCurrentWaveNumber()
	local extraBatch = math.floor((waveNumber - 1) / CombatConfig.WaveSpawnBatchIncreaseEvery)

	if isInCalmDifficultyWindow() then
		return math.max(1, CombatConfig.WaveSpawnBatchBase)
	end

	local spawnBatch = math.max(1, CombatConfig.WaveSpawnBatchBase + extraBatch)

	if CombatConfig.WaveSpawnBatchMax ~= nil then
		spawnBatch = math.min(spawnBatch, CombatConfig.WaveSpawnBatchMax)
	end

	return spawnBatch
end

local function getCurrentSpawnInterval()
	local spawnInterval = CombatConfig.MonsterSpawnInterval

	if isInCalmDifficultyWindow() then
		return math.max(
			CombatConfig.MonsterSpawnIntervalMin or CombatConfig.MonsterSpawnInterval,
			spawnInterval / getDifficultyMultiplier()
		)
	end

	local waveNumber = getCurrentWaveNumber()
	local intervalReduction = (waveNumber - 1) * (CombatConfig.MonsterSpawnIntervalDecreasePerWave or 0)
	spawnInterval = CombatConfig.MonsterSpawnInterval - intervalReduction

	return math.max(
		CombatConfig.MonsterSpawnIntervalMin or CombatConfig.MonsterSpawnInterval,
		spawnInterval / getDifficultyMultiplier()
	)
end

local function getPlayerStatsPayload(player)
	local humanoid = getCharacterHumanoid(player)
	local health = 0
	local maxHealth = 100
	local waveNumber = getCurrentWaveNumber()
	local shield, maxShield = PerkService.GetShieldState(player)

	if humanoid ~= nil then
		health = math.max(0, math.floor(humanoid.Health + 0.5))
		maxHealth = math.max(1, math.floor(humanoid.MaxHealth + 0.5))
	end

	return {
		Health = health,
		MaxHealth = maxHealth,
		Shield = math.floor(shield + 0.5),
		MaxShield = math.floor(maxShield + 0.5),
		AliveMonsters = getAliveMonsterCount(),
		MaxAliveMonsters = getCurrentWaveMaxAlive(),
		Wave = waveNumber,
		Kills = killsByUserId[player.UserId] or 0,
		WeaponName = CombatConfig.FireballTemplateName,
		DifficultyPercent = math.floor((difficultyPercent * 100) + 0.5),
	}
end

local function sendStats(player)
	if player.Parent == Players then
		statsRemote:FireClient(player, getPlayerStatsPayload(player))
	end
end

local function sendStatsToAll()
	for _, player in ipairs(Players:GetPlayers()) do
		sendStats(player)
	end
end

local getLootScatterOffset

local function getSpatialCellSize()
	return math.max(1, CombatConfig.MonsterSpatialCellSize or CombatConfig.MonsterSeparationRadius or 8)
end

-- La grille de ciblage reste large pour les requetes d'armes. La separation
-- utilise sa propre maille, bornee par son rayon, afin de ne pas visiter des
-- voisins qui ne peuvent pas contribuer au deplacement.
local function getSeparationCellSize()
	return math.max(0.5, CombatConfig.MonsterSeparationRadius or 4.5)
end

local function getGridKey(cellX, cellZ)
	return tostring(cellX) .. ":" .. tostring(cellZ)
end

local function getSpatialCell(position, cellSize)
	local resolvedCellSize = cellSize or getSpatialCellSize()

	return math.floor(position.X / resolvedCellSize), math.floor(position.Z / resolvedCellSize)
end

local function removeMonsterFromGrid(grid, key, monsterState)
	if key == nil then
		return
	end

	local cell = grid[key]

	if cell ~= nil then
		cell[monsterState] = nil

		if next(cell) == nil then
			grid[key] = nil
		end
	end
end

local function removeMonsterFromSpatialGrid(monsterState)
	removeMonsterFromGrid(monsterSpatialGrid, monsterState.SpatialGridKey, monsterState)
	removeMonsterFromGrid(monsterSeparationGrid, monsterState.SeparationGridKey, monsterState)

	monsterState.SpatialGridKey = nil
	monsterState.SeparationGridKey = nil
	monsterState.SeparationCellX = nil
	monsterState.SeparationCellZ = nil
end

local function updateMonsterSpatialCell(monsterState, position)
	if position == nil then
		return
	end

	local cellX, cellZ = getSpatialCell(position)
	local key = getGridKey(cellX, cellZ)

	if monsterState.SpatialGridKey ~= key then
		removeMonsterFromGrid(monsterSpatialGrid, monsterState.SpatialGridKey, monsterState)

		local cell = monsterSpatialGrid[key]

		if cell == nil then
			cell = {}
			monsterSpatialGrid[key] = cell
		end

		cell[monsterState] = true
		monsterState.SpatialGridKey = key
	end

	local separationCellX, separationCellZ = getSpatialCell(position, getSeparationCellSize())
	local separationKey = getGridKey(separationCellX, separationCellZ)

	if monsterState.SeparationGridKey ~= separationKey then
		removeMonsterFromGrid(monsterSeparationGrid, monsterState.SeparationGridKey, monsterState)

		local separationCell = monsterSeparationGrid[separationKey]

		if separationCell == nil then
			separationCell = {}
			monsterSeparationGrid[separationKey] = separationCell
		end

		separationCell[monsterState] = true
		monsterState.SeparationGridKey = separationKey
	end

	monsterState.SeparationCellX = separationCellX
	monsterState.SeparationCellZ = separationCellZ
end

local function getMonsterPoolFolder(templateName)
	if poolFolder == nil then
		setupFolders()
	end

	return getOrCreateFolder(poolFolder, templateName)
end

local function getMonsterPoolSize()
	if poolFolder == nil then
		return 0
	end

	local count = 0

	for _, folder in ipairs(poolFolder:GetChildren()) do
		count += #folder:GetChildren()
	end

	return count
end

local function getSpatialGridCellCount()
	local count = 0

	for _ in pairs(monsterSpatialGrid) do
		count += 1
	end

	return count
end

local function getSeparationGridCellCount()
	local count = 0

	for _ in pairs(monsterSeparationGrid) do
		count += 1
	end

	return count
end

local function getGroundSurfaceCacheCellKey(position)
	local cellX, cellZ = getSpatialCell(position, getSeparationCellSize())

	return getGridKey(cellX, cellZ)
end

local function getGroundSurfaceCacheCellCount()
	local count = 0

	for _ in pairs(groundSurfaceCellCache) do
		count += 1
	end

	return count
end

local function getSurfacePivotPosition(monster, surfacePosition)
	if monster:IsA("BasePart") then
		return surfacePosition + Vector3.new(0, (monster.Size.Y * 0.5) + CombatConfig.MonsterSpawnSurfaceOffset, 0)
	end

	local pivot = monster:GetPivot()
	local boundingCFrame, size = monster:GetBoundingBox()
	local bottomY = boundingCFrame.Position.Y - (size.Y * 0.5)
	local pivotToBottomOffset = pivot.Position.Y - bottomY

	return Vector3.new(
		surfacePosition.X,
		surfacePosition.Y + pivotToBottomOffset + CombatConfig.MonsterSpawnSurfaceOffset,
		surfacePosition.Z
	)
end

local function getCachedGroundSurfacePosition(monsterState, candidatePosition)
	local key = getGroundSurfaceCacheCellKey(candidatePosition)
	local cachedSurface = groundSurfaceCellCache[key]

	if cachedSurface == nil then
		return nil
	end

	local surfacePart = cachedSurface.Part

	if surfacePart == nil or surfacePart.Parent == nil then
		groundSurfaceCellCache[key] = nil
		return nil
	end

	local localPosition = surfacePart.CFrame:PointToObjectSpace(candidatePosition)
	local halfSize = surfacePart.Size * 0.5

	if math.abs(localPosition.X) > halfSize.X or math.abs(localPosition.Z) > halfSize.Z then
		groundSurfaceCellCache[key] = nil
		return nil
	end

	local surfacePosition = Vector3.new(candidatePosition.X, cachedSurface.Height, candidatePosition.Z)
	local groundedPosition = getSurfacePivotPosition(monsterState.Template, surfacePosition)
	local verticalTolerance = math.max(2, CombatConfig.MonsterDirectMoveSpeed * 0.25)

	if math.abs(groundedPosition.Y - candidatePosition.Y) > verticalTolerance then
		return nil
	end

	return groundedPosition, surfacePosition
end

local function cacheGroundSurfacePosition(candidatePosition, surfacePosition, surfaceInstance)
	if surfaceInstance == nil or not surfaceInstance:IsA("BasePart") then
		return
	end

	-- Les rampes, les pentes et les pieces physiques restent raycastees exactement.
	if not surfaceInstance.Anchored or not surfaceInstance.CanCollide or surfaceInstance.CFrame.UpVector.Y < 0.999 then
		return
	end

	groundSurfaceCellCache[getGroundSurfaceCacheCellKey(candidatePosition)] = {
		Part = surfaceInstance,
		Height = surfacePosition.Y,
	}
end

local function acquireMonsterInstance(template, templateName)
	local templatePoolFolder = getMonsterPoolFolder(templateName)
	local pooledMonster = templatePoolFolder:FindFirstChild(templateName)

	if pooledMonster == nil then
		pooledMonster = templatePoolFolder:FindFirstChildWhichIsA("Model") or templatePoolFolder:FindFirstChildWhichIsA("BasePart")
	end

	if pooledMonster ~= nil then
		pooledMonster.Parent = monsterFolder
		return pooledMonster, true
	end

	local monster = template:Clone()
	monster.Parent = monsterFolder

	return monster, false
end

local function prewarmMonsterPool(template, templateName, count)
	local prewarmCount = math.max(0, math.floor(count or 0))

	if template == nil or prewarmCount <= 0 then
		return
	end

	local templatePoolFolder = getMonsterPoolFolder(templateName)

	for _ = 1, prewarmCount do
		local monster = template:Clone()
		monster.Name = templateName
		monster.Parent = templatePoolFolder
	end

	DebugLog.Info("Perf", "Pool monstres prechauffe", {
		Template = templateName,
		Count = prewarmCount,
	})
end

local function restoreMonsterColorsNow(monsterState)
	if monsterState.OriginalPartColors == nil then
		return
	end

	for part, originalColor in pairs(monsterState.OriginalPartColors) do
		if part.Parent ~= nil then
			part.Color = originalColor
		end
	end
end

local function resetMonsterAnimators(monster)
	-- Les AnimationTrack restent comptes par Roblox meme apres Stop().
	-- Un ennemi reutilise doit repartir avec un Animator neuf pour eviter
	-- d'atteindre la limite de 64 pistes sur les templates Meshy.
	for _, descendant in ipairs(monster:GetDescendants()) do
		if descendant:IsA("Animator") then
			descendant:Destroy()
		end
	end
end

local function releaseMonsterToPool(monsterState)
	removeMonsterFromSpatialGrid(monsterState)

	if monsterState.AnimationTrack ~= nil then
		pcall(function()
			monsterState.AnimationTrack:Stop(0)
		end)
	end

	if monsterState.DeathConnection ~= nil then
		monsterState.DeathConnection:Disconnect()
		monsterState.DeathConnection = nil
	end

	if monsterState.AncestryConnection ~= nil then
		monsterState.AncestryConnection:Disconnect()
		monsterState.AncestryConnection = nil
	end

	restoreMonsterColorsNow(monsterState)

	local monster = monsterState.Instance

	if monster == nil or monster.Parent == nil then
		return
	end

	monster:SetAttribute("RuntimeMonster", false)
	monster:SetAttribute("IsElite", false)
	monster:SetAttribute("IsBoss", false)
	monster:SetAttribute("BossName", nil)
	monster:SetAttribute("ElitePackId", nil)
	monster:SetAttribute("PoisonStacks", 0)
	monster:SetAttribute("MonsterHealth", 0)

	resetMonsterAnimators(monster)

	local templateName = monsterState.TemplateName or monster.Name or CombatConfig.MonsterTemplateName
	monster.Name = templateName
	monster.Parent = getMonsterPoolFolder(templateName)
end

local function getMonsterLootMultiplier(monsterState)
	if monsterState.DropLoot == false then
		return 0
	end

	if monsterState.IsElite then
		return math.max(1, math.floor(CombatConfig.EliteMonsterLootMultiplier or 2))
	end

	return 1
end

local function updateElitePackAfterRemoval(monsterState, killer, deathPosition)
	local elitePackId = monsterState.ElitePackId

	if not monsterState.IsElite or elitePackId == nil then
		return
	end

	local packState = elitePacksById[elitePackId]

	if packState == nil then
		return
	end

	packState.AliveCount = math.max(0, (packState.AliveCount or 0) - 1)

	if killer ~= nil and killer.Parent == Players then
		packState.KilledCount = (packState.KilledCount or 0) + 1
	end

	if packState.AliveCount <= 0 then
		elitePacksById[elitePackId] = nil

		if killer ~= nil and killer.Parent == Players and deathPosition ~= nil and not packState.RewardSpawned then
			packState.RewardSpawned = true
			ChestService.SpawnRewardChestAtPosition(deathPosition, killer)
			DebugLog.Info("Combat", "Pack elite termine, ChestOpen demande", {
				Player = killer.Name,
				PackId = elitePackId,
				KilledCount = packState.KilledCount,
				DeathPosition = deathPosition,
			})
		end
	end
end

local function removeMonster(monsterState, killer)
	if monsterState.IsDead then
		return
	end

	local deathPosition = nil

	if monsterState.Root ~= nil then
		deathPosition = monsterState.Root.Position
	end

	monsterState.IsDead = true
	monstersByInstance[monsterState.Instance] = nil

	if killer ~= nil and killer.Parent == Players then
		killsByUserId[killer.UserId] = (killsByUserId[killer.UserId] or 0) + 1
		RunAnalyticsService.RecordMonsterKill(killer, monsterState.Instance)
		monsterKilledEvent:Fire(killer, monsterState.Instance)
		getRunItemService().OnMonsterKilled(killer)
		pickupFeedbackRemote:FireClient(killer, {
			Kind = "Kill",
			Amount = 1,
		})

		if deathPosition ~= nil and monsterState.DropLoot ~= false then
			local lootMultiplier = getMonsterLootMultiplier(monsterState)
			local xpDropCount = math.max(1, (CombatConfig.XpGemsPerMonster or 1) * lootMultiplier)

			for _ = 1, xpDropCount do
				XpService.SpawnXpGem(deathPosition + getLootScatterOffset())
			end

			if rng:NextNumber() <= PerkService.GetCoinDropChance(killer, CombatConfig.CoinDropChance) then
				local coinDropCount = rng:NextInteger(CombatConfig.CoinDropsMin, CombatConfig.CoinDropsMax)
					* lootMultiplier

				for _ = 1, coinDropCount do
					CoinService.SpawnCoin(deathPosition + getLootScatterOffset())
				end
			end
		end
	end

	updateElitePackAfterRemoval(monsterState, killer, deathPosition)

	if monsterState.OnDefeated ~= nil then
		task.defer(monsterState.OnDefeated, monsterState.Instance, killer, deathPosition)
	end

	releaseMonsterToPool(monsterState)

	sendStatsToAll()
end

local function getMonsterStateFromInstance(instance)
	local current = instance

	while current ~= nil do
		local monsterState = monstersByInstance[current]

		if monsterState ~= nil then
			return monsterState
		end

		current = current.Parent
	end

	return nil
end

getLootScatterOffset = function()
	local angle = rng:NextNumber(0, math.pi * 2)
	local distance = rng:NextNumber(0, CombatConfig.LootScatterRadius)

	return Vector3.new(math.cos(angle) * distance, 1, math.sin(angle) * distance)
end

local function getAlivePlayerTargets()
	local targets = {}

	for _, player in ipairs(Players:GetPlayers()) do
		if RunStateService.IsRunActive(player) then
			local humanoid = getCharacterHumanoid(player)
			local root = getCharacterRoot(player)

			if humanoid ~= nil and root ~= nil and humanoid.Health > 0 then
				table.insert(targets, {
					Player = player,
					Humanoid = humanoid,
					Root = root,
				})
			end
		end
	end

	return targets
end

local function getClosestAlivePlayer(position, playerTargets)
	local closestPlayer = nil
	local closestRoot = nil
	local closestDistance = math.huge

	for _, target in ipairs(playerTargets or getAlivePlayerTargets()) do
		local distance = (target.Root.Position - position).Magnitude

		if distance < closestDistance then
			closestDistance = distance
			closestPlayer = target.Player
			closestRoot = target.Root
		end
	end

	return closestPlayer, closestRoot, closestDistance
end

local function getPlayerForwardDirection(player, root)
	local humanoid = getCharacterHumanoid(player)

	if humanoid ~= nil then
		local movementDirection = Vector3.new(humanoid.MoveDirection.X, 0, humanoid.MoveDirection.Z)

		if movementDirection.Magnitude > 0.1 then
			return movementDirection.Unit
		end
	end

	local lookVector = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)

	if lookVector.Magnitude > 0.1 then
		return lookVector.Unit
	end

	return Vector3.new(0, 0, -1)
end

local function getDirectionInArc(forwardDirection, arcDegrees)
	local arcRadians = math.rad(math.max(0, arcDegrees or 0))
	local angle = rng:NextNumber(-arcRadians, arcRadians)
	local sideDirection = Vector3.new(-forwardDirection.Z, 0, forwardDirection.X)

	return ((forwardDirection * math.cos(angle)) + (sideDirection * math.sin(angle))).Unit
end

local function getSpawnSurfacePositionNearPlayer(player, options)
	options = options or {}

	local root = getCharacterRoot(player)

	if root == nil then
		return nil
	end

	local attempts = math.max(1, options.Attempts or CombatConfig.MonsterSpawnSurfaceAttempts or 1)
	local minDistance = math.max(0, options.MinDistance or CombatConfig.MonsterMinSpawnDistance)
	local maxDistance = math.max(minDistance, options.MaxDistance or CombatConfig.MonsterMaxSpawnDistance)
	local forwardDirection = getPlayerForwardDirection(player, root)
	local forwardBias = math.clamp(options.ForwardBias or CombatConfig.MonsterSpawnForwardBias or 0, 0, 1)
	local shouldPreferForward = options.PreferForward == true
	local forwardArcDegrees = options.ForwardArcDegrees or options.ArcDegrees or CombatConfig.MonsterSpawnForwardArcDegrees

	local function findSurfaceInRange(rangeMinDistance, rangeMaxDistance, rangeAttempts)
		for _ = 1, rangeAttempts do
			local useForwardDirection = shouldPreferForward or rng:NextNumber() <= forwardBias
			local randomAngle = rng:NextNumber(0, math.pi * 2)
			local direction = if useForwardDirection
				then getDirectionInArc(forwardDirection, forwardArcDegrees)
				else Vector3.new(math.cos(randomAngle), 0, math.sin(randomAngle))
			local distance = rng:NextNumber(rangeMinDistance, rangeMaxDistance)
			local samplePosition = root.Position + (direction * distance)

			if not WorldSpawnService.IsInsideActivePlayableBounds(samplePosition, CombatConfig.MonsterSpawnMapEdgeInset) then
				continue
			end

			local surfacePosition = WorldSpawnService.FindSurfacePositionAtXZ(samplePosition.X, samplePosition.Z, {
				Center = root.Position,
				RaycastHeight = CombatConfig.MonsterGroundRaycastHeight,
				RaycastDepth = CombatConfig.MonsterGroundRaycastDepth,
				MinSurfaceNormalY = 0.65,
				ExcludeInstances = { player.Character, runtimeFolder },
				AllowWorkspaceSurfaceFallback = true,
				TelemetryTag = "Monster.Spawn",
			})

			if surfacePosition ~= nil then
				return surfacePosition
			end
		end

		return nil
	end

	local primarySurfacePosition = findSurfaceInRange(minDistance, maxDistance, attempts)

	if primarySurfacePosition ~= nil then
		return primarySurfacePosition, false
	end

	if options.AllowFallback == false then
		return nil, false
	end

	local fallbackMinDistance = math.max(0, CombatConfig.MonsterSpawnFallbackMinDistance or 0)
	local fallbackMaxDistance = math.max(fallbackMinDistance, CombatConfig.MonsterSpawnFallbackMaxDistance or fallbackMinDistance)
	local fallbackAttempts = math.max(1, CombatConfig.MonsterSpawnFallbackAttempts or attempts)
	local fallbackSurfacePosition = findSurfaceInRange(fallbackMinDistance, fallbackMaxDistance, fallbackAttempts)

	return fallbackSurfacePosition, fallbackSurfacePosition ~= nil
end

local function getHorizontalDistance(firstPosition, secondPosition)
	return (Vector2.new(firstPosition.X, firstPosition.Z) - Vector2.new(secondPosition.X, secondPosition.Z)).Magnitude
end

local function getGroundedMonsterPosition(monsterState, candidatePosition, now)
	local telemetryStartedAt = if activeSimulationTelemetry ~= nil then os.clock() else nil
	local lastSamplePosition = monsterState.LastGroundSamplePosition
	local lastSampleAt = monsterState.LastGroundSampleAt or 0
	local sampleDistance = math.max(0.25, CombatConfig.MonsterGroundFollowSampleDistance or 1)
	local sampleInterval = math.max(0.03, CombatConfig.MonsterGroundFollowMaxInterval or 0.1)

	if lastSamplePosition ~= nil
		and getHorizontalDistance(candidatePosition, lastSamplePosition) < sampleDistance
		and now - lastSampleAt < sampleInterval
	then
		addSimulationTelemetry("GroundCacheHits", 1)
		if telemetryStartedAt ~= nil then
			addSimulationTelemetry("GroundFollowSeconds", os.clock() - telemetryStartedAt)
		end
		return Vector3.new(candidatePosition.X, monsterState.BasePosition.Y, candidatePosition.Z)
	end

	addSimulationTelemetry("GroundSamples", 1)

	local cachedGroundPosition, cachedSurfacePosition = getCachedGroundSurfacePosition(monsterState, candidatePosition)

	if cachedGroundPosition ~= nil then
		addSimulationTelemetry("GroundSharedSurfaceCacheHits", 1)
		monsterState.LastGroundSamplePosition = cachedSurfacePosition
		monsterState.LastGroundSampleAt = now

		if telemetryStartedAt ~= nil then
			addSimulationTelemetry("GroundFollowSeconds", os.clock() - telemetryStartedAt)
		end

		return cachedGroundPosition
	end

	local surfacePosition, surfaceInstance = WorldSpawnService.FindSurfacePositionAtXZ(candidatePosition.X, candidatePosition.Z, {
		Center = candidatePosition,
		RaycastHeight = CombatConfig.MonsterGroundRaycastHeight,
		RaycastDepth = CombatConfig.MonsterGroundRaycastDepth,
		MinSurfaceNormalY = CombatConfig.MonsterGroundFollowMinNormalY,
		AllowGeneratedRampSurface = true,
		ExcludeInstances = { monsterFolder },
		AllowWorkspaceSurfaceFallback = true,
		TelemetryTag = "Monster.Ground",
	})

	if surfacePosition == nil then
		if telemetryStartedAt ~= nil then
			addSimulationTelemetry("GroundFollowSeconds", os.clock() - telemetryStartedAt)
		end
		return nil
	end

	monsterState.LastGroundSamplePosition = surfacePosition
	monsterState.LastGroundSampleAt = now
	cacheGroundSurfacePosition(candidatePosition, surfacePosition, surfaceInstance)
	local groundedPosition = getSurfacePivotPosition(monsterState.Template, surfacePosition)

	if telemetryStartedAt ~= nil then
		addSimulationTelemetry("GroundFollowSeconds", os.clock() - telemetryStartedAt)
	end

	return groundedPosition
end

local function spawnMonsterAtSurface(surfacePosition, options)
	options = options or {}

	local template = options.Template or monsterTemplate
	local templateName = options.TemplateName or CombatConfig.MonsterTemplateName
	local healthMultiplier = options.HealthMultiplier or 1
	local damageMultiplier = options.DamageMultiplier or 1
	local maxHealth = math.max(
		1,
		math.floor(options.MaxHealth or ((CombatConfig.MonsterHealth * healthMultiplier) + 0.5))
	)
	local attackDamage = math.max(0, options.AttackDamage or (CombatConfig.MonsterAttackDamage * damageMultiplier))
	local isElite = options.IsElite == true
	local isBoss = options.IsBoss == true
	local elitePackId = options.ElitePackId
	local speedMultiplier = math.max(0.1, options.SpeedMultiplier or 1)

	if template == nil or surfacePosition == nil then
		DebugLog.Warn("Combat", "Spawn monstre impossible", {
			TemplateName = templateName,
			HasTemplate = template ~= nil,
			SurfacePosition = surfacePosition,
			Reason = if template == nil then "TemplateMissing" else "SurfaceMissing",
			IsElite = isElite,
			IsBoss = isBoss,
		})
		return false
	end

	local monster, reusedFromPool = acquireMonsterInstance(template, templateName)
	local useProceduralMotion = resolveProceduralMotion(monster, options.UseProceduralMotion)

	monster.Name = templateName
	monster:SetAttribute("RuntimeMonster", true)
	monster:SetAttribute("IsElite", isElite)
	monster:SetAttribute("IsBoss", isBoss)
	monster:SetAttribute("BossName", options.BossName)
	monster:SetAttribute("MonsterMaxHealth", maxHealth)
	monster:SetAttribute("MonsterHealth", maxHealth)
	monster:SetAttribute("MonsterAttackDamage", attackDamage)
	monster:SetAttribute("ElitePackId", elitePackId)

	local humanoid, root = prepareMonsterInstance(monster, maxHealth)

	if humanoid ~= nil then
		humanoid.WalkSpeed *= speedMultiplier
	end

	if root == nil then
		DebugLog.Warn("Combat", "Monstre sans BasePart, spawn annule", {
			Monster = monster,
			TemplateName = templateName,
			IsElite = isElite,
		})
		monster:Destroy()
		return false
	end

	-- Le pool conserve la derniere rotation runtime. Le template reste la source de verite
	-- afin qu'un monstre reutilise ne cumule jamais son ancienne orientation.
	local pivotRotation = WorldSpawnService.GetPivotRotation(template)
	local spawnPivotPosition = getSurfacePivotPosition(template, surfacePosition)

	pivotInstance(monster, WorldSpawnService.GetPivotCFrameAtPosition(template, spawnPivotPosition))

	local monsterState = {
		Instance = monster,
		Template = template,
		Humanoid = humanoid,
		Root = root,
		TemplateName = templateName,
		BasePosition = spawnPivotPosition,
		LastGroundSamplePosition = surfacePosition,
		LastGroundSampleAt = CombatStateService.GetTime(),
		PivotRotation = pivotRotation,
		Health = maxHealth,
		AttackDamage = attackDamage,
		SpeedMultiplier = speedMultiplier,
		UseProceduralMotion = useProceduralMotion,
		IsElite = isElite,
		IsBoss = isBoss,
		BossName = options.BossName,
		ElitePackId = elitePackId,
		MaxHealth = maxHealth,
		DropLoot = options.DropLoot,
		OnDefeated = options.OnDefeated,
		OnHealthChanged = options.OnHealthChanged,
		AnimationTrack = playMonsterAnimation(monster),
		AnimationTime = rng:NextNumber(0, 10),
		LastDamageByUserId = {},
		SpawnedAt = CombatStateService.GetTime(),
		LastDamagedAt = CombatStateService.GetTime(),
		LastLodUpdateAt = CombatStateService.GetTime(),
		OriginalPartColors = captureOriginalPartColors(monster),
		DamageFlashId = 0,
		IsDead = false,
		ReusedFromPool = reusedFromPool,
	}

	monstersByInstance[monster] = monsterState
	updateMonsterSpatialCell(monsterState, spawnPivotPosition)

	monsterState.AncestryConnection = monster.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			removeMonsterFromSpatialGrid(monsterState)
			monstersByInstance[monster] = nil
		end
	end)

	if humanoid ~= nil then
		monsterState.DeathConnection = humanoid.Died:Connect(function()
			removeMonster(monsterState, monsterState.PendingKiller)
		end)
	end

	return true, monster, spawnPivotPosition, monsterState
end

local function spawnMonsterNearPlayer(player, spawnOptions)
	if monsterTemplate == nil or not isPlayerAlive(player) then
		DebugLog.ThrottledWarn("Combat", "mob_spawn_blocked_" .. player.UserId, 2, "Spawn mob bloque", {
			Player = player.Name,
			HasTemplate = monsterTemplate ~= nil,
			PlayerAlive = isPlayerAlive(player),
		})
		return false
	end

	local spawnSurfacePosition, usedFallback = getSpawnSurfacePositionNearPlayer(player, spawnOptions)

	if spawnSurfacePosition == nil then
		DebugLog.ThrottledWarn("Combat", "mob_no_surface_" .. player.UserId, 2, "Aucune surface trouvee pour spawn mob", {
			Player = player.Name,
			Root = getCharacterRoot(player),
			RaycastHeight = CombatConfig.MonsterGroundRaycastHeight,
			RaycastDepth = CombatConfig.MonsterGroundRaycastDepth,
			Attempts = (spawnOptions and spawnOptions.Attempts) or CombatConfig.MonsterSpawnSurfaceAttempts,
		})
		return false
	end

	if usedFallback then
		spawnActivity.Fallbacks += 1
	end

	local didSpawn, _, spawnPivotPosition = spawnMonsterAtSurface(spawnSurfacePosition, {
		Template = monsterTemplate,
		TemplateName = CombatConfig.MonsterTemplateName,
		Player = player,
	})

	if not didSpawn then
		return false
	end

	DebugLog.ThrottledInfo("Combat", "mob_spawn_success", 1.5, "Monstre genere", {
		Player = player.Name,
		Position = spawnPivotPosition,
		Alive = getAliveMonsterCount(),
		Wave = getCurrentWaveNumber(),
	})

	return true
end

local function getMonsterSeparation(monsterState)
	local telemetryStartedAt = if activeSimulationTelemetry ~= nil then os.clock() else nil
	local neighborCandidates = 0
	local neighborsInRadius = 0
	local root = monsterState.Root

	if root == nil or monsterState.SeparationCellX == nil or monsterState.SeparationCellZ == nil then
		return Vector3.zero
	end

	local radius = CombatConfig.MonsterSeparationRadius
	local separation = Vector3.zero

	for offsetX = -1, 1 do
		for offsetZ = -1, 1 do
			local key = getGridKey(monsterState.SeparationCellX + offsetX, monsterState.SeparationCellZ + offsetZ)
			local cell = monsterSeparationGrid[key]

			if cell ~= nil then
				for otherState in pairs(cell) do
					if otherState ~= monsterState and not otherState.IsDead and otherState.Root ~= nil then
						if telemetryStartedAt ~= nil then
							neighborCandidates += 1
						end

						local offset = root.Position - otherState.Root.Position
						local horizontalOffset = Vector3.new(offset.X, 0, offset.Z)
						local distance = horizontalOffset.Magnitude

						if distance > 0.05 and distance < radius then
							if telemetryStartedAt ~= nil then
								neighborsInRadius += 1
							end

							separation += horizontalOffset.Unit * ((radius - distance) / radius)
						elseif distance <= 0.05 then
							if telemetryStartedAt ~= nil then
								neighborsInRadius += 1
							end

							local randomAngle = rng:NextNumber(0, math.pi * 2)
							separation += Vector3.new(math.cos(randomAngle), 0, math.sin(randomAngle))
						end
					end
				end
			end
		end
	end

	if telemetryStartedAt ~= nil then
		addSimulationTelemetry("SeparationQueries", 1)
		addSimulationTelemetry("SeparationNeighborCandidates", neighborCandidates)
		addSimulationTelemetry("SeparationNeighborsInRadius", neighborsInRadius)
		addSimulationTelemetry("SeparationSeconds", os.clock() - telemetryStartedAt)
	end

	return separation
end

local function getMoveDirection(fromPosition, targetPosition, separation)
	local targetOffset = targetPosition - fromPosition
	local horizontalTargetOffset = Vector3.new(targetOffset.X, 0, targetOffset.Z)

	if horizontalTargetOffset.Magnitude <= 0.1 then
		return Vector3.zero
	end

	local desiredDirection = horizontalTargetOffset.Unit

	if separation.Magnitude > 0 then
		desiredDirection += separation * CombatConfig.MonsterSeparationStrength
	end

	if desiredDirection.Magnitude <= 0.1 then
		return horizontalTargetOffset.Unit
	end

	return desiredDirection.Unit
end

local function getTerrainMoveDirection(monsterState, position, requestedDirection, targetPosition, step, now)
	if CombatConfig.MonsterTerrainAvoidanceEnabled ~= true then
		return requestedDirection
	end

	local interval = math.max(0.03, CombatConfig.MonsterTerrainAvoidanceInterval or 0.1)
	local shouldSample = now - (monsterState.LastTerrainAvoidanceAt or 0) >= interval

	if shouldSample then
		local telemetryStartedAt = if activeSimulationTelemetry ~= nil then os.clock() else nil
		monsterState.LastTerrainAvoidanceAt = now
		addSimulationTelemetry("TerrainAvoidanceSamples", 1)
		local barrier = WorldSpawnService.FindGeneratedTerrainBarrier(
			position,
			requestedDirection,
			step + math.max(0, CombatConfig.MonsterTerrainAvoidanceLookahead or 0),
			{
				Height = CombatConfig.MonsterTerrainAvoidanceHeight,
				TelemetryTag = "Monster.Avoidance",
			}
		)

		if barrier == nil then
			monsterState.TerrainAvoidanceDirection = nil
		else
			local tangent = Vector3.new(-barrier.Normal.Z, 0, barrier.Normal.X)
			local targetOffset = Vector3.new(targetPosition.X - position.X, 0, targetPosition.Z - position.Z)

			if tangent.Magnitude > 0.01 and targetOffset.Magnitude > 0.01 then
				tangent = tangent.Unit

				if tangent:Dot(targetOffset.Unit) < 0 then
					tangent = -tangent
				end

				monsterState.TerrainAvoidanceDirection = tangent
			else
				monsterState.TerrainAvoidanceDirection = nil
			end
		end

		if telemetryStartedAt ~= nil then
			addSimulationTelemetry("TerrainAvoidanceSeconds", os.clock() - telemetryStartedAt)
		end
	end

	return monsterState.TerrainAvoidanceDirection or requestedDirection
end

local function getProceduralAnimationCFrame(monsterState, position, moveDirection, deltaTime)
	monsterState.AnimationTime += deltaTime

	local bob = math.sin(monsterState.AnimationTime * 8) * CombatConfig.MonsterProceduralBobHeight
	local sway = math.sin(monsterState.AnimationTime * 7) * math.rad(CombatConfig.MonsterProceduralSwayDegrees)
	local visualPosition = position + Vector3.new(0, bob, 0)
	local lookTarget = visualPosition + moveDirection
	local pivotRotation = monsterState.PivotRotation or CFrame.new()

	return CFrame.lookAt(visualPosition, lookTarget) * CFrame.Angles(0, 0, sway) * pivotRotation
end

local function updateMonsterMovement(monsterState, targetRoot, distance, deltaTime, useSeparation, useProceduralMotion, now)
	local root = monsterState.Root

	if root == nil then
		removeMonster(monsterState, nil)
		return false
	end

	if targetRoot == nil then
		return true
	end

	if distance > CombatConfig.MonsterDespawnDistance then
		removeMonster(monsterState, nil)
		return false
	end

	local separation = if useSeparation then getMonsterSeparation(monsterState) else Vector3.zero

	local basePosition = monsterState.BasePosition or root.Position
	local directionStartedAt = if activeSimulationTelemetry ~= nil then os.clock() else nil
	local moveDirection = getMoveDirection(basePosition, targetRoot.Position, separation)

	if directionStartedAt ~= nil then
		addSimulationTelemetry("MoveDirectionSeconds", os.clock() - directionStartedAt)
	end

	if moveDirection.Magnitude <= 0.1 then
		return true
	end

	local targetDistance = (Vector3.new(targetRoot.Position.X, 0, targetRoot.Position.Z) - Vector3.new(basePosition.X, 0, basePosition.Z)).Magnitude
	local speedMultiplier = monsterState.SpeedMultiplier or 1
	local step = math.min(targetDistance, CombatConfig.MonsterDirectMoveSpeed * speedMultiplier * deltaTime)
	moveDirection = getTerrainMoveDirection(monsterState, basePosition, moveDirection, targetRoot.Position, step, now)
	local horizontalCandidate = basePosition + (moveDirection * step)
	local nextPosition = getGroundedMonsterPosition(monsterState, horizontalCandidate, now)

	if nextPosition == nil then
		-- Sans sol valide, le monstre s'arrete plutot que de traverser un volume ou le vide.
		return true
	end

	monsterState.BasePosition = nextPosition

	local transformStartedAt = if activeSimulationTelemetry ~= nil then os.clock() else nil
	local targetCFrame

	if monsterState.UseProceduralMotion ~= true or useProceduralMotion ~= true then
		local lookTarget = nextPosition + moveDirection
		local pivotRotation = monsterState.PivotRotation or CFrame.new()
		targetCFrame = CFrame.lookAt(nextPosition, lookTarget) * pivotRotation
	else
		targetCFrame = getProceduralAnimationCFrame(monsterState, nextPosition, moveDirection, deltaTime)
	end

	if transformStartedAt ~= nil then
		addSimulationTelemetry("VisualTransformSeconds", os.clock() - transformStartedAt)
	end

	local pivotStartedAt = if activeSimulationTelemetry ~= nil then os.clock() else nil
	pivotInstance(monsterState.Instance, targetCFrame)

	if pivotStartedAt ~= nil then
		addSimulationTelemetry("PivotSeconds", os.clock() - pivotStartedAt)
	end

	local gridUpdateStartedAt = if activeSimulationTelemetry ~= nil then os.clock() else nil
	updateMonsterSpatialCell(monsterState, nextPosition)

	if gridUpdateStartedAt ~= nil then
		addSimulationTelemetry("SpatialGridUpdateSeconds", os.clock() - gridUpdateStartedAt)
	end
	return true
end

local function updateMonsterDamage(monsterState, now, playerTargets)
	if benchmarkMode then
		return
	end

	local root = monsterState.Root

	if root == nil then
		return
	end

	for _, target in ipairs(playerTargets) do
		local distance = (target.Root.Position - root.Position).Magnitude

		if distance <= CombatConfig.MonsterAttackRange then
			local player = target.Player
			local lastDamageAt = monsterState.LastDamageByUserId[player.UserId] or 0

			if now - lastDamageAt >= CombatConfig.MonsterAttackCooldown then
				monsterState.LastDamageByUserId[player.UserId] = now

				local attackDamage = monsterState.AttackDamage or CombatConfig.MonsterAttackDamage
				local finalDamage, shieldAbsorbed = PerkService.CalculateIncomingDamage(player, attackDamage)

				if finalDamage > 0 then
					target.Humanoid:TakeDamage(finalDamage)
				end

				RunAnalyticsService.RecordDamageTaken(player, finalDamage, shieldAbsorbed)
				sendStats(player)
			end
		end
	end
end

local function getMonsterSimulationLod(monsterState, distance)
	if monsterState.IsBoss == true then
		return "Full"
	end

	local fullDistance = math.max(0, CombatConfig.MonsterFullSimulationDistance or CombatConfig.FireballRange or 90)
	local reducedDistance = math.max(
		fullDistance,
		CombatConfig.MonsterReducedSimulationDistance or CombatConfig.MonsterDespawnDistance
	)

	if distance <= fullDistance then
		return "Full"
	end

	if distance <= reducedDistance then
		return "Reduced"
	end

	return "Distant"
end

local function getLodInterval(lod)
	if lod == "Reduced" then
		return 1 / math.max(1, CombatConfig.MonsterReducedSimulationHz or 10)
	end

	if lod == "Distant" then
		return 1 / math.max(1, CombatConfig.MonsterDistantSimulationHz or 2)
	end

	return 0
end

local function getLodStepDelta(monsterState, lod, now, frameDelta)
	if lod == "Full" then
		monsterState.LastLodUpdateAt = now
		return frameDelta
	end

	local interval = getLodInterval(lod)
	local lastUpdateAt = monsterState.LastLodUpdateAt or now
	local elapsed = now - lastUpdateAt

	if elapsed < interval then
		return nil
	end

	monsterState.LastLodUpdateAt = now
	return elapsed
end

local function isMonsterAtFullHealth(monsterState)
	if monsterState.Humanoid ~= nil then
		return monsterState.Humanoid.Health >= monsterState.MaxHealth
	end

	return monsterState.Health >= monsterState.MaxHealth
end

local function getBehindMassCandidates(player, now)
	local root = getCharacterRoot(player)

	if root == nil then
		return {}
	end

	local forwardDirection = getPlayerForwardDirection(player, root)
	local minDistance = math.max(0, CombatConfig.MonsterRecycleMinBehindDistance or 0)
	local maxDistance = math.max(minDistance, CombatConfig.MonsterRecycleMaxBehindDistance or minDistance)
	local undamagedSeconds = math.max(0, CombatConfig.MonsterRecycleUndamagedSeconds or 0)
	local behindDotThreshold = CombatConfig.MonsterRecycleBehindDotThreshold or -0.35
	local candidates = {}

	for _, monsterState in pairs(monstersByInstance) do
		local monsterRoot = monsterState.Root

		if
			not monsterState.IsDead
			and not monsterState.IsElite
			and not monsterState.IsBoss
			and monsterRoot ~= nil
			and isMonsterAtFullHealth(monsterState)
			and now - (monsterState.LastDamagedAt or monsterState.SpawnedAt or now) >= undamagedSeconds
		then
			local horizontalOffset = Vector3.new(
				monsterRoot.Position.X - root.Position.X,
				0,
				monsterRoot.Position.Z - root.Position.Z
			)
			local distance = horizontalOffset.Magnitude

			if distance >= minDistance and distance <= maxDistance then
				local directionToMonster = horizontalOffset.Unit

				if forwardDirection:Dot(directionToMonster) <= behindDotThreshold then
					table.insert(candidates, {
						State = monsterState,
						Distance = distance,
						BehindDot = forwardDirection:Dot(directionToMonster),
					})
				end
			end
		end
	end

	table.sort(candidates, function(a, b)
		return a.Distance > b.Distance
	end)

	return candidates
end

local function recycleMonsterAhead(monsterState, surfacePosition, now)
	local monster = monsterState.Instance
	local template = monsterState.Template or monsterTemplate

	if monster == nil or monster.Parent == nil or template == nil then
		return false
	end

	local spawnPivotPosition = getSurfacePivotPosition(template, surfacePosition)

	monsterState.BasePosition = spawnPivotPosition
	monsterState.PivotRotation = WorldSpawnService.GetPivotRotation(template)
	monsterState.LastDamagedAt = now
	monsterState.LastRecycledAt = now
	monsterState.LastLodUpdateAt = now
	pivotInstance(monster, WorldSpawnService.GetPivotCFrameAtPosition(template, spawnPivotPosition))
	updateMonsterSpatialCell(monsterState, spawnPivotPosition)

	return true
end

local function tryRecycleBehindMass(player, now)
	local userId = player.UserId
	local checkInterval = math.max(0.1, CombatConfig.MonsterRecycleCheckInterval or 1.5)
	local cooldown = math.max(0, CombatConfig.MonsterRecycleCooldown or 4)
	local lastCheckAt = lastRecycleCheckAtByUserId[userId] or 0

	if now - lastCheckAt < checkInterval then
		return
	end

	lastRecycleCheckAtByUserId[userId] = now

	if now - (lastRecycleAtByUserId[userId] or 0) < cooldown then
		return
	end

	local candidates = getBehindMassCandidates(player, now)
	local minimumCount = math.max(1, CombatConfig.MonsterRecycleMinimumBacklineCount or 1)

	if #candidates < minimumCount then
		return
	end

	spawnActivity.RecycleCandidates += #candidates

	local maxToRecycle = math.min(#candidates, math.max(1, CombatConfig.MonsterRecycleBatchSize or 1))
	local recycledCount = 0

	for index = 1, maxToRecycle do
		local surfacePosition = getSpawnSurfacePositionNearPlayer(player, {
			PreferForward = true,
			ForwardBias = 1,
			MinDistance = CombatConfig.MonsterRecycleSpawnMinDistance,
			MaxDistance = CombatConfig.MonsterRecycleSpawnMaxDistance,
			ArcDegrees = CombatConfig.MonsterRecycleSpawnArcDegrees,
			Attempts = CombatConfig.MonsterSpawnSurfaceAttempts,
			AllowFallback = false,
		})

		if surfacePosition ~= nil and recycleMonsterAhead(candidates[index].State, surfacePosition, now) then
			recycledCount += 1
		end
	end

	if recycledCount <= 0 then
		return
	end

	lastRecycleAtByUserId[userId] = now
	spawnActivity.Recycled += recycledCount
	DebugLog.ThrottledInfo("Combat", "rear_mass_recycled_" .. userId, cooldown, "Masse arriere recyclee devant le joueur", {
		Player = player.Name,
		Candidates = #candidates,
		Recycled = recycledCount,
		Wave = getCurrentWaveNumber(),
	})
end

local function updateSpawns(now)
	if benchmarkMode then
		return
	end

	local maxAliveMonsters = getCurrentWaveMaxAlive()

	for _, player in ipairs(Players:GetPlayers()) do
		if isPlayerAlive(player) and hasPlayerBeenGroundedLongEnough(player, now) then
			local recycleStartedAt = if activeSimulationTelemetry ~= nil then os.clock() else nil
			tryRecycleBehindMass(player, now)
			if recycleStartedAt ~= nil then
				addSimulationTelemetry("RecycleSeconds", os.clock() - recycleStartedAt)
			end

			if getAliveMonsterCount() >= maxAliveMonsters then
				continue
			end

			local lastSpawnAt = lastSpawnAtByUserId[player.UserId] or 0
			local spawnInterval = getCurrentSpawnInterval()

			if now - lastSpawnAt >= spawnInterval then
				lastSpawnAtByUserId[player.UserId] = now

				local requestedSpawnCount = math.max(
					1,
					math.floor(getCurrentWaveSpawnBatch() * PerkService.GetEnemyCountMultiplier(player))
				)
				local availableCapacity = math.max(
					0,
					maxAliveMonsters - getAliveMonsterCount() - getPendingWaveSpawnCount()
				)
				local pendingRequest = pendingWaveSpawnsByUserId[player.UserId]
				local queuedCount = math.min(requestedSpawnCount, availableCapacity)

				if queuedCount > 0 then
					if pendingRequest == nil then
						pendingRequest = {
							Player = player,
							Remaining = 0,
						}
						pendingWaveSpawnsByUserId[player.UserId] = pendingRequest
					end

					pendingRequest.Remaining += queuedCount
				end
			end
		end
	end
end

local function updateQueuedWaveSpawns()
	if benchmarkMode then
		return
	end

	if waveSpawnDispatchAllowance <= 0 then
		return
	end

	local maxAliveMonsters = getCurrentWaveMaxAlive()

	for userId, request in pairs(pendingWaveSpawnsByUserId) do
		local player = request.Player

		if player.Parent ~= Players or not isPlayerAlive(player) then
			pendingWaveSpawnsByUserId[userId] = nil
			continue
		end

		local availableCapacity = math.max(0, maxAliveMonsters - getAliveMonsterCount())

		if availableCapacity <= 0 then
			continue
		end

		local requestedInBatch = math.min(request.Remaining, waveSpawnDispatchAllowance, availableCapacity)
		local spawnedInBatch = 0
		local startedAt = os.clock()

		for _ = 1, requestedInBatch do
			if spawnMonsterNearPlayer(player) then
				spawnedInBatch += 1
			else
				spawnActivity.Failed += 1
			end
		end

		request.Remaining -= requestedInBatch
		waveSpawnDispatchAllowance -= requestedInBatch
		local waveSpawnSeconds = os.clock() - startedAt
		recordWaveSpawnBatch(requestedInBatch, spawnedInBatch, waveSpawnSeconds)

		if activeSimulationTelemetry ~= nil then
			addSimulationTelemetry("WaveSpawnSeconds", waveSpawnSeconds)
		end

		if request.Remaining <= 0 then
			pendingWaveSpawnsByUserId[userId] = nil
		end

		if waveSpawnDispatchAllowance <= 0 then
			break
		end
	end
end

local function updateQueuedDebugSpawns(now)
	if benchmarkMode then
		return
	end

	for userId, request in pairs(pendingDebugSpawnsByUserId) do
		local player = request.Player

		if player.Parent ~= Players or not isPlayerAlive(player) then
			pendingDebugSpawnsByUserId[userId] = nil
			DebugLog.Info("Combat", "Spawn debug annule", {
				Player = player.Name,
				Reason = "PlayerUnavailable",
				Spawned = request.Spawned,
				Remaining = request.Remaining,
			})
			continue
		end

		if now < request.NextBatchAt then
			continue
		end

		local availableCapacity = math.max(0, CombatConfig.MonsterMaxAlive - getAliveMonsterCount())

		if availableCapacity <= 0 then
			request.NextBatchAt = now + request.BatchInterval
			continue
		end

		local requestedInBatch = math.min(request.Remaining, request.BatchSize, availableCapacity)
		local spawnedInBatch = 0
		local attempts = 0
		local maxAttempts = math.max(requestedInBatch * 5, requestedInBatch)
		local startedAt = os.clock()

		while spawnedInBatch < requestedInBatch and attempts < maxAttempts do
			attempts += 1

			if spawnMonsterNearPlayer(player) then
				spawnedInBatch += 1
			end
		end

		request.Remaining -= requestedInBatch
		request.Spawned += spawnedInBatch
		request.NextBatchAt = now + request.BatchInterval
		recordDebugSpawnBatch(requestedInBatch, spawnedInBatch, os.clock() - startedAt)

		if request.Remaining <= 0 then
			pendingDebugSpawnsByUserId[userId] = nil

			if request.Spawned > 0 then
				sendStatsToAll()
			end

			DebugLog.Info("Combat", "Spawn debug termine", {
				Player = player.Name,
				Requested = request.Requested,
				Spawned = request.Spawned,
			})
		end
	end
end

local function updateMonsterStep(deltaTime)
	local now = CombatStateService.GetTime()
	local startedAt = os.clock()
	local simulationTelemetry = if PerformanceTelemetryService.IsCapturing() then {} else nil
	activeSimulationTelemetry = simulationTelemetry
	local playerTargetsStartedAt = if simulationTelemetry ~= nil then os.clock() else nil
	local playerTargets = getAlivePlayerTargets()
	if playerTargetsStartedAt ~= nil then
		addSimulationTelemetry("PlayerTargetCollectionSeconds", os.clock() - playerTargetsStartedAt)
	end
	local lodCounts = createSimulationLodCounts(#playerTargets)

	local spawnStartedAt = if simulationTelemetry ~= nil then os.clock() else nil
	updateSpawns(now)
	updateQueuedWaveSpawns()
	updateQueuedDebugSpawns(now)
	if spawnStartedAt ~= nil then
		addSimulationTelemetry("SpawnSeconds", os.clock() - spawnStartedAt)
	end

	for _, monsterState in pairs(monstersByInstance) do
		addSimulationTelemetry("VisitedStates", 1)

		if not monsterState.IsDead then
			local root = monsterState.Root

			if root == nil then
				removeMonster(monsterState, nil)
				lodCounts.Despawned += 1
				continue
			end

			local targetingStartedAt = if simulationTelemetry ~= nil then os.clock() else nil
			local _, targetRoot, distance = getClosestAlivePlayer(root.Position, playerTargets)
			if targetingStartedAt ~= nil then
				addSimulationTelemetry("TargetQueries", 1)
				addSimulationTelemetry("TargetingSeconds", os.clock() - targetingStartedAt)
			end

			if targetRoot == nil then
				continue
			end

			if distance > CombatConfig.MonsterDespawnDistance then
				removeMonster(monsterState, nil)
				lodCounts.Despawned += 1
				continue
			end

			local lodStartedAt = if simulationTelemetry ~= nil then os.clock() else nil
			local lod = getMonsterSimulationLod(monsterState, distance)
			lodCounts[lod] += 1

			local lodDeltaTime = getLodStepDelta(monsterState, lod, now, deltaTime)
			if lodStartedAt ~= nil then
				addSimulationTelemetry("LodEvaluations", 1)
				addSimulationTelemetry("LodSeconds", os.clock() - lodStartedAt)
			end

			if lodDeltaTime ~= nil then
				lodCounts[lod .. "Steps"] += 1
				local movementStartedAt = if simulationTelemetry ~= nil then os.clock() else nil
				local stillActive = updateMonsterMovement(
					monsterState,
					targetRoot,
					distance,
					lodDeltaTime,
					lod == "Full",
					lod == "Full",
					now
				)
				if movementStartedAt ~= nil then
					addSimulationTelemetry("MovementUpdates", 1)
					addSimulationTelemetry("MovementSeconds", os.clock() - movementStartedAt)
				end

				if stillActive and lod == "Full" and not monsterState.IsDead then
					local damageStartedAt = if simulationTelemetry ~= nil then os.clock() else nil
					updateMonsterDamage(monsterState, now, playerTargets)
					if damageStartedAt ~= nil then
						addSimulationTelemetry("DamageUpdates", 1)
						addSimulationTelemetry("DamageSeconds", os.clock() - damageStartedAt)
					end
				end
			end
		end
	end

	if simulationTelemetry ~= nil then
		addSimulationTelemetry("LodFullStates", lodCounts.Full)
		addSimulationTelemetry("LodReducedStates", lodCounts.Reduced)
		addSimulationTelemetry("LodDistantStates", lodCounts.Distant)
		addSimulationTelemetry("LodFullSteps", lodCounts.FullSteps)
		addSimulationTelemetry("LodReducedSteps", lodCounts.ReducedSteps)
		addSimulationTelemetry("LodDistantSteps", lodCounts.DistantSteps)

		local numberMetrics = {
			"VisitedStates",
			"TargetQueries",
			"LodEvaluations",
			"LodFullStates",
			"LodReducedStates",
			"LodDistantStates",
			"LodFullSteps",
			"LodReducedSteps",
			"LodDistantSteps",
			"MovementUpdates",
			"SeparationQueries",
			"SeparationNeighborCandidates",
			"SeparationNeighborsInRadius",
			"GroundSamples",
			"GroundCacheHits",
			"GroundSharedSurfaceCacheHits",
			"TerrainAvoidanceSamples",
			"DamageUpdates",
		}
		local durationMetrics = {
			"SpawnSeconds",
			"WaveSpawnSeconds",
			"RecycleSeconds",
			"PlayerTargetCollectionSeconds",
			"TargetingSeconds",
			"LodSeconds",
			"MovementSeconds",
			"MoveDirectionSeconds",
			"SeparationSeconds",
			"GroundFollowSeconds",
			"TerrainAvoidanceSeconds",
			"VisualTransformSeconds",
			"PivotSeconds",
			"SpatialGridUpdateSeconds",
			"DamageSeconds",
		}

		for _, metricName in ipairs(numberMetrics) do
			local value = simulationTelemetry[metricName] or 0
			PerformanceTelemetryService.Record("Monster." .. metricName .. "PerTick", value)
			PerformanceTelemetryService.Increment("Monster." .. metricName, value)
		end

		for _, metricName in ipairs(durationMetrics) do
			PerformanceTelemetryService.Record("Monster." .. metricName, simulationTelemetry[metricName] or 0)
		end
	end

	activeSimulationTelemetry = nil

	lastSimulationLodCounts = lodCounts

	local tickDuration = os.clock() - startedAt
	PerformanceTelemetryService.Record("Monster.TickSeconds", tickDuration)
	monsterTickTimeTotal += tickDuration
	monsterTickSampleCount += 1
	monsterTickMaxSeconds = math.max(monsterTickMaxSeconds, tickDuration)
	elapsedSincePerfLog += deltaTime
	elapsedStatsUpdate += deltaTime

	if elapsedStatsUpdate >= CombatConfig.StatsUpdateInterval then
		elapsedStatsUpdate = 0
		sendStatsToAll()
	end

	local averageTickMs = 0

	if monsterTickSampleCount > 0 then
		averageTickMs = (monsterTickTimeTotal / monsterTickSampleCount) * 1000
	end

	if elapsedSincePerfLog >= (CombatConfig.PerfLogInterval or 5) then
		DebugLog.Info("Perf", "Perf monstres serveur", {
			Alive = getAliveMonsterCount(),
			GridCells = getSpatialGridCellCount(),
			SeparationGridCells = getSeparationGridCellCount(),
			GroundSurfaceCacheCells = getGroundSurfaceCacheCellCount(),
			Pool = getMonsterPoolSize(),
			SimulationMode = if (CombatConfig.MonsterSimulationHz or 0) <= 0 then "Heartbeat" else "FixedHz",
			SimulationHz = CombatConfig.MonsterSimulationHz,
			LodFull = lastSimulationLodCounts.Full,
			LodReduced = lastSimulationLodCounts.Reduced,
			LodDistant = lastSimulationLodCounts.Distant,
			LodDespawned = lastSimulationLodCounts.Despawned,
			LodFullSteps = lastSimulationLodCounts.FullSteps,
			LodReducedSteps = lastSimulationLodCounts.ReducedSteps,
			LodDistantSteps = lastSimulationLodCounts.DistantSteps,
			LodPlayerTargets = lastSimulationLodCounts.PlayerTargets,
			AverageTickMs = averageTickMs,
			MaxTickMs = monsterTickMaxSeconds * 1000,
			SpawnBatches = spawnActivity.Batches,
			SpawnRequested = spawnActivity.Requested,
			Spawned = spawnActivity.Spawned,
			SpawnFailed = spawnActivity.Failed,
			SpawnLargestRequestedBatch = spawnActivity.LargestRequestedBatch,
			SpawnLargestSpawnedBatch = spawnActivity.LargestSpawnedBatch,
			SpawnBatchAverageMs = if spawnActivity.Batches > 0
				then (spawnActivity.TotalBatchSeconds / spawnActivity.Batches) * 1000
				else 0,
			SpawnBatchMaxMs = spawnActivity.MaxBatchSeconds * 1000,
			SpawnPending = getPendingWaveSpawnCount(),
			DebugSpawnBatches = spawnActivity.DebugBatches,
			DebugSpawnRequested = spawnActivity.DebugRequested,
			DebugSpawned = spawnActivity.DebugSpawned,
			DebugSpawnAverageMs = if spawnActivity.DebugBatches > 0
				then (spawnActivity.DebugTotalSeconds / spawnActivity.DebugBatches) * 1000
				else 0,
			DebugSpawnMaxMs = spawnActivity.DebugMaxSeconds * 1000,
			DebugSpawnPending = getPendingDebugSpawnCount(),
			SpawnFallbacks = spawnActivity.Fallbacks,
			Recycled = spawnActivity.Recycled,
			RecycleCandidates = spawnActivity.RecycleCandidates,
		})

		-- La ligne generale est volontairement riche mais Studio tronque les tables longues.
		-- Ce resume conserve les valeurs necessaires pour relier un pic a un lot de spawn.
		if spawnActivity.Batches > 0 or spawnActivity.DebugBatches > 0 then
			DebugLog.Info("Perf", "Perf lots de spawn serveur", {
				PeakTickMs = monsterTickMaxSeconds * 1000,
				WaveBatches = spawnActivity.Batches,
				WaveLargestRequested = spawnActivity.LargestRequestedBatch,
				WaveLargestSpawned = spawnActivity.LargestSpawnedBatch,
				WaveAverageMs = if spawnActivity.Batches > 0
					then (spawnActivity.TotalBatchSeconds / spawnActivity.Batches) * 1000
					else 0,
				WaveMaxMs = spawnActivity.MaxBatchSeconds * 1000,
				WavePending = getPendingWaveSpawnCount(),
				DebugBatches = spawnActivity.DebugBatches,
				DebugRequested = spawnActivity.DebugRequested,
				DebugSpawned = spawnActivity.DebugSpawned,
				DebugAverageMs = if spawnActivity.DebugBatches > 0
					then (spawnActivity.DebugTotalSeconds / spawnActivity.DebugBatches) * 1000
					else 0,
				DebugMaxMs = spawnActivity.DebugMaxSeconds * 1000,
				DebugPending = getPendingDebugSpawnCount(),
			})
		end
		elapsedSincePerfLog = 0
		monsterTickTimeTotal = 0
		monsterTickSampleCount = 0
		monsterTickMaxSeconds = 0
		spawnActivity = createSpawnActivity()
	end
end

local function updateMonsters(deltaTime)
	if CombatStateService.IsPaused() then
		waveSpawnDispatchAllowance = 0
		return
	end

	waveSpawnDispatchAllowance = math.max(1, math.floor(CombatConfig.WaveSpawnDispatchBudget or 1))

	local configuredSimulationHz = CombatConfig.MonsterSimulationHz

	if configuredSimulationHz == nil or configuredSimulationHz <= 0 then
		updateMonsterStep(deltaTime)
		waveSpawnDispatchAllowance = 0
		return
	end

	local simulationHz = math.max(1, configuredSimulationHz)
	local fixedStep = 1 / simulationHz
	local maxStepsPerHeartbeat = 4
	local steps = 0

	simulationAccumulator += deltaTime

	while simulationAccumulator >= fixedStep and steps < maxStepsPerHeartbeat do
		simulationAccumulator -= fixedStep
		steps += 1
		updateMonsterStep(fixedStep)
	end

	if steps >= maxStepsPerHeartbeat and simulationAccumulator >= fixedStep then
		simulationAccumulator = fixedStep
	end

	waveSpawnDispatchAllowance = 0
end

local function bindCharacter(player, character)
	local previousHealthConnection = healthConnectionsByUserId[player.UserId]

	if previousHealthConnection ~= nil then
		previousHealthConnection:Disconnect()
	end

	local humanoid = character:WaitForChild("Humanoid", 5)

	if humanoid == nil then
		return
	end

	healthConnectionsByUserId[player.UserId] = humanoid.HealthChanged:Connect(function()
		sendStats(player)
	end)

	sendStats(player)
end

function MonsterService.SetupPlayer(player)
	DebugLog.Info("Combat", "Setup joueur combat", {
		Player = player.Name,
	})

	killsByUserId[player.UserId] = killsByUserId[player.UserId] or 0
	groundedSinceByUserId[player.UserId] = nil
	lastSpawnAtByUserId[player.UserId] = os.clock() + CombatConfig.MonsterInitialSpawnDelay - CombatConfig.MonsterSpawnInterval
	lastRecycleCheckAtByUserId[player.UserId] = nil
	lastRecycleAtByUserId[player.UserId] = nil
	pendingWaveSpawnsByUserId[player.UserId] = nil

	if characterConnectionsByUserId[player.UserId] ~= nil then
		characterConnectionsByUserId[player.UserId]:Disconnect()
	end

	characterConnectionsByUserId[player.UserId] = player.CharacterAdded:Connect(function(character)
		bindCharacter(player, character)
	end)

	if player.Character ~= nil then
		task.spawn(function()
			bindCharacter(player, player.Character)
		end)
	end

	sendStats(player)
end

function MonsterService.RemovePlayer(player)
	lastSpawnAtByUserId[player.UserId] = nil
	killsByUserId[player.UserId] = nil
	groundedSinceByUserId[player.UserId] = nil
	lastRecycleCheckAtByUserId[player.UserId] = nil
	lastRecycleAtByUserId[player.UserId] = nil
	pendingDebugSpawnsByUserId[player.UserId] = nil
	pendingWaveSpawnsByUserId[player.UserId] = nil

	if characterConnectionsByUserId[player.UserId] ~= nil then
		characterConnectionsByUserId[player.UserId]:Disconnect()
		characterConnectionsByUserId[player.UserId] = nil
	end

	if healthConnectionsByUserId[player.UserId] ~= nil then
		healthConnectionsByUserId[player.UserId]:Disconnect()
		healthConnectionsByUserId[player.UserId] = nil
	end
end

local function getElitePackSurfacePosition(originPosition, index, count)
	local packRadius = CombatConfig.EliteMonsterPackRadius or 7
	local attempts = math.max(1, CombatConfig.MonsterSpawnSurfaceAttempts or 1)
	local countRatio = (index - 1) / math.max(1, count)
	local baseAngle = (countRatio * math.pi * 2) + rng:NextNumber(-0.35, 0.35)

	for attempt = 1, attempts do
		local angle = baseAngle
		local distance = rng:NextNumber(packRadius * 0.35, packRadius)

		if attempt > 1 then
			angle = rng:NextNumber(0, math.pi * 2)
			distance = rng:NextNumber(0, packRadius)
		end

		local offset = Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
		local samplePosition = originPosition + offset
		local surfacePosition = WorldSpawnService.FindSurfacePositionAtXZ(samplePosition.X, samplePosition.Z, {
			Center = originPosition,
			RaycastHeight = CombatConfig.MonsterGroundRaycastHeight,
			RaycastDepth = CombatConfig.MonsterGroundRaycastDepth,
			ExcludeInstances = { monsterFolder },
			TelemetryTag = "Monster.Spawn",
		})

		if surfacePosition ~= nil then
			return surfacePosition
		end
	end

	local surfacePosition = WorldSpawnService.FindSurfacePositionAtXZ(originPosition.X, originPosition.Z, {
		Center = originPosition,
		RaycastHeight = CombatConfig.MonsterGroundRaycastHeight,
		RaycastDepth = CombatConfig.MonsterGroundRaycastDepth,
		ExcludeInstances = { monsterFolder },
		TelemetryTag = "Monster.Spawn",
	})

	if surfacePosition ~= nil then
		return surfacePosition
	end

	-- Certains anciens templates reposent encore sur un sol parent de Workspace.
	-- Le fallback garde les elites et le boss sur le meme sol que Monster1.
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = {
		monsterFolder,
		TemplateService.GetShrinesRuntimeFolder(),
		TemplateService.GetPortalsRuntimeFolder(),
		TemplateService.GetChestsRuntimeFolder(),
		TemplateService.GetJarsRuntimeFolder(),
		TemplateService.GetTotemsRuntimeFolder(),
	}

	local rayOrigin = originPosition + Vector3.new(0, CombatConfig.MonsterGroundRaycastHeight, 0)
	local raycastStartedAt = os.clock()
	local result = Workspace:Raycast(
		rayOrigin,
		Vector3.new(0, -CombatConfig.MonsterGroundRaycastDepth, 0),
		raycastParams
	)
	PerformanceTelemetryService.Record("Monster.RaycastSeconds", os.clock() - raycastStartedAt)
	PerformanceTelemetryService.Increment("Monster.RaycastCount")

	if result ~= nil and result.Normal.Y >= 0.65 then
		DebugLog.ThrottledWarn("Combat", "elite_surface_fallback", 2, "Fallback sol utilise pour elite ou boss", {
			Origin = originPosition,
			Surface = result.Position,
			Instance = result.Instance,
		})
		return result.Position
	end

	return nil
end

local function getElitePackCenterPosition(originPosition, player, minimumSafetyDistance)
	local playerRoot = nil

	if player ~= nil then
		playerRoot = getCharacterRoot(player)
	end

	if playerRoot == nil then
		return originPosition
	end

	local safetyDistance = minimumSafetyDistance or CombatConfig.EliteMonsterPlayerSafetyDistance or 24
	local playerPosition = playerRoot.Position
	local offset = originPosition - playerPosition
	local horizontalOffset = Vector3.new(offset.X, 0, offset.Z)

	if horizontalOffset.Magnitude >= safetyDistance then
		return originPosition
	end

	local direction = nil

	if horizontalOffset.Magnitude > 0.1 then
		direction = horizontalOffset.Unit
	else
		local angle = rng:NextNumber(0, math.pi * 2)
		direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
	end

	local candidatePosition = playerPosition + (direction * safetyDistance)
	local surfacePosition = WorldSpawnService.FindSurfacePositionAtXZ(candidatePosition.X, candidatePosition.Z, {
		Center = originPosition,
		RaycastHeight = CombatConfig.MonsterGroundRaycastHeight,
		RaycastDepth = CombatConfig.MonsterGroundRaycastDepth,
		ExcludeInstances = { monsterFolder },
		TelemetryTag = "Monster.Spawn",
	})

	return surfacePosition or getElitePackSurfacePosition(candidatePosition, 1, 1) or candidatePosition
end

function MonsterService.SpawnElitePack(originPosition, player, requestedCount)
	local requested = math.clamp(
		math.floor(requestedCount or CombatConfig.EliteMonsterSpawnCount or 5),
		0,
		CombatConfig.MonsterMaxAlive
	)
	local playerName = nil

	if player ~= nil then
		playerName = player.Name
	end

	if monsterFolder == nil then
		setupFolders()
	end

	if eliteMonsterTemplate == nil then
		eliteMonsterTemplate = findTemplate(CombatConfig.EliteMonsterTemplateName, false)
	end

	if originPosition == nil then
		DebugLog.Warn("Combat", "Spawn pack elite annule, position absente", {
			Player = playerName,
			Requested = requested,
		})
		return 0, requested
	end

	if eliteMonsterTemplate == nil then
		DebugLog.Warn("Combat", "Spawn pack elite annule, template absent", {
			Player = playerName,
			TemplateName = CombatConfig.EliteMonsterTemplateName,
			Requested = requested,
		})
		return 0, requested
	end

	local aliveMonsterCount = getAliveMonsterCount()
	local maxToSpawn = math.max(0, math.min(requested, CombatConfig.MonsterMaxAlive - aliveMonsterCount))
	local spawnedCount = 0
	local packCenterPosition = getElitePackCenterPosition(originPosition, player)
	nextElitePackId += 1

	local elitePackId = nextElitePackId
	local packState = {
		AliveCount = 0,
		KilledCount = 0,
		Origin = originPosition,
		Center = packCenterPosition,
		RewardSpawned = false,
	}

	for index = 1, maxToSpawn do
		local surfacePosition = getElitePackSurfacePosition(packCenterPosition, index, maxToSpawn)

		if spawnMonsterAtSurface(surfacePosition, {
			Template = eliteMonsterTemplate,
			TemplateName = CombatConfig.EliteMonsterTemplateName,
			Player = player,
			IsElite = true,
			ElitePackId = elitePackId,
			HealthMultiplier = CombatConfig.EliteMonsterHealthMultiplier,
			DamageMultiplier = CombatConfig.EliteMonsterDamageMultiplier,
		}) then
			spawnedCount += 1
			packState.AliveCount = spawnedCount
		end
	end

	if spawnedCount > 0 then
		elitePacksById[elitePackId] = packState
	else
		elitePackId = nil
	end

	if spawnedCount > 0 then
		sendStatsToAll()
	end

	DebugLog.Info("Combat", "Pack elite genere", {
		Player = playerName,
		Origin = originPosition,
		Center = packCenterPosition,
		PackId = elitePackId,
		Spawned = spawnedCount,
		Requested = requested,
		MaxToSpawn = maxToSpawn,
		Alive = getAliveMonsterCount(),
		Template = CombatConfig.EliteMonsterTemplateName,
		HealthMultiplier = CombatConfig.EliteMonsterHealthMultiplier,
		DamageMultiplier = CombatConfig.EliteMonsterDamageMultiplier,
	})

	return spawnedCount, requested
end

function MonsterService.SpawnBossNearPlayer(originPosition, player, options)
	options = options or {}

	if monsterFolder == nil then
		setupFolders()
	end

	if originPosition == nil or player == nil or not isPlayerAlive(player) then
		DebugLog.Warn("Boss", "Spawn boss annule, joueur ou position invalide", {
			Player = player and player.Name or "nil",
			Origin = originPosition,
		})
		return false
	end

	local templateName = options.TemplateName or CombatConfig.EliteMonsterTemplateName
	local template = options.Template or findTemplate(templateName, false)

	if template == nil then
		DebugLog.Warn("Boss", "Spawn boss annule, template absent", {
			Player = player.Name,
			TemplateName = templateName,
		})
		return false
	end

	if getAliveMonsterCount() >= CombatConfig.MonsterMaxAlive then
		DebugLog.Warn("Boss", "Spawn boss annule, plafond monstres atteint", {
			Player = player.Name,
			MaxAlive = CombatConfig.MonsterMaxAlive,
		})
		return false
	end

	local center = getElitePackCenterPosition(originPosition, player, options.SafetyDistance)
	local surfacePosition = getElitePackSurfacePosition(center, 1, 1)

	if surfacePosition == nil then
		DebugLog.Warn("Boss", "Spawn boss annule, surface introuvable", {
			Player = player.Name,
			Center = center,
		})
		return false
	end

	local didSpawn, monster, spawnPosition, monsterState = spawnMonsterAtSurface(surfacePosition, {
		Template = template,
		TemplateName = templateName,
		MaxHealth = options.MaxHealth,
		AttackDamage = options.AttackDamage,
		IsBoss = true,
		BossName = options.BossName,
		DropLoot = options.DropLoot,
		SpeedMultiplier = options.SpeedMultiplier,
		OnDefeated = options.OnDefeated,
		OnHealthChanged = options.OnHealthChanged,
	})

	if didSpawn then
		DebugLog.Info("Boss", "Boss genere", {
			Player = player.Name,
			Boss = monster,
			Template = templateName,
			Position = spawnPosition,
			Health = options.MaxHealth,
			Damage = options.AttackDamage,
			HasHumanoid = monsterState.Humanoid ~= nil,
			Root = monsterState.Root,
			RootAnchored = monsterState.Root.Anchored,
		UsesProceduralMotion = monsterState.UseProceduralMotion,
		})
	end

	return didSpawn, monster, spawnPosition, monsterState
end

function MonsterService.DebugSpawnMonstersNearPlayer(player, requestedCount)
	DebugLog.Info("Combat", "Debug spawn monstres demande", {
		Player = player.Name,
		Requested = requestedCount,
	})

	local count = math.clamp(math.floor(requestedCount or 0), 0, CombatConfig.MonsterMaxAlive)
	local aliveMonsterCount = getAliveMonsterCount()
	local maxToSpawn = math.max(0, math.min(count, CombatConfig.MonsterMaxAlive - aliveMonsterCount))
	local spawnedCount = 0
	local attempts = 0
	local maxAttempts = math.max(maxToSpawn * 5, maxToSpawn)
	local startedAt = os.clock()

	while spawnedCount < maxToSpawn and attempts < maxAttempts do
		attempts += 1

		if spawnMonsterNearPlayer(player) then
			spawnedCount += 1
		end
	end

	if spawnedCount > 0 then
		sendStatsToAll()
	end

	recordDebugSpawnBatch(maxToSpawn, spawnedCount, os.clock() - startedAt)

	return spawnedCount, maxToSpawn
end

function MonsterService.QueueDebugSpawnMonstersNearPlayer(player, requestedCount, batchSize, batchInterval)
	if player == nil or player.Parent ~= Players or not isPlayerAlive(player) then
		return 0, 0, false
	end

	local existingRequest = pendingDebugSpawnsByUserId[player.UserId]

	if existingRequest ~= nil then
		return 0, existingRequest.Remaining, true
	end

	local count = math.clamp(math.floor(requestedCount or 0), 0, CombatConfig.MonsterMaxAlive)
	local availableCapacity = math.max(0, CombatConfig.MonsterMaxAlive - getAliveMonsterCount())
	local maxToSpawn = math.max(0, math.min(count, availableCapacity))

	if maxToSpawn <= 0 then
		return 0, 0, false
	end

	pendingDebugSpawnsByUserId[player.UserId] = {
		Player = player,
		Requested = maxToSpawn,
		Remaining = maxToSpawn,
		Spawned = 0,
		BatchSize = math.max(1, math.floor(batchSize or 1)),
		BatchInterval = math.max(0, batchInterval or 0),
		NextBatchAt = CombatStateService.GetTime(),
	}

	DebugLog.Info("Combat", "Spawn debug mis en file", {
		Player = player.Name,
		Requested = maxToSpawn,
		BatchSize = math.max(1, math.floor(batchSize or 1)),
		BatchInterval = math.max(0, batchInterval or 0),
	})

	return maxToSpawn, maxToSpawn, false
end

function MonsterService.DebugKillAllMonsters()
	DebugLog.Info("Combat", "Debug kill all monstres demande")

	return MonsterService.ClearAllMonsters("Debug")
end

function MonsterService.GetPerformanceSnapshot()
	return {
		Active = getAliveMonsterCount(),
		Pool = getMonsterPoolSize(),
		GridCells = getSpatialGridCellCount(),
		SeparationGridCells = getSeparationGridCellCount(),
		GroundSurfaceCacheCells = getGroundSurfaceCacheCellCount(),
		Lod = table.clone(lastSimulationLodCounts),
		BenchmarkMode = benchmarkMode,
	}
end

function MonsterService.SetBenchmarkMode(isEnabled)
	benchmarkMode = isEnabled == true
end

function MonsterService.SetBenchmarkSeed(seed)
	if seed == nil then
		rng = Random.new()
		return
	end

	rng = Random.new(math.floor(tonumber(seed) or 0))
end

function MonsterService.ClearAllMonsters(reason)
	DebugLog.Info("Combat", "Nettoyage monstres demande", {
		Reason = reason,
	})

	local monsterStates = {}

	for _, monsterState in pairs(monstersByInstance) do
		table.insert(monsterStates, monsterState)
	end

	local killedCount = 0

	for _, monsterState in ipairs(monsterStates) do
		if not monsterState.IsDead then
			monsterState.IsDead = true
			monstersByInstance[monsterState.Instance] = nil
			killedCount += 1
			releaseMonsterToPool(monsterState)
		end
	end

	elitePacksById = {}
	monsterSpatialGrid = {}
	monsterSeparationGrid = {}
	groundSurfaceCellCache = {}
	pendingDebugSpawnsByUserId = {}
	pendingWaveSpawnsByUserId = {}
	waveSpawnDispatchAllowance = 0

	if killedCount > 0 then
		sendStatsToAll()
	end

	return killedCount
end

function MonsterService.GetKills(player)
	if player == nil then
		return 0
	end

	return killsByUserId[player.UserId] or 0
end

function MonsterService.ResetRunStats(player)
	if player == nil then
		return
	end

	killsByUserId[player.UserId] = 0
	difficultyPercent = 0
	sendStats(player)
end

function MonsterService.AddDifficultyPercent(percent, player, source)
	local amount = math.max(0, percent or 0)
	local playerName = nil

	if amount <= 0 then
		return difficultyPercent
	end

	if player ~= nil then
		playerName = player.Name
	end

	difficultyPercent += amount
	sendStatsToAll()

	DebugLog.Info("Combat", "Difficulte combat augmentee", {
		Player = playerName,
		Source = source,
		AddedPercent = math.floor((amount * 100) + 0.5),
		TotalPercent = math.floor((difficultyPercent * 100) + 0.5),
		Multiplier = getDifficultyMultiplier(),
	})

	return difficultyPercent
end

function MonsterService.GetClosestMonster(position, maxDistance, ignoredMonsters)
	local closestMonster = nil
	local closestRoot = nil
	local queryRadius = maxDistance or CombatConfig.FireballRange or 128
	local closestDistanceSquared = queryRadius * queryRadius

	for _, monsterData in ipairs(MonsterService.GetMonstersNear(position, queryRadius, ignoredMonsters)) do
		local distanceSquared = monsterData.DistanceSquared

		if distanceSquared <= closestDistanceSquared then
			closestMonster = monsterData.Monster
			closestRoot = monsterData.Root
			closestDistanceSquared = distanceSquared
		end
	end

	return closestMonster, closestRoot, math.sqrt(closestDistanceSquared)
end

function MonsterService.GetMonstersNear(position, radius, ignoredMonsters)
	local results = {}
	local queryRadius = math.max(0, radius or 0)

	if queryRadius <= 0 then
		return results
	end

	local cellSize = getSpatialCellSize()
	local centerCellX, centerCellZ = getSpatialCell(position)
	local cellRange = math.max(0, math.ceil(queryRadius / cellSize))
	local radiusSquared = queryRadius * queryRadius

	for offsetX = -cellRange, cellRange do
		for offsetZ = -cellRange, cellRange do
			local key = getGridKey(centerCellX + offsetX, centerCellZ + offsetZ)
			local cell = monsterSpatialGrid[key]

			if cell ~= nil then
				for monsterState in pairs(cell) do
					local monster = monsterState.Instance
					local root = monsterState.Root

					if
						not monsterState.IsDead
						and monster ~= nil
						and root ~= nil
						and monster.Parent ~= nil
						and (ignoredMonsters == nil or not ignoredMonsters[monster])
					then
						local offset = root.Position - position
						local distanceSquared = offset:Dot(offset)

						if distanceSquared <= radiusSquared then
							table.insert(results, {
								Monster = monster,
								Root = root,
								State = monsterState,
								DistanceSquared = distanceSquared,
							})
						end
					end
				end
			end
		end
	end

	return results
end

function MonsterService.GetMonsterPosition(monster)
	local monsterState = getMonsterStateFromInstance(monster)

	if monsterState == nil or monsterState.IsDead then
		return nil
	end

	local root = monsterState.Root

	if root == nil then
		return nil
	end

	return root.Position
end

function MonsterService.IsMonsterAlive(monster)
	local monsterState = getMonsterStateFromInstance(monster)

	return monsterState ~= nil and not monsterState.IsDead
end

function MonsterService.DamageMonster(monster, damage, attacker, options)
	local monsterState = getMonsterStateFromInstance(monster)

	if monsterState == nil or monsterState.IsDead then
		return false
	end

	if damage > 0 then
		flashMonsterDamage(monsterState, options and options.FlashColor)
	end

	if benchmarkMode then
		return true, math.max(0, damage)
	end

	if monsterState.Humanoid ~= nil then
		monsterState.PendingKiller = attacker
		local previousHealth = monsterState.Humanoid.Health

		monsterState.Humanoid:TakeDamage(damage)
		monsterState.Instance:SetAttribute("MonsterHealth", math.max(0, monsterState.Humanoid.Health))

		local damageDealt = math.max(0, previousHealth - monsterState.Humanoid.Health)

		if damageDealt > 0 then
			monsterState.LastDamagedAt = CombatStateService.GetTime()
		end

		if monsterState.OnHealthChanged ~= nil then
			task.defer(monsterState.OnHealthChanged, monsterState.Instance, math.max(0, monsterState.Humanoid.Health), monsterState.MaxHealth)
		end

		if monsterState.Humanoid.Health <= 0 then
			removeMonster(monsterState, attacker)
		end

		return true, damageDealt
	end

	local previousHealth = monsterState.Health

	monsterState.Health -= damage
	monsterState.Instance:SetAttribute("MonsterHealth", monsterState.Health)

	local damageDealt = math.max(0, math.min(previousHealth, damage))

	if damageDealt > 0 then
		monsterState.LastDamagedAt = CombatStateService.GetTime()
	end

	if monsterState.OnHealthChanged ~= nil then
		task.defer(monsterState.OnHealthChanged, monsterState.Instance, math.max(0, monsterState.Health), monsterState.MaxHealth)
	end

	if monsterState.Health <= 0 then
		removeMonster(monsterState, attacker)
	end

	return true, damageDealt
end

function MonsterService.Start()
	setupFolders()
	monsterTemplate = findTemplate(CombatConfig.MonsterTemplateName, true)
	eliteMonsterTemplate = findTemplate(CombatConfig.EliteMonsterTemplateName, false)
	prewarmMonsterPool(monsterTemplate, CombatConfig.MonsterTemplateName, CombatConfig.MonsterPoolPrewarm)
	waveStartedAt = CombatStateService.GetTime()

	RunStateService.RunStarted:Connect(function(player, reason)
		local now = CombatStateService.GetTime()

		waveStartedAt = now
		simulationAccumulator = 0
		monsterTickTimeTotal = 0
		monsterTickSampleCount = 0
		monsterTickMaxSeconds = 0
		elapsedSincePerfLog = 0
		lastSimulationLodCounts = createSimulationLodCounts()
		groundedSinceByUserId[player.UserId] = nil
		killsByUserId[player.UserId] = 0
		difficultyPercent = 0
		lastSpawnAtByUserId[player.UserId] = now + CombatConfig.MonsterInitialSpawnDelay - CombatConfig.MonsterSpawnInterval
		lastRecycleCheckAtByUserId[player.UserId] = nil
		lastRecycleAtByUserId[player.UserId] = nil
		pendingDebugSpawnsByUserId[player.UserId] = nil
		pendingWaveSpawnsByUserId[player.UserId] = nil
		spawnActivity = createSpawnActivity()
		sendStats(player)
		DebugLog.Info("Combat", "Combat run demarre pour joueur", {
			Player = player.Name,
			Reason = reason,
			WaveStartedAt = waveStartedAt,
		})
	end)

	RunStateService.RunEnded:Connect(function(player, reason)
		benchmarkMode = false
		groundedSinceByUserId[player.UserId] = nil
		lastSpawnAtByUserId[player.UserId] = nil
		lastRecycleCheckAtByUserId[player.UserId] = nil
		lastRecycleAtByUserId[player.UserId] = nil
		pendingDebugSpawnsByUserId[player.UserId] = nil
		pendingWaveSpawnsByUserId[player.UserId] = nil
		simulationAccumulator = 0
		monsterTickTimeTotal = 0
		monsterTickSampleCount = 0
		monsterTickMaxSeconds = 0
		elapsedSincePerfLog = 0
		lastSimulationLodCounts = createSimulationLodCounts()
		spawnActivity = createSpawnActivity()
		MonsterService.ClearAllMonsters(reason)
		sendStats(player)
		DebugLog.Info("Combat", "Combat run arrete pour joueur", {
			Player = player.Name,
			Reason = reason,
		})
	end)

	DebugLog.Info("Combat", "MonsterService demarre", {
		RuntimeFolder = runtimeFolder,
		MonsterFolder = monsterFolder,
		Template = monsterTemplate,
		EliteTemplate = eliteMonsterTemplate,
		MaxAlive = CombatConfig.MonsterMaxAlive,
		CalmDuration = CombatConfig.DifficultyCalmDuration,
		CalmMaxAlive = CombatConfig.DifficultyCalmMaxAlive,
		SpawnInterval = CombatConfig.MonsterSpawnInterval,
		SpawnIntervalMin = CombatConfig.MonsterSpawnIntervalMin,
		GroundedDelay = CombatConfig.MonsterSpawnGroundedDelay,
	})

	if heartbeatConnection ~= nil then
		return
	end

	heartbeatConnection = RunService.Heartbeat:Connect(updateMonsters)
end

return MonsterService
