local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DebugLog = require(Shared:WaitForChild("DebugLog"))
local PerformanceTelemetryService = require(script.Parent:WaitForChild("PerformanceTelemetryService"))

local WorldSpawnService = {}

local rng = Random.new()
local activeSurfaceRoot = nil
local activeSurfaceCenter = nil
local activeSurfaceBounds = nil
local GOLDEN_ANGLE = math.pi * (3 - math.sqrt(5))

local DEFAULT_RUNTIME_FOLDER_NAMES = {
	"CombatRuntime",
	"PortalsRuntime",
	"ShrinesRuntime",
	"ChestsRuntime",
	"JarsRuntime",
	"TotemsRuntime",
}

local function appendIfPresent(list, instance)
	if instance ~= nil then
		table.insert(list, instance)
	end
end

local function getDefaultExcludeInstances(extraExcludeInstances)
	local excludeInstances = {}

	for _, player in ipairs(Players:GetPlayers()) do
		appendIfPresent(excludeInstances, player.Character)
	end

	for _, folderName in ipairs(DEFAULT_RUNTIME_FOLDER_NAMES) do
		appendIfPresent(excludeInstances, Workspace:FindFirstChild(folderName))
	end

	for _, instance in ipairs(extraExcludeInstances or {}) do
		appendIfPresent(excludeInstances, instance)
	end

	return excludeInstances
end

-- Le tag est purement observatoire : il ne modifie jamais le rayon ni ses filtres.
local function recordRaycastTelemetry(options, duration)
	if not PerformanceTelemetryService.IsCapturing() then
		return
	end

	PerformanceTelemetryService.Record("WorldSpawn.RaycastSeconds", duration)
	PerformanceTelemetryService.Increment("WorldSpawn.RaycastCount")

	local telemetryTag = if options ~= nil then options.TelemetryTag else nil

	if typeof(telemetryTag) == "string" and telemetryTag ~= "" then
		PerformanceTelemetryService.Record(telemetryTag .. ".RaycastSeconds", duration)
		PerformanceTelemetryService.Increment(telemetryTag .. ".RaycastCount")
	end
end

local function isNameRejected(instance, rejectedNameContains)
	local current = instance

	while current ~= nil and current ~= Workspace do
		for _, nameFragment in ipairs(rejectedNameContains or {}) do
			if string.find(current.Name, nameFragment, 1, true) ~= nil then
				return true
			end
		end

		current = current.Parent
	end

	return false
end

local function getInheritedAttribute(instance, attributeName)
	local current = instance

	while current ~= nil and current ~= Workspace do
		local value = current:GetAttribute(attributeName)

		if value ~= nil then
			return value
		end

		current = current.Parent
	end

	return nil
end

local function hasIgnoredSurfaceAttribute(instance)
	return getInheritedAttribute(instance, "MegaRobloxIgnoreAsSpawnSurface") == true
end

local function isSurfaceAllowed(result, options)
	if result == nil then
		return false
	end

	local minSurfaceNormalY = options.MinSurfaceNormalY or 0.65

	if result.Normal.Y < minSurfaceNormalY then
		return false
	end

	if hasIgnoredSurfaceAttribute(result.Instance) then
		return false
	end

	local isGeneratedTerrain = getInheritedAttribute(result.Instance, "MegaRobloxGeneratedTerrain") == true
	local terrainKind = getInheritedAttribute(result.Instance, "MegaRobloxTerrainKind")

	if options.RejectGeneratedTerrain == true and isGeneratedTerrain then
		return false
	end

	-- Les volumes de terre ne sont jamais des sols de spawn. Les rampes restent
	-- praticables pour les monstres en mouvement, mais pas pour les objets fixes.
	if terrainKind == "Bottom" or terrainKind == "LinkBottom" or terrainKind == "BaseBottom" then
		return false
	end

	if terrainKind == "Ramp" and options.AllowGeneratedRampSurface ~= true then
		return false
	end

	if isNameRejected(result.Instance, options.RejectedSurfaceNameContains) then
		return false
	end

	if result.Instance:IsA("BasePart") and options.RequireCanCollide ~= false and not result.Instance.CanCollide then
		return false
	end

	return true
end

local function getHorizontalDistance(a, b)
	return (Vector2.new(a.X, a.Z) - Vector2.new(b.X, b.Z)).Magnitude
