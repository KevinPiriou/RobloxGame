--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local DebugLog = require(Shared:WaitForChild("DebugLog"))
local UiTemplateConfig = require(Shared:WaitForChild("UiTemplateConfig"))

local PRODUCTION_GUI_NAME = "RunLoadoutV2"
local COMPONENTS = {
	{Template = "WeaponDock", Runtime = "WeaponDockV2"},
	{Template = "GemDock", Runtime = "GemDockV2"},
	{Template = "UltimateDock", Runtime = "UltimateDockV2"},
}

local pendingLoadout = nil

local function asFrame(instance: Instance?)
	return if instance and instance:IsA("Frame") then instance else nil
end

local function applyWeaponLoadout(screenGui: ScreenGui, payload)
	if typeof(payload) ~= "table" or typeof(payload.Weapons) ~= "table" then
		return
	end

	local weaponDock = asFrame(screenGui:FindFirstChild("WeaponDockV2"))
	local content = weaponDock and asFrame(weaponDock:FindFirstChild("Content"))
	local referenceSlot = content and asFrame(content:FindFirstChild("WeaponSlot01"))
	local referenceIcon = referenceSlot and referenceSlot:FindFirstChild("WeaponIcon")
	local referenceBadge = referenceSlot and asFrame(referenceSlot:FindFirstChild("LevelBadge"))

	if content == nil or referenceIcon == nil or not referenceIcon:IsA("ImageLabel") or referenceBadge == nil then
		DebugLog.Warn("UI", "Loadout armes non applique, recette de slot incomplete")
		return
	end

	for slotIndex = 1, math.max(4, tonumber(payload.MaxWeapons) or 4) do
		local slot = asFrame(content:FindFirstChild(("WeaponSlot%02d"):format(slotIndex)))
		if slot == nil then continue end
		local weapon = payload.Weapons[slotIndex]
		local icon = slot:FindFirstChild("WeaponIcon")
		local badge = asFrame(slot:FindFirstChild("LevelBadge"))
		local emptyGlyph = slot:FindFirstChild("EmptyGlyph")

		if icon == nil then
			icon = referenceIcon:Clone()
			icon.Parent = slot
		end
		if badge == nil then
			badge = referenceBadge:Clone()
			badge.Parent = slot
		end

		if icon:IsA("ImageLabel") then
			icon.Image = if weapon then tostring(weapon.Icon or "") else ""
			icon.Visible = weapon ~= nil and icon.Image ~= ""
		end
		badge.Visible = weapon ~= nil
		local level = badge:FindFirstChild("Level")
		if level and level:IsA("TextLabel") then
			level.Text = if weapon then tostring(math.max(1, math.floor(tonumber(weapon.Level) or 1))) else ""
		end
		if emptyGlyph and emptyGlyph:IsA("TextLabel") then
			emptyGlyph.Visible = weapon == nil or tostring(weapon.Icon or "") == ""
			emptyGlyph.Text = if weapon then string.sub(tostring(weapon.Name or "L"), 1, 1) else "+"
		end
		slot:SetAttribute("WeaponId", if weapon then weapon.Id else nil)
	end
end

local function initialise()
	local templateGui = playerGui:WaitForChild(UiTemplateConfig.ProductionTemplateGuiName, 30)
	if templateGui == nil or not templateGui:IsA("ScreenGui") then
		DebugLog.Warn("UI", "Loadout V2 non active, template de production introuvable")
		return
	end

	local templateCanvas = templateGui:FindFirstChild("RunCanvas")
	if templateCanvas == nil or not templateCanvas:IsA("Frame") then
		DebugLog.Warn("UI", "Loadout V2 non active, RunCanvas invalide")
		return
	end

	local previousGui = playerGui:FindFirstChild(PRODUCTION_GUI_NAME)
	if previousGui then
		previousGui:Destroy()
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = PRODUCTION_GUI_NAME
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 18
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Enabled = false
	screenGui.Parent = playerGui

	local mounted = 0
	for _, component in ipairs(COMPONENTS) do
		local source = templateCanvas:FindFirstChild(component.Template)
		if source == nil or not source:IsA("Frame") then
			DebugLog.Warn("UI", "Composant loadout absent du template", {
				Component = component.Template,
			})
			continue
		end

		local dock = source:Clone()
		dock.Name = component.Runtime
		dock.Visible = true
		dock:SetAttribute("ProductionBound", true)
		dock.Parent = screenGui
		mounted += 1
	end

	if mounted ~= #COMPONENTS then
		screenGui:Destroy()
		DebugLog.Warn("UI", "Loadout V2 refuse, composant incomplet", {
			Expected = #COMPONENTS,
			Mounted = mounted,
		})
		return
	end

	-- Le template reste une source figee : aucun de ses composants ne doit
	-- participer directement au rendu de production.
	templateGui.Enabled = false

	local function setRunVisibility(isRunActive: boolean)
		screenGui.Enabled = isRunActive
	end

	setRunVisibility(player:GetAttribute("IsRunActive") == true)
	player:GetAttributeChangedSignal("IsRunActive"):Connect(function()
		setRunVisibility(player:GetAttribute("IsRunActive") == true)
	end)

	task.spawn(function()
		local runStateRemote = ReplicatedStorage:WaitForChild("Run_StateUpdate", 30)
		if runStateRemote and runStateRemote:IsA("RemoteEvent") then
			runStateRemote.OnClientEvent:Connect(function(payload)
				if typeof(payload) == "table" then
					setRunVisibility(payload.IsRunActive == true)
				end
			end)
		end
	end)

	playerGui:SetAttribute("RunLoadoutV2Ready", true)
	DebugLog.Info("UI", "Loadout V2 initialise", {
		Components = mounted,
		Source = UiTemplateConfig.ProductionTemplateGuiName,
	})

	if pendingLoadout then
		applyWeaponLoadout(screenGui, pendingLoadout)
	end

	local getLoadoutRemote = ReplicatedStorage:FindFirstChild("Weapon_GetLoadout")
	if getLoadoutRemote and getLoadoutRemote:IsA("RemoteFunction") then
		local success, snapshot = pcall(function()
			return getLoadoutRemote:InvokeServer()
		end)
		if success and typeof(snapshot) == "table" then
			pendingLoadout = snapshot
			applyWeaponLoadout(screenGui, snapshot)
		end
	end
end

task.spawn(function()
	local loadoutRemote = ReplicatedStorage:WaitForChild("Weapon_LoadoutUpdate", 30)
	if loadoutRemote and loadoutRemote:IsA("RemoteEvent") then
		loadoutRemote.OnClientEvent:Connect(function(payload)
			pendingLoadout = payload
			local productionGui = playerGui:FindFirstChild(PRODUCTION_GUI_NAME)
			if productionGui and productionGui:IsA("ScreenGui") then
				applyWeaponLoadout(productionGui, payload)
			end
		end)
	end
end)

task.spawn(function()
	local success, err = pcall(initialise)
	if not success then
		DebugLog.Warn("UI", "Initialisation loadout V2 impossible", {
			Error = tostring(err),
		})
	end
end)
