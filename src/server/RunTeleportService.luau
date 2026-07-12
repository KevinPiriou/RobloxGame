local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DebugLog = require(Shared:WaitForChild("DebugLog"))
local RunTeleportConfig = require(Shared:WaitForChild("RunTeleportConfig"))

local ChapterProgressService = require(script.Parent:WaitForChild("ChapterProgressService"))
local RunSessionService = require(script.Parent:WaitForChild("RunSessionService"))
local RunStateService = require(script.Parent:WaitForChild("RunStateService"))

local RunTeleportService = {}

local isStarted = false
local trackedTriggers = {}
local cooldownsByUserId = {}
local teleportingByUserId = {}
local arrivalConnectionsByUserId = {}
local neutralizedContainers = {}
local pendingLobbySummariesByUserId = {}

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

local runSummaryRemote = getOrCreateRemote("Run_ShowSummary")
local startRunRemote = getOrCreateRemoteFunction("Run_StartRequest")

local function getPlayerFromHit(hit)
	if hit == nil then
		return nil
	end

	local character = hit:FindFirstAncestorOfClass("Model")

	if character == nil then
		return nil
	end

	return Players:GetPlayerFromCharacter(character)
end

local function getContainerNamed(instance, containerName)
	local current = instance

	while current ~= nil and current ~= Workspace do
		if current.Name == containerName then
			return current
		end

		current = current.Parent
	end

	return nil
end

local function getTriggerContainer(instance)
	return getContainerNamed(instance, RunTeleportConfig.TriggerPartName)
end

local function neutralizeContainer(container, shouldDisableTouch)
	if container == nil or neutralizedContainers[container] then
		return
	end

	neutralizedContainers[container] = true

	local disabledScriptCount = 0
	local disabledTouchCount = 0

	for _, descendant in ipairs(container:GetDescendants()) do
		if descendant:IsA("BaseScript") then
			descendant.Disabled = true
			disabledScriptCount += 1
		elseif shouldDisableTouch and descendant:IsA("BasePart") then
			descendant.CanTouch = false
			disabledTouchCount += 1
		end
	end

	if container:IsA("BaseScript") then
		container.Disabled = true
		disabledScriptCount += 1
	elseif shouldDisableTouch and container:IsA("BasePart") then
		container.CanTouch = false
		disabledTouchCount += 1
	end

	if disabledScriptCount > 0 or disabledTouchCount > 0 then
		DebugLog.Warn("RunTeleport", "Teleport boutique neutralise", {
			Container = container,
			DisabledScripts = disabledScriptCount,
			DisabledTouchParts = disabledTouchCount,
		})
	end
end

local function neutralizeTeleportTemplateParts()
	if not RunTeleportConfig.DisableTemplateTeleportScripts then
		return
	end

	local seenContainers = {}

	for _, descendant in ipairs(Workspace:GetDescendants()) do
		local trigger = getContainerNamed(descendant, RunTeleportConfig.TriggerPartName)

		if trigger ~= nil and not seenContainers[trigger] then
			seenContainers[trigger] = true
			neutralizeContainer(trigger, false)
		end

		local arrival = getContainerNamed(descendant, RunTeleportConfig.ArrivalPartName)

		if arrival ~= nil and not seenContainers[arrival] then
			seenContainers[arrival] = true
			neutralizeContainer(arrival, RunTeleportConfig.DisableArrivalTouch == true)
		end
	end
end

local function getBaseParts(instance)
	local parts = {}

	if instance:IsA("BasePart") then
		table.insert(parts, instance)
		return parts
	end

	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end

	return parts
end

local function findArrivalInstance(arrivalPartName)
	local arrival = Workspace:FindFirstChild(arrivalPartName, true)

	if arrival == nil then
		return nil
	end

	if arrival:IsA("BasePart") or arrival:IsA("Model") then
		return arrival
	end

	local parent = arrival:FindFirstAncestorOfClass("Model")

	if parent ~= nil then
		return parent
	end

	return nil
