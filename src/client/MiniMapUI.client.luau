local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MiniMapConfig = require(Shared:WaitForChild("MiniMapConfig"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))

local existingGui = playerGui:FindFirstChild("MiniMapGui")

if existingGui ~= nil then
	existingGui:Destroy()
end

local function addCorner(instance, radius)
	return UiTheme.AddCorner(instance, radius)
end

local function addStroke(instance, color, transparency, thickness)
	return UiTheme.AddStroke(instance, color, transparency, thickness)
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MiniMapGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = false
screenGui.DisplayOrder = 7
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "MiniMapPanel"
panel.AnchorPoint = Vector2.new(1, 0)
panel.Position = UDim2.new(1, -MiniMapConfig.PanelOffset.X, 0, MiniMapConfig.PanelOffset.Y)
panel.Size = UDim2.fromOffset(MiniMapConfig.PanelSize.X, MiniMapConfig.PanelSize.Y)
panel.BackgroundColor3 = UiTheme.Colors.MetalDark
panel.BackgroundTransparency = 0.24
panel.BorderSizePixel = 0
panel.ClipsDescendants = true
panel.Visible = player:GetAttribute("IsRunActive") == true
panel.Parent = screenGui
addCorner(panel, 7)
addStroke(panel, Color3.fromRGB(7, 12, 19), 0.1, 3)
addStroke(panel, UiTheme.Colors.GlassTint, 0.48, 1)
UiTheme.AddSurfaceFinish(panel, {
	Accent = UiTheme.Colors.Accent,
	Intensity = 0.3,
})

local panelScale = Instance.new("UIScale")
panelScale.Name = "ResponsiveScale"
panelScale.Parent = panel

local header = Instance.new("TextLabel")
header.Name = "Header"
header.Position = UDim2.fromOffset(10, 6)
header.Size = UDim2.new(1, -20, 0, 17)
header.BackgroundTransparency = 1
header.Font = UiTheme.Fonts.Bold
header.Text = "REPERES"
header.TextColor3 = UiTheme.Colors.Text
header.TextSize = 11
header.TextStrokeColor3 = UiTheme.Colors.Shadow
header.TextStrokeTransparency = 0.55
header.TextXAlignment = Enum.TextXAlignment.Left
header.Parent = panel

local divider = Instance.new("Frame")
divider.Name = "Divider"
divider.Position = UDim2.fromOffset(10, 25)
divider.Size = UDim2.new(1, -20, 0, 1)
divider.BackgroundColor3 = UiTheme.Colors.GlassTint
divider.BackgroundTransparency = 0.58
divider.BorderSizePixel = 0
divider.Parent = panel

local mapArea = Instance.new("Frame")
mapArea.Name = "MapArea"
mapArea.Position = UDim2.fromOffset(9, 34)
mapArea.Size = UDim2.new(1, -18, 1, -43)
mapArea.BackgroundColor3 = Color3.fromRGB(6, 13, 22)
mapArea.BackgroundTransparency = 0.28
mapArea.BorderSizePixel = 0
mapArea.ClipsDescendants = true
mapArea.Parent = panel
addCorner(mapArea, 5)
addStroke(mapArea, UiTheme.Colors.GlassStroke, 0.78, 1)

local mapAspect = Instance.new("UIAspectRatioConstraint")
mapAspect.AspectRatio = 1
mapAspect.DominantAxis = Enum.DominantAxis.Height
mapAspect.Parent = mapArea

local radarTint = Instance.new("Frame")
radarTint.Name = "RadarTint"
radarTint.Size = UDim2.fromScale(1, 1)
radarTint.BackgroundColor3 = Color3.fromRGB(31, 81, 100)
radarTint.BackgroundTransparency = 0.9
radarTint.BorderSizePixel = 0
radarTint.ZIndex = 1
radarTint.Parent = mapArea

