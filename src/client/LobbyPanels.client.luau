--!strict

-- Cree les panneaux du lobby relies aux raccourcis lateraux.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local WeaponSkinConfig = require(Shared:WaitForChild("WeaponSkinConfig"))

local COLORS = UiTheme.Contexts.Lobby

type ContentLayout = "Grid" | "List" | "Profile"

type EntryData = {
	Title: string,
	Description: string,
	Value: string,
	Symbol: string,
	OfferId: string?,
}

type TabData = {
	Id: string,
	Label: string,
	Layout: ContentLayout,
	Entries: {EntryData},
}

type PanelData = {
	Id: string,
	Name: string,
	Title: string,
	Subtitle: string,
	Accent: Color3,
	Tabs: {TabData},
}

type WeaponSkinData = {
	Id: string,
	Name: string,
	Description: string,
	Image: string,
}

local FIREBALL = WeaponSkinConfig.Weapons.fireball
local FIREBALL_WEAPON_ICON = FIREBALL.Icon
local FIREBALL_SKINS: {WeaponSkinData} = FIREBALL.Skins

local selectedFireballSkinId = FIREBALL.DefaultSkinId or FIREBALL_SKINS[1].Id
local selectFireballSkinRemote: RemoteEvent? = nil

task.spawn(function()
	local remote = ReplicatedStorage:WaitForChild("WeaponSkin_Select", 20)

	if remote ~= nil and remote:IsA("RemoteEvent") then
		selectFireballSkinRemote = remote
	end
end)

