local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ChapterConfig = require(Shared:WaitForChild("ChapterConfig"))
local DebugLog = require(Shared:WaitForChild("DebugLog"))

local TemplateService = require(script.Parent:WaitForChild("TemplateService"))
local WorldSpawnService = require(script.Parent:WaitForChild("WorldSpawnService"))

local RunMapService = {}

local activeMap = nil
local activeRunId = nil
local activeArrival = nil
local isStarted = false

local function disableMapScripts(map)
	if not ChapterConfig.DisableMapScripts then
		return 0
	end

	local disabledCount = 0

	for _, descendant in ipairs(map:GetDescendants()) do
		if descendant:IsA("BaseScript") then
			descendant.Disabled = true
			disabledCount += 1
		end
	end

	return disabledCount
end

local function isArrivalCandidate(instance)
	return instance:IsA("BasePart") or instance:IsA("Model")
end

local function findArrival(map, preferredArrivalName)
	local arrivalName = preferredArrivalName or ChapterConfig.ArrivalPartName
	local arrival = map:FindFirstChild(arrivalName, true)

	if arrival ~= nil and isArrivalCandidate(arrival) then
		return arrival
	end

	local fallbackCandidates = {}

	for _, descendant in ipairs(map:GetDescendants()) do
		if string.sub(descendant.Name, 1, 12) == "TeleportPart" and isArrivalCandidate(descendant) then
			table.insert(fallbackCandidates, descendant)
		end
	end

	if #fallbackCandidates == 1 then
		DebugLog.Warn("RunMap", "Point d'arrivee deduit depuis le template", {
			Map = map,
			ExpectedName = arrivalName,
			FoundName = fallbackCandidates[1].Name,
		})
		return fallbackCandidates[1]
	end

	local spawnLocation = map:FindFirstChildWhichIsA("SpawnLocation", true)

	if spawnLocation ~= nil then
		return spawnLocation
	end

	return nil
end

local function clearRuntimeFolder()
	local runtimeFolder = TemplateService.GetMapRuntimeFolder()

	for _, child in ipairs(runtimeFolder:GetChildren()) do
		child:Destroy()
	end
end

local function getMapCenter(map)
	if map:IsA("Model") then
		local boundingCFrame = map:GetBoundingBox()
		return boundingCFrame.Position
	end

	if map:IsA("BasePart") then
		return map.Position
	end

	local minimum = nil
	local maximum = nil

	for _, descendant in ipairs(map:GetDescendants()) do
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

	return if minimum ~= nil and maximum ~= nil then (minimum + maximum) * 0.5 else Vector3.zero
end

function RunMapService.Generate(session)
	local chapter = ChapterConfig.GetChapter(session.ChapterId)

	if chapter == nil then
		return false, "UnknownChapter"
	end

	local template = TemplateService.GetTemplate(ChapterConfig.TemplateFolderName, chapter.MapTemplateName)

	if template == nil then
		DebugLog.Warn("RunMap", "Generation impossible, template de map absent", {
			ChapterId = chapter.Id,
			Template = chapter.MapTemplateName,
			ExpectedFolder = "ServerStorage/" .. ChapterConfig.TemplateFolderName,
		})
		return false, "MapTemplateMissing"
	end

	RunMapService.Destroy(activeRunId)
	clearRuntimeFolder()

	local runtimeFolder = TemplateService.GetMapRuntimeFolder()
	local map = template:Clone()
	map.Name = chapter.MapTemplateName
	map:SetAttribute("RunId", session.RunId)
	map:SetAttribute("RunSeed", session.Seed)
	map:SetAttribute("ChapterId", chapter.Id)
	map.Parent = runtimeFolder

	local disabledScriptCount = disableMapScripts(map)
	local arrival = findArrival(map, chapter.ArrivalPartName)

	if arrival == nil then
		map:Destroy()
		DebugLog.Warn("RunMap", "Map sans point d'arrivee", {
			ChapterId = chapter.Id,
			Map = chapter.MapTemplateName,
			ExpectedName = chapter.ArrivalPartName or ChapterConfig.ArrivalPartName,
		})
		return false, "ArrivalMissing"
	end

	activeMap = map
	activeRunId = session.RunId
	activeArrival = arrival
	local mapCenter = getMapCenter(map)
	WorldSpawnService.SetRunContext(map, session.Seed, mapCenter)

	DebugLog.Info("RunMap", "Map de run generee", {
		RunId = session.RunId,
		Seed = session.Seed,
		ChapterId = chapter.Id,
		Map = map,
		Arrival = arrival,
		MapCenter = mapCenter,
		DisabledScripts = disabledScriptCount,
	})

	return true, arrival
end

function RunMapService.Start()
	if isStarted then
		return
	end

	isStarted = true
	RunMapService.Destroy(activeRunId)
	clearRuntimeFolder()
	WorldSpawnService.ClearRunContext()
	DebugLog.Info("RunMap", "RunMapService demarre, runtime vide")
end

function RunMapService.GetActiveMap()
	return activeMap
end

function RunMapService.GetArrival(runId)
	if activeMap == nil or activeMap.Parent == nil or (runId ~= nil and runId ~= activeRunId) then
		return nil
	end

	if activeArrival ~= nil and activeArrival.Parent ~= nil then
		return activeArrival
	end

	return findArrival(activeMap)
end

function RunMapService.Destroy(runId)
	if activeMap == nil then
		return false
	end

	if runId ~= nil and activeRunId ~= nil and runId ~= activeRunId then
		return false
	end

	local map = activeMap
	local destroyedRunId = activeRunId
	activeMap = nil
	activeRunId = nil
	activeArrival = nil
	WorldSpawnService.ClearRunContext(map)

	if map.Parent ~= nil then
		map:Destroy()
	end

	DebugLog.Info("RunMap", "Map de run detruite", {
		RunId = destroyedRunId,
	})

	return true
end

return RunMapService
