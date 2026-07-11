local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))
local DebugLog = require(Shared:WaitForChild("DebugLog"))

local CombatStateService = require(script.Parent:WaitForChild("CombatStateService"))
local ChestService = require(script.Parent:WaitForChild("ChestService"))
local CoinService = require(script.Parent:WaitForChild("CoinService"))
local PerkService = require(script.Parent:WaitForChild("PerkService"))
local RunStateService = require(script.Parent:WaitForChild("RunStateService"))
local TemplateService = require(script.Parent:WaitForChild("TemplateService"))
local WorldSpawnService = require(script.Parent:WaitForChild("WorldSpawnService"))
local XpService = require(script.Parent:WaitForChild("XpService"))

local MonsterService = {}

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
local waveStartedAt = CombatStateService.GetTime()
local monstersByInstance = {}
local monsterSpatialGrid = {}
local killsByUserId = {}
local lastSpawnAtByUserId = {}
local groundedSinceByUserId = {}
local characterConnectionsByUserId = {}
local healthConnectionsByUserId = {}
local elitePacksById = {}
local nextElitePackId = 0
local difficultyPercent = 0

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

			if humanoid ~= nil then
				descendant.Anchored = false

				pcall(function()
					descendant:SetNetworkOwner(nil)
				end)
			else
				descendant.Anchored = true
			end
		end
	end

	if monster:IsA("BasePart") then
		monster.Anchored = humanoid == nil
		monster.CanCollide = CombatConfig.MonsterPartsCanCollide == true
		monster.CanTouch = CombatConfig.MonsterPartsCanTouch == true
		monster.CanQuery = CombatConfig.MonsterPartsCanQuery == true
	end

	if humanoid ~= nil then
		humanoid.BreakJointsOnDeath = false
		humanoid.MaxHealth = resolvedMaxHealth
		humanoid.Health = resolvedMaxHealth
		humanoid.WalkSpeed = CombatConfig.MonsterWalkSpeed
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

		pcall(function()
			humanoid:ChangeState(Enum.HumanoidStateType.Running)
		end)
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

local function flashMonsterDamage(monsterState)
	if monsterState.OriginalPartColors == nil then
		return
	end

	monsterState.DamageFlashId += 1

	local flashId = monsterState.DamageFlashId

	setMonsterPartsColor(monsterState, CombatConfig.MonsterDamageFlashColor)

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

local function getGridKey(cellX, cellZ)
	return tostring(cellX) .. ":" .. tostring(cellZ)
end

local function getSpatialCell(position)
	local cellSize = getSpatialCellSize()

	return math.floor(position.X / cellSize), math.floor(position.Z / cellSize)
end

local function removeMonsterFromSpatialGrid(monsterState)
	local key = monsterState.SpatialGridKey

	if key == nil then
		return
	end

	local cell = monsterSpatialGrid[key]

	if cell ~= nil then
		cell[monsterState] = nil

		if next(cell) == nil then
			monsterSpatialGrid[key] = nil
		end
	end

	monsterState.SpatialGridKey = nil
	monsterState.SeparationCellX = nil
	monsterState.SeparationCellZ = nil
end

local function updateMonsterSpatialCell(monsterState, position)
	if position == nil then
		return
	end

	local cellX, cellZ = getSpatialCell(position)
	local key = getGridKey(cellX, cellZ)

	if monsterState.SpatialGridKey == key then
		return
	end

	removeMonsterFromSpatialGrid(monsterState)

	local cell = monsterSpatialGrid[key]

	if cell == nil then
		cell = {}
		monsterSpatialGrid[key] = cell
	end

	cell[monsterState] = true
	monsterState.SpatialGridKey = key
	monsterState.SeparationCellX = cellX
	monsterState.SeparationCellZ = cellZ
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
	monster:SetAttribute("ElitePackId", nil)
	monster:SetAttribute("MonsterHealth", 0)

	local templateName = monsterState.TemplateName or monster.Name or CombatConfig.MonsterTemplateName
	monster.Name = templateName
	monster.Parent = getMonsterPoolFolder(templateName)
