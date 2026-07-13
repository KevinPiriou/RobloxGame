-- Auras locales de build. Elles lisent uniquement les statistiques deja validees par le serveur.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local AuraConfig = require(Shared:WaitForChild("AuraConfig"))
local DebugLog = require(Shared:WaitForChild("DebugLog"))

local VfxQualityController = require(script.Parent:WaitForChild("VfxQualityController"))

VfxQualityController.Start()

local isRunActive = player:GetAttribute("IsRunActive") == true
local latestStats = {}
local textureIds = {}
local missingTextures = {}
local runtimeFolder = nil
local packagesByFamilyId = {}
local lastActiveSignature = ""

local function getTextureId(textureName, fallbackTextureName)
	if textureIds[textureName] ~= nil then
		return textureIds[textureName]
	end

	local visualTemplates = ReplicatedStorage:FindFirstChild(AuraConfig.VisualTemplatesFolderName)
	local auraTemplates = if visualTemplates ~= nil then visualTemplates:FindFirstChild(AuraConfig.AuraTemplatesFolderName) else nil
	-- Les nouvelles textures VFX vivent directement dans VisualTemplates. L'ancien
	-- dossier AuraTemplates reste lu pour ne pas casser les assets deja importes.
	local particleTextures = if visualTemplates ~= nil then visualTemplates:FindFirstChild(AuraConfig.ParticleTexturesFolderName) else nil

	if particleTextures == nil and auraTemplates ~= nil then
		particleTextures = auraTemplates:FindFirstChild(AuraConfig.ParticleTexturesFolderName)
	end
	local textureValue = if particleTextures ~= nil then particleTextures:FindFirstChild(textureName) else nil

	if textureValue ~= nil and textureValue:IsA("StringValue") and textureValue.Value ~= "" then
		textureIds[textureName] = textureValue.Value
		return textureValue.Value
	end

	local builtinTextureId = AuraConfig.BuiltinTextureIds[textureName]

	if builtinTextureId ~= nil and builtinTextureId ~= "" then
		textureIds[textureName] = builtinTextureId
		return builtinTextureId
	end

	if not missingTextures[textureName] then
		missingTextures[textureName] = true
		DebugLog.Warn("Aura", "Texture d'aura introuvable, fallback utilise", {
			Texture = textureName,
			Fallback = fallbackTextureName,
			ExpectedPath = "ReplicatedStorage/VisualTemplates/ParticleTextures",
		})
	end

	if fallbackTextureName ~= nil then
		return getTextureId(fallbackTextureName)
	end

	return nil
end

local function findFirstPart(character, names)
	for _, name in ipairs(names) do
		local candidate = character:FindFirstChild(name)

		if candidate ~= nil and candidate:IsA("BasePart") then
			return candidate
		end
	end

	return character:FindFirstChild("HumanoidRootPart")
end

local function getPartsForStyle(character, style)
	local function getBodyParts(names)
		local parts = {}
		local seen = {}

		for _, name in ipairs(names) do
			local part = findFirstPart(character, { name })

			if part ~= nil and not seen[part] then
				seen[part] = true
				table.insert(parts, part)
			end
		end

		return parts
	end

	if style == "Feet" then
		return {
			findFirstPart(character, { "LeftFoot", "LeftLowerLeg", "Left Leg" }),
			findFirstPart(character, { "RightFoot", "RightLowerLeg", "Right Leg" }),
		}
	elseif style == "Hands" then
		return {
			findFirstPart(character, { "LeftHand", "LeftLowerArm", "Left Arm" }),
			findFirstPart(character, { "RightHand", "RightLowerArm", "Right Arm" }),
		}
	elseif style == "Head" then
		return {
			findFirstPart(character, { "Head", "UpperTorso", "Torso" }),
		}
	elseif style == "BodyFlame" then
		return getBodyParts({
			"UpperTorso",
			"LowerTorso",
			"LeftUpperArm",
			"RightUpperArm",
			"LeftUpperLeg",
			"RightUpperLeg",
		})
	elseif style == "Armor" or style == "Sustain" then
		return getBodyParts({
			"UpperTorso",
			"LeftUpperArm",
			"RightUpperArm",
		})
	end

	return {
		findFirstPart(character, { "UpperTorso", "Torso", "HumanoidRootPart" }),
	}
end

