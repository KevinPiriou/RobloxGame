local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ChestConfig = require(Shared:WaitForChild("ChestConfig"))
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))
local DebugLog = require(Shared:WaitForChild("DebugLog"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local JarConfig = require(Shared:WaitForChild("JarConfig"))
local PortalConfig = require(Shared:WaitForChild("PortalConfig"))
local ShrineConfig = require(Shared:WaitForChild("ShrineConfig"))

local TemplateService = {}

local SERVER_TEMPLATE_FOLDERS = {
	CombatConfig.TemplateFolderName,
	"CollectibleTemplates",
	ShrineConfig.TemplateFolderName,
	PortalConfig.TemplateFolderName,
	JarConfig.TemplateFolderName,
	"MapTemplates",
	ChestConfig.TemplateFolderName,
}

local function getOrCreateFolder(parent, folderName)
	local folder = parent:FindFirstChild(folderName)

	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = folderName
		folder.Parent = parent
		DebugLog.Info("Templates", "Dossier cree", {
			Parent = parent,
			Folder = folderName,
		})
	end

	assert(folder:IsA("Folder"), folderName .. " doit etre un Folder.")

	return folder
end

local function isInsideFolderName(instance, folderName)
	local current = instance.Parent

	while current ~= nil do
		if current.Name == folderName then
			return true
		end

		current = current.Parent
	end

	return false
end

local function isWorkspaceRuntimeInstance(instance)
	if not instance:IsDescendantOf(Workspace) then
		return false
	end

	return isInsideFolderName(instance, CombatConfig.RuntimeFolderName)
		or isInsideFolderName(instance, ShrineConfig.RuntimeFolderName)
		or isInsideFolderName(instance, PortalConfig.RuntimeFolderName)
		or isInsideFolderName(instance, ChestConfig.RuntimeFolderName)
		or isInsideFolderName(instance, JarConfig.RuntimeFolderName)
		or isInsideFolderName(instance, "MapRuntime")
end

local function warnTemplateMoved(templateName, folderName, sourceName)
	DebugLog.Warn("Templates", "Template range dans ServerStorage", {
		Template = templateName,
		Source = sourceName,
		TargetFolder = "ServerStorage/" .. folderName,
	})
end

local function warnTemplateCloned(templateName, folderName, sourceName)
	DebugLog.Warn("Templates", "Template copie vers ServerStorage", {
		Template = templateName,
		Source = sourceName,
		TargetFolder = "ServerStorage/" .. folderName,
	})
end

function TemplateService.GetServerTemplateFolder(folderName)
	return getOrCreateFolder(ServerStorage, folderName)
end

function TemplateService.GetWorkspaceRuntimeFolder(folderName)
	return getOrCreateFolder(Workspace, folderName)
end

function TemplateService.GetCombatRuntimeFolder()
	return TemplateService.GetWorkspaceRuntimeFolder(CombatConfig.RuntimeFolderName)
end

function TemplateService.GetCombatMonsterFolder()
	return getOrCreateFolder(TemplateService.GetCombatRuntimeFolder(), CombatConfig.MonsterFolderName)
end

function TemplateService.GetCombatProjectileFolder()
	return getOrCreateFolder(TemplateService.GetCombatRuntimeFolder(), CombatConfig.ProjectileFolderName)
end

function TemplateService.GetCombatLootFolder()
	return getOrCreateFolder(TemplateService.GetCombatRuntimeFolder(), CombatConfig.LootFolderName)
end

function TemplateService.GetShrinesRuntimeFolder()
	return TemplateService.GetWorkspaceRuntimeFolder(ShrineConfig.RuntimeFolderName)
end

function TemplateService.GetPortalsRuntimeFolder()
	return TemplateService.GetWorkspaceRuntimeFolder(PortalConfig.RuntimeFolderName)
end

function TemplateService.GetChestsRuntimeFolder()
	return TemplateService.GetWorkspaceRuntimeFolder(ChestConfig.RuntimeFolderName)
end

function TemplateService.GetJarsRuntimeFolder()
	return TemplateService.GetWorkspaceRuntimeFolder(JarConfig.RuntimeFolderName)
end

function TemplateService.GetMapRuntimeFolder()
	return TemplateService.GetWorkspaceRuntimeFolder("MapRuntime")
end

function TemplateService.GetTemplate(folderName, templateName, fallbackFactory)
	local templateStorage = TemplateService.GetServerTemplateFolder(folderName)
	local storedTemplate = templateStorage:FindFirstChild(templateName)

	if storedTemplate ~= nil then
		DebugLog.Info("Templates", "Template trouve dans dossier cible", {
			Folder = "ServerStorage/" .. folderName,
			Template = templateName,
		})
		return storedTemplate
	end

	for _, root in ipairs({ ServerStorage, ReplicatedStorage, Workspace }) do
		local candidate = root:FindFirstChild(templateName, true)

		if candidate ~= nil and not candidate:IsDescendantOf(templateStorage) and not isWorkspaceRuntimeInstance(candidate) then
			if candidate:IsDescendantOf(ServerStorage) then
				warnTemplateMoved(templateName, folderName, "ServerStorage hors dossier cible")
				candidate.Parent = templateStorage
				return candidate
			end

			if candidate:IsDescendantOf(Workspace) then
				warnTemplateMoved(templateName, folderName, "Workspace")
				candidate.Parent = templateStorage
				return candidate
			end

			warnTemplateCloned(templateName, folderName, "ReplicatedStorage")

			local clone = candidate:Clone()
			clone.Parent = templateStorage
			return clone
		end
	end

	if fallbackFactory ~= nil then
		DebugLog.Warn("Templates", "Template introuvable, fallback demande", {
			Folder = "ServerStorage/" .. folderName,
			Template = templateName,
		})
		return fallbackFactory(templateStorage)
	end

	DebugLog.Warn("Templates", "Template introuvable sans fallback", {
		Folder = "ServerStorage/" .. folderName,
		Template = templateName,
	})

	return nil
end

local function migrateOptionalTemplate(folderName, templateName)
	local templateStorage = TemplateService.GetServerTemplateFolder(folderName)

	if templateStorage:FindFirstChild(templateName) ~= nil then
		return
	end

	for _, root in ipairs({ ServerStorage, ReplicatedStorage, Workspace }) do
		local candidate = root:FindFirstChild(templateName, true)

		if candidate ~= nil and not candidate:IsDescendantOf(templateStorage) and not isWorkspaceRuntimeInstance(candidate) then
			if candidate:IsDescendantOf(Workspace) or candidate:IsDescendantOf(ServerStorage) then
				warnTemplateMoved(templateName, folderName, candidate:IsDescendantOf(Workspace) and "Workspace" or "ServerStorage hors dossier cible")
				candidate.Parent = templateStorage
				return
			end

			warnTemplateCloned(templateName, folderName, "ReplicatedStorage")

			local clone = candidate:Clone()
			clone.Parent = templateStorage
			return
		end
	end
end

function TemplateService.Start()
	DebugLog.Info("Templates", "Initialisation arborescence templates/runtime")

	for _, folderName in ipairs(SERVER_TEMPLATE_FOLDERS) do
		TemplateService.GetServerTemplateFolder(folderName)
	end

	TemplateService.GetCombatMonsterFolder()
	TemplateService.GetCombatProjectileFolder()
	TemplateService.GetCombatLootFolder()
	TemplateService.GetPortalsRuntimeFolder()
	TemplateService.GetShrinesRuntimeFolder()
	TemplateService.GetChestsRuntimeFolder()
	TemplateService.GetJarsRuntimeFolder()
	TemplateService.GetMapRuntimeFolder()

	migrateOptionalTemplate(CombatConfig.TemplateFolderName, CombatConfig.MonsterTemplateName)
	migrateOptionalTemplate(CombatConfig.TemplateFolderName, "Monster3")
	migrateOptionalTemplate(CombatConfig.TemplateFolderName, CombatConfig.FireballTemplateName)

	for _, tierName in ipairs(GameConfig.CoinTierNames or { "Coin" }) do
		migrateOptionalTemplate("CollectibleTemplates", tierName)
	end

	for _, tierName in ipairs(CombatConfig.XpGemTierNames) do
		migrateOptionalTemplate("CollectibleTemplates", tierName)
	end

	migrateOptionalTemplate(ShrineConfig.TemplateFolderName, ShrineConfig.PerkShrineTemplateName)
	migrateOptionalTemplate(ShrineConfig.TemplateFolderName, ShrineConfig.EliteChallengeShrineTemplateName)
	migrateOptionalTemplate(ShrineConfig.TemplateFolderName, ShrineConfig.MagnetShrineTemplateName)
	migrateOptionalTemplate(PortalConfig.TemplateFolderName, PortalConfig.PortalTemplateName)
	migrateOptionalTemplate(ChestConfig.TemplateFolderName, ChestConfig.ChestName)
	migrateOptionalTemplate(JarConfig.TemplateFolderName, JarConfig.JarName)

	DebugLog.Info("Templates", "Arborescence templates/runtime prete", {
		CombatRuntime = TemplateService.GetCombatRuntimeFolder(),
		ChestsRuntime = TemplateService.GetChestsRuntimeFolder(),
		PortalsRuntime = TemplateService.GetPortalsRuntimeFolder(),
		ShrinesRuntime = TemplateService.GetShrinesRuntimeFolder(),
		JarsRuntime = TemplateService.GetJarsRuntimeFolder(),
		MapRuntime = TemplateService.GetMapRuntimeFolder(),
	})
end

return TemplateService
