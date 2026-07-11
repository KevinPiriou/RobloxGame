local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BossConfig = require(Shared:WaitForChild("BossConfig"))
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))
local DebugLog = require(Shared:WaitForChild("DebugLog"))

local CombatStateService = require(script.Parent:WaitForChild("CombatStateService"))
local BossAttackService = require(script.Parent:WaitForChild("BossAttackService"))
local HudMessageService = require(script.Parent:WaitForChild("HudMessageService"))
local MonsterService = require(script.Parent:WaitForChild("MonsterService"))
local RunEndService = require(script.Parent:WaitForChild("RunEndService"))
local RunStateService = require(script.Parent:WaitForChild("RunStateService"))
local TemplateService = require(script.Parent:WaitForChild("TemplateService"))

local BossService = {}

local statesByUserId = {}
local bossTemplate = nil
local bossTemplateName = nil
local isStarted = false

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

local bossRemote = getOrCreateRemote(BossConfig.BossRemoteName)
local decisionRemote = getOrCreateRemote(BossConfig.DecisionRemoteName)

local function getDecisionPauseReason(player)
	return "BossDecision_" .. player.UserId
end

local function getPortalPosition(portal)
	if portal == nil then
		return nil
	end

	if portal:IsA("BasePart") then
		return portal.Position
	end

	if portal:IsA("Model") then
		return portal:GetPivot().Position
	end

	local part = portal:FindFirstChildWhichIsA("BasePart", true)

	return if part ~= nil then part.Position else nil
end

local function sendBossBar(player, monster, health, maxHealth)
	bossRemote:FireClient(player, {
		Action = "ShowBar",
		Name = BossConfig.DisplayName,
		CurrentHealth = math.max(0, math.floor(health + 0.5)),
		MaxHealth = math.max(1, math.floor(maxHealth + 0.5)),
		Boss = monster,
	})
end

local function hideBossUi(player)
	bossRemote:FireClient(player, {
		Action = "Hide",
	})
end

local function playArrivalSound(position)
	if BossConfig.ArrivalSoundId == nil or BossConfig.ArrivalSoundId == "" or position == nil then
		return
	end

	local emitter = Instance.new("Part")
	emitter.Name = "BossArrivalSoundPoint"
	emitter.Size = Vector3.new(0.2, 0.2, 0.2)
	emitter.CFrame = CFrame.new(position)
	emitter.Transparency = 1
	emitter.Anchored = true
	emitter.CanCollide = false
	emitter.CanTouch = false
	emitter.CanQuery = false
	emitter.Parent = Workspace

	local sound = Instance.new("Sound")
	sound.Name = "BossArrivalSound"
	sound.SoundId = BossConfig.ArrivalSoundId
	sound.Volume = BossConfig.ArrivalSoundVolume
	sound.Parent = emitter
	sound:Play()
	Debris:AddItem(emitter, 12)
end

local function loadBossTemplate()
	if bossTemplate ~= nil then
		return bossTemplate, bossTemplateName
	end

	bossTemplate = TemplateService.GetTemplate(CombatConfig.TemplateFolderName, BossConfig.BossTemplateName)
	bossTemplateName = BossConfig.BossTemplateName

	if bossTemplate == nil then
		bossTemplate = TemplateService.GetTemplate(CombatConfig.TemplateFolderName, BossConfig.FallbackTemplateName)
		bossTemplateName = BossConfig.FallbackTemplateName
		DebugLog.Warn("Boss", "Template Boss1 absent, fallback utilise", {
			Fallback = bossTemplateName,
		})
	end

	return bossTemplate, bossTemplateName
end

local function clearPlayerState(player)
	local state = statesByUserId[player.UserId]

	if state == nil then
		return
	end

	BossAttackService.Deactivate(player)
	CombatStateService.Resume(getDecisionPauseReason(player))
	statesByUserId[player.UserId] = nil
	hideBossUi(player)
end

local function onBossDefeated(player, monster, killer)
	local state = statesByUserId[player.UserId]

	if state == nil or state.Boss ~= monster or state.Phase ~= "Active" then
		return
	end

	state.Boss = nil
	state.Phase = "Decision"
	BossAttackService.Deactivate(player)
	RunEndService.MarkLevelValidated(player)
	hideBossUi(player)
	HudMessageService.Show(player, "BossDefeated")
	CombatStateService.Pause(getDecisionPauseReason(player))

	bossRemote:FireClient(player, {
		Action = "ShowDecision",
		Name = BossConfig.DisplayName,
	})

	DebugLog.Info("Boss", "Boss vaincu", {
		Player = player.Name,
		Boss = monster,
		Killer = killer and killer.Name or "nil",
	})
end

