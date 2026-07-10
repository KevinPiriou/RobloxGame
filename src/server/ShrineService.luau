local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DebugLog = require(Shared:WaitForChild("DebugLog"))
local ShrineConfig = require(Shared:WaitForChild("ShrineConfig"))

local CoinService = require(script.Parent:WaitForChild("CoinService"))
local CombatStateService = require(script.Parent:WaitForChild("CombatStateService"))
local HudMessageService = require(script.Parent:WaitForChild("HudMessageService"))
local MonsterService = require(script.Parent:WaitForChild("MonsterService"))
local PerkService = require(script.Parent:WaitForChild("PerkService"))
local TemplateService = require(script.Parent:WaitForChild("TemplateService"))
local WorldSpawnService = require(script.Parent:WaitForChild("WorldSpawnService"))
local XpService = require(script.Parent:WaitForChild("XpService"))

local ShrineService = {}

local SHRINE_DEFINITIONS = {
	{
		TypeId = "Perk",
		TemplateName = ShrineConfig.PerkShrineTemplateName,
		InitialSpawnCount = ShrineConfig.InitialSpawnCount,
		PromptName = "PerkShrinePrompt",
		PromptText = ShrineConfig.PromptText,
		PromptObjectText = ShrineConfig.PromptObjectText,
		ChargeDuration = ShrineConfig.ChargeDuration,
		ChargeDistance = ShrineConfig.ChargeDistance,
		DischargeDuration = ShrineConfig.ChargeDuration,
		ActivationMode = "BubblePresence",
		BubbleVisibleWhenActive = true,
		SpawnMinRadius = ShrineConfig.SpawnWorldMinRadius,
		SpawnMaxRadius = ShrineConfig.SpawnWorldMaxRadius,
		SpawnMinDistance = ShrineConfig.SpawnWorldMinObjectDistance,
		LogLabel = "shrines perk",
		FallbackColor = Color3.fromRGB(72, 63, 100),
	},
	{
		TypeId = "EliteChallenge",
		TemplateName = ShrineConfig.EliteChallengeShrineTemplateName,
		InitialSpawnCount = ShrineConfig.EliteChallengeInitialSpawnCount,
		PromptName = "EliteChallengeShrinePrompt",
		PromptText = ShrineConfig.EliteChallengePromptText,
		PromptObjectText = ShrineConfig.EliteChallengePromptObjectText,
		ChargeDuration = ShrineConfig.ChargeDuration * 0.5,
		ChargeDistance = ShrineConfig.ChargeDistance,
		CompleteSoundId = ShrineConfig.EliteChallengeCompleteSoundId,
		SpawnMinRadius = 36,
		SpawnMaxRadius = ShrineConfig.SpawnWorldMaxRadius,
		SpawnMinDistance = 32,
		LogLabel = "shrines elite",
		FallbackColor = Color3.fromRGB(135, 51, 51),
	},
	{
		TypeId = "Magnet",
		TemplateName = ShrineConfig.MagnetShrineTemplateName,
		InitialSpawnCount = ShrineConfig.MagnetInitialSpawnCount,
		PromptName = "MagnetShrinePrompt",
		PromptText = ShrineConfig.MagnetPromptText,
		PromptObjectText = ShrineConfig.MagnetPromptObjectText,
		ChargeDuration = ShrineConfig.ChargeDuration * 0.5,
		ChargeDistance = ShrineConfig.ChargeDistance,
		SpawnMinRadius = 20,
		SpawnMaxRadius = 215,
		SpawnMinDistance = 18,
		RelaxedSpawnMaxRadius = 235,
		RelaxedSpawnMinDistance = 10,
		RelaxedSpawnAttemptsMultiplier = 3,
		LogLabel = "shrines magnet",
		FallbackColor = Color3.fromRGB(63, 112, 120),
	},
}

local runtimeFolder = nil
local isStarted = false
local shrineTemplatesByType = {}
local spawnedCountsByType = {}
local shrinesByInstance = {}
local chargeHeartbeatConnection = nil

