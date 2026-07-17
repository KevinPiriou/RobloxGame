--!strict

-- Adapte le composant visuel V2 de coffre aux donnees deja decidees par le
-- serveur. Le client ne choisit ni la recompense ni la consommation de credits.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DebugLog = require(Shared:WaitForChild("DebugLog"))
local UiTemplateConfig = require(Shared:WaitForChild("UiTemplateConfig"))

local openResultRemote = ReplicatedStorage:WaitForChild("Chest_OpenResult")
local openFailedRemote = ReplicatedStorage:WaitForChild("Chest_OpenFailed")
local choiceRequestRemote = ReplicatedStorage:WaitForChild("Chest_ChoiceRequest")
local choiceResultRemote = ReplicatedStorage:WaitForChild("Chest_ChoiceResult")

local V2_GUI_NAME = "ItemRevealV2"
local PRODUCTION_TEMPLATE_GUI_NAME = UiTemplateConfig.ProductionTemplateGuiName

local RARITY_COLORS = {
	Common = Color3.fromRGB(80, 220, 120),
	Rare = Color3.fromRGB(80, 155, 255),
	Epic = Color3.fromRGB(185, 95, 255),
	Legendary = Color3.fromRGB(255, 245, 99),
}

local ACTION_COLORS = {
	Continue = Color3.fromRGB(160, 71, 230),
	Pass = Color3.fromRGB(40, 223, 248),
	Ban = Color3.fromRGB(248, 60, 76),
}

local function asFrame(instance: Instance?): Frame?
	if instance and instance:IsA("Frame") then
		return instance
	end

	return nil
end

local function asTextLabel(instance: Instance?): TextLabel?
	if instance and instance:IsA("TextLabel") then
		return instance
	end

	return nil
end

local function asImageLabel(instance: Instance?): ImageLabel?
	if instance and instance:IsA("ImageLabel") then
		return instance
	end

	return nil
end

local function asButton(instance: Instance?): TextButton?
	if instance and instance:IsA("TextButton") then
		return instance
	end

	return nil
end

local function findPath(root: Instance?, names: { string }): Instance?
	local current = root

	for _, name in ipairs(names) do
		current = current and current:FindFirstChild(name)

		if current == nil then
			return nil
		end
	end

	return current
end

local function setText(instance: Instance?, value: unknown)
	local label = asTextLabel(instance)

	if label then
		label.Text = tostring(value or "")
	end
end

local function getRarityColor(rarity: unknown, fallback: unknown): Color3
	if typeof(rarity) == "string" and RARITY_COLORS[rarity] then
		return RARITY_COLORS[rarity]
	end

	if typeof(fallback) == "Color3" then
		return fallback
	end

	return RARITY_COLORS.Common
end

local function setStrokeColor(instance: Instance?, color: Color3)
	local stroke = instance and instance:FindFirstChild("RarityStroke")

	if stroke and stroke:IsA("UIStroke") then
		stroke.Color = color
	end
end

local function tween(instance: Instance?, duration: number, properties: { [string]: unknown })
	if instance == nil then
		return
	end

	TweenService:Create(instance, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), properties):Play()
end

type Reward = {
	Id: string?,
	Name: string?,
	Description: string?,
	Icon: string?,
	Rarity: string?,
	Accent: Color3?,
}

