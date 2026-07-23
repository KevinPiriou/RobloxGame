--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CharacterConfig = require(Shared:WaitForChild("CharacterConfig"))
local CharacterDefinitionValidator = require(Shared:WaitForChild("CharacterDefinitionValidator"))
local CharacterSkinConfig = require(Shared:WaitForChild("CharacterSkinConfig"))
local DebugLog = require(Shared:WaitForChild("DebugLog"))

local MetaProgressionService = require(script.Parent:WaitForChild("MetaProgressionService"))
local RunStateService = require(script.Parent:WaitForChild("RunStateService"))

local CharacterService = {}

local profilesByUserId = {}
local characterConnectionsByUserId = {}
local originalAppearanceByUserId = {}
local runnableDefinitions, definitionDiagnostics = CharacterDefinitionValidator.ValidateAll()
local isStarted = false

local IDENTITY_TAG_NAME = "MegaRobloxCharacterIdentity"
local IDENTITY_TAG_MAX_DISTANCE = 80

local function getOrCreateRemote(remoteName: string, className: string)
	local remote = ReplicatedStorage:FindFirstChild(remoteName)
	if remote == nil then
		remote = Instance.new(className)
		remote.Name = remoteName
		remote.Parent = ReplicatedStorage
	end
	assert(remote.ClassName == className, remoteName .. " doit etre un " .. className)
	return remote
end

local getRosterRemote = getOrCreateRemote("Character_GetRoster", "RemoteFunction") :: RemoteFunction
local selectRemote = getOrCreateRemote("Character_Select", "RemoteEvent") :: RemoteEvent
local updateRemote = getOrCreateRemote("Character_Update", "RemoteEvent") :: RemoteEvent

local function getProfile(player: Player)
	local profile = profilesByUserId[player.UserId]
	if profile == nil then
		profile = {
			SelectedCharacterId = nil,
			ActiveRunSnapshot = nil,
		}
		profilesByUserId[player.UserId] = profile
	end
	return profile
end

local function copyRunSnapshot(snapshot)
	if typeof(snapshot) ~= "table" then
		return nil
	end

	return {
		SchemaVersion = math.max(1, math.floor(tonumber(snapshot.SchemaVersion) or CharacterConfig.SchemaVersion)),
		CharacterId = tostring(snapshot.CharacterId or ""),
		PrimaryWeaponId = tostring(snapshot.PrimaryWeaponId or ""),
		CharacterSkinId = tostring(snapshot.CharacterSkinId or "default"),
		WeaponSkinId = tostring(snapshot.WeaponSkinId or "default"),
	}
end

local function publishRuntimeState(player: Player)
	local snapshot = getProfile(player).ActiveRunSnapshot
	player:SetAttribute("RunCharacterId", snapshot and snapshot.CharacterId or nil)
	player:SetAttribute("RunPrimaryWeaponId", snapshot and snapshot.PrimaryWeaponId or nil)
	player:SetAttribute("RunCharacterSkinId", snapshot and snapshot.CharacterSkinId or nil)
	player:SetAttribute("RunWeaponSkinId", snapshot and snapshot.WeaponSkinId or nil)
end

local function getIdentityDefinition(player: Player)
	local profile = getProfile(player)
	local characterId = profile.SelectedCharacterId or CharacterConfig.DefaultCharacterId
	return CharacterConfig.GetDefinition(characterId)
end

local function clearIdentityTag(character: Model?)
	if character == nil then
		return
	end

	local tag = character:FindFirstChild(IDENTITY_TAG_NAME)
	if tag ~= nil then
		tag:Destroy()
	end
end

local function attachIdentityTag(player: Player)
	local character = player.Character
	local definition = getIdentityDefinition(player)

	if character == nil or definition == nil then
		return
	end

	clearIdentityTag(character)

	local head = character:FindFirstChild("Head") or character:WaitForChild("Head", 5)
	if head == nil or not head:IsA("BasePart") then
		return
	end

	local tag = Instance.new("BillboardGui")
	tag.Name = IDENTITY_TAG_NAME
	tag.Adornee = head
	tag.AlwaysOnTop = false
	tag.LightInfluence = 0
	tag.MaxDistance = IDENTITY_TAG_MAX_DISTANCE
	tag.Size = UDim2.fromOffset(160, 26)
	tag.StudsOffsetWorldSpace = Vector3.new(0, 3.15, 0)
	tag.Parent = character

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.MontserratBold
	label.Text = definition.Name
	label.TextColor3 = Color3.fromRGB(245, 246, 255)
	label.TextSize = 14
	label.TextStrokeColor3 = Color3.fromRGB(20, 12, 36)
	label.TextStrokeTransparency = 0.35
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = tag
end

