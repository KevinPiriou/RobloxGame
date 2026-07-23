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

local InvocationWeaponService = {}

local WEAPON_ID = "soul_lantern"
local TARGET_SCAN_INTERVAL = 0.125
local definition = WeaponConfig.GetDefinition(WEAPON_ID)
assert(definition ~= nil, "Definition Lanterne des ames introuvable")

local cooldownsByUserId: {[number]: number} = {}
local summonsByUserId: {[number]: {any}} = {}
local summonSerial = 0
local heartbeatConnection: RBXScriptConnection? = nil

local vfxRemote = ReplicatedStorage:FindFirstChild("Weapon_InvocationVfx")
if vfxRemote == nil then
	vfxRemote = Instance.new("RemoteEvent")
	vfxRemote.Name = "Weapon_InvocationVfx"
	vfxRemote.Parent = ReplicatedStorage
end
assert(vfxRemote:IsA("RemoteEvent"), "Weapon_InvocationVfx doit etre un RemoteEvent")

local function getRoot(player: Player): BasePart?
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
	return humanoid ~= nil and humanoid.Health > 0 and getRoot(player) ~= nil
end

local function removeSummon(player: Player, summon, reason: string)
	vfxRemote:FireClient(player, {
		Type = "Destroy",
		WeaponId = WEAPON_ID,
		Id = summon.Id,
		Position = summon.Position,
		Reason = reason,
	})
end

local function clearSummons(player: Player, reason: string)
	local summons = summonsByUserId[player.UserId] or {}
	for _, summon in ipairs(summons) do
		removeSummon(player, summon, reason)
	end
	summonsByUserId[player.UserId] = {}
end

local function createSummon(player: Player, now: number, runtimeStats)
	local root = getRoot(player)
	if root == nil then
		return false
	end
	local initialTarget = MonsterService.GetClosestMonster(root.Position, runtimeStats.Range)
	if initialTarget == nil then
		return false
	end
	local initialTargetPosition = MonsterService.GetMonsterPosition(initialTarget)
	if initialTargetPosition == nil then
		return false
	end

	summonSerial += 1
	local angle = math.rad((summonSerial * 137.5) % 360)
	local offset = (root.CFrame.RightVector * math.cos(angle) + root.CFrame.LookVector * math.sin(angle)) * 3
	local position = root.Position + offset + Vector3.new(0, 1.2, 0)
	local lifetime = math.min(
		definition.Caps.MinionLifetime,
		PerkService.GetEffectDuration(player, runtimeStats.MinionLifetime)
	)
	local summon = {
		Id = summonSerial,
		Position = position,
		ExpiresAt = now + lifetime,
		NextAttackAt = now + 0.2,
		NextTargetScanAt = now + TARGET_SCAN_INTERVAL,
		Target = initialTarget,
		NextVisualSyncAt = now,
	}
	table.insert(summonsByUserId[player.UserId], summon)
	vfxRemote:FireClient(player, {
		Type = "Spawn",
		WeaponId = WEAPON_ID,
		Id = summon.Id,
		Position = initialTargetPosition,
		TargetPosition = initialTargetPosition,
		Lifetime = lifetime,
		ServerStartTime = Workspace:GetServerTimeNow(),
	})
	return true
end

local function updateSummon(player: Player, summon, runtimeStats, now: number, deltaTime: number): boolean
	if now >= summon.ExpiresAt then
		removeSummon(player, summon, "Expired")
		return false
	end

	if now >= summon.NextTargetScanAt then
		summon.NextTargetScanAt = now + TARGET_SCAN_INTERVAL
		summon.Target = MonsterService.GetClosestMonster(summon.Position, runtimeStats.MinionTargetRange)
	end
	local target = summon.Target
	local targetPosition = if target then MonsterService.GetMonsterPosition(target) else nil
	if targetPosition ~= nil then
		local delta = targetPosition - summon.Position
		local distance = delta.Magnitude
		if distance > 0.1 then
			local moveDistance = math.min(distance, runtimeStats.MinionMoveSpeed * deltaTime)
			summon.Position += delta.Unit * moveDistance
		end

		if distance <= 4.5 and now >= summon.NextAttackAt then
			WeaponHitService.Apply(player, target, WEAPON_ID, runtimeStats.Damage, Color3.fromRGB(96, 255, 174))
			summon.NextAttackAt = now + math.max(
				definition.Caps.MinimumAttackCooldown,
				PerkService.GetAttackCooldown(player, runtimeStats.MinionAttackCooldown)
			)
			vfxRemote:FireClient(player, {
				Type = "Attack",
				WeaponId = WEAPON_ID,
				Id = summon.Id,
				From = summon.Position,
				To = targetPosition,
			})
		end
	end

	if now >= summon.NextVisualSyncAt then
		summon.NextVisualSyncAt = now + 0.12
		vfxRemote:FireClient(player, {
			Type = "Update",
			WeaponId = WEAPON_ID,
			Id = summon.Id,
			TargetPosition = targetPosition or summon.Position,
		})
	end
	return true
end

local function update(deltaTime: number)
	if CombatStateService.IsPaused() then
		return
	end

	local now = CombatStateService.GetTime()
	for _, player in ipairs(Players:GetPlayers()) do
		if not isPlayerAvailable(player) or not WeaponLoadoutService.HasWeapon(player, WEAPON_ID) then
			if summonsByUserId[player.UserId] ~= nil then
				clearSummons(player, "Unavailable")
			end
			continue
		end

		local runtimeStats = WeaponLoadoutService.GetRuntimeStats(player, WEAPON_ID)
		if runtimeStats == nil then
			continue
		end

		local active = summonsByUserId[player.UserId] or {}
		summonsByUserId[player.UserId] = active
		for index = #active, 1, -1 do
			if not updateSummon(player, active[index], runtimeStats, now, deltaTime) then
				table.remove(active, index)
			end
		end

		local maximum = math.clamp(math.floor(runtimeStats.MinionCount), 1, definition.Caps.MinionCount)
		local readyAt = cooldownsByUserId[player.UserId] or now
		if #active < maximum and now >= readyAt then
			local cooldown = math.max(
				definition.Caps.MinimumCooldown,
				PerkService.GetAttackCooldown(player, runtimeStats.Cooldown)
			)
			if createSummon(player, now, runtimeStats) then
				cooldownsByUserId[player.UserId] = now + cooldown
			end
		end
	end
end

function InvocationWeaponService.RemovePlayer(player: Player)
	cooldownsByUserId[player.UserId] = nil
	clearSummons(player, "Removed")
	summonsByUserId[player.UserId] = nil
end

function InvocationWeaponService.Start()
	if heartbeatConnection ~= nil then
		return
	end

	heartbeatConnection = RunService.Heartbeat:Connect(update)
	RunStateService.RunStarted:Connect(function(player)
		cooldownsByUserId[player.UserId] = CombatStateService.GetTime() + 0.8
		summonsByUserId[player.UserId] = {}
	end)
	RunStateService.RunEnded:Connect(InvocationWeaponService.RemovePlayer)
	DebugLog.Info("Weapon", "Executeur d'invocation demarre", { WeaponId = WEAPON_ID })
end

return InvocationWeaponService
