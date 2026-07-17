local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AdminConfig = require(Shared:WaitForChild("AdminConfig"))
local DebugLog = require(Shared:WaitForChild("DebugLog"))
local FeatureFlags = require(Shared:WaitForChild("FeatureFlags"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))

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
local setDebugLogSettingRemote = ReplicatedStorage:WaitForChild("Admin_SetDebugLogSetting")
local debugLogStateRemote = ReplicatedStorage:WaitForChild("Admin_DebugLogState")
local getDebugLogStateRemote = ReplicatedStorage:WaitForChild("Admin_GetDebugLogState")
local toggleDevKitPreviewRemote = ReplicatedStorage:WaitForChild("Admin_ToggleDevKitPreview")

local DEV_KIT_PREVIEW_ATTRIBUTE = "DevKitPreviewEnabled"

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

local addCorner = UiTheme.AddCorner
local addStroke = UiTheme.AddStroke

local function addGradient(instance, firstColor, secondColor)
	return UiTheme.AddGradient(instance, firstColor, secondColor, 90)
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
UiTheme.AddSurfaceFinish(adminButton, {
	Accent = UiTheme.Colors.Accent,
	Intensity = 0.4,
})

local container = Instance.new("Frame")
container.Name = "AdminPanel"
container.AnchorPoint = Vector2.new(1, 0)
container.Position = UDim2.new(1, -92, 0, 58)
container.Size = UDim2.fromOffset(310, 520)
container.BackgroundColor3 = Color3.fromRGB(37, 51, 70)
container.BackgroundTransparency = 0.16
container.BorderSizePixel = 0
container.Visible = false
container.Parent = screenGui
addCorner(container, 10)
addStroke(container, Color3.fromRGB(93, 125, 161), 0.24, 2)
addGradient(container, Color3.fromRGB(65, 88, 118), Color3.fromRGB(13, 22, 34))
UiTheme.AddSurfaceFinish(container, {
	Accent = UiTheme.Colors.Accent,
	Intensity = 0.6,
})

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
local devKitPreviewButton = createButton("DevKitPreviewButton", "Kit UI demo : afficher", Color3.fromRGB(52, 101, 153), 4)

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
statusLabel.LayoutOrder = 5
statusLabel.Parent = content

local debugSection = Instance.new("Frame")
debugSection.Name = "DebugLogSection"
debugSection.Size = UDim2.new(1, 0, 0, 266)
debugSection.BackgroundTransparency = 1
debugSection.BorderSizePixel = 0
debugSection.LayoutOrder = 6
debugSection.Parent = content

local debugTitle = Instance.new("TextLabel")
debugTitle.Name = "DebugLogTitle"
debugTitle.Position = UDim2.fromOffset(0, 0)
debugTitle.Size = UDim2.new(1, 0, 0, 18)
debugTitle.BackgroundTransparency = 1
debugTitle.Font = Enum.Font.GothamBold
debugTitle.Text = "JOURNAUX DEBUG"
debugTitle.TextColor3 = Color3.fromRGB(173, 211, 255)
debugTitle.TextSize = 11
debugTitle.TextXAlignment = Enum.TextXAlignment.Left
debugTitle.Parent = debugSection

