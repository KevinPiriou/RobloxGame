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

local MeleeWeaponService = {}

local WEAPON_ID = "valorcrest_blade"
local definition = WeaponConfig.GetDefinition(WEAPON_ID)
assert(definition ~= nil, "Definition Lame de Valorcrest introuvable")

local cooldownsByUserId: {[number]: number} = {}
local heartbeatConnection: RBXScriptConnection? = nil
local swingSerial = 0

local vfxRemote = ReplicatedStorage:FindFirstChild("Weapon_MeleeVfx")
if vfxRemote == nil then
	vfxRemote = Instance.new("RemoteEvent")
	vfxRemote.Name = "Weapon_MeleeVfx"
	vfxRemote.Parent = ReplicatedStorage
end
assert(vfxRemote:IsA("RemoteEvent"), "Weapon_MeleeVfx doit etre un RemoteEvent")

local function getCharacterRoot(player: Player): BasePart?
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

local function isPlayerAvailable(player: Player): boolean
	if not RunStateService.IsRunActive(player) then
		return false
	end
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	return humanoid ~= nil and humanoid.Health > 0 and getCharacterRoot(player) ~= nil
end

local function horizontalUnit(vector: Vector3, fallback: Vector3): Vector3
	local horizontal = Vector3.new(vector.X, 0, vector.Z)
	if horizontal.Magnitude <= 0.001 then
		return fallback
	end
	return horizontal.Unit
end

local function findArcTargets(origin: Vector3, direction: Vector3, runtimeStats): {{Monster: Instance, Position: Vector3, DistanceSquared: number}}
	local range = math.clamp(tonumber(runtimeStats.Range) or definition.Base.Range, 1, definition.Caps.Range)
	local arcAngle = math.clamp(tonumber(runtimeStats.ArcAngleDegrees) or definition.Base.ArcAngleDegrees, 1, 180)
	local threshold = math.cos(math.rad(arcAngle * 0.5))
	local targets = {}

	for _, candidate in ipairs(MonsterService.GetMonstersNear(origin, range)) do
		local offset = candidate.Root.Position - origin
		local horizontalOffset = Vector3.new(offset.X, 0, offset.Z)
		if horizontalOffset.Magnitude > 0.05 and horizontalOffset.Unit:Dot(direction) >= threshold then
			table.insert(targets, {
				Monster = candidate.Monster,
				Position = candidate.Root.Position,
				DistanceSquared = candidate.DistanceSquared,
			})
		end
	end

	table.sort(targets, function(left, right)
		return left.DistanceSquared < right.DistanceSquared
	end)
	return targets
end

local function strike(player: Player): boolean
	local runtimeStats = WeaponLoadoutService.GetRuntimeStats(player, WEAPON_ID)
	local root = getCharacterRoot(player)
	if runtimeStats == nil or root == nil then
		return false
	end

	local target, targetRoot = MonsterService.GetClosestMonster(root.Position, runtimeStats.Range)
	if target == nil or targetRoot == nil then
		return false
	end

	local direction = horizontalUnit(targetRoot.Position - root.Position, horizontalUnit(root.CFrame.LookVector, Vector3.zAxis))
	local origin = root.Position + Vector3.new(0, 1.3, 0)
	local targets = findArcTargets(root.Position, direction, runtimeStats)
	if #targets == 0 then
		return false
	end

	local hitPositions = {}
	for _, targetData in ipairs(targets) do
		local hit = WeaponHitService.Apply(
			player,
			targetData.Monster,
			WEAPON_ID,
			runtimeStats.Damage,
			Color3.fromRGB(187, 220, 255)
		)
		if hit then
			table.insert(hitPositions, targetData.Position)
		end
	end

	if #hitPositions == 0 then
		return false
	end

	swingSerial += 1
	vfxRemote:FireClient(player, {
		Type = "Swing",
		WeaponId = WEAPON_ID,
		Id = swingSerial,
		Origin = origin,
		Direction = direction,
		Range = math.clamp(tonumber(runtimeStats.Range) or definition.Base.Range, 1, definition.Caps.Range),
		ArcAngleDegrees = math.clamp(tonumber(runtimeStats.ArcAngleDegrees) or definition.Base.ArcAngleDegrees, 1, 180),
		HitPositions = hitPositions,
		Seed = (player.UserId * 1009) + swingSerial,
		ServerStartTime = Workspace:GetServerTimeNow(),
	})

	return true
end

local function update()
	if CombatStateService.IsPaused() then
		return
	end

	local now = CombatStateService.GetTime()
	for _, player in ipairs(Players:GetPlayers()) do
		if not isPlayerAvailable(player) or not WeaponLoadoutService.HasWeapon(player, WEAPON_ID) then
			continue
		end

		local readyAt = cooldownsByUserId[player.UserId] or now
		if now >= readyAt then
			local runtimeStats = WeaponLoadoutService.GetRuntimeStats(player, WEAPON_ID)
			if runtimeStats ~= nil and strike(player) then
				local cooldown = PerkService.GetAttackCooldown(player, runtimeStats.Cooldown)
				cooldownsByUserId[player.UserId] = now + math.max(definition.Caps.MinimumCooldown, cooldown)
			end
		end
	end
end

function MeleeWeaponService.RemovePlayer(player: Player)
	cooldownsByUserId[player.UserId] = nil
end

function MeleeWeaponService.Start()
	if heartbeatConnection ~= nil then
		return
	end

	heartbeatConnection = RunService.Heartbeat:Connect(update)
	RunStateService.RunStarted:Connect(function(player)
		cooldownsByUserId[player.UserId] = CombatStateService.GetTime() + 0.75
	end)
	RunStateService.RunEnded:Connect(MeleeWeaponService.RemovePlayer)
	DebugLog.Info("Weapon", "Executeur melee demarre", { WeaponId = WEAPON_ID })
end

return MeleeWeaponService
