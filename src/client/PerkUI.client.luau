local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local DebugLog = require(Shared:WaitForChild("DebugLog"))
local PerkIconConfig = require(Shared:WaitForChild("PerkIconConfig"))

local showChoicesRemote = ReplicatedStorage:WaitForChild("Perk_ShowChoices")
local hideChoicesRemote = ReplicatedStorage:WaitForChild("Perk_HideChoices")
local selectChoiceRemote = ReplicatedStorage:WaitForChild("Perk_SelectChoice")

local existingGui = playerGui:FindFirstChild("PerkChoiceGui")

if existingGui ~= nil then
	existingGui:Destroy()
end

local COLORS = {
	Overlay = Color3.fromRGB(4, 7, 12),
	Panel = Color3.fromRGB(17, 27, 39),
	PanelTop = Color3.fromRGB(37, 51, 70),
	Card = Color3.fromRGB(20, 34, 48),
	CardHover = Color3.fromRGB(32, 48, 66),
	Text = Color3.fromRGB(245, 248, 255),
	Muted = Color3.fromRGB(181, 194, 211),
	Preview = Color3.fromRGB(221, 230, 241),
	PreviewCurrent = Color3.fromRGB(163, 177, 195),
	Purple = Color3.fromRGB(180, 91, 255),
	PurpleLight = Color3.fromRGB(224, 171, 255),
}

local TWEEN_FAST = TweenInfo.new(0.13, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_HOVER = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function createLabel(parent, name, text, font, textSize, color)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Font = font
	label.Text = text
	label.TextColor3 = color
	label.TextSize = textSize
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0.58
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = parent

	return label
end

local function addCorner(instance, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance

	return corner
end

local function addStroke(instance, color, transparency, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Transparency = transparency
	stroke.Thickness = thickness
	stroke.Parent = instance

	return stroke
end

local function createGradient(parent)
	local gradient = Instance.new("UIGradient")
	gradient.Name = "RarityGradient"
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(COLORS.Card, COLORS.Card)
	gradient.Parent = parent

	return gradient
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PerkChoiceGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 20
screenGui.Enabled = false
screenGui.Parent = playerGui

local overlay = Instance.new("Frame")
overlay.Name = "Overlay"
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = COLORS.Overlay
overlay.BackgroundTransparency = 0.42
overlay.BorderSizePixel = 0
overlay.Parent = screenGui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.new(0.59, 0, 0.5, 0)
panel.Size = UDim2.new(0.66, 0, 0, 446)
panel.BackgroundColor3 = COLORS.Panel
panel.BackgroundTransparency = 0.2
panel.BorderSizePixel = 0
panel.ClipsDescendants = false
panel.Parent = overlay
addCorner(panel, 10)
addStroke(panel, Color3.fromRGB(7, 12, 19), 0.16, 4)
addStroke(panel, COLORS.Purple, 0.3, 1)

local panelGradient = Instance.new("UIGradient")
panelGradient.Rotation = 90
panelGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(42, 48, 65)),
	ColorSequenceKeypoint.new(0.19, COLORS.PanelTop),
	ColorSequenceKeypoint.new(0.42, COLORS.Panel),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(8, 11, 18)),
})
panelGradient.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.08),
	NumberSequenceKeypoint.new(1, 0.32),
})
panelGradient.Parent = panel

local panelSizeConstraint = Instance.new("UISizeConstraint")
panelSizeConstraint.MinSize = Vector2.new(320, 340)
panelSizeConstraint.MaxSize = Vector2.new(960, 466)
panelSizeConstraint.Parent = panel

local titleGemOuter = Instance.new("Frame")
titleGemOuter.Name = "TitleGemOuter"
titleGemOuter.AnchorPoint = Vector2.new(0.5, 0.5)
titleGemOuter.Position = UDim2.new(0.5, 0, 0, 0)
titleGemOuter.Size = UDim2.fromOffset(42, 42)
titleGemOuter.BackgroundColor3 = Color3.fromRGB(9, 11, 18)
titleGemOuter.BorderSizePixel = 0
titleGemOuter.Rotation = 45
titleGemOuter.ZIndex = 5
titleGemOuter.Parent = panel
addCorner(titleGemOuter, 6)
addStroke(titleGemOuter, COLORS.Purple, 0.14, 2)

