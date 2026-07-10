local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DebugLog = require(Shared:WaitForChild("DebugLog"))

local CombatStateService = {}

local pauseReasons = {}
local pauseStartedAt = nil
local totalPausedDuration = 0
local lockedHumanoids = {}
local playerCharacterConnections = {}
local isApplyingMovementLock = false
local userPausePrefix = "UserPause_"

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

local togglePauseRemote = getOrCreateRemote("Combat_TogglePause")
local pauseStateRemote = getOrCreateRemote("Combat_PauseState")

local function getReasonCount()
	local count = 0

	for _ in pairs(pauseReasons) do
		count += 1
	end

	return count
end

local function getUserPauseReason(player)
	return userPausePrefix .. tostring(player.UserId)
end

local function getHumanoid(player)
	local character = player.Character

	if character == nil then
		return nil
	end

	return character:FindFirstChildOfClass("Humanoid")
end

local function getRootPartFromHumanoid(humanoid)
	local character = humanoid.Parent

	if character == nil then
		return nil
	end

	return character:FindFirstChild("HumanoidRootPart")
end

local function stopRootVelocity(humanoid)
	local root = getRootPartFromHumanoid(humanoid)

	if root == nil or not root:IsA("BasePart") then
		return
	end

	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
end

local function forceHumanoidLocked(humanoid)
	isApplyingMovementLock = true
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	humanoid.Jump = false
	humanoid.AutoRotate = false
	isApplyingMovementLock = false
	stopRootVelocity(humanoid)
end

local function disconnectLockConnections(lockState)
	for _, connection in ipairs(lockState.Connections) do
		connection:Disconnect()
	end

	table.clear(lockState.Connections)
end

local function watchLockedHumanoidProperty(humanoid, lockState, propertyName, lockedValue)
	local connection = humanoid:GetPropertyChangedSignal(propertyName):Connect(function()
		if isApplyingMovementLock or lockedHumanoids[humanoid] ~= lockState then
			return
		end

		local currentValue = humanoid[propertyName]

		if currentValue ~= lockedValue then
			lockState[propertyName] = currentValue
			forceHumanoidLocked(humanoid)
		end
	end)

	table.insert(lockState.Connections, connection)
end

local function lockHumanoidMovement(humanoid)
	local lockState = lockedHumanoids[humanoid]

	if lockState == nil then
		lockState = {
			WalkSpeed = humanoid.WalkSpeed,
			JumpPower = humanoid.JumpPower,
			JumpHeight = humanoid.JumpHeight,
			AutoRotate = humanoid.AutoRotate,
			Connections = {},
		}
		lockedHumanoids[humanoid] = lockState

		watchLockedHumanoidProperty(humanoid, lockState, "WalkSpeed", 0)
		watchLockedHumanoidProperty(humanoid, lockState, "JumpPower", 0)
		watchLockedHumanoidProperty(humanoid, lockState, "JumpHeight", 0)
		watchLockedHumanoidProperty(humanoid, lockState, "AutoRotate", false)

		table.insert(lockState.Connections, humanoid.AncestryChanged:Connect(function(_, parent)
			if parent == nil and lockedHumanoids[humanoid] == lockState then
				disconnectLockConnections(lockState)
				lockedHumanoids[humanoid] = nil
			end
		end))
	end

	forceHumanoidLocked(humanoid)
end

local function unlockHumanoidMovement(humanoid, lockState)
	if humanoid.Parent == nil then
		disconnectLockConnections(lockState)
		lockedHumanoids[humanoid] = nil
		return
	end

	disconnectLockConnections(lockState)
	lockedHumanoids[humanoid] = nil

	isApplyingMovementLock = true
	humanoid.WalkSpeed = lockState.WalkSpeed
	humanoid.JumpPower = lockState.JumpPower
	humanoid.JumpHeight = lockState.JumpHeight
	humanoid.AutoRotate = lockState.AutoRotate
	isApplyingMovementLock = false
end

local function lockAllPlayerMovement()
	for _, player in ipairs(Players:GetPlayers()) do
		local humanoid = getHumanoid(player)

		if humanoid ~= nil then
			lockHumanoidMovement(humanoid)
		end
	end
end

