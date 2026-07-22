--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local DebugLog = require(Shared:WaitForChild("DebugLog"))
local UiTemplateConfig = require(Shared:WaitForChild("UiTemplateConfig"))

local showRemote = ReplicatedStorage:WaitForChild("WeaponProgression_Show") :: RemoteEvent
local hideRemote = ReplicatedStorage:WaitForChild("WeaponProgression_Hide") :: RemoteEvent
local selectRemote = ReplicatedStorage:WaitForChild("WeaponProgression_Select") :: RemoteEvent
local passRemote = ReplicatedStorage:WaitForChild("WeaponProgression_Pass") :: RemoteEvent
local banRemote = ReplicatedStorage:WaitForChild("WeaponProgression_Ban") :: RemoteEvent
local PRODUCTION_GUI_NAME = "WeaponChoiceV2"

local RARITY_COLORS = {
	Common = Color3.fromRGB(80, 220, 120), Rare = Color3.fromRGB(80, 155, 255),
	Epic = Color3.fromRGB(185, 95, 255), Legendary = Color3.fromRGB(255, 245, 99),
}

local function applyRarityGradient(gradient: UIGradient, rarityColor: Color3)
	local dark = Color3.fromRGB(4, 8, 16)
	local white = Color3.fromRGB(245, 246, 255)

	if gradient.Name == "DA_CardGradient" then
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, dark:Lerp(rarityColor, 0.26)),
			ColorSequenceKeypoint.new(0.34, Color3.fromRGB(8, 13, 20)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(5, 9, 15)),
		})
	elseif gradient.Name == "MaterialGradient" then
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, rarityColor:Lerp(white, 0.18)),
			ColorSequenceKeypoint.new(0.5, rarityColor),
			ColorSequenceKeypoint.new(1, rarityColor:Lerp(dark, 0.35)),
		})
	elseif gradient.Name == "GlassGradient" then
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, white),
			ColorSequenceKeypoint.new(0.46, rarityColor:Lerp(white, 0.52)),
			ColorSequenceKeypoint.new(1, rarityColor),
		})
	elseif gradient.Name == "AuraGradient" then
		local shadow = rarityColor:Lerp(dark, 0.55)
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, shadow),
			ColorSequenceKeypoint.new(0.38, rarityColor:Lerp(dark, 0.25)),
			ColorSequenceKeypoint.new(0.5, rarityColor:Lerp(white, 0.35)),
			ColorSequenceKeypoint.new(0.62, rarityColor),
			ColorSequenceKeypoint.new(1, shadow),
		})
	elseif gradient.Name == "WashGradient" or gradient.Name == "SheenGradient" then
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, rarityColor:Lerp(white, 0.58)),
			ColorSequenceKeypoint.new(0.5, white),
			ColorSequenceKeypoint.new(1, rarityColor:Lerp(white, 0.4)),
		})
	end
end

local function applyRarityVisual(card: Frame, rarityColor: Color3)
	card:SetAttribute("RarityColor", rarityColor)

	for _, descendant in ipairs(card:GetDescendants()) do
		if descendant:IsA("UIGradient") then
			applyRarityGradient(descendant, rarityColor)
		elseif descendant:IsA("UIStroke") and (
			descendant.Name == "RarityStroke"
			or descendant.Name == "IdleAuraStroke"
		) then
			descendant.Color = rarityColor
		elseif descendant:IsA("GuiObject") and (
			descendant.Name == "RarityAccent"
			or descendant.Name == "RarityAura"
			or descendant.Name == "MaterialLayer"
			or descendant.Name == "GlassSurface"
			or descendant.Name == "HoverWash"
		) then
			descendant.BackgroundColor3 = rarityColor
		end
	end
end

local function find(root: Instance?, path: {string}): Instance?
	local current = root
	for _, name in ipairs(path) do current = current and current:FindFirstChild(name) end
	return current
end

