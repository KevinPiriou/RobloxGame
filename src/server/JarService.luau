local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DebugLog = require(Shared:WaitForChild("DebugLog"))
local JarConfig = require(Shared:WaitForChild("JarConfig"))

local CoinService = require(script.Parent:WaitForChild("CoinService"))
local CombatStateService = require(script.Parent:WaitForChild("CombatStateService"))
local TemplateService = require(script.Parent:WaitForChild("TemplateService"))
local WorldSpawnService = require(script.Parent:WaitForChild("WorldSpawnService"))
local XpService = require(script.Parent:WaitForChild("XpService"))

local JarService = {}

local rng = Random.new()
local trackedJars = {}
local isStarted = false
local runtimeFolder = nil
local jarTemplate = nil
local spawnedJarCount = 0

local function createFallbackJarTemplate(templateStorage)
	local model = Instance.new("Model")
	model.Name = JarConfig.JarName

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Cylinder
	body.Size = Vector3.new(2.4, 2.8, 2.4)
	body.Color = Color3.fromRGB(128, 86, 54)
	body.Material = Enum.Material.Ceramic
	body.Anchored = true
	body.Parent = model

	local neck = Instance.new("Part")
	neck.Name = "Neck"
	neck.Shape = Enum.PartType.Cylinder
	neck.Size = Vector3.new(1.2, 1, 1.2)
	neck.Position = Vector3.new(0, 1.6, 0)
	neck.Color = Color3.fromRGB(102, 68, 45)
	neck.Material = Enum.Material.Ceramic
	neck.Anchored = true
	neck.Parent = model

	model.PrimaryPart = body
	model.Parent = templateStorage

	DebugLog.Warn("Jar", "Template Jar introuvable, fallback cree")

	return model
end

local function getJarContainer(instance)
	local current = instance

	while current ~= nil and current ~= Workspace do
		if current.Name == JarConfig.JarName then
			return current
		end

		current = current.Parent
	end

	return nil
end

local function findJarRoot(jar)
	if jar:IsA("BasePart") then
		return jar
	end

	if not jar:IsA("Model") then
		return nil
	end

	if jar.PrimaryPart ~= nil then
		return jar.PrimaryPart
	end

	local root = jar:FindFirstChildWhichIsA("BasePart", true)

	if root ~= nil then
		jar.PrimaryPart = root
	end

	return root
end

local function resolveJar(instance)
	if typeof(instance) ~= "Instance" then
		return nil
	end

	local jar = getJarContainer(instance)

	if jar == nil or findJarRoot(jar) == nil then
		return nil
	end

	return jar
end

local function getJarPosition(jar)
	if jar:IsA("Model") then
		local cframe = jar:GetBoundingBox()

		return cframe.Position
	end

	local root = findJarRoot(jar)

	if root == nil then
		return nil
	end

	return root.Position
end

local function getPlayerRoot(player)
	local character = player.Character

	if character == nil then
		return nil
	end

	return character:FindFirstChild("HumanoidRootPart")
end

local function canBreakJar(player, jar, jarState)
	if CombatStateService.IsPaused() then
		return false, "CombatPaused"
	end

	if jar == nil or jar.Parent == nil then
		return false, "JarMissing"
	end

	if jarState == nil or jarState.Broken or jar:GetAttribute("JarBroken") == true then
		return false, "AlreadyBroken"
	end

	local playerRoot = getPlayerRoot(player)
	local jarPosition = getJarPosition(jar)

	if playerRoot == nil or jarPosition == nil then
		return false, "MissingPosition"
	end

	local distance = (playerRoot.Position - jarPosition).Magnitude

	if distance > JarConfig.BreakDistance + (JarConfig.BreakValidationTolerance or 0) then
		return false, "TooFar"
	end

	return true, "Ok"
end

