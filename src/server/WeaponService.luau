local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))
local DebugLog = require(Shared:WaitForChild("DebugLog"))

local CombatStateService = require(script.Parent:WaitForChild("CombatStateService"))
local AudioService = require(script.Parent:WaitForChild("AudioService"))
local MonsterService = require(script.Parent:WaitForChild("MonsterService"))
local PerkService = require(script.Parent:WaitForChild("PerkService"))
local RunStateService = require(script.Parent:WaitForChild("RunStateService"))
local TemplateService = require(script.Parent:WaitForChild("TemplateService"))
local ProjectileVisualService = require(script.Parent:WaitForChild("ProjectileVisualService"))
local WeaponSkinService = require(script.Parent:WaitForChild("WeaponSkinService"))
local WeaponHitService = require(script.Parent:WaitForChild("WeaponHitService"))
local WeaponLoadoutService = require(script.Parent:WaitForChild("WeaponLoadoutService"))
local PerformanceTelemetryService = require(script.Parent:WaitForChild("PerformanceTelemetryService"))

local WeaponService = {}

local runtimeFolder = nil
local projectileFolder = nil
local projectilePoolFolder = nil
local projectileSimulationFolder = nil
local fireballTemplate = nil
local heartbeatConnection = nil
local projectileAccumulator = 0
local projectileTickTimeTotal = 0
local projectileTickSampleCount = 0
local cooldownsByUserId = {}
local projectilesByInstance = {}
local pendingFireballVolleysByUserId = {}
local projectileSerial = 0
-- Les profils donnent des tirs lisibles mais jamais parfaitement rectilignes.
local FIREBALL_FLIGHT_PATTERNS = {
	{ SideMultiplier = 1, VerticalMultiplier = 0.62, FrequencyMultiplier = 0.9 },
	{ SideMultiplier = -0.86, VerticalMultiplier = 1, FrequencyMultiplier = 1.12 },
	{ SideMultiplier = 0.7, VerticalMultiplier = -0.55, FrequencyMultiplier = 1.28 },
	{ SideMultiplier = -1, VerticalMultiplier = 0.38, FrequencyMultiplier = 0.78 },
}

local function getFireballRuntimeStats(player: Player)
	return WeaponLoadoutService.GetRuntimeStats(player, "fireball") or {
		Damage = CombatConfig.FireballDamage,
		Cooldown = CombatConfig.FireballCooldown,
		Range = CombatConfig.FireballRange,
		ProjectileCount = 0,
		BounceCount = 0,
	}
end

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
	projectileFolder = TemplateService.GetCombatProjectileFolder()
	projectilePoolFolder = getOrCreateFolder(ServerStorage, "ProjectilePools")
	projectileSimulationFolder = getOrCreateFolder(ServerStorage, "ProjectileSimulation")
end

local function createFallbackFireballTemplate(templateStorage)
	local part = Instance.new("Part")
	part.Name = CombatConfig.FireballTemplateName
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(1.4, 1.4, 1.4)
	part.Color = Color3.fromRGB(255, 105, 45)
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Parent = templateStorage

	DebugLog.Warn("Weapon", "Template Fireball introuvable, fallback cree", {
		Template = CombatConfig.FireballTemplateName,
	})

	return part
end

local function findTemplate(templateName)
	return TemplateService.GetTemplate(CombatConfig.TemplateFolderName, templateName, createFallbackFireballTemplate)
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

	local firstPart = instance:FindFirstChildWhichIsA("BasePart", true)

	if firstPart ~= nil then
		instance.PrimaryPart = firstPart
	end

	return firstPart
end

local function pivotInstance(instance, cframe)
	if instance:IsA("Model") or instance:IsA("BasePart") then
		instance:PivotTo(cframe)
	end
end

