return {
	SeedGuardEnabled = true,
	MaximumGenerationAttempts = 4,
	MaximumSeed = 2147483646,
	RetrySeedStride = 104729,
	HorizontalBoundsTolerance = 1.5,

	-- Une run sans une de ces familles est structurellement incomplete, meme si
	-- le joueur pourrait encore se deplacer sur la map.
	MinimumWorldCounts = {
		Portals = 1,
		Shrines = 1,
		Chests = 1,
		Totems = 1,
		Jars = 1,
	},

	-- Seuls les echecs qui peuvent reellement dependre de la seed sont rejoues.
	RetryableReasons = {
		TerrainPlacementInsufficient = true,
		TerrainSurfaceMissing = true,
		SeedTerrainInvalid = true,
		BossPortalMissing = true,
		SeedWorldInvalid = true,
	},
}
