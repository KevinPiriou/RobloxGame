local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DebugLog = require(Shared:WaitForChild("DebugLog"))

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
	Kills = "rbxassetid://78565181494437",
	Gold = "rbxassetid://137648994340847",
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

local togglePauseRemote = nil
local isPauseButtonBlocked = false
local viewportConnection = nil
local timerRemaining = RUN_TIMER_SECONDS
local damageFlashTween = nil
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
	Level = 1,
	Xp = 0,
	XpRequired = 6,
	PerkCount = 0,
	IsUserPaused = false,
	HasBlockingPause = false,
}

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

local function createIcon(parent, name, imageId, fallbackText, color)
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
		image.ImageColor3 = color or COLORS.Text
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
	track.BackgroundTransparency = 0.18
	track.BorderSizePixel = 0
	track.ClipsDescendants = true
	track.Parent = parent
	addCorner(track, 7)

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
screenGui.IgnoreGuiInset = false
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

local topCluster = Instance.new("Frame")
topCluster.Name = "TopCluster"
topCluster.AnchorPoint = Vector2.new(0.5, 0)
topCluster.Position = UDim2.new(0.5, 0, 0, 12)
topCluster.Size = UDim2.fromOffset(640, 70)
topCluster.BackgroundTransparency = 1
topCluster.BorderSizePixel = 0
topCluster.Parent = screenGui

local topScale = Instance.new("UIScale")
topScale.Parent = topCluster

local topPauseSize = 44
local topStatSlotWidth = 138
local topStatValueOffset = 52
local topStatIconSize = math.floor(topPauseSize * 1.1)
local topStatTextSize = math.floor(topPauseSize * 0.72)

addGlassBackground(topCluster, "TopStatsGlassBackground", UDim2.fromOffset(-8, -1), UDim2.fromOffset(302, 45), 13)

local killsSlot = Instance.new("Frame")
killsSlot.Name = "KillsSlot"
killsSlot.Position = UDim2.fromOffset(0, -3)
killsSlot.Size = UDim2.fromOffset(topStatSlotWidth, 52)
killsSlot.BackgroundTransparency = 1
killsSlot.BorderSizePixel = 0
killsSlot.Parent = topCluster

local killsIcon = createIcon(killsSlot, "KillsIcon", ICON_IMAGES.Kills, "K", COLORS.Kills)
killsIcon.Position = UDim2.fromOffset(0, 0)
killsIcon.Size = UDim2.fromOffset(topStatIconSize, topStatIconSize)

local killsValue = createLabel(killsSlot, "KillsValue", "0", UI_FONTS.Heavy, topStatTextSize, COLORS.Kills)
killsValue.Position = UDim2.fromOffset(topStatValueOffset, 1)
killsValue.Size = UDim2.fromOffset(topStatSlotWidth - topStatValueOffset, 43)
killsValue.TextScaled = true
killsValue.TextXAlignment = Enum.TextXAlignment.Left
addTextSizeConstraint(killsValue, 15, topStatTextSize)

local goldSlot = Instance.new("Frame")
goldSlot.Name = "GoldSlot"
goldSlot.Position = UDim2.fromOffset(148, -3)
goldSlot.Size = UDim2.fromOffset(topStatSlotWidth, 52)
goldSlot.BackgroundTransparency = 1
goldSlot.BorderSizePixel = 0
goldSlot.Parent = topCluster

local goldIcon = createIcon(goldSlot, "GoldIcon", ICON_IMAGES.Gold, "G", COLORS.Gold)
goldIcon.Position = UDim2.fromOffset(0, 0)
goldIcon.Size = UDim2.fromOffset(topStatIconSize, topStatIconSize)

local goldValue = createLabel(goldSlot, "GoldValue", "0", UI_FONTS.Heavy, topStatTextSize, COLORS.Gold)
goldValue.Position = UDim2.fromOffset(topStatValueOffset, 1)
goldValue.Size = UDim2.fromOffset(topStatSlotWidth - topStatValueOffset, 43)
goldValue.TextScaled = true
goldValue.TextXAlignment = Enum.TextXAlignment.Left
addTextSizeConstraint(goldValue, 15, topStatTextSize)

