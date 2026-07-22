local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CharacterConfig = require(Shared:WaitForChild("CharacterConfig"))
local DebugLog = require(Shared:WaitForChild("DebugLog"))
local WeaponSkinConfig = require(Shared:WaitForChild("WeaponSkinConfig"))

local MetaProgressionService = require(script.Parent:WaitForChild("MetaProgressionService"))

local WeaponSkinService = {}

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

local selectSkinRemote = getOrCreateRemote("WeaponSkin_Select")

local function getFireballSkin(skinId)
	for _, skin in ipairs(WeaponSkinConfig.Weapons.fireball.Skins) do
		if skin.Id == skinId then
			return skin
		end
	end

	return nil
end

function WeaponSkinService.GetSelectedFireballSkin(player)
	local runSkinId = player:GetAttribute("RunWeaponSkinId")
	if typeof(runSkinId) == "string" and getFireballSkin(runSkinId) ~= nil then
		return runSkinId
	end

	local requestedSkinId = player:GetAttribute("FireballSkinId")

	if typeof(requestedSkinId) == "string" and getFireballSkin(requestedSkinId) ~= nil then
		return requestedSkinId
	end

	return WeaponSkinConfig.Weapons.fireball.DefaultSkinId
end

function WeaponSkinService.SetupPlayer(player)
	local characterId = tostring(player:GetAttribute("SelectedCharacterId") or "medivh")
	local cosmetics = MetaProgressionService.GetCosmeticSelection(player, characterId)
	local selectedSkinId = cosmetics.WeaponSkinId
	if getFireballSkin(selectedSkinId) == nil then
		selectedSkinId = WeaponSkinConfig.Weapons.fireball.DefaultSkinId
	end
	player:SetAttribute("FireballSkinId", selectedSkinId)
end

function WeaponSkinService.RemovePlayer(_player)
	-- L'apparence est pour l'instant une selection de session : aucune donnee persistante a nettoyer.
end

local function canUseSkin(skin)
	-- Les skins achetables devront valider leur ownership serveur ici.
	return skin.UnlockType == "Starter"
end

local function selectFireballSkin(player, skinId)
	if typeof(skinId) ~= "string" then
		return
	end

	local skin = getFireballSkin(skinId)

	if skin == nil or not canUseSkin(skin) then
		DebugLog.Warn("Weapon", "Selection skin Fireball refusee", {
			Player = player.Name,
			SkinId = skinId,
		})
		return
	end

	local characterId = tostring(player:GetAttribute("SelectedCharacterId") or "")
	local characterDefinition = CharacterConfig.GetDefinition(characterId)
	if characterDefinition == nil or characterDefinition.PrimaryWeaponId ~= "fireball" then
		DebugLog.Warn("Weapon", "Selection skin Fireball incompatible avec le personnage", {
			Player = player.Name,
			CharacterId = characterId,
		})
		return
	end

	local cosmetics = MetaProgressionService.GetCosmeticSelection(player, characterId)
	local persisted, persistReason = MetaProgressionService.SetCosmeticSelection(
		player,
		characterId,
		cosmetics.CharacterSkinId,
		skin.Id
	)
	if not persisted then
		DebugLog.Warn("Weapon", "Persistance du skin Fireball impossible", {
			Player = player.Name,
			SkinId = skin.Id,
			Reason = tostring(persistReason),
		})
		return
	end

	player:SetAttribute("FireballSkinId", skin.Id)
	DebugLog.Info("Weapon", "Skin Fireball selectionne", {
		Player = player.Name,
		SkinId = skin.Id,
	})
end

function WeaponSkinService.Start()
	if isStarted then
		return
	end

	isStarted = true
	selectSkinRemote.OnServerEvent:Connect(selectFireballSkin)

	local function bindCharacterSelection(player)
		player:GetAttributeChangedSignal("SelectedCharacterId"):Connect(function()
			WeaponSkinService.SetupPlayer(player)
		end)
	end

	for _, player in ipairs(Players:GetPlayers()) do
		WeaponSkinService.SetupPlayer(player)
		bindCharacterSelection(player)
	end
	Players.PlayerAdded:Connect(bindCharacterSelection)

	DebugLog.Info("Weapon", "WeaponSkinService demarre", {
		DefaultSkinId = WeaponSkinConfig.Weapons.fireball.DefaultSkinId,
	})
end

return WeaponSkinService
