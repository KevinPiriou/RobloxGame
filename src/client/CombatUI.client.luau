local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ChestConfig = require(Shared:WaitForChild("ChestConfig"))
local DebugLog = require(Shared:WaitForChild("DebugLog"))
local HudMessageConfig = require(Shared:WaitForChild("HudMessageConfig"))

local function setNativeHealthGuiEnabled(isEnabled)
	task.spawn(function()
		local lastError = nil

		for _ = 1, 5 do
			local success, err = pcall(function()
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, isEnabled)
			end)

			if success then
				return
			end

			lastError = err
			task.wait(0.5)
		end

		DebugLog.Warn("UI", "CoreGui Health impossible a modifier", {
			Enabled = isEnabled,
			Error = tostring(lastError),
		})
	end)
end

setNativeHealthGuiEnabled(false)

local existingGui = playerGui:FindFirstChild("CombatGui")

if existingGui ~= nil then
	existingGui:Destroy()
end

local COLORS = {
	Text = Color3.fromRGB(248, 250, 255),
	Muted = Color3.fromRGB(183, 190, 206),
	Shadow = Color3.fromRGB(0, 0, 0),
	Track = Color3.fromRGB(7, 10, 17),
	Health = Color3.fromRGB(69, 255, 118),
	HealthDark = Color3.fromRGB(15, 128, 58),
	Shield = Color3.fromRGB(25, 255, 218),
	ShieldDark = Color3.fromRGB(0, 104, 156),
	Arcane = Color3.fromRGB(149, 222, 255),
	Kills = Color3.fromRGB(255, 43, 57),
	Gold = Color3.fromRGB(255, 202, 48),
	Green = Color3.fromRGB(105, 245, 100),
	Xp = Color3.fromRGB(190, 86, 255),
	XpDark = Color3.fromRGB(82, 35, 210),
	DamageFlash = Color3.fromRGB(255, 24, 44),
	Glass = Color3.fromRGB(232, 247, 255),
	GlassTint = Color3.fromRGB(157, 212, 255),
	GlassStroke = Color3.fromRGB(255, 255, 255),
}

-- Remplacer les chaines vides par des ids du catalogue Roblox Studio si besoin.
local ICON_IMAGES = {
	ArcaneGem = "rbxassetid://137344039860332",
	Kills = "rbxassetid://78565181494437",
	Gold = "rbxassetid://137648994340847",
	NextChest = "rbxassetid://75386927173068",
	Timer = "rbxassetid://84807607704086",
	Pause = "rbxassetid://99288878339871",
	Play = "rbxassetid://111726051060051",
	Health = "rbxassetid://107129416801939",
	Shield = "rbxassetid://125061574107320",
}

local UI_FONTS = {
	Regular = Enum.Font.Gotham,
	Medium = Enum.Font.GothamMedium,
	Bold = Enum.Font.GothamBold,
	Heavy = Enum.Font.GothamBlack,
}

local RUN_TIMER_SECONDS = 12 * 60
local BAR_TWEEN = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local QUICK_TWEEN = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local EVENT_IN_TWEEN = TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local EVENT_OUT_TWEEN = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local togglePauseRemote = nil
local isPauseButtonBlocked = false
local viewportConnection = nil
local timerRemaining = RUN_TIMER_SECONDS
local damageFlashTween = nil
local eventMessageTweenIn = nil
local eventMessageTweenOut = nil
local eventMessageId = 0
local hasReceivedStatsSnapshot = false

local state = {
	Health = 100,
	MaxHealth = 100,
	Shield = 0,
	MaxShield = 0,
	AliveMonsters = 0,
	MaxAliveMonsters = 1,
	Wave = 1,
	Kills = 0,
	WeaponName = "Fireball",
	Coins = 0,
	ArcaneGems = math.max(0, math.floor(tonumber(player:GetAttribute("ArcaneGems")) or 0)),
	NextChestCost = ChestConfig.BaseOpenCost,
	Level = 1,
	Xp = 0,
	XpRequired = 6,
	PerkCount = 0,
	IsRunActive = false,
	IsUserPaused = false,
	HasBlockingPause = false,
}

state.IsRunActive = player:GetAttribute("IsRunActive") == true

