local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DebugLog = require(Shared:WaitForChild("DebugLog"))
local TotemConfig = require(Shared:WaitForChild("TotemConfig"))

local CombatStateService = require(script.Parent:WaitForChild("CombatStateService"))
local HudMessageService = require(script.Parent:WaitForChild("HudMessageService"))
local MonsterService = require(script.Parent:WaitForChild("MonsterService"))
local TemplateService = require(script.Parent:WaitForChild("TemplateService"))
local WorldSpawnService = require(script.Parent:WaitForChild("WorldSpawnService"))

local TotemService = {}

local rng = Random.new()
local runtimeFolder = nil
local totemTemplate = nil
local isStarted = false
local spawnedTotemCount = 0
local trackedTotems = {}

local function createFallbackTotemTemplate(templateStorage)
	local model = Instance.new("Model")
	model.Name = TotemConfig.DifficultTotemName

	local base = Instance.new("Part")
	base.Name = "Base"
	base.Size = Vector3.new(3.5, 0.8, 3.5)
	base.Color = Color3.fromRGB(68, 42, 34)
	base.Material = Enum.Material.Slate
	base.Anchored = true
	base.Parent = model

	local pillar = Instance.new("Part")
	pillar.Name = "Pillar"
	pillar.Size = Vector3.new(1.8, 4.8, 1.8)
	pillar.Position = Vector3.new(0, 2.8, 0)
	pillar.Color = Color3.fromRGB(126, 65, 52)
	pillar.Material = Enum.Material.Rock
	pillar.Anchored = true
	pillar.Parent = model

	local glow = Instance.new("Part")
	glow.Name = "DifficultyGlow"
	glow.Shape = Enum.PartType.Ball
	glow.Size = Vector3.new(1.2, 1.2, 1.2)
	glow.Position = Vector3.new(0, 5.6, 0)
	glow.Color = Color3.fromRGB(255, 86, 54)
	glow.Material = Enum.Material.Neon
	glow.Anchored = true
	glow.CanCollide = false
	glow.Parent = model

	model.PrimaryPart = base
	model.Parent = templateStorage

	DebugLog.Warn("Totem", "Template DifficultTotem introuvable, fallback cree")

	return model
end

local function getTotemContainer(instance)
	local current = instance

	while current ~= nil and current ~= Workspace do
		if current.Name == TotemConfig.DifficultTotemName then
			return current
		end

		current = current.Parent
	end

	return nil
end

local function findTotemRoot(totem)
	if totem:IsA("BasePart") then
		return totem
	end

	if totem:IsA("Model") and totem.PrimaryPart ~= nil then
		return totem.PrimaryPart
	end

	local root = totem:FindFirstChildWhichIsA("BasePart", true)

	if root ~= nil and totem:IsA("Model") then
		totem.PrimaryPart = root
	end

	return root
end

local function resolveTotem(instance)
	if typeof(instance) ~= "Instance" then
		return nil
	end

	local totem = getTotemContainer(instance)

	if totem == nil or findTotemRoot(totem) == nil then
		return nil
	end

	return totem
end

