-- Site 9: inhägnad byggarbetsplats (RESTRICTED). Ställningar med stegar, en container
-- högst upp och en byggkran som går att klättra upp i. Ett hål i stängslet för den nyfikne.

local Builder = require(script.Parent.Parent.Builder)
local Buildings = require(script.Parent.Parent.Buildings)

local Site9 = {}

local function fence(parent: Instance, from: Vector3, to: Vector3, height: number)
	local direction = to - from
	local middle = from + direction / 2 + Vector3.new(0, height / 2, 0)
	Builder.box(
		parent,
		"Fence",
		Vector3.new(0.3, height, direction.Magnitude),
		Builder.lookAt(middle, middle + direction),
		Color3.fromRGB(150, 156, 160),
		Enum.Material.DiamondPlate,
		{ Transparency = 0.45, CastShadow = false }
	)
	local railMid = middle + Vector3.new(0, height / 2, 0)
	Builder.box(
		parent,
		"FenceRail",
		Vector3.new(0.4, 0.4, direction.Magnitude),
		Builder.lookAt(railMid, railMid + direction),
		Color3.fromRGB(110, 114, 118),
		Enum.Material.Metal
	)
end
Site9.fence = fence

local function ladder(parent: Instance, position: Vector3, height: number, color: Color3)
	local truss = Instance.new("TrussPart")
	truss.Name = "Ladder"
	truss.Size = Vector3.new(2, height, 2)
	truss.CFrame = CFrame.new(position + Vector3.new(0, height / 2, 0))
	truss.Anchored = true
	truss.Color = color
	truss.Parent = parent
	return truss
end
Site9.ladder = ladder

