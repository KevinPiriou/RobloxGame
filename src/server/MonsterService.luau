local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))

local CoinService = require(script.Parent:WaitForChild("CoinService"))
local XpService = require(script.Parent:WaitForChild("XpService"))

local MonsterService = {}

local rng = Random.new()
local runtimeFolder = nil
local monsterFolder = nil
local monsterTemplate = nil
local heartbeatConnection = nil
local elapsedStatsUpdate = 0
local waveStartedAt = os.clock()
local monstersByInstance = {}
local killsByUserId = {}
local lastSpawnAtByUserId = {}
local characterConnectionsByUserId = {}
local healthConnectionsByUserId = {}

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

	assert(folder:IsA("Folder"), folderName .. " doit etre un Folder.")

	return folder
end

local function setupFolders()
	runtimeFolder = getOrCreateFolder(Workspace, CombatConfig.RuntimeFolderName)
	monsterFolder = getOrCreateFolder(runtimeFolder, CombatConfig.MonsterFolderName)
end

local function isRuntimeInstance(instance)
	return runtimeFolder ~= nil and instance:IsDescendantOf(runtimeFolder)
end

local function createFallbackMonsterTemplate(templateStorage)
	local part = Instance.new("Part")
	part.Name = CombatConfig.MonsterTemplateName
	part.Size = Vector3.new(3, 4, 3)
	part.Color = Color3.fromRGB(190, 55, 55)
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = true
	part.Parent = templateStorage

	warn("Template Monster1 introuvable. Un monstre simple de secours a ete cree pour le test.")

	return part
end

local function findTemplate(templateName)
	local templateStorage = getOrCreateFolder(ServerStorage, CombatConfig.TemplateFolderName)
	local storedTemplate = templateStorage:FindFirstChild(templateName)

	if storedTemplate ~= nil then
		return storedTemplate
	end

	for _, root in ipairs({ ServerStorage, ReplicatedStorage, Workspace }) do
		local candidate = root:FindFirstChild(templateName, true)

		if candidate ~= nil and not isRuntimeInstance(candidate) and not candidate:IsDescendantOf(templateStorage) then
			if candidate:IsDescendantOf(Workspace) then
				candidate.Parent = templateStorage
				return candidate
			end

			local clone = candidate:Clone()
			clone.Parent = templateStorage
			return clone
		end
	end

	return createFallbackMonsterTemplate(templateStorage)
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
	local animationController = findAnimationController(monster)
	local animation = findAnimation(monster)

	if animationController == nil or animation == nil then
		return nil
	end

	local animator = animationController:FindFirstChildWhichIsA("Animator")

	if animator == nil then
		animator = Instance.new("Animator")
		animator.Parent = animationController
	end

	local success, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)

	if not success then
		warn("Impossible de charger l'animation du monstre : " .. tostring(track))
		return nil
	end

	track.Looped = true
	track:Play()

	return track
end

local function pivotInstance(instance, cframe)
	if instance:IsA("Model") or instance:IsA("BasePart") then
		instance:PivotTo(cframe)
	end
end

