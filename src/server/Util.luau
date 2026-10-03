-- Små hjälpfunktioner som flera serversystem använder.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Util = {}

-- Om delen tillhör en levande karaktär (spelare eller NPC) returneras dess Humanoid.
function Util.getLivingHumanoid(part: BasePart): Humanoid?
	local model = part:FindFirstAncestorOfClass("Model")
	if not model then
		return nil
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return humanoid
	end
	return nil
end

-- Om delen tillhör en levande spelares karaktär returneras spelaren.
function Util.getPlayerFromPart(part: BasePart): Player?
	local humanoid = Util.getLivingHumanoid(part)
	if not humanoid then
		return nil
	end
	return Players:GetPlayerFromCharacter(humanoid.Parent)
end

-- Kör callback för alla delar som har taggen nu, och för alla som får den senare.
function Util.bindTag(tag: string, callback: (BasePart) -> ())
	local function onAdded(instance: Instance)
		if instance:IsA("BasePart") then
			callback(instance)
		end
	end

	for _, instance in CollectionService:GetTagged(tag) do
		task.spawn(onAdded, instance)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(onAdded)
end

-- Returnerar en CFrame vars X-axel pekar åt `axis`. Constraints (Prismatic, Hinge)
-- använder attachmentens X-axel som sin axel.
function Util.axisFrame(axis: Vector3): CFrame
	local x = axis.Unit
	local up = if math.abs(x.Y) > 0.99 then Vector3.zAxis else Vector3.yAxis
	local z = x:Cross(up).Unit
	local y = z:Cross(x)
	return CFrame.fromMatrix(Vector3.zero, x, y, z)
end

return Util