local function addCorner(instance, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance

	return corner
end

local function addStroke(instance, color, transparency, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Transparency = transparency or 0
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
	label.Font = font or UI_FONTS.Bold
	label.Text = text or ""
	label.TextColor3 = color or COLORS.Text
	label.TextSize = textSize or 14
	label.TextStrokeColor3 = COLORS.Shadow
	label.TextStrokeTransparency = 0.45
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = parent

	return label
end

local function createIcon(parent, name, imageId, fallbackText, color, preserveImageColors)
	local holder = Instance.new("Frame")
	holder.Name = name
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	holder.Parent = parent

	if imageId ~= nil and imageId ~= "" then
		local image = Instance.new("ImageLabel")
		image.Name = "Image"
		image.BackgroundTransparency = 1
		image.Image = imageId
		image.ImageColor3 = if preserveImageColors then Color3.new(1, 1, 1) else (color or COLORS.Text)
		image.ScaleType = Enum.ScaleType.Fit
		image.Size = UDim2.fromScale(1, 1)
		image.Parent = holder
	else
		local label = createLabel(holder, "Fallback", fallbackText, UI_FONTS.Heavy, 18, color or COLORS.Text)
		label.Size = UDim2.fromScale(1, 1)
		label.TextXAlignment = Enum.TextXAlignment.Center
		label.TextYAlignment = Enum.TextYAlignment.Center
		addTextSizeConstraint(label, 11, 18)
	end

	return holder
end

local function createBar(parent, name, fillColor, _fillDarkColor)
	local track = Instance.new("Frame")
	track.Name = name .. "Track"
	track.BackgroundColor3 = COLORS.Track
	track.BackgroundTransparency = 0.12
	track.BorderSizePixel = 0
	track.ClipsDescendants = true
	track.Parent = parent
	addCorner(track, 7)
	addStroke(track, COLORS.GlassStroke, 0.76, 1)

	local fill = Instance.new("Frame")
	fill.Name = name .. "Fill"
	fill.BackgroundColor3 = fillColor
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	fill.Parent = track
	addCorner(fill, 7)

	return track, fill
end

local function addGlassBackground(parent, name, position, size, radius)
	local glass = Instance.new("Frame")
	glass.Name = name
	glass.Position = position
	glass.Size = size
	glass.BackgroundColor3 = COLORS.Glass
	glass.BackgroundTransparency = 0.74
	glass.BorderSizePixel = 0
	glass.ZIndex = 0
	glass.Parent = parent
	addCorner(glass, radius)
	addStroke(glass, COLORS.GlassStroke, 0.58, 1)
	addGradient(glass, COLORS.Glass, COLORS.GlassTint, 90)

	return glass
end

local function addRunGlassSurface(parent, name, position, size, radius, accent)
	local surface = Instance.new("Frame")
	surface.Name = name
	surface.Position = position
	surface.Size = size
	surface.BackgroundColor3 = Color3.fromRGB(17, 27, 39)
	surface.BackgroundTransparency = 0.24
	surface.BorderSizePixel = 0
	surface.ZIndex = 0
	surface.Parent = parent
	addCorner(surface, radius)
	addStroke(surface, Color3.fromRGB(7, 12, 19), 0.16, 3)
	addStroke(surface, accent, 0.56, 1)
	addGradient(surface, Color3.fromRGB(47, 64, 86), Color3.fromRGB(12, 20, 31), 90)

	return surface
end

local function addTopBarGlassSurface(parent, name, position, size, radius)
	local surface = Instance.new("Frame")
	surface.Name = name
	surface.Position = position
	surface.Size = size
	surface.BackgroundColor3 = Color3.fromRGB(37, 51, 70)
	surface.BackgroundTransparency = 0.26
	surface.BorderSizePixel = 0
	surface.ZIndex = 0
	surface.Parent = parent
	addCorner(surface, radius)
	addStroke(surface, COLORS.GlassTint, 0.36, 2)
	addGradient(surface, Color3.fromRGB(61, 81, 108), Color3.fromRGB(17, 27, 39), 90)

	local inner = Instance.new("Frame")
	inner.Name = "Inner"
	inner.Position = UDim2.fromOffset(4, 4)
	inner.Size = UDim2.new(1, -8, 1, -8)
	inner.BackgroundColor3 = Color3.fromRGB(17, 27, 39)
	inner.BackgroundTransparency = 0.38
	inner.BorderSizePixel = 0
	inner.Parent = surface
	addCorner(inner, math.max(0, radius - 3))
	addStroke(inner, COLORS.GlassStroke, 0.66, 1)

	return surface
end

local function setBarProgress(fill, progress)
	TweenService:Create(fill, BAR_TWEEN, {
		Size = UDim2.new(math.clamp(progress, 0, 1), 0, 1, 0),
	}):Play()
end

local function formatNumber(value)
	local number = math.floor(tonumber(value) or 0)
	local text = tostring(number)
	local left, middle, right = string.match(text, "^([^%d]*%d)(%d*)(.-)$")

	if left == nil then
		return text
	end

	return left .. (middle:reverse():gsub("(%d%d%d)", "%1,"):reverse()) .. right
end

local function formatTopStatNumber(value)
	local number = math.max(0, math.floor(tonumber(value) or 0))

	if number >= 1000000 then
		return "1M"
	end

	return formatNumber(number)
end

local function formatTimer(seconds)
	local safeSeconds = math.max(0, math.floor(seconds + 0.5))
	local minutes = math.floor(safeSeconds / 60)
	local remainingSeconds = safeSeconds % 60

	return ("%02d:%02d"):format(minutes, remainingSeconds)
end

local function getViewportSize()
	local currentCamera = Workspace.CurrentCamera

	if currentCamera == nil then
		return Vector2.new(1280, 720)
	end

	return currentCamera.ViewportSize
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CombatGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 6
screenGui.Parent = playerGui

local damageFlash = Instance.new("Frame")
damageFlash.Name = "DamageFlash"
damageFlash.Size = UDim2.fromScale(1, 1)
damageFlash.BackgroundColor3 = COLORS.DamageFlash
damageFlash.BackgroundTransparency = 1
damageFlash.BorderSizePixel = 0
damageFlash.ZIndex = 1000
damageFlash.Parent = screenGui

local function playDamageFlash()
	if damageFlashTween ~= nil then
		damageFlashTween:Cancel()
		damageFlashTween = nil
	end

	damageFlash.BackgroundTransparency = 0.82
	damageFlashTween = TweenService:Create(damageFlash, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	})
	damageFlashTween:Play()
end

local TOP_CLUSTER_WIDTH = 960
local TOP_CLUSTER_HEIGHT = 70
local TOP_FRAME_HEIGHT = 60
local TOP_PAUSE_SIZE = 22
local TOP_STAT_ICON_SIZE = 28
local TOP_STAT_TEXT_SIZE = 20

local topCluster = Instance.new("Frame")
topCluster.Name = "TopCluster"
topCluster.AnchorPoint = Vector2.new(0.5, 0)
topCluster.Position = UDim2.new(0.5, 0, 0, 2)
topCluster.Size = UDim2.fromOffset(TOP_CLUSTER_WIDTH, TOP_CLUSTER_HEIGHT)
topCluster.BackgroundTransparency = 1
topCluster.BorderSizePixel = 0
topCluster.Parent = screenGui

local topScale = Instance.new("UIScale")
topScale.Parent = topCluster

local topFrame = Instance.new("Frame")
topFrame.Name = "TopMetalFrame"
topFrame.Size = UDim2.new(1, 0, 0, TOP_FRAME_HEIGHT)
topFrame.BackgroundColor3 = Color3.fromRGB(37, 51, 70)
topFrame.BackgroundTransparency = 0.26
topFrame.BorderSizePixel = 0
topFrame.Parent = topCluster
addCorner(topFrame, 12)
addStroke(topFrame, COLORS.GlassTint, 0.36, 2)
addGradient(topFrame, Color3.fromRGB(61, 81, 108), Color3.fromRGB(17, 27, 39), 90)

local topInner = Instance.new("Frame")
topInner.Name = "TopInner"
topInner.Position = UDim2.fromOffset(4, 4)
topInner.Size = UDim2.new(1, -8, 1, -8)
topInner.BackgroundColor3 = Color3.fromRGB(17, 27, 39)
topInner.BackgroundTransparency = 0.38
topInner.BorderSizePixel = 0
topInner.Parent = topFrame
addCorner(topInner, 9)
addStroke(topInner, COLORS.GlassStroke, 0.66, 1)

local lobbyArcaneChip = Instance.new("Frame")
lobbyArcaneChip.Name = "LobbyArcaneChip"
lobbyArcaneChip.AnchorPoint = Vector2.new(0.5, 0)
lobbyArcaneChip.Position = UDim2.new(0.5, 0, 0, 4)
lobbyArcaneChip.Size = UDim2.fromOffset(148, 38)
lobbyArcaneChip.BackgroundTransparency = 1
lobbyArcaneChip.BorderSizePixel = 0
lobbyArcaneChip.Parent = screenGui
addTopBarGlassSurface(lobbyArcaneChip, "Background", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 8)

local lobbyArcaneIcon = createIcon(lobbyArcaneChip, "ArcaneIcon", ICON_IMAGES.ArcaneGem, "A", COLORS.Arcane, true)
lobbyArcaneIcon.Position = UDim2.fromOffset(12, 7)
lobbyArcaneIcon.Size = UDim2.fromOffset(24, 24)

local lobbyArcaneCaption = createLabel(lobbyArcaneChip, "Caption", "GEMMES", UI_FONTS.Bold, 9, COLORS.Muted)
lobbyArcaneCaption.Position = UDim2.fromOffset(43, 4)
lobbyArcaneCaption.Size = UDim2.fromOffset(92, 12)

local lobbyArcaneValue = createLabel(lobbyArcaneChip, "Value", "0", UI_FONTS.Heavy, 18, COLORS.Arcane)
lobbyArcaneValue.Position = UDim2.fromOffset(43, 15)
lobbyArcaneValue.Size = UDim2.fromOffset(92, 19)
addTextSizeConstraint(lobbyArcaneValue, 12, 18)

local arcaneSlot = Instance.new("Frame")
arcaneSlot.Name = "ArcaneSlot"
arcaneSlot.AnchorPoint = Vector2.new(0, 0.5)
arcaneSlot.Position = UDim2.fromOffset(32, 30)
arcaneSlot.Size = UDim2.fromOffset(82, 28)
arcaneSlot.BackgroundTransparency = 1
arcaneSlot.BorderSizePixel = 0
arcaneSlot.Parent = topCluster

local arcaneIcon = createIcon(arcaneSlot, "ArcaneIcon", ICON_IMAGES.ArcaneGem, "A", COLORS.Arcane, true)
arcaneIcon.AnchorPoint = Vector2.new(0, 0.5)
arcaneIcon.Position = UDim2.fromOffset(0, 14)
arcaneIcon.Size = UDim2.fromOffset(TOP_STAT_ICON_SIZE, TOP_STAT_ICON_SIZE)

local arcaneValue = createLabel(arcaneSlot, "ArcaneValue", "0", UI_FONTS.Heavy, TOP_STAT_TEXT_SIZE, COLORS.Arcane)
arcaneValue.AnchorPoint = Vector2.new(0, 0.5)
arcaneValue.Position = UDim2.fromOffset(34, 14)
arcaneValue.Size = UDim2.fromOffset(48, 28)
arcaneValue.TextScaled = true
arcaneValue.TextXAlignment = Enum.TextXAlignment.Left
addTextSizeConstraint(arcaneValue, 11, TOP_STAT_TEXT_SIZE)

local killsSlot = Instance.new("Frame")
killsSlot.Name = "KillsSlot"
killsSlot.AnchorPoint = Vector2.new(0, 0.5)
killsSlot.Position = UDim2.fromOffset(142, 30)
killsSlot.Size = UDim2.fromOffset(74, 28)
killsSlot.BackgroundTransparency = 1
killsSlot.BorderSizePixel = 0
killsSlot.Parent = topCluster

local killsIcon = createIcon(killsSlot, "KillsIcon", ICON_IMAGES.Kills, "K", COLORS.Kills)
killsIcon.AnchorPoint = Vector2.new(0, 0.5)
killsIcon.Position = UDim2.fromOffset(0, 14)
killsIcon.Size = UDim2.fromOffset(TOP_STAT_ICON_SIZE, TOP_STAT_ICON_SIZE)

local killsValue = createLabel(killsSlot, "KillsValue", "0", UI_FONTS.Heavy, TOP_STAT_TEXT_SIZE, COLORS.Kills)
killsValue.AnchorPoint = Vector2.new(0, 0.5)
killsValue.Position = UDim2.fromOffset(34, 14)
killsValue.Size = UDim2.fromOffset(40, 28)
killsValue.TextScaled = true
killsValue.TextXAlignment = Enum.TextXAlignment.Left
addTextSizeConstraint(killsValue, 11, TOP_STAT_TEXT_SIZE)

local goldSlot = Instance.new("Frame")
goldSlot.Name = "GoldSlot"
goldSlot.AnchorPoint = Vector2.new(0, 0.5)
goldSlot.Position = UDim2.fromOffset(252, 30)
goldSlot.Size = UDim2.fromOffset(74, 28)
goldSlot.BackgroundTransparency = 1
goldSlot.BorderSizePixel = 0
goldSlot.Parent = topCluster

local goldIcon = createIcon(goldSlot, "GoldIcon", ICON_IMAGES.Gold, "G", COLORS.Gold)
goldIcon.AnchorPoint = Vector2.new(0, 0.5)
goldIcon.Position = UDim2.fromOffset(0, 14)
goldIcon.Size = UDim2.fromOffset(TOP_STAT_ICON_SIZE, TOP_STAT_ICON_SIZE)

local goldValue = createLabel(goldSlot, "GoldValue", "0", UI_FONTS.Heavy, TOP_STAT_TEXT_SIZE, COLORS.Gold)
goldValue.AnchorPoint = Vector2.new(0, 0.5)
goldValue.Position = UDim2.fromOffset(34, 14)
goldValue.Size = UDim2.fromOffset(40, 28)
goldValue.TextScaled = true
goldValue.TextXAlignment = Enum.TextXAlignment.Left
addTextSizeConstraint(goldValue, 11, TOP_STAT_TEXT_SIZE)

local chestCostSlot = Instance.new("Frame")
chestCostSlot.Name = "ChestCostSlot"
chestCostSlot.AnchorPoint = Vector2.new(0, 0.5)
chestCostSlot.Position = UDim2.fromOffset(560, 30)
chestCostSlot.Size = UDim2.fromOffset(238, 28)
chestCostSlot.BackgroundTransparency = 1
chestCostSlot.BorderSizePixel = 0
chestCostSlot.Parent = topCluster

local chestCostCoinIcon = createIcon(chestCostSlot, "CoinIcon", ICON_IMAGES.Gold, "G", COLORS.Gold)
chestCostCoinIcon.AnchorPoint = Vector2.new(0, 0.5)
chestCostCoinIcon.Position = UDim2.fromOffset(0, 14)
chestCostCoinIcon.Size = UDim2.fromOffset(19, 19)

local chestCostIcon = createIcon(chestCostSlot, "ChestIcon", ICON_IMAGES.NextChest, "C", COLORS.Gold, true)
chestCostIcon.AnchorPoint = Vector2.new(0, 0.5)
chestCostIcon.Position = UDim2.fromOffset(16, 14)
chestCostIcon.Size = UDim2.fromOffset(26, 26)

local chestCostValue = createLabel(chestCostSlot, "ChestCostValue", "5", UI_FONTS.Heavy, TOP_STAT_TEXT_SIZE, COLORS.Gold)
chestCostValue.AnchorPoint = Vector2.new(0, 0.5)
chestCostValue.Position = UDim2.fromOffset(49, 14)
chestCostValue.Size = UDim2.fromOffset(58, 28)
chestCostValue.TextScaled = true
chestCostValue.TextXAlignment = Enum.TextXAlignment.Left
addTextSizeConstraint(chestCostValue, 11, TOP_STAT_TEXT_SIZE)

local topLevelValue = createLabel(chestCostSlot, "TopLevelValue", "LVL 1", UI_FONTS.Heavy, 18, COLORS.Text)
topLevelValue.AnchorPoint = Vector2.new(0, 0.5)
topLevelValue.Position = UDim2.fromOffset(116, 14)
topLevelValue.Size = UDim2.fromOffset(96, 28)
topLevelValue.TextScaled = true
topLevelValue.TextXAlignment = Enum.TextXAlignment.Left
addTextSizeConstraint(topLevelValue, 12, 18)

local pauseDiamond = Instance.new("Frame")
pauseDiamond.Name = "PauseDiamond"
pauseDiamond.AnchorPoint = Vector2.new(0.5, 0.5)
pauseDiamond.Position = UDim2.new(0.5, 0, 0, 45)
pauseDiamond.Size = UDim2.fromOffset(30, 30)
pauseDiamond.BackgroundColor3 = Color3.fromRGB(21, 34, 52)
pauseDiamond.BackgroundTransparency = 0.08
pauseDiamond.BorderSizePixel = 0
pauseDiamond.Rotation = 45
pauseDiamond.Parent = topCluster
addCorner(pauseDiamond, 4)
addStroke(pauseDiamond, Color3.fromRGB(164, 222, 255), 0.24, 1)
addGradient(pauseDiamond, Color3.fromRGB(68, 98, 138), Color3.fromRGB(18, 25, 38), 45)

local pauseButton = Instance.new("TextButton")
pauseButton.Name = "PauseButton"
pauseButton.AnchorPoint = Vector2.new(0.5, 0.5)
pauseButton.Position = UDim2.new(0.5, 0, 0, 45)
pauseButton.Size = UDim2.fromOffset(TOP_PAUSE_SIZE, TOP_PAUSE_SIZE)
pauseButton.BackgroundTransparency = 1
pauseButton.BorderSizePixel = 0
pauseButton.Text = ""
pauseButton.AutoButtonColor = true
pauseButton.Parent = topCluster

local pauseImage = Instance.new("ImageLabel")
pauseImage.Name = "PauseImage"
pauseImage.BackgroundTransparency = 1
pauseImage.Image = ICON_IMAGES.Pause
pauseImage.ScaleType = Enum.ScaleType.Fit
pauseImage.Size = UDim2.fromScale(1, 1)
pauseImage.Parent = pauseButton

local timerSlot = Instance.new("Frame")
timerSlot.Name = "TimerSlot"
timerSlot.AnchorPoint = Vector2.new(0.5, 0.5)
timerSlot.Position = UDim2.new(0.5, 0, 0, 30)
timerSlot.Size = UDim2.fromOffset(112, 28)
timerSlot.BackgroundTransparency = 1
timerSlot.BorderSizePixel = 0
timerSlot.Parent = topCluster

local timerImage = Instance.new("ImageLabel")
timerImage.Name = "TimerImage"
timerImage.AnchorPoint = Vector2.new(0.5, 0.5)
timerImage.Position = UDim2.fromScale(0.5, 0.5)
timerImage.Size = UDim2.fromOffset(40, 40)
timerImage.BackgroundTransparency = 1
timerImage.Image = ICON_IMAGES.Timer
timerImage.ScaleType = Enum.ScaleType.Fit
timerImage.ImageTransparency = 0.2
timerImage.Parent = timerSlot

local timerLabel = createLabel(timerSlot, "TimerLabel", "12:00", UI_FONTS.Heavy, 18, Color3.fromRGB(220, 246, 255))
timerLabel.Size = UDim2.fromScale(1, 1)
timerLabel.TextXAlignment = Enum.TextXAlignment.Center
timerLabel.TextStrokeTransparency = 0.08
timerLabel.ZIndex = 2
addTextSizeConstraint(timerLabel, 12, 18)

local eventMessageFrame = Instance.new("Frame")
eventMessageFrame.Name = "EventMessageFrame"
eventMessageFrame.AnchorPoint = Vector2.new(0.5, 0)
eventMessageFrame.Position = UDim2.new(0.5, 0, 0, 82)
eventMessageFrame.Size = UDim2.fromOffset(620, 56)
eventMessageFrame.BackgroundTransparency = 1
eventMessageFrame.BorderSizePixel = 0
eventMessageFrame.Visible = false
eventMessageFrame.ZIndex = 120
eventMessageFrame.Parent = screenGui

local eventMessageScale = Instance.new("UIScale")
eventMessageScale.Parent = eventMessageFrame

local eventMessageBackground = Instance.new("Frame")
eventMessageBackground.Name = "Background"
eventMessageBackground.Size = UDim2.fromScale(1, 1)
eventMessageBackground.BackgroundColor3 = Color3.fromRGB(10, 12, 18)
eventMessageBackground.BackgroundTransparency = 1
eventMessageBackground.BorderSizePixel = 0
eventMessageBackground.ZIndex = 120
eventMessageBackground.Parent = eventMessageFrame
addCorner(eventMessageBackground, 14)
local eventMessageStroke = addStroke(eventMessageBackground, COLORS.Text, 1, 2)

local eventMessageAccent = Instance.new("Frame")
eventMessageAccent.Name = "Accent"
eventMessageAccent.Position = UDim2.fromOffset(12, 9)
eventMessageAccent.Size = UDim2.new(0, 5, 1, -18)
eventMessageAccent.BackgroundColor3 = COLORS.Text
eventMessageAccent.BackgroundTransparency = 1
eventMessageAccent.BorderSizePixel = 0
eventMessageAccent.ZIndex = 121
eventMessageAccent.Parent = eventMessageBackground
addCorner(eventMessageAccent, 4)

local eventMessageLabel = createLabel(
	eventMessageBackground,
	"Label",
	HudMessageConfig.Styles[HudMessageConfig.DefaultStyleId].Message,
	UI_FONTS.Heavy,
	28,
	COLORS.Text
)
eventMessageLabel.Position = UDim2.fromOffset(28, 0)
eventMessageLabel.Size = UDim2.new(1, -44, 1, 0)
eventMessageLabel.TextXAlignment = Enum.TextXAlignment.Center
eventMessageLabel.TextYAlignment = Enum.TextYAlignment.Center
eventMessageLabel.TextScaled = true
eventMessageLabel.TextWrapped = true
eventMessageLabel.TextTransparency = 1
eventMessageLabel.TextStrokeTransparency = 1
eventMessageLabel.ZIndex = 122
local eventMessageTextConstraint = addTextSizeConstraint(eventMessageLabel, 16, 34)

local xpPanel = Instance.new("Frame")
xpPanel.Name = "XpPanel"
xpPanel.AnchorPoint = Vector2.new(0.5, 1)
xpPanel.Position = UDim2.new(0.5, 0, 1, -16)
xpPanel.Size = UDim2.new(0.52, 0, 0, 80)
xpPanel.BackgroundTransparency = 1
xpPanel.BorderSizePixel = 0
xpPanel.Parent = screenGui

local xpSize = Instance.new("UISizeConstraint")
xpSize.MinSize = Vector2.new(390, 80)
xpSize.MaxSize = Vector2.new(760, 80)
xpSize.Parent = xpPanel

local xpScale = Instance.new("UIScale")
xpScale.Parent = xpPanel

addTopBarGlassSurface(
	xpPanel,
	"BarsGlassBackground",
	UDim2.fromOffset(-14, -8),
	UDim2.new(1, 28, 1, 16),
	13
)

local hpGroup = Instance.new("Frame")
hpGroup.Name = "HpGroup"
hpGroup.Position = UDim2.fromOffset(0, 0)
hpGroup.Size = UDim2.new(0.45, 0, 0, 36)
hpGroup.BackgroundTransparency = 1
hpGroup.Parent = xpPanel
addRunGlassSurface(
	hpGroup,
	"HpGlassSurface",
	UDim2.fromOffset(-7, -5),
	UDim2.new(1, 14, 1, 10),
	8,
	COLORS.Health
)

local hpIcon = createIcon(hpGroup, "HealthIcon", ICON_IMAGES.Health, "+", COLORS.Health)
hpIcon.Position = UDim2.fromOffset(-3, -8)
hpIcon.Size = UDim2.fromOffset(32, 32)

local hpText = createLabel(hpGroup, "HpText", "100 / 100", UI_FONTS.Heavy, 14, COLORS.Health)
hpText.Position = UDim2.fromOffset(36, -1)
hpText.Size = UDim2.new(1, -36, 0, 20)
hpText.TextScaled = true
addTextSizeConstraint(hpText, 11, 15)

local hpTrack, hpFill = createBar(hpGroup, "Health", COLORS.Health, COLORS.HealthDark)
hpTrack.Position = UDim2.fromOffset(0, 22)
hpTrack.Size = UDim2.new(1, 0, 0, 14)

local shieldGroup = Instance.new("Frame")
shieldGroup.Name = "ShieldGroup"
shieldGroup.AnchorPoint = Vector2.new(1, 0)
shieldGroup.Position = UDim2.new(1, 0, 0, 0)
shieldGroup.Size = UDim2.new(0.45, 0, 0, 36)
shieldGroup.BackgroundTransparency = 1
shieldGroup.Parent = xpPanel
addRunGlassSurface(
	shieldGroup,
	"ShieldGlassSurface",
	UDim2.fromOffset(-7, -5),
	UDim2.new(1, 14, 1, 10),
	8,
	COLORS.Shield
)

local shieldHeader = Instance.new("Frame")
shieldHeader.Name = "ShieldHeader"
shieldHeader.AnchorPoint = Vector2.new(0, 0)
shieldHeader.Position = UDim2.fromOffset(0, 0)
shieldHeader.Size = UDim2.new(1, 0, 0, 20)
shieldHeader.BackgroundTransparency = 1
shieldHeader.BorderSizePixel = 0
shieldHeader.Parent = shieldGroup

local shieldIcon = createIcon(shieldHeader, "ShieldIcon", ICON_IMAGES.Shield, "S", COLORS.Shield)
shieldIcon.Position = UDim2.fromOffset(-3, -8)
shieldIcon.Size = UDim2.fromOffset(32, 32)

local shieldText = createLabel(shieldHeader, "ShieldText", "0 / 0", UI_FONTS.Heavy, 14, COLORS.Shield)
shieldText.Position = UDim2.fromOffset(36, -1)
shieldText.Size = UDim2.new(1, -36, 0, 20)
shieldText.TextScaled = true
shieldText.TextXAlignment = Enum.TextXAlignment.Right
addTextSizeConstraint(shieldText, 11, 15)

local shieldTrack, shieldFill = createBar(shieldGroup, "Shield", COLORS.Shield, COLORS.ShieldDark)
shieldTrack.Position = UDim2.fromOffset(0, 22)
shieldTrack.Size = UDim2.new(1, 0, 0, 14)

addRunGlassSurface(
	xpPanel,
	"XpGlassSurface",
	UDim2.fromOffset(-7, 39),
	UDim2.new(1, 14, 0, 47),
	8,
	COLORS.Xp
)

local levelValue = createLabel(xpPanel, "LevelValue", "LVL 1", UI_FONTS.Heavy, 16, COLORS.Xp)
levelValue.Position = UDim2.fromOffset(0, 43)
levelValue.Size = UDim2.fromOffset(72, 18)
addTextSizeConstraint(levelValue, 12, 16)

local xpText = createLabel(xpPanel, "XpText", "XP 0 / 6", UI_FONTS.Heavy, 16, COLORS.Xp)
xpText.AnchorPoint = Vector2.new(1, 0)
xpText.Position = UDim2.new(1, 0, 0, 43)
xpText.Size = UDim2.new(1, -78, 0, 18)
xpText.TextXAlignment = Enum.TextXAlignment.Right
addTextSizeConstraint(xpText, 12, 16)

local xpTrack, xpFill = createBar(xpPanel, "Xp", COLORS.Xp, COLORS.XpDark)
xpTrack.Position = UDim2.fromOffset(0, 64)
xpTrack.Size = UDim2.new(1, 0, 0, 14)

local centerGemOuter = Instance.new("Frame")
centerGemOuter.Name = "CenterGemOuter"
centerGemOuter.AnchorPoint = Vector2.new(0.5, 0.5)
centerGemOuter.Position = UDim2.new(0.5, 0, 0, 18)
centerGemOuter.Size = UDim2.fromOffset(30, 30)
centerGemOuter.BackgroundColor3 = Color3.fromRGB(230, 242, 255)
centerGemOuter.BorderSizePixel = 0
centerGemOuter.Rotation = 45
centerGemOuter.ZIndex = 5
centerGemOuter.Parent = xpPanel
addCorner(centerGemOuter, 5)
addStroke(centerGemOuter, Color3.fromRGB(7, 12, 19), 0.1, 2)

local centerGemGradient = Instance.new("UIGradient")
centerGemGradient.Name = "MetalGradient"
centerGemGradient.Rotation = 45
centerGemGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(76, 224, 255)),
	ColorSequenceKeypoint.new(0.28, Color3.fromRGB(240, 248, 255)),
	ColorSequenceKeypoint.new(0.58, Color3.fromRGB(190, 104, 255)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(244, 250, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(84, 207, 255)),
})
centerGemGradient.Parent = centerGemOuter