end

local function getInstancePivot(instance)
	if instance:IsA("Model") then
		return instance:GetPivot()
	end

	if instance:IsA("BasePart") then
		return instance.CFrame
	end

	return nil
end

local function destroyArrivalInstance(arrival)
	if not RunTeleportConfig.DestroyArrivalAfterUse then
		return false
	end

	if arrival == nil or arrival.Parent == nil then
		return false
	end

	local arrivalName = arrival.Name
	arrival:Destroy()

	DebugLog.Warn("RunTeleport", "Point d'arrivee run supprime apres usage", {
		ArrivalName = arrivalName,
	})

	return true
end

local function movePlayerToArrival(player, arrivalPartName, providedArrival)
	local character = player.Character

	if character == nil then
		return false, "CharacterMissing", nil
	end

	local root = character:FindFirstChild("HumanoidRootPart")

	if root == nil then
		root = character:WaitForChild("HumanoidRootPart", 8)
	end

	if root == nil then
		return false, "RootMissing", nil
	end

	local arrival = providedArrival or findArrivalInstance(arrivalPartName)

	if arrival == nil then
		return false, "ArrivalMissing", nil
	end

	local arrivalPivot = getInstancePivot(arrival)

	if arrivalPivot == nil then
		return false, "ArrivalPivotMissing", nil
	end

	character:PivotTo(arrivalPivot + Vector3.new(0, RunTeleportConfig.ArrivalHeightOffset, 0))

	return true, "Ok", arrival
end

local function copyTeleportData(player)
	local data = {}

	for key, value in pairs(RunTeleportConfig.TeleportData or {}) do
		data[key] = value
	end

	data.arrivalPartName = RunTeleportConfig.ArrivalPartName
	data.sourcePartName = RunTeleportConfig.TriggerPartName

	local sessionData = RunSessionService.GetTeleportData(player)

	if sessionData ~= nil then
		for key, value in pairs(sessionData) do
			data[key] = value
		end
	end

	return data
end

local function copyLobbyTeleportData(summary)
	return {
		runMode = "LobbyReturn",
		runSummary = summary,
	}
end

local function canStartTeleport(player)
	if not RunTeleportConfig.Enabled then
		return false, "Disabled"
	end

	if player == nil or player.Parent == nil then
		return false, "PlayerMissing"
	end

	if teleportingByUserId[player.UserId] then
		return false, "AlreadyTeleporting"
	end

	if RunStateService.IsRunActive(player) then
		return false, "RunAlreadyActive"
	end

	local now = os.clock()
	local lastTouchAt = cooldownsByUserId[player.UserId]

	if lastTouchAt ~= nil and now - lastTouchAt < RunTeleportConfig.TouchCooldownSeconds then
		return false, "Cooldown"
	end

	if RunTeleportConfig.RunPlaceId == nil or RunTeleportConfig.RunPlaceId <= 0 then
		return false, "InvalidPlaceId"
	end

	return true, "Ok"
end

