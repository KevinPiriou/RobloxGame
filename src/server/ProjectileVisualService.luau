local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))
local DebugLog = require(Shared:WaitForChild("DebugLog"))
local WeaponSkinConfig = require(Shared:WaitForChild("WeaponSkinConfig"))

local ProjectileVisualService = {}
local impactPoolFolder = nil
local impactSerial = 0

local function getOrCreateFolder(parent, folderName)
	local folder = parent:FindFirstChild(folderName)

	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = folderName
		folder.Parent = parent
	end

	return folder
end

local function findFireballSkin(skinId)
	local weapon = WeaponSkinConfig.Weapons.fireball
	local requestedId = skinId or weapon.DefaultSkinId

	for _, skin in ipairs(weapon.Skins) do
		if skin.Id == requestedId then
			return skin
		end
	end

	return weapon.Skins[1]
end

local function colorSequence(firstColor, secondColor)
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, firstColor),
		ColorSequenceKeypoint.new(1, secondColor),
	})
end

local function getOrCreateAttachment(root, name, position)
	local attachment = root:FindFirstChild(name)

	if attachment == nil then
		attachment = Instance.new("Attachment")
		attachment.Name = name
		attachment.Parent = root
	end

	if attachment:IsA("Attachment") then
		attachment.Position = position
		return attachment
	end

	return nil
end

local function getOrCreateTrail(root)
	local front = getOrCreateAttachment(root, "MegaRobloxTrailFront", Vector3.new(0, 0, 0.42))
	local back = getOrCreateAttachment(root, "MegaRobloxTrailBack", Vector3.new(0, 0, -0.72))

	if front == nil or back == nil then
		return nil
	end

	local trail = root:FindFirstChild("MegaRobloxFireballTrail")

	if trail == nil then
		trail = Instance.new("Trail")
		trail.Name = "MegaRobloxFireballTrail"
		trail.Parent = root
	end

	if trail:IsA("Trail") then
		trail.Attachment0 = front
		trail.Attachment1 = back
		trail.FaceCamera = true
		trail.LightEmission = 1
		trail.MinLength = 0.05
		return trail
	end

	return nil
end

local function getOrCreateLight(root)
	local light = root:FindFirstChild("MegaRobloxCoreLight")

	if light == nil then
		light = Instance.new("PointLight")
		light.Name = "MegaRobloxCoreLight"
		light.Shadows = false
		light.Parent = root
	end

	if light:IsA("PointLight") then
		return light
	end

	return nil
end

local function getImpactPoolFolder()
	if impactPoolFolder == nil then
		impactPoolFolder = getOrCreateFolder(ServerStorage, "ProjectileImpactPool")
	end

	return impactPoolFolder
end

local function createImpactPart()
	local impact = Instance.new("Part")
	impact.Name = "FireballImpact"
	impact.Shape = Enum.PartType.Ball
	impact.Material = Enum.Material.Neon
	impact.Anchored = true
	impact.CanCollide = false
	impact.CanTouch = false
	impact.CanQuery = false
	impact.CastShadow = false

	local light = Instance.new("PointLight")
	light.Name = "ImpactLight"
	light.Shadows = false
	light.Parent = impact

	return impact
end

local function acquireImpactPart()
	local pool = getImpactPoolFolder()
	local impact = pool:FindFirstChild("FireballImpact")

	if impact ~= nil and impact:IsA("BasePart") then
		return impact
	end

	return createImpactPart()
end

local function releaseImpactPart(impact, serial)
	if impact:GetAttribute("ImpactSerial") ~= serial then
		return
	end

	impact.Transparency = 1
	impact.Parent = getImpactPoolFolder()
end

local function configureParticleEmitter(emitter, visual)
	local lowerName = string.lower(emitter.Name)

	if string.find(lowerName, "fire", 1, true) then
		emitter.Enabled = true
		emitter.Color = colorSequence(visual.AccentColor, visual.CoreColor)
		emitter.LightEmission = 1
		emitter.Rate = visual.FireRate
		emitter.Lifetime = NumberRange.new(0.18, 0.34)
		emitter.Speed = NumberRange.new(0.5, 1.8)
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.78),
			NumberSequenceKeypoint.new(1, 0.06),
		})
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.12),
			NumberSequenceKeypoint.new(1, 1),
		})
	elseif string.find(lowerName, "smoke", 1, true) then
		emitter.Enabled = true
		emitter.Color = colorSequence(visual.CoreColor, visual.SmokeColor)
		emitter.LightEmission = 0.18
		emitter.Rate = visual.SmokeRate
		emitter.Lifetime = NumberRange.new(0.24, 0.46)
		emitter.Speed = NumberRange.new(0.5, 1.3)
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.5),
			NumberSequenceKeypoint.new(1, 1.2),
		})
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.58),
			NumberSequenceKeypoint.new(1, 1),
		})
	elseif string.find(lowerName, "spark", 1, true) then
		emitter.Enabled = true
		emitter.Color = colorSequence(visual.AccentColor, visual.CoreColor)
		emitter.LightEmission = 1
		emitter.Rate = visual.SparkleRate
		emitter.Lifetime = NumberRange.new(0.12, 0.25)
		emitter.Speed = NumberRange.new(0.4, 1.1)
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.22),
			NumberSequenceKeypoint.new(1, 0),
		})
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.08),
			NumberSequenceKeypoint.new(1, 1),
		})
	end