local titleGem = Instance.new("Frame")
titleGem.Name = "TitleGem"
titleGem.AnchorPoint = Vector2.new(0.5, 0.5)
titleGem.Position = UDim2.new(0.5, 0, 0.5, 0)
titleGem.Size = UDim2.fromOffset(24, 24)
titleGem.BackgroundColor3 = COLORS.Purple
titleGem.BorderSizePixel = 0
titleGem.Rotation = 45
titleGem.ZIndex = 6
titleGem.Parent = titleGemOuter
addCorner(titleGem, 4)
addStroke(titleGem, COLORS.PurpleLight, 0.12, 1)

local titleLabel = createLabel(panel, "TitleLabel", "NIVEAU 1", Enum.Font.GothamBlack, 28, COLORS.Text)
titleLabel.Position = UDim2.fromOffset(22, 24)
titleLabel.Size = UDim2.new(1, -44, 0, 30)
titleLabel.TextXAlignment = Enum.TextXAlignment.Center

local subtitleLabel = createLabel(panel, "SubtitleLabel", "CHOISIS UNE AMELIORATION PERMANENTE", Enum.Font.GothamBold, 12, COLORS.PurpleLight)
subtitleLabel.Position = UDim2.fromOffset(22, 57)
subtitleLabel.Size = UDim2.new(1, -44, 0, 20)
subtitleLabel.TextXAlignment = Enum.TextXAlignment.Center

local divider = Instance.new("Frame")
divider.Name = "Divider"
divider.Position = UDim2.new(0, 22, 0, 90)
divider.Size = UDim2.new(1, -44, 0, 1)
divider.BackgroundColor3 = COLORS.PurpleLight
divider.BackgroundTransparency = 0.7
divider.BorderSizePixel = 0
divider.Parent = panel

local optionsFrame = Instance.new("ScrollingFrame")
optionsFrame.Name = "Options"
optionsFrame.Position = UDim2.fromOffset(18, 108)
optionsFrame.Size = UDim2.new(1, -36, 1, -126)
optionsFrame.BackgroundTransparency = 1
optionsFrame.BorderSizePixel = 0
optionsFrame.CanvasSize = UDim2.fromOffset(0, 0)
optionsFrame.ScrollBarThickness = 4
optionsFrame.ScrollBarImageTransparency = 0.35
optionsFrame.ScrollBarImageColor3 = Color3.fromRGB(255, 255, 255)
optionsFrame.ScrollingEnabled = false
optionsFrame.Parent = panel

local optionsLayout = Instance.new("UIListLayout")
optionsLayout.FillDirection = Enum.FillDirection.Horizontal
optionsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
optionsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
optionsLayout.Padding = UDim.new(0, 10)
optionsLayout.SortOrder = Enum.SortOrder.LayoutOrder
optionsLayout.Parent = optionsFrame

local currentChoiceId = nil
local isSubmitting = false
local optionButtons = {}

local function setEntryHover(entry, isHovered)
	if entry.Option == nil or isSubmitting then
		return
	end

	TweenService:Create(entry.Button, TWEEN_HOVER, {
		BackgroundColor3 = if isHovered then COLORS.CardHover else COLORS.Card,
	}):Play()
	TweenService:Create(entry.Scale, TWEEN_HOVER, {
		Scale = if isHovered then 1.025 else 1,
	}):Play()
	TweenService:Create(entry.Stroke, TWEEN_HOVER, {
		Transparency = if isHovered then 0.05 else 0.22,
		Thickness = if isHovered then 2.5 else 2,
	}):Play()
end

