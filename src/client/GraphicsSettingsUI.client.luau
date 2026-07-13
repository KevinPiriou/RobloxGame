local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GraphicsConfig = require(Shared:WaitForChild("GraphicsConfig"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local GraphicsController = require(script.Parent:WaitForChild("GraphicsController"))

GraphicsController.Start()

local existingGui = playerGui:FindFirstChild("GraphicsSettingsGui")

if existingGui ~= nil then
	existingGui:Destroy()
end

local COLORS = UiTheme.Contexts.Audio
local addCorner = UiTheme.AddCorner
local addStroke = UiTheme.AddStroke

local function addGradient(instance, firstColor, secondColor)
	return UiTheme.AddGradient(instance, firstColor, secondColor, 90)
end

local function createLabel(parent, name, text, size, color, font)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Font = font or Enum.Font.GothamBold
	label.Text = text
	label.TextColor3 = color
	label.TextSize = size
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0.55
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = parent
	return label
end

local function getSettingsPanelEvent()
	local event = playerGui:FindFirstChild("SettingsPanelChanged")

	if event == nil then
		event = Instance.new("BindableEvent")
		event.Name = "SettingsPanelChanged"
		event.Parent = playerGui
	end

	assert(event:IsA("BindableEvent"), "SettingsPanelChanged doit etre un BindableEvent.")
	return event
end

local settingsPanelEvent = getSettingsPanelEvent()

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "GraphicsSettingsGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = false
screenGui.DisplayOrder = 10
screenGui.Parent = playerGui

local graphicsButton = Instance.new("TextButton")
graphicsButton.Name = "GraphicsButton"
graphicsButton.AnchorPoint = Vector2.new(1, 0)
graphicsButton.Position = UDim2.new(1, -166, 0, 16)
graphicsButton.Size = UDim2.fromOffset(66, 34)
graphicsButton.BackgroundColor3 = Color3.fromRGB(37, 51, 70)
graphicsButton.BackgroundTransparency = 0.16
graphicsButton.BorderSizePixel = 0
graphicsButton.AutoButtonColor = false
graphicsButton.Font = Enum.Font.GothamBlack
graphicsButton.Text = "VIDEO"
graphicsButton.TextColor3 = COLORS.Text
graphicsButton.TextSize = 10
graphicsButton.Parent = screenGui
addCorner(graphicsButton, 8)
addStroke(graphicsButton, COLORS.MetalLight, 0.28, 1)
addGradient(graphicsButton, Color3.fromRGB(65, 88, 118), COLORS.MetalDark)
UiTheme.AddSurfaceFinish(graphicsButton, {
	Accent = Color3.fromRGB(167, 123, 255),
	Intensity = 0.4,
})

local panel = Instance.new("Frame")
panel.Name = "GraphicsPanel"
panel.AnchorPoint = Vector2.new(1, 0)
panel.Position = UDim2.new(1, -18, 0, 58)
panel.Size = UDim2.fromOffset(350, 290)
panel.BackgroundColor3 = Color3.fromRGB(37, 51, 70)
panel.BackgroundTransparency = 0.16
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = screenGui
addCorner(panel, 10)
addStroke(panel, COLORS.MetalLight, 0.24, 2)
addGradient(panel, Color3.fromRGB(65, 88, 118), COLORS.MetalDark)
UiTheme.AddSurfaceFinish(panel, {
	Accent = Color3.fromRGB(167, 123, 255),
	Intensity = 0.6,
})

local panelConstraint = Instance.new("UISizeConstraint")
panelConstraint.MinSize = Vector2.new(290, 252)
panelConstraint.MaxSize = Vector2.new(350, 290)
panelConstraint.Parent = panel

local inner = Instance.new("Frame")
inner.Name = "GlassInner"
inner.Position = UDim2.fromOffset(4, 4)
inner.Size = UDim2.new(1, -8, 1, -8)
inner.BackgroundColor3 = Color3.fromRGB(13, 22, 34)
inner.BackgroundTransparency = 0.2
inner.BorderSizePixel = 0
inner.Parent = panel
addCorner(inner, 7)
addStroke(inner, COLORS.GlassStroke, 0.68, 1)

local title = createLabel(inner, "Title", "VIDEO", 17, COLORS.Text, Enum.Font.GothamBlack)
title.Position = UDim2.fromOffset(16, 10)
title.Size = UDim2.new(1, -120, 0, 24)

local resetButton = Instance.new("TextButton")
resetButton.Name = "ResetButton"
resetButton.AnchorPoint = Vector2.new(1, 0)
resetButton.Position = UDim2.new(1, -14, 0, 10)
resetButton.Size = UDim2.fromOffset(80, 24)
resetButton.BackgroundColor3 = Color3.fromRGB(32, 48, 66)
resetButton.BackgroundTransparency = 0.12
resetButton.BorderSizePixel = 0
resetButton.AutoButtonColor = false
resetButton.Font = Enum.Font.GothamBold
resetButton.Text = "DEFAUT"
resetButton.TextColor3 = COLORS.Text
resetButton.TextSize = 10
resetButton.Parent = inner
addCorner(resetButton, 5)
addStroke(resetButton, COLORS.GlassStroke, 0.6, 1)

local divider = Instance.new("Frame")
divider.Position = UDim2.fromOffset(14, 42)
divider.Size = UDim2.new(1, -28, 0, 1)
divider.BackgroundColor3 = COLORS.GlassStroke
divider.BackgroundTransparency = 0.75
divider.BorderSizePixel = 0
divider.Parent = inner

local qualityLabel = createLabel(inner, "QualityLabel", "QUALITE", 11, COLORS.Muted, Enum.Font.GothamBold)
qualityLabel.Position = UDim2.fromOffset(16, 52)
qualityLabel.Size = UDim2.new(1, -32, 0, 16)

local qualityContainer = Instance.new("Frame")
qualityContainer.Name = "QualityContainer"
qualityContainer.Position = UDim2.fromOffset(16, 72)
qualityContainer.Size = UDim2.new(1, -32, 0, 45)
qualityContainer.BackgroundTransparency = 1
qualityContainer.BorderSizePixel = 0
qualityContainer.Parent = inner

local qualityLayout = Instance.new("UIListLayout")
qualityLayout.FillDirection = Enum.FillDirection.Horizontal
qualityLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
qualityLayout.VerticalAlignment = Enum.VerticalAlignment.Center
qualityLayout.SortOrder = Enum.SortOrder.LayoutOrder
qualityLayout.Padding = UDim.new(0, 5)
qualityLayout.Parent = qualityContainer

local qualityButtons = {}
local qualityOrder = { "Performance", "Balanced", "Quality" }

for index, qualityName in ipairs(qualityOrder) do
	local profile = GraphicsConfig.GetProfile(qualityName)
	local button = Instance.new("TextButton")
	button.Name = qualityName
	button.LayoutOrder = index
	button.Size = UDim2.new(1 / #qualityOrder, -4, 1, 0)
	button.BackgroundColor3 = Color3.fromRGB(18, 33, 48)
	button.BackgroundTransparency = 0.08
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Font = Enum.Font.GothamBold
	button.Text = profile.Label
	button.TextColor3 = COLORS.Muted
	button.TextSize = 10
	button.TextWrapped = true
	button.Parent = qualityContainer
	addCorner(button, 5)
	addStroke(button, COLORS.GlassStroke, 0.74, 1)
	qualityButtons[qualityName] = button

	button.Activated:Connect(function()
		GraphicsController.SetQuality(qualityName)
	end)
end

local function createSliderRow(parent, labelText, accent, yOffset)
	local row = Instance.new("Frame")
	row.Name = labelText .. "Row"
	row.Position = UDim2.fromOffset(16, yOffset)
	row.Size = UDim2.new(1, -32, 0, 42)
	row.BackgroundTransparency = 1
	row.BorderSizePixel = 0
	row.Parent = parent

	local label = createLabel(row, "Label", labelText, 11, COLORS.Muted, Enum.Font.GothamBold)
	label.Size = UDim2.new(0, 160, 0, 15)

	local value = createLabel(row, "Value", "100%", 11, accent, Enum.Font.GothamBlack)
	value.AnchorPoint = Vector2.new(1, 0)
	value.Position = UDim2.new(1, 0, 0, 0)
	value.Size = UDim2.fromOffset(52, 15)
	value.TextXAlignment = Enum.TextXAlignment.Right

	local track = Instance.new("TextButton")
	track.Name = "Track"
	track.Position = UDim2.fromOffset(0, 21)
	track.Size = UDim2.new(1, 0, 0, 10)
	track.BackgroundColor3 = COLORS.Track
	track.BackgroundTransparency = 0.04
	track.BorderSizePixel = 0
	track.AutoButtonColor = false
	track.Text = ""
	track.ClipsDescendants = true
	track.Parent = row
	addCorner(track, 5)
	addStroke(track, COLORS.GlassStroke, 0.76, 1)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = accent
	fill.BorderSizePixel = 0
	fill.Parent = track
	addCorner(fill, 5)

	return {
		Track = track,
		Fill = fill,
		Value = value,
	}
end

local effectsRow = createSliderRow(inner, "EFFETS", Color3.fromRGB(190, 116, 255), 128)

local shadowsRow = Instance.new("Frame")
shadowsRow.Name = "ShadowsRow"
shadowsRow.Position = UDim2.fromOffset(16, 182)
shadowsRow.Size = UDim2.new(1, -32, 0, 36)
shadowsRow.BackgroundTransparency = 1
shadowsRow.BorderSizePixel = 0
shadowsRow.Parent = inner

local shadowsLabel = createLabel(shadowsRow, "Label", "OMBRES", 11, COLORS.Muted, Enum.Font.GothamBold)
shadowsLabel.Size = UDim2.new(0.6, 0, 1, 0)

local shadowsToggle = Instance.new("TextButton")
shadowsToggle.Name = "ShadowsToggle"
shadowsToggle.AnchorPoint = Vector2.new(1, 0.5)
shadowsToggle.Position = UDim2.new(1, 0, 0.5, 0)
shadowsToggle.Size = UDim2.fromOffset(64, 26)
shadowsToggle.BackgroundColor3 = Color3.fromRGB(18, 33, 48)
shadowsToggle.BorderSizePixel = 0
shadowsToggle.AutoButtonColor = false
shadowsToggle.Text = ""
shadowsToggle.Parent = shadowsRow
addCorner(shadowsToggle, 13)
addStroke(shadowsToggle, COLORS.GlassStroke, 0.62, 1)

local toggleKnob = Instance.new("Frame")
toggleKnob.Name = "Knob"
toggleKnob.AnchorPoint = Vector2.new(0, 0.5)
toggleKnob.Position = UDim2.new(0, 3, 0.5, 0)
toggleKnob.Size = UDim2.fromOffset(20, 20)
toggleKnob.BackgroundColor3 = COLORS.Text
toggleKnob.BorderSizePixel = 0
toggleKnob.Parent = shadowsToggle
addCorner(toggleKnob, 10)

local summary = createLabel(inner, "Summary", "", 10, COLORS.Muted, Enum.Font.GothamMedium)
summary.Position = UDim2.fromOffset(16, 226)
summary.Size = UDim2.new(1, -32, 0, 20)
summary.TextXAlignment = Enum.TextXAlignment.Center

local activeSlider = nil

local function setEffectsFromPosition(positionX)
	local width = math.max(1, effectsRow.Track.AbsoluteSize.X)
	local value = math.clamp((positionX - effectsRow.Track.AbsolutePosition.X) / width, 0, 1)
	GraphicsController.SetEffectsIntensity(value)
end

effectsRow.Track.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		activeSlider = effectsRow
		setEffectsFromPosition(input.Position.X)
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if activeSlider == nil then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		setEffectsFromPosition(input.Position.X)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		activeSlider = nil
	end
end)

local function refresh(settings)
	for qualityName, button in pairs(qualityButtons) do
		local isSelected = settings.Quality == qualityName
		button.BackgroundColor3 = if isSelected then Color3.fromRGB(64, 50, 110) else Color3.fromRGB(18, 33, 48)
		button.TextColor3 = if isSelected then COLORS.Text else COLORS.Muted
	end

	local effects = math.clamp(settings.EffectsIntensity or 0, 0, 1)
	effectsRow.Fill.Size = UDim2.new(effects, 0, 1, 0)
	effectsRow.Value.Text = tostring(math.floor((effects * 100) + 0.5)) .. "%"

	local shadowsEnabled = settings.ShadowsEnabled == true
	shadowsToggle.BackgroundColor3 = if shadowsEnabled then Color3.fromRGB(66, 104, 83) else Color3.fromRGB(45, 53, 65)
	toggleKnob.Position = if shadowsEnabled
		then UDim2.new(1, -23, 0.5, 0)
		else UDim2.new(0, 3, 0.5, 0)
	toggleKnob.BackgroundColor3 = if shadowsEnabled then Color3.fromRGB(156, 255, 185) else COLORS.Muted

	local profile = GraphicsConfig.GetProfile(settings.Quality)
	summary.Text = ("Loot %d studs  |  VFX x%.2f"):format(
		profile.CollectibleCullMaxDistance,
		effects * profile.EffectsMultiplier
	)
end

graphicsButton.Activated:Connect(function()
	local nextVisible = not panel.Visible

	if nextVisible then
		settingsPanelEvent:Fire("Graphics")
	else
		settingsPanelEvent:Fire(nil)
	end

	panel.Visible = nextVisible
	TweenService:Create(graphicsButton, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = if panel.Visible then 0.02 else 0.16,
	}):Play()
end)

settingsPanelEvent.Event:Connect(function(openPanelName)
	if openPanelName == "Graphics" or not panel.Visible then
		return
	end

	panel.Visible = false
	TweenService:Create(graphicsButton, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.16,
	}):Play()
end)

shadowsToggle.Activated:Connect(function()
	local settings = GraphicsController.GetSettings()
	GraphicsController.SetShadowsEnabled(settings.ShadowsEnabled ~= true)
end)

resetButton.Activated:Connect(function()
	GraphicsController.Reset()
end)

GraphicsController.Changed.Event:Connect(refresh)
refresh(GraphicsController.GetSettings())
