local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local RunLoadingConfig = require(Shared:WaitForChild("RunLoadingConfig"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))

local existingGui = playerGui:FindFirstChild(RunLoadingConfig.GuiName)

if existingGui ~= nil then
	existingGui:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = RunLoadingConfig.GuiName
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 120
screenGui.Enabled = false
screenGui.Parent = playerGui

local overlay = Instance.new("Frame")
overlay.Name = "Overlay"
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = Color3.fromRGB(7, 12, 19)
overlay.BackgroundTransparency = 0.08
overlay.BorderSizePixel = 0
overlay.Parent = screenGui

local panel = Instance.new("Frame")
panel.Name = "LoadingPanel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(520, 190)
panel.BackgroundColor3 = Color3.fromRGB(17, 27, 39)
panel.BackgroundTransparency = 0.12
panel.BorderSizePixel = 0
panel.Parent = overlay
UiTheme.AddCorner(panel, 10)
UiTheme.AddStroke(panel, Color3.fromRGB(6, 10, 17), 0.1, 3)
UiTheme.AddStroke(panel, Color3.fromRGB(122, 214, 255), 0.42, 1)
UiTheme.AddGradient(panel, Color3.fromRGB(47, 64, 86), Color3.fromRGB(12, 20, 31), 90)
UiTheme.AddSurfaceFinish(panel, {
	Accent = Color3.fromRGB(122, 214, 255),
	Intensity = 0.55,
})

local panelConstraint = Instance.new("UISizeConstraint")
panelConstraint.MinSize = Vector2.new(300, 160)
panelConstraint.MaxSize = Vector2.new(620, 210)
panelConstraint.Parent = panel

local diamond = Instance.new("Frame")
diamond.Name = "ArcaneDiamond"
diamond.AnchorPoint = Vector2.new(0.5, 0)
diamond.Position = UDim2.new(0.5, 0, 0, 23)
diamond.Size = UDim2.fromOffset(24, 24)
diamond.BackgroundColor3 = Color3.fromRGB(148, 91, 255)
diamond.BorderSizePixel = 0
diamond.Rotation = 45
diamond.Parent = panel
UiTheme.AddCorner(diamond, 3)
UiTheme.AddStroke(diamond, Color3.fromRGB(221, 209, 255), 0.18, 2)

local title = Instance.new("TextLabel")
title.Name = "Title"
title.AnchorPoint = Vector2.new(0.5, 0)
title.Position = UDim2.new(0.5, 0, 0, 58)
title.Size = UDim2.new(1, -48, 0, 28)
title.BackgroundTransparency = 1
title.Font = UiTheme.Fonts.Heavy
title.Text = "PREPARATION DE LA RUN"
title.TextColor3 = Color3.fromRGB(245, 246, 250)
title.TextSize = 21
title.TextStrokeColor3 = Color3.fromRGB(5, 8, 12)
title.TextStrokeTransparency = 0.35
title.TextXAlignment = Enum.TextXAlignment.Center
title.Parent = panel

local message = Instance.new("TextLabel")
message.Name = "Message"
message.AnchorPoint = Vector2.new(0.5, 0)
message.Position = UDim2.new(0.5, 0, 0, 94)
message.Size = UDim2.new(1, -64, 0, 22)
message.BackgroundTransparency = 1
message.Font = UiTheme.Fonts.Bold
message.Text = "Preparation de la run"
message.TextColor3 = Color3.fromRGB(183, 211, 235)
message.TextSize = 15
message.TextXAlignment = Enum.TextXAlignment.Center
message.Parent = panel

local detail = Instance.new("TextLabel")
detail.Name = "Detail"
detail.AnchorPoint = Vector2.new(0.5, 0)
detail.Position = UDim2.new(0.5, 0, 0, 116)
detail.Size = UDim2.new(1, -64, 0, 16)
detail.BackgroundTransparency = 1
detail.Font = UiTheme.Fonts.Regular
detail.Text = ""
detail.TextColor3 = Color3.fromRGB(133, 158, 182)
detail.TextSize = 12
detail.TextXAlignment = Enum.TextXAlignment.Center
detail.Parent = panel

local track = Instance.new("Frame")
track.Name = "ProgressTrack"
track.AnchorPoint = Vector2.new(0.5, 0)
track.Position = UDim2.new(0.5, 0, 0, 147)
track.Size = UDim2.new(1, -84, 0, 12)
track.BackgroundColor3 = Color3.fromRGB(7, 13, 22)
track.BorderSizePixel = 0
track.ClipsDescendants = true
track.Parent = panel
UiTheme.AddCorner(track, 6)
UiTheme.AddStroke(track, Color3.fromRGB(113, 137, 170), 0.6, 1)

local fill = Instance.new("Frame")
fill.Name = "ProgressFill"
fill.Size = UDim2.fromScale(0, 1)
fill.BackgroundColor3 = Color3.fromRGB(115, 79, 255)
fill.BorderSizePixel = 0
fill.Parent = track
UiTheme.AddCorner(fill, 6)
UiTheme.AddGradient(fill, Color3.fromRGB(92, 206, 255), Color3.fromRGB(152, 77, 255), 0)

local percent = Instance.new("TextLabel")
percent.Name = "Percent"
percent.AnchorPoint = Vector2.new(0.5, 0)
percent.Position = UDim2.new(0.5, 0, 0, 166)
percent.Size = UDim2.new(1, -84, 0, 16)
percent.BackgroundTransparency = 1
percent.Font = UiTheme.Fonts.Bold
percent.Text = "0%"
percent.TextColor3 = Color3.fromRGB(213, 197, 255)
percent.TextSize = 12
percent.TextXAlignment = Enum.TextXAlignment.Center
percent.Parent = panel

local panelScale = Instance.new("UIScale")
panelScale.Parent = panel

local function updateScale()
	local camera = workspace.CurrentCamera

	if camera == nil then
		return
	end

	local viewport = camera.ViewportSize
	panelScale.Scale = math.clamp(math.min(viewport.X / 760, viewport.Y / 420), 0.72, 1)
end

local function applyPayload(payload)
	payload = payload or {}

	if payload.Visible ~= true then
		screenGui.Enabled = false
		return
	end

	screenGui.Enabled = true
	message.Text = tostring(payload.Message or "Preparation de la run")
	detail.Text = tostring(payload.Detail or "")
	local progress = math.clamp(tonumber(payload.Progress) or 0, 0, 1)
	percent.Text = tostring(math.floor((progress * 100) + 0.5)) .. "%"
	TweenService:Create(fill, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromScale(progress, 1),
	}):Play()
end

local loadingRemote = ReplicatedStorage:WaitForChild(RunLoadingConfig.RemoteName)
loadingRemote.OnClientEvent:Connect(applyPayload)

player:GetAttributeChangedSignal(RunLoadingConfig.AttributeName):Connect(function()
	if player:GetAttribute(RunLoadingConfig.AttributeName) == true then
		applyPayload({
			Visible = true,
			Stage = "Preparing",
			Progress = RunLoadingConfig.Stages.Preparing.Progress,
			Message = RunLoadingConfig.Stages.Preparing.Message,
		})
	else
		applyPayload({ Visible = false })
	end
end)

if workspace.CurrentCamera ~= nil then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end

updateScale()

if player:GetAttribute(RunLoadingConfig.AttributeName) == true then
	applyPayload({
		Visible = true,
		Progress = RunLoadingConfig.Stages.Preparing.Progress,
		Message = RunLoadingConfig.Stages.Preparing.Message,
	})
end
