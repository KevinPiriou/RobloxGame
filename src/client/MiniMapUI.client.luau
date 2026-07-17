local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DebugLog = require(Shared:WaitForChild("DebugLog"))
local MiniMapConfig = require(Shared:WaitForChild("MiniMapConfig"))
local UiTemplateConfig = require(Shared:WaitForChild("UiTemplateConfig"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))

local PRODUCTION_TEMPLATE_GUI_NAME = UiTemplateConfig.ProductionTemplateGuiName
local PRODUCTION_GUI_NAME = "MiniMapGui"
local PRODUCTION_DOCK_NAME = "MiniMapPanelV2"

type MarkerVisual = {
	Core: Frame,
	Glow: Frame,
}

local existingGui = playerGui:FindFirstChild(PRODUCTION_GUI_NAME)

if existingGui ~= nil then
	existingGui:Destroy()
end

local function addCorner(instance: GuiObject, radius: number)
	return UiTheme.AddCorner(instance, radius)
end

local function addStroke(instance: GuiObject, color: Color3, transparency: number, thickness: number)
	return UiTheme.AddStroke(instance, color, transparency, thickness)
end

local function getMiniMapTemplate(): Frame?
	local templateGui = StarterGui:FindFirstChild(PRODUCTION_TEMPLATE_GUI_NAME)
	local runCanvas = templateGui and templateGui:FindFirstChild("RunCanvas")
	local dock = runCanvas and runCanvas:FindFirstChild("MiniMapDock")

	if dock and dock:IsA("Frame") then
		return dock
	end

	DebugLog.Warn("UI", "Minimap V2 non initialisee, template introuvable", {
		ProductionTemplate = templateGui ~= nil,
		RunCanvas = runCanvas ~= nil,
		Template = dock ~= nil,
	})
	return nil
end

local template = getMiniMapTemplate()

if template == nil then
	return
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = PRODUCTION_GUI_NAME
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 26
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Enabled = true
screenGui.Parent = playerGui

local panel = template:Clone()
panel.Name = PRODUCTION_DOCK_NAME
panel.Visible = false
panel:SetAttribute("ProductionBound", true)
panel.Parent = screenGui

local content = panel:FindFirstChild("Content")
local mapArea = content and content:FindFirstChild("Radar")

if mapArea == nil or not mapArea:IsA("Frame") then
	DebugLog.Warn("UI", "Minimap V2 non initialisee, radar introuvable")
	screenGui:Destroy()
	return
end

-- Le template contient quelques points de demonstration. Ils ne doivent jamais
-- survivre dans une run : les seuls reperes visibles proviennent du runtime.
for _, markerName in ipairs({
	"PlayerGlow",
	"Player",
	"ShrineAGlow",
	"ShrineA",
	"ShrineBGlow",
	"ShrineB",
	"ChestAGlow",
	"ChestA",
	"ChestBGlow",
	"ChestB",
	"BossGlow",
	"Boss",
}) do
	local marker = mapArea:FindFirstChild(markerName)
	if marker then
		marker:Destroy()
	end
end

local markersFolder = Instance.new("Folder")
markersFolder.Name = "Markers"
markersFolder.Parent = mapArea

local markerByInstance: { [Instance]: MarkerVisual } = {}
local elapsedSinceUpdate = 0
local focusPosition: Vector3? = nil

-- La minimap reste orientee nord. Le joueur pivote au centre, mais ni la carte
-- ni les reperes ne tournent avec lui : c'est la convention la plus lisible ici.
local centralTargetRadiusRatio = 0.46

local function getInstancePosition(instance: Instance): Vector3?
	if instance:IsA("BasePart") then
		return instance.Position
	end

	if instance:IsA("Model") then
		return instance:GetPivot().Position
	end

	return nil
end

