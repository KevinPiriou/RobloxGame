local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DebugLog = require(Shared:WaitForChild("DebugLog"))
local RunItemConfig = require(Shared:WaitForChild("RunItemConfig"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local UiTemplateConfig = require(Shared:WaitForChild("UiTemplateConfig"))

local PRODUCTION_TEMPLATE_GUI_NAME = UiTemplateConfig.ProductionTemplateGuiName

local function findPath(root, names)
	local current = root

	for _, name in ipairs(names) do
		local directChild = current:FindFirstChild(name)
		current = directChild or current:FindFirstChild(name, true)

		if current == nil then
			return nil
		end
	end

	return current
end

local function getTextLabel(root, names)
	local instance = findPath(root, names)

	if instance and instance:IsA("TextLabel") then
		return instance
	end

	return nil
end

local function getGuiObject(root, names)
	local instance = findPath(root, names)

	if instance and instance:IsA("GuiObject") then
		return instance
	end

	return nil
end

local function getFrame(root, names)
	local instance = findPath(root, names)

	if instance and instance:IsA("Frame") then
		return instance
	end

	return nil
end

local function getItemRarityColor(definition)
	if definition and type(definition.Rarity) == "string" then
		return UiTheme.Rarities[definition.Rarity] or UiTheme.Colors.GlassTint
	end

	return UiTheme.Colors.GlassTint
end

local function bindText(source, target)
	if source == nil or target == nil then
		return
	end

	local function copyText()
		target.Text = source.Text
	end

	copyText()
	source:GetPropertyChangedSignal("Text"):Connect(copyText)
end

local function bindBar(sourceFill, targetFill)
	if sourceFill == nil or targetFill == nil then
		return
	end

	local function copyProgress()
		targetFill.Size = sourceFill.Size
	end

	copyProgress()
	sourceFill:GetPropertyChangedSignal("Size"):Connect(copyProgress)
end

local function getOrCreateScale(parent, name)
	local scale = parent:FindFirstChild(name)

	if scale and scale:IsA("UIScale") then
		return scale
	end

	local created = Instance.new("UIScale")
	created.Name = name
	created.Parent = parent
	return created
end

local function configureTopBarLayout(topDock, topContent)
	local timerSlot = topContent:FindFirstChild("TimerSlot")
	local leftCluster = topContent:FindFirstChild("LeftCluster")
	local rightCluster = topContent:FindFirstChild("RightCluster")
	local pauseControl = topDock:FindFirstChild("PauseControl")

	if
		not (timerSlot and timerSlot:IsA("Frame"))
		or not (leftCluster and leftCluster:IsA("Frame"))
		or not (rightCluster and rightCluster:IsA("Frame"))
	then
		return
	end

	local leftScale = getOrCreateScale(leftCluster, "ClusterScale")
	local rightScale = getOrCreateScale(rightCluster, "ClusterScale")
	local pauseButton = pauseControl and pauseControl:FindFirstChild("PauseButton")
	local hexCore = pauseControl and pauseControl:FindFirstChild("HexCore")

	local function updateLayout()
		local availableWidth = math.max(1, topContent.AbsoluteSize.X)
		local topHeight = math.max(1, topDock.AbsoluteSize.Y)
		local timerWidth = 136
		local middleGap = 18
		local groupWidth = math.max(1, (availableWidth - timerWidth - (middleGap * 2)) * 0.5)
		local leftFactor = math.clamp(groupWidth / 294, 0.42, 1)
		local rightFactor = math.clamp(groupWidth / 342, 0.42, 1)
		local pauseSize = math.clamp(math.floor(topHeight * 0.64 + 0.5), 34, 46)
		local pauseGap = math.clamp(math.floor(topHeight * 0.13 + 0.5), 5, 10)

		leftScale.Scale = leftFactor
		rightScale.Scale = rightFactor
		leftCluster.Position = UDim2.new(0, 0, 0.5, 0)
		rightCluster.Position = UDim2.new(1, -(342 * rightFactor), 0.5, 0)

		timerSlot.AnchorPoint = Vector2.new(0.5, 0.5)
		timerSlot.Position = UDim2.fromScale(0.5, 0.5)
		timerSlot.Size = UDim2.new(0, timerWidth, 1, 0)

		if pauseControl and pauseControl:IsA("Frame") then
			pauseControl.AnchorPoint = Vector2.new(0.5, 0)
			pauseControl.Position = UDim2.fromScale(0.5, 0)
			pauseControl.Size = UDim2.new(0, timerWidth, 0, topHeight + pauseGap + pauseSize)
		end

		if hexCore and hexCore:IsA("GuiObject") then
			hexCore.AnchorPoint = Vector2.new(0.5, 0)
			hexCore.Position = UDim2.fromScale(0.5, 0)
			hexCore.Size = UDim2.new(0, timerWidth, 0, topHeight)
		end

		if pauseButton and pauseButton:IsA("GuiObject") then
			pauseButton.AnchorPoint = Vector2.new(0.5, 0)
			pauseButton.Position = UDim2.new(0.5, 0, 0, topHeight + pauseGap)
			pauseButton.Size = UDim2.fromOffset(pauseSize, pauseSize)
		end
	end

	topContent:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateLayout)
	topDock:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateLayout)
	task.defer(updateLayout)