local centerGem = Instance.new("Frame")
centerGem.Name = "CenterGem"
centerGem.AnchorPoint = Vector2.new(0.5, 0.5)
centerGem.Position = UDim2.fromScale(0.5, 0.5)
centerGem.Size = UDim2.fromOffset(18, 18)
centerGem.BackgroundColor3 = Color3.fromRGB(15, 24, 37)
centerGem.BackgroundTransparency = 0.08
centerGem.BorderSizePixel = 0
centerGem.Rotation = 45
centerGem.ZIndex = 6
centerGem.Parent = centerGemOuter
addCorner(centerGem, 3)
addStroke(centerGem, Color3.fromRGB(238, 246, 255), 0.42, 1)

local function updateResponsiveLayout()
	local viewportSize = getViewportSize()
	local function getTopScale(targetScale)
		local availableWidth = math.max(1, viewportSize.X - 24)

		return math.min(targetScale, availableWidth / TOP_CLUSTER_WIDTH)
	end

	if viewportSize.X < 560 then
		topCluster.Position = UDim2.new(0.5, 0, 0, 2)
		topScale.Scale = getTopScale(0.72)
		eventMessageFrame.Position = UDim2.new(0.5, 0, 0, 78)
		eventMessageFrame.Size = UDim2.new(0.9, 0, 0, 50)
		eventMessageScale.Scale = 0.84
		xpPanel.Position = UDim2.new(0.5, 0, 1, -8)
		xpPanel.Size = UDim2.new(0.88, 0, 0, 80)
		xpScale.Scale = 0.8
	elseif viewportSize.X < 760 then
		topCluster.Position = UDim2.new(0.5, 0, 0, 2)
		topScale.Scale = getTopScale(0.84)
		eventMessageFrame.Position = UDim2.new(0.5, 0, 0, 82)
		eventMessageFrame.Size = UDim2.new(0.84, 0, 0, 52)
		eventMessageScale.Scale = 0.9
		xpPanel.Position = UDim2.new(0.5, 0, 1, -8)
		xpPanel.Size = UDim2.new(0.82, 0, 0, 80)
		xpScale.Scale = 0.86
	elseif viewportSize.X < 1250 then
		topCluster.Position = UDim2.new(0.5, 0, 0, 2)
		topScale.Scale = getTopScale(0.95)
		eventMessageFrame.Position = UDim2.new(0.5, 0, 0, 86)
		eventMessageFrame.Size = UDim2.new(0.58, 0, 0, 54)
		eventMessageScale.Scale = 0.96
		xpPanel.Position = UDim2.new(0.5, 0, 1, -12)
		xpPanel.Size = UDim2.new(0.62, 0, 0, 80)
		xpScale.Scale = 0.92
	else
		topCluster.Position = UDim2.new(0.5, 0, 0, 2)
		topScale.Scale = getTopScale(1)
		eventMessageFrame.Position = UDim2.new(0.5, 0, 0, 90)
		eventMessageFrame.Size = UDim2.fromOffset(620, 56)
		eventMessageScale.Scale = 1
		xpPanel.Position = UDim2.new(0.5, 0, 1, -16)
		xpPanel.Size = UDim2.new(0.52, 0, 0, 80)
		xpScale.Scale = 1
	end