local PANELS: {PanelData} = {
	{
		Id = "Shop",
		Name = "ShopPanel",
		Title = "BOUTIQUE",
		Subtitle = "COSMETIQUES ET OPTIONS DE RUN",
		Accent = Color3.fromRGB(255, 196, 54),
		Tabs = {
			{
				Id = "Store",
				Label = "BOUTIQUE",
				Layout = "Grid",
				Entries = {
					{
						Title = "REROLL PERK X1",
						Description = "Relance une offre de perk.",
						Value = "50 ROBUX",
						Symbol = "P",
						OfferId = "PerkRerollOne",
					},
					{
						Title = "REROLL PERK X3",
						Description = "Trois relances de perk.",
						Value = "125 ROBUX",
						Symbol = "P",
						OfferId = "PerkRerollThree",
					},
					{
						Title = "REROLL ITEM X1",
						Description = "Relance une offre d'objet.",
						Value = "50 ROBUX",
						Symbol = "I",
						OfferId = "ItemRerollOne",
					},
					{
						Title = "REROLL ITEM X3",
						Description = "Trois relances d'objet.",
						Value = "125 ROBUX",
						Symbol = "I",
						OfferId = "ItemRerollThree",
					},
				},
			},
			{
				Id = "Support",
				Label = "SOUTENIR LE STUDIO",
				Layout = "Grid",
				Entries = {
					{
						Title = "PACK FONDATEUR",
						Description = "Badge, couleur de pseudo, aura exclusive et titre de profil.",
						Value = "ENV. 99 ROBUX",
						Symbol = "F",
						OfferId = "FounderPass",
					},
				},
			},
			{
				Id = "TimeToken",
				Label = "TOKEN DE TEMPS",
				Layout = "Grid",
				Entries = {
					{
						Title = "GEMME ARCANIQUE X10",
						Description = "Convertis tes tokens de temps en gemmes arcaniques.",
						Value = "1 TOKEN",
						Symbol = "G",
					},
				},
			},
			{
				Id = "Wheel",
				Label = "ROUE DE LA CHANCE",
				Layout = "Grid",
				Entries = {
					{
						Title = "ROUE DE LA CHANCE",
						Description = "La roue et ses recompenses apparaitront ici.",
						Value = "BIENTOT",
						Symbol = "?",
					},
				},
			},
		},
	},
	{
		Id = "Quests",
		Name = "QuestsPanel",
		Title = "QUETES",
		Subtitle = "OBJECTIFS ET RECOMPENSES",
		Accent = Color3.fromRGB(68, 210, 255),
		Tabs = {
			{
				Id = "Quests",
				Label = "QUETES",
				Layout = "List",
				Entries = {
					{
						Title = "FAIRE UNE RUN",
						Description = "Termine une run.",
						Value = "0 / 1",
						Symbol = "1",
					},
					{
						Title = "GARDIEN DU CHAPITRE 1",
						Description = "Vaincs le boss de la map du chapitre 1.",
						Value = "0 / 1",
						Symbol = "B",
					},
					{
						Title = "AUTELS DE PERK",
						Description = "Active 10 autels de perk.",
						Value = "0 / 10",
						Symbol = "P",
					},
				},
			},
			{
				Id = "DailyQuests",
				Label = "QUETES JOURNALIERES",
				Layout = "List",
				Entries = {
					{
						Title = "DEFI 100 ENNEMIS",
						Description = "Elimine 100 ennemis aujourd'hui.",
						Value = "0 / 100",
						Symbol = "1",
					},
					{
						Title = "DEFI 250 ENNEMIS",
						Description = "Elimine 250 ennemis aujourd'hui.",
						Value = "0 / 250",
						Symbol = "2",
					},
					{
						Title = "DEFI 500 ENNEMIS",
						Description = "Elimine 500 ennemis aujourd'hui.",
						Value = "0 / 500",
						Symbol = "3",
					},
				},
			},
		},
	},
	{
		Id = "Unlocks",
		Name = "UnlocksPanel",
		Title = "DEBLOCAGES",
		Subtitle = "PROGRESSION DE TON COMPTE",
		Accent = Color3.fromRGB(184, 90, 255),
		Tabs = {
			{
				Id = "Characters",
				Label = "PERSONNAGES",
				Layout = "Grid",
				Entries = {
					{ Title = "PERSONNAGE 01", Description = "Personnage de depart.", Value = "DISPONIBLE", Symbol = "1" },
					{ Title = "PERSONNAGE 02", Description = "A debloquer en progressant.", Value = "VERROUILLE", Symbol = "?" },
					{ Title = "PERSONNAGE 03", Description = "A debloquer en progressant.", Value = "VERROUILLE", Symbol = "?" },
					{ Title = "PERSONNAGE 04", Description = "A debloquer en progressant.", Value = "VERROUILLE", Symbol = "?" },
				},
			},
			{
				Id = "Weapons",
				Label = "ARMES",
				Layout = "Grid",
				Entries = {
					{ Title = "FIREBALL", Description = "Arme de depart automatique.", Value = "DISPONIBLE", Symbol = "F" },
					{ Title = "ARME 02", Description = "A debloquer en progressant.", Value = "VERROUILLE", Symbol = "?" },
					{ Title = "ARME 03", Description = "A debloquer en progressant.", Value = "VERROUILLE", Symbol = "?" },
					{ Title = "ARME 04", Description = "A debloquer en progressant.", Value = "VERROUILLE", Symbol = "?" },
				},
			},
			{
				Id = "Gems",
				Label = "GEMMES",
				Layout = "Grid",
				Entries = {
					{ Title = "GEMME 01", Description = "Gemme thematique a venir.", Value = "VERROUILLE", Symbol = "?" },
					{ Title = "GEMME 02", Description = "Gemme thematique a venir.", Value = "VERROUILLE", Symbol = "?" },
					{ Title = "GEMME 03", Description = "Gemme thematique a venir.", Value = "VERROUILLE", Symbol = "?" },
					{ Title = "GEMME 04", Description = "Gemme thematique a venir.", Value = "VERROUILLE", Symbol = "?" },
				},
			},
			{
				Id = "Abilities",
				Label = "CAPACITES",
				Layout = "Grid",
				Entries = {
					{ Title = "CAPACITE 01", Description = "Capacite de personnage a venir.", Value = "VERROUILLE", Symbol = "?" },
					{ Title = "CAPACITE 02", Description = "Capacite de personnage a venir.", Value = "VERROUILLE", Symbol = "?" },
					{ Title = "CAPACITE 03", Description = "Capacite de personnage a venir.", Value = "VERROUILLE", Symbol = "?" },
					{ Title = "CAPACITE 04", Description = "Capacite de personnage a venir.", Value = "VERROUILLE", Symbol = "?" },
				},
			},
		},
	},
	{
		Id = "Housing",
		Name = "HousingPanel",
		Title = "REFUGE",
		Subtitle = "TON ESPACE ENTRE DEUX RUNS",
		Accent = Color3.fromRGB(76, 239, 137),
		Tabs = {
			{
				Id = "Achievements",
				Label = "HAUTS FAITS",
				Layout = "List",
				Entries = {
					{ Title = "FONDATEUR", Description = "Achete le pass permanent Fondateur.", Value = "VERROUILLE", Symbol = "F" },
					{ Title = "ON DEBUTE TOUS UN JOUR ..", Description = "Lance ta premiere run.", Value = "VERROUILLE", Symbol = "1" },
				},
			},
			{
				Id = "Statistics",
				Label = "STATISTIQUES",
				Layout = "Profile",
				Entries = {
					{ Title = "RUNS TERMINEES", Description = "Total cumule sur le compte.", Value = "0", Symbol = "R" },
					{ Title = "MONSTRES ELIMINES", Description = "Total cumule sur le compte.", Value = "0", Symbol = "M" },
					{ Title = "NIVEAUX VALIDES", Description = "Total cumule sur le compte.", Value = "0", Symbol = "N" },
					{ Title = "OR COLLECTE", Description = "Total cumule sur le compte.", Value = "0", Symbol = "O" },
				},
			},
			{
				Id = "Nurse",
				Label = "NOURRICE",
				Layout = "Grid",
				Entries = {
					{
						Title = "NOURRICE ARCANIQUE",
						Description = "Une activite AFK pour produire des gemmes arcaniques.",
						Value = "NIV. 0 - BIENTOT",
						Symbol = "N",
					},
				},
			},
		},
	},
}

local addCorner = UiTheme.AddCorner
local addStroke = UiTheme.AddStroke

local function createLabel(
	parent: Instance,
	name: string,
	text: string,
	font: Enum.Font,
	textSize: number,
	color: Color3
): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Font = font
	label.Text = text
	label.TextColor3 = color
	label.TextSize = textSize
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0.65
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = parent
	return label
end

local existingGui = playerGui:FindFirstChild("Menus")

if existingGui ~= nil and not existingGui:IsA("ScreenGui") then
	existingGui:Destroy()
	existingGui = nil
end

local menus: ScreenGui

if existingGui and existingGui:IsA("ScreenGui") then
	menus = existingGui
