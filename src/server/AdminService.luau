local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AdminConfig = require(Shared:WaitForChild("AdminConfig"))

local JumpBonusService = require(script.Parent:WaitForChild("JumpBonusService"))
local MonsterService = require(script.Parent:WaitForChild("MonsterService"))

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
local spawnMonstersRemote = getOrCreateRemote("Admin_SpawnMonsters")
local killMonstersRemote = getOrCreateRemote("Admin_KillMonsters")
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

local function runAdminAction(player, refusedWarning, callback)
	if not canUseAdminTools(player) then
		warn(refusedWarning .. " refuse pour " .. player.Name)
		sendAdminMessage(player, false, "Acces admin refuse")
		return
	end

	local success, message = pcall(callback)

	if not success then
		warn(refusedWarning .. " erreur pour " .. player.Name .. " : " .. tostring(message))
		sendAdminMessage(player, false, "Erreur admin")
		return
	end

	sendAdminMessage(player, true, message)
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
		runAdminAction(player, "Reset admin", function()
			return JumpBonusService.ResetPowerUps(player)
		end)
	end)

	spawnMonstersRemote.OnServerEvent:Connect(function(player)
		runAdminAction(player, "Spawn admin", function()
			local spawnedCount, maxToSpawn = MonsterService.DebugSpawnMonstersNearPlayer(
				player,
				AdminConfig.DebugSpawnMonsterCount
			)

			return ("Spawn debug : %d/%d ennemis"):format(spawnedCount, maxToSpawn)
		end)
	end)

	killMonstersRemote.OnServerEvent:Connect(function(player)
		runAdminAction(player, "Kill admin", function()
			local killedCount = MonsterService.DebugKillAllMonsters()

			return ("Debug : %d ennemis supprimes"):format(killedCount)
		end)
	end)
end

return AdminService
