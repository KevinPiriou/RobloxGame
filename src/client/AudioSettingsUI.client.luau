local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local AudioController = require(script.Parent:WaitForChild("AudioController"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))

AudioController.Start()

local existingGui = playerGui:FindFirstChild("AudioSettingsGui")

if existingGui ~= nil then
	existingGui:Destroy()
end

local COLORS = UiTheme.Contexts.Audio

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

local SETTINGS = {
	{ Id = "Master", Label = "GENERAL", Color = Color3.fromRGB(242, 246, 255) },
	{ Id = "Music", Label = "MUSIQUE", Color = Color3.fromRGB(190, 116, 255) },
	{ Id = "Effects", Label = "EFFETS", Color = Color3.fromRGB(255, 190, 75) },
	{ Id = "Environment", Label = "AMBIANCE", Color = Color3.fromRGB(86, 214, 172) },
	{ Id = "Interface", Label = "INTERFACE", Color = Color3.fromRGB(102, 191, 255) },
}

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
	label.TextStrokeTransparency = 0.5
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = parent

	return label
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AudioSettingsGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = false
screenGui.DisplayOrder = 10
screenGui.Parent = playerGui

local audioButton = Instance.new("TextButton")
audioButton.Name = "AudioButton"
audioButton.AnchorPoint = Vector2.new(1, 0)
audioButton.Position = UDim2.new(1, -18, 0, 16)
audioButton.Size = UDim2.fromOffset(66, 34)
audioButton.BackgroundColor3 = Color3.fromRGB(37, 51, 70)
audioButton.BackgroundTransparency = 0.16
audioButton.BorderSizePixel = 0
audioButton.AutoButtonColor = false
audioButton.Font = Enum.Font.GothamBlack
audioButton.Text = "AUDIO"
audioButton.TextColor3 = COLORS.Text
audioButton.TextSize = 10
audioButton.Parent = screenGui
addCorner(audioButton, 8)
addStroke(audioButton, COLORS.MetalLight, 0.28, 1)
addGradient(audioButton, Color3.fromRGB(65, 88, 118), COLORS.MetalDark)
UiTheme.AddSurfaceFinish(audioButton, {
	Accent = COLORS.Accent,
	Intensity = 0.4,
})

local panel = Instance.new("Frame")
panel.Name = "AudioPanel"
panel.AnchorPoint = Vector2.new(1, 0)
panel.Position = UDim2.new(1, -18, 0, 58)
panel.Size = UDim2.fromOffset(310, 276)
panel.BackgroundColor3 = Color3.fromRGB(37, 51, 70)
panel.BackgroundTransparency = 0.16
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = screenGui
addCorner(panel, 10)
addStroke(panel, COLORS.MetalLight, 0.24, 2)
addGradient(panel, Color3.fromRGB(65, 88, 118), COLORS.MetalDark)
UiTheme.AddSurfaceFinish(panel, {
	Accent = COLORS.Accent,
	Intensity = 0.6,
})

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

local title = createLabel(inner, "Title", "AUDIO", 17, COLORS.Text, Enum.Font.GothamBlack)
title.Position = UDim2.fromOffset(16, 10)
title.Size = UDim2.new(1, -110, 0, 24)

local muteButton = Instance.new("TextButton")
muteButton.Name = "MuteButton"
muteButton.AnchorPoint = Vector2.new(1, 0)
muteButton.Position = UDim2.new(1, -14, 0, 10)
muteButton.Size = UDim2.fromOffset(72, 24)
muteButton.BackgroundColor3 = Color3.fromRGB(32, 48, 66)
muteButton.BackgroundTransparency = 0.12
muteButton.BorderSizePixel = 0
muteButton.AutoButtonColor = false
muteButton.Font = Enum.Font.GothamBold
muteButton.Text = "COUPER"
muteButton.TextColor3 = COLORS.Text
muteButton.TextSize = 10
muteButton.Parent = inner
addCorner(muteButton, 5)
addStroke(muteButton, COLORS.GlassStroke, 0.6, 1)

local divider = Instance.new("Frame")
divider.Position = UDim2.fromOffset(14, 42)
divider.Size = UDim2.new(1, -28, 0, 1)
divider.BackgroundColor3 = COLORS.GlassStroke
divider.BackgroundTransparency = 0.75
divider.BorderSizePixel = 0
divider.Parent = inner

