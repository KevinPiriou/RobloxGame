local MetaProgressionConfig = {
	DataStoreName = "MegaRobloxMetaProgression_v1",
	DataVersion = 5,
	ProcessedRunLimit = 40,
	StartedRunHistoryLimit = 40,
	DefaultUnlockedCharacterIds = { "medivh", "albert", "shinobi", "rusal_gale", "rufus", "lorelei" },
	DefaultUnlockedWeaponIds = { "fireball", "leyden_needle", "shuriken", "soul_lantern", "valorcrest_blade", "soulthorn_drain" },

	Quests = {
		{
			Id = "first_run",
			Label = "FAIRE UNE RUN",
			Target = 1,
			Source = "RunsCompleted",
		},
		{
			Id = "chapter_one_boss",
			Label = "GARDIEN DU CHAPITRE 1",
			Target = 1,
			Source = "Chapter1BossVictories",
		},
		{
			Id = "perk_shrines",
			Label = "AUTELS DE PERK",
			Target = 10,
			Source = "TotalPerkShrinesActivated",
		},
	},

	DailyQuests = {
		{
			Id = "daily_kills_100",
			Label = "DEFI 100 ENNEMIS",
			Target = 100,
			Source = "DailyKills",
		},
		{
			Id = "daily_kills_250",
			Label = "DEFI 250 ENNEMIS",
			Target = 250,
			Source = "DailyKills",
		},
		{
			Id = "daily_kills_500",
			Label = "DEFI 500 ENNEMIS",
			Target = 500,
			Source = "DailyKills",
		},
	},

	Achievements = {
		{
			Id = "founder",
			Label = "FONDATEUR",
			Target = 1,
			Source = "FounderPassOwned",
		},
		{
			Id = "first_run_started",
			Label = "ON DEBUTE TOUS UN JOUR ..",
			Target = 1,
			Source = "RunsStarted",
		},
	},
}

return MetaProgressionConfig
