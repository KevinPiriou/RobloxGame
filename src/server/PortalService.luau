local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BossConfig = require(Shared:WaitForChild("BossConfig"))
local DebugLog = require(Shared:WaitForChild("DebugLog"))
local PortalConfig = require(Shared:WaitForChild("PortalConfig"))

local TemplateService = require(script.Parent:WaitForChild("TemplateService"))
local ProceduralMapService = require(script.Parent:WaitForChild("ProceduralMapService"))
local RunMapService = require(script.Parent:WaitForChild("RunMapService"))
local WorldSpawnService = require(script.Parent:WaitForChild("WorldSpawnService"))
local BossService = require(script.Parent:WaitForChild("BossService"))
local RunAnalyticsService = require(script.Parent:WaitForChild("RunAnalyticsService"))

local PortalService = {}

local runtimeFolder = nil
local portalTemplate = nil
local isStarted = false
local spawnedPortalCount = 0

local function createFallbackPortalTemplate(templateStorage)
	local model = Instance.new("Model")
	model.Name = PortalConfig.PortalTemplateName

	local base = Instance.new("Part")
	base.Name = "Base"
	base.Size = Vector3.new(7, 0.8, 7)
	base.Color = Color3.fromRGB(48, 36, 76)
	base.Material = Enum.Material.Slate
	base.Anchored = true
	base.Parent = model

	local ring = Instance.new("Part")
	ring.Name = "Portal"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.6, 8, 8)
	ring.Color = Color3.fromRGB(142, 76, 255)
	ring.Material = Enum.Material.Neon
	ring.Anchored = true
	ring.CanCollide = false
	ring.CFrame = CFrame.new(0, 4, 0) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = model

	model.PrimaryPart = base
	model.Parent = templateStorage

	DebugLog.Warn("Portal", "Template PortalBoss introuvable, fallback cree")

	return model
end

