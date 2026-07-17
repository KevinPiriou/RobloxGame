-- Echantillonnage client P0. Ce script ne modifie jamais le rendu ni le gameplay.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DebugLog = require(Shared:WaitForChild("DebugLog"))
local PerformanceBaselineConfig = require(Shared:WaitForChild("PerformanceBaselineConfig"))
local VfxConfig = require(Shared:WaitForChild("VfxConfig"))

local GraphicsController = require(script.Parent:WaitForChild("GraphicsController"))
local VfxQualityController = require(script.Parent:WaitForChild("VfxQualityController"))

local sampleRemote = ReplicatedStorage:WaitForChild(PerformanceBaselineConfig.ClientSampleRemoteName)
local statusRemote = ReplicatedStorage:WaitForChild(PerformanceBaselineConfig.StatusRemoteName)

if not sampleRemote:IsA("RemoteEvent") or not statusRemote:IsA("RemoteEvent") then
	error("Remotes P0 invalides")
end

local activeBenchmarkId = nil
local activePhase = "Idle"
local elapsedSinceSample = 0
local frameSamples = {}
local frameSpikeCount = 0
local memoryBeforeMb = nil
local memoryPeakMb = nil
local memoryAfterCleanupMb = nil
local memoryAfterIdleMb = nil
local viewportBefore = nil
local viewportChanged = false
local focusLostCount = 0

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

local function countMegaRobloxVfx()
	local root = Workspace:FindFirstChild(VfxConfig.RuntimeFolderName)

	if root == nil then
		return 0, 0, 0
	end

	local particles = 0
	local lights = 0
	local trails = 0

	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") then
			particles += 1
		elseif descendant:IsA("Trail") then
			trails += 1
		elseif descendant:IsA("PointLight") or descendant:IsA("SpotLight") or descendant:IsA("SurfaceLight") then
			lights += 1
		end
	end

	return particles, lights, trails
end

