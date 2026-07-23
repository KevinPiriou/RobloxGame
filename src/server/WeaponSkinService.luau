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

local function getWeaponDefinition(weaponId)
	return WeaponSkinConfig.Weapons[tostring(weaponId or "")]
end

local function getSkin(weaponId, skinId)
	local weapon = getWeaponDefinition(weaponId)
	if weapon == nil then
		return nil
	end

	for _, skin in ipairs(weapon.Skins) do
		if skin.Id == skinId then
			return skin
		end
	end

	return nil
end

local function getDefaultSkinId(weaponId)
	local weapon = getWeaponDefinition(weaponId)
	return weapon and weapon.DefaultSkinId or nil
end

function WeaponSkinService.GetSelectedWeaponSkin(player, weaponId)
	local normalizedWeaponId = tostring(weaponId or "")
	local runWeaponId = player:GetAttribute("RunPrimaryWeaponId")
	local runSkinId = player:GetAttribute("RunWeaponSkinId")
	if runWeaponId == normalizedWeaponId and typeof(runSkinId) == "string" and getSkin(normalizedWeaponId, runSkinId) ~= nil then
		return runSkinId
	end

	local selectedSkinId = player:GetAttribute("SelectedWeaponSkinId")
	if typeof(selectedSkinId) == "string" and getSkin(normalizedWeaponId, selectedSkinId) ~= nil then
		return selectedSkinId
	end

	if normalizedWeaponId == "fireball" then
		local legacySkinId = player:GetAttribute("FireballSkinId")
		if typeof(legacySkinId) == "string" and getSkin(normalizedWeaponId, legacySkinId) ~= nil then
			return legacySkinId
		end
	end

	return getDefaultSkinId(normalizedWeaponId)
end

function WeaponSkinService.GetSelectedFireballSkin(player)
	return WeaponSkinService.GetSelectedWeaponSkin(player, "fireball")
end

function WeaponSkinService.SetupPlayer(player)
	local characterId = tostring(player:GetAttribute("SelectedCharacterId") or CharacterConfig.DefaultCharacterId)
	local characterDefinition = CharacterConfig.GetDefinition(characterId)
	local weaponId = characterDefinition and characterDefinition.PrimaryWeaponId or "fireball"
	local cosmetics = MetaProgressionService.GetCosmeticSelection(player, characterId)
	local selectedSkinId = cosmetics.WeaponSkinId
	if getSkin(weaponId, selectedSkinId) == nil then
		selectedSkinId = getDefaultSkinId(weaponId)
	end

	player:SetAttribute("SelectedWeaponSkinId", selectedSkinId)
	if weaponId == "fireball" then
		player:SetAttribute("FireballSkinId", selectedSkinId)
	else
		player:SetAttribute("FireballSkinId", nil)
	end
end

function WeaponSkinService.RemovePlayer(_player)
	-- La selection est persistee dans le profil joueur, aucun cache de session a liberer.
end

local function canUseSkin(skin)
	-- Les skins achetables devront valider leur ownership serveur ici.
	return skin.UnlockType == "Starter"
end

local function selectWeaponSkin(player, skinId)
	if typeof(skinId) ~= "string" then
		return
	end

	local characterId = tostring(player:GetAttribute("SelectedCharacterId") or "")
	local characterDefinition = CharacterConfig.GetDefinition(characterId)
	if characterDefinition == nil then
		return
	end

	local weaponId = characterDefinition.PrimaryWeaponId
	local skin = getSkin(weaponId, skinId)
	if skin == nil or not canUseSkin(skin) then
		DebugLog.Warn("Weapon", "Selection skin d'arme refusee", {
			Player = player.Name,
			WeaponId = weaponId,
			SkinId = skinId,
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
		DebugLog.Warn("Weapon", "Persistance du skin d'arme impossible", {
			Player = player.Name,
			WeaponId = weaponId,
			SkinId = skin.Id,
			Reason = tostring(persistReason),
		})
		return
	end

	player:SetAttribute("SelectedWeaponSkinId", skin.Id)
	if weaponId == "fireball" then
		player:SetAttribute("FireballSkinId", skin.Id)
	end

	DebugLog.Info("Weapon", "Skin d'arme selectionne", {
		Player = player.Name,
		WeaponId = weaponId,
		SkinId = skin.Id,
	})
end

function WeaponSkinService.Start()
	if isStarted then
		return
	end

	isStarted = true
	selectSkinRemote.OnServerEvent:Connect(selectWeaponSkin)

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
		Weapons = (function()
			local count = 0
			for _ in pairs(WeaponSkinConfig.Weapons) do
				count += 1
			end
			return count
		end)(),
	})
end

return WeaponSkinService
