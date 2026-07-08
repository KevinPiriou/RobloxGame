local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local statsRemote = ReplicatedStorage:WaitForChild("Combat_UpdateStats")
local updateXpRemote = ReplicatedStorage:WaitForChild("Xp_UpdateCount")

local existingGui = playerGui:FindFirstChild("CombatGui")

if existingGui ~= nil then
	existingGui:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CombatGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 4
screenGui.Parent = playerGui

local container = Instance.new("Frame")
container.Name = "Container"
container.AnchorPoint = Vector2.new(0, 1)
container.Position = UDim2.new(0, 14, 1, -18)
container.Size = UDim2.new(0, 230, 0, 104)
container.BackgroundColor3 = Color3.fromRGB(22, 25, 31)
container.BackgroundTransparency = 0.16
container.BorderSizePixel = 0
container.Parent = screenGui

local containerCorner = Instance.new("UICorner")
containerCorner.CornerRadius = UDim.new(0, 8)
containerCorner.Parent = container

local containerStroke = Instance.new("UIStroke")
containerStroke.Color = Color3.fromRGB(255, 255, 255)
containerStroke.Transparency = 0.84
containerStroke.Thickness = 1
containerStroke.Parent = container

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 8)
padding.PaddingRight = UDim.new(0, 10)
padding.PaddingBottom = UDim.new(0, 8)
padding.PaddingLeft = UDim.new(0, 10)
padding.Parent = container

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "TitleLabel"
titleLabel.Size = UDim2.new(0.5, 0, 0, 18)
titleLabel.BackgroundTransparency = 1
titleLabel.Font = Enum.Font.GothamBold
titleLabel.Text = "Survie"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextSize = 14
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = container

local xpLabel = Instance.new("TextLabel")
xpLabel.Name = "XpLabel"
xpLabel.AnchorPoint = Vector2.new(1, 0)
xpLabel.Position = UDim2.new(1, 0, 0, 0)
xpLabel.Size = UDim2.new(0.5, 0, 0, 18)
xpLabel.BackgroundTransparency = 1
xpLabel.Font = Enum.Font.GothamMedium
xpLabel.Text = "Niv. 1"
xpLabel.TextColor3 = Color3.fromRGB(95, 220, 255)
xpLabel.TextSize = 12
xpLabel.TextXAlignment = Enum.TextXAlignment.Right
xpLabel.Parent = container

local healthLabel = Instance.new("TextLabel")
healthLabel.Name = "HealthLabel"
healthLabel.Position = UDim2.new(0, 0, 0, 22)
healthLabel.Size = UDim2.new(1, 0, 0, 18)
healthLabel.BackgroundTransparency = 1
healthLabel.Font = Enum.Font.GothamMedium
healthLabel.Text = "PV : 100 / 100"
healthLabel.TextColor3 = Color3.fromRGB(255, 125, 125)
healthLabel.TextSize = 13
healthLabel.TextXAlignment = Enum.TextXAlignment.Left
healthLabel.Parent = container

local waveLabel = Instance.new("TextLabel")
waveLabel.Name = "WaveLabel"
waveLabel.Position = UDim2.new(0, 0, 0, 42)
waveLabel.Size = UDim2.new(1, 0, 0, 16)
waveLabel.BackgroundTransparency = 1
waveLabel.Font = Enum.Font.GothamMedium
waveLabel.Text = "Vague : 1"
waveLabel.TextColor3 = Color3.fromRGB(255, 205, 120)
waveLabel.TextSize = 12
waveLabel.TextXAlignment = Enum.TextXAlignment.Left
waveLabel.Parent = container

local monstersLabel = Instance.new("TextLabel")
monstersLabel.Name = "MonstersLabel"
monstersLabel.Position = UDim2.new(0, 0, 0, 60)
monstersLabel.Size = UDim2.new(0.5, 0, 0, 18)
monstersLabel.BackgroundTransparency = 1
monstersLabel.Font = Enum.Font.GothamMedium
monstersLabel.Text = "Monstres : 0"
monstersLabel.TextColor3 = Color3.fromRGB(235, 235, 235)
monstersLabel.TextSize = 12
monstersLabel.TextXAlignment = Enum.TextXAlignment.Left
monstersLabel.Parent = container

local killsLabel = Instance.new("TextLabel")
killsLabel.Name = "KillsLabel"
killsLabel.AnchorPoint = Vector2.new(1, 0)
killsLabel.Position = UDim2.new(1, 0, 0, 60)
killsLabel.Size = UDim2.new(0.5, 0, 0, 18)
killsLabel.BackgroundTransparency = 1
killsLabel.Font = Enum.Font.GothamMedium
killsLabel.Text = "Kills : 0"
killsLabel.TextColor3 = Color3.fromRGB(235, 235, 235)
killsLabel.TextSize = 12
killsLabel.TextXAlignment = Enum.TextXAlignment.Right
killsLabel.Parent = container