local function createFallbackShrineTemplate(templateStorage, definition)
	local model = Instance.new("Model")
	model.Name = definition.TemplateName

	local base = Instance.new("Part")
	base.Name = "Base"
	base.Size = Vector3.new(6, 1, 6)
	base.Color = definition.FallbackColor
	base.Material = Enum.Material.Slate
	base.Anchored = true
	base.Parent = model

	local chargePart = Instance.new("Part")
	chargePart.Name = ShrineConfig.ChargePartName
	chargePart.Size = Vector3.new(8, 5, 8)
	chargePart.Position = Vector3.new(0, 2.5, 0)
	chargePart.Transparency = 1
	chargePart.Anchored = true
	chargePart.CanCollide = false
	chargePart.CanTouch = false
	chargePart.CanQuery = false
	chargePart.Parent = model

	if definition.TypeId == "Perk" then
		local bubble = Instance.new("Part")
		bubble.Name = ShrineConfig.BubbleName
		bubble.Shape = Enum.PartType.Ball
		bubble.Size = Vector3.new(8, 8, 8)
		bubble.Position = Vector3.new(0, 3.2, 0)
		bubble.Color = Color3.fromRGB(135, 215, 255)
		bubble.Material = Enum.Material.ForceField
		bubble.Transparency = 0.45
		bubble.Anchored = true
		bubble.CanCollide = false
		bubble.CanTouch = false
		bubble.CanQuery = false
		bubble.Parent = model
	end

	model.PrimaryPart = base
	model.Parent = templateStorage

	DebugLog.Warn("Shrine", "Template shrine introuvable, fallback cree", {
		Template = definition.TemplateName,
		TypeId = definition.TypeId,
	})

	return model
end

local function hasAncestorNamed(instance, ancestorName)
	local current = instance.Parent

	while current ~= nil do
		if current.Name == ancestorName then
			return true
		end

		current = current.Parent
	end

	return false
end

local function isIgnoredForGrounding(part)
	return part.Name == ShrineConfig.ChargePartName
		or part.Name == ShrineConfig.BubbleName
		or hasAncestorNamed(part, ShrineConfig.BubbleName)
		or part.Name == ShrineConfig.ActivationMarkerName
end

local function findGroundingPart(instance)
	if instance:IsA("BasePart") then
		return instance
	end

	if not instance:IsA("Model") then
		return nil
	end

	if instance.PrimaryPart ~= nil and not isIgnoredForGrounding(instance.PrimaryPart) then
		return instance.PrimaryPart
	end

	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("BasePart") and not isIgnoredForGrounding(descendant) then
			instance.PrimaryPart = descendant
			return descendant
		end
	end

	return instance:FindFirstChildWhichIsA("BasePart", true)
end

local function findRoot(instance)
	if instance:IsA("BasePart") then
		return instance
	end

	if not instance:IsA("Model") then
		return nil
	end

	return findGroundingPart(instance)
end

local function findPromptPart(shrine)
	local chargePart = shrine:FindFirstChild(ShrineConfig.ChargePartName, true)

	if chargePart ~= nil and chargePart:IsA("BasePart") then
		return chargePart
	end

	return findRoot(shrine)
end

local function findBubble(shrine)
	return shrine:FindFirstChild(ShrineConfig.BubbleName, true)
end

local function createRuntimeFallbackBubble(shrine, definition)
	if definition.TypeId ~= "Perk" or findBubble(shrine) ~= nil then
		return
	end

	local root = findRoot(shrine)

	if root == nil then
		return
	end

	local bubble = Instance.new("Part")
	bubble.Name = ShrineConfig.BubbleName
	bubble.Shape = Enum.PartType.Ball
	bubble.Size = ShrineConfig.FallbackBubbleSize
	bubble.CFrame = CFrame.new(root.Position + Vector3.new(0, ShrineConfig.FallbackBubbleHeightOffset, 0))
	bubble.Color = Color3.fromRGB(135, 215, 255)
	bubble.Material = Enum.Material.ForceField
	bubble.Transparency = 0.45
	bubble.Anchored = true
	bubble.CanCollide = false
	bubble.CanTouch = false
	bubble.CanQuery = false
	bubble.Parent = shrine

	DebugLog.Warn("Shrine", "Bubble PerkShrine absente, fallback runtime cree", {
		Shrine = shrine,
	})
end

local function setVisualVisible(instance, isVisible)
	if instance:IsA("BasePart") or instance:IsA("Decal") or instance:IsA("Texture") then
		if instance:GetAttribute("ShrineOriginalTransparency") == nil then
			instance:SetAttribute("ShrineOriginalTransparency", instance.Transparency)
		end

		if isVisible then
			instance.Transparency = instance:GetAttribute("ShrineOriginalTransparency")
		else
			instance.Transparency = 1
		end
	elseif instance:IsA("ParticleEmitter") or instance:IsA("Beam") or instance:IsA("Trail") or instance:IsA("BillboardGui") then
		instance.Enabled = isVisible
	end
end

