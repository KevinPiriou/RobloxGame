-- Ambiance de run locale : elle ne modifie jamais la map ni le Lighting serveur.

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local DebugLog = require(Shared:WaitForChild("DebugLog"))
local EnvironmentConfig = require(Shared:WaitForChild("EnvironmentConfig"))

local VfxQualityController = require(script.Parent:WaitForChild("VfxQualityController"))

VfxQualityController.Start()

local isRunActive = player:GetAttribute("IsRunActive") == true
local runtimeFolder = nil
local atmosphere = nil
local correction = nil
local bloom = nil
local sunRays = nil
local moteAnchor = nil
local moteEmitter = nil
local lastProfileId = nil
local moteUpdateElapsed = 0
local lightingBaseline = nil
local atmosphereBaseline = nil
local sunRaysBaseline = nil

local function getOrCreateFolder(parent, name)
	local folder = parent:FindFirstChild(name)

	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
	end

	return folder
end

local function getOrCreateEffect(className, name)
	local effect = Lighting:FindFirstChild(name)

	if effect == nil then
		effect = Instance.new(className)
		effect.Name = name
		effect.Parent = Lighting
	end

	return effect
end

local function captureLightingBaseline()
	if lightingBaseline ~= nil then
		return
	end

	lightingBaseline = {
		ClockTime = Lighting.ClockTime,
		Brightness = Lighting.Brightness,
		ExposureCompensation = Lighting.ExposureCompensation,
		Ambient = Lighting.Ambient,
		OutdoorAmbient = Lighting.OutdoorAmbient,
		EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
		EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
		ShadowSoftness = Lighting.ShadowSoftness,
	}
end

local function captureAtmosphereBaseline(effect)
	return {
		Density = effect.Density,
		Offset = effect.Offset,
		Color = effect.Color,
		Decay = effect.Decay,
		Glare = effect.Glare,
		Haze = effect.Haze,
	}
end

local function captureSunRaysBaseline(effect)
	return {
		Enabled = effect.Enabled,
		Intensity = effect.Intensity,
		Spread = effect.Spread,
	}
end

local function findSourceEffect(className, fallbackName)
	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA(className) and child.Name ~= fallbackName then
			return child
		end
	end

	local fallback = Lighting:FindFirstChild(fallbackName)

	if fallback ~= nil and fallback:IsA(className) then
		return fallback
	end

	return nil
end

local function createFallbackEffect(className, name)
	local effect = Instance.new(className)
	effect.Name = name
	effect.Parent = Lighting
	return effect
end

local function ensureSourceEffects()
	local sourceAtmosphere = findSourceEffect("Atmosphere", EnvironmentConfig.FallbackAtmosphereName)

	if sourceAtmosphere == nil then
		sourceAtmosphere = createFallbackEffect("Atmosphere", EnvironmentConfig.FallbackAtmosphereName)
	end

	local sourceSunRays = findSourceEffect("SunRaysEffect", EnvironmentConfig.FallbackSunRaysName)

	if sourceSunRays == nil then
		sourceSunRays = createFallbackEffect("SunRaysEffect", EnvironmentConfig.FallbackSunRaysName)
	end

	local changed = false

	if atmosphere ~= sourceAtmosphere then
		local previousAtmosphere = atmosphere
		atmosphere = sourceAtmosphere
		atmosphereBaseline = captureAtmosphereBaseline(sourceAtmosphere)
		changed = true

		if previousAtmosphere ~= nil
			and previousAtmosphere ~= sourceAtmosphere
			and previousAtmosphere.Name == EnvironmentConfig.FallbackAtmosphereName
			and previousAtmosphere.Parent ~= nil then
			previousAtmosphere:Destroy()
		end
	end

	if sunRays ~= sourceSunRays then
		local previousSunRays = sunRays
		sunRays = sourceSunRays
		sunRaysBaseline = captureSunRaysBaseline(sourceSunRays)
		changed = true

		if previousSunRays ~= nil
			and previousSunRays ~= sourceSunRays
			and previousSunRays.Name == EnvironmentConfig.FallbackSunRaysName
			and previousSunRays.Parent ~= nil then
			previousSunRays:Destroy()
		end
	end

	if changed then
		DebugLog.Info("Environment", "Sources Lighting capturees", {
			Atmosphere = atmosphere,
			SunRays = sunRays,
		})
	end

	return changed
end

