local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ChestConfig = require(Shared:WaitForChild("ChestConfig"))
local DebugLog = require(Shared:WaitForChild("DebugLog"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local openRequestRemote = ReplicatedStorage:WaitForChild("Chest_OpenRequest")
local openResultRemote = ReplicatedStorage:WaitForChild("Chest_OpenResult")
local openFailedRemote = ReplicatedStorage:WaitForChild("Chest_OpenFailed")
local choiceRequestRemote = ReplicatedStorage:WaitForChild("Chest_ChoiceRequest")
local choiceResultRemote = ReplicatedStorage:WaitForChild("Chest_ChoiceResult")
local priceUpdateRemote = ReplicatedStorage:WaitForChild("Chest_PriceUpdate")

local trackedChests = {}
local currentPromptChest = nil
local pendingChest = nil
local activeOpeningId = nil
local isSlotPlaying = false
local currentOpenCost = ChestConfig.BaseOpenCost
-- Les coffres normaux utilisent un ProximityPrompt serveur, comme les jarres.
-- Ce bloc client reste disponible comme fallback, mais il ne dessine plus de label.
local CLIENT_CHEST_PROMPTS_ENABLED = false

local CHEST_UI_COLORS = UiTheme.Contexts.Chest

local addCorner = UiTheme.AddCorner
local addStroke = UiTheme.AddStroke

local function getChestContainer(instance)
	local current = instance

	while current ~= nil and current ~= Workspace do
		if current.Name == ChestConfig.ChestName then
			return current
		end

		current = current.Parent
	end

	return nil
end

local function findChestRoot(chest)
	if chest:IsA("BasePart") then
		return chest
	end

	if chest:IsA("Model") and chest.PrimaryPart ~= nil then
		return chest.PrimaryPart
	end

	return chest:FindFirstChildWhichIsA("BasePart", true)
end

local function resolveChest(instance)
	if typeof(instance) ~= "Instance" then
		return nil
	end

	local chest = getChestContainer(instance)

	if chest == nil or findChestRoot(chest) == nil then
		return nil
	end

	return chest
end

local function getChestBounds(chest)
	if chest:IsA("Model") then
		return chest:GetBoundingBox()
	end

	if chest:IsA("BasePart") then
		return chest.CFrame, chest.Size
	end

	local root = findChestRoot(chest)

	if root == nil then
		return CFrame.new(), Vector3.new(1, 2, 1)
	end

	return root.CFrame, root.Size
end

local function getChestHeight(chest)
	local _, size = getChestBounds(chest)

	return size.Y
end

local function getChestPosition(chest)
	local cframe = getChestBounds(chest)

	return cframe.Position
end

local function createPrompt(chest)
	local root = findChestRoot(chest)

	if root == nil then
		return nil
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ChestPrompt"
	billboard.Adornee = root
	billboard.AlwaysOnTop = true
	billboard.Enabled = false
	billboard.LightInfluence = 0
	billboard.MaxDistance = ChestConfig.PromptMaxDistance
	billboard.Size = UDim2.fromOffset(154, 34)
	billboard.StudsOffset = Vector3.new(0, (getChestHeight(chest) * 0.5) + ChestConfig.PromptHeightOffset, 0)
	billboard.Parent = root

	local frame = Instance.new("Frame")
	frame.Name = "Background"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(10, 12, 16)
	frame.BackgroundTransparency = 0.25
	frame.BorderSizePixel = 0
	frame.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Transparency = 0.76
	stroke.Thickness = 1
	stroke.Parent = frame

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.Text = "E pour ouvrir"
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextSize = 12
	label.TextWrapped = true
	label.Parent = frame

	return billboard, label
end

local function getPromptText()
	return ("E pour ouvrir - %d coins"):format(currentOpenCost)
end

local function updatePromptLabel(chestState)
	if chestState ~= nil and chestState.Label ~= nil then
		chestState.Label.Text = getPromptText()
	end
end

local function trackChest(instance)
	if not CLIENT_CHEST_PROMPTS_ENABLED then
		return
	end

	local chest = resolveChest(instance)

	if chest == nil then
		return
	end

	if trackedChests[chest] ~= nil then
		return
	end

	local prompt, label = createPrompt(chest)

	trackedChests[chest] = {
		Prompt = prompt,
		Label = label,
	}

	updatePromptLabel(trackedChests[chest])
	DebugLog.ThrottledInfo("UI", "chest_tracked", 2, "Coffre detecte cote client", {
		Chest = chest,
	})
end

local function getPlayerRoot()
	local character = player.Character

	if character == nil then
		return nil
	end

	return character:FindFirstChild("HumanoidRootPart")
end

local function isChestAvailable(chest)
	return chest.Parent ~= nil and chest:GetAttribute("ChestOpened") ~= true and chest:GetAttribute("ChestOpening") ~= true
end

local function setPromptVisible(chest, isVisible)
	local chestState = trackedChests[chest]

	if chestState == nil or chestState.Prompt == nil then
		return
	end

	chestState.Prompt.Enabled = isVisible
end

local function getClosestPromptChest()
	local playerRoot = getPlayerRoot()

	if playerRoot == nil or isSlotPlaying then
		return nil
	end

	local closestChest = nil
	local closestDistance = ChestConfig.PromptDistance

	for chest in pairs(trackedChests) do
		if chest.Parent == nil then
			trackedChests[chest] = nil
			continue
		end

		if isChestAvailable(chest) then
			local chestPosition = getChestPosition(chest)

			if chestPosition ~= nil then
				local distance = (playerRoot.Position - chestPosition).Magnitude

				if distance <= closestDistance then
					closestDistance = distance
					closestChest = chest
				end
			end
		end
	end

	return closestChest
end

local slotGui = Instance.new("ScreenGui")
slotGui.Name = "ChestSlotGui"
slotGui.ResetOnSpawn = false
slotGui.DisplayOrder = 18
slotGui.Enabled = false
slotGui.Parent = playerGui

local slotPanel = Instance.new("Frame")
slotPanel.Name = "Panel"
slotPanel.AnchorPoint = Vector2.new(0.5, 0.5)
slotPanel.Position = UDim2.fromScale(0.5, 0.38)
slotPanel.Size = UDim2.new(0.34, 0, 0, 174)
slotPanel.BackgroundColor3 = CHEST_UI_COLORS.Panel
slotPanel.BackgroundTransparency = 0.18
slotPanel.BorderSizePixel = 0
slotPanel.Parent = slotGui

local slotSizeConstraint = Instance.new("UISizeConstraint")
slotSizeConstraint.MinSize = Vector2.new(300, 174)
slotSizeConstraint.MaxSize = Vector2.new(480, 174)
slotSizeConstraint.Parent = slotPanel

local slotCorner = Instance.new("UICorner")
slotCorner.CornerRadius = UDim.new(0, 10)
slotCorner.Parent = slotPanel

local slotStroke = Instance.new("UIStroke")
slotStroke.Color = CHEST_UI_COLORS.Accent
slotStroke.Transparency = 0.3
slotStroke.Thickness = 1.5
slotStroke.Parent = slotPanel
addStroke(slotPanel, Color3.fromRGB(7, 12, 19), 0.16, 4)

local slotGradient = Instance.new("UIGradient")
slotGradient.Rotation = 90
slotGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, CHEST_UI_COLORS.PanelTop),
	ColorSequenceKeypoint.new(1, CHEST_UI_COLORS.Panel),
})
slotGradient.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.12),
	NumberSequenceKeypoint.new(1, 0.34),
})
slotGradient.Parent = slotPanel
UiTheme.AddSurfaceFinish(slotPanel, {
	Accent = CHEST_UI_COLORS.Accent,
	Intensity = 0.68,
})

