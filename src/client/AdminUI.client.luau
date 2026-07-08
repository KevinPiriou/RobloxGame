local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FeatureFlags = require(Shared:WaitForChild("FeatureFlags"))

if not FeatureFlags.AdminToolsEnabled then
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
screenGui.DisplayOrder = 8
screenGui.Enabled = false
screenGui.Parent = playerGui

local container = Instance.new("Frame")
container.Name = "Container"
container.AnchorPoint = Vector2.new(1, 1)
container.Position = UDim2.new(1, -14, 1, -18)
container.Size = UDim2.new(0, 220, 0, 138)
container.BackgroundColor3 = Color3.fromRGB(22, 25, 31)
container.BackgroundTransparency = 0.16
container.BorderSizePixel = 0
container.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = container

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(255, 255, 255)
stroke.Transparency = 0.84
stroke.Thickness = 1
stroke.Parent = container

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 8)
padding.PaddingRight = UDim.new(0, 8)
padding.PaddingBottom = UDim.new(0, 8)
padding.PaddingLeft = UDim.new(0, 8)
padding.Parent = container

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 6)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = container

local defaultButtonTexts = {}

local function createButton(name, text, color, layoutOrder)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = UDim2.new(1, 0, 0, 28)
	button.BackgroundColor3 = color
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.Text = text
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextSize = 12
	button.LayoutOrder = layoutOrder
	button.Parent = container

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 6)
	buttonCorner.Parent = button

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
statusLabel.Parent = container

local activeButton = nil

local function updateVisibility()
	screenGui.Enabled = player:GetAttribute("CanUseAdminTools") == true
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

adminMessageRemote.OnClientEvent:Connect(function(payload)
	resetActiveButton()
	statusLabel.Text = payload.Message or "Action terminee"

	if payload.Success then
		statusLabel.TextColor3 = Color3.fromRGB(145, 235, 170)
	else
		statusLabel.TextColor3 = Color3.fromRGB(255, 145, 145)
	end
end)

player:GetAttributeChangedSignal("CanUseAdminTools"):Connect(updateVisibility)
updateVisibility()
