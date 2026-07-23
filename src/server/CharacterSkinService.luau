local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CharacterConfig = require(Shared:WaitForChild("CharacterConfig"))
local CharacterSkinConfig = require(Shared:WaitForChild("CharacterSkinConfig"))
local DebugLog = require(Shared:WaitForChild("DebugLog"))

local MetaProgressionService = require(script.Parent:WaitForChild("MetaProgressionService"))

local CharacterSkinService = {}

local isStarted = false

local function getOrCreateRemote(remoteName)
	local remote = ReplicatedStorage:FindFirstChild(remoteName)
	if remote == nil then
		remote = Instance.new("RemoteEvent")
		remote.Name = remoteName
		remote.Parent = ReplicatedStorage
	end
	assert(remote:IsA("RemoteEvent"), remoteName .. " doit etre un RemoteEvent.")
	return remote
end

local selectSkinRemote = getOrCreateRemote("CharacterSkin_Select")

local function getCharacterEntry(characterId)
	return CharacterSkinConfig.Characters[tostring(characterId or "")]
end

local function getSkin(characterId, skinId)
	local entry = getCharacterEntry(characterId)
	if entry == nil then
		return nil
	end
	for _, skin in ipairs(entry.Skins) do
		if skin.Id == skinId then
			return skin
		end
	end
	return nil
end

local function getDefaultSkinId(characterId)
	local entry = getCharacterEntry(characterId)
	return entry and entry.DefaultSkinId or "default"
end

local function canUseSkin(skin)
	return skin.UnlockType == "Starter"
end

function CharacterSkinService.SetupPlayer(player)
	local characterId = tostring(player:GetAttribute("SelectedCharacterId") or CharacterConfig.DefaultCharacterId)
	local cosmetics = MetaProgressionService.GetCosmeticSelection(player, characterId)
	local skinId = cosmetics.CharacterSkinId
	if getSkin(characterId, skinId) == nil then
		skinId = getDefaultSkinId(characterId)
	end
	player:SetAttribute("SelectedCharacterSkinId", skinId)
end

function CharacterSkinService.RemovePlayer(_player)
	-- La selection persiste dans MetaProgressionService.
end

local function selectCharacterSkin(player, skinId)
	if typeof(skinId) ~= "string" then
		return
	end

	local characterId = tostring(player:GetAttribute("SelectedCharacterId") or "")
	local skin = getSkin(characterId, skinId)
	if skin == nil or not canUseSkin(skin) then
		DebugLog.Warn("Character", "Selection skin de personnage refusee", {
			Player = player.Name,
			CharacterId = characterId,
			SkinId = skinId,
		})
		return
	end

	local cosmetics = MetaProgressionService.GetCosmeticSelection(player, characterId)
	local persisted, reason = MetaProgressionService.SetCosmeticSelection(
		player,
		characterId,
		skin.Id,
		cosmetics.WeaponSkinId
	)
	if not persisted then
		DebugLog.Warn("Character", "Persistance du skin de personnage impossible", {
			Player = player.Name,
			CharacterId = characterId,
			SkinId = skin.Id,
			Reason = tostring(reason),
		})
		return
	end

	player:SetAttribute("SelectedCharacterSkinId", skin.Id)
	DebugLog.Info("Character", "Skin de personnage selectionne", {
		Player = player.Name,
		CharacterId = characterId,
		SkinId = skin.Id,
	})
end

function CharacterSkinService.Start()
	if isStarted then
		return
	end

	isStarted = true
	selectSkinRemote.OnServerEvent:Connect(selectCharacterSkin)

	local function bindCharacterSelection(player)
		player:GetAttributeChangedSignal("SelectedCharacterId"):Connect(function()
			CharacterSkinService.SetupPlayer(player)
		end)
	end

	for _, player in ipairs(Players:GetPlayers()) do
		CharacterSkinService.SetupPlayer(player)
		bindCharacterSelection(player)
	end
	Players.PlayerAdded:Connect(bindCharacterSelection)
end

return CharacterSkinService