local function initialise()
	local templateGui = playerGui:WaitForChild(PRODUCTION_TEMPLATE_GUI_NAME, 30)

	if templateGui == nil or not templateGui:IsA("ScreenGui") then
		DebugLog.Warn("UI", "Item reveal V2 non active, template de production introuvable")
		return
	end

	local template = findPath(templateGui, { "RunCanvas", "ItemRevealDock" })

	if template == nil or not template:IsA("Frame") then
		DebugLog.Warn("UI", "Item reveal V2 non active, ItemRevealDock invalide")
		return
	end

	local previousGui = playerGui:FindFirstChild(V2_GUI_NAME)

	if previousGui then
		previousGui:Destroy()
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = V2_GUI_NAME
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 21
	screenGui.Enabled = false
	screenGui.Parent = playerGui

	local overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.fromRGB(2, 5, 11)
	overlay.BackgroundTransparency = 0.36
	overlay.BorderSizePixel = 0
	overlay.Parent = screenGui

	local dock = template:Clone()
	dock.Name = "ItemRevealDockV2"
	dock.Visible = true
	dock:SetAttribute("ProductionBound", true)
	dock.Parent = overlay

	templateGui.Enabled = false

	local panel = asFrame(dock:FindFirstChild("ItemRevealPanel"))
	local content = panel and asFrame(panel:FindFirstChild("Content"))
	local reelStage = content and asFrame(content:FindFirstChild("ReelStage"))
	local reelSlots = content and asFrame(findPath(content, { "ReelStage", "ReelViewport", "ReelSlots" }))
	local revealCard = content and asFrame(content:FindFirstChild("RevealCard"))
	local titleLabel = content and asTextLabel(content:FindFirstChild("Title"))
	local subtitleLabel = content and asTextLabel(content:FindFirstChild("Subtitle"))
	local actionRow = content and asFrame(content:FindFirstChild("ActionRow"))
	local continueButton = content and asButton(findPath(content, { "ActionRow", "ButtonRow", "Continue" }))
	local passButton = content and asButton(findPath(content, { "ActionRow", "ButtonRow", "Pass" }))
	local banButton = content and asButton(findPath(content, { "ActionRow", "ButtonRow", "Ban" }))

	if
		panel == nil
		or content == nil
		or reelStage == nil
		or reelSlots == nil
		or revealCard == nil
		or titleLabel == nil
		or subtitleLabel == nil
		or actionRow == nil
		or continueButton == nil
		or passButton == nil
		or banButton == nil
	then
		DebugLog.Warn("UI", "Item reveal V2 non active, hierarchie du kit incomplete")
		screenGui:Destroy()
		return
	end

	local reelSlotFrames = {}

	for index = 1, 5 do
		local slot = asFrame(reelSlots:FindFirstChild("Slot" .. tostring(index)))

		if slot then
			reelSlotFrames[index] = slot
		end
	end

	local cardIcon = asImageLabel(findPath(revealCard, { "IconFrame", "Icon" }))
	local cardRarity = asTextLabel(findPath(revealCard, { "ResultContent", "Rarity" }))
	local cardItemName = asTextLabel(findPath(revealCard, { "ResultContent", "ItemName" }))
	local cardDescription = asTextLabel(findPath(revealCard, { "ResultContent", "Description" }))
	local cardStack = asTextLabel(findPath(revealCard, { "ResultContent", "StackText" }))
	local selectionMarker = asFrame(findPath(content, { "ReelStage", "ReelViewport", "SelectionMarker" }))

	local activeOpeningId: string? = nil
	local isChoiceSubmitting = false

	if selectionMarker then
		selectionMarker.BackgroundTransparency = 1
		local markerStroke = selectionMarker:FindFirstChild("GlowStroke")
		if markerStroke and markerStroke:IsA("UIStroke") then
			markerStroke.Color = Color3.fromRGB(245, 246, 255)
		end

		for _, capName in ipairs({ "TopCap", "BottomCap" }) do
			local cap = asFrame(selectionMarker:FindFirstChild(capName))
			if cap then
				cap.BackgroundColor3 = Color3.fromRGB(245, 246, 255)
			end
		end
	end

	local function getCreditCount(attributeName: string): number
		return math.max(0, math.floor(tonumber(player:GetAttribute(attributeName)) or 0))
	end

	local function getCreditMaximum(attributeName: string): number
		return math.max(0, math.floor(tonumber(player:GetAttribute(attributeName)) or 0))
	end

	local function setActionState(
		button: TextButton,
		state: "Available" | "Consumed" | "Disabled",
		color: Color3,
		label: string,
		charges: number
	)
		button.Text = label
		button.Active = state == "Available"
		button.AutoButtonColor = state == "Available"
		button.TextColor3 = if state == "Disabled" then Color3.fromRGB(96, 99, 118) else Color3.fromRGB(245, 246, 255)
		button.BackgroundTransparency = if state == "Available" then 0.08 else 0.38
		button:SetAttribute("ActionState", state)
		button:SetAttribute("Charges", charges)

		local stroke = button:FindFirstChild("ActionStroke")
		if stroke and stroke:IsA("UIStroke") then
			stroke.Color = color
			stroke.Transparency = if state == "Available" then 0.12 else 0.58
		end

		local glow = asFrame(button:FindFirstChild("AccentGlow"))
		if glow then
			glow.BackgroundColor3 = color
			glow.BackgroundTransparency = if state == "Available" then 0.7 else 0.9
		end

		local pips = asFrame(button:FindFirstChild("ChargePips"))
		if pips then
			local pipIndex = 0
			for _, pip in ipairs(pips:GetChildren()) do
				if pip:IsA("Frame") then
					pipIndex += 1
					pip.BackgroundColor3 = color
					pip.BackgroundTransparency = if state == "Available" and pipIndex <= charges then 0.04 else 0.82
				end
			end
		end
	end

	local function refreshActions()
		local passCredits = getCreditCount("RunPassCredits")
		local passMaximum = getCreditMaximum("RunPassCreditsMax")
		local banCredits = getCreditCount("RunBanCredits")
		local banMaximum = getCreditMaximum("RunBanCreditsMax")

		setActionState(continueButton, "Available", ACTION_COLORS.Continue, "CONTINUER", 0)
		setActionState(
			passButton,
			if passCredits > 0 then "Available" else "Consumed",
			ACTION_COLORS.Pass,
			("PASSER (%d/%d)"):format(passCredits, passMaximum),
			passCredits
		)
		setActionState(
			banButton,
			if banCredits > 0 then "Available" else "Consumed",
			ACTION_COLORS.Ban,
			("BANNIR (%d/%d)"):format(banCredits, banMaximum),
			banCredits
		)
	end

	local function setSlotItem(slot: Frame, item: Reward, isSelected: boolean)
		local rarityColor = getRarityColor(item.Rarity, item.Accent)
		local icon = asImageLabel(slot:FindFirstChild("Icon"))
		local rarity = asTextLabel(slot:FindFirstChild("Rarity"))

		if icon then
			icon.Image = tostring(item.Icon or "")
		end

		if rarity then
			rarity.Text = string.upper(tostring(item.Rarity or "COMMUN"))
			rarity.TextColor3 = rarityColor
		end

		setStrokeColor(slot, rarityColor)
		local materialLayer = asFrame(slot:FindFirstChild("MaterialLayer"))
		if materialLayer then
			materialLayer.BackgroundColor3 = rarityColor
			materialLayer.BackgroundTransparency = if isSelected then 0.88 else 0.94
		end
	end

	local function setReelItems(items: { Reward }, selectedIndex: number)
		if #items == 0 then
			return
		end

		for index, slot in ipairs(reelSlotFrames) do
			local itemIndex = ((selectedIndex + index - 3 - 1) % #items) + 1
			setSlotItem(slot, items[itemIndex], index == 3)
		end
	end

	local function showRevealCard(reward: Reward, isNewItem: boolean, itemCount: number?)
		local rarityColor = getRarityColor(reward.Rarity, reward.Accent)

		if cardIcon then
			cardIcon.Image = tostring(reward.Icon or "")
		end

		setText(cardRarity, string.upper(tostring(reward.Rarity or "COMMUN")))
		setText(cardItemName, reward.Name or "Objet mystere")
		setText(cardDescription, reward.Description or "Objet permanent pour cette run")

		if cardRarity then
			cardRarity.TextColor3 = rarityColor
		end

		if cardStack then
			if isNewItem then
				cardStack.Text = "NOUVEL OBJET  x1"
			else
				cardStack.Text = "OBJET CUMULE  x" .. tostring(math.max(1, math.floor(tonumber(itemCount) or 1)))
			end
			cardStack.TextColor3 = rarityColor
		end

		setStrokeColor(revealCard, rarityColor)
		local iconFrame = asFrame(revealCard:FindFirstChild("IconFrame"))
		setStrokeColor(iconFrame, rarityColor)

		local materialLayer = asFrame(revealCard:FindFirstChild("MaterialLayer"))
		if materialLayer then
			materialLayer.BackgroundColor3 = rarityColor
			materialLayer.BackgroundTransparency = 0.93
		end

		revealCard.Visible = true
		actionRow.Visible = true
		-- Le rouleau appartient exclusivement a la phase de tirage. Une fois
		-- l'objet revele, il disparait pour ne laisser que la recompense lisible.
		reelStage.Visible = false
		revealCard.BackgroundTransparency = 1
		tween(revealCard, 0.18, { BackgroundTransparency = 0.12 })
	end

	local function resetPresentation()
		revealCard.Visible = false
		actionRow.Visible = false
		reelStage.Visible = true
		titleLabel.Text = "OBJET TROUVE"
		subtitleLabel.Text = "Le coffre revele un objet permanent pour cette run"
		refreshActions()
	end

	local function closePresentation()
		activeOpeningId = nil
		isChoiceSubmitting = false
		screenGui.Enabled = false
		revealCard.Visible = false
		actionRow.Visible = false
	end

	local function playReel(payload)
		local reward = (payload.Reward or {}) :: Reward
		local rawSpinItems = payload.SpinItems
		local spinItems: { Reward } = {}

		if typeof(rawSpinItems) == "table" then
			for _, item in ipairs(rawSpinItems) do
				if typeof(item) == "table" then
					table.insert(spinItems, item :: Reward)
				end
			end
		end

		if #spinItems == 0 then
			spinItems = { reward }
		end

		activeOpeningId = tostring(payload.OpeningId or "")
		isChoiceSubmitting = false
		screenGui.Enabled = true
		resetPresentation()
		titleLabel.Text = if payload.IsRewardChest then "RECOMPENSE ELITE" else "COFFRE OUVERT"
		subtitleLabel.Text = "Les reliques tournent..."

		local duration = math.max(0.5, tonumber(payload.Duration) or 2.4)
		local startedAt = os.clock()
		local nextStepAt = startedAt
		local selectedIndex = 1

		while os.clock() - startedAt < duration do
			local elapsed = os.clock() - startedAt
			local progress = math.clamp(elapsed / duration, 0, 1)
			local interval = 0.025 + (progress ^ 3.2) * 0.18

			if os.clock() >= nextStepAt then
				selectedIndex = (selectedIndex % #spinItems) + 1
				setReelItems(spinItems, selectedIndex)
				nextStepAt = os.clock() + interval
			end

			task.wait()
		end

		setReelItems({ reward }, 1)
		subtitleLabel.Text = "Objet revele"
		task.wait(0.35)
		showRevealCard(reward, false, nil)
	end

	local function submitChoice(action: string)
		if activeOpeningId == nil or activeOpeningId == "" or isChoiceSubmitting then
			return
		end

		isChoiceSubmitting = true
		setActionState(continueButton, "Disabled", ACTION_COLORS.Continue, "CONTINUER", 0)
		setActionState(passButton, "Disabled", ACTION_COLORS.Pass, passButton.Text, getCreditCount("RunPassCredits"))
		setActionState(banButton, "Disabled", ACTION_COLORS.Ban, banButton.Text, getCreditCount("RunBanCredits"))
		choiceRequestRemote:FireServer(activeOpeningId, action)
	end

	continueButton.Activated:Connect(function()
		submitChoice("Accept")
	end)

	passButton.Activated:Connect(function()
		submitChoice("Pass")
	end)

	banButton.Activated:Connect(function()
		submitChoice("Ban")
	end)

	openResultRemote.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end

		task.spawn(function()
			playReel(payload)
		end)
	end)

	openFailedRemote.OnClientEvent:Connect(function(payload)
		if typeof(payload) == "table" and payload.Reason == "OpeningAlreadyActive" then
			return
		end

		closePresentation()
	end)

	choiceResultRemote.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end

		if activeOpeningId == nil then
			return
		end

		local reward = (payload.Reward or {}) :: Reward
		showRevealCard(reward, payload.IsNewItem == true, payload.ItemCount)
		subtitleLabel.Text = if payload.Accepted then "Objet ajoute a votre run" else "Choix confirme"
		isChoiceSubmitting = false

		-- La confirmation serveur apporte le vrai statut « nouveau » ou « cumule ».
		-- On le laisse visible assez longtemps pour que ce retour ait une valeur.
		task.delay(0.75, function()
			closePresentation()
		end)
	end)

	player:GetAttributeChangedSignal("RunPassCredits"):Connect(refreshActions)
	player:GetAttributeChangedSignal("RunPassCreditsMax"):Connect(refreshActions)
	player:GetAttributeChangedSignal("RunBanCredits"):Connect(refreshActions)
	player:GetAttributeChangedSignal("RunBanCreditsMax"):Connect(refreshActions)

	refreshActions()
	playerGui:SetAttribute("ItemRevealV2Ready", true)

	DebugLog.Info("UI", "Item reveal V2 initialise", {
		Player = player.Name,
		Template = PRODUCTION_TEMPLATE_GUI_NAME,
	})
end

initialise()
