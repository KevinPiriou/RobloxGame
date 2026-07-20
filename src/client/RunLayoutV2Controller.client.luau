--!strict

-- Le layout V2 ne sait rien des donnees de combat. Il aligne uniquement les
-- composants clones du brouillon deja alimentes par leurs adaptateurs respectifs.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local RunHudLayout = require(Shared:WaitForChild("RunHudLayout"))
local layoutScheduled = false

local function asGuiObject(instance: Instance?): GuiObject?
	if instance and instance:IsA("GuiObject") then
		return instance
	end

	return nil
end

local function normalizeBarRoots(topDock: GuiObject?, bottomDock: GuiObject?)
	if topDock then
		local topContent = asGuiObject(topDock:FindFirstChild("Content"))
		local topSurface = asGuiObject(topDock:FindFirstChild("Surface"))

		if topContent then
			topContent.AnchorPoint = Vector2.new(0.5, 0.5)
			topContent.Position = UDim2.fromScale(0.5, 0.5)
			topContent.Size = UDim2.new(1, -32, 1, -10)
		end

		if topSurface then
			topSurface.Position = UDim2.fromScale(0, 0)
			topSurface.Size = UDim2.fromScale(1, 1)
		end
	end

	if bottomDock then
		local bottomBar = asGuiObject(bottomDock:FindFirstChild("BottomBar"))

		if bottomBar then
			bottomBar.Position = UDim2.fromScale(0, 0)
			bottomBar.Size = UDim2.fromScale(1, 1)

			local bottomSurface = asGuiObject(bottomBar:FindFirstChild("Surface"))
			local bottomContent = asGuiObject(bottomBar:FindFirstChild("Content"))

			if bottomSurface then
				bottomSurface.Position = UDim2.fromScale(0, 0)
				bottomSurface.Size = UDim2.fromScale(1, 1)
			end

			if bottomContent then
				bottomContent.AnchorPoint = Vector2.new(0.5, 0.5)
				bottomContent.Position = UDim2.fromScale(0.5, 0.5)
				bottomContent.Size = UDim2.new(1, -32, 1, -14)
			end
		end
	end
end

local function configureLoadoutDock(dock: GuiObject?, slotPattern: string, loadoutHeight: number, density: number)
	if dock == nil then
		return
	end

	local content = asGuiObject(dock:FindFirstChild("Content"))
	if content == nil then
		return
	end

	local slotSize = math.clamp(math.floor((loadoutHeight * 0.88) + 0.5), 38, 60)
	local slotsLayout = content:FindFirstChild("SlotsLayout")
	if slotsLayout and slotsLayout:IsA("UIListLayout") then
		slotsLayout.Padding = UDim.new(0, math.clamp(math.floor((10 * density) + 0.5), 6, 12))
	end

	for _, child in ipairs(content:GetChildren()) do
		if child:IsA("Frame") and child.Name:match(slotPattern) then
			child.Size = UDim2.fromOffset(slotSize, slotSize)
		end
	end
end