local function preparePortalInstance(portal)
	for _, descendant in ipairs(portal:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanTouch = false
			descendant.CanQuery = false
		end
	end

	if portal:IsA("BasePart") then
		portal.Anchored = true
		portal.CanTouch = false
		portal.CanQuery = false
	end

	portal:SetAttribute("PortalBossRuntime", true)
	portal:SetAttribute("BossPortalActivated", false)
end

local function findPortalRoot(portal)
	if portal:IsA("BasePart") then
		return portal
	end

	if portal:IsA("Model") and portal.PrimaryPart ~= nil then
		return portal.PrimaryPart
	end

	local root = portal:FindFirstChildWhichIsA("BasePart", true)

	if root ~= nil and portal:IsA("Model") then
		portal.PrimaryPart = root
	end

	return root
end

local function setupPortalPrompt(portal)
	local root = findPortalRoot(portal)

	if root == nil then
		DebugLog.Warn("Portal", "Portail sans BasePart, interaction impossible", {
			Portal = portal,
		})
		return
	end

	local prompt = root:FindFirstChild(BossConfig.PortalPromptName)

	if prompt == nil then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = BossConfig.PortalPromptName
		prompt.Parent = root
	end

	assert(prompt:IsA("ProximityPrompt"), BossConfig.PortalPromptName .. " doit etre un ProximityPrompt.")
	prompt.ActionText = BossConfig.PortalPromptText
	prompt.ObjectText = BossConfig.PortalPromptObjectText
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = BossConfig.PortalActivationDistance
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.Enabled = true

	prompt.Triggered:Connect(function(player)
		local started, reason = BossService.TryStartBoss(player, portal, function()
			if prompt.Parent ~= nil then
				prompt.Enabled = true
			end
		end)

		DebugLog.Info("Portal", "Activation portail demandee", {
			Player = player.Name,
			Portal = portal,
			Started = started,
			Reason = reason,
		})

		if started then
			RunAnalyticsService.RecordPortalActivated(player)
			prompt.Enabled = false
		end
	end)
end

local function pivotInstance(instance, cframe)
	if instance:IsA("Model") or instance:IsA("BasePart") then
		instance:PivotTo(cframe)
	end
end

local function clonePortalRuntimeModel()
	if portalTemplate == nil then
		return nil
	end

	local portal = portalTemplate:Clone()

	if portal:IsA("Folder") then
		-- Certains assets de portail arrivent comme Folder. Un Model est requis
		-- pour disposer d'un pivot et garantir une pose correcte sur la surface.
		local model = Instance.new("Model")

		for _, child in ipairs(portal:GetChildren()) do
			child.Parent = model
		end

		portal:Destroy()
		portal = model
	end

	return portal
end

local function getLowestWorldY(part)
	local halfSize = part.Size * 0.5
	local lowestY = math.huge

	for _, xSign in ipairs({ -1, 1 }) do
		for _, ySign in ipairs({ -1, 1 }) do
			for _, zSign in ipairs({ -1, 1 }) do
				local corner = part.CFrame:PointToWorldSpace(Vector3.new(
					halfSize.X * xSign,
					halfSize.Y * ySign,
					halfSize.Z * zSign
				))
				lowestY = math.min(lowestY, corner.Y)
			end
		end
	end

	return lowestY
end

local function correctPortalGrounding(portal, surfacePosition)
	if not portal:IsA("Model") then
		return 0
	end

	local lowestY = nil

	for _, descendant in ipairs(portal:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local partLowestY = getLowestWorldY(descendant)
			lowestY = if lowestY == nil then partLowestY else math.min(lowestY, partLowestY)
		end
	end

	if lowestY == nil then
		return 0
	end

	local correction = (surfacePosition.Y + PortalConfig.SpawnSurfaceOffset) - lowestY

	if math.abs(correction) > 0.001 then
		portal:PivotTo(portal:GetPivot() + Vector3.new(0, correction, 0))
	end

	return correction
end

local function spawnPortalAtSurface(surfacePosition)
	if portalTemplate == nil then
		return nil
	end

	local portal = clonePortalRuntimeModel()

	if portal == nil then
		return nil
	end

	portal.Name = PortalConfig.PortalTemplateName
	portal.Parent = runtimeFolder
	preparePortalInstance(portal)

	local pivotPosition = WorldSpawnService.GetSurfacePivotPosition(
		portal,
		surfacePosition,
		PortalConfig.SpawnSurfaceOffset
	)

	pivotInstance(portal, WorldSpawnService.GetPivotCFrameAtPosition(portal, pivotPosition))
	local groundingCorrection = correctPortalGrounding(portal, surfacePosition)
	setupPortalPrompt(portal)
	spawnedPortalCount += 1

	DebugLog.Info("Portal", "Portail boss genere", {
		Portal = portal,
		SurfacePosition = surfacePosition,
		PivotPosition = pivotPosition,
		GroundingCorrection = groundingCorrection,
		SpawnedCount = spawnedPortalCount,
	})

	return portal
end

local function spawnInitialPortal(generationOptions)
	if portalTemplate == nil then
		DebugLog.Warn("Portal", "Generation portail boss impossible, template absent")
		return
	end

	if spawnedPortalCount >= PortalConfig.InitialSpawnCount then
		return
	end

	DebugLog.Info("Portal", "Generation portail boss demandee", {
		Requested = PortalConfig.InitialSpawnCount,
		MaxRadius = PortalConfig.SpawnWorldMaxRadius,
	})

	local function findPortalSurface(clearance)
		return WorldSpawnService.FindSurfacePositionInPlayableBounds({
			MinRadius = PortalConfig.SpawnWorldMinRadius,
			MaxRadius = PortalConfig.SpawnWorldMaxRadius,
			EdgeInset = PortalConfig.SpawnWorldEdgeInset,
			Attempts = PortalConfig.SpawnWorldAttemptsPerPortal,
			RaycastHeight = PortalConfig.SpawnRaycastHeight,
			RaycastDepth = PortalConfig.SpawnRaycastDepth,
			RejectGeneratedTerrain = PortalConfig.RejectGeneratedTerrain,
			RejectedSurfaceNameContains = PortalConfig.RejectedSurfaceNameContains,
			PositionFilter = function(position, surfaceInstance)
				return ProceduralMapService.IsAreaClear(RunMapService.GetActiveMap(), position, clearance, {
					AllowSupportingTerrain = surfaceInstance ~= nil,
				})
			end,
		})
	end

	while spawnedPortalCount < PortalConfig.InitialSpawnCount do
		local surfacePosition = findPortalSurface(PortalConfig.GeneratedTerrainClearance)

		if surfacePosition == nil then
			surfacePosition = findPortalSurface(PortalConfig.GeneratedTerrainFallbackClearance)

			if surfacePosition ~= nil then
				DebugLog.Warn("Portal", "Portail place avec marge terrain reduite", {
					Clearance = PortalConfig.GeneratedTerrainFallbackClearance,
				})
			end
		end

		if surfacePosition == nil then
			DebugLog.Warn("Portal", "Aucune zone sure trouvee pour le portail", {
				Attempts = PortalConfig.SpawnWorldAttemptsPerPortal * 2,
				MinRadius = PortalConfig.SpawnWorldMinRadius,
				MaxRadius = PortalConfig.SpawnWorldMaxRadius,
			})
			break
		end

		spawnPortalAtSurface(surfacePosition)
	end

	if generationOptions ~= nil and generationOptions.OnBatch ~= nil then
		generationOptions.OnBatch(spawnedPortalCount, PortalConfig.InitialSpawnCount)
	end

	DebugLog.Info("Portal", "Generation portail boss terminee", {
		Requested = PortalConfig.InitialSpawnCount,
		SpawnedCount = spawnedPortalCount,
	})
end

function PortalService.ClearRunContent()
	if runtimeFolder ~= nil then
		for _, child in ipairs(runtimeFolder:GetChildren()) do
			child:Destroy()
		end
	end

	spawnedPortalCount = 0
end

function PortalService.GenerateForRun(_, generationOptions)
	PortalService.ClearRunContent()
	spawnInitialPortal(generationOptions)
	return spawnedPortalCount
end

function PortalService.Start()
	if isStarted then
		DebugLog.Info("Portal", "Start ignore, service deja demarre")
		return
	end

	isStarted = true
	runtimeFolder = TemplateService.GetPortalsRuntimeFolder()
	portalTemplate = TemplateService.GetTemplate(
		PortalConfig.TemplateFolderName,
		PortalConfig.PortalTemplateName,
		createFallbackPortalTemplate
	)

	DebugLog.Info("Portal", "PortalService demarre", {
		RuntimeFolder = runtimeFolder,
		Template = portalTemplate,
		InitialSpawnCount = PortalConfig.InitialSpawnCount,
	})

end

return PortalService