end

local function getMonsterLootMultiplier(monsterState)
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
			ChestService.SpawnRewardChestAtPosition(deathPosition)
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

		if deathPosition ~= nil then
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

local function getClosestAlivePlayer(position)
	local closestPlayer = nil
	local closestRoot = nil
	local closestDistance = math.huge

	for _, player in ipairs(Players:GetPlayers()) do
		if isPlayerAlive(player) then
			local root = getCharacterRoot(player)
			local distance = (root.Position - position).Magnitude

			if distance < closestDistance then
				closestDistance = distance
				closestPlayer = player
				closestRoot = root
			end
		end
	end

	return closestPlayer, closestRoot, closestDistance
end

local function getSpawnSurfacePositionNearPlayer(player)
	local root = getCharacterRoot(player)

	if root == nil then
		return nil
	end

	local attempts = math.max(1, CombatConfig.MonsterSpawnSurfaceAttempts or 1)

	for _ = 1, attempts do
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = rng:NextNumber(CombatConfig.MonsterMinSpawnDistance, CombatConfig.MonsterMaxSpawnDistance)
		local horizontalOffset = Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
		local rayOrigin = root.Position + horizontalOffset + Vector3.new(0, CombatConfig.MonsterGroundRaycastHeight, 0)
		local rayDirection = Vector3.new(0, -CombatConfig.MonsterGroundRaycastDepth, 0)
		local raycastParams = RaycastParams.new()

		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		raycastParams.FilterDescendantsInstances = { player.Character, runtimeFolder }

		local result = Workspace:Raycast(rayOrigin, rayDirection, raycastParams)

		if result ~= nil then
			return result.Position
		end
	end

	return nil
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

