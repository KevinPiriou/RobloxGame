local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DebugLog = require(Shared:WaitForChild("DebugLog"))
local FeatureFlags = require(Shared:WaitForChild("FeatureFlags"))

local AdminService = require(script.Parent:WaitForChild("AdminService"))
local ArcaneGemService = require(script.Parent:WaitForChild("ArcaneGemService"))
local AudioService = require(script.Parent:WaitForChild("AudioService"))
local BossService = require(script.Parent:WaitForChild("BossService"))
local ChapterProgressService = require(script.Parent:WaitForChild("ChapterProgressService"))
local ChestService = require(script.Parent:WaitForChild("ChestService"))
local CoinService = require(script.Parent:WaitForChild("CoinService"))
local CommerceService = require(script.Parent:WaitForChild("CommerceService"))
local JarService = require(script.Parent:WaitForChild("JarService"))
local JumpBonusService = require(script.Parent:WaitForChild("JumpBonusService"))
local MonsterService = require(script.Parent:WaitForChild("MonsterService"))
local MetaProgressionService = require(script.Parent:WaitForChild("MetaProgressionService"))
local PerkService = require(script.Parent:WaitForChild("PerkService"))
local PlayerPreferencesService = require(script.Parent:WaitForChild("PlayerPreferencesService"))
local PortalService = require(script.Parent:WaitForChild("PortalService"))
local RoundService = require(script.Parent:WaitForChild("RoundService"))
local RunEndService = require(script.Parent:WaitForChild("RunEndService"))
local RunAnalyticsService = require(script.Parent:WaitForChild("RunAnalyticsService"))
local RunMapService = require(script.Parent:WaitForChild("RunMapService"))
local RunSessionService = require(script.Parent:WaitForChild("RunSessionService"))
local RunTeleportService = require(script.Parent:WaitForChild("RunTeleportService"))
local RunItemService = require(script.Parent:WaitForChild("RunItemService"))
local RunStateService = require(script.Parent:WaitForChild("RunStateService"))
local RunWorldService = require(script.Parent:WaitForChild("RunWorldService"))
local ScoreService = require(script.Parent:WaitForChild("ScoreService"))
local ShrineService = require(script.Parent:WaitForChild("ShrineService"))
local TemplateService = require(script.Parent:WaitForChild("TemplateService"))
local TotemService = require(script.Parent:WaitForChild("TotemService"))
local WeaponSkinService = require(script.Parent:WaitForChild("WeaponSkinService"))
local WeaponService = require(script.Parent:WaitForChild("WeaponService"))
local XpService = require(script.Parent:WaitForChild("XpService"))

DebugLog.Info("GameManager", "Demarrage GameManager", {
	AdminToolsEnabled = FeatureFlags.AdminToolsEnabled,
	DebugUIEnabled = FeatureFlags.DebugUIEnabled,
	QuizEnabled = FeatureFlags.QuizEnabled,
})

TemplateService.Start()
RunMapService.Start()
RunSessionService.SetWorldService(RunWorldService)
DebugLog.Info("GameManager", "Start PlayerPreferencesService")
PlayerPreferencesService.Start()