local function createOptionButton(index)
	local button = Instance.new("TextButton")
	button.Name = "Option" .. tostring(index)
	button.Size = UDim2.new(0.333, -7, 1, 0)
	button.BackgroundColor3 = COLORS.Card
	button.BackgroundTransparency = 0.2
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Font = Enum.Font.GothamBold
	button.Text = ""
	button.Modal = true
	button.LayoutOrder = index
	button.Parent = optionsFrame
	addCorner(button, 8)

	local scale = Instance.new("UIScale")
	scale.Parent = button

	local gradient = createGradient(button)
	local stroke = addStroke(button, Color3.fromRGB(255, 255, 255), 0.22, 2)

	local accent = Instance.new("Frame")
	accent.Name = "Accent"
	accent.Size = UDim2.new(1, 0, 0, 5)
	accent.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	accent.BorderSizePixel = 0
	accent.Parent = button
	addCorner(accent, 7)

	local rarityChip = Instance.new("Frame")
	rarityChip.Name = "RarityChip"
	rarityChip.Position = UDim2.fromOffset(12, 14)
	rarityChip.Size = UDim2.fromOffset(88, 21)
	rarityChip.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	rarityChip.BackgroundTransparency = 0.78
	rarityChip.BorderSizePixel = 0
	rarityChip.Parent = button
	addCorner(rarityChip, 5)

	local rarityLabel = createLabel(rarityChip, "Rarity", "COMMUN", Enum.Font.GothamBold, 10, COLORS.Text)
	rarityLabel.Size = UDim2.fromScale(1, 1)
	rarityLabel.TextXAlignment = Enum.TextXAlignment.Center

	local stackLabel = createLabel(button, "Stack", "NIV. 0 -> 1", Enum.Font.GothamBold, 10, COLORS.Muted)
	stackLabel.AnchorPoint = Vector2.new(1, 0)
	stackLabel.Position = UDim2.new(1, -12, 0, 14)
	stackLabel.Size = UDim2.fromOffset(92, 21)
	stackLabel.TextXAlignment = Enum.TextXAlignment.Right

	local iconFrame = Instance.new("Frame")
	iconFrame.Name = "PerkIcon"
	iconFrame.AnchorPoint = Vector2.new(0.5, 0)
	iconFrame.Position = UDim2.new(0.5, 0, 0, 42)
	iconFrame.Size = UDim2.fromOffset(88, 88)
	iconFrame.BackgroundColor3 = Color3.fromRGB(6, 10, 16)
	iconFrame.BackgroundTransparency = 0.16
	iconFrame.BorderSizePixel = 0
	iconFrame.ClipsDescendants = true
	iconFrame.Parent = button
	addCorner(iconFrame, 44)
	local iconStroke = addStroke(iconFrame, Color3.fromRGB(255, 255, 255), 0.22, 2)

	local iconGlow = Instance.new("Frame")
	iconGlow.Name = "Glow"
	iconGlow.AnchorPoint = Vector2.new(0.5, 0.5)
	iconGlow.Position = UDim2.new(0.5, 0, 0.5, 0)
	iconGlow.Size = UDim2.fromScale(1.34, 1.34)
	iconGlow.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	iconGlow.BackgroundTransparency = 0.8
	iconGlow.BorderSizePixel = 0
	iconGlow.ZIndex = 0
	iconGlow.Parent = iconFrame
	addCorner(iconGlow, 60)

	local iconImage = Instance.new("ImageLabel")
	iconImage.Name = "Image"
	iconImage.AnchorPoint = Vector2.new(0.5, 0.5)
	iconImage.Position = UDim2.new(0.5, 0, 0.5, 0)
	iconImage.Size = UDim2.new(1, -6, 1, -6)
	iconImage.BackgroundTransparency = 1
	iconImage.Image = ""
	iconImage.ScaleType = Enum.ScaleType.Fit
	iconImage.ZIndex = 2
	iconImage.Parent = iconFrame

	local iconFallback = createLabel(iconFrame, "Fallback", "*", Enum.Font.GothamBlack, 40, COLORS.Text)
	iconFallback.Size = UDim2.fromScale(1, 1)
	iconFallback.TextXAlignment = Enum.TextXAlignment.Center
	iconFallback.ZIndex = 1

	local nameLabel = createLabel(button, "PerkName", "Perk", Enum.Font.GothamBold, 18, COLORS.Text)
	nameLabel.Position = UDim2.fromOffset(12, 138)
	nameLabel.Size = UDim2.new(1, -24, 0, 40)
	nameLabel.TextWrapped = true
	nameLabel.TextTruncate = Enum.TextTruncate.None
	nameLabel.TextXAlignment = Enum.TextXAlignment.Center
	nameLabel.TextYAlignment = Enum.TextYAlignment.Center

	local descriptionLabel = createLabel(button, "Description", "Description", Enum.Font.GothamMedium, 12, COLORS.Muted)
	descriptionLabel.Position = UDim2.fromOffset(12, 181)
	descriptionLabel.Size = UDim2.new(1, -24, 0, 31)
	descriptionLabel.TextWrapped = true
	descriptionLabel.TextTruncate = Enum.TextTruncate.None
	descriptionLabel.TextXAlignment = Enum.TextXAlignment.Center
	descriptionLabel.TextYAlignment = Enum.TextYAlignment.Top

	local previewHeader = createLabel(button, "PreviewHeader", "ACTUEL   ->   APRES CHOIX", Enum.Font.GothamBold, 9, COLORS.Muted)
	previewHeader.Position = UDim2.fromOffset(12, 218)
	previewHeader.Size = UDim2.new(1, -24, 0, 14)
	previewHeader.TextXAlignment = Enum.TextXAlignment.Center

	local previewFrame = Instance.new("Frame")
	previewFrame.Name = "Preview"
	previewFrame.Position = UDim2.fromOffset(12, 234)
	previewFrame.Size = UDim2.new(1, -24, 0, 45)
	previewFrame.BackgroundTransparency = 1
	previewFrame.BorderSizePixel = 0
	previewFrame.Parent = button

	local previewLayout = Instance.new("UIListLayout")
	previewLayout.FillDirection = Enum.FillDirection.Vertical
	previewLayout.Padding = UDim.new(0, 3)
	previewLayout.SortOrder = Enum.SortOrder.LayoutOrder
	previewLayout.Parent = previewFrame

	local footer = Instance.new("Frame")
	footer.Name = "Footer"
	footer.AnchorPoint = Vector2.new(0, 1)
	footer.Position = UDim2.new(0, 12, 1, -12)
	footer.Size = UDim2.new(1, -24, 0, 32)
	footer.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	footer.BackgroundTransparency = 0.72
	footer.BorderSizePixel = 0
	footer.Parent = button
	addCorner(footer, 6)
	local footerStroke = addStroke(footer, Color3.fromRGB(255, 255, 255), 0.4, 1)

	local footerLabel = createLabel(footer, "FooterLabel", "CHOISIR", Enum.Font.GothamBold, 12, COLORS.Text)
	footerLabel.Size = UDim2.fromScale(1, 1)
	footerLabel.TextXAlignment = Enum.TextXAlignment.Center

	local footerArrow = createLabel(footer, "FooterArrow", ">", Enum.Font.GothamBlack, 16, COLORS.Text)
	footerArrow.AnchorPoint = Vector2.new(1, 0)
	footerArrow.Position = UDim2.new(1, -10, 0, 6)
	footerArrow.Size = UDim2.fromOffset(18, 20)
	footerArrow.TextXAlignment = Enum.TextXAlignment.Right

	local entry = {
		Button = button,
		Scale = scale,
		Stroke = stroke,
		Gradient = gradient,
		Accent = accent,
		RarityChip = rarityChip,
		RarityLabel = rarityLabel,
		StackLabel = stackLabel,
		IconFrame = iconFrame,
		IconGlow = iconGlow,
		IconStroke = iconStroke,
		IconImage = iconImage,
		IconFallback = iconFallback,
		NameLabel = nameLabel,
		DescriptionLabel = descriptionLabel,
		PreviewFrame = previewFrame,
		Footer = footer,
		FooterStroke = footerStroke,
		FooterLabel = footerLabel,
		FooterArrow = footerArrow,
		Option = nil,
	}

	button.MouseEnter:Connect(function()
		setEntryHover(entry, true)
	end)

	button.MouseLeave:Connect(function()
		setEntryHover(entry, false)
	end)

	optionButtons[index] = entry
