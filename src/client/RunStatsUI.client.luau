local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))
local DebugLog = require(Shared:WaitForChild("DebugLog"))
local RunItemConfig = require(Shared:WaitForChild("RunItemConfig"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))

local existingGui = playerGui:FindFirstChild("RunStatsGui")

if existingGui ~= nil then
	existingGui:Destroy()
end

local COLORS = UiTheme.Contexts.RunStats

local function createLabel(parent, name, text, font, size, color)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Font = font
	label.Text = text
	label.TextColor3 = color
	label.TextSize = size
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0.62
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = parent

	return label
end

local addCorner = UiTheme.AddCorner
local addStroke = UiTheme.AddStroke

local function getDefaultDisplayStats()
	return {
		MaxHealth = 100,
		MoveSpeed = 16,
		JumpMode = "Power",
		JumpValue = 50,
		CurrentShield = 0,
		MaxShield = 0,
		HealthRegen = 0,
		ArmorPercent = 0,
		LifeStealPercent = 0,
		CritChance = 0,
		CritDamageMultiplier = 1.5,
		BaseDamage = CombatConfig.FireballDamage,
		EliteDamage = CombatConfig.FireballDamage,
		AttackRate = 1 / CombatConfig.FireballCooldown,
		ProjectileCount = 1,
		BounceCount = 0,
		ProjectileSpeed = CombatConfig.FireballSpeed,
		ProjectileDuration = CombatConfig.FireballLifetime,
		CollectRadius = CombatConfig.XpCollectDistance,
		XpMultiplier = 1,
		GoldMultiplier = 1,
		Luck = 0,
		EnemyMultiplier = 1,
	}
end

local state = {
	IsRunActive = false,
	IsPaused = false,
	MaxHealth = 100,
	CurrentShield = 0,
	MaxShield = 0,
	DisplayStats = getDefaultDisplayStats(),
	RunItemStacks = {},
}

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "RunStatsGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 30
screenGui.Enabled = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "StatsPanel"
panel.AnchorPoint = Vector2.new(0, 0.5)
panel.Position = UDim2.new(0, 18, 0.5, 0)
panel.Size = UDim2.new(0, 230, 0.78, 0)
panel.BackgroundColor3 = COLORS.Panel
panel.BackgroundTransparency = 0.2
panel.BorderSizePixel = 0
panel.ClipsDescendants = true
panel.Parent = screenGui
addCorner(panel, 8)
addStroke(panel, Color3.fromRGB(7, 12, 19), 0.16, 4)
addStroke(panel, COLORS.Cyan, 0.3, 1.5)

local panelGradient = Instance.new("UIGradient")
panelGradient.Name = "GlassGradient"
panelGradient.Rotation = 90
panelGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, COLORS.Header),
	ColorSequenceKeypoint.new(0.36, COLORS.Panel),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 17, 26)),
})
panelGradient.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.1),
	NumberSequenceKeypoint.new(1, 0.36),
})
panelGradient.Parent = panel
UiTheme.AddSurfaceFinish(panel, {
	Accent = COLORS.Cyan,
	Intensity = 0.62,
})

local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 34)
header.BackgroundColor3 = COLORS.Header
header.BackgroundTransparency = 0.32
header.BorderSizePixel = 0
header.Parent = panel

local headerAccent = Instance.new("Frame")
headerAccent.Name = "HeaderAccent"
headerAccent.Position = UDim2.fromOffset(0, 31)
headerAccent.Size = UDim2.new(1, 0, 0, 3)
headerAccent.BackgroundColor3 = COLORS.Cyan
headerAccent.BackgroundTransparency = 0.12
headerAccent.BorderSizePixel = 0
headerAccent.Parent = header

local headerIcon = createLabel(header, "HeaderIcon", "|||", Enum.Font.GothamBlack, 12, COLORS.Cyan)
headerIcon.Position = UDim2.fromOffset(9, 0)
headerIcon.Size = UDim2.fromOffset(20, 31)
headerIcon.TextXAlignment = Enum.TextXAlignment.Center

