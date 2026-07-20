--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DebugLog = require(Shared:WaitForChild("DebugLog"))
local VfxQualityController = require(script.Parent:WaitForChild("VfxQualityController"))

VfxQualityController.Start()

local visualTemplates = ReplicatedStorage:WaitForChild("VisualTemplates")
local vfxRemote = ReplicatedStorage:WaitForChild("Weapon_ZoneVfx")
local activeCasts = {}

local runtime = Workspace:FindFirstChild("ClientWeaponVfx")
if runtime == nil then
	runtime = Instance.new("Folder")
	runtime.Name = "ClientWeaponVfx"
	runtime.Parent = Workspace
end

local function configureVisual(instance: Instance)
	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.CastShadow = false
		elseif descendant:IsA("ParticleEmitter") then
			descendant.Enabled = false
		end
	end
end

local function emitDescendants(instance: Instance, multiplier: number?)
	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") then
			local count = math.max(1, math.floor((descendant:GetAttribute("BurstCount") or descendant.Rate or 1) * (multiplier or 1)))
			descendant:Emit(math.min(count, 28))
		end
	end
end

local function setDecalTransparency(instance: Instance, transparency: number)
	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("Decal") then
			descendant.Transparency = transparency
		end
	end
end

local function showCharge(payload)
	local quality = VfxQualityController.GetSettings()
	local weaponVfx = visualTemplates:FindFirstChild("WeaponVfx")
	local template = weaponVfx and weaponVfx:FindFirstChild("LeydenNeedleZone")
	if template == nil or not template:IsA("Model") then
		DebugLog.ThrottledWarn("Vfx", "leyden_template_missing", 5, "Template VFX Aiguille de Leyde introuvable")
		return
	end

	local previous = activeCasts[payload.CastId]
	if previous then previous:Destroy() end
	local visual = template:Clone()
	visual.Name = "LeydenCast_" .. tostring(payload.CastId)
	configureVisual(visual)
	visual:PivotTo(CFrame.new(payload.Center))
	visual.Parent = runtime
	activeCasts[payload.CastId] = visual

	local ring = visual:FindFirstChild("ChargeRing", true)
	if ring then
		setDecalTransparency(ring, 0.72)
		for _, descendant in ipairs(ring:GetDescendants()) do
			if descendant:IsA("Decal") then
				TweenService:Create(descendant, TweenInfo.new(payload.ChargeDuration, Enum.EasingStyle.Quad), {
					Transparency = 0.08,
				}):Play()
			end
		end
	end

	local chargeCore = visual:FindFirstChild("ChargeCore", true)
	if chargeCore and quality.EffectsIntensity > 0 then
		emitDescendants(chargeCore, 0.45 + (quality.EffectsIntensity * 0.35))
	end
	local impact = visual:FindFirstChild("Impact", true)
	if impact then setDecalTransparency(impact, 1) end
end

local function placeArc(arcTemplate: BasePart, from: Vector3, to: Vector3, parent: Instance)
	local distance = (to - from).Magnitude
	if distance <= 0.1 then return end
	local arc = arcTemplate:Clone()
	arc.Name = "BounceArc"
	arc.Size = Vector3.new(math.max(2, distance), math.max(2, distance * 0.24), 0.08)
	arc.CFrame = CFrame.lookAt((from + to) * 0.5, to) * CFrame.Angles(0, math.rad(90), 0)
	arc.Parent = parent
	task.delay(0.16, function()
		if arc.Parent then arc:Destroy() end
	end)
end

local function showImpact(payload)
	local quality = VfxQualityController.GetSettings()
	local visual = activeCasts[payload.CastId]
	if visual == nil then return end
	activeCasts[payload.CastId] = nil

	local strikes = visual:FindFirstChild("Strikes")
	if strikes then
		local children = strikes:GetChildren()
		table.sort(children, function(left, right) return left.Name < right.Name end)
		local qualityCount = if quality.EffectsIntensity <= 0
			then 1
			elseif quality.Quality == "Performance" then 2 elseif quality.Quality == "Balanced" then 4 else 5
		local visibleStrikeCount = math.min(payload.StrikeCount, qualityCount)
		for index, strike in ipairs(children) do
			if index <= visibleStrikeCount then
				task.delay((index - 1) * 0.035, function()
					if strike.Parent then
						emitDescendants(strike, math.max(0.35, quality.EffectsIntensity))
					end
				end)
			end
		end
	end

	local impact = visual:FindFirstChild("Impact", true)
	if impact then
		setDecalTransparency(impact, 0.12)
		emitDescendants(impact, 1)
	end
	local sound = visual:FindFirstChild("ImpactSound", true)
	if sound and sound:IsA("Sound") then sound:Play() end

	local arcTemplate = visual:FindFirstChild("ChainArcTemplate", true)
	if arcTemplate and arcTemplate:IsA("BasePart") then
		arcTemplate.Transparency = 1
		for _, arcData in ipairs(payload.Arcs or {}) do
			placeArc(arcTemplate, arcData.From, arcData.To, visual)
		end
	end

	task.delay(1.2, function()
		if visual.Parent then visual:Destroy() end
	end)
end

vfxRemote.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" or payload.WeaponId ~= "leyden_needle" then return end
	if payload.Type == "Charge" then
		showCharge(payload)
	elseif payload.Type == "Impact" then
		showImpact(payload)
	elseif payload.Type == "Cancel" then
		local visual = activeCasts[payload.CastId]
		activeCasts[payload.CastId] = nil
		if visual then visual:Destroy() end
	end
end)