local function rememberAppearance(player: Player, character: Model)
	local current = originalAppearanceByUserId[player.UserId]
	if current ~= nil and current.Character == character then
		return current
	end

	local shirt = character:FindFirstChildOfClass("Shirt")
	local pants = character:FindFirstChildOfClass("Pants")
	local snapshot = {
		Character = character,
		HadShirt = shirt ~= nil,
		ShirtTemplate = shirt and shirt.ShirtTemplate or "",
		HadPants = pants ~= nil,
		PantsTemplate = pants and pants.PantsTemplate or "",
	}
	originalAppearanceByUserId[player.UserId] = snapshot
	return snapshot
end

local function setShirt(character: Model, templateId: string)
	local shirt = character:FindFirstChildOfClass("Shirt")
	if shirt == nil then
		shirt = Instance.new("Shirt")
		shirt.Name = "MegaRobloxRunShirt"
		shirt.Parent = character
	end
	shirt.ShirtTemplate = templateId
end

local function setPants(character: Model, templateId: string)
	local pants = character:FindFirstChildOfClass("Pants")
	if pants == nil then
		pants = Instance.new("Pants")
		pants.Name = "MegaRobloxRunPants"
		pants.Parent = character
	end
	pants.PantsTemplate = templateId
end

local function restoreAppearance(player: Player)
	local snapshot = originalAppearanceByUserId[player.UserId]
	originalAppearanceByUserId[player.UserId] = nil
	if snapshot == nil then
		return
	end

	local character = snapshot.Character
	if character == nil or character.Parent == nil then
		return
	end

	local shirt = character:FindFirstChildOfClass("Shirt")
	if snapshot.HadShirt then
		setShirt(character, snapshot.ShirtTemplate)
	elseif shirt ~= nil then
		shirt:Destroy()
	end

	local pants = character:FindFirstChildOfClass("Pants")
	if snapshot.HadPants then
		setPants(character, snapshot.PantsTemplate)
	elseif pants ~= nil then
		pants:Destroy()
	end
end

local function getClothingForSkin(definition, characterSkinId: string)
	local clothing = definition and definition.Appearance and definition.Appearance.Clothing
	local characterSkins = definition and CharacterSkinConfig.Characters[definition.Id]
	if characterSkins == nil then
		return clothing
	end

	for _, skin in ipairs(characterSkins.Skins) do
		if skin.Id == characterSkinId and skin.Clothing ~= nil then
			return skin.Clothing
		end
	end

	return clothing
end

local function applyRunAppearance(player: Player, character: Model)
	local snapshot = getProfile(player).ActiveRunSnapshot
	local definition = snapshot and runnableDefinitions[snapshot.CharacterId]
	local clothing = getClothingForSkin(definition, snapshot and snapshot.CharacterSkinId or "default")
	if clothing == nil then
		attachIdentityTag(player)
		return
	end

	rememberAppearance(player, character)
	setShirt(character, clothing.ShirtTemplate)
	setPants(character, clothing.PantsTemplate)
	attachIdentityTag(player)
end

local function getAvailability(player: Player, characterId: string, definition)
	local unlocked = MetaProgressionService.IsCharacterUnlocked(player, characterId)
	local weaponUnlocked = MetaProgressionService.IsWeaponUnlocked(player, definition.PrimaryWeaponId)
	local runnable, errors = CharacterDefinitionValidator.IsRunnable(characterId)

	if not unlocked then
		return false, "CharacterLocked", errors
	end

	if not weaponUnlocked then
		return false, "PrimaryWeaponLocked", errors
	end

	if not runnable then
		return false, "CharacterNotReady", errors
	end

	return true, "Ok", errors
end

