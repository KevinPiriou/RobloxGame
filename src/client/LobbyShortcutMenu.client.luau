--!strict

-- StarterPlayer/StarterPlayerScripts/LobbyShortcutMenu.client.lua

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

--==================================================
-- CONFIGURATION
--==================================================

type ButtonData = {
	Id: string,
	Label: string,
	PanelName: string,
	Image: string,
	Accent: Color3,
	KeyCode: Enum.KeyCode,
}

local BUTTONS: {ButtonData} = {
	{
		Id = "Shop",
		Label = "BOUTIQUE",
		PanelName = "ShopPanel",

		-- Remplace 0 par l'ID de ton icône PNG transparente.
		Image = "rbxassetid://105785484806067",

		Accent = Color3.fromRGB(255, 196, 54),
		KeyCode = Enum.KeyCode.One,
	},

	{
		Id = "Quests",
		Label = "QUETES",
		PanelName = "QuestsPanel",

		Image = "rbxassetid://103279732475381",

		Accent = Color3.fromRGB(68, 210, 255),
		KeyCode = Enum.KeyCode.Two,
	},

	{
		Id = "Unlocks",
		Label = "DEBLOCAGES",
		PanelName = "UnlocksPanel",

		Image = "rbxassetid://116965784565243",

		Accent = Color3.fromRGB(184, 90, 255),
		KeyCode = Enum.KeyCode.Three,
	},

	{
		Id = "Housing",
		Label = "REFUGE",
		PanelName = "HousingPanel",

		Image = "rbxassetid://131445292729637",

		Accent = Color3.fromRGB(76, 239, 137),
		KeyCode = Enum.KeyCode.Four,
	},
}

local BUTTON_WIDTH = 150
local BUTTON_HEIGHT = 112
local ICON_SIZE = 84
local BUTTON_SPACING = 4

local NORMAL_SCALE = 1
local HOVER_SCALE = 1.12
local SELECTED_SCALE = 1.08

-- Police proche de celle de ta DA actuelle.
local BUTTON_FONT = Font.fromEnum(Enum.Font.GothamBold)

local TWEEN_FAST = TweenInfo.new(
	0.12,
	Enum.EasingStyle.Quad,
	Enum.EasingDirection.Out
)

local TWEEN_NORMAL = TweenInfo.new(
	0.18,
	Enum.EasingStyle.Back,
	Enum.EasingDirection.Out
)

--==================================================
-- NETTOYAGE
--==================================================

local oldGui = playerGui:FindFirstChild("LobbyShortcutMenu")

if oldGui then
	oldGui:Destroy()
end

--==================================================
-- INTERFACE PRINCIPALE
--==================================================

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "LobbyShortcutMenu"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = false
screenGui.DisplayOrder = 40
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- Permet à d'autres LocalScripts d'écouter les sélections.
local menuSelectedEvent = Instance.new("BindableEvent")
menuSelectedEvent.Name = "MenuSelected"
menuSelectedEvent.Parent = screenGui

local closeRequestedEvent = Instance.new("BindableEvent")
closeRequestedEvent.Name = "CloseRequested"
closeRequestedEvent.Parent = screenGui

