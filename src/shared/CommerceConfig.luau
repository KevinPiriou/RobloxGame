-- Configuration des offres Robux. Les identifiants sont renseignes depuis le Creator Hub.

local CommerceConfig = {
	DataStoreName = "MegaRobloxCommerce_v1",
	ReceiptHistoryLimit = 120,
	PurchaseRequestCooldown = 1,
	Offers = {
		PerkRerollOne = {
			Id = "PerkRerollOne",
			Kind = "DeveloperProduct",
			ProductId = 3609427860,
			Enabled = true,
			PerkRerollCredits = 1,
		},
		PerkRerollThree = {
			Id = "PerkRerollThree",
			Kind = "DeveloperProduct",
			ProductId = 3609427919,
			Enabled = true,
			PerkRerollCredits = 3,
		},
		ItemRerollOne = {
			Id = "ItemRerollOne",
			Kind = "DeveloperProduct",
			ProductId = 3609429613,
			Enabled = false,
			ItemRerollCredits = 1,
		},
		ItemRerollThree = {
			Id = "ItemRerollThree",
			Kind = "DeveloperProduct",
			ProductId = 3609429674,
			Enabled = false,
			ItemRerollCredits = 3,
		},
		FounderPass = {
			Id = "FounderPass",
			Kind = "GamePass",
			ProductId = 0,
			Enabled = false,
		},
	},
}

function CommerceConfig.GetOffer(offerId)
	return CommerceConfig.Offers[offerId]
end

function CommerceConfig.IsOfferConfigured(offer)
	return offer ~= nil
		and offer.Enabled == true
		and typeof(offer.ProductId) == "number"
		and offer.ProductId > 0
end

function CommerceConfig.GetDeveloperProductOffer(productId)
	for _, offer in pairs(CommerceConfig.Offers) do
		if offer.Kind == "DeveloperProduct"
			and offer.Enabled == true
			and offer.ProductId == productId then
			return offer
		end
	end

	return nil
end

return CommerceConfig
