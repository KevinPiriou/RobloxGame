local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local resetPowerUpsRemote = ReplicatedStorage:WaitForChild("Admin_ResetPowerUps")
local adminMessageRemote = ReplicatedStorage:WaitForChild("Admin_ShowMessage")

local existingGui = playerGui:FindFirstChild("AdminGui")

if existingGui ~= nil then
	existingGui:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AdminGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 8
screenGui.Enabled = false
screenGui.Parent = playerGui

local container = Instance.new("Frame")
container.Name = "Container"
container.AnchorPoint = Vector2.new(1, 1)
container.Position = UDim2.new(1, -14, 1, -18)
container.Size = UDim2.new(0, 210, 0, 58)
container.BackgroundColor3 = Color3.fromRGB(22, 25, 31)
container.BackgroundTransparency = 0.16
container.BorderSizePixel = 0
container.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = container

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(255, 255, 255)
stroke.Transparency = 0.84
stroke.Thickness = 1
stroke.Parent = container

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 8)
padding.PaddingRight = UDim.new(0, 8)
padding.PaddingBottom = UDim.new(0, 8)
padding.PaddingLeft = UDim.new(0, 8)
padding.Parent = container

local resetButton = Instance.new("TextButton")
resetButton.Name = "ResetPowerUpsButton"
resetButton.Size = UDim2.new(1, 0, 0, 28)
resetButton.BackgroundColor3 = Color3.fromRGB(92, 70, 145)
resetButton.BorderSizePixel = 0
resetButton.Font = Enum.Font.GothamBold
resetButton.Text = "Admin : reinit bonus"
resetButton.TextColor3 = Color3.fromRGB(255, 255, 255)
resetButton.TextSize = 13
resetButton.Parent = container

local buttonCorner = Instance.new("UICorner")
buttonCorner.CornerRadius = UDim.new(0, 6)
buttonCorner.Parent = resetButton

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "StatusLabel"
statusLabel.Position = UDim2.new(0, 0, 0, 32)
statusLabel.Size = UDim2.new(1, 0, 0, 14)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.GothamMedium
statusLabel.Text = ""
statusLabel.TextColor3 = Color3.fromRGB(220, 225, 235)
statusLabel.TextSize = 11
statusLabel.TextTruncate = Enum.TextTruncate.AtEnd
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = container

local function updateVisibility()
	screenGui.Enabled = player:GetAttribute("CanUseAdminTools") == true
end

local function setButtonBusy(isBusy)
	resetButton.Active = not isBusy
	resetButton.AutoButtonColor = not isBusy

	if isBusy then
		resetButton.Text = "Reset..."
	else
		resetButton.Text = "Admin : reinit bonus"
	end
end

resetButton.Activated:Connect(function()
	setButtonBusy(true)
	statusLabel.Text = "Demande envoyee"
	resetPowerUpsRemote:FireServer()
end)

adminMessageRemote.OnClientEvent:Connect(function(payload)
	setButtonBusy(false)
	statusLabel.Text = payload.Message or "Action terminee"

	if payload.Success then
		statusLabel.TextColor3 = Color3.fromRGB(145, 235, 170)
	else
		statusLabel.TextColor3 = Color3.fromRGB(255, 145, 145)
	end
end)

player:GetAttributeChangedSignal("CanUseAdminTools"):Connect(updateVisibility)
updateVisibility()