end

local function refreshCombatStats()
	local healthProgress = state.Health / math.max(1, state.MaxHealth)
	local shieldProgress = 0

	if state.MaxShield > 0 then
		shieldProgress = state.Shield / state.MaxShield
	end

	hpText.Text = ("%s / %s"):format(formatNumber(state.Health), formatNumber(state.MaxHealth))
	shieldText.Text = ("%s / %s"):format(formatNumber(state.Shield), formatNumber(state.MaxShield))
	killsValue.Text = formatTopStatNumber(state.Kills)
	goldValue.Text = formatTopStatNumber(state.Coins)

	setBarProgress(hpFill, healthProgress)
	setBarProgress(shieldFill, shieldProgress)
end

local function refreshXp()
	local progress = state.Xp / math.max(1, state.XpRequired)

	levelValue.Text = ("LVL %s"):format(formatNumber(state.Level))
	topLevelValue.Text = ("LVL %s"):format(formatNumber(state.Level))
	xpText.Text = ("XP %s / %s"):format(formatNumber(state.Xp), formatNumber(state.XpRequired))
	setBarProgress(xpFill, progress)
end

local function refreshCoins()
	goldValue.Text = formatTopStatNumber(state.Coins)
end

local function refreshArcaneGems()
	arcaneValue.Text = formatTopStatNumber(state.ArcaneGems)
	lobbyArcaneValue.Text = formatTopStatNumber(state.ArcaneGems)
