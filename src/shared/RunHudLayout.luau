--!strict

-- Contrat de placement partage par les composants V2 de la HUD en production.
-- Il reprend les proportions validees sur le brouillon sans intervenir sur leur DA.
local RunHudLayout = {}

export type Metrics = {
	Viewport: Vector2,
	Density: number,
	MarginX: number,
	MarginY: number,
	Gap: number,
	TopHeight: number,
	BottomHeight: number,
	MainLeft: number,
	MainTop: number,
	MainWidth: number,
	MainHeight: number,
	MainBottom: number,
	RailWidth: number,
	BottomTop: number,
	LoadoutTop: number,
	LoadoutHeight: number,
	LoadoutVisible: boolean,
	ToastHeight: number,
}

local function round(value: number): number
	return math.floor(value + 0.5)
end

local function clamp(value: number, minimum: number, maximum: number): number
	return math.max(minimum, math.min(maximum, value))
end

function RunHudLayout.Compute(viewport: Vector2): Metrics?
	if viewport.X < 2 or viewport.Y < 2 then
		return nil
	end

	local density = clamp(math.min(viewport.X / 1920, viewport.Y / 1080), 0.55, 1.2)
	local marginX = clamp(round(viewport.X * 0.018), 16, 38)
	local marginY = clamp(round(viewport.Y * 0.014), 12, 28)
	local gap = clamp(round(16 * density), 10, 20)
	local topHeight = clamp(round(64 * density), 50, 72)
	local bottomHeight = clamp(round(110 * density), 84, 132)
	local usableWidth = viewport.X - (marginX * 2)

	local mainWidth = clamp(round(viewport.X * 0.53), 420, 980)
	local railWidth = clamp(round(viewport.X * 0.164), 180, 320)
	local minimumMainWidth = clamp(round(420 * density), 330, 420)
	local minimumRailWidth = clamp(round(180 * density), 140, 180)
	local requestedWidth = mainWidth + (railWidth * 2) + (gap * 2)

	if requestedWidth > usableWidth then
		mainWidth = math.max(minimumMainWidth, usableWidth - (railWidth * 2) - (gap * 2))
	end

	requestedWidth = mainWidth + (railWidth * 2) + (gap * 2)
	if requestedWidth > usableWidth then
		railWidth = math.max(minimumRailWidth, math.floor((usableWidth - mainWidth - (gap * 2)) / 2))
	end

	mainWidth = math.max(minimumMainWidth, math.min(mainWidth, usableWidth - (railWidth * 2) - (gap * 2)))

	local topBottom = marginY + topHeight
	local bottomTop = viewport.Y - marginY - bottomHeight
	local availableMiddleHeight = math.max(0, bottomTop - topBottom)
	-- Le panneau central remonte, mais conserve sa hauteur validee. L'espace
	-- libere sous lui appartient exclusivement au rail de loadout.
	local legacyContentTopGap = clamp(round(84 * density), 56, 108)
	local contentTopGap = clamp(round(48 * density), 34, 62)
	local contentBottomGap = clamp(round(42 * density), 28, 54)
	local mainTop = topBottom + contentTopGap
	local mainHeight = math.min(900, math.max(0, availableMiddleHeight - legacyContentTopGap - contentBottomGap))
	local mainBottom = mainTop + mainHeight
	local loadoutGap = clamp(round(8 * density), 5, 10)
	local loadoutAvailableHeight = math.max(0, bottomTop - mainBottom - (loadoutGap * 2))
	local loadoutHeight = math.min(clamp(round(62 * density), 44, 72), loadoutAvailableHeight)
	local loadoutTop = mainBottom + loadoutGap
	local loadoutVisible = loadoutHeight >= 40

	return {
		Viewport = viewport,
		Density = density,
		MarginX = marginX,
		MarginY = marginY,
		Gap = gap,
		TopHeight = topHeight,
		BottomHeight = bottomHeight,
		MainLeft = (viewport.X - mainWidth) * 0.5,
		MainTop = mainTop,
		MainWidth = mainWidth,
		MainHeight = mainHeight,
		MainBottom = mainBottom,
		RailWidth = railWidth,
		BottomTop = bottomTop,
		LoadoutTop = loadoutTop,
		LoadoutHeight = loadoutHeight,
		LoadoutVisible = loadoutVisible,
		ToastHeight = clamp(round(250 * density), 150, 340),
	}
end

function RunHudLayout.ApplyDock(
	dock: GuiObject,
	anchorPoint: Vector2,
	position: Vector2,
	size: Vector2,
	minimum: Vector2,
	maximum: Vector2
)
	dock.AnchorPoint = anchorPoint
	dock.Position = UDim2.fromOffset(round(position.X), round(position.Y))
	dock.Size = UDim2.fromOffset(round(size.X), round(size.Y))

	local constraint = dock:FindFirstChildOfClass("UISizeConstraint")
	if constraint and constraint:IsA("UISizeConstraint") then
		constraint.MinSize = minimum
		constraint.MaxSize = maximum
	end
end

return RunHudLayout