end

local function getBoundsForInstance(instance)
	if instance == nil then
		return nil
	end

	if instance:IsA("BasePart") then
		local halfSize = instance.Size * 0.5

		return {
			MinX = instance.Position.X - halfSize.X,
			MaxX = instance.Position.X + halfSize.X,
			MinZ = instance.Position.Z - halfSize.Z,
			MaxZ = instance.Position.Z + halfSize.Z,
		}
	end

	if instance:IsA("Model") then
		-- Une map contient souvent des murs ou limites plus grands que sa base
		-- jouable. La plus grande surface horizontale est donc la reference utile
		-- pour tous les placements runtime.
		local largestSurfacePart = nil
		local largestSurfaceArea = 0

		for _, descendant in ipairs(instance:GetDescendants()) do
			if descendant:IsA("BasePart") and descendant.CFrame.UpVector.Y >= 0.98 then
				local horizontalArea = descendant.Size.X * descendant.Size.Z

				if horizontalArea > largestSurfaceArea then
					largestSurfaceArea = horizontalArea
					largestSurfacePart = descendant
				end
			end
		end

		if largestSurfacePart ~= nil then
			local halfSize = largestSurfacePart.Size * 0.5

			return {
				MinX = largestSurfacePart.Position.X - halfSize.X,
				MaxX = largestSurfacePart.Position.X + halfSize.X,
				MinZ = largestSurfacePart.Position.Z - halfSize.Z,
				MaxZ = largestSurfacePart.Position.Z + halfSize.Z,
			}
		end

		local boundingCFrame, size = instance:GetBoundingBox()
		local halfSize = size * 0.5

		return {
			MinX = boundingCFrame.Position.X - halfSize.X,
			MaxX = boundingCFrame.Position.X + halfSize.X,
			MinZ = boundingCFrame.Position.Z - halfSize.Z,
			MaxZ = boundingCFrame.Position.Z + halfSize.Z,
		}
	end

	local minimum = nil
	local maximum = nil

	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local halfSize = descendant.Size * 0.5
			local partMinimum = descendant.Position - halfSize
			local partMaximum = descendant.Position + halfSize
			minimum = if minimum == nil then partMinimum else Vector3.new(
				math.min(minimum.X, partMinimum.X),
				math.min(minimum.Y, partMinimum.Y),
				math.min(minimum.Z, partMinimum.Z)
			)
			maximum = if maximum == nil then partMaximum else Vector3.new(
				math.max(maximum.X, partMaximum.X),
				math.max(maximum.Y, partMaximum.Y),
				math.max(maximum.Z, partMaximum.Z)
			)
		end
	end

	if minimum == nil or maximum == nil then
		return nil
	end

	return {
		MinX = minimum.X,
		MaxX = maximum.X,
		MinZ = minimum.Z,
		MaxZ = maximum.Z,
	}
end

local function isFarEnough(position, positions, minDistance)
	for _, existingPosition in ipairs(positions) do
		if getHorizontalDistance(position, existingPosition) < minDistance then
			return false
		end
	end

	return true
end

local function findFirstBasePart(instance)
	if instance == nil then
		return nil
	end

	if instance:IsA("BasePart") then
		return instance
	end

	if not instance:IsA("Model") then
		return nil
	end

	if instance.PrimaryPart ~= nil then
		return instance.PrimaryPart
	end

	return instance:FindFirstChildWhichIsA("BasePart", true)
end

function WorldSpawnService.GetInstancePosition(instance)
	if instance == nil then
		return nil
	end

	if instance:IsA("BasePart") then
		return instance.Position
	end

	if instance:IsA("Model") then
		local root = findFirstBasePart(instance)

		if root == nil then
			return nil
		end

		local cframe = instance:GetBoundingBox()

		return cframe.Position
	end

	local root = findFirstBasePart(instance)

	if root == nil then
		return nil
	end

	return root.Position
end

function WorldSpawnService.GetPositionsFromFolder(folder)
	local positions = {}

	if folder == nil then
		return positions
	end

	for _, child in ipairs(folder:GetChildren()) do
		local position = WorldSpawnService.GetInstancePosition(child)

		if position ~= nil then
			table.insert(positions, position)
		end
	end

	return positions