local slotPadding = Instance.new("UIPadding")
slotPadding.PaddingTop = UDim.new(0, 12)
slotPadding.PaddingRight = UDim.new(0, 14)
slotPadding.PaddingBottom = UDim.new(0, 12)
slotPadding.PaddingLeft = UDim.new(0, 14)
slotPadding.Parent = slotPanel

local slotTitle = Instance.new("TextLabel")
slotTitle.Name = "Title"
slotTitle.Size = UDim2.new(1, 0, 0, 18)
slotTitle.BackgroundTransparency = 1
slotTitle.Font = Enum.Font.GothamBlack
slotTitle.Text = "Coffre"
slotTitle.TextColor3 = CHEST_UI_COLORS.Text
slotTitle.TextSize = 16
slotTitle.TextXAlignment = Enum.TextXAlignment.Center
slotTitle.Parent = slotPanel

local reelFrame = Instance.new("Frame")
reelFrame.Name = "Reel"
reelFrame.Position = UDim2.new(0, 0, 0, 30)
reelFrame.Size = UDim2.new(1, 0, 0, 42)
reelFrame.BackgroundColor3 = CHEST_UI_COLORS.PanelTop
reelFrame.BackgroundTransparency = 0.22
reelFrame.BorderSizePixel = 0
reelFrame.Parent = slotPanel

