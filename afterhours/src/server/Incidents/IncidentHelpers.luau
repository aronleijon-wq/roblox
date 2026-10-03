-- Hjälpfunktioner som flera incidenter delar.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local IncidentHelpers = {}

-- Spelare (levande) inom en låda.
function IncidentHelpers.playersIn(ctx, cframe: CFrame, size: Vector3): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		local position = ctx.services.Security.position(player)
		if position and ctx.services.World.insideBox(cframe, size, position) then
			table.insert(list, player)
		end
	end
	return list
end

-- När en dörr stängs: ge de som är inne en stund att komma ut.
function IncidentHelpers.letOut(ctx, cframe: CFrame, size: Vector3, gateId: string, seconds: number)
	for _, player in IncidentHelpers.playersIn(ctx, cframe, size) do
		ctx.services.World.grant(player, gateId, seconds)
		ctx.services.State.notify(player, "warning", nil, "The door is closing. You have a moment to get out.", 5)
	end
end

-- Rummets lampa (de små tillbyggnaderna har en släckt lampa i taket).
function IncidentHelpers.setRoomLight(room, on: boolean, color: Color3?)
	if not room or not room.bulb then
		return
	end
	local bulb = room.bulb :: BasePart
	bulb.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
	bulb.Color = if on then (color or Color3.fromRGB(255, 220, 170)) else Color3.fromRGB(60, 56, 50)
	local light = bulb:FindFirstChild("RoomLight")
	if light and light:IsA("PointLight") then
		light.Brightness = if on then 1.4 else 0
		if color then
			light.Color = color
		end
	end
end

-- En polisspärr tvärs över en gata (LOCKDOWN).
function IncidentHelpers.barrier(spec): Model
	local model = Instance.new("Model")
	model.Name = "PoliceLine"
	local wall = Instance.new("Part")
	wall.Name = "Barrier"
	wall.Size = spec.size
	wall.CFrame = spec.cframe
	wall.Anchored = true
	wall.Material = Enum.Material.ForceField
	wall.Color = Color3.fromRGB(255, 50, 60)
	wall.Transparency = 0.2
	wall.CastShadow = false
	wall.Parent = model
	for k = -1, 1 do
		local sawhorse = Instance.new("Part")
		sawhorse.Name = "Sawhorse"
		sawhorse.Size = Vector3.new(6, 2.5, 1)
		sawhorse.CFrame = spec.cframe * CFrame.new(k * 10, -spec.size.Y / 2 + 1.8, 1.4)
		sawhorse.Anchored = true
		sawhorse.Color = Color3.fromRGB(240, 240, 235)
		sawhorse.Material = Enum.Material.SmoothPlastic
		sawhorse.Parent = model
		local stripe = Instance.new("Part")
		stripe.Name = "Stripe"
		stripe.Size = Vector3.new(6.05, 0.6, 1.05)
		stripe.CFrame = sawhorse.CFrame * CFrame.new(0, 0.5, 0)
		stripe.Anchored = true
		stripe.CanCollide = false
		stripe.Color = Color3.fromRGB(220, 40, 40)
		stripe.Material = Enum.Material.Neon
		stripe.Parent = model
	end
	local beacon = Instance.new("Part")
	beacon.Name = "Beacon"
	beacon.Size = Vector3.new(1, 1, 1)
	beacon.CFrame = spec.cframe * CFrame.new(0, spec.size.Y / 2 + 0.6, 0)
	beacon.Anchored = true
	beacon.CanCollide = false
	beacon.Material = Enum.Material.Neon
	beacon.Color = Color3.fromRGB(60, 120, 255)
	beacon:AddTag("AH_FlickerLight")
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(80, 130, 255)
	light.Range = 30
	light.Brightness = 2
	light.Parent = beacon
	beacon.Parent = model
	model.Parent = Workspace
	return model
end

-- Närmaste rum för SOMETHING INSIDE till en position.
function IncidentHelpers.nearestTwistRoom(ctx, position: Vector3, maxDistance: number)
	local best, bestDistance = nil, maxDistance
	for _, room in ctx.world.twistRooms do
		local distance = (room.center - position).Magnitude
		if distance < bestDistance then
			best, bestDistance = room, distance
		end
	end
	return best
end

return IncidentHelpers
