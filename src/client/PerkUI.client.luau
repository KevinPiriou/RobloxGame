local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local showChoicesRemote = ReplicatedStorage:WaitForChild("Perk_ShowChoices")
local hideChoicesRemote = ReplicatedStorage:WaitForChild("Perk_HideChoices")
local selectChoiceRemote = ReplicatedStorage:WaitForChild("Perk_SelectChoice")

local existingGui = playerGui:FindFirstChild("PerkChoiceGui")

if existingGui ~= nil then
	existingGui:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PerkChoiceGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 20
screenGui.Enabled = false
screenGui.Parent = playerGui

local overlay = Instance.new("Frame")
overlay.Name = "Overlay"
overlay.Size = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3 = Color3.fromRGB(8, 10, 14)
overlay.BackgroundTransparency = 0.28
overlay.BorderSizePixel = 0
overlay.Parent = screenGui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.new(0.5, 0, 0.5, 0)
panel.Size = UDim2.new(0.78, 0, 0, 310)
panel.BackgroundColor3 = Color3.fromRGB(22, 25, 31)
panel.BackgroundTransparency = 0.04
panel.BorderSizePixel = 0
panel.Parent = overlay

local panelSizeConstraint = Instance.new("UISizeConstraint")
panelSizeConstraint.MinSize = Vector2.new(340, 310)
panelSizeConstraint.MaxSize = Vector2.new(780, 310)
panelSizeConstraint.Parent = panel

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 8)
panelCorner.Parent = panel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = Color3.fromRGB(255, 255, 255)
panelStroke.Transparency = 0.78
panelStroke.Thickness = 1
panelStroke.Parent = panel

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 16)
padding.PaddingRight = UDim.new(0, 16)
padding.PaddingBottom = UDim.new(0, 16)
padding.PaddingLeft = UDim.new(0, 16)
padding.Parent = panel

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "TitleLabel"
titleLabel.Size = UDim2.new(1, 0, 0, 28)
titleLabel.BackgroundTransparency = 1
titleLabel.Font = Enum.Font.GothamBold
titleLabel.Text = "Niveau superieur"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextSize = 22
titleLabel.TextXAlignment = Enum.TextXAlignment.Center
titleLabel.Parent = panel

local subtitleLabel = Instance.new("TextLabel")
subtitleLabel.Name = "SubtitleLabel"
subtitleLabel.Position = UDim2.new(0, 0, 0, 32)
subtitleLabel.Size = UDim2.new(1, 0, 0, 20)
subtitleLabel.BackgroundTransparency = 1
subtitleLabel.Font = Enum.Font.GothamMedium
subtitleLabel.Text = "Choisis un bonus permanent"
subtitleLabel.TextColor3 = Color3.fromRGB(210, 218, 230)
subtitleLabel.TextSize = 13
subtitleLabel.TextXAlignment = Enum.TextXAlignment.Center
subtitleLabel.Parent = panel

local optionsFrame = Instance.new("Frame")
optionsFrame.Name = "Options"
optionsFrame.Position = UDim2.new(0, 0, 0, 70)
optionsFrame.Size = UDim2.new(1, 0, 1, -70)
optionsFrame.BackgroundTransparency = 1
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

local function createOptionButton(index)
	local button = Instance.new("TextButton")
	button.Name = "Option" .. tostring(index)
	button.Size = UDim2.new(0.333, -8, 1, 0)
	button.BackgroundColor3 = Color3.fromRGB(35, 40, 50)
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Font = Enum.Font.GothamBold
	button.Text = ""
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextSize = 14
	button.TextWrapped = true
	button.Modal = true
	button.LayoutOrder = index
	button.Parent = optionsFrame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Transparency = 0.8
	stroke.Thickness = 1
	stroke.Parent = button

	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Name = "Rarity"
	rarityLabel.Position = UDim2.new(0, 10, 0, 10)
	rarityLabel.Size = UDim2.new(1, -20, 0, 18)
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.Font = Enum.Font.GothamBold
	rarityLabel.Text = "Commun"
	rarityLabel.TextColor3 = Color3.fromRGB(80, 220, 120)
	rarityLabel.TextSize = 12
	rarityLabel.TextXAlignment = Enum.TextXAlignment.Left
	rarityLabel.Parent = button

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "PerkName"
	nameLabel.Position = UDim2.new(0, 10, 0, 38)
	nameLabel.Size = UDim2.new(1, -20, 0, 48)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Text = "Perk"
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextSize = 16
	nameLabel.TextWrapped = true
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextYAlignment = Enum.TextYAlignment.Top
	nameLabel.Parent = button

	local descriptionLabel = Instance.new("TextLabel")
	descriptionLabel.Name = "Description"
	descriptionLabel.Position = UDim2.new(0, 10, 0, 96)
	descriptionLabel.Size = UDim2.new(1, -20, 1, -106)
	descriptionLabel.BackgroundTransparency = 1
	descriptionLabel.Font = Enum.Font.GothamMedium
	descriptionLabel.Text = "Description"
	descriptionLabel.TextColor3 = Color3.fromRGB(220, 228, 240)
	descriptionLabel.TextSize = 13
	descriptionLabel.TextWrapped = true
	descriptionLabel.TextXAlignment = Enum.TextXAlignment.Left
	descriptionLabel.TextYAlignment = Enum.TextYAlignment.Top
	descriptionLabel.Parent = button

	optionButtons[index] = {
		Button = button,
		RarityLabel = rarityLabel,
		NameLabel = nameLabel,
		DescriptionLabel = descriptionLabel,
		Option = nil,
	}
end

for index = 1, 3 do
	createOptionButton(index)
end

local function setButtonsEnabled(isEnabled)
	for _, entry in ipairs(optionButtons) do
		entry.Button.Active = isEnabled
		entry.Button.AutoButtonColor = isEnabled
	end
end

local function hideChoices()
	currentChoiceId = nil
	isSubmitting = false
	screenGui.Enabled = false
	setButtonsEnabled(true)
end

local function showChoices(payload)
	currentChoiceId = payload.ChoiceId
	isSubmitting = false
	titleLabel.Text = "Niveau " .. tostring(payload.Level or "?")
	screenGui.Enabled = true
	setButtonsEnabled(true)

	for index, entry in ipairs(optionButtons) do
		local option = payload.Choices[index]
		entry.Option = option

		if option == nil then
			entry.Button.Visible = false
		else
			entry.Button.Visible = true
			entry.RarityLabel.Text = option.RarityName or option.Rarity or "Perk"
			entry.RarityLabel.TextColor3 = option.RarityColor or Color3.fromRGB(255, 255, 255)
			entry.NameLabel.Text = option.Name or "Perk"
			entry.DescriptionLabel.Text = option.Description or ""
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
		selectChoiceRemote:FireServer(currentChoiceId, entry.Option.OptionId)
	end)
end

showChoicesRemote.OnClientEvent:Connect(showChoices)
hideChoicesRemote.OnClientEvent:Connect(hideChoices)
hideChoices()
