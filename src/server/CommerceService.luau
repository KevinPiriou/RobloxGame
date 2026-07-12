local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CommerceConfig = require(Shared:WaitForChild("CommerceConfig"))
local DebugLog = require(Shared:WaitForChild("DebugLog"))

local CommerceService = {}

local purchaseDataStore = DataStoreService:GetDataStore(CommerceConfig.DataStoreName)
local profilesByUserId = {}
local lastPurchaseRequestAtByUserId = {}
local isStarted = false

local function getOrCreateRemote(remoteName)
	local remote = ReplicatedStorage:FindFirstChild(remoteName)

	if remote == nil then
		remote = Instance.new("RemoteEvent")
		remote.Name = remoteName
		remote.Parent = ReplicatedStorage
	end

	assert(remote:IsA("RemoteEvent"), remoteName .. " doit etre un RemoteEvent.")

	return remote
end

local purchaseRequestRemote = getOrCreateRemote("Commerce_RequestPurchase")
local promptPurchaseRemote = getOrCreateRemote("Commerce_PromptPurchase")

local function createDefaultData()
	return {
		Version = 1,
		PerkRerollCredits = 0,
		ItemRerollCredits = 0,
		ProcessedReceipts = {},
	}
end

local function normalizeData(rawData)
	local data = createDefaultData()

	if typeof(rawData) ~= "table" then
		return data
	end

	data.PerkRerollCredits = math.max(0, math.floor(tonumber(rawData.PerkRerollCredits) or 0))
	data.ItemRerollCredits = math.max(0, math.floor(tonumber(rawData.ItemRerollCredits) or 0))

	if typeof(rawData.ProcessedReceipts) == "table" then
		for receiptId, timestamp in pairs(rawData.ProcessedReceipts) do
			if typeof(receiptId) == "string" and typeof(timestamp) == "number" then
				data.ProcessedReceipts[receiptId] = timestamp
			end
		end
	end

	return data
end

local function trimReceiptHistory(data)
	local receipts = {}

	for receiptId, timestamp in pairs(data.ProcessedReceipts) do
		table.insert(receipts, {
			Id = receiptId,
			Timestamp = timestamp,
		})
	end

	table.sort(receipts, function(left, right)
		return left.Timestamp < right.Timestamp
	end)

	local removeCount = #receipts - CommerceConfig.ReceiptHistoryLimit

	for index = 1, math.max(0, removeCount) do
		data.ProcessedReceipts[receipts[index].Id] = nil
	end
end

local function getDataStoreKey(player)
	return "Player_" .. player.UserId
end

local function getOrCreateProfile(player)
	local profile = profilesByUserId[player.UserId]

	if profile == nil then
		profile = {
			Data = createDefaultData(),
			Loaded = false,
			SessionOnly = false,
			HasFounderPass = false,
		}
		profilesByUserId[player.UserId] = profile
	end

	return profile
end

local function publishProfile(player, profile)
	if player.Parent ~= Players then
		return
	end

	player:SetAttribute("PerkRerollCredits", profile.Data.PerkRerollCredits)
	player:SetAttribute("ItemRerollCredits", profile.Data.ItemRerollCredits)
	player:SetAttribute("HasFounderPass", profile.HasFounderPass == true)
end

local function refreshFounderPass(player, profile)
	local offer = CommerceConfig.GetOffer("FounderPass")

	if offer == nil or typeof(offer.ProductId) ~= "number" or offer.ProductId <= 0 then
		profile.HasFounderPass = false
		publishProfile(player, profile)
		return
	end

	local success, ownsPass = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, offer.ProductId)
	end)

	if success then
		profile.HasFounderPass = ownsPass == true
	else
		DebugLog.Warn("Commerce", "Verification du pass Fondateur impossible", {
			Player = player.Name,
			Error = tostring(ownsPass),
		})
	end

	publishProfile(player, profile)
end

local function loadProfile(player)
	local profile = getOrCreateProfile(player)
	local success, rawData = pcall(function()
		return purchaseDataStore:GetAsync(getDataStoreKey(player))
	end)

	if success then
		profile.Data = normalizeData(rawData)
		profile.Loaded = true
		profile.SessionOnly = false
	elseif RunService:IsStudio() then
		profile.Data = createDefaultData()
		profile.Loaded = true
		profile.SessionOnly = true
		DebugLog.Warn("Commerce", "DataStore indisponible dans Studio, profil de test en memoire", {
			Player = player.Name,
			Error = tostring(rawData),
		})
	else
		profile.Loaded = false
		DebugLog.Warn("Commerce", "Chargement commerce impossible", {
			Player = player.Name,
			Error = tostring(rawData),
		})
	end

	refreshFounderPass(player, profile)
end

local function applyDeveloperProductGrant(data, offer)
	data.PerkRerollCredits += math.max(0, math.floor(tonumber(offer.PerkRerollCredits) or 0))
	data.ItemRerollCredits += math.max(0, math.floor(tonumber(offer.ItemRerollCredits) or 0))
end