for index = 1, MiniMapConfig.GridLineCount - 1 do
	local ratio = index / MiniMapConfig.GridLineCount

	local verticalLine = Instance.new("Frame")
	verticalLine.Name = "VerticalGrid"
	verticalLine.AnchorPoint = Vector2.new(0.5, 0)
	verticalLine.Position = UDim2.fromScale(ratio, 0)
	verticalLine.Size = UDim2.new(0, 1, 1, 0)
	verticalLine.BackgroundColor3 = UiTheme.Colors.Accent
	verticalLine.BackgroundTransparency = 0.9
	verticalLine.BorderSizePixel = 0
	verticalLine.ZIndex = 2
	verticalLine.Parent = mapArea

	local horizontalLine = Instance.new("Frame")
	horizontalLine.Name = "HorizontalGrid"
	horizontalLine.AnchorPoint = Vector2.new(0, 0.5)
	horizontalLine.Position = UDim2.fromScale(0, ratio)
	horizontalLine.Size = UDim2.new(1, 0, 0, 1)
	horizontalLine.BackgroundColor3 = UiTheme.Colors.Accent
	horizontalLine.BackgroundTransparency = 0.9
	horizontalLine.BorderSizePixel = 0
	horizontalLine.ZIndex = 2
	horizontalLine.Parent = mapArea
end

for _, scale in ipairs({ 0.5, 0.82 }) do
	local rangeRing = Instance.new("Frame")
	rangeRing.Name = "RangeRing"
	rangeRing.AnchorPoint = Vector2.new(0.5, 0.5)
	rangeRing.Position = UDim2.fromScale(0.5, 0.5)
	rangeRing.Size = UDim2.fromScale(scale, scale)
	rangeRing.BackgroundTransparency = 1
	rangeRing.BorderSizePixel = 0
	rangeRing.ZIndex = 2
	rangeRing.Parent = mapArea
	addCorner(rangeRing, 999)
	addStroke(rangeRing, UiTheme.Colors.Accent, 0.85, 1)
end

local centerCrossHorizontal = Instance.new("Frame")
centerCrossHorizontal.Name = "CenterCrossHorizontal"
centerCrossHorizontal.AnchorPoint = Vector2.new(0.5, 0.5)
centerCrossHorizontal.Position = UDim2.fromScale(0.5, 0.5)
centerCrossHorizontal.Size = UDim2.fromOffset(18, 1)
centerCrossHorizontal.BackgroundColor3 = UiTheme.Colors.Accent
centerCrossHorizontal.BackgroundTransparency = 0.72
centerCrossHorizontal.BorderSizePixel = 0
centerCrossHorizontal.ZIndex = 3
centerCrossHorizontal.Parent = mapArea

local centerCrossVertical = centerCrossHorizontal:Clone()
centerCrossVertical.Name = "CenterCrossVertical"
centerCrossVertical.Size = UDim2.fromOffset(1, 18)
centerCrossVertical.Parent = mapArea

local markersFolder = Instance.new("Folder")
markersFolder.Name = "Markers"
markersFolder.Parent = mapArea

local markerByInstance = {}
local elapsedSinceUpdate = 0
local focusPosition = nil

local function getInstancePosition(instance)
	if instance:IsA("BasePart") then
		return instance.Position
	end

	if instance:IsA("Model") then
		return instance:GetPivot().Position
	end

	return nil
end

local function getMarkerStyle(runtimeFolderName, instance)
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

local function createMarker(instance)
	local marker = Instance.new("Frame")
	marker.Name = "Marker"
	marker.AnchorPoint = Vector2.new(0.5, 0.5)
	marker.Size = UDim2.fromOffset(MiniMapConfig.MarkerSize, MiniMapConfig.MarkerSize)
	marker.BackgroundColor3 = UiTheme.Colors.Text
	marker.BorderSizePixel = 0
	marker.ZIndex = 4
	marker.Parent = markersFolder
	addCorner(marker, MiniMapConfig.MarkerSize)
	addStroke(marker, Color3.new(1, 1, 1), 0.26, 1)

	markerByInstance[instance] = marker
	return marker
