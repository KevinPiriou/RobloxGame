--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("Weapon_DrainVfx", 30)

if remote == nil or not remote:IsA("RemoteEvent") then
	warn("[Vfx] Remote Weapon_DrainVfx introuvable")
	return
end

local channels = {}

local function findRoot(instance: Instance): BasePart?
	if instance:IsA("BasePart") then
		return instance
	end
	if instance:IsA("Model") then
		if instance.PrimaryPart ~= nil then
			return instance.PrimaryPart
		end
		local humanoidRoot = instance:FindFirstChild("HumanoidRootPart", true)
		if humanoidRoot ~= nil and humanoidRoot:IsA("BasePart") then
			return humanoidRoot
		end
	end
	return instance:FindFirstChildWhichIsA("BasePart", true)
end

local function releaseChannel(channelId: number)
	local channel = channels[channelId]
	if channel == nil then
		return
	end
	channels[channelId] = nil
	for _, visual in ipairs(channel.Visuals) do
		visual.Beam:Destroy()
		visual.Source:Destroy()
		visual.Target:Destroy()
	end
end

local function createBeam(sourceRoot: BasePart, targetRoot: BasePart)
	local source = Instance.new("Attachment")
	source.Name = "LoreleiDrainSource"
	source.Position = Vector3.new(0, 1.15, -0.35)
	source.Parent = sourceRoot

	local target = Instance.new("Attachment")
	target.Name = "LoreleiDrainTarget"
	target.Parent = targetRoot

	local beam = Instance.new("Beam")
	beam.Name = "LoreleiLifeDrain"
	beam.Attachment0 = source
	beam.Attachment1 = target
	beam.Color = ColorSequence.new(Color3.fromRGB(255, 56, 166), Color3.fromRGB(100, 8, 59))
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.12),
		NumberSequenceKeypoint.new(0.55, 0.28),
		NumberSequenceKeypoint.new(1, 0.78),
	})
	beam.Width0 = 0.32
	beam.Width1 = 0.16
	beam.LightEmission = 0.78
	beam.FaceCamera = true
	beam.TextureMode = Enum.TextureMode.Wrap
	beam.TextureSpeed = 1.4
	beam.Segments = 2
	beam.Parent = sourceRoot
	return { Beam = beam, Source = source, Target = target }
end

remote.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" or typeof(payload.ChannelId) ~= "number" then
		return
	end
	local channelId = math.max(0, math.floor(payload.ChannelId))
	if payload.Type == "Stop" then
		releaseChannel(channelId)
		return
	end
	if payload.Type ~= "Start" or typeof(payload.Targets) ~= "table" then
		return
	end

	releaseChannel(channelId)
	local sourceRoot = findRoot(player.Character or player.CharacterAdded:Wait())
	if sourceRoot == nil then
		return
	end
	local visuals = {}
	for _, target in ipairs(payload.Targets) do
		if typeof(target) == "Instance" then
			local targetRoot = findRoot(target)
			if targetRoot ~= nil then
				table.insert(visuals, createBeam(sourceRoot, targetRoot))
			end
		end
	end
	if #visuals > 0 then
		channels[channelId] = { Visuals = visuals }
	end
end)