local pauseButton = Instance.new("TextButton")
pauseButton.Name = "PauseButton"
pauseButton.AnchorPoint = Vector2.new(0.5, 0)
pauseButton.Position = UDim2.new(0.5, 0, 0, 0)
pauseButton.Size = UDim2.fromOffset(topPauseSize, topPauseSize)
pauseButton.BackgroundColor3 = Color3.fromRGB(5, 8, 14)
pauseButton.BackgroundTransparency = 0.18
pauseButton.BorderSizePixel = 0
pauseButton.Font = UI_FONTS.Heavy
pauseButton.Text = "||"
pauseButton.TextColor3 = COLORS.Green
pauseButton.TextSize = 22
pauseButton.TextStrokeTransparency = 0.45
pauseButton.AutoButtonColor = true
pauseButton.Parent = topCluster
addCorner(pauseButton, 10)
addStroke(pauseButton, COLORS.Green, 0.38, 1)
addTextSizeConstraint(pauseButton, 15, 22)

local timerLabel = createLabel(topCluster, "TimerLabel", "12:00", UI_FONTS.Bold, 15, COLORS.Text)
timerLabel.AnchorPoint = Vector2.new(0.5, 0)
timerLabel.Position = UDim2.new(0.5, 0, 0, 45)
timerLabel.Size = UDim2.fromOffset(82, 20)
timerLabel.TextXAlignment = Enum.TextXAlignment.Center
addTextSizeConstraint(timerLabel, 11, 15)

local xpPanel = Instance.new("Frame")
xpPanel.Name = "XpPanel"
xpPanel.AnchorPoint = Vector2.new(0.5, 1)
xpPanel.Position = UDim2.new(0.5, 0, 1, -16)
xpPanel.Size = UDim2.new(0.52, 0, 0, 72)
xpPanel.BackgroundTransparency = 1
xpPanel.BorderSizePixel = 0
xpPanel.Parent = screenGui

local xpSize = Instance.new("UISizeConstraint")
xpSize.MinSize = Vector2.new(390, 72)
xpSize.MaxSize = Vector2.new(760, 72)
xpSize.Parent = xpPanel

local xpScale = Instance.new("UIScale")
xpScale.Parent = xpPanel

addGlassBackground(xpPanel, "BarsGlassBackground", UDim2.fromOffset(-14, -8), UDim2.new(1, 28, 1, 16), 13)

local hpGroup = Instance.new("Frame")
hpGroup.Name = "HpGroup"
hpGroup.Position = UDim2.fromOffset(0, 0)
hpGroup.Size = UDim2.new(0.45, 0, 0, 32)
hpGroup.BackgroundTransparency = 1
hpGroup.Parent = xpPanel

local hpIcon = createIcon(hpGroup, "HealthIcon", ICON_IMAGES.Health, "+", COLORS.Health)
hpIcon.Position = UDim2.fromOffset(-3, -7)
hpIcon.Size = UDim2.fromOffset(28, 28)

local hpText = createLabel(hpGroup, "HpText", "100 / 100", UI_FONTS.Heavy, 14, COLORS.Health)
hpText.Position = UDim2.fromOffset(31, -1)
hpText.Size = UDim2.new(1, -31, 0, 18)
hpText.TextScaled = true
addTextSizeConstraint(hpText, 11, 15)

local hpTrack, hpFill = createBar(hpGroup, "Health", COLORS.Health, COLORS.HealthDark)
hpTrack.Position = UDim2.fromOffset(0, 19)
hpTrack.Size = UDim2.new(1, 0, 0, 13)

local shieldGroup = Instance.new("Frame")
shieldGroup.Name = "ShieldGroup"
shieldGroup.AnchorPoint = Vector2.new(1, 0)
shieldGroup.Position = UDim2.new(1, 0, 0, 0)
shieldGroup.Size = UDim2.new(0.45, 0, 0, 32)
shieldGroup.BackgroundTransparency = 1
shieldGroup.Parent = xpPanel

local shieldHeader = Instance.new("Frame")
shieldHeader.Name = "ShieldHeader"
shieldHeader.AnchorPoint = Vector2.new(1, 0)
shieldHeader.Position = UDim2.new(1, 0, 0, 0)
shieldHeader.Size = UDim2.fromOffset(136, 18)
shieldHeader.BackgroundTransparency = 1
shieldHeader.BorderSizePixel = 0
shieldHeader.Parent = shieldGroup

local shieldIcon = createIcon(shieldHeader, "ShieldIcon", ICON_IMAGES.Shield, "S", COLORS.Shield)
shieldIcon.Position = UDim2.fromOffset(-3, -7)
shieldIcon.Size = UDim2.fromOffset(28, 28)

local shieldText = createLabel(shieldHeader, "ShieldText", "0 / 0", UI_FONTS.Heavy, 14, COLORS.Shield)
shieldText.Position = UDim2.fromOffset(31, -1)
shieldText.Size = UDim2.new(1, -31, 0, 18)
shieldText.TextScaled = true
shieldText.TextXAlignment = Enum.TextXAlignment.Right
addTextSizeConstraint(shieldText, 11, 15)