local function spawnMonsterAtSurface(surfacePosition, options)
	options = options or {}

	local template = options.Template or monsterTemplate
	local templateName = options.TemplateName or CombatConfig.MonsterTemplateName
	local healthMultiplier = options.HealthMultiplier or 1
	local damageMultiplier = options.DamageMultiplier or 1
	local maxHealth = math.max(1, math.floor((CombatConfig.MonsterHealth * healthMultiplier) + 0.5))
	local attackDamage = math.max(0, CombatConfig.MonsterAttackDamage * damageMultiplier)
	local isElite = options.IsElite == true
	local elitePackId = options.ElitePackId

	if template == nil or surfacePosition == nil then
		DebugLog.Warn("Combat", "Spawn monstre impossible", {
			TemplateName = templateName,
			HasTemplate = template ~= nil,
			SurfacePosition = surfacePosition,
			IsElite = isElite,
		})
		return false
	end

	local monster, reusedFromPool = acquireMonsterInstance(template, templateName)

	monster.Name = templateName
	monster:SetAttribute("RuntimeMonster", true)
	monster:SetAttribute("IsElite", isElite)
	monster:SetAttribute("MonsterMaxHealth", maxHealth)
	monster:SetAttribute("MonsterHealth", maxHealth)
	monster:SetAttribute("MonsterAttackDamage", attackDamage)
	monster:SetAttribute("ElitePackId", elitePackId)

	local humanoid, root = prepareMonsterInstance(monster, maxHealth)

	if root == nil then
		DebugLog.Warn("Combat", "Monstre sans BasePart, spawn annule", {
			Monster = monster,
			TemplateName = templateName,
			IsElite = isElite,
		})
		monster:Destroy()
		return false
	end

	local pivotRotation = WorldSpawnService.GetPivotRotation(monster)
	local spawnPivotPosition = getSurfacePivotPosition(monster, surfacePosition)

	pivotInstance(monster, WorldSpawnService.GetPivotCFrameAtPosition(monster, spawnPivotPosition))

	local monsterState = {
		Instance = monster,
		Humanoid = humanoid,
		Root = root,
		TemplateName = templateName,
		BasePosition = spawnPivotPosition,
		PivotRotation = pivotRotation,
		Health = maxHealth,
		AttackDamage = attackDamage,
		IsElite = isElite,
		ElitePackId = elitePackId,
		AnimationTrack = playMonsterAnimation(monster),
		AnimationTime = rng:NextNumber(0, 10),
		LastMoveToAt = 0,
		LastDamageByUserId = {},
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

local function spawnMonsterNearPlayer(player)
	if monsterTemplate == nil or not isPlayerAlive(player) then
		DebugLog.ThrottledWarn("Combat", "mob_spawn_blocked_" .. player.UserId, 2, "Spawn mob bloque", {
			Player = player.Name,
			HasTemplate = monsterTemplate ~= nil,
			PlayerAlive = isPlayerAlive(player),
		})
		return false
	end

	local spawnSurfacePosition = getSpawnSurfacePositionNearPlayer(player)

	if spawnSurfacePosition == nil then
		DebugLog.ThrottledWarn("Combat", "mob_no_surface_" .. player.UserId, 2, "Aucune surface trouvee pour spawn mob", {
			Player = player.Name,
			Root = getCharacterRoot(player),
			RaycastHeight = CombatConfig.MonsterGroundRaycastHeight,
			RaycastDepth = CombatConfig.MonsterGroundRaycastDepth,
			Attempts = CombatConfig.MonsterSpawnSurfaceAttempts,
		})
		return false
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
	local root = monsterState.Root

	if root == nil or monsterState.SeparationCellX == nil or monsterState.SeparationCellZ == nil then
		return Vector3.zero
	end

	local radius = CombatConfig.MonsterSeparationRadius
	local separation = Vector3.zero

	for offsetX = -1, 1 do
		for offsetZ = -1, 1 do
			local key = getGridKey(monsterState.SeparationCellX + offsetX, monsterState.SeparationCellZ + offsetZ)
			local cell = monsterSpatialGrid[key]

			if cell ~= nil then
				for otherState in pairs(cell) do
					if otherState ~= monsterState and not otherState.IsDead and otherState.Root ~= nil then
						local offset = root.Position - otherState.Root.Position
						local horizontalOffset = Vector3.new(offset.X, 0, offset.Z)
						local distance = horizontalOffset.Magnitude

						if distance > 0.05 and distance < radius then
							separation += horizontalOffset.Unit * ((radius - distance) / radius)
						elseif distance <= 0.05 then
							local randomAngle = rng:NextNumber(0, math.pi * 2)
							separation += Vector3.new(math.cos(randomAngle), 0, math.sin(randomAngle))
						end
					end
				end
			end
		end
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

local function getProceduralAnimationCFrame(monsterState, position, moveDirection, deltaTime)
	monsterState.AnimationTime += deltaTime

	local bob = math.sin(monsterState.AnimationTime * 8) * CombatConfig.MonsterProceduralBobHeight
	local sway = math.sin(monsterState.AnimationTime * 7) * math.rad(CombatConfig.MonsterProceduralSwayDegrees)
	local visualPosition = position + Vector3.new(0, bob, 0)
	local lookTarget = visualPosition + moveDirection
	local pivotRotation = monsterState.PivotRotation or CFrame.new()

	return CFrame.lookAt(visualPosition, lookTarget) * CFrame.Angles(0, 0, sway) * pivotRotation
end

local function updateMonsterMovement(monsterState, deltaTime, now)
	local root = monsterState.Root

	if root == nil then
		removeMonster(monsterState, nil)
		return
	end

	local _, targetRoot, distance = getClosestAlivePlayer(root.Position)

	if targetRoot == nil then
		return
	end

	if distance > CombatConfig.MonsterDespawnDistance then
		removeMonster(monsterState, nil)
		return
	end

	local separation = getMonsterSeparation(monsterState)

	if monsterState.Humanoid ~= nil then
		updateMonsterSpatialCell(monsterState, root.Position)

		if now - monsterState.LastMoveToAt >= 0.35 then
			local moveDirection = getMoveDirection(root.Position, targetRoot.Position, separation)

			if moveDirection.Magnitude > 0 then
				monsterState.Humanoid:MoveTo(root.Position + (moveDirection * 24))
			else
				monsterState.Humanoid:MoveTo(targetRoot.Position)
			end

			monsterState.LastMoveToAt = now
		end

		return
	end

	local basePosition = monsterState.BasePosition or root.Position
	local moveDirection = getMoveDirection(basePosition, targetRoot.Position, separation)

	if moveDirection.Magnitude <= 0.1 then
		return
	end

	local targetDistance = (Vector3.new(targetRoot.Position.X, 0, targetRoot.Position.Z) - Vector3.new(basePosition.X, 0, basePosition.Z)).Magnitude
	local step = math.min(targetDistance, CombatConfig.MonsterDirectMoveSpeed * deltaTime)
	local nextPosition = basePosition + (moveDirection * step)

	monsterState.BasePosition = nextPosition
	pivotInstance(monsterState.Instance, getProceduralAnimationCFrame(monsterState, nextPosition, moveDirection, deltaTime))
	updateMonsterSpatialCell(monsterState, nextPosition)
end

local function updateMonsterDamage(monsterState, now)
	local root = monsterState.Root

	if root == nil then
		return
	end

	for _, player in ipairs(Players:GetPlayers()) do
		if isPlayerAlive(player) then
			local playerRoot = getCharacterRoot(player)
			local distance = (playerRoot.Position - root.Position).Magnitude

			if distance <= CombatConfig.MonsterAttackRange then
				local lastDamageAt = monsterState.LastDamageByUserId[player.UserId] or 0

				if now - lastDamageAt >= CombatConfig.MonsterAttackCooldown then
					monsterState.LastDamageByUserId[player.UserId] = now

					local attackDamage = monsterState.AttackDamage or CombatConfig.MonsterAttackDamage
					local finalDamage = PerkService.CalculateIncomingDamage(player, attackDamage)

					if finalDamage > 0 then
						getCharacterHumanoid(player):TakeDamage(finalDamage)
					end

					sendStats(player)
				end
			end
		end
	end
end

local function updateSpawns(now)
	local maxAliveMonsters = getCurrentWaveMaxAlive()
	local aliveMonsterCount = getAliveMonsterCount()

	if aliveMonsterCount >= maxAliveMonsters then
		return
	end

	for _, player in ipairs(Players:GetPlayers()) do
		if aliveMonsterCount >= maxAliveMonsters then
			return
		end

		if isPlayerAlive(player) and hasPlayerBeenGroundedLongEnough(player, now) then
			local lastSpawnAt = lastSpawnAtByUserId[player.UserId] or 0
			local spawnInterval = getCurrentSpawnInterval()

			if now - lastSpawnAt >= spawnInterval then
				lastSpawnAtByUserId[player.UserId] = now

				local spawnBatch = math.max(
					1,
					math.floor(getCurrentWaveSpawnBatch() * PerkService.GetEnemyCountMultiplier(player))
				)

				for _ = 1, spawnBatch do
					if aliveMonsterCount >= maxAliveMonsters then
						return
					end

					if spawnMonsterNearPlayer(player) then
						aliveMonsterCount += 1
					end
				end
			end
		end
	end
end

local function updateMonsterStep(deltaTime)
	local now = CombatStateService.GetTime()
	local startedAt = os.clock()

	updateSpawns(now)

	for _, monsterState in pairs(monstersByInstance) do
		if not monsterState.IsDead then
			updateMonsterMovement(monsterState, deltaTime, now)
			updateMonsterDamage(monsterState, now)
		end
	end

	monsterTickTimeTotal += os.clock() - startedAt
	monsterTickSampleCount += 1
	elapsedStatsUpdate += deltaTime

	if elapsedStatsUpdate >= CombatConfig.StatsUpdateInterval then
		elapsedStatsUpdate = 0
		sendStatsToAll()
	end

	local averageTickMs = 0

	if monsterTickSampleCount > 0 then
		averageTickMs = (monsterTickTimeTotal / monsterTickSampleCount) * 1000
	end

	DebugLog.ThrottledInfo("Perf", "monster_tick", CombatConfig.PerfLogInterval or 5, "Perf monstres serveur", {
		Alive = getAliveMonsterCount(),
		GridCells = getSpatialGridCellCount(),
		Pool = getMonsterPoolSize(),
		SimulationHz = CombatConfig.MonsterSimulationHz,
		AverageTickMs = averageTickMs,
	})
end

local function updateMonsters(deltaTime)
	if CombatStateService.IsPaused() then
		return
	end

	local simulationHz = math.max(1, CombatConfig.MonsterSimulationHz or 15)
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
			RejectedSurfaceNameContains = {
				"MurInvisible",
			},
		})

		if surfacePosition ~= nil then
			return surfacePosition
		end
	end

	return WorldSpawnService.FindSurfacePositionAtXZ(originPosition.X, originPosition.Z, {
		Center = originPosition,
		RaycastHeight = CombatConfig.MonsterGroundRaycastHeight,
		RaycastDepth = CombatConfig.MonsterGroundRaycastDepth,
		ExcludeInstances = { monsterFolder },
		RejectedSurfaceNameContains = {
			"MurInvisible",
		},
	})
