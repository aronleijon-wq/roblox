-- Buildings: generiska byggnader med fönster, tak, skyltfönster och brandtrappor.
-- Fönstren taggas så att klienten kan släcka dem lokalt (t.ex. vid BLACKOUT) utan
-- att servern behöver skicka tusentals egenskapsändringar över nätverket.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Builder = require(script.Parent.Builder)

local Buildings = {}

-- Utåtriktad normal och tangent (längs fasaden) för varje sida. Tangenten pekar åt höger
-- för den som står utanför och tittar på fasaden, så kolumn 1 är alltid längst till vänster.
local FACES = {
	North = { normal = Vector3.new(0, 0, -1), tangent = Vector3.new(-1, 0, 0) },
	South = { normal = Vector3.new(0, 0, 1), tangent = Vector3.new(1, 0, 0) },
	East = { normal = Vector3.new(1, 0, 0), tangent = Vector3.new(0, 0, -1) },
	West = { normal = Vector3.new(-1, 0, 0), tangent = Vector3.new(0, 0, 1) },
}
Buildings.Faces = FACES

local WINDOW_STYLES = {
	Residential = { width = 3, height = 4, gap = 3.2, margin = 3 },
	Office = { width = 6, height = 5, gap = 1.2, margin = 2.5 },
	Industrial = { width = 8, height = 2.5, gap = 6, margin = 5 },
	-- Smala fönster i tornet: 17 kolumner per fasad, så att "03:00" (3x5-siffror) får plats.
	Tower = { width = 1.6, height = 4.4, gap = 0.6, margin = 1.5 },
}

-- Halva storleken längs en normal (bredd eller djup).
local function halfAlong(size: Vector3, direction: Vector3): number
	return math.abs(direction.X) * size.X / 2 + math.abs(direction.Z) * size.Z / 2
end

local function widthAlong(size: Vector3, tangent: Vector3): number
	return math.abs(tangent.X) * size.X + math.abs(tangent.Z) * size.Z
end

-- Lägger fönsterrader på en fasad. Returnerar fönstren (för t.ex. tornets mönster).
function Buildings.windows(ctx, parent: Instance, building, faceName: string, options)
	local face = FACES[faceName]
	local style = WINDOW_STYLES[options.style or "Residential"]
	local palette = ctx.palette
	local center: Vector3 = building.center
	local size: Vector3 = building.size
	local floorHeight = building.floorHeight

	local width = widthAlong(size, face.tangent)
	local usable = width - style.margin * 2
	local count = math.floor((usable + style.gap) / (style.width + style.gap))
	if count < 1 then
		return {}
	end
	local span = count * style.width + (count - 1) * style.gap
	local faceCenter = center + face.normal * (halfAlong(size, face.normal) + 0.15)
	local floors = math.floor(size.Y / floorHeight)
	local created = {}

	for floor = options.startFloor or 1, floors - 1 do
		local y = floor * floorHeight + floorHeight * 0.55
		if y + style.height / 2 < size.Y - 1 then
			for col = 1, count do
				local offset = -span / 2 + style.width / 2 + (col - 1) * (style.width + style.gap)
				local position = Vector3.new(faceCenter.X, y, faceCenter.Z) + face.tangent * offset
				local lit = ctx.rng:chance(options.litChance or ctx.litChance)
				local warm = if options.warm == nil then ctx.rng:chance(0.7) else options.warm
				local window = Builder.decor(
					parent,
					"Window",
					Vector3.new(style.width, style.height, 0.3),
					Builder.lookAt(position, position + face.normal),
					if lit then (if warm then palette.WindowWarm else palette.WindowCool) else palette.WindowDark,
					if lit then Enum.Material.Neon else Enum.Material.Glass,
					{ Reflectance = if lit then 0 else 0.15 }
				)
				window:SetAttribute("Lit", lit)
				window:SetAttribute("Warm", warm)
				if options.group then
					window:SetAttribute("Group", options.group)
					window:SetAttribute("Row", floor)
					window:SetAttribute("Col", col)
					window:SetAttribute("Face", faceName)
				end
				window:AddTag(Constants.Tags.WindowLight)
				table.insert(created, { part = window, row = floor, col = col, face = faceName })
			end
		end
	end
	return created
end

