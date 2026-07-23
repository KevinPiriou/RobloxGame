local ChapterConfig = {
	DataStoreName = "MegaRobloxChapters_v1",
	RunDataStoreName = "MegaRobloxRuns_v1",
	DataVersion = 1,
	DefaultUnlockedChapter = 1,
	MaxRunHistory = 20,
	TemplateFolderName = "MapTemplates",
	RuntimeFolderName = "MapRuntime",
	ArrivalPartName = "TeleportPart1",
	SelectedChapterAttributeName = "SelectedChapter",
	HighestUnlockedChapterAttributeName = "HighestUnlockedChapter",
	CompletedChapterCountAttributeName = "CompletedChapterCount",
	DisableMapScripts = true,

	Chapters = {
		[1] = {
			Id = 1,
			DisplayName = "Chapitre 1",
			DisplayNameKey = "chapter.1.name",
			MapTemplateName = "Map_Test",
			ArrivalPartName = "TeleportPart1",
			TerrainThemeId = "Verdant",
		},
		[2] = {
			Id = 2,
			DisplayName = "Chapitre 2",
			DisplayNameKey = "chapter.2.name",
			MapTemplateName = "Map_Test",
			ArrivalPartName = "TeleportPart1",
			TerrainThemeId = "Azure",
		},
		[3] = {
			Id = 3,
			DisplayName = "Chapitre 3",
			DisplayNameKey = "chapter.3.name",
			MapTemplateName = "Map_Test",
			ArrivalPartName = "TeleportPart1",
			TerrainThemeId = "Ember",
		},
	},
}

function ChapterConfig.GetChapter(chapterId)
	return ChapterConfig.Chapters[math.floor(tonumber(chapterId) or 0)]
end

function ChapterConfig.GetChapterCount()
	local count = 0

	for _ in pairs(ChapterConfig.Chapters) do
		count += 1
	end

	return count
end

return ChapterConfig