local function getMarkerStyle(runtimeFolderName: string, instance: Instance): Color3?
	if runtimeFolderName == "PortalsRuntime" then
		return MiniMapConfig.Colors.Portal
	end

	if runtimeFolderName == "ShrinesRuntime" then
		if instance:GetAttribute("ShrineActive") ~= true then
			return nil
		end

		local shrineType = instance:GetAttribute("ShrineType")

		if shrineType == "Magnet" then
			return MiniMapConfig.Colors.MagnetShrine
		end

		if shrineType == "EliteChallenge" then
			return MiniMapConfig.Colors.EliteShrine
		end

		return MiniMapConfig.Colors.PerkShrine
	end

	if runtimeFolderName == "ChestsRuntime" then
		return if instance:GetAttribute("ChestOpened") == true then nil else MiniMapConfig.Colors.Chest
	end

	if runtimeFolderName == "JarsRuntime" then
		return if instance:GetAttribute("JarBroken") == true then nil else MiniMapConfig.Colors.Jar
	end

	if runtimeFolderName == "TotemsRuntime" then
		return if instance:GetAttribute("TotemActivated") == true then nil else MiniMapConfig.Colors.Totem
	end

	return nil
end

local function createMarkerVisual(name: string, color: Color3, size: number, rotation: number): MarkerVisual
	local glow = Instance.new("Frame")
	glow.Name = name .. "Glow"
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Size = UDim2.fromOffset(size + 8, size + 8)
	glow.BackgroundColor3 = color
	glow.BackgroundTransparency = 0.84
	glow.BorderSizePixel = 0
	glow.Rotation = rotation
	glow.ZIndex = 16
	glow.Parent = markersFolder
	addCorner(glow, 999)

	local core = Instance.new("Frame")
	core.Name = name
	core.AnchorPoint = Vector2.new(0.5, 0.5)
	core.Size = UDim2.fromOffset(size, size)
	core.BackgroundColor3 = color
	core.BorderSizePixel = 0
	core.Rotation = rotation
	core.ZIndex = 17
	core.Parent = markersFolder
	addCorner(core, if rotation ~= 0 then 2 else 999)
	addStroke(core, Color3.fromRGB(245, 246, 255), 0.2, 1)

	return {
		Core = core,
		Glow = glow,
	}
end

local function setVisualVisible(visual: MarkerVisual, isVisible: boolean)
	visual.Core.Visible = isVisible
	visual.Glow.Visible = isVisible
end

local cardinalDirections = {
	N = Vector3.new(0, 0, -1),
	E = Vector3.new(1, 0, 0),
	S = Vector3.new(0, 0, 1),
	W = Vector3.new(-1, 0, 0),
}

local function updateCardinals()
	for labelName, worldDirection in pairs(cardinalDirections) do
		local label = mapArea:FindFirstChild(labelName)

		if label and label:IsA("TextLabel") then
			label.Visible = focusPosition ~= nil
			label.AnchorPoint = Vector2.new(0.5, 0.5)
			label.Position = UDim2.fromScale(
				0.5 + (worldDirection.X * 0.44),
				0.5 + (worldDirection.Z * 0.44)
			)
		end
	end
end

local function setMarkerPosition(visual: MarkerVisual, position: Vector3, isPlayer: boolean)
	if focusPosition == nil then
		setVisualVisible(visual, false)
		return
	end

	local x = 0.5
	local y = 0.5

	if not isPlayer then
		local deltaX = position.X - focusPosition.X
		local deltaZ = position.Z - focusPosition.Z
		local visibleRadius = math.max(1, MiniMapConfig.VisibleRadius)
		local targetRadius = visibleRadius * centralTargetRadiusRatio

		-- Les anneaux restent un repere de lecture. Seul le disque central affiche
		-- les cibles proches ; aucune icone n'est rabattue sur les anneaux externes.
		if (deltaX * deltaX) + (deltaZ * deltaZ) > targetRadius * targetRadius then
			setVisualVisible(visual, false)
			return
		end

		x += deltaX / (visibleRadius * 2)
		y += deltaZ / (visibleRadius * 2)
	end

	local horizontalPadding = math.min(0.44, MiniMapConfig.MarkerPadding / math.max(1, mapArea.AbsoluteSize.X))
	local verticalPadding = math.min(0.44, MiniMapConfig.MarkerPadding / math.max(1, mapArea.AbsoluteSize.Y))
	local markerPosition = UDim2.new(
		math.clamp(x, horizontalPadding, 1 - horizontalPadding),
		0,
		math.clamp(y, verticalPadding, 1 - verticalPadding),
		0
	)

	visual.Core.Position = markerPosition
	visual.Glow.Position = markerPosition
	setVisualVisible(visual, true)