local weaponLabel = Instance.new("TextLabel")
weaponLabel.Name = "WeaponLabel"
weaponLabel.Position = UDim2.new(0, 0, 0, 80)
weaponLabel.Size = UDim2.new(1, 0, 0, 16)
weaponLabel.BackgroundTransparency = 1
weaponLabel.Font = Enum.Font.GothamMedium
weaponLabel.Text = "Arme : Fireball auto"
weaponLabel.TextColor3 = Color3.fromRGB(255, 205, 120)
weaponLabel.TextSize = 12
weaponLabel.TextXAlignment = Enum.TextXAlignment.Left
weaponLabel.Parent = container

local xpBarContainer = Instance.new("Frame")
xpBarContainer.Name = "XpBarContainer"
xpBarContainer.AnchorPoint = Vector2.new(0.5, 1)
xpBarContainer.Position = UDim2.new(0.5, 0, 1, -88)
xpBarContainer.Size = UDim2.new(0.46, 0, 0, 34)
xpBarContainer.BackgroundColor3 = Color3.fromRGB(18, 21, 27)
xpBarContainer.BackgroundTransparency = 0.12
xpBarContainer.BorderSizePixel = 0
xpBarContainer.Parent = screenGui

local xpBarSizeConstraint = Instance.new("UISizeConstraint")
xpBarSizeConstraint.MinSize = Vector2.new(260, 34)
xpBarSizeConstraint.MaxSize = Vector2.new(540, 34)
xpBarSizeConstraint.Parent = xpBarContainer

local xpBarCorner = Instance.new("UICorner")
xpBarCorner.CornerRadius = UDim.new(0, 8)
xpBarCorner.Parent = xpBarContainer

local xpBarStroke = Instance.new("UIStroke")
xpBarStroke.Color = Color3.fromRGB(255, 255, 255)
xpBarStroke.Transparency = 0.82
xpBarStroke.Thickness = 1
xpBarStroke.Parent = xpBarContainer

local xpTrack = Instance.new("Frame")
xpTrack.Name = "Track"
xpTrack.Position = UDim2.new(0, 8, 0, 8)
xpTrack.Size = UDim2.new(1, -16, 1, -16)
xpTrack.BackgroundColor3 = Color3.fromRGB(45, 51, 63)
xpTrack.BorderSizePixel = 0
xpTrack.ClipsDescendants = true
xpTrack.Parent = xpBarContainer

local xpTrackCorner = Instance.new("UICorner")
xpTrackCorner.CornerRadius = UDim.new(0, 6)
xpTrackCorner.Parent = xpTrack

local xpFill = Instance.new("Frame")
xpFill.Name = "Fill"
xpFill.Size = UDim2.new(0, 0, 1, 0)
xpFill.BackgroundColor3 = Color3.fromRGB(80, 210, 255)
xpFill.BorderSizePixel = 0
xpFill.Parent = xpTrack

local xpFillCorner = Instance.new("UICorner")
xpFillCorner.CornerRadius = UDim.new(0, 6)
xpFillCorner.Parent = xpFill

local xpBarText = Instance.new("TextLabel")
xpBarText.Name = "Text"
xpBarText.Size = UDim2.new(1, 0, 1, 0)
xpBarText.BackgroundTransparency = 1
xpBarText.Font = Enum.Font.GothamBold
xpBarText.Text = "Niveau 1 - XP 0 / 10"
xpBarText.TextColor3 = Color3.fromRGB(255, 255, 255)
xpBarText.TextSize = 12
xpBarText.TextXAlignment = Enum.TextXAlignment.Center
xpBarText.TextYAlignment = Enum.TextYAlignment.Center
xpBarText.Parent = xpTrack

local function updateXpDisplay(payload)
	local level = payload.Level or 1
	local xp = payload.Xp or 0
	local xpRequired = math.max(1, payload.XpRequired or 1)
	local progress = math.clamp(xp / xpRequired, 0, 1)

	xpLabel.Text = "Niv. " .. tostring(level)
	xpFill.Size = UDim2.new(progress, 0, 1, 0)
	xpBarText.Text = ("Niveau %d - XP %d / %d"):format(level, xp, xpRequired)
end

statsRemote.OnClientEvent:Connect(function(payload)
	local health = payload.Health or 0
	local maxHealth = payload.MaxHealth or 100
	local shield = payload.Shield or 0
	local maxShield = payload.MaxShield or 0
	local aliveMonsters = payload.AliveMonsters or 0
	local maxAliveMonsters = payload.MaxAliveMonsters or aliveMonsters
	local wave = payload.Wave or 1
	local kills = payload.Kills or 0
	local weaponName = payload.WeaponName or "Fireball"

	if maxShield > 0 then
		healthLabel.Text = ("PV : %d/%d | B : %d/%d"):format(health, maxHealth, shield, maxShield)
	else
		healthLabel.Text = ("PV : %d / %d"):format(health, maxHealth)
	end
	waveLabel.Text = "Vague : " .. tostring(wave)
	monstersLabel.Text = ("Monstres : %d/%d"):format(aliveMonsters, maxAliveMonsters)
	killsLabel.Text = "Kills : " .. tostring(kills)
	weaponLabel.Text = "Arme : " .. weaponName .. " auto"
end)

updateXpRemote.OnClientEvent:Connect(function(payload)
	updateXpDisplay(payload)
end)
