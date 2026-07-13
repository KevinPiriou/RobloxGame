--!strict

-- Alimente les panneaux lobby existants avec les donnees serveur persistantes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local menus = playerGui:WaitForChild("Menus")
local getStateRemote = ReplicatedStorage:WaitForChild("MetaProgression_GetState") :: RemoteFunction
local updateStateRemote = ReplicatedStorage:WaitForChild("MetaProgression_Update") :: RemoteEvent

local latestState: {[string]: any}? = nil

local function formatNumber(value: any): string
	return string.format("%d", math.max(0, math.floor(tonumber(value) or 0)))
end

local function formatProgress(entry: {[string]: any}): string
	return string.format("%s / %s", formatNumber(entry.Progress), formatNumber(entry.Target))
end

local function updateValueForTitle(panelName: string, titleText: string, valueText: string)
	local panel = menus:FindFirstChild(panelName)

	if panel == nil then
		return
	end

	for _, descendant in ipairs(panel:GetDescendants()) do
		if descendant:IsA("Frame") then
			local title = descendant:FindFirstChild("Title")
			local value = descendant:FindFirstChild("Value")

			if title ~= nil
				and value ~= nil
				and title:IsA("TextLabel")
				and value:IsA("TextLabel")
				and title.Text == titleText
			then
				value.Text = valueText
			end
		end
	end
end

local function updateEntries(panelName: string, entries: {any})
	for _, entry in ipairs(entries) do
		local suffix = if entry.Completed == true then "TERMINE" else formatProgress(entry)
		updateValueForTitle(panelName, tostring(entry.Label), suffix)
	end
end

local function applyState(state: {[string]: any})
	latestState = state
	local stats = state.Stats or {}

	updateEntries("QuestsPanel", state.Quests or {})
	updateEntries("QuestsPanel", state.DailyQuests or {})
	updateEntries("HousingPanel", state.Achievements or {})
	updateValueForTitle("HousingPanel", "RUNS TERMINEES", formatNumber(stats.RunsCompleted))
	updateValueForTitle("HousingPanel", "MONSTRES ELIMINES", formatNumber(stats.TotalKills))
	updateValueForTitle("HousingPanel", "NIVEAUX VALIDES", formatNumber(stats.ChaptersValidated))
	updateValueForTitle("HousingPanel", "OR COLLECTE", formatNumber(stats.TotalCoinsEarned))
end

local function refreshFromServer(): boolean
	local success, state = pcall(function()
		return getStateRemote:InvokeServer()
	end)

	if success and typeof(state) == "table" then
		applyState(state)
		return true
	end

	return false
end

updateStateRemote.OnClientEvent:Connect(function(state)
	if typeof(state) == "table" then
		applyState(state)
	end
end)

menus.ChildAdded:Connect(function()
	if latestState ~= nil then
		task.defer(function()
			if latestState ~= nil then
				applyState(latestState)
			end
		end)
	end
end)

task.spawn(function()
	for _ = 1, 10 do
		if refreshFromServer() then
			return
		end

		task.wait(0.5)
	end
end)