local function processReceipt(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)

	if player == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local profile = getOrCreateProfile(player)

	if not profile.Loaded then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local offer = CommerceConfig.GetDeveloperProductOffer(receiptInfo.ProductId)

	if offer == nil then
		DebugLog.Warn("Commerce", "Receipt produit inconnu ou desactive", {
			Player = player.Name,
			ProductId = receiptInfo.ProductId,
			PurchaseId = receiptInfo.PurchaseId,
		})
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if profile.SessionOnly then
		if profile.Data.ProcessedReceipts[receiptInfo.PurchaseId] == nil then
			applyDeveloperProductGrant(profile.Data, offer)
			profile.Data.ProcessedReceipts[receiptInfo.PurchaseId] = os.time()
			trimReceiptHistory(profile.Data)
			publishProfile(player, profile)
		end

		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local success, updatedData = pcall(function()
		return purchaseDataStore:UpdateAsync(getDataStoreKey(player), function(rawData)
			local data = normalizeData(rawData)

			if data.ProcessedReceipts[receiptInfo.PurchaseId] ~= nil then
				return data
			end

			applyDeveloperProductGrant(data, offer)
			data.ProcessedReceipts[receiptInfo.PurchaseId] = os.time()
			trimReceiptHistory(data)
			return data
		end)
	end)

	if not success then
		DebugLog.Warn("Commerce", "Receipt non traite, ecriture DataStore impossible", {
			Player = player.Name,
			ProductId = receiptInfo.ProductId,
			PurchaseId = receiptInfo.PurchaseId,
			Error = tostring(updatedData),
		})
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	profile.Data = normalizeData(updatedData)
	publishProfile(player, profile)
	DebugLog.Info("Commerce", "Developer Product accorde", {
		Player = player.Name,
		Offer = offer.Id,
		ProductId = receiptInfo.ProductId,
		PurchaseId = receiptInfo.PurchaseId,
	})

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function onPurchaseRequested(player, offerId)
	if typeof(offerId) ~= "string" then
		return
	end

	local now = os.clock()
	local lastRequestAt = lastPurchaseRequestAtByUserId[player.UserId] or 0

	if now - lastRequestAt < CommerceConfig.PurchaseRequestCooldown then
		return
	end

	lastPurchaseRequestAtByUserId[player.UserId] = now

	local offer = CommerceConfig.GetOffer(offerId)

	if not CommerceConfig.IsOfferConfigured(offer) then
		DebugLog.Warn("Commerce", "Demande achat refusee, offre non configuree", {
			Player = player.Name,
			Offer = offerId,
		})
		return
	end

	local profile = getOrCreateProfile(player)

	if not profile.Loaded then
		return
	end

	if offer.Kind == "GamePass" and profile.HasFounderPass then
		return
	end

	promptPurchaseRemote:FireClient(player, {
		OfferId = offer.Id,
		Kind = offer.Kind,
		ProductId = offer.ProductId,
	})
end

local function onGamePassPurchaseFinished(player, gamePassId, wasPurchased)
	local offer = CommerceConfig.GetOffer("FounderPass")

	if wasPurchased ~= true
		or offer == nil
		or offer.Kind ~= "GamePass"
		or offer.ProductId ~= gamePassId then
		return
	end

	local profile = getOrCreateProfile(player)
	profile.HasFounderPass = true
	publishProfile(player, profile)
	DebugLog.Info("Commerce", "Pass Fondateur confirme", {
		Player = player.Name,
		PassId = gamePassId,
	})
end

function CommerceService.TryConsumePerkReroll(player)
	local profile = getOrCreateProfile(player)

	if not profile.Loaded then
		return false, "ProfileNotLoaded"
	end

	if profile.Data.PerkRerollCredits <= 0 then
		return false, "NoCredits"
	end

	if profile.SessionOnly then
		profile.Data.PerkRerollCredits -= 1
		publishProfile(player, profile)
		return true
	end

	local consumed = false
	local success, updatedData = pcall(function()
		return purchaseDataStore:UpdateAsync(getDataStoreKey(player), function(rawData)
			local data = normalizeData(rawData)

			if data.PerkRerollCredits <= 0 then
				consumed = false
				return data
			end

			data.PerkRerollCredits -= 1
			consumed = true
			return data
		end)
	end)

	if not success then
		DebugLog.Warn("Commerce", "Consommation reroll perk impossible", {
			Player = player.Name,
			Error = tostring(updatedData),
		})
		return false, "SaveFailed"
	end

	profile.Data = normalizeData(updatedData)
	publishProfile(player, profile)

	if not consumed then
		return false, "NoCredits"
	end

	return true
end

function CommerceService.SetupPlayer(player)
	loadProfile(player)
end

function CommerceService.RemovePlayer(player)
	profilesByUserId[player.UserId] = nil
	lastPurchaseRequestAtByUserId[player.UserId] = nil
end

function CommerceService.Start()
	if isStarted then
		return
	end

	isStarted = true
	purchaseRequestRemote.OnServerEvent:Connect(onPurchaseRequested)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(onGamePassPurchaseFinished)

	MarketplaceService.ProcessReceipt = processReceipt
	DebugLog.Info("Commerce", "Service commerce demarre")
end

return CommerceService
