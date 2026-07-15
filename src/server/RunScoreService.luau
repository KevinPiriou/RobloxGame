--!strict

-- Score de pas autoritaire : seule la position repliquee au serveur est lue.
-- Les teleports et les phases de pause reinitialisent simplement l'echantillon.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RunScoreConfig = require(Shared:WaitForChild("RunScoreConfig"))

local CombatStateService = require(script.Parent:WaitForChild("CombatStateService"))
local GameplayFeedbackService = require(script.Parent:WaitForChild("GameplayFeedbackService"))
local RunStateService = require(script.Parent:WaitForChild("RunStateService"))

local RunScoreService = {}

type ScoreState = {
	IsActive: boolean,
	LastPosition: Vector3?,
	PendingScore: number,
	Remainder: number,
	Score: number,
}

local statesByUserId: { [number]: ScoreState } = {}
local accumulator = 0
local publishAccumulator = 0
local isStarted = false

local function getOrCreateRemote(remoteName: string): RemoteEvent
	local remote = ReplicatedStorage:FindFirstChild(remoteName)

	if remote == nil then
		remote = Instance.new("RemoteEvent")
		remote.Name = remoteName
		remote.Parent = ReplicatedStorage
	end

	assert(remote:IsA("RemoteEvent"), remoteName .. " doit etre un RemoteEvent.")
	return remote
end

local updateRemote = getOrCreateRemote(RunScoreConfig.UpdateRemoteName)

local function getOrCreateState(player: Player): ScoreState
	local state = statesByUserId[player.UserId]

	if state == nil then
		state = {
			IsActive = false,
			LastPosition = nil,
			PendingScore = 0,
			Remainder = 0,
			Score = 0,
		}
		statesByUserId[player.UserId] = state
	end

	return state
end

local function getRootPosition(player: Player): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")

	if root ~= nil and root:IsA("BasePart") then
		return root.Position
	end

	return nil
end

local function sendState(player: Player, delta: number?)
	if player.Parent ~= Players then
		return
	end

	local state = getOrCreateState(player)
	updateRemote:FireClient(player, {
		Score = state.Score,
		Delta = math.max(0, math.floor(delta or 0)),
	})
end

local function resetSampling(state: ScoreState, position: Vector3?)
	state.LastPosition = position
	state.Remainder = 0
end

local function updatePlayerScore(player: Player)
	local state = getOrCreateState(player)

	if not state.IsActive or not RunStateService.IsRunActive(player) then
		return
	end

	local position = getRootPosition(player)

	if position == nil then
		return
	end

	if CombatStateService.IsPaused() then
		resetSampling(state, position)
		return
	end

	local previousPosition = state.LastPosition
	state.LastPosition = position

	if previousPosition == nil then
		return
	end

	local horizontalDistance = Vector2.new(position.X - previousPosition.X, position.Z - previousPosition.Z).Magnitude
	local maximumSampleDistance = math.max(1, tonumber(RunScoreConfig.MaximumSampleDistance) or 28)

	if horizontalDistance > maximumSampleDistance then
		resetSampling(state, position)
		return
	end

	local pointsPerStud = math.max(0, tonumber(RunScoreConfig.PointsPerStud) or 1)
	state.Remainder += horizontalDistance * pointsPerStud
	local gainedScore = math.floor(state.Remainder)

	if gainedScore <= 0 then
		return
	end

	state.Remainder -= gainedScore
	state.Score += gainedScore
	state.PendingScore += gainedScore
end

local function publishPendingScores()
	for _, player in ipairs(Players:GetPlayers()) do
		local state = statesByUserId[player.UserId]

		if state ~= nil and state.IsActive and state.PendingScore > 0 then
			local delta = state.PendingScore
			state.PendingScore = 0
			sendState(player, delta)
			GameplayFeedbackService.Queue(player, "Run", delta)
		end
	end
end

function RunScoreService.GetScore(player: Player?): number
	if player == nil then
		return 0
	end

	local state = statesByUserId[player.UserId]
	return if state == nil then 0 else state.Score
end

function RunScoreService.SetupPlayer(player: Player)
	getOrCreateState(player)
	sendState(player)
end

function RunScoreService.RemovePlayer(player: Player?)
	if player ~= nil then
		statesByUserId[player.UserId] = nil
	end
end

function RunScoreService.Start()
	if isStarted then
		return
	end

	isStarted = true

	RunStateService.RunStarted:Connect(function(player)
		local state = getOrCreateState(player)
		state.IsActive = true
		state.PendingScore = 0
		state.Remainder = 0
		state.Score = 0
		state.LastPosition = getRootPosition(player)
		sendState(player)
	end)

	RunStateService.RunEnded:Connect(function(player)
		local state = getOrCreateState(player)
		state.IsActive = false
		state.PendingScore = 0
		state.LastPosition = nil
	end)

	RunService.Heartbeat:Connect(function(deltaTime)
		accumulator += deltaTime
		local sampleInterval = math.max(0.05, tonumber(RunScoreConfig.SampleInterval) or 0.15)

		if accumulator < sampleInterval then
			return
		end

		accumulator %= sampleInterval
		publishAccumulator += sampleInterval

		for _, player in ipairs(Players:GetPlayers()) do
			updatePlayerScore(player)
		end

		local publishInterval = math.max(sampleInterval, tonumber(RunScoreConfig.PublishInterval) or 0.45)

		if publishAccumulator >= publishInterval then
			publishAccumulator %= publishInterval
			publishPendingScores()
		end
	end)
end

return RunScoreService
