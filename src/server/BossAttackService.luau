local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BossConfig = require(Shared:WaitForChild("BossConfig"))
local DebugLog = require(Shared:WaitForChild("DebugLog"))

local CombatStateService = require(script.Parent:WaitForChild("CombatStateService"))
local MonsterService = require(script.Parent:WaitForChild("MonsterService"))
local PerkService = require(script.Parent:WaitForChild("PerkService"))
local RunAnalyticsService = require(script.Parent:WaitForChild("RunAnalyticsService"))
local RunStateService = require(script.Parent:WaitForChild("RunStateService"))
local TemplateService = require(script.Parent:WaitForChild("TemplateService"))
local WorldSpawnService = require(script.Parent:WaitForChild("WorldSpawnService"))

local BossAttackService = {}

local rng = Random.new()
local activeAttacksByUserId = {}
local attackFolder = nil
local heartbeatConnection = nil

local function getAttackFolder()
	if attackFolder ~= nil and attackFolder.Parent ~= nil then
		return attackFolder
	end

	local combatRuntime = TemplateService.GetCombatRuntimeFolder()
	attackFolder = combatRuntime:FindFirstChild("BossAttacks")

	if attackFolder == nil then
		attackFolder = Instance.new("Folder")
		attackFolder.Name = "BossAttacks"
		attackFolder.Parent = combatRuntime
	end

	return attackFolder
end

local function findRoot(monster)
	if monster == nil then
		return nil
	end

	if monster:IsA("BasePart") then
		return monster
	end

	if monster:IsA("Model") and monster.PrimaryPart ~= nil then
		return monster.PrimaryPart
	end

	local root = monster:FindFirstChild("HumanoidRootPart", true)

	if root == nil then
		root = monster:FindFirstChild("RootPart", true)
	end

	if root == nil then
		root = monster:FindFirstChildWhichIsA("BasePart", true)
	end

	if root ~= nil and root:IsA("BasePart") and monster:IsA("Model") then
		monster.PrimaryPart = root
	end

	return if root ~= nil and root:IsA("BasePart") then root else nil
end

local function getPlayerRoot(player)
	local character = player.Character

	if character == nil then
		return nil
	end

	return character:FindFirstChild("HumanoidRootPart")
end

local function getPlayerHumanoid(player)
	local character = player.Character

	if character == nil then
		return nil
	end

	return character:FindFirstChildOfClass("Humanoid")
end

local function getForwardDirection(root, player)
	local forward = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)

	if forward.Magnitude > 0.1 then
		return forward.Unit
	end

	local playerRoot = getPlayerRoot(player)

	if playerRoot == nil then
		return Vector3.new(0, 0, 1)
	end

	local toPlayer = playerRoot.Position - root.Position
	local horizontal = Vector3.new(toPlayer.X, 0, toPlayer.Z)

	return if horizontal.Magnitude > 0.1 then horizontal.Unit else Vector3.new(0, 0, 1)
end

local function createBubble(position, verticalOffset)
	local radius = BossConfig.ConeAttackBubbleRadius
	local diameter = radius * 2
	local bubble = Instance.new("Part")
	bubble.Name = "BossConeBubble"
	bubble.Shape = Enum.PartType.Ball
	bubble.Size = Vector3.new(diameter, diameter, diameter)
	bubble.Position = position + Vector3.new(0, verticalOffset or (radius * 0.35), 0)
	bubble.Anchored = true
	bubble.CanCollide = false
	bubble.CanTouch = false
	bubble.CanQuery = false
	bubble.Material = Enum.Material.Neon
	bubble.Color = Color3.fromRGB(236, 52, 61)
	bubble.Transparency = 0.72
	bubble.Parent = getAttackFolder()

	TweenService:Create(bubble, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(diameter * 1.18, diameter * 1.18, diameter * 1.18),
		Transparency = 0.6,
	}):Play()

	return bubble
end

local function getGroundPosition(root, candidatePosition)
	return WorldSpawnService.FindSurfacePositionAtXZ(candidatePosition.X, candidatePosition.Z, {
		Center = root.Position,
		RaycastHeight = BossConfig.ConeAttackGroundRaycastHeight,
		RaycastDepth = BossConfig.ConeAttackGroundRaycastDepth,
		ExcludeInstances = { root.Parent, getAttackFolder() },
		RejectedSurfaceNameContains = {
			"MurInvisible",
		},
	})
end

local function clearTelegraph(telegraph)
	if telegraph == nil then
		return
	end

	local function clearBubbles(bubbles)
		for _, bubbleState in ipairs(bubbles) do
			if bubbleState.Part.Parent ~= nil then
				bubbleState.Part:Destroy()
			end
		end
	end

	if telegraph.Type == "SequentialCone" then
		for _, row in ipairs(telegraph.Rows) do
			clearBubbles(row.Bubbles)
		end
	else
		clearBubbles(telegraph.Bubbles)
	end
end

local function getConeAttackCooldown()
	local minimum = math.max(0.1, BossConfig.ConeAttackCooldownMin or 4)
	local maximum = math.max(minimum, BossConfig.ConeAttackCooldownMax or minimum)

	return rng:NextNumber(minimum, maximum)
