local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AdminConfig = require(Shared:WaitForChild("AdminConfig"))
local DebugLog = require(Shared:WaitForChild("DebugLog"))
local FeatureFlags = require(Shared:WaitForChild("FeatureFlags"))
local PerformanceBaselineConfig = require(Shared:WaitForChild("PerformanceBaselineConfig"))
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
local performanceBenchmarkRemote = ReplicatedStorage:WaitForChild(PerformanceBaselineConfig.AdminRemoteName)
local performanceBenchmarkStatusRemote = ReplicatedStorage:WaitForChild(PerformanceBaselineConfig.StatusRemoteName)
local physicsAuditRemote = ReplicatedStorage:WaitForChild("Admin_RunPhysicsAudit")

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

local content = Instance.new("ScrollingFrame")
content.Name = "Content"
content.Position = UDim2.fromOffset(14, 52)
content.Size = UDim2.new(1, -28, 1, -64)
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.CanvasSize = UDim2.fromOffset(0, 0)
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.ScrollBarImageColor3 = Color3.fromRGB(118, 193, 255)
content.ScrollBarThickness = 4
content.ScrollingDirection = Enum.ScrollingDirection.Y
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
local benchmarkScenarioButton = createButton("BenchmarkScenarioButton", "P0 : scenario", Color3.fromRGB(64, 109, 142), 5)
local benchmarkStartButton = createButton("BenchmarkStartButton", "P0 : lancer", Color3.fromRGB(47, 137, 91), 6)
local benchmarkStopButton = createButton("BenchmarkStopButton", "P0 : arreter", Color3.fromRGB(143, 70, 70), 7)
local physicsAuditButton = createButton("PhysicsAuditButton", "P1 : inventaire physique", Color3.fromRGB(94, 91, 143), 8)

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
statusLabel.LayoutOrder = 10
statusLabel.Parent = content

local benchmarkStatusLabel = Instance.new("TextLabel")
benchmarkStatusLabel.Name = "BenchmarkStatusLabel"
benchmarkStatusLabel.Size = UDim2.new(1, 0, 0, 18)
benchmarkStatusLabel.BackgroundTransparency = 1
benchmarkStatusLabel.Font = Enum.Font.GothamMedium
benchmarkStatusLabel.Text = "P0 : pret"
benchmarkStatusLabel.TextColor3 = Color3.fromRGB(154, 212, 255)
benchmarkStatusLabel.TextSize = 11
benchmarkStatusLabel.TextTruncate = Enum.TextTruncate.AtEnd
benchmarkStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
benchmarkStatusLabel.LayoutOrder = 9
benchmarkStatusLabel.Parent = content

local debugSection = Instance.new("Frame")
debugSection.Name = "DebugLogSection"
debugSection.Size = UDim2.new(1, 0, 0, 266)
debugSection.BackgroundTransparency = 1
debugSection.BorderSizePixel = 0
debugSection.LayoutOrder = 11
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
local benchmarkScenarioIndex = 1
local benchmarkIsActive = false
local benchmarkPhase = "Idle"
local benchmarkScenarioLabel = "P0"
local benchmarkElapsedAtStatus = 0
local benchmarkStatusReceivedAt = 0
local benchmarkCampaignLabel = nil
local benchmarkCampaignIndex = nil
local benchmarkCampaignTotal = nil
local benchmarkStatusRefreshElapsed = 0

local function getBenchmarkPhaseDuration(phase)
	if phase == "Warmup" then
		return PerformanceBaselineConfig.WarmupSeconds
	elseif phase == "Measuring" then
		return PerformanceBaselineConfig.MeasurementSeconds
	elseif phase == "Cleanup" then
		return PerformanceBaselineConfig.CleanupSeconds
	elseif phase == "IdleObservation" then
		return PerformanceBaselineConfig.IdleObservationSeconds
	end

	return 0
end

local function getBenchmarkPhaseElapsed(totalElapsed)
	if benchmarkPhase == "Measuring" then
		return math.max(0, totalElapsed - PerformanceBaselineConfig.WarmupSeconds)
	elseif benchmarkPhase == "Cleanup" then
		return math.max(0, totalElapsed - PerformanceBaselineConfig.WarmupSeconds - PerformanceBaselineConfig.MeasurementSeconds)
	elseif benchmarkPhase == "IdleObservation" then
		return math.max(
			0,
			totalElapsed
				- PerformanceBaselineConfig.WarmupSeconds
				- PerformanceBaselineConfig.MeasurementSeconds
				- PerformanceBaselineConfig.CleanupSeconds
		)
	end

	return totalElapsed
end

local function refreshBenchmarkStatusLabel()
	local elapsedSeconds = math.max(0, math.floor(benchmarkElapsedAtStatus + (os.clock() - benchmarkStatusReceivedAt)))
	local phaseElapsed = getBenchmarkPhaseElapsed(elapsedSeconds)
	local phaseDuration = getBenchmarkPhaseDuration(benchmarkPhase)
	local phaseLabel = if benchmarkPhase == "Warmup"
		then "chauffe"
		elseif benchmarkPhase == "Measuring"
			then "mesure"
			elseif benchmarkPhase == "Cleanup"
				then "nettoyage"
				elseif benchmarkPhase == "IdleObservation"
					then "repos mesure"
				elseif benchmarkPhase == "CampaignTransition"
					then "scenario suivant"
				else string.lower(benchmarkPhase)
	local benchmarkLabel = if benchmarkCampaignLabel ~= nil and benchmarkCampaignIndex ~= nil and benchmarkCampaignTotal ~= nil
		then ("%s %d/%d | %s"):format(
			benchmarkCampaignLabel,
			benchmarkCampaignIndex,
			benchmarkCampaignTotal,
			benchmarkScenarioLabel
		)
		else benchmarkScenarioLabel

	if benchmarkIsActive and phaseDuration > 0 then
		benchmarkStatusLabel.Text = ("%s | %s %ds / %ds"):format(
			benchmarkLabel,
			phaseLabel,
			math.min(phaseElapsed, phaseDuration),
			phaseDuration
		)
	elseif benchmarkIsActive then
		benchmarkStatusLabel.Text = ("%s | %s"):format(benchmarkLabel, phaseLabel)
	else
		benchmarkStatusLabel.Text = ("%s | %s"):format(
			benchmarkScenarioLabel,
			phaseLabel
		)
	end