end

local function configureLegacyEffect(effect, visual)
	if effect:IsA("Fire") then
		effect.Enabled = true
		effect.Color = visual.CoreColor
		effect.SecondaryColor = visual.AccentColor
		effect.Size = 3.5
		effect.Heat = 4
	elseif effect:IsA("Smoke") then
		effect.Enabled = true
		effect.Color = visual.SmokeColor
		effect.Opacity = 0.32
		effect.Size = 2.2
		effect.RiseVelocity = 2
	elseif effect:IsA("Sparkles") then
		effect.Enabled = true
		effect.SparkleColor = visual.AccentColor
	end
end

function ProjectileVisualService.ApplyFireballSkin(projectile, root, skinId)
	if projectile == nil or root == nil then
		return
	end

	local skin = findFireballSkin(skinId)
	local visual = skin.Visual

	if visual == nil then
		return
	end

	if projectile:GetAttribute("ProjectileSkinId") == skin.Id then
		return
	end

	root.Material = Enum.Material.Neon
	root.Color = visual.CoreColor
	root.Transparency = visual.CoreTransparency

	local light = getOrCreateLight(root)

	if light ~= nil then
		light.Color = visual.AccentColor
		light.Brightness = visual.LightBrightness
		light.Range = visual.LightRange
	end

	local trail = getOrCreateTrail(root)

	if trail ~= nil then
		trail.Color = colorSequence(visual.AccentColor, visual.TrailColor)
		trail.Lifetime = visual.TrailLifetime
		trail.WidthScale = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.72),
			NumberSequenceKeypoint.new(0.45, 0.36),
			NumberSequenceKeypoint.new(1, 0),
		})
		trail.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.08),
			NumberSequenceKeypoint.new(0.7, 0.48),
			NumberSequenceKeypoint.new(1, 1),
		})
	end

	for _, descendant in ipairs(projectile:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") then
			configureParticleEmitter(descendant, visual)
		elseif descendant:IsA("Fire") or descendant:IsA("Smoke") or descendant:IsA("Sparkles") then
			configureLegacyEffect(descendant, visual)
		end
	end

	projectile:SetAttribute("ProjectileSkinId", skin.Id)
	DebugLog.ThrottledInfo("Weapon", "fireball_visual_" .. skin.Id, 3, "Visuel Fireball applique", {
		Skin = skin.Id,
		Projectile = projectile,
	})
end

function ProjectileVisualService.PlayFireballImpact(projectile, position, parent)
	if projectile == nil or parent == nil or typeof(position) ~= "Vector3" then
		return
	end

	local skin = findFireballSkin(projectile:GetAttribute("ProjectileSkinId"))
	local visual = skin.Visual
	local impact = acquireImpactPart()
	impactSerial += 1

	local serial = impactSerial
	local startSize = CombatConfig.FireballImpactStartSize or 0.7
	local endSize = CombatConfig.FireballImpactEndSize or 3
	local lifetime = CombatConfig.FireballImpactLifetime or 0.16

	impact:SetAttribute("ImpactSerial", serial)
	impact.CFrame = CFrame.new(position)
	impact.Size = Vector3.new(startSize, startSize, startSize)
	impact.Color = visual.AccentColor
	impact.Transparency = 0.24
	impact.Parent = parent

	local light = impact:FindFirstChild("ImpactLight")

	if light ~= nil and light:IsA("PointLight") then
		light.Color = visual.AccentColor
		light.Brightness = 1.5
		light.Range = endSize * 2
	end

	local tween = TweenService:Create(impact, TweenInfo.new(lifetime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(endSize, endSize, endSize),
		Transparency = 1,
	})
	tween:Play()

	task.delay(lifetime, function()
		releaseImpactPart(impact, serial)
	end)
end

return ProjectileVisualService
