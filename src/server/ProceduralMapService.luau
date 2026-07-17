local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ChapterConfig = require(Shared:WaitForChild("ChapterConfig"))
local DebugLog = require(Shared:WaitForChild("DebugLog"))
local ProceduralMapConfig = require(Shared:WaitForChild("ProceduralMapConfig"))

local TemplateService = require(script.Parent:WaitForChild("TemplateService"))
local WorldSpawnService = require(script.Parent:WaitForChild("WorldSpawnService"))

local ProceduralMapService = {}

local SIDE_DIRECTIONS = {
	North = Vector2.new(0, -1),
	South = Vector2.new(0, 1),
	East = Vector2.new(1, 0),
	West = Vector2.new(-1, 0),
}

local REJECTED_SURFACE_NAMES = {
	"LevelLimit",
	"Montain",
	"MurInvisible",
	ProceduralMapConfig.TerrainFolderName,
	ProceduralMapConfig.DecorationFolderName,
}

local function getOrCreateFolder(parent, name)
	local folder = parent:FindFirstChild(name)

	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
	end

	assert(folder:IsA("Folder"), name .. " doit etre un Folder.")
	return folder
end

local function getKit()
	local mapTemplates = TemplateService.GetServerTemplateFolder(ProceduralMapConfig.TemplateFolderName)
	local kit = mapTemplates:FindFirstChild(ProceduralMapConfig.KitFolderName)

	if kit ~= nil then
		return kit
	end

	local legacyKit = Workspace:FindFirstChild(ProceduralMapConfig.LegacyWorkspaceKitName)

	if legacyKit ~= nil then
		legacyKit.Name = ProceduralMapConfig.KitFolderName
		legacyKit.Parent = mapTemplates
		DebugLog.Warn("MapGeneration", "Kit procedural migre depuis Workspace", {
			Target = legacyKit,
		})
		return legacyKit
	end

	DebugLog.Warn("MapGeneration", "Kit procedural introuvable", {
		Expected = "ServerStorage/MapTemplates/" .. ProceduralMapConfig.KitFolderName,
	})
	return nil
end

local function getTemplatePart(kit, name)
	local template = kit:FindFirstChild(name)

	if template == nil or not template:IsA("BasePart") then
		DebugLog.Warn("MapGeneration", "Piece du kit introuvable", {
			Kit = kit,
			Template = name,
		})
		return nil
	end

	return template
end

local function getUsableBounds(map)
	local activeBounds = WorldSpawnService.GetActivePlayableBounds()
	local mapCFrame, mapSize = map:GetBoundingBox()
	local inset = ProceduralMapConfig.PlayableInset
	local minimumX = if activeBounds ~= nil then activeBounds.MinX else mapCFrame.Position.X - (mapSize.X * 0.5)
	local maximumX = if activeBounds ~= nil then activeBounds.MaxX else mapCFrame.Position.X + (mapSize.X * 0.5)
	local minimumZ = if activeBounds ~= nil then activeBounds.MinZ else mapCFrame.Position.Z - (mapSize.Z * 0.5)
	local maximumZ = if activeBounds ~= nil then activeBounds.MaxZ else mapCFrame.Position.Z + (mapSize.Z * 0.5)

	return {
		MinX = minimumX + inset,
		MaxX = maximumX - inset,
		MinZ = minimumZ + inset,
		MaxZ = maximumZ - inset,
		Center = Vector3.new((minimumX + maximumX) * 0.5, mapCFrame.Position.Y, (minimumZ + maximumZ) * 0.5),
	}
end

local function getHorizontalDistance(a, b)
	return (Vector2.new(a.X, a.Z) - Vector2.new(b.X, b.Z)).Magnitude
end

local function getSurfacePosition(x, z, center)
	return WorldSpawnService.FindSurfacePositionAtXZ(x, z, {
		Center = center,
		RaycastHeight = 360,
		RaycastDepth = 720,
		RejectedSurfaceNameContains = REJECTED_SURFACE_NAMES,
	})
end

local function pickWeightedLayout(random, excludedIds)
	local totalWeight = 0

	for _, layout in ipairs(ProceduralMapConfig.Layouts) do
		if not excludedIds[layout.Id] then
			totalWeight += layout.Weight
		end
	end

	if totalWeight <= 0 then
		return nil
	end

	local cursor = random:NextNumber(0, totalWeight)

	for _, layout in ipairs(ProceduralMapConfig.Layouts) do
		if not excludedIds[layout.Id] then
			cursor -= layout.Weight

			if cursor <= 0 then
				return layout
			end
		end
	end

	return ProceduralMapConfig.Layouts[1]
end

local function getPlatformElevation(definition, elevationScale)
	return math.clamp(
		(definition.Elevation * (elevationScale or 1)) + ProceduralMapConfig.ElevationOffset,
		ProceduralMapConfig.MinimumElevation,
		ProceduralMapConfig.MaximumElevation
	)
end

local function getRampLength(elevation)
	return math.clamp(
		elevation * ProceduralMapConfig.Ramp.LengthPerElevation,
		ProceduralMapConfig.Ramp.MinimumLength,
		ProceduralMapConfig.Ramp.MaximumLength
	)
end

local function extendLocalBounds(bounds, minimumX, maximumX, minimumZ, maximumZ)
	bounds.MinX = math.min(bounds.MinX, minimumX)
	bounds.MaxX = math.max(bounds.MaxX, maximumX)
	bounds.MinZ = math.min(bounds.MinZ, minimumZ)
	bounds.MaxZ = math.max(bounds.MaxZ, maximumZ)
end

