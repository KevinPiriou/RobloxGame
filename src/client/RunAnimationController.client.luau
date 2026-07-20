-- Course locale additive. Le serveur conserve integralement le mouvement et les etats du Humanoid.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

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
		return
	end

	local speed = getMoveSpeed(humanoid, character)
	local minimumSpeed = math.max(0.1, CombatConfig.PlayerRunAnimationMinSpeed or 2.5)
	local blendAlpha = math.clamp(deltaTime * math.max(1, CombatConfig.PlayerRunAnimationBlendSpeed or 12), 0, 1)
	local isRunning = CombatConfig.PlayerRunAnimationEnabled == true
		and humanoid.MoveDirection.Magnitude > 0.05
		and speed >= minimumSpeed
		and isGrounded(humanoid)

	if not isRunning then
		resetPose(jointMap, blendAlpha)
		return
	end

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
end

player.CharacterAdded:Connect(bindCharacter)

if player.Character ~= nil then
	task.defer(bindCharacter, player.Character)
end

RunService:BindToRenderStep(RENDER_STEP_NAME, Enum.RenderPriority.Character.Value + 1, updateRunPose)

script.Destroying:Connect(function()
	RunService:UnbindFromRenderStep(RENDER_STEP_NAME)
end)
