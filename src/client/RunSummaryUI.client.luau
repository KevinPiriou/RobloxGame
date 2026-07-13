local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BossConfig = require(Shared:WaitForChild("BossConfig"))
local MetaProgressionConfig = require(Shared:WaitForChild("MetaProgressionConfig"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))

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
	label.Font = font or UiTheme.Fonts.Bold
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
card.Size = UDim2.new(0.4, 0, 0, 520)
card.BackgroundColor3 = Color3.fromRGB(37, 51, 70)
card.BackgroundTransparency = 0.12
card.BorderSizePixel = 0
card.ZIndex = 201
card.Parent = overlay
addCorner(card, 10)
addStroke(card, Color3.fromRGB(93, 125, 161), 0.2, 2)
addGradient(card, Color3.fromRGB(65, 88, 118), Color3.fromRGB(13, 22, 34))
UiTheme.AddSurfaceFinish(card, {
	Accent = UiTheme.Colors.Purple,
	Intensity = 0.68,
})

local sizeConstraint = Instance.new("UISizeConstraint")
sizeConstraint.MinSize = Vector2.new(320, 520)
sizeConstraint.MaxSize = Vector2.new(560, 520)
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
rowsFrame.Size = UDim2.new(1, -56, 0, 244)
rowsFrame.BackgroundTransparency = 1
rowsFrame.ZIndex = 203
rowsFrame.Parent = card

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 4)
layout.FillDirection = Enum.FillDirection.Vertical
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = rowsFrame

local statRows = {}

for index, labelText in ipairs({
	"Temps",
	"Kills",
	"Elites",
	"Boss",
	"Or de run",
	"XP gagnee",
	"Niveau",
	"Perks",
	"Coffres",
	"Jarres",
}) do
	local row = Instance.new("Frame")
	row.Name = "Row" .. tostring(index)
	row.Size = UDim2.new(1, 0, 0, 20)
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
	rowAccent.Position = UDim2.fromOffset(0, 2)
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

local progressionFrame = Instance.new("Frame")
progressionFrame.Name = "Progression"
progressionFrame.Position = UDim2.fromOffset(28, 362)
progressionFrame.Size = UDim2.new(1, -56, 0, 90)
progressionFrame.BackgroundColor3 = Color3.fromRGB(20, 34, 48)
progressionFrame.BackgroundTransparency = 0.2
progressionFrame.BorderSizePixel = 0
progressionFrame.ZIndex = 203
progressionFrame.Parent = card
addCorner(progressionFrame, 6)
addStroke(progressionFrame, Color3.fromRGB(113, 232, 255), 0.68, 1)

local progressionTitle = createLabel(
	progressionFrame,
	"Title",
	"PROGRESSION DEBLOQUEE",
	12,
	Color3.fromRGB(113, 232, 255),
	Enum.Font.GothamBold
)
progressionTitle.Position = UDim2.fromOffset(12, 8)
progressionTitle.Size = UDim2.new(1, -24, 0, 16)
progressionTitle.ZIndex = 204

local progressionText = createLabel(
	progressionFrame,
	"Details",
	"Aucune nouvelle progression.",
	11,
	Color3.fromRGB(224, 234, 247),
	Enum.Font.Gotham
)
progressionText.Position = UDim2.fromOffset(12, 27)
progressionText.Size = UDim2.new(1, -24, 1, -35)
progressionText.TextWrapped = true
progressionText.TextTruncate = Enum.TextTruncate.AtEnd
progressionText.TextYAlignment = Enum.TextYAlignment.Top
progressionText.ZIndex = 204

local returnButton = Instance.new("TextButton")
returnButton.Name = "ReturnToLobby"
returnButton.Position = UDim2.new(0.5, 0, 1, -54)
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

local function findDefinition(definitions, id)
	for _, definition in ipairs(definitions) do
		if definition.Id == id then
			return definition
		end
	end

	return nil
end

local function formatProgression(payload)
	if payload.ProgressionEligible ~= true then
		return "Run de debug : statistiques, quetes et hauts faits non comptabilises."
	end

	local progression = payload.Progression or {}
	local lines = {}

	for _, unlock in ipairs(progression.NewUnlocks or {}) do
		if unlock.Type == "Chapter" then
			table.insert(lines, "Nouveau chapitre debloque : " .. tostring(unlock.Id))
		end
	end

	for _, questId in ipairs(progression.CompletedQuestIds or {}) do
		local definition = findDefinition(MetaProgressionConfig.Quests, questId)
			or findDefinition(MetaProgressionConfig.DailyQuests, questId)

		if definition ~= nil then
			table.insert(lines, "Quete terminee : " .. definition.Label)
		end
	end

	for _, achievementId in ipairs(progression.NewAchievementIds or {}) do
		local definition = findDefinition(MetaProgressionConfig.Achievements, achievementId)

		if definition ~= nil then
			table.insert(lines, "Haut fait : " .. definition.Label)
		end
	end

	for _, personalBest in ipairs(progression.PersonalBestChanges or {}) do
		table.insert(lines, "Nouveau record : " .. tostring(personalBest.StatId))
	end

	if #lines == 0 then
		if progression.Reason == "DataStoreFailure" or progression.Reason == "ProfileNotLoaded" then
			return "Progression non sauvegardee : nouvelle tentative necessaire."
		end

		return "Aucune nouvelle progression cette fois."
	end

	return table.concat(lines, "\n")
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
	statRows["Elites"].Text = formatNumber(payload.EliteKills)
	statRows["Boss"].Text = formatNumber(payload.BossKills)
	statRows["Or de run"].Text = formatNumber(payload.Coins)
	statRows["Niveau"].Text = formatNumber(payload.Level)
	statRows["XP gagnee"].Text = formatNumber(payload.TotalXp)
	statRows["Perks"].Text = formatNumber(payload.PerkCount)
	statRows["Coffres"].Text = formatNumber(payload.ChestsOpened)
	statRows["Jarres"].Text = formatNumber(payload.JarsBroken)
	progressionText.Text = formatProgression(payload)
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
