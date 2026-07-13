-- Reglages graphiques locaux. Ils ne modifient jamais les decisions serveur.

local GraphicsConfig = {
	DefaultSettings = {
		Quality = "Balanced",
		EffectsIntensity = 1,
		ShadowsEnabled = true,
	},

	QualityProfiles = {
		Performance = {
			Label = "PERF",
			CollectibleCullInterval = 0.35,
			CollectibleCullViewportMargin = 70,
			CollectibleCullMaxDistance = 180,
			CollectibleIdleAnimationHz = 12,
			EffectsMultiplier = 0.45,
		},
		Balanced = {
			Label = "EQUILIBRE",
			CollectibleCullInterval = 0.2,
			CollectibleCullViewportMargin = 120,
			CollectibleCullMaxDistance = 360,
			CollectibleIdleAnimationHz = 30,
			EffectsMultiplier = 0.75,
		},
		Quality = {
			Label = "QUALITE",
			CollectibleCullInterval = 0.12,
			CollectibleCullViewportMargin = 180,
			CollectibleCullMaxDistance = 640,
			CollectibleIdleAnimationHz = 45,
			EffectsMultiplier = 1,
		},
	},
}

function GraphicsConfig.GetProfile(qualityName: string?)
	return GraphicsConfig.QualityProfiles[qualityName or ""]
		or GraphicsConfig.QualityProfiles.Balanced
end

return GraphicsConfig