else
	menus = Instance.new("ScreenGui")
	menus.Name = "Menus"
	menus.ResetOnSpawn = false
	menus.IgnoreGuiInset = false
	menus.DisplayOrder = 39
	menus.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	menus.Parent = playerGui
end

local function setVisiblePanel(panelName: string?)
	for _, definition in PANELS do
		local panel = menus:FindFirstChild(definition.Name)

		if panel and panel:IsA("GuiObject") then
			panel.Visible = panelName == definition.Name
		end
	end
end

local function requestClose()
	local shortcutMenu = playerGui:FindFirstChild("LobbyShortcutMenu")
	local closeRequested = shortcutMenu and shortcutMenu:FindFirstChild("CloseRequested")

	if closeRequested and closeRequested:IsA("BindableEvent") then
		closeRequested:Fire()
	else
		setVisiblePanel(nil)
	end
end

local function bindCanvasSize(
	content: ScrollingFrame,
	layout: UIGridLayout | UIListLayout
)
	local function updateCanvas()
		content.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 4)
	end

	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas)
	updateCanvas()
end

local function createGridCard(
	parent: Instance,
	entry: EntryData,
	accent: Color3,
	layoutOrder: number
)
	local card = Instance.new("Frame")
	card.Name = "GridCard"
	card.LayoutOrder = layoutOrder
	card:SetAttribute("OfferId", entry.OfferId)
	card.BackgroundColor3 = COLORS.Card
	card.BackgroundTransparency = 0.22
	card.BorderSizePixel = 0
	card.ClipsDescendants = true
	card.Parent = parent
	addCorner(card, 8)
	addStroke(card, accent, 0.22, 2)
	UiTheme.AddSurfaceFinish(card, {
		Accent = accent,
		Intensity = 0.28,
	})

	local accentBar = Instance.new("Frame")
	accentBar.Name = "Accent"
	accentBar.Size = UDim2.new(1, 0, 0, 5)
	accentBar.BackgroundColor3 = accent
	accentBar.BorderSizePixel = 0
	accentBar.Parent = card
	addCorner(accentBar, 7)

	local icon = Instance.new("Frame")
	icon.Name = "PlaceholderIcon"
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.Position = UDim2.new(0.5, 0, 0, 19)
	icon.Size = UDim2.fromOffset(54, 54)
	icon.BackgroundColor3 = COLORS.Dark
	icon.BackgroundTransparency = 0.08
	icon.BorderSizePixel = 0
	icon.Parent = card
	addCorner(icon, 27)
	addStroke(icon, accent, 0.18, 2)

	local symbol = createLabel(icon, "Symbol", entry.Symbol, Enum.Font.GothamBlack, 25, accent)
	symbol.Size = UDim2.fromScale(1, 1)
	symbol.TextXAlignment = Enum.TextXAlignment.Center

	local title = createLabel(card, "Title", entry.Title, Enum.Font.GothamBold, 14, COLORS.Text)
	title.Position = UDim2.new(0, 10, 0, 82)
	title.Size = UDim2.new(1, -20, 0, 32)
	title.TextWrapped = true
	title.TextTruncate = Enum.TextTruncate.None
	title.TextXAlignment = Enum.TextXAlignment.Center

	local description = createLabel(card, "Description", entry.Description, Enum.Font.Gotham, 11, COLORS.Muted)
	description.Position = UDim2.new(0, 12, 0, 118)
	description.Size = UDim2.new(1, -24, 0, 38)
	description.TextWrapped = true
	description.TextTruncate = Enum.TextTruncate.None
	description.TextXAlignment = Enum.TextXAlignment.Center
	description.TextYAlignment = Enum.TextYAlignment.Top

	local value = Instance.new("Frame")
	value.Name = "Value"
	value.AnchorPoint = Vector2.new(0.5, 1)
	value.Position = UDim2.new(0.5, 0, 1, -12)
	value.Size = UDim2.new(1, -24, 0, 25)
	value.BackgroundColor3 = accent
	value.BackgroundTransparency = 0.75
	value.BorderSizePixel = 0
	value.Parent = card
	addCorner(value, 5)

	local valueLabel = createLabel(value, "ValueLabel", entry.Value, Enum.Font.GothamBold, 11, COLORS.Text)
	valueLabel.Size = UDim2.fromScale(1, 1)
	valueLabel.TextXAlignment = Enum.TextXAlignment.Center
end