end

local playerMarker = createMarkerVisual("Player", MiniMapConfig.Colors.Player, MiniMapConfig.PlayerMarkerSize, 45)
playerMarker.Core.BackgroundTransparency = 1

local playerStroke = playerMarker.Core:FindFirstChildOfClass("UIStroke")
if playerStroke then
	playerStroke:Destroy()
end

local playerPointer = Instance.new("TextLabel")
playerPointer.Name = "DirectionPointer"
playerPointer.AnchorPoint = Vector2.new(0.5, 0.5)
playerPointer.Position = UDim2.fromScale(0.5, 0.5)
playerPointer.Size = UDim2.fromOffset(MiniMapConfig.PlayerMarkerSize + 8, MiniMapConfig.PlayerMarkerSize + 8)
playerPointer.BackgroundTransparency = 1
playerPointer.Font = Enum.Font.GothamBlack
playerPointer.Text = utf8.char(0x25B2)
playerPointer.TextColor3 = MiniMapConfig.Colors.Player
playerPointer.TextStrokeColor3 = Color3.fromRGB(245, 246, 255)
playerPointer.TextStrokeTransparency = 0.32
playerPointer.TextSize = MiniMapConfig.PlayerMarkerSize + 8
playerPointer.ZIndex = playerMarker.Core.ZIndex + 1
playerPointer.Parent = playerMarker.Core

local function updatePlayerMarker()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")

	if root == nil or not root:IsA("BasePart") then
		focusPosition = nil
		setVisualVisible(playerMarker, false)
		updateCardinals()
		return
	end

	local rawForward = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)

	if rawForward.Magnitude < 0.001 then
		focusPosition = nil
		setVisualVisible(playerMarker, false)
		updateCardinals()
		return
	end

	focusPosition = root.Position
	playerMarker.Core.Rotation = 0
	playerPointer.Rotation = math.deg(math.atan2(rawForward.X, -rawForward.Z))
	setMarkerPosition(playerMarker, root.Position, true)
	updateCardinals()
end

local function createMarker(instance: Instance, color: Color3): MarkerVisual
	local visual = createMarkerVisual("Marker", color, MiniMapConfig.MarkerSize, 0)
	markerByInstance[instance] = visual
	return visual
end

local function updateInteractableMarkers()
	local activeInstances: { [Instance]: boolean } = {}

	for _, runtimeFolderName in ipairs({ "PortalsRuntime", "ShrinesRuntime", "ChestsRuntime", "JarsRuntime", "TotemsRuntime" }) do
		local runtimeFolder = Workspace:FindFirstChild(runtimeFolderName)

		if runtimeFolder ~= nil then
			for _, instance in ipairs(runtimeFolder:GetChildren()) do
				local color = getMarkerStyle(runtimeFolderName, instance)
				local position = getInstancePosition(instance)

				if color ~= nil and position ~= nil then
					activeInstances[instance] = true
					local visual = markerByInstance[instance] or createMarker(instance, color)
					visual.Core.BackgroundColor3 = color
					visual.Glow.BackgroundColor3 = color
					setMarkerPosition(visual, position, false)
				end
			end
		end
	end

	for instance, visual in pairs(markerByInstance) do
		if not activeInstances[instance] then
			visual.Core:Destroy()
			visual.Glow:Destroy()
			markerByInstance[instance] = nil
		end
	end
end

local function refreshVisibility()
	panel.Visible = player:GetAttribute("IsRunActive") == true

	if not panel.Visible then
		focusPosition = nil
		setVisualVisible(playerMarker, false)
		updateCardinals()
	end
end

player:GetAttributeChangedSignal("IsRunActive"):Connect(refreshVisibility)

RunService.RenderStepped:Connect(function(deltaTime)
	if not panel.Visible then
		return
	end

	elapsedSinceUpdate += deltaTime

	if elapsedSinceUpdate < MiniMapConfig.UpdateInterval then
		return
	end

	elapsedSinceUpdate = 0
	updatePlayerMarker()
	updateInteractableMarkers()
end)

refreshVisibility()
