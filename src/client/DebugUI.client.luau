local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local UPDATE_INTERVAL = 0.5

local frameCount = 0
local elapsedSinceUpdate = 0

local existingGui = playerGui:FindFirstChild("DebugGui")

if existingGui ~= nil then
	existingGui:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DebugGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 20
screenGui.Parent = playerGui

local container = Instance.new("Frame")
container.Name = "Container"
container.AnchorPoint = Vector2.new(1, 0)
container.Position = UDim2.new(1, -14, 0, 14)
container.Size = UDim2.new(0, 210, 0, 134)
container.BackgroundColor3 = Color3.fromRGB(16, 18, 22)
container.BackgroundTransparency = 0.12
container.BorderSizePixel = 0
container.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = container

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(255, 255, 255)
stroke.Transparency = 0.82
stroke.Thickness = 1
stroke.Parent = container

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 6)
padding.PaddingRight = UDim.new(0, 10)
padding.PaddingBottom = UDim.new(0, 6)
padding.PaddingLeft = UDim.new(0, 10)
padding.Parent = container

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 2)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = container

local function createLabel(name, text, color)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = UDim2.new(1, 0, 0, 13)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamMedium
	label.Text = text
	label.TextColor3 = color or Color3.fromRGB(230, 235, 245)
	label.TextSize = 11
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Parent = container

	return label
end

local titleLabel = createLabel("TitleLabel", "Debug performances", Color3.fromRGB(255, 255, 255))
titleLabel.Font = Enum.Font.GothamBold

local fpsLabel = createLabel("FpsLabel", "FPS : --")
local memoryLabel = createLabel("MemoryLabel", "RAM : -- MB")
local cpuLabel = createLabel("CpuLabel", "CPU render : -- ms")
local gpuLabel = createLabel("GpuLabel", "GPU render : -- ms")
local physicsLabel = createLabel("PhysicsLabel", "Physics : -- ms")
local instancesLabel = createLabel("InstancesLabel", "Instances : --")
local drawLabel = createLabel("DrawLabel", "Draw/Tri : -- / --")

local function readNumber(valueReader)
	local success, value = pcall(valueReader)

	if not success or typeof(value) ~= "number" then
		return nil
	end

	return value
end

local function formatMs(seconds)
	if seconds == nil then
		return "-- ms"
	end

	return ("%.2f ms"):format(seconds * 1000)
end

local function formatWholeNumber(value)
	if value == nil then
		return "--"
	end

	return tostring(math.floor(value + 0.5))
end

local function updateDebugValues(fps)
	local memoryMb = readNumber(function()
		return Stats:GetTotalMemoryUsageMb()
	end)
	local renderCpu = readNumber(function()
		return Stats.RenderCPUFrameTime
	end)
	local renderGpu = readNumber(function()
		return Stats.RenderGPUFrameTime
	end)
	local physicsStep = readNumber(function()
		return Stats.PhysicsStepTime
	end)
	local instanceCount = readNumber(function()
		return Stats.InstanceCount
	end)
	local drawCalls = readNumber(function()
		return Stats.SceneDrawcallCount
	end)
	local triangles = readNumber(function()
		return Stats.SceneTriangleCount
	end)

	fpsLabel.Text = ("FPS : %d"):format(math.floor(fps + 0.5))

	if memoryMb == nil then
		memoryLabel.Text = "RAM : -- MB"
	else
		memoryLabel.Text = ("RAM : %.0f MB"):format(memoryMb)
	end

	cpuLabel.Text = "CPU render : " .. formatMs(renderCpu)
	gpuLabel.Text = "GPU render : " .. formatMs(renderGpu)
	physicsLabel.Text = "Physics : " .. formatMs(physicsStep)
	instancesLabel.Text = "Instances : " .. formatWholeNumber(instanceCount)
	drawLabel.Text = ("Draw/Tri : %s / %s"):format(formatWholeNumber(drawCalls), formatWholeNumber(triangles))
end

RunService.RenderStepped:Connect(function(deltaTime)
	frameCount += 1
	elapsedSinceUpdate += deltaTime

	if elapsedSinceUpdate < UPDATE_INTERVAL then
		return
	end

	local fps = frameCount / elapsedSinceUpdate

	frameCount = 0
	elapsedSinceUpdate = 0
	updateDebugValues(fps)
end)
