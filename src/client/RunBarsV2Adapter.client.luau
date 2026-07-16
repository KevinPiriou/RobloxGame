local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DebugLog = require(Shared:WaitForChild("DebugLog"))
local RunItemConfig = require(Shared:WaitForChild("RunItemConfig"))

local DRAFT_GUI_NAME = "MegaRobloxUIV_RunLayoutDraft"
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
		stroke.Color = definition.Accent
		stroke.Transparency = 0.12
	end
end

local function initialise()
	local combatGui = playerGui:WaitForChild("CombatGui", 30)
	local draftGui = playerGui:WaitForChild(DRAFT_GUI_NAME, 30)

	if combatGui == nil or draftGui == nil or not draftGui:IsA("ScreenGui") then
		DebugLog.Warn("UI", "Barres V2 non activees, template ou HUD introuvable", {
			HasCombatGui = combatGui ~= nil,
			HasDraftGui = draftGui ~= nil,
		})
		return
	end

	local draftCanvas = draftGui:FindFirstChild("RunCanvas")
	local topTemplate = draftCanvas and draftCanvas:FindFirstChild("TopDock")
	local bottomTemplate = draftCanvas and draftCanvas:FindFirstChild("BottomDock")

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

	-- Le contenu de la TopBar est volontairement plus large que son dock.
	-- Cette echelle garde la composition lisible sur les petits ecrans sans positions fixes.
	local responsiveScale = topDock.Content:FindFirstChild("ResponsiveScale")
	if responsiveScale == nil then
		responsiveScale = Instance.new("UIScale")
		responsiveScale.Name = "ResponsiveScale"
		responsiveScale.Parent = topDock.Content
	end

	if responsiveScale:IsA("UIScale") then
		local function updateTopScale()
			local visualWidth = (topDock.AbsoluteSize.X * 1.25895083) - 56
			responsiveScale.Scale = math.clamp(visualWidth / 801, 0.64, 1)
		end

		topDock:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateTopScale)
		task.defer(updateTopScale)
	end

	-- Le kit reste une source de composition dans StarterGui, il ne doit pas s'afficher en doublon.
	draftGui.Enabled = false

	local topContent = getFrame(topDock, { "Content" })
	local bottomBar = getFrame(bottomDock, { "BottomBar" })
	local bottomContent = bottomBar and getFrame(bottomBar, { "Content" })

	if topContent == nil or bottomContent == nil then
		DebugLog.Warn("UI", "Barres V2 non activees, hierarchie de composants incomplete")
		topDock:Destroy()
		bottomDock:Destroy()
		return
	end

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

			local success, err = pcall(function()
				legacyPauseButton:Activate()
			end)

			if not success then
				DebugLog.Warn("UI", "Pause V2 impossible a declencher", {
					Error = tostring(err),
				})
			end
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
		local stacksById = {}

		if typeof(payload) == "table" and typeof(payload.Items) == "table" then
			for _, item in ipairs(payload.Items) do
				if typeof(item) == "table" and item.Id ~= nil then
					local stacks = math.max(0, math.floor(tonumber(item.Stacks) or 0))
					stacksById[tostring(item.Id)] = stacks
				end
			end
		end

		for _, slot in ipairs(inventorySlots) do
			setSlotEmpty(slot)
		end

		local usedSlots = 0
		for _, itemId in ipairs(RunItemConfig.ChestRewardIds) do
			local stacks = stacksById[itemId] or 0
			local definition = RunItemConfig.Definitions[itemId]

			if stacks > 0 and definition ~= nil then
				usedSlots += 1
				local slot = inventorySlots[usedSlots]

				if slot then
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
		ArcaneGem = { Root = getFrame(topContent, { "ArcaneSlot" }) },
		Kill = { Root = getFrame(topContent, { "KillsSlot" }) },
		Coin = { Root = getFrame(topContent, { "GoldSlot" }) },
		RunScore = { Root = getFrame(topContent, { "RunScoreSlot" }) },
	}

	local feedbackTokens = {}

	local function playFeedback(targetId)
		local target = feedbackTargets[targetId]

		if target == nil or target.Root == nil then
			return
		end

		local token = (feedbackTokens[targetId] or 0) + 1
		feedbackTokens[targetId] = token

		local scale = target.Root:FindFirstChild("FeedbackPulseScale")
		if scale == nil then
			scale = Instance.new("UIScale")
			scale.Name = "FeedbackPulseScale"
			scale.Parent = target.Root
		end

		if scale:IsA("UIScale") then
			scale.Scale = 1
			TweenService:Create(scale, TweenInfo.new(0.11, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Scale = 1.055,
			}):Play()
			task.delay(0.13, function()
				if feedbackTokens[targetId] == token and scale.Parent ~= nil then
					TweenService:Create(scale, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						Scale = 1,
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
		Source = DRAFT_GUI_NAME,
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
