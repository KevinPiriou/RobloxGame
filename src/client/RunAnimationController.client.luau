-- Course locale additive. Le serveur conserve integralement le mouvement et les etats du Humanoid.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

-- Témoin visible uniquement dans Studio : l'attribut local seul n'apparait pas
-- dans la vue serveur de l'Explorer pendant un Play Test.
local debugLabel: TextLabel? = nil
local isCustomRunLayerEnabled = true

if RunService:IsStudio() then
	local playerGui = player:WaitForChild("PlayerGui")
	local previousOverlay = playerGui:FindFirstChild("MegaRobloxRunAnimationDebug")

	if previousOverlay ~= nil then
		previousOverlay:Destroy()
	end

	local overlay = Instance.new("ScreenGui")
	overlay.Name = "MegaRobloxRunAnimationDebug"
	overlay.ResetOnSpawn = false
	overlay.IgnoreGuiInset = false
	overlay.DisplayOrder = 500
	overlay.Parent = playerGui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Position = UDim2.fromOffset(18, 66)
	panel.Size = UDim2.fromOffset(172, 60)
	panel.BackgroundColor3 = Color3.fromRGB(8, 15, 26)
	panel.BackgroundTransparency = 0.16
	panel.BorderSizePixel = 0
	panel.Parent = overlay

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 5)
	corner.Parent = panel

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(80, 220, 255)
	stroke.Transparency = 0.2
	stroke.Thickness = 1
	stroke.Parent = panel

	local label = Instance.new("TextLabel")
	label.Name = "State"
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(9, 0)
	label.Size = UDim2.new(1, -18, 0, 28)
	label.Font = Enum.Font.GothamBold
	label.Text = "COURSE : BOOT"
	label.TextColor3 = Color3.fromRGB(245, 246, 255)
	label.TextSize = 12
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = panel
	debugLabel = label

	local modeButton = Instance.new("TextButton")
	modeButton.Name = "ModeSelector"
	modeButton.Position = UDim2.fromOffset(6, 31)
	modeButton.Size = UDim2.new(1, -12, 0, 23)
	modeButton.BackgroundColor3 = Color3.fromRGB(24, 77, 106)
	modeButton.BackgroundTransparency = 0.05
	modeButton.BorderSizePixel = 0
	modeButton.AutoButtonColor = false
	modeButton.Font = Enum.Font.GothamBold
	modeButton.Text = "ANIM : CUSTOM"
	modeButton.TextColor3 = Color3.fromRGB(245, 246, 255)
	modeButton.TextSize = 11
	modeButton.Parent = panel

	local modeCorner = Instance.new("UICorner")
	modeCorner.CornerRadius = UDim.new(0, 4)
	modeCorner.Parent = modeButton

	local modeStroke = Instance.new("UIStroke")
	modeStroke.Color = Color3.fromRGB(110, 231, 255)
	modeStroke.Transparency = 0.35
	modeStroke.Thickness = 1
	modeStroke.Parent = modeButton

	modeButton.Activated:Connect(function()
		isCustomRunLayerEnabled = not isCustomRunLayerEnabled
		modeButton.Text = if isCustomRunLayerEnabled then "ANIM : CUSTOM" else "ANIM : DEFAULT"
		modeButton.BackgroundColor3 = if isCustomRunLayerEnabled
			then Color3.fromRGB(24, 77, 106)
			else Color3.fromRGB(48, 54, 68)
	end)

end

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))

type JointMap = {
	Root: Motor6D?,
	Waist: Motor6D?,
	Neck: Motor6D?,
	LeftShoulder: Motor6D?,
	RightShoulder: Motor6D?,
	LeftElbow: Motor6D?,
	RightElbow: Motor6D?,
	LeftHip: Motor6D?,
	RightHip: Motor6D?,
	LeftKnee: Motor6D?,
	RightKnee: Motor6D?,
	LeftAnkle: Motor6D?,
	RightAnkle: Motor6D?,
}

local RENDER_STEP_NAME = "MegaRobloxRunAnimation"
local currentCharacter: Model? = nil
local currentHumanoid: Humanoid? = nil
local joints: JointMap? = nil
local strideTime = 0
local currentState = "Unavailable"

