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
xpLabel.Text = "XP : 0"
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

statsRemote.OnClientEvent:Connect(function(payload)
	local health = payload.Health or 0
	local maxHealth = payload.MaxHealth or 100
	local aliveMonsters = payload.AliveMonsters or 0
	local maxAliveMonsters = payload.MaxAliveMonsters or aliveMonsters
	local wave = payload.Wave or 1
	local kills = payload.Kills or 0
	local weaponName = payload.WeaponName or "Fireball"

	healthLabel.Text = ("PV : %d / %d"):format(health, maxHealth)
	waveLabel.Text = "Vague : " .. tostring(wave)
	monstersLabel.Text = ("Monstres : %d/%d"):format(aliveMonsters, maxAliveMonsters)
	killsLabel.Text = "Kills : " .. tostring(kills)
	weaponLabel.Text = "Arme : " .. weaponName .. " auto"
end)

updateXpRemote.OnClientEvent:Connect(function(payload)
	xpLabel.Text = "XP : " .. tostring(payload.Xp or 0)
end)
