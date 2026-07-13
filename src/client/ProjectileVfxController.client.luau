-- Presentation locale des projectiles. Le serveur garde toute la logique de combat.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local DebugLog = require(Shared:WaitForChild("DebugLog"))
local VfxConfig = require(Shared:WaitForChild("VfxConfig"))

local VfxQualityController = require(script.Parent:WaitForChild("VfxQualityController"))

VfxQualityController.Start()

local activeStates = {}
local observedConnections = {}
local packagePool = {}
local activeImpactStates = {}
local impactPool = {}
local packageSerial = 0
local impactSerial = 0
local runtimeFolder = nil
local poolAnchor = nil
local impactPoolFolder = nil
local activeImpactFolder = nil

local function colorSequence(firstColor, secondColor)
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, firstColor),
		ColorSequenceKeypoint.new(1, secondColor),
	})
end

local function numberSequence(firstValue, secondValue)
	return NumberSequence.new({
		NumberSequenceKeypoint.new(0, firstValue),
		NumberSequenceKeypoint.new(1, secondValue),
	})
end

local function getOrCreateFolder(parent, name)
	local folder = parent:FindFirstChild(name)

	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
	end

	return folder
end

local function setupRuntime()
	if runtimeFolder ~= nil and runtimeFolder.Parent ~= nil then
		return
	end

	runtimeFolder = getOrCreateFolder(Workspace, VfxConfig.RuntimeFolderName)
	impactPoolFolder = getOrCreateFolder(runtimeFolder, "ImpactPool")
	activeImpactFolder = getOrCreateFolder(runtimeFolder, "Impacts")

	poolAnchor = runtimeFolder:FindFirstChild("PoolAnchor")

	if poolAnchor == nil then
		local anchor = Instance.new("Part")
		anchor.Name = "PoolAnchor"
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanTouch = false
		anchor.CanQuery = false
		anchor.CastShadow = false
		anchor.Transparency = 1
		anchor.Size = Vector3.new(0.1, 0.1, 0.1)
		anchor.CFrame = CFrame.new(0, -10000, 0)
		anchor.Parent = runtimeFolder
		poolAnchor = anchor
	end
end

local function findRoot(projectile)
	if projectile:IsA("BasePart") then
		return projectile
	end

	if not projectile:IsA("Model") then
		return nil
	end

	if projectile.PrimaryPart ~= nil then
		return projectile.PrimaryPart
	end

	return projectile:FindFirstChildWhichIsA("BasePart", true)
end

local function createAttachment(name, parent)
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.Parent = parent
	return attachment
end

local function createEmitter(name, parent, lockedToPart)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = name
	emitter.LockedToPart = lockedToPart ~= false
	emitter.VelocityInheritance = 0
	emitter.LightInfluence = 0
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-70, 70)
	emitter.Parent = parent
	return emitter
end

local function createVisualPackage()
	setupRuntime()
	packageSerial += 1

	local front = createAttachment("ProjectileVfxFront", poolAnchor)
	local back = createAttachment("ProjectileVfxBack", poolAnchor)
	local trail = Instance.new("Trail")
	trail.Name = "ProjectileVfxTrail"
	trail.Attachment0 = front
	trail.Attachment1 = back
	trail.FaceCamera = true
	trail.LightEmission = 0.45
	trail.MinLength = 0.05
	trail.Enabled = false
	trail.Parent = poolAnchor

	local flameShell = createEmitter("ProjectileVfxFlameShell", front)
	local flameTail = createEmitter("ProjectileVfxFlameTail", back, false)
	local smoke = createEmitter("ProjectileVfxSmoke", back)
	local spark = createEmitter("ProjectileVfxSpark", front)
	flameShell.Enabled = false
	flameTail.Enabled = false
	smoke.Enabled = false
	spark.Enabled = false

	local light = Instance.new("PointLight")
	light.Name = "ProjectileVfxLight"
	light.Shadows = false
	light.Enabled = false
	light.Parent = poolAnchor

	return {
		Id = packageSerial,
		Front = front,
		Back = back,
		Trail = trail,
		FlameShell = flameShell,
		FlameTail = flameTail,
		Smoke = smoke,
		Spark = spark,
		Light = light,
	}
end

local function acquireVisualPackage()
	local package = table.remove(packagePool)

	if package ~= nil then
		return package
	end

	return createVisualPackage()
end

local function disableEmitter(emitter)
	emitter.Enabled = false
	emitter:Clear()
end