function RunTeleportService.StartSoloRun(player, trigger, explicitChapterId)
	local canStart, reason = canStartTeleport(player)

	if not canStart then
		DebugLog.ThrottledInfo("RunTeleport", "teleport_refused_" .. tostring(player and player.UserId), 2, "Teleport run refuse", {
			Player = player and player.Name or "nil",
			Reason = reason,
			Trigger = trigger,
		})
		return false, reason
	end

	cooldownsByUserId[player.UserId] = os.clock()
	teleportingByUserId[player.UserId] = true

	local requestedChapter = math.floor(
		tonumber(explicitChapterId)
			or tonumber(trigger and trigger:GetAttribute("ChapterId"))
			or ChapterProgressService.GetSelectedChapter(player)
	)
	local prepared, sessionOrReason = RunSessionService.PrepareRun(player, requestedChapter)

	if not prepared then
		teleportingByUserId[player.UserId] = nil
		DebugLog.Warn("RunTeleport", "Preparation de run refusee", {
			Player = player.Name,
			ChapterId = requestedChapter,
			Reason = sessionOrReason,
		})
		return false, sessionOrReason
	end

	local teleportData = copyTeleportData(player)

	if RunService:IsStudio() and RunTeleportConfig.StudioSimulatesArrival then
		local activated, activateReason, generatedArrival = RunSessionService.ActivatePreparedRun(
			player,
			sessionOrReason.RunId,
			"StudioTeleport"
		)
		local moved, moveReason, arrival = false, activateReason, nil

		if activated then
			moved, moveReason, arrival = movePlayerToArrival(
				player,
				RunTeleportConfig.ArrivalPartName,
				generatedArrival
			)
		end
		local arrivalDestroyed = false

		teleportingByUserId[player.UserId] = nil
		if moved then
			arrivalDestroyed = destroyArrivalInstance(arrival)
		elseif activated then
			RunStateService.EndRun(player, "ArrivalFailed")
		end
		DebugLog.Warn("RunTeleport", "Teleport reserve simule en Studio", {
			Player = player.Name,
			ArrivalPartName = RunTeleportConfig.ArrivalPartName,
			Moved = moved,
			Reason = moveReason,
			ArrivalDestroyed = arrivalDestroyed,
		})
		return moved, moveReason
	end

	local teleportOptions = Instance.new("TeleportOptions")
	teleportOptions.ShouldReserveServer = RunTeleportConfig.ShouldReserveServer == true
	teleportOptions:SetTeleportData(teleportData)

	local success, result = pcall(function()
		return TeleportService:TeleportAsync(RunTeleportConfig.RunPlaceId, { player }, teleportOptions)
	end)

	if not success then
		teleportingByUserId[player.UserId] = nil
		RunSessionService.CancelPreparedRun(player, "TeleportFailed")
		DebugLog.Warn("RunTeleport", "Teleport run impossible", {
			Player = player.Name,
			PlaceId = RunTeleportConfig.RunPlaceId,
			Error = tostring(result),
		})
		return false, "TeleportFailed"
	end

	RunSessionService.MarkTeleporting(player)

	DebugLog.Info("RunTeleport", "Teleport run demande", {
		Player = player.Name,
		PlaceId = RunTeleportConfig.RunPlaceId,
		Reserved = RunTeleportConfig.ShouldReserveServer == true,
		Result = tostring(result),
	})

	return true, "TeleportRequested"
end

function RunTeleportService.ReturnToLobby(player, summary)
	if player == nil or player.Parent == nil then
		return false
	end

	if RunService:IsStudio() and RunTeleportConfig.StudioSimulatesLobbyReturn then
		player:LoadCharacter()

		if summary ~= nil then
			task.delay(0.7, function()
				if player.Parent ~= nil then
					runSummaryRemote:FireClient(player, summary)
				end
			end)
		end

		DebugLog.Warn("RunTeleport", "Retour lobby simule en Studio", {
			Player = player.Name,
		})
		return true
	end

	local lobbyPlaceId = RunTeleportConfig.LobbyPlaceId or game.PlaceId

	if lobbyPlaceId <= 0 then
		DebugLog.Warn("RunTeleport", "Retour lobby impossible, PlaceId invalide", {
			Player = player.Name,
			PlaceId = lobbyPlaceId,
		})
		return false
	end

	local teleportOptions = Instance.new("TeleportOptions")
	teleportOptions:SetTeleportData(copyLobbyTeleportData(summary))

	local success, result = pcall(function()
		return TeleportService:TeleportAsync(lobbyPlaceId, { player }, teleportOptions)
	end)

	if not success then
		DebugLog.Warn("RunTeleport", "Retour lobby impossible", {
			Player = player.Name,
			PlaceId = lobbyPlaceId,
			Error = tostring(result),
		})
		return false
	end

	if summary ~= nil then
		pendingLobbySummariesByUserId[player.UserId] = summary
	end

	DebugLog.Info("RunTeleport", "Retour lobby demande", {
		Player = player.Name,
		PlaceId = lobbyPlaceId,
	})
	return true