local function applyLayout()
	local camera = Workspace.CurrentCamera
	local metrics = RunHudLayout.Compute(if camera then camera.ViewportSize else Vector2.zero)

	if metrics == nil then
		return
	end

	local combatGui = playerGui:FindFirstChild("CombatGui")
	local perkChoiceGui = playerGui:FindFirstChild("PerkChoiceV2")
	local itemRevealGui = playerGui:FindFirstChild("ItemRevealV2")
	local weaponChoiceGui = playerGui:FindFirstChild("WeaponChoiceV2")
	local loadoutGui = playerGui:FindFirstChild("RunLoadoutV2")
	local runStatsGui = playerGui:FindFirstChild("RunStatsGui")
	local utilityGui = playerGui:FindFirstChild("RunUtilityGui")
	local miniMapGui = playerGui:FindFirstChild("MiniMapGui")
	local perkOverlay = perkChoiceGui and perkChoiceGui:FindFirstChild("Overlay")
	local itemRevealOverlay = itemRevealGui and itemRevealGui:FindFirstChild("Overlay")
	local weaponChoiceCanvas = weaponChoiceGui and weaponChoiceGui:FindFirstChild("RunCanvas")

	local topDock = combatGui and asGuiObject(combatGui:FindFirstChild("TopBarV2"))
	local bottomDock = combatGui and asGuiObject(combatGui:FindFirstChild("BottomBarV2"))
	local perkDock = perkOverlay and asGuiObject(perkOverlay:FindFirstChild("PerkChoiceDockV2"))
	local itemRevealDock = itemRevealOverlay and asGuiObject(itemRevealOverlay:FindFirstChild("ItemRevealDockV2"))
	local weaponChoiceDock = weaponChoiceCanvas and asGuiObject(weaponChoiceCanvas:FindFirstChild("WeaponChoiceDock"))
	local weaponDock = loadoutGui and asGuiObject(loadoutGui:FindFirstChild("WeaponDockV2"))
	local gemDock = loadoutGui and asGuiObject(loadoutGui:FindFirstChild("GemDockV2"))
	local ultimateDock = loadoutGui and asGuiObject(loadoutGui:FindFirstChild("UltimateDockV2"))
	local statsDock = runStatsGui and asGuiObject(runStatsGui:FindFirstChild("StatsPanel"))
	local utilityDock = utilityGui and asGuiObject(utilityGui:FindFirstChild("UtilityDockV2"))
	local miniMapDock = miniMapGui and asGuiObject(miniMapGui:FindFirstChild("MiniMapPanelV2"))

	normalizeBarRoots(topDock, bottomDock)

	if topDock then
		RunHudLayout.ApplyDock(
			topDock,
			Vector2.new(0.5, 0),
			Vector2.new(metrics.Viewport.X * 0.5, metrics.MarginY),
			Vector2.new(metrics.MainWidth, metrics.TopHeight),
			Vector2.new(330, 48),
			Vector2.new(980, 80)
		)
	end

	if bottomDock then
		RunHudLayout.ApplyDock(
			bottomDock,
			Vector2.new(0.5, 1),
			Vector2.new(metrics.Viewport.X * 0.5, metrics.Viewport.Y - metrics.MarginY),
			Vector2.new(metrics.MainWidth, metrics.BottomHeight),
			Vector2.new(330, 80),
			Vector2.new(980, 140)
		)
	end

	if perkDock then
		RunHudLayout.ApplyDock(
			perkDock,
			Vector2.new(0, 0),
			Vector2.new(metrics.MainLeft, metrics.MainTop),
			Vector2.new(metrics.MainWidth, metrics.MainHeight),
			Vector2.new(330, 220),
			Vector2.new(980, 900)
		)
	end

	if itemRevealDock then
		RunHudLayout.ApplyDock(
			itemRevealDock,
			Vector2.new(0, 0),
			Vector2.new(metrics.MainLeft, metrics.MainTop),
			Vector2.new(metrics.MainWidth, metrics.MainHeight),
			Vector2.new(330, 220),
			Vector2.new(980, 900)
		)
	end

	if weaponChoiceDock then
		RunHudLayout.ApplyDock(
			weaponChoiceDock,
			Vector2.new(0, 0),
			Vector2.new(metrics.MainLeft, metrics.MainTop),
			Vector2.new(metrics.MainWidth, metrics.MainHeight),
			Vector2.new(330, 220),
			Vector2.new(980, 900)
		)
	end

	for _, loadoutDock in ipairs({weaponDock, gemDock, ultimateDock}) do
		if loadoutDock then
			RunHudLayout.ApplyDock(
				loadoutDock,
				Vector2.new(0.5, 0),
				Vector2.new(metrics.Viewport.X * 0.5, metrics.LoadoutTop),
				Vector2.new(metrics.MainWidth, metrics.LoadoutHeight),
				Vector2.new(220, 40),
				Vector2.new(980, 72)
			)
			loadoutDock.Visible = metrics.LoadoutVisible
		end
	end

	configureLoadoutDock(weaponDock, "^WeaponSlot%d%d$", metrics.LoadoutHeight, metrics.Density)
	configureLoadoutDock(gemDock, "^GemSlot%d%d$", metrics.LoadoutHeight, metrics.Density)
	configureLoadoutDock(ultimateDock, "^UltimateSlot$", metrics.LoadoutHeight, metrics.Density)

	if statsDock then
		RunHudLayout.ApplyDock(
			statsDock,
			Vector2.new(0, 0),
			Vector2.new(metrics.MarginX, metrics.MainTop),
			Vector2.new(metrics.RailWidth, metrics.MainHeight),
			Vector2.new(140, 220),
			Vector2.new(320, 960)
		)
	end

	if utilityDock then
		local utilityHeight = math.max(46, metrics.TopHeight - math.max(4, math.floor(metrics.TopHeight * 0.1)))
		local utilityTop = metrics.MarginY + ((metrics.TopHeight - utilityHeight) * 0.5)

		RunHudLayout.ApplyDock(
			utilityDock,
			Vector2.new(1, 0),
			Vector2.new(metrics.Viewport.X - metrics.MarginX, utilityTop),
			Vector2.new(metrics.RailWidth, utilityHeight),
			Vector2.new(96, 46),
			Vector2.new(320, 80)
		)
	end

	if miniMapDock then
		local miniMapSize = math.min(metrics.RailWidth, math.max(88, metrics.BottomTop - metrics.MainTop - metrics.Gap))

		RunHudLayout.ApplyDock(
			miniMapDock,
			Vector2.new(1, 0),
			Vector2.new(metrics.Viewport.X - metrics.MarginX, metrics.MainTop),
			Vector2.new(miniMapSize, miniMapSize),
			Vector2.new(88, 88),
			Vector2.new(320, 320)
		)
	end
end

local function scheduleLayout()
	if layoutScheduled then
		return
	end

	layoutScheduled = true
	task.defer(function()
		layoutScheduled = false
		applyLayout()
	end)
end

local function bindCamera(camera: Camera)
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(scheduleLayout)
	scheduleLayout()
end

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	local camera = Workspace.CurrentCamera
	if camera then
		bindCamera(camera)
	end
end)

playerGui.ChildAdded:Connect(function()
	scheduleLayout()
end)

playerGui.DescendantAdded:Connect(function(descendant)
	if
		descendant.Name == "TopBarV2"
		or descendant.Name == "BottomBarV2"
		or descendant.Name == "PerkChoiceDockV2"
		or descendant.Name == "ItemRevealDockV2"
		or descendant.Name == "WeaponChoiceDock"
		or descendant.Name == "WeaponDockV2"
		or descendant.Name == "GemDockV2"
		or descendant.Name == "UltimateDockV2"
		or descendant.Name == "StatsPanel"
		or descendant.Name == "UtilityDockV2"
		or descendant.Name == "MiniMapPanelV2"
	then
		scheduleLayout()
	end
end)

player:GetAttributeChangedSignal("IsRunActive"):Connect(scheduleLayout)

local currentCamera = Workspace.CurrentCamera
if currentCamera then
	bindCamera(currentCamera)
end

scheduleLayout()