end

function WorldSpawnService.FindSurfacePositionAtXZ(x, z, options)
	-- Les appels locaux, notamment autour du joueur, doivent dicter la hauteur du rayon.
	-- Le centre global de la map peut etre remonte par ses murs et ne touche alors plus le sol.
	local center = options.Center or activeSurfaceCenter or Vector3.new(0, 0, 0)
	local raycastHeight = options.RaycastHeight or 240
	local raycastDepth = options.RaycastDepth or 520
	local rayOrigin = Vector3.new(x, center.Y + raycastHeight, z)
	local rayDirection = Vector3.new(0, -raycastDepth, 0)
	local raycastParams = RaycastParams.new()

	local includeInstances = options.IncludeInstances

	if includeInstances == nil and activeSurfaceRoot ~= nil and activeSurfaceRoot.Parent ~= nil then
		-- Une map peut etre un modele clone alors que son sol est le Terrain global Roblox.
		-- Les deux restent des surfaces autorisees pendant une run, sans inclure les runtimes.
		includeInstances = { activeSurfaceRoot, Workspace.Terrain }
	end

	if includeInstances ~= nil and #includeInstances > 0 then
		raycastParams.FilterType = Enum.RaycastFilterType.Include
		raycastParams.FilterDescendantsInstances = includeInstances
	else
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		raycastParams.FilterDescendantsInstances = getDefaultExcludeInstances(options.ExcludeInstances)
	end

	local raycastStartedAt = os.clock()
	local result = Workspace:Raycast(rayOrigin, rayDirection, raycastParams)
	recordRaycastTelemetry(options, os.clock() - raycastStartedAt)

	if isSurfaceAllowed(result, options) then
		return result.Position, result.Instance
	end

	-- Certaines maps gardent volontairement leur sol dans Workspace. Ce repli est
	-- explicite afin de ne pas modifier le placement des autres interactables.
	if options.AllowWorkspaceSurfaceFallback == true and includeInstances ~= nil then
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		raycastParams.FilterDescendantsInstances = getDefaultExcludeInstances(options.ExcludeInstances)
		local fallbackStartedAt = os.clock()
		local fallbackResult = Workspace:Raycast(rayOrigin, rayDirection, raycastParams)
		recordRaycastTelemetry(options, os.clock() - fallbackStartedAt)

		if isSurfaceAllowed(fallbackResult, options) then
			return fallbackResult.Position, fallbackResult.Instance
		end
	end

	return nil
end

function WorldSpawnService.IsInsideActivePlayableBounds(position, edgeInset)
	if activeSurfaceBounds == nil then
		return true
	end

	local inset = math.max(0, edgeInset or 0)
	local minimumX = activeSurfaceBounds.MinX + inset
	local maximumX = activeSurfaceBounds.MaxX - inset
	local minimumZ = activeSurfaceBounds.MinZ + inset
	local maximumZ = activeSurfaceBounds.MaxZ - inset

	if minimumX > maximumX or minimumZ > maximumZ then
		return true
	end

	return position.X >= minimumX
		and position.X <= maximumX
		and position.Z >= minimumZ
		and position.Z <= maximumZ
end

function WorldSpawnService.GetActivePlayableBounds()
	return activeSurfaceBounds
end

function WorldSpawnService.FindSurfacePositionInPlayableBounds(options)
	if activeSurfaceBounds == nil then
		return nil
	end

	local edgeInset = math.max(0, options.EdgeInset or 0)
	local minimumX = activeSurfaceBounds.MinX + edgeInset
	local maximumX = activeSurfaceBounds.MaxX - edgeInset
	local minimumZ = activeSurfaceBounds.MinZ + edgeInset
	local maximumZ = activeSurfaceBounds.MaxZ - edgeInset

	if minimumX >= maximumX or minimumZ >= maximumZ then
		return nil
	end

	local center = options.Center or activeSurfaceCenter or Vector3.new(0, 0, 0)
	local minRadius = math.max(0, options.MinRadius or 0)
	local maxRadius = math.max(minRadius, options.MaxRadius or math.huge)
	local attempts = math.max(1, options.Attempts or 48)

	for _ = 1, attempts do
		local sampleX = rng:NextNumber(minimumX, maximumX)
		local sampleZ = rng:NextNumber(minimumZ, maximumZ)
		local horizontalDistance = getHorizontalDistance(Vector3.new(sampleX, 0, sampleZ), center)

		if horizontalDistance < minRadius or horizontalDistance > maxRadius then
			continue
		end

		local surfacePosition, surfaceInstance = WorldSpawnService.FindSurfacePositionAtXZ(sampleX, sampleZ, options)

		if surfacePosition ~= nil and (options.PositionFilter == nil or options.PositionFilter(surfacePosition, surfaceInstance) == true) then
			return surfacePosition, surfaceInstance
		end
	end

	return nil
