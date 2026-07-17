-- Budget local des VFX. Il ajuste uniquement le rendu du joueur courant.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DebugLog = require(Shared:WaitForChild("DebugLog"))
local VfxConfig = require(Shared:WaitForChild("VfxConfig"))

local GraphicsController = require(script.Parent:WaitForChild("GraphicsController"))

local VfxQualityController = {}

local isStarted = false
local changedEvent = Instance.new("BindableEvent")
local manualQualityName = "Balanced"
local effectsIntensity = 1
local adaptivePenalty = 0
local benchmarkLockEnabled = false
local sampleElapsed = 0
local sampleFrameTime = 0
local sampleFrames = 0
local slowSamples = 0
local fastSamples = 0

local function getManualQualityIndex()
	return VfxConfig.GetQualityIndex(manualQualityName)
end

local function getEffectiveQualityName()
	local manualIndex = getManualQualityIndex()
	local effectiveIndex = math.max(1, manualIndex - adaptivePenalty)
	return VfxConfig.GetQualityName(effectiveIndex)
end

local function buildSettings()
	local qualityName = getEffectiveQualityName()

	return {
		ManualQuality = manualQualityName,
		Quality = qualityName,
		EffectsIntensity = effectsIntensity,
		AdaptivePenalty = adaptivePenalty,
		BenchmarkLockEnabled = benchmarkLockEnabled,
		Profile = VfxConfig.GetQualityProfile(qualityName),
	}
end

local function notifyChanged()
	changedEvent:Fire(buildSettings())
end

local function applyGraphicsSettings(settings)
	if typeof(settings) ~= "table" then
		return
	end

	manualQualityName = settings.Quality or manualQualityName
	effectsIntensity = math.clamp(tonumber(settings.EffectsIntensity) or effectsIntensity, 0, 1)
	adaptivePenalty = math.clamp(adaptivePenalty, 0, math.max(0, getManualQualityIndex() - 1))
	notifyChanged()
end

local function updateAdaptiveBudget(deltaTime)
	if benchmarkLockEnabled then
		sampleElapsed = 0
		sampleFrameTime = 0
		sampleFrames = 0
		slowSamples = 0
		fastSamples = 0
		return
	end

	if effectsIntensity <= 0 then
		sampleElapsed = 0
		sampleFrameTime = 0
		sampleFrames = 0
		slowSamples = 0
		fastSamples = 0
		return
	end

	sampleElapsed += deltaTime
	sampleFrameTime += deltaTime
	sampleFrames += 1

	if sampleElapsed < VfxConfig.AdaptiveBudget.SampleSeconds then
		return
	end

	local averageFrameTime = sampleFrameTime / math.max(1, sampleFrames)
	sampleElapsed = 0
	sampleFrameTime = 0
	sampleFrames = 0

	if averageFrameTime > VfxConfig.AdaptiveBudget.SlowFrameTime then
		slowSamples += 1
		fastSamples = 0
	elseif averageFrameTime < VfxConfig.AdaptiveBudget.RecoverFrameTime then
		fastSamples += 1
		slowSamples = 0
	else
		slowSamples = 0
		fastSamples = 0
	end

	local manualIndex = getManualQualityIndex()
	local maximumPenalty = math.max(0, manualIndex - 1)

	if slowSamples >= VfxConfig.AdaptiveBudget.SlowFrameSeconds and adaptivePenalty < maximumPenalty then
		adaptivePenalty += 1
		slowSamples = 0
		fastSamples = 0
		DebugLog.Info("Vfx", "Budget VFX reduit", buildSettings())
		notifyChanged()
	elseif fastSamples >= VfxConfig.AdaptiveBudget.RecoverFrameSeconds and adaptivePenalty > 0 then
		adaptivePenalty -= 1
		slowSamples = 0
		fastSamples = 0
		DebugLog.Info("Vfx", "Budget VFX restaure", buildSettings())
		notifyChanged()
	end
end

function VfxQualityController.GetSettings()
	return buildSettings()
end

function VfxQualityController.SetBenchmarkLock(isEnabled)
	local nextValue = isEnabled == true

	if benchmarkLockEnabled == nextValue then
		return
	end

	benchmarkLockEnabled = nextValue
	-- Une campagne repart de la qualite manuelle, pas d'une penalite issue
	-- d'une activite precedente du joueur.
	adaptivePenalty = 0
	sampleElapsed = 0
	sampleFrameTime = 0
	sampleFrames = 0
	slowSamples = 0
	fastSamples = 0
	notifyChanged()
end

function VfxQualityController.Start()
	if isStarted then
		return
	end

	isStarted = true
	GraphicsController.Start()
	applyGraphicsSettings(GraphicsController.GetSettings())

	GraphicsController.Changed.Event:Connect(function(settings)
		applyGraphicsSettings(settings)
	end)

	RunService.RenderStepped:Connect(updateAdaptiveBudget)

	DebugLog.Info("Vfx", "Budget VFX client initialise", buildSettings())
end

VfxQualityController.Changed = changedEvent

return VfxQualityController
