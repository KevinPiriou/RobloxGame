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

local ChannelWeaponService = {}

local WEAPON_ID = "soulthorn_drain"
local definition = WeaponConfig.GetDefinition(WEAPON_ID)
assert(definition ~= nil, "Definition Epine d'ame introuvable")

local cooldownsByUserId = {}
local channelsByUserId = {}
local heartbeatConnection: RBXScriptConnection? = nil
local channelSerial = 0

local vfxRemote = ReplicatedStorage:FindFirstChild("Weapon_DrainVfx")
if vfxRemote == nil then
	vfxRemote = Instance.new("RemoteEvent")
	vfxRemote.Name = "Weapon_DrainVfx"
	vfxRemote.Parent = ReplicatedStorage
end
assert(vfxRemote:IsA("RemoteEvent"), "Weapon_DrainVfx doit etre un RemoteEvent")

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

local function getTargets(player: Player, origin: Vector3, runtimeStats): {Instance}
	local range = math.clamp(tonumber(runtimeStats.Range) or definition.Base.Range, 1, definition.Caps.Range)
	local targetLimit = math.clamp(PerkService.GetProjectileCount(player), 1, definition.Caps.ChannelTargets)
	local targets = {}

	for _, candidate in ipairs(MonsterService.GetMonstersNear(origin, range)) do
		table.insert(targets, candidate)
	end
	table.sort(targets, function(left, right)
		return left.DistanceSquared < right.DistanceSquared
	end)

	local selected = {}
	for _, candidate in ipairs(targets) do
		if #selected >= targetLimit then
			break
		end
		table.insert(selected, candidate.Monster)
	end
	return selected
end

local function stopChannel(player: Player, channel, reason: string)
	if channelsByUserId[player.UserId] ~= channel then
		return
	end
	channelsByUserId[player.UserId] = nil
	vfxRemote:FireClient(player, {
		Type = "Stop",
		ChannelId = channel.Id,
		Reason = reason,
	})
end

local function beginChannel(player: Player, now: number): boolean
	local runtimeStats = WeaponLoadoutService.GetRuntimeStats(player, WEAPON_ID)
	local root = getCharacterRoot(player)
	if runtimeStats == nil or root == nil then
		return false
	end

	local targets = getTargets(player, root.Position, runtimeStats)
	if #targets == 0 then
		return false
	end

	channelSerial += 1
	local duration = math.clamp(tonumber(runtimeStats.ChannelDuration) or definition.Base.ChannelDuration, 0.1, definition.Caps.ChannelDuration)
	local tickInterval = math.max(0.05, tonumber(runtimeStats.TickInterval) or definition.Base.TickInterval)
	local channel = {
		Id = channelSerial,
		Targets = targets,
		Stats = runtimeStats,
		EndsAt = now + duration,
		NextTickAt = now,
	}
	channelsByUserId[player.UserId] = channel
	vfxRemote:FireClient(player, {
		Type = "Start",
		ChannelId = channel.Id,
		Targets = targets,
		Duration = duration,
		ServerStartTime = Workspace:GetServerTimeNow(),
	})
	return true
end

local function tickChannel(player: Player, channel, now: number)
	if now >= channel.EndsAt then
		stopChannel(player, channel, "DurationElapsed")
		return
	end
	if now < channel.NextTickAt then
		return
	end

	local root = getCharacterRoot(player)
	if root == nil then
		stopChannel(player, channel, "OwnerUnavailable")
		return
	end

	local stats = channel.Stats
	local range = math.clamp(tonumber(stats.Range) or definition.Base.Range, 1, definition.Caps.Range)
	local interval = math.max(0.05, tonumber(stats.TickInterval) or definition.Base.TickInterval)
	local damagePerTick = math.max(0, tonumber(stats.Damage) or definition.Base.Damage) * interval
	local drainPercent = math.clamp(tonumber(stats.DrainPercent) or definition.Base.DrainPercent, 0, 1)
	local aliveTargets = 0

	for _, monster in ipairs(channel.Targets) do
		local position = MonsterService.GetMonsterPosition(monster)
		if position == nil or not MonsterService.IsMonsterAlive(monster) or (position - root.Position).Magnitude > range then
			continue
		end
		aliveTargets += 1
		local didHit, dealt = WeaponHitService.Apply(
			player,
			monster,
			WEAPON_ID,
			damagePerTick,
			Color3.fromRGB(244, 56, 153)
		)
		if didHit and dealt > 0 then
			PerkService.ApplyDirectLifeDrain(player, dealt * drainPercent)
		end
	end

	channel.NextTickAt = now + interval
	if aliveTargets == 0 then
		stopChannel(player, channel, "TargetsLost")
	end
end

local function update()
	if CombatStateService.IsPaused() then
		return
	end
	local now = CombatStateService.GetTime()
	for _, player in ipairs(Players:GetPlayers()) do
		if not isPlayerAvailable(player) or not WeaponLoadoutService.HasWeapon(player, WEAPON_ID) then
			local channel = channelsByUserId[player.UserId]
			if channel ~= nil then
				stopChannel(player, channel, "WeaponUnavailable")
			end
			continue
		end

		local channel = channelsByUserId[player.UserId]
		if channel ~= nil then
			tickChannel(player, channel, now)
			continue
		end

		local readyAt = cooldownsByUserId[player.UserId] or now
		if now < readyAt or not beginChannel(player, now) then
			continue
		end

		local runtimeStats = WeaponLoadoutService.GetRuntimeStats(player, WEAPON_ID)
		local cooldown = PerkService.GetAttackCooldown(player, runtimeStats and runtimeStats.Cooldown or definition.Base.Cooldown)
		cooldownsByUserId[player.UserId] = now + math.max(definition.Caps.MinimumCooldown, cooldown)
		local newChannel = channelsByUserId[player.UserId]
		if newChannel ~= nil then
			tickChannel(player, newChannel, now)
		end
	end
end

function ChannelWeaponService.RemovePlayer(player: Player)
	local channel = channelsByUserId[player.UserId]
	if channel ~= nil then
		stopChannel(player, channel, "PlayerRemoved")
	end
	cooldownsByUserId[player.UserId] = nil
end

function ChannelWeaponService.Start()
	if heartbeatConnection ~= nil then
		return
	end
	heartbeatConnection = RunService.Heartbeat:Connect(update)
	RunStateService.RunStarted:Connect(function(player)
		cooldownsByUserId[player.UserId] = CombatStateService.GetTime() + 0.75
	end)
	RunStateService.RunEnded:Connect(ChannelWeaponService.RemovePlayer)
	DebugLog.Info("Weapon", "Executeur de canalisation demarre", { WeaponId = WEAPON_ID })
end

return ChannelWeaponService
