local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DebugLog = require(Shared:WaitForChild("DebugLog"))
local RunLoadingConfig = require(Shared:WaitForChild("RunLoadingConfig"))

local RunLoadingService = {}

local statesByUserId = {}
local characterConnectionsByUserId = {}
local isStarted = false

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

local loadingRemote = getOrCreateRemote(RunLoadingConfig.RemoteName)

local function getOrCreateState(player)
	local state = statesByUserId[player.UserId]

	if state == nil then
		state = {
			IsLoading = false,
			LockedCharacter = nil,
			SavedMovement = nil,
		}
		statesByUserId[player.UserId] = state
	end

	return state
end

local function getHumanoidAndRoot(character)
	if character == nil then
		return nil, nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")

	return humanoid, root
end

local function lockCharacter(player, character)
	local state = getOrCreateState(player)

	if not state.IsLoading or character == nil or state.LockedCharacter == character then
		return
	end

	local humanoid, root = getHumanoidAndRoot(character)

	if humanoid == nil or root == nil then
		return
	end

	state.LockedCharacter = character
	state.SavedMovement = {
		Humanoid = humanoid,
		Root = root,
		WalkSpeed = humanoid.WalkSpeed,
		JumpPower = humanoid.JumpPower,
		JumpHeight = humanoid.JumpHeight,
		AutoRotate = humanoid.AutoRotate,
		RootAnchored = root.Anchored,
	}

	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	humanoid.AutoRotate = false
	root.Anchored = true
end

local function unlockCharacter(player)
	local state = getOrCreateState(player)
	local savedMovement = state.SavedMovement

	state.LockedCharacter = nil
	state.SavedMovement = nil

	if savedMovement == nil then
		return
	end

	local humanoid = savedMovement.Humanoid
	local root = savedMovement.Root

	if humanoid ~= nil and humanoid.Parent ~= nil then
		humanoid.WalkSpeed = savedMovement.WalkSpeed
		humanoid.JumpPower = savedMovement.JumpPower
		humanoid.JumpHeight = savedMovement.JumpHeight
		humanoid.AutoRotate = savedMovement.AutoRotate
	end

	if root ~= nil and root.Parent ~= nil then
		root.Anchored = savedMovement.RootAnchored
	end
end

local function sendState(player, payload)
	if player.Parent ~= Players then
		return
	end

	loadingRemote:FireClient(player, payload)
end

function RunLoadingService.Begin(player)
	if player == nil or player.Parent ~= Players then
		return false
	end

	local state = getOrCreateState(player)
	state.IsLoading = true
	player:SetAttribute(RunLoadingConfig.AttributeName, true)
	lockCharacter(player, player.Character)
	RunLoadingService.Update(player, "Preparing")

	return true
end

function RunLoadingService.Update(player, stageId, detail)
	if player == nil or player.Parent ~= Players then
		return
	end

	local stage = RunLoadingConfig.Stages[stageId] or RunLoadingConfig.Stages.Preparing

	sendState(player, {
		Visible = true,
		Stage = stageId,
		Progress = stage.Progress,
		Message = stage.Message,
		Detail = detail,
	})
end

function RunLoadingService.Complete(player)
	if player == nil or player.Parent ~= Players then
		return
	end

	local state = getOrCreateState(player)

	if not state.IsLoading then
		return
	end

	RunLoadingService.Update(player, "Ready")
	state.IsLoading = false
	player:SetAttribute(RunLoadingConfig.AttributeName, false)

	task.delay(RunLoadingConfig.ReleaseDelay, function()
		if player.Parent ~= Players or getOrCreateState(player).IsLoading then
			return
		end

		sendState(player, {
			Visible = false,
		})
		unlockCharacter(player)
	end)
end

function RunLoadingService.Cancel(player, reason)
	if player == nil then
		return
	end

	local state = getOrCreateState(player)
	state.IsLoading = false
	player:SetAttribute(RunLoadingConfig.AttributeName, false)
	sendState(player, {
		Visible = false,
		Reason = reason,
	})
	unlockCharacter(player)
end

function RunLoadingService.SetupPlayer(player)
	local state = getOrCreateState(player)
	state.IsLoading = false
	player:SetAttribute(RunLoadingConfig.AttributeName, false)

	if characterConnectionsByUserId[player.UserId] ~= nil then
		characterConnectionsByUserId[player.UserId]:Disconnect()
	end

	characterConnectionsByUserId[player.UserId] = player.CharacterAdded:Connect(function(character)
		task.defer(function()
			lockCharacter(player, character)
		end)
	end)
end

function RunLoadingService.RemovePlayer(player)
	if player == nil then
		return
	end

	unlockCharacter(player)
	statesByUserId[player.UserId] = nil

	if characterConnectionsByUserId[player.UserId] ~= nil then
		characterConnectionsByUserId[player.UserId]:Disconnect()
		characterConnectionsByUserId[player.UserId] = nil
	end
end

function RunLoadingService.Start()
	if isStarted then
		return
	end

	isStarted = true
	DebugLog.Info("RunLoading", "Service de chargement run demarre", {
		Remote = loadingRemote,
	})
end

return RunLoadingService
