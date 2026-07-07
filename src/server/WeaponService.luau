local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))

local MonsterService = require(script.Parent:WaitForChild("MonsterService"))

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
	}
end

local function updatePlayerWeapons(now)
	for _, player in ipairs(Players:GetPlayers()) do
		local lastFireAt = cooldownsByUserId[player.UserId] or 0

		if now - lastFireAt >= CombatConfig.FireballCooldown then
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

	if projectileState.Age >= CombatConfig.FireballLifetime then
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

	local nextPosition = projectileState.Position + (projectileState.Direction * CombatConfig.FireballSpeed * deltaTime)
	projectileState.Position = nextPosition

	pivotInstance(projectile, CFrame.lookAt(nextPosition, nextPosition + projectileState.Direction))

	local hitMonster = MonsterService.GetClosestMonster(nextPosition, CombatConfig.FireballHitRadius)

	if hitMonster ~= nil then
		MonsterService.DamageMonster(hitMonster, CombatConfig.FireballDamage, projectileState.Owner)
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
		local now = os.clock()

		updatePlayerWeapons(now)
		updateProjectiles(deltaTime)
	end)
end

return WeaponService