local reelCorner = Instance.new("UICorner")
reelCorner.CornerRadius = UDim.new(0, 6)
reelCorner.Parent = reelFrame
addStroke(reelFrame, CHEST_UI_COLORS.Accent, 0.46, 1)

local rewardIcon = Instance.new("ImageLabel")
rewardIcon.Name = "RewardIcon"
rewardIcon.Position = UDim2.fromOffset(7, 5)
rewardIcon.Size = UDim2.fromOffset(32, 32)
rewardIcon.BackgroundTransparency = 1
rewardIcon.Image = ""
rewardIcon.ScaleType = Enum.ScaleType.Fit
rewardIcon.Parent = reelFrame

local reelLabel = Instance.new("TextLabel")
reelLabel.Name = "RewardName"
reelLabel.Position = UDim2.fromOffset(44, 0)
reelLabel.Size = UDim2.new(1, -51, 1, 0)
reelLabel.BackgroundTransparency = 1
reelLabel.Font = Enum.Font.GothamBold
reelLabel.Text = "..."
reelLabel.TextColor3 = CHEST_UI_COLORS.AccentLight
reelLabel.TextSize = 18
reelLabel.TextWrapped = true
reelLabel.TextXAlignment = Enum.TextXAlignment.Left
reelLabel.Parent = reelFrame

local slotSubtitle = Instance.new("TextLabel")
slotSubtitle.Name = "Subtitle"
slotSubtitle.Position = UDim2.new(0, 0, 0, 82)
slotSubtitle.Size = UDim2.new(1, 0, 0, 20)
slotSubtitle.BackgroundTransparency = 1
slotSubtitle.Font = Enum.Font.GothamMedium
slotSubtitle.Text = "Ouverture..."
slotSubtitle.TextColor3 = CHEST_UI_COLORS.Muted
slotSubtitle.TextSize = 12
slotSubtitle.TextXAlignment = Enum.TextXAlignment.Center
slotSubtitle.Parent = slotPanel

local buttonRow = Instance.new("Frame")
buttonRow.Name = "ButtonRow"
buttonRow.Position = UDim2.new(0, 0, 1, -38)
buttonRow.Size = UDim2.new(1, 0, 0, 32)
buttonRow.BackgroundTransparency = 1
buttonRow.Visible = false
buttonRow.Parent = slotPanel

local skipButton = Instance.new("TextButton")
skipButton.Name = "SkipButton"
skipButton.Position = UDim2.new(0, 0, 0, 0)
skipButton.Size = UDim2.new(0.5, -5, 1, 0)
skipButton.BackgroundColor3 = CHEST_UI_COLORS.PanelTop
skipButton.BackgroundTransparency = 0.2
skipButton.BorderSizePixel = 0
skipButton.Font = Enum.Font.GothamBold
skipButton.Text = "Passer"
skipButton.TextColor3 = Color3.fromRGB(235, 240, 250)
skipButton.TextSize = 13
skipButton.Parent = buttonRow

local skipCorner = Instance.new("UICorner")
skipCorner.CornerRadius = UDim.new(0, 6)
skipCorner.Parent = skipButton
addStroke(skipButton, Color3.fromRGB(238, 245, 255), 0.58, 1)

