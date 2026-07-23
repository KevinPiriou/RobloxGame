--!strict

-- Facade de lancement de run : elle reutilise les composants valides du kit
-- visuel et conserve le cycle serveur autoritaire deja en production.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local I18nClient = require(script.Parent:WaitForChild("I18nClient"))
local CharacterSkinConfig = require(Shared:WaitForChild("CharacterSkinConfig"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local WeaponSkinConfig = require(Shared:WaitForChild("WeaponSkinConfig"))

local getChapterState = ReplicatedStorage:WaitForChild("Chapter_GetState") :: RemoteFunction
local startRunRequest = ReplicatedStorage:WaitForChild("Run_StartRequest") :: RemoteFunction
local getRoster = ReplicatedStorage:WaitForChild("Character_GetRoster") :: RemoteFunction
local selectCharacter = ReplicatedStorage:WaitForChild("Character_Select") :: RemoteEvent
local characterUpdate = ReplicatedStorage:WaitForChild("Character_Update") :: RemoteEvent
local selectCharacterSkin = ReplicatedStorage:WaitForChild("CharacterSkin_Select") :: RemoteEvent
local selectWeaponSkin = ReplicatedStorage:WaitForChild("WeaponSkin_Select") :: RemoteEvent

type ChapterPayload = {
	Id: number,
	DisplayName: string,
	DisplayNameKey: string?,
	MapId: string,
	IsUnlocked: boolean,
	IsCompleted: boolean,
	IsSelected: boolean,
}

type CharacterPayload = {
	Id: string,
	Name: string,
	NameKey: string?,
	Description: string,
	DescriptionKey: string?,
	Portrait: string,
	PrimaryWeaponId: string,
	Passive: {[string]: unknown},
	Unlocked: boolean,
	PrimaryWeaponUnlocked: boolean,
	AvailableForRun: boolean,
	Reason: string,
	Selected: boolean,
}

type RosterPayload = {
	SelectedCharacterId: string?,
	Characters: {CharacterPayload},
}

local oldGui = playerGui:FindFirstChild("RunLauncher")
if oldGui ~= nil then
	oldGui:Destroy()
end

local function findDescendant(parent: Instance, name: string, className: string?): Instance?
	local instance = parent:FindFirstChild(name, true)
	if instance == nil then
		return nil
	end

	if className ~= nil and instance.ClassName ~= className then
		return nil
	end

	return instance
end

local function getChild(parent: Instance, name: string, className: string?): Instance
	local instance = parent:WaitForChild(name)
	if className ~= nil then
		assert(instance.ClassName == className, name .. " doit etre un " .. className)
	end
	return instance
end

local function setLabel(parent: Instance, name: string, text: string)
	local label = findDescendant(parent, name, "TextLabel") :: TextLabel?
	if label ~= nil then
		label.Text = text
	end
end

local function localized(key: unknown, fallback: string, parameters: {[string]: unknown}?): string
	if type(key) == "string" and key ~= "" then
		return I18nClient.T(key, parameters)
	end
	return fallback
end

local function setImage(parent: Instance, name: string, image: string)
	local imageLabel = findDescendant(parent, name, "ImageLabel") :: ImageLabel?
	if imageLabel ~= nil and image ~= "" then
		imageLabel.Image = image
	end
end

local function setVisible(parent: Instance, name: string, visible: boolean)
	local object = parent:FindFirstChild(name, true)
	if object ~= nil and object:IsA("GuiObject") then
		object.Visible = visible
	end
end

local function setStroke(parent: Instance, name: string, color: Color3, transparency: number)
	local stroke = findDescendant(parent, name, "UIStroke") :: UIStroke?
	if stroke ~= nil then
		stroke.Color = color
		stroke.Transparency = transparency
	end
end

local rarityColors: {[string]: Color3}

local function getChoiceButtons(container: Frame): {ImageButton}
	local buttons = {}
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("ImageButton") then
			table.insert(buttons, child)
		end
	end
	table.sort(buttons, function(left, right)
		if left.LayoutOrder == right.LayoutOrder then
			return left.Name < right.Name
		end
		return left.LayoutOrder < right.LayoutOrder
	end)
	return buttons
end

local function setChoicePresentation(button: ImageButton, skin, selected: boolean, available: boolean)
	button.Active = available
	button.AutoButtonColor = available
	button.ImageTransparency = if available then 0 else 0.62
	setVisible(button, "Placeholder", skin == nil)
	setVisible(button, "Icon", skin ~= nil)
	if skin ~= nil then
		setImage(button, "Icon", tostring(skin.Image or ""))
		setLabel(button, "Caption", string.upper(tostring(skin.Name or "")))
	else
		setLabel(button, "Caption", I18nClient.T("ui.coming_soon"))
	end
	setStroke(button, "Outline", if selected then rarityColors.Active elseif available then rarityColors.Available else rarityColors.Locked, if selected then 0.08 elseif available then 0.48 else 0.68)
end

local COLORS = UiTheme.Contexts.RunLauncher

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "RunLauncher"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 45
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local openButton = Instance.new("TextButton")
openButton.Name = "OpenRunLauncher"
openButton.AnchorPoint = Vector2.new(0.5, 1)
openButton.Position = UDim2.new(0.5, 0, 1, -28)
openButton.Size = UDim2.fromOffset(230, 48)
openButton.BackgroundColor3 = COLORS.Panel
openButton.BackgroundTransparency = 0.16
openButton.BorderSizePixel = 0
openButton.AutoButtonColor = true
openButton.Font = Enum.Font.GothamBold
openButton.Text = I18nClient.T("ui.run.launch")
openButton.TextColor3 = COLORS.Text
openButton.TextSize = 16
openButton.Parent = screenGui
UiTheme.AddCorner(openButton, 7)
UiTheme.AddStroke(openButton, COLORS.Cyan, 0.16, 2)
UiTheme.AddSurfaceFinish(openButton, {
	Accent = COLORS.Cyan,
	Intensity = 0.44,
})

local overlay = Instance.new("Frame")
overlay.Name = "Overlay"
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = Color3.new(0, 0, 0)
overlay.BackgroundTransparency = 0.52
overlay.BorderSizePixel = 0
overlay.Visible = false
overlay.Parent = screenGui

local kitGui = StarterGui:WaitForChild("MegaRobloxUIV_RunLayoutDraft")
local kitCanvas = kitGui:WaitForChild("RunCanvas")
local runLaunchDock = kitCanvas:WaitForChild("RunLaunchDock"):Clone() :: Frame
local mapSelectionDock = kitCanvas:WaitForChild("MapSelectionDock"):Clone() :: Frame

runLaunchDock.Name = "RunLaunchDock"
runLaunchDock.ZIndex = 2
runLaunchDock.Visible = false
runLaunchDock.Parent = overlay

mapSelectionDock.Name = "MapSelectionDock"
mapSelectionDock.ZIndex = 2
mapSelectionDock.Visible = false
mapSelectionDock.Parent = overlay

local runLaunchPanel = getChild(runLaunchDock, "RunLaunchPanel", "Frame") :: Frame
local runLaunchContent = getChild(runLaunchPanel, "Content", "Frame") :: Frame
local runLaunchMain = getChild(runLaunchContent, "Main", "Frame") :: Frame
local characterRoster = getChild(runLaunchMain, "CharacterRoster", "Frame") :: Frame
local characterSlots = getChild(characterRoster, "CharacterSlots", "Frame") :: Frame
local selectedCharacterInfo = getChild(characterRoster, "SelectedCharacterInfo", "Frame") :: Frame
local previewAndSkins = getChild(runLaunchMain, "PreviewAndSkins", "Frame") :: Frame
local characterPreview = getChild(previewAndSkins, "CharacterPreview", "Frame") :: Frame
local skinSelectors = getChild(previewAndSkins, "SkinSelectors", "Frame") :: Frame
local runLaunchActionRow = getChild(runLaunchContent, "ActionRow", "Frame") :: Frame
local runLaunchButton = getChild(runLaunchActionRow, "LaunchRun", "TextButton") :: TextButton

local mapSelectionPanel = getChild(mapSelectionDock, "MapSelectionPanel", "Frame") :: Frame
local mapSelectionContent = getChild(mapSelectionPanel, "Content", "Frame") :: Frame
local mapSelectionMain = getChild(mapSelectionContent, "Main", "Frame") :: Frame
local levelRail = getChild(mapSelectionMain, "LevelRail", "Frame") :: Frame
local levelList = getChild(levelRail, "LevelList", "Frame") :: Frame
local mapAndChapters = getChild(mapSelectionMain, "MapAndChapters", "Frame") :: Frame
local mapPreview = getChild(mapAndChapters, "MapPreview", "Frame") :: Frame
local chapterList = getChild(mapAndChapters, "ChapterList", "Frame") :: Frame
local mapLaunchActionRow = getChild(mapSelectionContent, "ActionRow", "Frame") :: Frame
local mapLaunchButton = getChild(mapLaunchActionRow, "LaunchRun", "TextButton") :: TextButton

local runLaunchHeader = getChild(runLaunchContent, "Header", "Frame") :: Frame
local mapSelectionHeader = getChild(mapSelectionContent, "Header", "Frame") :: Frame

local function createCloseButton(parent: Frame)
	local button = Instance.new("TextButton")
	button.Name = "Close"
	button.AnchorPoint = Vector2.new(1, 0)
	button.Position = UDim2.new(1, -18, 0, 18)
	button.Size = UDim2.fromOffset(32, 32)
	button.BackgroundColor3 = COLORS.Panel
	button.BackgroundTransparency = 0.12
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Font = Enum.Font.MontserratBold
	button.Text = "X"
	button.TextColor3 = COLORS.Text
	button.TextSize = 16
	button.ZIndex = 20
	button.Parent = parent
	UiTheme.AddCorner(button, 6)
	UiTheme.AddStroke(button, COLORS.Cyan, 0.2, 1)
	return button
end

local runLaunchCloseButton = createCloseButton(runLaunchPanel)
local mapSelectionCloseButton = createCloseButton(mapSelectionPanel)

local selectedCharacterId: string? = nil
local selectedChapterId: number? = nil
local characterEntriesById: {[string]: CharacterPayload} = {}
local chapterEntriesById: {[number]: ChapterPayload} = {}
local isBusy = false
local wasRunActive = player:GetAttribute("IsRunActive") == true
local activeScreen = "Characters"
local viewportConnection: RBXScriptConnection? = nil

rarityColors = {
	Active = Color3.fromRGB(0, 170, 255),
	Available = Color3.fromRGB(170, 0, 127),
	Locked = Color3.fromRGB(96, 99, 118),
	Confirm = Color3.fromRGB(66, 219, 107),
	Danger = Color3.fromRGB(248, 60, 76),
}

local function updateCentralLayout()
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end

	local viewport = camera.ViewportSize
	if viewport.X < 2 or viewport.Y < 2 then
		return
	end

	local density = math.clamp(math.min(viewport.X / 1920, viewport.Y / 1080), 0.55, 1.2)
	local marginX = math.clamp(math.floor(viewport.X * 0.018 + 0.5), 16, 38)
	local marginY = math.clamp(math.floor(viewport.Y * 0.014 + 0.5), 12, 28)
	local gap = math.clamp(math.floor(16 * density + 0.5), 10, 20)
	local topHeight = math.clamp(math.floor(64 * density + 0.5), 50, 72)
	local bottomHeight = math.clamp(math.floor(110 * density + 0.5), 84, 132)
	local usableWidth = viewport.X - (marginX * 2)
	local mainWidth = math.clamp(math.floor(viewport.X * 0.53 + 0.5), 420, 980)
	local railWidth = math.clamp(math.floor(viewport.X * 0.164 + 0.5), 180, 320)
	local minimumMainWidth = math.clamp(math.floor(420 * density + 0.5), 330, 420)
	local minimumRailWidth = math.clamp(math.floor(180 * density + 0.5), 140, 180)
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
	local legacyContentTopGap = math.clamp(math.floor(84 * density + 0.5), 56, 108)
	local contentTopGap = math.clamp(math.floor(48 * density + 0.5), 34, 62)
	local contentBottomGap = math.clamp(math.floor(42 * density + 0.5), 28, 54)
	local mainTop = topBottom + contentTopGap
	local mainHeight = math.min(900, math.max(220, availableMiddleHeight - legacyContentTopGap - contentBottomGap))
	local centerLeft = (viewport.X - mainWidth) * 0.5

	for _, dock in ipairs({ runLaunchDock, mapSelectionDock }) do
		dock.AnchorPoint = Vector2.zero
		dock.Position = UDim2.fromOffset(math.floor(centerLeft + 0.5), math.floor(mainTop + 0.5))
		dock.Size = UDim2.fromOffset(math.floor(mainWidth + 0.5), math.floor(mainHeight + 0.5))
	end
end

local function bindCamera()
	if viewportConnection ~= nil then
		viewportConnection:Disconnect()
		viewportConnection = nil
	end

	local camera = Workspace.CurrentCamera
	if camera ~= nil then
		viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateCentralLayout)
	end

	updateCentralLayout()
end

local function setActionState(button: TextButton, enabled: boolean, text: string)
	button.Active = enabled
	button.AutoButtonColor = enabled
	button.BackgroundTransparency = if enabled then 0 else 0.48
	setLabel(button, "Text", text)
end

local function refreshCharacterCards()
	for _, child in ipairs(characterSlots:GetChildren()) do
		if child:IsA("ImageButton") then
			local entry = characterEntriesById[string.lower(child.Name)]
			local available = entry ~= nil and entry.AvailableForRun
			local selected = entry ~= nil and entry.Id == selectedCharacterId

			child.Active = available
			child.AutoButtonColor = available
			child.ImageTransparency = if available then 0 else 0.42
			setVisible(child, "Lock", not available)
			setStroke(child, "SelectionStroke", if selected then rarityColors.Active elseif available then rarityColors.Available else rarityColors.Locked, if selected then 0.02 elseif available then 0.38 else 0.62)

			if entry ~= nil then
				setImage(child, "Portrait", entry.Portrait)
				setLabel(child, "Caption", string.upper(entry.Name))
			elseif child.Name:match("^Future") then
				setLabel(child, "Caption", I18nClient.T("ui.coming_soon"))
			end
		end
	end

	local selectedEntry = selectedCharacterId and characterEntriesById[selectedCharacterId] or nil
	if selectedEntry ~= nil then
		setLabel(selectedCharacterInfo, "Name", string.upper(selectedEntry.Name))
		setLabel(selectedCharacterInfo, "Role", string.upper(selectedEntry.PrimaryWeaponId))
		setLabel(selectedCharacterInfo, "PassiveLabel", I18nClient.T("ui.character.passive"))
		local passive = selectedEntry.Passive
		setLabel(selectedCharacterInfo, "Passive", localized(passive.NameKey, tostring(passive.Name or selectedEntry.Description)))
		setLabel(characterPreview, "Label", string.upper(selectedEntry.Name))
		setLabel(characterPreview, "State", I18nClient.T("ui.character.preview"))
	end

	local canProceed = selectedEntry ~= nil and selectedEntry.AvailableForRun and not isBusy
	setActionState(runLaunchButton, canProceed, if isBusy then I18nClient.T("ui.run.loading") else I18nClient.T("ui.run.choose_level"))
end

local function refreshSkinChoices()
	local characterSkin = getChild(skinSelectors, "CharacterSkin", "Frame") :: Frame
	local weaponSkinPanel = getChild(skinSelectors, "WeaponSkin", "Frame") :: Frame
	local characterChoices = getChild(characterSkin, "Choices", "Frame") :: Frame
	local weaponChoices = getChild(weaponSkinPanel, "Choices", "Frame") :: Frame
	local characterId = selectedCharacterId or tostring(player:GetAttribute("SelectedCharacterId") or "")
	local characterEntry = CharacterSkinConfig.Characters[characterId]
	local weaponId = tostring(player:GetAttribute("SelectedPrimaryWeaponId") or "")
	local weaponEntry = WeaponSkinConfig.Weapons[weaponId]
	local selectedCharacterSkinId = player:GetAttribute("SelectedCharacterSkinId")
	local selectedWeaponSkinId = player:GetAttribute("SelectedWeaponSkinId")

	for index, button in ipairs(getChoiceButtons(characterChoices)) do
		local skin = characterEntry and characterEntry.Skins[index] or nil
		setChoicePresentation(button, skin, skin ~= nil and skin.Id == selectedCharacterSkinId, skin ~= nil)
	end

	for index, button in ipairs(getChoiceButtons(weaponChoices)) do
		local skin = weaponEntry and weaponEntry.Skins[index] or nil
		setChoicePresentation(button, skin, skin ~= nil and skin.Id == selectedWeaponSkinId, skin ~= nil)
	end
end

local function refreshChapterCards()
	for _, child in ipairs(chapterList:GetChildren()) do
		if child:IsA("TextButton") then
			local chapterId = tonumber(child.Name:match("(%d+)$"))
			local entry = chapterId and chapterEntriesById[chapterId] or nil
			local available = entry ~= nil and entry.IsUnlocked
			local selected = entry ~= nil and entry.Id == selectedChapterId

			child.Active = available
			child.AutoButtonColor = available
			setLabel(child, "Chapter", if entry ~= nil then string.upper(localized(entry.DisplayNameKey, entry.DisplayName)) else I18nClient.T("ui.coming_soon"))
			setLabel(child, "Detail", if entry == nil then I18nClient.T("ui.coming_soon") elseif not available then I18nClient.T("ui.chapter.locked") elseif entry.IsCompleted then I18nClient.T("ui.chapter.completed") else I18nClient.T("ui.chapter.available"))
			setStroke(child, "Outline", if selected then rarityColors.Active elseif available then rarityColors.Available else rarityColors.Locked, if selected then 0.04 elseif available then 0.42 else 0.68)
		end
	end

	for _, child in ipairs(levelList:GetChildren()) do
		if child:IsA("TextButton") then
			local levelId = tonumber(child.Name:match("(%d+)$"))
			local isCurrentLevel = levelId == 1
			child.Active = isCurrentLevel
			child.AutoButtonColor = isCurrentLevel
			setStroke(child, "Outline", if isCurrentLevel then rarityColors.Active else rarityColors.Locked, if isCurrentLevel then 0.08 else 0.68)
			if isCurrentLevel then
				setLabel(child, "Number", "01")
				setLabel(child, "Name", I18nClient.T("ui.level.one"))
				setLabel(child, "Subtitle", I18nClient.T("ui.map.test"))
			else
				setLabel(child, "Subtitle", I18nClient.T("ui.coming_soon"))
			end
		end
	end

	local selectedEntry = selectedChapterId and chapterEntriesById[selectedChapterId] or nil
	if selectedEntry ~= nil then
		setLabel(mapPreview, "Label", I18nClient.T("ui.level.one"))
		setLabel(mapPreview, "SelectedChapter", string.upper(localized(selectedEntry.DisplayNameKey, selectedEntry.DisplayName)))
		setLabel(mapSelectionHeader, "Subtitle", I18nClient.T("ui.map.test") .. " - " .. localized(selectedEntry.DisplayNameKey, selectedEntry.DisplayName))
	end

	local canLaunch = selectedEntry ~= nil and selectedEntry.IsUnlocked and not isBusy
	setActionState(mapLaunchButton, canLaunch, if isBusy then I18nClient.T("ui.run.generating") else I18nClient.T("ui.run.start"))
end

local function chooseFirstAvailableCharacter()
	if selectedCharacterId ~= nil and characterEntriesById[selectedCharacterId] and characterEntriesById[selectedCharacterId].AvailableForRun then
		return
	end

	for _, entry in pairs(characterEntriesById) do
		if entry.AvailableForRun then
			selectedCharacterId = entry.Id
			return
		end
	end
end

local function applyRoster(payload: unknown)
	if typeof(payload) ~= "table" or typeof(payload.Characters) ~= "table" then
		return
	end

	table.clear(characterEntriesById)
	for _, rawEntry in ipairs(payload.Characters) do
		if typeof(rawEntry) == "table" and typeof(rawEntry.Id) == "string" then
			characterEntriesById[rawEntry.Id] = rawEntry :: CharacterPayload
		end
	end

	local serverSelected = payload.SelectedCharacterId
	if typeof(serverSelected) == "string" and characterEntriesById[serverSelected] ~= nil then
		selectedCharacterId = serverSelected
	end

	chooseFirstAvailableCharacter()
	refreshCharacterCards()
	refreshSkinChoices()
end

local function loadRoster()
	local success, payload = pcall(function()
		return getRoster:InvokeServer()
	end)
	if success then
		applyRoster(payload)
		return
	end

	setLabel(runLaunchHeader, "Subtitle", I18nClient.T("ui.run.characters_unavailable"))
end

local function chooseFirstUnlockedChapter()
	if selectedChapterId ~= nil and chapterEntriesById[selectedChapterId] and chapterEntriesById[selectedChapterId].IsUnlocked then
		return
	end

	for chapterId = 1, 3 do
		local entry = chapterEntriesById[chapterId]
		if entry ~= nil and entry.IsUnlocked then
			selectedChapterId = entry.Id
			return
		end
	end
end

local function loadChapters()
	local success, payload = pcall(function()
		return getChapterState:InvokeServer()
	end)

	if not success or typeof(payload) ~= "table" then
		setLabel(mapSelectionHeader, "Subtitle", I18nClient.T("ui.run.progression_unavailable"))
		return
	end

	table.clear(chapterEntriesById)
	for _, rawEntry in ipairs(payload) do
		if typeof(rawEntry) == "table" and typeof(rawEntry.Id) == "number" then
			chapterEntriesById[rawEntry.Id] = rawEntry :: ChapterPayload
			if rawEntry.IsSelected == true and rawEntry.IsUnlocked == true then
				selectedChapterId = rawEntry.Id
			end
		end
	end

	chooseFirstUnlockedChapter()
	refreshChapterCards()
end

local function setActiveScreen(screen: string)
	activeScreen = screen
	runLaunchDock.Visible = screen == "Characters"
	mapSelectionDock.Visible = screen == "Map"

	if screen == "Characters" then
		loadRoster()
	elseif screen == "Map" then
		loadChapters()
	end
end

local function closeOverlay()
	if isBusy then
		return
	end
	overlay.Visible = false
	setActiveScreen("Characters")
end

local function openOverlay()
	if player:GetAttribute("IsRunActive") == true then
		return
	end

	overlay.Visible = true
	setActiveScreen("Characters")
end

for _, child in ipairs(characterSlots:GetChildren()) do
	if child:IsA("ImageButton") then
		child.Activated:Connect(function()
			local characterId = string.lower(child.Name)
			local entry = characterEntriesById[characterId]
			if isBusy or entry == nil or not entry.AvailableForRun then
				return
			end

			selectedCharacterId = entry.Id
			selectCharacter:FireServer(entry.Id)
			refreshCharacterCards()
			refreshSkinChoices()
		end)
	end
end

for _, child in ipairs(chapterList:GetChildren()) do
	if child:IsA("TextButton") then
		child.Activated:Connect(function()
			local chapterId = tonumber(child.Name:match("(%d+)$"))
			local entry = chapterId and chapterEntriesById[chapterId] or nil
			if isBusy or entry == nil or not entry.IsUnlocked then
				return
			end

			selectedChapterId = entry.Id
			refreshChapterCards()
		end)
	end
end

local characterSkinPanel = getChild(skinSelectors, "CharacterSkin", "Frame") :: Frame
local characterChoices = getChild(characterSkinPanel, "Choices", "Frame") :: Frame
for index, button in ipairs(getChoiceButtons(characterChoices)) do
	button.Activated:Connect(function()
		local characterEntry = CharacterSkinConfig.Characters[selectedCharacterId or ""]
		local skin = characterEntry and characterEntry.Skins[index] or nil
		if skin ~= nil then
			selectCharacterSkin:FireServer(skin.Id)
		end
	end)
end

local weaponSkinPanel = getChild(skinSelectors, "WeaponSkin", "Frame") :: Frame
local weaponChoices = getChild(weaponSkinPanel, "Choices", "Frame") :: Frame
for index, button in ipairs(getChoiceButtons(weaponChoices)) do
	button.Activated:Connect(function()
		local weaponId = tostring(player:GetAttribute("SelectedPrimaryWeaponId") or "")
		local weaponEntry = WeaponSkinConfig.Weapons[weaponId]
		local skin = weaponEntry and weaponEntry.Skins[index] or nil
		if skin ~= nil then
			selectWeaponSkin:FireServer(skin.Id)
		end
	end)
end

runLaunchButton.Activated:Connect(function()
	local entry = selectedCharacterId and characterEntriesById[selectedCharacterId] or nil
	if isBusy or entry == nil or not entry.AvailableForRun then
		return
	end

	selectCharacter:FireServer(entry.Id)
	setActiveScreen("Map")
end)

mapLaunchButton.Activated:Connect(function()
	if isBusy or selectedChapterId == nil then
		return
	end

	isBusy = true
	setLabel(mapSelectionHeader, "Subtitle", I18nClient.T("ui.run.generating"))
	refreshCharacterCards()
	refreshChapterCards()

	task.spawn(function()
		local requestSucceeded, started, reason = pcall(function()
			return startRunRequest:InvokeServer(selectedChapterId)
		end)

		if requestSucceeded and started == true then
			setLabel(mapSelectionHeader, "Subtitle", I18nClient.T("ui.run.ready"))
			return
		end

		isBusy = false
		setLabel(mapSelectionHeader, "Subtitle", I18nClient.T("ui.run.launch_failed", { reason = tostring(if requestSucceeded then reason else started) }))
		refreshCharacterCards()
		refreshChapterCards()
	end)
end)

openButton.Activated:Connect(openOverlay)
runLaunchCloseButton.Activated:Connect(closeOverlay)
mapSelectionCloseButton.Activated:Connect(closeOverlay)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not overlay.Visible then
		return
	end

	if input.KeyCode == Enum.KeyCode.Escape then
		closeOverlay()
	elseif input.KeyCode == Enum.KeyCode.Backspace and activeScreen == "Map" and not isBusy then
		setActiveScreen("Characters")
	end
end)

characterUpdate.OnClientEvent:Connect(applyRoster)
player:GetAttributeChangedSignal("SelectedCharacterSkinId"):Connect(refreshSkinChoices)
player:GetAttributeChangedSignal("SelectedWeaponSkinId"):Connect(refreshSkinChoices)
player:GetAttributeChangedSignal("FireballSkinId"):Connect(refreshSkinChoices)
player:GetAttributeChangedSignal("SelectedPrimaryWeaponId"):Connect(refreshSkinChoices)

local function refreshVisibility()
	local isRunActive = player:GetAttribute("IsRunActive") == true

	if wasRunActive and not isRunActive then
		isBusy = false
		setActiveScreen("Characters")
	end

	wasRunActive = isRunActive
	openButton.Visible = not isRunActive

	if isRunActive then
		overlay.Visible = false
	end
end

player:GetAttributeChangedSignal("IsRunActive"):Connect(refreshVisibility)
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)

bindCamera()
refreshSkinChoices()
refreshVisibility()