local function getContourOffsets(part)
	local halfWidth = math.max(0.18, part.Size.X * 0.42)
	local halfHeight = math.max(0.18, part.Size.Y * 0.38)
	local isTorso = part.Name == "UpperTorso" or part.Name == "LowerTorso" or part.Name == "Torso"

	if isTorso then
		return {
			Vector3.new(-halfWidth, 0, 0),
			Vector3.new(halfWidth, 0, 0),
			Vector3.new(0, halfHeight, 0),
		}
	end

	return {
		Vector3.new(-halfWidth, 0, 0),
		Vector3.new(halfWidth, 0, 0),
	}
end

local function numberSequence(startValue, endValue)
	return NumberSequence.new({
		NumberSequenceKeypoint.new(0, startValue),
		NumberSequenceKeypoint.new(1, endValue),
	})
end

local function createAttachment(parent, name, position, package)
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.Position = position or Vector3.zero
	attachment.Parent = parent

	if package ~= nil then
		table.insert(package.Attachments, attachment)
	end

	return attachment
end

local function createEmitter(parent, name)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = name
	emitter.LockedToPart = true
	emitter.VelocityInheritance = 0
	emitter.LightInfluence = 0
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-18, 18)
	emitter.SpreadAngle = Vector2.new(18, 18)
	emitter.Enabled = false
	emitter.Parent = parent
	return emitter
end

local function getScoreForFamily(family, stats)
	local score = 0

	for _, rule in ipairs(family.Stats) do
		local rawValue = math.max(0, tonumber(stats[rule.Name]) or 0)
		local normalizedValue = math.clamp(rawValue / rule.Saturation, 0, 1)
		score += normalizedValue * rule.Weight
	end

	return math.clamp(score, 0, 1)
end

local function getEffectColor(family, stats)
	if family.Style ~= "Sustain" or family.SecondaryColor == nil then
		return family.Color
	end

	local regenWeight = 0
	local lifeStealWeight = 0

	for _, rule in ipairs(family.Stats) do
		local normalizedValue = math.clamp((tonumber(stats[rule.Name]) or 0) / rule.Saturation, 0, 1)

		if rule.Name == "HealthRegen" then
			regenWeight = normalizedValue
		elseif rule.Name == "LifeStealPercent" then
			lifeStealWeight = normalizedValue
		end
	end

	if regenWeight + lifeStealWeight <= 0 then
		return family.Color
	end

	return family.Color:Lerp(family.SecondaryColor, lifeStealWeight / (regenWeight + lifeStealWeight))
end

local function getTier(score)
	local thresholds = AuraConfig.TierThresholds

	if score >= thresholds[3] then
		return 3
	elseif score >= thresholds[2] then
		return 2
	elseif score >= thresholds[1] then
		return 1
	end

	return 0
end

local function getDominantFamilies(maxFamilies)
	local families = {}

	for familyId, family in pairs(AuraConfig.Families) do
		local score = getScoreForFamily(family, latestStats)
		local tier = getTier(score)

		if tier > 0 then
			table.insert(families, {
				Id = familyId,
				Definition = family,
				Score = score,
				Tier = tier,
			})
		end
	end

	table.sort(families, function(left, right)
		if left.Score == right.Score then
			return left.Id < right.Id
		end

		return left.Score > right.Score
	end)

	while #families > maxFamilies do
		table.remove(families)
	end

	return families
end

local function getRuntimeFolder(character)
	if runtimeFolder ~= nil and runtimeFolder.Parent == character then
		return runtimeFolder
	end

	runtimeFolder = Instance.new("Folder")
	runtimeFolder.Name = AuraConfig.RuntimeFolderName
	runtimeFolder.Parent = character
	packagesByFamilyId = {}
	return runtimeFolder
end

local function addEmitterDescriptor(package, parent, name, textureId, configure)
	if textureId == nil then
		return
	end

	local emitter = createEmitter(parent, name)
	table.insert(package.Descriptors, {
		Emitter = emitter,
		TextureId = textureId,
		Configure = configure,
	})
end

local function addContourDescriptors(package, part, familyId, partIndex, textureId, configure)
	for contourIndex, offset in ipairs(getContourOffsets(part)) do
		local attachment = createAttachment(
			part,
			"Aura_" .. familyId .. "_" .. tostring(partIndex) .. "_" .. tostring(contourIndex),
			offset,
			package
		)
		addEmitterDescriptor(package, attachment, "Contour", textureId, configure)
	end