local titleLabel = createLabel(header, "Title", "STATISTIQUES DE RUN", Enum.Font.GothamBold, 14, COLORS.Text)
titleLabel.Position = UDim2.fromOffset(32, 0)
titleLabel.Size = UDim2.new(1, -42, 1, 0)
titleLabel.TextXAlignment = Enum.TextXAlignment.Left

local content = Instance.new("ScrollingFrame")
content.Name = "Content"
content.Position = UDim2.fromOffset(7, 40)
content.Size = UDim2.new(1, -14, 1, -47)
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.CanvasSize = UDim2.fromOffset(0, 0)
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.ScrollBarImageColor3 = COLORS.Cyan
content.ScrollBarImageTransparency = 0.35
content.ScrollBarThickness = 4
content.ScrollingDirection = Enum.ScrollingDirection.Y
content.Parent = panel

local contentPadding = Instance.new("UIPadding")
contentPadding.PaddingTop = UDim.new(0, 2)
contentPadding.PaddingBottom = UDim.new(0, 4)
contentPadding.Parent = content

local contentLayout = Instance.new("UIListLayout")
contentLayout.FillDirection = Enum.FillDirection.Vertical
contentLayout.Padding = UDim.new(0, 1)
contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
contentLayout.Parent = content

local rows = {}
local rowOrder = 0
local currentSectionColor = COLORS.Cyan

local SECTION_STYLES = {
	SURVIE = {
		Color = COLORS.Survival,
		Icon = "+",
	},
	ATTAQUE = {
		Color = COLORS.Attack,
		Icon = "x",
	},
	["MOBILITE ET GAIN"] = {
		Color = COLORS.Mobility,
		Icon = ">",
	},
}

local function createSection(text)
	rowOrder += 1
	local style = SECTION_STYLES[text] or {
		Color = COLORS.Cyan,
		Icon = ">",
	}
	currentSectionColor = style.Color

	local section = createLabel(content, "Section", text, Enum.Font.GothamBold, 12, style.Color)
	section.Size = UDim2.new(1, 0, 0, 22)
	section.LayoutOrder = rowOrder
	section.TextXAlignment = Enum.TextXAlignment.Left
	section.Text = "  " .. style.Icon .. "  " .. text

	return section
end

local function createRow(id, text)
	rowOrder += 1

	local row = Instance.new("Frame")
	row.Name = id
	row.Size = UDim2.new(1, 0, 0, 20)
	row.BackgroundColor3 = Color3.fromRGB(20, 34, 48)
	row.BackgroundTransparency = 0.38
	row.BorderSizePixel = 0
	row.LayoutOrder = rowOrder
	row.Parent = content
	addCorner(row, 3)
	addStroke(row, currentSectionColor, 0.8, 1)

	local marker = Instance.new("Frame")
	marker.Name = "Marker"
	marker.Position = UDim2.fromOffset(4, 6)
	marker.Size = UDim2.fromOffset(8, 8)
	marker.BackgroundColor3 = currentSectionColor
	marker.BorderSizePixel = 0
	marker.Parent = row
	addCorner(marker, 4)

	local nameLabel = createLabel(row, "Name", text, Enum.Font.GothamMedium, 10, COLORS.Muted)
	nameLabel.Position = UDim2.fromOffset(17, 0)
	nameLabel.Size = UDim2.new(0.63, -17, 1, 0)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left

	local valueLabel = createLabel(row, "Value", "-", Enum.Font.GothamBold, 10, COLORS.Value)
	valueLabel.AnchorPoint = Vector2.new(1, 0)
	valueLabel.Position = UDim2.new(1, -7, 0, 0)
	valueLabel.Size = UDim2.new(0.37, -7, 1, 0)
	valueLabel.TextXAlignment = Enum.TextXAlignment.Right

	rows[id] = valueLabel
end

createSection("SURVIE")
createRow("MaxHealth", "PV maximum")
createRow("HealthRegen", "Regeneration PV")
createRow("Shield", "Bouclier")
createRow("Armor", "Armure")
createRow("LifeSteal", "Vol de vie")