end

function WorldSpawnService.SetRunContext(surfaceRoot, seed, surfaceCenter)
	activeSurfaceRoot = surfaceRoot
	activeSurfaceCenter = surfaceCenter
	activeSurfaceBounds = getBoundsForInstance(surfaceRoot)
	rng = Random.new(math.floor(tonumber(seed) or 0))

	DebugLog.Info("WorldSpawn", "Contexte de generation active", {
		SurfaceRoot = surfaceRoot,
		Center = surfaceCenter,
		Bounds = activeSurfaceBounds,
		Seed = seed,
	})
end

function WorldSpawnService.ClearRunContext(surfaceRoot)
	if surfaceRoot == nil or activeSurfaceRoot == surfaceRoot then
		activeSurfaceRoot = nil
		activeSurfaceCenter = nil
		activeSurfaceBounds = nil
		rng = Random.new()
	end
end

function WorldSpawnService.FindDistributedSurfacePositions(options)
	local requestedCount = options.Count or 0
	local center = activeSurfaceCenter or options.Center or Vector3.new(0, 0, 0)
	local minRadius = options.MinRadius or 0
	local maxRadius = math.max(minRadius, options.MaxRadius or 160)
	local minDistance = options.MinDistance or 12
	local attemptsPerPoint = options.AttemptsPerPoint or 24
	local jitterRadius = options.JitterRadius or 14
	local logCategory = options.LogCategory or "Templates"
	local logLabel = options.LogLabel or "objets"
	local positions = {}
	local occupiedPositions = {}
	local usePlayableBounds = options.UsePlayableBounds == true and activeSurfaceBounds ~= nil
	local edgeInset = math.max(0, options.EdgeInset or 12)
	local minimumX = nil
	local maximumX = nil
	local minimumZ = nil
	local maximumZ = nil

	if usePlayableBounds then
		minimumX = activeSurfaceBounds.MinX + edgeInset
		maximumX = activeSurfaceBounds.MaxX - edgeInset
		minimumZ = activeSurfaceBounds.MinZ + edgeInset
		maximumZ = activeSurfaceBounds.MaxZ - edgeInset

		if minimumX >= maximumX or minimumZ >= maximumZ then
			DebugLog.Warn(logCategory, "Surface jouable trop etroite pour le placement", {
				Type = logLabel,
				EdgeInset = edgeInset,
			})
			return positions
		end
	end

	for _, position in ipairs(options.OccupiedPositions or {}) do
		table.insert(occupiedPositions, position)
	end

	for index = 1, requestedCount do
		local acceptedPosition = nil
		local progress = (index - 0.5) / math.max(1, requestedCount)
		local baseRadius = minRadius + (math.sqrt(progress) * (maxRadius - minRadius))
		local baseAngle = index * GOLDEN_ANGLE

		for _ = 1, attemptsPerPoint do
			local sampleX = nil
			local sampleZ = nil

			if usePlayableBounds then
				-- Les objets fixes couvrent la base rectangulaire, y compris ses coins.
				sampleX = rng:NextNumber(minimumX, maximumX)
				sampleZ = rng:NextNumber(minimumZ, maximumZ)
			else
				local jitterAngle = rng:NextNumber(0, math.pi * 2)
				local jitterDistance = rng:NextNumber(0, jitterRadius)
				local angle = baseAngle + rng:NextNumber(-0.22, 0.22)
				sampleX = center.X + (math.cos(angle) * baseRadius) + (math.cos(jitterAngle) * jitterDistance)
				sampleZ = center.Z + (math.sin(angle) * baseRadius) + (math.sin(jitterAngle) * jitterDistance)
			end

			if usePlayableBounds
				and getHorizontalDistance(Vector3.new(sampleX, 0, sampleZ), center) < minRadius
			then
				continue
			end
			local surfacePosition = WorldSpawnService.FindSurfacePositionAtXZ(sampleX, sampleZ, options)

			if surfacePosition ~= nil
				and isFarEnough(surfacePosition, occupiedPositions, minDistance)
				and isFarEnough(surfacePosition, positions, minDistance)
				and (options.PositionFilter == nil or options.PositionFilter(surfacePosition) == true)
			then
				acceptedPosition = surfacePosition
				break
			end
		end

		if acceptedPosition ~= nil then
			table.insert(positions, acceptedPosition)
		end
	end

	if #positions < requestedCount then
		DebugLog.Warn(logCategory, "Placement surface incomplet", {
			Type = logLabel,
			Requested = requestedCount,
			Placed = #positions,
			MinDistance = minDistance,
			MaxRadius = maxRadius,
			UsePlayableBounds = usePlayableBounds,
			EdgeInset = if usePlayableBounds then edgeInset else nil,
		})
	else
		DebugLog.Info(logCategory, "Placement surface pret", {
			Type = logLabel,
			Placed = #positions,
			MinDistance = minDistance,
			MaxRadius = maxRadius,
		})
	end

	return positions
