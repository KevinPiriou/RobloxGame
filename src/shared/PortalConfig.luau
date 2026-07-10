return {
	TemplateFolderName = "PortalBossTemplate",
	RuntimeFolderName = "PortalsRuntime",
	PortalTemplateName = "PortalBoss",

	InitialSpawnCount = 1,
	SpawnWorldCenter = Vector3.new(0, 0, 0),
	SpawnWorldMinRadius = 90,
	SpawnWorldMaxRadius = 180,
	SpawnWorldMinObjectDistance = 36,
	SpawnWorldAttemptsPerPortal = 36,
	SpawnWorldJitterRadius = 20,
	SpawnRaycastHeight = 240,
	SpawnRaycastDepth = 520,
	SpawnSurfaceOffset = 0,
	RejectedSurfaceNameContains = {
		"MurInvisible",
	},
}
