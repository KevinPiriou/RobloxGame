local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DebugLog = require(Shared:WaitForChild("DebugLog"))

local RunStateService = {}

local runStartedEvent = Instance.new("BindableEvent")
local runEndedEvent = Instance.new("BindableEvent")

RunStateService.RunStarted = runStartedEvent.Event
RunStateService.RunEnded = runEndedEvent.Event

local statesByUserId = {}
local characterConnectionsByUserId = {}
local deathConnectionsByUserId = {}

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

local stateRemote = getOrCreateRemote("Run_StateUpdate")

local function getState(player)
	local state = statesByUserId[player.UserId]

	if state == nil then
		state = {
			IsActive = false,
			StartedAt = nil,
			LastReason = "Initial",
		}
		statesByUserId[player.UserId] = state
	end

	return state
end

local function sendState(player)
	if player.Parent ~= Players then
		return
	end

	local state = getState(player)
	player:SetAttribute("IsRunActive", state.IsActive == true)

	stateRemote:FireClient(player, {
		IsRunActive = state.IsActive == true,
		StartedAt = state.StartedAt,
		Reason = state.LastReason,
	})
end

local function bindCharacter(player, character)
	local previousDeathConnection = deathConnectionsByUserId[player.UserId]

	if previousDeathConnection ~= nil then
		previousDeathConnection:Disconnect()
		deathConnectionsByUserId[player.UserId] = nil
	end

	local humanoid = character:WaitForChild("Humanoid", 8)

	if humanoid == nil then
		return
	end

	deathConnectionsByUserId[player.UserId] = humanoid.Died:Connect(function()
		if RunStateService.IsRunActive(player) then
			RunStateService.EndRun(player, "Death")
		else
			sendState(player)
		end
	end)
end

function RunStateService.SetRunActive(player, isActive, reason)
	if player == nil or player.Parent ~= Players then
		return false
	end

	local state = getState(player)
	local nextActive = isActive == true

	if state.IsActive == nextActive then
		state.LastReason = reason or state.LastReason
		sendState(player)
		return false
	end

	state.IsActive = nextActive

	if reason ~= nil then
		state.LastReason = reason
	elseif nextActive then
		state.LastReason = "RunStarted"
	else
		state.LastReason = "RunEnded"
	end

	state.StartedAt = if nextActive then os.clock() else nil

	sendState(player)

	if nextActive then
		runStartedEvent:Fire(player, state.LastReason)
		DebugLog.Info("RunState", "Run joueur activee", {
			Player = player.Name,
			Reason = state.LastReason,
		})
	else
		runEndedEvent:Fire(player, state.LastReason)
		DebugLog.Info("RunState", "Run joueur terminee", {
			Player = player.Name,
			Reason = state.LastReason,
		})
	end

	return true
end

function RunStateService.StartRun(player, reason)
	return RunStateService.SetRunActive(player, true, reason or "RunStarted")
end

function RunStateService.EndRun(player, reason)
	return RunStateService.SetRunActive(player, false, reason or "RunEnded")
end

function RunStateService.IsRunActive(player)
	if player == nil then
		return false
	end

	local state = statesByUserId[player.UserId]

	return state ~= nil and state.IsActive == true
end

function RunStateService.SetupPlayer(player)
	getState(player)

	if characterConnectionsByUserId[player.UserId] ~= nil then
		characterConnectionsByUserId[player.UserId]:Disconnect()
	end

	characterConnectionsByUserId[player.UserId] = player.CharacterAdded:Connect(function(character)
		bindCharacter(player, character)
	end)

	if player.Character ~= nil then
		task.spawn(function()
			bindCharacter(player, player.Character)
		end)
	end

	sendState(player)
end

function RunStateService.RemovePlayer(player)
	statesByUserId[player.UserId] = nil

	if characterConnectionsByUserId[player.UserId] ~= nil then
		characterConnectionsByUserId[player.UserId]:Disconnect()
		characterConnectionsByUserId[player.UserId] = nil
	end

	if deathConnectionsByUserId[player.UserId] ~= nil then
		deathConnectionsByUserId[player.UserId]:Disconnect()
		deathConnectionsByUserId[player.UserId] = nil
	end
end

return RunStateService
