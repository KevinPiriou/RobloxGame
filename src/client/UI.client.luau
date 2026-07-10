local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DebugLog = require(Shared:WaitForChild("DebugLog"))
local FeatureFlags = require(Shared:WaitForChild("FeatureFlags"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local isQuizEnabled = FeatureFlags.QuizEnabled == true
local showQuestionRemote = nil
local submitAnswerRemote = nil
local showResultRemote = nil
local updateScoreRemote = nil
local updateEffectsRemote = nil

if isQuizEnabled then
	showQuestionRemote = ReplicatedStorage:WaitForChild("Quiz_ShowQuestion")
	submitAnswerRemote = ReplicatedStorage:WaitForChild("Quiz_SubmitAnswer")
	showResultRemote = ReplicatedStorage:WaitForChild("Quiz_ShowResult")
	updateScoreRemote = ReplicatedStorage:WaitForChild("Quiz_UpdateScore")
	updateEffectsRemote = ReplicatedStorage:WaitForChild("Quiz_UpdateEffects")
end

local activeRoundId = nil
local selectedAnswerIndex = nil
local timerVersion = 0
local answerButtons = {}
local dragging = false
local dragStartPosition = nil
local dragStartTopLeft = nil

local existingGui = playerGui:FindFirstChild("QuizGui")

if existingGui ~= nil then
	existingGui:Destroy()
end

if not isQuizEnabled then
	DebugLog.Info("UI", "UI quiz desactivee par FeatureFlags")
	return
end

local updateCoinsRemote = ReplicatedStorage:WaitForChild("Coin_UpdateCount")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "QuizGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 5
screenGui.Parent = playerGui

local container = Instance.new("Frame")
container.Name = "Container"
container.AnchorPoint = Vector2.new(0.5, 0)
container.Position = UDim2.new(0.5, 0, 0, 6)
container.Size = UDim2.new(0.36, 0, 0, 188)
container.BackgroundColor3 = Color3.fromRGB(22, 25, 31)
container.BackgroundTransparency = 0.12
container.BorderSizePixel = 0
container.Active = true
container.Visible = isQuizEnabled
container.Parent = screenGui

local sizeConstraint = Instance.new("UISizeConstraint")
sizeConstraint.MinSize = Vector2.new(320, 166)
sizeConstraint.MaxSize = Vector2.new(600, 204)
sizeConstraint.Parent = container

local containerCorner = Instance.new("UICorner")
containerCorner.CornerRadius = UDim.new(0, 8)
containerCorner.Parent = container

local containerStroke = Instance.new("UIStroke")
containerStroke.Color = Color3.fromRGB(255, 255, 255)
containerStroke.Transparency = 0.84
containerStroke.Thickness = 1
containerStroke.Parent = container

local containerPadding = Instance.new("UIPadding")
containerPadding.PaddingTop = UDim.new(0, 12)
containerPadding.PaddingRight = UDim.new(0, 12)
containerPadding.PaddingBottom = UDim.new(0, 10)
containerPadding.PaddingLeft = UDim.new(0, 12)
containerPadding.Parent = container

local function addTextSizeConstraint(textObject, minSize, maxSize)
	local textConstraint = Instance.new("UITextSizeConstraint")
	textConstraint.MinTextSize = minSize
	textConstraint.MaxTextSize = maxSize
	textConstraint.Parent = textObject
end

local headerFrame = Instance.new("Frame")
headerFrame.Name = "HeaderFrame"
headerFrame.Size = UDim2.new(1, 0, 0, 24)
headerFrame.BackgroundTransparency = 1
headerFrame.Active = true
headerFrame.Parent = container

local quizLabel = Instance.new("TextLabel")
quizLabel.Name = "QuizLabel"
quizLabel.Size = UDim2.new(0.34, 0, 1, 0)
quizLabel.BackgroundTransparency = 1
quizLabel.Font = Enum.Font.GothamBold
quizLabel.Text = "Quiz"
quizLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
quizLabel.TextSize = 16
quizLabel.TextXAlignment = Enum.TextXAlignment.Left
quizLabel.Active = true
quizLabel.Parent = headerFrame

local scoreLabel = Instance.new("TextLabel")
scoreLabel.Name = "ScoreLabel"
scoreLabel.AnchorPoint = Vector2.new(1, 0)
scoreLabel.Position = UDim2.fromScale(1, 0)
scoreLabel.Size = UDim2.new(0.34, 0, 1, 0)
scoreLabel.BackgroundTransparency = 1
scoreLabel.Font = Enum.Font.GothamMedium
scoreLabel.Text = "Score : 0"
scoreLabel.TextColor3 = Color3.fromRGB(220, 225, 235)
scoreLabel.TextSize = 13
scoreLabel.TextXAlignment = Enum.TextXAlignment.Right
scoreLabel.Active = true
scoreLabel.Parent = headerFrame

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "StatusLabel"
statusLabel.AnchorPoint = Vector2.new(0.5, 0)
statusLabel.Position = UDim2.fromScale(0.5, 0)
statusLabel.Size = UDim2.new(0.32, 0, 1, 0)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.GothamMedium
statusLabel.Text = ""
statusLabel.TextColor3 = Color3.fromRGB(245, 215, 120)
statusLabel.TextSize = 13
statusLabel.TextTruncate = Enum.TextTruncate.AtEnd
statusLabel.Active = true
statusLabel.Parent = headerFrame

local effectsLabel = Instance.new("TextLabel")
effectsLabel.Name = "EffectsLabel"
effectsLabel.Position = UDim2.new(0, 0, 0, 24)
effectsLabel.Size = UDim2.new(0.62, 0, 0, 18)
effectsLabel.BackgroundTransparency = 1
effectsLabel.Font = Enum.Font.GothamMedium
effectsLabel.Text = "Bonus saut : aucun"
effectsLabel.TextColor3 = Color3.fromRGB(190, 225, 255)
effectsLabel.TextSize = 12
effectsLabel.TextTruncate = Enum.TextTruncate.AtEnd
effectsLabel.TextXAlignment = Enum.TextXAlignment.Left
effectsLabel.Parent = container

local goldContainer = Instance.new("Frame")
goldContainer.Name = "GoldContainer"
goldContainer.Position = UDim2.new(0, 14, 0, 72)
goldContainer.Size = UDim2.new(0, 150, 0, 34)
goldContainer.BackgroundColor3 = Color3.fromRGB(22, 25, 31)
goldContainer.BackgroundTransparency = 0.12
goldContainer.BorderSizePixel = 0
goldContainer.Parent = screenGui

local goldCorner = Instance.new("UICorner")
goldCorner.CornerRadius = UDim.new(0, 8)
goldCorner.Parent = goldContainer

local goldStroke = Instance.new("UIStroke")
goldStroke.Color = Color3.fromRGB(255, 255, 255)
goldStroke.Transparency = 0.84
goldStroke.Thickness = 1
goldStroke.Parent = goldContainer

local goldPadding = Instance.new("UIPadding")
goldPadding.PaddingTop = UDim.new(0, 7)
goldPadding.PaddingRight = UDim.new(0, 10)
goldPadding.PaddingBottom = UDim.new(0, 7)
goldPadding.PaddingLeft = UDim.new(0, 10)
goldPadding.Parent = goldContainer

local coinsLabel = Instance.new("TextLabel")
coinsLabel.Name = "CoinsLabel"
coinsLabel.Size = UDim2.new(1, 0, 1, 0)
coinsLabel.BackgroundTransparency = 1
coinsLabel.Font = Enum.Font.GothamMedium
coinsLabel.Text = "Golds : 0"
coinsLabel.TextColor3 = Color3.fromRGB(255, 220, 120)
coinsLabel.TextSize = 13
coinsLabel.TextTruncate = Enum.TextTruncate.AtEnd
coinsLabel.TextXAlignment = Enum.TextXAlignment.Left
coinsLabel.Parent = goldContainer

local questionLabel = Instance.new("TextLabel")
questionLabel.Name = "QuestionLabel"
questionLabel.Position = UDim2.new(0, 0, 0, 44)
questionLabel.Size = UDim2.new(1, 0, 0, 40)
questionLabel.BackgroundTransparency = 1
questionLabel.Font = Enum.Font.GothamBold
questionLabel.Text = "En attente de la premiere question..."
questionLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
questionLabel.TextScaled = true
questionLabel.TextWrapped = true
questionLabel.TextXAlignment = Enum.TextXAlignment.Left
questionLabel.TextYAlignment = Enum.TextYAlignment.Center
questionLabel.Active = true
questionLabel.Parent = container
addTextSizeConstraint(questionLabel, 12, 17)

local answersFrame = Instance.new("Frame")
answersFrame.Name = "AnswersFrame"
answersFrame.Position = UDim2.new(0, 0, 0, 92)
answersFrame.Size = UDim2.new(1, 0, 1, -92)
answersFrame.BackgroundTransparency = 1
answersFrame.Parent = container

local answersLayout = Instance.new("UIGridLayout")
answersLayout.CellPadding = UDim2.new(0, 6, 0, 6)
answersLayout.CellSize = UDim2.new(0.5, -3, 0, 32)
answersLayout.FillDirection = Enum.FillDirection.Horizontal
answersLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
answersLayout.SortOrder = Enum.SortOrder.LayoutOrder
answersLayout.VerticalAlignment = Enum.VerticalAlignment.Top
answersLayout.Parent = answersFrame

local function clearAnswers()
	for _, button in ipairs(answerButtons) do
		button:Destroy()
	end

	answerButtons = {}
end

local function setButtonsEnabled(isEnabled)
	for _, button in ipairs(answerButtons) do
		button.Active = isEnabled
		button.AutoButtonColor = isEnabled
	end
end

local function setButtonColor(button, color)
	button.BackgroundColor3 = color
end

local function updateSelectionStyle()
	for index, button in ipairs(answerButtons) do
		if index == selectedAnswerIndex then
			setButtonColor(button, Color3.fromRGB(70, 95, 150))
		else
			setButtonColor(button, Color3.fromRGB(52, 58, 69))
		end
	end
end

local function markResult(selectedAnswerIndex, correctAnswerIndex)
	for index, button in ipairs(answerButtons) do
		if index == correctAnswerIndex then
			setButtonColor(button, Color3.fromRGB(46, 132, 82))
		elseif index == selectedAnswerIndex then
			setButtonColor(button, Color3.fromRGB(156, 64, 64))
		else
			setButtonColor(button, Color3.fromRGB(55, 61, 72))
		end
	end
end

local function submitAnswer(answerIndex)
	if activeRoundId == nil then
		return
	end

	if selectedAnswerIndex == answerIndex then
		selectedAnswerIndex = nil
		submitAnswerRemote:FireServer(activeRoundId, 0)
	else
		selectedAnswerIndex = answerIndex
		submitAnswerRemote:FireServer(activeRoundId, answerIndex)
	end

	updateSelectionStyle()
end

local function createAnswerButton(answerText, answerIndex)
	local button = Instance.new("TextButton")
	button.Name = "Answer" .. answerIndex
	button.BackgroundColor3 = Color3.fromRGB(52, 58, 69)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.Text = answerText
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextScaled = true
	button.TextWrapped = true
	button.LayoutOrder = answerIndex
	button.Parent = answersFrame
	addTextSizeConstraint(button, 10, 14)

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 5)
	buttonCorner.Parent = button

	local buttonPadding = Instance.new("UIPadding")
	buttonPadding.PaddingRight = UDim.new(0, 6)
	buttonPadding.PaddingLeft = UDim.new(0, 6)
	buttonPadding.Parent = button

	button.Activated:Connect(function()
		submitAnswer(answerIndex)
	end)

	answerButtons[answerIndex] = button
end

local function startTimer(duration)
	timerVersion += 1

	local localTimerVersion = timerVersion

	task.spawn(function()
		for remaining = duration, 0, -1 do
			if localTimerVersion ~= timerVersion or activeRoundId == nil then
				return
			end

			statusLabel.Text = ("%d s"):format(remaining)

			task.wait(1)
		end
	end)
end

local function showQuestion(payload)
	activeRoundId = payload.RoundId
	selectedAnswerIndex = nil

	clearAnswers()

	questionLabel.Text = payload.Prompt
	statusLabel.Text = ""

	for index, answerText in ipairs(payload.Answers) do
		createAnswerButton(answerText, index)
	end

	startTimer(payload.TimeLimit)
end

local function showStatus(payload)
	activeRoundId = nil
	selectedAnswerIndex = nil
	timerVersion += 1
	clearAnswers()

	questionLabel.Text = payload.Message or "En attente..."
	statusLabel.Text = ""
end

local function showResult(payload)
	activeRoundId = nil
	selectedAnswerIndex = nil
	timerVersion += 1
	setButtonsEnabled(false)
	markResult(payload.SelectedAnswerIndex, payload.CorrectAnswerIndex)

	if payload.WasCorrect then
		statusLabel.Text = "Bonus"
	elseif payload.SelectedAnswerIndex == 0 then
		statusLabel.Text = "Temps ecoule"
	else
		statusLabel.Text = "Malus"
	end

	scoreLabel.Text = "Score : " .. tostring(payload.Score)
	questionLabel.Text = payload.EffectMessage or ("Bonne reponse : " .. payload.CorrectAnswerText)
end

if isQuizEnabled then
	showQuestionRemote.OnClientEvent:Connect(showQuestion)

	showResultRemote.OnClientEvent:Connect(function(payload)
		if payload.State == "Result" then
			showResult(payload)
		else
			showStatus(payload)
		end
	end)

	updateScoreRemote.OnClientEvent:Connect(function(score)
		scoreLabel.Text = "Score : " .. tostring(score)
	end)

	updateEffectsRemote.OnClientEvent:Connect(function(payload)
		local stackCount = payload.JumpBonusStacks or 0
		local jumpMultiplier = payload.JumpMultiplier or 1
		local saveStatus = ""

		if payload.LastSaveSucceeded == false then
			saveStatus = " | non sauvegarde"
		end

		if stackCount <= 0 then
			effectsLabel.Text = "Bonus saut : aucun" .. saveStatus
		else
			effectsLabel.Text = ("Bonus saut : %d stacks | x%.1f%s"):format(stackCount, jumpMultiplier, saveStatus)
		end
	end)
end

updateCoinsRemote.OnClientEvent:Connect(function(payload)
	local coinCount = payload.Coins or 0
	local saveStatus = ""

	if payload.LastSaveSucceeded == false then
		saveStatus = " *"
	end

	coinsLabel.Text = "Golds : " .. tostring(coinCount) .. saveStatus
end)

DebugLog.Info("UI", "UI quiz initialisee", {
	Player = player.Name,
})

local function getViewportSize()
	local currentCamera = workspace.CurrentCamera

	if currentCamera == nil then
		return Vector2.new(1280, 720)
	end

	return currentCamera.ViewportSize
end

local function setContainerTopLeft(topLeft)
	local viewportSize = getViewportSize()
	local containerSize = container.AbsoluteSize
	local margin = 6

	local clampedTopLeft = Vector2.new(
		math.clamp(topLeft.X, margin, math.max(margin, viewportSize.X - containerSize.X - margin)),
		math.clamp(topLeft.Y, margin, math.max(margin, viewportSize.Y - containerSize.Y - margin))
	)

	container.Position = UDim2.fromOffset(
		clampedTopLeft.X + (containerSize.X * container.AnchorPoint.X),
		clampedTopLeft.Y + (containerSize.Y * container.AnchorPoint.Y)
	)
end

local function beginDrag(input)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end

	dragging = true
	dragStartPosition = input.Position
	dragStartTopLeft = container.AbsolutePosition

	input.Changed:Connect(function()
		if input.UserInputState == Enum.UserInputState.End then
			dragging = false
		end
	end)
end

local function bindDragHandle(handle)
	handle.InputBegan:Connect(beginDrag)
end

UserInputService.InputChanged:Connect(function(input)
	if not dragging then
		return
	end

	if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end

	local delta = input.Position - dragStartPosition
	setContainerTopLeft(dragStartTopLeft + Vector2.new(delta.X, delta.Y))
end)

bindDragHandle(headerFrame)
bindDragHandle(quizLabel)
bindDragHandle(statusLabel)
bindDragHandle(scoreLabel)
bindDragHandle(questionLabel)