createSection("ATTAQUE")
createRow("BaseDamage", "Degats")
createRow("EliteDamage", "Degats elites")
createRow("AttackRate", "Vitesse d'attaque")
createRow("ProjectileCount", "Projectiles")
createRow("BounceCount", "Rebonds")
createRow("CritChance", "Chance critique")
createRow("CritDamage", "Degats critiques")
createRow("ProjectileSpeed", "Vitesse projectile")
createRow("ProjectileDuration", "Duree projectile")

createSection("MOBILITE ET GAIN")
createRow("MoveSpeed", "Vitesse deplacement")
createRow("Jump", "Puissance saut")
createRow("CollectRadius", "Rayon recolte")
createRow("XpMultiplier", "Gain d'XP")
createRow("GoldMultiplier", "Gain d'or")
createRow("Luck", "Chance")
createRow("EnemyMultiplier", "Plus d'ennemis")

createSection("OBJETS DE RUN")

for _, itemId in ipairs(RunItemConfig.ChestRewardIds) do
	local definition = RunItemConfig.Definitions[itemId]

	if definition ~= nil then
		createRow("RunItem_" .. itemId, definition.Name)
	end
end

local function getNumber(value, fallback)
	if typeof(value) == "number" then
		return value
	end

	return fallback or 0
end

local function formatInteger(value)
	return tostring(math.floor(getNumber(value) + 0.5))
end

local function formatDecimal(value, decimals)
	local text = string.format("%." .. tostring(decimals) .. "f", getNumber(value))

	return string.gsub(text, "%.", ",")
end

local function formatPercent(value)
	return formatInteger(getNumber(value) * 100) .. "%"
end

local function formatMultiplier(value)
	return "x" .. formatDecimal(value, 2)
end

local function refreshRows()
	local stats = state.DisplayStats
	local maxHealth = state.MaxHealth

	if maxHealth <= 0 then
		maxHealth = getNumber(stats.MaxHealth, 100)
	end

	local currentShield = state.CurrentShield
	local maxShield = state.MaxShield

	if maxShield <= 0 then
		maxShield = getNumber(stats.MaxShield)
	end

	if currentShield <= 0 and getNumber(stats.CurrentShield) > 0 then
		currentShield = getNumber(stats.CurrentShield)
	end

	rows.MaxHealth.Text = formatInteger(maxHealth)
	rows.HealthRegen.Text = formatDecimal(stats.HealthRegen, 1) .. " /s"
	rows.Shield.Text = formatInteger(currentShield) .. " / " .. formatInteger(maxShield)
	rows.Armor.Text = "-" .. formatPercent(stats.ArmorPercent) .. " degats"
	rows.LifeSteal.Text = formatPercent(stats.LifeStealPercent)

	rows.BaseDamage.Text = formatDecimal(stats.BaseDamage, 1)
	rows.EliteDamage.Text = formatDecimal(stats.EliteDamage, 1)
	rows.AttackRate.Text = formatDecimal(stats.AttackRate, 2) .. " /s"
	rows.ProjectileCount.Text = formatInteger(stats.ProjectileCount)
	rows.BounceCount.Text = formatInteger(stats.BounceCount)
	rows.CritChance.Text = formatPercent(stats.CritChance)
	rows.CritDamage.Text = formatPercent(stats.CritDamageMultiplier)
	rows.ProjectileSpeed.Text = formatDecimal(stats.ProjectileSpeed, 0)
	rows.ProjectileDuration.Text = formatDecimal(stats.ProjectileDuration, 1) .. " s"

	rows.MoveSpeed.Text = formatDecimal(stats.MoveSpeed, 1)
	rows.Jump.Text = formatDecimal(stats.JumpValue, 1)
	rows.CollectRadius.Text = formatDecimal(stats.CollectRadius, 1)
	rows.XpMultiplier.Text = formatMultiplier(stats.XpMultiplier)
	rows.GoldMultiplier.Text = formatMultiplier(stats.GoldMultiplier)
	rows.Luck.Text = formatPercent(stats.Luck)
	rows.EnemyMultiplier.Text = formatMultiplier(stats.EnemyMultiplier)

	for _, itemId in ipairs(RunItemConfig.ChestRewardIds) do
		local row = rows["RunItem_" .. itemId]

		if row ~= nil then
			row.Text = "x" .. formatInteger(state.RunItemStacks[itemId] or 0)
		end
	end
