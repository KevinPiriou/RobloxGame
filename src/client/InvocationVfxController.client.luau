--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DebugLog = require(Shared:WaitForChild("DebugLog"))

local WEAPON_ID = "soul_lantern"
local remote = ReplicatedStorage:WaitForChild("Weapon_InvocationVfx")
assert(remote:IsA("RemoteEvent"), "Weapon_InvocationVfx doit etre un RemoteEvent")

local visualTemplates = ReplicatedStorage:WaitForChild("VisualTemplates")
local weaponVfx = visualTemplates:WaitForChild("WeaponVfx")
local summonTemplate = weaponVfx:WaitForChild("SoulLanternSummon")
local impactTemplate = weaponVfx:WaitForChild("SoulLanternImpact")

local runtime = Workspace:FindFirstChild("ClientWeaponVfx")
if runtime == nil then
	runtime = Instance.new("Folder")
	runtime.Name = "ClientWeaponVfx"
	runtime.Parent = Workspace
end

local active: {[number]: any} = {}
local WRAITH_ORBIT_RADIUS = 1.65

local function setVisualPhysics(instance: Instance)
	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.CastShadow = false
		elseif descendant:IsA("ParticleEmitter") then
			descendant.Color = ColorSequence.new(Color3.fromRGB(56, 205, 119), Color3.fromRGB(196, 255, 211))
			descendant.LightEmission = math.max(descendant.LightEmission, 0.5)
		end
	end
end

local function destroyVisual(id: number)
	local state = active[id]
	active[id] = nil
	if state and state.Model then
		state.Model:Destroy()
	end
end

local function spawnImpact(position: Vector3)
	local impact = impactTemplate:Clone()
	setVisualPhysics(impact)
	impact:PivotTo(CFrame.new(position))
	impact.Parent = runtime
	for _, descendant in ipairs(impact:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") then
			descendant:Emit(math.max(3, math.floor(descendant.Rate * 0.08)))
		end
	end
	task.delay(1.4, function()
		if impact.Parent then
			impact:Destroy()
		end
	end)
end

remote.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" or payload.WeaponId ~= WEAPON_ID then
		return
	end
	local id = tonumber(payload.Id)
	if id == nil then
		return
	end

	if payload.Type == "Spawn" and typeof(payload.Position) == "Vector3" then
		destroyVisual(id)
		local model = summonTemplate:Clone()
		setVisualPhysics(model)
		local targetPosition = if typeof(payload.TargetPosition) == "Vector3" then payload.TargetPosition else payload.Position
		model:PivotTo(CFrame.new(targetPosition - Vector3.new(0, 2.4, 0)))
		model.Parent = runtime
		active[id] = {
			Model = model,
			AnchorPosition = targetPosition,
			TargetPosition = targetPosition,
			SpawnedAt = os.clock(),
			Phase = (id * 1.618) % (math.pi * 2),
		}
	elseif payload.Type == "Update" and typeof(payload.TargetPosition) == "Vector3" then
		local state = active[id]
		if state then
			state.TargetPosition = payload.TargetPosition
		end
	elseif payload.Type == "Attack" then
		if typeof(payload.To) == "Vector3" then
			spawnImpact(payload.To)
		end
	elseif payload.Type == "Destroy" then
		destroyVisual(id)
	end
end)

RunService.RenderStepped:Connect(function(deltaTime)
	local alpha = math.clamp(deltaTime * 12, 0, 1)
	local now = os.clock()
	for _, state in pairs(active) do
		state.AnchorPosition = state.AnchorPosition:Lerp(state.TargetPosition, alpha)
		local age = now - state.SpawnedAt
		local materialize = math.clamp(age / 0.32, 0, 1)
		local angle = state.Phase + now * 1.35
		local orbit = Vector3.new(math.cos(angle), 0, math.sin(angle)) * WRAITH_ORBIT_RADIUS
		local height = -2.4 * (1 - materialize) + 1.15 + math.sin(now * 2.4 + state.Phase) * 0.16
		local position = state.AnchorPosition + orbit + Vector3.new(0, height, 0)
		state.Model:PivotTo(CFrame.lookAt(position, state.AnchorPosition + Vector3.new(0, 0.8, 0)))
	end
end)

DebugLog.Info("Vfx", "Controleur VFX Lanterne des ames demarre")
