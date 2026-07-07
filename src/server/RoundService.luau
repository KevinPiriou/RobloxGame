local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")

local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Questions = require(Shared:WaitForChild("Questions"))
local JumpBonusService = require(script.Parent:WaitForChild("JumpBonusService"))
local ScoreService = require(script.Parent:WaitForChild("ScoreService"))

local RoundService = {}

local rng = Random.new()
local isRunning = false
local currentRoundId = 0
local currentQuestion = nil
local answersByUserId = {}

local remotes = {
	ShowQuestion = nil,
	SubmitAnswer = nil,
	ShowResult = nil,
	UpdateScore = nil,
}

local function getOrCreateRemote(remoteName)
	local remote = ReplicatedStorage:FindFirstChild(remoteName)

	if remote == nil then
		remote = Instance.new("RemoteEvent")
		remote.Name = remoteName
		remote.Parent = ReplicatedStorage
	end

	assert(remote:IsA("RemoteEvent"), remoteName .. " doit etre un RemoteEvent.")

	return remote
end

local function setupRemotes()
	remotes.ShowQuestion = getOrCreateRemote("Quiz_ShowQuestion")
	remotes.SubmitAnswer = getOrCreateRemote("Quiz_SubmitAnswer")
	remotes.ShowResult = getOrCreateRemote("Quiz_ShowResult")
	remotes.UpdateScore = getOrCreateRemote("Quiz_UpdateScore")
end

local function getPlayerCount()
	return #Players:GetPlayers()
end

local function hasEnoughPlayers()
	return getPlayerCount() >= GameConfig.MinPlayers
end

local function copyAnswers(answers)
	local copiedAnswers = {}

	for index, answer in ipairs(answers) do
		copiedAnswers[index] = answer
	end

	return copiedAnswers
end

local function chooseQuestion()
	assert(#Questions > 0, "Aucune question de quiz n'est configuree.")

	return Questions[rng:NextInteger(1, #Questions)]
end

local function sendStatus(message)
	remotes.ShowResult:FireAllClients({
		State = "Status",
		Message = message,
	})
end

local function waitForEnoughPlayers()
	while not hasEnoughPlayers() do
		sendStatus(("En attente de joueurs (%d/%d)."):format(getPlayerCount(), GameConfig.MinPlayers))
		task.wait(1)
	end
end

local function runLobby()
	for remaining = GameConfig.LobbyDuration, 1, -1 do
		if not hasEnoughPlayers() then
			return false
		end

		sendStatus(("Prochaine question dans %d s."):format(remaining))
		task.wait(1)
	end

	return true
end

local function sendQuestion(question)
	remotes.ShowQuestion:FireAllClients({
		RoundId = currentRoundId,
		Prompt = question.Prompt,
		Answers = copyAnswers(question.Answers),
		TimeLimit = GameConfig.QuestionDuration,
	})
end

local function sendPlayerResult(player, question, selectedAnswerIndex, wasCorrect, score, effectMessage)
	remotes.ShowResult:FireClient(player, {
		State = "Result",
		WasCorrect = wasCorrect,
		SelectedAnswerIndex = selectedAnswerIndex or 0,
		CorrectAnswerIndex = question.CorrectAnswerIndex,
		CorrectAnswerText = question.Answers[question.CorrectAnswerIndex],
		Score = score,
		EffectMessage = effectMessage,
	})

	remotes.UpdateScore:FireClient(player, score)
end

local function finishQuestion(participants, question)
	for _, player in ipairs(participants) do
		if player.Parent == Players then
			local selectedAnswerIndex = answersByUserId[player.UserId]
			local wasCorrect = selectedAnswerIndex == question.CorrectAnswerIndex
			local score = ScoreService.GetScore(player)
			local effectMessage = "Aucun effet."

			if wasCorrect then
				score = ScoreService.AddPoints(player, GameConfig.PointsPerCorrectAnswer)
				effectMessage = JumpBonusService.GrantDoubleJump(player)
			elseif selectedAnswerIndex ~= nil then
				effectMessage = JumpBonusService.ApplyJumpMalus(player)
			end

			sendPlayerResult(player, question, selectedAnswerIndex, wasCorrect, score, effectMessage)
		end
	end
end

local function runQuestion()
	local participants = Players:GetPlayers()

	currentRoundId += 1
	currentQuestion = chooseQuestion()
	answersByUserId = {}

	sendQuestion(currentQuestion)
	task.wait(GameConfig.QuestionDuration)

	finishQuestion(participants, currentQuestion)

	currentQuestion = nil
	answersByUserId = {}

	task.wait(GameConfig.ResultDuration)
end

local function onSubmitAnswer(player, roundId, answerIndex)
	if currentQuestion == nil then
		return
	end

	if typeof(roundId) ~= "number" or typeof(answerIndex) ~= "number" then
		return
	end

	if roundId ~= currentRoundId then
		return
	end

	if answerIndex ~= math.floor(answerIndex) then
		return
	end

	if answerIndex == 0 then
		answersByUserId[player.UserId] = nil
		return
	end

	if answerIndex < 1 or answerIndex > #currentQuestion.Answers then
		return
	end

	answersByUserId[player.UserId] = answerIndex
end

function RoundService.RemovePlayer(player)
	answersByUserId[player.UserId] = nil
end

function RoundService.Start()
	if isRunning then
		return
	end

	isRunning = true
	setupRemotes()
	remotes.SubmitAnswer.OnServerEvent:Connect(onSubmitAnswer)

	while true do
		waitForEnoughPlayers()

		if runLobby() then
			runQuestion()
		end
	end
end

return RoundService
