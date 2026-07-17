local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Stats = game:GetService("Stats")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ChapterConfig = require(Shared:WaitForChild("ChapterConfig"))
local ChestConfig = require(Shared:WaitForChild("ChestConfig"))
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))
local DebugLog = require(Shared:WaitForChild("DebugLog"))
local JarConfig = require(Shared:WaitForChild("JarConfig"))
local LobbyConfig = require(Shared:WaitForChild("LobbyConfig"))
local PortalConfig = require(Shared:WaitForChild("PortalConfig"))
local ShrineConfig = require(Shared:WaitForChild("ShrineConfig"))
local TotemConfig = require(Shared:WaitForChild("TotemConfig"))

local TemplateService = require(script.Parent:WaitForChild("TemplateService"))

local PhysicsAuditService = {}

local REPORT_FOLDER_NAME = "PerformanceAuditReports"
local PHYSICS_REPORT_FOLDER_NAME = "PhysicsLatest"
local MAX_FINDING_SAMPLES = 12

local templateScopes = {
	{ Id = "CombatTemplates", FolderName = CombatConfig.TemplateFolderName },
	{ Id = "CollectibleTemplates", FolderName = "CollectibleTemplates" },
	{ Id = "ShrineTemplates", FolderName = ShrineConfig.TemplateFolderName },
	{ Id = "ChestTemplates", FolderName = ChestConfig.TemplateFolderName },
	{ Id = "JarTemplates", FolderName = JarConfig.TemplateFolderName },
	{ Id = "TotemTemplates", FolderName = TotemConfig.TemplateFolderName },
	{ Id = "PortalTemplates", FolderName = PortalConfig.TemplateFolderName },
	{ Id = "MapTemplates", FolderName = ChapterConfig.TemplateFolderName },
	{ Id = "LobbyTemplates", FolderName = LobbyConfig.TemplateFolderName },
}

local runtimeScopes = {
	{ Id = "CombatMonsters", GetFolder = TemplateService.GetCombatMonsterFolder },
	{ Id = "CombatProjectiles", GetFolder = TemplateService.GetCombatProjectileFolder },
	{ Id = "CombatLoot", GetFolder = TemplateService.GetCombatLootFolder },
	{ Id = "ShrinesRuntime", GetFolder = TemplateService.GetShrinesRuntimeFolder },
	{ Id = "ChestsRuntime", GetFolder = TemplateService.GetChestsRuntimeFolder },
	{ Id = "JarsRuntime", GetFolder = TemplateService.GetJarsRuntimeFolder },
	{ Id = "TotemsRuntime", GetFolder = TemplateService.GetTotemsRuntimeFolder },
	{ Id = "PortalsRuntime", GetFolder = TemplateService.GetPortalsRuntimeFolder },
	{ Id = "MapRuntime", GetFolder = TemplateService.GetMapRuntimeFolder },
}

local latestReport = nil

local function getOrCreateFolder(parent, name)
	local child = parent:FindFirstChild(name)

	if child == nil then
		child = Instance.new("Folder")
		child.Name = name
		child.Parent = parent
	end

	assert(child:IsA("Folder"), name .. " doit etre un Folder.")
	return child
end

local function getInstancePath(instance)
	local parts = {}
	local current = instance

	while current ~= nil and current ~= game do
		table.insert(parts, 1, current.Name)
		current = current.Parent
	end

	return table.concat(parts, "/")
end

local function readNumber(reader)
	local success, value = pcall(reader)

	if success and typeof(value) == "number" then
		return value
	end

	return nil
end

local function readMemoryTag(tagName)
	return readNumber(function()
		local tag = Enum.DeveloperMemoryTag[tagName]

		if tag == nil then
			error("Tag memoire indisponible")
		end

		return Stats:GetMemoryUsageMbForTag(tag)
	end)
end

local function getMemorySnapshot()
	return {
		TotalMb = readNumber(function()
			return Stats:GetTotalMemoryUsageMb()
		end),
		InstancesMb = readMemoryTag("Instances"),
		PhysicsPartsMb = readMemoryTag("PhysicsParts"),
		PhysicsCollisionMb = readMemoryTag("PhysicsCollision"),
	}
end

local function increment(counter, key)
	counter[key] = (counter[key] or 0) + 1
end

local function addFinding(report, category, path)
	increment(report.FindingCounts, category)

	local samples = report.FindingSamples[category]

	if samples == nil then
		samples = {}
		report.FindingSamples[category] = samples
	end

	if #samples < MAX_FINDING_SAMPLES then
		table.insert(samples, path)
	end
