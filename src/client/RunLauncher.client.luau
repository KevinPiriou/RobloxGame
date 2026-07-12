--!strict

-- Lance une run depuis le lobby sans dependre d'une plaque presente dans Workspace.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local getChapterState = ReplicatedStorage:WaitForChild("Chapter_GetState") :: RemoteFunction
local startRunRequest = ReplicatedStorage:WaitForChild("Run_StartRequest") :: RemoteFunction

local oldGui = playerGui:FindFirstChild("RunLauncher")

if oldGui ~= nil then
	oldGui:Destroy()
end

local COLORS = {
	Panel = Color3.fromRGB(12, 20, 30),
	PanelLight = Color3.fromRGB(25, 39, 55),
	Card = Color3.fromRGB(18, 31, 45),
	CardSelected = Color3.fromRGB(31, 52, 72),
	Text = Color3.fromRGB(245, 248, 255),
	Muted = Color3.fromRGB(158, 177, 198),
	Cyan = Color3.fromRGB(76, 218, 255),
	Purple = Color3.fromRGB(181, 93, 255),
	Green = Color3.fromRGB(87, 232, 143),
	Locked = Color3.fromRGB(99, 108, 122),
	Danger = Color3.fromRGB(255, 104, 104),
}

local function addCorner(parent: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

local function addStroke(parent: Instance, color: Color3, transparency: number, thickness: number)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Transparency = transparency
	stroke.Thickness = thickness
	stroke.Parent = parent
	return stroke
end

local function createLabel(parent: Instance, name: string, text: string, size: number, color: Color3)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.TextColor3 = color
	label.TextSize = size
	label.TextWrapped = true
	label.Parent = parent
	return label
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "RunLauncher"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 45
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local openButton = Instance.new("TextButton")
openButton.Name = "OpenRunLauncher"
openButton.AnchorPoint = Vector2.new(0.5, 1)
openButton.Position = UDim2.new(0.5, 0, 1, -28)
openButton.Size = UDim2.fromOffset(230, 48)
openButton.BackgroundColor3 = COLORS.Panel
openButton.BackgroundTransparency = 0.16
openButton.BorderSizePixel = 0
openButton.AutoButtonColor = true
openButton.Font = Enum.Font.GothamBold
openButton.Text = "LANCER UNE RUN"
openButton.TextColor3 = COLORS.Text
openButton.TextSize = 16
openButton.Parent = screenGui
addCorner(openButton, 7)
addStroke(openButton, COLORS.Cyan, 0.16, 2)

local overlay = Instance.new("Frame")
overlay.Name = "Overlay"
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = Color3.new(0, 0, 0)
overlay.BackgroundTransparency = 0.52
overlay.BorderSizePixel = 0
overlay.Visible = false
overlay.Parent = screenGui

local panel = Instance.new("Frame")
panel.Name = "ChapterPanel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(690, 390)
panel.BackgroundColor3 = COLORS.Panel
panel.BackgroundTransparency = 0.1
panel.BorderSizePixel = 0
panel.ClipsDescendants = true
panel.Parent = overlay
addCorner(panel, 8)
addStroke(panel, Color3.fromRGB(128, 151, 177), 0.2, 2)

local panelGradient = Instance.new("UIGradient")
panelGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, COLORS.PanelLight),
	ColorSequenceKeypoint.new(1, COLORS.Panel),
})
panelGradient.Rotation = 90
panelGradient.Parent = panel

local panelScale = Instance.new("UIScale")
panelScale.Parent = panel

local title = createLabel(panel, "Title", "CHOISIR UN CHAPITRE", 24, COLORS.Text)
title.Position = UDim2.fromOffset(30, 22)
title.Size = UDim2.new(1, -60, 0, 34)
title.TextXAlignment = Enum.TextXAlignment.Center

local subtitle = createLabel(
	panel,
	"Subtitle",
	"Chaque chapitre utilise sa propre map et sa propre progression.",
	12,
	COLORS.Muted
)
subtitle.Position = UDim2.fromOffset(30, 57)
subtitle.Size = UDim2.new(1, -60, 0, 24)
subtitle.Font = Enum.Font.Gotham
subtitle.TextXAlignment = Enum.TextXAlignment.Center

local closeButton = Instance.new("TextButton")
closeButton.Name = "Close"
closeButton.AnchorPoint = Vector2.new(1, 0)
closeButton.Position = UDim2.new(1, -14, 0, 14)
closeButton.Size = UDim2.fromOffset(32, 32)
closeButton.BackgroundColor3 = COLORS.Card
closeButton.BackgroundTransparency = 0.15
closeButton.BorderSizePixel = 0
closeButton.Font = Enum.Font.GothamBold
closeButton.Text = "X"
closeButton.TextColor3 = COLORS.Text
closeButton.TextSize = 14
closeButton.Parent = panel
addCorner(closeButton, 6)