local function setAnimationState(state: string)
	if currentState == state then
		return
	end

	currentState = state

	if debugLabel ~= nil and debugLabel.Parent ~= nil then
		debugLabel.Text = "COURSE : " .. string.upper(state)
	end

	if currentCharacter ~= nil and currentCharacter.Parent ~= nil then
		-- Attribut local de diagnostic : il permet de verifier le cycle sans bruit console.
		currentCharacter:SetAttribute("MegaRobloxRunAnimationState", state)
	end
end

local function findJointByPart1(character: Model, names: { string }): Motor6D?
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("Motor6D") and descendant.Part1 ~= nil then
			for _, name in ipairs(names) do
				if descendant.Part1.Name == name then
					return descendant
				end
			end
		end
	end

	return nil
end

local function getJointMap(character: Model): JointMap
	return {
		Root = findJointByPart1(character, { "LowerTorso", "Torso" }),
		Waist = findJointByPart1(character, { "UpperTorso" }),
		Neck = findJointByPart1(character, { "Head" }),
		LeftShoulder = findJointByPart1(character, { "LeftUpperArm", "Left Arm" }),
		RightShoulder = findJointByPart1(character, { "RightUpperArm", "Right Arm" }),
		LeftElbow = findJointByPart1(character, { "LeftLowerArm" }),
		RightElbow = findJointByPart1(character, { "RightLowerArm" }),
		LeftHip = findJointByPart1(character, { "LeftUpperLeg", "Left Leg" }),
		RightHip = findJointByPart1(character, { "RightUpperLeg", "Right Leg" }),
		LeftKnee = findJointByPart1(character, { "LeftLowerLeg" }),
		RightKnee = findJointByPart1(character, { "RightLowerLeg" }),
		LeftAnkle = findJointByPart1(character, { "LeftFoot" }),
		RightAnkle = findJointByPart1(character, { "RightFoot" }),
	}
end

local function isGrounded(humanoid: Humanoid): boolean
	local state = humanoid:GetState()

	return humanoid.FloorMaterial ~= Enum.Material.Air
		and state ~= Enum.HumanoidStateType.Jumping
		and state ~= Enum.HumanoidStateType.Freefall
		and state ~= Enum.HumanoidStateType.Climbing
		and state ~= Enum.HumanoidStateType.Swimming
end

local function getMoveSpeed(humanoid: Humanoid, character: Model): number
	local root = character:FindFirstChild("HumanoidRootPart")

	if root ~= nil and root:IsA("BasePart") then
		local horizontalVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z)
		return horizontalVelocity.Magnitude
	end

	return humanoid.MoveDirection.Magnitude * humanoid.WalkSpeed
end

local function blendJoint(joint: Motor6D?, target: CFrame, alpha: number)
	if joint ~= nil and joint.Parent ~= nil then
		joint.Transform = joint.Transform:Lerp(target, alpha)
	end
end

local function resetPose(jointMap: JointMap, alpha: number)
	blendJoint(jointMap.Root, CFrame.new(), alpha)
	blendJoint(jointMap.Waist, CFrame.new(), alpha)
	blendJoint(jointMap.Neck, CFrame.new(), alpha)
	blendJoint(jointMap.LeftShoulder, CFrame.new(), alpha)
	blendJoint(jointMap.RightShoulder, CFrame.new(), alpha)
	blendJoint(jointMap.LeftElbow, CFrame.new(), alpha)
	blendJoint(jointMap.RightElbow, CFrame.new(), alpha)
	blendJoint(jointMap.LeftHip, CFrame.new(), alpha)
	blendJoint(jointMap.RightHip, CFrame.new(), alpha)
	blendJoint(jointMap.LeftKnee, CFrame.new(), alpha)
	blendJoint(jointMap.RightKnee, CFrame.new(), alpha)
	blendJoint(jointMap.LeftAnkle, CFrame.new(), alpha)
	blendJoint(jointMap.RightAnkle, CFrame.new(), alpha)
end