end

for index = 1, 3 do
	createOptionButton(index)
end

local function clearPreviewLines(entry)
	for _, child in ipairs(entry.PreviewFrame:GetChildren()) do
		if child.Name == "PreviewLine" then
			child:Destroy()
		end
	end
end

local function addPreviewLine(entry, line, index, rarityColor)
	local lineFrame = Instance.new("Frame")
	lineFrame.Name = "PreviewLine"
	lineFrame.Size = UDim2.new(1, 0, 0, 22)
	lineFrame.BackgroundColor3 = rarityColor
	lineFrame.BackgroundTransparency = 0.88
	lineFrame.BorderSizePixel = 0
	lineFrame.LayoutOrder = index
	lineFrame.Parent = entry.PreviewFrame
	addCorner(lineFrame, 4)

	local nameLabel = createLabel(lineFrame, "Name", line.Label or "Stat", Enum.Font.GothamMedium, 10, COLORS.Preview)
	nameLabel.Position = UDim2.fromOffset(6, 0)
	nameLabel.Size = UDim2.new(0.42, -6, 1, 0)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left

	local currentLabel = createLabel(lineFrame, "Current", line.Current or "-", Enum.Font.GothamBold, 10, COLORS.PreviewCurrent)
	currentLabel.Position = UDim2.new(0.42, 0, 0, 0)
	currentLabel.Size = UDim2.new(0.21, 0, 1, 0)
	currentLabel.TextXAlignment = Enum.TextXAlignment.Right

	local arrowLabel = createLabel(lineFrame, "Arrow", ">", Enum.Font.GothamBold, 11, rarityColor)
	arrowLabel.Position = UDim2.new(0.63, 0, 0, 0)
	arrowLabel.Size = UDim2.new(0.1, 0, 1, 0)
	arrowLabel.TextXAlignment = Enum.TextXAlignment.Center

	local nextLabel = createLabel(lineFrame, "Next", line.Next or "-", Enum.Font.GothamBold, 10, COLORS.Text)
	nextLabel.Position = UDim2.new(0.73, 0, 0, 0)
	nextLabel.Size = UDim2.new(0.27, -6, 1, 0)
	nextLabel.TextXAlignment = Enum.TextXAlignment.Right
