-- Ostrava Parking: tre plan och tak, med ramper i sicksack. Stadens bästa höjdskillnader.

local Builder = require(script.Parent.Parent.Builder)

local Garage = {}

local LEVELS = { 12, 24, 36 } -- ovansidan på plan 2, plan 3 och taket

-- En platta med ett rektangulärt hål (för ramperna).
local function slab(parent: Instance, y: number, x1: number, x2: number, z1: number, z2: number, hole, color: Color3)
	local rects = {}
	if hole then
		table.insert(rects, { x1, hole.x1, z1, z2 })
		table.insert(rects, { hole.x2, x2, z1, z2 })
		table.insert(rects, { hole.x1, hole.x2, z1, hole.z1 })
		table.insert(rects, { hole.x1, hole.x2, hole.z2, z2 })
	else
		table.insert(rects, { x1, x2, z1, z2 })
	end
	for _, r in rects do
		if r[2] - r[1] > 0.01 and r[4] - r[3] > 0.01 then
			Builder.box(
				parent,
				"Deck",
				Vector3.new(r[2] - r[1], 1, r[4] - r[3]),
				CFrame.new((r[1] + r[2]) / 2, y - 0.5, (r[3] + r[4]) / 2),
				color,
				Enum.Material.Concrete
			)
		end
	end
end

local function parkedCar(ctx, parent: Instance, position: Vector3)
	local colors = {
		Color3.fromRGB(120, 24, 30),
		Color3.fromRGB(30, 50, 90),
		Color3.fromRGB(190, 190, 195),
		Color3.fromRGB(28, 28, 32),
	}
	local color = ctx.rng:pick(colors) :: Color3
	Builder.box(
		parent,
		"CarBody",
		Vector3.new(6, 2.2, 13),
		CFrame.new(position + Vector3.new(0, 2, 0)),
		color,
		Enum.Material.SmoothPlastic
	)
	Builder.box(
		parent,
		"CarCabin",
		Vector3.new(5.6, 2, 7),
		CFrame.new(position + Vector3.new(0, 4, 0.5)),
		Color3.fromRGB(20, 24, 30),
		Enum.Material.Glass
	)
end

