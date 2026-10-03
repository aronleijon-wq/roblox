-- Streets: gatunätet, trottoarer, gatubelysning, rekvisita och stadens yttre ring.
-- Ger också gatunamn, NPC-gångvägar, elskåp (kontraktsplatser), lootpunkter och
-- platser för LOCKDOWN-spärrar.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Builder = require(script.Parent.Builder)
local Buildings = require(script.Parent.Buildings)

local Streets = {}

-- Rutnätets geometri, räknad från DistrictConfig.
function Streets.layout(config)
	local B, W = config.blockSize, config.streetWidth
	local total = config.columns * B + (config.columns + 1) * W
	local half = total / 2
	local layout = {
		half = half,
		blockSize = B,
		streetWidth = W,
		roadHalf = config.roadWidth / 2,
		platformHalf = B / 2 + (W - config.roadWidth) / 2, -- kvarter + trottoar
		avenueX = {},
		streetZ = {},
		blockCenters = {},
	}
	for i = 0, config.columns do
		layout.avenueX[i + 1] = -half + W / 2 + i * (B + W)
	end
	for i = 0, config.rows do
		layout.streetZ[i + 1] = -half + W / 2 + i * (B + W)
	end
	for col = 1, config.columns do
		layout.blockCenters[col] = {}
		for row = 1, config.rows do
			local x = (layout.avenueX[col] + layout.avenueX[col + 1]) / 2
			local z = (layout.streetZ[row] + layout.streetZ[row + 1]) / 2
			layout.blockCenters[col][row] = Vector3.new(x, 0, z)
		end
	end
	return layout
end

