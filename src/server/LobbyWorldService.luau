local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ChapterConfig = require(Shared:WaitForChild("ChapterConfig"))
local DebugLog = require(Shared:WaitForChild("DebugLog"))
local LobbyConfig = require(Shared:WaitForChild("LobbyConfig"))

local RunStateService = require(script.Parent:WaitForChild("RunStateService"))
local TemplateService = require(script.Parent:WaitForChild("TemplateService"))

local LobbyWorldService = {}

local isStarted = false
local serverRole = "Unknown"
local activeLobby = nil

local function isSupportedTemplate(instance)
	return instance:IsA("Model") or instance:IsA("Folder") or instance:IsA("BasePart")
end

local function getRuntimeFolder()
	return TemplateService.GetWorkspaceRuntimeFolder(LobbyConfig.RuntimeFolderName)
end

local function getTemplateFolder()
	return TemplateService.GetServerTemplateFolder(LobbyConfig.TemplateFolderName)
end

local function findUniqueLobbyCandidate(parent, excludedInstance)
	local candidates = {}

	for _, child in ipairs(parent:GetChildren()) do
		if child ~= excludedInstance
			and isSupportedTemplate(child)
			and string.find(string.lower(child.Name), "lobby", 1, true) ~= nil then
			table.insert(candidates, child)
		end
	end

	return if #candidates == 1 then candidates[1] else nil, #candidates
end

local function findTemplate()
	local templateFolder = getTemplateFolder()
	local configured = templateFolder:FindFirstChild(LobbyConfig.TemplateName)

	if configured ~= nil and isSupportedTemplate(configured) then
		return configured
	end

	local onlyTemplate = nil
	local templateCount = 0

	for _, child in ipairs(templateFolder:GetChildren()) do
		if isSupportedTemplate(child) then
			templateCount += 1
			onlyTemplate = child
		end
	end

	if templateCount == 1 then
		DebugLog.Warn("LobbyWorld", "Template de lobby deduit depuis le dossier", {
			Template = onlyTemplate,
			ExpectedName = LobbyConfig.TemplateName,
		})
		return onlyTemplate
	end

	-- Compatibilite de migration : un seul modele contenant "lobby" a la racine
	-- de ServerStorage est range dans le dossier dedie.
	local legacyTemplate, legacyCount = findUniqueLobbyCandidate(ServerStorage, templateFolder)

	if legacyTemplate ~= nil then
		legacyTemplate.Parent = templateFolder
		DebugLog.Warn("LobbyWorld", "Template de lobby migre vers LobbyTemplates", {
			Template = legacyTemplate,
			Target = "ServerStorage/" .. LobbyConfig.TemplateFolderName,
		})
		return legacyTemplate
	end

	local mapTemplates = ServerStorage:FindFirstChild(ChapterConfig.TemplateFolderName)
	local mapTemplate = nil
	local mapTemplateCount = 0

	if mapTemplates ~= nil and mapTemplates:IsA("Folder") then
		mapTemplate, mapTemplateCount = findUniqueLobbyCandidate(mapTemplates)
	end

	if mapTemplate ~= nil then
		mapTemplate.Parent = templateFolder
		DebugLog.Warn("LobbyWorld", "Template de lobby extrait de MapTemplates", {
			Template = mapTemplate,
			Target = "ServerStorage/" .. LobbyConfig.TemplateFolderName,
		})
		return mapTemplate
	end

	DebugLog.Warn("LobbyWorld", "Template de lobby introuvable ou ambigu", {
		Expected = "ServerStorage/" .. LobbyConfig.TemplateFolderName .. "/" .. LobbyConfig.TemplateName,
		TemplatesInFolder = templateCount,
		LegacyCandidates = legacyCount,
		MapTemplateCandidates = mapTemplateCount,
	})

	return nil
end

local function disableTemplateScripts(lobby)
	if not LobbyConfig.DisableTemplateScripts then
		return 0
	end

	local disabledCount = 0

	for _, descendant in ipairs(lobby:GetDescendants()) do
		if descendant:IsA("BaseScript") then
			descendant.Disabled = true
			disabledCount += 1
		end
	end

	return disabledCount
end

local function getLobbySpawn(lobby)
	local namedSpawn = lobby:FindFirstChild(LobbyConfig.SpawnName, true)

	if namedSpawn ~= nil and namedSpawn:IsA("BasePart") then
		return namedSpawn
	end

	return lobby:FindFirstChildWhichIsA("SpawnLocation", true)
end

