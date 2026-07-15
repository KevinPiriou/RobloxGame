return {
	TemplateFolderName = "TotemTemplates",
	RuntimeFolderName = "TotemsRuntime",
	DifficultTotemName = "DifficultTotem",

	InitialSpawnCount = 5,
	SpawnWorldCenter = Vector3.new(0, 0, 0),
	SpawnWorldMinRadius = 28,
	SpawnWorldMaxRadius = 190,
	SpawnWorldMinObjectDistance = 24,
	SpawnWorldAttemptsPerTotem = 32,
	SpawnWorldJitterRadius = 18,
	SpawnWorldEdgeInset = 18,
	SpawnRaycastHeight = 240,
	SpawnRaycastDepth = 520,
	SpawnSurfaceOffset = 0,
	RejectedSurfaceNameContains = {
		"MurInvisible",
	},

	PromptName = "DifficultTotemPrompt",
	PromptText = "Activer",
	PromptObjectText = "Totem de difficulte",
	ActivationDistance = 9,
	DifficultyIncreasePercent = 0.05,
}
