--!strict

-- Adaptateur isole de la barre d'outils V2. Les vraies pages Parametres et
-- Support seront branchees plus tard : cette passe ne remplace aucun bouton
-- Audio, Video ou Admin deja utilise par le jeu.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local DebugLog = require(Shared:WaitForChild("DebugLog"))
local UiTemplateConfig = require(Shared:WaitForChild("UiTemplateConfig"))

local PRODUCTION_TEMPLATE_GUI_NAME = UiTemplateConfig.ProductionTemplateGuiName
local PRODUCTION_GUI_NAME = "RunUtilityGui"
local PRODUCTION_DOCK_NAME = "UtilityDockV2"

local existingGui = playerGui:FindFirstChild(PRODUCTION_GUI_NAME)

if existingGui then
	existingGui:Destroy()
end

local function getTemplate(): Frame?
	local templateGui = StarterGui:FindFirstChild(PRODUCTION_TEMPLATE_GUI_NAME)
	local runCanvas = templateGui and templateGui:FindFirstChild("RunCanvas")
	local dock = runCanvas and runCanvas:FindFirstChild("UtilityDock")

	if dock and dock:IsA("Frame") then
		return dock
	end

	DebugLog.Warn("UI", "Barre d'outils V2 non initialisee, template introuvable")
	return nil
end

local template = getTemplate()

if template == nil then
	return
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = PRODUCTION_GUI_NAME
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 26
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Enabled = true
screenGui.Parent = playerGui

local dock = template:Clone()
dock.Name = PRODUCTION_DOCK_NAME
dock.Visible = false
dock:SetAttribute("ProductionBound", true)
dock.Parent = screenGui

local surface = dock:FindFirstChild("Surface")
if surface and surface:IsA("Frame") then
	-- La texture reste celle de la Top Bar, mais la barre d'outils se place
	-- derriere le gameplay avec un verre un peu plus present.
	surface.BackgroundTransparency = 0.22

	local innerGlass = surface:FindFirstChild("InnerGlass")
	if innerGlass and innerGlass:IsA("Frame") then
		innerGlass.BackgroundTransparency = math.max(innerGlass.BackgroundTransparency, 0.68)
	end
end

local content = dock:FindFirstChild("Content")

if content and content:IsA("GuiObject") then
	for _, child in ipairs(content:GetChildren()) do
		if child:IsA("TextButton") then
			local accent = child:FindFirstChild("Accent")
			local label = child:FindFirstChild("Label")
			local baseTransparency = child.BackgroundTransparency

			child.AutoButtonColor = false
			child.MouseEnter:Connect(function()
				TweenService:Create(child, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					BackgroundTransparency = 0.52,
				}):Play()

				if accent and accent:IsA("Frame") then
					TweenService:Create(accent, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					BackgroundTransparency = 0.02,
					Size = UDim2.new(1, -10, 0, 2),
					}):Play()
				end

				if label and label:IsA("TextLabel") then
					TweenService:Create(label, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					TextColor3 = Color3.fromRGB(245, 246, 255),
					}):Play()
				end
			end)

			child.MouseLeave:Connect(function()
				TweenService:Create(child, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					BackgroundTransparency = baseTransparency,
				}):Play()

				if accent and accent:IsA("Frame") then
					TweenService:Create(accent, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					BackgroundTransparency = 0.34,
					Size = UDim2.new(1, -18, 0, 1),
					}):Play()
				end
			end)
		end
	end
end

local function refreshVisibility()
	dock.Visible = player:GetAttribute("IsRunActive") == true
end

player:GetAttributeChangedSignal("IsRunActive"):Connect(refreshVisibility)
refreshVisibility()