-- Låg kant runt taket, lite utrustning och ibland ett vattentorn.
function Buildings.roof(ctx, parent: Instance, building, options)
	local palette = ctx.palette
	local c: Vector3 = building.center
	local s: Vector3 = building.size
	local top = s.Y
	local color = building.trimColor or palette.ConcreteDark
	local h = 1.5
	Builder.box(
		parent,
		"Parapet",
		Vector3.new(s.X, h, 1),
		CFrame.new(c.X, top + h / 2, c.Z - s.Z / 2 + 0.5),
		color,
		Enum.Material.Concrete
	)
	Builder.box(
		parent,
		"Parapet",
		Vector3.new(s.X, h, 1),
		CFrame.new(c.X, top + h / 2, c.Z + s.Z / 2 - 0.5),
		color,
		Enum.Material.Concrete
	)
	Builder.box(
		parent,
		"Parapet",
		Vector3.new(1, h, s.Z - 2),
		CFrame.new(c.X - s.X / 2 + 0.5, top + h / 2, c.Z),
		color,
		Enum.Material.Concrete
	)
	Builder.box(
		parent,
		"Parapet",
		Vector3.new(1, h, s.Z - 2),
		CFrame.new(c.X + s.X / 2 - 0.5, top + h / 2, c.Z),
		color,
		Enum.Material.Concrete
	)

	if options and options.noProps then
		return
	end
	local units = ctx.rng:integer(1, 3)
	for _ = 1, units do
		local ux = c.X + ctx.rng:number(-s.X / 2 + 5, s.X / 2 - 5)
		local uz = c.Z + ctx.rng:number(-s.Z / 2 + 5, s.Z / 2 - 5)
		Builder.box(
			parent,
			"AirUnit",
			Vector3.new(4, 3, 4),
			CFrame.new(ux, top + 1.5, uz),
			palette.Steel,
			Enum.Material.DiamondPlate
		)
	end
	if s.X >= 24 and s.Z >= 24 and ctx.rng:chance(0.35) then
		local tx = c.X + s.X / 4
		local tz = c.Z - s.Z / 4
		for _, leg in { Vector3.new(-2, 0, -2), Vector3.new(2, 0, -2), Vector3.new(-2, 0, 2), Vector3.new(2, 0, 2) } do
			Builder.box(
				parent,
				"TowerLeg",
				Vector3.new(0.6, 6, 0.6),
				CFrame.new(tx + leg.X, top + 3, tz + leg.Z),
				palette.Steel,
				Enum.Material.Metal
			)
		end
		Builder.cylinder(
			parent,
			"WaterTower",
			7,
			7,
			CFrame.new(tx, top + 9.5, tz) * CFrame.Angles(0, 0, math.pi / 2),
			Color3.fromRGB(104, 78, 60),
			Enum.Material.WoodPlanks
		)
	end
end

-- Skyltfönster i bottenvåningen med upplyst skylt.
function Buildings.storefront(ctx, parent: Instance, building, faceName: string, options)
	local face = FACES[faceName]
	local c: Vector3 = building.center
	local s: Vector3 = building.size
	local width = widthAlong(s, face.tangent) - 4
	local base = c + face.normal * (halfAlong(s, face.normal) + 0.2)
	local glassPos = Vector3.new(base.X, 4, base.Z)
	local glass = Builder.decor(
		parent,
		"Storefront",
		Vector3.new(width, 6, 0.3),
		Builder.lookAt(glassPos, glassPos + face.normal),
		if options.lit then Color3.fromRGB(255, 230, 190) else ctx.palette.WindowDark,
		if options.lit then Enum.Material.Neon else Enum.Material.Glass,
		{ Transparency = if options.lit then 0.35 else 0 }
	)
	if options.lit then
		glass:SetAttribute("Lit", true)
		glass:AddTag(Constants.Tags.WindowLight)
	end
	if options.sign then
		local signPos = Vector3.new(base.X, 8.5, base.Z) + face.normal * 0.3
		local board = Builder.decor(
			parent,
			"ShopSign",
			Vector3.new(math.min(width, 24), 2.4, 0.5),
			Builder.lookAt(signPos, signPos + face.normal),
			Color3.fromRGB(20, 20, 24),
			Enum.Material.SmoothPlastic
		)
		Builder.sign(board, Enum.NormalId.Front, options.sign, {
			color = options.signColor or Color3.new(1, 1, 1),
			lit = options.lit ~= false,
			font = Enum.Font.GothamBlack,
		})
	end
	return glass
end

