--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DebugLog = require(Shared:WaitForChild("DebugLog"))
local RunActionCreditConfig = require(Shared:WaitForChild("RunActionCreditConfig"))

local RunStateService = require(script.Parent:WaitForChild("RunStateService"))

local RunActionCreditService = {}

export type ActionId = "Pass" | "Ban"

type Profile = {
	PassCredits: number,
	BanCredits: number,
}

local profilesByUserId: { [number]: Profile } = {}
local isStarted = false

local function normalizeCredit(value: number?): number
	return math.max(0, math.floor(tonumber(value) or 0))
end

local function getOrCreateProfile(player: Player): Profile
	local profile = profilesByUserId[player.UserId]

	if profile == nil then
		profile = {
			PassCredits = 0,
			BanCredits = 0,
		}
		profilesByUserId[player.UserId] = profile
	end

	return profile
end

local function publish(player: Player, profile: Profile)
	if player.Parent ~= Players then
		return
	end

	player:SetAttribute("RunPassCredits", normalizeCredit(profile.PassCredits))
	player:SetAttribute("RunBanCredits", normalizeCredit(profile.BanCredits))
	player:SetAttribute("RunPassCreditsMax", RunActionCreditConfig.MaxPassCreditsPerRun)
	player:SetAttribute("RunBanCreditsMax", RunActionCreditConfig.MaxBanCreditsPerRun)
end

local function resetForRun(player: Player)
	local profile = getOrCreateProfile(player)
	profile.PassCredits = RunActionCreditConfig.MaxPassCreditsPerRun
	profile.BanCredits = RunActionCreditConfig.MaxBanCreditsPerRun
	publish(player, profile)

	DebugLog.Info("RunActions", "Credits de choix initialises pour la run", {
		Player = player.Name,
		PassCredits = profile.PassCredits,
		BanCredits = profile.BanCredits,
	})
end

local function clearForLobby(player: Player)
	local profile = getOrCreateProfile(player)
	profile.PassCredits = 0
	profile.BanCredits = 0
	publish(player, profile)
end

function RunActionCreditService.SetupPlayer(player: Player)
	publish(player, getOrCreateProfile(player))
end

function RunActionCreditService.RemovePlayer(player: Player)
	profilesByUserId[player.UserId] = nil
end

function RunActionCreditService.GetCredits(player: Player): (number, number)
	local profile = getOrCreateProfile(player)
	return normalizeCredit(profile.PassCredits), normalizeCredit(profile.BanCredits)
end

function RunActionCreditService.TryConsume(player: Player, action: ActionId): (boolean, string?)
	if not RunStateService.IsRunActive(player) then
		return false, "RunInactive"
	end

	local profile = getOrCreateProfile(player)

	if action == "Pass" then
		if profile.PassCredits <= 0 then
			return false, "NoPassCredits"
		end

		profile.PassCredits -= 1
	elseif action == "Ban" then
		if profile.BanCredits <= 0 then
			return false, "NoBanCredits"
		end

		profile.BanCredits -= 1
	else
		return false, "UnknownAction"
	end

	publish(player, profile)
	DebugLog.Info("RunActions", "Credit de choix consomme", {
		Player = player.Name,
		Action = action,
		PassCredits = profile.PassCredits,
		BanCredits = profile.BanCredits,
	})

	return true
end

function RunActionCreditService.Start()
	if isStarted then
		return
	end

	isStarted = true
	RunStateService.RunStarted:Connect(resetForRun)
	RunStateService.RunEnded:Connect(clearForLobby)
	DebugLog.Info("RunActions", "Service de credits de choix demarre")
end

return RunActionCreditService
