--!strict

-- Palette et finitions communes de l'interface MegaRoblox.
-- Les helpers restent opt-in afin de ne pas modifier la geometrie des interfaces existantes.

local UiTheme = {}

UiTheme.Colors = {
	Text = Color3.fromRGB(248, 250, 255),
	Muted = Color3.fromRGB(183, 190, 206),
	Shadow = Color3.fromRGB(0, 0, 0),
	Overlay = Color3.fromRGB(4, 7, 12),
	Dark = Color3.fromRGB(8, 13, 20),
	MetalDark = Color3.fromRGB(13, 22, 34),
	MetalMid = Color3.fromRGB(37, 51, 70),
	MetalTop = Color3.fromRGB(65, 88, 118),
	MetalLight = Color3.fromRGB(93, 125, 161),
	Panel = Color3.fromRGB(17, 27, 39),
	PanelTop = Color3.fromRGB(37, 51, 70),
	Card = Color3.fromRGB(20, 34, 48),
	CardHover = Color3.fromRGB(32, 48, 66),
	Track = Color3.fromRGB(7, 10, 17),
	Glass = Color3.fromRGB(232, 247, 255),
	GlassTint = Color3.fromRGB(157, 212, 255),
	GlassStroke = Color3.fromRGB(221, 240, 255),
	Health = Color3.fromRGB(69, 255, 118),
	HealthDark = Color3.fromRGB(15, 128, 58),
	Shield = Color3.fromRGB(25, 255, 218),
	ShieldDark = Color3.fromRGB(0, 104, 156),
	Arcane = Color3.fromRGB(149, 222, 255),
	Kills = Color3.fromRGB(255, 43, 57),
	Gold = Color3.fromRGB(255, 202, 48),
	Green = Color3.fromRGB(105, 245, 100),
	Xp = Color3.fromRGB(190, 86, 255),
	XpDark = Color3.fromRGB(82, 35, 210),
	Purple = Color3.fromRGB(180, 91, 255),
	PurpleLight = Color3.fromRGB(224, 171, 255),
	Accent = Color3.fromRGB(113, 232, 255),
	Progress = Color3.fromRGB(130, 255, 170),
	DamageFlash = Color3.fromRGB(255, 24, 44),
	Preview = Color3.fromRGB(221, 230, 241),
	PreviewCurrent = Color3.fromRGB(163, 177, 195),
}

UiTheme.Fonts = {
	Regular = Enum.Font.Gotham,
	Medium = Enum.Font.GothamMedium,
	Bold = Enum.Font.GothamBold,
	Heavy = Enum.Font.GothamBlack,
}

UiTheme.Icons = {
	ArcaneGem = "rbxassetid://137344039860332",
	Kills = "rbxassetid://78565181494437",
	Gold = "rbxassetid://137648994340847",
	NextChest = "rbxassetid://75386927173068",
	Timer = "rbxassetid://84807607704086",
	Pause = "rbxassetid://99288878339871",
	Play = "rbxassetid://111726051060051",
	Health = "rbxassetid://107129416801939",
	Shield = "rbxassetid://125061574107320",
}

UiTheme.Rarities = {
	Common = Color3.fromRGB(80, 220, 120),
	Rare = Color3.fromRGB(80, 155, 255),
	Epic = Color3.fromRGB(185, 95, 255),
	Legendary = Color3.fromRGB(255, 200, 75),
}