-- Brandtrappa i sicksack utanpå en fasad, från marken upp till taket.
function Buildings.fireEscape(ctx, parent: Instance, building, faceName: string)
	local face = FACES[faceName]
	local c: Vector3 = building.center
	local s: Vector3 = building.size
	local fh = building.floorHeight
	local floors = math.floor(s.Y / fh)
	local width = widthAlong(s, face.tangent)
	local depth = 5
	local landing = 6
	local out = c + face.normal * (halfAlong(s, face.normal) + depth / 2)
	local endA = -width / 2 + landing / 2 + 1
	local endB = width / 2 - landing / 2 - 1
	local steel = ctx.palette.Steel

	local function landingAt(level: number, along: number)
		local p = Vector3.new(out.X, level, out.Z) + face.tangent * along
		Builder.box(
			parent,
			"FireEscapeLanding",
			Vector3.new(landing, 0.6, depth),
			Builder.lookAt(p + Vector3.new(0, -0.3, 0), p + Vector3.new(0, -0.3, 0) + face.normal),
			steel,
			Enum.Material.DiamondPlate
		)
		local railPos = p + face.normal * (depth / 2 - 0.2) + Vector3.new(0, 1.6, 0)
		Builder.box(
			parent,
			"Rail",
			Vector3.new(landing, 0.3, 0.3),
			Builder.lookAt(railPos, railPos + face.normal),
			steel,
			Enum.Material.Metal
		)
	end

	local previousLevel, previousAlong = 0, endA
	for floor = 1, floors do
		local level = math.min(floor * fh, s.Y)
		local along = if floor % 2 == 1 then endB else endA
		landingAt(level, along)
		-- trappan går från förra avsatsens kant till den här avsatsens kant
		local fromAlong = previousAlong + (if along > previousAlong then landing / 2 else -landing / 2)
		local toAlong = along - (if along > previousAlong then landing / 2 else -landing / 2)
		local bottom = Vector3.new(out.X, previousLevel, out.Z) + face.tangent * fromAlong
		local top = Vector3.new(out.X, level, out.Z) + face.tangent * toAlong
		Builder.ramp(parent, "FireEscapeStairs", bottom, top, depth - 1.5, steel, Enum.Material.DiamondPlate)
		previousLevel, previousAlong = level, along
	end
	return Vector3.new(out.X, s.Y, out.Z) + face.tangent * previousAlong
end

-- En hel byggnad. spec: name, center (marknivå), size, color, material, floorHeight,
-- windows = { faces, style, litChance, warm, group }, storefront = { face, sign, ... },
-- fireEscape = faceName, roof = { noProps }
function Buildings.build(ctx, parent: Instance, spec)
	local model = Builder.model(parent, spec.name or "Building")
	local building = {
		center = spec.center,
		size = spec.size,
		floorHeight = spec.floorHeight or 10,
		trimColor = spec.trimColor,
	}
	local c, s = spec.center, spec.size
	local body = Builder.box(
		model,
		"Body",
		s,
		CFrame.new(c.X, s.Y / 2, c.Z),
		spec.color or ctx.palette.Concrete,
		spec.material or Enum.Material.Concrete
	)
	building.body = body

	local windows = {}
	if spec.windows then
		for _, faceName in spec.windows.faces or { "North", "South", "East", "West" } do
			for _, w in Buildings.windows(ctx, model, building, faceName, spec.windows) do
				table.insert(windows, w)
			end
		end
	end
	building.windows = windows

	if spec.storefront then
		Buildings.storefront(ctx, model, building, spec.storefront.face, spec.storefront)
	end
	if spec.fireEscape then
		building.fireEscapeTop = Buildings.fireEscape(ctx, model, building, spec.fireEscape)
	end
	if spec.roof ~= false then
		Buildings.roof(ctx, model, building, spec.roof)
	end
	building.model = model
	return building
end