end

local function setSlotEmpty(slot)
	slot:SetAttribute("ObjectId", "")
	slot:SetAttribute("Count", 0)
	slot.BackgroundTransparency = 0.64

	local icon = slot:FindFirstChild("ItemIcon")
	if icon and icon:IsA("ImageLabel") then
		icon.Visible = false
		icon.Image = ""
	end

	local count = slot:FindFirstChild("Count")
	if count and count:IsA("TextLabel") then
		count.Visible = false
		count.Text = ""
	end

	local stroke = slot:FindFirstChild("SlotStroke")
	if stroke and stroke:IsA("UIStroke") then
		stroke.Color = Color3.fromRGB(55, 76, 104)
		stroke.Transparency = 0.72
	end
end

local function setSlotItem(slot, definition, stacks)
	local rarityColor = getItemRarityColor(definition)

	slot:SetAttribute("ObjectId", definition.Id)
	slot:SetAttribute("Count", stacks)
	slot.BackgroundTransparency = 0.08

	local icon = slot:FindFirstChild("ItemIcon")
	if icon and icon:IsA("ImageLabel") then
		icon.Image = definition.Icon
		icon.Visible = true
	end

	local count = slot:FindFirstChild("Count")
	if count and count:IsA("TextLabel") then
		count.Text = "x" .. tostring(stacks)
		count.Visible = true
	end

	local stroke = slot:FindFirstChild("SlotStroke")
	if stroke and stroke:IsA("UIStroke") then
		stroke.Color = rarityColor
		stroke.Transparency = 0.12
	end
end