end

local playerMarker = Instance.new("Frame")
playerMarker.Name = "PlayerMarker"
playerMarker.AnchorPoint = Vector2.new(0.5, 0.5)
playerMarker.Size = UDim2.fromOffset(MiniMapConfig.PlayerMarkerSize, MiniMapConfig.PlayerMarkerSize)
playerMarker.BackgroundColor3 = MiniMapConfig.Colors.Player
playerMarker.BorderSizePixel = 0
playerMarker.Rotation = 45
playerMarker.ZIndex = 5
playerMarker.Parent = mapArea
addCorner(playerMarker, 2)
addStroke(playerMarker, UiTheme.Colors.Accent, 0.08, 2)

local function setMarkerPosition(marker, position, isPlayer)
	if focusPosition == nil then
		marker.Visible = false
		return
	end

	local x = 0.5
	local y = 0.5

	if not isPlayer then
		local deltaX = position.X - focusPosition.X
		local deltaZ = position.Z - focusPosition.Z
		local visibleRadius = math.max(1, MiniMapConfig.VisibleRadius)

		if (deltaX * deltaX) + (deltaZ * deltaZ) > visibleRadius * visibleRadius then
			marker.Visible = false
			return
		end

		x += deltaX / (visibleRadius * 2)
		y += deltaZ / (visibleRadius * 2)
	end

	-- Au premier frame, Roblox peut ne pas avoir calcule AbsoluteSize.
	local horizontalPadding = math.min(0.45, MiniMapConfig.MarkerPadding / math.max(1, mapArea.AbsoluteSize.X))
	local verticalPadding = math.min(0.45, MiniMapConfig.MarkerPadding / math.max(1, mapArea.AbsoluteSize.Y))

	marker.Position = UDim2.new(
		math.clamp(x, horizontalPadding, 1 - horizontalPadding),
		0,
		math.clamp(y, verticalPadding, 1 - verticalPadding),
		0
	)
	marker.Visible = true
end

local function updatePlayerMarker()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")

	if root == nil or not root:IsA("BasePart") then
		focusPosition = nil
		playerMarker.Visible = false
		return
	end

	focusPosition = root.Position
	setMarkerPosition(playerMarker, root.Position, true)
end

local function updateInteractableMarkers()
	local activeInstances = {}

	for _, runtimeFolderName in ipairs({ "PortalsRuntime", "ShrinesRuntime", "ChestsRuntime", "JarsRuntime", "TotemsRuntime" }) do
		local runtimeFolder = Workspace:FindFirstChild(runtimeFolderName)

		if runtimeFolder ~= nil then
			for _, instance in ipairs(runtimeFolder:GetChildren()) do
				local color = getMarkerStyle(runtimeFolderName, instance)
				local position = getInstancePosition(instance)

				if color ~= nil and position ~= nil then
					activeInstances[instance] = true
					local marker = markerByInstance[instance] or createMarker(instance)
					marker.BackgroundColor3 = color
					setMarkerPosition(marker, position, false)
				end
			end
		end
	end

	for instance, marker in pairs(markerByInstance) do
		if not activeInstances[instance] then
			marker:Destroy()
			markerByInstance[instance] = nil
		end
	end
end

local function refreshScale()
	local camera = Workspace.CurrentCamera

	if camera == nil then
		return
	end

	local viewportSize = camera.ViewportSize
	local scale = math.min(viewportSize.X / 1440, viewportSize.Y / 900)
	panelScale.Scale = math.clamp(scale, MiniMapConfig.MinimumScale, MiniMapConfig.MaximumScale)
end

local function refreshVisibility()
	panel.Visible = player:GetAttribute("IsRunActive") == true

	if not panel.Visible then
		focusPosition = nil
		playerMarker.Visible = false
	end
end

player:GetAttributeChangedSignal("IsRunActive"):Connect(refreshVisibility)

RunService.RenderStepped:Connect(function(deltaTime)
	refreshScale()

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
refreshScale()
