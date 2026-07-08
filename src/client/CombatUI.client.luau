local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local statsRemote = ReplicatedStorage:WaitForChild("Combat_UpdateStats")
local updateXpRemote = ReplicatedStorage:WaitForChild("Xp_UpdateCount")
local updateCoinsRemote = ReplicatedStorage:WaitForChild("Coin_UpdateCount")
local updatePerksRemote = ReplicatedStorage:WaitForChild("Perk_UpdateStats")

local existingGui = playerGui:FindFirstChild("CombatGui")

if existingGui ~= nil then
	existingGui:Destroy()
end

local COLORS = {
	Panel = Color3.fromRGB(18, 20, 28),
	PanelSoft = Color3.fromRGB(28, 32, 44),
	Line = Color3.fromRGB(255, 255, 255),
	Text = Color3.fromRGB(246, 248, 255),
	Muted = Color3.fromRGB(174, 183, 198),
	Health = Color3.fromRGB(255, 82, 92),
	HealthDark = Color3.fromRGB(155, 39, 52),
	Shield = Color3.fromRGB(85, 175, 255),
	Xp = Color3.fromRGB(80, 220, 255),
	XpAlt = Color3.fromRGB(168, 94, 255),
	Gold = Color3.fromRGB(255, 206, 82),
	Wave = Color3.fromRGB(255, 135, 72),
	Kills = Color3.fromRGB(122, 239, 160),
	Monster = Color3.fromRGB(230, 96, 255),
	Weapon = Color3.fromRGB(120, 145, 255),
}

local BAR_TWEEN = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function addCorner(instance, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance

	return corner
end

local function addStroke(instance, color, transparency, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or COLORS.Line
	stroke.Transparency = transparency or 0.82
	stroke.Thickness = thickness or 1
	stroke.Parent = instance

	return stroke
end

local function addGradient(instance, firstColor, secondColor, rotation)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, firstColor),
		ColorSequenceKeypoint.new(1, secondColor),
	})
	gradient.Rotation = rotation or 0
	gradient.Parent = instance

	return gradient
end

local function addPadding(instance, top, right, bottom, left)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, top)
	padding.PaddingRight = UDim.new(0, right)
	padding.PaddingBottom = UDim.new(0, bottom)
	padding.PaddingLeft = UDim.new(0, left)
	padding.Parent = instance

	return padding
end

local function addTextSizeConstraint(textObject, minSize, maxSize)
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = minSize
	constraint.MaxTextSize = maxSize
	constraint.Parent = textObject

	return constraint
end

local function createLabel(parent, name, text, font, textSize, color)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = font or Enum.Font.GothamMedium
	label.Text = text or ""
	label.TextColor3 = color or COLORS.Text
	label.TextSize = textSize or 12
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Parent = parent

	return label
end

local function createPanel(parent, name)
	local panel = Instance.new("Frame")
	panel.Name = name
	panel.BackgroundColor3 = COLORS.Panel
	panel.BackgroundTransparency = 0.08
	panel.BorderSizePixel = 0
	panel.Parent = parent
	addCorner(panel, 8)
	addStroke(panel, COLORS.Line, 0.82, 1)
	addGradient(panel, Color3.fromRGB(31, 34, 46), Color3.fromRGB(12, 14, 20), 90)

	return panel
end

local function createTag(parent, name, text, color)
	local tag = Instance.new("TextLabel")
	tag.Name = name
	tag.Size = UDim2.fromOffset(34, 22)
	tag.BackgroundColor3 = color
	tag.BorderSizePixel = 0
	tag.Font = Enum.Font.GothamBlack
	tag.Text = text
	tag.TextColor3 = Color3.fromRGB(12, 14, 20)
	tag.TextSize = 11
	tag.TextXAlignment = Enum.TextXAlignment.Center
	tag.TextYAlignment = Enum.TextYAlignment.Center
	tag.Parent = parent
	addCorner(tag, 6)
	addGradient(tag, Color3.fromRGB(255, 255, 255), color, 90)

	return tag
end

local function setBarProgress(fill, progress)
	TweenService:Create(fill, BAR_TWEEN, {
		Size = UDim2.new(math.clamp(progress, 0, 1), 0, 1, 0),
	}):Play()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CombatGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 6
screenGui.IgnoreGuiInset = false
screenGui.Parent = playerGui