end

local function getAuditInstances(root)
	local instances = { root }

	for _, descendant in ipairs(root:GetDescendants()) do
		table.insert(instances, descendant)
	end

	return instances
end

local function readAssemblyRootPath(part)
	local success, assemblyRoot = pcall(function()
		return part.AssemblyRootPart
	end)

	if success and assemblyRoot ~= nil then
		return getInstancePath(assemblyRoot)
	end

	return getInstancePath(part)
end

local function auditRoot(scopeId, kind, root)
	local report = {
		Scope = scopeId,
		Kind = kind,
		Path = getInstancePath(root),
		RootClass = root.ClassName,
		ClassCounts = {},
		BaseParts = 0,
		MeshParts = 0,
		AnchoredParts = 0,
		UnanchoredParts = 0,
		CollidableParts = 0,
		TouchEnabledParts = 0,
		QueryEnabledParts = 0,
		MasslessParts = 0,
		InvisiblePhysicalParts = 0,
		Constraints = 0,
		JointInstances = 0,
		Assemblies = 0,
		NonAnchoredAssemblies = 0,
		CollisionFidelity = {},
		FindingCounts = {},
		FindingSamples = {},
	}
	local assemblyPaths = {}
	local nonAnchoredAssemblyPaths = {}

	for _, instance in ipairs(getAuditInstances(root)) do
		increment(report.ClassCounts, instance.ClassName)

		if instance:IsA("Constraint") then
			report.Constraints += 1
		elseif instance:IsA("JointInstance") then
			report.JointInstances += 1
		end

		if not instance:IsA("BasePart") then
			continue
		end

		report.BaseParts += 1

		if instance:IsA("MeshPart") then
			report.MeshParts += 1
			local collisionFidelity = tostring(instance.CollisionFidelity)
			increment(report.CollisionFidelity, collisionFidelity)

			if string.find(collisionFidelity, "Precise", 1, true) ~= nil then
				addFinding(report, "PreciseCollision", getInstancePath(instance))
			end
		end

		local partPath = getInstancePath(instance)
		local assemblyPath = readAssemblyRootPath(instance)
		assemblyPaths[assemblyPath] = true

		if instance.Anchored then
			report.AnchoredParts += 1
		else
			report.UnanchoredParts += 1
			nonAnchoredAssemblyPaths[assemblyPath] = true
			addFinding(report, "UnanchoredPart", partPath)
		end

		if instance.CanCollide then
			report.CollidableParts += 1
		end

		if instance.CanTouch then
			report.TouchEnabledParts += 1
		end

		if instance.CanQuery then
			report.QueryEnabledParts += 1
		end

		if instance.Massless then
			report.MasslessParts += 1
		end

		if instance.Transparency >= 0.95 and (instance.CanCollide or instance.CanTouch or instance.CanQuery) then
			report.InvisiblePhysicalParts += 1
			addFinding(report, "InvisiblePhysicalPart", partPath)
		end
	end

	for _ in pairs(assemblyPaths) do
		report.Assemblies += 1
	end

	for _ in pairs(nonAnchoredAssemblyPaths) do
		report.NonAnchoredAssemblies += 1
	end

	if report.Constraints > 0 then
		addFinding(report, "ConstraintPresent", report.Path)
	end

	if report.JointInstances > 0 then
		addFinding(report, "JointPresent", report.Path)
	end

	return report
end

local function createSummary()
	return {
		Records = 0,
		BaseParts = 0,
		MeshParts = 0,
		UnanchoredParts = 0,
		CollidableParts = 0,
		TouchEnabledParts = 0,
		QueryEnabledParts = 0,
		InvisiblePhysicalParts = 0,
		Constraints = 0,
		JointInstances = 0,
		Assemblies = 0,
		NonAnchoredAssemblies = 0,
		FindingCounts = {},
	}
end

local function accumulateSummary(summary, report)
	summary.Records += 1
	summary.BaseParts += report.BaseParts
	summary.MeshParts += report.MeshParts
	summary.UnanchoredParts += report.UnanchoredParts
	summary.CollidableParts += report.CollidableParts
	summary.TouchEnabledParts += report.TouchEnabledParts
	summary.QueryEnabledParts += report.QueryEnabledParts
	summary.InvisiblePhysicalParts += report.InvisiblePhysicalParts
	summary.Constraints += report.Constraints
	summary.JointInstances += report.JointInstances
	summary.Assemblies += report.Assemblies
	summary.NonAnchoredAssemblies += report.NonAnchoredAssemblies

	for category, count in pairs(report.FindingCounts) do
		summary.FindingCounts[category] = (summary.FindingCounts[category] or 0) + count
	end