local function streetLight(ctx, parent: Instance, base: Vector3, facing: Vector3)
	local palette = ctx.palette
	local pole = Builder.cylinder(
		parent,
		"LampPole",
		16,
		0.6,
		CFrame.new(base + Vector3.new(0, 8, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(40, 42, 48),
		Enum.Material.Metal
	)
	pole.CastShadow = false
	local armEnd = base + Vector3.new(0, 15.6, 0) + facing * 3
	Builder.decor(
		parent,
		"LampArm",
		Vector3.new(0.4, 0.4, 3.2),
		Builder.lookAt(base + Vector3.new(0, 15.6, 0) + facing * 1.6, armEnd),
		Color3.fromRGB(40, 42, 48),
		Enum.Material.Metal
	)
	local head = Builder.decor(
		parent,
		"LampHead",
		Vector3.new(1.6, 0.5, 2.4),
		Builder.lookAt(armEnd - Vector3.new(0, 0.3, 0), armEnd - Vector3.new(0, 0.3, 0) + facing),
		palette.StreetLamp,
		Enum.Material.Neon
	)
	head:AddTag(Constants.Tags.StreetLight)
	local light = Builder.pointLight(head, palette.StreetLamp, 34, 1.4, false)
	light.Name = "Light"
	-- Nödljus som bara tänds vid strömavbrott (klienten tänder dem).
	local emergency = Builder.decor(
		parent,
		"EmergencyLamp",
		Vector3.new(0.6, 0.6, 0.6),
		CFrame.new(base + Vector3.new(0, 10, 0) + facing * 0.5),
		Color3.fromRGB(60, 10, 10),
		Enum.Material.SmoothPlastic
	)
	emergency:AddTag(Constants.Tags.EmergencyLight)
	local eLight = Builder.pointLight(emergency, palette.Emergency, 20, 0, false)
	eLight.Name = "Light"
	return head
end

local function car(ctx, parent: Instance, position: Vector3, yaw: number)
	local colors = {
		Color3.fromRGB(120, 24, 30),
		Color3.fromRGB(30, 50, 90),
		Color3.fromRGB(190, 190, 195),
		Color3.fromRGB(28, 28, 32),
		Color3.fromRGB(60, 90, 70),
		Color3.fromRGB(200, 160, 60),
	}
	local color = ctx.rng:pick(colors) :: Color3
	local model = Builder.model(parent, "ParkedCar")
	local base = CFrame.new(position) * CFrame.Angles(0, yaw, 0)
	Builder.box(model, "Body", Vector3.new(6, 2.2, 13), base * CFrame.new(0, 2, 0), color, Enum.Material.SmoothPlastic)
	Builder.box(
		model,
		"Cabin",
		Vector3.new(5.6, 2, 7),
		base * CFrame.new(0, 4, 0.5),
		Color3.fromRGB(20, 24, 30),
		Enum.Material.Glass,
		{ Reflectance = 0.2 }
	)
	for _, w in
		{ Vector3.new(-2.6, 0.9, -4), Vector3.new(2.6, 0.9, -4), Vector3.new(-2.6, 0.9, 4), Vector3.new(2.6, 0.9, 4) }
	do
		Builder.decor(
			model,
			"Wheel",
			Vector3.new(1, 2, 2),
			base * CFrame.new(w) * CFrame.Angles(0, 0, 0),
			Color3.fromRGB(18, 18, 20),
			Enum.Material.SmoothPlastic,
			{ Shape = Enum.PartType.Cylinder }
		)
	end
	Builder.decor(
		model,
		"Taillights",
		Vector3.new(5, 0.5, 0.2),
		base * CFrame.new(0, 2.4, 6.55),
		Color3.fromRGB(120, 10, 10),
		Enum.Material.SmoothPlastic
	)
	return model
end

local function powerBox(ctx, parent: Instance, position: Vector3, facing: Vector3, id: string, label: string)
	local cabinet = Builder.box(
		parent,
		"PowerBox",
		Vector3.new(3, 5, 1.6),
		Builder.lookAt(position + Vector3.new(0, 2.5, 0), position + Vector3.new(0, 2.5, 0) + facing),
		Color3.fromRGB(70, 92, 80),
		Enum.Material.Metal
	)
	Builder.sign(cabinet, Enum.NormalId.Front, "HGS", { color = Color3.fromRGB(230, 230, 200), pixelsPerStud = 12 })
	ctx.addSite("PowerBox", id, label, cabinet.CFrame * CFrame.new(0, 0, -1.2), cabinet)
	return cabinet
end

function Streets.build(ctx, layout)
	local config = ctx.config
	local palette = ctx.palette
	local folder = Builder.folder(ctx.root, "Streets")
	local props = Builder.folder(ctx.root, "StreetProps")
	local half = layout.half
	local rh = layout.roadHalf
	local ph = layout.platformHalf
	local outerEdge = half -- ytterkant på yttre trottoaren
	local sidewalkTop = config.sidewalkHeight

	-- Körbanor ----------------------------------------------------------------
	local roadMinZ = layout.streetZ[1] - rh
	local roadMaxZ = layout.streetZ[#layout.streetZ] + rh
	for i, x in layout.avenueX do
		Builder.box(
			folder,
			"Road_" .. config.avenues[i],
			Vector3.new(rh * 2, 2, roadMaxZ - roadMinZ),
			CFrame.new(x, -1, (roadMinZ + roadMaxZ) / 2),
			palette.Asphalt,
			Enum.Material.Asphalt
		)
		-- mittlinje (streckad)
		local z = roadMinZ + 20
		while z < roadMaxZ - 20 do
			Builder.decor(
				folder,
				"LaneMark",
				Vector3.new(0.4, 0.05, 6),
				CFrame.new(x, 0.03, z),
				palette.LaneYellow,
				Enum.Material.SmoothPlastic
			)
			z += 14
		end
	end
	for i, z in layout.streetZ do
		for a = 1, #layout.avenueX - 1 do
			local x1 = layout.avenueX[a] + rh
			local x2 = layout.avenueX[a + 1] - rh
			Builder.box(
				folder,
				"Road_" .. config.streets[i],
				Vector3.new(x2 - x1, 2, rh * 2),
				CFrame.new((x1 + x2) / 2, -1, z),
				palette.Asphalt,
				Enum.Material.Asphalt
			)
			local x = x1 + 18
			while x < x2 - 18 do
				Builder.decor(
					folder,
					"LaneMark",
					Vector3.new(6, 0.05, 0.4),
					CFrame.new(x, 0.03, z),
					palette.LaneYellow,
					Enum.Material.SmoothPlastic
				)
				x += 14
			end
		end
	end

	-- Övergångsställen i varje korsning -----------------------------------------
	for _, x in layout.avenueX do
		for _, z in layout.streetZ do
			for side = -1, 1, 2 do
				for stripe = -3, 3 do
					-- tvärs över avenyn (norr/söder om korsningen)
					Builder.decor(
						folder,
						"Crosswalk",
						Vector3.new(1.4, 0.05, 4),
						CFrame.new(x + stripe * 2.6, 0.04, z + side * (rh + 2.5)),
						palette.LaneWhite,
						Enum.Material.SmoothPlastic
					)
					-- tvärs över gatan (öst/väst om korsningen)
					Builder.decor(
						folder,
						"Crosswalk",
						Vector3.new(4, 0.05, 1.4),
						CFrame.new(x + side * (rh + 2.5), 0.04, z + stripe * 2.6),
						palette.LaneWhite,
						Enum.Material.SmoothPlastic
					)
				end
			end
			-- blinkande gult trafikljus mitt i korsningen
			local signal = Builder.decor(
				folder,
				"TrafficSignal",
				Vector3.new(1.2, 3, 1.2),
				CFrame.new(x + rh - 1, 18, z + rh - 1),
				Color3.fromRGB(30, 30, 30),
				Enum.Material.Metal
			)
			local lamp = Builder.decor(
				folder,
				"SignalAmber",
				Vector3.new(1.3, 0.8, 1.3),
				signal.CFrame,
				Color3.fromRGB(255, 170, 40),
				Enum.Material.Neon
			)
			lamp:AddTag("AH_TrafficSignal")
			Builder.cylinder(
				folder,
				"SignalPole",
				18,
				0.5,
				CFrame.new(x + rh + 1, 9, z + rh + 1) * CFrame.Angles(0, 0, math.pi / 2),
				Color3.fromRGB(40, 42, 48),
				Enum.Material.Metal
			)
			Builder.decor(
				folder,
				"SignalArm",
				Vector3.new(0.3, 0.3, 3),
				Builder.lookAt(Vector3.new(x + rh, 17.6, z + rh), Vector3.new(x + rh - 2, 17.6, z + rh - 2)),
				Color3.fromRGB(40, 42, 48),
				Enum.Material.Metal
			)
		end
	end

	-- Kvarterens trottoarplattor (utom de landmärken som bygger egen mark) ------
	for col = 1, config.columns do
		for row = 1, config.rows do
			local landmark = config.blocks[row][col]
			local center = layout.blockCenters[col][row]
			if not ctx.customGround[landmark] then
				Builder.box(
					folder,
					"Block_" .. landmark,
					Vector3.new(ph * 2, 2 + sidewalkTop, ph * 2),
					CFrame.new(center.X, (sidewalkTop - 2) / 2, center.Z),
					palette.Sidewalk,
					Enum.Material.Pavement
				)
			end
		end
	end

	-- Yttre trottoar runt hela stadsdelen ---------------------------------------
	local ringWidth = outerEdge - (layout.avenueX[#layout.avenueX] + rh)
	local ringCenter = outerEdge - ringWidth / 2
	local fullLength = outerEdge * 2
	for _, sign in { -1, 1 } do
		Builder.box(
			folder,
			"OuterSidewalk",
			Vector3.new(ringWidth, 2 + sidewalkTop, fullLength),
			CFrame.new(sign * ringCenter, (sidewalkTop - 2) / 2, 0),
			palette.Sidewalk,
			Enum.Material.Pavement
		)
		Builder.box(
			folder,
			"OuterSidewalk",
			Vector3.new(fullLength - ringWidth * 2, 2 + sidewalkTop, ringWidth),
			CFrame.new(0, (sidewalkTop - 2) / 2, sign * ringCenter),
			palette.Sidewalk,
			Enum.Material.Pavement
		)
	end

	-- Gatlyktor längs alla trottoarer -------------------------------------------
	local spacing = config.streetLightSpacing
	local lampOffset = rh + 1.5
	for i, x in layout.avenueX do
		local z = roadMinZ + spacing / 2
		local side = if i % 2 == 0 then 1 else -1
		while z < roadMaxZ do
			local onIntersection = false
			for _, sz in layout.streetZ do
				if math.abs(z - sz) < rh + 6 then
					onIntersection = true
				end
			end
			if not onIntersection then
				streetLight(ctx, props, Vector3.new(x + side * lampOffset, sidewalkTop, z), Vector3.new(-side, 0, 0))
				side = -side
			end
			z += spacing
		end
	end
	for i, z in layout.streetZ do
		local x = -half + spacing
		local side = if i % 2 == 0 then 1 else -1
		while x < half - spacing / 2 do
			local onIntersection = false
			for _, ax in layout.avenueX do
				if math.abs(x - ax) < rh + 6 then
					onIntersection = true
				end
			end
			if not onIntersection then
				streetLight(ctx, props, Vector3.new(x, sidewalkTop, z + side * lampOffset), Vector3.new(0, 0, -side))
				side = -side
			end
			x += spacing
		end
	end

	-- Parkerade bilar längs kanten ----------------------------------------------
	for i, x in layout.avenueX do
		for s = 1, #layout.streetZ - 1 do
			local z1, z2 = layout.streetZ[s] + rh + 10, layout.streetZ[s + 1] - rh - 10
			local z = z1
			while z < z2 do
				if ctx.rng:chance(0.35) then
					local side = if ctx.rng:chance(0.5) then 1 else -1
					car(ctx, props, Vector3.new(x + side * (rh - 3.5), 0, z + 7), if side > 0 then 0 else math.pi)
				end
				z += 16
			end
		end
		local _ = i
	end

	-- Brandposter och papperskorgar
	for col = 1, config.columns do
		for row = 1, config.rows do
			local c = layout.blockCenters[col][row]
			for _, corner in { Vector3.new(-1, 0, -1), Vector3.new(1, 0, 1) } do
				local p = c + corner * (ph - 1.2) + Vector3.new(0, sidewalkTop, 0)
				Builder.cylinder(
					props,
					"Hydrant",
					2.2,
					1,
					CFrame.new(p + Vector3.new(0, 1.1, 0)) * CFrame.Angles(0, 0, math.pi / 2),
					Color3.fromRGB(170, 30, 30),
					Enum.Material.Metal
				)
			end
			local binPos = c + Vector3.new(ph - 1.4, sidewalkTop + 1.5, -ph + 8)
			Builder.box(
				props,
				"TrashCan",
				Vector3.new(2, 3, 2),
				CFrame.new(binPos),
				Color3.fromRGB(46, 60, 52),
				Enum.Material.Metal
			)
		end
	end

	-- Avstängda vägar ut ur stan ---------------------------------------------------
	-- Mercer St och Quay St fortsätter norrut, Fifth St och Lumen St åt väst och öst.
	local stubLength = 34
	local function roadblock(position: Vector3, facing: Vector3, alongWidth: Vector3)
		for k = -2, 2 do
			local p = position + alongWidth * (k * 4.2)
			Builder.box(
				props,
				"JerseyBarrier",
				Vector3.new(4, 3, 1.6),
				Builder.lookAt(p + Vector3.new(0, 1.5, 0), p + Vector3.new(0, 1.5, 0) + facing),
				Color3.fromRGB(200, 200, 196),
				Enum.Material.Concrete
			)
		end
		local signPos = position + Vector3.new(0, 5, 0)
		local board = Builder.box(
			props,
			"RoadClosedSign",
			Vector3.new(10, 3, 0.4),
			Builder.lookAt(signPos, signPos + facing),
			Color3.fromRGB(230, 120, 20),
			Enum.Material.SmoothPlastic
		)
		Builder.sign(
			board,
			Enum.NormalId.Front,
			"ROAD CLOSED - NIGHT WORKS",
			{ color = Color3.fromRGB(20, 20, 20), pixelsPerStud = 20 }
		)
		local warn = Builder.decor(
			props,
			"WarningLamp",
			Vector3.new(0.8, 0.8, 0.8),
			CFrame.new(signPos + Vector3.new(4.5, 2, 0)),
			Color3.fromRGB(255, 140, 20),
			Enum.Material.Neon
		)
		Builder.pointLight(warn, Color3.fromRGB(255, 140, 20), 14, 1, false)
		-- osynlig vägg så att man inte kan gå ut ur stan
		Builder.anchor(
			props,
			"Boundary",
			Vector3.new(36, 60, 2),
			Builder.lookAt(position + Vector3.new(0, 30, 0) - facing * 6, position + Vector3.new(0, 30, 0) - facing * 7),
			{ CanCollide = true }
		)
	end
	for _, i in { 2, 3 } do
		local x = layout.avenueX[i]
		Builder.box(
			folder,
			"RoadStub",
			Vector3.new(rh * 2, 2, stubLength),
			CFrame.new(x, -1, -outerEdge - stubLength / 2 + ringWidth),
			palette.Asphalt,
			Enum.Material.Asphalt
		)
		roadblock(
			Vector3.new(x, 0, -outerEdge - stubLength + ringWidth + 8),
			Vector3.new(0, 0, 1),
			Vector3.new(1, 0, 0)
		)
	end
	for _, i in { 2, 3 } do
		local z = layout.streetZ[i]
		for _, sign in { -1, 1 } do
			Builder.box(
				folder,
				"RoadStub",
				Vector3.new(stubLength, 2, rh * 2),
				CFrame.new(sign * (outerEdge + stubLength / 2 - ringWidth), -1, z),
				palette.Asphalt,
				Enum.Material.Asphalt
			)
			roadblock(
				Vector3.new(sign * (outerEdge + stubLength - ringWidth - 8), 0, z),
				Vector3.new(-sign, 0, 0),
				Vector3.new(0, 0, 1)
			)
		end
	end

	-- Yttre ringen av höga hus som stänger in stan (kulisser med få tända fönster) ---
	local skyline = Builder.folder(ctx.root, "Skyline")
	local depth = 46
	local inner = outerEdge
	local outer = outerEdge + depth
	local stubs = {}
	for _, i in { 2, 3 } do
		table.insert(stubs, { axis = "x", at = layout.avenueX[i], side = "North" })
		table.insert(stubs, { axis = "z", at = layout.streetZ[i], side = "West" })
		table.insert(stubs, { axis = "z", at = layout.streetZ[i], side = "East" })
	end
	local depotHalf = ctx.depotHalfWidth
	local function blocked(side: string, from: number, to: number): boolean
		for _, stub in stubs do
			if
				stub.side == side
				and from < stub.at + layout.streetWidth / 2
				and to > stub.at - layout.streetWidth / 2
			then
				return true
			end
		end
		if side == "South" and from < depotHalf and to > -depotHalf then
			return true
		end
		return false
	end
	local function ringBuilding(side: string, from: number, to: number)
		local length = to - from
		local height = ctx.rng:integer(5, 15) * 10
		local mid = (from + to) / 2
		local center, size, faceName
		if side == "North" then
			center, size, faceName =
				Vector3.new(mid, 0, -(inner + outer) / 2), Vector3.new(length, height, depth), "South"
		elseif side == "South" then
			center, size, faceName =
				Vector3.new(mid, 0, (inner + outer) / 2), Vector3.new(length, height, depth), "North"
		elseif side == "West" then
			center, size, faceName =
				Vector3.new(-(inner + outer) / 2, 0, mid), Vector3.new(depth, height, length), "East"
		else
			center, size, faceName =
				Vector3.new((inner + outer) / 2, 0, mid), Vector3.new(depth, height, length), "West"
		end
		local tone =
			ctx.rng:pick({ palette.ConcreteDark, palette.BrickDark, palette.Concrete, palette.Steel }) :: Color3
		Buildings.build(ctx, skyline, {
			name = "Skyline",
			center = center,
			size = size,
			color = tone,
			material = Enum.Material.Concrete,
			floorHeight = 10,
			windows = { faces = { faceName }, style = "Residential", litChance = 0.12 },
			roof = { noProps = true },
		})
	end
	for _, side in { "North", "South", "West", "East" } do
		local from = -outer
		while from < outer do
			local width = ctx.rng:integer(28, 52)
			local to = math.min(from + width, outer)
			if not blocked(side, from, to) then
				ringBuilding(side, from, to)
			else
				-- huset som stänger vägstumpen ligger längre ut
				if side ~= "South" then
					local backCenter
					if side == "North" then
						backCenter = Vector3.new((from + to) / 2, 0, -(outer + 20))
					elseif side == "West" then
						backCenter = Vector3.new(-(outer + 20), 0, (from + to) / 2)
					else
						backCenter = Vector3.new(outer + 20, 0, (from + to) / 2)
					end
					Builder.box(
						skyline,
						"StubBackdrop",
						Vector3.new(44, 110, 44),
						CFrame.new(backCenter.X, 55, backCenter.Z),
						palette.ConcreteDark,
						Enum.Material.Concrete
					)
				end
			end
			from = to
		end
	end

	-- Elskåp (kontraktsplatser för reparationer) ------------------------------------
	local boxes = {
		{
			x = layout.avenueX[2] + rh + 2,
			z = layout.streetZ[2] + 30,
			facing = Vector3.new(-1, 0, 0),
			label = "Mercer St at Fifth",
		},
		{
			x = layout.avenueX[3] - rh - 2,
			z = layout.streetZ[3] - 26,
			facing = Vector3.new(1, 0, 0),
			label = "Quay St, south of Fifth",
		},
		{
			x = layout.avenueX[1] + rh + 2,
			z = layout.streetZ[3] + 34,
			facing = Vector3.new(-1, 0, 0),
			label = "Harlow Ave at Lumen",
		},
		{
			x = layout.avenueX[4] - rh - 2,
			z = layout.streetZ[2] + 40,
			facing = Vector3.new(1, 0, 0),
			label = "Vance Ave, north end",
		},
		{
			x = layout.avenueX[2] + 40,
			z = layout.streetZ[4] - rh - 2,
			facing = Vector3.new(0, 0, 1),
			label = "Depot Rd at Mercer",
		},
		{
			x = layout.avenueX[3] + 30,
			z = layout.streetZ[3] + rh + 2,
			facing = Vector3.new(0, 0, -1),
			label = "Lumen St at Quay",
		},
	}
	for index, spec in boxes do
		powerBox(ctx, props, Vector3.new(spec.x, sidewalkTop, spec.z), spec.facing, "PowerBox" .. index, spec.label)
	end

	-- Lootpunkter på trottoarerna (gatufynd) ------------------------------------------
	for col = 1, config.columns do
		for row = 1, config.rows do
			local c = layout.blockCenters[col][row]
			for _, offset in
				{ Vector3.new(ph - 2, 0, ctx.rng:number(-40, 40)), Vector3.new(ctx.rng:number(-40, 40), 0, -ph + 2) }
			do
				ctx.addLoot("Street", c + offset + Vector3.new(0, sidewalkTop + 0.5, 0))
			end
		end
	end

	-- NPC-gångvägar: hörn på varje kvarters trottoar, kopplade runt kvarteret och över gatan.
	local inset = ph - 4.5 -- mellan husväggarna och gatans rekvisita
	local nodeIndex = {}
	local function node(col: number, row: number, corner: string): number
		local key = col .. ":" .. row .. ":" .. corner
		if nodeIndex[key] then
			return nodeIndex[key]
		end
		local c = layout.blockCenters[col][row]
		local dx = if corner:find("E") then inset else -inset
		local dz = if corner:find("S") then inset else -inset
		table.insert(ctx.world.npc.nodes, Vector3.new(c.X + dx, sidewalkTop, c.Z + dz))
		nodeIndex[key] = #ctx.world.npc.nodes
		return nodeIndex[key]
	end
	local edges = ctx.world.npc.edges
	for col = 1, config.columns do
		for row = 1, config.rows do
			table.insert(edges, { node(col, row, "NW"), node(col, row, "NE") })
			table.insert(edges, { node(col, row, "NE"), node(col, row, "SE") })
			table.insert(edges, { node(col, row, "SE"), node(col, row, "SW") })
			table.insert(edges, { node(col, row, "SW"), node(col, row, "NW") })
			if col < config.columns then
				table.insert(edges, { node(col, row, "NE"), node(col + 1, row, "NW") })
				table.insert(edges, { node(col, row, "SE"), node(col + 1, row, "SW") })
			end
			if row < config.rows then
				table.insert(edges, { node(col, row, "SW"), node(col, row + 1, "NW") })
				table.insert(edges, { node(col, row, "SE"), node(col, row + 1, "NE") })
			end
		end
	end

	-- Möjliga LOCKDOWN-spärrar mitt på gatusträckor nära centrum.
	local function barrierOnAvenue(i: number, s: number)
		local z = (layout.streetZ[s] + layout.streetZ[s + 1]) / 2
		table.insert(ctx.world.barriers, {
			name = config.avenues[i],
			cframe = CFrame.new(layout.avenueX[i], 6, z),
			size = Vector3.new(layout.streetWidth, 12, 2),
		})
	end
	local function barrierOnStreet(i: number, a: number)
		local x = (layout.avenueX[a] + layout.avenueX[a + 1]) / 2
		table.insert(ctx.world.barriers, {
			name = config.streets[i],
			cframe = CFrame.new(x, 6, layout.streetZ[i]) * CFrame.Angles(0, math.pi / 2, 0),
			size = Vector3.new(layout.streetWidth, 12, 2),
		})
	end
	barrierOnAvenue(2, 2)
	barrierOnAvenue(3, 2)
	barrierOnAvenue(2, 3)
	barrierOnAvenue(3, 1)
	barrierOnStreet(2, 2)
	barrierOnStreet(3, 2)
	barrierOnStreet(4, 2)
	barrierOnStreet(3, 1)

	return folder
end

return Streets