local function setBubbleVisible(shrine, isVisible)
	local bubble = findBubble(shrine)

	if bubble == nil then
		return
	end

	setVisualVisible(bubble, isVisible)

	for _, descendant in ipairs(bubble:GetDescendants()) do
		setVisualVisible(descendant, isVisible)
	end
end

local function ensureBubbleIsInsideTemplate(template)
	if template == nil or findBubble(template) ~= nil then
		return
	end

	local looseBubble = Workspace:FindFirstChild(ShrineConfig.BubbleName, true)

	if looseBubble == nil or looseBubble:IsDescendantOf(runtimeFolder) then
		DebugLog.Warn("Shrine", "Bubble absente du template PerkShrine", {
			Template = template,
		})
		return
	end

	DebugLog.Warn("Shrine", "Bubble rattachee au template PerkShrine", {
		Bubble = looseBubble,
		Template = template,
	})
	looseBubble.Parent = template
end

local function getPlayerRoot(player)
	local character = player.Character

	if character == nil then
		return nil
	end

	return character:FindFirstChild("HumanoidRootPart")
end

local function getShrinePosition(shrine)
	if shrine:IsA("Model") then
		local cframe = shrine:GetBoundingBox()

		return cframe.Position
	end

	local root = findRoot(shrine)

	if root == nil then
		return nil
	end

	return root.Position
end

local function isPlayerCloseEnough(player, shrine, definition)
	local playerRoot = getPlayerRoot(player)
	local shrinePosition = getShrinePosition(shrine)

	if playerRoot == nil or shrinePosition == nil then
		return false
	end

	return (playerRoot.Position - shrinePosition).Magnitude <= definition.ChargeDistance + 1
end

local function getBubbleChargeZone(shrine, definition)
	local bubble = findBubble(shrine)

	if bubble ~= nil and bubble:IsA("BasePart") then
		return bubble.Position, math.max(bubble.Size.X, bubble.Size.Y, bubble.Size.Z) * 0.5
	end

	if bubble ~= nil and bubble:IsA("Model") then
		local cframe, size = bubble:GetBoundingBox()

		return cframe.Position, math.max(size.X, size.Y, size.Z) * 0.5
	end

	local chargePart = shrine:FindFirstChild(ShrineConfig.ChargePartName, true)

	if chargePart ~= nil and chargePart:IsA("BasePart") then
		return chargePart.Position, math.max(chargePart.Size.X, chargePart.Size.Y, chargePart.Size.Z) * 0.5
	end

	return getShrinePosition(shrine), definition.ChargeDistance
end

local function isPlayerInsideBubbleChargeZone(player, shrine, definition)
	local playerRoot = getPlayerRoot(player)
	local zonePosition, zoneRadius = getBubbleChargeZone(shrine, definition)

	if playerRoot == nil or zonePosition == nil then
		return false
	end

	return (playerRoot.Position - zonePosition).Magnitude <= zoneRadius + 1
end

local function findBubbleChargePlayer(shrine, definition)
	for _, player in ipairs(Players:GetPlayers()) do
		if isPlayerInsideBubbleChargeZone(player, shrine, definition) then
			return player
		end
	end

	return nil
end

local function setShrineChargeProgress(shrine, progress)
	shrine:SetAttribute("ShrineChargeProgress", math.clamp(progress, 0, 1))
end

local function normalizeSoundId(soundId)
	if typeof(soundId) == "number" then
		return "rbxassetid://" .. tostring(soundId)
	end

	if typeof(soundId) ~= "string" or soundId == "" then
		return nil
	end

	if string.find(soundId, "rbxassetid://") == 1 then
		return soundId
	end

	return "rbxassetid://" .. soundId
end

local function createShrineSound(parent, name, soundId, volume, maxDistance, isLooped)
	local normalizedSoundId = normalizeSoundId(soundId)

	if normalizedSoundId == nil or parent == nil then
		return nil
	end

	local sound = parent:FindFirstChild(name)

	if sound == nil then
		sound = Instance.new("Sound")
		sound.Name = name
		sound.Parent = parent
	end

	assert(sound:IsA("Sound"), name .. " doit etre un Sound.")

	sound.SoundId = normalizedSoundId
	sound.Volume = volume
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMaxDistance = maxDistance
	sound.Looped = isLooped

	DebugLog.Info("Audio", "Sound shrine configure", {
		Name = name,
		SoundId = normalizedSoundId,
		Looped = isLooped,
		Parent = parent,
	})

	return sound
end

