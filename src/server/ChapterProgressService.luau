local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ChapterConfig = require(Shared:WaitForChild("ChapterConfig"))
local DebugLog = require(Shared:WaitForChild("DebugLog"))

local ChapterProgressService = {}

local chapterDataStore = DataStoreService:GetDataStore(ChapterConfig.DataStoreName)
local profilesByUserId = {}
local isStarted = false

local function getOrCreateRemote(remoteName, className)
	local remote = ReplicatedStorage:FindFirstChild(remoteName)

	if remote == nil then
		remote = Instance.new(className)
		remote.Name = remoteName
		remote.Parent = ReplicatedStorage
	end

	assert(remote.ClassName == className, remoteName .. " doit etre un " .. className .. ".")
	return remote
end

local getStateRemote = getOrCreateRemote("Chapter_GetState", "RemoteFunction")
local selectRemote = getOrCreateRemote("Chapter_Select", "RemoteEvent")

local function createDefaultData()
	return {
		Version = ChapterConfig.DataVersion,
		HighestUnlockedChapter = ChapterConfig.DefaultUnlockedChapter,
		CompletedChapters = {},
	}
end

local function normalizeData(rawData)
	local data = createDefaultData()

	if typeof(rawData) ~= "table" then
		return data
	end

	local chapterCount = ChapterConfig.GetChapterCount()
	data.HighestUnlockedChapter = math.clamp(
		math.floor(tonumber(rawData.HighestUnlockedChapter) or ChapterConfig.DefaultUnlockedChapter),
		ChapterConfig.DefaultUnlockedChapter,
		chapterCount
	)

	if typeof(rawData.CompletedChapters) == "table" then
		for chapterId, isCompleted in pairs(rawData.CompletedChapters) do
			local numericChapterId = math.floor(tonumber(chapterId) or 0)

			if ChapterConfig.GetChapter(numericChapterId) ~= nil and isCompleted == true then
				data.CompletedChapters[tostring(numericChapterId)] = true
			end
		end
	end

	return data
end

local function getDataStoreKey(player)
	return "Player_" .. player.UserId
end

local function getOrCreateProfile(player)
	local profile = profilesByUserId[player.UserId]

	if profile == nil then
		profile = {
			Data = createDefaultData(),
			Loaded = false,
			SessionOnly = false,
			Dirty = false,
		}
		profilesByUserId[player.UserId] = profile
	end

	return profile
end

local function countCompletedChapters(data)
	local count = 0

	for _, isCompleted in pairs(data.CompletedChapters) do
		if isCompleted == true then
			count += 1
		end
	end

	return count
end

local function publishProfile(player, profile)
	player:SetAttribute(ChapterConfig.HighestUnlockedChapterAttributeName, profile.Data.HighestUnlockedChapter)
	player:SetAttribute(ChapterConfig.CompletedChapterCountAttributeName, countCompletedChapters(profile.Data))

	local selectedChapter = math.floor(tonumber(player:GetAttribute(ChapterConfig.SelectedChapterAttributeName)) or 1)

	if selectedChapter > profile.Data.HighestUnlockedChapter or ChapterConfig.GetChapter(selectedChapter) == nil then
		selectedChapter = profile.Data.HighestUnlockedChapter
	end

	player:SetAttribute(ChapterConfig.SelectedChapterAttributeName, selectedChapter)
end

function ChapterProgressService.SetupPlayer(player)
	local profile = getOrCreateProfile(player)
	local success, rawData = pcall(function()
		return chapterDataStore:GetAsync(getDataStoreKey(player))
	end)

	if success then
		profile.Data = normalizeData(rawData)
		profile.Loaded = true
		profile.SessionOnly = false
	elseif RunService:IsStudio() then
		profile.Data = createDefaultData()
		profile.Loaded = true
		profile.SessionOnly = true
		DebugLog.Warn("Chapter", "DataStore des chapitres indisponible dans Studio", {
			Player = player.Name,
			Error = tostring(rawData),
		})
	else
		profile.Loaded = false
		DebugLog.Warn("Chapter", "Chargement de progression impossible", {
			Player = player.Name,
			Error = tostring(rawData),
		})
	end

	publishProfile(player, profile)

	DebugLog.Info("Chapter", "Progression chapitre chargee", {
		Player = player.Name,
		HighestUnlockedChapter = profile.Data.HighestUnlockedChapter,
		CompletedChapters = countCompletedChapters(profile.Data),
	})
end

function ChapterProgressService.IsChapterUnlocked(player, chapterId)
	local chapter = ChapterConfig.GetChapter(chapterId)
	local profile = player and profilesByUserId[player.UserId]

	return chapter ~= nil and profile ~= nil and profile.Loaded and chapter.Id <= profile.Data.HighestUnlockedChapter