local shieldTrack, shieldFill = createBar(shieldGroup, "Shield", COLORS.Shield, COLORS.ShieldDark)
shieldTrack.Position = UDim2.fromOffset(0, 19)
shieldTrack.Size = UDim2.new(1, 0, 0, 13)

local levelValue = createLabel(xpPanel, "LevelValue", "LVL 1", UI_FONTS.Heavy, 16, COLORS.Xp)
levelValue.Position = UDim2.fromOffset(0, 37)
levelValue.Size = UDim2.fromOffset(72, 18)
addTextSizeConstraint(levelValue, 12, 16)

local xpText = createLabel(xpPanel, "XpText", "XP 0 / 6", UI_FONTS.Heavy, 16, COLORS.Xp)
xpText.AnchorPoint = Vector2.new(1, 0)
xpText.Position = UDim2.new(1, 0, 0, 37)
xpText.Size = UDim2.new(1, -78, 0, 18)
xpText.TextXAlignment = Enum.TextXAlignment.Right
addTextSizeConstraint(xpText, 12, 16)

local xpTrack, xpFill = createBar(xpPanel, "Xp", COLORS.Xp, COLORS.XpDark)
xpTrack.Position = UDim2.fromOffset(0, 58)
xpTrack.Size = UDim2.new(1, 0, 0, 14)

local function updateResponsiveLayout()
	local viewportSize = getViewportSize()

	if viewportSize.X < 560 then
		topCluster.Position = UDim2.new(0.5, 0, 0, 8)
		topScale.Scale = 0.68
		xpPanel.Position = UDim2.new(0.5, 0, 1, -8)
		xpPanel.Size = UDim2.new(0.88, 0, 0, 72)
		xpScale.Scale = 0.8
	elseif viewportSize.X < 760 then
		topCluster.Position = UDim2.new(0.5, 0, 0, 8)
		topScale.Scale = 0.78
		xpPanel.Position = UDim2.new(0.5, 0, 1, -8)
		xpPanel.Size = UDim2.new(0.82, 0, 0, 72)
		xpScale.Scale = 0.86
	elseif viewportSize.X < 1250 then
		topCluster.Position = UDim2.new(0.5, 0, 0, 10)
		topScale.Scale = 0.9
		xpPanel.Position = UDim2.new(0.5, 0, 1, -12)
		xpPanel.Size = UDim2.new(0.62, 0, 0, 72)
		xpScale.Scale = 0.92
	else
		topCluster.Position = UDim2.new(0.5, 0, 0, 12)
		topScale.Scale = 1
		xpPanel.Position = UDim2.new(0.5, 0, 1, -16)
		xpPanel.Size = UDim2.new(0.52, 0, 0, 72)
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
	xpText.Text = ("XP %s / %s"):format(formatNumber(state.Xp), formatNumber(state.XpRequired))
	setBarProgress(xpFill, progress)
end

local function refreshCoins()
	goldValue.Text = formatTopStatNumber(state.Coins)
end

local function refreshTimer()
	timerLabel.Text = formatTimer(timerRemaining)
end

local function isTimerPaused()
	return state.IsUserPaused or state.HasBlockingPause
end

local function refreshPause()
	isPauseButtonBlocked = state.HasBlockingPause and not state.IsUserPaused
	pauseButton.Active = not isPauseButtonBlocked
	pauseButton.AutoButtonColor = not isPauseButtonBlocked
	pauseButton.Text = if state.IsUserPaused then ">" else "||"
	pauseButton.TextColor3 = if isPauseButtonBlocked then COLORS.Muted else COLORS.Green
	pauseButton.TextTransparency = if isPauseButtonBlocked then 0.42 else 0

	local stroke = pauseButton:FindFirstChildWhichIsA("UIStroke")

	if stroke ~= nil then
		TweenService:Create(stroke, QUICK_TWEEN, {
			Color = if isPauseButtonBlocked then COLORS.Muted else COLORS.Green,
			Transparency = if state.IsUserPaused then 0.1 else 0.38,
		}):Play()
	end
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
bindRemote("Perk_UpdateStats", onPerksPayload)
bindRemote("Combat_PauseState", onPausePayload)

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
refreshTimer()
refreshPause()
updateResponsiveLayout()

DebugLog.Info("UI", "HUD combat epure initialise", {
	Player = player.Name,
})
