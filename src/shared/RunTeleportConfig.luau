return {
	Enabled = true,

	-- Le GUI du lobby est le point d'entree principal.
	-- TeleportPart2 reste un declencheur physique facultatif pour compatibilite.
	-- TeleportPart1 est le point d'arrivee contenu dans chaque template de map.
	TriggerPartName = "TeleportPart2",
	ArrivalPartName = "TeleportPart1",
	ArrivalHeightOffset = 4,
	DisableTemplateTeleportScripts = true,
	DisableArrivalTouch = true,
	DestroyArrivalAfterUse = true,

	-- Par defaut on relance la run dans un serveur reserve du meme place.
	-- Si la map de run devient un autre place, remplacer par son PlaceId.
	RunPlaceId = game.PlaceId,
	ShouldReserveServer = true,
	-- Le lobby reste public. Garder le meme PlaceId tant que les deux zones partagent ce lieu.
	LobbyPlaceId = game.PlaceId,

	TouchCooldownSeconds = 6,
	StudioSimulatesArrival = true,
	StudioSimulatesLobbyReturn = true,

	TeleportData = {
		runMode = "Solo",
		difficulty = 1,
	},
}