end

local function setButtonsEnabled(isEnabled)
	for _, entry in ipairs(optionButtons) do
		entry.Button.Active = isEnabled
		entry.Button.Selectable = isEnabled

		if not isEnabled then
			TweenService:Create(entry.Button, TWEEN_FAST, {
				BackgroundTransparency = 0.34,
			}):Play()
		else
			TweenService:Create(entry.Button, TWEEN_FAST, {
				BackgroundTransparency = 0.2,
			}):Play()
		end
	end
end

local function getViewportSize()
	local camera = Workspace.CurrentCamera

	if camera == nil then
		return Vector2.new(1280, 720)
	end

	return camera.ViewportSize
end

local function updateResponsiveLayout()
	local viewportSize = getViewportSize()
	local useVerticalCards = viewportSize.X < 900

	if useVerticalCards then
		panel.Position = UDim2.new(0.5, 0, 0.5, 0)
		panel.Size = UDim2.new(0.9, 0, 0.84, 0)
		optionsLayout.FillDirection = Enum.FillDirection.Vertical
		optionsLayout.Padding = UDim.new(0, 8)
		optionsFrame.ScrollingEnabled = true
		optionsFrame.ScrollingDirection = Enum.ScrollingDirection.Y
		optionsFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
		optionsFrame.CanvasSize = UDim2.fromOffset(0, 0)

		for _, entry in ipairs(optionButtons) do
			entry.Button.Size = UDim2.new(1, -6, 0, 310)
		end
	else
		panel.Position = UDim2.new(0.59, 0, 0.5, 0)
		panel.Size = UDim2.new(0.66, 0, 0, 446)
		optionsLayout.FillDirection = Enum.FillDirection.Horizontal
		optionsLayout.Padding = UDim.new(0, 10)
		optionsFrame.ScrollingEnabled = false
		optionsFrame.AutomaticCanvasSize = Enum.AutomaticSize.None
		optionsFrame.CanvasSize = UDim2.fromOffset(0, 0)

		for _, entry in ipairs(optionButtons) do
			entry.Button.Size = UDim2.new(0.333, -7, 1, 0)
		end
	end
end