end

local function onTriggerTouched(trigger, hit)
	local player = getPlayerFromHit(hit)

	if player == nil then
		return
	end

	RunTeleportService.StartSoloRun(player, trigger)
end

local function trackTrigger(instance)
	local trigger = getTriggerContainer(instance)

	if trigger == nil or trackedTriggers[trigger] ~= nil then
		return
	end

	local parts = getBaseParts(trigger)

	if #parts <= 0 then
		DebugLog.Warn("RunTeleport", "Plaque de teleport sans BasePart", {
			Trigger = trigger,
		})
		return
	end

	local connections = {}

	for _, part in ipairs(parts) do
		part.CanTouch = true
		table.insert(connections, part.Touched:Connect(function(hit)
			onTriggerTouched(trigger, hit)
		end))
	end

	trackedTriggers[trigger] = connections

	DebugLog.Info("RunTeleport", "Plaque de lancement run trackee", {
		Trigger = trigger,
		PartCount = #parts,
		RunPlaceId = RunTeleportConfig.RunPlaceId,
		ArrivalPartName = RunTeleportConfig.ArrivalPartName,
	})
end

local function scanTriggers()
	for _, descendant in ipairs(Workspace:GetDescendants()) do
		trackTrigger(descendant)
	end
end

local function getSoloTeleportData(player)
	local success, joinData = pcall(function()
		return player:GetJoinData()
	end)

	if not success or typeof(joinData) ~= "table" then
		return nil
	end

	local teleportData = joinData.TeleportData

	if typeof(teleportData) ~= "table" or teleportData.runMode ~= "Solo" then
		return nil
	end

	return teleportData
end

local function getLobbyReturnSummary(player)
	local success, joinData = pcall(function()
		return player:GetJoinData()
	end)

	if not success or typeof(joinData) ~= "table" then
		return nil
	end

	local teleportData = joinData.TeleportData

	if typeof(teleportData) ~= "table" or teleportData.runMode ~= "LobbyReturn" then
		return nil
	end

	if typeof(teleportData.runSummary) ~= "table" then
		return nil
	end

	return teleportData.runSummary
end

function RunTeleportService.SetupPlayer(player)
	local lobbySummary = getLobbyReturnSummary(player)

	if lobbySummary ~= nil then
		RunSessionService.ResolveArrival(player, nil)

		local function sendLobbySummary()
			local connection = arrivalConnectionsByUserId[player.UserId]

			if connection ~= nil then
				connection:Disconnect()
				arrivalConnectionsByUserId[player.UserId] = nil
			end

			task.delay(0.7, function()
				if player.Parent ~= nil then
					runSummaryRemote:FireClient(player, lobbySummary)
				end
			end)
		end

		if player.Character ~= nil then
			sendLobbySummary()
		else
			arrivalConnectionsByUserId[player.UserId] = player.CharacterAdded:Connect(sendLobbySummary)
		end

		return
	end

	local soloTeleportData = getSoloTeleportData(player)

	if soloTeleportData == nil then
		RunSessionService.ResolveArrival(player, nil)
		return
	end

	local arrivalPartName = if typeof(soloTeleportData.arrivalPartName) == "string"
		and soloTeleportData.arrivalPartName ~= ""
		then soloTeleportData.arrivalPartName
		else RunTeleportConfig.ArrivalPartName

	neutralizeTeleportTemplateParts()

	local function placeCharacter()
		local activated, activationReason, generatedArrival = RunSessionService.ResolveArrival(player, soloTeleportData)
		local moved, reason, arrival = false, activationReason, nil

		if activated then
			moved, reason, arrival = movePlayerToArrival(player, arrivalPartName, generatedArrival)
		end
		local arrivalDestroyed = false

		if moved then
			arrivalDestroyed = destroyArrivalInstance(arrival)
		elseif activated then
			RunStateService.EndRun(player, "ArrivalFailed")
		end

		DebugLog.Info("RunTeleport", "Placement joueur apres teleport", {
			Player = player.Name,
			ArrivalPartName = arrivalPartName,
			Moved = moved,
			Reason = reason,
			ArrivalDestroyed = arrivalDestroyed,
		})

		local connection = arrivalConnectionsByUserId[player.UserId]

		if connection ~= nil then
			connection:Disconnect()
			arrivalConnectionsByUserId[player.UserId] = nil
		end
	end

	if player.Character ~= nil then
		task.defer(placeCharacter)
	else
		arrivalConnectionsByUserId[player.UserId] = player.CharacterAdded:Connect(function()
			task.defer(placeCharacter)
		end)
	end
