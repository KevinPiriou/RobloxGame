local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DebugLog = require(Shared:WaitForChild("DebugLog"))
local FeatureFlags = require(Shared:WaitForChild("FeatureFlags"))

if not FeatureFlags.AdminToolsEnabled then
	DebugLog.Info("UI", "UI admin desactivee par FeatureFlags")
	return
end

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local resetPowerUpsRemote = ReplicatedStorage:WaitForChild("Admin_ResetPowerUps")
local spawnMonstersRemote = ReplicatedStorage:WaitForChild("Admin_SpawnMonsters")
local killMonstersRemote = ReplicatedStorage:WaitForChild("Admin_KillMonsters")
local adminMessageRemote = ReplicatedStorage:WaitForChild("Admin_ShowMessage")

local existingGui = playerGui:FindFirstChild("AdminGui")

if existingGui ~= nil then
	existingGui:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AdminGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = false
screenGui.DisplayOrder = 8
screenGui.Enabled = false
screenGui.Parent = playerGui

local function addCorner(instance, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
	return corner
end

local function addStroke(instance, color, transparency, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Transparency = transparency
	stroke.Thickness = thickness
	stroke.Parent = instance
	return stroke
end

local function addGradient(instance, firstColor, secondColor)
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, firstColor),
		ColorSequenceKeypoint.new(1, secondColor),
	})
	gradient.Parent = instance
	return gradient
end

local adminButton = Instance.new("TextButton")
adminButton.Name = "AdminButton"
adminButton.AnchorPoint = Vector2.new(1, 0)
adminButton.Position = UDim2.new(1, -92, 0, 16)
adminButton.Size = UDim2.fromOffset(66, 34)
adminButton.BackgroundColor3 = Color3.fromRGB(37, 51, 70)
adminButton.BackgroundTransparency = 0.16
adminButton.BorderSizePixel = 0
adminButton.AutoButtonColor = false
adminButton.Font = Enum.Font.GothamBlack
adminButton.Text = "ADMIN"
adminButton.TextColor3 = Color3.fromRGB(248, 250, 255)
adminButton.TextSize = 10
adminButton.Parent = screenGui
addCorner(adminButton, 8)
addStroke(adminButton, Color3.fromRGB(93, 125, 161), 0.28, 1)
addGradient(adminButton, Color3.fromRGB(65, 88, 118), Color3.fromRGB(13, 22, 34))

local container = Instance.new("Frame")
container.Name = "AdminPanel"
container.AnchorPoint = Vector2.new(1, 0)
container.Position = UDim2.new(1, -92, 0, 58)
container.Size = UDim2.fromOffset(310, 226)
container.BackgroundColor3 = Color3.fromRGB(37, 51, 70)
container.BackgroundTransparency = 0.16
container.BorderSizePixel = 0
container.Visible = false
container.Parent = screenGui
addCorner(container, 10)
addStroke(container, Color3.fromRGB(93, 125, 161), 0.24, 2)
addGradient(container, Color3.fromRGB(65, 88, 118), Color3.fromRGB(13, 22, 34))

local inner = Instance.new("Frame")
inner.Name = "GlassInner"
inner.Position = UDim2.fromOffset(4, 4)
inner.Size = UDim2.new(1, -8, 1, -8)
inner.BackgroundColor3 = Color3.fromRGB(13, 22, 34)
inner.BackgroundTransparency = 0.2
inner.BorderSizePixel = 0
inner.Parent = container
addCorner(inner, 7)
addStroke(inner, Color3.fromRGB(221, 240, 255), 0.68, 1)

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Position = UDim2.fromOffset(16, 10)
title.Size = UDim2.new(1, -32, 0, 24)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBlack
title.Text = "OUTILS ADMIN"
title.TextColor3 = Color3.fromRGB(248, 250, 255)
title.TextSize = 17
title.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
title.TextStrokeTransparency = 0.5
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = inner

