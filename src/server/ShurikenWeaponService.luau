--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DebugLog = require(Shared:WaitForChild("DebugLog"))
local WeaponConfig = require(Shared:WaitForChild("WeaponConfig"))

local CombatStateService = require(script.Parent:WaitForChild("CombatStateService"))
local MonsterService = require(script.Parent:WaitForChild("MonsterService"))
local PerkService = require(script.Parent:WaitForChild("PerkService"))
local RunStateService = require(script.Parent:WaitForChild("RunStateService"))
local WeaponHitService = require(script.Parent:WaitForChild("WeaponHitService"))
local WeaponLoadoutService = require(script.Parent:WaitForChild("WeaponLoadoutService"))
local WeaponSkinService = require(script.Parent:WaitForChild("WeaponSkinService"))

local ShurikenWeaponService = {}

local WEAPON_ID = "shuriken"
local definition = WeaponConfig.GetDefinition(WEAPON_ID)
assert(definition ~= nil, "Definition Shuriken introuvable")

local cooldownsByUserId: {[number]: number} = {}
local projectilesById: {[number]: any} = {}
local projectileSerial = 0
local heartbeatConnection: RBXScriptConnection? = nil

local vfxRemote = ReplicatedStorage:FindFirstChild("Weapon_ShurikenVfx")
if vfxRemote == nil then
	vfxRemote = Instance.new("RemoteEvent")
	vfxRemote.Name = "Weapon_ShurikenVfx"
	vfxRemote.Parent = ReplicatedStorage
end
assert(vfxRemote:IsA("RemoteEvent"), "Weapon_ShurikenVfx doit etre un RemoteEvent")

local function getCharacterRoot(player: Player): BasePart?
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

local function isPlayerAvailable(player: Player): boolean
	if not RunStateService.IsRunActive(player) then return false end
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	return humanoid ~= nil and humanoid.Health > 0 and getCharacterRoot(player) ~= nil
end

local function getVolleyCount(player: Player, runtimeStats): number
	local bonusProjectiles = math.max(0, PerkService.GetProjectileCount(player) - 1)
	local baseCount = math.max(1, math.floor(tonumber(runtimeStats.ProjectileCount) or definition.Base.ProjectileCount))
	return math.clamp(baseCount + bonusProjectiles, 1, definition.Caps.ProjectileCount)
end

local function getSpawnPosition(root: BasePart): Vector3
	return root.Position + (root.CFrame.LookVector * 2.1) + Vector3.new(0, 1.25, 0)
end

local function getConeDirection(baseDirection: Vector3, index: number, count: number, coneAngleDegrees: number): Vector3
	if count <= 1 then return baseDirection.Unit end
	local progress = (index - 1) / (count - 1)
	local angle = math.rad((-coneAngleDegrees * 0.5) + (coneAngleDegrees * progress))
	return CFrame.fromAxisAngle(Vector3.yAxis, angle):VectorToWorldSpace(baseDirection).Unit
end

local function emitProjectile(player: Player, root: BasePart, baseDirection: Vector3, index: number, count: number, runtimeStats)
	projectileSerial += 1
	local spawnPosition = getSpawnPosition(root)
	local direction = getConeDirection(baseDirection, index, count, runtimeStats.ConeAngleDegrees)
	local projectile = {
		Id = projectileSerial,
		Owner = player,
		Position = spawnPosition,
		Direction = direction,
		Speed = runtimeStats.ProjectileSpeed,
		Lifetime = runtimeStats.Lifetime,
		Age = 0,
		Damage = runtimeStats.Damage,
		HitRadius = runtimeStats.HitRadius,
	}
	projectilesById[projectile.Id] = projectile

	vfxRemote:FireClient(player, {
		Type = "Spawn",
		WeaponId = WEAPON_ID,
		Id = projectile.Id,
		Position = spawnPosition,
		Direction = direction,
		Speed = projectile.Speed,
		Lifetime = projectile.Lifetime,
		Seed = (player.UserId * 7919) + projectile.Id,
		SkinId = WeaponSkinService.GetSelectedWeaponSkin(player, WEAPON_ID),
		ServerStartTime = Workspace:GetServerTimeNow(),
	})