end

function ChapterProgressService.GetSelectedChapter(player)
	local selectedChapter = math.floor(tonumber(player:GetAttribute(ChapterConfig.SelectedChapterAttributeName)) or 1)

	if ChapterProgressService.IsChapterUnlocked(player, selectedChapter) then
		return selectedChapter
	end

	return 1
end

function ChapterProgressService.SelectChapter(player, chapterId)
	local chapter = ChapterConfig.GetChapter(chapterId)

	if chapter == nil then
		return false, "UnknownChapter"
	end

	if not ChapterProgressService.IsChapterUnlocked(player, chapter.Id) then
		return false, "ChapterLocked"
	end

	player:SetAttribute(ChapterConfig.SelectedChapterAttributeName, chapter.Id)
	return true, "Ok"
end

function ChapterProgressService.MarkChapterCompleted(player, chapterId)
	local chapter = ChapterConfig.GetChapter(chapterId)
	local profile = player and profilesByUserId[player.UserId]

	if chapter == nil or profile == nil or not profile.Loaded then
		return false
	end

	local wasCompleted = profile.Data.CompletedChapters[tostring(chapter.Id)] == true
	local previousHighestUnlockedChapter = profile.Data.HighestUnlockedChapter
	profile.Data.CompletedChapters[tostring(chapter.Id)] = true
	profile.Data.HighestUnlockedChapter = math.max(
		profile.Data.HighestUnlockedChapter,
		math.min(ChapterConfig.GetChapterCount(), chapter.Id + 1)
	)
	local newlyUnlockedChapterId = nil

	if profile.Data.HighestUnlockedChapter > previousHighestUnlockedChapter then
		newlyUnlockedChapterId = profile.Data.HighestUnlockedChapter
	end
	profile.Dirty = true
	publishProfile(player, profile)

	DebugLog.Info("Chapter", "Chapitre valide", {
		Player = player.Name,
		ChapterId = chapter.Id,
		HighestUnlockedChapter = profile.Data.HighestUnlockedChapter,
	})

	return true, {
		WasAlreadyCompleted = wasCompleted,
		NewlyUnlockedChapterId = newlyUnlockedChapterId,
	}
end

function ChapterProgressService.SavePlayer(player)
	local profile = player and profilesByUserId[player.UserId]

	if profile == nil or not profile.Loaded or not profile.Dirty then
		return true
	end

	if profile.SessionOnly then
		profile.Dirty = false
		return true
	end

	local success, updatedData = pcall(function()
		return chapterDataStore:UpdateAsync(getDataStoreKey(player), function(rawData)
			local data = normalizeData(rawData)
			data.HighestUnlockedChapter = math.max(data.HighestUnlockedChapter, profile.Data.HighestUnlockedChapter)

			for chapterId, isCompleted in pairs(profile.Data.CompletedChapters) do
				if isCompleted == true then
					data.CompletedChapters[chapterId] = true
				end
			end

			return data
		end)
	end)

	if not success then
		DebugLog.Warn("Chapter", "Sauvegarde de progression impossible", {
			Player = player.Name,
			Error = tostring(updatedData),
		})
		return false
	end

	profile.Data = normalizeData(updatedData)
	profile.Dirty = false
	publishProfile(player, profile)
	return true
end

function ChapterProgressService.RemovePlayer(player)
	ChapterProgressService.SavePlayer(player)
	profilesByUserId[player.UserId] = nil
end

function ChapterProgressService.Start()
	if isStarted then
		return
	end

	isStarted = true

	getStateRemote.OnServerInvoke = function(player)
		local profile = profilesByUserId[player.UserId]
		local chapters = {}

		for chapterId = 1, ChapterConfig.GetChapterCount() do
			local chapter = ChapterConfig.GetChapter(chapterId)
			table.insert(chapters, {
				Id = chapter.Id,
				DisplayName = chapter.DisplayName,
				DisplayNameKey = chapter.DisplayNameKey,
				MapId = chapter.MapTemplateName,
				IsUnlocked = ChapterProgressService.IsChapterUnlocked(player, chapter.Id),
				IsCompleted = profile ~= nil and profile.Data.CompletedChapters[tostring(chapter.Id)] == true,
				IsSelected = ChapterProgressService.GetSelectedChapter(player) == chapter.Id,
			})
		end

		return chapters
	end

	selectRemote.OnServerEvent:Connect(function(player, chapterId)
		local selected, reason = ChapterProgressService.SelectChapter(player, chapterId)

		if not selected then
			DebugLog.Warn("Chapter", "Selection chapitre refusee", {
				Player = player.Name,
				ChapterId = chapterId,
				Reason = reason,
			})
		end
	end)

	DebugLog.Info("Chapter", "ChapterProgressService demarre")
end

return ChapterProgressService
