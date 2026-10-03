-- Hazards: ger beteende åt alla hinder via CollectionService-taggar.
-- Fungerar både för banan som CourseBuilder bygger och för delar du själv taggar i Studio.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(script.Parent.Util)

local Hazards = {}

local function attribute(part: BasePart, name: string, default: any): any
	local value = part:GetAttribute(name)
	if value == nil then
		return default
	end
	return value
end

-- KillBrick: dödar alla som nuddar den.
local function setupKillBrick(part: BasePart)
	part.Touched:Connect(function(hit)
		local humanoid = Util.getLivingHumanoid(hit)
		if humanoid then
			humanoid.Health = 0
		end
	end)
end

-- FadingPlatform: bleknar bort när någon står på den och kommer tillbaka efter en stund.
local function setupFadingPlatform(part: BasePart)
	local fadeTime = attribute(part, "FadeTime", Config.Hazards.FadeTime)
	local reappearTime = attribute(part, "ReappearTime", Config.Hazards.ReappearTime)
	local originalTransparency = part.Transparency
	local fading = false

	part.Touched:Connect(function(hit)
		if fading or not Util.getLivingHumanoid(hit) then
			return
		end
		fading = true

		local tween = TweenService:Create(part, TweenInfo.new(fadeTime), { Transparency = 1 })
		tween:Play()
		tween.Completed:Wait()
		part.CanCollide = false

		task.wait(reappearTime)
		part.CanCollide = true
		part.Transparency = originalTransparency
		fading = false
	end)
end

-- Skapar en osynlig, förankrad del på samma plats som `part`. Constraints kopplar
-- den rörliga delen till ankaret så att den rör sig med fysik och kan bära spelare.
local function createAnchor(part: BasePart, axis: Vector3): (Attachment, Attachment)
	local anchor = Instance.new("Part")
	anchor.Name = part.Name .. "Anchor"
	anchor.Size = Vector3.one
	anchor.CFrame = part.CFrame
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Parent = part.Parent

	-- Axeln i delens eget koordinatsystem. Ankaret har samma CFrame, så samma
	-- lokala CFrame ger två attachments på exakt samma plats.
	local axisFrame = Util.axisFrame(part.CFrame:VectorToObjectSpace(axis))

	local attachment0 = Instance.new("Attachment")
	attachment0.CFrame = axisFrame
	attachment0.Parent = anchor

	local attachment1 = Instance.new("Attachment")
	attachment1.CFrame = axisFrame
	attachment1.Parent = part

	return attachment0, attachment1
end

local function releaseToPhysics(part: BasePart)
	part.Anchored = false
	-- Låt servern sköta fysiken så att alla spelare ser samma rörelse.
	pcall(part.SetNetworkOwner, part, nil)
end

-- MovingPlatform: åker fram och tillbaka längs attributet MoveOffset (Vector3, i världskoordinater).
local function setupMovingPlatform(part: BasePart)
	local offset = part:GetAttribute("MoveOffset")
	if typeof(offset) ~= "Vector3" or offset.Magnitude < 0.01 then
		warn(`[Hazards] {part:GetFullName()} saknar attributet MoveOffset (Vector3)`)
		return
	end
	local moveTime = attribute(part, "MoveTime", Config.Hazards.MoveTime)
	local pause = attribute(part, "MovePause", Config.Hazards.MovePause)
	local distance = offset.Magnitude

	local attachment0, attachment1 = createAnchor(part, offset.Unit)
	local slider = Instance.new("PrismaticConstraint")
	slider.Attachment0 = attachment0
	slider.Attachment1 = attachment1
	slider.ActuatorType = Enum.ActuatorType.Servo
	slider.Speed = distance / moveTime
	slider.ServoMaxForce = 1e7
	slider.TargetPosition = 0
	slider.Parent = part
	releaseToPhysics(part)

	task.spawn(function()
		local atEnd = false
		while part:IsDescendantOf(game) do
			task.wait(pause)
			atEnd = not atEnd
			slider.TargetPosition = if atEnd then distance else 0
			task.wait(moveTime)
		end
	end)
end

-- Spinner: snurrar runt världens Y-axel genom sin mittpunkt.
local function setupSpinner(part: BasePart)
	local speed = attribute(part, "SpinSpeed", Config.Hazards.SpinSpeed)

	local attachment0, attachment1 = createAnchor(part, Vector3.yAxis)
	local motor = Instance.new("HingeConstraint")
	motor.Attachment0 = attachment0
	motor.Attachment1 = attachment1
	motor.ActuatorType = Enum.ActuatorType.Motor
	motor.AngularVelocity = speed
	motor.MotorMaxTorque = 1e9
	motor.Parent = part
	releaseToPhysics(part)
end

function Hazards.start()
	Util.bindTag(Config.Tags.KillBrick, setupKillBrick)
	Util.bindTag(Config.Tags.FadingPlatform, setupFadingPlatform)
	Util.bindTag(Config.Tags.MovingPlatform, setupMovingPlatform)
	Util.bindTag(Config.Tags.Spinner, setupSpinner)
end

return Hazards
