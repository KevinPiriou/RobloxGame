local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DebugLog = require(Shared:WaitForChild("DebugLog"))

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

function RunWorldService.Generate(session)
	if not RunWorldService.WaitUntilReady(10) then
		return false, "GeneratorsNotReady"
	end

	local counts = {
		Portals = PortalService.GenerateForRun(session),
		Shrines = ShrineService.GenerateForRun(session),
		Chests = ChestService.GenerateForRun(session),
		Totems = TotemService.GenerateForRun(session),
		Jars = JarService.GenerateForRun(session),
	}

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
