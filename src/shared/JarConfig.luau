return {
	TemplateFolderName = "JarTemplates",
	RuntimeFolderName = "JarsRuntime",
	JarName = "Jar",

	InitialSpawnCount = 40,
	SpawnWorldCenter = Vector3.new(0, 0, 0),
	SpawnWorldMinRadius = 16,
	SpawnWorldMaxRadius = 190,
	SpawnWorldMinObjectDistance = 12,
	SpawnWorldAttemptsPerJar = 28,
	SpawnWorldJitterRadius = 18,
	SpawnWorldEdgeInset = 12,
	SpawnRaycastHeight = 240,
	SpawnRaycastDepth = 520,
	SpawnSurfaceOffset = 0,
	RejectedSurfaceNameContains = {
		"MurInvisible",
	},

	PromptName = "JarBreakPrompt",
	PromptText = "Casser",
	PromptObjectText = "Jarre",
	BreakDistance = 5,
	BreakValidationTolerance = 0.75,
	BreakResolveDelay = 0.12,

	DropHeightOffset = 1.1,
	DropScatterRadius = 2.4,
	DropRaycastHeight = 24,
	DropRaycastDepth = 80,

	XpDropMin = 1,
	XpDropMax = 2,
	XpDropTier = 1,

	CoinDropMin = 1,
	CoinDropMax = 2,

	LootTable = {
		{
			Type = "Xp",
			Weight = 45,
		},
		{
			Type = "Coin",
			Weight = 35,
		},
		{
			Type = "Both",
			Weight = 20,
		},
	},
}