local function chooseLootType()
	local totalWeight = 0

	for _, entry in ipairs(JarConfig.LootTable) do
		totalWeight += entry.Weight or 0
	end

	if totalWeight <= 0 then
		return "Xp"
	end

	local roll = rng:NextNumber(0, totalWeight)
	local cursor = 0

	for _, entry in ipairs(JarConfig.LootTable) do
		cursor += entry.Weight or 0

		if roll <= cursor then
			return entry.Type
		end
	end

	return "Xp"
end

local function getDropPosition(origin, ignoredInstance)
	local angle = rng:NextNumber(0, math.pi * 2)
	local distance = rng:NextNumber(0, JarConfig.DropScatterRadius)
	local horizontalPosition = origin + Vector3.new(
		math.cos(angle) * distance,
		0,
		math.sin(angle) * distance
	)
	local raycastParams = RaycastParams.new()

	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = {
		ignoredInstance,
		Workspace:FindFirstChild("CombatRuntime"),
	}

	local result = Workspace:Raycast(
		horizontalPosition + Vector3.new(0, JarConfig.DropRaycastHeight, 0),
		Vector3.new(0, -JarConfig.DropRaycastDepth, 0),
		raycastParams
	)

	if result ~= nil then
		return result.Position + Vector3.new(0, JarConfig.DropHeightOffset, 0)
	end

	return horizontalPosition + Vector3.new(
		0,
		JarConfig.DropHeightOffset,
		0
	)
end

local function spawnXpDrops(origin, ignoredInstance)
	local count = rng:NextInteger(JarConfig.XpDropMin, JarConfig.XpDropMax)

	for _ = 1, count do
		XpService.SpawnXpGem(getDropPosition(origin, ignoredInstance), JarConfig.XpDropTier)
	end

	return count
end

local function spawnCoinDrops(origin, ignoredInstance)
	local count = rng:NextInteger(JarConfig.CoinDropMin, JarConfig.CoinDropMax)

	for _ = 1, count do
		CoinService.SpawnCoin(getDropPosition(origin, ignoredInstance))
	end

	return count
end

local function playBreakSound(position)
	if typeof(position) ~= "Vector3" or JarConfig.BreakSoundId == nil or JarConfig.BreakSoundId == "" then
		return
	end

	local soundPart = Instance.new("Part")
	soundPart.Name = "JarBreakSoundPoint"
	soundPart.Size = Vector3.new(0.2, 0.2, 0.2)
	soundPart.CFrame = CFrame.new(position)
	soundPart.Transparency = 1
	soundPart.Anchored = true
	soundPart.CanCollide = false
	soundPart.CanTouch = false
	soundPart.CanQuery = false
	soundPart.Parent = Workspace

	local sound = Instance.new("Sound")
	sound.Name = "JarBreakSound"
	sound.SoundId = JarConfig.BreakSoundId
	sound.Volume = JarConfig.BreakSoundVolume
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMaxDistance = JarConfig.BreakSoundMaxDistance
	sound.Parent = soundPart
	sound:Play()

	Debris:AddItem(soundPart, JarConfig.BreakSoundLifetime)
end

local function breakJar(player, jar, prompt)
	local jarState = trackedJars[jar]
	local canBreak, reason = canBreakJar(player, jar, jarState)

	if not canBreak then
		DebugLog.Info("Jar", "Casse jarre refusee", {
			Player = player.Name,
			Jar = jar,
			Reason = reason,
		})
		return
	end

	local jarPosition = getJarPosition(jar)
	playBreakSound(jarPosition)

	jarState.Broken = true
	jar:SetAttribute("JarBroken", true)

	if prompt ~= nil then
		prompt.Enabled = false
	end

	if (JarConfig.BreakResolveDelay or 0) > 0 then
		task.wait(JarConfig.BreakResolveDelay)
	end

	if jar.Parent == nil then
		trackedJars[jar] = nil
		return
	end

	local lootType = chooseLootType()
	local xpCount = 0
	local coinCount = 0

	if lootType == "Xp" or lootType == "Both" then
		xpCount = spawnXpDrops(jarPosition, jar)
	end

	if lootType == "Coin" or lootType == "Both" then
		coinCount = spawnCoinDrops(jarPosition, jar)
	end

	DebugLog.Info("Jar", "Jarre cassee", {
		Player = player.Name,
		Jar = jar,
		LootType = lootType,
		XpCount = xpCount,
		CoinCount = coinCount,
		Position = jarPosition,
	})

	trackedJars[jar] = nil
	jar:Destroy()