function Site9.build(ctx, c: Vector3, _layout)
	local palette = ctx.palette
	local root = Builder.model(ctx.root, "Site9")
	local top = ctx.config.sidewalkHeight
	local inset = 54
	local y = top
	local gateZ1, gateZ2 = c.Z - 6, c.Z + 6
	local gapX1, gapX2 = c.X + 24, c.X + 27

	-- Stängsel runt hela tomten, grind mot Mercer St (öster) och ett hål i norra stängslet
	fence(root, Vector3.new(c.X - inset, y, c.Z + inset), Vector3.new(c.X + inset, y, c.Z + inset), 10)
	fence(root, Vector3.new(c.X - inset, y, c.Z - inset), Vector3.new(gapX1, y, c.Z - inset), 10)
	fence(root, Vector3.new(gapX2, y, c.Z - inset), Vector3.new(c.X + inset, y, c.Z - inset), 10)
	fence(root, Vector3.new(c.X - inset, y, c.Z - inset), Vector3.new(c.X - inset, y, c.Z + inset), 10)
	fence(root, Vector3.new(c.X + inset, y, c.Z - inset), Vector3.new(c.X + inset, y, gateZ1), 10)
	fence(root, Vector3.new(c.X + inset, y, gateZ2), Vector3.new(c.X + inset, y, c.Z + inset), 10)
	local gateSign = Builder.box(
		root,
		"GateSign",
		Vector3.new(0.4, 3, 12),
		CFrame.new(c.X + inset + 0.4, y + 11.5, c.Z),
		palette.SafetyYellow,
		Enum.Material.SmoothPlastic
	)
	Builder.sign(
		gateSign,
		Enum.NormalId.Right,
		"SITE 9 - AUTHORIZED PERSONNEL ONLY",
		{ color = Color3.fromRGB(20, 20, 20) }
	)
	for _, z in { gateZ1, gateZ2 } do
		Builder.box(
			root,
			"GatePost",
			Vector3.new(0.8, 13, 0.8),
			CFrame.new(c.X + inset, y + 6.5, z),
			palette.Steel,
			Enum.Material.Metal
		)
	end

	Builder.decor(
		root,
		"Dirt",
		Vector3.new(inset * 2, 0.2, inset * 2),
		CFrame.new(c.X, top + 0.08, c.Z),
		Color3.fromRGB(78, 64, 50),
		Enum.Material.Ground
	)

	-- Ställningen: fyra däck med stegar i sicksack ------------------------------------------
	local scaffold = Builder.model(root, "Scaffold")
	local sc = Vector3.new(c.X - 6, 0, c.Z - 6)
	local half = 11
	for level = 1, 4 do
		local deckY = level * 10
		Builder.box(
			scaffold,
			"Deck",
			Vector3.new(half * 2, 0.8, half * 2),
			CFrame.new(sc.X, deckY - 0.4, sc.Z),
			Color3.fromRGB(120, 100, 70),
			Enum.Material.WoodPlanks
		)
		for _, corner in { Vector3.new(-1, 0, -1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, 1) } do
			Builder.box(
				scaffold,
				"Post",
				Vector3.new(0.6, 10, 0.6),
				CFrame.new(sc.X + corner.X * (half - 0.3), deckY - 5, sc.Z + corner.Z * (half - 0.3)),
				palette.Steel,
				Enum.Material.Metal
			)
		end
		Builder.decor(
			scaffold,
			"Netting",
			Vector3.new(half * 2, 3, 0.1),
			CFrame.new(sc.X, deckY + 1.5, sc.Z - half),
			Color3.fromRGB(40, 110, 60),
			Enum.Material.Fabric,
			{ Transparency = 0.4 }
		)
		local sideZ = if level % 2 == 1 then sc.Z + half + 1 else sc.Z - half - 1
		ladder(scaffold, Vector3.new(sc.X, (level - 1) * 10, sideZ), 10, palette.SafetyYellow)
	end
	-- Containerkontoret högst upp (HIGH RISK-kontraktets mål)
	local office = Buildings.room(ctx, scaffold, "SiteOffice", Vector3.new(sc.X, 40, sc.Z), Vector3.new(12, 8, 7), {
		floor = false,
		wallColor = Color3.fromRGB(40, 90, 140),
		wallMaterial = Enum.Material.CorrodedMetal,
		doors = { { face = "South", width = 4, height = 7, offset = 0 } },
	})
	local desk = Builder.box(
		office,
		"Desk",
		Vector3.new(5, 3, 2.4),
		CFrame.new(sc.X, 41.5, sc.Z - 1.5),
		Color3.fromRGB(100, 90, 70),
		Enum.Material.Wood
	)
	ctx.addSite(
		"SiteOffice",
		"Site9Office",
		"the Site 9 container office, top of the scaffold",
		desk.CFrame * CFrame.new(0, 0.5, 2.6),
		desk
	)

	-- Byggkranen ---------------------------------------------------------------------------
	local crane = Builder.model(root, "Crane")
	local base = Vector3.new(c.X + 36, top, c.Z - 36)
	local mast = Instance.new("TrussPart")
	mast.Name = "CraneMast"
	mast.Size = Vector3.new(2, 80, 2)
	mast.CFrame = CFrame.new(base + Vector3.new(0, 40, 0))
	mast.Anchored = true
	mast.Color = palette.SafetyYellow
	mast.Parent = crane
	Builder.box(
		crane,
		"CraneBase",
		Vector3.new(6, 2, 6),
		CFrame.new(base + Vector3.new(0, 1, 0)),
		palette.ConcreteDark,
		Enum.Material.Concrete
	)
	Builder.box(
		crane,
		"CranePlatform",
		Vector3.new(6, 1, 6),
		CFrame.new(base + Vector3.new(-2, 80.5, 0)),
		palette.SafetyYellow,
		Enum.Material.DiamondPlate
	)
	Builder.box(
		crane,
		"Cab",
		Vector3.new(4, 4, 4),
		CFrame.new(base + Vector3.new(-3, 83, 2)),
		Color3.fromRGB(220, 200, 60),
		Enum.Material.Metal
	)
	Builder.box(
		crane,
		"Jib",
		Vector3.new(70, 1.6, 1.6),
		CFrame.new(base + Vector3.new(-36, 86, 0)),
		palette.SafetyYellow,
		Enum.Material.Metal
	)
	Builder.box(
		crane,
		"CounterJib",
		Vector3.new(18, 1.6, 1.6),
		CFrame.new(base + Vector3.new(10, 86, 0)),
		palette.SafetyYellow,
		Enum.Material.Metal
	)
	Builder.box(
		crane,
		"Counterweight",
		Vector3.new(4, 5, 3),
		CFrame.new(base + Vector3.new(16, 83, 0)),
		palette.ConcreteDark,
		Enum.Material.Concrete
	)
	Builder.decor(
		crane,
		"Cable",
		Vector3.new(0.2, 40, 0.2),
		CFrame.new(base + Vector3.new(-50, 66, 0)),
		Color3.fromRGB(30, 30, 30),
		Enum.Material.Metal
	)
	Builder.box(
		crane,
		"Hook",
		Vector3.new(1.4, 2, 1.4),
		CFrame.new(base + Vector3.new(-50, 45, 0)),
		Color3.fromRGB(60, 60, 60),
		Enum.Material.Metal
	)
	local warning = Builder.decor(
		crane,
		"WarningLight",
		Vector3.new(0.8, 0.8, 0.8),
		CFrame.new(base + Vector3.new(0, 88, 0)),
		Color3.fromRGB(255, 40, 40),
		Enum.Material.Neon
	)
	warning:AddTag("AH_FlickerLight")
	Builder.pointLight(warning, Color3.fromRGB(255, 40, 40), 16, 1, false)
	ctx.addDiscovery("CraneTop", CFrame.new(base + Vector3.new(-2, 83, 0)), Vector3.new(8, 6, 8))
	ctx.addLoot("Secret", base + Vector3.new(-3, 81.5, -2))

	-- Containrar, rör och en arbetslampa
	Builder.box(
		root,
		"Container",
		Vector3.new(20, 9, 8),
		CFrame.new(c.X - 34, top + 4.5, c.Z + 38),
		Color3.fromRGB(150, 50, 40),
		Enum.Material.CorrodedMetal
	)
	Builder.box(
		root,
		"Container",
		Vector3.new(20, 9, 8),
		CFrame.new(c.X - 34, top + 13.5, c.Z + 38) * CFrame.Angles(0, 0.12, 0),
		Color3.fromRGB(40, 90, 140),
		Enum.Material.CorrodedMetal
	)
	Builder.box(
		root,
		"Container",
		Vector3.new(8, 9, 20),
		CFrame.new(gapX1 + 1.5, top + 4.5, c.Z - inset + 15),
		Color3.fromRGB(60, 110, 70),
		Enum.Material.CorrodedMetal
	)
	for k = 0, 3 do
		Builder.cylinder(
			root,
			"Pipe",
			16,
			2,
			CFrame.new(c.X + 20, top + 1 + k * 0.1, c.Z + 30 + k * 2.2),
			Color3.fromRGB(110, 110, 116),
			Enum.Material.Metal
		)
	end
	local lampPost = Builder.box(
		root,
		"FloodlightPost",
		Vector3.new(0.6, 14, 0.6),
		CFrame.new(c.X + 20, top + 7, c.Z + 10),
		palette.Steel,
		Enum.Material.Metal
	)
	local flood = Builder.decor(
		root,
		"Floodlight",
		Vector3.new(2, 1.4, 1),
		Builder.lookAt(lampPost.CFrame.Position + Vector3.new(0, 7, 0), sc + Vector3.new(0, 10, 0)),
		Color3.fromRGB(255, 250, 230),
		Enum.Material.Neon
	)
	flood:AddTag("AH_StreetLight")
	Builder.spotLight(flood, Enum.NormalId.Front, Color3.fromRGB(255, 245, 225), 60, 50, 2, true)

	ctx.addZone("Restricted", "Site 9", CFrame.new(c.X, 45, c.Z), Vector3.new(inset * 2, 92, inset * 2))
	ctx.addLoot("Restricted", Vector3.new(sc.X + 6, 20.5, sc.Z + 6))
	ctx.addLoot("Restricted", Vector3.new(sc.X - 6, 30.5, sc.Z - 4))
	ctx.addLoot("Restricted", Vector3.new(c.X - 20, top + 0.5, c.Z + 30))
	ctx.addLoot("Restricted", Vector3.new(c.X + 30, top + 0.5, c.Z - 10))
	return root
end

return Site9