local function setupShrineSounds(promptPart, definition)
	local chargeSoundId = definition.ChargeSoundId or ShrineConfig.ChargeSoundId
	local completeSoundId = definition.CompleteSoundId or ShrineConfig.CompleteSoundId

	return {
		Charge = createShrineSound(
			promptPart,
			"ShrineChargeSound",
			chargeSoundId,
			ShrineConfig.ChargeSoundVolume,
			ShrineConfig.ChargeSoundMaxDistance,
			true
		),
		Complete = createShrineSound(
			promptPart,
			"ShrineCompleteSound",
			completeSoundId,
			ShrineConfig.CompleteSoundVolume,
			ShrineConfig.CompleteSoundMaxDistance,
			false
		),
	}
end

local function playChargeSound(shrineState)
	local sound = shrineState.ChargeSound

	if sound == nil then
		return
	end

	if not sound.IsPlaying then
		sound.TimePosition = 0
		sound:Play()
	end
end

local function stopChargeSound(shrineState)
	local sound = shrineState.ChargeSound

	if sound ~= nil and sound.IsPlaying then
		sound:Stop()
	end
end

local function playCompleteSound(shrineState)
	local sound = shrineState.CompleteSound

	if sound == nil then
		return
	end

	sound.TimePosition = 0
	sound:Play()
end

local function getMarkerHeight(shrine)
	if shrine:IsA("Model") then
		local _, size = shrine:GetBoundingBox()

		return (size.Y * 0.5) + ShrineConfig.ActivationMarkerHeightOffset
	end

	if shrine:IsA("BasePart") then
		return (shrine.Size.Y * 0.5) + ShrineConfig.ActivationMarkerHeightOffset
	end

	return ShrineConfig.ActivationMarkerHeightOffset
end

local function setupActivationMarker(shrine)
	local root = findRoot(shrine)

	if root == nil then
		return nil
	end

	local marker = root:FindFirstChild(ShrineConfig.ActivationMarkerName)

	if marker == nil then
		marker = Instance.new("BillboardGui")
		marker.Name = ShrineConfig.ActivationMarkerName
		marker.Parent = root
	end

	assert(marker:IsA("BillboardGui"), ShrineConfig.ActivationMarkerName .. " doit etre un BillboardGui.")

	marker.Adornee = root
	marker.AlwaysOnTop = true
	marker.Enabled = true
	marker.LightInfluence = 0
	marker.MaxDistance = ShrineConfig.ActivationMarkerMaxDistance
	marker.Size = UDim2.fromOffset(42, 42)
	marker.StudsOffset = Vector3.new(0, getMarkerHeight(shrine), 0)

	local label = marker:FindFirstChild("Label")

	if label == nil then
		label = Instance.new("TextLabel")
		label.Name = "Label"
		label.Parent = marker
	end

	assert(label:IsA("TextLabel"), "Label du marker shrine doit etre un TextLabel.")

	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(16, 18, 26)
	label.BackgroundTransparency = 0.28
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBlack
	label.Text = ShrineConfig.ActivationMarkerText
	label.TextColor3 = Color3.fromRGB(255, 232, 92)
	label.TextScaled = true
	label.TextStrokeTransparency = 0.3

	local corner = label:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = label

	local stroke = label:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Transparency = 0.72
	stroke.Thickness = 1
	stroke.Parent = label

	return marker
end

local function setActivationMarkerVisible(shrine, isVisible)
	local shrineState = shrinesByInstance[shrine]

	if shrineState == nil or shrineState.Marker == nil then
		return
	end

	shrineState.Marker.Enabled = isVisible
end

local function setShrineInactive(shrine, prompt)
	local shrineState = shrinesByInstance[shrine]

	if shrineState ~= nil then
		stopChargeSound(shrineState)
		shrineState.ChargingPlayer = nil
		shrineState.ChargeProgress = 0
	end

	shrine:SetAttribute("ShrineActive", false)
	shrine:SetAttribute("ShrineCharging", false)
	setShrineChargeProgress(shrine, 0)
	setBubbleVisible(shrine, false)
	setActivationMarkerVisible(shrine, false)

	if prompt ~= nil then
		prompt.Enabled = false
	end
end

local function onChargeStarted(shrine, player)
	local shrineState = shrinesByInstance[shrine]

	if shrineState == nil
		or not shrineState.Active
		or CombatStateService.IsPaused()
		or not isPlayerCloseEnough(player, shrine, shrineState.Definition)
	then
		return
	end

	shrine:SetAttribute("ShrineCharging", true)
	setBubbleVisible(shrine, true)
	playChargeSound(shrineState)
	DebugLog.Info("Shrine", "Charge shrine commencee", {
		Player = player.Name,
		Shrine = shrine,
		TypeId = shrineState.Definition.TypeId,
	})
