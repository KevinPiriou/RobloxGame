local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DebugLog = require(Shared:WaitForChild("DebugLog"))
local PerkConfig = require(Shared:WaitForChild("PerkConfig"))
local PerkIconConfig = require(Shared:WaitForChild("PerkIconConfig"))
local UiTemplateConfig = require(Shared:WaitForChild("UiTemplateConfig"))

local showChoicesRemote = ReplicatedStorage:WaitForChild("Perk_ShowChoices")
local hideChoicesRemote = ReplicatedStorage:WaitForChild("Perk_HideChoices")
local selectChoiceRemote = ReplicatedStorage:WaitForChild("Perk_SelectChoice")
local rerollChoiceRemote = ReplicatedStorage:WaitForChild("Perk_RerollRequest")
local passChoiceRemote = ReplicatedStorage:WaitForChild("Perk_PassRequest")
local banChoiceRemote = ReplicatedStorage:WaitForChild("Perk_BanRequest")

local PRODUCTION_TEMPLATE_GUI_NAME = UiTemplateConfig.ProductionTemplateGuiName
local V2_GUI_NAME = "PerkChoiceV2"

local HOVER_TWEEN = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local SELECT_TWEEN = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local REFRESH_ACTION_LABEL = "RAFRAICHIR"
local AURA_PARTICLES_BY_RARITY = {
	Common = 12,
	Rare = 16,
	Epic = 20,
	Legendary = 24,
}
local SHEEN_TRANSPARENCY_BY_RARITY = {
	Common = 0.46,
	Rare = 0.36,
	Epic = 0.26,
	Legendary = 0.18,
}
local MAX_AURA_PARTICLES = 24
local randomizer = Random.new()

-- Les cartes exposent une vue strictement visuelle des statistiques affectees.
-- Les valeurs viennent de l'option envoyee par le serveur ; elles ne pilotent
-- jamais le calcul ou l'application du perk.
local STAT_PREVIEW_ROWS_BY_STAT = {
	MaxHealthBonus = { "MaxHealth" },
	HealthRegen = { "HealthRegen" },
	Shield = { "Shield" },
	ArmorPercent = { "Armor" },
	LifeStealPercent = { "LifeSteal" },
	DamagePercent = { "BaseDamage", "EliteDamage" },
	FlatDamage = { "BaseDamage" },
	EliteFlatDamage = { "EliteDamage" },
	AttackSpeedPercent = { "AttackRate" },
	ProjectileCount = { "ProjectileCount" },
	BounceCount = { "BounceCount" },
	CritChance = { "CritChance" },
	CritMultiplierBonus = { "CritDamage" },
	ProjectileSpeedPercent = { "ProjectileSpeed" },
	EffectDurationPercent = { "ProjectileDuration" },
	MoveSpeedPercent = { "MoveSpeed" },
	JumpPercent = { "Jump" },
	CollectRadius = { "CollectRadius" },
	XpGainPercent = { "XpMultiplier" },
	GoldGainPercent = { "GoldMultiplier" },
	Luck = { "Luck" },
	EnemyCountPercent = { "EnemyMultiplier" },
}

local VISUAL_IMPACT_BY_STAT = {
	MaxHealthBonus = 20,
	HealthRegen = 0.2,
	Shield = 5,
	ArmorPercent = 0.05,
	LifeStealPercent = 0.05,
	DamagePercent = 0.1,
	FlatDamage = 1,
	EliteFlatDamage = 1,
	AttackSpeedPercent = 0.1,
	ProjectileCount = 1,
	BounceCount = 1,
	CritChance = 0.05,
	CritMultiplierBonus = 0.25,
	ProjectileSpeedPercent = 0.1,
	EffectDurationPercent = 0.1,
	MoveSpeedPercent = 0.05,
	JumpPercent = 0.1,
	CollectRadius = 4,
	XpGainPercent = 0.1,
	GoldGainPercent = 0.1,
	Luck = 0.05,
	EnemyCountPercent = 0.1,
}

local RARITY_IMPACT_FLOOR = {
	Common = 1,
	Rare = 2,
	Epic = 2,
	Legendary = 3,
}

local function findPath(root, names)
	local current = root

	for _, name in ipairs(names) do
		current = current:FindFirstChild(name)

		if current == nil then
			return nil
		end
	end

	return current
end

local function asTextLabel(instance)
	if instance and instance:IsA("TextLabel") then
		return instance
	end

	return nil
end

local function asFrame(instance)
	if instance and instance:IsA("Frame") then
		return instance
	end

	return nil
end

local function asButton(instance)
	if instance and instance:IsA("TextButton") then
		return instance
	end

	return nil
end

local function asImageLabel(instance)
	if instance and instance:IsA("ImageLabel") then
		return instance
	end

	return nil
end

local function setText(instance, value)
	local label = asTextLabel(instance)

	if label then
		label.Text = tostring(value or "")
	end
end

local function tween(instance, info, properties)
	if instance == nil then
		return
	end

	TweenService:Create(instance, info, properties):Play()
end