function Garage.build(ctx, c: Vector3, _layout)
	local palette = ctx.palette
	local root = Builder.model(ctx.root, "OstravaParking")
	local top = ctx.config.sidewalkHeight
	local x1, x2 = c.X - 52, c.X + 52
	local z1, z2 = c.Z - 52, c.Z + 52
	local concrete = Color3.fromRGB(128, 128, 124)
	local east = { x1 = c.X + 36, x2 = c.X + 48, z1 = c.Z - 20, z2 = c.Z + 40 }
	local west = { x1 = c.X - 48, x2 = c.X - 36, z1 = c.Z - 40, z2 = c.Z + 20 }

	-- Plan och ramper
	slab(root, LEVELS[1], x1, x2, z1, z2, east, concrete)
	slab(root, LEVELS[2], x1, x2, z1, z2, west, concrete)
	slab(root, LEVELS[3], x1, x2, z1, z2, east, concrete)
	Builder.ramp(
		root,
		"Ramp",
		Vector3.new(c.X + 42, top, c.Z + 40),
		Vector3.new(c.X + 42, LEVELS[1], c.Z - 20),
		11.6,
		palette.ConcreteDark,
		Enum.Material.Concrete
	)
	Builder.ramp(
		root,
		"Ramp",
		Vector3.new(c.X - 42, LEVELS[1], c.Z - 40),
		Vector3.new(c.X - 42, LEVELS[2], c.Z + 20),
		11.6,
		palette.ConcreteDark,
		Enum.Material.Concrete
	)
	Builder.ramp(
		root,
		"Ramp",
		Vector3.new(c.X + 42, LEVELS[2], c.Z + 40),
		Vector3.new(c.X + 42, LEVELS[3], c.Z - 20),
		11.6,
		palette.ConcreteDark,
		Enum.Material.Concrete
	)

	-- Pelare, räcken och lysrör på varje plan
	local floors = { top, LEVELS[1], LEVELS[2] }
	for index, floorY in floors do
		local ceiling = LEVELS[index] - 1
		for _, px in { -30, -8, 14, 32 } do
			for _, pz in { -42, -14, 14, 42 } do
				Builder.box(
					root,
					"Column",
					Vector3.new(1.6, ceiling - floorY, 1.6),
					CFrame.new(c.X + px, (floorY + ceiling) / 2, c.Z + pz),
					concrete,
					Enum.Material.Concrete
				)
			end
		end
		for _, pz in { -26, 26 } do
			for _, px in { -20, 22 } do
				local tube = Builder.decor(
					root,
					"Fluorescent",
					Vector3.new(6, 0.25, 0.6),
					CFrame.new(c.X + px, ceiling - 0.2, c.Z + pz),
					Color3.fromRGB(220, 240, 230),
					Enum.Material.Neon
				)
				tube:AddTag("AH_InteriorLight")
				Builder.pointLight(tube, Color3.fromRGB(210, 235, 225), 24, 0.8, false)
			end
		end
	end
	for _, level in LEVELS do
		local h = 3.4
		Builder.box(
			root,
			"Parapet",
			Vector3.new(104, h, 1),
			CFrame.new(c.X, level + h / 2, z1 + 0.5),
			concrete,
			Enum.Material.Concrete
		)
		Builder.box(
			root,
			"Parapet",
			Vector3.new(104, h, 1),
			CFrame.new(c.X, level + h / 2, z2 - 0.5),
			concrete,
			Enum.Material.Concrete
		)
		Builder.box(
			root,
			"Parapet",
			Vector3.new(1, h, 102),
			CFrame.new(x1 + 0.5, level + h / 2, c.Z),
			concrete,
			Enum.Material.Concrete
		)
		Builder.box(
			root,
			"Parapet",
			Vector3.new(1, h, 102),
			CFrame.new(x2 - 0.5, level + h / 2, c.Z),
			concrete,
			Enum.Material.Concrete
		)
		local stripe = Builder.decor(
			root,
			"LevelStripe",
			Vector3.new(104, 0.6, 0.2),
			CFrame.new(c.X, level + 1.2, z1 - 0.1),
			palette.SafetyYellow,
			Enum.Material.SmoothPlastic
		)
		local _ = stripe
	end

	-- Skylt på fasaden mot Quay St
	local sign = Builder.decor(
		root,
		"ParkingSign",
		Vector3.new(0.5, 26, 6),
		CFrame.new(x1 - 0.6, 20, c.Z),
		Color3.fromRGB(20, 40, 90),
		Enum.Material.SmoothPlastic
	)
	Builder.sign(
		sign,
		Enum.NormalId.Left,
		"P\nOSTRAVA",
		{ color = Color3.new(1, 1, 1), lit = true, font = Enum.Font.GothamBlack }
	)

	-- Biljettkur med larmpanel vid infarten
	local booth = Builder.box(
		root,
		"Booth",
		Vector3.new(5, 7, 5),
		CFrame.new(x1 + 5, top + 3.5, c.Z + 30),
		Color3.fromRGB(60, 70, 80),
		Enum.Material.Metal
	)
	local boothLed = Builder.decor(
		root,
		"AlarmLed",
		Vector3.new(0.3, 0.3, 0.3),
		booth.CFrame * CFrame.new(-2.6, 2, 0),
		Color3.fromRGB(40, 255, 80),
		Enum.Material.Neon
	)
	ctx.addAlarmPanel("AlarmGarage", "the Ostrava Parking booth", booth, boothLed)

	-- Bilar, platser och loot
	parkedCar(ctx, root, Vector3.new(c.X - 20, top, c.Z - 30))
	parkedCar(ctx, root, Vector3.new(c.X + 10, top, c.Z + 26))
	parkedCar(ctx, root, Vector3.new(c.X - 20, LEVELS[1], c.Z + 30))
	parkedCar(ctx, root, Vector3.new(c.X + 20, LEVELS[1], c.Z - 34))
	parkedCar(ctx, root, Vector3.new(c.X + 6, LEVELS[2], c.Z + 6))
	parkedCar(ctx, root, Vector3.new(c.X - 24, LEVELS[3], c.Z - 10))

	local function bay(id: string, label: string, position: Vector3)
		local cart = Builder.box(
			root,
			"EquipmentCart",
			Vector3.new(4, 3, 2.4),
			CFrame.new(position + Vector3.new(0, 1.5, 0)),
			Color3.fromRGB(200, 120, 30),
			Enum.Material.Metal
		)
		ctx.addSite("GarageBay", id, label, cart.CFrame * CFrame.new(0, 0, 2.6), cart)
	end
	bay("GarageL2", "Ostrava Parking, level 2", Vector3.new(c.X - 6, LEVELS[1], c.Z + 20))
	bay("GarageL3", "Ostrava Parking, level 3", Vector3.new(c.X + 18, LEVELS[2], c.Z - 30))
	bay("GarageStreet", "Ostrava Parking, street level", Vector3.new(c.X - 28, top, c.Z + 4))

	local relay = Builder.box(
		root,
		"RelayBox",
		Vector3.new(3, 4, 2),
		CFrame.new(c.X - 30, LEVELS[3] + 2, c.Z - 40),
		Color3.fromRGB(70, 76, 84),
		Enum.Material.Metal
	)
	ctx.addSite("Rooftop", "GarageRelay", "the Ostrava Parking roof", relay.CFrame * CFrame.new(0, 0, 2.5), relay)

	ctx.addLoot("Interior", Vector3.new(c.X + 26, LEVELS[1] + 0.5, c.Z + 4))
	ctx.addLoot("Interior", Vector3.new(c.X - 30, LEVELS[2] + 0.5, c.Z + 34))
	ctx.addLoot("Interior", Vector3.new(c.X + 10, LEVELS[3] + 0.5, c.Z + 30))
	ctx.addLoot("Interior", Vector3.new(c.X + 30, top + 0.5, c.Z - 44))
	return root
end

return Garage
