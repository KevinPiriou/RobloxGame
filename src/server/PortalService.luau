local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DebugLog = require(Shared:WaitForChild("DebugLog"))
local PortalConfig = require(Shared:WaitForChild("PortalConfig"))

local TemplateService = require(script.Parent:WaitForChild("TemplateService"))
local WorldSpawnService = require(script.Parent:WaitForChild("WorldSpawnService"))

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
		end
	end

	if portal:IsA("BasePart") then
		portal.Anchored = true
	end

	portal:SetAttribute("PortalBossRuntime", true)
end

local function pivotInstance(instance, cframe)
	if instance:IsA("Model") or instance:IsA("BasePart") then
		instance:PivotTo(cframe)
	end
end

local function spawnPortalAtSurface(surfacePosition)
	if portalTemplate == nil then
		return nil
	end

	local portal = portalTemplate:Clone()
	portal.Name = PortalConfig.PortalTemplateName
	portal.Parent = runtimeFolder
	preparePortalInstance(portal)

	local pivotPosition = WorldSpawnService.GetSurfacePivotPosition(
		portal,
		surfacePosition,
		PortalConfig.SpawnSurfaceOffset
	)

	pivotInstance(portal, WorldSpawnService.GetPivotCFrameAtPosition(portal, pivotPosition))
	spawnedPortalCount += 1

	DebugLog.Info("Portal", "Portail boss genere", {
		Portal = portal,
		SurfacePosition = surfacePosition,
		PivotPosition = pivotPosition,
		SpawnedCount = spawnedPortalCount,
	})

	return portal
end

local function spawnInitialPortal()
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

	local surfacePositions = WorldSpawnService.FindDistributedSurfacePositions({
		Count = PortalConfig.InitialSpawnCount - spawnedPortalCount,
		Center = PortalConfig.SpawnWorldCenter,
		MinRadius = PortalConfig.SpawnWorldMinRadius,
		MaxRadius = PortalConfig.SpawnWorldMaxRadius,
		MinDistance = PortalConfig.SpawnWorldMinObjectDistance,
		AttemptsPerPoint = PortalConfig.SpawnWorldAttemptsPerPortal,
		JitterRadius = PortalConfig.SpawnWorldJitterRadius,
		RaycastHeight = PortalConfig.SpawnRaycastHeight,
		RaycastDepth = PortalConfig.SpawnRaycastDepth,
		RejectedSurfaceNameContains = PortalConfig.RejectedSurfaceNameContains,
		LogCategory = "Portal",
		LogLabel = "portail boss",
	})

	for _, surfacePosition in ipairs(surfacePositions) do
		if spawnedPortalCount >= PortalConfig.InitialSpawnCount then
			break
		end

		spawnPortalAtSurface(surfacePosition)
	end

	DebugLog.Info("Portal", "Generation portail boss terminee", {
		Requested = PortalConfig.InitialSpawnCount,
		SpawnedCount = spawnedPortalCount,
	})
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

	spawnInitialPortal()
end

return PortalService