end

local function getTargetedSeriesInterval()
	local minimum = math.max(0.05, BossConfig.TargetedSeriesIntervalMin or 0.2)
	local maximum = math.max(minimum, BossConfig.TargetedSeriesIntervalMax or minimum)

	return rng:NextNumber(minimum, maximum)
end

local function createConeRow(root, origin, forward, right, rowIndex)
	local rowDistance = BossConfig.ConeAttackStartDistance + ((rowIndex - 1) * BossConfig.ConeAttackRowDistance)

	if rowDistance > BossConfig.ConeAttackMaxDistance then
		return {}
	end

	local rowCenter = origin + (forward * rowDistance)
	local bubbles = {}

	for column = 1, rowIndex do
		local lateralOffset = (column - ((rowIndex + 1) * 0.5)) * BossConfig.ConeAttackBubbleSpacing
		local candidatePosition = rowCenter + (right * lateralOffset)
		local groundPosition = getGroundPosition(root, candidatePosition)

		if groundPosition ~= nil then
			table.insert(bubbles, {
				Part = createBubble(groundPosition),
				Position = groundPosition,
			})
		end
	end

	return bubbles
end

local function explodeBubbles(player, state, telegraph, bubbles)
	local playerRoot = getPlayerRoot(player)
	local humanoid = getPlayerHumanoid(player)

	for _, bubbleState in ipairs(bubbles) do
		local bubble = bubbleState.Part

		if bubble.Parent ~= nil then
			TweenService:Create(bubble, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = bubble.Size * 1.8,
				Transparency = 1,
			}):Play()
			task.delay(0.2, function()
				if bubble.Parent ~= nil then
					bubble:Destroy()
				end
			end)
		end

		if not telegraph.DidHitPlayer and playerRoot ~= nil and humanoid ~= nil and humanoid.Health > 0 then
			local offset = playerRoot.Position - bubbleState.Position
			local horizontalDistance = Vector2.new(offset.X, offset.Z).Magnitude

			if horizontalDistance <= BossConfig.ConeAttackHitRadius then
				local incomingDamage, shieldAbsorbed = PerkService.CalculateIncomingDamage(player, state.ConeDamage)

				if incomingDamage > 0 then
					humanoid:TakeDamage(incomingDamage)
				end

				RunAnalyticsService.RecordDamageTaken(player, incomingDamage, shieldAbsorbed)

				telegraph.DidHitPlayer = true
			end
		end
	end
end

local function startSimultaneousCone(player, state, now, root, origin, forward, right)
	local bubbles = {}

	for row = 1, BossConfig.ConeAttackRows do
		for _, bubbleState in ipairs(createConeRow(root, origin, forward, right, row)) do
			table.insert(bubbles, bubbleState)
		end
	end

	state.Telegraph = {
		Type = "SimultaneousCone",
		Bubbles = bubbles,
		DidHitPlayer = false,
		ExplodeAt = now + BossConfig.ConeAttackTelegraphDuration,
	}

	DebugLog.Info("Boss", "Pattern cone simultane prepare", {
		Player = player.Name,
		Boss = state.Boss,
		Bubbles = #bubbles,
	})
end

local function startSequentialCone(player, state, now, root, origin, forward, right)
	state.Telegraph = {
		Type = "SequentialCone",
		Rows = {},
		NextRowIndex = 1,
		NextRowAt = now,
		Root = root,
		Origin = origin,
		Forward = forward,
		Right = right,
		DidHitPlayer = false,
	}

	DebugLog.Info("Boss", "Pattern cone sequentiel prepare", {
		Player = player.Name,
		Boss = state.Boss,
		Rows = BossConfig.ConeAttackRows,
	})
end

local function startTargetedSeries(player, state, now, root)
	local minimum = math.max(1, math.floor(BossConfig.TargetedSeriesMinBubbles or 2))
	local maximum = math.max(minimum, math.floor(BossConfig.TargetedSeriesMaxBubbles or minimum))

	state.Telegraph = {
		Type = "TargetedSeries",
		Bubbles = {},
		NextBubbleIndex = 1,
		BubbleCount = rng:NextInteger(minimum, maximum),
		NextBubbleAt = now,
		Root = root,
		HitCount = 0,
	}

	DebugLog.Info("Boss", "Pattern serie ciblee prepare", {
		Player = player.Name,
		Boss = state.Boss,
		Count = state.Telegraph.BubbleCount,
	})
end

local function startNextPattern(player, state, now)
	local root = findRoot(state.Boss)

	if root == nil then
		return
	end

	local forward = getForwardDirection(root, player)
	local right = Vector3.new(-forward.Z, 0, forward.X)
	local origin = root.Position

	state.NextAttackAt = now + getConeAttackCooldown()

	local patternRoll = rng:NextInteger(1, 3)

	if patternRoll == 1 then
		startSimultaneousCone(player, state, now, root, origin, forward, right)
	elseif patternRoll == 2 then
		startSequentialCone(player, state, now, root, origin, forward, right)
	else
		startTargetedSeries(player, state, now, root)
	end