local function buildRoster(player: Player)
	local entries = {}
	local selectedCharacterId = getProfile(player).SelectedCharacterId

	for characterId, definition in pairs(CharacterConfig.Definitions) do
		local available, reason, errors = getAvailability(player, characterId, definition)
		table.insert(entries, {
			Id = characterId,
			Name = definition.Name,
			NameKey = definition.NameKey,
			Description = definition.Description,
			DescriptionKey = definition.DescriptionKey,
			Portrait = definition.Portrait,
			PrimaryWeaponId = definition.PrimaryWeaponId,
			Passive = definition.Passive,
			Unlock = definition.Unlock,
			Lifecycle = definition.Lifecycle,
			Unlocked = MetaProgressionService.IsCharacterUnlocked(player, characterId),
			PrimaryWeaponUnlocked = MetaProgressionService.IsWeaponUnlocked(player, definition.PrimaryWeaponId),
			AvailableForRun = available,
			Reason = reason,
			Diagnostics = errors,
			Selected = selectedCharacterId == characterId,
		})
	end

	table.sort(entries, function(left, right)
		return left.Id < right.Id
	end)

	return {
		SchemaVersion = CharacterConfig.SchemaVersion,
		SelectedCharacterId = selectedCharacterId,
		Characters = entries,
	}
end

local function publish(player: Player)
	if player.Parent == Players then
		local profile = getProfile(player)
		local definition = profile.SelectedCharacterId and CharacterConfig.GetDefinition(profile.SelectedCharacterId)
		player:SetAttribute("SelectedCharacterId", profile.SelectedCharacterId)
		player:SetAttribute("SelectedPrimaryWeaponId", definition and definition.PrimaryWeaponId or nil)
		publishRuntimeState(player)
		updateRemote:FireClient(player, buildRoster(player))
	end
end

function CharacterService.SetupPlayer(player: Player)
	local profile = getProfile(player)
	local persistedCharacterId = MetaProgressionService.GetSelectedCharacterId(player)
	local persistedDefinition = persistedCharacterId and CharacterConfig.GetDefinition(persistedCharacterId)
	if persistedDefinition ~= nil and getAvailability(player, persistedCharacterId, persistedDefinition) then
		profile.SelectedCharacterId = persistedCharacterId
	else
		profile.SelectedCharacterId = CharacterConfig.DefaultCharacterId
	end
	local previousConnection = characterConnectionsByUserId[player.UserId]
	if previousConnection ~= nil then
		previousConnection:Disconnect()
	end
	characterConnectionsByUserId[player.UserId] = player.CharacterAdded:Connect(function(character)
		if RunStateService.IsRunActive(player) then
			task.defer(applyRunAppearance, player, character)
		end
	end)
	publish(player)
end

function CharacterService.RemovePlayer(player: Player)
	local connection = characterConnectionsByUserId[player.UserId]
	if connection ~= nil then
		connection:Disconnect()
	end
	characterConnectionsByUserId[player.UserId] = nil
	originalAppearanceByUserId[player.UserId] = nil
	profilesByUserId[player.UserId] = nil
end

function CharacterService.SelectCharacter(player: Player, characterId: string)
	if RunStateService.IsRunActive(player) then
		return false, "RunActive"
	end

	local normalizedCharacterId = tostring(characterId or "")
	local definition = CharacterConfig.GetDefinition(normalizedCharacterId)
	if definition == nil then
		return false, "UnknownCharacter"
	end

	local available, reason = getAvailability(player, normalizedCharacterId, definition)
	if not available then
		return false, reason
	end

	local persisted, persistReason = MetaProgressionService.SetSelectedCharacterId(player, normalizedCharacterId)
	if not persisted then
		return false, tostring(persistReason or "SelectionPersistenceFailed")
	end

	getProfile(player).SelectedCharacterId = normalizedCharacterId
	publish(player)
	return true, "Ok"
end

function CharacterService.GetSelectedDefinition(player: Player)
	local characterId = getProfile(player).SelectedCharacterId
	if characterId == nil then
		return nil
	end

	local definition = runnableDefinitions[characterId]
	if definition == nil then
		return nil
	end

	local available = getAvailability(player, characterId, definition)
	if not available then
		return nil
	end

	return definition
end

function CharacterService.CaptureRunSelection(player: Player)
	local profile = getProfile(player)
	local characterId = profile.SelectedCharacterId or CharacterConfig.DefaultCharacterId
	local definition = runnableDefinitions[characterId]
	if definition == nil then
		return false, "CharacterNotReady", nil
	end

	local available, reason = getAvailability(player, characterId, definition)
	if not available then
		return false, reason, nil
	end

	local cosmetics = MetaProgressionService.GetCosmeticSelection(player, characterId)
	return true, "Ok", {
		SchemaVersion = CharacterConfig.SchemaVersion,
		CharacterId = characterId,
		PrimaryWeaponId = definition.PrimaryWeaponId,
		CharacterSkinId = cosmetics.CharacterSkinId,
		WeaponSkinId = cosmetics.WeaponSkinId,
	}
