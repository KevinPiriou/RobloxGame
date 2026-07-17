-- Ambiance de run locale : elle ne modifie jamais la map ni le Lighting serveur.

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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
local blur = nil
local depthOfField = nil
local sunRays = nil
local moteVolumesFolder = nil
local moteEmitters = {}
local leafEmitters = {}
local moteMap = nil
local moteCoverageArea = nil
local lastProfileId = nil
local lightingBaseline = nil
local windBaseline = nil

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
	windBaseline = Workspace.GlobalWind
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

local function replaceSourceEffect(currentEffect, className, fallbackName)
	local sourceEffect = findSourceEffect(className, fallbackName)

	if sourceEffect == nil then
		sourceEffect = createFallbackEffect(className, fallbackName)
	end

	local changed = currentEffect ~= sourceEffect

	if currentEffect ~= nil
		and currentEffect ~= sourceEffect
		and currentEffect.Name == fallbackName
		and currentEffect.Parent ~= nil then
		currentEffect:Destroy()
	end

	return sourceEffect, changed
end

local function ensureSourceEffects()
	local atmosphereChanged = false
	local correctionChanged = false
	local blurChanged = false
	local depthOfFieldChanged = false
	local sunRaysChanged = false

	atmosphere, atmosphereChanged = replaceSourceEffect(
		atmosphere,
		"Atmosphere",
		EnvironmentConfig.FallbackAtmosphereName
	)
	correction, correctionChanged = replaceSourceEffect(
		correction,
		"ColorCorrectionEffect",
		EnvironmentConfig.ColorCorrectionName
	)
	blur, blurChanged = replaceSourceEffect(
		blur,
		"BlurEffect",
		EnvironmentConfig.BlurName
	)
	depthOfField, depthOfFieldChanged = replaceSourceEffect(
		depthOfField,
		"DepthOfFieldEffect",
		EnvironmentConfig.DepthOfFieldName
	)
	sunRays, sunRaysChanged = replaceSourceEffect(
		sunRays,
		"SunRaysEffect",
		EnvironmentConfig.FallbackSunRaysName
	)

	local changed = atmosphereChanged
		or correctionChanged
		or blurChanged
		or depthOfFieldChanged
		or sunRaysChanged

	if changed then
		DebugLog.Info("Environment", "Sources Lighting capturees", {
			Atmosphere = atmosphere,
			ColorCorrection = correction,
			Blur = blur,
			DepthOfField = depthOfField,
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
	bloom = getOrCreateEffect("BloomEffect", EnvironmentConfig.BloomName)

	moteVolumesFolder = getOrCreateFolder(runtimeFolder, EnvironmentConfig.MoteVolumesFolderName)
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

local function getActiveEnvironmentContext()
	local activeMap = getActiveRunMap()
	local runMapId = player:GetAttribute("RunMapId")
	local levelId = if typeof(runMapId) == "string" and runMapId ~= ""
		then runMapId
		else if activeMap ~= nil then activeMap.Name else EnvironmentConfig.DefaultLevelId

	local chapterId = if activeMap ~= nil then activeMap:GetAttribute("ChapterId") else nil

	if tonumber(chapterId) == nil then
		chapterId = player:GetAttribute("SelectedChapter")
	end

	return levelId, chapterId
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

local function applyAtmosphere(properties)
	if atmosphere == nil then
		return
	end

	atmosphere.Density = properties.Density
	atmosphere.Offset = properties.Offset
	atmosphere.Color = properties.Color
	atmosphere.Decay = properties.Decay
	atmosphere.Glare = properties.Glare
	atmosphere.Haze = properties.Haze
end

local function createMoteEmitter(parent)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "ForestMotes"
	emitter.Texture = EnvironmentConfig.MoteTexture
	emitter.Enabled = false
	emitter.LockedToPart = false
	emitter.LightInfluence = 0.15
	emitter.LightEmission = 0.55
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.SpreadAngle = Vector2.new(9, 9)
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	emitter.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	emitter.Lifetime = NumberRange.new(9.5, 12)
	emitter.Speed = NumberRange.new(0.25, 0.7)
	emitter.Acceleration = Vector3.new(0.3, -3, 0.2)
	emitter.Drag = 0.15
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-28, 28)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(0.45, 1.1),
		NumberSequenceKeypoint.new(1, 0.45),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(0.7, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Parent = parent
	return emitter
end

local function createLeafEmitter(parent, pattern)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = pattern.Name
	emitter.Texture = pattern.Texture
	emitter.Enabled = false
	emitter.LockedToPart = false
	emitter.LightInfluence = 0.65
	emitter.LightEmission = 0.05
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.SpreadAngle = Vector2.new(14, 14)
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	emitter.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	emitter.FlipbookLayout = Enum.ParticleFlipbookLayout.None
	emitter.Lifetime = NumberRange.new(10.5, 13.5)
	emitter.Speed = NumberRange.new(0.3, 0.8)
	emitter.Acceleration = Vector3.new(0, EnvironmentConfig.AtmosphereLeafFallAcceleration, 0)
	emitter.Drag = 0.12
	emitter.WindAffectsDrag = true
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-38, 38)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, pattern.SizeStart),
		NumberSequenceKeypoint.new(0.5, pattern.SizePeak),
		NumberSequenceKeypoint.new(1, pattern.SizeEnd),
	})
	emitter.Transparency = NumberSequence.new({
		-- Au sommet, les feuilles se fondent dans la brume puis gagnent doucement en presence.
		NumberSequenceKeypoint.new(0, 0.9),
		NumberSequenceKeypoint.new(0.3, 0.62),
		NumberSequenceKeypoint.new(0.64, 0.48),
		NumberSequenceKeypoint.new(0.9, 0.68),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Parent = parent

	return {
		Emitter = emitter,
		Pattern = pattern,
	}
end

local function isAtmospherePlatform(part, map)
	if part.CanCollide ~= true or part.Transparency >= 0.95 then
		return false
	end

	local current = part

	while current ~= nil and current ~= map do
		local name = string.lower(current.Name)

		if string.find(name, "limit", 1, true)
			or string.find(name, "invisible", 1, true)
			or string.find(name, "boundary", 1, true)
			or string.find(name, "border", 1, true)
			or string.find(name, "leaves", 1, true)
			or string.find(name, "trunk", 1, true)
			or string.find(name, "tree", 1, true) then
			return false
		end

		current = current.Parent
	end

	return true
end

local function getPartTopY(part)
	local halfSize = part.Size * 0.5
	local cframe = part.CFrame

	return part.Position.Y
		+ (math.abs(cframe.RightVector.Y) * halfSize.X)
		+ (math.abs(cframe.UpVector.Y) * halfSize.Y)
		+ (math.abs(cframe.LookVector.Y) * halfSize.Z)
end

local function getHighestPlatformSurface(map, mapCenter, mapSize)
	local highest = nil

	local function consider(part)
		if not isAtmospherePlatform(part, map) then
			return
		end

		local topY = getPartTopY(part)
		highest = if highest == nil then topY else math.max(highest, topY)
	end

	if map:IsA("BasePart") then
		consider(map)
	end

	for _, descendant in ipairs(map:GetDescendants()) do
		if descendant:IsA("BasePart") then
			consider(descendant)
		end
	end

	return if highest ~= nil then highest else mapCenter.Y + (mapSize.Y * 0.5)
end

local function clearMoteVolumes()
	if moteVolumesFolder ~= nil then
		for _, child in ipairs(moteVolumesFolder:GetChildren()) do
			child:Destroy()
		end
	end

	table.clear(moteEmitters)
	table.clear(leafEmitters)
	moteMap = nil
	moteCoverageArea = nil
end

local function updateMoteVolumes()
	if moteVolumesFolder == nil then
		return nil, 0
	end

	local map = getActiveRunMap()

	if map == nil then
		clearMoteVolumes()
		return nil, 0
	end

	if moteMap == map and #moteEmitters > 0 and #leafEmitters > 0 then
		return moteCoverageArea, #moteEmitters
	end

	local mapCenter = nil
	local mapSize = nil

	if map:IsA("Model") then
		local boundingCFrame, size = map:GetBoundingBox()
		mapCenter = boundingCFrame.Position
		mapSize = size
	elseif map:IsA("BasePart") then
		mapCenter = map.Position
		mapSize = map.Size
	else
		return nil, 0
	end

	clearMoteVolumes()

	local width = math.max(mapSize.X, 1)
	local depth = math.max(mapSize.Z, 1)
	local columns = math.max(1, math.ceil(width / EnvironmentConfig.MoteTileMaximumSize))
	local rows = math.max(1, math.ceil(depth / EnvironmentConfig.MoteTileMaximumSize))
	local tileWidth = width / columns
	local tileDepth = depth / rows
	local emissionHeight = getHighestPlatformSurface(map, mapCenter, mapSize)
		+ EnvironmentConfig.AtmosphereSpawnMarginAbovePlatform
	local minimumX = mapCenter.X - (width * 0.5)
	local minimumZ = mapCenter.Z - (depth * 0.5)

	-- Les tuiles sont fixes dans le monde : aucune ne suit la position du joueur.
	for column = 1, columns do
		for row = 1, rows do
			local volume = Instance.new("Part")
			volume.Name = string.format("MoteTile_%d_%d", column, row)
			volume.Anchored = true
			volume.CanCollide = false
			volume.CanTouch = false
			volume.CanQuery = false
			volume.CastShadow = false
			volume.Transparency = 1
			volume.Size = Vector3.new(tileWidth, 0.2, tileDepth)
			volume.CFrame = CFrame.new(
				minimumX + (tileWidth * (column - 0.5)),
				emissionHeight,
				minimumZ + (tileDepth * (row - 0.5))
			)
			volume.Parent = moteVolumesFolder
			table.insert(moteEmitters, createMoteEmitter(volume))

			for _, pattern in ipairs(EnvironmentConfig.AtmosphereLeafPatterns) do
				table.insert(leafEmitters, createLeafEmitter(volume, pattern))
			end
		end
	end

	moteMap = map
	moteCoverageArea = width * depth

	return moteCoverageArea, #moteEmitters
end

local function applyLobbyLighting()
	if correction ~= nil then
		correction.Enabled = false
	end

	if bloom ~= nil then
		bloom.Enabled = false
	end

	if blur ~= nil then
		blur.Enabled = false
	end

	if depthOfField ~= nil then
		depthOfField.Enabled = false
	end

	applyAtmosphere(EnvironmentConfig.LobbyAtmosphere)

	if sunRays ~= nil then
		sunRays.Enabled = false
	end

	clearMoteVolumes()

	if windBaseline ~= nil then
		Workspace.GlobalWind = windBaseline
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

	local levelId, chapterId = getActiveEnvironmentContext()
	local profile = EnvironmentConfig.GetLevelProfile(levelId, chapterId)
	local qualitySettings = VfxQualityController.GetSettings()
	local qualityProfile = EnvironmentConfig.GetQualityProfile(qualitySettings.Quality)
	local intensity = math.clamp(qualitySettings.EffectsIntensity, 0, 1)
	local atmosphereDensity = profile.Atmosphere.Density
		* qualityProfile.AtmosphereDensityMultiplier
		* (0.65 + (intensity * 0.35))

	applyAtmosphere({
		Density = atmosphereDensity,
		Offset = profile.Atmosphere.Offset,
		Color = profile.Atmosphere.Color,
		Decay = profile.Atmosphere.Decay,
		Glare = profile.Atmosphere.Glare * intensity,
		Haze = profile.Atmosphere.Haze,
	})

	correction.TintColor = Color3.new(1, 1, 1):Lerp(profile.Correction.TintColor, 0.55 + (intensity * 0.45))
	correction.Brightness = profile.Correction.Brightness * intensity
	correction.Contrast = profile.Correction.Contrast * intensity
	correction.Saturation = profile.Correction.Saturation * intensity
	correction.Enabled = intensity >= 0.05

	bloom.Intensity = profile.Bloom.Intensity * intensity
	bloom.Size = profile.Bloom.Size
	bloom.Threshold = profile.Bloom.Threshold
	bloom.Enabled = qualityProfile.BloomEnabled and intensity >= 0.08

	blur.Size = profile.Blur.Size * qualityProfile.BlurSizeMultiplier * intensity
	blur.Enabled = qualityProfile.BlurEnabled and blur.Size >= 0.05

	depthOfField.FocusDistance = profile.DepthOfField.FocusDistance
	depthOfField.InFocusRadius = profile.DepthOfField.InFocusRadius
	depthOfField.NearIntensity = profile.DepthOfField.NearIntensity * qualityProfile.DepthOfFieldIntensityMultiplier * intensity
	depthOfField.FarIntensity = profile.DepthOfField.FarIntensity * qualityProfile.DepthOfFieldIntensityMultiplier * intensity
	depthOfField.Enabled = qualityProfile.DepthOfFieldEnabled and intensity >= 0.08

	sunRays.Intensity = profile.SunRays.Intensity * intensity
	sunRays.Spread = profile.SunRays.Spread
	sunRays.Enabled = qualityProfile.SunRaysEnabled and intensity >= 0.12

	Workspace.GlobalWind = profile.Wind * intensity

	local moteArea, moteEmitterCount = updateMoteVolumes()
	local coverageMultiplier = if moteArea ~= nil
		then math.clamp(
			moteArea / EnvironmentConfig.MoteAreaReference,
			1,
			EnvironmentConfig.MoteAreaMaxMultiplier
		)
		else 0
	local moteRate = profile.Motes.Rate
		* coverageMultiplier
		* qualityProfile.MoteRateMultiplier
		* intensity
		* EnvironmentConfig.MoteDebugRateMultiplier
	local moteRatePerEmitter = moteRate / math.max(1, moteEmitterCount)

	for _, emitter in ipairs(moteEmitters) do
		emitter.Color = ColorSequence.new(profile.Motes.Color)
		emitter.Rate = moteRatePerEmitter
		emitter.Enabled = moteRatePerEmitter >= 0.1
	end

	local leafRatePerEmitter = EnvironmentConfig.AtmosphereLeafRatePerTile
		* qualityProfile.LeafRateMultiplier
		* intensity
	local leafAcceleration = Vector3.new(
		profile.Wind.X * EnvironmentConfig.AtmosphereLeafWindAccelerationMultiplier,
		EnvironmentConfig.AtmosphereLeafFallAcceleration,
		profile.Wind.Z * EnvironmentConfig.AtmosphereLeafWindAccelerationMultiplier
	)

	for _, leafState in ipairs(leafEmitters) do
		local leafRate = leafRatePerEmitter * leafState.Pattern.RateMultiplier
		leafState.Emitter.Color = ColorSequence.new(profile.Motes.Color)
		leafState.Emitter.Acceleration = leafAcceleration
		leafState.Emitter.Rate = leafRate
		leafState.Emitter.Enabled = leafRate >= 0.1
	end

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
			ChapterId = chapterId,
			Profile = profile.Id,
			Quality = qualitySettings.Quality,
			Atmosphere = atmosphere,
			Density = atmosphereDensity,
			MoteEmitters = moteEmitterCount,
			MoteRate = moteRate,
			MoteRatePerEmitter = moteRatePerEmitter,
			LeafEmitters = #leafEmitters,
			LeafRatePerEmitter = leafRatePerEmitter,
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
	if not child:IsA("Atmosphere")
		and not child:IsA("ColorCorrectionEffect")
		and not child:IsA("BlurEffect")
		and not child:IsA("DepthOfFieldEffect")
		and not child:IsA("SunRaysEffect") then
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

task.defer(applyRunEnvironment)

DebugLog.Info("Environment", "Controleur d'ambiance initialise", {
	Player = player.Name,
})