end

local function onChargeEnded(shrine)
	local shrineState = shrinesByInstance[shrine]

	if shrineState == nil or not shrineState.Active then
		return
	end

	shrine:SetAttribute("ShrineCharging", false)
	setBubbleVisible(shrine, false)
	stopChargeSound(shrineState)
	DebugLog.Info("Shrine", "Charge shrine interrompue", {
		Shrine = shrine,
		TypeId = shrineState.Definition.TypeId,
	})
end

local function activateMagnetShrine(player)
	local xpCount = XpService.CollectAllForPlayer(
		player,
		ShrineConfig.MagnetCollectDuration,
		ShrineConfig.MagnetCollectSpreadDuration
	)
	local coinCount = CoinService.CollectAllForPlayer(
		player,
		ShrineConfig.MagnetCollectDuration,
		ShrineConfig.MagnetCollectSpreadDuration
	)

	DebugLog.Info("Shrine", "MagnetShrine activee", {
		Player = player.Name,
		XpCount = xpCount,
		CoinCount = coinCount,
	})
end

local function activateEliteChallengeShrine(player, shrine)
	local shrinePosition = getShrinePosition(shrine)
	local spawnedCount, requestedCount = MonsterService.SpawnElitePack(shrinePosition, player)

	if spawnedCount > 0 then
		HudMessageService.Show(player, "EliteChallenge", {
			Message = ("CHALLENGE ELITE : %d ENNEMIS APPROCHENT"):format(spawnedCount),
		})
	end

	DebugLog.Info("Shrine", "EliteChallengeShrine activee", {
		Player = player.Name,
		Shrine = shrine,
		Spawned = spawnedCount,
		Requested = requestedCount,
	})
end

local function activateShrineEffect(player, definition, shrine)
	if definition.TypeId == "Perk" then
		PerkService.QueueBonusChoice(player, ShrineConfig.PerkChoiceTitle)
	elseif definition.TypeId == "Magnet" then
		activateMagnetShrine(player)
	elseif definition.TypeId == "EliteChallenge" then
		activateEliteChallengeShrine(player, shrine)
	end
end

local function activateShrineFromPlayer(shrine, prompt, player)
	local shrineState = shrinesByInstance[shrine]

	if shrineState == nil
		or not shrineState.Active
		or CombatStateService.IsPaused()
		or not isPlayerCloseEnough(player, shrine, shrineState.Definition)
	then
		return false
	end

	shrineState.Active = false
	shrineState.ChargingPlayer = nil
	shrineState.ChargeProgress = 1
	stopChargeSound(shrineState)
	playCompleteSound(shrineState)
	setShrineInactive(shrine, prompt)
	activateShrineEffect(player, shrineState.Definition, shrine)
	DebugLog.Info("Shrine", "Shrine validee", {
		Player = player.Name,
		Shrine = shrine,
		TypeId = shrineState.Definition.TypeId,
	})

	return true
end

local function onShrineTriggered(shrine, prompt, player)
	activateShrineFromPlayer(shrine, prompt, player)
end

local function updateBubblePresenceShrine(shrine, shrineState, deltaTime)
	local definition = shrineState.Definition

	if definition.ActivationMode ~= "BubblePresence" or not shrineState.Active then
		return
	end

	if CombatStateService.IsPaused() then
		if shrineState.ChargingPlayer ~= nil then
			shrineState.ChargingPlayer = nil
			shrine:SetAttribute("ShrineCharging", false)
			stopChargeSound(shrineState)
		end

		return
	end

	local player = findBubbleChargePlayer(shrine, definition)

	if player ~= nil then
		if shrineState.ChargingPlayer ~= player then
			shrineState.ChargingPlayer = player
			shrine:SetAttribute("ShrineCharging", true)
			setBubbleVisible(shrine, true)
			playChargeSound(shrineState)
			DebugLog.Info("Shrine", "Charge shrine par presence commencee", {
				Player = player.Name,
				Shrine = shrine,
				TypeId = definition.TypeId,
			})
		end

		local chargeDuration = math.max(0.1, definition.ChargeDuration)
		shrineState.ChargeProgress = math.min(1, (shrineState.ChargeProgress or 0) + (deltaTime / chargeDuration))
		setShrineChargeProgress(shrine, shrineState.ChargeProgress)

		if shrineState.ChargeProgress >= 1 then
			activateShrineFromPlayer(shrine, shrineState.Prompt, player)
		end

		return
	end

	if shrineState.ChargingPlayer ~= nil then
		DebugLog.Info("Shrine", "Charge shrine par presence interrompue", {
			Shrine = shrine,
			TypeId = definition.TypeId,
		})
	end

	shrineState.ChargingPlayer = nil
	shrine:SetAttribute("ShrineCharging", false)
	stopChargeSound(shrineState)

	if (shrineState.ChargeProgress or 0) > 0 then
		local dischargeDuration = math.max(0.1, definition.DischargeDuration or definition.ChargeDuration)

		shrineState.ChargeProgress = math.max(0, shrineState.ChargeProgress - (deltaTime / dischargeDuration))
		setShrineChargeProgress(shrine, shrineState.ChargeProgress)
	end