-- Les contextes conservent les nuances deja reglees ecran par ecran.
-- Ils evitent qu'une centralisation transforme subtilement la DA existante.
UiTheme.Contexts = {
	Combat = {
		Text = Color3.fromRGB(248, 250, 255),
		Muted = Color3.fromRGB(183, 190, 206),
		Shadow = Color3.fromRGB(0, 0, 0),
		Track = Color3.fromRGB(7, 10, 17),
		Health = Color3.fromRGB(69, 255, 118),
		HealthDark = Color3.fromRGB(15, 128, 58),
		Shield = Color3.fromRGB(25, 255, 218),
		ShieldDark = Color3.fromRGB(0, 104, 156),
		Arcane = Color3.fromRGB(149, 222, 255),
		Kills = Color3.fromRGB(255, 43, 57),
		Gold = Color3.fromRGB(255, 202, 48),
		Green = Color3.fromRGB(105, 245, 100),
		Xp = Color3.fromRGB(190, 86, 255),
		XpDark = Color3.fromRGB(82, 35, 210),
		DamageFlash = Color3.fromRGB(255, 24, 44),
		Glass = Color3.fromRGB(232, 247, 255),
		GlassTint = Color3.fromRGB(157, 212, 255),
		GlassStroke = Color3.fromRGB(255, 255, 255),
	},
	Perk = {
		Overlay = Color3.fromRGB(4, 7, 12),
		Panel = Color3.fromRGB(17, 27, 39),
		PanelTop = Color3.fromRGB(37, 51, 70),
		Card = Color3.fromRGB(20, 34, 48),
		CardHover = Color3.fromRGB(32, 48, 66),
		Text = Color3.fromRGB(245, 248, 255),
		Muted = Color3.fromRGB(181, 194, 211),
		Preview = Color3.fromRGB(221, 230, 241),
		PreviewCurrent = Color3.fromRGB(163, 177, 195),
		Purple = Color3.fromRGB(180, 91, 255),
		PurpleLight = Color3.fromRGB(224, 171, 255),
	},
	Chest = {
		Panel = Color3.fromRGB(17, 27, 39),
		PanelTop = Color3.fromRGB(37, 51, 70),
		Text = Color3.fromRGB(245, 248, 255),
		Muted = Color3.fromRGB(191, 202, 218),
		Accent = Color3.fromRGB(180, 91, 255),
		AccentLight = Color3.fromRGB(224, 171, 255),
	},
	Interaction = {
		Text = Color3.fromRGB(248, 250, 255),
		Muted = Color3.fromRGB(185, 199, 216),
		MetalLight = Color3.fromRGB(93, 125, 161),
		MetalDark = Color3.fromRGB(13, 22, 34),
		GlassStroke = Color3.fromRGB(221, 240, 255),
		Accent = Color3.fromRGB(113, 232, 255),
		Progress = Color3.fromRGB(130, 255, 170),
	},
	Lobby = {
		Panel = Color3.fromRGB(17, 27, 39),
		PanelTop = Color3.fromRGB(37, 51, 70),
		Card = Color3.fromRGB(20, 34, 48),
		CardHover = Color3.fromRGB(32, 48, 66),
		Text = Color3.fromRGB(244, 248, 255),
		Muted = Color3.fromRGB(180, 194, 211),
		Dark = Color3.fromRGB(8, 13, 20),
		Purple = Color3.fromRGB(180, 91, 255),
		PurpleLight = Color3.fromRGB(224, 171, 255),
	},
	Audio = {
		Text = Color3.fromRGB(248, 250, 255),
		Muted = Color3.fromRGB(184, 199, 216),
		MetalLight = Color3.fromRGB(93, 125, 161),
		MetalDark = Color3.fromRGB(13, 22, 34),
		GlassStroke = Color3.fromRGB(221, 240, 255),
		Accent = Color3.fromRGB(113, 232, 255),
		Track = Color3.fromRGB(6, 13, 22),
		Fill = Color3.fromRGB(113, 232, 255),
	},
	RunStats = {
		Panel = Color3.fromRGB(17, 27, 39),
		Header = Color3.fromRGB(37, 51, 70),
		Section = Color3.fromRGB(94, 224, 164),
		Text = Color3.fromRGB(236, 242, 250),
		Muted = Color3.fromRGB(171, 186, 204),
		Value = Color3.fromRGB(255, 231, 154),
		Stroke = Color3.fromRGB(169, 222, 255),
		Cyan = Color3.fromRGB(41, 205, 255),
		Survival = Color3.fromRGB(86, 236, 146),
		Attack = Color3.fromRGB(255, 80, 91),
		Mobility = Color3.fromRGB(43, 219, 255),
	},
	RunLauncher = {
		Panel = Color3.fromRGB(12, 20, 30),
		PanelLight = Color3.fromRGB(25, 39, 55),
		Card = Color3.fromRGB(18, 31, 45),
		CardSelected = Color3.fromRGB(31, 52, 72),
		Text = Color3.fromRGB(245, 248, 255),
		Muted = Color3.fromRGB(158, 177, 198),
		Cyan = Color3.fromRGB(76, 218, 255),
		Purple = Color3.fromRGB(181, 93, 255),
		Green = Color3.fromRGB(87, 232, 143),
		Locked = Color3.fromRGB(99, 108, 122),
		Danger = Color3.fromRGB(255, 104, 104),
	},
}