local function ensureRuntime()
	if runtimeFolder ~= nil and runtimeFolder.Parent ~= nil then
		ensureSourceEffects()
		return
	end

	runtimeFolder = getOrCreateFolder(Workspace, EnvironmentConfig.RuntimeFolderName)
	captureLightingBaseline()
	ensureSourceEffects()
	correction = getOrCreateEffect("ColorCorrectionEffect", EnvironmentConfig.ColorCorrectionName)
	bloom = getOrCreateEffect("BloomEffect", EnvironmentConfig.BloomName)

	moteAnchor = runtimeFolder:FindFirstChild(EnvironmentConfig.MoteAnchorName)

	if moteAnchor == nil then
		local anchor = Instance.new("Part")
		anchor.Name = EnvironmentConfig.MoteAnchorName
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanTouch = false
		anchor.CanQuery = false
		anchor.CastShadow = false
		anchor.Transparency = 1
		anchor.Size = Vector3.new(0.2, 0.2, 0.2)
		anchor.CFrame = CFrame.new(0, -10000, 0)
		anchor.Parent = runtimeFolder
		moteAnchor = anchor
	end

	moteEmitter = moteAnchor:FindFirstChild("ForestMotes")

	if moteEmitter == nil then
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "ForestMotes"
		emitter.Texture = EnvironmentConfig.MoteTexture
		emitter.Enabled = false
		emitter.LockedToPart = false
		emitter.LightInfluence = 0
		emitter.LightEmission = 0.35
		emitter.EmissionDirection = Enum.NormalId.Top
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Lifetime = NumberRange.new(3.2, 5.4)
		emitter.Speed = NumberRange.new(0.55, 1.3)
		emitter.Acceleration = Vector3.new(0, 0.16, 0)
		emitter.Drag = 1.2
		emitter.Rotation = NumberRange.new(0, 360)
		emitter.RotSpeed = NumberRange.new(-12, 12)
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.08),
			NumberSequenceKeypoint.new(0.55, 0.16),
			NumberSequenceKeypoint.new(1, 0.04),
		})
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.28),
			NumberSequenceKeypoint.new(0.7, 0.56),
			NumberSequenceKeypoint.new(1, 1),
		})
		emitter.Parent = moteAnchor
		moteEmitter = emitter
	end
end

local function getActiveRunMap()
	local mapRuntime = Workspace:FindFirstChild("MapRuntime")

	if mapRuntime == nil then
		return nil
	end

	for _, candidate in ipairs(mapRuntime:GetChildren()) do
		local runId = candidate:GetAttribute("RunId")

		if typeof(runId) == "string" and runId ~= "" then
			return candidate
		end
	end

	return nil
end

local function getActiveLevelId()
	local runMapId = player:GetAttribute("RunMapId")

	if typeof(runMapId) == "string" and runMapId ~= "" then
		return runMapId
	end

	local activeMap = getActiveRunMap()

	if activeMap ~= nil then
		return activeMap.Name
	end

	return EnvironmentConfig.DefaultLevelId
end

local function isEnvironmentActive()
	-- La map runtime est le repere visuel fiable pendant le chargement et la run.
	return isRunActive or getActiveRunMap() ~= nil
end