local currencyPanel = createPanel(screenGui, "CurrencyPanel")
currencyPanel.Position = UDim2.fromOffset(14, 72)
currencyPanel.Size = UDim2.fromOffset(178, 44)
currencyPanel.BackgroundTransparency = 0.04

local currencyIcon = createTag(currencyPanel, "CoinTag", "G", COLORS.Gold)
currencyIcon.Position = UDim2.fromOffset(9, 11)

local currencyLabel = createLabel(currencyPanel, "CurrencyLabel", "GOLDS DE RUN", Enum.Font.GothamBold, 10, COLORS.Muted)
currencyLabel.Position = UDim2.fromOffset(50, 6)
currencyLabel.Size = UDim2.new(1, -58, 0, 15)

local coinsValueLabel = createLabel(currencyPanel, "CoinsValue", "0", Enum.Font.GothamBlack, 18, COLORS.Gold)
coinsValueLabel.Position = UDim2.fromOffset(50, 20)
coinsValueLabel.Size = UDim2.new(1, -58, 0, 20)
addTextSizeConstraint(coinsValueLabel, 12, 18)

local statusPanel = createPanel(screenGui, "StatusPanel")
statusPanel.AnchorPoint = Vector2.new(0, 1)
statusPanel.Position = UDim2.new(0, 14, 1, -18)
statusPanel.Size = UDim2.fromOffset(302, 148)
addPadding(statusPanel, 10, 10, 10, 10)

local statusSizeConstraint = Instance.new("UISizeConstraint")
statusSizeConstraint.MinSize = Vector2.new(260, 138)
statusSizeConstraint.MaxSize = Vector2.new(330, 150)
statusSizeConstraint.Parent = statusPanel

local brandLabel = createLabel(statusPanel, "BrandLabel", "MEGAROBLOX", Enum.Font.GothamBlack, 13, COLORS.Text)
brandLabel.Position = UDim2.fromOffset(0, 0)
brandLabel.Size = UDim2.new(0.58, 0, 0, 18)

local runLabel = createLabel(statusPanel, "RunLabel", "RUN SURVIVOR", Enum.Font.GothamBold, 10, COLORS.Muted)
runLabel.AnchorPoint = Vector2.new(1, 0)
runLabel.Position = UDim2.new(1, 0, 0, 1)
runLabel.Size = UDim2.new(0.42, 0, 0, 16)
runLabel.TextXAlignment = Enum.TextXAlignment.Right

local healthTitle = createLabel(statusPanel, "HealthTitle", "PV", Enum.Font.GothamBlack, 11, COLORS.Health)
healthTitle.Position = UDim2.fromOffset(0, 26)
healthTitle.Size = UDim2.fromOffset(36, 16)

local healthValueLabel = createLabel(statusPanel, "HealthValue", "100 / 100", Enum.Font.GothamBold, 12, COLORS.Text)
healthValueLabel.AnchorPoint = Vector2.new(1, 0)
healthValueLabel.Position = UDim2.new(1, 0, 0, 26)
healthValueLabel.Size = UDim2.new(1, -42, 0, 16)
healthValueLabel.TextXAlignment = Enum.TextXAlignment.Right

local healthTrack = Instance.new("Frame")
healthTrack.Name = "HealthTrack"
healthTrack.Position = UDim2.fromOffset(0, 45)
healthTrack.Size = UDim2.new(1, 0, 0, 12)
healthTrack.BackgroundColor3 = Color3.fromRGB(51, 35, 43)
healthTrack.BorderSizePixel = 0
healthTrack.ClipsDescendants = true
healthTrack.Parent = statusPanel
addCorner(healthTrack, 5)

local healthFill = Instance.new("Frame")
healthFill.Name = "HealthFill"
healthFill.Size = UDim2.fromScale(1, 1)
healthFill.BackgroundColor3 = COLORS.Health
healthFill.BorderSizePixel = 0
healthFill.Parent = healthTrack
addCorner(healthFill, 5)
addGradient(healthFill, COLORS.Health, COLORS.HealthDark, 0)

local shieldRow = Instance.new("Frame")
shieldRow.Name = "ShieldRow"
shieldRow.Position = UDim2.fromOffset(0, 62)
shieldRow.Size = UDim2.new(1, 0, 0, 18)
shieldRow.BackgroundTransparency = 1
shieldRow.Visible = false
shieldRow.Parent = statusPanel

