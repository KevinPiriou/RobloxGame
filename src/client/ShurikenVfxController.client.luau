--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DebugLog = require(Shared:WaitForChild("DebugLog"))
local VfxQualityController = require(script.Parent:WaitForChild("VfxQualityController"))

local WEAPON_ID = "shuriken"
local vfxRemote = ReplicatedStorage:WaitForChild("Weapon_ShurikenVfx")
assert(vfxRemote:IsA("RemoteEvent"), "Weapon_ShurikenVfx doit etre un RemoteEvent")

VfxQualityController.Start()

local runtime = Workspace:FindFirstChild("ClientWeaponVfx")
if runtime == nil then
	runtime = Instance.new("Folder")
	runtime.Name = "ClientWeaponVfx"
	runtime.Parent = Workspace
end

local activeProjectiles: {[number]: any} = {}

local SKIN_PALETTES = {
	shuriken_shadowspin = {
		Blade = Color3.fromRGB(45, 34, 61),
		Accent = Color3.fromRGB(122, 62, 174),
		Core = Color3.fromRGB(195, 86, 255),
		Spark = Color3.fromRGB(242, 218, 255),
	},
	shuriken_moonveil = {
		Blade = Color3.fromRGB(91, 103, 124),
		Accent = Color3.fromRGB(71, 189, 255),
		Core = Color3.fromRGB(171, 241, 255),
		Spark = Color3.fromRGB(234, 253, 255),
	},
}

local function getPalette(skinId: unknown)
	if typeof(skinId) == "string" and SKIN_PALETTES[skinId] ~= nil then
		return SKIN_PALETTES[skinId]
	end
	return SKIN_PALETTES.shuriken_shadowspin
end

local function getSparkTexture(): string
	local visualTemplates = ReplicatedStorage:FindFirstChild("VisualTemplates")
	local auraTemplates = visualTemplates and visualTemplates:FindFirstChild("AuraTemplates")
	local textures = auraTemplates and auraTemplates:FindFirstChild("ParticleTextures")
	local spark = textures and textures:FindFirstChild("Spark")
	return if spark and spark:IsA("StringValue") then spark.Value else ""
end

local function createBlade(name: string, angle: number, color: Color3): WedgePart
	local blade = Instance.new("WedgePart")
	blade.Name = name
	blade.Anchored = true
	blade.CanCollide = false
	blade.CanTouch = false
	blade.CanQuery = false
	blade.CastShadow = false
	blade.Material = Enum.Material.Metal
	blade.Color = color
	blade.Size = Vector3.new(0.56, 0.11, 0.78)
	blade.CFrame = CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, 0.36)
	return blade
end

local function createVisual(id: number, skinId: unknown): Model
	local palette = getPalette(skinId)
	local model = Instance.new("Model")
	model.Name = "Shuriken_" .. tostring(id)

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.CastShadow = false
	root.Transparency = 1
	root.Size = Vector3.new(0.1, 0.1, 0.1)
	root.Parent = model

	-- Les pointes decalées evitent la lecture en croix et gardent une silhouette nette en mouvement.
	for index = 0, 3 do
		local blade = createBlade("Blade" .. tostring(index + 1), math.rad(45 + (index * 90)), palette.Blade)
		blade.Parent = model
	end

	for index = 0, 3 do
		local accent = createBlade("Accent" .. tostring(index + 1), math.rad(45 + (index * 90)), palette.Accent)
		accent.Material = Enum.Material.Neon
		accent.Size = Vector3.new(0.17, 0.055, 0.43)
		accent.CFrame = CFrame.Angles(0, math.rad(45 + (index * 90)), 0) * CFrame.new(0, -0.075, 0.26)
		accent.Parent = model
	end

	local core = Instance.new("Part")
	core.Name = "ArcaneCore"
	core.Anchored = true
	core.CanCollide = false
	core.CanTouch = false
	core.CanQuery = false
	core.CastShadow = false
	core.Material = Enum.Material.Neon
	core.Color = palette.Core
	core.Shape = Enum.PartType.Ball
	core.Size = Vector3.new(0.38, 0.16, 0.38)
	core.Parent = model

	local light = Instance.new("PointLight")
	light.Color = core.Color
	light.Brightness = 0.65
	light.Range = 5
	light.Shadows = false
	light.Parent = core

	local attachment = Instance.new("Attachment")
	attachment.Parent = root
	local particles = Instance.new("ParticleEmitter")
	particles.Enabled = false
	particles.Texture = getSparkTexture()
	particles.Color = ColorSequence.new(palette.Accent, palette.Spark)
	particles.LightEmission = 0.8
	particles.Lifetime = NumberRange.new(0.16, 0.3)
	particles.Speed = NumberRange.new(0, 0.35)
	particles.SpreadAngle = Vector2.new(35, 35)
	particles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.22),
		NumberSequenceKeypoint.new(1, 0),
	})
	particles.Parent = attachment

	model.Parent = runtime
	return model