local function getLayoutLocalBounds(layout, elevationScale)
	local localBounds = {
		MinX = math.huge,
		MaxX = -math.huge,
		MinZ = math.huge,
		MaxZ = -math.huge,
	}

	for _, definition in ipairs(layout.Platforms) do
		local halfWidth = definition.Size.X * 0.5
		local halfDepth = definition.Size.Y * 0.5
		extendLocalBounds(
			localBounds,
			definition.Offset.X - halfWidth,
			definition.Offset.X + halfWidth,
			definition.Offset.Y - halfDepth,
			definition.Offset.Y + halfDepth
		)

		local rampLength = getRampLength(getPlatformElevation(definition, elevationScale))

		for _, side in ipairs(definition.Ramps or {}) do
			if side == "East" then
				extendLocalBounds(
					localBounds,
					definition.Offset.X + halfWidth,
					definition.Offset.X + halfWidth + rampLength,
					definition.Offset.Y - halfDepth,
					definition.Offset.Y + halfDepth
				)
			elseif side == "West" then
				extendLocalBounds(
					localBounds,
					definition.Offset.X - halfWidth - rampLength,
					definition.Offset.X - halfWidth,
					definition.Offset.Y - halfDepth,
					definition.Offset.Y + halfDepth
				)
			elseif side == "North" then
				extendLocalBounds(
					localBounds,
					definition.Offset.X - halfWidth,
					definition.Offset.X + halfWidth,
					definition.Offset.Y - halfDepth - rampLength,
					definition.Offset.Y - halfDepth
				)
			elseif side == "South" then
				extendLocalBounds(
					localBounds,
					definition.Offset.X - halfWidth,
					definition.Offset.X + halfWidth,
					definition.Offset.Y + halfDepth,
					definition.Offset.Y + halfDepth + rampLength
				)
			end
		end
	end

	return localBounds
end

local function getWorldLayoutBounds(anchorPosition, localBounds, layoutYaw)
	local rotation = CFrame.Angles(0, layoutYaw, 0)
	local worldBounds = {
		MinX = math.huge,
		MaxX = -math.huge,
		MinZ = math.huge,
		MaxZ = -math.huge,
	}

	for _, localX in ipairs({ localBounds.MinX, localBounds.MaxX }) do
		for _, localZ in ipairs({ localBounds.MinZ, localBounds.MaxZ }) do
			local offset = rotation:VectorToWorldSpace(Vector3.new(localX, 0, localZ))
			local position = anchorPosition + offset
			extendLocalBounds(worldBounds, position.X, position.X, position.Z, position.Z)
		end
	end

	return worldBounds
end

local function isLayoutWithinBounds(layoutBounds, bounds)
	return layoutBounds.MinX >= bounds.MinX
		and layoutBounds.MaxX <= bounds.MaxX
		and layoutBounds.MinZ >= bounds.MinZ
		and layoutBounds.MaxZ <= bounds.MaxZ
end

local function isLayoutFree(layoutBounds, occupiedAnchors)
	local spacing = ProceduralMapConfig.PlatformSpacing

	for _, occupied in ipairs(occupiedAnchors) do
		local occupiedBounds = occupied.Bounds

		if layoutBounds.MaxX + spacing >= occupiedBounds.MinX
			and layoutBounds.MinX - spacing <= occupiedBounds.MaxX
			and layoutBounds.MaxZ + spacing >= occupiedBounds.MinZ
			and layoutBounds.MinZ - spacing <= occupiedBounds.MaxZ
		then
			return false
		end
	end

	return true
end

local function isLayoutAwayFromArrival(layoutBounds, arrivalPosition)
	if arrivalPosition == nil then
		return true
	end

	local nearestX = math.clamp(arrivalPosition.X, layoutBounds.MinX, layoutBounds.MaxX)
	local nearestZ = math.clamp(arrivalPosition.Z, layoutBounds.MinZ, layoutBounds.MaxZ)
	local distance = (Vector2.new(arrivalPosition.X, arrivalPosition.Z) - Vector2.new(nearestX, nearestZ)).Magnitude

	return distance >= ProceduralMapConfig.ArrivalClearRadius
end

local function findLayoutAnchor(random, localBounds, layoutYaw, bounds, arrivalPosition, occupiedAnchors)

	for _ = 1, ProceduralMapConfig.AnchorAttempts do
		local candidate = Vector3.new(
			random:NextNumber(bounds.MinX, bounds.MaxX),
			bounds.Center.Y,
			random:NextNumber(bounds.MinZ, bounds.MaxZ)
		)

		local worldLayoutBounds = getWorldLayoutBounds(candidate, localBounds, layoutYaw)

		if isLayoutWithinBounds(worldLayoutBounds, bounds)
			and isLayoutFree(worldLayoutBounds, occupiedAnchors)
			and isLayoutAwayFromArrival(worldLayoutBounds, arrivalPosition)
		then
			local surfacePosition = getSurfacePosition(candidate.X, candidate.Z, bounds.Center)

			if surfacePosition ~= nil then
				return surfacePosition, worldLayoutBounds
			end
		end
	end

	return nil
end

local function getSourceRotation(part)
	return part.CFrame - part.Position
end

local function getWorldOffset(anchorCFrame, offset)
	return anchorCFrame:VectorToWorldSpace(Vector3.new(offset.X, 0, offset.Y))
end

local function getWorldDirection(anchorCFrame, side)
	local direction = SIDE_DIRECTIONS[side]

	assert(direction ~= nil, "Direction de rampe inconnue : " .. tostring(side))
	return anchorCFrame:VectorToWorldSpace(Vector3.new(direction.X, 0, direction.Y)).Unit
end

local function setGeneratedTerrainProperties(part, name, terrainKind)
	part.Name = name
	part.Anchored = true
	part.CanCollide = true
	part.CanTouch = true
	part.CanQuery = true
	part.Material = ProceduralMapConfig.GeneratedTerrainMaterial

	-- Les pieces du kit portent des surfaces Studs par defaut. Le relief runtime
	-- doit conserver ses couleurs de biome sans reprendre cet aspect de baseplate.
	part.TopSurface = ProceduralMapConfig.GeneratedTerrainSurface
	part.BottomSurface = ProceduralMapConfig.GeneratedTerrainSurface
	part:SetAttribute(ProceduralMapConfig.GeneratedTerrainAttributeName, true)
	part:SetAttribute(ProceduralMapConfig.TerrainKindAttributeName, terrainKind)
end

local function getTerrainTheme(session)
	local chapter = ChapterConfig.GetChapter(session.ChapterId)
	local themeId = chapter and chapter.TerrainThemeId or ProceduralMapConfig.DefaultTerrainThemeId
	local theme = ProceduralMapConfig.TerrainThemes[themeId]

	if theme == nil then
		themeId = ProceduralMapConfig.DefaultTerrainThemeId
		theme = ProceduralMapConfig.TerrainThemes[themeId]
	end

	assert(theme ~= nil, "Theme de terrain par defaut introuvable.")
	return theme, themeId
end