local function createListCard(
	parent: Instance,
	entry: EntryData,
	accent: Color3,
	layoutOrder: number
)
	local card = Instance.new("Frame")
	card.Name = "ListCard"
	card.LayoutOrder = layoutOrder
	card.Size = UDim2.new(1, 0, 0, 92)
	card.BackgroundColor3 = COLORS.Card
	card.BackgroundTransparency = 0.18
	card.BorderSizePixel = 0
	card.Parent = parent
	addCorner(card, 7)
	addStroke(card, accent, 0.32, 1)
	UiTheme.AddSurfaceFinish(card, {
		Accent = accent,
		Intensity = 0.22,
	})

	local icon = Instance.new("Frame")
	icon.Name = "PlaceholderIcon"
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new(0, 16, 0.5, 0)
	icon.Size = UDim2.fromOffset(46, 46)
	icon.BackgroundColor3 = COLORS.Dark
	icon.BackgroundTransparency = 0.06
	icon.BorderSizePixel = 0
	icon.Parent = card
	addCorner(icon, 23)
	addStroke(icon, accent, 0.14, 2)

	local symbol = createLabel(icon, "Symbol", entry.Symbol, Enum.Font.GothamBlack, 20, accent)
	symbol.Size = UDim2.fromScale(1, 1)
	symbol.TextXAlignment = Enum.TextXAlignment.Center

	local title = createLabel(card, "Title", entry.Title, Enum.Font.GothamBold, 16, COLORS.Text)
	title.Position = UDim2.new(0, 76, 0, 14)
	title.Size = UDim2.new(1, -190, 0, 21)

	local description = createLabel(card, "Description", entry.Description, Enum.Font.Gotham, 12, COLORS.Muted)
	description.Position = UDim2.new(0, 76, 0, 39)
	description.Size = UDim2.new(1, -190, 0, 33)
	description.TextWrapped = true
	description.TextTruncate = Enum.TextTruncate.None
	description.TextYAlignment = Enum.TextYAlignment.Top

	local value = createLabel(card, "Value", entry.Value, Enum.Font.GothamBold, 14, accent)
	value.AnchorPoint = Vector2.new(1, 0.5)
	value.Position = UDim2.new(1, -16, 0.5, 0)
	value.Size = UDim2.fromOffset(92, 24)
	value.TextXAlignment = Enum.TextXAlignment.Right
end

local function createProfileCard(
	parent: Instance,
	entries: {EntryData},
	accent: Color3
)
	local card = Instance.new("Frame")
	card.Name = "ProfileCard"
	card.Size = UDim2.new(1, 0, 0, 260)
	card.BackgroundColor3 = COLORS.Card
	card.BackgroundTransparency = 0.16
	card.BorderSizePixel = 0
	card.Parent = parent
	addCorner(card, 8)
	addStroke(card, accent, 0.24, 2)
	UiTheme.AddSurfaceFinish(card, {
		Accent = accent,
		Intensity = 0.3,
	})

	local avatarPanel = Instance.new("Frame")
	avatarPanel.Name = "AvatarPanel"
	avatarPanel.Position = UDim2.fromOffset(14, 14)
	avatarPanel.Size = UDim2.new(0.37, -20, 1, -28)
	avatarPanel.BackgroundColor3 = COLORS.Dark
	avatarPanel.BackgroundTransparency = 0.08
	avatarPanel.BorderSizePixel = 0
	avatarPanel.Parent = card
	addCorner(avatarPanel, 7)
	addStroke(avatarPanel, accent, 0.38, 1)

	local avatar = Instance.new("ImageLabel")
	avatar.Name = "Avatar"
	avatar.AnchorPoint = Vector2.new(0.5, 0)
	avatar.Position = UDim2.new(0.5, 0, 0, 16)
	avatar.Size = UDim2.fromOffset(108, 108)
	avatar.BackgroundColor3 = COLORS.PanelTop
	avatar.BackgroundTransparency = 0.12
	avatar.BorderSizePixel = 0
	avatar.Image = ""
	avatar.ScaleType = Enum.ScaleType.Crop
	avatar.Parent = avatarPanel
	addCorner(avatar, 54)
	addStroke(avatar, accent, 0.08, 2)

	local fallback = createLabel(avatar, "Fallback", "?", Enum.Font.GothamBlack, 40, accent)
	fallback.Size = UDim2.fromScale(1, 1)
	fallback.TextXAlignment = Enum.TextXAlignment.Center

	local displayName = createLabel(avatarPanel, "DisplayName", player.DisplayName, Enum.Font.GothamBold, 16, COLORS.Text)
	displayName.Position = UDim2.new(0, 12, 0, 136)
	displayName.Size = UDim2.new(1, -24, 0, 22)
	displayName.TextXAlignment = Enum.TextXAlignment.Center

	local username = createLabel(avatarPanel, "Username", "@" .. player.Name, Enum.Font.Gotham, 12, COLORS.Muted)
	username.Position = UDim2.new(0, 12, 0, 160)
	username.Size = UDim2.new(1, -24, 0, 18)
	username.TextXAlignment = Enum.TextXAlignment.Center

	local placeholder = createLabel(avatarPanel, "Placeholder", "STATISTIQUES CUMULEES", Enum.Font.GothamBold, 10, accent)
	placeholder.AnchorPoint = Vector2.new(0.5, 1)
	placeholder.Position = UDim2.new(0.5, 0, 1, -13)
	placeholder.Size = UDim2.new(1, -20, 0, 18)
	placeholder.TextXAlignment = Enum.TextXAlignment.Center

	local statsPanel = Instance.new("Frame")
	statsPanel.Name = "StatsPanel"
	statsPanel.AnchorPoint = Vector2.new(1, 0)
	statsPanel.Position = UDim2.new(1, -14, 0, 14)
	statsPanel.Size = UDim2.new(0.63, -20, 1, -28)
	statsPanel.BackgroundTransparency = 1
	statsPanel.BorderSizePixel = 0
	statsPanel.Parent = card

	local statsLayout = Instance.new("UIListLayout")
	statsLayout.Padding = UDim.new(0, 8)
	statsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	statsLayout.Parent = statsPanel

	for index, entry in entries do
		local stat = Instance.new("Frame")
		stat.Name = "Stat"
		stat.LayoutOrder = index
		stat.Size = UDim2.new(1, 0, 0, 44)
		stat.BackgroundColor3 = COLORS.Dark
		stat.BackgroundTransparency = 0.12
		stat.BorderSizePixel = 0
		stat.Parent = statsPanel
		addCorner(stat, 5)

		local title = createLabel(stat, "Title", entry.Title, Enum.Font.GothamBold, 11, COLORS.Muted)
		title.Position = UDim2.fromOffset(12, 5)
		title.Size = UDim2.new(1, -86, 0, 16)

		local value = createLabel(stat, "Value", entry.Value, Enum.Font.GothamBlack, 17, accent)
		value.AnchorPoint = Vector2.new(1, 0.5)
		value.Position = UDim2.new(1, -12, 0.5, 0)
		value.Size = UDim2.fromOffset(58, 26)
		value.TextXAlignment = Enum.TextXAlignment.Right

		local description = createLabel(stat, "Description", entry.Description, Enum.Font.Gotham, 10, COLORS.Muted)
		description.Position = UDim2.fromOffset(12, 23)
		description.Size = UDim2.new(1, -86, 0, 14)
	end

	task.spawn(function()
		local success, image = pcall(function()
			return Players:GetUserThumbnailAsync(
				player.UserId,
				Enum.ThumbnailType.HeadShot,
				Enum.ThumbnailSize.Size420x420
			)
		end)

		if success and type(image) == "string" then
			avatar.Image = image
			fallback.Visible = false
		end
	end)
