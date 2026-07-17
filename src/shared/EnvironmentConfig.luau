-- Profils d'ambiance locaux. Ils changent uniquement le rendu du joueur.

local EnvironmentConfig = {
	RuntimeFolderName = "MegaRobloxClientEnvironment",
	FallbackAtmosphereName = "MegaRoblox_FallbackAtmosphere",
	ColorCorrectionName = "MegaRoblox_RunColorCorrection",
	BloomName = "MegaRoblox_RunBloom",
	BlurName = "MegaRoblox_RunBlur",
	DepthOfFieldName = "MegaRoblox_RunDepthOfField",
	FallbackSunRaysName = "MegaRoblox_FallbackSunRays",
	MoteVolumesFolderName = "ForestMoteVolumes",
	TransitionSeconds = 0.65,
	MoteTexture = "rbxasset://textures/particles/sparkles_main.dds",
	-- L'emission commence au-dessus de la plus haute plateforme jouable de la map.
	AtmosphereSpawnMarginAbovePlatform = 24,
	MoteTileMaximumSize = 128,
	MoteAreaReference = 160000,
	MoteAreaMaxMultiplier = 6,
	-- Amplification temporaire, uniquement pour rendre le volume global visible pendant le debug visuel.
	MoteDebugRateMultiplier = 5.5,
	AtmosphereLeafRatePerTile = 0.75,
	AtmosphereLeafFallAcceleration = -3,
	AtmosphereLeafWindAccelerationMultiplier = 1.15,
	AtmosphereLeafPatterns = {
		{
			Name = "Particule_Atmos1",
			Texture = "rbxassetid://122342824323639",
			RateMultiplier = 1,
			SizeStart = 1.6,
			SizePeak = 2.8,
			SizeEnd = 1.2,
		},
		{
			Name = "Particule_Atmos2",
			Texture = "rbxassetid://140439338158742",
			RateMultiplier = 0.85,
			SizeStart = 1.3,
			SizePeak = 2.4,
			SizeEnd = 1,
		},
	},
	DefaultLevelId = "Map_Test",
	LobbyAtmosphere = {
		Density = 0,
		Offset = 0,
		Color = Color3.fromRGB(255, 255, 255),
		Decay = Color3.fromRGB(255, 255, 255),
		Glare = 0,
		Haze = 0,
	},

	QualityProfiles = {
		Performance = {
			AtmosphereDensityMultiplier = 0.76,
			BloomEnabled = false,
			SunRaysEnabled = false,
			BlurEnabled = false,
			BlurSizeMultiplier = 0,
			DepthOfFieldEnabled = false,
			DepthOfFieldIntensityMultiplier = 0,
			-- Un voile tres leger subsiste si le budget adaptatif bascule temporairement en Performance.
			MoteRateMultiplier = 0.18,
			LeafRateMultiplier = 0.45,
		},
		Balanced = {
			AtmosphereDensityMultiplier = 0.9,
			BloomEnabled = true,
			SunRaysEnabled = false,
			BlurEnabled = true,
			BlurSizeMultiplier = 0.55,
			DepthOfFieldEnabled = true,
			DepthOfFieldIntensityMultiplier = 0.55,
			MoteRateMultiplier = 0.55,
			LeafRateMultiplier = 0.7,
		},
		Quality = {
			AtmosphereDensityMultiplier = 1,
			BloomEnabled = true,
			SunRaysEnabled = true,
			BlurEnabled = true,
			BlurSizeMultiplier = 1,
			DepthOfFieldEnabled = true,
			DepthOfFieldIntensityMultiplier = 1,
			MoteRateMultiplier = 1,
			LeafRateMultiplier = 1,
		},
	},

	-- La map porte le theme de monde. Les chapitres partagent ce theme et choisissent leur variante chromatique.
	LevelProfiles = {
		Map_Test = {
			Id = "ForestVerdant",
			ClockTime = 14.8,
			Brightness = 2.4,
			ExposureCompensation = 0.18,
			Ambient = Color3.fromRGB(90, 112, 88),
			OutdoorAmbient = Color3.fromRGB(150, 172, 130),
			EnvironmentDiffuseScale = 0.54,
			EnvironmentSpecularScale = 0.18,
			ShadowSoftness = 0.42,
			Wind = Vector3.new(1.8, 0, 0.7),
			Blur = {
				Size = 0.45,
			},
			DepthOfField = {
				FocusDistance = 34,
				InFocusRadius = 26,
				NearIntensity = 0,
				FarIntensity = 0.1,
			},
			Atmosphere = {
				Density = 0.25,
				Offset = 0.04,
				Color = Color3.fromRGB(205, 232, 194),
				Decay = Color3.fromRGB(112, 154, 92),
				Glare = 0.012,
				Haze = 1.15,
			},
			Correction = {
				TintColor = Color3.fromRGB(232, 246, 219),
				Brightness = 0.012,
				Contrast = 0.02,
				Saturation = 0.02,
			},
			Bloom = {
				Intensity = 0.035,
				Size = 10,
				Threshold = 1.9,
			},
			SunRays = {
				Intensity = 0.01,
				Spread = 0.65,
			},
			Motes = {
				Color = Color3.fromRGB(195, 255, 157),
				Rate = 7,
			},
		},
		Map_Test2 = {
			Id = "ForestAzure",
			ClockTime = 15.3,
			Brightness = 2.05,
			ExposureCompensation = 0.04,
			Ambient = Color3.fromRGB(61, 88, 101),
			OutdoorAmbient = Color3.fromRGB(112, 140, 151),
			EnvironmentDiffuseScale = 0.43,
			EnvironmentSpecularScale = 0.18,
			ShadowSoftness = 0.4,
			Wind = Vector3.new(1.55, 0, 1.05),
			Blur = {
				Size = 0.4,
			},
			DepthOfField = {
				FocusDistance = 36,
				InFocusRadius = 28,
				NearIntensity = 0,
				FarIntensity = 0.085,
			},
			Atmosphere = {
				Density = 0.13,
				Offset = 0.06,
				Color = Color3.fromRGB(193, 221, 226),
				Decay = Color3.fromRGB(76, 112, 126),
				Glare = 0.012,
				Haze = 0.86,
			},
			Correction = {
				TintColor = Color3.fromRGB(218, 237, 238),
				Brightness = 0.005,
				Contrast = 0.035,
				Saturation = -0.035,
			},
			Bloom = {
				Intensity = 0.04,
				Size = 10,
				Threshold = 1.95,
			},
			SunRays = {
				Intensity = 0.01,
				Spread = 0.64,
			},
			Motes = {
				Color = Color3.fromRGB(225, 255, 255),
				Rate = 8,
			},
		},
		Map_Test3 = {
			Id = "ForestEmber",
			ClockTime = 15,
			Brightness = 2.1,
			ExposureCompensation = 0.06,
			Ambient = Color3.fromRGB(96, 57, 46),
			OutdoorAmbient = Color3.fromRGB(151, 99, 75),
			EnvironmentDiffuseScale = 0.45,
			EnvironmentSpecularScale = 0.16,
			ShadowSoftness = 0.36,
			Wind = Vector3.new(2.05, 0, 0.5),
			Blur = {
				Size = 0.35,
			},
			DepthOfField = {
				FocusDistance = 32,
				InFocusRadius = 24,
				NearIntensity = 0,
				FarIntensity = 0.075,
			},
			Atmosphere = {
				Density = 0.12,
				Offset = 0.08,
				Color = Color3.fromRGB(230, 194, 157),
				Decay = Color3.fromRGB(145, 79, 57),
				Glare = 0.016,
				Haze = 0.76,
			},
			Correction = {
				TintColor = Color3.fromRGB(242, 215, 187),
				Brightness = 0.008,
				Contrast = 0.03,
				Saturation = 0.01,
			},
			Bloom = {
				Intensity = 0.04,
				Size = 10,
				Threshold = 1.95,
			},
			SunRays = {
				Intensity = 0.012,
				Spread = 0.62,
			},
			Motes = {
				Color = Color3.fromRGB(255, 178, 91),
				Rate = 5,
			},
		},
	},

	-- Les trois chapitres emploient actuellement Map_Test : cette table rend leurs palettes atteignables.
	ChapterProfileIdsByWorld = {
		Map_Test = {
			[1] = "Map_Test",
			[2] = "Map_Test2",
			[3] = "Map_Test3",
		},
	},
}

function EnvironmentConfig.GetLevelProfile(levelId, chapterId)
	local profileIds = EnvironmentConfig.ChapterProfileIdsByWorld[levelId or ""]
	local normalizedChapterId = math.floor(tonumber(chapterId) or 0)
	local chapterProfileId = if profileIds ~= nil then profileIds[normalizedChapterId] else nil

	return EnvironmentConfig.LevelProfiles[chapterProfileId or levelId or ""]
		or EnvironmentConfig.LevelProfiles[EnvironmentConfig.DefaultLevelId]
end

function EnvironmentConfig.GetQualityProfile(qualityName)
	return EnvironmentConfig.QualityProfiles[qualityName or ""]
		or EnvironmentConfig.QualityProfiles.Balanced
end

return EnvironmentConfig