local divider = Instance.new("Frame")
divider.Position = UDim2.fromOffset(14, 42)
divider.Size = UDim2.new(1, -28, 0, 1)
divider.BackgroundColor3 = Color3.fromRGB(221, 240, 255)
divider.BackgroundTransparency = 0.75
divider.BorderSizePixel = 0
divider.Parent = inner

local content = Instance.new("Frame")
content.Name = "Content"
content.Position = UDim2.fromOffset(14, 52)
content.Size = UDim2.new(1, -28, 1, -64)
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.Parent = inner

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 6)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = content

local defaultButtonTexts = {}

local function createButton(name, text, color, layoutOrder)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = UDim2.new(1, 0, 0, 30)
	button.BackgroundColor3 = color
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.Text = text
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextSize = 12
	button.LayoutOrder = layoutOrder
	button.Parent = content

	addCorner(button, 5)
	addStroke(button, Color3.fromRGB(221, 240, 255), 0.78, 1)

	defaultButtonTexts[button] = text

	return button
end

local resetButton = createButton("ResetPowerUpsButton", "Reinit bonus", Color3.fromRGB(92, 70, 145), 1)
local spawnButton = createButton("SpawnMonstersButton", "Spawn 100 ennemis", Color3.fromRGB(54, 105, 165), 2)
local killButton = createButton("KillMonstersButton", "Tuer tous les ennemis", Color3.fromRGB(155, 65, 65), 3)

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "StatusLabel"
statusLabel.Size = UDim2.new(1, 0, 0, 18)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.GothamMedium
statusLabel.Text = ""
statusLabel.TextColor3 = Color3.fromRGB(220, 225, 235)
statusLabel.TextSize = 11
statusLabel.TextTruncate = Enum.TextTruncate.AtEnd
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.LayoutOrder = 4
statusLabel.Parent = content

local activeButton = nil

local function updateVisibility()
	local canUseAdminTools = player:GetAttribute("CanUseAdminTools") == true
	screenGui.Enabled = canUseAdminTools

	if not canUseAdminTools then
		container.Visible = false
	end
end

local function resetActiveButton()
	if activeButton == nil then
		return
	end

	activeButton.Active = true
	activeButton.AutoButtonColor = true
	activeButton.Text = defaultButtonTexts[activeButton]
	activeButton = nil
end

local function fireAdminAction(button, remote, busyText)
	resetActiveButton()

	activeButton = button
	button.Active = false
	button.AutoButtonColor = false
	button.Text = busyText
	statusLabel.Text = "Demande envoyee"
	statusLabel.TextColor3 = Color3.fromRGB(220, 225, 235)
	DebugLog.Info("UI", "Action admin envoyee", {
		Action = button.Name,
	})
	remote:FireServer()
end

resetButton.Activated:Connect(function()
	fireAdminAction(resetButton, resetPowerUpsRemote, "Reset...")
end)

spawnButton.Activated:Connect(function()
	fireAdminAction(spawnButton, spawnMonstersRemote, "Spawn...")
end)

killButton.Activated:Connect(function()
	fireAdminAction(killButton, killMonstersRemote, "Suppression...")
end)

adminButton.Activated:Connect(function()
	container.Visible = not container.Visible
	adminButton.BackgroundTransparency = if container.Visible then 0.02 else 0.16
end)

adminMessageRemote.OnClientEvent:Connect(function(payload)
	resetActiveButton()
	DebugLog.Info("UI", "Retour action admin recu", payload)
	statusLabel.Text = payload.Message or "Action terminee"

	if payload.Success then
		statusLabel.TextColor3 = Color3.fromRGB(145, 235, 170)
	else
		statusLabel.TextColor3 = Color3.fromRGB(255, 145, 145)
	end
end)

player:GetAttributeChangedSignal("CanUseAdminTools"):Connect(updateVisibility)
updateVisibility()

DebugLog.Info("UI", "UI admin initialisee", {
	Player = player.Name,
	Visible = screenGui.Enabled,
})