local function tweenLighting(properties)
	TweenService:Create(
		Lighting,
		TweenInfo.new(EnvironmentConfig.TransitionSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		properties
	):Play()
end

local function updateMoteAnchor()
	if moteAnchor == nil or not isEnvironmentActive() then
		return
	end

	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil

	if root ~= nil and root:IsA("BasePart") then
		moteAnchor.CFrame = CFrame.new(root.Position + Vector3.new(0, EnvironmentConfig.MoteFollowHeight, 0))
	end
end

local function applyLobbyLighting()
	if correction ~= nil then
		correction.Enabled = false
	end

	if bloom ~= nil then
		bloom.Enabled = false
	end

	if atmosphere ~= nil and atmosphereBaseline ~= nil then
		atmosphere.Density = atmosphereBaseline.Density
		atmosphere.Offset = atmosphereBaseline.Offset
		atmosphere.Color = atmosphereBaseline.Color
		atmosphere.Decay = atmosphereBaseline.Decay
		atmosphere.Glare = atmosphereBaseline.Glare
		atmosphere.Haze = atmosphereBaseline.Haze
	end

	if sunRays ~= nil and sunRaysBaseline ~= nil then
		sunRays.Intensity = sunRaysBaseline.Intensity
		sunRays.Spread = sunRaysBaseline.Spread
		sunRays.Enabled = sunRaysBaseline.Enabled
	end

	if moteEmitter ~= nil then
		moteEmitter.Enabled = false
		moteEmitter.Rate = 0
	end

	if moteAnchor ~= nil then
		moteAnchor.CFrame = CFrame.new(0, -10000, 0)
	end

	if lightingBaseline ~= nil then
		tweenLighting(lightingBaseline)
	end
	lastProfileId = nil
end

local function applyRunEnvironment()
	ensureRuntime()

	if not isEnvironmentActive() then
		applyLobbyLighting()
		return
	end

	local levelId = getActiveLevelId()
	local profile = EnvironmentConfig.GetLevelProfile(levelId)
	local qualitySettings = VfxQualityController.GetSettings()
	local qualityProfile = EnvironmentConfig.GetQualityProfile(qualitySettings.Quality)
	local intensity = math.clamp(qualitySettings.EffectsIntensity, 0, 1)
	local atmosphereDensity = profile.Atmosphere.Density
		* qualityProfile.AtmosphereDensityMultiplier
		* (0.65 + (intensity * 0.35))

	atmosphere.Density = atmosphereDensity
	atmosphere.Offset = profile.Atmosphere.Offset
	atmosphere.Color = profile.Atmosphere.Color
	atmosphere.Decay = profile.Atmosphere.Decay
	atmosphere.Glare = profile.Atmosphere.Glare * intensity
	atmosphere.Haze = profile.Atmosphere.Haze

	correction.TintColor = Color3.new(1, 1, 1):Lerp(profile.Correction.TintColor, 0.55 + (intensity * 0.45))
	correction.Brightness = profile.Correction.Brightness * intensity
	correction.Contrast = profile.Correction.Contrast * intensity
	correction.Saturation = profile.Correction.Saturation * intensity
	correction.Enabled = intensity >= 0.05

	bloom.Intensity = profile.Bloom.Intensity * intensity
	bloom.Size = profile.Bloom.Size
	bloom.Threshold = profile.Bloom.Threshold
	bloom.Enabled = qualityProfile.BloomEnabled and intensity >= 0.08

	sunRays.Intensity = profile.SunRays.Intensity * intensity
	sunRays.Spread = profile.SunRays.Spread
	sunRays.Enabled = qualityProfile.SunRaysEnabled and intensity >= 0.12

	local moteRate = profile.Motes.Rate * qualityProfile.MoteRateMultiplier * intensity
	moteEmitter.Color = ColorSequence.new(profile.Motes.Color)
	moteEmitter.Rate = moteRate
	moteEmitter.Enabled = moteRate >= 0.1
	updateMoteAnchor()

	tweenLighting({
		ClockTime = profile.ClockTime,
		Brightness = profile.Brightness,
		ExposureCompensation = profile.ExposureCompensation,
		Ambient = profile.Ambient,
		OutdoorAmbient = profile.OutdoorAmbient,
		EnvironmentDiffuseScale = profile.EnvironmentDiffuseScale,
		EnvironmentSpecularScale = profile.EnvironmentSpecularScale,
		ShadowSoftness = profile.ShadowSoftness,
	})

	if lastProfileId ~= profile.Id then
		lastProfileId = profile.Id
		DebugLog.Info("Environment", "Ambiance de niveau appliquee", {
			LevelId = levelId,
			Profile = profile.Id,
			Quality = qualitySettings.Quality,
			Atmosphere = atmosphere,
			Density = atmosphereDensity,
		})
	end
end

local function bindMapRuntime(mapRuntime)
	if mapRuntime == nil then
		return
	end

	mapRuntime.ChildAdded:Connect(function()
		task.defer(applyRunEnvironment)
	end)

	mapRuntime.ChildRemoved:Connect(function()
		task.defer(applyRunEnvironment)
	end)
end

local function refreshRunState(payload)
	isRunActive = typeof(payload) == "table" and payload.IsRunActive == true
	task.defer(applyRunEnvironment)
end

Workspace.ChildAdded:Connect(function(child)
	if child.Name == "MapRuntime" then
		bindMapRuntime(child)
		task.defer(applyRunEnvironment)
	end
end)

bindMapRuntime(Workspace:FindFirstChild("MapRuntime"))

Lighting.ChildAdded:Connect(function(child)
	if not child:IsA("Atmosphere") and not child:IsA("SunRaysEffect") then
		return
	end

	task.defer(function()
		if ensureSourceEffects() then
			applyRunEnvironment()
		end
	end)
end)

ReplicatedStorage:WaitForChild("Run_StateUpdate").OnClientEvent:Connect(refreshRunState)

player:GetAttributeChangedSignal("IsRunActive"):Connect(function()
	isRunActive = player:GetAttribute("IsRunActive") == true
	task.defer(applyRunEnvironment)
end)

player:GetAttributeChangedSignal("RunMapId"):Connect(function()
	if isEnvironmentActive() then
		task.defer(applyRunEnvironment)
	end
end)

VfxQualityController.Changed.Event:Connect(function()
	if isEnvironmentActive() then
		applyRunEnvironment()
	end
end)

RunService.RenderStepped:Connect(function(deltaTime)
	if not isEnvironmentActive() or moteEmitter == nil or moteEmitter.Enabled ~= true then
		return
	end

	moteUpdateElapsed += deltaTime

	if moteUpdateElapsed >= EnvironmentConfig.MoteUpdateInterval then
		moteUpdateElapsed = 0
		updateMoteAnchor()
	end
end)

task.defer(applyRunEnvironment)

DebugLog.Info("Environment", "Controleur d'ambiance initialise", {
	Player = player.Name,
})