end

local function refreshChestCost()
	chestCostValue.Text = formatTopStatNumber(state.NextChestCost)
end

local function refreshTimer()
	timerLabel.Text = formatTimer(timerRemaining)
end

local function refreshRunVisibility()
	topCluster.Visible = state.IsRunActive
	xpPanel.Visible = state.IsRunActive
	lobbyArcaneChip.Visible = not state.IsRunActive

	if not state.IsRunActive then
		eventMessageFrame.Visible = false
	end
end

local function isTimerPaused()
	return not state.IsRunActive or state.IsUserPaused or state.HasBlockingPause
end

local function refreshPause()
	isPauseButtonBlocked = (not state.IsRunActive) or (state.HasBlockingPause and not state.IsUserPaused)
	pauseButton.Active = not isPauseButtonBlocked
	pauseButton.AutoButtonColor = not isPauseButtonBlocked
	pauseImage.Image = if state.IsUserPaused then ICON_IMAGES.Play else ICON_IMAGES.Pause
	pauseImage.ImageTransparency = if isPauseButtonBlocked then 0.45 else 0
end

local function showEventMessage(payload)
	payload = payload or {}

	local styleId = payload.StyleId or HudMessageConfig.DefaultStyleId
	local style = HudMessageConfig.Styles[styleId] or HudMessageConfig.Styles[HudMessageConfig.DefaultStyleId]

	if style == nil then
		return
	end

	eventMessageId += 1
	local currentId = eventMessageId
	local targetBackgroundTransparency = style.BackgroundTransparency or 0.18
	local targetStrokeTransparency = style.StrokeTransparency or 0.35
	local targetTextStrokeTransparency = style.TextStrokeTransparency or 0.28
	local duration = payload.Duration or style.Duration or HudMessageConfig.DefaultDuration

	if eventMessageTweenIn ~= nil then
		eventMessageTweenIn:Cancel()
		eventMessageTweenIn = nil
	end

	if eventMessageTweenOut ~= nil then
		eventMessageTweenOut:Cancel()
		eventMessageTweenOut = nil
	end

	eventMessageFrame.Visible = true
	eventMessageBackground.BackgroundColor3 = style.BackgroundColor or Color3.fromRGB(10, 12, 18)
	eventMessageBackground.BackgroundTransparency = 1
	eventMessageStroke.Color = style.StrokeColor or COLORS.Text
	eventMessageStroke.Transparency = 1
	eventMessageAccent.BackgroundColor3 = style.AccentColor or COLORS.Text
	eventMessageAccent.BackgroundTransparency = 1
	eventMessageLabel.Font = style.Font or UI_FONTS.Heavy
	eventMessageLabel.Text = tostring(payload.Message or style.Message or "Evenement")
	eventMessageLabel.TextColor3 = style.TextColor or COLORS.Text
	eventMessageLabel.TextStrokeColor3 = style.StrokeColor or COLORS.Shadow
	eventMessageLabel.TextTransparency = 1
	eventMessageLabel.TextStrokeTransparency = 1
	eventMessageTextConstraint.MaxTextSize = style.TextSize or 32
	eventMessageTextConstraint.MinTextSize = math.min(18, style.TextSize or 32)

	eventMessageTweenIn = TweenService:Create(eventMessageBackground, EVENT_IN_TWEEN, {
		BackgroundTransparency = targetBackgroundTransparency,
	})
	eventMessageTweenIn:Play()
	TweenService:Create(eventMessageStroke, EVENT_IN_TWEEN, {
		Transparency = targetStrokeTransparency,
	}):Play()
	TweenService:Create(eventMessageAccent, EVENT_IN_TWEEN, {
		BackgroundTransparency = 0,
	}):Play()
	TweenService:Create(eventMessageLabel, EVENT_IN_TWEEN, {
		TextTransparency = 0,
		TextStrokeTransparency = targetTextStrokeTransparency,
	}):Play()

	task.delay(duration, function()
		if currentId ~= eventMessageId then
			return
		end

		eventMessageTweenOut = TweenService:Create(eventMessageBackground, EVENT_OUT_TWEEN, {
			BackgroundTransparency = 1,
		})
		eventMessageTweenOut:Play()
		TweenService:Create(eventMessageStroke, EVENT_OUT_TWEEN, {
			Transparency = 1,
		}):Play()
		TweenService:Create(eventMessageAccent, EVENT_OUT_TWEEN, {
			BackgroundTransparency = 1,
		}):Play()
		TweenService:Create(eventMessageLabel, EVENT_OUT_TWEEN, {
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}):Play()

		task.delay(EVENT_OUT_TWEEN.Time, function()
			if currentId == eventMessageId then
				eventMessageFrame.Visible = false
			end
		end)
	end)
