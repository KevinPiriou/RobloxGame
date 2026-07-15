--!strict

-- Confirmation locale de gains et d'evenements deja valides par le serveur.
-- Ce script ne modifie jamais les PV, boucliers, degats, score ou ressources.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DebugLog = require(Shared:WaitForChild("DebugLog"))
local PickupFeedbackConfig = require(Shared:WaitForChild("PickupFeedbackConfig"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))

local player = Players.LocalPlayer
local pickupRemote = ReplicatedStorage:WaitForChild(PickupFeedbackConfig.RemoteName) :: RemoteEvent

type FeedbackKind =
	"Coin"
	| "Xp"
	| "Kill"
	| "ArcaneGem"
	| "Run"
	| "HealRegen"
	| "HealInstant"
	| "Shield"
	| "LifeStealHit"
	| "LifeStealDot"
	| "MaxHealth"
	| "Critical"
	| "Poison"

type PopupRoute = "Bottom" | "Top" | "Combat"

type PendingFeedback = {
	Amount: number,
	DueAt: number,
	Kind: FeedbackKind,
}

type PopupPresentation = {
	Accent: Color3,
	AmountPrefix: string?,
	AmountSuffix: string?,
	Glyph: string?,
	GlyphSize: number?,
	Icon: string?,
	IconWidth: number,
	Label: string?,
	Route: PopupRoute,
	TargetId: string?,
	UsesRunScoreIcon: boolean?,
}

type ActivePopup = {
	ArrivalSignaled: boolean,
	Frame: Frame,
	Kind: FeedbackKind,
	Lane: number,
	Presentation: PopupPresentation,
	StartedAt: number,
}

local pendingPickups: { PendingFeedback } = {}
local activePopups: { ActivePopup } = {}
local popupIndex = 0

local hudTargetNames: { [string]: string } = {
	Health = "HpGroup",
	Shield = "ShieldGroup",
	Xp = "XpPanel",
	ArcaneGem = "ArcaneSlot",
	Kill = "KillsSlot",
	Coin = "GoldSlot",
	RunScore = "RunScoreSlot",
}

local playerGui = player:WaitForChild("PlayerGui")
local gui = Instance.new("ScreenGui")
gui.Name = "PickupFeedbackUI"
gui.DisplayOrder = 70
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local container = Instance.new("Frame")
container.Name = "PopupLayer"
container.BackgroundTransparency = 1
container.BorderSizePixel = 0
container.Size = UDim2.fromScale(1, 1)
container.Active = false
container.Parent = gui

