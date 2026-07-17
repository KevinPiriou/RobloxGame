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
	-- Fenetre de repos : le contexte P0 reste actif pour isoler la memoire
	-- residuelle du redemarrage normal des vagues.
	IdleObservationSeconds = 8,
	InterScenarioSeconds = 1,
	SampleInterval = 1,
	MinimumRepetitions = 3,
	MaximumSamplesPerMetric = 7200,
	-- P0 mesure la qualite choisie manuellement, sans adaptation temporaire.
	LockAdaptiveVfx = true,
	DefaultSelectionId = "p0_complete",
	ReportFolderName = "PerformanceBaselineReports",

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
			Label = "P0 - projectiles soutenus (24/s)",
			MonsterCount = 48,
			ProjectileBurst = 8,
			ProjectileBurstIntervalSeconds = 1 / 3,
		},
		{
			Id = "collectibles_fusion_300",
			Label = "P0 - fusion initiale 300 collectibles",
			XpGemCount = 150,
			CoinCount = 150,
		},
	},

	-- Une campagne enchainee sert a relever la stabilite sur une meme run.
	-- Les scenarios unitaires restent la reference pour isoler une regression.
	Campaigns = {
		{
			Id = "p0_complete",
			Label = "P0 - campagne complete",
			ScenarioIds = {
				"monsters_25",
				"monsters_100",
				"monsters_250",
				"monsters_500",
				"monsters_1000",
				"projectiles_24",
				"collectibles_fusion_300",
			},
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

function PerformanceBaselineConfig.GetCampaign(campaignId)
	for _, campaign in ipairs(PerformanceBaselineConfig.Campaigns) do
		if campaign.Id == campaignId then
			return campaign
		end
	end

	return nil
end

function PerformanceBaselineConfig.GetSelections()
	local selections = {}

	for _, scenario in ipairs(PerformanceBaselineConfig.Scenarios) do
		table.insert(selections, {
			Id = scenario.Id,
			Label = scenario.Label,
			Kind = "Scenario",
		})
	end

	for _, campaign in ipairs(PerformanceBaselineConfig.Campaigns) do
		table.insert(selections, {
			Id = campaign.Id,
			Label = campaign.Label,
			Kind = "Campaign",
		})
	end

	return selections
end

return PerformanceBaselineConfig
