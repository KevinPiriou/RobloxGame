--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DebugLog = require(Shared:WaitForChild("DebugLog"))
local VfxQualityController = require(script.Parent:WaitForChild("VfxQualityController"))

local vfxRemote = ReplicatedStorage:WaitForChild("Weapon_MeleeVfx")
assert(vfxRemote:IsA("RemoteEvent"), "Weapon_MeleeVfx doit etre un RemoteEvent")

VfxQualityController.Start()

local visualTemplates = ReplicatedStorage:WaitForChild("VisualTemplates")
local weaponVfx = visualTemplates:WaitForChild("WeaponVfx")
local missingProfiles: {[string]: boolean} = {}

local runtime = Workspace:FindFirstChild("ClientWeaponVfx")
if runtime == nil then
	runtime = Instance.new("Folder")
	runtime.Name = "ClientWeaponVfx"
	runtime.Parent = Workspace
end

local function prepareVisual(instance: Instance)
	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.CastShadow = false
			descendant.Transparency = 1
		elseif descendant:IsA("ParticleEmitter") then
			descendant.Enabled = false
		end
	end
end

local function emitParticles(instance: Instance, multiplier: number)
	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") then
			local burst = tonumber(descendant:GetAttribute("BurstCount")) or math.max(1, math.floor(descendant.Rate * 0.05))
			descendant:Emit(math.clamp(math.floor(burst * multiplier), 1, 24))
		end
	end
end

local function pivot(instance: Instance, cframe: CFrame)
	if instance:IsA("Model") then
		instance:PivotTo(cframe)
	elseif instance:IsA("BasePart") then
		instance.CFrame = cframe
	end
end

local function spawnImpact(impactTemplate: Instance, position: Vector3, direction: Vector3, multiplier: number)
	local impact = impactTemplate:Clone()
	prepareVisual(impact)
	pivot(impact, CFrame.lookAt(position + Vector3.new(0, 0.65, 0), position + direction + Vector3.new(0, 0.65, 0)))
	impact.Parent = runtime
	emitParticles(impact, multiplier)
	task.delay(0.65, function()
		if impact.Parent ~= nil then
			impact:Destroy()
		end
	end)
end

local function showSwing(payload)
	if typeof(payload.Origin) ~= "Vector3" or typeof(payload.Direction) ~= "Vector3" then
		return
	end

	local quality = VfxQualityController.GetSettings()
	local direction = Vector3.new(payload.Direction.X, 0, payload.Direction.Z)
	if direction.Magnitude <= 0.001 then
		return
	end
	direction = direction.Unit

	local range = math.clamp(tonumber(payload.Range) or 12, 1, 24)
	local center = payload.Origin + (direction * math.min(range * 0.48, 7.2))
	local vfxProfileId = tostring(payload.VfxProfileId or "")
	local template = weaponVfx:FindFirstChild(vfxProfileId)
	if template == nil then
		if not missingProfiles[vfxProfileId] then
			missingProfiles[vfxProfileId] = true
			DebugLog.Warn("Vfx", "Template de melee introuvable", { VfxProfileId = vfxProfileId })
		end
		return
	end
	local visual = template:Clone()
	visual.Name = vfxProfileId .. "_" .. tostring(payload.Id or 0)
	prepareVisual(visual)
	pivot(visual, CFrame.lookAt(center, center + direction))
	visual.Parent = runtime

	local intensity = math.max(0.35, tonumber(quality.EffectsIntensity) or 1)
	local sweep = visual:FindFirstChild("Sweep")
	local edge = visual:FindFirstChild("Edge")
	if sweep ~= nil then
		emitParticles(sweep, intensity)
	end
	if edge ~= nil and quality.EffectsIntensity > 0 then
		emitParticles(edge, math.max(0.5, intensity * 0.7))
	end

	local impactTemplate = visual:FindFirstChild("Impact")
	if impactTemplate ~= nil then
		local maxImpacts = if quality.Quality == "Performance" then 1 elseif quality.Quality == "Balanced" then 3 else 5
		for index, position in ipairs(payload.HitPositions or {}) do
			if index > maxImpacts or typeof(position) ~= "Vector3" then
				break
			end
			spawnImpact(impactTemplate, position, direction, math.max(0.45, intensity * 0.75))
		end
	end

	task.delay(0.82, function()
		if visual.Parent ~= nil then
			visual:Destroy()
		end
	end)
end

vfxRemote.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" or payload.Type ~= "Swing" then
		return
	end
	showSwing(payload)
end)

DebugLog.Info("Vfx", "Controleur VFX melee demarre")
