local ScoreService = {}

local scoresByUserId = {}

local function getOrCreateScoreValue(player)
	local leaderstats = player:FindFirstChild("leaderstats")

	if leaderstats == nil then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	local scoreValue = leaderstats:FindFirstChild("Score")

	if scoreValue == nil then
		scoreValue = Instance.new("IntValue")
		scoreValue.Name = "Score"
		scoreValue.Parent = leaderstats
	end

	return scoreValue
end

function ScoreService.SetupPlayer(player)
	if scoresByUserId[player.UserId] == nil then
		scoresByUserId[player.UserId] = 0
	end

	local scoreValue = getOrCreateScoreValue(player)
	scoreValue.Value = scoresByUserId[player.UserId]
end

function ScoreService.RemovePlayer(player)
	scoresByUserId[player.UserId] = nil
end

function ScoreService.GetScore(player)
	return scoresByUserId[player.UserId] or 0
end

function ScoreService.AddPoints(player, points)
	local currentScore = ScoreService.GetScore(player)
	local nextScore = currentScore + points

	scoresByUserId[player.UserId] = nextScore
	getOrCreateScoreValue(player).Value = nextScore

	return nextScore
end

return ScoreService