-- Ett enkelt rum med väggar, golv och tak, och dörröppningar.
-- doors = { { face = "South", width = 4, height = 7, offset = 0 } }
function Buildings.room(ctx, parent: Instance, name: string, center: Vector3, size: Vector3, options)
	local opts = options or {}
	local model = Builder.model(parent, name)
	local wallColor = opts.wallColor or ctx.palette.Plaster
	local floorColor = opts.floorColor or ctx.palette.ConcreteDark
	local t = opts.thickness or 1
	local floorY = center.Y

	if opts.floor ~= false then
		Builder.box(
			model,
			"Floor",
			Vector3.new(size.X, 1, size.Z),
			CFrame.new(center.X, floorY - 0.5, center.Z),
			floorColor,
			opts.floorMaterial or Enum.Material.Concrete
		)
	end
	if opts.ceiling ~= false then
		Builder.box(
			model,
			"Ceiling",
			Vector3.new(size.X, 1, size.Z),
			CFrame.new(center.X, floorY + size.Y + 0.5, center.Z),
			opts.ceilingColor or ctx.palette.ConcreteDark,
			Enum.Material.Concrete
		)
	end

	local doorsByFace = {}
	for _, door in opts.doors or {} do
		doorsByFace[door.face] = doorsByFace[door.face] or {}
		table.insert(doorsByFace[door.face], door)
	end

	local openings = {}
	for faceName, face in FACES do
		if not (opts.openFaces and table.find(opts.openFaces, faceName)) then
			local length = widthAlong(size, face.tangent)
			if faceName == "East" or faceName == "West" then
				length -= t * 2 -- gavelväggarna ryms mellan långväggarna
			end
			local wallCenter = center + face.normal * (halfAlong(size, face.normal) - t / 2)
			-- Dela upp väggen kring dörrarna (sorterade längs tangenten).
			local doors = doorsByFace[faceName] or {}
			table.sort(doors, function(a, b)
				return (a.offset or 0) < (b.offset or 0)
			end)
			local cursor = -length / 2
			local function segment(from: number, to: number, bottom: number, top: number)
				if to - from > 0.05 and top - bottom > 0.05 then
					local mid = (from + to) / 2
					local p = Vector3.new(wallCenter.X, floorY + (bottom + top) / 2, wallCenter.Z) + face.tangent * mid
					Builder.box(
						model,
						"Wall",
						Vector3.new(to - from, top - bottom, t),
						Builder.lookAt(p, p + face.normal),
						wallColor,
						opts.wallMaterial or Enum.Material.Concrete
					)
				end
			end
			for _, door in doors do
				local dFrom = (door.offset or 0) - door.width / 2
				local dTo = (door.offset or 0) + door.width / 2
				segment(cursor, dFrom, 0, size.Y)
				segment(dFrom, dTo, door.height, size.Y) -- överstycket
				local doorCenter = Vector3.new(wallCenter.X, floorY + door.height / 2, wallCenter.Z)
					+ face.tangent * (door.offset or 0)
				table.insert(openings, {
					face = faceName,
					cframe = Builder.lookAt(doorCenter, doorCenter + face.normal),
					size = Vector3.new(door.width, door.height, t),
					id = door.id,
				})
				cursor = dTo
			end
			segment(cursor, length / 2, 0, size.Y)
		end
	end
	return model, openings
end

-- En liten låst byggnad (tillbyggnad) med en dörr som är en AccessGate.
-- Används för hemliga rum och rum som öppnas i kontraktens vändningar.
function Buildings.annex(ctx, parent: Instance, spec)
	local c: Vector3 = spec.center
	local size: Vector3 = spec.size
	local doorWidth = spec.doorWidth or 4
	local model, openings = Buildings.room(ctx, parent, spec.name, c, size, {
		wallColor = spec.wallColor or ctx.palette.Brick,
		wallMaterial = spec.wallMaterial or Enum.Material.Brick,
		floorColor = spec.floorColor,
		floor = spec.floor == true, -- står normalt på befintlig mark (undvik dubbla golv som flimrar)
		doors = { { face = spec.doorFace, width = doorWidth, height = 7, offset = spec.doorOffset or 0 } },
	})
	local opening = openings[1]
	local door = Builder.box(
		model,
		"Door",
		Vector3.new(doorWidth, 7, 0.4),
		opening.cframe,
		spec.doorColor or Color3.fromRGB(60, 64, 70),
		Enum.Material.Metal
	)
	ctx.addGate(spec.gateId, door)
	if spec.sign then
		local face = FACES[spec.doorFace]
		local signPos = opening.cframe.Position + Vector3.new(0, 5, 0) + face.normal * 0.3
		local plate = Builder.decor(
			model,
			"DoorSign",
			Vector3.new(math.max(doorWidth, 6), 1.4, 0.2),
			Builder.lookAt(signPos, signPos + face.normal),
			Color3.fromRGB(28, 30, 34),
			Enum.Material.SmoothPlastic
		)
		Builder.sign(
			plate,
			Enum.NormalId.Front,
			spec.sign,
			{ color = spec.signColor or Color3.fromRGB(230, 230, 220), pixelsPerStud = 20 }
		)
	end
	-- En lampa i taket som är släckt tills något händer där inne.
	local bulb = Builder.decor(
		model,
		"Bulb",
		Vector3.new(0.8, 0.8, 0.8),
		CFrame.new(c.X, c.Y + size.Y - 0.6, c.Z),
		Color3.fromRGB(60, 56, 50),
		Enum.Material.SmoothPlastic
	)
	local light = Builder.pointLight(bulb, Color3.fromRGB(255, 210, 160), math.max(size.X, size.Z), 0, true)
	light.Name = "RoomLight"
	return {
		model = model,
		door = door,
		doorCFrame = opening.cframe,
		center = c,
		size = size,
		bulb = bulb,
	}
end

return Buildings