local function setTotemVisualActive(totem, isActive)
	for _, descendant in ipairs(totem:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Material == Enum.Material.Neon then
			descendant.Transparency = isActive and 0 or 0.6
		end
	end
end

local function activateTotem(player, totem, prompt)
	local totemState = trackedTotems[totem]

	if CombatStateService.IsPaused() then
		return
	end

	if totemState == nil or totemState.Activated or totem:GetAttribute("TotemActivated") == true then
		return
	end

	totemState.Activated = true
	totem:SetAttribute("TotemActivated", true)
	setTotemVisualActive(totem, false)

	if prompt ~= nil then
		prompt.Enabled = false
	end

	local totalDifficulty = MonsterService.AddDifficultyPercent(
		TotemConfig.DifficultyIncreasePercent,
		player,
		TotemConfig.DifficultTotemName
	)
	local addedPercent = math.floor((TotemConfig.DifficultyIncreasePercent * 100) + 0.5)

	HudMessageService.Show(player, "DifficultyTotem", {
		Message = ("LA DIFFICULTE AUGMENTE DE %d%%"):format(addedPercent),
	})

	DebugLog.Info("Totem", "DifficultTotem active", {
		Player = player.Name,
		Totem = totem,
		AddedPercent = addedPercent,
		TotalPercent = math.floor((totalDifficulty * 100) + 0.5),
	})
end

local function setupPrompt(totem)
	local root = findTotemRoot(totem)

	if root == nil then
		return nil
	end

	local prompt = root:FindFirstChild(TotemConfig.PromptName)

	if prompt == nil then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = TotemConfig.PromptName
		prompt.Parent = root
	end

	assert(prompt:IsA("ProximityPrompt"), TotemConfig.PromptName .. " doit etre un ProximityPrompt.")

	prompt.ActionText = TotemConfig.PromptText
	prompt.ObjectText = TotemConfig.PromptObjectText
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = TotemConfig.ActivationDistance
	prompt.RequiresLineOfSight = false
	prompt.Enabled = totem:GetAttribute("TotemActivated") ~= true

	prompt.Triggered:Connect(function(player)
		activateTotem(player, totem, prompt)
	end)

	return prompt
end

local function trackTotem(instance)
	local totem = resolveTotem(instance)

	if totem == nil or trackedTotems[totem] ~= nil then
		return
	end

	local prompt = setupPrompt(totem)

	if prompt == nil then
		DebugLog.Warn("Totem", "DifficultTotem sans BasePart, interaction impossible", {
			Totem = totem,
		})
		return
	end

	if totem:GetAttribute("TotemActivated") == nil then
		totem:SetAttribute("TotemActivated", false)
	end

	setTotemVisualActive(totem, totem:GetAttribute("TotemActivated") ~= true)

	trackedTotems[totem] = {
		Activated = totem:GetAttribute("TotemActivated") == true,
		Prompt = prompt,
	}

	DebugLog.Info("Totem", "DifficultTotem tracke", {
		Totem = totem,
	})
end

local function scanExistingTotems()
	for _, descendant in ipairs(Workspace:GetDescendants()) do
		trackTotem(descendant)
	end
end

local function pivotInstance(instance, cframe)
	if instance:IsA("Model") or instance:IsA("BasePart") then
		instance:PivotTo(cframe)
	end
end

local function prepareTotemInstance(totem)
	for _, descendant in ipairs(totem:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
		end
	end

	if totem:IsA("BasePart") then
		totem.Anchored = true
	end

	if totem:GetAttribute("TotemActivated") == nil then
		totem:SetAttribute("TotemActivated", false)
	end
end

local function getOccupiedSurfacePositions()
	local occupiedPositions = WorldSpawnService.GetPositionsFromFolder(runtimeFolder)

	for _, folder in ipairs({
		TemplateService.GetShrinesRuntimeFolder(),
		TemplateService.GetChestsRuntimeFolder(),
		TemplateService.GetJarsRuntimeFolder(),
		TemplateService.GetPortalsRuntimeFolder(),
	}) do
		for _, position in ipairs(WorldSpawnService.GetPositionsFromFolder(folder)) do
			table.insert(occupiedPositions, position)
		end
	end

	for totem in pairs(trackedTotems) do
		local position = WorldSpawnService.GetInstancePosition(totem)

		if position ~= nil then
			table.insert(occupiedPositions, position)
		end
	end

	return occupiedPositions
end

local function spawnTotemAtSurface(surfacePosition)
	if totemTemplate == nil then
		return nil
	end

	local totem = totemTemplate:Clone()
	totem.Name = TotemConfig.DifficultTotemName
	totem.Parent = runtimeFolder
	prepareTotemInstance(totem)

	local root = findTotemRoot(totem)

	if root == nil then
		DebugLog.Warn("Totem", "DifficultTotem sans BasePart, generation annulee", {
			Totem = totem,
		})
		totem:Destroy()
		return nil
	end

	local pivotPosition = WorldSpawnService.GetSurfacePivotPosition(
		totem,
		surfacePosition,
		TotemConfig.SpawnSurfaceOffset
	)

	pivotInstance(totem, WorldSpawnService.GetPivotCFrameAtPosition(totem, pivotPosition, rng:NextNumber(0, math.pi * 2)))
	trackTotem(totem)
	spawnedTotemCount += 1

	DebugLog.Info("Totem", "DifficultTotem genere", {
		Totem = totem,
		SurfacePosition = surfacePosition,
		PivotPosition = pivotPosition,
		SpawnedCount = spawnedTotemCount,
	})

	return totem
end

local function spawnInitialTotems()
	if totemTemplate == nil then
		DebugLog.Warn("Totem", "Generation DifficultTotem impossible, template absent")
		return
	end

	local neededCount = math.max(0, TotemConfig.InitialSpawnCount - spawnedTotemCount)

	if neededCount <= 0 then
		DebugLog.Info("Totem", "Generation DifficultTotem ignoree, limite deja atteinte", {
			SpawnedCount = spawnedTotemCount,
			Limit = TotemConfig.InitialSpawnCount,
		})
		return
	end

	DebugLog.Info("Totem", "Generation DifficultTotem repartie demandee", {
		Requested = neededCount,
		MaxRadius = TotemConfig.SpawnWorldMaxRadius,
		MinDistance = TotemConfig.SpawnWorldMinObjectDistance,
	})

	local surfacePositions = WorldSpawnService.FindDistributedSurfacePositions({
		Count = neededCount,
		Center = TotemConfig.SpawnWorldCenter,
		MinRadius = TotemConfig.SpawnWorldMinRadius,
		MaxRadius = TotemConfig.SpawnWorldMaxRadius,
		MinDistance = TotemConfig.SpawnWorldMinObjectDistance,
		AttemptsPerPoint = TotemConfig.SpawnWorldAttemptsPerTotem,
		JitterRadius = TotemConfig.SpawnWorldJitterRadius,
		RaycastHeight = TotemConfig.SpawnRaycastHeight,
		RaycastDepth = TotemConfig.SpawnRaycastDepth,
		RejectedSurfaceNameContains = TotemConfig.RejectedSurfaceNameContains,
		OccupiedPositions = getOccupiedSurfacePositions(),
		LogCategory = "Totem",
		LogLabel = "DifficultTotem",
	})

	for _, surfacePosition in ipairs(surfacePositions) do
		if spawnedTotemCount >= TotemConfig.InitialSpawnCount then
			break
		end

		spawnTotemAtSurface(surfacePosition)
	end

	DebugLog.Info("Totem", "Generation DifficultTotem initiale terminee", {
		Requested = TotemConfig.InitialSpawnCount,
		SpawnedCount = spawnedTotemCount,
	})
end

function TotemService.Start()
	if isStarted then
		DebugLog.Info("Totem", "Start ignore, service deja demarre")
		return
	end

	isStarted = true
	runtimeFolder = TemplateService.GetTotemsRuntimeFolder()
	totemTemplate = TemplateService.GetTemplate(
		TotemConfig.TemplateFolderName,
		TotemConfig.DifficultTotemName,
		createFallbackTotemTemplate
	)

	scanExistingTotems()
	spawnInitialTotems()

	DebugLog.Info("Totem", "TotemService demarre", {
		RuntimeFolder = runtimeFolder,
		Template = totemTemplate,
		SpawnedTotemCount = spawnedTotemCount,
		DifficultyIncreasePercent = math.floor((TotemConfig.DifficultyIncreasePercent * 100) + 0.5),
	})

	Workspace.DescendantAdded:Connect(function(descendant)
		task.defer(function()
			trackTotem(descendant)
		end)
	end)

	Workspace.DescendantRemoving:Connect(function(descendant)
		local totemState = trackedTotems[descendant]

		if totemState ~= nil and totemState.Prompt ~= nil then
			totemState.Prompt:Destroy()
		end

		trackedTotems[descendant] = nil
	end)
end

return TotemService