end

local function createFamilyPackage(character, familyData)
	local familyId = familyData.Id
	local definition = familyData.Definition
	local folder = Instance.new("Folder")
	folder.Name = "AuraFamily_" .. familyId
	folder.Parent = getRuntimeFolder(character)

	local package = {
		Id = familyId,
		Definition = definition,
		Folder = folder,
		Descriptors = {},
		Attachments = {},
		Highlight = nil,
		Active = false,
	}
	local primaryTexture = getTextureId(definition.PrimaryTexture, definition.FallbackPrimaryTexture)
	local secondaryTexture = getTextureId(definition.SecondaryTexture, definition.FallbackSecondaryTexture)
	local parts = getPartsForStyle(character, definition.Style)

	for index, part in ipairs(parts) do
		if part == nil or not part:IsA("BasePart") then
			continue
		end

		if definition.Style == "BodyFlame" then
			addContourDescriptors(package, part, familyId, index, primaryTexture, function(context)
				return {
					Rate = 0.8 + (2.2 * context.EffectScale),
					Lifetime = 0.62,
					Speed = 0.62,
					StartSize = 0.9 * context.SizeScale,
					EndSize = 0.08,
					Transparency = 0.44,
				}
			end)
		elseif definition.Style == "Armor" then
			addContourDescriptors(package, part, familyId, index, primaryTexture, function(context)
				return {
					Rate = 0.55 + (1.65 * context.EffectScale),
					Lifetime = 0.7,
					Speed = 0.4,
					StartSize = 0.82 * context.SizeScale,
					EndSize = 0.08,
					Transparency = 0.58,
				}
			end)
		elseif definition.Style == "Sustain" then
			addContourDescriptors(package, part, familyId, index, primaryTexture, function(context)
				return {
					Rate = 0.65 + (1.7 * context.EffectScale),
					Lifetime = 0.82,
					Speed = 0.35,
					StartSize = 0.9 * context.SizeScale,
					EndSize = 0.1,
					Transparency = 0.6,
				}
			end)
		else
			local attachment = createAttachment(part, "Aura_" .. familyId .. "_" .. tostring(index), nil, package)

			if definition.Style == "Feet" then
				attachment.Position = Vector3.new(0, -0.35, 0)
				addEmitterDescriptor(package, attachment, "Wind", primaryTexture, function(context)
					return { Rate = 5 + (11 * context.EffectScale), Lifetime = 0.42, Speed = 2, StartSize = 0.72 * context.SizeScale, EndSize = 0.08, Transparency = 0.4 }
				end)
				addEmitterDescriptor(package, attachment, "Glow", secondaryTexture, function(context)
					return { Rate = 1 + (3 * context.EffectScale), Lifetime = 0.54, Speed = 0.45, StartSize = 0.9 * context.SizeScale, EndSize = 0.06, Transparency = 0.62 }
				end)
			elseif definition.Style == "Hands" then
				addEmitterDescriptor(package, attachment, "Spark", primaryTexture, function(context)
					return { Rate = 2 + (6 * context.EffectScale), Lifetime = 0.38, Speed = 0.6, StartSize = 0.18 * context.SizeScale, EndSize = 0, Transparency = 0.48 }
				end)
				addEmitterDescriptor(package, attachment, "Wind", secondaryTexture, function(context)
					return { Rate = 1 + (3 * context.EffectScale), Lifetime = 0.5, Speed = 0.55, StartSize = 0.58 * context.SizeScale, EndSize = 0.04, Transparency = 0.68 }
				end)
			elseif definition.Style == "Head" then
				attachment.Position = Vector3.new(0, 0.55, 0)
				addEmitterDescriptor(package, attachment, "Glyph", primaryTexture, function(context)
					return { Rate = 0.6 + (1.8 * context.EffectScale), Lifetime = 1.1, Speed = 0.35, StartSize = 0.7 * context.SizeScale, EndSize = 0.1, Transparency = 0.52 }
				end)
				addEmitterDescriptor(package, attachment, "Spark", secondaryTexture, function(context)
					return { Rate = 2 + (6 * context.EffectScale), Lifetime = 0.75, Speed = 0.8, StartSize = 0.2 * context.SizeScale, EndSize = 0, Transparency = 0.48 }
				end)
			elseif definition.Style == "Orbit" then
				addEmitterDescriptor(package, attachment, "Glyph", primaryTexture, function(context)
					return { Rate = 0.8 + (2.2 * context.EffectScale), Lifetime = 1.25, Speed = 1.2, StartSize = 0.75 * context.SizeScale, EndSize = 0.1, Transparency = 0.46 }
				end)
				addEmitterDescriptor(package, attachment, "Spark", secondaryTexture, function(context)
					return { Rate = 2 + (6 * context.EffectScale), Lifetime = 0.85, Speed = 1.3, StartSize = 0.2 * context.SizeScale, EndSize = 0, Transparency = 0.46 }
				end)
			elseif definition.Style == "Magnetism" then
				attachment.Position = Vector3.new(0, -0.8, 0)
				addEmitterDescriptor(package, attachment, "Glyph", primaryTexture, function(context)
					return { Rate = 1 + (3 * context.EffectScale), Lifetime = 1, Speed = 0.35, StartSize = 0.76 * context.SizeScale, EndSize = 0.08, Transparency = 0.48 }
				end)
				addEmitterDescriptor(package, attachment, "Spark", secondaryTexture, function(context)
					return { Rate = 2 + (6 * context.EffectScale), Lifetime = 0.72, Speed = 0.42, StartSize = 0.22 * context.SizeScale, EndSize = 0, Transparency = 0.5 }
				end)
			end
		end
	end

	local primaryPart = parts[1]

	if primaryPart ~= nil and primaryPart:IsA("BasePart") then
		local attachment = createAttachment(primaryPart, "Aura_" .. familyId .. "_Special", nil, package)

		if definition.Style == "BodyFlame" then
			addEmitterDescriptor(package, attachment, "Spark", secondaryTexture, function(context)
				return { Rate = 1.5 + (4 * context.EffectScale), Lifetime = 0.52, Speed = 0.5, StartSize = 0.18 * context.SizeScale, EndSize = 0, Transparency = 0.46 }
			end)
		elseif definition.Style == "Armor" then
			addEmitterDescriptor(package, attachment, "Shield", secondaryTexture, function(context)
				return { Rate = 0.7 + (1.8 * context.EffectScale), Lifetime = 0.95, Speed = 0.2, StartSize = 1.15 * context.SizeScale, EndSize = 0.16, Transparency = 0.5 }
			end)
		elseif definition.Style == "Sustain" then
			attachment.Position = Vector3.new(0, 0.15, 0)
			addEmitterDescriptor(package, attachment, "Pulse", secondaryTexture, function(context)
				return { Rate = 0.7 + (2 * context.EffectScale), Lifetime = 0.86, Speed = 0.2, StartSize = 0.95 * context.SizeScale, EndSize = 0.12, Transparency = 0.58 }
			end)
		end
	end

	if definition.Style == "Armor" then
		local highlight = Instance.new("Highlight")
		highlight.Name = "ArmorHighlight"
		highlight.Adornee = character
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.Enabled = false
		highlight.Parent = folder
		package.Highlight = highlight
	end

	packagesByFamilyId[familyId] = package
	return package