end

local function setupPrompt(jar)
	local root = findJarRoot(jar)

	if root == nil then
		return nil
	end

	local prompt = root:FindFirstChild(JarConfig.PromptName)

	if prompt == nil then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = JarConfig.PromptName
		prompt.Parent = root
	end

	assert(prompt:IsA("ProximityPrompt"), JarConfig.PromptName .. " doit etre un ProximityPrompt.")

	prompt.ActionText = JarConfig.PromptText
	prompt.ObjectText = JarConfig.PromptObjectText
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = JarConfig.BreakDistance
	prompt.RequiresLineOfSight = false
	prompt.Enabled = jar:GetAttribute("JarBroken") ~= true

	prompt.Triggered:Connect(function(player)
		breakJar(player, jar, prompt)
	end)

	return prompt
end

local function trackJar(instance)
	local jar = resolveJar(instance)

	if jar == nil or trackedJars[jar] ~= nil then
		return
	end

	local prompt = setupPrompt(jar)

	if prompt == nil then
		DebugLog.Warn("Jar", "Jarre sans BasePart, interaction impossible", {
			Jar = jar,
		})
		return
	end

	if jar:GetAttribute("JarBroken") == nil then
		jar:SetAttribute("JarBroken", false)
	end

	trackedJars[jar] = {
		Broken = jar:GetAttribute("JarBroken") == true,
		Prompt = prompt,
	}

	DebugLog.Info("Jar", "Jarre trackee", {
		Jar = jar,
	})
end

local function scanExistingJars()
	for _, descendant in ipairs(Workspace:GetDescendants()) do
		trackJar(descendant)
	end
end

local function pivotInstance(instance, cframe)
	if instance:IsA("Model") or instance:IsA("BasePart") then
		instance:PivotTo(cframe)
	end
end