local function getPercentile(samples, percentage)
	if #samples == 0 then
		return nil
	end

	local sorted = table.clone(samples)
	table.sort(sorted)
	return sorted[math.clamp(math.ceil(#sorted * percentage), 1, #sorted)]
end

local function sendSummary()
	if activeBenchmarkId == nil then
		return
	end

	sampleRemote:FireServer({
		Kind = "Summary",
		BenchmarkId = activeBenchmarkId,
		Summary = {
			FrameP50Seconds = getPercentile(frameSamples, 0.5),
			FrameP95Seconds = getPercentile(frameSamples, 0.95),
			FrameP99Seconds = getPercentile(frameSamples, 0.99),
			FrameSpikeCount = frameSpikeCount,
			MemoryBeforeMb = memoryBeforeMb,
			MemoryPeakMb = memoryPeakMb,
			MemoryAfterCleanupMb = memoryAfterCleanupMb,
			MemoryAfterIdleMb = memoryAfterIdleMb,
			ViewportBefore = viewportBefore,
			ViewportAfter = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or nil,
			ViewportChanged = viewportChanged,
			FocusLostCount = focusLostCount,
			Graphics = GraphicsController.GetSettings(),
			Vfx = VfxQualityController.GetSettings(),
		},
	})
end

local function sendPeriodicSample()
	if activeBenchmarkId == nil or activePhase ~= "Measuring" then
		return
	end

	local particles, lights, trails = countMegaRobloxVfx()
	local totalMemory = readNumber(function()
		return Stats:GetTotalMemoryUsageMb()
	end)

	if totalMemory ~= nil then
		memoryPeakMb = math.max(memoryPeakMb or totalMemory, totalMemory)
	end

	sampleRemote:FireServer({
		Kind = "Sample",
		BenchmarkId = activeBenchmarkId,
		Metrics = {
			["Client.RenderCpuSeconds"] = readNumber(function()
				return Stats.RenderCPUFrameTime
			end) or -1,
			["Client.RenderGpuSeconds"] = readNumber(function()
				return Stats.RenderGPUFrameTime
			end) or -1,
			["Client.PhysicsSeconds"] = readNumber(function()
				return Stats.PhysicsStepTime
			end) or -1,
			["Client.DrawCalls"] = readNumber(function()
				return Stats.SceneDrawcallCount
			end) or -1,
			["Client.Triangles"] = readNumber(function()
				return Stats.SceneTriangleCount
			end) or -1,
			["Client.Instances"] = readNumber(function()
				return Stats.InstanceCount
			end) or -1,
			["Client.Memory.TotalMb"] = totalMemory or -1,
			["Client.Memory.InstancesMb"] = readMemoryTag("Instances") or -1,
			["Client.Memory.LuaHeapMb"] = readMemoryTag("LuaHeap") or -1,
			["Client.Memory.GraphicsTextureMb"] = readMemoryTag("GraphicsTexture") or -1,
			["Client.Memory.SoundsMb"] = readMemoryTag("Sounds") or -1,
			["Client.Memory.PhysicsPartsMb"] = readMemoryTag("PhysicsParts") or -1,
			["Client.Memory.PhysicsCollisionMb"] = readMemoryTag("PhysicsCollision") or -1,
			["Client.Vfx.ParticleEmitters"] = particles,
			["Client.Vfx.Lights"] = lights,
			["Client.Vfx.Trails"] = trails,
			["Client.FrameSpikes"] = frameSpikeCount,
		},
	})
end

statusRemote.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end

	local nextPhase = payload.Phase
	if payload.Active == true and typeof(payload.BenchmarkId) == "string" then
		if activeBenchmarkId ~= payload.BenchmarkId then
			activeBenchmarkId = payload.BenchmarkId
			frameSamples = {}
			frameSpikeCount = 0
			memoryBeforeMb = readNumber(function()
				return Stats:GetTotalMemoryUsageMb()
			end)
			memoryPeakMb = memoryBeforeMb
			memoryAfterCleanupMb = nil
			memoryAfterIdleMb = nil
			viewportBefore = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or nil
			viewportChanged = false
			focusLostCount = 0
			elapsedSinceSample = 0
		end
	end

	if typeof(payload.VfxBenchmarkLock) == "boolean" then
		VfxQualityController.SetBenchmarkLock(payload.VfxBenchmarkLock)
	end

	if nextPhase == "Cleanup" then
		memoryAfterCleanupMb = readNumber(function()
			return Stats:GetTotalMemoryUsageMb()
		end)
		sendSummary()
	elseif nextPhase == "IdleObservation" then
		memoryAfterIdleMb = readNumber(function()
			return Stats:GetTotalMemoryUsageMb()
		end)
		sendSummary()
	elseif nextPhase == "Completed" then
		activeBenchmarkId = nil
	end

	activePhase = if typeof(nextPhase) == "string" then nextPhase else activePhase
end)

UserInputService.WindowFocusReleased:Connect(function()
	if activeBenchmarkId ~= nil then
		focusLostCount += 1
	end
end)

RunService.RenderStepped:Connect(function(deltaTime)
	if activeBenchmarkId == nil then
		return
	end

	local currentCamera = Workspace.CurrentCamera
	if viewportBefore ~= nil and currentCamera ~= nil and currentCamera.ViewportSize ~= viewportBefore then
		viewportChanged = true
	end

	if activePhase == "Measuring" then
		if #frameSamples < PerformanceBaselineConfig.MaximumSamplesPerMetric then
			table.insert(frameSamples, deltaTime)
		end

		if deltaTime > (1 / 30) then
			frameSpikeCount += 1
		end

		elapsedSinceSample += deltaTime
		if elapsedSinceSample >= PerformanceBaselineConfig.SampleInterval then
			elapsedSinceSample = 0
			sendPeriodicSample()
		end
	end
end)

DebugLog.Info("Perf", "Collecteur client P0 initialise")