end

local function setEmitterState(descriptor, context)
	local emitter = descriptor.Emitter
	local values = descriptor.Configure(context)
	local rate = values.Rate * context.DecorativeScale

	emitter.Texture = descriptor.TextureId
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, context.BrightColor),
		ColorSequenceKeypoint.new(1, context.DeepColor),
	})
	emitter.LightEmission = 0.42
	emitter.Rate = rate
	emitter.Lifetime = NumberRange.new(values.Lifetime * 0.8, values.Lifetime)
	emitter.Speed = NumberRange.new(math.max(0.03, values.Speed * 0.08), math.max(0.06, values.Speed * 0.14))
	emitter.Acceleration = Vector3.new(0, math.min(0.65, values.Speed * 0.14), 0)
	emitter.Drag = 3
	emitter.Size = numberSequence(values.StartSize, values.EndSize)
	emitter.Transparency = numberSequence(values.Transparency, 1)
	emitter.Enabled = context.Active and rate > 0.01

	if not emitter.Enabled then
		emitter:Clear()
	end
end

local function applyPackage(package, familyData, settings)
	local definition = familyData.Definition
	local tierScale = AuraConfig.TierScales[familyData.Tier] or 1
	local intensity = math.clamp(familyData.Score, AuraConfig.MinimumScore, 1)
	local effectScale = tierScale * (0.55 + (0.45 * intensity))
	local effectColor = getEffectColor(definition, latestStats)
	local decorativeScale = settings.EffectsIntensity * settings.Profile.AuraLayerMultiplier
	local context = {
		Active = decorativeScale >= 0.08,
		DecorativeScale = decorativeScale,
		EffectScale = effectScale,
		SizeScale = effectScale * AuraConfig.NativeSizeMultiplier,
		BrightColor = effectColor:Lerp(Color3.new(1, 1, 1), 0.07),
		DeepColor = effectColor:Lerp(Color3.new(0, 0, 0), 0.06),
	}

	for _, descriptor in ipairs(package.Descriptors) do
		setEmitterState(descriptor, context)
	end

	if package.Highlight ~= nil then
		package.Highlight.Enabled = context.Active
		package.Highlight.FillColor = effectColor
		package.Highlight.FillTransparency = math.clamp(0.95 - (intensity * 0.16), 0.72, 0.93)
		package.Highlight.OutlineColor = Color3.fromRGB(222, 244, 255)
		package.Highlight.OutlineTransparency = 0.96
	end

	package.Active = true
	package.Tier = familyData.Tier
