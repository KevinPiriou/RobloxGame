local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DebugLog = require(Shared:WaitForChild("DebugLog"))
local HudMessageConfig = require(Shared:WaitForChild("HudMessageConfig"))

local HudMessageService = {}

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

local messageRemote = getOrCreateRemote(HudMessageConfig.RemoteName)

local function buildPayload(styleId, overrides)
	overrides = overrides or {}

	local style = HudMessageConfig.Styles[styleId] or HudMessageConfig.Styles[HudMessageConfig.DefaultStyleId]
	local message = overrides.Message or (style and style.Message) or "Evenement"
	local duration = overrides.Duration or (style and style.Duration) or HudMessageConfig.DefaultDuration

	return {
		StyleId = styleId or HudMessageConfig.DefaultStyleId,
		Message = message,
		Duration = duration,
	}
end

function HudMessageService.Show(player, styleId, overrides)
	if player == nil or player.Parent == nil then
		return
	end

	local payload = buildPayload(styleId, overrides)

	messageRemote:FireClient(player, payload)
	DebugLog.Info("HudMessage", "Message HUD envoye", {
		Player = player.Name,
		StyleId = payload.StyleId,
		Message = payload.Message,
	})
end

function HudMessageService.Broadcast(styleId, overrides)
	local payload = buildPayload(styleId, overrides)

	messageRemote:FireAllClients(payload)
	DebugLog.Info("HudMessage", "Message HUD broadcast", {
		StyleId = payload.StyleId,
		Message = payload.Message,
	})
end

return HudMessageService