end

function WorldSpawnService.FindGeneratedTerrainBarrier(origin, direction, distance, options)
	if activeSurfaceRoot == nil or activeSurfaceRoot.Parent == nil then
		return nil
	end

	local horizontalDirection = Vector3.new(direction.X, 0, direction.Z)

	if horizontalDirection.Magnitude <= 0.001 or distance <= 0 then
		return nil
	end

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Include
	raycastParams.FilterDescendantsInstances = { activeSurfaceRoot }

	local rayHeight = if options ~= nil and options.Height ~= nil then options.Height else 2
	local rayOrigin = origin + Vector3.new(0, rayHeight, 0)
	local raycastStartedAt = os.clock()
	local result = Workspace:Raycast(rayOrigin, horizontalDirection.Unit * distance, raycastParams)
	recordRaycastTelemetry(options, os.clock() - raycastStartedAt)

	if result == nil then
		return nil
	end

	local terrainKind = getInheritedAttribute(result.Instance, "MegaRobloxTerrainKind")

	if terrainKind == "Bottom" or terrainKind == "LinkBottom" or terrainKind == "BaseBottom" then
		return result
	end

	return nil
end

function WorldSpawnService.GetSurfacePivotPosition(instance, surfacePosition, surfaceOffset, shouldIgnorePart)
	surfaceOffset = surfaceOffset or 0

	if instance:IsA("BasePart") then
		return surfacePosition + Vector3.new(0, (instance.Size.Y * 0.5) + surfaceOffset, 0)
	end

	if not instance:IsA("Model") then
		return surfacePosition + Vector3.new(0, surfaceOffset, 0)
	end

	local pivot = instance:GetPivot()
	local bottomY = nil

	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("BasePart") and (shouldIgnorePart == nil or not shouldIgnorePart(descendant)) then
			local partBottomY = descendant.Position.Y - (descendant.Size.Y * 0.5)

			if bottomY == nil or partBottomY < bottomY then
				bottomY = partBottomY
			end
		end
	end

	if bottomY == nil then
		local boundingCFrame, size = instance:GetBoundingBox()

		bottomY = boundingCFrame.Position.Y - (size.Y * 0.5)
	end

	local pivotToBottomOffset = pivot.Position.Y - bottomY

	return Vector3.new(
		surfacePosition.X,
		surfacePosition.Y + pivotToBottomOffset + surfaceOffset,
		surfacePosition.Z
	)
end

function WorldSpawnService.GetPivotRotation(instance)
	if instance:IsA("Model") or instance:IsA("BasePart") then
		local pivot = instance:GetPivot()

		return pivot - pivot.Position
	end

	return CFrame.new()
end

function WorldSpawnService.GetPivotCFrameAtPosition(instance, pivotPosition, yawRadians)
	local yawCFrame = CFrame.Angles(0, yawRadians or 0, 0)

	return CFrame.new(pivotPosition) * yawCFrame * WorldSpawnService.GetPivotRotation(instance)
end

return WorldSpawnService
