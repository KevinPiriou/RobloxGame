local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AdminConfig = require(Shared:WaitForChild("AdminConfig"))
local DebugLog = require(Shared:WaitForChild("DebugLog"))
local PerformanceBaselineConfig = require(Shared:WaitForChild("PerformanceBaselineConfig"))

local JumpBonusService = require(script.Parent:WaitForChild("JumpBonusService"))
local MonsterService = require(script.Parent:WaitForChild("MonsterService"))
local PerformanceBenchmarkService = require(script.Parent:WaitForChild("PerformanceBenchmarkService"))
local PhysicsAuditService = require(script.Parent:WaitForChild("PhysicsAuditService"))
local RunAnalyticsService = require(script.Parent:WaitForChild("RunAnalyticsService"))

local AdminService = {}

local ADMIN_ATTRIBUTE = "CanUseAdminTools"
local DEV_KIT_PREVIEW_ATTRIBUTE = "DevKitPreviewEnabled"
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

local function getOrCreateRemoteFunction(remoteName)
	local remote = ReplicatedStorage:FindFirstChild(remoteName)

	if remote == nil then
		remote = Instance.new("RemoteFunction")
		remote.Name = remoteName
		remote.Parent = ReplicatedStorage
	end

	assert(remote:IsA("RemoteFunction"), remoteName .. " doit etre un RemoteFunction.")

	return remote
end

local resetPowerUpsRemote = getOrCreateRemote("Admin_ResetPowerUps")
local spawnMonstersRemote = getOrCreateRemote("Admin_SpawnMonsters")
local killMonstersRemote = getOrCreateRemote("Admin_KillMonsters")
local adminMessageRemote = getOrCreateRemote("Admin_ShowMessage")
local setDebugLogSettingRemote = getOrCreateRemote("Admin_SetDebugLogSetting")
local debugLogStateRemote = getOrCreateRemote("Admin_DebugLogState")
local getDebugLogStateRemote = getOrCreateRemoteFunction("Admin_GetDebugLogState")
local toggleDevKitPreviewRemote = getOrCreateRemote("Admin_ToggleDevKitPreview")
local performanceBenchmarkRemote = getOrCreateRemote(PerformanceBaselineConfig.AdminRemoteName)
local physicsAuditRemote = getOrCreateRemote("Admin_RunPhysicsAudit")
local debugCategoryIds = {}

for _, category in ipairs(AdminConfig.DebugLogCategories) do
	debugCategoryIds[category.Id] = true
end

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

local function runAdminAction(player, refusedWarning, callback, shouldRecordAnalytics)
	if not canUseAdminTools(player) then
		DebugLog.Warn("Admin", refusedWarning .. " refuse", {
			Player = player.Name,
		})
		sendAdminMessage(player, false, "Acces admin refuse")
		return
	end

	if shouldRecordAnalytics ~= false then
		RunAnalyticsService.RecordAdminCommand(player)
	end

	local success, message = pcall(callback)

	if not success then
		DebugLog.Warn("Admin", refusedWarning .. " erreur", {
			Player = player.Name,
			Error = tostring(message),
		})
		sendAdminMessage(player, false, "Erreur admin")
		return
	end

	DebugLog.Info("Admin", refusedWarning .. " execute", {
		Player = player.Name,
		Message = message,
	})
	sendAdminMessage(player, true, message)
end

local function publishDebugLogState()
	local state = DebugLog.GetState()

	for _, targetPlayer in ipairs(Players:GetPlayers()) do
		debugLogStateRemote:FireClient(targetPlayer, state)
	end
end

function AdminService.SetupPlayer(player)
	player:SetAttribute(ADMIN_ATTRIBUTE, canUseAdminTools(player))
	player:SetAttribute(DEV_KIT_PREVIEW_ATTRIBUTE, false)
	DebugLog.Info("Admin", "Setup joueur admin", {
		Player = player.Name,
		CanUseAdminTools = player:GetAttribute(ADMIN_ATTRIBUTE),
	})
	debugLogStateRemote:FireClient(player, DebugLog.GetState())
end

function AdminService.RemovePlayer(player)
	player:SetAttribute(ADMIN_ATTRIBUTE, nil)
	player:SetAttribute(DEV_KIT_PREVIEW_ATTRIBUTE, nil)
end

function AdminService.Start()
	if isStarted then
		DebugLog.Info("Admin", "Start ignore, service deja demarre")
		return
	end

	isStarted = true
	DebugLog.Info("Admin", "AdminService demarre")

	getDebugLogStateRemote.OnServerInvoke = function(player)
		if not canUseAdminTools(player) then
			return nil
		end

		return DebugLog.GetState()
	end

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

	toggleDevKitPreviewRemote.OnServerEvent:Connect(function(player)
		runAdminAction(player, "Apercu kit UI", function()
			local isEnabled = player:GetAttribute(DEV_KIT_PREVIEW_ATTRIBUTE) ~= true
			player:SetAttribute(DEV_KIT_PREVIEW_ATTRIBUTE, isEnabled)

			return if isEnabled then "Apercu kit UI active" else "Apercu kit UI masque"
		end, false)
	end)

	physicsAuditRemote.OnServerEvent:Connect(function(player)
		runAdminAction(player, "Inventaire physique P1", function()
			return PhysicsAuditService.RunAudit()
		end, false)
	end)

	performanceBenchmarkRemote.OnServerEvent:Connect(function(player, payload)
		if not canUseAdminTools(player) then
			DebugLog.Warn("Admin", "Benchmark P0 refuse", {
				Player = player.Name,
			})
			sendAdminMessage(player, false, "Acces admin refuse")
			return
		end

		if typeof(payload) ~= "table" or typeof(payload.Action) ~= "string" then
			sendAdminMessage(player, false, "Commande P0 invalide")
			return
		end

		local success = false
		local message = "Commande P0 inconnue"

		if payload.Action == "Start" and typeof(payload.SelectionId) == "string" then
			success, message = PerformanceBenchmarkService.StartSelection(player, payload.SelectionId)
		elseif payload.Action == "Stop" then
			success, message = PerformanceBenchmarkService.StopScenario(player)
		end

		if success then
			RunAnalyticsService.RecordAdminCommand(player)
			DebugLog.Info("Perf", "Commande benchmark P0 executee", {
				Player = player.Name,
				Action = payload.Action,
				SelectionId = payload.SelectionId,
			})
		else
			DebugLog.Warn("Perf", "Commande benchmark P0 refusee", {
				Player = player.Name,
				Action = payload.Action,
				SelectionId = payload.SelectionId,
				Reason = message,
			})
		end

		sendAdminMessage(player, success, message)
	end)

	setDebugLogSettingRemote.OnServerEvent:Connect(function(player, payload)
		runAdminAction(player, "Reglage logs admin", function()
			if typeof(payload) ~= "table" or typeof(payload.Enabled) ~= "boolean" then
				error("Payload de logs invalide")
			end

			if payload.Scope == "Console" then
				DebugLog.SetConsoleEnabled(payload.Enabled)
				publishDebugLogState()
				return if payload.Enabled then "Console debug activee" else "Console debug desactivee"
			end

			if payload.Scope ~= "Category" or typeof(payload.Category) ~= "string"
				or debugCategoryIds[payload.Category] ~= true
			then
				error("Categorie de logs invalide")
			end

			DebugLog.SetCategoryEnabled(payload.Category, payload.Enabled)
			publishDebugLogState()

			return ("Logs %s : %s"):format(payload.Category, payload.Enabled and "actifs" or "coupes")
		end, false)
	end)
end

return AdminService
