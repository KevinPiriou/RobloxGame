local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BossConfig = require(Shared:WaitForChild("BossConfig"))

local existingGui = playerGui:FindFirstChild("RunSummaryGui")

if existingGui ~= nil then
	existingGui:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "RunSummaryGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 180
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
	label.TextStrokeTransparency = 0.5
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = parent
	return label
end

local overlay = Instance.new("Frame")
overlay.Name = "Overlay"
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
overlay.BackgroundTransparency = 0.38
overlay.BorderSizePixel = 0
overlay.Visible = false
overlay.ZIndex = 200
overlay.Parent = screenGui

local card = Instance.new("Frame")
card.Name = "Card"
card.AnchorPoint = Vector2.new(0.5, 0.5)
card.Position = UDim2.fromScale(0.5, 0.5)
card.Size = UDim2.new(0.36, 0, 0, 360)
card.BackgroundColor3 = Color3.fromRGB(13, 16, 24)
card.BackgroundTransparency = 0.04
card.BorderSizePixel = 0
card.ZIndex = 201
card.Parent = overlay
addCorner(card, 8)
addStroke(card, Color3.fromRGB(219, 225, 244), 0.45, 1)

local sizeConstraint = Instance.new("UISizeConstraint")
sizeConstraint.MinSize = Vector2.new(300, 360)
sizeConstraint.MaxSize = Vector2.new(460, 360)
sizeConstraint.Parent = card

local title = createLabel(card, "Title", "FIN DE RUN", 25, Color3.fromRGB(248, 250, 255), Enum.Font.GothamBlack)
title.Position = UDim2.fromOffset(24, 20)
title.Size = UDim2.new(1, -48, 0, 30)
title.TextXAlignment = Enum.TextXAlignment.Center
title.ZIndex = 202

local result = createLabel(card, "Result", "", 14, Color3.fromRGB(230, 235, 246), Enum.Font.GothamBold)
result.Position = UDim2.fromOffset(24, 56)
result.Size = UDim2.new(1, -48, 0, 22)
result.TextXAlignment = Enum.TextXAlignment.Center
result.ZIndex = 202

local rowsFrame = Instance.new("Frame")
rowsFrame.Name = "Rows"
rowsFrame.Position = UDim2.fromOffset(28, 96)
rowsFrame.Size = UDim2.new(1, -56, 0, 170)
rowsFrame.BackgroundTransparency = 1
rowsFrame.ZIndex = 202
rowsFrame.Parent = card

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.FillDirection = Enum.FillDirection.Vertical
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = rowsFrame

local statRows = {}

for index, labelText in ipairs({ "Temps", "Kills", "Or de run", "Niveau", "XP gagnee", "Perks" }) do
	local row = Instance.new("Frame")
	row.Name = "Row" .. tostring(index)
	row.Size = UDim2.new(1, 0, 0, 22)
	row.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	row.BackgroundTransparency = 0.94
	row.BorderSizePixel = 0
	row.ZIndex = 202
	row.Parent = rowsFrame
	addCorner(row, 4)

	local label = createLabel(row, "Label", labelText, 13, Color3.fromRGB(191, 200, 218), Enum.Font.Gotham)
	label.Position = UDim2.fromOffset(9, 0)
	label.Size = UDim2.new(0.6, 0, 1, 0)
	label.ZIndex = 203

	local value = createLabel(row, "Value", "0", 13, Color3.fromRGB(255, 232, 126), Enum.Font.GothamBold)
	value.Position = UDim2.new(0.6, 0, 0, 0)
	value.Size = UDim2.new(0.4, -9, 1, 0)
	value.TextXAlignment = Enum.TextXAlignment.Right
	value.ZIndex = 203
	statRows[labelText] = value
end

local returnButton = Instance.new("TextButton")
returnButton.Name = "ReturnToLobby"
returnButton.Position = UDim2.new(0.5, 0, 1, -62)
returnButton.AnchorPoint = Vector2.new(0.5, 0)
returnButton.Size = UDim2.new(1, -56, 0, 40)
returnButton.BackgroundColor3 = Color3.fromRGB(54, 103, 182)
returnButton.BackgroundTransparency = 0.06
returnButton.BorderSizePixel = 0
returnButton.Font = Enum.Font.GothamBold
returnButton.Text = "RETOUR AU LOBBY"
returnButton.TextColor3 = Color3.fromRGB(255, 255, 255)
returnButton.TextSize = 14
returnButton.ZIndex = 202
returnButton.Parent = card
addCorner(returnButton, 5)
addStroke(returnButton, Color3.fromRGB(255, 255, 255), 0.65, 1)

local function formatTime(seconds)
	local total = math.max(0, math.floor(tonumber(seconds) or 0))
	return string.format("%02d:%02d", math.floor(total / 60), total % 60)
end

local function formatNumber(value)
	return string.format("%d", math.floor(tonumber(value) or 0))
end

local function showSummary(payload)
	local reason = payload.Reason
	local validated = payload.LevelValidated == true

	if reason == "Death" then
		title.Text = "RUN TERMINEE"
		result.Text = if validated then "Niveau valide avant la chute" else "Tu pourras faire mieux a la prochaine run"
	else
		title.Text = "NIVEAU TERMINE"
		result.Text = if validated then "Boss vaincu - niveau valide" else "Sortie de run"
	end

	statRows["Temps"].Text = formatTime(payload.SurvivalSeconds)
	statRows["Kills"].Text = formatNumber(payload.Kills)
	statRows["Or de run"].Text = formatNumber(payload.Coins)
	statRows["Niveau"].Text = formatNumber(payload.Level)
	statRows["XP gagnee"].Text = formatNumber(payload.TotalXp)
	statRows["Perks"].Text = formatNumber(payload.PerkCount)
	overlay.Visible = true
end

local returnToLobbyRemote = ReplicatedStorage:WaitForChild(BossConfig.ReturnToLobbyRemoteName)

returnButton.Activated:Connect(function()
	returnToLobbyRemote:FireServer()
end)

local summaryRemote = ReplicatedStorage:WaitForChild(BossConfig.ResultRemoteName)

summaryRemote.OnClientEvent:Connect(function(payload)
	payload = payload or {}

	if payload.Visible == false then
		overlay.Visible = false
		return
	end

	showSummary(payload)
end)