end

local function onHudMessagePayload(payload)
	showEventMessage(payload)
end

local function onStatsPayload(payload)
	payload = payload or {}

	local previousHealth = state.Health
	local previousShield = state.Shield

	state.Health = payload.Health or state.Health
	state.MaxHealth = math.max(1, payload.MaxHealth or state.MaxHealth)
	state.Shield = payload.Shield or state.Shield
	state.MaxShield = math.max(0, payload.MaxShield or state.MaxShield)
	state.AliveMonsters = payload.AliveMonsters or state.AliveMonsters
	state.MaxAliveMonsters = math.max(1, payload.MaxAliveMonsters or state.MaxAliveMonsters)
	state.Wave = payload.Wave or state.Wave
	state.Kills = payload.Kills or state.Kills
	state.WeaponName = payload.WeaponName or state.WeaponName

	if hasReceivedStatsSnapshot and (state.Health < previousHealth or state.Shield < previousShield) then
		playDamageFlash()
	end

	hasReceivedStatsSnapshot = true
	refreshCombatStats()
end

local function onXpPayload(payload)
	payload = payload or {}

	state.Xp = payload.Xp or state.Xp
	state.Level = payload.Level or state.Level
	state.XpRequired = math.max(1, payload.XpRequired or state.XpRequired)
	refreshXp()