local acceptButton = Instance.new("TextButton")
acceptButton.Name = "AcceptButton"
acceptButton.Position = UDim2.new(0.5, 5, 0, 0)
acceptButton.Size = UDim2.new(0.5, -5, 1, 0)
acceptButton.BackgroundColor3 = CHEST_UI_COLORS.Accent
acceptButton.BackgroundTransparency = 0.22
acceptButton.BorderSizePixel = 0
acceptButton.Font = Enum.Font.GothamBold
acceptButton.Text = "Valider"
acceptButton.TextColor3 = Color3.fromRGB(255, 255, 255)
acceptButton.TextSize = 13
acceptButton.Parent = buttonRow

local acceptCorner = Instance.new("UICorner")
acceptCorner.CornerRadius = UDim.new(0, 6)
acceptCorner.Parent = acceptButton
addStroke(acceptButton, CHEST_UI_COLORS.AccentLight, 0.32, 1)

local function setDecisionButtonsEnabled(isEnabled)
	skipButton.Active = isEnabled
	skipButton.AutoButtonColor = isEnabled
	acceptButton.Active = isEnabled
	acceptButton.AutoButtonColor = isEnabled
end

local function closeSlotUi()
	if currentPromptChest ~= nil then
		setPromptVisible(currentPromptChest, false)
	end

	slotGui.Enabled = false
	buttonRow.Visible = false
	setDecisionButtonsEnabled(true)
	isSlotPlaying = false
	currentPromptChest = nil
	pendingChest = nil
	activeOpeningId = nil
end

local function setDisplayedReward(reward)
	if typeof(reward) == "table" then
		reelLabel.Text = tostring(reward.Name or "Objet mystere")
		rewardIcon.Image = tostring(reward.Icon or "")
		return
	end

	reelLabel.Text = tostring(reward or "Objet mystere")
	rewardIcon.Image = ""
end

