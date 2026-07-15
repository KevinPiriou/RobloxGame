local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DebugLog = require(Shared:WaitForChild("DebugLog"))
local RunLoadingConfig = require(Shared:WaitForChild("RunLoadingConfig"))

local ChestService = require(script.Parent:WaitForChild("ChestService"))
local JarService = require(script.Parent:WaitForChild("JarService"))
local PortalService = require(script.Parent:WaitForChild("PortalService"))
local ShrineService = require(script.Parent:WaitForChild("ShrineService"))
local TotemService = require(script.Parent:WaitForChild("TotemService"))

local RunWorldService = {}

local isReady = false

function RunWorldService.Start()
	RunWorldService.Clear()
	isReady = true
	DebugLog.Info("RunWorld", "Generateurs de contenu runtime prets")
end

function RunWorldService.WaitUntilReady(timeoutSeconds)
	local deadline = os.clock() + (timeoutSeconds or 10)

	while not isReady and os.clock() < deadline do
		task.wait()
	end

	return isReady
end

local GENERATION_STEPS = {
	{
		CountKey = "Portals",
		Stage = "Portal",
		Label = "Portail boss",
		BatchSize = RunLoadingConfig.BatchSizes.Portal,
		Generate = function(session, options)
			return PortalService.GenerateForRun(session, options)
		end,
	},
	{
		CountKey = "Shrines",
		Stage = "Shrines",
		Label = "Autels",
		BatchSize = RunLoadingConfig.BatchSizes.Shrines,
		Generate = function(session, options)
			return ShrineService.GenerateForRun(session, options)
		end,
	},
	{
		CountKey = "Chests",
		Stage = "Chests",
		Label = "Coffres",
		BatchSize = RunLoadingConfig.BatchSizes.Chests,
		Generate = function(session, options)
			return ChestService.GenerateForRun(session, options)
		end,
	},
	{
		CountKey = "Totems",
		Stage = "Totems",
		Label = "Totems",
		BatchSize = RunLoadingConfig.BatchSizes.Totems,
		Generate = function(session, options)
			return TotemService.GenerateForRun(session, options)
		end,
	},
	{
		CountKey = "Jars",
		Stage = "Jars",
		Label = "Jarres",
		BatchSize = RunLoadingConfig.BatchSizes.Jars,
		Generate = function(session, options)
			return JarService.GenerateForRun(session, options)
		end,
	},
}

function RunWorldService.Generate(session, onProgress)
	if not RunWorldService.WaitUntilReady(10) then
		return false, "GeneratorsNotReady"
	end

	local counts = {}

	for _, step in ipairs(GENERATION_STEPS) do
		if onProgress ~= nil then
			onProgress(step.Stage, step.Label)
		end

		counts[step.CountKey] = step.Generate(session, {
			BatchSize = step.BatchSize,
			OnBatch = function(placed, requested, typeId)
				if onProgress == nil then
					return
				end

				local detailLabel = step.Label

				if typeId ~= nil then
					detailLabel ..= " " .. tostring(typeId)
				end

				onProgress(step.Stage, ("%s : %d / %d"):format(detailLabel, placed, requested))
			end,
		})

		-- Laisse au serveur et au client le temps de respirer entre deux familles lourdes.
		task.wait()
	end

	if counts.Portals < 1 then
		RunWorldService.Clear()
		DebugLog.Warn("RunWorld", "Generation refusee, portail boss absent", {
			RunId = session.RunId,
			ChapterId = session.ChapterId,
		})
		return false, "BossPortalMissing"
	end

	DebugLog.Info("RunWorld", "Contenu de run genere", {
		RunId = session.RunId,
		Seed = session.Seed,
		ChapterId = session.ChapterId,
		Portals = counts.Portals,
		Shrines = counts.Shrines,
		Chests = counts.Chests,
		Totems = counts.Totems,
		Jars = counts.Jars,
	})

	return true, counts
end

function RunWorldService.Clear()
	PortalService.ClearRunContent()
	ShrineService.ClearRunContent()
	ChestService.ClearRunContent()
	TotemService.ClearRunContent()
	JarService.ClearRunContent()
end

return RunWorldService