end

local function onCoinsPayload(payload)
	payload = payload or {}

	state.Coins = payload.Coins or state.Coins
	refreshCoins()
end

local function onChestPricePayload(payload)
	payload = payload or {}

	if payload.Coins ~= nil then
		state.Coins = payload.Coins
		refreshCoins()
	end

	if payload.NextOpenCost ~= nil then
		state.NextChestCost = math.max(0, math.floor(tonumber(payload.NextOpenCost) or state.NextChestCost))
		refreshChestCost()
	end
end

local function onPerksPayload(payload)
	payload = payload or {}

	local previousShield = state.Shield

	if payload.CurrentShield ~= nil then
		state.Shield = payload.CurrentShield
	end

	if payload.MaxShield ~= nil then
		state.MaxShield = math.max(0, payload.MaxShield)
	end

	if hasReceivedStatsSnapshot and state.Shield < previousShield then
		playDamageFlash()
	end

	refreshCombatStats()
end

local function onPausePayload(payload)
	payload = payload or {}

	state.IsUserPaused = payload.IsUserPaused == true
	state.HasBlockingPause = payload.HasBlockingPause == true
	refreshPause()
end

local function onRunStatePayload(payload)
	payload = payload or {}

	local wasRunActive = state.IsRunActive

	state.IsRunActive = payload.IsRunActive == true

	if state.IsRunActive and not wasRunActive then
		timerRemaining = RUN_TIMER_SECONDS
	elseif not state.IsRunActive then
		timerRemaining = RUN_TIMER_SECONDS
	end

	refreshTimer()
	refreshPause()
	refreshRunVisibility()