local rowsById = {}
local activeRow = nil
local lastMasterVolume = 1

local function updateRow(row, settings)
	local value = math.clamp(settings[row.Id] or 0, 0, 1)
	row.Fill.Size = UDim2.new(value, 0, 1, 0)
	row.Value.Text = tostring(math.floor((value * 100) + 0.5)) .. "%"
end

local function refresh(settings)
	for _, row in pairs(rowsById) do
		updateRow(row, settings)
	end

	local masterVolume = settings.Master or 0
	muteButton.Text = if masterVolume <= 0 then "ACTIVER" else "COUPER"
	muteButton.TextColor3 = if masterVolume <= 0 then COLORS.Accent else COLORS.Text
end

local function setRowFromPosition(row, positionX)
	local width = math.max(1, row.Track.AbsoluteSize.X)
	local value = math.clamp((positionX - row.Track.AbsolutePosition.X) / width, 0, 1)
	AudioController.SetVolume(row.Id, value)
end

for index, setting in ipairs(SETTINGS) do
	local row = Instance.new("Frame")
	row.Name = setting.Id .. "Row"
	row.Position = UDim2.fromOffset(16, 50 + ((index - 1) * 42))
	row.Size = UDim2.new(1, -32, 0, 34)
	row.BackgroundTransparency = 1
	row.BorderSizePixel = 0
	row.Parent = inner

	local label = createLabel(row, "Label", setting.Label, 11, COLORS.Muted, Enum.Font.GothamBold)
	label.Size = UDim2.new(0, 104, 0, 15)

	local value = createLabel(row, "Value", "0%", 11, setting.Color, Enum.Font.GothamBlack)
	value.AnchorPoint = Vector2.new(1, 0)
	value.Position = UDim2.new(1, 0, 0, 0)
	value.Size = UDim2.fromOffset(42, 15)
	value.TextXAlignment = Enum.TextXAlignment.Right

	local track = Instance.new("TextButton")
	track.Name = "Track"
	track.Position = UDim2.fromOffset(0, 20)
	track.Size = UDim2.new(1, 0, 0, 9)
	track.BackgroundColor3 = COLORS.Track
	track.BackgroundTransparency = 0.04
	track.BorderSizePixel = 0
	track.AutoButtonColor = false
	track.Text = ""
	track.ClipsDescendants = true
	track.Parent = row
	addCorner(track, 4)
	addStroke(track, COLORS.GlassStroke, 0.76, 1)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = setting.Color
	fill.BorderSizePixel = 0
	fill.Parent = track
	addCorner(fill, 4)

	local rowReference = {
		Id = setting.Id,
		Track = track,
		Fill = fill,
		Value = value,
	}
	rowsById[setting.Id] = rowReference

	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			activeRow = rowReference
			setRowFromPosition(rowReference, input.Position.X)
		end
	end)
end

UserInputService.InputChanged:Connect(function(input)
	if activeRow == nil then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		setRowFromPosition(activeRow, input.Position.X)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		activeRow = nil
	end
end)

audioButton.Activated:Connect(function()
	local nextVisible = not panel.Visible

	if nextVisible then
		settingsPanelEvent:Fire("Audio")
	else
		settingsPanelEvent:Fire(nil)
	end

	panel.Visible = nextVisible
	TweenService:Create(audioButton, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = if panel.Visible then 0.02 else 0.16,
	}):Play()
end)

settingsPanelEvent.Event:Connect(function(openPanelName)
	if openPanelName == "Audio" or not panel.Visible then
		return
	end

	panel.Visible = false
	TweenService:Create(audioButton, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.16,
	}):Play()
end)

muteButton.Activated:Connect(function()
	local settings = AudioController.GetSettings()

	if (settings.Master or 0) > 0 then
		lastMasterVolume = settings.Master
		AudioController.SetVolume("Master", 0)
	else
		AudioController.SetVolume("Master", math.max(0.1, lastMasterVolume))
	end
end)

AudioController.Changed.Event:Connect(refresh)
refresh(AudioController.GetSettings())
