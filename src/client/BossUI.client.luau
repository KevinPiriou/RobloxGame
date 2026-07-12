local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BossConfig = require(Shared:WaitForChild("BossConfig"))

local existingGui = playerGui:FindFirstChild("BossGui")

if existingGui ~= nil then
	existingGui:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BossGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 125
screenGui.Parent = playerGui

local function addCorner(instance, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
end

local function addStroke(instance, color, transparency, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Transparency = transparency
	stroke.Thickness = thickness
	stroke.Parent = instance
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
	label.TextStrokeTransparency = 0.45
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = parent
	return label
end

local bossBar = Instance.new("Frame")
bossBar.Name = "BossHealthBar"
bossBar.AnchorPoint = Vector2.new(0.5, 0)
bossBar.Position = UDim2.new(0.5, 0, 0, 104)
bossBar.Size = UDim2.new(0.48, 0, 0, 58)
bossBar.BackgroundColor3 = Color3.fromRGB(12, 14, 21)
bossBar.BackgroundTransparency = 0.12
bossBar.BorderSizePixel = 0
bossBar.Visible = false
bossBar.Parent = screenGui
addCorner(bossBar, 8)
addStroke(bossBar, Color3.fromRGB(255, 105, 80), 0.2, 1)

local bossBarSize = Instance.new("UISizeConstraint")
bossBarSize.MinSize = Vector2.new(280, 52)
bossBarSize.MaxSize = Vector2.new(620, 58)
bossBarSize.Parent = bossBar

local bossName = createLabel(bossBar, "BossName", BossConfig.DisplayName, 15, Color3.fromRGB(255, 229, 213), Enum.Font.GothamBlack)
bossName.Position = UDim2.fromOffset(14, 6)
bossName.Size = UDim2.new(0.64, 0, 0, 18)
bossName.TextXAlignment = Enum.TextXAlignment.Left

local bossHealthText = createLabel(bossBar, "Health", "1000 / 1000", 14, Color3.fromRGB(255, 236, 230), Enum.Font.GothamBold)
bossHealthText.Position = UDim2.new(0.64, 0, 0, 6)
bossHealthText.Size = UDim2.new(0.36, -14, 0, 18)
bossHealthText.TextXAlignment = Enum.TextXAlignment.Right

local healthTrack = Instance.new("Frame")
healthTrack.Name = "Track"
healthTrack.Position = UDim2.fromOffset(14, 32)
healthTrack.Size = UDim2.new(1, -28, 0, 16)
healthTrack.BackgroundColor3 = Color3.fromRGB(45, 12, 16)
healthTrack.BackgroundTransparency = 0.08
healthTrack.BorderSizePixel = 0
healthTrack.ClipsDescendants = true
healthTrack.Parent = bossBar
addCorner(healthTrack, 5)

local healthFill = Instance.new("Frame")
healthFill.Name = "Fill"
healthFill.Size = UDim2.fromScale(1, 1)
healthFill.BackgroundColor3 = Color3.fromRGB(229, 63, 54)
healthFill.BorderSizePixel = 0
healthFill.Parent = healthTrack
addCorner(healthFill, 5)

local decisionOverlay = Instance.new("Frame")
decisionOverlay.Name = "DecisionOverlay"
decisionOverlay.Size = UDim2.fromScale(1, 1)
decisionOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
decisionOverlay.BackgroundTransparency = 0.45
decisionOverlay.BorderSizePixel = 0
decisionOverlay.Visible = false
decisionOverlay.ZIndex = 150
decisionOverlay.Parent = screenGui

local decisionCard = Instance.new("Frame")
decisionCard.Name = "DecisionCard"
decisionCard.AnchorPoint = Vector2.new(0.5, 0.5)
decisionCard.Position = UDim2.fromScale(0.5, 0.5)
decisionCard.Size = UDim2.new(0.42, 0, 0, 184)
decisionCard.BackgroundColor3 = Color3.fromRGB(13, 16, 24)
decisionCard.BackgroundTransparency = 0.04
decisionCard.BorderSizePixel = 0
decisionCard.ZIndex = 151
decisionCard.Parent = decisionOverlay
addCorner(decisionCard, 8)
addStroke(decisionCard, Color3.fromRGB(255, 200, 74), 0.18, 1)

local decisionSize = Instance.new("UISizeConstraint")
decisionSize.MinSize = Vector2.new(300, 184)
decisionSize.MaxSize = Vector2.new(520, 184)
decisionSize.Parent = decisionCard

local victoryTitle = createLabel(decisionCard, "Title", "NIVEAU VALIDE", 24, Color3.fromRGB(255, 225, 116), Enum.Font.GothamBlack)
victoryTitle.Position = UDim2.fromOffset(16, 20)
victoryTitle.Size = UDim2.new(1, -32, 0, 28)
victoryTitle.ZIndex = 152

local victoryDescription = createLabel(
	decisionCard,
	"Description",
	"Tu peux poursuivre la survie pour améliorer ton score ou quitter le niveau.",
	14,
	Color3.fromRGB(224, 229, 240),
	Enum.Font.Gotham
)
victoryDescription.Position = UDim2.fromOffset(22, 56)
victoryDescription.Size = UDim2.new(1, -44, 0, 42)
victoryDescription.TextWrapped = true
victoryDescription.ZIndex = 152

local function createDecisionButton(name, text, position, color)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Position = position
	button.Size = UDim2.new(0.5, -26, 0, 40)
	button.BackgroundColor3 = color
	button.BackgroundTransparency = 0.1
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.Text = text
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextSize = 14
	button.ZIndex = 152
	button.Parent = decisionCard
	addCorner(button, 5)
	addStroke(button, Color3.fromRGB(255, 255, 255), 0.65, 1)
	return button
end

local continueButton = createDecisionButton("Continue", "CONTINUER", UDim2.new(0, 16, 1, -56), Color3.fromRGB(38, 130, 75))
local exitButton = createDecisionButton("Exit", "QUITTER LE NIVEAU", UDim2.new(0.5, 10, 1, -56), Color3.fromRGB(135, 65, 60))

local decisionRemote = ReplicatedStorage:WaitForChild(BossConfig.DecisionRemoteName)

continueButton.Activated:Connect(function()
	decisionRemote:FireServer("Continue")
end)

exitButton.Activated:Connect(function()
	decisionRemote:FireServer("Exit")
end)

local function updateBossBar(payload)
	local currentHealth = math.max(0, tonumber(payload.CurrentHealth) or 0)
	local maxHealth = math.max(1, tonumber(payload.MaxHealth) or 1)

	bossName.Text = tostring(payload.Name or BossConfig.DisplayName)
	bossHealthText.Text = string.format("%d / %d", math.floor(currentHealth + 0.5), math.floor(maxHealth + 0.5))
	healthFill.Size = UDim2.fromScale(math.clamp(currentHealth / maxHealth, 0, 1), 1)
	bossBar.Visible = true
end

local bossRemote = ReplicatedStorage:WaitForChild(BossConfig.BossRemoteName)

bossRemote.OnClientEvent:Connect(function(payload)
	payload = payload or {}

	if payload.Action == "ShowBar" then
		updateBossBar(payload)
	elseif payload.Action == "Hide" then
		bossBar.Visible = false
	elseif payload.Action == "ShowDecision" then
		bossBar.Visible = false
		decisionOverlay.Visible = true
	elseif payload.Action == "HideDecision" then
		decisionOverlay.Visible = false
	end
end)