end

local function auditTemplateScope(scope)
	local folder = TemplateService.GetServerTemplateFolder(scope.FolderName)
	local reports = {}

	for _, child in ipairs(folder:GetChildren()) do
		table.insert(reports, auditRoot(scope.Id, "Template", child))
	end

	return reports
end

local function auditRuntimeScope(scope)
	local folder = scope.GetFolder()
	local reports = {
		auditRoot(scope.Id, "Runtime", folder),
	}

	if scope.Id ~= "MapRuntime" then
		return reports
	end

	for _, map in ipairs(folder:GetChildren()) do
		local mapChildren = map:GetChildren()

		if #mapChildren == 0 then
			local record = auditRoot(scope.Id, "RuntimeBreakdown", map)
			record.IsBreakdown = true
			table.insert(reports, record)
			continue
		end

		for _, child in ipairs(mapChildren) do
			local record = auditRoot(scope.Id, "RuntimeBreakdown", child)
			record.IsBreakdown = true
			table.insert(reports, record)
		end
	end

	return reports
end

local function summarizeFindings(summary)
	local parts = {}

	for category, count in pairs(summary.FindingCounts) do
		table.insert(parts, ("%s=%d"):format(category, count))
	end

	table.sort(parts)
	return table.concat(parts, ", ")
end

local function formatCountMap(counts)
	local parts = {}

	for key, count in pairs(counts) do
		table.insert(parts, ("%s=%d"):format(key, count))
	end

	table.sort(parts)
	return if #parts > 0 then table.concat(parts, ", ") else "aucun"
end

local function formatMemoryValue(value)
	if typeof(value) ~= "number" then
		return "indisponible"
	end

	return ("%.2f MB"):format(value)
end

local function buildReadableReport(report)
	local lines = {
		("P1 - Inventaire physique %s"):format(report.Id),
		("Memoire avant | total=%s | instances=%s | physicsParts=%s | physicsCollision=%s"):format(
			formatMemoryValue(report.MemoryBeforeMb.TotalMb),
			formatMemoryValue(report.MemoryBeforeMb.InstancesMb),
			formatMemoryValue(report.MemoryBeforeMb.PhysicsPartsMb),
			formatMemoryValue(report.MemoryBeforeMb.PhysicsCollisionMb)
		),
		("Memoire apres | total=%s | instances=%s | physicsParts=%s | physicsCollision=%s"):format(
			formatMemoryValue(report.MemoryAfterMb.TotalMb),
			formatMemoryValue(report.MemoryAfterMb.InstancesMb),
			formatMemoryValue(report.MemoryAfterMb.PhysicsPartsMb),
			formatMemoryValue(report.MemoryAfterMb.PhysicsCollisionMb)
		),
		report.SummaryText,
		(
			"Templates | records=%d parts=%d mesh=%d unanchored=%d collide=%d touch=%d query=%d constraints=%d joints=%d"
		):format(
			report.TemplateSummary.Records,
			report.TemplateSummary.BaseParts,
			report.TemplateSummary.MeshParts,
			report.TemplateSummary.UnanchoredParts,
			report.TemplateSummary.CollidableParts,
			report.TemplateSummary.TouchEnabledParts,
			report.TemplateSummary.QueryEnabledParts,
			report.TemplateSummary.Constraints,
			report.TemplateSummary.JointInstances
		),
		(
			"Runtime | records=%d parts=%d mesh=%d unanchored=%d collide=%d touch=%d query=%d constraints=%d joints=%d"
		):format(
			report.RuntimeSummary.Records,
			report.RuntimeSummary.BaseParts,
			report.RuntimeSummary.MeshParts,
			report.RuntimeSummary.UnanchoredParts,
			report.RuntimeSummary.CollidableParts,
			report.RuntimeSummary.TouchEnabledParts,
			report.RuntimeSummary.QueryEnabledParts,
			report.RuntimeSummary.Constraints,
			report.RuntimeSummary.JointInstances
		),
		"",
		"RECORDS",
	}

	for _, record in ipairs(report.Records) do
		table.insert(lines, ("[%s | %s] %s"):format(record.Scope, record.Kind, record.Path))
		table.insert(lines, (
			"  parts=%d mesh=%d anchored=%d unanchored=%d collide=%d touch=%d query=%d massless=%d"
		):format(
			record.BaseParts,
			record.MeshParts,
			record.AnchoredParts,
			record.UnanchoredParts,
			record.CollidableParts,
			record.TouchEnabledParts,
			record.QueryEnabledParts,
			record.MasslessParts
		))
		table.insert(lines, (
			"  assemblies=%d nonAnchoredAssemblies=%d constraints=%d joints=%d invisiblePhysical=%d"
		):format(
			record.Assemblies,
			record.NonAnchoredAssemblies,
			record.Constraints,
			record.JointInstances,
			record.InvisiblePhysicalParts
		))
		table.insert(lines, "  collisionFidelity=" .. formatCountMap(record.CollisionFidelity))

		if next(record.FindingCounts) ~= nil then
			table.insert(lines, "  findings=" .. formatCountMap(record.FindingCounts))
		end
	end

	return table.concat(lines, "\n")
