--!strict

local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local I18n = require(Shared:WaitForChild("I18n"))

local I18nClient = {}

local tableInstance: LocalizationTable? = nil
local translatorsByLocale: {[string]: Translator} = {}

local function applyParameters(text: string, parameters: {[string]: unknown}?): string
	if parameters == nil then
		return text
	end

	return string.gsub(text, "{([%w_]+)}", function(parameterName)
		local value = parameters[parameterName]
		return if value == nil then "{" .. parameterName .. "}" else tostring(value)
	end)
end

local function ensureTable(): LocalizationTable
	if tableInstance ~= nil then
		return tableInstance
	end

	local existing = LocalizationService:FindFirstChild("MegaRobloxLocalizationRuntime")
	if existing ~= nil and existing:IsA("LocalizationTable") then
		tableInstance = existing
		return existing
	end

	local created = Instance.new("LocalizationTable")
	created.Name = "MegaRobloxLocalizationRuntime"
	created.SourceLocaleId = "fr"
	created:SetEntries(I18n.GetEntries())
	created.Parent = LocalizationService
	tableInstance = created
	return created
end

function I18nClient.GetLocale(): string
	local player = Players.LocalPlayer
	local override = player:GetAttribute("I18nLocaleOverride")
	if type(override) == "string" and override ~= "" then
		return I18n.NormalizeLocale(override)
	end
	return I18n.NormalizeLocale(player.LocaleId)
end

function I18nClient.T(key: string, parameters: {[string]: unknown}?): string
	local locale = I18nClient.GetLocale()
	local translator = translatorsByLocale[locale]
	if translator == nil then
		local success, result = pcall(function()
			return ensureTable():GetTranslator(locale)
		end)
		if success and result ~= nil then
			translator = result :: Translator
			translatorsByLocale[locale] = translator
		end
	end

	if translator ~= nil then
		local success, translated = pcall(function()
			return translator:FormatByKey(key, parameters or {})
		end)
		if success and type(translated) == "string" and translated ~= key then
			return applyParameters(translated, parameters)
		end
	end

	return I18n.Format(key, locale, parameters)
end

function I18nClient.Start()
	ensureTable()
end

return I18nClient