local function initialise()
	local templateGui = playerGui:WaitForChild(PRODUCTION_TEMPLATE_GUI_NAME, 30)
	local legacyGui = playerGui:WaitForChild("PerkChoiceGui", 30)

	if templateGui == nil or not templateGui:IsA("ScreenGui") or legacyGui == nil or not legacyGui:IsA("ScreenGui") then
		DebugLog.Warn("UI", "Choix de perk V2 non active, snapshot ou rail historique introuvable", {
			HasProductionTemplate = templateGui ~= nil,
			HasLegacyGui = legacyGui ~= nil,
		})
		return
	end

	local runCanvas = templateGui:FindFirstChild("RunCanvas")
	local template = runCanvas and runCanvas:FindFirstChild("PerkChoiceDock")

	if template == nil or not template:IsA("Frame") then
		DebugLog.Warn("UI", "Choix de perk V2 non active, PerkChoiceDock invalide")
		return
	end

	local previousGui = playerGui:FindFirstChild(V2_GUI_NAME)

	if previousGui then
		previousGui:Destroy()
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = V2_GUI_NAME
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 20
	screenGui.Enabled = false
	screenGui.Parent = playerGui

	local overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.fromRGB(2, 5, 11)
	overlay.BackgroundTransparency = 0.36
	overlay.BorderSizePixel = 0
	overlay.Parent = screenGui

	local dock = template:Clone()
	dock.Name = "PerkChoiceDockV2"
	dock.Visible = true
	dock:SetAttribute("ProductionBound", true)
	dock.Parent = overlay

	-- Le snapshot reste une source de composants. Les scripts actuels gardent
	-- leurs donnees et les remotes serveur, sans rendu historique duplique.
	templateGui.Enabled = false

	local panel = asFrame(dock:FindFirstChild("PerkChoicePanel"))
	local content = panel and asFrame(panel:FindFirstChild("Content"))
	local offersRoot = content and asFrame(content:FindFirstChild("Offers"))
	local buttonRow = content and asFrame(findPath(content, { "ActionRow", "ButtonRow" }))
	local titleLabel = content and asTextLabel(content:FindFirstChild("Title"))
	local subtitleLabel = content and asTextLabel(content:FindFirstChild("Subtitle"))
	local refreshButton = buttonRow and asButton(buttonRow:FindFirstChild("Refresh"))
	local passButton = buttonRow and asButton(buttonRow:FindFirstChild("Pass"))
	local banButton = buttonRow and asButton(buttonRow:FindFirstChild("Ban"))

	if
		panel == nil
		or content == nil
		or offersRoot == nil
		or refreshButton == nil
		or passButton == nil
		or banButton == nil
	then
		DebugLog.Warn("UI", "Choix de perk V2 non active, hierarchie du kit incomplete")
		screenGui:Destroy()
		return
	end

	-- L'ordre gameplay est Bannir, Passer, Rafraichir. Le layout reste porte
	-- par le UIGridLayout du kit : aucune position fixe n'est introduite.
	banButton.LayoutOrder = 1
	passButton.LayoutOrder = 2
	refreshButton.LayoutOrder = 3

	local cards = {}

	for index = 1, 3 do
		local card = asFrame(offersRoot:FindFirstChild("Offer" .. tostring(index)))

		if card == nil then
			DebugLog.Warn("UI", "Carte de perk V2 introuvable", {
				Index = index,
			})
			screenGui:Destroy()
			return
		end

		cards[index] = {
			Root = card,
			Content = asFrame(card:FindFirstChild("Content")),
			Stroke = card:FindFirstChild("RarityStroke"),
			Accent = asFrame(card:FindFirstChild("RarityAccent")),
			Aura = asFrame(card:FindFirstChild("RarityAura")),
			AuraStroke = card:FindFirstChild("IdleAuraStroke"),
			HoverScale = card:FindFirstChild("HoverScale"),
			HoverWash = asFrame(card:FindFirstChild("HoverWash")),
			HoverSheen = asFrame(card:FindFirstChild("HoverSheen")),
			Option = nil,
			Hovered = false,
			IdleTweens = {},
			AuraCycle = 0,
			AuraParticleTweens = {},
			SheenTransparency = 0.46,
			RarityColor = Color3.fromRGB(245, 246, 255),
		}
	end

	local function getCardContent(cardState, name)
		return cardState.Content and cardState.Content:FindFirstChild(name) or nil
	end

	local currentChoiceId = nil
	local isSubmitting = false
	local isRerollPending = false
	local isBanMode = false
	local legacySuppressionInProgress = false

	local function suppressLegacyGui()
		if legacySuppressionInProgress then
			return
		end

		legacySuppressionInProgress = true
		legacyGui.Enabled = false
		local legacyOverlay = legacyGui:FindFirstChild("Overlay")

		if legacyOverlay and legacyOverlay:IsA("GuiObject") then
			legacyOverlay.Visible = false
		end

		legacySuppressionInProgress = false
	end

	legacyGui:GetPropertyChangedSignal("Enabled"):Connect(function()
		if legacyGui.Enabled then
			task.defer(suppressLegacyGui)
		end
	end)
	suppressLegacyGui()

	local function setActionState(button, state, charges)
		if button == nil then
			return
		end

		local active = state == "Active"
		button:SetAttribute("ActionState", state)
		button:SetAttribute("Charges", charges or 0)
		button.Active = active
		button.Selectable = active

		local actionStroke = button:FindFirstChild("ActionStroke")
		local stateMark = asFrame(button:FindFirstChild("StateMark"))
		local accentGlow = asFrame(button:FindFirstChild("AccentGlow"))
		local chargePips = button:FindFirstChild("ChargePips")
		local accent = button:GetAttribute("RoleBorderColor")

		if typeof(accent) ~= "Color3" then
			accent = button.TextColor3
		end

		if state == "Active" then
			button.TextTransparency = 0
			button.BackgroundTransparency = 0.12
		elseif state == "Consumed" then
			button.TextTransparency = 0.5
			button.BackgroundTransparency = 0.5
		else
			button.TextTransparency = 0.62
			button.BackgroundTransparency = 0.66
		end

		if actionStroke and actionStroke:IsA("UIStroke") then
			actionStroke.Color = accent
			actionStroke.Transparency = if state == "Active" then 0.15 elseif state == "Consumed" then 0.56 else 0.76
		end

		if stateMark then
			stateMark.BackgroundColor3 = accent
			stateMark.BackgroundTransparency = if state == "Active" then 0.06 else 0.72
		end

		if accentGlow then
			accentGlow.BackgroundColor3 = accent
			accentGlow.BackgroundTransparency = if state == "Active" then 0.72 else 0.94
		end

		if chargePips then
			local pipIndex = 0
			for _, pip in ipairs(chargePips:GetChildren()) do
				if pip:IsA("Frame") then
					pipIndex += 1
					pip.BackgroundColor3 = accent
					pip.BackgroundTransparency = if state == "Active" and pipIndex <= (charges or 0) then 0.04 else 0.82
				end
			end
		end
	end

	local function getRerollCredits()
		return math.max(0, math.floor(tonumber(player:GetAttribute("PerkRerollCredits")) or 0))
	end

	local function getRerollsRemainingThisRun()
		local used = math.max(0, math.floor(tonumber(player:GetAttribute("PerkRerollsUsedThisRun")) or 0))
		local maxUses = math.max(
			0,
			math.floor(tonumber(player:GetAttribute("PerkRerollsMaxUses")) or PerkConfig.MaxRerollsPerRun)
		)

		return math.max(0, math.min(getRerollCredits(), maxUses - used))
	end

	local function getRunActionCredits(attributeName)
		return math.max(0, math.floor(tonumber(player:GetAttribute(attributeName)) or 0))
	end

	local function getRunActionCreditMaximum(attributeName)
		return math.max(0, math.floor(tonumber(player:GetAttribute(attributeName)) or 0))
	end

	local function refreshActions()
		local credits = getRerollCredits()
		local rerollsRemaining = getRerollsRemainingThisRun()
		local refreshAvailable = screenGui.Enabled and currentChoiceId ~= nil and rerollsRemaining > 0 and not isSubmitting and not isRerollPending
		local passCredits = getRunActionCredits("RunPassCredits")
		local banCredits = getRunActionCredits("RunBanCredits")
		local passMaximum = getRunActionCreditMaximum("RunPassCreditsMax")
		local banMaximum = getRunActionCreditMaximum("RunBanCreditsMax")
		local canUseRunAction = screenGui.Enabled and currentChoiceId ~= nil and not isSubmitting and not isRerollPending

		refreshButton.Text = string.format("%s (%d/%d)", REFRESH_ACTION_LABEL, rerollsRemaining, credits)
		setActionState(refreshButton, if refreshAvailable then "Active" elseif rerollsRemaining <= 0 then "Consumed" else "Disabled", rerollsRemaining)

		passButton.Text = string.format("PASSER (%d/%d)", passCredits, passMaximum)
		banButton.Text = string.format("BANNIR (%d/%d)", banCredits, banMaximum)
		setActionState(passButton, if canUseRunAction and passCredits > 0 then "Active" elseif passCredits <= 0 then "Consumed" else "Disabled", passCredits)
		setActionState(banButton, if canUseRunAction and banCredits > 0 then "Active" elseif banCredits <= 0 then "Consumed" else "Disabled", banCredits)

		-- Le mode bannissement doit se lire sans modifier le contrat visuel du bouton.
		banButton:SetAttribute("BanModeActive", isBanMode)
		local accentGlow = asFrame(banButton:FindFirstChild("AccentGlow"))
		if accentGlow then
			accentGlow.BackgroundTransparency = if isBanMode then 0.48 else accentGlow.BackgroundTransparency
		end
	end

	local function setCardInteractive(cardState, interactive)
		cardState.Root.Active = interactive
		cardState.Root.Selectable = interactive

		if not interactive then
			tween(cardState.Root, SELECT_TWEEN, { BackgroundTransparency = 0.34 })
		else
			tween(cardState.Root, SELECT_TWEEN, { BackgroundTransparency = 0.1 })
		end
	end

	local function setCardsInteractive(interactive)
		for _, cardState in ipairs(cards) do
			setCardInteractive(cardState, interactive and cardState.Option ~= nil)
		end
	end

	local function startIdleAura(cardState)
		if #cardState.IdleTweens > 0 then
			return
		end

		local auraStroke = cardState.AuraStroke
		local auraGradient = auraStroke and auraStroke:FindFirstChild("AuraGradient")

		if not auraStroke or not auraStroke:IsA("UIStroke") or not auraGradient or not auraGradient:IsA("UIGradient") then
			return
		end

		auraStroke.Thickness = 2.8
		auraStroke.Transparency = 0.34
		auraGradient.Rotation = 0

		local rotation = TweenService:Create(
			auraGradient,
			TweenInfo.new(7.2, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
			{ Rotation = 360 }
		)
		local pulse = TweenService:Create(
			auraStroke,
			TweenInfo.new(2.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Transparency = 0.48 }
		)

		table.insert(cardState.IdleTweens, rotation)
		table.insert(cardState.IdleTweens, pulse)
		rotation:Play()
		pulse:Play()
	end

	local function getAuraParticles(aura)
		local particles = {}

		for _, particle in ipairs(aura:GetChildren()) do
			if particle:IsA("Frame") and string.match(particle.Name, "^Particle") then
				table.insert(particles, particle)
			end
		end

		return particles
	end

	local function prepareAuraParticles(cardState)
		local aura = cardState.Aura

		if aura == nil then
			return
		end

		local templateParticle = aura:FindFirstChild("Particle01")
		if templateParticle and templateParticle:IsA("Frame") then
			local particleCount = 0
			for _, child in ipairs(aura:GetChildren()) do
				if child:IsA("Frame") and string.match(child.Name, "^Particle") then
					particleCount += 1
				end
			end

			-- Une nappe dense de petites particules donne une aura continue. Les
			-- clones restent locaux a l'UI V2 et n'alourdissent pas le template.
			while particleCount < MAX_AURA_PARTICLES do
				particleCount += 1
				local particle = templateParticle:Clone()
				particle.Name = string.format("Particle%02d", particleCount)
				particle.BackgroundTransparency = 1
				particle.Parent = aura
			end
		end

		for _, particle in ipairs(getAuraParticles(aura)) do
			particle.Visible = false
			particle.BackgroundTransparency = 1
		end
	end

	local function stopAuraParticles(cardState)
		cardState.AuraCycle += 1

		for _, activeTween in pairs(cardState.AuraParticleTweens) do
			activeTween:Cancel()
		end
		table.clear(cardState.AuraParticleTweens)

		if cardState.Aura then
			for _, particle in ipairs(getAuraParticles(cardState.Aura)) do
				particle.Visible = false
				particle.BackgroundTransparency = 1
			end
		end
	end

	local function startAuraParticles(cardState)
		local aura = cardState.Aura

		if aura == nil then
			return
		end

		prepareAuraParticles(cardState)
		stopAuraParticles(cardState)

		local cycle = cardState.AuraCycle
		local rarityColor = aura:GetAttribute("RarityColor")

		if typeof(rarityColor) ~= "Color3" then
			return
		end

		for particleIndex, particle in ipairs(getAuraParticles(aura)) do
			local currentParticleIndex = particleIndex

			task.spawn(function()
				task.wait(currentParticleIndex * 0.055)

				while aura.Parent ~= nil and cycle == cardState.AuraCycle do
					if
						not screenGui.Enabled
						or cardState.Option == nil
						or currentParticleIndex > (cardState.AuraParticleLimit or 0)
					then
						particle.Visible = false
						task.wait(0.2)
						continue
					end

					particle.BackgroundColor3 = rarityColor
					particle.Position = UDim2.fromScale(0.5 + randomizer:NextNumber(-0.13, 0.13), 0.98)
					particle.Size = UDim2.fromOffset(randomizer:NextInteger(2, 3), randomizer:NextInteger(2, 3))
					particle.BackgroundTransparency = randomizer:NextNumber(0.34, 0.54)
					particle.Visible = true

					local corner = particle:FindFirstChildOfClass("UICorner")
					if corner == nil then
						corner = Instance.new("UICorner")
						corner.Parent = particle
					end
					corner.CornerRadius = UDim.new(1, 0)

					local glow = particle:FindFirstChild("Glow")
					if glow and glow:IsA("UIStroke") then
						glow.Color = rarityColor
						glow.Thickness = 0.45
						glow.Transparency = 0.48
					end

					local rise = TweenService:Create(
						particle,
						TweenInfo.new(randomizer:NextNumber(0.82, 1.22), Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
						{
							Position = UDim2.fromScale(0.5 + randomizer:NextNumber(-0.22, 0.22), -0.1),
							BackgroundTransparency = 1,
						}
					)

					cardState.AuraParticleTweens[particle] = rise
					rise:Play()
					rise.Completed:Wait()

					if cycle ~= cardState.AuraCycle then
						return
					end

					if cardState.AuraParticleTweens[particle] == rise then
						cardState.AuraParticleTweens[particle] = nil
					end
					particle.Visible = false
					task.wait(randomizer:NextNumber(0.025, 0.09))
				end
			end)
		end
	end

	local function startPanelIdle()
		local surface = asFrame(panel:FindFirstChild("Surface"))
		local innerGlass = surface and asFrame(surface:FindFirstChild("InnerGlass"))
		local material = innerGlass and asFrame(innerGlass:FindFirstChild("PerkAscensionMaterial"))
		local rim = surface and asFrame(surface:FindFirstChild("PerkAscensionRim"))
		local flow = material and asFrame(material:FindFirstChild("FlowCanvas"))
		local pulse = material and asFrame(material:FindFirstChild("PowerPulse"))
		local veil = material and asFrame(material:FindFirstChild("AmbientVeil"))
		local veilGradient = veil and veil:FindFirstChild("AmbientGradient")
		local rimGradient = rim and rim:FindFirstChild("RimGradient")

		if flow then
			TweenService:Create(
				flow,
				TweenInfo.new(6.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ Position = UDim2.fromScale(0.5, 0.487) }
			):Play()
		end

		if pulse then
			TweenService:Create(
				pulse,
				TweenInfo.new(4.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{
					BackgroundTransparency = 0.935,
					Size = UDim2.fromScale(0.62, 0.48),
				}
			):Play()
		end

		if veilGradient and veilGradient:IsA("UIGradient") then
			TweenService:Create(
				veilGradient,
				TweenInfo.new(9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{
					Offset = Vector2.new(0.12, 0.04),
					Rotation = 12,
				}
			):Play()
		end

		if rimGradient and rimGradient:IsA("UIGradient") then
			TweenService:Create(
				rimGradient,
				TweenInfo.new(9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ Rotation = 18 }
			):Play()
		end
	end

	local function updateCardInspection(cardState, pointerPosition)
		local card = cardState.Root
		local size = card.AbsoluteSize

		if size.X <= 0 or size.Y <= 0 then
			return
		end

		local normalizedX = math.clamp(((pointerPosition.X - card.AbsolutePosition.X) / size.X - 0.5) * 2, -1, 1)
		local normalizedY = math.clamp(((pointerPosition.Y - card.AbsolutePosition.Y) / size.Y - 0.5) * 2, -1, 1)
		local tilt = tonumber(card:GetAttribute("TiltDegrees")) or 1
		local materialLayer = asFrame(card:FindFirstChild("MaterialLayer"))
		local patternCanvas = materialLayer and asFrame(materialLayer:FindFirstChild("PatternCanvas"))
		local materialGradient = materialLayer and materialLayer:FindFirstChild("MaterialGradient")
		local sheenGradient = cardState.HoverSheen and cardState.HoverSheen:FindFirstChild("SheenGradient")

		-- Ces proprietes suivent directement le pointeur. Des tweens recrees a
		-- chaque MouseMovement finissent leur course apres la souris et donnent
		-- l'impression que le reflet n'est pas accroche a la carte.
		card.Rotation = normalizedX * tilt + normalizedY * tilt * 0.22

		if patternCanvas then
			patternCanvas.Position = UDim2.fromScale(0.5 + normalizedX * 0.01, 0.5 + normalizedY * 0.006)
		end

		if materialGradient and materialGradient:IsA("UIGradient") then
			materialGradient.Offset = Vector2.new(normalizedX * 0.08, normalizedY * 0.04)
		end

		if sheenGradient and sheenGradient:IsA("UIGradient") then
			sheenGradient.Offset = Vector2.new(normalizedX * 0.48, normalizedY * 0.16)
		end
	end

	local function resetCardInspection(cardState)
		local card = cardState.Root
		local materialLayer = asFrame(card:FindFirstChild("MaterialLayer"))
		local patternCanvas = materialLayer and asFrame(materialLayer:FindFirstChild("PatternCanvas"))
		local materialGradient = materialLayer and materialLayer:FindFirstChild("MaterialGradient")
		local sheenGradient = cardState.HoverSheen and cardState.HoverSheen:FindFirstChild("SheenGradient")
		local returnTween = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

		tween(card, returnTween, { Rotation = 0 })
		if patternCanvas then
			tween(patternCanvas, returnTween, { Position = UDim2.fromScale(0.5, 0.5) })
		end
		if materialGradient and materialGradient:IsA("UIGradient") then
			tween(materialGradient, returnTween, { Offset = Vector2.new(0, 0) })
		end
		if sheenGradient and sheenGradient:IsA("UIGradient") then
			tween(sheenGradient, returnTween, { Offset = Vector2.new(0, 0) })
		end
	end

	local function setCardHover(cardState, hovered)
		if cardState.Option == nil or isSubmitting then
			return
		end

		if cardState.HoverScale and cardState.HoverScale:IsA("UIScale") then
			tween(cardState.HoverScale, HOVER_TWEEN, {
				Scale = if hovered then 1.025 else 1,
			})
		end

		local icon = asImageLabel(getCardContent(cardState, "Icon"))
		local iconScale = icon and icon:FindFirstChild("HoverScale")
		if iconScale and iconScale:IsA("UIScale") then
			tween(iconScale, HOVER_TWEEN, {
				Scale = if hovered then 1.05 else 1,
			})
		end

		if cardState.Stroke and cardState.Stroke:IsA("UIStroke") then
			tween(cardState.Stroke, HOVER_TWEEN, {
				Color = if isBanMode and hovered then Color3.fromRGB(248, 60, 76) else cardState.RarityColor,
				Transparency = if hovered then 0.02 else 0.12,
				Thickness = if hovered then 2.3 else 1.5,
			})
		end

		if cardState.HoverWash then
			tween(cardState.HoverWash, HOVER_TWEEN, {
				BackgroundTransparency = if hovered then 0.76 else 1,
			})
		end

		if cardState.HoverSheen then
			cardState.HoverSheen.Visible = hovered
			cardState.HoverSheen.Position = UDim2.fromScale(0, 0)
			cardState.HoverSheen.BackgroundTransparency = if hovered then cardState.SheenTransparency else 1
		end

		local materialLayer = asFrame(cardState.Root:FindFirstChild("MaterialLayer"))
		if materialLayer then
			tween(materialLayer, HOVER_TWEEN, {
				BackgroundTransparency = if hovered then 0.954 else 0.974,
			})
		end
	end

	local function applyRarityText(cardState, rarityColor)
		local nameLabel = asTextLabel(getCardContent(cardState, "Name"))
		local effectLabel = asTextLabel(getCardContent(cardState, "Effect"))

		if nameLabel then
			nameLabel.TextColor3 = Color3.fromRGB(245, 246, 255)
		end

		if effectLabel then
			effectLabel.TextColor3 = rarityColor
		end
	end

	local function setGradientColors(gradient, keypoints)
		gradient.Color = ColorSequence.new(keypoints)
	end

	local function applyRarityGradient(gradient, rarityColor)
		local dark = Color3.fromRGB(4, 8, 16)
		local white = Color3.fromRGB(245, 246, 255)

		if gradient.Name == "DA_CardGradient" then
			-- Fond de carte : une teinte profonde, sans ecraser le noir bleute.
			setGradientColors(gradient, {
				ColorSequenceKeypoint.new(0, dark:Lerp(rarityColor, 0.26)),
				ColorSequenceKeypoint.new(0.34, Color3.fromRGB(8, 13, 20)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(5, 9, 15)),
			})
		elseif gradient.Name == "MaterialGradient" then
			-- Matiere : reflets clairs, couleur pure, puis ombre coloree.
			setGradientColors(gradient, {
				ColorSequenceKeypoint.new(0, rarityColor:Lerp(white, 0.18)),
				ColorSequenceKeypoint.new(0.5, rarityColor),
				ColorSequenceKeypoint.new(1, rarityColor:Lerp(dark, 0.35)),
			})
		elseif gradient.Name == "GlassGradient" then
			-- Verre : le reflet reste lumineux comme dans le kit de demo.
			setGradientColors(gradient, {
				ColorSequenceKeypoint.new(0, white),
				ColorSequenceKeypoint.new(0.46, rarityColor:Lerp(white, 0.52)),
				ColorSequenceKeypoint.new(1, rarityColor),
			})
		elseif gradient.Name == "AuraGradient" then
			-- Bordure animee : conserver les cinq paliers de lumiere du kit.
			local shadow = rarityColor:Lerp(dark, 0.55)
			setGradientColors(gradient, {
				ColorSequenceKeypoint.new(0, shadow),
				ColorSequenceKeypoint.new(0.38, rarityColor:Lerp(dark, 0.25)),
				ColorSequenceKeypoint.new(0.5, rarityColor:Lerp(white, 0.35)),
				ColorSequenceKeypoint.new(0.62, rarityColor),
				ColorSequenceKeypoint.new(1, shadow),
			})
		elseif gradient.Name == "WashGradient" then
			setGradientColors(gradient, {
				ColorSequenceKeypoint.new(0, rarityColor:Lerp(white, 0.58)),
				ColorSequenceKeypoint.new(0.42, white),
				ColorSequenceKeypoint.new(1, rarityColor:Lerp(white, 0.35)),
			})
		elseif gradient.Name == "SheenGradient" then
			-- Le rayon de hover reste presque blanc pour garder son impact.
			setGradientColors(gradient, {
				ColorSequenceKeypoint.new(0, rarityColor:Lerp(white, 0.5)),
				ColorSequenceKeypoint.new(0.5, white),
				ColorSequenceKeypoint.new(1, rarityColor:Lerp(white, 0.65)),
			})
		end
	end

	local function applyRarityMaterial(cardState, rarityColor)
		local materialLayer = asFrame(cardState.Root:FindFirstChild("MaterialLayer"))
		local patternCanvas = materialLayer and asFrame(materialLayer:FindFirstChild("PatternCanvas"))
		local glassSurface = asFrame(cardState.Root:FindFirstChild("GlassSurface"))
		local hoverWash = cardState.HoverWash

		if materialLayer then
			materialLayer.BackgroundColor3 = rarityColor
		end

		if glassSurface then
			glassSurface.BackgroundColor3 = rarityColor
		end

		if hoverWash then
			hoverWash.BackgroundColor3 = rarityColor
		end

		if patternCanvas then
			patternCanvas.BackgroundColor3 = rarityColor
			for _, element in ipairs(patternCanvas:GetDescendants()) do
				if element:IsA("Frame") then
					element.BackgroundColor3 = rarityColor
				elseif element:IsA("ImageLabel") then
					element.ImageColor3 = rarityColor
				elseif element:IsA("UIStroke") then
					element.Color = rarityColor
				elseif element:IsA("UIGradient") then
					applyRarityGradient(element, rarityColor)
				end
			end
		end

		-- Le kit porte une teinte de demonstration par carte. En production,
		-- seules les couches de surface nommees suivent l'offre runtime.
		for _, gradient in ipairs(cardState.Root:GetDescendants()) do
			if gradient:IsA("UIGradient") and gradient.Name ~= "" then
				applyRarityGradient(gradient, rarityColor)
			end
		end
	end

	local function applyRarityAura(cardState, rarityColor)
		local aura = cardState.Aura

		if aura == nil then
			return
		end

		aura:SetAttribute("RarityColor", rarityColor)

		for _, element in ipairs(aura:GetDescendants()) do
			if element:IsA("Frame") then
				element.BackgroundColor3 = rarityColor
			elseif element:IsA("UIStroke") then
				element.Color = rarityColor
			elseif element:IsA("ImageLabel") then
				element.ImageColor3 = rarityColor
			end
		end
	end

	local function updateStatPreview(cardState, option)
		local preview = cardState.Root:FindFirstChild("StatPreview")

		if preview == nil then
			preview = Instance.new("Folder")
			preview.Name = "StatPreview"
			preview.Parent = cardState.Root
		end

		for _, child in ipairs(preview:GetChildren()) do
			child:Destroy()
		end

		local deltasByRow = {}
		local impactsByRow = {}
		local stats = if typeof(option.Stats) == "table" then option.Stats else {}
		local rarityFloor = RARITY_IMPACT_FLOOR[option.Rarity] or 1

		for statId, rawValue in pairs(stats) do
			if typeof(rawValue) == "number" and rawValue ~= 0 then
				local rowIds = STAT_PREVIEW_ROWS_BY_STAT[statId]

				if rowIds then
					local step = VISUAL_IMPACT_BY_STAT[statId] or 1
					local impact = math.clamp(math.max(rarityFloor, math.ceil(math.abs(rawValue) / step)), 1, 3)

					for _, rowId in ipairs(rowIds) do
						deltasByRow[rowId] = (deltasByRow[rowId] or 0) + rawValue
						impactsByRow[rowId] = math.max(impactsByRow[rowId] or 1, impact)
					end
				end
			end
		end

		for rowId, delta in pairs(deltasByRow) do
			local entry = Instance.new("NumberValue")
			entry.Name = rowId
			entry.Value = delta
			entry:SetAttribute("VisualImpact", impactsByRow[rowId] or 1)
			entry.Parent = preview
		end
	end

	local function updateCard(cardState, option)
		stopAuraParticles(cardState)
		cardState.Option = option
		cardState.AuraParticleLimit = 0
		cardState.Root.Visible = option ~= nil

		if option == nil then
			return
		end

		local rarityColor = if typeof(option.RarityColor) == "Color3" then option.RarityColor else Color3.fromRGB(245, 246, 255)
		cardState.RarityColor = rarityColor
		local rarityName = string.upper(tostring(option.RarityName or option.Rarity or "Commun"))
		cardState.AuraParticleLimit = AURA_PARTICLES_BY_RARITY[option.Rarity] or AURA_PARTICLES_BY_RARITY.Common
		cardState.SheenTransparency = SHEEN_TRANSPARENCY_BY_RARITY[option.Rarity] or SHEEN_TRANSPARENCY_BY_RARITY.Common
		local iconAssetId = (PerkIconConfig.AssetIds or {})[option.PerkId] or ""

		cardState.Root:SetAttribute("PerkId", option.PerkId or "")
		cardState.Root:SetAttribute("RarityId", option.Rarity or "Common")
		cardState.Root:SetAttribute("RarityColor", rarityColor)

		setText(getCardContent(cardState, "Rarity"), rarityName)
		setText(getCardContent(cardState, "Name"), option.Name or "Perk")
		setText(getCardContent(cardState, "Effect"), option.Description or "")

		local rarityLabel = asTextLabel(getCardContent(cardState, "Rarity"))
		if rarityLabel then
			rarityLabel.TextColor3 = rarityColor
		end

		applyRarityText(cardState, rarityColor)
		applyRarityMaterial(cardState, rarityColor)
		updateStatPreview(cardState, option)

		local icon = asImageLabel(getCardContent(cardState, "Icon"))
		if icon then
			icon.Image = iconAssetId
			icon.Visible = iconAssetId ~= ""
		end

		if cardState.Stroke and cardState.Stroke:IsA("UIStroke") then
			cardState.Stroke.Color = rarityColor
			cardState.Stroke.Transparency = 0.12
		end

		if cardState.Accent then
			cardState.Accent.BackgroundColor3 = rarityColor
		end

		applyRarityAura(cardState, rarityColor)

		if cardState.AuraStroke and cardState.AuraStroke:IsA("UIStroke") then
			cardState.AuraStroke.Color = rarityColor
		end

		startIdleAura(cardState)
		startAuraParticles(cardState)
		setCardInteractive(cardState, not isSubmitting)
	end

	local function getChoiceTitle(payload)
		if type(payload.Title) == "string" and payload.Title ~= "" then
			return string.upper(payload.Title)
		end

		return "CHOIX DE PERK"
	end

	local function showChoices(payload)
		payload = if typeof(payload) == "table" then payload else {}
		local choices = if typeof(payload.Choices) == "table" then payload.Choices else {}

		currentChoiceId = payload.ChoiceId
		isSubmitting = false
		isRerollPending = false
		isBanMode = false
		screenGui.Enabled = true

		setText(titleLabel, getChoiceTitle(payload))
		setText(subtitleLabel, "Choisis une amélioration permanente")

		for index, cardState in ipairs(cards) do
			updateCard(cardState, choices[index])
		end

		setCardsInteractive(true)
		refreshActions()
		suppressLegacyGui()

		DebugLog.Info("UI", "Choix de perk V2 affiche", {
			ChoiceId = currentChoiceId,
			Choices = #choices,
		})
	end

	local function hideChoices()
		currentChoiceId = nil
		isSubmitting = false
		isRerollPending = false
		isBanMode = false
		screenGui.Enabled = false
		for _, cardState in ipairs(cards) do
			stopAuraParticles(cardState)
		end
		refreshActions()
		suppressLegacyGui()
	end

	for _, cardState in ipairs(cards) do
		cardState.Root.MouseEnter:Connect(function()
			cardState.Hovered = true
			setCardHover(cardState, true)
			updateCardInspection(cardState, UserInputService:GetMouseLocation())
		end)

		cardState.Root.MouseLeave:Connect(function()
			cardState.Hovered = false
			setCardHover(cardState, false)
			resetCardInspection(cardState)
		end)

		cardState.Root.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
				return
			end

			if isSubmitting or currentChoiceId == nil or cardState.Option == nil then
				return
			end

			isSubmitting = true
			setCardsInteractive(false)
			refreshActions()

			if isBanMode then
				DebugLog.Info("Perks", "Bannissement perk V2 envoye", {
					ChoiceId = currentChoiceId,
					OptionId = cardState.Option.OptionId,
					PerkId = cardState.Option.PerkId,
				})
				banChoiceRemote:FireServer(currentChoiceId, cardState.Option.OptionId)
				return
			end

			DebugLog.Info("Perks", "Choix perk V2 envoye", {
				ChoiceId = currentChoiceId,
				OptionId = cardState.Option.OptionId,
				PerkId = cardState.Option.PerkId,
			})
			selectChoiceRemote:FireServer(currentChoiceId, cardState.Option.OptionId)
		end)
	end

	UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseMovement then
			return
		end

		local pointerPosition = Vector2.new(input.Position.X, input.Position.Y)
		for _, cardState in ipairs(cards) do
			if cardState.Hovered then
				updateCardInspection(cardState, pointerPosition)
			end
		end
	end)

	startPanelIdle()

	refreshButton.Activated:Connect(function()
		if currentChoiceId == nil or isSubmitting or isRerollPending or getRerollsRemainingThisRun() <= 0 then
			return
		end

		isRerollPending = true
		refreshActions()
		rerollChoiceRemote:FireServer(currentChoiceId)

		task.delay(2, function()
			if isRerollPending then
				isRerollPending = false
				refreshActions()
			end
		end)
	end)

	passButton.Activated:Connect(function()
		if currentChoiceId == nil or isSubmitting or isRerollPending or getRunActionCredits("RunPassCredits") <= 0 then
			return
		end

		isSubmitting = true
		isBanMode = false
		setCardsInteractive(false)
		refreshActions()
		passChoiceRemote:FireServer(currentChoiceId)
	end)

	banButton.Activated:Connect(function()
		if currentChoiceId == nil or isSubmitting or isRerollPending or getRunActionCredits("RunBanCredits") <= 0 then
			return
		end

		isBanMode = not isBanMode
		for _, cardState in ipairs(cards) do
			if cardState.Hovered then
				setCardHover(cardState, true)
			end
		end
		refreshActions()
	end)

	player:GetAttributeChangedSignal("PerkRerollCredits"):Connect(refreshActions)
	player:GetAttributeChangedSignal("PerkRerollsUsedThisRun"):Connect(refreshActions)
	player:GetAttributeChangedSignal("PerkRerollsMaxUses"):Connect(refreshActions)
	player:GetAttributeChangedSignal("RunPassCredits"):Connect(refreshActions)
	player:GetAttributeChangedSignal("RunPassCreditsMax"):Connect(refreshActions)
	player:GetAttributeChangedSignal("RunBanCredits"):Connect(refreshActions)
	player:GetAttributeChangedSignal("RunBanCreditsMax"):Connect(refreshActions)
	showChoicesRemote.OnClientEvent:Connect(showChoices)
	hideChoicesRemote.OnClientEvent:Connect(hideChoices)

	hideChoices()
	DebugLog.Info("UI", "Adaptateur choix de perk V2 active", {
		Source = PRODUCTION_TEMPLATE_GUI_NAME,
	})
end

task.spawn(function()
	local success, err = pcall(initialise)

	if not success then
		DebugLog.Warn("UI", "Initialisation choix de perk V2 impossible", {
			Error = tostring(err),
		})
	end
end)