local shieldTitle = createLabel(shieldRow, "ShieldTitle", "SH", Enum.Font.GothamBlack, 10, COLORS.Shield)
shieldTitle.Size = UDim2.fromOffset(32, 18)

local shieldTrack = Instance.new("Frame")
shieldTrack.Name = "ShieldTrack"
shieldTrack.Position = UDim2.fromOffset(36, 4)
shieldTrack.Size = UDim2.new(1, -92, 0, 10)
shieldTrack.BackgroundColor3 = Color3.fromRGB(32, 43, 62)
shieldTrack.BorderSizePixel = 0
shieldTrack.ClipsDescendants = true
shieldTrack.Parent = shieldRow
addCorner(shieldTrack, 5)

local shieldFill = Instance.new("Frame")
shieldFill.Name = "ShieldFill"
shieldFill.Size = UDim2.fromScale(0, 1)
shieldFill.BackgroundColor3 = COLORS.Shield
shieldFill.BorderSizePixel = 0
shieldFill.Parent = shieldTrack
addCorner(shieldFill, 5)
addGradient(shieldFill, COLORS.Shield, Color3.fromRGB(98, 240, 255), 0)

local shieldValueLabel = createLabel(shieldRow, "ShieldValue", "0 / 0", Enum.Font.GothamBold, 10, COLORS.Muted)
shieldValueLabel.AnchorPoint = Vector2.new(1, 0)
shieldValueLabel.Position = UDim2.new(1, 0, 0, 1)
shieldValueLabel.Size = UDim2.fromOffset(52, 16)
shieldValueLabel.TextXAlignment = Enum.TextXAlignment.Right

local metricsRow = Instance.new("Frame")
metricsRow.Name = "MetricsRow"
metricsRow.Position = UDim2.fromOffset(0, 84)
metricsRow.Size = UDim2.new(1, 0, 0, 28)
metricsRow.BackgroundTransparency = 1
metricsRow.Parent = statusPanel

local metricsLayout = Instance.new("UIListLayout")
metricsLayout.FillDirection = Enum.FillDirection.Horizontal
metricsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
metricsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
metricsLayout.Padding = UDim.new(0, 6)
metricsLayout.SortOrder = Enum.SortOrder.LayoutOrder
metricsLayout.Parent = metricsRow

local function createMetricChip(name, tagText, color)
	local chip = Instance.new("Frame")
	chip.Name = name
	chip.Size = UDim2.new(0.333, -4, 1, 0)
	chip.BackgroundColor3 = COLORS.PanelSoft
	chip.BackgroundTransparency = 0.06
	chip.BorderSizePixel = 0
	chip.Parent = metricsRow
	addCorner(chip, 7)
	addStroke(chip, color, 0.7, 1)

	local tag = createTag(chip, "Tag", tagText, color)
	tag.Position = UDim2.fromOffset(4, 3)
	tag.Size = UDim2.fromOffset(24, 20)

	local value = createLabel(chip, "Value", "0", Enum.Font.GothamBlack, 13, COLORS.Text)
	value.Position = UDim2.fromOffset(33, 4)
	value.Size = UDim2.new(1, -37, 0, 19)
	value.TextXAlignment = Enum.TextXAlignment.Left
	addTextSizeConstraint(value, 10, 13)

	return value
end

local waveValueLabel = createMetricChip("WaveChip", "W", COLORS.Wave)
local killsValueLabel = createMetricChip("KillsChip", "K", COLORS.Kills)
local monsterValueLabel = createMetricChip("MonsterChip", "M", COLORS.Monster)

local weaponPanel = Instance.new("Frame")
weaponPanel.Name = "WeaponPanel"
weaponPanel.Position = UDim2.fromOffset(0, 119)
weaponPanel.Size = UDim2.new(1, 0, 0, 20)
weaponPanel.BackgroundColor3 = COLORS.PanelSoft
weaponPanel.BackgroundTransparency = 0.06
weaponPanel.BorderSizePixel = 0
weaponPanel.Parent = statusPanel
addCorner(weaponPanel, 7)
addStroke(weaponPanel, COLORS.Weapon, 0.72, 1)

local weaponTag = createTag(weaponPanel, "WeaponTag", "FB", COLORS.Weapon)
weaponTag.Position = UDim2.fromOffset(5, 2)
weaponTag.Size = UDim2.fromOffset(32, 16)
weaponTag.TextSize = 9

