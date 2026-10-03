-- Lumen Theater: stängd biograf. Bara ett "ghost light" lyser på scenen, som det alltid gjort.
-- Scendörren på baksidan öppnas vid BLACKOUT (nya vägar) och för fel adress (WRONG ADDRESS).

local Builder = require(script.Parent.Parent.Builder)
local Buildings = require(script.Parent.Parent.Buildings)

local Theater = {}

function Theater.build(ctx, c: Vector3, _layout)
	local palette = ctx.palette
	local root = Builder.model(ctx.root, "LumenTheater")
	local top = ctx.config.sidewalkHeight
	local hallCenter = Vector3.new(c.X, top + 0.1, c.Z + 23)
	local hallSize = Vector3.new(80, 26, 50)

	local hall, openings = Buildings.room(ctx, root, "Auditorium", hallCenter, hallSize, {
		wallColor = Color3.fromRGB(120, 54, 46),
		wallMaterial = Enum.Material.Brick,
		floorColor = Color3.fromRGB(70, 30, 34),
		floorMaterial = Enum.Material.Carpet,
		doors = {
			{ face = "South", width = 10, height = 10, offset = 0, id = "Front" },
			{ face = "North", width = 4, height = 7, offset = 20, id = "Stage" },
		},
	})
	for _, opening in openings do
		if opening.id == "Front" then
			local doors = Builder.box(
				hall,
				"FrontDoors",
				opening.size + Vector3.new(0, 0, -0.4),
				opening.cframe,
				Color3.fromRGB(60, 30, 26),
				Enum.Material.Wood
			)
			Builder.sign(
				doors,
				Enum.NormalId.Front,
				"CLOSED",
				{ color = Color3.fromRGB(230, 200, 150), pixelsPerStud = 8 }
			)
		elseif opening.id == "Stage" then
			local stageDoor = Builder.box(
				hall,
				"StageDoor",
				Vector3.new(4, 7, 0.4),
				opening.cframe,
				Color3.fromRGB(50, 52, 56),
				Enum.Material.Metal
			)
			ctx.addGate("TheaterStage", stageDoor)
			ctx.addSite(
				"StageDoor",
				"TheaterStageDoor",
				"the Lumen Theater stage door",
				opening.cframe * CFrame.new(0, -1.5, -2.5),
				nil
			)
		end
	end

	-- Markisen med flimrande glödlampor
	local front = hallCenter.Z + hallSize.Z / 2
	local marquee = Builder.box(
		root,
		"Marquee",
		Vector3.new(44, 4, 8),
		CFrame.new(c.X, top + 13, front + 4),
		Color3.fromRGB(30, 26, 30),
		Enum.Material.Metal
	)
	Builder.sign(
		marquee,
		Enum.NormalId.Back,
		"LUMEN - CLOSED FOR RENOVATION",
		{ color = Color3.fromRGB(255, 220, 150), lit = true, font = Enum.Font.GothamBlack }
	)
	local bulbs = Builder.decor(
		root,
		"MarqueeBulbs",
		Vector3.new(44.4, 0.5, 8.4),
		CFrame.new(c.X, top + 15.2, front + 4),
		Color3.fromRGB(255, 210, 130),
		Enum.Material.Neon
	)
	bulbs:AddTag("AH_FlickerLight")
	Builder.pointLight(bulbs, Color3.fromRGB(255, 200, 120), 30, 0.9, false)
	local poster = Builder.decor(
		root,
		"Poster",
		Vector3.new(5, 7, 0.1),
		CFrame.new(c.X - 18, top + 5, front + 0.15),
		Color3.fromRGB(240, 230, 210),
		Enum.Material.SmoothPlastic
	)
	ctx.addPoster("PosterTheater", poster, Enum.NormalId.Back)
	local alarm = Builder.box(
		root,
		"AlarmPanel",
		Vector3.new(1.8, 2.4, 0.4),
		CFrame.new(c.X + 10, top + 4.5, front + 0.3),
		Color3.fromRGB(200, 200, 196),
		Enum.Material.SmoothPlastic
	)
	local alarmLed = Builder.decor(
		root,
		"AlarmLed",
		Vector3.new(0.3, 0.3, 0.3),
		alarm.CFrame * CFrame.new(0, 0.8, 0.25),
		Color3.fromRGB(40, 255, 80),
		Enum.Material.Neon
	)
	ctx.addAlarmPanel("AlarmTheater", "the Lumen Theater entrance", alarm, alarmLed)

	-- Salongen: scen, stolsrader och ett ghost light
	local stageTop = top + 4
	Builder.box(
		hall,
		"Stage",
		Vector3.new(48, 4, 16),
		CFrame.new(c.X, top + 2.1, hallCenter.Z - 16),
		Color3.fromRGB(60, 44, 34),
		Enum.Material.WoodPlanks
	)
	Builder.ramp(
		hall,
		"StageSteps",
		Vector3.new(c.X + 20, top + 0.1, hallCenter.Z - 4),
		Vector3.new(c.X + 20, stageTop + 0.1, hallCenter.Z - 8),
		4,
		Color3.fromRGB(60, 44, 34),
		Enum.Material.WoodPlanks
	)
	Builder.decor(
		hall,
		"Curtain",
		Vector3.new(48, 18, 0.6),
		CFrame.new(c.X, top + 13, hallCenter.Z - 23.6),
		Color3.fromRGB(110, 16, 24),
		Enum.Material.Fabric
	)
	for row = 0, 7 do
		for _, side in { -1, 1 } do
			Builder.box(
				hall,
				"SeatRow",
				Vector3.new(30, 2.4, 1.6),
				CFrame.new(c.X + side * 19, top + 1.3, hallCenter.Z + 2 + row * 2.6),
				Color3.fromRGB(90, 20, 30),
				Enum.Material.Fabric
			)
		end
	end
	Builder.cylinder(
		hall,
		"GhostLightStand",
		5,
		0.3,
		CFrame.new(c.X - 4, stageTop + 2.6, hallCenter.Z - 14) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(30, 30, 30),
		Enum.Material.Metal
	)
	local bulb = Builder.decor(
		hall,
		"GhostLight",
		Vector3.new(0.7, 0.9, 0.7),
		CFrame.new(c.X - 4, stageTop + 5.4, hallCenter.Z - 14),
		Color3.fromRGB(255, 226, 170),
		Enum.Material.Neon,
		{ Shape = Enum.PartType.Ball }
	)
	Builder.pointLight(bulb, Color3.fromRGB(255, 220, 160), 34, 0.9, true)
	ctx.addDiscovery("TheaterStage", CFrame.new(c.X, stageTop + 4, hallCenter.Z - 16), Vector3.new(48, 8, 16))
	ctx.addLoot("Secret", Vector3.new(c.X + 10, stageTop + 0.5, hallCenter.Z - 18))
	ctx.addLoot("Interior", Vector3.new(c.X - 37, top + 0.6, hallCenter.Z + 18))
	ctx.world.theater = { center = hallCenter }

	-- Husen norr om bakgården
	Buildings.build(ctx, root, {
		name = "NorthTower",
		center = Vector3.new(c.X - 28, 0, c.Z - 37),
		size = Vector3.new(48, 70, 38),
		color = palette.ConcreteDark,
		material = Enum.Material.Concrete,
		windows = { faces = { "North", "South", "West" }, style = "Office", litChance = 0.18 },
	})
	Buildings.build(ctx, root, {
		name = "NorthFlats",
		center = Vector3.new(c.X + 26, 0, c.Z - 37),
		size = Vector3.new(52, 44, 38),
		color = palette.Brick,
		material = Enum.Material.Brick,
		windows = { faces = { "North", "South", "East" }, style = "Residential" },
	})
	Builder.box(
		root,
		"Dumpster",
		Vector3.new(6, 4, 3.5),
		CFrame.new(c.X + 4, top + 2, c.Z - 12),
		Color3.fromRGB(40, 70, 52),
		Enum.Material.Metal
	)
	ctx.addLoot("Alley", Vector3.new(c.X - 14, top + 0.5, c.Z - 13))
	return root
end

return Theater
