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
local LEYDEN_BASE_RADIUS = 14

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

local function scaleZonePresentation(visual: Model, center: Vector3, radius: number)
	local factor = math.max(0.25, radius / LEYDEN_BASE_RADIUS)
	local ring = visual:FindFirstChild("ChargeRing", true)
	if ring then
		for _, descendant in ipairs(ring:GetDescendants()) do
			if descendant:IsA("BasePart") then
				descendant.Size = Vector3.new(
					descendant.Size.X * factor,
					descendant.Size.Y * factor,
					descendant.Size.Z
				)
			end
		end
	end

	local strikes = visual:FindFirstChild("Strikes")
	if strikes then
		local centerCFrame = CFrame.new(center)
		for _, strike in ipairs(strikes:GetChildren()) do
			if strike:IsA("BasePart") then
				local relative = centerCFrame:ToObjectSpace(strike.CFrame)
				strike.CFrame = centerCFrame
					* CFrame.new(relative.Position.X * factor, relative.Position.Y, relative.Position.Z * factor)
					* relative.Rotation
			end
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
	scaleZonePresentation(visual, payload.Center, tonumber(payload.Radius) or LEYDEN_BASE_RADIUS)
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
end

local function addBackFace(arc: BasePart)
	local front = arc:FindFirstChildOfClass("Decal")
	if front == nil then return end
	local back = front:Clone()
	back.Face = Enum.NormalId.Back
	back.Parent = arc
end

local function fadeAndDestroyArc(arc: BasePart)
	task.delay(0.18, function()
		if arc.Parent == nil then return end
		for _, descendant in ipairs(arc:GetDescendants()) do
			if descendant:IsA("Decal") then
				TweenService:Create(descendant, TweenInfo.new(0.14, Enum.EasingStyle.Quad), {
					Transparency = 1,
				}):Play()
			end
		end
	end)
	task.delay(0.34, function()
		if arc.Parent then arc:Destroy() end
	end)
end

local function placeArc(arcTemplate: BasePart, from: Vector3, to: Vector3, parent: Instance)
	local raisedFrom = from + Vector3.new(0, 2.2, 0)
	local raisedTo = to + Vector3.new(0, 2.2, 0)
	local delta = raisedTo - raisedFrom
	local distance = delta.Magnitude
	if distance <= 0.1 then return end

	local direction = delta.Unit
	local referenceUp = if math.abs(direction:Dot(Vector3.yAxis)) > 0.95 then Vector3.xAxis else Vector3.yAxis
	local backVector = direction:Cross(referenceUp).Unit
	local upVector = backVector:Cross(direction).Unit
	local baseCFrame = CFrame.fromMatrix((raisedFrom + raisedTo) * 0.5, direction, upVector, backVector)

	for planeIndex = 1, 2 do
		local arc = arcTemplate:Clone()
		arc.Name = "BounceArc"
		arc.Size = Vector3.new(distance, math.clamp(distance * 0.2, 2.8, 5.5), 0.08)
		arc.CFrame = baseCFrame * CFrame.Angles(math.rad((planeIndex - 1) * 90), 0, 0)
		addBackFace(arc)
		arc.Parent = parent
		fadeAndDestroyArc(arc)
	end
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