end

local function updateBubblePresenceShrines(deltaTime)
	for shrine, shrineState in pairs(shrinesByInstance) do
		updateBubblePresenceShrine(shrine, shrineState, deltaTime)
	end
end

local function setupPrompt(shrine, definition)
	local promptPart = findPromptPart(shrine)

	if promptPart == nil then
		DebugLog.Warn("Shrine", "Aucune BasePart pour placer le ProximityPrompt", {
			Shrine = shrine,
			TypeId = definition.TypeId,
		})
		return nil, nil
	end

	local prompt = promptPart:FindFirstChild(definition.PromptName)

	if prompt == nil then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = definition.PromptName
		prompt.Parent = promptPart
	end

	assert(prompt:IsA("ProximityPrompt"), definition.PromptName .. " doit etre un ProximityPrompt.")

	prompt.ActionText = definition.PromptText
	prompt.ObjectText = definition.PromptObjectText
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = definition.ChargeDuration
	prompt.MaxActivationDistance = definition.ChargeDistance
	prompt.RequiresLineOfSight = false
	prompt.Enabled = true

	DebugLog.Info("Shrine", "ProximityPrompt shrine pret", {
		Shrine = shrine,
		TypeId = definition.TypeId,
		PromptPart = promptPart,
		Distance = definition.ChargeDistance,
		HoldDuration = definition.ChargeDuration,
	})

	prompt.PromptButtonHoldBegan:Connect(function(player)
		onChargeStarted(shrine, player)
	end)

	prompt.PromptButtonHoldEnded:Connect(function()
		onChargeEnded(shrine)
	end)

	prompt.Triggered:Connect(function(player)
		onShrineTriggered(shrine, prompt, player)
	end)

	return prompt, promptPart
end

local function removePrompt(shrine, promptName)
	for _, descendant in ipairs(shrine:GetDescendants()) do
		if descendant:IsA("ProximityPrompt") and descendant.Name == promptName then
			descendant:Destroy()
		end
	end
end

local function prepareShrineInstance(shrine, definition)
	createRuntimeFallbackBubble(shrine, definition)

	local bubble = findBubble(shrine)
	local chargePart = shrine:FindFirstChild(ShrineConfig.ChargePartName, true)

	for _, descendant in ipairs(shrine:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true

			if descendant == chargePart or (bubble ~= nil and (descendant == bubble or descendant:IsDescendantOf(bubble))) then
				descendant.CanCollide = false
				descendant.CanTouch = false
				descendant.CanQuery = false
			end
		end
	end

	if shrine:IsA("BasePart") then
		shrine.Anchored = true
	end

	if chargePart ~= nil and chargePart:IsA("BasePart") then
		chargePart.Transparency = 1
	end

	shrine:SetAttribute("ShrineActive", true)
	shrine:SetAttribute("ShrineCharging", false)
	setShrineChargeProgress(shrine, 0)
	shrine:SetAttribute("ShrineType", definition.TypeId)

	local prompt = nil
	local promptPart = findPromptPart(shrine)

	if definition.ActivationMode == "BubblePresence" then
		removePrompt(shrine, definition.PromptName)
		setBubbleVisible(shrine, definition.BubbleVisibleWhenActive == true)
		DebugLog.Info("Shrine", "Charge shrine par presence prete", {
			Shrine = shrine,
			TypeId = definition.TypeId,
			ChargeDuration = definition.ChargeDuration,
			DischargeDuration = definition.DischargeDuration,
		})
	else
		setBubbleVisible(shrine, false)
		prompt, promptPart = setupPrompt(shrine, definition)
	end

	local marker = setupActivationMarker(shrine)

	return prompt, marker, setupShrineSounds(promptPart, definition)
end

local function pivotInstance(instance, cframe)
	if instance:IsA("Model") or instance:IsA("BasePart") then
		instance:PivotTo(cframe)
	end
end

local function spawnShrineAtSurface(definition, surfacePosition)
	local shrineTemplate = shrineTemplatesByType[definition.TypeId]

	if shrineTemplate == nil then
		return nil
	end

	local shrine = shrineTemplate:Clone()
	shrine.Name = definition.TemplateName
	shrine.Parent = runtimeFolder

	local root = findRoot(shrine)

	if root == nil then
		DebugLog.Warn("Shrine", "Shrine sans BasePart, generation annulee", {
			Shrine = shrine,
			TypeId = definition.TypeId,
		})
		shrine:Destroy()
		return nil
	end

	local prompt, marker, sounds = prepareShrineInstance(shrine, definition)
	local pivotPosition = WorldSpawnService.GetSurfacePivotPosition(
		shrine,
		surfacePosition,
		ShrineConfig.SpawnSurfaceOffset,
		isIgnoredForGrounding
	)

	pivotInstance(shrine, WorldSpawnService.GetPivotCFrameAtPosition(shrine, pivotPosition))

	shrinesByInstance[shrine] = {
		Active = true,
		Definition = definition,
		Marker = marker,
		Prompt = prompt,
		ChargeProgress = 0,
		ChargingPlayer = nil,
		ChargeSound = sounds.Charge,
		CompleteSound = sounds.Complete,
	}

	shrine.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			shrinesByInstance[shrine] = nil
		end
	end)

	spawnedCountsByType[definition.TypeId] = (spawnedCountsByType[definition.TypeId] or 0) + 1

	DebugLog.Info("Shrine", "Shrine generee", {
		Shrine = shrine,
		TypeId = definition.TypeId,
		SurfacePosition = surfacePosition,
		PivotPosition = pivotPosition,
		SpawnedCount = spawnedCountsByType[definition.TypeId],
	})

	return shrine