export type SurfaceFinishOptions = {
	Accent: Color3?,
	ZIndex: number?,
	Intensity: number?,
}

function UiTheme.AddCorner(instance: Instance, radius: number): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
	return corner
end

function UiTheme.AddStroke(
	instance: Instance,
	color: Color3,
	transparency: number?,
	thickness: number?
): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Transparency = transparency or 0
	stroke.Thickness = thickness or 1
	stroke.Parent = instance
	return stroke
end

function UiTheme.AddGradient(
	instance: Instance,
	firstColor: Color3,
	secondColor: Color3,
	rotation: number?
): UIGradient
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, firstColor),
		ColorSequenceKeypoint.new(1, secondColor),
	})
	gradient.Rotation = rotation or 0
	gradient.Parent = instance
	return gradient
end

-- Ajoute un relief discret sans modifier la taille ni les interactions du conteneur.
function UiTheme.AddSurfaceFinish(surface: GuiObject, options: SurfaceFinishOptions?): Frame
	local existing = surface:FindFirstChild("ThemeSurfaceFinish")

	if existing and existing:IsA("Frame") then
		return existing
	end

	local intensity = math.clamp(options and options.Intensity or 1, 0, 1)
	local accent = options and options.Accent or UiTheme.Colors.GlassTint
	local zIndex = options and options.ZIndex or surface.ZIndex

	local finish = Instance.new("Frame")
	finish.Name = "ThemeSurfaceFinish"
	finish.Size = UDim2.fromScale(1, 1)
	finish.BackgroundTransparency = 1
	finish.BorderSizePixel = 0
	finish.ClipsDescendants = true
	finish.Active = false
	finish.Selectable = false
	finish.ZIndex = zIndex
	finish.Parent = surface
	UiTheme.AddCorner(finish, 8)

	local topRim = Instance.new("Frame")
	topRim.Name = "TopMetalRim"
	topRim.Size = UDim2.new(1, -18, 0, 1)
	topRim.Position = UDim2.fromOffset(9, 2)
	topRim.BackgroundColor3 = UiTheme.Colors.GlassStroke
	topRim.BackgroundTransparency = 0.72 + ((1 - intensity) * 0.16)
	topRim.BorderSizePixel = 0
	topRim.ZIndex = zIndex
	topRim.Parent = finish
	UiTheme.AddGradient(topRim, UiTheme.Colors.GlassStroke, accent, 0)

	local reflection = Instance.new("Frame")
	reflection.Name = "GlassReflection"
	reflection.Position = UDim2.new(-0.12, 0, 0, 3)
	reflection.Size = UDim2.new(0.66, 0, 0, 16)
	reflection.Rotation = -8
	reflection.BackgroundColor3 = UiTheme.Colors.Glass
	reflection.BackgroundTransparency = 0.92 + ((1 - intensity) * 0.05)
	reflection.BorderSizePixel = 0
	reflection.ZIndex = zIndex
	reflection.Parent = finish
	UiTheme.AddGradient(reflection, UiTheme.Colors.Glass, UiTheme.Colors.GlassTint, 0)

	local lowerShade = Instance.new("Frame")
	lowerShade.Name = "LowerMetalShade"
	lowerShade.AnchorPoint = Vector2.new(0, 1)
	lowerShade.Position = UDim2.new(0, 0, 1, 0)
	lowerShade.Size = UDim2.new(1, 0, 0, 7)
	lowerShade.BackgroundColor3 = UiTheme.Colors.Shadow
	lowerShade.BackgroundTransparency = 0.9 + ((1 - intensity) * 0.06)
	lowerShade.BorderSizePixel = 0
	lowerShade.ZIndex = zIndex
	lowerShade.Parent = finish

	for index, offset in ipairs({ 0.2, 0.5, 0.8 }) do
		local glint = Instance.new("Frame")
		glint.Name = "MetalGlint" .. tostring(index)
		glint.Position = UDim2.new(offset, -1, 0, 4)
		glint.Size = UDim2.fromOffset(2, 2)
		glint.BackgroundColor3 = accent
		glint.BackgroundTransparency = 0.82 + ((1 - intensity) * 0.12)
		glint.BorderSizePixel = 0
		glint.ZIndex = zIndex
		glint.Parent = finish
		UiTheme.AddCorner(glint, 1)
	end

	return finish
end

return UiTheme