end

function RunTeleportService.RemovePlayer(player)
	teleportingByUserId[player.UserId] = nil
	cooldownsByUserId[player.UserId] = nil
	pendingLobbySummariesByUserId[player.UserId] = nil

	local connection = arrivalConnectionsByUserId[player.UserId]

	if connection ~= nil then
		connection:Disconnect()
		arrivalConnectionsByUserId[player.UserId] = nil
	end
end

function RunTeleportService.Start()
	if isStarted then
		DebugLog.Info("RunTeleport", "Start ignore, service deja demarre")
		return
	end

	isStarted = true
	startRunRemote.OnServerInvoke = function(player, chapterId)
		local selected, selectionReason = ChapterProgressService.SelectChapter(player, chapterId)

		if not selected then
			DebugLog.Warn("RunTeleport", "Lancement GUI refuse", {
				Player = player.Name,
				ChapterId = chapterId,
				Reason = selectionReason,
			})
			return false, selectionReason
		end

		return RunTeleportService.StartSoloRun(player, nil, chapterId)
	end

	neutralizeTeleportTemplateParts()
	scanTriggers()

	Workspace.DescendantAdded:Connect(function(descendant)
		task.defer(function()
			local trigger = getContainerNamed(descendant, RunTeleportConfig.TriggerPartName)
			local arrival = getContainerNamed(descendant, RunTeleportConfig.ArrivalPartName)

			if trigger ~= nil then
				neutralizeContainer(trigger, false)
			end

			if arrival ~= nil then
				neutralizeContainer(arrival, RunTeleportConfig.DisableArrivalTouch == true)
			end

			trackTrigger(descendant)
		end)
	end)

	Workspace.DescendantRemoving:Connect(function(descendant)
		local connections = trackedTriggers[descendant]

		if connections == nil then
			return
		end

		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end

		trackedTriggers[descendant] = nil
	end)

	TeleportService.TeleportInitFailed:Connect(function(player, teleportResult, errorMessage, placeId)
		teleportingByUserId[player.UserId] = nil
		RunSessionService.CancelPreparedRun(player, "TeleportInitFailed")
		local pendingSummary = pendingLobbySummariesByUserId[player.UserId]
		pendingLobbySummariesByUserId[player.UserId] = nil
		DebugLog.Warn("RunTeleport", "Initialisation teleport echouee", {
			Player = player.Name,
			Result = tostring(teleportResult),
			Error = tostring(errorMessage),
			PlaceId = placeId,
		})

		if pendingSummary ~= nil then
			player:LoadCharacter()
			task.delay(0.7, function()
				if player.Parent ~= nil then
					runSummaryRemote:FireClient(player, pendingSummary)
				end
			end)
		end
	end)

	DebugLog.Info("RunTeleport", "RunTeleportService demarre", {
		Enabled = RunTeleportConfig.Enabled,
		TriggerPartName = RunTeleportConfig.TriggerPartName,
		ArrivalPartName = RunTeleportConfig.ArrivalPartName,
		RunPlaceId = RunTeleportConfig.RunPlaceId,
	})
end

return RunTeleportService