local function setupPlayer(player)
	DebugLog.Info("GameManager", "Setup joueur", {
		Player = player.Name,
		UserId = player.UserId,
	})

	if FeatureFlags.AdminToolsEnabled then
		AdminService.SetupPlayer(player)
	end

	if FeatureFlags.QuizEnabled then
		ScoreService.SetupPlayer(player)
	end

	RunStateService.SetupPlayer(player)
	RunEndService.SetupPlayer(player)
	ChapterProgressService.SetupPlayer(player)
	RunSessionService.SetupPlayer(player)
	CommerceService.SetupPlayer(player)
	PlayerPreferencesService.SetupPlayer(player)
	ArcaneGemService.SetupPlayer(player)
	MetaProgressionService.SetupPlayer(player)
	MetaProgressionService.ReconcileRunHistory(player, RunSessionService.GetHistory(player))
	PerkService.SetupPlayer(player)
	RunItemService.SetupPlayer(player)
	WeaponSkinService.SetupPlayer(player)
	XpService.SetupPlayer(player)
	MonsterService.SetupPlayer(player)
	ShrineService.SetupPlayer(player)
	RunTeleportService.SetupPlayer(player)

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
	DebugLog.Info("GameManager", "Remove joueur", {
		Player = player.Name,
		UserId = player.UserId,
	})

	if FeatureFlags.QuizEnabled then
		RoundService.RemovePlayer(player)
	end

	WeaponService.RemovePlayer(player)
	MonsterService.RemovePlayer(player)
	ShrineService.RemovePlayer(player)
	ChestService.RemovePlayer(player)
	RunTeleportService.RemovePlayer(player)
	RunAnalyticsService.RemovePlayer(player)
	RunSessionService.RemovePlayer(player)
	BossService.RemovePlayer(player)
	RunEndService.RemovePlayer(player)
	RunStateService.RemovePlayer(player)
	ChapterProgressService.RemovePlayer(player)
	CommerceService.RemovePlayer(player)
	PlayerPreferencesService.SavePlayer(player)
	PlayerPreferencesService.RemovePlayer(player)
	ArcaneGemService.RemovePlayer(player)
	MetaProgressionService.RemovePlayer(player)

	if FeatureFlags.AdminToolsEnabled then
		AdminService.RemovePlayer(player)
	end

	XpService.RemovePlayer(player)
	CoinService.RemovePlayer(player)
	PerkService.RemovePlayer(player)
	RunItemService.RemovePlayer(player)
	WeaponSkinService.RemovePlayer(player)
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
		ArcaneGemService.SavePlayer(player)
		PlayerPreferencesService.SavePlayer(player)
		MetaProgressionService.SavePlayer(player)
		ChapterProgressService.SavePlayer(player)
		RunSessionService.SavePlayer(player)
		CoinService.SavePlayer(player)
		JumpBonusService.SavePlayer(player)
	end
end)

if FeatureFlags.AdminToolsEnabled then
	DebugLog.Info("GameManager", "Start AdminService")
	AdminService.Start()
end

DebugLog.Info("GameManager", "Start AudioService")
AudioService.Start()
DebugLog.Info("GameManager", "Start CommerceService")
CommerceService.Start()
DebugLog.Info("GameManager", "Start ChapterProgressService")
ChapterProgressService.Start()
DebugLog.Info("GameManager", "Start MetaProgressionService")
MetaProgressionService.Start()
DebugLog.Info("GameManager", "Start PerkService")
PerkService.Start()
DebugLog.Info("GameManager", "Start RunAnalyticsService")
RunAnalyticsService.Start()
DebugLog.Info("GameManager", "Start RunItemService")
RunItemService.Start()
DebugLog.Info("GameManager", "Start RunSessionService")
RunSessionService.Start()
DebugLog.Info("GameManager", "Start RunEndService")
RunEndService.Start()
DebugLog.Info("GameManager", "Start BossService")
BossService.Start()
DebugLog.Info("GameManager", "Start PortalService")
PortalService.Start()
DebugLog.Info("GameManager", "Start ShrineService")
ShrineService.Start()
DebugLog.Info("GameManager", "Start ChestService")
ChestService.Start()
DebugLog.Info("GameManager", "Start MonsterService")
MonsterService.Start()
DebugLog.Info("GameManager", "Start TotemService")
TotemService.Start()
DebugLog.Info("GameManager", "Start WeaponSkinService")
WeaponSkinService.Start()
DebugLog.Info("GameManager", "Start WeaponService")
WeaponService.Start()
DebugLog.Info("GameManager", "Start CoinService")
CoinService.Start()
DebugLog.Info("GameManager", "Start XpService")
XpService.Start()
DebugLog.Info("GameManager", "Start JarService")
JarService.Start()
DebugLog.Info("GameManager", "Start RunWorldService")
RunWorldService.Start()
DebugLog.Info("GameManager", "Start RunTeleportService")
RunTeleportService.Start()

if FeatureFlags.QuizEnabled then
	DebugLog.Info("GameManager", "Start RoundService")
	RoundService.Start()
end
