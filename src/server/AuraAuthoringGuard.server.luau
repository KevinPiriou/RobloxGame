-- Retire la scene de calibration du monde runtime sans toucher a la scene d'edition.

local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

if not RunService:IsRunning() then
	return
end

local preview = Workspace:FindFirstChild("AuraAuthoringPreview")

if preview ~= nil and preview:GetAttribute("MegaRobloxAuraAuthoring") == true then
	preview.Parent = ServerStorage
end
