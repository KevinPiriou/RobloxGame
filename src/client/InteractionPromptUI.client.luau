local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local DebugLog = require(Shared:WaitForChild("DebugLog"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))

local existingGui = playerGui:FindFirstChild("InteractionPromptGui")

if existingGui ~= nil then
	existingGui:Destroy()
end

local COLORS = UiTheme.Contexts.Interaction

local viewsByPrompt = {}
local PROMPT_VISUAL_MAX_DISTANCE = 300

local addCorner = UiTheme.AddCorner
local addStroke = UiTheme.AddStroke

local function addGradient(instance, firstColor, secondColor)
	return UiTheme.AddGradient(instance, firstColor, secondColor, 90)
end

local function createLabel(parent, name, text, font, textSize, color)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Font = font
	label.Text = text
	label.TextColor3 = color
	label.TextSize = textSize
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0.48
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = parent

	return label
end

local function getAdornee(prompt)
	local parent = prompt.Parent

	if parent ~= nil and (parent:IsA("BasePart") or parent:IsA("Attachment")) then
		return parent
	end

	if parent ~= nil and parent:IsA("Model") then
		return parent.PrimaryPart or parent:FindFirstChildWhichIsA("BasePart", true)
	end

	return nil
end

local function getInputText(prompt, inputType)
	if inputType == Enum.ProximityPromptInputType.Gamepad then
		return string.gsub(prompt.GamepadKeyCode.Name, "Button", "")
	end

	if inputType == Enum.ProximityPromptInputType.Touch then
		return "TAP"
	end

	return prompt.KeyboardKeyCode.Name
end

local function destroyView(prompt)
	local view = viewsByPrompt[prompt]

	if view == nil then
		return
	end

	if view.HoldTween ~= nil then
		view.HoldTween:Cancel()
	end

	viewsByPrompt[prompt] = nil

	if view.Billboard.Parent ~= nil then
		view.Billboard:Destroy()
	end
end

local function resetHoldProgress(view)
	if view.HoldTween ~= nil then
		view.HoldTween:Cancel()
		view.HoldTween = nil
	end

	view.ProgressFill.Size = UDim2.fromScale(0, 1)
end

