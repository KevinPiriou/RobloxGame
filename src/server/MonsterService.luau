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
local RunAnalyticsService = require(script.Parent:WaitForChild("RunAnalyticsService"))
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
local monsterTickMaxSeconds = 0
local elapsedSincePerfLog = 0
local waveStartedAt = CombatStateService.GetTime()
local monstersByInstance = {}
local nextRuntimeMonsterId = 0
local monsterSpatialGrid = {}
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

local function createSpawnActivity()
	return {
		Batches = 0,
		Requested = 0,
		Spawned = 0,
		Failed = 0,
		Fallbacks = 0,
		Recycled = 0,
		RecycleCandidates = 0,
	}
end

local spawnActivity = createSpawnActivity()

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
	monster:SetAttribute("RuntimeMonsterId", nil)
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
	nextRuntimeMonsterId += 1
	monster:SetAttribute("RuntimeMonster", true)
	monster:SetAttribute("RuntimeMonsterId", nextRuntimeMonsterId)
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

local function updateMonsterMovement(monsterState, targetRoot, distance, deltaTime, useSeparation, useProceduralMotion)
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
	local moveDirection = getMoveDirection(basePosition, targetRoot.Position, separation)

	if moveDirection.Magnitude <= 0.1 then
		return true
	end

	local targetDistance = (Vector3.new(targetRoot.Position.X, 0, targetRoot.Position.Z) - Vector3.new(basePosition.X, 0, basePosition.Z)).Magnitude
	local speedMultiplier = monsterState.SpeedMultiplier or 1
	local step = math.min(targetDistance, CombatConfig.MonsterDirectMoveSpeed * speedMultiplier * deltaTime)
	local nextPosition = basePosition + (moveDirection * step)

	monsterState.BasePosition = nextPosition

	if monsterState.UseProceduralMotion ~= true or useProceduralMotion ~= true then
		local lookTarget = nextPosition + moveDirection
		local pivotRotation = monsterState.PivotRotation or CFrame.new()
		pivotInstance(monsterState.Instance, CFrame.lookAt(nextPosition, lookTarget) * pivotRotation)
	else
		pivotInstance(monsterState.Instance, getProceduralAnimationCFrame(monsterState, nextPosition, moveDirection, deltaTime))
	end

	updateMonsterSpatialCell(monsterState, nextPosition)
	return true
end

local function updateMonsterDamage(monsterState, now, playerTargets)
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
	local maxAliveMonsters = getCurrentWaveMaxAlive()
	local aliveMonsterCount = getAliveMonsterCount()

	for _, player in ipairs(Players:GetPlayers()) do
		if isPlayerAlive(player) and hasPlayerBeenGroundedLongEnough(player, now) then
			tryRecycleBehindMass(player, now)

			if aliveMonsterCount >= maxAliveMonsters then
				continue
			end

			local lastSpawnAt = lastSpawnAtByUserId[player.UserId] or 0
			local spawnInterval = getCurrentSpawnInterval()

			if now - lastSpawnAt >= spawnInterval then
				lastSpawnAtByUserId[player.UserId] = now

				local spawnBatch = math.max(
					1,
					math.floor(getCurrentWaveSpawnBatch() * PerkService.GetEnemyCountMultiplier(player))
				)
				spawnActivity.Batches += 1
				spawnActivity.Requested += spawnBatch

				for _ = 1, spawnBatch do
					if aliveMonsterCount >= maxAliveMonsters then
						break
					end

					if spawnMonsterNearPlayer(player) then
						aliveMonsterCount += 1
						spawnActivity.Spawned += 1
					else
						spawnActivity.Failed += 1
					end
				end
			end
		end
	end
end

local function updateMonsterStep(deltaTime)
	local now = CombatStateService.GetTime()
	local startedAt = os.clock()
	local playerTargets = getAlivePlayerTargets()
	local lodCounts = createSimulationLodCounts(#playerTargets)

	updateSpawns(now)

	for _, monsterState in pairs(monstersByInstance) do
		if not monsterState.IsDead then
			local root = monsterState.Root

			if root == nil then
				removeMonster(monsterState, nil)
				lodCounts.Despawned += 1
				continue
			end

			local _, targetRoot, distance = getClosestAlivePlayer(root.Position, playerTargets)

			if targetRoot == nil then
				continue
			end

			if distance > CombatConfig.MonsterDespawnDistance then
				removeMonster(monsterState, nil)
				lodCounts.Despawned += 1
				continue
			end

			local lod = getMonsterSimulationLod(monsterState, distance)
			lodCounts[lod] += 1

			local lodDeltaTime = getLodStepDelta(monsterState, lod, now, deltaTime)

			if lodDeltaTime ~= nil then
				lodCounts[lod .. "Steps"] += 1
				local stillActive = updateMonsterMovement(
					monsterState,
					targetRoot,
					distance,
					lodDeltaTime,
					lod == "Full",
					lod == "Full"
				)

				if stillActive and lod == "Full" and not monsterState.IsDead then
					updateMonsterDamage(monsterState, now, playerTargets)
				end
			end
		end
	end

	lastSimulationLodCounts = lodCounts

	local tickDuration = os.clock() - startedAt
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
			SpawnFallbacks = spawnActivity.Fallbacks,
			Recycled = spawnActivity.Recycled,
			RecycleCandidates = spawnActivity.RecycleCandidates,
		})
		elapsedSincePerfLog = 0
		monsterTickTimeTotal = 0
		monsterTickSampleCount = 0
		monsterTickMaxSeconds = 0
		spawnActivity = createSpawnActivity()
	end
end

local function updateMonsters(deltaTime)
	if CombatStateService.IsPaused() then
		return
	end

	local configuredSimulationHz = CombatConfig.MonsterSimulationHz

	if configuredSimulationHz == nil or configuredSimulationHz <= 0 then
		updateMonsterStep(deltaTime)
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
	local result = Workspace:Raycast(
		rayOrigin,
		Vector3.new(0, -CombatConfig.MonsterGroundRaycastDepth, 0),
		raycastParams
	)

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
		spawnActivity = createSpawnActivity()
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
		lastRecycleCheckAtByUserId[player.UserId] = nil
		lastRecycleAtByUserId[player.UserId] = nil
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