local function initialise()
	local combatGui = playerGui:WaitForChild("CombatGui", 30)
	local templateGui = playerGui:WaitForChild(PRODUCTION_TEMPLATE_GUI_NAME, 30)

	if combatGui == nil or templateGui == nil or not templateGui:IsA("ScreenGui") then
		DebugLog.Warn("UI", "Barres V2 non activees, snapshot ou HUD introuvable", {
			HasCombatGui = combatGui ~= nil,
			HasProductionTemplate = templateGui ~= nil,
		})
		return
	end

	local templateCanvas = templateGui:FindFirstChild("RunCanvas")
	local topTemplate = templateCanvas and templateCanvas:FindFirstChild("TopDock")
	local bottomTemplate = templateCanvas and templateCanvas:FindFirstChild("BottomDock")

	if topTemplate == nil or bottomTemplate == nil or not topTemplate:IsA("Frame") or not bottomTemplate:IsA("Frame") then
		DebugLog.Warn("UI", "Barres V2 non activees, docks du kit invalides")
		return
	end

	local legacyTop = combatGui:WaitForChild("TopCluster", 30)
	local legacyBottom = combatGui:WaitForChild("XpPanel", 30)

	if legacyTop == nil or legacyBottom == nil or not legacyTop:IsA("Frame") or not legacyBottom:IsA("Frame") then
		DebugLog.Warn("UI", "Barres V2 non activees, sources HUD historiques invalides")
		return
	end

	local oldTop = combatGui:FindFirstChild("TopBarV2")
	if oldTop then
		oldTop:Destroy()
	end

	local oldBottom = combatGui:FindFirstChild("BottomBarV2")
	if oldBottom then
		oldBottom:Destroy()
	end

	local topDock = topTemplate:Clone()
	topDock.Name = "TopBarV2"
	topDock:SetAttribute("ProductionBound", true)
	topDock.Visible = false
	topDock.Parent = combatGui

	local bottomDock = bottomTemplate:Clone()
	bottomDock.Name = "BottomBarV2"
	bottomDock:SetAttribute("ProductionBound", true)
	bottomDock.Visible = false
	bottomDock.Parent = combatGui

	-- Le snapshot sert uniquement de source de clonage dans StarterGui.
	templateGui.Enabled = false

	local topContent = getFrame(topDock, { "Content" })
	local bottomBar = getFrame(bottomDock, { "BottomBar" })
	local bottomContent = bottomBar and getFrame(bottomBar, { "Content" })

	if topContent == nil or bottomContent == nil then
		DebugLog.Warn("UI", "Barres V2 non activees, hierarchie de composants incomplete")
		topDock:Destroy()
		bottomDock:Destroy()
		return
	end

	configureTopBarLayout(topDock, topContent)

	local kitHealth = getFrame(bottomContent, { "Stats", "Health" })
	local kitShield = getFrame(bottomContent, { "Stats", "Shield" })
	local kitExperience = getFrame(bottomContent, { "Stats", "Experience" })

	if kitHealth == nil or kitShield == nil or kitExperience == nil then
		DebugLog.Warn("UI", "Barres V2 non activees, pistes de statistiques absentes")
		topDock:Destroy()
		bottomDock:Destroy()
		return
	end

	-- Ces noms conservent le contrat des popups existants sans dupliquer leur logique.
	kitHealth.Name = "HpGroup"
	kitShield.Name = "ShieldGroup"
	kitExperience.Name = "XpPanel"

	local legacyHealth = legacyBottom:WaitForChild("HpGroup", 30)
	local legacyShield = legacyBottom:WaitForChild("ShieldGroup", 30)
	local legacyArcane = legacyTop:WaitForChild("ArcaneSlot", 30)
	local legacyKills = legacyTop:WaitForChild("KillsSlot", 30)
	local legacyGold = legacyTop:WaitForChild("GoldSlot", 30)
	local legacyChestCost = legacyTop:WaitForChild("ChestCostSlot", 30)
	local legacyRunScore = legacyTop:WaitForChild("RunScoreSlot", 30)
	local legacyLevel = legacyTop:WaitForChild("TopLevelValue", 30)
	local legacyTimer = legacyTop:WaitForChild("TimerSlot", 30)
	local legacyPauseButton = legacyTop:WaitForChild("PauseButton", 30)
	local legacyPauseImage = legacyPauseButton:FindFirstChild("PauseImage")

	if
		legacyHealth == nil
		or legacyShield == nil
		or legacyArcane == nil
		or legacyKills == nil
		or legacyGold == nil
		or legacyChestCost == nil
		or legacyRunScore == nil
		or legacyLevel == nil
		or legacyTimer == nil
		or legacyPauseButton == nil
		or not legacyHealth:IsA("Frame")
		or not legacyShield:IsA("Frame")
		or not legacyArcane:IsA("Frame")
		or not legacyKills:IsA("Frame")
		or not legacyGold:IsA("Frame")
		or not legacyChestCost:IsA("Frame")
		or not legacyRunScore:IsA("Frame")
		or not legacyLevel:IsA("TextLabel")
		or not legacyTimer:IsA("Frame")
		or not legacyPauseButton:IsA("TextButton")
		or (legacyPauseImage ~= nil and not legacyPauseImage:IsA("ImageLabel"))
	then
		DebugLog.Warn("UI", "Barres V2 non activees, donnees HUD historiques incompletes")
		topDock:Destroy()
		bottomDock:Destroy()
		return
	end

	local legacyHealthText = getTextLabel(legacyHealth, { "HpText" })
	local legacyShieldText = getTextLabel(legacyShield, { "ShieldHeader", "ShieldText" })
	local legacyXpText = getTextLabel(legacyBottom, { "XpText" })
	local legacyLevelText = getTextLabel(legacyBottom, { "LevelValue" })
	local legacyHealthFill = getFrame(legacyHealth, { "HealthTrack", "HealthFill" })
	local legacyShieldFill = getFrame(legacyShield, { "ShieldTrack", "ShieldFill" })
	local legacyXpFill = getFrame(legacyBottom, { "XpTrack", "XpFill" })
	local legacyTimerText = getTextLabel(legacyTimer, { "TimerLabel" })

	local kitArcaneValue = getTextLabel(topContent, { "ArcaneSlot", "Info", "Value" })
	local kitKillsValue = getTextLabel(topContent, { "KillsSlot", "Info", "Value" })
	local kitGoldValue = getTextLabel(topContent, { "GoldSlot", "Info", "Value" })
	local kitTimerValue = getTextLabel(topContent, { "TimerSlot", "Info", "Value" })
	local kitChestValue = getTextLabel(topContent, { "ChestCostSlot", "Info", "Value" })
	local kitRunScoreValue = getTextLabel(topContent, { "RunScoreSlot", "Info", "Value" })
	local kitLevelValue = getTextLabel(topContent, { "LevelSlot", "Info", "Value" })

	local kitHealthValue = getTextLabel(kitHealth, { "Header", "Value" })
	local kitShieldValue = getTextLabel(kitShield, { "Header", "Value" })
	local kitXpValue = getTextLabel(kitExperience, { "Header", "Value" })
	local kitXpLabel = getTextLabel(kitExperience, { "Header", "Label" })
	local kitHealthFill = getFrame(kitHealth, { "Track", "Fill" })
	local kitShieldFill = getFrame(kitShield, { "Track", "Fill" })
	local kitXpFill = getFrame(kitExperience, { "Track", "Fill" })

	bindText(getTextLabel(legacyArcane, { "ArcaneValue" }), kitArcaneValue)
	bindText(getTextLabel(legacyKills, { "KillsValue" }), kitKillsValue)
	bindText(getTextLabel(legacyGold, { "GoldValue" }), kitGoldValue)
	bindText(legacyTimerText, kitTimerValue)
	bindText(getTextLabel(legacyChestCost, { "ChestCostValue" }), kitChestValue)
	bindText(getTextLabel(legacyRunScore, { "RunScoreValue" }), kitRunScoreValue)
	bindText(legacyLevel, kitLevelValue)

	bindText(legacyHealthText, kitHealthValue)
	bindText(legacyShieldText, kitShieldValue)
	bindText(legacyXpText, kitXpValue)
	bindText(legacyLevelText, kitXpLabel)
	bindBar(legacyHealthFill, kitHealthFill)
	bindBar(legacyShieldFill, kitShieldFill)
	bindBar(legacyXpFill, kitXpFill)

	local kitPauseButton = getGuiObject(topDock, { "PauseControl", "PauseButton" })
	local kitPauseGlow = getFrame(topDock, { "PauseControl", "StateGlow" })
	local pauseToggleRemote = ReplicatedStorage:FindFirstChild("Combat_TogglePause")
		or ReplicatedStorage:WaitForChild("Combat_TogglePause", 10)

	if pauseToggleRemote ~= nil and not pauseToggleRemote:IsA("RemoteEvent") then
		DebugLog.Warn("UI", "Remote de pause invalide pour les barres V2", {
		ClassName = pauseToggleRemote.ClassName,
		Name = pauseToggleRemote.Name,
	})
		pauseToggleRemote = nil
	end

	if kitPauseButton and kitPauseButton:IsA("ImageButton") then
		local function refreshPauseButton()
			kitPauseButton.Active = legacyPauseButton.Active
			kitPauseButton.ImageTransparency = if legacyPauseButton.Active then 0 else 0.45

			if legacyPauseImage and legacyPauseImage:IsA("ImageLabel") then
				kitPauseButton.Image = legacyPauseImage.Image
			end

			if kitPauseGlow then
				kitPauseGlow.BackgroundTransparency = if legacyPauseButton.Active then 0.90 else 0.97
			end
		end

		refreshPauseButton()
		legacyPauseButton:GetPropertyChangedSignal("Active"):Connect(refreshPauseButton)

		if legacyPauseImage and legacyPauseImage:IsA("ImageLabel") then
			legacyPauseImage:GetPropertyChangedSignal("Image"):Connect(refreshPauseButton)
		end

		kitPauseButton.Activated:Connect(function()
			if not legacyPauseButton.Active then
				return
			end

			if pauseToggleRemote == nil then
				DebugLog.Warn("UI", "Pause V2 ignoree, remote indisponible")
				return
			end

			-- Le bouton V2 parle directement au serveur. Activer artificiellement
			-- le bouton historique masque peut lever une erreur et coupe la partie.
			pauseToggleRemote:FireServer()
		end)
	end

	local inventoryGrid = getFrame(bottomContent, { "Inventory", "Grid" })
	local inventorySlots = {}

	if inventoryGrid then
		for index = 1, 12 do
			local slot = inventoryGrid:FindFirstChild(string.format("Slot%02d", index))

			if slot and slot:IsA("Frame") then
				table.insert(inventorySlots, slot)
				setSlotEmpty(slot)
			end
		end
	end

	local function refreshRunItems(payload)
		for _, slot in ipairs(inventorySlots) do
			setSlotEmpty(slot)
		end

		local usedSlots = 0
		local displayedItemIds = {}

		if typeof(payload) == "table" and typeof(payload.Items) == "table" then
			for _, item in ipairs(payload.Items) do
				local itemId = if typeof(item) == "table" and item.Id ~= nil then tostring(item.Id) else ""
				local stacks = if typeof(item) == "table" then math.max(0, math.floor(tonumber(item.Stacks) or 0)) else 0
				local definition = RunItemConfig.Definitions[itemId]

				if stacks > 0 and definition ~= nil and not displayedItemIds[itemId] then
					usedSlots += 1
					local slot = inventorySlots[usedSlots]

					if slot == nil then
						break
					end

					displayedItemIds[itemId] = true
					setSlotItem(slot, definition, stacks)
				end
			end
		end
	end

	local feedbackEvent = combatGui:FindFirstChild("FeedbackArrived")
	local feedbackTargets = {
		Health = { Root = kitHealth, Track = getFrame(kitHealth, { "Track" }), Fill = kitHealthFill },
		Shield = { Root = kitShield, Track = getFrame(kitShield, { "Track" }), Fill = kitShieldFill },
		Xp = { Root = kitExperience, Track = getFrame(kitExperience, { "Track" }), Fill = kitXpFill },
		ArcaneGem = { Root = getFrame(topContent, { "ArcaneSlot" }), Accent = Color3.fromRGB(109, 220, 255) },
		Kill = { Root = getFrame(topContent, { "KillsSlot" }), Accent = Color3.fromRGB(248, 60, 76) },
		Coin = { Root = getFrame(topContent, { "GoldSlot" }), Accent = Color3.fromRGB(255, 211, 82) },
		RunScore = { Root = getFrame(topContent, { "RunScoreSlot" }), Accent = Color3.fromRGB(112, 228, 255) },
	}

	local feedbackTokens = {}

	local function playFeedback(targetId)
		local target = feedbackTargets[targetId]

		if target == nil or target.Root == nil then
			return
		end

		local token = (feedbackTokens[targetId] or 0) + 1
		feedbackTokens[targetId] = token


		-- Un UIScale sur un slot horizontal rend la top bar nerveuse : le slot
		-- grossit a l'ecran au milieu de ses voisins. Le retour est donc porte
		-- par un contour local, sans modifier aucune emprise de layout.
		local legacyScale = target.Root:FindFirstChild("FeedbackPulseScale")
		if legacyScale and legacyScale:IsA("UIScale") then
			legacyScale:Destroy()
		end

		local pulseStroke = target.Root:FindFirstChild("FeedbackPulseStroke")
		if pulseStroke == nil then
			pulseStroke = Instance.new("UIStroke")
			pulseStroke.Name = "FeedbackPulseStroke"
			pulseStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			pulseStroke.Parent = target.Root
		end

		if pulseStroke:IsA("UIStroke") then
			local accent = target.Accent
			if typeof(accent) ~= "Color3" and target.Fill ~= nil then
				accent = target.Fill.BackgroundColor3
			end

			pulseStroke.Color = if typeof(accent) == "Color3" then accent else Color3.fromRGB(245, 246, 255)
			pulseStroke.Thickness = 1
			pulseStroke.Transparency = 0.9
			TweenService:Create(pulseStroke, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Thickness = 1.65,
				Transparency = 0.42,
			}):Play()

			task.delay(0.14, function()
				if feedbackTokens[targetId] == token and pulseStroke.Parent ~= nil then
					TweenService:Create(pulseStroke, TweenInfo.new(0.24, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
						Thickness = 1,
						Transparency = 1,
					}):Play()
				end
			end)
		end

		if target.Track then
			local sheen = target.Track:FindFirstChild("FeedbackSheen")
			if sheen and sheen:IsA("Frame") then
				sheen.Position = UDim2.fromScale(-0.4, 0.5)
				sheen.BackgroundTransparency = 0.38
				TweenService:Create(sheen, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Position = UDim2.fromScale(1.35, 0.5),
					BackgroundTransparency = 1,
				}):Play()
			end
		end
	end

	if feedbackEvent and feedbackEvent:IsA("BindableEvent") then
		feedbackEvent.Event:Connect(playFeedback)
	end

	-- Les anciens objets restent le temps de valider le rail de donnees, mais ne peuvent plus etre rendus.
	legacyHealth.Name = "LegacyHpGroup"
	legacyShield.Name = "LegacyShieldGroup"
	legacyBottom.Name = "LegacyXpPanel"
	legacyArcane.Name = "LegacyArcaneSlot"
	legacyKills.Name = "LegacyKillsSlot"
	legacyGold.Name = "LegacyGoldSlot"
	legacyRunScore.Name = "LegacyRunScoreSlot"

	local isSuppressingLegacy = false
	local function suppressLegacyBars()
		if isSuppressingLegacy then
			return
		end

		isSuppressingLegacy = true
		legacyTop.Visible = false
		legacyBottom.Visible = false
		isSuppressingLegacy = false
	end

	legacyTop:GetPropertyChangedSignal("Visible"):Connect(suppressLegacyBars)
	legacyBottom:GetPropertyChangedSignal("Visible"):Connect(suppressLegacyBars)
	suppressLegacyBars()

	local function setRunVisibility(isRunActive)
		topDock.Visible = isRunActive
		bottomDock.Visible = isRunActive
		suppressLegacyBars()
	end

	setRunVisibility(player:GetAttribute("IsRunActive") == true)
	player:GetAttributeChangedSignal("IsRunActive"):Connect(function()
		setRunVisibility(player:GetAttribute("IsRunActive") == true)
	end)

	task.spawn(function()
		local runStateRemote = ReplicatedStorage:WaitForChild("Run_StateUpdate", 30)
		if runStateRemote and runStateRemote:IsA("RemoteEvent") then
			runStateRemote.OnClientEvent:Connect(function(payload)
				if typeof(payload) == "table" then
					setRunVisibility(payload.IsRunActive == true)
				end
			end)
		end
	end)

	task.spawn(function()
		local runItemsRemote = ReplicatedStorage:WaitForChild(RunItemConfig.UpdateRemoteName, 30)
		if runItemsRemote and runItemsRemote:IsA("RemoteEvent") then
			runItemsRemote.OnClientEvent:Connect(refreshRunItems)
		end
	end)

	DebugLog.Info("UI", "Barres V2 du kit activees", {
		BottomSlots = #inventorySlots,
		Source = PRODUCTION_TEMPLATE_GUI_NAME,
	})
end

task.spawn(function()
	local success, err = pcall(initialise)

	if not success then
		DebugLog.Warn("UI", "Initialisation des barres V2 impossible", {
			Error = tostring(err),
		})
	end
end)