local function releaseVisualPackage(package)
	if package == nil then
		return
	end

	setupRuntime()
	disableEmitter(package.FlameShell)
	disableEmitter(package.FlameTail)
	disableEmitter(package.Smoke)
	disableEmitter(package.Spark)
	package.Trail.Enabled = false
	package.Light.Enabled = false
	package.Light.Parent = poolAnchor
	package.Trail.Parent = poolAnchor
	package.Front.Parent = poolAnchor
	package.Back.Parent = poolAnchor
	table.insert(packagePool, package)
end

local function configureFlameShell(emitter, profile, rateScale)
	emitter.Texture = profile.FlameTexture
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Orientation = Enum.ParticleOrientation.FacingCamera
	emitter.Color = colorSequence(profile.AccentColor, profile.TrailColor)
	emitter.LightEmission = 0.38
	emitter.Rate = profile.FlameShellRate * rateScale
	emitter.Lifetime = NumberRange.new(0.13, 0.22)
	emitter.Speed = NumberRange.new(0.01, 0.08)
	emitter.Size = numberSequence(profile.FlameShellStartSize, 0.22)
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.18),
		NumberSequenceKeypoint.new(0.42, 0.08),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Enabled = rateScale > 0
end

local function configureFlameTail(emitter, profile, rateScale)
	emitter.Texture = profile.FlameTexture
	emitter.EmissionDirection = Enum.NormalId.Back
	emitter.SpreadAngle = Vector2.new(28, 28)
	emitter.Orientation = Enum.ParticleOrientation.FacingCamera
	emitter.Color = colorSequence(profile.CoreColor, profile.TrailColor)
	emitter.LightEmission = 0.24
	emitter.VelocityInheritance = 0.06
	emitter.Rate = profile.FlameTailRate * rateScale
	emitter.Lifetime = NumberRange.new(0.2, 0.34)
	emitter.Speed = NumberRange.new(0.65, 1.35)
	emitter.Size = numberSequence(profile.FlameTailStartSize, 0.14)
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(0.36, 0.12),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Enabled = rateScale > 0
end

local function configureSmoke(emitter, profile, rateScale)
	emitter.Texture = profile.SmokeTexture
	emitter.EmissionDirection = Enum.NormalId.Back
	emitter.SpreadAngle = Vector2.new(80, 80)
	emitter.Color = colorSequence(profile.CoreColor, profile.SmokeColor)
	emitter.LightEmission = 0.08
	emitter.Rate = profile.SmokeRate * rateScale
	emitter.Lifetime = NumberRange.new(0.28, 0.5)
	emitter.Speed = NumberRange.new(0.08, 0.32)
	emitter.Size = numberSequence(0.28, 0.78)
	emitter.Transparency = numberSequence(0.72, 1)
	emitter.Enabled = rateScale > 0
end

local function configureSpark(emitter, profile, rateScale)
	emitter.Texture = profile.SparkTexture
	emitter.EmissionDirection = Enum.NormalId.Back
	emitter.SpreadAngle = Vector2.new(110, 110)
	emitter.Color = colorSequence(profile.AccentColor, profile.CoreColor)
	emitter.LightEmission = 0.35
	emitter.Rate = profile.SparkleRate * rateScale
	emitter.Lifetime = NumberRange.new(0.1, 0.19)
	emitter.Speed = NumberRange.new(0.1, 0.55)
	emitter.Size = numberSequence(0.1, 0)
	emitter.Transparency = numberSequence(0.08, 1)
	emitter.Enabled = rateScale > 0
end

local function configurePackage(state, lod, settings)
	local package = state.Package
	local profile = state.Profile
	local root = state.Root

	if root == nil or root.Parent == nil then
		return
	end

	package.Front.Parent = root
	package.Back.Parent = root
	package.Trail.Parent = root
	package.Light.Parent = root
	package.Front.Position = Vector3.new(0, 0, 0.42)
	package.Back.Position = Vector3.new(0, 0, -0.72)

	local intensity = settings.EffectsIntensity
	local hasDecorativeEffects = intensity >= 0.08 and lod ~= "Minimal"
	local isFull = lod == "Full"
	local rateScale = if isFull then intensity else intensity * 0.35

	package.Trail.Color = colorSequence(profile.AccentColor, profile.TrailColor)
	package.Trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.54),
		NumberSequenceKeypoint.new(0.45, 0.24),
		NumberSequenceKeypoint.new(1, 0),
	})
	package.Trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.26),
		NumberSequenceKeypoint.new(0.7, 0.62),
		NumberSequenceKeypoint.new(1, 1),
	})
	package.Trail.Lifetime = profile.TrailLifetime * if isFull then 1 else 0.55
	package.Trail.Enabled = hasDecorativeEffects

	if hasDecorativeEffects then
		configureFlameShell(package.FlameShell, profile, rateScale)
	else
		disableEmitter(package.FlameShell)
	end

	if isFull and hasDecorativeEffects then
		configureFlameTail(package.FlameTail, profile, rateScale)
	else
		disableEmitter(package.FlameTail)
	end

	if isFull and hasDecorativeEffects then
		configureSmoke(package.Smoke, profile, rateScale)
		configureSpark(package.Spark, profile, rateScale)
	else
		disableEmitter(package.Smoke)
		disableEmitter(package.Spark)
	end

	package.Light.Color = profile.AccentColor
	package.Light.Range = profile.LightRange
	package.Light.Brightness = profile.LightBrightness * intensity
	package.Light.Enabled = isFull and intensity >= 0.12
	state.Lod = lod