end

local function getBenchmarkSelections()
	return PerformanceBaselineConfig.GetSelections()
end

local function selectDefaultBenchmark()
	for index, selection in ipairs(getBenchmarkSelections()) do
		if selection.Id == PerformanceBaselineConfig.DefaultSelectionId then
			benchmarkScenarioIndex = index
			return
		end
	end
end

local function getSelectedBenchmarkSelection()
	return getBenchmarkSelections()[benchmarkScenarioIndex]
end

local function refreshBenchmarkControls()
	local selection = getSelectedBenchmarkSelection()

	if selection == nil then
		benchmarkScenarioButton.Text = "P0 : aucune selection"
		benchmarkStartButton.Active = false
		benchmarkStopButton.Active = false
		return
	end

	benchmarkScenarioButton.Text = selection.Label
	benchmarkStartButton.Active = not benchmarkIsActive
	benchmarkStartButton.AutoButtonColor = not benchmarkIsActive
	benchmarkStartButton.Text = if benchmarkIsActive then "P0 : en cours" else "P0 : lancer"
	benchmarkStopButton.Active = benchmarkIsActive
	benchmarkStopButton.AutoButtonColor = benchmarkIsActive
	benchmarkStopButton.Text = "P0 : arreter"
end

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

benchmarkScenarioButton.Activated:Connect(function()
	if benchmarkIsActive then
		return
	end

	local selections = getBenchmarkSelections()
	benchmarkScenarioIndex = (benchmarkScenarioIndex % #selections) + 1
	refreshBenchmarkControls()
end)

benchmarkStartButton.Activated:Connect(function()
	local selection = getSelectedBenchmarkSelection()
	if selection == nil or benchmarkIsActive or not performanceBenchmarkRemote:IsA("RemoteEvent") then
		return
	end

	benchmarkStatusLabel.Text = "P0 : demande envoyee"
	benchmarkStatusLabel.TextColor3 = Color3.fromRGB(214, 230, 255)
	performanceBenchmarkRemote:FireServer({
		Action = "Start",
		SelectionId = selection.Id,
	})
end)

benchmarkStopButton.Activated:Connect(function()
	if not benchmarkIsActive or not performanceBenchmarkRemote:IsA("RemoteEvent") then
		return
	end

	benchmarkStatusLabel.Text = "P0 : nettoyage demande"
	benchmarkStatusLabel.TextColor3 = Color3.fromRGB(255, 221, 150)
	performanceBenchmarkRemote:FireServer({
		Action = "Stop",
	})
end)

physicsAuditButton.Activated:Connect(function()
	if not physicsAuditRemote:IsA("RemoteEvent") then
		return
	end

	fireAdminAction(physicsAuditButton, physicsAuditRemote, "Audit P1...")
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

performanceBenchmarkStatusRemote.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end

	benchmarkIsActive = payload.Active == true
	benchmarkPhase = if typeof(payload.Phase) == "string" then payload.Phase else "Inconnu"
	benchmarkScenarioLabel = if typeof(payload.ScenarioLabel) == "string" then payload.ScenarioLabel else "P0"
	benchmarkElapsedAtStatus = math.max(0, tonumber(payload.ElapsedSeconds) or 0)
	benchmarkStatusReceivedAt = os.clock()
	benchmarkCampaignLabel = if typeof(payload.CampaignLabel) == "string" then payload.CampaignLabel else nil
	benchmarkCampaignIndex = if typeof(payload.CampaignIndex) == "number" then payload.CampaignIndex else nil
	benchmarkCampaignTotal = if typeof(payload.CampaignTotal) == "number" then payload.CampaignTotal else nil
	benchmarkStatusLabel.TextColor3 = if benchmarkPhase == "Completed"
		then Color3.fromRGB(145, 235, 170)
		elseif benchmarkPhase == "Cleanup"
			then Color3.fromRGB(255, 221, 150)
			else Color3.fromRGB(154, 212, 255)
	refreshBenchmarkStatusLabel()
	refreshBenchmarkControls()
end)

RunService.RenderStepped:Connect(function(deltaTime)
	if not benchmarkIsActive then
		benchmarkStatusRefreshElapsed = 0
		return
	end

	benchmarkStatusRefreshElapsed += deltaTime
	if benchmarkStatusRefreshElapsed >= 0.2 then
		benchmarkStatusRefreshElapsed = 0
		refreshBenchmarkStatusLabel()
	end
end)

debugLogStateRemote.OnClientEvent:Connect(function(payload)
	applyDebugLogState(payload)
end)

player:GetAttributeChangedSignal("CanUseAdminTools"):Connect(updateVisibility)
player:GetAttributeChangedSignal(DEV_KIT_PREVIEW_ATTRIBUTE):Connect(refreshDevKitPreviewButton)
updateVisibility()
refreshDevKitPreviewButton()
selectDefaultBenchmark()
refreshBenchmarkControls()

DebugLog.Info("UI", "UI admin initialisee", {
	Player = player.Name,
	Visible = screenGui.Enabled,
})