local function tintTerrainPart(part, colorFamily, paletteIndex, terrainTheme)
	local colors = terrainTheme[colorFamily]

	if colors == nil or #colors == 0 then
		return
	end

	local colorIndex = math.clamp(paletteIndex or 1, 1, #colors)
	part.Color = colors[colorIndex]
end

local function hasRejectedBaseName(instance)
	local current = instance

	while current ~= nil and current ~= Workspace do
		for _, nameFragment in ipairs(ProceduralMapConfig.Base.RejectedSurfaceNameContains) do
			if string.find(current.Name, nameFragment, 1, true) ~= nil then
				return true
			end
		end

		current = current.Parent
	end

	return false
end

local function getHighestWorldY(part)
	local halfSize = part.Size * 0.5
	local highestY = -math.huge

	for _, xSign in ipairs({ -1, 1 }) do
		for _, ySign in ipairs({ -1, 1 }) do
			for _, zSign in ipairs({ -1, 1 }) do
				local corner = part.CFrame:PointToWorldSpace(Vector3.new(
					halfSize.X * xSign,
					halfSize.Y * ySign,
					halfSize.Z * zSign
				))
				highestY = math.max(highestY, corner.Y)
			end
		end
	end

	return highestY
end

local function findBaseSourcePart(map)
	local sourcePart = nil
	local largestArea = ProceduralMapConfig.Base.MinimumSourceArea

	for _, descendant in ipairs(map:GetDescendants()) do
		if descendant:IsA("BasePart")
			and descendant.CFrame.UpVector.Y >= 0.98
			and descendant:GetAttribute(ProceduralMapConfig.GeneratedTerrainAttributeName) ~= true
			and not hasRejectedBaseName(descendant)
		then
			local horizontalArea = descendant.Size.X * descendant.Size.Z

			if horizontalArea > largestArea then
				largestArea = horizontalArea
				sourcePart = descendant
			end
		end
	end

	return sourcePart
end

local function createGeneratedBase(map, templates, terrainTheme, styleRandom)
	local sourcePart = findBaseSourcePart(map)

	if sourcePart == nil then
		DebugLog.Warn("MapGeneration", "Base source introuvable, sol original conserve", {
			Map = map,
			MinimumSourceArea = ProceduralMapConfig.Base.MinimumSourceArea,
		})
		return false
	end

	local baseFolder = getOrCreateFolder(map, ProceduralMapConfig.Base.FolderName)
	baseFolder:SetAttribute(ProceduralMapConfig.IgnoreAsSurfaceAttributeName, false)
	local sourceRotation = sourcePart.CFrame - sourcePart.Position
	local surfaceY = getHighestWorldY(sourcePart) + ProceduralMapConfig.Base.SurfaceOffset
	local paletteIndex = styleRandom:NextInteger(1, #terrainTheme.Grass)
	local top = templates.Top:Clone()
	top.Size = Vector3.new(sourcePart.Size.X, ProceduralMapConfig.TopThickness, sourcePart.Size.Z)
	setGeneratedTerrainProperties(top, "BaseTop", "BaseTop")
	tintTerrainPart(top, "Grass", paletteIndex, terrainTheme)
	top.CFrame = CFrame.new(
		sourcePart.Position.X,
		surfaceY - (ProceduralMapConfig.TopThickness * 0.5),
		sourcePart.Position.Z
	) * sourceRotation
	top.Parent = baseFolder

	local bottomDepth = math.max(
		ProceduralMapConfig.Base.MinimumBottomDepth,
		sourcePart.Size.Y - ProceduralMapConfig.TopThickness
	)
	local bottom = templates.Bottom:Clone()
	bottom.Size = Vector3.new(sourcePart.Size.X, bottomDepth, sourcePart.Size.Z)
	setGeneratedTerrainProperties(bottom, "BaseBottom", "BaseBottom")
	tintTerrainPart(bottom, "Dirt", paletteIndex, terrainTheme)
	bottom.CFrame = CFrame.new(
		sourcePart.Position.X,
		surfaceY - ProceduralMapConfig.TopThickness - (bottomDepth * 0.5),
		sourcePart.Position.Z
	) * sourceRotation
	bottom.Parent = baseFolder

	if ProceduralMapConfig.Base.DestroySourceSurface then
		-- La map est deja un clone runtime. Supprimer la plaque source elimine le
		-- risque de z-fighting et garantit que la base generee est le seul sol.
		sourcePart:Destroy()
	else
		-- Compatibilite temporaire pour un futur mode qui souhaiterait conserver
		-- le support source sans le rendre interactif ni visible.
		sourcePart.Transparency = 1
		sourcePart.CanCollide = false
		sourcePart.CanTouch = false
		sourcePart.CanQuery = false
		sourcePart:SetAttribute(ProceduralMapConfig.IgnoreAsSurfaceAttributeName, true)
	end

	DebugLog.Info("MapGeneration", "Base procedural generee", {
		Source = sourcePart,
		Size = sourcePart.Size,
		SurfaceY = surfaceY,
		PaletteIndex = paletteIndex,
	})

	return true
end

local function createRamp(terrainFolder, rampTemplate, center, platformSize, elevation, side, anchorCFrame, platformIndex, rampIndex, paletteIndex, terrainTheme)
	local direction = getWorldDirection(anchorCFrame, side)
	local followsLocalX = side == "East" or side == "West"
	local horizontalExtent = if followsLocalX then platformSize.X * 0.5 else platformSize.Z * 0.5
	local crossExtent = if followsLocalX then platformSize.Z else platformSize.X
	local rampLength = getRampLength(elevation)
	-- La rampe doit reprendre exactement la largeur du plateau qu'elle raccorde.
	local rampWidth = crossExtent
	local ramp = rampTemplate:Clone()

	-- Le template conserve son axe de pente configure dans Studio.
	ramp.Size = Vector3.new(rampWidth, rampLength, elevation)
	setGeneratedTerrainProperties(ramp, ("Ramp_%d_%d_%s"):format(platformIndex, rampIndex, side), "Ramp")
	tintTerrainPart(ramp, "Ramp", paletteIndex, terrainTheme)

	local rampCenter = center + (direction * (horizontalExtent + (rampLength * 0.5)))
	local rampYaw = math.atan2(direction.X, direction.Z) + ProceduralMapConfig.Ramp.YawCorrection
	ramp.CFrame = CFrame.new(rampCenter.X, center.Y - elevation + (elevation * 0.5), rampCenter.Z)
		* CFrame.Angles(0, rampYaw, 0)
		* getSourceRotation(rampTemplate)
	ramp.Parent = terrainFolder

	return ramp
end

local function createPlatform(terrainFolder, templates, anchorPosition, layoutYaw, definition, platformIndex, elevationScale, paletteIndex, terrainTheme)
	local elevation = getPlatformElevation(definition, elevationScale)
	local anchorCFrame = CFrame.new(anchorPosition) * CFrame.Angles(0, layoutYaw, 0)
	local offset = getWorldOffset(anchorCFrame, definition.Offset)
	local surfacePosition = getSurfacePosition(anchorPosition.X + offset.X, anchorPosition.Z + offset.Z, anchorPosition)

	if surfacePosition == nil then
		return nil
	end

	local platformSize = Vector3.new(definition.Size.X, ProceduralMapConfig.TopThickness, definition.Size.Y)
	local platformCenter = Vector3.new(surfacePosition.X, surfacePosition.Y + elevation - (ProceduralMapConfig.TopThickness * 0.5), surfacePosition.Z)
	local bottomHeight = elevation - ProceduralMapConfig.TopThickness
	local top = templates.Top:Clone()
	top.Size = platformSize
	setGeneratedTerrainProperties(top, "Top_" .. platformIndex, "Top")
	tintTerrainPart(top, "Grass", paletteIndex, terrainTheme)
	top.CFrame = CFrame.new(platformCenter) * CFrame.Angles(0, layoutYaw, 0)
	top.Parent = terrainFolder

	if bottomHeight > 0.1 then
		local bottom = templates.Bottom:Clone()
		bottom.Size = Vector3.new(definition.Size.X, bottomHeight, definition.Size.Y)
		setGeneratedTerrainProperties(bottom, "Bottom_" .. platformIndex, "Bottom")
		tintTerrainPart(bottom, "Dirt", paletteIndex, terrainTheme)
		bottom.CFrame = CFrame.new(surfacePosition.X, surfacePosition.Y + (bottomHeight * 0.5), surfacePosition.Z) * CFrame.Angles(0, layoutYaw, 0)
		bottom.Parent = terrainFolder
	end

	for rampIndex, side in ipairs(definition.Ramps) do
		createRamp(
			terrainFolder,
			templates.Ramp,
			Vector3.new(surfacePosition.X, surfacePosition.Y + elevation, surfacePosition.Z),
			platformSize,
			elevation,
			side,
			anchorCFrame,
			platformIndex,
			rampIndex,
			paletteIndex,
			terrainTheme
		)
	end

	return {
		Center = platformCenter,
		GroundPosition = surfacePosition,
		SurfaceY = surfacePosition.Y + elevation,
		Elevation = elevation,
		Size = definition.Size,
		Yaw = layoutYaw,
		Ramps = definition.Ramps,
	}
end

local function getLayoutSurfaceArea(layout)
	local area = 0

	for _, platform in ipairs(layout.Platforms) do
		area += platform.Size.X * platform.Size.Y
	end

	return area
end

local function getCardinalDirection(fromPosition, toPosition)
	local delta = toPosition - fromPosition

	if math.abs(delta.X) >= math.abs(delta.Z) then
		return if delta.X >= 0 then Vector3.new(1, 0, 0) else Vector3.new(-1, 0, 0)
	end

	return if delta.Z >= 0 then Vector3.new(0, 0, 1) else Vector3.new(0, 0, -1)
end

local function getPlatformEdgePosition(record, direction)
	local localDirection = CFrame.Angles(0, record.Yaw, 0):VectorToObjectSpace(direction)
	local horizontalExtent = if math.abs(localDirection.X) > math.abs(localDirection.Z)
		then record.Size.X * 0.5
		else record.Size.Y * 0.5

	return record.GroundPosition + (direction * (horizontalExtent + ProceduralMapConfig.Links.Clearance))
end

local function createLinkBlock(terrainFolder, templates, startPosition, endPosition, linkIndex, styleRandom, terrainTheme)
	local delta = Vector3.new(endPosition.X - startPosition.X, 0, endPosition.Z - startPosition.Z)
	local length = delta.Magnitude

	if length < ProceduralMapConfig.Links.MinimumLength then
		return 0
	end

	local direction = delta.Unit
	local isAlongX = math.abs(direction.X) > math.abs(direction.Z)
	local segmentCount = math.max(1, math.ceil(length / ProceduralMapConfig.Links.MaximumLength))
	local segmentLength = length / segmentCount
	local placedCount = 0

	for segment = 1, segmentCount do
		local paletteIndex = styleRandom:NextInteger(1, #terrainTheme.Grass)
		local segmentStart = startPosition + (direction * ((segment - 1) * segmentLength))
		local segmentEnd = startPosition + (direction * (segment * segmentLength))
		local midpoint = (segmentStart + segmentEnd) * 0.5
		local surfacePosition = getSurfacePosition(midpoint.X, midpoint.Z, midpoint)

		if surfacePosition ~= nil then
			local elevation = ProceduralMapConfig.Links.Elevation
			local topSize = if isAlongX
				then Vector3.new(segmentLength, ProceduralMapConfig.TopThickness, ProceduralMapConfig.Links.Width)
				else Vector3.new(ProceduralMapConfig.Links.Width, ProceduralMapConfig.TopThickness, segmentLength)
			local bottomHeight = math.max(1, elevation - ProceduralMapConfig.TopThickness)
			local top = templates.Top:Clone()
			top.Size = topSize
			setGeneratedTerrainProperties(top, ("LinkTop_%d_%d"):format(linkIndex, segment), "LinkTop")
			tintTerrainPart(top, "Grass", paletteIndex, terrainTheme)
			top.CFrame = CFrame.new(
				surfacePosition.X,
				surfacePosition.Y + elevation - (ProceduralMapConfig.TopThickness * 0.5),
				surfacePosition.Z
			)
			top.Parent = terrainFolder

			local bottom = templates.Bottom:Clone()
			bottom.Size = Vector3.new(topSize.X, bottomHeight, topSize.Z)
			setGeneratedTerrainProperties(bottom, ("LinkBottom_%d_%d"):format(linkIndex, segment), "LinkBottom")
			tintTerrainPart(bottom, "Dirt", paletteIndex, terrainTheme)
			bottom.CFrame = CFrame.new(
				surfacePosition.X,
				surfacePosition.Y + (bottomHeight * 0.5),
				surfacePosition.Z
			)
			bottom.Parent = terrainFolder
			placedCount += 1
		end
	end

	return placedCount
end

local function createLayoutConnection(terrainFolder, templates, fromRecord, toRecord, linkIndex, styleRandom, terrainTheme)
	local directDistance = getHorizontalDistance(fromRecord.GroundPosition, toRecord.GroundPosition)

	if directDistance > ProceduralMapConfig.Links.MaximumConnectionDistance then
		return 0
	end

	local firstDirection = getCardinalDirection(fromRecord.GroundPosition, toRecord.GroundPosition)
	local secondDirection = getCardinalDirection(toRecord.GroundPosition, fromRecord.GroundPosition)
	local startPosition = getPlatformEdgePosition(fromRecord, firstDirection)
	local endPosition = getPlatformEdgePosition(toRecord, secondDirection)
	local elbow = Vector3.new(endPosition.X, startPosition.Y, startPosition.Z)
	local created = createLinkBlock(terrainFolder, templates, startPosition, elbow, linkIndex, styleRandom, terrainTheme)

	return created + createLinkBlock(terrainFolder, templates, elbow, endPosition, linkIndex + 1, styleRandom, terrainTheme)
end

local function createLayoutLinks(terrainFolder, templates, selectedLayouts, styleRandom, terrainTheme)
	if not ProceduralMapConfig.Links.Enabled or #selectedLayouts < 2 then
		return 0
	end

	local linked = { [1] = true }
	local linkCount = 0
	local placedCount = 0

	while true do
		local nearestFromIndex = nil
		local nearestToIndex = nil
		local nearestDistance = math.huge

		for fromIndex, fromLayout in ipairs(selectedLayouts) do
			if linked[fromIndex] and fromLayout.PlatformRecords ~= nil and fromLayout.PlatformRecords[1] ~= nil then
				for toIndex, toLayout in ipairs(selectedLayouts) do
					if not linked[toIndex] and toLayout.PlatformRecords ~= nil and toLayout.PlatformRecords[1] ~= nil then
						local distance = getHorizontalDistance(
							fromLayout.PlatformRecords[1].GroundPosition,
							toLayout.PlatformRecords[1].GroundPosition
						)

						if distance < nearestDistance then
							nearestDistance = distance
							nearestFromIndex = fromIndex
							nearestToIndex = toIndex
						end
					end
				end
			end
		end

		if nearestFromIndex == nil or nearestToIndex == nil then
			break
		end

		linkCount += 2
		placedCount += createLayoutConnection(
			terrainFolder,
			templates,
			selectedLayouts[nearestFromIndex].PlatformRecords[1],
			selectedLayouts[nearestToIndex].PlatformRecords[1],
			linkCount,
			styleRandom,
			terrainTheme
		)
		linked[nearestToIndex] = true
	end

	return placedCount
end

local function getDecorationTemplateHeight(template)
	if template:IsA("BasePart") then
		return math.max(0.01, template.Size.Y)
	end

	local _, size = template:GetBoundingBox()
	return math.max(0.01, size.Y)
end

local function getDecorationPivotRotation(instance)
	local pivot = instance:GetPivot()
	return pivot - pivot.Position
end

local function getDecorationParts(decoration)
	local parts = {}

	if decoration:IsA("BasePart") then
		table.insert(parts, decoration)
	end

	for _, descendant in ipairs(decoration:GetDescendants()) do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end

	return parts
end

local function shouldDecorationPartCollide(part, collisionMode, maximumHorizontalArea)
	if collisionMode == "All" then
		return true
	end

	if collisionMode == "TreeTrunk" then
		local horizontalArea = part.Size.X * part.Size.Z
		return part.Size.Y >= 8 and horizontalArea <= (maximumHorizontalArea or 0)
	end

	return false
end

local function prepareDecoration(decoration, collisionMode, maximumHorizontalArea)
	decoration:SetAttribute(ProceduralMapConfig.GeneratedDecorationAttributeName, true)
	decoration:SetAttribute(ProceduralMapConfig.IgnoreAsSurfaceAttributeName, true)

	for _, part in ipairs(getDecorationParts(decoration)) do
		part.Anchored = true
		part.CanCollide = shouldDecorationPartCollide(part, collisionMode, maximumHorizontalArea)
		part.CanTouch = false
		part.CanQuery = false
		part.Massless = true
		part:SetAttribute(ProceduralMapConfig.GeneratedDecorationAttributeName, true)
		part:SetAttribute(ProceduralMapConfig.IgnoreAsSurfaceAttributeName, true)
	end
end

local function getDecorationBounds(decoration)
	if decoration:IsA("BasePart") then
		return decoration.CFrame, decoration.Size
	end

	return decoration:GetBoundingBox()
end

local function createDecorationCollisionBounds(decoration, cframe, size)
	local collision = Instance.new("Part")
	collision.Name = "Collision"
	collision.Size = size
	collision.CFrame = cframe
	collision.Transparency = 1
	collision.CastShadow = false
	collision.Anchored = true
	collision.CanCollide = true
	collision.CanTouch = false
	collision.CanQuery = false
	collision.Massless = true
	collision:SetAttribute(ProceduralMapConfig.GeneratedDecorationAttributeName, true)
	collision:SetAttribute(ProceduralMapConfig.IgnoreAsSurfaceAttributeName, true)
	collision.Parent = decoration

	return collision
end

local function scaleDecoration(decoration, scale)
	if decoration:IsA("BasePart") then
		decoration.Size = decoration.Size * scale
		return
	end

	decoration:ScaleTo(scale)
end

local function buildDecorationCatalog(kit)
	local templateFolder = kit:FindFirstChild(ProceduralMapConfig.Decorations.TemplateFolderName)

	if templateFolder == nil or not templateFolder:IsA("Folder") then
		DebugLog.Warn("MapGeneration", "Dossier de decorations introuvable dans le kit procedural", {
			Kit = kit,
			Expected = ProceduralMapConfig.Decorations.TemplateFolderName,
		})
		return nil
	end

	local catalog = {}
	local hasAnyTemplate = false

	for familyName, family in pairs(ProceduralMapConfig.Decorations.Families) do
		local assets = {}

		for _, asset in ipairs(family.Assets) do
			local template = templateFolder:FindFirstChild(asset.Name)

			if template ~= nil and (template:IsA("Model") or template:IsA("BasePart")) then
				table.insert(assets, {
					Config = asset,
					Template = template,
					TemplateHeight = getDecorationTemplateHeight(template),
					CollisionMode = family.CollisionMode,
					CollisionMaximumHorizontalArea = family.CollisionMaximumHorizontalArea,
				})
				hasAnyTemplate = true
			else
				DebugLog.Warn("MapGeneration", "Asset de decor absent ou invalide", {
					Family = familyName,
					Asset = asset.Name,
				})
			end
		end

		catalog[familyName] = assets
	end

	if not hasAnyTemplate then
		DebugLog.Warn("MapGeneration", "Aucun asset de decor exploitable dans le kit procedural", {
			Folder = templateFolder,
		})
		return nil
	end

	return catalog
end

local function selectWeightedDecorationAsset(random, assets)
	local totalWeight = 0

	for _, asset in ipairs(assets) do
		totalWeight += asset.Config.Weight
	end

	if totalWeight <= 0 then
		return nil
	end

	local selection = random:NextNumber(0, totalWeight)

	for _, asset in ipairs(assets) do
		selection -= asset.Config.Weight

		if selection <= 0 then
			return asset
		end
	end

	return assets[#assets]
end

local function isDecorationRecordEligible(record, family)
	local area = record.Size.X * record.Size.Y

	return area >= family.MinimumPlatformArea
		and record.Elevation >= family.MinimumElevation
		and record.Elevation <= family.MaximumElevation
end

local function getDecorationTargetCount(random, record, family)
	local expectedCount = (record.Size.X * record.Size.Y / 1000) * family.DensityPerThousandStuds
	local count = math.floor(expectedCount)

	if random:NextNumber() < (expectedCount - count) then
		count += 1
	end

	return math.clamp(
		math.max(family.MinimumPerPlatform, count),
		family.MinimumPerPlatform,
		family.MaximumPerPlatform
	)
end

local function isDecorationPositionAvailable(position, radius, occupiedPositions, arrivalPosition)
	if arrivalPosition ~= nil and getHorizontalDistance(position, arrivalPosition) < ProceduralMapConfig.Decorations.ArrivalClearRadius then
		return false
	end

	for _, occupied in ipairs(occupiedPositions) do
		if getHorizontalDistance(position, occupied.Position) < radius + occupied.Radius then
			return false
		end
	end

	return true
end

local function getDecorationPosition(random, record, family, occupiedPositions, arrivalPosition)
	local maximumMargin = math.min(record.Size.X, record.Size.Y) * 0.35
	local margin = math.min(ProceduralMapConfig.Decorations.PlatformMargin, maximumMargin)
	local halfWidth = record.Size.X * 0.5
	local halfDepth = record.Size.Y * 0.5

	if halfWidth <= margin or halfDepth <= margin then
		return nil
	end

	local platformCFrame = CFrame.new(record.Center.X, record.SurfaceY, record.Center.Z) * CFrame.Angles(0, record.Yaw, 0)

	for _ = 1, ProceduralMapConfig.Decorations.PlacementAttemptsPerInstance do
		local localPosition = Vector3.new(
			random:NextNumber(-halfWidth + margin, halfWidth - margin),
			0,
			random:NextNumber(-halfDepth + margin, halfDepth - margin)
		)
		local worldPosition = platformCFrame:PointToWorldSpace(localPosition)
		local position = Vector3.new(worldPosition.X, record.SurfaceY, worldPosition.Z)

		if isDecorationPositionAvailable(position, family.FootprintRadius, occupiedPositions, arrivalPosition) then
			return position
		end
	end

	return nil
end

local function getGroundDecorationTargetCount(random, bounds, family)
	local groundConfig = ProceduralMapConfig.Decorations.Ground
	local usableWidth = (bounds.MaxX - bounds.MinX) - (groundConfig.EdgeInset * 2)
	local usableDepth = (bounds.MaxZ - bounds.MinZ) - (groundConfig.EdgeInset * 2)

	if usableWidth <= 0 or usableDepth <= 0 then
		return 0
	end

	local expectedCount = (usableWidth * usableDepth / 1000)
		* family.DensityPerThousandStuds
		* groundConfig.DensityMultiplier
	local count = math.floor(expectedCount)

	if random:NextNumber() < (expectedCount - count) then
		count += 1
	end

	return math.min(count, family.MaximumGroundInstances or math.huge)
end

local function getGroundDecorationPosition(random, map, bounds, family, occupiedPositions, arrivalPosition)
	local groundConfig = ProceduralMapConfig.Decorations.Ground
	local minimumX = bounds.MinX + groundConfig.EdgeInset
	local maximumX = bounds.MaxX - groundConfig.EdgeInset
	local minimumZ = bounds.MinZ + groundConfig.EdgeInset
	local maximumZ = bounds.MaxZ - groundConfig.EdgeInset

	if minimumX >= maximumX or minimumZ >= maximumZ then
		return nil
	end

	for _ = 1, ProceduralMapConfig.Decorations.PlacementAttemptsPerInstance do
		local surfacePosition = getSurfacePosition(
			random:NextNumber(minimumX, maximumX),
			random:NextNumber(minimumZ, maximumZ),
			bounds.Center
		)

		if surfacePosition ~= nil
			and ProceduralMapService.IsAreaClear(map, surfacePosition, groundConfig.TerrainClearance)
			and isDecorationPositionAvailable(surfacePosition, family.FootprintRadius, occupiedPositions, arrivalPosition)
		then
			return surfacePosition
		end
	end

	return nil
end

local function createFoliageDecoration(folder, random, asset, position, yaw, name)
	local decoration = asset.Template:Clone()
	local targetHeight = random:NextNumber(asset.Config.MinimumHeight, asset.Config.MaximumHeight)
	local scale = targetHeight / asset.TemplateHeight

	scaleDecoration(decoration, scale)
	prepareDecoration(decoration, asset.CollisionMode, asset.CollisionMaximumHorizontalArea)
	decoration.Name = name
	decoration.Parent = folder
	decoration:PivotTo(
		CFrame.new(position) * CFrame.Angles(0, yaw, 0) * getDecorationPivotRotation(asset.Template)
	)

	local boundsCFrame, boundsSize = getDecorationBounds(decoration)
	local bottomY = boundsCFrame.Position.Y - (boundsSize.Y * 0.5)
	decoration:PivotTo(decoration:GetPivot() + Vector3.new(0, position.Y + ProceduralMapConfig.Decorations.VerticalPadding - bottomY, 0))

	if asset.CollisionMode == "Bounds" then
		local collisionCFrame, collisionSize = getDecorationBounds(decoration)
		createDecorationCollisionBounds(decoration, collisionCFrame, collisionSize)
	end

	return decoration
end

local function generateFoliage(random, map, bounds, decorationFolder, catalog, platformRecords, arrivalPosition, onProgress)
	local placedCount = 0
	local attemptedCount = 0
	local byFamily = {}
	local occupiedPositions = {}

	for _, familyName in ipairs(ProceduralMapConfig.Decorations.FamilyOrder) do
		if placedCount >= ProceduralMapConfig.Decorations.MaximumInstances then
			break
		end

		local family = ProceduralMapConfig.Decorations.Families[familyName]
		local assets = catalog[familyName]
		local familyCount = 0
		local maximumFamilyInstances = if family ~= nil then family.MaximumInstancesPerMap or math.huge else 0

		if family ~= nil and assets ~= nil and #assets > 0 then
			local function tryPlaceDecoration(position)
				if position == nil then
					return
				end

				local asset = selectWeightedDecorationAsset(random, assets)

				if asset == nil then
					return
				end

				createFoliageDecoration(
					decorationFolder,
					random,
					asset,
					position,
					random:NextNumber(0, math.pi * 2),
					("%s_%d"):format(familyName, placedCount + 1)
				)
				table.insert(occupiedPositions, {
					Position = position,
					Radius = family.FootprintRadius,
				})
				placedCount += 1
				familyCount += 1
			end

			local function reportAttemptProgress()
				if attemptedCount % ProceduralMapConfig.DecorationBatchSize == 0 then
					if onProgress ~= nil then
						onProgress("Decorations", ("Foliage : %d / %d"):format(
							placedCount,
							ProceduralMapConfig.Decorations.MaximumInstances
						))
					end
					task.wait()
				end
			end

			for _, record in ipairs(platformRecords) do
				if placedCount >= ProceduralMapConfig.Decorations.MaximumInstances or familyCount >= maximumFamilyInstances then
					break
				end

				if isDecorationRecordEligible(record, family) then
					local targetCount = getDecorationTargetCount(random, record, family)

					for _ = 1, targetCount do
						if placedCount >= ProceduralMapConfig.Decorations.MaximumInstances or familyCount >= maximumFamilyInstances then
							break
						end

						attemptedCount += 1
						local position = getDecorationPosition(random, record, family, occupiedPositions, arrivalPosition)
						tryPlaceDecoration(position)
						reportAttemptProgress()
					end
				end
			end

			local groundTargetCount = getGroundDecorationTargetCount(random, bounds, family)

			for _ = 1, groundTargetCount do
				if placedCount >= ProceduralMapConfig.Decorations.MaximumInstances or familyCount >= maximumFamilyInstances then
					break
				end

				attemptedCount += 1
				local position = getGroundDecorationPosition(random, map, bounds, family, occupiedPositions, arrivalPosition)
				tryPlaceDecoration(position)
				reportAttemptProgress()
			end
		end

		byFamily[familyName] = familyCount
	end

	if onProgress ~= nil then
		onProgress("Decorations", ("Foliage : %d"):format(placedCount))
	end

	return placedCount, byFamily
end

function ProceduralMapService.Clear(map)
	if map == nil then
		return
	end

	for _, folderName in ipairs({
		ProceduralMapConfig.Base.FolderName,
		ProceduralMapConfig.TerrainFolderName,
		ProceduralMapConfig.DecorationFolderName,
	}) do
		local folder = map:FindFirstChild(folderName)

		if folder ~= nil then
			folder:Destroy()
		end
	end
end

function ProceduralMapService.IsAreaClear(map, position, clearance, options)
	if map == nil or position == nil then
		return true
	end

	local terrainFolder = map:FindFirstChild(ProceduralMapConfig.TerrainFolderName)

	if terrainFolder == nil then
		return true
	end

	local padding = math.max(0, clearance or 0)
	local allowSupportingTerrain = options ~= nil and options.AllowSupportingTerrain == true

	for _, descendant in ipairs(terrainFolder:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local localPosition = descendant.CFrame:PointToObjectSpace(position)
			local halfSize = descendant.Size * 0.5
			local isInsideFootprint = math.abs(localPosition.X) <= halfSize.X
				and math.abs(localPosition.Z) <= halfSize.Z
			local terrainKind = descendant:GetAttribute(ProceduralMapConfig.TerrainKindAttributeName)

			-- Une plateforme peut servir de sol au portail. Seuls ses volumes
			-- directement sous le point de pose sont ignores, pas les plateformes voisines.
			if allowSupportingTerrain
				and isInsideFootprint
				and (terrainKind == "Top" or terrainKind == "Bottom" or terrainKind == "LinkTop" or terrainKind == "LinkBottom")
			then
				continue
			end

			if math.abs(localPosition.X) <= halfSize.X + padding
				and math.abs(localPosition.Z) <= halfSize.Z + padding
			then
				return false
			end
		end
	end

	return true
end

function ProceduralMapService.Generate(session, map, arrival, onProgress)
	if not ProceduralMapConfig.Enabled then
		return true, {
			Layouts = 0,
			Platforms = 0,
			Foliage = 0,
			FoliageByFamily = {},
		}
	end

	if map == nil or map.Parent == nil then
		return false, "MapRuntimeMissing"
	end

	local kit = getKit()

	if kit == nil then
		return false, "ProceduralKitMissing"
	end

	local templates = {
		Top = getTemplatePart(kit, "TopBasePlateform"),
		Bottom = getTemplatePart(kit, "BotBasePlateform"),
		Ramp = getTemplatePart(kit, "RampBasePlateform"),
	}

	for name, template in pairs(templates) do
		if template == nil then
			return false, "TemplateMissing_" .. name
		end
	end

	local decorationCatalog = buildDecorationCatalog(kit)

	if decorationCatalog == nil then
		return false, "DecorationTemplatesMissing"
	end

	ProceduralMapService.Clear(map)
	local terrainFolder = getOrCreateFolder(map, ProceduralMapConfig.TerrainFolderName)
	local decorationFolder = getOrCreateFolder(map, ProceduralMapConfig.DecorationFolderName)
	decorationFolder:SetAttribute(ProceduralMapConfig.IgnoreAsSurfaceAttributeName, true)

	local seed = math.floor(tonumber(session.Seed) or 0)
	local random = Random.new(seed + 413)
	local styleRandom = Random.new(seed + 977)
	local terrainTheme, terrainThemeId = getTerrainTheme(session)
	local baseGenerated = createGeneratedBase(map, templates, terrainTheme, styleRandom)
	local bounds = getUsableBounds(map)
	local arrivalPosition = WorldSpawnService.GetInstancePosition(arrival)
	local selectedLayouts = {}
	local occupiedAnchors = {}
	local usableArea = math.max(1, (bounds.MaxX - bounds.MinX) * (bounds.MaxZ - bounds.MinZ))
	local targetSurfaceArea = usableArea * ProceduralMapConfig.TargetCoverageRatio
	local coveredSurfaceArea = 0
	local plannedPlatformCount = 0

	while #selectedLayouts < ProceduralMapConfig.MaximumLayoutCount
		and (#selectedLayouts < ProceduralMapConfig.MinimumLayoutCount or coveredSurfaceArea < targetSurfaceArea)
	do
		local attemptedIds = {}
		local selected = false

		for _ = 1, #ProceduralMapConfig.Layouts do
			local excludedIds = {}

			for id in pairs(attemptedIds) do
				excludedIds[id] = true
			end

			local layout = pickWeightedLayout(random, excludedIds)

			if layout == nil then
				break
			end

			if plannedPlatformCount + #layout.Platforms > ProceduralMapConfig.MaximumGeneratedPlatforms then
				attemptedIds[layout.Id] = true
				continue
			end

			local elevationScale = random:NextNumber(
				ProceduralMapConfig.ElevationScaleMinimum,
				ProceduralMapConfig.ElevationScaleMaximum
			)
			local layoutYaw = random:NextInteger(0, 3) * (math.pi * 0.5)
			local localBounds = getLayoutLocalBounds(layout, elevationScale)
			local anchor, worldLayoutBounds = findLayoutAnchor(
				random,
				localBounds,
				layoutYaw,
				bounds,
				arrivalPosition,
				occupiedAnchors
			)
			attemptedIds[layout.Id] = true

			if anchor ~= nil then
				table.insert(selectedLayouts, {
					Definition = layout,
					Anchor = anchor,
					Yaw = layoutYaw,
					ElevationScale = elevationScale,
					PlatformRecords = {},
				})
				table.insert(occupiedAnchors, {
					Bounds = worldLayoutBounds,
				})
				coveredSurfaceArea += getLayoutSurfaceArea(layout)
				plannedPlatformCount += #layout.Platforms
				selected = true
				break
			end
		end

		if not selected then
			DebugLog.Warn("MapGeneration", "Couverture relief plafonnee par la surface disponible", {
				RunId = session.RunId,
				Placed = #selectedLayouts,
				CoveredRatio = coveredSurfaceArea / usableArea,
				TargetRatio = ProceduralMapConfig.TargetCoverageRatio,
			})
			break
		end
	end

	if #selectedLayouts < ProceduralMapConfig.MinimumLayoutCount then
		ProceduralMapService.Clear(map)
		DebugLog.Warn("MapGeneration", "Generation relief insuffisante", {
			Minimum = ProceduralMapConfig.MinimumLayoutCount,
			Placed = #selectedLayouts,
			RunId = session.RunId,
		})
		return false, "TerrainPlacementInsufficient"
	end

	local totalPlatformCount = 0

	for _, selectedLayout in ipairs(selectedLayouts) do
		totalPlatformCount += #selectedLayout.Definition.Platforms
	end

	local platformRecords = {}
	local placedPlatforms = 0

	for _, selectedLayout in ipairs(selectedLayouts) do
		for _, platformDefinition in ipairs(selectedLayout.Definition.Platforms) do
			local paletteIndex = styleRandom:NextInteger(1, #terrainTheme.Grass)
			local record = createPlatform(
				terrainFolder,
				templates,
				selectedLayout.Anchor,
				selectedLayout.Yaw,
				platformDefinition,
				placedPlatforms + 1,
				selectedLayout.ElevationScale,
				paletteIndex,
				terrainTheme
			)

			if record ~= nil then
				table.insert(platformRecords, record)
				table.insert(selectedLayout.PlatformRecords, record)
				placedPlatforms += 1
			end

			if placedPlatforms % ProceduralMapConfig.TerrainBatchSize == 0 or placedPlatforms == totalPlatformCount then
				if onProgress ~= nil then
					onProgress("Terrain", ("Relief : %d / %d"):format(placedPlatforms, totalPlatformCount))
				end
				task.wait()
			end
		end
	end

	if placedPlatforms == 0 then
		ProceduralMapService.Clear(map)
		return false, "TerrainSurfaceMissing"
	end

	local linkCount = createLayoutLinks(terrainFolder, templates, selectedLayouts, styleRandom, terrainTheme)

	local foliageCount, foliageByFamily = generateFoliage(
		random,
		map,
		bounds,
		decorationFolder,
		decorationCatalog,
		platformRecords,
		arrivalPosition,
		onProgress
	)

	DebugLog.Info("MapGeneration", "Relief procedural genere", {
		RunId = session.RunId,
		Seed = session.Seed,
		Theme = terrainThemeId,
		BaseGenerated = baseGenerated,
		Layouts = #selectedLayouts,
		Platforms = placedPlatforms,
		Links = linkCount,
		CoveredRatio = coveredSurfaceArea / usableArea,
		TargetCoverageRatio = ProceduralMapConfig.TargetCoverageRatio,
		Foliage = foliageCount,
		FoliageByFamily = foliageByFamily,
	})

	return true, {
		Layouts = #selectedLayouts,
		Platforms = placedPlatforms,
		Links = linkCount,
		Foliage = foliageCount,
		FoliageByFamily = foliageByFamily,
		Theme = terrainThemeId,
		BaseGenerated = baseGenerated,
	}
end

return ProceduralMapService
