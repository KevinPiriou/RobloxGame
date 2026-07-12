--!strict

-- Gere les achats sans bloquer la creation des panneaux du lobby.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local CommerceConfig = require(Shared:WaitForChild("CommerceConfig"))

local purchaseRequestRemote: RemoteEvent? = nil
local pendingPurchaseRequests: {[string]: boolean} = {}

local function getPurchaseText(valueText: string, isConfigured: boolean): string
	if isConfigured then
		return valueText .. " - ACHETER"
	end

	return valueText .. " - BIENTOT"
end

local function requestPurchase(offerId: string)
	if purchaseRequestRemote ~= nil then
		purchaseRequestRemote:FireServer(offerId)
		return
	end

	-- Le clic reste valide si le RemoteEvent est encore en cours de replication.
	pendingPurchaseRequests[offerId] = true
end

local function attachPurchaseButton(card: Frame)
	if card:GetAttribute("CommerceBound") == true then
		return
	end

	card:SetAttribute("CommerceBound", true)
	local offerId = card:GetAttribute("OfferId")

	if typeof(offerId) ~= "string" then
		return
	end

	local value = card:WaitForChild("Value", 5)

	if value == nil or not value:IsA("Frame") then
		return
	end

	local valueLabel = value:FindFirstChild("ValueLabel")

	if valueLabel == nil or not valueLabel:IsA("TextLabel") then
		return
	end

	local offer = CommerceConfig.GetOffer(offerId)
	local isConfigured = CommerceConfig.IsOfferConfigured(offer)
	local baseValueText = valueLabel:GetAttribute("CommerceBaseValue")

	if typeof(baseValueText) ~= "string" then
		baseValueText = valueLabel.Text
		valueLabel:SetAttribute("CommerceBaseValue", baseValueText)
	end

	valueLabel.Text = getPurchaseText(baseValueText, isConfigured)

	if not isConfigured or offer == nil or value:FindFirstChild("PurchaseButton") ~= nil then
		return
	end

	local button = Instance.new("TextButton")
	button.Name = "PurchaseButton"
	button.Size = UDim2.fromScale(1, 1)
	button.BackgroundTransparency = 1
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Text = ""
	button.ZIndex = valueLabel.ZIndex + 1
	button.Parent = value

	button.Activated:Connect(function()
		requestPurchase(offer.Id)
	end)
end

local function bindShopPanel(shopPanel: Frame)
	local function attachFromDescendant(descendant: Instance)
		if descendant:IsA("Frame") and descendant.Name == "GridCard" then
			task.spawn(attachPurchaseButton, descendant)
		end
	end

	for _, descendant in ipairs(shopPanel:GetDescendants()) do
		attachFromDescendant(descendant)
	end

	shopPanel.DescendantAdded:Connect(attachFromDescendant)
end

local function bindMenus()
	local menus = playerGui:WaitForChild("Menus", 30)

	if menus == nil or not menus:IsA("ScreenGui") then
		return
	end

	local shopPanel = menus:WaitForChild("ShopPanel", 30)

	if shopPanel and shopPanel:IsA("Frame") then
		bindShopPanel(shopPanel)
	end
end

local function onPromptPurchase(payload)
	if typeof(payload) ~= "table" then
		return
	end

	local offerId = payload.OfferId
	local offer = if typeof(offerId) == "string" then CommerceConfig.GetOffer(offerId) else nil

	if not CommerceConfig.IsOfferConfigured(offer) then
		return
	end

	if payload.ProductId ~= offer.ProductId or payload.Kind ~= offer.Kind then
		return
	end

	local success, errorMessage = pcall(function()
		if offer.Kind == "DeveloperProduct" then
			MarketplaceService:PromptProductPurchase(player, offer.ProductId)
		elseif offer.Kind == "GamePass" then
			MarketplaceService:PromptGamePassPurchase(player, offer.ProductId)
		end
	end)

	if not success then
		warn("[MegaRoblox][Commerce] Prompt achat impossible : " .. tostring(errorMessage))
	end
end

task.spawn(function()
	local remote = ReplicatedStorage:WaitForChild("Commerce_RequestPurchase", 30)

	if remote and remote:IsA("RemoteEvent") then
		purchaseRequestRemote = remote

		for offerId in pairs(pendingPurchaseRequests) do
			remote:FireServer(offerId)
		end

		table.clear(pendingPurchaseRequests)
	end
end)

task.spawn(function()
	local remote = ReplicatedStorage:WaitForChild("Commerce_PromptPurchase", 30)

	if remote and remote:IsA("RemoteEvent") then
		remote.OnClientEvent:Connect(onPromptPurchase)
	end
end)

task.spawn(bindMenus)