local container = Instance.new("Frame")
container.Name = "ShortcutContainer"
container.AnchorPoint = Vector2.new(0, 0.5)
container.Position = UDim2.new(0, 26, 0.5, 0)
container.Size = UDim2.fromOffset(
	BUTTON_WIDTH,
	(#BUTTONS * BUTTON_HEIGHT)
		+ ((#BUTTONS - 1) * BUTTON_SPACING)
)
container.BackgroundTransparency = 1
container.BorderSizePixel = 0
container.ClipsDescendants = false
container.Parent = screenGui

local responsiveScale = Instance.new("UIScale")
responsiveScale.Name = "ResponsiveScale"
responsiveScale.Scale = 1
responsiveScale.Parent = container

local listLayout = Instance.new("UIListLayout")
listLayout.FillDirection = Enum.FillDirection.Vertical
listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
listLayout.VerticalAlignment = Enum.VerticalAlignment.Center
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding = UDim.new(0, BUTTON_SPACING)
listLayout.Parent = container

--==================================================
-- TYPES ET ÉTAT
--==================================================

type ButtonReference = {
	Data: ButtonData,
	Button: ImageButton,
	Scale: UIScale,
	IconGroup: Frame,
	Icon: ImageLabel,
	Shadow: ImageLabel,
	Glow: ImageLabel,
	Label: TextLabel,
	Marker: Frame,
	Hovered: boolean,
}

local references: {[string]: ButtonReference} = {}
local keyBindings: {[Enum.KeyCode]: string} = {}

local selectedId: string? = nil
local isRunActive = player:GetAttribute("IsRunActive") == true

--==================================================
-- OUTILS
--==================================================

local function tween(
	instance: Instance,
	tweenInfo: TweenInfo,
	properties: {[string]: any}
)
	TweenService:Create(
		instance,
		tweenInfo,
		properties
	):Play()
end

local function createCorner(
	parent: Instance,
	radius: number
): UICorner

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent

	return corner
end

local function getMenusGui(): ScreenGui?
	local menus = playerGui:FindFirstChild("Menus")

	if menus and menus:IsA("ScreenGui") then
		return menus
	end

	return nil
end

local function findPanel(
	panelName: string
): GuiObject?

	local menus = getMenusGui()

	if not menus then
		return nil
	end

	local panel = menus:FindFirstChild(
		panelName,
		true
	)

	if panel and panel:IsA("GuiObject") then
		return panel
	end

	return nil
end

local function updatePanels(
	targetId: string?
)
	local menus = getMenusGui()

	if not menus then
		return
	end

	for _, data in BUTTONS do
		local panel = findPanel(data.PanelName)

		if panel then
			panel.Visible = targetId == data.Id
		end
	end
end

--==================================================
-- ÉTATS VISUELS
--==================================================

local function updateVisual(
	menuId: string
)
	local reference = references[menuId]

	if not reference then
		return
	end

	local isSelected = selectedId == menuId

	if isSelected then
		tween(
			reference.Scale,
			TWEEN_NORMAL,
			{
				Scale = SELECTED_SCALE,
			}
		)

		tween(
			reference.IconGroup,
			TWEEN_NORMAL,
			{
				Rotation = -2,
			}
		)

		tween(
			reference.Glow,
			TWEEN_FAST,
			{
				ImageTransparency = 0.42,
				Size = UDim2.fromOffset(
					ICON_SIZE + 18,
					ICON_SIZE + 18
				),
			}
		)

		tween(
			reference.Shadow,
			TWEEN_FAST,
			{
				ImageTransparency = 0.08,
			}
		)

		tween(
			reference.Label,
			TWEEN_FAST,
			{
				TextColor3 = reference.Data.Accent,
			}
		)

		tween(
			reference.Marker,
			TWEEN_FAST,
			{
				BackgroundTransparency = 0,
				Size = UDim2.fromOffset(4, 42),
			}
		)

	elseif reference.Hovered then
		tween(
			reference.Scale,
			TWEEN_NORMAL,
			{
				Scale = HOVER_SCALE,
			}
		)

		tween(
			reference.IconGroup,
			TWEEN_NORMAL,
			{
				Rotation = 3,
			}
		)

		tween(
			reference.Glow,
			TWEEN_FAST,
			{
				ImageTransparency = 0.58,
				Size = UDim2.fromOffset(
					ICON_SIZE + 12,
					ICON_SIZE + 12
				),
			}
		)

		tween(
			reference.Shadow,
			TWEEN_FAST,
			{
				ImageTransparency = 0.12,
			}
		)

		tween(
			reference.Label,
			TWEEN_FAST,
			{
				TextColor3 = Color3.fromRGB(
					255,
					255,
					255
				),
			}
		)

		tween(
			reference.Marker,
			TWEEN_FAST,
			{
				BackgroundTransparency = 0.45,
				Size = UDim2.fromOffset(3, 28),
			}
		)

	else
		tween(
			reference.Scale,
			TWEEN_FAST,
			{
				Scale = NORMAL_SCALE,
			}
		)

		tween(
			reference.IconGroup,
			TWEEN_FAST,
			{
				Rotation = 0,
			}
		)

		tween(
			reference.Glow,
			TWEEN_FAST,
			{
				ImageTransparency = 1,
				Size = UDim2.fromOffset(
					ICON_SIZE,
					ICON_SIZE
				),
			}
		)

		tween(
			reference.Shadow,
			TWEEN_FAST,
			{
				ImageTransparency = 0.2,
			}
		)

		tween(
			reference.Label,
			TWEEN_FAST,
			{
				TextColor3 = Color3.fromRGB(
					245,
					245,
					249
				),
			}
		)

		tween(
			reference.Marker,
			TWEEN_FAST,
			{
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(3, 16),
			}
		)
	end
end

local function refreshAllVisuals()
	for menuId in references do
		updateVisual(menuId)
	end
end

--==================================================
-- SÉLECTION
--==================================================

local function selectMenu(
	menuId: string
)
	if isRunActive then
		return
	end

	local reference = references[menuId]

	if not reference then
		return
	end

	if selectedId == menuId then
		selectedId = nil

		updatePanels(nil)
		refreshAllVisuals()

		menuSelectedEvent:Fire(
			"Closed",
			menuId
		)

		return
	end

	selectedId = menuId

	updatePanels(menuId)
	refreshAllVisuals()

	-- Petit effet d'appui.
	reference.Scale.Scale = 0.94

	tween(
		reference.Scale,
		TWEEN_NORMAL,
		{
			Scale = SELECTED_SCALE,
		}
	)

	menuSelectedEvent:Fire(
		"Opened",
		menuId
	)
end

--==================================================
-- CRÉATION D'UN RACCOURCI
--==================================================

local function createShortcut(
	data: ButtonData,
	layoutOrder: number
)
	-- L'ImageButton est invisible :
	-- il sert seulement de zone cliquable.
	local button = Instance.new("ImageButton")
	button.Name = data.Id .. "Button"
	button.LayoutOrder = layoutOrder
	button.Size = UDim2.fromOffset(
		BUTTON_WIDTH,
		BUTTON_HEIGHT
	)
	button.BackgroundTransparency = 1
	button.BorderSizePixel = 0
	button.Image = ""
	button.AutoButtonColor = false
	button.ClipsDescendants = false
	button.Selectable = true
	button.Parent = container

	local buttonScale = Instance.new("UIScale")
	buttonScale.Name = "HoverScale"
	buttonScale.Scale = NORMAL_SCALE
	buttonScale.Parent = button

	-- Petit marqueur latéral de la DA actuelle.
	-- Ce n'est pas un fond de bouton.
	local marker = Instance.new("Frame")
	marker.Name = "SelectionMarker"
	marker.AnchorPoint = Vector2.new(0, 0.5)
	marker.Position = UDim2.new(0, 1, 0.5, -4)
	marker.Size = UDim2.fromOffset(3, 16)
	marker.BackgroundColor3 = data.Accent
	marker.BackgroundTransparency = 1
	marker.BorderSizePixel = 0
	marker.ZIndex = 8
	marker.Parent = button

	createCorner(marker, 4)

	-- Groupe qui contient uniquement l'icône.
	local iconGroup = Instance.new("Frame")
	iconGroup.Name = "IconGroup"
	iconGroup.AnchorPoint = Vector2.new(0.5, 0)
	iconGroup.Position = UDim2.new(0.5, 0, 0, 0)
	iconGroup.Size = UDim2.fromOffset(
	ICON_SIZE + 24,
	ICON_SIZE + 12
	)
	iconGroup.BackgroundTransparency = 1
	iconGroup.BorderSizePixel = 0
	iconGroup.ClipsDescendants = false
	iconGroup.ZIndex = 2
	iconGroup.Parent = button

	-- Lueur qui reprend exactement la silhouette du PNG.
	local glow = Instance.new("ImageLabel")
	glow.Name = "Glow"
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.Size = UDim2.fromOffset(
		ICON_SIZE,
		ICON_SIZE
	)
	glow.BackgroundTransparency = 1
	glow.BorderSizePixel = 0
	glow.Image = data.Image
	glow.ImageColor3 = data.Accent
	glow.ImageTransparency = 1
	glow.ScaleType = Enum.ScaleType.Fit
	glow.ZIndex = 1
	glow.Parent = iconGroup

	-- Ombre détourée sous l'icône.
	local shadow = Instance.new("ImageLabel")
	shadow.Name = "Shadow"
	shadow.AnchorPoint = Vector2.new(0.5, 0.5)
	shadow.Position = UDim2.new(
		0.5,
		3,
		0.5,
		4
	)
	shadow.Size = UDim2.fromOffset(
		ICON_SIZE,
		ICON_SIZE
	)
	shadow.BackgroundTransparency = 1
	shadow.BorderSizePixel = 0
	shadow.Image = data.Image
	shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
	shadow.ImageTransparency = 0.2
	shadow.ScaleType = Enum.ScaleType.Fit
	shadow.ZIndex = 2
	shadow.Parent = iconGroup

	-- Icône principale.
	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.Size = UDim2.fromOffset(
		ICON_SIZE,
		ICON_SIZE
	)
	icon.BackgroundTransparency = 1
	icon.BorderSizePixel = 0
	icon.Image = data.Image
	icon.ImageColor3 = Color3.fromRGB(
		255,
		255,
		255
	)
	icon.ImageTransparency = 0
	icon.ScaleType = Enum.ScaleType.Fit
	icon.ZIndex = 3
	icon.Parent = iconGroup

	-- Nom sous l'icône.
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.new(0.5, 0, 1, 0)
	label.Size = UDim2.new(1, 0, 0, 27)
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Text = data.Label
	label.TextColor3 = Color3.fromRGB(
		245,
		245,
		249
	)
	label.TextSize = 16
	label.FontFace = BUTTON_FONT
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextWrapped = false
	label.TextTruncate = Enum.TextTruncate.None

	-- Contour noir semblable aux boutons Roblox de référence.
	label.TextStrokeColor3 = Color3.fromRGB(
		6,
		7,
		10
	)
	label.TextStrokeTransparency = 0
	label.ZIndex = 5
	label.Parent = button

	local textConstraint = Instance.new(
		"UITextSizeConstraint"
	)
	textConstraint.MinTextSize = 12
	textConstraint.MaxTextSize = 17
	textConstraint.Parent = label

	local reference: ButtonReference = {
		Data = data,
		Button = button,
		Scale = buttonScale,
		IconGroup = iconGroup,
		Icon = icon,
		Shadow = shadow,
		Glow = glow,
		Label = label,
		Marker = marker,
		Hovered = false,
	}

	references[data.Id] = reference
	keyBindings[data.KeyCode] = data.Id

	button.MouseEnter:Connect(function()
		reference.Hovered = true
		updateVisual(data.Id)
	end)

	button.MouseLeave:Connect(function()
		reference.Hovered = false
		updateVisual(data.Id)
	end)

	button.SelectionGained:Connect(function()
		reference.Hovered = true
		updateVisual(data.Id)
	end)

	button.SelectionLost:Connect(function()
		reference.Hovered = false
		updateVisual(data.Id)
	end)

	button.Activated:Connect(function()
		selectMenu(data.Id)
	end)
end

--==================================================
-- CRÉATION DES QUATRE BOUTONS
--==================================================

for index, data in BUTTONS do
	createShortcut(data, index)
end

--==================================================
-- RACCOURCIS CLAVIER 1 À 4
--==================================================

UserInputService.InputBegan:Connect(function(
	input: InputObject,
	gameProcessed: boolean
)
	if gameProcessed then
		return
	end

	if isRunActive then
		return
	end

	if UserInputService:GetFocusedTextBox() then
		return
	end

	if input.KeyCode == Enum.KeyCode.Escape and selectedId ~= nil then
		selectMenu(selectedId)
		return
	end

	local menuId = keyBindings[input.KeyCode]

	if menuId then
		selectMenu(menuId)
	end
end)

--==================================================
-- ADAPTATION À LA RÉSOLUTION
--==================================================

local cameraConnection: RBXScriptConnection? = nil

local function updateResponsiveScale()
	local camera = workspace.CurrentCamera

	if not camera then
		return
	end

	local viewport = camera.ViewportSize

	local widthRatio = viewport.X / 1280
	local heightRatio = viewport.Y / 720

	responsiveScale.Scale = math.clamp(
		math.min(widthRatio, heightRatio),
		0.48,
		1.08
	)
end

local function bindCamera()
	if cameraConnection then
		cameraConnection:Disconnect()
		cameraConnection = nil
	end

	local camera = workspace.CurrentCamera

	if not camera then
		return
	end

	updateResponsiveScale()

	cameraConnection =
		camera:GetPropertyChangedSignal(
			"ViewportSize"
		):Connect(updateResponsiveScale)
end

bindCamera()

workspace:GetPropertyChangedSignal(
	"CurrentCamera"
):Connect(bindCamera)

local function setRunActive(nextIsRunActive: boolean)
	isRunActive = nextIsRunActive
	screenGui.Enabled = not isRunActive

	if isRunActive and selectedId ~= nil then
		selectedId = nil
		updatePanels(nil)
		refreshAllVisuals()
	end
end

local function bindRunStateRemote()
	local remote = ReplicatedStorage:WaitForChild("Run_StateUpdate", 20)

	if remote == nil or not remote:IsA("RemoteEvent") then
		return
	end

	remote.OnClientEvent:Connect(function(payload)
		payload = payload or {}
		setRunActive(payload.IsRunActive == true)
	end)
end

player:GetAttributeChangedSignal("IsRunActive"):Connect(function()
	setRunActive(player:GetAttribute("IsRunActive") == true)
end)

closeRequestedEvent.Event:Connect(function()
	if selectedId ~= nil then
		selectMenu(selectedId)
	end
end)

task.spawn(bindRunStateRemote)
setRunActive(isRunActive)
refreshAllVisuals()
