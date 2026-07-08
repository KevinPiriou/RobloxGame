local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FeatureFlags = require(Shared:WaitForChild("FeatureFlags"))

local AdminService = require(script.Parent:WaitForChild("AdminService"))
local ChestService = require(script.Parent:WaitForChild("ChestService"))
local CoinService = require(script.Parent:WaitForChild("CoinService"))
local JumpBonusService = require(script.Parent:WaitForChild("JumpBonusService"))
local MonsterService = require(script.Parent:WaitForChild("MonsterService"))
local PerkService = require(script.Parent:WaitForChild("PerkService"))
local RoundService = require(script.Parent:WaitForChild("RoundService"))
local ScoreService = require(script.Parent:WaitForChild("ScoreService"))
local WeaponService = require(script.Parent:WaitForChild("WeaponService"))
local XpService = require(script.Parent:WaitForChild("XpService"))

local function setupPlayer(player)
	if FeatureFlags.AdminToolsEnabled then
		AdminService.SetupPlayer(player)
	end

	if FeatureFlags.QuizEnabled then
		ScoreService.SetupPlayer(player)
	end

	PerkService.SetupPlayer(player)
	XpService.SetupPlayer(player)
	MonsterService.SetupPlayer(player)

	task.spawn(function()
		CoinService.SetupPlayer(player)
		ChestService.SetupPlayer(player)
	end)

	task.spawn(function()
		JumpBonusService.SetupPlayer(player)
	end)
end

Players.PlayerAdded:Connect(setupPlayer)
Players.PlayerRemoving:Connect(function(player)
	if FeatureFlags.QuizEnabled then
		RoundService.RemovePlayer(player)
	end

	WeaponService.RemovePlayer(player)
	MonsterService.RemovePlayer(player)
	ChestService.RemovePlayer(player)

	if FeatureFlags.AdminToolsEnabled then
		AdminService.RemovePlayer(player)
	end

	XpService.RemovePlayer(player)
	CoinService.RemovePlayer(player)
	PerkService.RemovePlayer(player)
	JumpBonusService.RemovePlayer(player)
	if FeatureFlags.QuizEnabled then
		ScoreService.RemovePlayer(player)
	end
end)

for _, player in ipairs(Players:GetPlayers()) do
	setupPlayer(player)
end

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		CoinService.SavePlayer(player)
		JumpBonusService.SavePlayer(player)
	end
end)

if FeatureFlags.AdminToolsEnabled then
	AdminService.Start()
end

ChestService.Start()
PerkService.Start()
MonsterService.Start()
WeaponService.Start()
CoinService.Start()
XpService.Start()

if FeatureFlags.QuizEnabled then
	RoundService.Start()
end
