local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))
local DebugLog = require(Shared:WaitForChild("DebugLog"))
local UiTemplateConfig = require(Shared:WaitForChild("UiTemplateConfig"))

local PRODUCTION_TEMPLATE_GUI_NAME = UiTemplateConfig.ProductionTemplateGuiName
local STATS_TEMPLATE_NAME = "RunStatsDock"
local PRODUCTION_GUI_NAME = "RunStatsGui"

local POSITIVE_COLOR = Color3.fromRGB(66, 219, 107)
local NEGATIVE_COLOR = Color3.fromRGB(248, 60, 76)
local PREVIEW_TWEEN = TweenInfo.new(0.58, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

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

	return string.gsub(text, "\\.", ",")
end

local function formatPercent(value)
	return formatInteger(getNumber(value) * 100) .. "%"
end

local function formatMultiplier(value)
	return "x" .. formatDecimal(value, 2)
end

local state = {
	IsRunActive = false,
	IsPaused = false,
	MaxHealth = 100,
	CurrentShield = 0,
	MaxShield = 0,
	DisplayStats = getDefaultDisplayStats(),
}

local existingGui = playerGui:FindFirstChild(PRODUCTION_GUI_NAME)

if existingGui then
	existingGui:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = PRODUCTION_GUI_NAME
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 30
screenGui.Enabled = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local function getStatsTemplate()
	local templateGui = StarterGui:FindFirstChild(PRODUCTION_TEMPLATE_GUI_NAME)
	local runCanvas = templateGui and templateGui:FindFirstChild("RunCanvas")
	local template = runCanvas and runCanvas:FindFirstChild(STATS_TEMPLATE_NAME)

	if template and template:IsA("Frame") then
		return template
	end

	DebugLog.Warn("UI", "Panneau statistiques V2 non initialise, template introuvable", {
		ProductionTemplate = templateGui ~= nil,
		RunCanvas = runCanvas ~= nil,
		Template = template ~= nil,
	})
	return nil
end

local template = getStatsTemplate()

if template == nil then
	return
end

local panel = template:Clone()
panel.Name = "StatsPanel"
panel.Visible = true
panel:SetAttribute("ProductionBound", true)
panel.Parent = screenGui

local content = panel:FindFirstChild("Content")
local statList = content and content:FindFirstChild("StatList")

if statList == nil or not statList:IsA("ScrollingFrame") then
	DebugLog.Warn("UI", "Panneau statistiques V2 non initialise, StatList introuvable")
	screenGui:Destroy()
	return
end

local rows = {}

for _, child in ipairs(statList:GetChildren()) do
	if child:IsA("Frame") then
		local value = child:FindFirstChild("Value")
		local cue = child:FindFirstChild("PreviewCue")

		if value and value:IsA("TextLabel") then
			rows[child.Name] = {
				Root = child,
				Value = value,
				Cue = if cue and cue:IsA("TextLabel") then cue else nil,
			}
		end
	end
end

local activePreviewTweens = {}
local activePreviewRows = {}

local function clearPreviewRow(row)
	local previewTween = activePreviewTweens[row]

	if previewTween then
		previewTween:Cancel()
		activePreviewTweens[row] = nil
	end

	local cue = row.Cue

	if cue then
		cue.Visible = false
		cue.Text = ""
		cue.TextTransparency = 1
	end

	activePreviewRows[row] = nil
end

local function clearAllPreviews()
	local rowsToClear = {}

	for row in pairs(activePreviewRows) do
		table.insert(rowsToClear, row)
	end

	for _, row in ipairs(rowsToClear) do
		clearPreviewRow(row)
	end
end

local function showPreview(row, delta, impact)
	local cue = row.Cue

	if cue == nil then
		return
	end

	local positive = delta >= 0
	local startY = if positive then 0.62 else 0.38
	local endY = if positive then 0.36 else 0.64

	clearPreviewRow(row)

	cue.Text = string.rep(if positive then "▲" else "▼", math.clamp(impact, 1, 3))
	cue.TextColor3 = if positive then POSITIVE_COLOR else NEGATIVE_COLOR
	cue.Position = UDim2.fromScale(0.595, startY)
	cue.TextTransparency = 0.02
	cue.Visible = true

	local previewTween = TweenService:Create(cue, PREVIEW_TWEEN, {
		Position = UDim2.fromScale(0.595, endY),
		TextTransparency = 0.46,
	})
	activePreviewTweens[row] = previewTween
	activePreviewRows[row] = true
	previewTween:Play()
end

local function previewCard(card)
	clearAllPreviews()

	local preview = card:FindFirstChild("StatPreview")

	if preview == nil then
		return
	end

	for _, entry in ipairs(preview:GetChildren()) do
		if entry:IsA("NumberValue") and entry.Value ~= 0 then
			local row = rows[entry.Name]

			if row then
				local impact = math.clamp(math.floor(getNumber(entry:GetAttribute("VisualImpact"), 1)), 1, 3)
				showPreview(row, entry.Value, impact)
			end
		end
	end
end

local boundCards = {}

local function bindCard(card)
	if boundCards[card] or not card:IsA("GuiObject") then
		return
	end

	boundCards[card] = true
	card.MouseEnter:Connect(function()
		previewCard(card)
	end)
	card.MouseLeave:Connect(clearAllPreviews)
	card.SelectionGained:Connect(function()
		previewCard(card)
	end)
	card.SelectionLost:Connect(clearAllPreviews)
	card.Destroying:Connect(function()
		boundCards[card] = nil
		clearAllPreviews()
	end)
end

local observedPerkChoiceGuis = {}

local function bindPerkChoiceGui(perkChoiceGui)
	if observedPerkChoiceGuis[perkChoiceGui] or not perkChoiceGui:IsA("ScreenGui") then
		return
	end
	observedPerkChoiceGuis[perkChoiceGui] = true

	perkChoiceGui:GetPropertyChangedSignal("Enabled"):Connect(function()
		if not perkChoiceGui.Enabled then
			clearAllPreviews()
		end
	end)
	perkChoiceGui.Destroying:Connect(function()
		observedPerkChoiceGuis[perkChoiceGui] = nil
		clearAllPreviews()
	end)

	-- PerkChoiceV2 est construit apres son parent ScreenGui. Le raccordement
	-- attend donc sa hierarchie au lieu de dependre de l'ordre des LocalScripts.
	task.spawn(function()
		local overlay = perkChoiceGui:WaitForChild("Overlay", 5)
		local dock = overlay and overlay:WaitForChild("PerkChoiceDockV2", 5)
		local choicePanel = dock and dock:WaitForChild("PerkChoicePanel", 5)
		local choiceContent = choicePanel and choicePanel:WaitForChild("Content", 5)
		local offers = choiceContent and choiceContent:WaitForChild("Offers", 5)

		if offers == nil then
			DebugLog.Warn("UI", "Apercu statistiques V2 non raccorde, offres introuvables")
			return
		end

		for _, card in ipairs(offers:GetChildren()) do
			bindCard(card)
		end

		offers.ChildAdded:Connect(bindCard)
	end)
end

local currentPerkChoiceGui = playerGui:FindFirstChild("PerkChoiceV2")

if currentPerkChoiceGui then
	bindPerkChoiceGui(currentPerkChoiceGui)
end

playerGui.ChildAdded:Connect(function(child)
	if child.Name == "PerkChoiceV2" then
		bindPerkChoiceGui(child)
	end
end)

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

	local values = {
		MaxHealth = formatInteger(maxHealth),
		HealthRegen = formatDecimal(stats.HealthRegen, 1) .. " /s",
		Shield = formatInteger(currentShield) .. " / " .. formatInteger(maxShield),
		Armor = "-" .. formatPercent(stats.ArmorPercent) .. " degats",
		LifeSteal = formatPercent(stats.LifeStealPercent),
		BaseDamage = formatDecimal(stats.BaseDamage, 1),
		EliteDamage = formatDecimal(stats.EliteDamage, 1),
		AttackRate = formatDecimal(stats.AttackRate, 2) .. " /s",
		ProjectileCount = formatInteger(stats.ProjectileCount),
		BounceCount = formatInteger(stats.BounceCount),
		CritChance = formatPercent(stats.CritChance),
		CritDamage = formatPercent(stats.CritDamageMultiplier),
		ProjectileSpeed = formatDecimal(stats.ProjectileSpeed, 0),
		ProjectileDuration = formatDecimal(stats.ProjectileDuration, 1) .. " s",
		MoveSpeed = formatDecimal(stats.MoveSpeed, 1),
		Jump = formatDecimal(stats.JumpValue, 1),
		CollectRadius = formatDecimal(stats.CollectRadius, 1),
		XpMultiplier = formatMultiplier(stats.XpMultiplier),
		GoldMultiplier = formatMultiplier(stats.GoldMultiplier),
		Luck = formatPercent(stats.Luck),
		EnemyMultiplier = formatMultiplier(stats.EnemyMultiplier),
	}

	for rowId, text in pairs(values) do
		local row = rows[rowId]

		if row then
			row.Value.Text = text
		end
	end
end

local function refreshVisibility()
	screenGui.Enabled = state.IsRunActive and state.IsPaused

	if not screenGui.Enabled then
		clearAllPreviews()
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

ReplicatedStorage:WaitForChild("Perk_UpdateStats").OnClientEvent:Connect(onPerkStats)
ReplicatedStorage:WaitForChild("Combat_UpdateStats").OnClientEvent:Connect(onCombatStats)
ReplicatedStorage:WaitForChild("Combat_PauseState").OnClientEvent:Connect(onPauseState)
ReplicatedStorage:WaitForChild("Run_StateUpdate").OnClientEvent:Connect(onRunState)
ReplicatedStorage:WaitForChild("Perk_HideChoices").OnClientEvent:Connect(clearAllPreviews)

refreshRows()
