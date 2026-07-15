-- Controle local du joueur.
-- Le serveur reste la source de verite pour les pauses, les perks et les mouvements autorises.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local DebugLog = require(Shared:WaitForChild("DebugLog"))
local RunLoadingConfig = require(Shared:WaitForChild("RunLoadingConfig"))

type ControlState = "Lobby" | "Loading" | "Run" | "Paused" | "Respawning"

local controls = nil
local currentHumanoid = nil
local currentState: ControlState? = nil
local isRunActive = player:GetAttribute("IsRunActive") == true
local isRunLoading = player:GetAttribute(RunLoadingConfig.AttributeName) == true
local isCombatPaused = player:GetAttribute("IsCombatPaused") == true
local humanoidDiedConnection = nil

local function getControls()
	if controls ~= nil then
		return controls
	end

	local playerScripts = player:WaitForChild("PlayerScripts")
	local playerModule = require(playerScripts:WaitForChild("PlayerModule"))
	controls = playerModule:GetControls()

	return controls
end

local function getControlState(): ControlState
	if currentHumanoid == nil or currentHumanoid.Parent == nil or currentHumanoid.Health <= 0 then
		return "Respawning"
	end

	if isRunLoading then
		return "Loading"
	end

	if isRunActive and isCombatPaused then
		return "Paused"
	end

	if isRunActive then
		return "Run"
	end

	return "Lobby"
end

local function restoreCameraSubject()
	local camera = Workspace.CurrentCamera

	if camera == nil or currentHumanoid == nil or currentHumanoid.Parent == nil then
		return
	end

	-- Ne touche pas a une camera de cinematique volontairement definie par un futur systeme.
	if camera.CameraType == Enum.CameraType.Custom
		and (camera.CameraSubject == nil or camera.CameraSubject.Parent == nil)
	then
		camera.CameraSubject = currentHumanoid
	end
end

local function refreshControls()
	local nextState = getControlState()
	local nextControlsEnabled = nextState == "Lobby" or nextState == "Run"

	getControls():Enable(nextControlsEnabled)
	restoreCameraSubject()

	if currentState ~= nextState then
		currentState = nextState
		DebugLog.Info("PlayerControl", "Etat de controle joueur mis a jour", {
			Player = player.Name,
			State = nextState,
			ControlsEnabled = nextControlsEnabled,
		})
	end
end

local function bindCharacter(character)
	if humanoidDiedConnection ~= nil then
		humanoidDiedConnection:Disconnect()
		humanoidDiedConnection = nil
	end

	local humanoid = character:WaitForChild("Humanoid", 8)

	if humanoid == nil or not humanoid:IsA("Humanoid") then
		currentHumanoid = nil
		refreshControls()
		return
	end

	currentHumanoid = humanoid
	humanoidDiedConnection = humanoid.Died:Connect(function()
		refreshControls()
	end)

	task.defer(function()
		restoreCameraSubject()
		refreshControls()
	end)
end

local function bindPauseState()
	local pauseRemote = ReplicatedStorage:WaitForChild("Combat_PauseState", 20)

	if pauseRemote == nil or not pauseRemote:IsA("RemoteEvent") then
		DebugLog.Warn("PlayerControl", "Remote de pause introuvable")
		return
	end

	pauseRemote.OnClientEvent:Connect(function(payload)
		payload = payload or {}
		isCombatPaused = payload.IsPaused == true
		refreshControls()
	end)
end

player.CharacterAdded:Connect(bindCharacter)

if player.Character ~= nil then
	task.defer(bindCharacter, player.Character)
end

player:GetAttributeChangedSignal("IsRunActive"):Connect(function()
	isRunActive = player:GetAttribute("IsRunActive") == true
	refreshControls()
end)

player:GetAttributeChangedSignal(RunLoadingConfig.AttributeName):Connect(function()
	isRunLoading = player:GetAttribute(RunLoadingConfig.AttributeName) == true
	refreshControls()
end)

player:GetAttributeChangedSignal("IsCombatPaused"):Connect(function()
	isCombatPaused = player:GetAttribute("IsCombatPaused") == true
	refreshControls()
end)

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(restoreCameraSubject)

task.spawn(bindPauseState)

DebugLog.Info("PlayerControl", "Controleur joueur initialise", {
	Player = player.Name,
})
