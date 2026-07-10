local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))
local DebugLog = require(Shared:WaitForChild("DebugLog"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local player = Players.LocalPlayer
local collectCoinRemote = ReplicatedStorage:WaitForChild("Coin_PlayCollect")
local collectXpRemote = ReplicatedStorage:WaitForChild("Xp_PlayCollect")

local animatedCollectibles = {}
local hiddenCollectibles = {}
local elapsedSinceCull = 0

local function isCoinName(name)
	for _, coinName in ipairs(GameConfig.CoinTierNames or { "Coin" }) do
		if name == coinName then
			return true
		end
	end

	return false
end

local function isXpGemName(name)
	for _, gemName in ipairs(CombatConfig.XpGemTierNames) do
		if name == gemName then
			return true
		end
	end

	return false
end

local function findCoinRoot(coin)
	if coin:IsA("BasePart") then
		return coin
	end

	if not coin:IsA("Model") then
		return nil
	end

	if coin.PrimaryPart ~= nil then
		return coin.PrimaryPart
	end

	return coin:FindFirstChildWhichIsA("BasePart", true)
end

local function hasCollectibleModelAncestor(instance, collectibleName)
	local current = instance.Parent

	while current ~= nil do
		if current:IsA("Model") and current.Name == collectibleName then
			return true
		end

		current = current.Parent
	end

	return false
end

local function isCollectible(instance)
	if not isCoinName(instance.Name) and not isXpGemName(instance.Name) then
		return false
	end

	if instance:IsA("Model") then
		return findCoinRoot(instance) ~= nil
	end

	if instance:IsA("BasePart") then
		return not hasCollectibleModelAncestor(instance, instance.Name)
	end

	return false
end

local function setCoinCFrame(coin, cframe)
	if coin:IsA("Model") then
		coin:PivotTo(cframe)
	elseif coin:IsA("BasePart") then
		coin.CFrame = cframe
	end
end

local function getCoinCFrame(coin)
	if coin:IsA("Model") then
		return coin:GetPivot()
	end

	if coin:IsA("BasePart") then
		return coin.CFrame
	end

	return nil
end

local function isInstanceVisibleToCamera(instance)
	local currentCamera = Workspace.CurrentCamera

	if currentCamera == nil then
		return true
	end

	local cframe = getCoinCFrame(instance)

	if cframe == nil then
		return true
	end

	local viewportSize = currentCamera.ViewportSize
	local screenPosition, isInFront = currentCamera:WorldToViewportPoint(cframe.Position)

	if not isInFront then
		return false
	end

	local distance = (currentCamera.CFrame.Position - cframe.Position).Magnitude

	if distance > CombatConfig.CollectibleCullMaxDistance then
		return false
	end

	local margin = CombatConfig.CollectibleCullViewportMargin

	return screenPosition.X >= -margin
		and screenPosition.X <= viewportSize.X + margin
		and screenPosition.Y >= -margin
		and screenPosition.Y <= viewportSize.Y + margin
end

local function setCoinTransparency(coin, transparency)
	if coin:IsA("BasePart") then
		coin.LocalTransparencyModifier = transparency
		return
	end

	for _, descendant in ipairs(coin:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.LocalTransparencyModifier = transparency
		end
	end
end

local function setCollectibleCulled(coin, isCulled)
	if hiddenCollectibles[coin] == isCulled then
		return
	end

	hiddenCollectibles[coin] = isCulled

	if isCulled then
		setCoinTransparency(coin, 1)
	else
		setCoinTransparency(coin, 0)
	end
end

local function trackCoin(instance)
	if not isCollectible(instance) then
		return
	end

	animatedCollectibles[instance] = true
end

local function getPlayerTargetPosition(userId)
	local targetPlayer = Players:GetPlayerByUserId(userId)

	if targetPlayer == nil or targetPlayer.Character == nil then
		return nil
	end

	local root = targetPlayer.Character:FindFirstChild("HumanoidRootPart")

	if root == nil then
		return nil
	end

	return root.Position + Vector3.new(0, 2, 0)
end

for _, descendant in ipairs(Workspace:GetDescendants()) do
	trackCoin(descendant)
end

Workspace.DescendantAdded:Connect(function(descendant)
	task.defer(function()
		trackCoin(descendant)
	end)
end)

Workspace.DescendantRemoving:Connect(function(descendant)
	animatedCollectibles[descendant] = nil
	hiddenCollectibles[descendant] = nil
end)

local function updateCollectibleCulling()
	if not CombatConfig.CollectibleCullingEnabled then
		return
	end

	for coin in pairs(animatedCollectibles) do
		if coin.Parent == nil then
			animatedCollectibles[coin] = nil
			hiddenCollectibles[coin] = nil
			continue
		end

		setCollectibleCulled(coin, not isInstanceVisibleToCamera(coin))
	end
end

RunService.RenderStepped:Connect(function(deltaTime)
	elapsedSinceCull += deltaTime

	if elapsedSinceCull >= CombatConfig.CollectibleCullInterval then
		elapsedSinceCull = 0
		updateCollectibleCulling()
	end

	for coin in pairs(animatedCollectibles) do
		if coin.Parent == nil then
			animatedCollectibles[coin] = nil
			hiddenCollectibles[coin] = nil
			continue
		end

		if hiddenCollectibles[coin] then
			continue
		end

		local currentCFrame = getCoinCFrame(coin)

		if currentCFrame ~= nil then
			local rotationSpeed = GameConfig.CoinRotationSpeed

			if isXpGemName(coin.Name) then
				rotationSpeed = CombatConfig.XpGemRotationSpeed
			end

			local rotation = CFrame.Angles(0, math.rad(rotationSpeed) * deltaTime, 0)

			setCoinCFrame(coin, currentCFrame * rotation)
		end
	end
end)

local function playCollectAnimation(coin, collectorUserId, duration)
	if coin == nil or coin.Parent == nil then
		return
	end

	DebugLog.ThrottledInfo("UI", "collectible_animation", 0.5, "Animation collectible recue", {
		Collectible = coin,
		CollectorUserId = collectorUserId,
		Duration = duration,
	})

	animatedCollectibles[coin] = nil
	hiddenCollectibles[coin] = nil

	local startCFrame = getCoinCFrame(coin)

	if startCFrame == nil then
		return
	end

	local startedAt = os.clock()

	task.spawn(function()
		while coin.Parent ~= nil do
			local alpha = math.clamp((os.clock() - startedAt) / duration, 0, 1)
			local targetPosition = getPlayerTargetPosition(collectorUserId)

			if targetPosition == nil then
				targetPosition = startCFrame.Position + Vector3.new(0, 3, 0)
			end

			local easedAlpha = 1 - ((1 - alpha) * (1 - alpha))
			local currentPosition = startCFrame.Position:Lerp(targetPosition, easedAlpha)
			local spin = CFrame.Angles(0, math.rad(720) * alpha, 0)

			setCoinCFrame(coin, CFrame.new(currentPosition) * spin)
			setCoinTransparency(coin, alpha)

			if alpha >= 1 then
				break
			end

			RunService.RenderStepped:Wait()
		end

		if collectorUserId == player.UserId then
			-- Petite confirmation locale: l'UI serveur mettra le compteur a jour juste apres.
			setCoinTransparency(coin, 1)
		end
	end)
end

collectCoinRemote.OnClientEvent:Connect(playCollectAnimation)
collectXpRemote.OnClientEvent:Connect(playCollectAnimation)

DebugLog.Info("UI", "Animation collectibles initialisee", {
	Player = player.Name,
	CullingEnabled = CombatConfig.CollectibleCullingEnabled,
})