local function prepareProjectile(projectile)
	if projectile:IsA("BasePart") then
		projectile.Anchored = true
		projectile.CanCollide = false
		projectile.CanTouch = false
		projectile.CanQuery = false
	end

	for _, descendant in ipairs(projectile:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		end
	end

	return findRoot(projectile)
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
	if not RunStateService.IsRunActive(player) then
		return false
	end

	local humanoid = getCharacterHumanoid(player)
	local root = getCharacterRoot(player)

	return humanoid ~= nil and root ~= nil and humanoid.Health > 0
end

local function getProjectilePoolSize()
	if projectilePoolFolder == nil then
		return 0
	end

	return #projectilePoolFolder:GetChildren()
end

local function acquireProjectileInstance(activeFolder)
	local projectile = projectilePoolFolder:FindFirstChild(CombatConfig.FireballTemplateName)

	if projectile == nil then
		projectile = projectilePoolFolder:FindFirstChildWhichIsA("Model")
			or projectilePoolFolder:FindFirstChildWhichIsA("BasePart")
	end

	if projectile ~= nil then
		projectile.Parent = activeFolder
		return projectile, true
	end

	projectile = fireballTemplate:Clone()
	projectile.Parent = activeFolder

	return projectile, false
end

local function releaseProjectileInstance(projectile)
	if projectile == nil or projectile.Parent == nil then
		return
	end

	if projectile:GetAttribute("BenchmarkProjectile") == true then
		PerformanceTelemetryService.Increment("Weapon.Projectiles.BenchmarkReleased")
	end

	projectile.Name = CombatConfig.FireballTemplateName
	projectile:SetAttribute("RuntimeProjectile", false)
	projectile:SetAttribute("BenchmarkProjectile", nil)
	projectile:SetAttribute("WeaponId", nil)
	projectile:SetAttribute("VfxProfileId", nil)
	projectile:SetAttribute("ProjectileSkinId", nil)
	projectile:SetAttribute("ProjectileOwnerUserId", nil)
	projectile:SetAttribute("ProjectileVisualSerial", nil)
	projectile.Parent = projectilePoolFolder
end

local function prewarmProjectilePool(count)
	local prewarmCount = math.max(0, math.floor(count or 0))

	if fireballTemplate == nil or prewarmCount <= 0 then
		return
	end

	for _ = 1, prewarmCount do
		local projectile = fireballTemplate:Clone()
		projectile.Name = CombatConfig.FireballTemplateName
		prepareProjectile(projectile)
		projectile.Parent = projectilePoolFolder
	end

	DebugLog.Info("Perf", "Pool projectiles prechauffe", {
		Template = CombatConfig.FireballTemplateName,
		Count = prewarmCount,
	})
end

local function destroyProjectile(projectile)
	local state = projectilesByInstance[projectile]

	if state ~= nil and state.ClientPresentationMode == "ClientPilot" then
		ProjectileVisualService.PlayClientProjectileDestroy(state.Owner, state.VisualSerial)
		PerformanceTelemetryService.Increment("Weapon.Projectiles.ClientPilotDestroys")
	end

	projectilesByInstance[projectile] = nil

	releaseProjectileInstance(projectile)
end

local function resolveProjectilePresentationMode(_player, requestedPresentationMode)
	if requestedPresentationMode == "ClientPilot" or requestedPresentationMode == "ReplicatedCore" then
		return requestedPresentationMode
	end

	return if CombatConfig.ProjectilePresentationMode == "ReplicatedCore" then "ReplicatedCore" else "ClientPilot"
end

local function createProjectile(
	player,
	spawnPosition,
	targetMonster,
	targetRoot,
	direction,
	pattern,
	phase,
	benchmarkTargetPosition,
	presentationMode
)
	local clientPresentationMode = resolveProjectilePresentationMode(player, presentationMode)
	local activeFolder = if clientPresentationMode == "ClientPilot" then projectileSimulationFolder else projectileFolder
	local projectile, reusedFromPool = acquireProjectileInstance(activeFolder)
	PerformanceTelemetryService.Increment("Weapon.Projectiles.Created")
	PerformanceTelemetryService.Increment(
		if reusedFromPool then "Weapon.Projectiles.ReusedFromPool" else "Weapon.Projectiles.Cloned"
	)

	projectile.Name = CombatConfig.FireballTemplateName
	projectile:SetAttribute("RuntimeProjectile", true)
	projectile:SetAttribute("BenchmarkProjectile", benchmarkTargetPosition ~= nil)

	local projectileRoot = prepareProjectile(projectile)

	if projectileRoot == nil then
		DebugLog.Warn("Weapon", "Projectile Fireball sans BasePart, tir annule", {
			Projectile = projectile,
		})
		releaseProjectileInstance(projectile)
		return false
	end

	local vfxProfileId = ProjectileVisualService.PrepareFireball(
		projectile,
		projectileRoot,
		player,
		WeaponSkinService.GetSelectedFireballSkin(player),
		projectileSerial
	)

	if vfxProfileId == nil then
		releaseProjectileInstance(projectile)
		return false
	end

	if clientPresentationMode == "ReplicatedCore" then
		pivotInstance(projectile, CFrame.lookAt(spawnPosition, spawnPosition + direction))
	end

	local projectileState = {
		Instance = projectile,
		Owner = player,
		TargetMonster = targetMonster,
		BenchmarkTargetPosition = benchmarkTargetPosition,
		Position = spawnPosition,
		Direction = direction.Unit,
		Age = 0,
		Speed = PerkService.GetProjectileSpeed(player, CombatConfig.FireballSpeed),
		Lifetime = PerkService.GetAttackDuration(player, CombatConfig.FireballLifetime),
		FlightPattern = pattern,
		FlightPhase = phase,
		HomingDelay = CombatConfig.FireballHomingDelay,
		BounceRemaining = PerkService.GetBounceCount(player) + (getFireballRuntimeStats(player).BounceCount or 0),
		Damage = getFireballRuntimeStats(player).Damage,
		HitMonsters = {},
		ReusedFromPool = reusedFromPool,
		VfxProfileId = vfxProfileId,
		VisualSerial = projectileSerial,
		ClientPresentationMode = clientPresentationMode,
	}
	projectilesByInstance[projectile] = projectileState

	if clientPresentationMode == "ClientPilot" then
		local initialTargetPosition = benchmarkTargetPosition

		if initialTargetPosition == nil and targetRoot ~= nil then
			initialTargetPosition = targetRoot.Position
		end

		if initialTargetPosition == nil then
			DebugLog.Warn("Vfx", "Pilote projectile annule sans cible visuelle", {
				Player = player.Name,
				VisualSerial = projectileSerial,
			})
		else
			ProjectileVisualService.PlayClientProjectileSpawn(player, {
				Type = "ProjectileSpawn",
				VisualSerial = projectileSerial,
				ProfileId = vfxProfileId,
				Position = spawnPosition,
				Direction = direction,
				TargetPosition = initialTargetPosition,
				TargetRoot = targetRoot,
				Speed = projectileState.Speed,
				Lifetime = projectileState.Lifetime,
				HomingDelay = projectileState.HomingDelay,
				FlightPattern = pattern,
				FlightPhase = phase,
				CoreSize = projectileRoot.Size,
				ServerStartTime = Workspace:GetServerTimeNow(),
			})
			PerformanceTelemetryService.Increment("Weapon.Projectiles.ClientPilotSpawns")
		end
	end

	DebugLog.ThrottledInfo("Weapon", "fireball_created_" .. player.UserId, 1, "Projectile cree", {
		Player = player.Name,
		Position = spawnPosition,
		ProjectileCount = PerkService.GetProjectileCount(player),
		Target = targetMonster,
	})

	return true
end

local function rotateDirection(direction, radians)
	local rotation = CFrame.fromAxisAngle(Vector3.new(0, 1, 0), radians)

	return rotation:VectorToWorldSpace(direction).Unit
end

local function clampProjectileDirection(direction)
	local minimumVerticalDirection = CombatConfig.FireballMinimumVerticalDirection or -0.05

	if direction.Y >= minimumVerticalDirection then
		return direction.Unit
	end

	return Vector3.new(direction.X, minimumVerticalDirection, direction.Z).Unit
end

local function createInitialProjectileDirection(targetDirection, projectileIndex)
	projectileSerial += 1

	local seed = (projectileSerial * 7919) + (projectileIndex * 104729)
	local random = Random.new(seed)
	local launchAngle = random:NextNumber(
		-(CombatConfig.FireballLaunchAngleRadians or math.rad(90)),
		CombatConfig.FireballLaunchAngleRadians or math.rad(90)
	)
	local upwardKick = random:NextNumber(0.06, 0.24)
	local direction = rotateDirection(targetDirection.Unit, launchAngle) + Vector3.new(0, upwardKick, 0)
	local patternIndex = ((projectileSerial - 1) % #FIREBALL_FLIGHT_PATTERNS) + 1

	return clampProjectileDirection(direction), FIREBALL_FLIGHT_PATTERNS[patternIndex], random:NextNumber(0, math.pi * 2)
end

local function getTargetCandidates(position)
	local targets = MonsterService.GetMonstersNear(position, CombatConfig.FireballRange)

	table.sort(targets, function(first, second)
		return first.DistanceSquared < second.DistanceSquared
	end)

	return targets
end

local function getFireballSpawnPosition(player)
	local root = getCharacterRoot(player)

	if root == nil then
		return nil
	end

	return root.Position
		+ (root.CFrame.LookVector * CombatConfig.FireballSpawnForwardOffset)
		+ Vector3.new(0, CombatConfig.FireballSpawnHeightOffset, 0)
end

local function playFireballCast(player)
	if AudioService.PlayForPlayer(player, "FireballCast") then
		PerformanceTelemetryService.Increment("Weapon.Projectiles.CastAudioEvents")
	end
end

local function emitFireballVolleyShot(player, targetData, projectileIndex)
	if not isPlayerAlive(player) or targetData == nil then
		return false
	end

	local spawnPosition = getFireballSpawnPosition(player)
	local targetPosition = MonsterService.GetMonsterPosition(targetData.Monster)

	if spawnPosition == nil or targetPosition == nil then
		return false
	end

	local direction = targetPosition - spawnPosition

	if direction.Magnitude <= 0.1 then
		return false
	end

	local projectileDirection, pattern, phase = createInitialProjectileDirection(direction.Unit, projectileIndex)
	local didCreate = createProjectile(
		player,
		spawnPosition,
		targetData.Monster,
		targetData.Root,
		projectileDirection,
		pattern,
		phase
	)

	if didCreate then
		playFireballCast(player)
	end

	return didCreate
end

local function getFireballVolleyShotDelay(projectileCount, cooldown)
	if projectileCount <= 1 then
		return 0
	end

	local desiredInterval = math.max(0, CombatConfig.FireballVolleyProjectileInterval or 0)
	local endGuard = math.max(0, CombatConfig.FireballVolleyEndGuard or 0)
	local availableDuration = math.max(0, cooldown - endGuard)
	local maximumInterval = availableDuration / (projectileCount - 1)

	return math.min(desiredInterval, maximumInterval)
end

local function getPendingVolleyCounts()
	local activeVolleys = 0
	local pendingShots = 0

	for _, volley in pairs(pendingFireballVolleysByUserId) do
		activeVolleys += 1
		pendingShots += math.max(0, #volley.Targets - volley.NextShotIndex + 1)
	end

	return activeVolleys, pendingShots
end

local function updatePendingFireballVolleys(now)
	for userId, volley in pairs(pendingFireballVolleysByUserId) do
		if not isPlayerAlive(volley.Player) then
			pendingFireballVolleysByUserId[userId] = nil
			continue
		end

		if now < volley.NextShotAt then
			continue
		end

		local targetData = volley.Targets[volley.NextShotIndex]
		emitFireballVolleyShot(volley.Player, targetData, volley.NextShotIndex)
		volley.NextShotIndex += 1
		volley.NextShotAt += volley.Interval

		-- Une frame retardee ne transforme jamais les tirs dus en nouvelle rafale.
		-- Le reste de la salve reprend un projectile par frame apres le retard.
		if volley.NextShotIndex > #volley.Targets then
			pendingFireballVolleysByUserId[userId] = nil
		end
	end
end

local function fireAtClosestMonster(player, now, cooldown, emitAllImmediately)
	if fireballTemplate == nil or not isPlayerAlive(player) then
		return
	end

	local spawnPosition = getFireballSpawnPosition(player)

	if spawnPosition == nil then
		return
	end

	local targets = getTargetCandidates(spawnPosition)
	local firstTarget = targets[1]
	local targetMonster = if firstTarget ~= nil then firstTarget.Monster else nil
	local targetRoot = if firstTarget ~= nil then firstTarget.Root else nil

	if targetMonster == nil or targetRoot == nil then
		DebugLog.ThrottledInfo("Weapon", "no_target_" .. player.UserId, 3, "Aucune cible Fireball en portee", {
			Player = player.Name,
			Range = CombatConfig.FireballRange,
			Position = spawnPosition,
		})
		return
	end

	local runtimeStats = getFireballRuntimeStats(player)
	local projectileCount = math.max(1, PerkService.GetProjectileCount(player) + (runtimeStats.ProjectileCount or 0))
	local volleyTargets = {}

	for projectileIndex = 1, projectileCount do
		-- On couvre les cibles proches avant de repasser sur la premiere si les projectiles sont plus nombreux.
		volleyTargets[projectileIndex] = targets[((projectileIndex - 1) % #targets) + 1]
	end

	if not emitFireballVolleyShot(player, volleyTargets[1], 1) then
		return
	end

	if projectileCount > 1 then
		if emitAllImmediately then
			for projectileIndex = 2, projectileCount do
				emitFireballVolleyShot(player, volleyTargets[projectileIndex], projectileIndex)
			end
		else
			local volleyInterval = getFireballVolleyShotDelay(projectileCount, cooldown)
			pendingFireballVolleysByUserId[player.UserId] = {
				Player = player,
				Targets = volleyTargets,
				NextShotIndex = 2,
				NextShotAt = now + volleyInterval,
				Interval = volleyInterval,
			}
		end
	end

end

local function updatePlayerWeapons(now)
	updatePendingFireballVolleys(now)

	for _, player in ipairs(Players:GetPlayers()) do
		if not RunStateService.IsRunActive(player) then
			continue
		end

		if pendingFireballVolleysByUserId[player.UserId] ~= nil then
			continue
		end

		local lastFireAt = cooldownsByUserId[player.UserId] or 0
		local cooldown = PerkService.GetAttackCooldown(player, getFireballRuntimeStats(player).Cooldown)

		if now - lastFireAt >= cooldown then
			cooldownsByUserId[player.UserId] = now
			fireAtClosestMonster(player, now, cooldown)
		end
	end
end

local function updateProjectile(projectileState, deltaTime)
	local projectile = projectileState.Instance

	if projectile.Parent == nil then
		projectilesByInstance[projectile] = nil
		return
	end

	projectileState.Age += deltaTime

	if projectileState.Age >= projectileState.Lifetime then
		if projectileState.BenchmarkTargetPosition ~= nil then
			PerformanceTelemetryService.Increment("Weapon.Projectiles.BenchmarkExpired")
		end
		destroyProjectile(projectile)
		return
	end

	local targetPosition = projectileState.BenchmarkTargetPosition

	if targetPosition == nil then
		targetPosition = MonsterService.GetMonsterPosition(projectileState.TargetMonster)
	end

	if targetPosition ~= nil then
		local desiredDirection = targetPosition - projectileState.Position

		if desiredDirection.Magnitude > 0.1 then
			local targetDirection = desiredDirection.Unit
			local sideDirection = Vector3.new(-targetDirection.Z, 0, targetDirection.X)

			if sideDirection.Magnitude <= 0.001 then
				sideDirection = Vector3.new(1, 0, 0)
			else
				sideDirection = sideDirection.Unit
			end

			local speedRatio = math.max(0.25, projectileState.Speed / math.max(1, CombatConfig.FireballSpeed))
			local curveDuration = math.max(0.08, (CombatConfig.FireballCurveDuration or 1) / speedRatio)
			local curveProgress = math.clamp((projectileState.Age - projectileState.HomingDelay) / curveDuration, 0, 1)
			local curveWeight = (1 - curveProgress) * (CombatConfig.FireballCurveStrength or 0)
			local pattern = projectileState.FlightPattern or FIREBALL_FLIGHT_PATTERNS[1]
			local oscillation = projectileState.FlightPhase
				+ (projectileState.Age * (CombatConfig.FireballCurveFrequency or 1) * pattern.FrequencyMultiplier)
			local lateralCurve = math.sin(oscillation) * curveWeight * pattern.SideMultiplier
			local verticalCurve = math.cos(oscillation * 0.82) * (CombatConfig.FireballVerticalCurveStrength or 0)
				* curveWeight
				* pattern.VerticalMultiplier
			local curvedDirection = clampProjectileDirection(
				targetDirection + (sideDirection * lateralCurve) + Vector3.new(0, verticalCurve, 0)
			)
			local steeringWeight = 0.2 + (0.8 * curveProgress)
			local homingAlpha = math.clamp(
				deltaTime * (CombatConfig.FireballHomingStrength or 1) * math.sqrt(speedRatio) * steeringWeight,
				0,
				1
			)

			projectileState.Direction = clampProjectileDirection(projectileState.Direction:Lerp(curvedDirection, homingAlpha))
		end
	end

	local nextPosition = projectileState.Position + (projectileState.Direction * projectileState.Speed * deltaTime)
	projectileState.Position = nextPosition

	PerformanceTelemetryService.Increment("Weapon.Projectiles.LogicalUpdates")

	if projectileState.ClientPresentationMode == "ReplicatedCore" then
		pivotInstance(projectile, CFrame.lookAt(nextPosition, nextPosition + projectileState.Direction))
		PerformanceTelemetryService.Increment("Weapon.Projectiles.TransformUpdates")
	end

	local didReachBenchmarkTarget = false
	local hitMonster = nil

	if projectileState.BenchmarkTargetPosition ~= nil then
		didReachBenchmarkTarget = (nextPosition - projectileState.BenchmarkTargetPosition).Magnitude
			<= CombatConfig.FireballHitRadius
	else
		hitMonster = MonsterService.GetClosestMonster(nextPosition, CombatConfig.FireballHitRadius, projectileState.HitMonsters)
	end

	if didReachBenchmarkTarget then
		ProjectileVisualService.PlayProjectileImpact(
			projectileState.Owner,
			projectileState.VfxProfileId,
			nextPosition,
			projectileState.VisualSerial
		)
		PerformanceTelemetryService.Increment("Weapon.Projectiles.BenchmarkImpacts")
		destroyProjectile(projectile)
		return
	end

	if hitMonster ~= nil then
		projectileState.HitMonsters[hitMonster] = true
		local impactPosition = MonsterService.GetMonsterPosition(hitMonster) or nextPosition
		ProjectileVisualService.PlayProjectileImpact(
			projectileState.Owner,
			projectileState.VfxProfileId,
			impactPosition,
			projectileState.VisualSerial
		)
		WeaponHitService.Apply(
			projectileState.Owner,
			hitMonster,
			CombatConfig.FireballTemplateName,
			projectileState.Damage or CombatConfig.FireballDamage
		)

		if projectileState.BounceRemaining > 0 then
			local nextMonster, nextRoot = MonsterService.GetClosestMonster(
				nextPosition,
				CombatConfig.FireballRange,
				projectileState.HitMonsters
			)

			if nextMonster ~= nil and nextRoot ~= nil then
				local nextDirection = nextRoot.Position - nextPosition

				if nextDirection.Magnitude > 0.1 then
					projectileState.BounceRemaining -= 1
					projectileState.TargetMonster = nextMonster
					projectileState.Direction = nextDirection.Unit

					if projectileState.ClientPresentationMode == "ClientPilot" then
						ProjectileVisualService.PlayClientProjectileRetarget(projectileState.Owner, {
							Type = "ProjectileRetarget",
							VisualSerial = projectileState.VisualSerial,
							Position = nextPosition,
							Direction = projectileState.Direction,
							TargetPosition = nextRoot.Position,
							TargetRoot = nextRoot,
							ServerTime = Workspace:GetServerTimeNow(),
						})
						PerformanceTelemetryService.Increment("Weapon.Projectiles.ClientPilotRetargets")
					end

					return
				end
			end
		end

		destroyProjectile(projectile)
	end
end

local function updateProjectiles(deltaTime)
	for _, projectileState in pairs(projectilesByInstance) do
		updateProjectile(projectileState, deltaTime)
	end
end

local function getActiveProjectileCount()
	local count = 0

	for _ in pairs(projectilesByInstance) do
		count += 1
	end

	return count
end

local function updateWeaponStep(deltaTime)
	local startedAt = os.clock()
	local now = CombatStateService.GetTime()

	updatePlayerWeapons(now)
	updateProjectiles(deltaTime)

	local tickDuration = os.clock() - startedAt
	PerformanceTelemetryService.Record("Weapon.TickSeconds", tickDuration)
	projectileTickTimeTotal += tickDuration
	projectileTickSampleCount += 1

	local averageTickMs = 0

	if projectileTickSampleCount > 0 then
		averageTickMs = (projectileTickTimeTotal / projectileTickSampleCount) * 1000
	end

	local activeVolleys, pendingVolleyShots = getPendingVolleyCounts()

	DebugLog.ThrottledInfo("Perf", "projectile_tick", CombatConfig.PerfLogInterval or 5, "Perf projectiles serveur", {
		Active = getActiveProjectileCount(),
		Pool = getProjectilePoolSize(),
		SimulationHz = CombatConfig.ProjectileSimulationHz,
		AverageTickMs = averageTickMs,
		ActiveVolleys = activeVolleys,
		PendingVolleyShots = pendingVolleyShots,
	})
end

function WeaponService.RemovePlayer(player)
	cooldownsByUserId[player.UserId] = nil
	pendingFireballVolleysByUserId[player.UserId] = nil
end

local function clearProjectiles()
	for projectile in pairs(projectilesByInstance) do
		destroyProjectile(projectile)
	end
end

function WeaponService.GetPerformanceSnapshot()
	return {
		Active = getActiveProjectileCount(),
		Pool = getProjectilePoolSize(),
	}
end

function WeaponService.ClearProjectilesForBenchmark()
	clearProjectiles()
end

function WeaponService.DebugFireballBurst(player, requestedCount)
	local burstCount = math.clamp(math.floor(requestedCount or 0), 0, 96)
	local now = CombatStateService.GetTime()
	local cooldown = PerkService.GetAttackCooldown(player, CombatConfig.FireballCooldown)

	for _ = 1, burstCount do
		fireAtClosestMonster(player, now, cooldown, true)
	end

	return burstCount
end

function WeaponService.DebugFireballBurstAtPositions(player, targetPositions, requestedCount, presentationMode)
	if not isPlayerAlive(player) or typeof(targetPositions) ~= "table" then
		return 0
	end

	local burstCount = math.clamp(math.floor(requestedCount or 0), 0, 96)
	local availableTargets = {}

	for _, targetPosition in ipairs(targetPositions) do
		if typeof(targetPosition) == "Vector3" then
			table.insert(availableTargets, targetPosition)
		end
	end

	if burstCount <= 0 or #availableTargets <= 0 then
		return 0
	end

	local emittedCount = 0

	for projectileIndex = 1, burstCount do
		local spawnPosition = getFireballSpawnPosition(player)
		local targetPosition = availableTargets[((projectileIndex - 1) % #availableTargets) + 1]

		if spawnPosition == nil then
			break
		end

		local direction = targetPosition - spawnPosition

		if direction.Magnitude <= 0.1 then
			continue
		end

		local projectileDirection, pattern, phase = createInitialProjectileDirection(direction.Unit, projectileIndex)
		local didCreate = createProjectile(
			player,
			spawnPosition,
			nil,
			nil,
			projectileDirection,
			pattern,
			phase,
			targetPosition,
			presentationMode
		)

		if didCreate then
			playFireballCast(player)
			emittedCount += 1
		end
	end

	PerformanceTelemetryService.Increment("Weapon.Projectiles.BenchmarkShotsRequested", burstCount)
	PerformanceTelemetryService.Increment("Weapon.Projectiles.BenchmarkShotsEmitted", emittedCount)

	return emittedCount
end

function WeaponService.Start()
	setupFolders()
	fireballTemplate = findTemplate(CombatConfig.FireballTemplateName)
	prewarmProjectilePool(CombatConfig.ProjectilePoolPrewarm)

	DebugLog.Info("Weapon", "WeaponService demarre", {
		RuntimeFolder = runtimeFolder,
		ProjectileFolder = projectileFolder,
		Template = fireballTemplate,
		Cooldown = CombatConfig.FireballCooldown,
		Range = CombatConfig.FireballRange,
		SimulationHz = CombatConfig.ProjectileSimulationHz,
	})

	RunStateService.RunStarted:Connect(function(player)
		cooldownsByUserId[player.UserId] = CombatStateService.GetTime()
		pendingFireballVolleysByUserId[player.UserId] = nil
		projectileAccumulator = 0
		projectileTickTimeTotal = 0
		projectileTickSampleCount = 0
	end)

	RunStateService.RunEnded:Connect(function(player)
		cooldownsByUserId[player.UserId] = nil
		pendingFireballVolleysByUserId[player.UserId] = nil
		projectileAccumulator = 0
		clearProjectiles()
	end)

	if heartbeatConnection ~= nil then
		return
	end

	heartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime)
		if CombatStateService.IsPaused() then
			return
		end

		local simulationHz = CombatConfig.ProjectileSimulationHz or 0

		if simulationHz <= 0 then
			updateWeaponStep(deltaTime)
			return
		end

		local fixedStep = 1 / simulationHz
		local maxStepsPerHeartbeat = 4
		local steps = 0

		projectileAccumulator += deltaTime

		while projectileAccumulator >= fixedStep and steps < maxStepsPerHeartbeat do
			projectileAccumulator -= fixedStep
			steps += 1
			updateWeaponStep(fixedStep)
		end

		if steps >= maxStepsPerHeartbeat and projectileAccumulator >= fixedStep then
			projectileAccumulator = fixedStep
		end
	end)
end

return WeaponService