end

local function getOccupiedSurfacePositions()
	local occupiedPositions = WorldSpawnService.GetPositionsFromFolder(runtimeFolder)

	for _, position in ipairs(WorldSpawnService.GetPositionsFromFolder(TemplateService.GetPortalsRuntimeFolder())) do
		table.insert(occupiedPositions, position)
	end

	for _, position in ipairs(WorldSpawnService.GetPositionsFromFolder(TemplateService.GetChestsRuntimeFolder())) do
		table.insert(occupiedPositions, position)
	end

	for _, position in ipairs(WorldSpawnService.GetPositionsFromFolder(TemplateService.GetJarsRuntimeFolder())) do
		table.insert(occupiedPositions, position)
	end

	return occupiedPositions
end

local function copyPositions(positions)
	local copiedPositions = {}

	for _, position in ipairs(positions) do
		table.insert(copiedPositions, position)
	end

	return copiedPositions
end

local function findSurfacePositionsForDefinition(definition, neededCount)
	local occupiedPositions = getOccupiedSurfacePositions()
	local surfacePositions = WorldSpawnService.FindDistributedSurfacePositions({
		Count = neededCount,
		Center = ShrineConfig.SpawnWorldCenter,
		MinRadius = definition.SpawnMinRadius,
		MaxRadius = definition.SpawnMaxRadius,
		MinDistance = definition.SpawnMinDistance,
		AttemptsPerPoint = ShrineConfig.SpawnWorldAttemptsPerShrine,
		JitterRadius = ShrineConfig.SpawnWorldJitterRadius,
		RaycastHeight = ShrineConfig.SpawnRaycastHeight,
		RaycastDepth = ShrineConfig.SpawnRaycastDepth,
		RejectedSurfaceNameContains = ShrineConfig.RejectedSurfaceNameContains,
		OccupiedPositions = occupiedPositions,
		LogCategory = "Shrine",
		LogLabel = definition.LogLabel,
	})

	local missingCount = neededCount - #surfacePositions

	if missingCount <= 0 or definition.RelaxedSpawnMinDistance == nil then
		return surfacePositions
	end

	DebugLog.Warn("Shrine", "Retry placement shrine avec contraintes relachees", {
		TypeId = definition.TypeId,
		Missing = missingCount,
		MaxRadius = definition.RelaxedSpawnMaxRadius or definition.SpawnMaxRadius,
		MinDistance = definition.RelaxedSpawnMinDistance,
	})

	local relaxedOccupiedPositions = copyPositions(occupiedPositions)

	for _, surfacePosition in ipairs(surfacePositions) do
		table.insert(relaxedOccupiedPositions, surfacePosition)
	end

	local relaxedSurfacePositions = WorldSpawnService.FindDistributedSurfacePositions({
		Count = missingCount,
		Center = ShrineConfig.SpawnWorldCenter,
		MinRadius = definition.SpawnMinRadius,
		MaxRadius = definition.RelaxedSpawnMaxRadius or definition.SpawnMaxRadius,
		MinDistance = definition.RelaxedSpawnMinDistance,
		AttemptsPerPoint = ShrineConfig.SpawnWorldAttemptsPerShrine * (definition.RelaxedSpawnAttemptsMultiplier or 2),
		JitterRadius = ShrineConfig.SpawnWorldJitterRadius,
		RaycastHeight = ShrineConfig.SpawnRaycastHeight,
		RaycastDepth = ShrineConfig.SpawnRaycastDepth,
		RejectedSurfaceNameContains = ShrineConfig.RejectedSurfaceNameContains,
		OccupiedPositions = relaxedOccupiedPositions,
		LogCategory = "Shrine",
		LogLabel = definition.LogLabel .. " retry",
	})

	for _, surfacePosition in ipairs(relaxedSurfacePositions) do
		table.insert(surfacePositions, surfacePosition)
	end

	return surfacePositions