end

local function writeLatestReport(report)
	local root = getOrCreateFolder(ReplicatedStorage, REPORT_FOLDER_NAME)
	local previous = root:FindFirstChild(PHYSICS_REPORT_FOLDER_NAME)

	if previous ~= nil then
		previous:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = PHYSICS_REPORT_FOLDER_NAME
	folder.Parent = root
	folder:SetAttribute("AuditId", report.Id)
	folder:SetAttribute("GeneratedAtUnix", report.GeneratedAtUnix)

	local summary = Instance.new("StringValue")
	summary.Name = "Summary"
	summary.Value = report.SummaryText
	summary.Parent = folder

	local inventory = Instance.new("StringValue")
	inventory.Name = "InventoryJson"
	inventory.Value = HttpService:JSONEncode(report)
	inventory.Parent = folder

	local readableReport = Instance.new("StringValue")
	readableReport.Name = "ReadableReport"
	readableReport.Value = buildReadableReport(report)
	readableReport.Parent = folder
end

function PhysicsAuditService.RunAudit()
	local report = {
		Id = ("P1-Physics-%d"):format(math.floor(os.clock() * 1000)),
		GeneratedAtUnix = os.time(),
		MemoryBeforeMb = getMemorySnapshot(),
		Records = {},
		Summary = createSummary(),
		TemplateSummary = createSummary(),
		RuntimeSummary = createSummary(),
	}

	for _, scope in ipairs(templateScopes) do
		for _, record in ipairs(auditTemplateScope(scope)) do
			table.insert(report.Records, record)
			accumulateSummary(report.Summary, record)
			accumulateSummary(report.TemplateSummary, record)
		end
	end

	for _, scope in ipairs(runtimeScopes) do
		for _, record in ipairs(auditRuntimeScope(scope)) do
			table.insert(report.Records, record)

			-- Les sous-ensembles de MapRuntime servent a attribuer les couts.
			-- Le total Runtime les couvre deja et reste le seul compte dans le resume.
			if record.IsBreakdown ~= true then
				accumulateSummary(report.Summary, record)
				accumulateSummary(report.RuntimeSummary, record)
			end
		end
	end

	report.MemoryAfterMb = getMemorySnapshot()
	report.SummaryText = (
		"P1 audit %s | records=%d parts=%d mesh=%d unanchored=%d invisiblePhysical=%d constraints=%d joints=%d | templatesParts=%d runtimeParts=%d | %s"
	):format(
		report.Id,
		report.Summary.Records,
		report.Summary.BaseParts,
		report.Summary.MeshParts,
		report.Summary.UnanchoredParts,
		report.Summary.InvisiblePhysicalParts,
		report.Summary.Constraints,
		report.Summary.JointInstances,
		report.TemplateSummary.BaseParts,
		report.RuntimeSummary.BaseParts,
		summarizeFindings(report.Summary)
	)

	writeLatestReport(report)
	latestReport = report

	DebugLog.Info("Perf", "Inventaire physique P1 termine", {
		AuditId = report.Id,
		Records = report.Summary.Records,
		BaseParts = report.Summary.BaseParts,
		MeshParts = report.Summary.MeshParts,
		Unanchored = report.Summary.UnanchoredParts,
		InvisiblePhysical = report.Summary.InvisiblePhysicalParts,
		Constraints = report.Summary.Constraints,
		Joints = report.Summary.JointInstances,
	})

	return (
		"P1 inventaire termine : %d records. Rapport dans ReplicatedStorage/%s/%s"
	):format(report.Summary.Records, REPORT_FOLDER_NAME, PHYSICS_REPORT_FOLDER_NAME)
end

function PhysicsAuditService.GetLatestReport()
	return latestReport
end

return PhysicsAuditService
