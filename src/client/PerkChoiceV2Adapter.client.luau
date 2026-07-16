local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DebugLog = require(Shared:WaitForChild("DebugLog"))
local PerkIconConfig = require(Shared:WaitForChild("PerkIconConfig"))

local showChoicesRemote = ReplicatedStorage:WaitForChild("Perk_ShowChoices")
local hideChoicesRemote = ReplicatedStorage:WaitForChild("Perk_HideChoices")
local selectChoiceRemote = ReplicatedStorage:WaitForChild("Perk_SelectChoice")
local rerollChoiceRemote = ReplicatedStorage:WaitForChild("Perk_RerollRequest")

local DRAFT_GUI_NAME = "MegaRobloxUIV_RunLayoutDraft"
local V2_GUI_NAME = "PerkChoiceV2"

local HOVER_TWEEN = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local SELECT_TWEEN = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local randomizer = Random.new()

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
	local draftGui = playerGui:WaitForChild(DRAFT_GUI_NAME, 30)
	local legacyGui = playerGui:WaitForChild("PerkChoiceGui", 30)

	if draftGui == nil or not draftGui:IsA("ScreenGui") or legacyGui == nil or not legacyGui:IsA("ScreenGui") then
		DebugLog.Warn("UI", "Choix de perk V2 non active, source ou rail historique introuvable", {
			HasDraftGui = draftGui ~= nil,
			HasLegacyGui = legacyGui ~= nil,
		})
		return
	end

	local runCanvas = draftGui:FindFirstChild("RunCanvas")
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

	-- Le kit reste uniquement une source de composants. Les scripts actuels gardent
	-- leurs donnees et les remotes serveur, mais plus aucun rendu historique.
	draftGui.Enabled = false

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
		}
	end

	local function getCardContent(cardState, name)
		return cardState.Content and cardState.Content:FindFirstChild(name) or nil
	end

	local currentChoiceId = nil
	local isSubmitting = false
	local isRerollPending = false
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

	local function refreshActions()
		local credits = getRerollCredits()
		local refreshAvailable = screenGui.Enabled and currentChoiceId ~= nil and credits > 0 and not isSubmitting and not isRerollPending

		setActionState(refreshButton, if refreshAvailable then "Active" elseif credits <= 0 then "Consumed" else "Disabled", math.min(credits, 3))

		-- Aucun consommable ni endpoint serveur n'existe encore pour ces deux actions.
		-- Les rendre inertes evite de promettre un effet local qui serait perdu a la prochaine offre.
		setActionState(passButton, "Disabled", 0)
		setActionState(banButton, "Disabled", 0)
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

	local function animateAuraParticles(cardState)
		local aura = cardState.Aura

		if aura == nil then
			return
		end

		local particleIndex = 0
		for _, particle in ipairs(aura:GetChildren()) do
			if particle:IsA("Frame") and string.match(particle.Name, "^Particle") then
				particleIndex += 1
				task.spawn(function()
					task.wait(particleIndex * 0.14)

					while aura.Parent ~= nil do
						if not screenGui.Enabled or cardState.Option == nil then
							particle.BackgroundTransparency = 1
							task.wait(0.2)
							continue
						end

						local rarityColor = aura:GetAttribute("RarityColor")
						if typeof(rarityColor) == "Color3" then
							particle.BackgroundColor3 = rarityColor
							local glow = particle:FindFirstChild("Glow")
							if glow and glow:IsA("UIStroke") then
								glow.Color = rarityColor
							end
						end

						particle.Position = UDim2.fromScale(0.5 + randomizer:NextNumber(-0.17, 0.17), 0.9)
						particle.Size = UDim2.fromOffset(randomizer:NextInteger(3, 5), randomizer:NextInteger(3, 5))
						particle.BackgroundTransparency = randomizer:NextNumber(0.18, 0.38)

						local rise = TweenService:Create(
							particle,
							TweenInfo.new(randomizer:NextNumber(1.15, 1.7), Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
							{
								Position = UDim2.fromScale(0.5 + randomizer:NextNumber(-0.36, 0.36), -0.16),
								BackgroundTransparency = 1,
							}
						)
						rise:Play()
						rise.Completed:Wait()
						task.wait(randomizer:NextNumber(0.12, 0.3))
					end
				end)
			end
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

		tween(card, TweenInfo.new(0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Rotation = normalizedX * tilt + normalizedY * tilt * 0.22,
		})

		if patternCanvas then
			tween(patternCanvas, TweenInfo.new(0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = UDim2.fromScale(0.5 + normalizedX * 0.01, 0.5 + normalizedY * 0.006),
			})
		end

		if materialGradient and materialGradient:IsA("UIGradient") then
			tween(materialGradient, TweenInfo.new(0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Offset = Vector2.new(normalizedX * 0.08, normalizedY * 0.04),
			})
		end

		if sheenGradient and sheenGradient:IsA("UIGradient") then
			tween(sheenGradient, TweenInfo.new(0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Offset = Vector2.new(normalizedX * 0.58, normalizedY * 0.24),
			})
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
			cardState.HoverSheen.Position = UDim2.fromScale(-0.38, 0)
			cardState.HoverSheen.BackgroundTransparency = 0.52

			if hovered then
				tween(cardState.HoverSheen, TweenInfo.new(0.38, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Position = UDim2.fromScale(1.12, 0),
					BackgroundTransparency = 1,
				})
			end
		end

		local materialLayer = asFrame(cardState.Root:FindFirstChild("MaterialLayer"))
		if materialLayer then
			tween(materialLayer, HOVER_TWEEN, {
				BackgroundTransparency = if hovered then 0.954 else 0.974,
			})
		end
	end

	local function updateCard(cardState, option)
		cardState.Option = option
		cardState.Root.Visible = option ~= nil

		if option == nil then
			return
		end

		local rarityColor = if typeof(option.RarityColor) == "Color3" then option.RarityColor else Color3.fromRGB(245, 246, 255)
		local rarityName = string.upper(tostring(option.RarityName or option.Rarity or "Commun"))
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

		if cardState.Aura then
			cardState.Aura:SetAttribute("RarityColor", rarityColor)
			for _, child in ipairs(cardState.Aura:GetDescendants()) do
				if child:IsA("Frame") then
					child.BackgroundColor3 = rarityColor
				end
			end
		end

		if cardState.AuraStroke and cardState.AuraStroke:IsA("UIStroke") then
			cardState.AuraStroke.Color = rarityColor
		end

		startIdleAura(cardState)
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
		screenGui.Enabled = false
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

		cardState.Root.InputChanged:Connect(function(input)
			if cardState.Hovered and input.UserInputType == Enum.UserInputType.MouseMovement then
				updateCardInspection(cardState, Vector2.new(input.Position.X, input.Position.Y))
			end
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

			DebugLog.Info("Perks", "Choix perk V2 envoye", {
				ChoiceId = currentChoiceId,
				OptionId = cardState.Option.OptionId,
				PerkId = cardState.Option.PerkId,
			})
			selectChoiceRemote:FireServer(currentChoiceId, cardState.Option.OptionId)
		end)
	end

	for _, cardState in ipairs(cards) do
		animateAuraParticles(cardState)
	end
	startPanelIdle()

	refreshButton.Activated:Connect(function()
		if currentChoiceId == nil or isSubmitting or isRerollPending or getRerollCredits() <= 0 then
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

	player:GetAttributeChangedSignal("PerkRerollCredits"):Connect(refreshActions)
	showChoicesRemote.OnClientEvent:Connect(showChoices)
	hideChoicesRemote.OnClientEvent:Connect(hideChoices)

	hideChoices()
	DebugLog.Info("UI", "Adaptateur choix de perk V2 active", {
		Source = DRAFT_GUI_NAME,
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