end

local function destroyVisual(id: number)
	local state = activeProjectiles[id]
	activeProjectiles[id] = nil
	if state and state.Model then state.Model:Destroy() end
end

local function spawnImpact(position: Vector3, skinId: unknown)
	local quality = VfxQualityController.GetSettings()
	local palette = getPalette(skinId)
	local burst = Instance.new("Part")
	burst.Name = "ShurikenImpact"
	burst.Anchored = true
	burst.CanCollide = false
	burst.CanTouch = false
	burst.CanQuery = false
	burst.CastShadow = false
	burst.Material = Enum.Material.Neon
	burst.Color = palette.Core
	burst.Shape = Enum.PartType.Ball
	burst.Transparency = 0.2
	burst.Size = Vector3.new(0.45, 0.45, 0.45)
	burst.CFrame = CFrame.new(position)
	burst.Parent = runtime
	local emitter = Instance.new("ParticleEmitter")
	emitter.Enabled = false
	emitter.Texture = getSparkTexture()
	emitter.Color = ColorSequence.new(burst.Color, palette.Spark)
	emitter.LightEmission = 0.8
	emitter.Lifetime = NumberRange.new(0.15, 0.28)
	emitter.Speed = NumberRange.new(4, 7)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new(0.18)
	emitter.Parent = burst
	if quality.EffectsIntensity > 0 then emitter:Emit(math.max(4, math.floor(12 * quality.EffectsIntensity))) end
	task.delay(0.14, function()
		if burst.Parent then burst:Destroy() end
	end)
end

vfxRemote.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" or payload.WeaponId ~= WEAPON_ID then return end
	local id = tonumber(payload.Id)
	if id == nil then return end

	if payload.Type == "Spawn" then
		destroyVisual(id)
		local skinId = if typeof(payload.SkinId) == "string" then payload.SkinId else "shuriken_shadowspin"
		local model = createVisual(id, skinId)
		activeProjectiles[id] = {
			Model = model,
			Position = payload.Position,
			Direction = payload.Direction,
			Speed = tonumber(payload.Speed) or 0,
			Lifetime = tonumber(payload.Lifetime) or 0,
			SkinId = skinId,
			StartedAt = tonumber(payload.ServerStartTime) or Workspace:GetServerTimeNow(),
		}
	elseif payload.Type == "Impact" then
		if typeof(payload.Position) == "Vector3" then
			local state = activeProjectiles[id]
			spawnImpact(payload.Position, state and state.SkinId or "shuriken_shadowspin")
		end
		destroyVisual(id)
	elseif payload.Type == "Destroy" then
		destroyVisual(id)
	end
end)

RunService.RenderStepped:Connect(function()
	local now = Workspace:GetServerTimeNow()
	for id, state in pairs(activeProjectiles) do
		local elapsed = now - state.StartedAt
		if elapsed >= state.Lifetime then
			destroyVisual(id)
			continue
		end
		local position = state.Position + (state.Direction * state.Speed * math.max(0, elapsed))
		state.Model:PivotTo(CFrame.lookAt(position, position + state.Direction) * CFrame.Angles(0, 0, elapsed * 23))
	end
end)

DebugLog.Info("Vfx", "Controleur VFX Shuriken demarre")