local function playSlotAnimation(payload)
	payload = payload or {}

	local reward = payload.Reward or {
		Name = "Objet mystere",
		Description = "Objet a venir",
	}
	local spinItems = payload.SpinItems or { reward.Name }

	if #spinItems <= 0 then
		spinItems = { reward.Name }
	end

	local duration = payload.Duration or ChestConfig.SlotDuration
	local startedAt = os.clock()
	local nextTickAt = startedAt
	local currentIndex = 0

	activeOpeningId = payload.OpeningId
	isSlotPlaying = true
	slotGui.Enabled = true
	buttonRow.Visible = false
	setDecisionButtonsEnabled(false)
	slotTitle.Text = "Coffre ouvert"
	if payload.IsRewardChest then
		slotSubtitle.Text = "Recompense elite"
	else
		slotSubtitle.Text = ("Ouverture : %d coins"):format(payload.Cost or currentOpenCost)
	end

	while os.clock() - startedAt < duration do
		local elapsed = os.clock() - startedAt
		local progress = math.clamp(elapsed / duration, 0, 1)
		local interval = ChestConfig.SlotMinInterval
			+ ((ChestConfig.SlotMaxInterval - ChestConfig.SlotMinInterval) * progress)

		if os.clock() >= nextTickAt then
			currentIndex = (currentIndex % #spinItems) + 1
			setDisplayedReward(spinItems[currentIndex])
			nextTickAt = os.clock() + interval
		end

		RunService.RenderStepped:Wait()
	end

	setDisplayedReward(reward)
	slotSubtitle.Text = tostring(reward.Description or "Objet a venir")
	buttonRow.Visible = true
	setDecisionButtonsEnabled(true)
end

local function showOpenFailed(payload)
	payload = payload or {}

	if payload.NextOpenCost ~= nil then
		currentOpenCost = payload.NextOpenCost
	end

	for _, chestState in pairs(trackedChests) do
		updatePromptLabel(chestState)
	end

	isSlotPlaying = true
	slotGui.Enabled = true
	buttonRow.Visible = false
	slotTitle.Text = "Coffre"
	reelLabel.Text = "Ouverture impossible"

	if payload.Reason == "NotEnoughCoins" then
		slotSubtitle.Text = ("Il faut %d coins."):format(payload.NextOpenCost or currentOpenCost)
	elseif payload.Reason == "NoEligibleReward" then
		slotSubtitle.Text = "Aucune recompense disponible."
	else
		slotSubtitle.Text = "Rapproche-toi du coffre."
	end

	task.delay(1.2, function()
		if activeOpeningId == nil then
			closeSlotUi()
		end
	end)
end

local function submitChoice(action)
	if activeOpeningId == nil then
		return
	end

	setDecisionButtonsEnabled(false)
	slotSubtitle.Text = "Validation..."
	choiceRequestRemote:FireServer(activeOpeningId, action)
end

for _, descendant in ipairs(Workspace:GetDescendants()) do
	trackChest(descendant)
end

Workspace.DescendantAdded:Connect(function(descendant)
	task.defer(function()
		trackChest(descendant)
	end)
end)

Workspace.DescendantRemoving:Connect(function(descendant)
	local chestState = trackedChests[descendant]

	if chestState ~= nil and chestState.Prompt ~= nil then
		chestState.Prompt:Destroy()
	end

	trackedChests[descendant] = nil
end)

RunService.RenderStepped:Connect(function()
	if not CLIENT_CHEST_PROMPTS_ENABLED then
		return
	end

	local closestChest = getClosestPromptChest()

	if closestChest == currentPromptChest then
		return
	end

	if currentPromptChest ~= nil then
		setPromptVisible(currentPromptChest, false)
	end

	currentPromptChest = closestChest

	if currentPromptChest ~= nil then
		setPromptVisible(currentPromptChest, true)
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if not CLIENT_CHEST_PROMPTS_ENABLED then
		return
	end

	if gameProcessed or input.KeyCode ~= Enum.KeyCode.E then
		return
	end

	if currentPromptChest == nil or pendingChest ~= nil then
		return
	end

	pendingChest = currentPromptChest
	setPromptVisible(pendingChest, false)
	DebugLog.Info("UI", "Demande ouverture coffre envoyee", {
		Chest = pendingChest,
		Cost = currentOpenCost,
	})
	openRequestRemote:FireServer(pendingChest)

	local requestedChest = pendingChest

	task.delay(1.2, function()
		if pendingChest == requestedChest and not isSlotPlaying then
			pendingChest = nil
		end
	end)
end)

skipButton.Activated:Connect(function()
	submitChoice("Skip")
end)

acceptButton.Activated:Connect(function()
	submitChoice("Accept")
end)

openResultRemote.OnClientEvent:Connect(function(payload)
	payload = payload or {}
	DebugLog.Info("UI", "Ouverture coffre recue cote client", {
		OpeningId = payload.OpeningId,
		Cost = payload.Cost,
	})

	if payload.Chest ~= nil then
		setPromptVisible(payload.Chest, false)
	end

	task.spawn(function()
		playSlotAnimation(payload)
	end)
end)

openFailedRemote.OnClientEvent:Connect(function(payload)
	DebugLog.Info("UI", "Ouverture coffre refusee cote client", payload)
	showOpenFailed(payload)
end)

choiceResultRemote.OnClientEvent:Connect(function(payload)
	payload = payload or {}
	DebugLog.Info("UI", "Choix coffre termine cote client", payload)

	if payload.NextOpenCost ~= nil then
		currentOpenCost = payload.NextOpenCost
	end

	for _, chestState in pairs(trackedChests) do
		updatePromptLabel(chestState)
	end

	if payload.Accepted then
		local stacks = math.max(1, math.floor(tonumber(payload.ItemCount) or 1))
		slotSubtitle.Text = "Objet equipe - x" .. tostring(stacks)
	else
		slotSubtitle.Text = "Objet passe."
	end

	-- Laisse le joueur lire le stack obtenu avant la reprise de la run.
	task.delay(0.75, closeSlotUi)
end)

priceUpdateRemote.OnClientEvent:Connect(function(payload)
	payload = payload or {}

	if payload.NextOpenCost ~= nil then
		currentOpenCost = payload.NextOpenCost
	end

	for _, chestState in pairs(trackedChests) do
		updatePromptLabel(chestState)
	end
end)

DebugLog.Info("UI", "UI coffre initialisee", {
	Player = player.Name,
	BaseOpenCost = currentOpenCost,
})
