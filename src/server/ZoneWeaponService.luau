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

local ZoneWeaponService = {}

local WEAPON_ID = "leyden_needle"
local definition = WeaponConfig.GetDefinition(WEAPON_ID)
local cooldownsByUserId = {}
local pendingCastsByUserId = {}
local heartbeatConnection = nil
local castSerial = 0

local vfxRemote = ReplicatedStorage:FindFirstChild("Weapon_ZoneVfx")
if vfxRemote == nil then
	vfxRemote = Instance.new("RemoteEvent")
	vfxRemote.Name = "Weapon_ZoneVfx"
	vfxRemote.Parent = ReplicatedStorage
end
assert(vfxRemote:IsA("RemoteEvent"), "Weapon_ZoneVfx doit etre un RemoteEvent")

local function getCharacterRoot(player: Player)
	local character = player.Character
	return if character then character:FindFirstChild("HumanoidRootPart") else nil
end

local function isPlayerAvailable(player: Player)
	if not RunStateService.IsRunActive(player) then
		return false
	end
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	return humanoid ~= nil and humanoid.Health > 0 and getCharacterRoot(player) ~= nil
end

local function projectToGround(player: Player, position: Vector3)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local excluded = {}
	if player.Character then table.insert(excluded, player.Character) end
	local combatRuntime = Workspace:FindFirstChild("CombatRuntime")
	if combatRuntime then table.insert(excluded, combatRuntime) end
	params.FilterDescendantsInstances = excluded
	params.IgnoreWater = false

	local result = Workspace:Raycast(position + Vector3.new(0, 48, 0), Vector3.new(0, -120, 0), params)
	return if result then result.Position + Vector3.new(0, 0.08, 0) else position
end

local function sortByDistanceFrom(position: Vector3, candidates)
	table.sort(candidates, function(left, right)
		local leftPosition = MonsterService.GetMonsterPosition(left.Monster) or position
		local rightPosition = MonsterService.GetMonsterPosition(right.Monster) or position
		return (leftPosition - position).Magnitude < (rightPosition - position).Magnitude
	end)
end

local function findNextBounce(origin: Vector3, ignored, bounceRange: number)
	local candidates = MonsterService.GetMonstersNear(origin, bounceRange, ignored)
	if #candidates == 0 then return nil end
	sortByDistanceFrom(origin, candidates)
	return candidates[1].Monster
end

local function resolveImpact(cast)
	local runtimeStats = WeaponLoadoutService.GetRuntimeStats(cast.Player, WEAPON_ID)
	if runtimeStats == nil then return end
	local impacted = {}
	local ignored = {}
	local candidates = MonsterService.GetMonstersNear(cast.Center, runtimeStats.ZoneRadius)
	sortByDistanceFrom(cast.Center, candidates)

	for _, candidate in ipairs(candidates) do
		local monster = candidate.Monster
		ignored[monster] = true
		table.insert(impacted, monster)
		WeaponHitService.Apply(cast.Player, monster, WEAPON_ID, runtimeStats.Damage, Color3.fromRGB(110, 225, 255))
	end

	local arcs = {}
	local bounceRemaining = math.min(
		PerkService.GetBounceCount(cast.Player) + (runtimeStats.BounceCount or 0),
		definition.Caps.BounceCount
	)
	local currentMonster = impacted[1]
	local currentPosition = if currentMonster then MonsterService.GetMonsterPosition(currentMonster) else cast.Center

	while bounceRemaining > 0 and currentPosition ~= nil do
		local nextMonster = findNextBounce(currentPosition, ignored, runtimeStats.BounceRange)
		if nextMonster == nil then break end
		local nextPosition = MonsterService.GetMonsterPosition(nextMonster)
		if nextPosition == nil then break end

		ignored[nextMonster] = true
		table.insert(arcs, { From = currentPosition, To = nextPosition })
		WeaponHitService.Apply(cast.Player, nextMonster, WEAPON_ID, runtimeStats.Damage, Color3.fromRGB(150, 240, 255))
		currentPosition = nextPosition
		bounceRemaining -= 1
	end

	vfxRemote:FireClient(cast.Player, {
		Type = "Impact",
		WeaponId = WEAPON_ID,
		CastId = cast.CastId,
		Center = cast.Center,
		Radius = runtimeStats.ZoneRadius,
		StrikeCount = definition.Base.StrikeCount,
		Arcs = arcs,
		Seed = cast.Seed,
	})

	DebugLog.ThrottledInfo("Weapon", "leyden_impact_" .. cast.Player.UserId, 0.5, "Aiguille de Leyde impacte", {
		Player = cast.Player.Name,
		Targets = #impacted,
		Bounces = #arcs,
		Center = cast.Center,
	})
