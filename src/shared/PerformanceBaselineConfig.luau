-- Configuration unique des campagnes de performance P0.
-- Ces valeurs ne sont pas des reglages de gameplay : elles servent uniquement
-- a rendre chaque mesure comparable a la campagne suivante.

local PerformanceBaselineConfig = {
	AdminRemoteName = "Admin_PerformanceBenchmark",
	ClientSampleRemoteName = "PerformanceBenchmark_ClientSample",
	StatusRemoteName = "PerformanceBenchmark_Status",
	BenchmarkFolderName = "PerformanceBaseline",
	ArenaName = "Arena",
	ReferencePointsName = "ReferencePoints",
	PlayerStartName = "PlayerStart",
	SimulationCenterName = "SimulationCenter",
	Seed = 17072026,
	WarmupSeconds = 15,
	MeasurementSeconds = 90,
	CleanupSeconds = 2,
	SampleInterval = 1,
	MinimumRepetitions = 3,
	MaximumSamplesPerMetric = 7200,

	Scenarios = {
		{
			Id = "monsters_25",
			Label = "P0 - 25 monstres",
			MonsterCount = 25,
		},
		{
			Id = "monsters_100",
			Label = "P0 - 100 monstres",
			MonsterCount = 100,
		},
		{
			Id = "monsters_250",
			Label = "P0 - 250 monstres",
			MonsterCount = 250,
		},
		{
			Id = "monsters_500",
			Label = "P0 - 500 monstres",
			MonsterCount = 500,
		},
		{
			Id = "monsters_1000",
			Label = "P0 - 1000 monstres",
			MonsterCount = 1000,
		},
		{
			Id = "projectiles_24",
			Label = "P0 - 24 projectiles",
			MonsterCount = 24,
			ProjectileBurst = 24,
		},
		{
			Id = "collectibles_300",
			Label = "P0 - 300 collectibles",
			XpGemCount = 150,
			CoinCount = 150,
		},
	},
}

function PerformanceBaselineConfig.GetScenario(scenarioId)
	for _, scenario in ipairs(PerformanceBaselineConfig.Scenarios) do
		if scenario.Id == scenarioId then
			return scenario
		end
	end

	return nil
end

return PerformanceBaselineConfig