local function unlockAllPlayerMovement()
	local locksToRelease = {}

	for humanoid, lockState in pairs(lockedHumanoids) do
		table.insert(locksToRelease, {
			Humanoid = humanoid,
			LockState = lockState,
		})
	end

	for _, entry in ipairs(locksToRelease) do
		if lockedHumanoids[entry.Humanoid] == entry.LockState then
			unlockHumanoidMovement(entry.Humanoid, entry.LockState)
		end
	end
end

local function updateMovementLock()
	if getReasonCount() > 0 then
		lockAllPlayerMovement()
	else
		unlockAllPlayerMovement()
	end
end

local function hasBlockingPauseForPlayer(player)
	local userPauseReason = getUserPauseReason(player)

	for reason in pairs(pauseReasons) do
		if reason ~= userPauseReason then
			return true
		end
	end

	return false
end

local function sendPauseState(player)
	if player.Parent ~= Players then
		return
	end

	pauseStateRemote:FireClient(player, {
		IsPaused = CombatStateService.IsPaused(),
		IsUserPaused = pauseReasons[getUserPauseReason(player)] == true,
		HasBlockingPause = hasBlockingPauseForPlayer(player),
		ReasonCount = getReasonCount(),
	})
end

local function sendPauseStateToAll()
	for _, player in ipairs(Players:GetPlayers()) do
		sendPauseState(player)
	end
end

function CombatStateService.Pause(reason)
	if pauseReasons[reason] then
		return
	end

	pauseReasons[reason] = true

	if getReasonCount() == 1 then
		pauseStartedAt = os.clock()
	end

	DebugLog.Info("Combat", "Combat pause", {
		Reason = reason,
		ReasonCount = getReasonCount(),
	})

	updateMovementLock()
	sendPauseStateToAll()
end

function CombatStateService.Resume(reason)
	if not pauseReasons[reason] then
		return
	end

	pauseReasons[reason] = nil

	if getReasonCount() == 0 and pauseStartedAt ~= nil then
		totalPausedDuration += os.clock() - pauseStartedAt
		pauseStartedAt = nil
	end

	DebugLog.Info("Combat", "Combat reprise", {
		Reason = reason,
		ReasonCount = getReasonCount(),
		TotalPausedDuration = totalPausedDuration,
	})

	updateMovementLock()
	sendPauseStateToAll()
end

function CombatStateService.IsPaused()
	return getReasonCount() > 0
end

function CombatStateService.IsPlayerPaused(player)
	return pauseReasons[getUserPauseReason(player)] == true
end

function CombatStateService.TogglePlayerPause(player)
	local userPauseReason = getUserPauseReason(player)

	if pauseReasons[userPauseReason] then
		CombatStateService.Resume(userPauseReason)
		return
	end

	if getReasonCount() > 0 then
		DebugLog.Info("Combat", "Pause joueur ignoree, autre pause active", {
			Player = player.Name,
			ReasonCount = getReasonCount(),
		})
		sendPauseState(player)
		return
	end

	CombatStateService.Pause(userPauseReason)
end

function CombatStateService.GetTime()
	local pausedNow = 0

	if pauseStartedAt ~= nil then
		pausedNow = os.clock() - pauseStartedAt
	end

	return os.clock() - totalPausedDuration - pausedNow
end

local function bindPlayer(player)
	if playerCharacterConnections[player.UserId] ~= nil then
		playerCharacterConnections[player.UserId]:Disconnect()
	end

	playerCharacterConnections[player.UserId] = player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid", 5)

		if humanoid ~= nil and CombatStateService.IsPaused() then
			lockHumanoidMovement(humanoid)
		end

		sendPauseState(player)
	end)

	if player.Character ~= nil and CombatStateService.IsPaused() then
		local humanoid = getHumanoid(player)

		if humanoid ~= nil then
			lockHumanoidMovement(humanoid)
		end
	end

	task.defer(function()
		sendPauseState(player)
	end)
end

Players.PlayerAdded:Connect(bindPlayer)

Players.PlayerRemoving:Connect(function(player)
	if playerCharacterConnections[player.UserId] ~= nil then
		playerCharacterConnections[player.UserId]:Disconnect()
		playerCharacterConnections[player.UserId] = nil
	end

	CombatStateService.Resume(getUserPauseReason(player))
end)

for _, player in ipairs(Players:GetPlayers()) do
	bindPlayer(player)
end

togglePauseRemote.OnServerEvent:Connect(function(player)
	CombatStateService.TogglePlayerPause(player)
end)

return CombatStateService