end

local function beginCast(player: Player, now: number)
	local runtimeStats = WeaponLoadoutService.GetRuntimeStats(player, WEAPON_ID)
	if runtimeStats == nil then return false end
	local root = getCharacterRoot(player)
	if root == nil then return false end
	local target = MonsterService.GetClosestMonster(root.Position, runtimeStats.Range)
	if target == nil then return false end
	local targetPosition = MonsterService.GetMonsterPosition(target)
	if targetPosition == nil then return false end

	castSerial += 1
	local center = projectToGround(player, targetPosition)
	local seed = (player.UserId * 4099) + castSerial
	pendingCastsByUserId[player.UserId] = {
		Player = player,
		CastId = castSerial,
		Center = center,
		ImpactAt = now + runtimeStats.ChargeDuration,
		Seed = seed,
	}
	vfxRemote:FireClient(player, {
		Type = "Charge",
		WeaponId = WEAPON_ID,
		CastId = castSerial,
		Center = center,
		Radius = runtimeStats.ZoneRadius,
		ChargeDuration = runtimeStats.ChargeDuration,
		StrikeCount = runtimeStats.StrikeCount,
		Seed = seed,
		ServerStartTime = Workspace:GetServerTimeNow(),
	})
	return true
end

local function update()
	if CombatStateService.IsPaused() then return end
	local now = CombatStateService.GetTime()

	for userId, cast in pairs(pendingCastsByUserId) do
		if not isPlayerAvailable(cast.Player) or not WeaponLoadoutService.HasWeapon(cast.Player, WEAPON_ID) then
			pendingCastsByUserId[userId] = nil
			vfxRemote:FireClient(cast.Player, { Type = "Cancel", WeaponId = WEAPON_ID, CastId = cast.CastId })
		elseif now >= cast.ImpactAt then
			pendingCastsByUserId[userId] = nil
			resolveImpact(cast)
		end
	end

	for _, player in ipairs(Players:GetPlayers()) do
		if
			isPlayerAvailable(player)
			and WeaponLoadoutService.HasWeapon(player, WEAPON_ID)
			and pendingCastsByUserId[player.UserId] == nil
		then
			local readyAt = cooldownsByUserId[player.UserId] or now
			if now >= readyAt then
				local runtimeStats = WeaponLoadoutService.GetRuntimeStats(player, WEAPON_ID)
				local cooldown = PerkService.GetAttackCooldown(player, runtimeStats and runtimeStats.Cooldown or definition.Base.Cooldown)
				cooldown = math.max(definition.Caps.MinimumCooldown, cooldown)
				if beginCast(player, now) then
					cooldownsByUserId[player.UserId] = now + cooldown
				end
			end
		end
	end
end

function ZoneWeaponService.RemovePlayer(player: Player)
	local cast = pendingCastsByUserId[player.UserId]
	if cast and player.Parent == Players then
		vfxRemote:FireClient(player, { Type = "Cancel", WeaponId = WEAPON_ID, CastId = cast.CastId })
	end
	cooldownsByUserId[player.UserId] = nil
	pendingCastsByUserId[player.UserId] = nil
end

function ZoneWeaponService.Start()
	if heartbeatConnection then return end
	heartbeatConnection = RunService.Heartbeat:Connect(update)

	RunStateService.RunStarted:Connect(function(player)
		cooldownsByUserId[player.UserId] = CombatStateService.GetTime() + 1
		pendingCastsByUserId[player.UserId] = nil
	end)
	RunStateService.RunEnded:Connect(ZoneWeaponService.RemovePlayer)
	DebugLog.Info("Weapon", "Executeur d'armes de zone demarre", { WeaponId = WEAPON_ID })
end

return ZoneWeaponService
