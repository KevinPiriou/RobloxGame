local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DebugLog = require(Shared:WaitForChild("DebugLog"))

local WorldSpawnService = {}

local rng = Random.new()
local GOLDEN_ANGLE = math.pi * (3 - math.sqrt(5))

local DEFAULT_RUNTIME_FOLDER_NAMES = {
	"CombatRuntime",
	"PortalsRuntime",
	"ShrinesRuntime",
	"ChestsRuntime",
	"JarsRuntime",
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

local function isSurfaceAllowed(result, options)
	if result == nil then
		return false
	end

	local minSurfaceNormalY = options.MinSurfaceNormalY or 0.65

	if result.Normal.Y < minSurfaceNormalY then
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
	local center = options.Center or Vector3.new(0, 0, 0)
	local raycastHeight = options.RaycastHeight or 240
	local raycastDepth = options.RaycastDepth or 520
	local rayOrigin = Vector3.new(x, center.Y + raycastHeight, z)
	local rayDirection = Vector3.new(0, -raycastDepth, 0)
	local raycastParams = RaycastParams.new()

	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = getDefaultExcludeInstances(options.ExcludeInstances)

	local result = Workspace:Raycast(rayOrigin, rayDirection, raycastParams)

	if not isSurfaceAllowed(result, options) then
		return nil
	end

	return result.Position
end

function WorldSpawnService.FindDistributedSurfacePositions(options)
	local requestedCount = options.Count or 0
	local center = options.Center or Vector3.new(0, 0, 0)
	local minRadius = options.MinRadius or 0
	local maxRadius = math.max(minRadius, options.MaxRadius or 160)
	local minDistance = options.MinDistance or 12
	local attemptsPerPoint = options.AttemptsPerPoint or 24
	local jitterRadius = options.JitterRadius or 14
	local logCategory = options.LogCategory or "Templates"
	local logLabel = options.LogLabel or "objets"
	local positions = {}
	local occupiedPositions = {}

	for _, position in ipairs(options.OccupiedPositions or {}) do
		table.insert(occupiedPositions, position)
	end

	for index = 1, requestedCount do
		local acceptedPosition = nil
		local progress = (index - 0.5) / math.max(1, requestedCount)
		local baseRadius = minRadius + (math.sqrt(progress) * (maxRadius - minRadius))
		local baseAngle = index * GOLDEN_ANGLE

		for _ = 1, attemptsPerPoint do
			local jitterAngle = rng:NextNumber(0, math.pi * 2)
			local jitterDistance = rng:NextNumber(0, jitterRadius)
			local angle = baseAngle + rng:NextNumber(-0.22, 0.22)
			local sampleX = center.X + (math.cos(angle) * baseRadius) + (math.cos(jitterAngle) * jitterDistance)
			local sampleZ = center.Z + (math.sin(angle) * baseRadius) + (math.sin(jitterAngle) * jitterDistance)
			local surfacePosition = WorldSpawnService.FindSurfacePositionAtXZ(sampleX, sampleZ, options)

			if surfacePosition ~= nil
				and isFarEnough(surfacePosition, occupiedPositions, minDistance)
				and isFarEnough(surfacePosition, positions, minDistance)
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