local function createDebugToggle(parent, name, label, position)
	local row = Instance.new("TextButton")
	row.Name = name
	row.Position = position or UDim2.new()
	row.Size = UDim2.new(1, -4, 0, 24)
	row.BackgroundColor3 = Color3.fromRGB(19, 33, 49)
	row.BackgroundTransparency = 0.12
	row.BorderSizePixel = 0
	row.AutoButtonColor = false
	row.Font = Enum.Font.GothamMedium
	row.Text = ""
	row.Parent = parent
	addCorner(row, 4)
	addStroke(row, Color3.fromRGB(123, 158, 196), 0.76, 1)

	local indicator = Instance.new("TextLabel")
	indicator.Name = "Indicator"
	indicator.Position = UDim2.fromOffset(4, 3)
	indicator.Size = UDim2.fromOffset(18, 18)
	indicator.BackgroundColor3 = Color3.fromRGB(48, 68, 92)
	indicator.BorderSizePixel = 0
	indicator.Font = Enum.Font.GothamBlack
	indicator.Text = ""
	indicator.TextColor3 = Color3.fromRGB(255, 255, 255)
	indicator.TextSize = 13
	indicator.Parent = row
	addCorner(indicator, 3)
	addStroke(indicator, Color3.fromRGB(211, 235, 255), 0.74, 1)

	local textLabel = Instance.new("TextLabel")
	textLabel.Name = "Label"
	textLabel.Position = UDim2.fromOffset(30, 0)
	textLabel.Size = UDim2.new(1, -36, 1, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.Font = Enum.Font.GothamMedium
	textLabel.Text = label
	textLabel.TextColor3 = Color3.fromRGB(226, 235, 246)
	textLabel.TextSize = 11
	textLabel.TextXAlignment = Enum.TextXAlignment.Left
	textLabel.Parent = row

	local function setSelected(isSelected)
		indicator.Text = if isSelected then "X" else ""
		indicator.BackgroundColor3 = if isSelected
			then Color3.fromRGB(45, 159, 101)
			else Color3.fromRGB(48, 68, 92)
		row.BackgroundTransparency = if isSelected then 0.02 else 0.12
	end

	return row, setSelected
end

local consoleToggle, setConsoleSelected = createDebugToggle(
	debugSection,
	"ConsoleToggle",
	"Console globale",
	UDim2.fromOffset(0, 22)
)

local categoryList = Instance.new("ScrollingFrame")
categoryList.Name = "CategoryList"
categoryList.Position = UDim2.fromOffset(0, 52)
categoryList.Size = UDim2.new(1, 0, 1, -52)
categoryList.BackgroundColor3 = Color3.fromRGB(9, 17, 28)
categoryList.BackgroundTransparency = 0.3
categoryList.BorderSizePixel = 0
categoryList.CanvasSize = UDim2.new()
categoryList.AutomaticCanvasSize = Enum.AutomaticSize.Y
categoryList.ScrollBarImageColor3 = Color3.fromRGB(108, 185, 255)
categoryList.ScrollBarThickness = 4
categoryList.Parent = debugSection
addCorner(categoryList, 4)
addStroke(categoryList, Color3.fromRGB(123, 158, 196), 0.84, 1)

local categoryLayout = Instance.new("UIListLayout")
categoryLayout.Padding = UDim.new(0, 3)
categoryLayout.SortOrder = Enum.SortOrder.LayoutOrder
categoryLayout.Parent = categoryList

local categoryPadding = Instance.new("UIPadding")
categoryPadding.PaddingTop = UDim.new(0, 3)
categoryPadding.PaddingLeft = UDim.new(0, 3)
categoryPadding.PaddingRight = UDim.new(0, 3)
categoryPadding.PaddingBottom = UDim.new(0, 3)
categoryPadding.Parent = categoryList

local debugCategoryRows = {}
local debugLogState = {
	ConsoleEnabled = true,
	Categories = {},
}

for layoutOrder, category in ipairs(AdminConfig.DebugLogCategories) do
	local row, setSelected = createDebugToggle(categoryList, "Debug_" .. category.Id, category.Label)
	row.LayoutOrder = layoutOrder
	debugCategoryRows[category.Id] = {
		Row = row,
		SetSelected = setSelected,
	}
end

local activeButton = nil
local debugStateRequestInFlight = false

local function refreshDevKitPreviewButton()
	local isPreviewEnabled = player:GetAttribute(DEV_KIT_PREVIEW_ATTRIBUTE) == true
	devKitPreviewButton.Text = if isPreviewEnabled then "Kit UI demo : actif" else "Kit UI demo : afficher"
	devKitPreviewButton.BackgroundColor3 = if isPreviewEnabled
		then Color3.fromRGB(48, 132, 93)
		else Color3.fromRGB(52, 101, 153)
end

local function applyDebugLogState(payload)
	if typeof(payload) ~= "table" or typeof(payload.Categories) ~= "table" then
		return
	end

	debugLogState = {
		ConsoleEnabled = payload.ConsoleEnabled == true,
		Categories = payload.Categories,
	}
	DebugLog.ApplyState(debugLogState)
	setConsoleSelected(debugLogState.ConsoleEnabled)

	for categoryId, entry in pairs(debugCategoryRows) do
		entry.SetSelected(debugLogState.Categories[categoryId] == true)
	end
end

local function requestDebugLogState()
	if debugStateRequestInFlight
		or player:GetAttribute("CanUseAdminTools") ~= true
		or not getDebugLogStateRemote:IsA("RemoteFunction")
	then
		return
	end

	debugStateRequestInFlight = true

	task.spawn(function()
		local success, payload = pcall(function()
			return getDebugLogStateRemote:InvokeServer()
		end)

		debugStateRequestInFlight = false

		if success then
			applyDebugLogState(payload)
		else
			statusLabel.Text = "Etat des logs indisponible"
			statusLabel.TextColor3 = Color3.fromRGB(255, 145, 145)
		end
	end)
end

local function sendDebugLogSetting(scope, categoryId, isEnabled)
	if not setDebugLogSettingRemote:IsA("RemoteEvent") then
		return
	end

	statusLabel.Text = "Mise a jour des logs..."
	statusLabel.TextColor3 = Color3.fromRGB(220, 225, 235)
	setDebugLogSettingRemote:FireServer({
		Scope = scope,
		Category = categoryId,
		Enabled = isEnabled,
	})
end

local function updateVisibility()
	local canUseAdminTools = player:GetAttribute("CanUseAdminTools") == true
	screenGui.Enabled = canUseAdminTools

	if not canUseAdminTools then
		container.Visible = false
		return
	end

	requestDebugLogState()
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

devKitPreviewButton.Activated:Connect(function()
	if not toggleDevKitPreviewRemote:IsA("RemoteEvent") then
		return
	end

	statusLabel.Text = "Mise a jour de l'apercu..."
	statusLabel.TextColor3 = Color3.fromRGB(220, 225, 235)
	toggleDevKitPreviewRemote:FireServer()
end)

consoleToggle.Activated:Connect(function()
	sendDebugLogSetting("Console", nil, not debugLogState.ConsoleEnabled)
end)

for categoryId, entry in pairs(debugCategoryRows) do
	entry.Row.Activated:Connect(function()
		local isEnabled = debugLogState.Categories[categoryId] == true
		sendDebugLogSetting("Category", categoryId, not isEnabled)
	end)
end

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

debugLogStateRemote.OnClientEvent:Connect(function(payload)
	applyDebugLogState(payload)
end)

player:GetAttributeChangedSignal("CanUseAdminTools"):Connect(updateVisibility)
player:GetAttributeChangedSignal(DEV_KIT_PREVIEW_ATTRIBUTE):Connect(refreshDevKitPreviewButton)
updateVisibility()
refreshDevKitPreviewButton()

DebugLog.Info("UI", "UI admin initialisee", {
	Player = player.Name,
	Visible = screenGui.Enabled,
})