end

local function getElitePackCenterPosition(originPosition, player)
	local playerRoot = nil

	if player ~= nil then
		playerRoot = getCharacterRoot(player)
	end

	if playerRoot == nil then
		return originPosition
	end

	local safetyDistance = CombatConfig.EliteMonsterPlayerSafetyDistance or 24
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
		RejectedSurfaceNameContains = {
			"MurInvisible",
		},
	})

	return surfacePosition or Vector3.new(candidatePosition.X, originPosition.Y, candidatePosition.Z)
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

	while spawnedCount < maxToSpawn and attempts < maxAttempts do
		attempts += 1

		if spawnMonsterNearPlayer(player) then
			spawnedCount += 1
		end
	end

	if spawnedCount > 0 then
		sendStatsToAll()
	end

	return spawnedCount, maxToSpawn
end

function MonsterService.DebugKillAllMonsters()
	DebugLog.Info("Combat", "Debug kill all monstres demande")

	return MonsterService.ClearAllMonsters("Debug")
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

	if killedCount > 0 then
		elitePacksById = {}
		monsterSpatialGrid = {}
		sendStatsToAll()
	end

	return killedCount
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

function MonsterService.DamageMonster(monster, damage, attacker)
	local monsterState = getMonsterStateFromInstance(monster)

	if monsterState == nil or monsterState.IsDead then
		return false
	end

	if damage > 0 then
		flashMonsterDamage(monsterState)
	end

	if monsterState.Humanoid ~= nil then
		monsterState.PendingKiller = attacker
		local previousHealth = monsterState.Humanoid.Health

		monsterState.Humanoid:TakeDamage(damage)
		monsterState.Instance:SetAttribute("MonsterHealth", math.max(0, monsterState.Humanoid.Health))

		local damageDealt = math.max(0, previousHealth - monsterState.Humanoid.Health)

		if monsterState.Humanoid.Health <= 0 then
			removeMonster(monsterState, attacker)
		end

		return true, damageDealt
	end

	local previousHealth = monsterState.Health

	monsterState.Health -= damage
	monsterState.Instance:SetAttribute("MonsterHealth", monsterState.Health)

	local damageDealt = math.max(0, math.min(previousHealth, damage))

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
		groundedSinceByUserId[player.UserId] = nil
		lastSpawnAtByUserId[player.UserId] = now + CombatConfig.MonsterInitialSpawnDelay - CombatConfig.MonsterSpawnInterval
		sendStats(player)
		DebugLog.Info("Combat", "Combat run demarre pour joueur", {
			Player = player.Name,
			Reason = reason,
			WaveStartedAt = waveStartedAt,
		})
	end)

	RunStateService.RunEnded:Connect(function(player, reason)
		groundedSinceByUserId[player.UserId] = nil
		lastSpawnAtByUserId[player.UserId] = nil
		simulationAccumulator = 0
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