end

local function updateSimultaneousCone(player, state, now)
	local telegraph = state.Telegraph

	if now < telegraph.ExplodeAt then
		return
	end

	explodeBubbles(player, state, telegraph, telegraph.Bubbles)
	state.Telegraph = nil

	DebugLog.Info("Boss", "Pattern cone simultane explose", {
		Player = player.Name,
		Hit = telegraph.DidHitPlayer,
		Damage = state.ConeDamage,
	})
end

local function updateSequentialCone(player, state, now)
	local telegraph = state.Telegraph

	if telegraph.NextRowIndex <= BossConfig.ConeAttackRows and now >= telegraph.NextRowAt then
		local rowIndex = telegraph.NextRowIndex
		local bubbles = createConeRow(telegraph.Root, telegraph.Origin, telegraph.Forward, telegraph.Right, rowIndex)

		table.insert(telegraph.Rows, {
			Bubbles = bubbles,
			ExplodeAt = now + BossConfig.ConeAttackTelegraphDuration,
			Exploded = false,
		})

		telegraph.NextRowIndex += 1
		telegraph.NextRowAt = now + BossConfig.ConeAttackSequentialRowInterval
	end

	local allRowsExploded = telegraph.NextRowIndex > BossConfig.ConeAttackRows

	for _, row in ipairs(telegraph.Rows) do
		if not row.Exploded then
			allRowsExploded = false

			if now >= row.ExplodeAt then
				explodeBubbles(player, state, telegraph, row.Bubbles)
				row.Exploded = true
			end
		end
	end

	if allRowsExploded then
		state.Telegraph = nil
		DebugLog.Info("Boss", "Pattern cone sequentiel termine", {
			Player = player.Name,
			Hit = telegraph.DidHitPlayer,
			Damage = state.ConeDamage,
		})
	end
end

local function updateTargetedSeries(player, state, now)
	local telegraph = state.Telegraph

	if telegraph.NextBubbleIndex <= telegraph.BubbleCount and now >= telegraph.NextBubbleAt then
		local playerRoot = getPlayerRoot(player)

		if playerRoot ~= nil then
			local targetPosition = playerRoot.Position

			table.insert(telegraph.Bubbles, {
				Part = createBubble(targetPosition, 0),
				Position = targetPosition,
				ExplodeAt = now + BossConfig.ConeAttackTelegraphDuration,
				Exploded = false,
			})
		end

		telegraph.NextBubbleIndex += 1
		telegraph.NextBubbleAt = now + getTargetedSeriesInterval()
	end

	local allBubblesExploded = telegraph.NextBubbleIndex > telegraph.BubbleCount

	for _, bubbleState in ipairs(telegraph.Bubbles) do
		if not bubbleState.Exploded then
			allBubblesExploded = false

			if now >= bubbleState.ExplodeAt then
				local explosionState = {
					DidHitPlayer = false,
				}

				explodeBubbles(player, state, explosionState, { bubbleState })
				bubbleState.Exploded = true

				if explosionState.DidHitPlayer then
					telegraph.HitCount += 1
				end
			end
		end
	end

	if allBubblesExploded then
		state.Telegraph = nil
		DebugLog.Info("Boss", "Pattern serie ciblee termine", {
			Player = player.Name,
			Hits = telegraph.HitCount,
			Damage = state.ConeDamage,
		})
	end
end

local function updateAttacks()
	local now = CombatStateService.GetTime()

	for userId, state in pairs(activeAttacksByUserId) do
		local player = state.Player

		if player.Parent ~= Players or not RunStateService.IsRunActive(player) or not MonsterService.IsMonsterAlive(state.Boss) then
			clearTelegraph(state.Telegraph)
			activeAttacksByUserId[userId] = nil
			continue
		end

		if CombatStateService.IsPaused() then
			continue
		end

		if state.Telegraph ~= nil then
			if state.Telegraph.Type == "SequentialCone" then
				updateSequentialCone(player, state, now)
			elseif state.Telegraph.Type == "TargetedSeries" then
				updateTargetedSeries(player, state, now)
			else
				updateSimultaneousCone(player, state, now)
			end
		elseif now >= state.NextAttackAt then
			startNextPattern(player, state, now)
		end
	end
end

function BossAttackService.Activate(player, boss, contactDamage)
	BossAttackService.Deactivate(player)

	activeAttacksByUserId[player.UserId] = {
		Player = player,
		Boss = boss,
		ConeDamage = math.max(0, contactDamage * BossConfig.ConeAttackDamageMultiplier),
		NextAttackAt = CombatStateService.GetTime() + getConeAttackCooldown(),
		Telegraph = nil,
	}
end

function BossAttackService.Deactivate(player)
	if player == nil then
		return
	end

	local state = activeAttacksByUserId[player.UserId]

	if state ~= nil then
		clearTelegraph(state.Telegraph)
		activeAttacksByUserId[player.UserId] = nil
	end
end

function BossAttackService.Start()
	if heartbeatConnection ~= nil then
		return
	end

	heartbeatConnection = RunService.Heartbeat:Connect(updateAttacks)
end

return BossAttackService