end

local function getSortedStates()
	local states = {}

	for _, state in pairs(activeStates) do
		if state.Projectile.Parent ~= nil then
			table.insert(states, state)
		end
	end

	table.sort(states, function(left, right)
		return left.VisualSerial < right.VisualSerial
	end)

	return states
end

local function refreshProjectileBudgets()
	local settings = VfxQualityController.GetSettings()
	local profile = settings.Profile
	local fullCount = 0
	local reducedCount = 0

	for _, state in ipairs(getSortedStates()) do
		local lod = "Minimal"

		if settings.EffectsIntensity >= 0.08 and fullCount < profile.FullProjectileLimit then
			lod = "Full"
			fullCount += 1
		elseif settings.EffectsIntensity >= 0.08 and reducedCount < profile.ReducedProjectileLimit then
			lod = "Reduced"
			reducedCount += 1
		end

		configurePackage(state, lod, settings)
	end

	DebugLog.ThrottledInfo("Vfx", "projectile_budget", 5, "Budget projectiles applique", {
		Quality = settings.Quality,
		Full = fullCount,
		Reduced = reducedCount,
		Minimal = math.max(0, #getSortedStates() - fullCount - reducedCount),
		Pool = #packagePool,
	})
end

local function disconnectObserved(projectile)
	local connections = observedConnections[projectile]

	if connections == nil then
		return
	end

	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end

	observedConnections[projectile] = nil
end

local function releaseProjectileState(projectile)
	local state = activeStates[projectile]

	if state == nil then
		return
	end

	activeStates[projectile] = nil
	releaseVisualPackage(state.Package)
	refreshProjectileBudgets()
end

local function isLocalRuntimeProjectile(projectile)
	return projectile:GetAttribute("RuntimeProjectile") == true
		and projectile:GetAttribute("ProjectileOwnerUserId") == player.UserId
		and typeof(projectile:GetAttribute("VfxProfileId")) == "string"
end

local function attachProjectile(projectile)
	if activeStates[projectile] ~= nil or not isLocalRuntimeProjectile(projectile) then
		return
	end

	local root = findRoot(projectile)

	if root == nil then
		return
	end

	local visualSerial = math.max(0, math.floor(tonumber(projectile:GetAttribute("ProjectileVisualSerial")) or 0))
	local profileId = projectile:GetAttribute("VfxProfileId")
	local state = {
		Projectile = projectile,
		Root = root,
		Profile = VfxConfig.GetProjectileProfile(profileId),
		VisualSerial = visualSerial,
		Package = acquireVisualPackage(),
		Lod = "Minimal",
	}

	activeStates[projectile] = state
	refreshProjectileBudgets()
end

local function observeProjectile(projectile)
	if observedConnections[projectile] ~= nil then
		attachProjectile(projectile)
		return
	end

	local function refresh()
		if isLocalRuntimeProjectile(projectile) then
			attachProjectile(projectile)
		else
			releaseProjectileState(projectile)
		end
	end

	observedConnections[projectile] = {
		projectile:GetAttributeChangedSignal("RuntimeProjectile"):Connect(refresh),
		projectile:GetAttributeChangedSignal("ProjectileOwnerUserId"):Connect(refresh),
		projectile:GetAttributeChangedSignal("VfxProfileId"):Connect(refresh),
		projectile.AncestryChanged:Connect(function()
			if projectile.Parent == nil then
				releaseProjectileState(projectile)
				disconnectObserved(projectile)
			end
		end),
	}

	task.defer(refresh)
end

local function createImpactPart()
	setupRuntime()
	local impact = Instance.new("Part")
	impact.Name = "ProjectileImpactVfx"
	impact.Shape = Enum.PartType.Ball
	impact.Material = Enum.Material.Neon
	impact.Anchored = true
	impact.CanCollide = false
	impact.CanTouch = false
	impact.CanQuery = false
	impact.CastShadow = false
	impact.Transparency = 1

	local light = Instance.new("PointLight")
	light.Name = "ImpactLight"
	light.Shadows = false
	light.Enabled = false
	light.Parent = impact

	impact.Parent = impactPoolFolder
	return impact
end

local function acquireImpact()
	local impact = table.remove(impactPool)

	if impact ~= nil then
		return impact
	end

	return createImpactPart()
end

local function releaseImpact(impact, serial)
	local state = activeImpactStates[impact]

	if state == nil or state.Serial ~= serial then
		return
	end

	activeImpactStates[impact] = nil
	impact.Transparency = 1
	impact.Parent = impactPoolFolder
	local light = impact:FindFirstChild("ImpactLight")

	if light ~= nil and light:IsA("PointLight") then
		light.Enabled = false
	end

	table.insert(impactPool, impact)
end

local function getImpactLod(settings)
	local fullCount = 0
	local reducedCount = 0
	local minimalCount = 0

	for _, state in pairs(activeImpactStates) do
		if state.Lod == "Full" then
			fullCount += 1
		elseif state.Lod == "Reduced" then
			reducedCount += 1
		elseif state.Lod == "Minimal" then
			minimalCount += 1
		end
	end

	if settings.EffectsIntensity < 0.08 then
		if minimalCount < settings.Profile.FullImpactLimit then
			return "Minimal"
		end

		return nil
	end

	if fullCount < settings.Profile.FullImpactLimit then
		return "Full"
	end

	if reducedCount < settings.Profile.ReducedImpactLimit then
		return "Reduced"
	end

	return nil
end

local function playImpact(payload)
	if typeof(payload) ~= "table" or payload.Type ~= "Impact" or typeof(payload.Position) ~= "Vector3" then
		return
	end

	local settings = VfxQualityController.GetSettings()
	local lod = getImpactLod(settings)

	if lod == nil then
		DebugLog.ThrottledInfo("Vfx", "impact_budget", 3, "Impact VFX ignore par budget", {
			Quality = settings.Quality,
		})
		return
	end

	local profile = VfxConfig.GetProjectileProfile(payload.ProfileId)
	local impact = acquireImpact()
	impactSerial += 1
	local serial = impactSerial
	local scale = if lod == "Full" then 1 elseif lod == "Reduced" then 0.72 else 0.48
	local duration = profile.ImpactLifetime

	impact.CFrame = CFrame.new(payload.Position)
	impact.Color = profile.AccentColor
	impact.Size = Vector3.new(profile.ImpactStartSize, profile.ImpactStartSize, profile.ImpactStartSize) * scale
	impact.Transparency = if lod == "Minimal" then 0.56 else 0.24
	impact.Parent = activeImpactFolder

	local light = impact:FindFirstChild("ImpactLight")

	if light ~= nil and light:IsA("PointLight") then
		light.Color = profile.AccentColor
		light.Range = profile.ImpactEndSize * 2 * scale
		light.Brightness = if lod == "Full" then 0.9 * settings.EffectsIntensity else 0
		light.Enabled = lod == "Full" and settings.EffectsIntensity >= 0.12
	end

	activeImpactStates[impact] = {
		Serial = serial,
		Lod = lod,
	}

	TweenService:Create(impact, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(profile.ImpactEndSize, profile.ImpactEndSize, profile.ImpactEndSize) * scale,
		Transparency = 1,
	}):Play()

	task.delay(duration, function()
		releaseImpact(impact, serial)
	end)