end

function CharacterService.ActivateRunSelection(player: Player, rawSnapshot)
	local snapshot = copyRunSnapshot(rawSnapshot)
	if snapshot == nil then
		return false, "CharacterSnapshotMissing"
	end

	local definition = runnableDefinitions[snapshot.CharacterId]
	if definition == nil or definition.PrimaryWeaponId ~= snapshot.PrimaryWeaponId then
		return false, "CharacterSnapshotInvalid"
	end

	local available, reason = getAvailability(player, snapshot.CharacterId, definition)
	if not available then
		return false, reason
	end

	local profile = getProfile(player)
	profile.SelectedCharacterId = snapshot.CharacterId
	profile.ActiveRunSnapshot = snapshot
	publish(player)
	return true, "Ok"
end

function CharacterService.GetActiveRunSnapshot(player: Player)
	return copyRunSnapshot(getProfile(player).ActiveRunSnapshot)
end

function CharacterService.GetActiveDefinition(player: Player)
	local snapshot = getProfile(player).ActiveRunSnapshot
	return snapshot and runnableDefinitions[snapshot.CharacterId] or nil
end

function CharacterService.GetPlayerStatBaseMultiplier(player: Player, statId: string): number
	local definition = CharacterService.GetActiveDefinition(player)
	local passive = definition and definition.Passive
	if passive == nil or passive.Scope ~= "Player" then
		return 1
	end

	local multiplier = 1
	for _, modifier in ipairs(passive.Modifiers or {}) do
		if modifier.StatId == statId and modifier.Operation == "MultiplyBase" then
			multiplier *= modifier.Amount
		end
	end
	return math.max(0, multiplier)
end

function CharacterService.GetPlayerStatAdditiveBonus(player: Player, statId: string): number
	local definition = CharacterService.GetActiveDefinition(player)
	local passive = definition and definition.Passive
	if passive == nil or passive.Scope ~= "Player" then
		return 0
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	local levelValue = if leaderstats then leaderstats:FindFirstChild("Level") else nil
	local level = if levelValue and levelValue:IsA("IntValue") then math.max(1, levelValue.Value) else 1
	local bonus = 0

	for _, modifier in ipairs(passive.Modifiers or {}) do
		if modifier.StatId == statId then
			if modifier.Operation == "Add" then
				bonus += modifier.Amount
			elseif modifier.Operation == "AddPerLevel" then
				bonus += modifier.Amount * level
			end
		end
	end

	return bonus
end

function CharacterService.GetRoster(player: Player)
	return buildRoster(player)
end

function CharacterService.Start()
	if isStarted then
		return
	end
	isStarted = true

	getRosterRemote.OnServerInvoke = function(player)
		return CharacterService.GetRoster(player)
	end

	selectRemote.OnServerEvent:Connect(function(player, characterId)
		local success, reason = CharacterService.SelectCharacter(player, tostring(characterId or ""))
		if not success then
			DebugLog.Warn("Character", "Selection de personnage refusee", {
				Player = player.Name,
				CharacterId = characterId,
				Reason = reason,
			})
		end
	end)

	RunStateService.RunEnded:Connect(function(player)
		clearIdentityTag(player.Character)
		restoreAppearance(player)
		getProfile(player).ActiveRunSnapshot = nil
		publish(player)
	end)

	RunStateService.RunStarted:Connect(function(player)
		local character = player.Character
		if character ~= nil then
			task.spawn(applyRunAppearance, player, character)
		end
	end)

	for characterId, errors in pairs(definitionDiagnostics) do
		if #errors > 0 then
			DebugLog.Warn("Character", "Definition de personnage non activable", {
				CharacterId = characterId,
				Errors = errors,
			})
		end
	end

	DebugLog.Info("Character", "Service de personnages initialise", {
		Definitions = (function()
			local count = 0
			for _ in pairs(CharacterConfig.Definitions) do
				count += 1
			end
			return count
		end)(),
		RunnableDefinitions = (function()
			local count = 0
			for _ in pairs(runnableDefinitions) do
				count += 1
			end
			return count
		end)(),
	})
end

return CharacterService