local weaponLabel = createLabel(weaponPanel, "WeaponLabel", "Fireball auto", Enum.Font.GothamBold, 11, COLORS.Text)
weaponLabel.Position = UDim2.fromOffset(44, 0)
weaponLabel.Size = UDim2.new(1, -126, 1, 0)

local perkCountLabel = createLabel(weaponPanel, "PerkCount", "0 perks", Enum.Font.GothamMedium, 10, COLORS.Muted)
perkCountLabel.AnchorPoint = Vector2.new(1, 0)
perkCountLabel.Position = UDim2.new(1, -6, 0, 0)
perkCountLabel.Size = UDim2.fromOffset(72, 20)
perkCountLabel.TextXAlignment = Enum.TextXAlignment.Right

local xpPanel = createPanel(screenGui, "XpPanel")
xpPanel.AnchorPoint = Vector2.new(0.5, 1)
xpPanel.Position = UDim2.new(0.5, 0, 1, -18)
xpPanel.Size = UDim2.new(0.46, 0, 0, 48)
xpPanel.BackgroundTransparency = 0.04

local xpPanelSizeConstraint = Instance.new("UISizeConstraint")
xpPanelSizeConstraint.MinSize = Vector2.new(320, 48)
xpPanelSizeConstraint.MaxSize = Vector2.new(620, 48)
xpPanelSizeConstraint.Parent = xpPanel

local levelBadge = Instance.new("Frame")
levelBadge.Name = "LevelBadge"
levelBadge.Position = UDim2.fromOffset(8, 8)
levelBadge.Size = UDim2.fromOffset(56, 32)
levelBadge.BackgroundColor3 = COLORS.XpAlt
levelBadge.BorderSizePixel = 0
levelBadge.Parent = xpPanel
addCorner(levelBadge, 7)
addGradient(levelBadge, COLORS.Xp, COLORS.XpAlt, 35)

local levelTitle = createLabel(levelBadge, "LevelTitle", "LV", Enum.Font.GothamBlack, 9, Color3.fromRGB(20, 23, 32))
levelTitle.Position = UDim2.fromOffset(7, 2)
levelTitle.Size = UDim2.new(1, -14, 0, 11)
levelTitle.TextXAlignment = Enum.TextXAlignment.Center

local levelValueLabel = createLabel(levelBadge, "LevelValue", "1", Enum.Font.GothamBlack, 17, Color3.fromRGB(20, 23, 32))
levelValueLabel.Position = UDim2.fromOffset(7, 12)
levelValueLabel.Size = UDim2.new(1, -14, 0, 17)
levelValueLabel.TextXAlignment = Enum.TextXAlignment.Center
addTextSizeConstraint(levelValueLabel, 11, 17)

local xpTrack = Instance.new("Frame")
xpTrack.Name = "XpTrack"
xpTrack.Position = UDim2.fromOffset(72, 11)
xpTrack.Size = UDim2.new(1, -88, 0, 25)
xpTrack.BackgroundColor3 = Color3.fromRGB(39, 42, 57)
xpTrack.BorderSizePixel = 0
xpTrack.ClipsDescendants = true
xpTrack.Parent = xpPanel
addCorner(xpTrack, 7)
addStroke(xpTrack, COLORS.Line, 0.9, 1)

local xpFill = Instance.new("Frame")
xpFill.Name = "XpFill"
xpFill.Size = UDim2.fromScale(0, 1)
xpFill.BackgroundColor3 = COLORS.Xp
xpFill.BorderSizePixel = 0
xpFill.Parent = xpTrack
addCorner(xpFill, 7)
addGradient(xpFill, COLORS.Xp, COLORS.XpAlt, 0)

local xpTextLabel = createLabel(xpTrack, "XpText", "XP 0 / 6", Enum.Font.GothamBlack, 12, COLORS.Text)
xpTextLabel.Size = UDim2.fromScale(1, 1)
xpTextLabel.TextXAlignment = Enum.TextXAlignment.Center
xpTextLabel.TextYAlignment = Enum.TextYAlignment.Center

local threatTrack = Instance.new("Frame")
threatTrack.Name = "ThreatTrack"
threatTrack.Position = UDim2.fromOffset(72, 38)
threatTrack.Size = UDim2.new(1, -88, 0, 3)
threatTrack.BackgroundColor3 = Color3.fromRGB(45, 34, 38)
threatTrack.BorderSizePixel = 0
threatTrack.ClipsDescendants = true
threatTrack.Parent = xpPanel
addCorner(threatTrack, 2)