end

local function createWeaponTab(content: ScrollingFrame, accent: Color3)
	local split = Instance.new("Frame")
	split.Name = "WeaponSplit"
	split.Size = UDim2.new(1, 0, 0, 214)
	split.BackgroundTransparency = 1
	split.BorderSizePixel = 0
	split.Parent = content

	local weaponPanel = Instance.new("Frame")
	weaponPanel.Name = "WeaponsPanel"
	weaponPanel.Size = UDim2.new(0.58, -6, 1, 0)
	weaponPanel.BackgroundColor3 = COLORS.Card
	weaponPanel.BackgroundTransparency = 0.14
	weaponPanel.BorderSizePixel = 0
	weaponPanel.Parent = split
	addCorner(weaponPanel, 8)
	addStroke(weaponPanel, accent, 0.28, 2)
	UiTheme.AddSurfaceFinish(weaponPanel, {
		Accent = accent,
		Intensity = 0.4,
	})

	local weaponTitle = createLabel(weaponPanel, "Title", "ARMES", Enum.Font.GothamBlack, 14, COLORS.Text)
	weaponTitle.Position = UDim2.fromOffset(14, 12)
	weaponTitle.Size = UDim2.new(1, -28, 0, 20)

	local weaponCard = Instance.new("Frame")
	weaponCard.Name = "FireballCard"
	weaponCard.Position = UDim2.fromOffset(14, 42)
	weaponCard.Size = UDim2.new(1, -28, 1, -56)
	weaponCard.BackgroundColor3 = COLORS.Dark
	weaponCard.BackgroundTransparency = 0.18
	weaponCard.BorderSizePixel = 0
	weaponCard.Parent = weaponPanel
	addCorner(weaponCard, 7)
	addStroke(weaponCard, Color3.fromRGB(82, 218, 255), 0.24, 1)

	local weaponIcon = Instance.new("ImageLabel")
	weaponIcon.Name = "WeaponIcon"
	weaponIcon.Position = UDim2.fromOffset(16, 18)
	weaponIcon.Size = UDim2.fromOffset(76, 76)
	weaponIcon.BackgroundTransparency = 1
	weaponIcon.Image = FIREBALL_WEAPON_ICON
	weaponIcon.ScaleType = Enum.ScaleType.Fit
	weaponIcon.Parent = weaponCard

	local weaponName = createLabel(weaponCard, "Name", "FIREBALL", Enum.Font.GothamBlack, 20, COLORS.Text)
	weaponName.Position = UDim2.fromOffset(106, 24)
	weaponName.Size = UDim2.new(1, -120, 0, 26)

	local weaponDescription = createLabel(
		weaponCard,
		"Description",
		FIREBALL.Description,
		Enum.Font.Gotham,
		12,
		COLORS.Muted
	)
	weaponDescription.Position = UDim2.fromOffset(106, 53)
	weaponDescription.Size = UDim2.new(1, -122, 0, 32)
	weaponDescription.TextWrapped = true

	local weaponState = createLabel(weaponCard, "State", "EQUIPEE", Enum.Font.GothamBold, 11, Color3.fromRGB(104, 239, 145))
	weaponState.Position = UDim2.fromOffset(16, 110)
	weaponState.Size = UDim2.new(1, -32, 0, 18)

	local skinsPanel = Instance.new("Frame")
	skinsPanel.Name = "SkinsPanel"
	skinsPanel.AnchorPoint = Vector2.new(1, 0)
	skinsPanel.Position = UDim2.new(1, 0, 0, 0)
	skinsPanel.Size = UDim2.new(0.42, -6, 1, 0)
	skinsPanel.BackgroundColor3 = COLORS.Card
	skinsPanel.BackgroundTransparency = 0.14
	skinsPanel.BorderSizePixel = 0
	skinsPanel.Parent = split
	addCorner(skinsPanel, 8)
	addStroke(skinsPanel, Color3.fromRGB(180, 91, 255), 0.28, 2)
	UiTheme.AddSurfaceFinish(skinsPanel, {
		Accent = Color3.fromRGB(180, 91, 255),
		Intensity = 0.4,
	})

	local skinsTitle = createLabel(skinsPanel, "Title", "SKINS DE PROJECTILE", Enum.Font.GothamBlack, 12, COLORS.Text)
	skinsTitle.Position = UDim2.fromOffset(12, 12)
	skinsTitle.Size = UDim2.new(1, -24, 0, 18)

	local selectedLabel = createLabel(skinsPanel, "Selected", "", Enum.Font.GothamBold, 10, Color3.fromRGB(224, 171, 255))
	selectedLabel.Position = UDim2.fromOffset(12, 31)
	selectedLabel.Size = UDim2.new(1, -24, 0, 16)
	selectedLabel.TextTruncate = Enum.TextTruncate.AtEnd

	local skinsList = Instance.new("Frame")
	skinsList.Name = "SkinsList"
	skinsList.Position = UDim2.fromOffset(12, 54)
	skinsList.Size = UDim2.new(1, -24, 1, -66)
	skinsList.BackgroundTransparency = 1
	skinsList.BorderSizePixel = 0
	skinsList.Parent = skinsPanel

	local skinsLayout = Instance.new("UIListLayout")
	skinsLayout.Padding = UDim.new(0, 7)
	skinsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	skinsLayout.Parent = skinsList

	local skinButtons: {[string]: TextButton} = {}

	local function refreshSelection()
		for _, skin in ipairs(FIREBALL_SKINS) do
			local button = skinButtons[skin.Id]

			if button ~= nil then
				local isSelected = skin.Id == selectedFireballSkinId
				button.BackgroundColor3 = if isSelected then Color3.fromRGB(55, 42, 76) else COLORS.Dark
				button.BackgroundTransparency = if isSelected then 0.04 else 0.2
			end
		end

		for _, skin in ipairs(FIREBALL_SKINS) do
			if skin.Id == selectedFireballSkinId then
				selectedLabel.Text = "ACTIF : " .. string.upper(skin.Name)
				return
			end
		end
	end

	for index, skin in ipairs(FIREBALL_SKINS) do
		local button = Instance.new("TextButton")
		button.Name = skin.Id
		button.LayoutOrder = index
		button.Size = UDim2.new(1, 0, 0, 67)
		button.BackgroundColor3 = COLORS.Dark
		button.BackgroundTransparency = 0.2
		button.BorderSizePixel = 0
		button.AutoButtonColor = false
		button.Text = ""
		button.Parent = skinsList
		addCorner(button, 6)
		addStroke(button, Color3.fromRGB(180, 91, 255), 0.48, 1)

		local icon = Instance.new("ImageLabel")
		icon.Name = "Icon"
		icon.Position = UDim2.fromOffset(8, 8)
		icon.Size = UDim2.fromOffset(50, 50)
		icon.BackgroundTransparency = 1
		icon.Image = skin.Image
		icon.ScaleType = Enum.ScaleType.Fit
		icon.Parent = button

		local name = createLabel(button, "Name", string.upper(skin.Name), Enum.Font.GothamBold, 11, COLORS.Text)
		name.Position = UDim2.fromOffset(65, 10)
		name.Size = UDim2.new(1, -74, 0, 16)
		name.TextTruncate = Enum.TextTruncate.AtEnd

		local description = createLabel(button, "Description", skin.Description, Enum.Font.Gotham, 9, COLORS.Muted)
		description.Position = UDim2.fromOffset(65, 27)
		description.Size = UDim2.new(1, -74, 0, 27)
		description.TextWrapped = true
		description.TextYAlignment = Enum.TextYAlignment.Top

		button.Activated:Connect(function()
			selectedFireballSkinId = skin.Id
			refreshSelection()

			local remote = selectFireballSkinRemote

			if remote ~= nil then
				remote:FireServer(skin.Id)
			end
		end)
		skinButtons[skin.Id] = button
	end

	content.CanvasSize = UDim2.fromOffset(0, 220)
	refreshSelection()
