local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ProceduralMapConfig = require(Shared:WaitForChild("ProceduralMapConfig"))
local RunGenerationConfig = require(Shared:WaitForChild("RunGenerationConfig"))

local WorldSpawnService = require(script.Parent:WaitForChild("WorldSpawnService"))

local RunSeedValidationService = {}

local BOUNDED_TERRAIN_KINDS = {
	Top = true,
	Bottom = true,
	Ramp = true,
	LinkTop = true,
	LinkBottom = true,
}
local MAX_REPORTED_ERRORS = 16

local function isFiniteNumber(value)
	return value == value and value > -math.huge and value < math.huge
end

local function isFiniteVector3(value)
	return isFiniteNumber(value.X) and isFiniteNumber(value.Y) and isFiniteNumber(value.Z)
end

local function getHorizontalExtents(part)
	local halfSize = part.Size * 0.5
	local cframe = part.CFrame
	local extentX = math.abs(cframe.RightVector.X) * halfSize.X
		+ math.abs(cframe.UpVector.X) * halfSize.Y
		+ math.abs(cframe.LookVector.X) * halfSize.Z
	local extentZ = math.abs(cframe.RightVector.Z) * halfSize.X
		+ math.abs(cframe.UpVector.Z) * halfSize.Y
		+ math.abs(cframe.LookVector.Z) * halfSize.Z

	return extentX, extentZ
end

local function isInsideBounds(part, bounds, tolerance)
	local extentX, extentZ = getHorizontalExtents(part)
	local position = part.Position

	return position.X - extentX >= bounds.MinX - tolerance
		and position.X + extentX <= bounds.MaxX + tolerance
		and position.Z - extentZ >= bounds.MinZ - tolerance
		and position.Z + extentZ <= bounds.MaxZ + tolerance
end

local function appendError(errors, code, detail)
	if #errors >= MAX_REPORTED_ERRORS then
		return
	end

	table.insert(errors, {
		Code = code,
		Detail = detail,
	})
end

function RunSeedValidationService.GetCandidateSeed(initialSeed, attemptNumber)
	local maximumSeed = RunGenerationConfig.MaximumSeed
	local normalizedSeed = math.clamp(math.floor(tonumber(initialSeed) or 1), 1, maximumSeed)
	local retryIndex = math.max(0, math.floor(tonumber(attemptNumber) or 1) - 1)

	return ((normalizedSeed - 1 + (retryIndex * RunGenerationConfig.RetrySeedStride)) % maximumSeed) + 1
end

function RunSeedValidationService.IsRetryableReason(reason)
	return RunGenerationConfig.RetryableReasons[tostring(reason)] == true
end

function RunSeedValidationService.ValidateTerrain(map, generationReport)
	if not RunGenerationConfig.SeedGuardEnabled or not ProceduralMapConfig.Enabled then
		return true, "Ok", {}
	end

	local errors = {}
	local terrainFolder = map and map:FindFirstChild(ProceduralMapConfig.TerrainFolderName)
	local bounds = WorldSpawnService.GetActivePlayableBounds()
	local countsByKind = {}
	local generatedPartCount = 0

	if terrainFolder == nil then
		appendError(errors, "TerrainFolderMissing")
	else
		for _, descendant in ipairs(terrainFolder:GetDescendants()) do
			if not descendant:IsA("BasePart") then
				continue
			end

			generatedPartCount += 1
			local terrainKind = tostring(descendant:GetAttribute(ProceduralMapConfig.TerrainKindAttributeName) or "Unknown")
			countsByKind[terrainKind] = (countsByKind[terrainKind] or 0) + 1

			if not isFiniteVector3(descendant.Position) or not isFiniteVector3(descendant.Size) then
				appendError(errors, "TerrainGeometryNonFinite", descendant:GetFullName())
			elseif descendant.Size.X <= 0 or descendant.Size.Y <= 0 or descendant.Size.Z <= 0 then
				appendError(errors, "TerrainGeometryEmpty", descendant:GetFullName())
			end

			if not descendant.Anchored
				or not descendant.CanCollide
				or descendant.CanTouch
				or not descendant.CanQuery
			then
				appendError(errors, "TerrainPhysicsUnexpected", descendant:GetFullName())
			end

			if bounds ~= nil
				and BOUNDED_TERRAIN_KINDS[terrainKind]
				and not isInsideBounds(descendant, bounds, RunGenerationConfig.HorizontalBoundsTolerance)
			then
				appendError(errors, "TerrainOutsidePlayableBounds", descendant:GetFullName())
			end
		end
	end

	if typeof(generationReport) ~= "table" then
		appendError(errors, "TerrainReportMissing")
	else
		local layouts = math.max(0, math.floor(tonumber(generationReport.Layouts) or 0))
		local platforms = math.max(0, math.floor(tonumber(generationReport.Platforms) or 0))
		local plannedPlatforms = math.max(0, math.floor(tonumber(generationReport.PlannedPlatforms) or platforms))
		local plannedRamps = math.max(0, math.floor(tonumber(generationReport.PlannedRamps) or 0))

		if layouts < ProceduralMapConfig.MinimumLayoutCount then
			appendError(errors, "LayoutCountBelowMinimum", layouts)
		end

		if platforms <= 0 or platforms ~= plannedPlatforms or (countsByKind.Top or 0) ~= platforms then
			appendError(errors, "PlatformPlanIncomplete", {
				Planned = plannedPlatforms,
				Reported = platforms,
				Actual = countsByKind.Top or 0,
			})
		end

		if (countsByKind.Ramp or 0) ~= plannedRamps then
			appendError(errors, "RampPlanIncomplete", {
				Planned = plannedRamps,
				Actual = countsByKind.Ramp or 0,
			})
		end
	end

	local validation = {
		Errors = errors,
		GeneratedParts = generatedPartCount,
		CountsByKind = countsByKind,
	}

	if #errors > 0 then
		return false, "SeedTerrainInvalid", validation
	end

	return true, "Ok", validation
end

function RunSeedValidationService.ValidateWorld(counts)
	if not RunGenerationConfig.SeedGuardEnabled then
		return true, "Ok", {}
	end

	local missing = {}

	for countKey, minimum in pairs(RunGenerationConfig.MinimumWorldCounts) do
		local actual = math.max(0, math.floor(tonumber(counts and counts[countKey]) or 0))

		if actual < minimum then
			table.insert(missing, {
				Type = countKey,
				Minimum = minimum,
				Actual = actual,
			})
		end
	end

	local validation = {
		Missing = missing,
		Counts = counts,
	}

	if #missing > 0 then
		return false, "SeedWorldInvalid", validation
	end

	return true, "Ok", validation
end

return RunSeedValidationService
