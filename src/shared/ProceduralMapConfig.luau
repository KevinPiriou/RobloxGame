local ProceduralMapConfig = {
	Enabled = true,
	TemplateFolderName = "MapTemplates",
	KitFolderName = "ProceduralKit",
	LegacyWorkspaceKitName = "Kit_Stud",
	TerrainFolderName = "GeneratedTerrain",
	DecorationFolderName = "GeneratedDecor",
	IgnoreAsSurfaceAttributeName = "MegaRobloxIgnoreAsSpawnSurface",
	GeneratedTerrainAttributeName = "MegaRobloxGeneratedTerrain",
	GeneratedDecorationAttributeName = "MegaRobloxGeneratedDecoration",
	TerrainKindAttributeName = "MegaRobloxTerrainKind",

	-- Les limites visuelles viendront plus tard. Pour l'instant, le relief peut
	-- exploiter presque toute la base tout en gardant une fine marge de surete.
	PlayableInset = 12,
	ArrivalClearRadius = 66,
	AnchorAttempts = 60,
	MinimumLayoutCount = 6,
	MaximumLayoutCount = 18,
	MaximumGeneratedPlatforms = 56,
	PlatformSpacing = 14,
	-- La couverture est estimee a partir des sommets jouables, pas des volumes de terre.
	TargetCoverageRatio = 0.38,

	TopThickness = 4,
	-- Le terrain est porte par les palettes de chapitre. Les surfaces lisses
	-- evitent que le sol runtime ressemble a une baseplate de prototype.
	GeneratedTerrainMaterial = Enum.Material.SmoothPlastic,
	GeneratedTerrainSurface = Enum.SurfaceType.Smooth,
	MinimumElevation = 4,
	MaximumElevation = 180,
	ElevationOffset = -5,
	ElevationScaleMinimum = 0.85,
	ElevationScaleMaximum = 2.7,
	TerrainBatchSize = 2,
	DecorationBatchSize = 4,

	Base = {
		FolderName = "GeneratedBase",
		SurfaceOffset = 0.04,
		MinimumBottomDepth = 24,
		MinimumSourceArea = 40000,
		-- La plaque source ne doit pas rester sous la base generee : deux surfaces
		-- presque coplanaires recreent un rendu parasite visible a distance.
		DestroySourceSurface = true,
		RejectedSurfaceNameContains = {
			"LevelLimit",
			"Montain",
			"MurInvisible",
		},
	},

	DefaultTerrainThemeId = "Verdant",
	-- Chaque theme garde la meme structure de terrain : seule sa palette change.
	-- Cela permet de creer des chapitres distincts sans dupliquer la geometrie.
	TerrainThemes = {
		Verdant = {
			Grass = {
				Color3.fromRGB(56, 137, 49),
				Color3.fromRGB(66, 151, 56),
				Color3.fromRGB(47, 122, 43),
				Color3.fromRGB(76, 158, 61),
			},
			Dirt = {
				Color3.fromRGB(96, 54, 34),
				Color3.fromRGB(108, 63, 39),
				Color3.fromRGB(84, 46, 30),
				Color3.fromRGB(118, 69, 42),
			},
			Ramp = {
				Color3.fromRGB(51, 127, 45),
				Color3.fromRGB(60, 140, 51),
				Color3.fromRGB(44, 113, 39),
				Color3.fromRGB(69, 147, 55),
			},
		},
		Azure = {
			Grass = {
				Color3.fromRGB(47, 111, 135),
				Color3.fromRGB(57, 127, 151),
				Color3.fromRGB(40, 95, 116),
				Color3.fromRGB(69, 138, 158),
			},
			Dirt = {
				Color3.fromRGB(49, 69, 89),
				Color3.fromRGB(58, 80, 102),
				Color3.fromRGB(42, 59, 77),
				Color3.fromRGB(67, 90, 112),
			},
			Ramp = {
				Color3.fromRGB(42, 103, 126),
				Color3.fromRGB(51, 117, 140),
				Color3.fromRGB(36, 88, 108),
				Color3.fromRGB(62, 129, 147),
			},
		},
		Ember = {
			Grass = {
				Color3.fromRGB(156, 61, 47),
				Color3.fromRGB(175, 73, 52),
				Color3.fromRGB(132, 49, 40),
				Color3.fromRGB(190, 84, 59),
			},
			Dirt = {
				Color3.fromRGB(91, 39, 31),
				Color3.fromRGB(106, 47, 36),
				Color3.fromRGB(76, 32, 28),
				Color3.fromRGB(119, 56, 42),
			},
			Ramp = {
				Color3.fromRGB(142, 52, 42),
				Color3.fromRGB(160, 63, 47),
				Color3.fromRGB(119, 43, 36),
				Color3.fromRGB(177, 75, 54),
			},
		},
	},

	Ramp = {
		MinimumLength = 24,
		MaximumLength = 230,
		LengthPerElevation = 1.35,
		YawCorrection = 0,
	},

	Links = {
		Enabled = true,
		Width = 22,
		Elevation = 10,
		MinimumLength = 24,
		MaximumLength = 130,
		MaximumConnectionDistance = 420,
		Clearance = 5,
	},

	Decorations = {
		MinimumTrunks = 3,
		MaximumTrunks = 5,
		MinimumBalls = 5,
		MaximumBalls = 8,
		PlatformMargin = 12,
		VerticalPadding = 0.2,
		TrunkLeanRadians = math.rad(5),
	},

	-- Chaque layout ne contient que des rotations cardinales. Le service calcule
	-- son emprise reelle, y compris les rampes, avant de reserver une position.
	Layouts = {
		{
			Id = "SoloButte",
			Weight = 8,
			Platforms = {
				{ Offset = Vector2.new(0, 0), Size = Vector2.new(72, 60), Elevation = 18, Ramps = { "South" } },
			},
		},
		{
			Id = "LongRidge",
			Weight = 7,
			Platforms = {
				{ Offset = Vector2.new(0, 0), Size = Vector2.new(118, 46), Elevation = 20, Ramps = { "East", "West" } },
			},
		},
		{
			Id = "TwinTerraces",
			Weight = 7,
			Platforms = {
				{ Offset = Vector2.new(-34, -6), Size = Vector2.new(62, 54), Elevation = 14, Ramps = { "South" } },
				{ Offset = Vector2.new(38, 12), Size = Vector2.new(58, 50), Elevation = 26, Ramps = { "North" } },
			},
		},
		{
			Id = "ThreeSteps",
			Weight = 7,
			Platforms = {
				{ Offset = Vector2.new(-52, -26), Size = Vector2.new(56, 48), Elevation = 12, Ramps = { "West" } },
				{ Offset = Vector2.new(0, 0), Size = Vector2.new(58, 52), Elevation = 22, Ramps = { "South" } },
				{ Offset = Vector2.new(50, 26), Size = Vector2.new(50, 46), Elevation = 30, Ramps = { "East" } },
			},
		},
		{
			Id = "Crossroads",
			Weight = 6,
			Platforms = {
				{ Offset = Vector2.new(0, 0), Size = Vector2.new(76, 58), Elevation = 22, Ramps = { "North", "South", "West" } },
			},
		},
		{
			Id = "Gateway",
			Weight = 7,
			Platforms = {
				{ Offset = Vector2.new(-42, 0), Size = Vector2.new(56, 68), Elevation = 20, Ramps = { "South" } },
				{ Offset = Vector2.new(42, 0), Size = Vector2.new(56, 68), Elevation = 20, Ramps = { "North" } },
			},
		},
		{
			Id = "Crescent",
			Weight = 6,
			Platforms = {
				{ Offset = Vector2.new(-54, 20), Size = Vector2.new(54, 48), Elevation = 16, Ramps = { "West" } },
				{ Offset = Vector2.new(0, -30), Size = Vector2.new(62, 52), Elevation = 24, Ramps = { "South" } },
				{ Offset = Vector2.new(54, 20), Size = Vector2.new(54, 48), Elevation = 16, Ramps = { "East" } },
			},
		},
		{
			Id = "Bastion",
			Weight = 4,
			Platforms = {
				{ Offset = Vector2.new(0, 0), Size = Vector2.new(94, 74), Elevation = 54, Ramps = { "South", "East" } },
				{ Offset = Vector2.new(-64, -34), Size = Vector2.new(44, 42), Elevation = 12, Ramps = { "West" } },
			},
		},
		{
			Id = "WideSteps",
			Weight = 7,
			Platforms = {
				{ Offset = Vector2.new(-58, 0), Size = Vector2.new(50, 64), Elevation = 14, Ramps = { "South" } },
				{ Offset = Vector2.new(0, 0), Size = Vector2.new(54, 68), Elevation = 22, Ramps = { "North" } },
				{ Offset = Vector2.new(58, 0), Size = Vector2.new(50, 64), Elevation = 30, Ramps = { "East" } },
			},
		},
		{
			Id = "FourCorners",
			Weight = 5,
			Platforms = {
				{ Offset = Vector2.new(-42, -42), Size = Vector2.new(48, 48), Elevation = 16, Ramps = { "South" } },
				{ Offset = Vector2.new(42, -42), Size = Vector2.new(48, 48), Elevation = 24, Ramps = { "East" } },
				{ Offset = Vector2.new(-42, 42), Size = Vector2.new(48, 48), Elevation = 24, Ramps = { "West" } },
				{ Offset = Vector2.new(42, 42), Size = Vector2.new(48, 48), Elevation = 16, Ramps = { "North" } },
			},
		},
		{
			Id = "LowIslands",
			Weight = 9,
			Platforms = {
				{ Offset = Vector2.new(-46, -18), Size = Vector2.new(42, 40), Elevation = 10, Ramps = { "West" } },
				{ Offset = Vector2.new(6, 16), Size = Vector2.new(46, 44), Elevation = 12, Ramps = { "South" } },
				{ Offset = Vector2.new(52, -12), Size = Vector2.new(40, 38), Elevation = 9, Ramps = { "East" } },
			},
		},
		{
			Id = "ForkedPath",
			Weight = 7,
			Platforms = {
				{ Offset = Vector2.new(0, 0), Size = Vector2.new(54, 50), Elevation = 18, Ramps = { "South" } },
				{ Offset = Vector2.new(-46, 42), Size = Vector2.new(42, 44), Elevation = 24, Ramps = { "West" } },
				{ Offset = Vector2.new(46, 42), Size = Vector2.new(42, 44), Elevation = 24, Ramps = { "East" } },
			},
		},
		{
			Id = "Switchback",
			Weight = 6,
			Platforms = {
				{ Offset = Vector2.new(-62, -36), Size = Vector2.new(42, 40), Elevation = 11, Ramps = { "West" } },
				{ Offset = Vector2.new(-20, -4), Size = Vector2.new(46, 44), Elevation = 20, Ramps = { "South" } },
				{ Offset = Vector2.new(24, 28), Size = Vector2.new(46, 44), Elevation = 28, Ramps = { "North" } },
				{ Offset = Vector2.new(66, 56), Size = Vector2.new(40, 38), Elevation = 34, Ramps = { "East" } },
			},
		},
		{
			Id = "TerraceGarden",
			Weight = 7,
			Platforms = {
				{ Offset = Vector2.new(-48, 0), Size = Vector2.new(48, 58), Elevation = 14, Ramps = { "South" } },
				{ Offset = Vector2.new(10, 0), Size = Vector2.new(58, 66), Elevation = 22, Ramps = { "North" } },
				{ Offset = Vector2.new(64, 0), Size = Vector2.new(42, 50), Elevation = 16, Ramps = { "East" } },
			},
		},
		{
			Id = "TwinRidge",
			Weight = 6,
			Platforms = {
				{ Offset = Vector2.new(-34, -34), Size = Vector2.new(72, 38), Elevation = 22, Ramps = { "West" } },
				{ Offset = Vector2.new(34, 34), Size = Vector2.new(72, 38), Elevation = 28, Ramps = { "East" } },
			},
		},
		{
			Id = "CrossSteps",
			Weight = 6,
			Platforms = {
				{ Offset = Vector2.new(0, 0), Size = Vector2.new(54, 54), Elevation = 26, Ramps = { "North", "South" } },
				{ Offset = Vector2.new(-58, 0), Size = Vector2.new(38, 42), Elevation = 14, Ramps = { "West" } },
				{ Offset = Vector2.new(58, 0), Size = Vector2.new(38, 42), Elevation = 14, Ramps = { "East" } },
			},
		},
		{
			Id = "TallSpire",
			Weight = 3,
			Platforms = {
				{ Offset = Vector2.new(0, 0), Size = Vector2.new(64, 64), Elevation = 58, Ramps = { "South" } },
				{ Offset = Vector2.new(-52, -46), Size = Vector2.new(40, 40), Elevation = 12, Ramps = { "West" } },
			},
		},
		{
			Id = "Citadel",
			Weight = 2,
			Platforms = {
				{ Offset = Vector2.new(0, 0), Size = Vector2.new(80, 80), Elevation = 66, Ramps = { "South" } },
				{ Offset = Vector2.new(58, -44), Size = Vector2.new(40, 42), Elevation = 18, Ramps = { "East" } },
			},
		},
	},
}

return ProceduralMapConfig