local function addCorner(instance: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
end

local function formatAmount(amount: number): string
	local roundedAmount = math.max(0, math.floor(amount + 0.5))

	if roundedAmount >= 1_000_000 then
		return string.format("%.1fM", roundedAmount / 1_000_000)
	end

	if roundedAmount >= 1_000 then
		return string.format("%.1fK", roundedAmount / 1_000)
	end

	return tostring(roundedAmount)
end

local function getPlayerScreenPosition(): Vector2
	local camera = Workspace.CurrentCamera
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")

	if camera ~= nil and root ~= nil and root:IsA("BasePart") then
		local projected, inFront = camera:WorldToViewportPoint(root.Position + Vector3.new(0, 3.1, 0))

		if inFront then
			return Vector2.new(projected.X, projected.Y)
		end
	end

	if camera ~= nil then
		return camera.ViewportSize * 0.5
	end

	return Vector2.new(640, 360)
end

local function getViewportSize(): Vector2
	local camera = Workspace.CurrentCamera

	if camera ~= nil then
		return camera.ViewportSize
	end

	return Vector2.new(1280, 720)
end

local function setPopupTransparency(frame: Frame, transparency: number)
	frame.BackgroundTransparency = 1

	for _, descendant in ipairs(frame:GetDescendants()) do
		if descendant:IsA("TextLabel") then
			descendant.TextTransparency = transparency
			descendant.TextStrokeTransparency = math.min(1, 0.18 + (transparency * 0.82))
		elseif descendant:IsA("ImageLabel") then
			descendant.ImageTransparency = transparency
		end
	end
end

local function getPopupPresentation(kind: FeedbackKind): PopupPresentation
	if kind == "Coin" then
		return {
			Accent = UiTheme.Colors.Gold,
			Icon = UiTheme.Icons.Gold,
			IconWidth = 34,
			Route = "Top",
			TargetId = "Coin",
		}
	end

	if kind == "Kill" then
		return {
			Accent = UiTheme.Colors.Kills,
			Icon = UiTheme.Icons.Kills,
			IconWidth = 34,
			Route = "Top",
			TargetId = "Kill",
		}
	end

	if kind == "ArcaneGem" then
		return {
			Accent = UiTheme.Colors.Arcane,
			Icon = UiTheme.Icons.ArcaneGem,
			IconWidth = 34,
			Route = "Top",
			TargetId = "ArcaneGem",
		}
	end

	if kind == "Run" then
		return {
			Accent = UiTheme.Colors.RunScore,
			IconWidth = 34,
			Route = "Top",
			TargetId = "RunScore",
			UsesRunScoreIcon = true,
		}
	end

	if kind == "HealRegen" then
		return {
			Accent = UiTheme.Colors.Health,
			AmountSuffix = " PV",
			Icon = UiTheme.Icons.Health,
			IconWidth = 34,
			Route = "Bottom",
			TargetId = "Health",
		}
	end

	if kind == "HealInstant" then
		return {
			Accent = UiTheme.Colors.Health,
			AmountSuffix = " SOIN",
			Icon = UiTheme.Icons.Health,
			IconWidth = 34,
			Route = "Bottom",
			TargetId = "Health",
		}
	end

	if kind == "LifeStealHit" then
		return {
			Accent = UiTheme.Colors.Health,
			AmountSuffix = " VDV",
			Icon = UiTheme.Icons.Health,
			IconWidth = 34,
			Route = "Bottom",
			TargetId = "Health",
		}
	end

	if kind == "LifeStealDot" then
		return {
			Accent = UiTheme.Colors.Health,
			AmountSuffix = " VDV DOT",
			Icon = UiTheme.Icons.Health,
			IconWidth = 34,
			Route = "Bottom",
			TargetId = "Health",
		}
	end

	if kind == "MaxHealth" then
		return {
			Accent = UiTheme.Colors.Health,
			AmountPrefix = "PV MAX +",
			Icon = UiTheme.Icons.Health,
			IconWidth = 34,
			Route = "Bottom",
			TargetId = "Health",
		}
	end

	if kind == "Shield" then
		return {
			Accent = UiTheme.Colors.Shield,
			AmountSuffix = " BOUCLIER",
			Icon = UiTheme.Icons.Shield,
			IconWidth = 34,
			Route = "Bottom",
			TargetId = "Shield",
		}
	end

	if kind == "Critical" then
		return {
			Accent = UiTheme.Colors.Critical,
			AmountPrefix = "CRIT ",
			IconWidth = 0,
			Route = "Combat",
		}
	end

	if kind == "Poison" then
		return {
			Accent = UiTheme.Colors.Poison,
			IconWidth = 0,
			Label = "POISON",
			Route = "Combat",
		}
	end

	return {
		Accent = UiTheme.Colors.Xp,
		Glyph = "XP",
		GlyphSize = 17,
		IconWidth = 34,
		Route = "Bottom",
		TargetId = "Xp",
	}
end

local function createRunScoreIcon(parent: Instance, color: Color3)
	local holder = Instance.new("Frame")
	holder.Name = "RunScoreIcon"
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	holder.Size = UDim2.fromOffset(30, 30)
	holder.Position = UDim2.fromOffset(0, 4)
	holder.ZIndex = 5
	holder.Parent = parent

	local iconId = UiTheme.Icons.RunScore

	if iconId ~= nil and iconId ~= "" then
		local image = Instance.new("ImageLabel")
		image.BackgroundTransparency = 1
		image.Image = iconId
		image.ScaleType = Enum.ScaleType.Fit
		image.Size = UDim2.fromScale(1, 1)
		image.Parent = holder
		return holder
	end

	for index, definition in ipairs({
		{ Position = UDim2.fromScale(0.25, 0.28), Rotation = -22 },
		{ Position = UDim2.fromScale(0.66, 0.64), Rotation = 22 },
	}) do
		local footprint = Instance.new("Frame")
		footprint.Name = "Footprint" .. tostring(index)
		footprint.AnchorPoint = Vector2.new(0.5, 0.5)
		footprint.Position = definition.Position
		footprint.Size = UDim2.fromScale(0.3, 0.54)
		footprint.BackgroundColor3 = color
		footprint.BorderSizePixel = 0
		footprint.Rotation = definition.Rotation
		footprint.Parent = holder
		addCorner(footprint, 8)
	end

	return holder
end

local function getPopupText(presentation: PopupPresentation, amount: number): string
	if presentation.Label ~= nil then
		return presentation.Label
	end

	local prefix = presentation.AmountPrefix or "+"
	local suffix = presentation.AmountSuffix or ""
	return prefix .. formatAmount(amount) .. suffix
end

local function createPopup(kind: FeedbackKind, amount: number): ActivePopup
	popupIndex += 1

	local presentation = getPopupPresentation(kind)
	local frame = Instance.new("Frame")
	frame.Name = kind .. "Popup"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromOffset(PickupFeedbackConfig.PopupWidth, PickupFeedbackConfig.PopupHeight)
	frame.ZIndex = 4
	frame.Parent = container

	local scale = Instance.new("UIScale")
	scale.Name = "Scale"
	scale.Scale = 0.8
	scale.Parent = frame

	if presentation.UsesRunScoreIcon then
		createRunScoreIcon(frame, presentation.Accent)
	elseif presentation.Icon ~= nil and presentation.Icon ~= "" then
		local image = Instance.new("ImageLabel")
		image.Name = kind .. "Icon"
		image.BackgroundTransparency = 1
		image.Image = presentation.Icon
		image.Size = UDim2.fromOffset(30, 30)
		image.Position = UDim2.fromOffset(0, 4)
		image.ScaleType = Enum.ScaleType.Fit
		image.ZIndex = 5
		image.Parent = frame
	elseif presentation.Glyph ~= nil then
		local glyph = Instance.new("TextLabel")
		glyph.Name = kind .. "Glyph"
		glyph.BackgroundTransparency = 1
		glyph.Font = UiTheme.Fonts.Heavy
		glyph.Text = presentation.Glyph
		glyph.TextColor3 = presentation.Accent
		glyph.TextSize = presentation.GlyphSize or 17
		glyph.TextStrokeColor3 = UiTheme.Colors.Shadow
		glyph.TextStrokeTransparency = 0.18
		glyph.TextXAlignment = Enum.TextXAlignment.Center
		glyph.Size = UDim2.fromOffset(32, 30)
		glyph.Position = UDim2.fromOffset(0, 4)
		glyph.ZIndex = 5
		glyph.Parent = frame
	end

	local amountLabel = Instance.new("TextLabel")
	amountLabel.Name = "Amount"
	amountLabel.BackgroundTransparency = 1
	amountLabel.Font = UiTheme.Fonts.Heavy
	amountLabel.Text = getPopupText(presentation, amount)
	amountLabel.TextColor3 = presentation.Accent
	amountLabel.TextSize = if presentation.Route == "Combat" then 23 else 21
	amountLabel.TextStrokeColor3 = UiTheme.Colors.Shadow
	amountLabel.TextStrokeTransparency = 0.18
	amountLabel.TextXAlignment = Enum.TextXAlignment.Left
	amountLabel.Size = UDim2.new(1, -(presentation.IconWidth + 4), 1, 0)
	amountLabel.Position = UDim2.fromOffset(presentation.IconWidth + 4, 0)
	amountLabel.ZIndex = 5
	amountLabel.Parent = frame

	return {
		ArrivalSignaled = false,
		Frame = frame,
		Kind = kind,
		Lane = ((popupIndex - 1) % 5) - 2,
		Presentation = presentation,
		StartedAt = os.clock(),
	}
end

local function queuePickup(kind: FeedbackKind, amount: number, arrivalTime: number?)
	local now = Workspace:GetServerTimeNow()
	local dueAt = math.max(now, arrivalTime or now)

	for index = #pendingPickups, 1, -1 do
		local pending = pendingPickups[index]

		if pending.Kind == kind and math.abs(pending.DueAt - dueAt) <= PickupFeedbackConfig.CoalesceWindow then
			pending.Amount += amount
			pending.DueAt = math.max(pending.DueAt, dueAt)
			return
		end
	end

	table.insert(pendingPickups, {
		Amount = amount,
		DueAt = dueAt,
		Kind = kind,
	})
end

local function onPickup(payload: unknown)
	if typeof(payload) ~= "table" then
		return
	end

	local kind = payload.Kind
	local amount = payload.Amount

	if
		(kind ~= "Coin" and kind ~= "Xp" and kind ~= "Kill" and kind ~= "ArcaneGem" and kind ~= "Run"
			and kind ~= "HealRegen" and kind ~= "HealInstant" and kind ~= "Shield" and kind ~= "LifeStealHit"
			and kind ~= "LifeStealDot" and kind ~= "MaxHealth" and kind ~= "Critical" and kind ~= "Poison")
		or typeof(amount) ~= "number"
	then
		return
	end

	local sanitizedAmount = math.max(0, amount)

	if sanitizedAmount <= 0 then
		return
	end

	DebugLog.ThrottledInfo("UI", "pickup_feedback_" .. tostring(kind), 0.5, "Feedback popup recu", {
		Amount = sanitizedAmount,
		Kind = kind,
	})

	queuePickup(kind :: FeedbackKind, sanitizedAmount, typeof(payload.ArrivalTime) == "number" and payload.ArrivalTime or nil)
end

local function getTargetScreenPosition(targetId: string?, route: PopupRoute): Vector2
	if targetId ~= nil then
		local combatGui = playerGui:FindFirstChild("CombatGui")
		local targetName = hudTargetNames[targetId]

		if combatGui ~= nil and targetName ~= nil then
			local target = combatGui:FindFirstChild(targetName, true)

			if target ~= nil and target:IsA("GuiObject") and target.Visible then
				return target.AbsolutePosition + (target.AbsoluteSize * 0.5)
			end
		end
	end

	local viewport = getViewportSize()

	if route == "Top" then
		return Vector2.new(viewport.X * 0.5, 34)
	end

	return Vector2.new(viewport.X * 0.5, viewport.Y - 58)
end

local function signalHudArrival(targetId: string?)
	if targetId == nil then
		return
	end

	local combatGui = playerGui:FindFirstChild("CombatGui")
	local feedbackEvent = combatGui and combatGui:FindFirstChild("FeedbackArrived")

	if feedbackEvent ~= nil and feedbackEvent:IsA("BindableEvent") then
		feedbackEvent:Fire(targetId)
	end
end

local function smoothstep(value: number): number
	local clamped = math.clamp(value, 0, 1)
	return clamped * clamped * (3 - (2 * clamped))
end

pickupRemote.OnClientEvent:Connect(onPickup)

RunService.RenderStepped:Connect(function()
	local now = os.clock()
	local serverNow = Workspace:GetServerTimeNow()

	for index = #pendingPickups, 1, -1 do
		if #activePopups >= PickupFeedbackConfig.PopupMaxActive or pendingPickups[index].DueAt > serverNow then
			continue
		end

		local pending = table.remove(pendingPickups, index)
		local success, popupOrError = pcall(createPopup, pending.Kind, pending.Amount)

		if success then
			table.insert(activePopups, popupOrError :: ActivePopup)
		else
			DebugLog.ThrottledWarn("UI", "pickup_feedback_create_failed", 1, "Creation popup impossible", {
				Error = tostring(popupOrError),
				Kind = pending.Kind,
			})
		end
	end

	for index = #activePopups, 1, -1 do
		local popup = activePopups[index]
		local elapsed = now - popup.StartedAt
		local alpha = math.clamp(elapsed / PickupFeedbackConfig.PopupDuration, 0, 1)

		if alpha >= 1 then
			popup.Frame:Destroy()
			table.remove(activePopups, index)
			continue
		end

		local scale = popup.Frame:FindFirstChild("Scale")

		if scale ~= nil and scale:IsA("UIScale") then
			scale.Scale = 0.76 + (math.sin(math.min(alpha, 0.22) / 0.22 * math.pi * 0.5) * 0.24)
		end

		local presentation = popup.Presentation
		local anchor = getPlayerScreenPosition()
		local horizontalOffset = popup.Lane * 32
		local position: Vector2
		local fade: number

		if presentation.Route == "Combat" then
			local rise = PickupFeedbackConfig.PopupRisePixels * alpha
			position = Vector2.new(anchor.X + 72 + horizontalOffset, anchor.Y - 12 - rise)
			fade = math.clamp((alpha - 0.56) / 0.44, 0, 1)
		else
			local initialPosition: Vector2

			if presentation.Route == "Top" then
				initialPosition = Vector2.new(anchor.X - 68 + horizontalOffset, anchor.Y - 4)
			else
				initialPosition = Vector2.new(anchor.X + horizontalOffset, anchor.Y + 36)
			end

			local travelStart = math.clamp(tonumber(PickupFeedbackConfig.ResourceTravelStart) or 0.42, 0, 0.9)
			local travelProgress = smoothstep((alpha - travelStart) / math.max(0.01, 1 - travelStart))
			local targetPosition = getTargetScreenPosition(presentation.TargetId, presentation.Route)
			position = initialPosition:Lerp(targetPosition, travelProgress)
			fade = math.clamp((alpha - 0.78) / 0.22, 0, 1)

			local arrivalAt = math.clamp(tonumber(PickupFeedbackConfig.ResourceArrivalAt) or 0.9, travelStart, 0.99)

			if not popup.ArrivalSignaled and alpha >= arrivalAt then
				popup.ArrivalSignaled = true
				signalHudArrival(presentation.TargetId)
			end
		end

		setPopupTransparency(popup.Frame, fade)
		popup.Frame.Position = UDim2.fromOffset(position.X, position.Y)
	end
end)

DebugLog.Info("UI", "Controleur de popups initialise", {
	Remote = pickupRemote.Name,
})
