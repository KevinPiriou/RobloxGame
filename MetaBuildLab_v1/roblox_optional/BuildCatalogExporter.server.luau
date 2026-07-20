--!strict
-- À exécuter côté serveur dans Studio après synchronisation.
-- Produit un JSON de snapshot sous ReplicatedStorage/BuildMetaExports.
-- Il ne modifie aucun système de gameplay.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))
local Perks = require(Shared:WaitForChild("Perks"))
local RunItemConfig = require(Shared:WaitForChild("RunItemConfig"))
local BuildMetaConfig = require(Shared:WaitForChild("BuildMetaConfig"))

local function sanitize(value)
	local valueType = typeof(value)

	if valueType == "Color3" then
		return {
			__type = "Color3",
			r = math.floor(value.R * 255 + 0.5),
			g = math.floor(value.G * 255 + 0.5),
			b = math.floor(value.B * 255 + 0.5),
		}
	elseif valueType == "Vector3" then
		return {
			__type = "Vector3",
			x = value.X,
			y = value.Y,
			z = value.Z,
		}
	elseif valueType == "EnumItem" then
		return tostring(value)
	elseif valueType ~= "table" then
		return value
	end

	local result = {}
	for key, child in pairs(value) do
		result[tostring(key)] = sanitize(child)
	end
	return result
end

local snapshot = {
	SchemaVersion = 1,
	ExportedAt = os.time(),
	CombatConfig = sanitize(CombatConfig),
	Perks = sanitize(Perks),
	RunItemConfig = sanitize(RunItemConfig),
	BuildMetaConfig = sanitize(BuildMetaConfig),
}

local json = HttpService:JSONEncode(snapshot)
local folder = ReplicatedStorage:FindFirstChild("BuildMetaExports")

if folder == nil then
	folder = Instance.new("Folder")
	folder.Name = "BuildMetaExports"
	folder.Parent = ReplicatedStorage
end

local value = folder:FindFirstChild("LatestJson")

if value == nil then
	value = Instance.new("StringValue")
	value.Name = "LatestJson"
	value.Parent = folder
end

assert(value:IsA("StringValue"))
value.Value = json

print(
	("BuildMeta export prêt : %d caractères dans %s")
		:format(#json, value:GetFullName())
)
