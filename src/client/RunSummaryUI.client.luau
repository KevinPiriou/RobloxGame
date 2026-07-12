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
card.BackgroundColor3 = Color3.fromRGB(37, 51, 70)
card.BackgroundTransparency = 0.12
card.BorderSizePixel = 0
card.ZIndex = 201
card.Parent = overlay
addCorner(card, 10)
addStroke(card, Color3.fromRGB(93, 125, 161), 0.2, 2)
addGradient(card, Color3.fromRGB(65, 88, 118), Color3.fromRGB(13, 22, 34))

local sizeConstraint = Instance.new("UISizeConstraint")
sizeConstraint.MinSize = Vector2.new(300, 360)
sizeConstraint.MaxSize = Vector2.new(460, 360)
sizeConstraint.Parent = card

local inner = Instance.new("Frame")
inner.Name = "GlassInner"
inner.Position = UDim2.fromOffset(4, 4)
inner.Size = UDim2.new(1, -8, 1, -8)
inner.BackgroundColor3 = Color3.fromRGB(13, 22, 34)
inner.BackgroundTransparency = 0.18
inner.BorderSizePixel = 0
inner.ZIndex = 202
inner.Parent = card
addCorner(inner, 7)
addStroke(inner, Color3.fromRGB(221, 240, 255), 0.7, 1)

local headerGem = Instance.new("Frame")
headerGem.Name = "HeaderGem"
headerGem.AnchorPoint = Vector2.new(0.5, 0.5)
headerGem.Position = UDim2.new(0.5, 0, 0, 19)
headerGem.Size = UDim2.fromOffset(12, 12)
headerGem.BackgroundColor3 = Color3.fromRGB(187, 107, 255)
headerGem.BorderSizePixel = 0
headerGem.Rotation = 45
headerGem.ZIndex = 203
headerGem.Parent = card
addCorner(headerGem, 2)
addStroke(headerGem, Color3.fromRGB(236, 244, 255), 0.38, 1)
addGradient(headerGem, Color3.fromRGB(113, 232, 255), Color3.fromRGB(157, 85, 255))

local title = createLabel(card, "Title", "FIN DE RUN", 25, Color3.fromRGB(248, 250, 255), Enum.Font.GothamBlack)
title.Position = UDim2.fromOffset(24, 28)
title.Size = UDim2.new(1, -48, 0, 30)
title.TextXAlignment = Enum.TextXAlignment.Center
title.ZIndex = 203

local result = createLabel(card, "Result", "", 14, Color3.fromRGB(191, 207, 226), Enum.Font.GothamBold)
result.Position = UDim2.fromOffset(24, 62)
result.Size = UDim2.new(1, -48, 0, 22)
result.TextXAlignment = Enum.TextXAlignment.Center
result.ZIndex = 203

local divider = Instance.new("Frame")
divider.Name = "Divider"
divider.Position = UDim2.fromOffset(22, 91)
divider.Size = UDim2.new(1, -44, 0, 1)
divider.BackgroundColor3 = Color3.fromRGB(221, 240, 255)
divider.BackgroundTransparency = 0.78
divider.BorderSizePixel = 0
divider.ZIndex = 203
divider.Parent = card

local rowsFrame = Instance.new("Frame")
rowsFrame.Name = "Rows"
rowsFrame.Position = UDim2.fromOffset(28, 104)
rowsFrame.Size = UDim2.new(1, -56, 0, 170)
rowsFrame.BackgroundTransparency = 1
rowsFrame.ZIndex = 203
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
	row.BackgroundColor3 = Color3.fromRGB(24, 37, 54)
	row.BackgroundTransparency = 0.12
	row.BorderSizePixel = 0
	row.ZIndex = 203
	row.Parent = rowsFrame
	addCorner(row, 4)
	addStroke(row, Color3.fromRGB(221, 240, 255), 0.82, 1)
	addGradient(row, Color3.fromRGB(39, 57, 78), Color3.fromRGB(15, 24, 36))

	local rowAccent = Instance.new("Frame")
	rowAccent.Name = "Accent"
	rowAccent.Position = UDim2.fromOffset(0, 3)
	rowAccent.Size = UDim2.fromOffset(2, 16)
	rowAccent.BackgroundColor3 = if index % 2 == 0 then Color3.fromRGB(113, 232, 255) else Color3.fromRGB(190, 116, 255)
	rowAccent.BackgroundTransparency = 0.1
	rowAccent.BorderSizePixel = 0
	rowAccent.ZIndex = 204
	rowAccent.Parent = row
	addCorner(rowAccent, 1)

	local label = createLabel(row, "Label", labelText, 13, Color3.fromRGB(201, 213, 230), Enum.Font.Gotham)
	label.Position = UDim2.fromOffset(10, 0)
	label.Size = UDim2.new(0.6, 0, 1, 0)
	label.ZIndex = 204

	local value = createLabel(row, "Value", "0", 13, Color3.fromRGB(255, 223, 103), Enum.Font.GothamBold)
	value.Position = UDim2.new(0.6, 0, 0, 0)
	value.Size = UDim2.new(0.4, -9, 1, 0)
	value.TextXAlignment = Enum.TextXAlignment.Right
	value.ZIndex = 204
	statRows[labelText] = value
end

local returnButton = Instance.new("TextButton")
returnButton.Name = "ReturnToLobby"
returnButton.Position = UDim2.new(0.5, 0, 1, -62)
returnButton.AnchorPoint = Vector2.new(0.5, 0)
returnButton.Size = UDim2.new(1, -56, 0, 40)
returnButton.BackgroundColor3 = Color3.fromRGB(37, 51, 70)
returnButton.BackgroundTransparency = 0.08
returnButton.BorderSizePixel = 0
returnButton.Font = Enum.Font.GothamBold
returnButton.Text = "RETOUR AU LOBBY"
returnButton.TextColor3 = Color3.fromRGB(255, 255, 255)
returnButton.TextSize = 14
returnButton.ZIndex = 203
returnButton.Parent = card
addCorner(returnButton, 6)
addStroke(returnButton, Color3.fromRGB(113, 232, 255), 0.38, 1)
addGradient(returnButton, Color3.fromRGB(65, 88, 118), Color3.fromRGB(20, 32, 48))

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