local function prepareJarInstance(jar)
	for _, descendant in ipairs(jar:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
		end
	end

	if jar:IsA("BasePart") then
		jar.Anchored = true
	end

	if jar:GetAttribute("JarBroken") == nil then
		jar:SetAttribute("JarBroken", false)
	end
end

local function getOccupiedSurfacePositions()
	local occupiedPositions = WorldSpawnService.GetPositionsFromFolder(runtimeFolder)

	for _, position in ipairs(WorldSpawnService.GetPositionsFromFolder(TemplateService.GetShrinesRuntimeFolder())) do
		table.insert(occupiedPositions, position)
	end

	for _, position in ipairs(WorldSpawnService.GetPositionsFromFolder(TemplateService.GetChestsRuntimeFolder())) do
		table.insert(occupiedPositions, position)
	end

	for jar in pairs(trackedJars) do
		local position = WorldSpawnService.GetInstancePosition(jar)

		if position ~= nil then
			table.insert(occupiedPositions, position)
		end
	end

	return occupiedPositions
end

local function spawnJarAtSurface(surfacePosition)
	if jarTemplate == nil then
		return nil
	end

	local jar = jarTemplate:Clone()
	jar.Name = JarConfig.JarName
	jar.Parent = runtimeFolder
	prepareJarInstance(jar)

	local root = findJarRoot(jar)

	if root == nil then
		DebugLog.Warn("Jar", "Jar sans BasePart, generation annulee", {
			Jar = jar,
		})
		jar:Destroy()
		return nil
	end

	local pivotPosition = WorldSpawnService.GetSurfacePivotPosition(
		jar,
		surfacePosition,
		JarConfig.SpawnSurfaceOffset
	)

	pivotInstance(jar, WorldSpawnService.GetPivotCFrameAtPosition(jar, pivotPosition, rng:NextNumber(0, math.pi * 2)))
	trackJar(jar)
	spawnedJarCount += 1

	DebugLog.Info("Jar", "Jarre generee", {
		Jar = jar,
		SurfacePosition = surfacePosition,
		PivotPosition = pivotPosition,
		SpawnedCount = spawnedJarCount,
	})

	return jar
end

local function spawnInitialJars()
	if jarTemplate == nil then
		DebugLog.Warn("Jar", "Generation jarres impossible, template absent")
		return
	end

	local neededCount = math.max(0, JarConfig.InitialSpawnCount - spawnedJarCount)

	if neededCount <= 0 then
		DebugLog.Info("Jar", "Generation jarres ignoree, limite deja atteinte", {
			SpawnedCount = spawnedJarCount,
			Limit = JarConfig.InitialSpawnCount,
		})
		return
	end

	DebugLog.Info("Jar", "Generation jarres reparties demandee", {
		Requested = neededCount,
		MaxRadius = JarConfig.SpawnWorldMaxRadius,
		MinDistance = JarConfig.SpawnWorldMinObjectDistance,
	})

	local surfacePositions = WorldSpawnService.FindDistributedSurfacePositions({
		Count = neededCount,
		Center = JarConfig.SpawnWorldCenter,
		MinRadius = JarConfig.SpawnWorldMinRadius,
		MaxRadius = JarConfig.SpawnWorldMaxRadius,
		MinDistance = JarConfig.SpawnWorldMinObjectDistance,
		AttemptsPerPoint = JarConfig.SpawnWorldAttemptsPerJar,
		JitterRadius = JarConfig.SpawnWorldJitterRadius,
		RaycastHeight = JarConfig.SpawnRaycastHeight,
		RaycastDepth = JarConfig.SpawnRaycastDepth,
		RejectedSurfaceNameContains = JarConfig.RejectedSurfaceNameContains,
		OccupiedPositions = getOccupiedSurfacePositions(),
		LogCategory = "Jar",
		LogLabel = "jarres",
	})

	for _, surfacePosition in ipairs(surfacePositions) do
		if spawnedJarCount >= JarConfig.InitialSpawnCount then
			break
		end

		spawnJarAtSurface(surfacePosition)
	end

	DebugLog.Info("Jar", "Generation jarres initiale terminee", {
		Requested = JarConfig.InitialSpawnCount,
		SpawnedCount = spawnedJarCount,
	})
end

function JarService.Start()
	if isStarted then
		DebugLog.Info("Jar", "Start ignore, service deja demarre")
		return
	end

	isStarted = true
	runtimeFolder = TemplateService.GetJarsRuntimeFolder()
	jarTemplate = TemplateService.GetTemplate(
		JarConfig.TemplateFolderName,
		JarConfig.JarName,
		createFallbackJarTemplate
	)
	scanExistingJars()
	spawnInitialJars()

	DebugLog.Info("Jar", "JarService demarre", {
		RuntimeFolder = runtimeFolder,
		Template = jarTemplate,
		JarName = JarConfig.JarName,
		BreakDistance = JarConfig.BreakDistance,
		SpawnedJarCount = spawnedJarCount,
	})

	Workspace.DescendantAdded:Connect(function(descendant)
		task.defer(function()
			trackJar(descendant)
		end)
	end)

	Workspace.DescendantRemoving:Connect(function(descendant)
		local jarState = trackedJars[descendant]

		if jarState ~= nil and jarState.Prompt ~= nil then
			jarState.Prompt:Destroy()
		end

		trackedJars[descendant] = nil
	end)
end

return JarService
