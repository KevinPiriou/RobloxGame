local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AdminConfig = require(Shared:WaitForChild("AdminConfig"))

local JumpBonusService = require(script.Parent:WaitForChild("JumpBonusService"))

local AdminService = {}

local ADMIN_ATTRIBUTE = "CanUseAdminTools"
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

local resetPowerUpsRemote = getOrCreateRemote("Admin_ResetPowerUps")
local adminMessageRemote = getOrCreateRemote("Admin_ShowMessage")

local function isConfiguredAdmin(player)
	for _, userId in ipairs(AdminConfig.AdminUserIds) do
		if userId == player.UserId then
			return true
		end
	end

	return false
end

local function isCreator(player)
	return game.CreatorId ~= 0 and player.UserId == game.CreatorId
end

local function canUseAdminTools(player)
	if AdminConfig.AllowStudioAdmin and RunService:IsStudio() then
		return true
	end

	return isCreator(player) or isConfiguredAdmin(player)
end

local function sendAdminMessage(player, success, message)
	adminMessageRemote:FireClient(player, {
		Success = success,
		Message = message,
	})
end

function AdminService.SetupPlayer(player)
	player:SetAttribute(ADMIN_ATTRIBUTE, canUseAdminTools(player))
end

function AdminService.RemovePlayer(player)
	player:SetAttribute(ADMIN_ATTRIBUTE, nil)
end

function AdminService.Start()
	if isStarted then
		return
	end

	isStarted = true

	resetPowerUpsRemote.OnServerEvent:Connect(function(player)
		if not canUseAdminTools(player) then
			warn("Reset admin refuse pour " .. player.Name)
			sendAdminMessage(player, false, "Acces admin refuse")
			return
		end

		local message = JumpBonusService.ResetPowerUps(player)
		sendAdminMessage(player, true, message)
	end)
end

return AdminService