local function createView(prompt, inputType)
	destroyView(prompt)

	local adornee = getAdornee(prompt)

	if adornee == nil then
		return nil
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "InteractionPrompt"
	billboard.Adornee = adornee
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	-- La distance d'interaction reste geree par le ProximityPrompt cote serveur.
	-- Cette valeur concerne seulement le rendu lorsque la camera est reculee.
	billboard.MaxDistance = math.max(prompt.MaxActivationDistance + 5, PROMPT_VISUAL_MAX_DISTANCE)
	billboard.Size = UDim2.fromOffset(270, 76)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 2.15, 0)
	billboard.Parent = playerGui

	local scale = Instance.new("UIScale")
	scale.Scale = 0.92
	scale.Parent = billboard

	local outer = Instance.new("Frame")
	outer.Name = "MetalFrame"
	outer.Size = UDim2.fromScale(1, 1)
	outer.BackgroundColor3 = Color3.fromRGB(37, 51, 70)
	outer.BackgroundTransparency = 0.2
	outer.BorderSizePixel = 0
	outer.Parent = billboard
	addCorner(outer, 11)
	addStroke(outer, COLORS.MetalLight, 0.22, 2)
	addGradient(outer, Color3.fromRGB(65, 88, 118), COLORS.MetalDark)
	UiTheme.AddSurfaceFinish(outer, {
		Accent = COLORS.Accent,
		Intensity = 0.55,
	})

	local inner = Instance.new("Frame")
	inner.Name = "GlassInner"
	inner.Position = UDim2.fromOffset(4, 4)
	inner.Size = UDim2.new(1, -8, 1, -8)
	inner.BackgroundColor3 = Color3.fromRGB(13, 22, 34)
	inner.BackgroundTransparency = 0.28
	inner.BorderSizePixel = 0
	inner.Parent = outer
	addCorner(inner, 8)
	addStroke(inner, COLORS.GlassStroke, 0.7, 1)

	local accent = Instance.new("Frame")
	accent.Name = "Accent"
	accent.Position = UDim2.fromOffset(8, 10)
	accent.Size = UDim2.fromOffset(3, 48)
	accent.BackgroundColor3 = COLORS.Accent
	accent.BackgroundTransparency = 0.16
	accent.BorderSizePixel = 0
	accent.Parent = inner
	addCorner(accent, 2)

	local keyShell = Instance.new("Frame")
	keyShell.Name = "KeyShell"
	keyShell.Position = UDim2.fromOffset(18, 13)
	keyShell.Size = UDim2.fromOffset(48, 48)
	keyShell.BackgroundColor3 = Color3.fromRGB(47, 64, 86)
	keyShell.BackgroundTransparency = 0.04
	keyShell.BorderSizePixel = 0
	keyShell.Parent = inner
	addCorner(keyShell, 10)
	addStroke(keyShell, COLORS.GlassStroke, 0.28, 2)
	addGradient(keyShell, Color3.fromRGB(111, 136, 163), Color3.fromRGB(24, 34, 48))

	local keyButton = Instance.new("TextButton")
	keyButton.Name = "KeyButton"
	keyButton.Position = UDim2.fromOffset(4, 4)
	keyButton.Size = UDim2.new(1, -8, 1, -8)
	keyButton.BackgroundColor3 = Color3.fromRGB(18, 29, 42)
	keyButton.BackgroundTransparency = 0.2
	keyButton.BorderSizePixel = 0
	keyButton.AutoButtonColor = false
	keyButton.Font = Enum.Font.GothamBlack
	keyButton.Text = getInputText(prompt, inputType)
	keyButton.TextColor3 = COLORS.Text
	keyButton.TextSize = 20
	keyButton.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	keyButton.TextStrokeTransparency = 0.34
	keyButton.Parent = keyShell
	addCorner(keyButton, 7)

	local objectText = createLabel(inner, "ObjectText", prompt.ObjectText, Enum.Font.GothamMedium, 12, COLORS.Muted)
	objectText.Position = UDim2.fromOffset(78, 13)
	objectText.Size = UDim2.new(1, -92, 0, 20)

	local actionText = createLabel(inner, "ActionText", prompt.ActionText, Enum.Font.GothamBold, 18, COLORS.Text)
	actionText.Position = UDim2.fromOffset(78, 31)
	actionText.Size = UDim2.new(1, -92, 0, 25)

	local progressTrack = Instance.new("Frame")
	progressTrack.Name = "HoldProgressTrack"
	progressTrack.Position = UDim2.new(0, 78, 1, -9)
	progressTrack.Size = UDim2.new(1, -92, 0, 3)
	progressTrack.BackgroundColor3 = Color3.fromRGB(6, 12, 20)
	progressTrack.BackgroundTransparency = 0.12
	progressTrack.BorderSizePixel = 0
	progressTrack.Visible = prompt.HoldDuration > 0
	progressTrack.ClipsDescendants = true
	progressTrack.Parent = inner
	addCorner(progressTrack, 2)

	local progressFill = Instance.new("Frame")
	progressFill.Name = "Fill"
	progressFill.Size = UDim2.fromScale(0, 1)
	progressFill.BackgroundColor3 = COLORS.Progress
	progressFill.BorderSizePixel = 0
	progressFill.Parent = progressTrack
	addCorner(progressFill, 2)

	local view = {
		Billboard = billboard,
		Scale = scale,
		ProgressFill = progressFill,
		HoldTween = nil,
	}
	viewsByPrompt[prompt] = view
	DebugLog.ThrottledInfo("UI", "interaction_prompt_shown", 1, "Prompt custom affiche", {
		Action = prompt.ActionText,
		Object = prompt.ObjectText,
		Prompt = prompt,
	})

	keyButton.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			prompt:InputHoldBegin()
		end
	end)

	keyButton.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			prompt:InputHoldEnd()
		end
	end)

	TweenService:Create(scale, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()

	return view
end

ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
	if prompt.Style ~= Enum.ProximityPromptStyle.Custom then
		return
	end

	createView(prompt, inputType)
end)

ProximityPromptService.PromptHidden:Connect(destroyView)

ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
	local view = viewsByPrompt[prompt]

	if view == nil or prompt.HoldDuration <= 0 then
		return
	end

	resetHoldProgress(view)
	view.HoldTween = TweenService:Create(view.ProgressFill, TweenInfo.new(prompt.HoldDuration, Enum.EasingStyle.Linear), {
		Size = UDim2.fromScale(1, 1),
	})
	view.HoldTween:Play()
end)

ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt)
	local view = viewsByPrompt[prompt]

	if view ~= nil then
		resetHoldProgress(view)
	end
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt, playerWhoTriggered)
	if playerWhoTriggered ~= player then
		return
	end

	local view = viewsByPrompt[prompt]

	if view ~= nil then
		TweenService:Create(view.Scale, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Scale = 0.96,
		}):Play()
	end
end)
