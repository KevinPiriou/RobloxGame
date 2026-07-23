--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DebugLog = require(Shared:WaitForChild("DebugLog"))

local CharacterService = require(script.Parent:WaitForChild("CharacterService"))
local MonsterService = require(script.Parent:WaitForChild("MonsterService"))
local PerkService = require(script.Parent:WaitForChild("PerkService"))
local RunStateService = require(script.Parent:WaitForChild("RunStateService"))

local CharacterPassiveProgressionService = {}
local progressByUserId = {}
local isStarted = false

local function getProgress(player: Player)
	local progress = progressByUserId[player.UserId]
	if progress == nil then
		progress = { Kills = 0, GrantedByModifier = {} }
		progressByUserId[player.UserId] = progress
	end
	return progress
end

local function applyKillThresholdModifiers(player: Player)
	local definition = CharacterService.GetActiveDefinition(player)
	local passive = definition and definition.Passive
	if passive == nil or passive.Scope ~= "Player" then
		return
	end

	local progress = getProgress(player)
	for modifierIndex, modifier in ipairs(passive.Modifiers or {}) do
		if modifier.Operation ~= "AddPerKillThreshold" or modifier.StatId ~= "MaxHealthBonus" then
			continue
		end

		local threshold = math.max(1, math.floor(tonumber(modifier.Threshold) or 0))
		local earned = math.floor(progress.Kills / threshold)
		local key = passive.Id .. ":" .. modifierIndex
		local granted = math.max(0, math.floor(progress.GrantedByModifier[key] or 0))
		local missing = math.max(0, earned - granted)
		if missing <= 0 then
			continue
		end

		local amount = math.max(0, tonumber(modifier.Amount) or 0)
		if amount <= 0 then
			continue
		end

		local grantedAmount = PerkService.GrantMaxHealth(player, amount * missing)
		if grantedAmount > 0 then
			progress.GrantedByModifier[key] = granted + missing
			DebugLog.Info("Character", "Palier de passif applique", {
				Player = player.Name,
				PassiveId = passive.Id,
				Kills = progress.Kills,
				Threshold = threshold,
				MaxHealthGranted = grantedAmount,
			})
		end
	end
end

function CharacterPassiveProgressionService.RemovePlayer(player: Player)
	progressByUserId[player.UserId] = nil
end

function CharacterPassiveProgressionService.Start()
	if isStarted then
		return
	end
	isStarted = true

	RunStateService.RunStarted:Connect(function(player)
		progressByUserId[player.UserId] = { Kills = 0, GrantedByModifier = {} }
	end)
	RunStateService.RunEnded:Connect(CharacterPassiveProgressionService.RemovePlayer)
	MonsterService.MonsterKilled:Connect(function(player)
		if player == nil or player.Parent ~= Players or not RunStateService.IsRunActive(player) then
			return
		end
		local progress = getProgress(player)
		progress.Kills += 1
		applyKillThresholdModifiers(player)
	end)

	DebugLog.Info("Character", "Progression des passifs par kills demarree")
end

return CharacterPassiveProgressionService