local function updateRunPose(deltaTime: number)
	local character = currentCharacter
	local humanoid = currentHumanoid
	local jointMap = joints

	if character == nil or humanoid == nil or jointMap == nil then
		setAnimationState("Unavailable")
		return
	end

	local speed = getMoveSpeed(humanoid, character)
	local minimumSpeed = math.max(0.1, CombatConfig.PlayerRunAnimationMinSpeed or 2.5)
	local blendAlpha = math.clamp(deltaTime * math.max(1, CombatConfig.PlayerRunAnimationBlendSpeed or 12), 0, 1)
	local isRunning = isCustomRunLayerEnabled
		and CombatConfig.PlayerRunAnimationEnabled == true
		and humanoid.MoveDirection.Magnitude > 0.05
		and speed >= minimumSpeed
		and isGrounded(humanoid)

	if not isRunning then
		resetPose(jointMap, blendAlpha)
		if not isCustomRunLayerEnabled then
			setAnimationState("Default")
		else
			setAnimationState(CombatConfig.PlayerRunAnimationEnabled == true and "Idle" or "Disabled")
		end
		return
	end

	setAnimationState("Running")

	local maxSpeed = math.max(minimumSpeed + 0.1, humanoid.WalkSpeed)
	local intensity = math.clamp((speed - minimumSpeed) / (maxSpeed - minimumSpeed), 0.38, 1)
	local strideHz = CombatConfig.PlayerRunAnimationBaseStrideHz
		+ ((CombatConfig.PlayerRunAnimationMaxStrideHz - CombatConfig.PlayerRunAnimationBaseStrideHz) * intensity)

	strideTime += deltaTime * strideHz * math.pi * 2

	local stride = math.sin(strideTime)
	local counterStride = -stride
	local lift = math.abs(math.cos(strideTime))
	local armDegrees = CombatConfig.PlayerRunAnimationArmDegrees * intensity
	local legDegrees = CombatConfig.PlayerRunAnimationLegDegrees * intensity
	local kneeDegrees = CombatConfig.PlayerRunAnimationKneeDegrees * intensity
	local torsoLeanRadians = math.rad(CombatConfig.PlayerRunAnimationTorsoLeanDegrees * intensity)
	local bob = (lift - 0.5) * 0.055 * intensity

	blendJoint(
		jointMap.Root,
		CFrame.new(0, bob, 0) * CFrame.Angles(torsoLeanRadians * 0.45, 0, math.rad(stride * 1.2 * intensity)),
		blendAlpha
	)
	blendJoint(
		jointMap.Waist,
		CFrame.Angles(-torsoLeanRadians, 0, math.rad(counterStride * 2.2 * intensity)),
		blendAlpha
	)
	blendJoint(jointMap.Neck, CFrame.Angles(math.rad(3 * intensity), 0, math.rad(stride * 1.4 * intensity)), blendAlpha)

	blendJoint(jointMap.LeftShoulder, CFrame.Angles(math.rad(counterStride * armDegrees), 0, math.rad(-8 * intensity)), blendAlpha)
	blendJoint(jointMap.RightShoulder, CFrame.Angles(math.rad(stride * armDegrees), 0, math.rad(8 * intensity)), blendAlpha)
	blendJoint(jointMap.LeftElbow, CFrame.Angles(math.rad(-12 - (math.max(0, counterStride) * 9)), 0, 0), blendAlpha)
	blendJoint(jointMap.RightElbow, CFrame.Angles(math.rad(-12 - (math.max(0, stride) * 9)), 0, 0), blendAlpha)

	blendJoint(jointMap.LeftHip, CFrame.Angles(math.rad(stride * legDegrees), 0, 0), blendAlpha)
	blendJoint(jointMap.RightHip, CFrame.Angles(math.rad(counterStride * legDegrees), 0, 0), blendAlpha)
	blendJoint(jointMap.LeftKnee, CFrame.Angles(math.rad(math.max(0, counterStride) * kneeDegrees), 0, 0), blendAlpha)
	blendJoint(jointMap.RightKnee, CFrame.Angles(math.rad(math.max(0, stride) * kneeDegrees), 0, 0), blendAlpha)
	blendJoint(jointMap.LeftAnkle, CFrame.Angles(math.rad(math.max(0, stride) * -8), 0, 0), blendAlpha)
	blendJoint(jointMap.RightAnkle, CFrame.Angles(math.rad(math.max(0, counterStride) * -8), 0, 0), blendAlpha)
end

local function bindCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 8)

	if humanoid == nil or not humanoid:IsA("Humanoid") then
		return
	end

	currentCharacter = character
	currentHumanoid = humanoid
	joints = getJointMap(character)
	strideTime = 0
	setAnimationState("Ready")
end

player.CharacterAdded:Connect(bindCharacter)

if player.Character ~= nil then
	task.defer(bindCharacter, player.Character)
end

RunService:BindToRenderStep(RENDER_STEP_NAME, Enum.RenderPriority.Character.Value + 1, updateRunPose)

script.Destroying:Connect(function()
	RunService:UnbindFromRenderStep(RENDER_STEP_NAME)
end)
