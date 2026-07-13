local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DebugLog = require(Shared:WaitForChild("DebugLog"))
local WeaponSkinConfig = require(Shared:WaitForChild("WeaponSkinConfig"))

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
	local requestedSkinId = player:GetAttribute("FireballSkinId")

	if typeof(requestedSkinId) == "string" and getFireballSkin(requestedSkinId) ~= nil then
		return requestedSkinId
	end

	return WeaponSkinConfig.Weapons.fireball.DefaultSkinId
end

function WeaponSkinService.SetupPlayer(player)
	player:SetAttribute("FireballSkinId", WeaponSkinService.GetSelectedFireballSkin(player))
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

	for _, player in ipairs(Players:GetPlayers()) do
		WeaponSkinService.SetupPlayer(player)
	end

	DebugLog.Info("Weapon", "WeaponSkinService demarre", {
		DefaultSkinId = WeaponSkinConfig.Weapons.fireball.DefaultSkinId,
	})
end

return WeaponSkinService
