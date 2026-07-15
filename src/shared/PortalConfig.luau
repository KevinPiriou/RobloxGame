return {
	TemplateFolderName = "PortalBossTemplate",
	RuntimeFolderName = "PortalsRuntime",
	PortalTemplateName = "PortalBoss",

	InitialSpawnCount = 1,
	SpawnWorldCenter = Vector3.new(0, 0, 0),
	SpawnWorldMinRadius = 90,
	SpawnWorldMaxRadius = 340,
	SpawnWorldMinObjectDistance = 36,
	SpawnWorldAttemptsPerPortal = 96,
	SpawnWorldJitterRadius = 20,
	SpawnWorldEdgeInset = 20,
	SpawnRaycastHeight = 240,
	SpawnRaycastDepth = 520,
	SpawnSurfaceOffset = 0,
	-- Le portail accepte le sol naturel et les sommets des plateformes.
	-- Les volumes Bottom et les rampes restent exclus par WorldSpawnService.
	GeneratedTerrainClearance = 28,
	GeneratedTerrainFallbackClearance = 10,
	RejectGeneratedTerrain = false,
	RejectedSurfaceNameContains = {
		"LevelLimit",
		"Montain",
		"MurInvisible",
	},
}