local function prepareMonsterInstance(monster)
	local humanoid = findHumanoid(monster)
	local root = findRoot(monster)

	for _, descendant in ipairs(monster:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = true

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
	end

	if humanoid ~= nil then
		humanoid.MaxHealth = CombatConfig.MonsterHealth
		humanoid.Health = CombatConfig.MonsterHealth
		humanoid.WalkSpeed = CombatConfig.MonsterWalkSpeed
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end

	return humanoid, root
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

local function isPlayerAlive(player)
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

local function getCurrentWaveNumber()
	local elapsed = math.max(0, os.clock() - waveStartedAt)

	return math.floor(elapsed / CombatConfig.WaveDuration) + 1
end

local function getCurrentWaveMaxAlive()
	local alivePlayerCount = math.max(1, getAlivePlayerCount())
	local waveNumber = getCurrentWaveNumber()
	local waveMaxAlive = CombatConfig.WaveBaseMaxAlive
		+ ((waveNumber - 1) * CombatConfig.WaveMaxAliveIncrease)

	return math.min(CombatConfig.MonsterMaxAlive, waveMaxAlive * alivePlayerCount)
end

local function getCurrentWaveSpawnBatch()
	local waveNumber = getCurrentWaveNumber()
	local extraBatch = math.floor((waveNumber - 1) / CombatConfig.WaveSpawnBatchIncreaseEvery)

	return math.max(1, CombatConfig.WaveSpawnBatchBase + extraBatch)
end

local function getPlayerStatsPayload(player)
	local humanoid = getCharacterHumanoid(player)
	local health = 0
	local maxHealth = 100
	local waveNumber = getCurrentWaveNumber()

	if humanoid ~= nil then
		health = math.max(0, math.floor(humanoid.Health + 0.5))
		maxHealth = math.max(1, math.floor(humanoid.MaxHealth + 0.5))
	end

	return {
		Health = health,
		MaxHealth = maxHealth,
		AliveMonsters = getAliveMonsterCount(),
		MaxAliveMonsters = getCurrentWaveMaxAlive(),
		Wave = waveNumber,
		Kills = killsByUserId[player.UserId] or 0,
		WeaponName = CombatConfig.FireballTemplateName,
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
			for _ = 1, CombatConfig.XpGemsPerMonster do
				XpService.SpawnXpGem(deathPosition + getLootScatterOffset())
			end

			if rng:NextNumber() <= CombatConfig.CoinDropChance then
				local coinDropCount = rng:NextInteger(CombatConfig.CoinDropsMin, CombatConfig.CoinDropsMax)

				for _ = 1, coinDropCount do
					CoinService.SpawnCoin(deathPosition + getLootScatterOffset())
				end
			end
		end
	end

	if monsterState.Instance.Parent ~= nil then
		monsterState.Instance:Destroy()
	end

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

local function getSpawnPositionNearPlayer(player)
	local root = getCharacterRoot(player)

	if root == nil then
		return nil
	end

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
		return result.Position + Vector3.new(0, CombatConfig.MonsterSpawnHeightOffset, 0)
	end

	return root.Position + horizontalOffset + Vector3.new(0, CombatConfig.MonsterSpawnHeightOffset, 0)
end

local function spawnMonsterNearPlayer(player)
	if monsterTemplate == nil or not isPlayerAlive(player) then
		return false
	end

	local spawnPosition = getSpawnPositionNearPlayer(player)

	if spawnPosition == nil then
		return false
	end

	local monster = monsterTemplate:Clone()

	monster.Name = CombatConfig.MonsterTemplateName
	monster:SetAttribute("RuntimeMonster", true)
	monster.Parent = monsterFolder

	local humanoid, root = prepareMonsterInstance(monster)

	if root == nil then
		warn("Monster1 ne contient aucune BasePart, impossible de le deplacer.")
		monster:Destroy()
		return false
	end

	pivotInstance(monster, CFrame.new(spawnPosition))

	local monsterState = {
		Instance = monster,
		Humanoid = humanoid,
		Root = root,
		BasePosition = spawnPosition,
		Health = CombatConfig.MonsterHealth,
		AnimationTrack = playMonsterAnimation(monster),
		AnimationTime = rng:NextNumber(0, 10),
		LastMoveToAt = 0,
		LastDamageByUserId = {},
		IsDead = false,
	}

	monstersByInstance[monster] = monsterState

	monster.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			monstersByInstance[monster] = nil
		end
	end)

	if humanoid ~= nil then
		humanoid.Died:Connect(function()
			removeMonster(monsterState, monsterState.PendingKiller)
		end)
	end

	return true
end

local function getGridKey(cellX, cellZ)
	return tostring(cellX) .. ":" .. tostring(cellZ)
end

local function buildMonsterSpatialGrid()
	local grid = {}
	local cellSize = CombatConfig.MonsterSeparationRadius

	for _, monsterState in pairs(monstersByInstance) do
		if not monsterState.IsDead then
			local root = findRoot(monsterState.Instance)

			if root ~= nil then
				monsterState.Root = root

				local cellX = math.floor(root.Position.X / cellSize)
				local cellZ = math.floor(root.Position.Z / cellSize)
				local key = getGridKey(cellX, cellZ)

				if grid[key] == nil then
					grid[key] = {}
				end

				monsterState.SeparationCellX = cellX
				monsterState.SeparationCellZ = cellZ
				table.insert(grid[key], monsterState)
			end
		end
	end

	return grid
end

local function getMonsterSeparation(monsterState, spatialGrid)
	local root = monsterState.Root

	if root == nil or monsterState.SeparationCellX == nil or monsterState.SeparationCellZ == nil then
		return Vector3.zero
	end

	local radius = CombatConfig.MonsterSeparationRadius
	local separation = Vector3.zero

	for offsetX = -1, 1 do
		for offsetZ = -1, 1 do
			local key = getGridKey(monsterState.SeparationCellX + offsetX, monsterState.SeparationCellZ + offsetZ)
			local cell = spatialGrid[key]

			if cell ~= nil then
				for _, otherState in ipairs(cell) do
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

	return CFrame.lookAt(visualPosition, lookTarget) * CFrame.Angles(0, 0, sway)
end

local function updateMonsterMovement(monsterState, deltaTime, now, spatialGrid)
	local root = findRoot(monsterState.Instance)

	if root == nil then
		removeMonster(monsterState, nil)
		return
	end

	monsterState.Root = root

	local _, targetRoot, distance = getClosestAlivePlayer(root.Position)

	if targetRoot == nil then
		return
	end

	if distance > CombatConfig.MonsterDespawnDistance then
		removeMonster(monsterState, nil)
		return
	end

	local separation = getMonsterSeparation(monsterState, spatialGrid)

	if monsterState.Humanoid ~= nil then
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
					getCharacterHumanoid(player):TakeDamage(CombatConfig.MonsterAttackDamage)
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

		if isPlayerAlive(player) then
			local lastSpawnAt = lastSpawnAtByUserId[player.UserId] or 0

			if now - lastSpawnAt >= CombatConfig.MonsterSpawnInterval then
				lastSpawnAtByUserId[player.UserId] = now

				for _ = 1, getCurrentWaveSpawnBatch() do
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

local function updateMonsters(deltaTime)
	local now = os.clock()

	updateSpawns(now)

	local spatialGrid = buildMonsterSpatialGrid()

	for _, monsterState in pairs(monstersByInstance) do
		if not monsterState.IsDead then
			updateMonsterMovement(monsterState, deltaTime, now, spatialGrid)
			updateMonsterDamage(monsterState, now)
		end
	end

	elapsedStatsUpdate += deltaTime

	if elapsedStatsUpdate >= CombatConfig.StatsUpdateInterval then
		elapsedStatsUpdate = 0
		sendStatsToAll()
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
	killsByUserId[player.UserId] = killsByUserId[player.UserId] or 0
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

	if characterConnectionsByUserId[player.UserId] ~= nil then
		characterConnectionsByUserId[player.UserId]:Disconnect()
		characterConnectionsByUserId[player.UserId] = nil
	end

	if healthConnectionsByUserId[player.UserId] ~= nil then
		healthConnectionsByUserId[player.UserId]:Disconnect()
		healthConnectionsByUserId[player.UserId] = nil
	end
end

function MonsterService.GetClosestMonster(position, maxDistance)
	local closestMonster = nil
	local closestRoot = nil
	local closestDistance = maxDistance or math.huge

	for _, monsterState in pairs(monstersByInstance) do
		if not monsterState.IsDead then
			local root = findRoot(monsterState.Instance)

			if root ~= nil then
				local distance = (root.Position - position).Magnitude

				if distance <= closestDistance then
					closestMonster = monsterState.Instance
					closestRoot = root
					closestDistance = distance
				end
			end
		end
	end

	return closestMonster, closestRoot, closestDistance
end

function MonsterService.GetMonsterPosition(monster)
	local monsterState = getMonsterStateFromInstance(monster)

	if monsterState == nil or monsterState.IsDead then
		return nil
	end

	local root = findRoot(monsterState.Instance)

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

	if monsterState.Humanoid ~= nil then
		monsterState.PendingKiller = attacker
		monsterState.Humanoid:TakeDamage(damage)

		if monsterState.Humanoid.Health <= 0 then
			removeMonster(monsterState, attacker)
		end

		return true
	end

	monsterState.Health -= damage
	monsterState.Instance:SetAttribute("MonsterHealth", monsterState.Health)

	if monsterState.Health <= 0 then
		removeMonster(monsterState, attacker)
	end

	return true
end

function MonsterService.Start()
	setupFolders()
	monsterTemplate = findTemplate(CombatConfig.MonsterTemplateName)
	waveStartedAt = os.clock()

	if heartbeatConnection ~= nil then
		return
	end

	heartbeatConnection = RunService.Heartbeat:Connect(updateMonsters)
end

return MonsterService
