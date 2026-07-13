-- Profils visuels partages. Ils ne portent aucune decision de gameplay.

local VfxConfig = {
	ImpactRemoteName = "CombatVfx_Play",
	RuntimeFolderName = "MegaRobloxClientVfxRuntime",
	ProjectileVisualFolderName = "MegaRobloxClientProjectileVfx",

	PresentationKinds = {
		Projectile = "Projectile",
		Persistent = "Persistant",
		Instant = "Instantane",
		Area = "Zone",
	},

	QualityOrder = {
		"Performance",
		"Balanced",
		"Quality",
	},

	QualityProfiles = {
		Performance = {
			FullProjectileLimit = 8,
			ReducedProjectileLimit = 24,
			FullImpactLimit = 6,
			ReducedImpactLimit = 12,
			AuraFamilyLimit = 2,
			AuraLayerMultiplier = 0.35,
		},
		Balanced = {
			FullProjectileLimit = 24,
			ReducedProjectileLimit = 56,
			FullImpactLimit = 16,
			ReducedImpactLimit = 32,
			AuraFamilyLimit = 3,
			AuraLayerMultiplier = 0.65,
		},
		Quality = {
			FullProjectileLimit = 48,
			ReducedProjectileLimit = 96,
			FullImpactLimit = 32,
			ReducedImpactLimit = 64,
			AuraFamilyLimit = 3,
			AuraLayerMultiplier = 1,
		},
	},

	AdaptiveBudget = {
		SampleSeconds = 1,
		SlowFrameSeconds = 3,
		RecoverFrameSeconds = 10,
		SlowFrameTime = 1 / 45,
		RecoverFrameTime = 1 / 55,
	},

	ProjectileProfiles = {
		fireball_default = {
			PresentationKind = "Projectile",
			CoreColor = Color3.fromRGB(255, 118, 32),
			AccentColor = Color3.fromRGB(255, 225, 112),
			TrailColor = Color3.fromRGB(255, 76, 24),
			SmokeColor = Color3.fromRGB(110, 42, 30),
			FlameTexture = "rbxassetid://72782845967015",
			SmokeTexture = "rbxassetid://82629816435413",
			SparkTexture = "rbxassetid://93416665109999",
			CoreTransparency = 0.04,
			LightBrightness = 1.35,
			LightRange = 8,
			TrailLifetime = 0.18,
			FlameShellRate = 54,
			FlameTailRate = 42,
			FlameShellStartSize = 1.55,
			FlameTailStartSize = 0.92,
			SmokeRate = 15,
			SparkleRate = 18,
			ImpactStartSize = 0.7,
			ImpactEndSize = 3.1,
			ImpactLifetime = 0.16,
		},
		fireball_arcane = {
			PresentationKind = "Projectile",
			CoreColor = Color3.fromRGB(119, 72, 255),
			AccentColor = Color3.fromRGB(107, 234, 255),
			TrailColor = Color3.fromRGB(91, 54, 235),
			SmokeColor = Color3.fromRGB(59, 35, 112),
			FlameTexture = "rbxassetid://72782845967015",
			SmokeTexture = "rbxassetid://82629816435413",
			SparkTexture = "rbxassetid://93416665109999",
			CoreTransparency = 0.06,
			LightBrightness = 1.5,
			LightRange = 9,
			TrailLifetime = 0.21,
			FlameShellRate = 58,
			FlameTailRate = 46,
			FlameShellStartSize = 1.62,
			FlameTailStartSize = 0.96,
			SmokeRate = 14,
			SparkleRate = 20,
			ImpactStartSize = 0.7,
			ImpactEndSize = 3.25,
			ImpactLifetime = 0.18,
		},
	},
}

function VfxConfig.GetQualityIndex(qualityName: string?)
	for index, candidate in ipairs(VfxConfig.QualityOrder) do
		if candidate == qualityName then
			return index
		end
	end

	return 2
end

function VfxConfig.GetQualityName(index: number)
	return VfxConfig.QualityOrder[math.clamp(math.floor(index), 1, #VfxConfig.QualityOrder)]
		or "Balanced"
end

function VfxConfig.GetQualityProfile(qualityName: string?)
	return VfxConfig.QualityProfiles[qualityName or ""] or VfxConfig.QualityProfiles.Balanced
end

function VfxConfig.GetProjectileProfile(profileId: string?)
	return VfxConfig.ProjectileProfiles[profileId or ""]
		or VfxConfig.ProjectileProfiles.fireball_default
end

return VfxConfig
