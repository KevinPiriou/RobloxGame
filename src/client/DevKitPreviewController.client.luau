local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local DRAFT_GUI_NAME = "MegaRobloxUIV_RunLayoutDraft"
local DEV_KIT_PREVIEW_ATTRIBUTE = "DevKitPreviewEnabled"

local draftGui = playerGui:WaitForChild(DRAFT_GUI_NAME, 30)

if draftGui == nil or not draftGui:IsA("ScreenGui") then
	warn("[MegaRoblox][UI] Apercu kit UI indisponible : brouillon introuvable")
	return
end

local originalDraftDisplayOrder = draftGui.DisplayOrder
local combatGui = playerGui:FindFirstChild("CombatGui")
local originalCombatGuiEnabled = true
local isApplying = false
local wasPreviewEnabled = false

if combatGui and combatGui:IsA("ScreenGui") then
	originalCombatGuiEnabled = combatGui.Enabled
else
	combatGui = nil
end

local function getCombatGui()
	if combatGui and combatGui.Parent == playerGui then
		return combatGui
	end

	local candidate = playerGui:FindFirstChild("CombatGui")

	if candidate and candidate:IsA("ScreenGui") then
		combatGui = candidate
		originalCombatGuiEnabled = candidate.Enabled
		return candidate
	end

	return nil
end

local function applyPreviewState()
	if isApplying then
		return
	end

	isApplying = true
	local isPreviewEnabled = player:GetAttribute(DEV_KIT_PREVIEW_ATTRIBUTE) == true
	local currentCombatGui = getCombatGui()

	if isPreviewEnabled then
		if currentCombatGui then
			if not wasPreviewEnabled then
				originalCombatGuiEnabled = currentCombatGui.Enabled
			end

			currentCombatGui.Enabled = false
		end

		-- Le brouillon reste sous l'admin et sous un vrai choix de perk afin que
	-- l'apercu ne masque jamais une interaction de gameplay active.
		draftGui.DisplayOrder = 6
		draftGui.Enabled = true
	else
		draftGui.Enabled = false
		draftGui.DisplayOrder = originalDraftDisplayOrder

		if currentCombatGui and wasPreviewEnabled then
			currentCombatGui.Enabled = originalCombatGuiEnabled
		end
	end

	wasPreviewEnabled = isPreviewEnabled
	isApplying = false
end

-- Le brouillon est masque par defaut en production. L'attribut serveur est
-- l'unique chemin normal qui autorise son affichage pour un administrateur.
draftGui.Enabled = false

draftGui:GetPropertyChangedSignal("Enabled"):Connect(function()
	if not isApplying and player:GetAttribute(DEV_KIT_PREVIEW_ATTRIBUTE) == true and not draftGui.Enabled then
		task.defer(applyPreviewState)
	end
end)

playerGui.ChildAdded:Connect(function(child)
	if child.Name == "CombatGui" and child:IsA("ScreenGui") then
		combatGui = child
		originalCombatGuiEnabled = child.Enabled
		applyPreviewState()
	end
end)

player:GetAttributeChangedSignal(DEV_KIT_PREVIEW_ATTRIBUTE):Connect(applyPreviewState)
applyPreviewState()