end

local function renderTab(
	content: ScrollingFrame,
	tab: TabData,
	accent: Color3
): UIGridLayout?
	content:ClearAllChildren()
	content.CanvasPosition = Vector2.zero

	if tab.Id == "Weapons" then
		createWeaponTab(content, accent)
		return nil
	end

	if tab.Layout == "Grid" then
		local layout = Instance.new("UIGridLayout")
		layout.Name = "GridLayout"
		layout.CellPadding = UDim2.fromOffset(12, 12)
		layout.CellSize = UDim2.fromOffset(156, 156)
		layout.FillDirectionMaxCells = 3
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = content

		for index, entry in tab.Entries do
			createGridCard(content, entry, accent, index)
		end

		bindCanvasSize(content, layout)
		return layout
	elseif tab.Layout == "List" then
		local layout = Instance.new("UIListLayout")
		layout.Name = "ListLayout"
		layout.Padding = UDim.new(0, 10)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = content

		for index, entry in tab.Entries do
			createListCard(content, entry, accent, index)
		end

		bindCanvasSize(content, layout)
		return nil
	else
		createProfileCard(content, tab.Entries, accent)
		content.CanvasSize = UDim2.fromOffset(0, 264)
		return nil
	end
end

local function createPanel(definition: PanelData)
	local previousPanel = menus:FindFirstChild(definition.Name)

	if previousPanel then
		previousPanel:Destroy()
	end

	local panel = Instance.new("Frame")
	panel.Name = definition.Name
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.new(0.62, 0, 0.7, 0)
	panel.BackgroundColor3 = COLORS.Panel
	panel.BackgroundTransparency = 0.2
	panel.BorderSizePixel = 0
	panel.ClipsDescendants = false
	panel.Visible = false
	panel.Parent = menus
	addCorner(panel, 10)
	addStroke(panel, COLORS.Dark, 0.04, 5)
	addStroke(panel, definition.Accent, 0.38, 1)

	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, COLORS.PanelTop),
		ColorSequenceKeypoint.new(0.3, COLORS.Panel),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 17, 26)),
	})
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 0.34),
	})
	gradient.Parent = panel
	UiTheme.AddSurfaceFinish(panel, {
		Accent = definition.Accent,
		Intensity = 0.7,
	})

	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MinSize = Vector2.new(320, 330)
	sizeConstraint.MaxSize = Vector2.new(980, 620)
	sizeConstraint.Parent = panel

	local titleGemOuter = Instance.new("Frame")
	titleGemOuter.Name = "TitleGemOuter"
	titleGemOuter.AnchorPoint = Vector2.new(0.5, 0.5)
	titleGemOuter.Position = UDim2.new(0.5, 0, 0, 0)
	titleGemOuter.Size = UDim2.fromOffset(34, 34)
	titleGemOuter.BackgroundColor3 = COLORS.Dark
	titleGemOuter.BorderSizePixel = 0
	titleGemOuter.Rotation = 45
	titleGemOuter.ZIndex = 5
	titleGemOuter.Parent = panel
	addCorner(titleGemOuter, 5)
	addStroke(titleGemOuter, definition.Accent, 0.12, 2)

	local titleGem = Instance.new("Frame")
	titleGem.Name = "TitleGem"
	titleGem.AnchorPoint = Vector2.new(0.5, 0.5)
	titleGem.Position = UDim2.fromScale(0.5, 0.5)
	titleGem.Size = UDim2.fromOffset(18, 18)
	titleGem.BackgroundColor3 = definition.Accent
	titleGem.BorderSizePixel = 0
	titleGem.Rotation = 45
	titleGem.ZIndex = 6
	titleGem.Parent = titleGemOuter
	addCorner(titleGem, 3)

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 84)
	header.BackgroundColor3 = COLORS.PanelTop
	header.BackgroundTransparency = 0.36
	header.BorderSizePixel = 0
	header.Parent = panel
	addCorner(header, 10)

	local title = createLabel(header, "Title", definition.Title, Enum.Font.GothamBlack, 27, COLORS.Text)
	title.Position = UDim2.new(0, 26, 0, 22)
	title.Size = UDim2.new(1, -96, 0, 28)
	title.TextXAlignment = Enum.TextXAlignment.Center

	local subtitle = createLabel(header, "Subtitle", definition.Subtitle, Enum.Font.GothamBold, 11, definition.Accent)
	subtitle.Position = UDim2.new(0, 26, 0, 52)
	subtitle.Size = UDim2.new(1, -96, 0, 18)
	subtitle.TextXAlignment = Enum.TextXAlignment.Center

	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.AnchorPoint = Vector2.new(1, 0.5)
	closeButton.Position = UDim2.new(1, -18, 0.5, 0)
	closeButton.Size = UDim2.fromOffset(34, 34)
	closeButton.BackgroundColor3 = COLORS.Dark
	closeButton.BackgroundTransparency = 0.14
	closeButton.BorderSizePixel = 0
	closeButton.AutoButtonColor = true
	closeButton.Font = Enum.Font.GothamBold
	closeButton.Text = "X"
	closeButton.TextColor3 = COLORS.Text
	closeButton.TextSize = 17
	closeButton.Parent = header
	addCorner(closeButton, 5)
	addStroke(closeButton, definition.Accent, 0.42, 1)
	closeButton.Activated:Connect(requestClose)

	local divider = Instance.new("Frame")
	divider.Name = "Divider"
	divider.Position = UDim2.new(0, 22, 0, 92)
	divider.Size = UDim2.new(1, -44, 0, 1)
	divider.BackgroundColor3 = definition.Accent
	divider.BackgroundTransparency = 0.62
	divider.BorderSizePixel = 0
	divider.Parent = panel

	local tabsFrame = Instance.new("ScrollingFrame")
	tabsFrame.Name = "Tabs"
	tabsFrame.Position = UDim2.new(0, 22, 0, 105)
	tabsFrame.Size = UDim2.new(1, -44, 0, 34)
	tabsFrame.BackgroundTransparency = 1
	tabsFrame.BorderSizePixel = 0
	tabsFrame.CanvasSize = UDim2.fromOffset(0, 0)
	tabsFrame.ScrollBarThickness = 0
	tabsFrame.ScrollingDirection = Enum.ScrollingDirection.X
	tabsFrame.Parent = panel

	local tabsLayout = Instance.new("UIListLayout")
	tabsLayout.FillDirection = Enum.FillDirection.Horizontal
	tabsLayout.Padding = UDim.new(0, 8)
	tabsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabsLayout.Parent = tabsFrame

	local content = Instance.new("ScrollingFrame")
	content.Name = "Content"
	content.Position = UDim2.new(0, 22, 0, 153)
	content.Size = UDim2.new(1, -44, 1, -194)
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.CanvasSize = UDim2.fromOffset(0, 0)
	content.ScrollBarThickness = 4
	content.ScrollBarImageColor3 = definition.Accent
	content.ScrollBarImageTransparency = 0.3
	content.ScrollingDirection = Enum.ScrollingDirection.Y
	content.Parent = panel

	local footer = createLabel(panel, "Footer", "PLACEHOLDERS - CONTENU EN PREPARATION", Enum.Font.GothamBold, 10, COLORS.Muted)
	footer.AnchorPoint = Vector2.new(0.5, 1)
	footer.Position = UDim2.new(0.5, 0, 1, -10)
	footer.Size = UDim2.new(1, -44, 0, 15)
	footer.TextXAlignment = Enum.TextXAlignment.Center

	local currentTab = definition.Tabs[1]
	local tabButtons: {[string]: TextButton} = {}
	local activeGridLayout: UIGridLayout? = nil

	local function updateGridSize()
		if activeGridLayout == nil or activeGridLayout.Parent == nil then
			return
		end

		local width = content.AbsoluteSize.X

		if width <= 0 then
			return
		end

		local cellSize = math.floor(math.clamp((width - 24) / 3, 108, 196))
		activeGridLayout.CellSize = UDim2.fromOffset(cellSize, cellSize)
	end

	content:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateGridSize)

	local function refreshTabs()
		for _, tab in definition.Tabs do
			local button = tabButtons[tab.Id]

			if button then
				local isSelected = currentTab.Id == tab.Id
				button.BackgroundColor3 = if isSelected then definition.Accent else COLORS.Dark
				button.BackgroundTransparency = if isSelected then 0.72 else 0.32
				button.TextColor3 = if isSelected then COLORS.Text else COLORS.Muted
			end
		end
	end

	local function selectTab(tab: TabData)
		currentTab = tab
		activeGridLayout = renderTab(content, tab, definition.Accent)
		updateGridSize()
		refreshTabs()
	end

	for index, tab in definition.Tabs do
		local button = Instance.new("TextButton")
		button.Name = tab.Id .. "Tab"
		button.LayoutOrder = index
		button.Size = UDim2.fromOffset(math.max(112, #tab.Label * 8 + 26), 32)
		button.BackgroundColor3 = COLORS.Dark
		button.BackgroundTransparency = 0.32
		button.BorderSizePixel = 0
		button.AutoButtonColor = true
		button.Font = Enum.Font.GothamBold
		button.Text = tab.Label
		button.TextColor3 = COLORS.Muted
		button.TextSize = 11
		button.TextTruncate = Enum.TextTruncate.AtEnd
		button.Parent = tabsFrame
		addCorner(button, 5)
		addStroke(button, definition.Accent, 0.55, 1)
		button.Activated:Connect(function()
			selectTab(tab)
		end)
		tabButtons[tab.Id] = button
	end

	local function updateTabsCanvas()
		tabsFrame.CanvasSize = UDim2.fromOffset(tabsLayout.AbsoluteContentSize.X, 0)
	end

	tabsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateTabsCanvas)
	updateTabsCanvas()
	selectTab(currentTab)
end

for _, definition in PANELS do
	createPanel(definition)
end

local function bindShortcutMenu()
	local shortcutMenu = playerGui:WaitForChild("LobbyShortcutMenu", 10)

	if shortcutMenu == nil then
		return
	end

	local menuSelected = shortcutMenu:FindFirstChild("MenuSelected")

	if menuSelected == nil or not menuSelected:IsA("BindableEvent") then
		return
	end

	menuSelected.Event:Connect(function(action: string, menuId: string)
		if action == "Opened" then
			for _, definition in PANELS do
				if definition.Id == menuId then
					setVisiblePanel(definition.Name)
					return
				end
			end
		else
			setVisiblePanel(nil)
		end
	end)
end

local cameraConnection: RBXScriptConnection? = nil

local function updateResponsivePanels()
	local camera = Workspace.CurrentCamera

	if camera == nil then
		return
	end

	local viewport = camera.ViewportSize
	local isCompact = viewport.X < 900 or viewport.Y < 620

	for _, definition in PANELS do
		local panel = menus:FindFirstChild(definition.Name)

		if panel and panel:IsA("Frame") then
			if isCompact then
				panel.AnchorPoint = Vector2.new(0.5, 0.5)
				panel.Position = UDim2.fromScale(0.5, 0.5)
				panel.Size = UDim2.new(0.88, 0, 0.74, 0)
			else
				panel.AnchorPoint = Vector2.new(0.5, 0.5)
				panel.Position = UDim2.fromScale(0.5, 0.5)
				panel.Size = UDim2.new(0.62, 0, 0.7, 0)
			end
		end
	end
end

local function bindCamera()
	if cameraConnection then
		cameraConnection:Disconnect()
		cameraConnection = nil
	end

	local camera = Workspace.CurrentCamera

	if camera == nil then
		return
	end

	updateResponsivePanels()
	cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(
		updateResponsivePanels
	)
end

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)

task.spawn(bindShortcutMenu)
bindCamera()
setVisiblePanel(nil)
