--!strict

-- Regroupe les confirmations de gameplay avant de les envoyer au client.
-- Les montants sont toujours etablis par les services serveur appelants.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PickupFeedbackConfig = require(Shared:WaitForChild("PickupFeedbackConfig"))

local RunStateService = require(script.Parent:WaitForChild("RunStateService"))

local GameplayFeedbackService = {}

type PendingFeedback = {
	Amount: number,
}

local pendingByUserId: { [number]: { [string]: PendingFeedback } } = {}
local accumulator = 0
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

local feedbackRemote = getOrCreateRemote(PickupFeedbackConfig.RemoteName)

local function getMinimumAmount(kind: string): number
	local minimumAmounts = PickupFeedbackConfig.MinimumAmounts

	if typeof(minimumAmounts) ~= "table" then
		return 0
	end

	return math.max(0, tonumber(minimumAmounts[kind]) or 0)
end

local function flushPlayer(player: Player)
	local queued = pendingByUserId[player.UserId]

	if queued == nil or player.Parent ~= Players then
		return
	end

	for kind, entry in pairs(queued) do
		local minimumAmount = getMinimumAmount(kind)

		if entry.Amount >= minimumAmount then
			feedbackRemote:FireClient(player, {
				Kind = kind,
				Amount = entry.Amount,
			})
			queued[kind] = nil
		end
	end

	if next(queued) == nil then
		pendingByUserId[player.UserId] = nil
	end
end

function GameplayFeedbackService.Queue(player: Player?, kind: string, amount: number)
	if player == nil or player.Parent ~= Players then
		return
	end

	local sanitizedAmount = math.max(0, tonumber(amount) or 0)

	if sanitizedAmount <= 0 then
		return
	end

	local sanitizedKind = tostring(kind or "")

	if sanitizedKind == "" then
		return
	end

	local queued = pendingByUserId[player.UserId]

	if queued == nil then
		queued = {}
		pendingByUserId[player.UserId] = queued
	end

	local entry = queued[sanitizedKind]

	if entry == nil then
		entry = { Amount = 0 }
		queued[sanitizedKind] = entry
	end

	entry.Amount += sanitizedAmount
end

function GameplayFeedbackService.RemovePlayer(player: Player?)
	if player ~= nil then
		pendingByUserId[player.UserId] = nil
	end
end

function GameplayFeedbackService.Start()
	if isStarted then
		return
	end

	isStarted = true

	RunStateService.RunEnded:Connect(function(player)
		GameplayFeedbackService.RemovePlayer(player)
	end)

	RunService.Heartbeat:Connect(function(deltaTime)
		accumulator += deltaTime
		local flushInterval = math.max(0.05, tonumber(PickupFeedbackConfig.ServerFlushInterval) or 0.12)

		if accumulator < flushInterval then
			return
		end

		accumulator %= flushInterval

		for _, player in ipairs(Players:GetPlayers()) do
			flushPlayer(player)
		end
	end)
end

return GameplayFeedbackService