end

local function waitForRemote(remoteName)
	local remote = ReplicatedStorage:FindFirstChild(remoteName)

	if remote == nil then
		remote = ReplicatedStorage:WaitForChild(remoteName, 20)
	end

	if remote == nil then
		DebugLog.Warn("UI", "Remote HUD introuvable", {
			Remote = remoteName,
		})
	end

	return remote
end

local function bindRemote(remoteName, callback)
	task.spawn(function()
		local remote = waitForRemote(remoteName)

		if remote == nil then
			return
		end

		remote.OnClientEvent:Connect(callback)
		DebugLog.Info("UI", "Remote HUD connecte", {
			Remote = remoteName,
		})
	end)
end

bindRemote("Combat_UpdateStats", onStatsPayload)
bindRemote("Xp_UpdateCount", onXpPayload)
bindRemote("Coin_UpdateCount", onCoinsPayload)
bindRemote("Chest_PriceUpdate", onChestPricePayload)
bindRemote("Perk_UpdateStats", onPerksPayload)
bindRemote("Combat_PauseState", onPausePayload)
bindRemote("Run_StateUpdate", onRunStatePayload)
bindRemote(HudMessageConfig.RemoteName, onHudMessagePayload)

player:GetAttributeChangedSignal("IsRunActive"):Connect(function()
	onRunStatePayload({
		IsRunActive = player:GetAttribute("IsRunActive") == true,
	})
end)

player:GetAttributeChangedSignal("ArcaneGems"):Connect(function()
	state.ArcaneGems = math.max(0, math.floor(tonumber(player:GetAttribute("ArcaneGems")) or 0))
	refreshArcaneGems()
end)

task.spawn(function()
	togglePauseRemote = waitForRemote("Combat_TogglePause")
end)

pauseButton.Activated:Connect(function()
	if isPauseButtonBlocked then
		return
	end

	if togglePauseRemote == nil then
		DebugLog.Warn("UI", "Pause ignoree, remote pas encore pret")
		return
	end

	togglePauseRemote:FireServer()
end)

RunService.RenderStepped:Connect(function(deltaTime)
	if timerRemaining <= 0 or isTimerPaused() then
		return
	end

	timerRemaining = math.max(0, timerRemaining - deltaTime)
	refreshTimer()
end)

if Workspace.CurrentCamera ~= nil then
	viewportConnection = Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveLayout)
end

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	if viewportConnection ~= nil then
		viewportConnection:Disconnect()
		viewportConnection = nil
	end

	if Workspace.CurrentCamera ~= nil then
		viewportConnection = Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveLayout)
	end

	updateResponsiveLayout()
end)

refreshCombatStats()
refreshXp()
refreshCoins()
refreshArcaneGems()
refreshChestCost()
refreshTimer()
refreshRunVisibility()
refreshPause()
updateResponsiveLayout()

DebugLog.Info("UI", "HUD combat epure initialise", {
	Player = player.Name,
})
