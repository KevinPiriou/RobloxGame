--!strict

-- Reglages purement visuels des confirmations de gain.
-- Les montants restent calcules et envoyes par le serveur apres attribution.
return {
	RemoteName = "PickupFeedback_Show",
	CoalesceWindow = 0.12,
	ServerFlushInterval = 0.12,
	PopupDuration = 0.9,
	PopupMaxActive = 7,
	PopupWidth = 132,
	PopupHeight = 38,
	PopupRisePixels = 46,
	ResourceTravelStart = 0.42,
	ResourceArrivalAt = 0.9,
	MinimumAmounts = {
		HealRegen = 1,
		LifeStealHit = 1,
		LifeStealDot = 1,
	},
}
