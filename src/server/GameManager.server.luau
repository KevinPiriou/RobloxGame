local Players = game:GetService("Players")

local AdminService = require(script.Parent:WaitForChild("AdminService"))
local CoinService = require(script.Parent:WaitForChild("CoinService"))
local JumpBonusService = require(script.Parent:WaitForChild("JumpBonusService"))
local MonsterService = require(script.Parent:WaitForChild("MonsterService"))
local RoundService = require(script.Parent:WaitForChild("RoundService"))
local ScoreService = require(script.Parent:WaitForChild("ScoreService"))
local WeaponService = require(script.Parent:WaitForChild("WeaponService"))
local XpService = require(script.Parent:WaitForChild("XpService"))

local function setupPlayer(player)
	AdminService.SetupPlayer(player)
	ScoreService.SetupPlayer(player)
	XpService.SetupPlayer(player)
	MonsterService.SetupPlayer(player)

	task.spawn(function()
		JumpBonusService.SetupPlayer(player)
	end)

	task.spawn(function()
		CoinService.SetupPlayer(player)
	end)
end

Players.PlayerAdded:Connect(setupPlayer)
Players.PlayerRemoving:Connect(function(player)
	RoundService.RemovePlayer(player)
	WeaponService.RemovePlayer(player)
	MonsterService.RemovePlayer(player)
	AdminService.RemovePlayer(player)
	XpService.RemovePlayer(player)
	CoinService.RemovePlayer(player)
	JumpBonusService.RemovePlayer(player)
	ScoreService.RemovePlayer(player)
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

AdminService.Start()
MonsterService.Start()
WeaponService.Start()
CoinService.Start()
XpService.Start()
RoundService.Start()