local function placePlayerAtLobby(player)
	if activeLobby == nil or activeLobby.Parent == nil then
		return
	end

	local spawn = getLobbySpawn(activeLobby)

	if spawn == nil then
		return
	end

	local function moveCharacter(character)
		local root = character:WaitForChild("HumanoidRootPart", 8)

		if root ~= nil and root:IsA("BasePart") and not RunStateService.IsRunActive(player) then
			character:PivotTo(spawn.CFrame + Vector3.new(0, LobbyConfig.SpawnHeightOffset, 0))
		end
	end

	if player.Character ~= nil then
		task.defer(moveCharacter, player.Character)
	else
		player.CharacterAdded:Once(moveCharacter)
	end
end

local function getJoinMode(player)
	local success, joinData = pcall(function()
		return player:GetJoinData()
	end)

	if not success or typeof(joinData) ~= "table" then
		return "Lobby"
	end

	local teleportData = joinData.TeleportData

	if typeof(teleportData) == "table" and teleportData.runMode == "Solo" and typeof(teleportData.runId) == "string" then
		return "Run"
	end

	return "Lobby"
end

function LobbyWorldService.EnsureLobby()
	if serverRole == "Run" then
		return false, "RunServer"
	end

	local runtimeFolder = getRuntimeFolder()

	if activeLobby ~= nil and activeLobby.Parent == runtimeFolder then
		return true, activeLobby
	end

	for _, child in ipairs(runtimeFolder:GetChildren()) do
		if child:GetAttribute("IsLobbyRuntime") == true then
			activeLobby = child
			return true, activeLobby
		end
	end

	local template = findTemplate()

	if template == nil then
		return false, "LobbyTemplateMissing"
	end

	local lobby = template:Clone()
	lobby.Name = LobbyConfig.TemplateName
	lobby:SetAttribute("IsLobbyRuntime", true)
	lobby:SetAttribute("LobbyTemplateName", template.Name)
	lobby.Parent = runtimeFolder

	local disabledCount = disableTemplateScripts(lobby)
	activeLobby = lobby

	DebugLog.Info("LobbyWorld", "Lobby runtime genere", {
		Template = template,
		Runtime = lobby,
		DisabledScripts = disabledCount,
	})

	return true, lobby
end

function LobbyWorldService.ClearLobby()
	local runtimeFolder = getRuntimeFolder()

	for _, child in ipairs(runtimeFolder:GetChildren()) do
		child:Destroy()
	end

	activeLobby = nil
end

function LobbyWorldService.SetupPlayer(player)
	local joinMode = getJoinMode(player)

	if joinMode == "Run" then
		if serverRole == "Unknown" then
			serverRole = "Run"
			LobbyWorldService.ClearLobby()
			DebugLog.Info("LobbyWorld", "Serveur reserve identifie comme run", {
				Player = player.Name,
			})
		elseif serverRole ~= "Run" then
			DebugLog.Warn("LobbyWorld", "Arrivee de run refusee dans un serveur lobby", {
				Player = player.Name,
			})
		end

		return
	end

	if serverRole == "Unknown" then
		serverRole = "Lobby"
	end

	if serverRole ~= "Lobby" then
		DebugLog.Warn("LobbyWorld", "Joueur lobby detecte dans un serveur de run", {
			Player = player.Name,
		})
		return
	end

	local generated = LobbyWorldService.EnsureLobby()

	if generated then
		placePlayerAtLobby(player)
	end
end

function LobbyWorldService.RemovePlayer(_player)
	-- Le lobby reste en place pour les autres joueurs du serveur public.
end

function LobbyWorldService.Start()
	if isStarted then
		return
	end

	isStarted = true

	RunStateService.RunStarted:Connect(function()
		if RunService:IsStudio() and LobbyConfig.HideLobbyDuringStudioRun then
			LobbyWorldService.ClearLobby()
			DebugLog.Info("LobbyWorld", "Lobby masque pour la simulation de run Studio")
		end
	end)

	RunStateService.RunEnded:Connect(function()
		if RunService:IsStudio() and LobbyConfig.HideLobbyDuringStudioRun and serverRole ~= "Run" then
			task.defer(function()
				local generated = LobbyWorldService.EnsureLobby()

				if generated then
					for _, player in ipairs(Players:GetPlayers()) do
						placePlayerAtLobby(player)
					end
				end
			end)
		end
	end)

	DebugLog.Info("LobbyWorld", "LobbyWorldService demarre")
end

return LobbyWorldService
