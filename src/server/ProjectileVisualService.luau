local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DebugLog = require(Shared:WaitForChild("DebugLog"))
local VfxConfig = require(Shared:WaitForChild("VfxConfig"))
local WeaponSkinConfig = require(Shared:WaitForChild("WeaponSkinConfig"))

local ProjectileVisualService = {}

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

local impactRemote = getOrCreateRemote(VfxConfig.ImpactRemoteName)

local function findFireballSkin(skinId)
	local weapon = WeaponSkinConfig.Weapons.fireball
	local requestedId = skinId or weapon.DefaultSkinId

	for _, skin in ipairs(weapon.Skins) do
		if skin.Id == requestedId then
			return skin
		end
	end

	return weapon.Skins[1]
end

local function disableLegacyVisuals(projectile)
	for _, descendant in ipairs(projectile:GetDescendants()) do
		if descendant:IsA("ParticleEmitter")
			or descendant:IsA("Trail")
			or descendant:IsA("Fire")
			or descendant:IsA("Smoke")
			or descendant:IsA("Sparkles")
		then
			descendant.Enabled = false
		elseif descendant:IsA("PointLight") or descendant:IsA("SpotLight") or descendant:IsA("SurfaceLight") then
			descendant.Enabled = false
		end
	end
end

-- Le serveur ne garde que le noyau lisible et les attributs de presentation.
-- Les particules, trails et impacts sont exclusifs au client du proprietaire.
function ProjectileVisualService.PrepareFireball(projectile, root, player, skinId, visualSerial)
	if projectile == nil or root == nil or player == nil then
		return nil
	end

	local skin = findFireballSkin(skinId)
	local profileId = skin.VfxProfileId or skin.Id
	local profile = VfxConfig.GetProjectileProfile(profileId)

	disableLegacyVisuals(projectile)
	root.Material = Enum.Material.Neon
	root.Color = profile.CoreColor
	root.Transparency = profile.CoreTransparency

	projectile:SetAttribute("WeaponId", WeaponSkinConfig.Weapons.fireball.Id)
	projectile:SetAttribute("ProjectileVisualSerial", visualSerial)
	projectile:SetAttribute("VfxProfileId", profileId)
	projectile:SetAttribute("ProjectileSkinId", skin.Id)
	projectile:SetAttribute("ProjectileOwnerUserId", player.UserId)

	DebugLog.ThrottledInfo("Vfx", "fireball_prepare_" .. profileId, 3, "Noyau Fireball prepare", {
		Player = player.Name,
		ProfileId = profileId,
		Projectile = projectile,
	})

	return profileId
end

function ProjectileVisualService.PlayProjectileImpact(player, profileId, position, seed)
	if player == nil or player.Parent == nil or typeof(position) ~= "Vector3" then
		return
	end

	impactRemote:FireClient(player, {
		Type = "Impact",
		ProfileId = profileId,
		Position = position,
		Seed = math.max(0, math.floor(tonumber(seed) or 0)),
	})
end

return ProjectileVisualService