end

local function disablePackage(package)
	if package == nil or not package.Active then
		return
	end

	for _, descriptor in ipairs(package.Descriptors) do
		descriptor.Emitter.Enabled = false
		descriptor.Emitter:Clear()
	end

	if package.Highlight ~= nil then
		package.Highlight.Enabled = false
	end

	package.Active = false
end

local function clearRuntime()
	for _, package in pairs(packagesByFamilyId) do
		for _, attachment in ipairs(package.Attachments) do
			attachment:Destroy()
		end
	end

	if runtimeFolder ~= nil then
		runtimeFolder:Destroy()
	end

	runtimeFolder = nil
	packagesByFamilyId = {}
	lastActiveSignature = ""
end

local function refreshAuras()
	local character = player.Character

	if character == nil or not isRunActive then
		clearRuntime()
		return
	end

	local settings = VfxQualityController.GetSettings()
	local dominantFamilies = getDominantFamilies(settings.Profile.AuraFamilyLimit)
	local activeIds = {}
	local signatureParts = {}
	local packageCount = 0

	for _, familyData in ipairs(dominantFamilies) do
		activeIds[familyData.Id] = true
		local package = packagesByFamilyId[familyData.Id] or createFamilyPackage(character, familyData)
		applyPackage(package, familyData, settings)
		table.insert(signatureParts, familyData.Id .. ":" .. tostring(familyData.Tier))
	end

	for familyId, package in pairs(packagesByFamilyId) do
		packageCount += 1

		if not activeIds[familyId] then
			disablePackage(package)
		end
	end

	local signature = table.concat(signatureParts, "|")

	if signature ~= lastActiveSignature then
		lastActiveSignature = signature
		DebugLog.Info("Aura", "Auras visuelles appliquees", {
			Player = player.Name,
			Families = signature,
			Quality = settings.Quality,
		})
	end

	DebugLog.ThrottledInfo("Vfx", "aura_budget", 5, "Budget auras applique", {
		Active = #dominantFamilies,
		Families = settings.Profile.AuraFamilyLimit,
		Packages = packageCount,
		Quality = settings.Quality,
	})
end

ReplicatedStorage:WaitForChild("Perk_UpdateStats").OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" or typeof(payload.Stats) ~= "table" then
		return
	end

	latestStats = payload.Stats
	refreshAuras()
end)

ReplicatedStorage:WaitForChild("Run_StateUpdate").OnClientEvent:Connect(function(payload)
	isRunActive = typeof(payload) == "table" and payload.IsRunActive == true
	refreshAuras()
end)

player:GetAttributeChangedSignal("IsRunActive"):Connect(function()
	isRunActive = player:GetAttribute("IsRunActive") == true
	refreshAuras()
end)

player.CharacterAdded:Connect(function(character)
	clearRuntime()
	task.defer(function()
		character:WaitForChild("HumanoidRootPart", 5)
		refreshAuras()
	end)
end)

VfxQualityController.Changed.Event:Connect(refreshAuras)

DebugLog.Info("Aura", "AuraController client initialise", {
	Player = player.Name,
})