local function getTitle(payload)
	if payload.Title ~= nil and payload.Title ~= "" then
		return string.upper(tostring(payload.Title))
	end

	return "NIVEAU " .. tostring(payload.Level or "?")
end

local function hideChoices()
	currentChoiceId = nil
	isSubmitting = false
	screenGui.Enabled = false
	setButtonsEnabled(true)
	DebugLog.Info("Perks", "UI choix perk cachee", {
		Player = player.Name,
	})
end

local function showChoices(payload)
	payload = payload or {}
	local choices = payload.Choices or {}

	currentChoiceId = payload.ChoiceId
	isSubmitting = false
	titleLabel.Text = getTitle(payload)
	subtitleLabel.Text = "CHOISIS UNE AMELIORATION PERMANENTE"
	screenGui.Enabled = true
	setButtonsEnabled(true)
	updateResponsiveLayout()

	DebugLog.Info("Perks", "UI choix perk affichee", {
		Player = player.Name,
		ChoiceId = payload.ChoiceId,
		Title = payload.Title,
		Level = payload.Level,
		Choices = #choices,
	})

	for index, entry in ipairs(optionButtons) do
		local option = choices[index]
		entry.Option = option

		if option == nil then
			entry.Button.Visible = false
		else
			local rarityColor = option.RarityColor or Color3.fromRGB(255, 255, 255)
			local rarityName = string.upper(option.RarityName or option.Rarity or "Commun")

			entry.Button.Visible = true
			entry.RarityLabel.Text = rarityName
			entry.RarityLabel.TextColor3 = rarityColor
			entry.StackLabel.Text = ("NIV. %s -> %s"):format(option.CurrentStacks or 0, option.NextStacks or 1)
			entry.NameLabel.Text = option.Name or "Perk"
			entry.DescriptionLabel.Text = option.Description or ""
			entry.Accent.BackgroundColor3 = rarityColor
			entry.RarityChip.BackgroundColor3 = rarityColor
			entry.Stroke.Color = rarityColor
			entry.IconGlow.BackgroundColor3 = rarityColor
			entry.IconStroke.Color = rarityColor
			entry.FooterLabel.TextColor3 = rarityColor
			entry.FooterArrow.TextColor3 = rarityColor
			entry.Footer.BackgroundColor3 = rarityColor
			entry.FooterStroke.Color = rarityColor

			local iconAssetId = (PerkIconConfig.AssetIds or {})[option.PerkId] or ""
			entry.IconImage.Image = iconAssetId
			entry.IconImage.Visible = iconAssetId ~= ""
			entry.IconFallback.Visible = iconAssetId == ""
			entry.IconFallback.Text = string.upper(string.sub(option.Name or "P", 1, 1))
			entry.IconFallback.TextColor3 = rarityColor
			entry.Gradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, rarityColor:Lerp(COLORS.Card, 0.8)),
				ColorSequenceKeypoint.new(0.62, COLORS.Card),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 15, 24)),
			})

			clearPreviewLines(entry)

			local previewLines = option.PreviewLines or {}

			for previewIndex, line in ipairs(previewLines) do
				addPreviewLine(entry, line, previewIndex, rarityColor)
			end
		end
	end
end

for _, entry in ipairs(optionButtons) do
	entry.Button.Activated:Connect(function()
		if isSubmitting or currentChoiceId == nil or entry.Option == nil then
			return
		end

		isSubmitting = true
		setButtonsEnabled(false)
		DebugLog.Info("Perks", "UI choix perk envoye", {
			Player = player.Name,
			ChoiceId = currentChoiceId,
			OptionId = entry.Option.OptionId,
			PerkId = entry.Option.PerkId,
		})
		selectChoiceRemote:FireServer(currentChoiceId, entry.Option.OptionId)
	end)
end

showChoicesRemote.OnClientEvent:Connect(showChoices)
hideChoicesRemote.OnClientEvent:Connect(hideChoices)

if Workspace.CurrentCamera ~= nil then
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveLayout)
end

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	if Workspace.CurrentCamera ~= nil then
		Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveLayout)
	end

	updateResponsiveLayout()
end)

hideChoices()
updateResponsiveLayout()