local cardsFrame = Instance.new("Frame")
cardsFrame.Name = "Chapters"
cardsFrame.Position = UDim2.fromOffset(24, 98)
cardsFrame.Size = UDim2.new(1, -48, 0, 190)
cardsFrame.BackgroundTransparency = 1
cardsFrame.Parent = panel

local cardsLayout = Instance.new("UIGridLayout")
cardsLayout.CellPadding = UDim2.fromOffset(12, 0)
cardsLayout.CellSize = UDim2.new(1 / 3, -8, 1, 0)
cardsLayout.FillDirectionMaxCells = 3
cardsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
cardsLayout.SortOrder = Enum.SortOrder.LayoutOrder
cardsLayout.Parent = cardsFrame

local statusLabel = createLabel(panel, "Status", "", 12, COLORS.Muted)
statusLabel.Position = UDim2.new(0, 30, 1, -88)
statusLabel.Size = UDim2.new(1, -60, 0, 22)
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextXAlignment = Enum.TextXAlignment.Center

local launchButton = Instance.new("TextButton")
launchButton.Name = "Launch"
launchButton.AnchorPoint = Vector2.new(0.5, 1)
launchButton.Position = UDim2.new(0.5, 0, 1, -24)
launchButton.Size = UDim2.fromOffset(250, 46)
launchButton.BackgroundColor3 = Color3.fromRGB(46, 126, 166)
launchButton.BorderSizePixel = 0
launchButton.AutoButtonColor = true
launchButton.Font = Enum.Font.GothamBold
launchButton.Text = "LANCER LE CHAPITRE"
launchButton.TextColor3 = COLORS.Text
launchButton.TextSize = 15
launchButton.Parent = panel
addCorner(launchButton, 6)
local launchStroke = addStroke(launchButton, COLORS.Cyan, 0.08, 2)

type ChapterPayload = {
	Id: number,
	DisplayName: string,
	MapId: string,
	IsUnlocked: boolean,
	IsCompleted: boolean,
	IsSelected: boolean,
}

type ChapterCard = {
	Data: ChapterPayload,
	Button: TextButton,
	Stroke: UIStroke,
}

local cards: {ChapterCard} = {}
local selectedChapterId: number? = nil
local isBusy = false
local responsiveScale = 1

local function refreshCards()
	for _, card in ipairs(cards) do
		local isSelected = card.Data.Id == selectedChapterId
		card.Button.BackgroundColor3 = if isSelected then COLORS.CardSelected else COLORS.Card
		card.Stroke.Color = if not card.Data.IsUnlocked
			then COLORS.Locked
			elseif isSelected
			then COLORS.Cyan
			else COLORS.Purple
		card.Stroke.Transparency = if isSelected then 0.02 else 0.42
	end

	local canLaunch = selectedChapterId ~= nil and not isBusy
	launchButton.Active = canLaunch
	launchButton.AutoButtonColor = canLaunch
	launchButton.BackgroundTransparency = if canLaunch then 0 else 0.45
	launchStroke.Transparency = if canLaunch then 0.08 else 0.65
end

local function clearCards()
	for _, card in ipairs(cards) do
		card.Button:Destroy()
	end

	table.clear(cards)
	selectedChapterId = nil
end