local function spawnBossAfterAnnouncement(player, state)
	if statesByUserId[player.UserId] ~= state or state.Phase ~= "Announcing" then
		return
	end

	if not RunStateService.IsRunActive(player) then
		clearPlayerState(player)
		return
	end

	local origin = getPortalPosition(state.Portal)
	local template, templateName = loadBossTemplate()
	local attackDamage = CombatConfig.MonsterAttackDamage * BossConfig.DamageMultiplier

	local didSpawn, monster = MonsterService.SpawnBossNearPlayer(origin, player, {
		Template = template,
		TemplateName = templateName,
		MaxHealth = BossConfig.MaxHealth,
		AttackDamage = attackDamage,
		BossName = BossConfig.DisplayName,
		SafetyDistance = BossConfig.SpawnSafetyDistance,
		SpeedMultiplier = BossConfig.SpeedMultiplier,
		DropLoot = false,
		OnHealthChanged = function(changedMonster, health, maxHealth)
			local currentState = statesByUserId[player.UserId]

			if currentState ~= nil and currentState.Phase == "Active" and currentState.Boss == changedMonster then
				sendBossBar(player, changedMonster, health, maxHealth)
			end
		end,
		OnDefeated = function(defeatedMonster, killer)
			onBossDefeated(player, defeatedMonster, killer)
		end,
	})

	if not didSpawn or monster == nil then
		local onFailed = state.OnFailed

		if state.Portal ~= nil and state.Portal.Parent ~= nil then
			state.Portal:SetAttribute("BossPortalActivated", false)
		end

		clearPlayerState(player)

		if onFailed ~= nil then
			onFailed()
		end

		DebugLog.Warn("Boss", "Invocation boss echouee", {
			Player = player.Name,
			Portal = state.Portal,
		})
		return
	end

	state.Phase = "Active"
	state.Boss = monster
	playArrivalSound(origin)
	sendBossBar(player, monster, BossConfig.MaxHealth, BossConfig.MaxHealth)
	BossAttackService.Activate(player, monster, attackDamage)

	DebugLog.Info("Boss", "Combat boss commence", {
		Player = player.Name,
		Boss = monster,
		Health = BossConfig.MaxHealth,
		AttackDamage = attackDamage,
		Template = templateName,
	})
end

function BossService.TryStartBoss(player, portal, onFailed)
	if player == nil or portal == nil or not RunStateService.IsRunActive(player) or CombatStateService.IsPaused() then
		return false
	end

	if statesByUserId[player.UserId] ~= nil or portal:GetAttribute("BossPortalActivated") == true then
		return false
	end

	local position = getPortalPosition(portal)

	if position == nil then
		DebugLog.Warn("Boss", "Activation portail refusee, position absente", {
			Player = player.Name,
			Portal = portal,
		})
		return false
	end

	local state = {
		Phase = "Announcing",
		Portal = portal,
		Boss = nil,
		OnFailed = onFailed,
	}

	statesByUserId[player.UserId] = state
	portal:SetAttribute("BossPortalActivated", true)
	HudMessageService.Show(player, "BossArrival", {
		Duration = BossConfig.AnnouncementDuration,
	})

	task.delay(BossConfig.AnnouncementDuration + BossConfig.AnnouncementReleaseDelay, function()
		spawnBossAfterAnnouncement(player, state)
	end)

	DebugLog.Info("Boss", "Portail boss active", {
		Player = player.Name,
		Portal = portal,
		Position = position,
	})

	return true
end

function BossService.RemovePlayer(player)
	clearPlayerState(player)
end

function BossService.Start()
	if isStarted then
		return
	end

	isStarted = true
	loadBossTemplate()
	BossAttackService.Start()

	RunStateService.RunStarted:Connect(function(player)
		clearPlayerState(player)
	end)

	RunStateService.RunEnded:Connect(function(player)
		clearPlayerState(player)
	end)

	decisionRemote.OnServerEvent:Connect(function(player, action)
		local state = statesByUserId[player.UserId]

		if state == nil or state.Phase ~= "Decision" or not RunEndService.IsLevelValidated(player) then
			return
		end

		if action == "Continue" then
			state.Phase = "Surviving"
			CombatStateService.Resume(getDecisionPauseReason(player))
			bossRemote:FireClient(player, {
				Action = "HideDecision",
			})
			DebugLog.Info("Boss", "Victoire boss, survie continue", {
				Player = player.Name,
			})
			return
		end

		if action == "Exit" then
			CombatStateService.Resume(getDecisionPauseReason(player))
			RunStateService.EndRun(player, "VictoryExit")
		end
	end)

	DebugLog.Info("Boss", "BossService demarre", {
		Template = bossTemplate,
		TemplateName = bossTemplateName,
	})
end

return BossService