end

local function connectProjectileFolder()
	local runtime = Workspace:WaitForChild("CombatRuntime", 30)

	if runtime == nil then
		DebugLog.Warn("Vfx", "CombatRuntime introuvable pour les VFX projectile")
		return
	end

	local projectiles = runtime:WaitForChild("Projectiles", 30)

	if projectiles == nil then
		DebugLog.Warn("Vfx", "Dossier Projectiles introuvable pour les VFX projectile")
		return
	end

	for _, projectile in ipairs(projectiles:GetChildren()) do
		observeProjectile(projectile)
	end

	projectiles.ChildAdded:Connect(observeProjectile)
	projectiles.ChildRemoved:Connect(function(projectile)
		releaseProjectileState(projectile)
		disconnectObserved(projectile)
	end)
end

VfxQualityController.Changed.Event:Connect(refreshProjectileBudgets)

local impactRemote = ReplicatedStorage:WaitForChild(VfxConfig.ImpactRemoteName, 30)

if impactRemote ~= nil and impactRemote:IsA("RemoteEvent") then
	impactRemote.OnClientEvent:Connect(playImpact)
else
	DebugLog.Warn("Vfx", "Remote des impacts projectile introuvable", {
		Remote = VfxConfig.ImpactRemoteName,
	})
end

task.spawn(connectProjectileFolder)

DebugLog.Info("Vfx", "Controleur VFX projectile initialise", {
	Player = player.Name,
})