local function createChapterCard(data: ChapterPayload, layoutOrder: number)
	local button = Instance.new("TextButton")
	button.Name = "Chapter" .. data.Id
	button.LayoutOrder = layoutOrder
	button.BackgroundColor3 = COLORS.Card
	button.BackgroundTransparency = 0.08
	button.BorderSizePixel = 0
	button.AutoButtonColor = data.IsUnlocked
	button.Text = ""
	button.Parent = cardsFrame
	addCorner(button, 6)
	local stroke = addStroke(button, if data.IsUnlocked then COLORS.Purple else COLORS.Locked, 0.42, 2)

	local chapterNumber = createLabel(button, "Number", string.format("%02d", data.Id), 35, if data.IsUnlocked then COLORS.Cyan else COLORS.Locked)
	chapterNumber.Position = UDim2.fromOffset(14, 16)
	chapterNumber.Size = UDim2.new(1, -28, 0, 48)
	chapterNumber.TextXAlignment = Enum.TextXAlignment.Left

	local chapterName = createLabel(button, "Name", string.upper(data.DisplayName), 16, COLORS.Text)
	chapterName.Position = UDim2.fromOffset(14, 70)
	chapterName.Size = UDim2.new(1, -28, 0, 28)
	chapterName.TextXAlignment = Enum.TextXAlignment.Left

	local mapName = createLabel(button, "Map", data.MapId, 11, COLORS.Muted)
	mapName.Position = UDim2.fromOffset(14, 101)
	mapName.Size = UDim2.new(1, -28, 0, 22)
	mapName.Font = Enum.Font.Gotham
	mapName.TextXAlignment = Enum.TextXAlignment.Left

	local stateText = if not data.IsUnlocked then "VERROUILLE" elseif data.IsCompleted then "TERMINE" else "DISPONIBLE"
	local stateColor = if not data.IsUnlocked then COLORS.Locked elseif data.IsCompleted then COLORS.Green else COLORS.Cyan
	local state = createLabel(button, "State", stateText, 11, stateColor)
	state.Position = UDim2.new(0, 14, 1, -39)
	state.Size = UDim2.new(1, -28, 0, 22)
	state.TextXAlignment = Enum.TextXAlignment.Left

	local card: ChapterCard = {
		Data = data,
		Button = button,
		Stroke = stroke,
	}
	table.insert(cards, card)

	if data.IsSelected and data.IsUnlocked then
		selectedChapterId = data.Id
	end

	button.Activated:Connect(function()
		if isBusy or not data.IsUnlocked then
			if not data.IsUnlocked then
				statusLabel.Text = "Termine le chapitre precedent pour le debloquer."
				statusLabel.TextColor3 = COLORS.Danger
			end
			return
		end

		selectedChapterId = data.Id
		statusLabel.Text = data.DisplayName .. " selectionne"
		statusLabel.TextColor3 = COLORS.Muted
		refreshCards()
	end)
end

local function loadChapters()
	clearCards()
	statusLabel.Text = "Chargement des chapitres..."
	statusLabel.TextColor3 = COLORS.Muted

	local success, result = pcall(function()
		return getChapterState:InvokeServer()
	end)

	if not success or typeof(result) ~= "table" then
		statusLabel.Text = "Progression indisponible. Reessaie dans un instant."
		statusLabel.TextColor3 = COLORS.Danger
		refreshCards()
		return
	end

	for index, chapterData in ipairs(result) do
		if typeof(chapterData) == "table" then
			createChapterCard(chapterData :: ChapterPayload, index)
		end
	end

	if selectedChapterId == nil then
		for _, card in ipairs(cards) do
			if card.Data.IsUnlocked then
				selectedChapterId = card.Data.Id
				break
			end
		end
	end

	statusLabel.Text = "Selectionne la map de ta prochaine run."
	statusLabel.TextColor3 = COLORS.Muted
	refreshCards()
end

local function closePanel()
	if isBusy then
		return
	end

	overlay.Visible = false
end

local function openPanel()
	if player:GetAttribute("IsRunActive") == true then
		return
	end

	overlay.Visible = true
	panelScale.Scale = responsiveScale * 0.96
	TweenService:Create(panelScale, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Scale = responsiveScale,
	}):Play()
	task.spawn(loadChapters)
end

openButton.Activated:Connect(openPanel)
closeButton.Activated:Connect(closePanel)

launchButton.Activated:Connect(function()
	if isBusy or selectedChapterId == nil then
		return
	end

	isBusy = true
	statusLabel.Text = "GENERATION DE LA RUN..."
	statusLabel.TextColor3 = COLORS.Cyan
	launchButton.Text = "LANCEMENT..."
	refreshCards()

	task.spawn(function()
		local requestSucceeded, started, reason = pcall(function()
			return startRunRequest:InvokeServer(selectedChapterId)
		end)

		if requestSucceeded and started == true then
			statusLabel.Text = "RUN PRETE"
			statusLabel.TextColor3 = COLORS.Green
			return
		end

		isBusy = false
		launchButton.Text = "LANCER LE CHAPITRE"
		statusLabel.Text = "Lancement impossible : " .. tostring(if requestSucceeded then reason else started)
		statusLabel.TextColor3 = COLORS.Danger
		refreshCards()
	end)
end)

local function refreshVisibility()
	local isRunActive = player:GetAttribute("IsRunActive") == true
	openButton.Visible = not isRunActive

	if isRunActive then
		overlay.Visible = false
	end
end

player:GetAttributeChangedSignal("IsRunActive"):Connect(refreshVisibility)

local cameraConnection: RBXScriptConnection? = nil

local function updateScale()
	local camera = workspace.CurrentCamera

	if camera == nil then
		return
	end

	local viewport = camera.ViewportSize
	responsiveScale = math.clamp(math.min(viewport.X / 900, viewport.Y / 600), 0.68, 1)
	panelScale.Scale = responsiveScale
end

local function bindCamera()
	if cameraConnection ~= nil then
		cameraConnection:Disconnect()
	end

	local camera = workspace.CurrentCamera

	if camera ~= nil then
		cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end

	updateScale()
end

workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
bindCamera()
refreshVisibility()