end

local function refreshVisibility()
	screenGui.Enabled = state.IsRunActive and state.IsPaused
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

	if viewportSize.X < 700 then
		panel.AnchorPoint = Vector2.new(0.5, 1)
		panel.Position = UDim2.new(0.5, 0, 1, -12)
		panel.Size = UDim2.new(0.9, 0, 0.42, 0)
	elseif viewportSize.X < 1200 then
		panel.AnchorPoint = Vector2.new(0, 0.5)
		panel.Position = UDim2.new(0, 12, 0.5, 0)
		panel.Size = UDim2.new(0, 218, 0.7, 0)
	else
		panel.AnchorPoint = Vector2.new(0, 0.5)
		panel.Position = UDim2.new(0, 18, 0.5, 0)
		panel.Size = UDim2.new(0, 230, 0.78, 0)
	end
end

local function onPerkStats(payload)
	payload = payload or {}

	if typeof(payload.DisplayStats) == "table" then
		state.DisplayStats = payload.DisplayStats
	end

	if payload.CurrentShield ~= nil then
		state.CurrentShield = getNumber(payload.CurrentShield)
	end

	if payload.MaxShield ~= nil then
		state.MaxShield = getNumber(payload.MaxShield)
	end

	refreshRows()
end

local function onCombatStats(payload)
	payload = payload or {}

	if payload.MaxHealth ~= nil then
		state.MaxHealth = math.max(1, getNumber(payload.MaxHealth, state.MaxHealth))
	end

	if payload.Shield ~= nil then
		state.CurrentShield = getNumber(payload.Shield)
	end

	if payload.MaxShield ~= nil then
		state.MaxShield = math.max(0, getNumber(payload.MaxShield))
	end

	refreshRows()
end

local function onPauseState(payload)
	payload = payload or {}
	state.IsPaused = payload.IsPaused == true
	refreshVisibility()
end

local function onRunState(payload)
	payload = payload or {}
	state.IsRunActive = payload.IsRunActive == true

	if not state.IsRunActive then
		state.IsPaused = false
	end

	refreshVisibility()
end

local function onRunItems(payload)
	payload = payload or {}
	state.RunItemStacks = {}

	if typeof(payload.Items) == "table" then
		for _, item in ipairs(payload.Items) do
			if typeof(item) == "table" and item.Id ~= nil then
				state.RunItemStacks[tostring(item.Id)] = math.max(0, math.floor(getNumber(item.Stacks) or 0))
			end
		end
	end

	refreshRows()
end

ReplicatedStorage:WaitForChild("Perk_UpdateStats").OnClientEvent:Connect(onPerkStats)
ReplicatedStorage:WaitForChild("Combat_UpdateStats").OnClientEvent:Connect(onCombatStats)
ReplicatedStorage:WaitForChild("Combat_PauseState").OnClientEvent:Connect(onPauseState)
ReplicatedStorage:WaitForChild("Run_StateUpdate").OnClientEvent:Connect(onRunState)
ReplicatedStorage:WaitForChild(RunItemConfig.UpdateRemoteName).OnClientEvent:Connect(onRunItems)

if Workspace.CurrentCamera ~= nil then
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveLayout)
end

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	if Workspace.CurrentCamera ~= nil then
		Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveLayout)
	end

	updateResponsiveLayout()
end)

refreshRows()
refreshVisibility()
updateResponsiveLayout()

DebugLog.Info("UI", "Panneau statistiques de run initialise", {
	Player = player.Name,
})
