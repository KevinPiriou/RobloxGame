-- Profils d'ambiance locaux. Ils changent uniquement le rendu du joueur.

local EnvironmentConfig = {
	RuntimeFolderName = "MegaRobloxClientEnvironment",
	FallbackAtmosphereName = "MegaRoblox_FallbackAtmosphere",
	ColorCorrectionName = "MegaRoblox_RunColorCorrection",
	BloomName = "MegaRoblox_RunBloom",
	FallbackSunRaysName = "MegaRoblox_FallbackSunRays",
	MoteAnchorName = "ForestMoteAnchor",
	TransitionSeconds = 0.65,
	MoteTexture = "rbxasset://textures/particles/sparkles_main.dds",
	MoteFollowHeight = 4.5,
	MoteUpdateInterval = 0.12,
	DefaultLevelId = "Map_Test",

	QualityProfiles = {
		Performance = {
			AtmosphereDensityMultiplier = 0.76,
			BloomEnabled = false,
			SunRaysEnabled = false,
			MoteRateMultiplier = 0,
		},
		Balanced = {
			AtmosphereDensityMultiplier = 0.9,
			BloomEnabled = true,
			SunRaysEnabled = false,
			MoteRateMultiplier = 0.55,
		},
		Quality = {
			AtmosphereDensityMultiplier = 1,
			BloomEnabled = true,
			SunRaysEnabled = true,
			MoteRateMultiplier = 1,
		},
	},

	-- L'ambiance est liee a la map jouee, jamais a la progression de chapitre.
	-- Un chapitre peut donc proposer plusieurs niveaux aux identites distinctes.
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
				Color = Color3.fromRGB(133, 224, 255),
				Rate = 6,
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
}

function EnvironmentConfig.GetLevelProfile(levelId)
	return EnvironmentConfig.LevelProfiles[levelId or ""]
		or EnvironmentConfig.LevelProfiles[EnvironmentConfig.DefaultLevelId]
end

function EnvironmentConfig.GetQualityProfile(qualityName)
	return EnvironmentConfig.QualityProfiles[qualityName or ""]
		or EnvironmentConfig.QualityProfiles.Balanced
end

return EnvironmentConfig