local threatFill = Instance.new("Frame")
threatFill.Name = "ThreatFill"
threatFill.Size = UDim2.fromScale(0, 1)
threatFill.BackgroundColor3 = COLORS.Wave
threatFill.BorderSizePixel = 0
threatFill.Parent = threatTrack
addCorner(threatFill, 2)
addGradient(threatFill, COLORS.Wave, COLORS.Monster, 0)

local function getViewportSize()
	local currentCamera = Workspace.CurrentCamera

	if currentCamera == nil then
		return Vector2.new(1280, 720)
	end

	return currentCamera.ViewportSize
end

local viewportConnection = nil

local function updateResponsiveLayout()
	local viewportSize = getViewportSize()

	if viewportSize.X < 760 then
		currencyPanel.Position = UDim2.fromOffset(12, 108)
		currencyPanel.Size = UDim2.fromOffset(154, 40)
		statusPanel.Position = UDim2.new(0, 12, 1, -72)
		statusPanel.Size = UDim2.fromOffset(270, 138)
		xpPanel.Size = UDim2.new(0.72, 0, 0, 46)
	else
		currencyPanel.Position = UDim2.fromOffset(14, 72)
		currencyPanel.Size = UDim2.fromOffset(178, 44)
		statusPanel.Position = UDim2.new(0, 14, 1, -18)
		statusPanel.Size = UDim2.fromOffset(302, 148)
		xpPanel.Size = UDim2.new(0.46, 0, 0, 48)
	end
end

local function bindViewportResize()
	if viewportConnection ~= nil then
		viewportConnection:Disconnect()
		viewportConnection = nil
	end

	if Workspace.CurrentCamera ~= nil then
		viewportConnection = Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveLayout)
	end
end

local function updateXpDisplay(payload)
	local level = payload.Level or 1
	local xp = payload.Xp or 0
	local xpRequired = math.max(1, payload.XpRequired or 1)
	local progress = math.clamp(xp / xpRequired, 0, 1)

	levelValueLabel.Text = tostring(level)
	setBarProgress(xpFill, progress)
	xpTextLabel.Text = ("XP %d / %d"):format(xp, xpRequired)
end

local function updatePerkDisplay(payload)
	local stacksByPerkId = payload.StacksByPerkId or {}
	local stackCount = 0

	for _, count in pairs(stacksByPerkId) do
		if typeof(count) == "number" then
			stackCount += count
		end
	end

	perkCountLabel.Text = ("%d perks"):format(stackCount)
end

statsRemote.OnClientEvent:Connect(function(payload)
	local health = payload.Health or 0
	local maxHealth = math.max(1, payload.MaxHealth or 100)
	local shield = payload.Shield or 0
	local maxShield = payload.MaxShield or 0
	local aliveMonsters = payload.AliveMonsters or 0
	local maxAliveMonsters = math.max(1, payload.MaxAliveMonsters or aliveMonsters)
	local wave = payload.Wave or 1
	local kills = payload.Kills or 0
	local weaponName = payload.WeaponName or "Fireball"
	local healthProgress = math.clamp(health / maxHealth, 0, 1)
	local threatProgress = math.clamp(aliveMonsters / maxAliveMonsters, 0, 1)

	healthValueLabel.Text = ("%d / %d"):format(health, maxHealth)
	setBarProgress(healthFill, healthProgress)

	shieldRow.Visible = maxShield > 0

	if maxShield > 0 then
		shieldValueLabel.Text = ("%d / %d"):format(shield, maxShield)
		setBarProgress(shieldFill, math.clamp(shield / math.max(1, maxShield), 0, 1))
	end

	waveValueLabel.Text = tostring(wave)
	killsValueLabel.Text = tostring(kills)
	monsterValueLabel.Text = ("%d/%d"):format(aliveMonsters, maxAliveMonsters)
	weaponLabel.Text = weaponName .. " auto"
	setBarProgress(threatFill, threatProgress)
end)

updateXpRemote.OnClientEvent:Connect(updateXpDisplay)

updateCoinsRemote.OnClientEvent:Connect(function(payload)
	local coinCount = payload.Coins or 0

	coinsValueLabel.Text = tostring(coinCount)
end)

updatePerksRemote.OnClientEvent:Connect(updatePerkDisplay)

bindViewportResize()

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	bindViewportResize()
	updateResponsiveLayout()
end)

updateResponsiveLayout()
