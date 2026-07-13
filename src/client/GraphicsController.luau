local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DebugLog = require(Shared:WaitForChild("DebugLog"))
local GraphicsConfig = require(Shared:WaitForChild("GraphicsConfig"))
local PlayerPreferencesConfig = require(Shared:WaitForChild("PlayerPreferencesConfig"))

local GraphicsController = {}

local isStarted = false
local changedEvent = Instance.new("BindableEvent")
local setGraphicsPreferencesRemote = nil
local preferenceSaveSerial = 0
local settings = table.clone(GraphicsConfig.DefaultSettings)

local function normalizeQuality(value)
	if typeof(value) == "string" and GraphicsConfig.QualityProfiles[value] ~= nil then
		return value
	end

	return GraphicsConfig.DefaultSettings.Quality
end

local function applyLocalWorldSettings()
	Lighting.GlobalShadows = settings.ShadowsEnabled == true
end

local function applyGraphicsPreferences(rawGraphics)
	if typeof(rawGraphics) ~= "table" then
		return
	end

	settings.Quality = normalizeQuality(rawGraphics.Quality)
	settings.EffectsIntensity = math.clamp(
		tonumber(rawGraphics.EffectsIntensity) or GraphicsConfig.DefaultSettings.EffectsIntensity,
		0,
		1
	)
	settings.ShadowsEnabled = rawGraphics.ShadowsEnabled ~= false
end

local function schedulePreferencesSave()
	if setGraphicsPreferencesRemote == nil then
		return
	end

	preferenceSaveSerial += 1
	local scheduledSerial = preferenceSaveSerial

	task.delay(PlayerPreferencesConfig.ClientGraphicsDebounceSeconds, function()
		if scheduledSerial ~= preferenceSaveSerial or setGraphicsPreferencesRemote == nil then
			return
		end

		setGraphicsPreferencesRemote:FireServer(GraphicsController.GetSettings())
	end)
end

local function notifyChanged(shouldSave)
	applyLocalWorldSettings()
	changedEvent:Fire(GraphicsController.GetSettings())

	if shouldSave then
		schedulePreferencesSave()
	end
end

local function connectPreferences()
	local updateRemote = ReplicatedStorage:WaitForChild(PlayerPreferencesConfig.UpdateRemoteName, 15)

	if updateRemote ~= nil and updateRemote:IsA("RemoteEvent") then
		updateRemote.OnClientEvent:Connect(function(payload)
			if typeof(payload) == "table" and typeof(payload.Graphics) == "table" then
				applyGraphicsPreferences(payload.Graphics)
				notifyChanged(false)
			end
		end)
	end

	local setRemote = ReplicatedStorage:WaitForChild(PlayerPreferencesConfig.SetGraphicsRemoteName, 15)

	if setRemote ~= nil and setRemote:IsA("RemoteEvent") then
		setGraphicsPreferencesRemote = setRemote
	end

	local getRemote = ReplicatedStorage:WaitForChild(PlayerPreferencesConfig.GetStateRemoteName, 15)

	if getRemote == nil or not getRemote:IsA("RemoteFunction") then
		DebugLog.Warn("Preferences", "Remote de lecture preferences graphiques introuvable")
		return
	end

	local success, payload = pcall(function()
		return getRemote:InvokeServer()
	end)

	if success and typeof(payload) == "table" and typeof(payload.Graphics) == "table" then
		applyGraphicsPreferences(payload.Graphics)
	elseif not success then
		DebugLog.Warn("Preferences", "Lecture preferences graphiques impossible", {
			Error = tostring(payload),
		})
	end
end

function GraphicsController.GetSettings()
	return table.clone(settings)
end

function GraphicsController.GetCollectibleSettings()
	local profile = GraphicsConfig.GetProfile(settings.Quality)

	return {
		CullInterval = profile.CollectibleCullInterval,
		CullViewportMargin = profile.CollectibleCullViewportMargin,
		CullMaxDistance = profile.CollectibleCullMaxDistance,
		IdleAnimationHz = profile.CollectibleIdleAnimationHz,
	}
end

function GraphicsController.SetQuality(qualityName)
	settings.Quality = normalizeQuality(qualityName)
	notifyChanged(true)
end

function GraphicsController.SetEffectsIntensity(value)
	settings.EffectsIntensity = math.clamp(tonumber(value) or 0, 0, 1)
	notifyChanged(true)
end

function GraphicsController.SetShadowsEnabled(isEnabled)
	settings.ShadowsEnabled = isEnabled == true
	notifyChanged(true)
end

function GraphicsController.Reset()
	settings = table.clone(GraphicsConfig.DefaultSettings)
	notifyChanged(true)
end

function GraphicsController.Start()
	if isStarted then
		return
	end

	isStarted = true
	connectPreferences()
	applyLocalWorldSettings()

	DebugLog.Info("Preferences", "Reglages graphiques client initialises", {
		Quality = settings.Quality,
	})
end

GraphicsController.Changed = changedEvent

return GraphicsController