end

local function startVolley(player: Player): boolean
	local runtimeStats = WeaponLoadoutService.GetRuntimeStats(player, WEAPON_ID)
	local root = getCharacterRoot(player)
	if runtimeStats == nil or root == nil then return false end

	local target, targetRoot = MonsterService.GetClosestMonster(root.Position, runtimeStats.Range)
	if target == nil or targetRoot == nil then return false end
	local baseDirection = targetRoot.Position - getSpawnPosition(root)
	if baseDirection.Magnitude <= 0.1 then return false end

	local count = getVolleyCount(player, runtimeStats)
	for index = 1, count do
		emitProjectile(player, root, baseDirection.Unit, index, count, runtimeStats)
	end
	return true
end

local function destroyProjectile(projectile, impactPosition: Vector3?)
	projectilesById[projectile.Id] = nil
	vfxRemote:FireClient(projectile.Owner, {
		Type = if impactPosition then "Impact" else "Destroy",
		WeaponId = WEAPON_ID,
		Id = projectile.Id,
		Position = impactPosition,
	})
end

local function updateProjectiles(deltaTime: number)
	for _, projectile in pairs(projectilesById) do
		if not isPlayerAvailable(projectile.Owner) then
			destroyProjectile(projectile)
			continue
		end

		projectile.Age += deltaTime
		if projectile.Age >= projectile.Lifetime then
			destroyProjectile(projectile)
			continue
		end

		local nextPosition = projectile.Position + (projectile.Direction * projectile.Speed * deltaTime)
		local candidates = MonsterService.GetMonstersNear(nextPosition, projectile.HitRadius)
		local candidate = candidates[1]
		if candidate and MonsterService.IsMonsterAlive(candidate.Monster) then
			local impactPosition = MonsterService.GetMonsterPosition(candidate.Monster) or nextPosition
			WeaponHitService.Apply(projectile.Owner, candidate.Monster, WEAPON_ID, projectile.Damage, Color3.fromRGB(181, 105, 255))
			destroyProjectile(projectile, impactPosition)
		else
			projectile.Position = nextPosition
		end
	end
end

function ShurikenWeaponService.RemovePlayer(player: Player)
	cooldownsByUserId[player.UserId] = nil
	local ownedProjectiles = {}
	for _, projectile in pairs(projectilesById) do
		if projectile.Owner == player then
			table.insert(ownedProjectiles, projectile)
		end
	end
	for _, projectile in ipairs(ownedProjectiles) do
		destroyProjectile(projectile)
	end
end

function ShurikenWeaponService.Start()
	if heartbeatConnection then return end
	heartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime)
		if not CombatStateService.IsPaused() then
			local now = CombatStateService.GetTime()
			updateProjectiles(deltaTime)

			for _, player in ipairs(Players:GetPlayers()) do
				if not isPlayerAvailable(player) or not WeaponLoadoutService.HasWeapon(player, WEAPON_ID) then
					continue
				end

				local runtimeStats = WeaponLoadoutService.GetRuntimeStats(player, WEAPON_ID)
				if runtimeStats == nil then continue end
				local readyAt = cooldownsByUserId[player.UserId] or now
				if now >= readyAt and startVolley(player) then
					cooldownsByUserId[player.UserId] = now
						+ math.max(definition.Caps.MinimumCooldown, PerkService.GetAttackCooldown(player, runtimeStats.Cooldown))
				end
			end
		end
	end)
	RunStateService.RunStarted:Connect(function(player)
		cooldownsByUserId[player.UserId] = CombatStateService.GetTime() + 0.75
	end)
	RunStateService.RunEnded:Connect(ShurikenWeaponService.RemovePlayer)
	DebugLog.Info("Weapon", "Executeur Shuriken demarre", { WeaponId = WEAPON_ID })
end

return ShurikenWeaponService