local function initialise()
	local templateGui = playerGui:WaitForChild(UiTemplateConfig.ProductionTemplateGuiName, 30)
	if templateGui == nil or not templateGui:IsA("ScreenGui") then return end
	local templateCanvas = templateGui:FindFirstChild("RunCanvas")
	local templateDock = templateCanvas and templateCanvas:FindFirstChild("WeaponChoiceDock")
	local templateContract = templateGui:FindFirstChild("DesignContract")
	local templateController = templateGui:FindFirstChild("WeaponChoiceEffectsController")
	if templateDock == nil or not templateDock:IsA("Frame") or templateContract == nil
		or templateController == nil or not templateController:IsA("LocalScript") then
		DebugLog.Warn("UI", "Choix d'arme V2 non actif, recette de production incomplete")
		return
	end

	local previous = playerGui:FindFirstChild(PRODUCTION_GUI_NAME)
	if previous then previous:Destroy() end
	local gui = Instance.new("ScreenGui")
	gui.Name = PRODUCTION_GUI_NAME
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 22
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false
	gui.Parent = playerGui
	local overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.fromRGB(2, 5, 11)
	overlay.BackgroundTransparency = 0.36
	overlay.BorderSizePixel = 0
	overlay.Parent = gui
	local canvas = Instance.new("Frame")
	canvas.Name = "RunCanvas"
	canvas.Size = UDim2.fromScale(1, 1)
	canvas.BackgroundTransparency = 1
	canvas.Parent = gui
	local dock = templateDock:Clone()
	dock.Name = "WeaponChoiceDock"
	dock.Visible = true
	dock:SetAttribute("ProductionBound", true)
	dock.Parent = canvas
	templateContract:Clone().Parent = gui
	local effects = templateController:Clone()
	effects.Enabled = true
	effects.Parent = gui
	templateGui.Enabled = false

	local offersRoot = find(dock, {"WeaponChoicePanel", "Content", "Offers"})
	local title = find(dock, {"WeaponChoicePanel", "Content", "Title"})
	local subtitle = find(dock, {"WeaponChoicePanel", "Content", "Subtitle"})
	local passButton = find(dock, {"WeaponChoicePanel", "Content", "ActionRow", "ButtonRow", "Pass"})
	local banButton = find(dock, {"WeaponChoicePanel", "Content", "ActionRow", "ButtonRow", "Ban"})
	if offersRoot == nil or passButton == nil or not passButton:IsA("TextButton")
		or banButton == nil or not banButton:IsA("TextButton") then
		gui:Destroy()
		DebugLog.Warn("UI", "Choix d'arme V2 non actif, contenu incomplet")
		return
	end

	local currentChoiceId: string? = nil
	local banMode = false
	local offerConnections: { RBXScriptConnection } = {}

	local function refreshButtons()
		local passCredits = math.max(0, math.floor(tonumber(player:GetAttribute("RunPassCredits")) or 0))
		local banCredits = math.max(0, math.floor(tonumber(player:GetAttribute("RunBanCredits")) or 0))
		passButton.Text = ("PASSER (%d/%d)"):format(passCredits, tonumber(player:GetAttribute("RunPassCreditsMax")) or 0)
		banButton.Text = if banMode then "CHOISIR L'ARME" else ("BANNIR (%d/%d)"):format(banCredits, tonumber(player:GetAttribute("RunBanCreditsMax")) or 0)
		passButton.Active = passCredits > 0
		banButton.Active = banCredits > 0
		banButton:SetAttribute("ActionState", if banMode then "Targeting" elseif banCredits > 0 then "Available" else "Consumed")
	end

	local function applyOption(card: Frame, option)
		local color = RARITY_COLORS[option.Rarity] or RARITY_COLORS.Common
		card.Visible = true
		card.Active = true
		card:SetAttribute("ComponentRecipe", "Recipe.WeaponOffer")
		card:SetAttribute("WeaponId", option.WeaponId)
		card:SetAttribute("OptionId", option.OptionId)
		card:SetAttribute("RarityId", option.Rarity)
		applyRarityVisual(card, color)
		local content = card:FindFirstChild("Content")
		if content then
			local rarity = content:FindFirstChild("Rarity")
			local icon = content:FindFirstChild("Icon")
			local name = content:FindFirstChild("Name")
			local effect = content:FindFirstChild("Effect")
			local kind = content:FindFirstChild("OfferKind")
			if rarity and rarity:IsA("TextLabel") then rarity.Text = string.upper(option.RarityName or option.Rarity); rarity.TextColor3 = color end
			if icon and icon:IsA("ImageLabel") then icon.Image = tostring(option.Icon or ""); icon.Visible = icon.Image ~= "" end
			if name and name:IsA("TextLabel") then name.Text = tostring(option.Name) end
			if effect and effect:IsA("TextLabel") then effect.Text = string.upper(tostring(option.Effect)); effect.TextColor3 = color end
			if kind and kind:IsA("TextLabel") then
				kind.Text = if option.Kind == "New" then "NOUVELLE ARME" else ("EVOLUTION  NIV. %d > %d"):format(option.CurrentLevel, option.CurrentLevel + 1)
				kind.TextColor3 = color
			end
		end
	end

	local function display(payload)
		currentChoiceId = tostring(payload.ChoiceId or "")
		banMode = false
		if title and title:IsA("TextLabel") then title.Text = "CHOIX D'ARME" end
		if subtitle and subtitle:IsA("TextLabel") then subtitle.Text = "Choisis une arme ou renforce ton arsenal" end
		for _, connection in ipairs(offerConnections) do connection:Disconnect() end
		table.clear(offerConnections)
		for index = 1, 3 do
			local card = offersRoot:FindFirstChild("Offer" .. index)
			local option = payload.Choices and payload.Choices[index]
			if card and card:IsA("Frame") then
				card.Visible = option ~= nil
				if option then
					applyOption(card, option)
					table.insert(offerConnections, card.InputBegan:Connect(function(input)
						if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
						if currentChoiceId == nil then return end
						if banMode then banRemote:FireServer(currentChoiceId, option.OptionId) else selectRemote:FireServer(currentChoiceId, option.OptionId) end
					end))
				end
			end
		end
		refreshButtons()
		gui.Enabled = true
	end

	passButton.Activated:Connect(function()
		if currentChoiceId then passRemote:FireServer(currentChoiceId) end
	end)
	banButton.Activated:Connect(function()
		if currentChoiceId and (tonumber(player:GetAttribute("RunBanCredits")) or 0) > 0 then
			banMode = not banMode
			refreshButtons()
		end
	end)
	showRemote.OnClientEvent:Connect(display)
	hideRemote.OnClientEvent:Connect(function()
		currentChoiceId = nil
		banMode = false
		gui.Enabled = false
	end)
	for _, attribute in ipairs({"RunPassCredits", "RunPassCreditsMax", "RunBanCredits", "RunBanCreditsMax"}) do
		player:GetAttributeChangedSignal(attribute):Connect(refreshButtons)
	end
	playerGui:SetAttribute("WeaponChoiceV2Ready", true)
	DebugLog.Info("UI", "Choix d'arme V2 branche en production")
end

task.spawn(function()
	local success, err = pcall(initialise)
	if not success then DebugLog.Warn("UI", "Initialisation choix d'arme V2 impossible", { Error = tostring(err) }) end
end)
