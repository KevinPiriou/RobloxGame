local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))

local CombatStateService = require(script.Parent:WaitForChild("CombatStateService"))
local MonsterService = require(script.Parent:WaitForChild("MonsterService"))
local PerkService = require(script.Parent:WaitForChild("PerkService"))

local WeaponService = {}

local runtimeFolder = nil
local projectileFolder = nil
local fireballTemplate = nil
local heartbeatConnection = nil
local cooldownsByUserId = {}
local projectilesByInstance = {}

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
	projectileFolder = getOrCreateFolder(runtimeFolder, CombatConfig.ProjectileFolderName)
end

local function isRuntimeInstance(instance)
	return runtimeFolder ~= nil and instance:IsDescendantOf(runtimeFolder)
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

	warn("Template Fireball introuvable. Une boule de feu simple de secours a ete creee pour le test.")

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

	return createFallbackFireballTemplate(templateStorage)
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
	local humanoid = getCharacterHumanoid(player)
	local root = getCharacterRoot(player)

	return humanoid ~= nil and root ~= nil and humanoid.Health > 0
end

local function destroyProjectile(projectile)
	projectilesByInstance[projectile] = nil

	if projectile.Parent ~= nil then
		projectile:Destroy()
	end
end

local function createProjectile(player, spawnPosition, targetMonster, targetRoot, direction)
	local projectile = fireballTemplate:Clone()

	projectile.Name = CombatConfig.FireballTemplateName
	projectile.Parent = projectileFolder

	local projectileRoot = prepareProjectile(projectile)

	if projectileRoot == nil then
		warn("Fireball ne contient aucune BasePart, impossible de tirer.")
		projectile:Destroy()
		return
	end

	pivotInstance(projectile, CFrame.lookAt(spawnPosition, targetRoot.Position))

	projectilesByInstance[projectile] = {
		Instance = projectile,
		Owner = player,
		TargetMonster = targetMonster,
		Position = spawnPosition,
		Direction = direction.Unit,
		Age = 0,
		Speed = PerkService.GetProjectileSpeed(player, CombatConfig.FireballSpeed),
		Lifetime = PerkService.GetAttackDuration(player, CombatConfig.FireballLifetime),
		BounceRemaining = PerkService.GetBounceCount(player),
		HitMonsters = {},
	}
end

local function rotateDirection(direction, radians)
	local rotation = CFrame.fromAxisAngle(Vector3.new(0, 1, 0), radians)

	return rotation:VectorToWorldSpace(direction).Unit
end

local function fireAtClosestMonster(player)
	if fireballTemplate == nil or not isPlayerAlive(player) then
		return
	end

	local root = getCharacterRoot(player)
	local spawnPosition = root.Position
		+ (root.CFrame.LookVector * CombatConfig.FireballSpawnForwardOffset)
		+ Vector3.new(0, CombatConfig.FireballSpawnHeightOffset, 0)
	local targetMonster, targetRoot = MonsterService.GetClosestMonster(spawnPosition, CombatConfig.FireballRange)

	if targetMonster == nil or targetRoot == nil then
		return
	end

	local direction = targetRoot.Position - spawnPosition

	if direction.Magnitude <= 0.1 then
		return
	end

	local projectileCount = PerkService.GetProjectileCount(player)
	local spreadStep = math.rad(8)

	for projectileIndex = 1, projectileCount do
		local offsetFromCenter = projectileIndex - ((projectileCount + 1) / 2)
		local projectileDirection = rotateDirection(direction.Unit, offsetFromCenter * spreadStep)

		createProjectile(player, spawnPosition, targetMonster, targetRoot, projectileDirection)
	end
end

local function updatePlayerWeapons(now)
	for _, player in ipairs(Players:GetPlayers()) do
		local lastFireAt = cooldownsByUserId[player.UserId] or 0
		local cooldown = PerkService.GetAttackCooldown(player, CombatConfig.FireballCooldown)

		if now - lastFireAt >= cooldown then
			cooldownsByUserId[player.UserId] = now
			fireAtClosestMonster(player)
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
		destroyProjectile(projectile)
		return
	end

	local targetPosition = MonsterService.GetMonsterPosition(projectileState.TargetMonster)

	if targetPosition ~= nil then
		local desiredDirection = targetPosition - projectileState.Position

		if desiredDirection.Magnitude > 0.1 then
			local homingAlpha = math.clamp(deltaTime * CombatConfig.FireballHomingStrength, 0, 1)
			projectileState.Direction = projectileState.Direction:Lerp(desiredDirection.Unit, homingAlpha).Unit
		end
	end

	local nextPosition = projectileState.Position + (projectileState.Direction * projectileState.Speed * deltaTime)
	projectileState.Position = nextPosition

	pivotInstance(projectile, CFrame.lookAt(nextPosition, nextPosition + projectileState.Direction))

	local hitMonster = MonsterService.GetClosestMonster(nextPosition, CombatConfig.FireballHitRadius, projectileState.HitMonsters)

	if hitMonster ~= nil then
		projectileState.HitMonsters[hitMonster] = true

		local damage = PerkService.CalculateOutgoingDamage(projectileState.Owner, CombatConfig.FireballDamage, hitMonster)
		local didDamage, damageDealt = MonsterService.DamageMonster(hitMonster, damage, projectileState.Owner)

		if didDamage then
			PerkService.ApplyLifeSteal(projectileState.Owner, damageDealt or 0)
		end

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

function WeaponService.RemovePlayer(player)
	cooldownsByUserId[player.UserId] = nil
end

function WeaponService.Start()
	setupFolders()
	fireballTemplate = findTemplate(CombatConfig.FireballTemplateName)

	if heartbeatConnection ~= nil then
		return
	end

	heartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime)
		if CombatStateService.IsPaused() then
			return
		end

		local now = CombatStateService.GetTime()

		updatePlayerWeapons(now)
		updateProjectiles(deltaTime)
	end)
end

return WeaponService