end

local function spawnInitialShrinesForDefinition(definition)
	if shrineTemplatesByType[definition.TypeId] == nil then
		DebugLog.Warn("Shrine", "Generation shrine impossible, template absent", {
			TypeId = definition.TypeId,
			Template = definition.TemplateName,
		})
		return
	end

	local spawnedCount = spawnedCountsByType[definition.TypeId] or 0
	local neededCount = math.max(0, definition.InitialSpawnCount - spawnedCount)

	if neededCount <= 0 then
		DebugLog.Info("Shrine", "Generation shrine ignoree, limite deja atteinte", {
			TypeId = definition.TypeId,
			SpawnedCount = spawnedCount,
			Limit = definition.InitialSpawnCount,
		})
		return
	end

	DebugLog.Info("Shrine", "Generation shrine repartie demandee", {
		TypeId = definition.TypeId,
		Requested = neededCount,
		MaxRadius = definition.SpawnMaxRadius,
		MinDistance = definition.SpawnMinDistance,
	})

	local surfacePositions = findSurfacePositionsForDefinition(definition, neededCount)

	for _, surfacePosition in ipairs(surfacePositions) do
		if (spawnedCountsByType[definition.TypeId] or 0) >= definition.InitialSpawnCount then
			break
		end

		spawnShrineAtSurface(definition, surfacePosition)
	end

	DebugLog.Info("Shrine", "Generation shrine initiale terminee", {
		TypeId = definition.TypeId,
		Requested = definition.InitialSpawnCount,
		SpawnedCount = spawnedCountsByType[definition.TypeId] or 0,
	})
end

local function loadTemplates()
	for _, definition in ipairs(SHRINE_DEFINITIONS) do
		shrineTemplatesByType[definition.TypeId] = TemplateService.GetTemplate(
			ShrineConfig.TemplateFolderName,
			definition.TemplateName,
			function(templateStorage)
				return createFallbackShrineTemplate(templateStorage, definition)
			end
		)

		if definition.TypeId == "Perk" then
			ensureBubbleIsInsideTemplate(shrineTemplatesByType[definition.TypeId])
		end
	end
end

local function spawnInitialShrines()
	for _, definition in ipairs(SHRINE_DEFINITIONS) do
		spawnInitialShrinesForDefinition(definition)
	end
end

function ShrineService.SetupPlayer(player)
	DebugLog.Info("Shrine", "Setup joueur shrine", {
		Player = player.Name,
	})
end

function ShrineService.RemovePlayer(player)
	DebugLog.Info("Shrine", "Remove joueur shrine", {
		Player = player.Name,
	})
end

function ShrineService.Start()
	if isStarted then
		DebugLog.Info("Shrine", "Start ignore, service deja demarre")
		return
	end

	isStarted = true
	runtimeFolder = TemplateService.GetShrinesRuntimeFolder()
	loadTemplates()

	DebugLog.Info("Shrine", "ShrineService demarre", {
		RuntimeFolder = runtimeFolder,
		PerkTemplate = shrineTemplatesByType.Perk,
		EliteTemplate = shrineTemplatesByType.EliteChallenge,
		MagnetTemplate = shrineTemplatesByType.Magnet,
	})

	if chargeHeartbeatConnection == nil then
		chargeHeartbeatConnection = RunService.Heartbeat:Connect(updateBubblePresenceShrines)
	end

	spawnInitialShrines()
end

return ShrineService
