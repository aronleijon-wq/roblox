-- Nite Owl Mart (öppet dygnet runt, en säker plats), gränden bakom med Maintenance B-7
-- och det stängda apoteket på Mercer St.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Builder = require(script.Parent.Parent.Builder)
local Buildings = require(script.Parent.Parent.Buildings)

local Store = {}

function Store.build(ctx, c: Vector3, _layout)
	local palette = ctx.palette
	local root = Builder.model(ctx.root, "NiteOwlBlock")
	local top = ctx.config.sidewalkHeight

	-- Butiken -------------------------------------------------------------------------
	local storeCenter = Vector3.new(c.X - 30, top + 0.1, c.Z - 37)
	local storeSize = Vector3.new(44, 12, 30)
	local store = Buildings.room(ctx, root, "NiteOwlMart", storeCenter, storeSize, {
		wallColor = Color3.fromRGB(70, 60, 76),
		floorColor = Color3.fromRGB(200, 200, 196),
		floorMaterial = Enum.Material.SmoothPlastic,
		doors = {
			{ face = "North", width = 8, height = 9, offset = 0 },
			{ face = "South", width = 4, height = 8, offset = 12 },
		},
	})
	local frontZ = storeCenter.Z - storeSize.Z / 2 - 0.25
	for _, x in { storeCenter.X - 13, storeCenter.X + 13 } do
		local pane = Builder.decor(
			store,
			"ShopWindow",
			Vector3.new(16, 6, 0.3),
			CFrame.new(x, top + 4, frontZ),
			Color3.fromRGB(255, 236, 200),
			Enum.Material.Neon,
			{ Transparency = 0.25 }
		)
		pane:SetAttribute("Lit", true)
		pane:AddTag(Constants.Tags.WindowLight)
	end
	local sign = Builder.decor(
		store,
		"NiteOwlSign",
		Vector3.new(22, 3.2, 0.5),
		CFrame.new(storeCenter.X, top + 10, frontZ - 0.3),
		Color3.fromRGB(18, 10, 24),
		Enum.Material.SmoothPlastic
	)
	Builder.sign(
		sign,
		Enum.NormalId.Front,
		"NITE OWL  24/7",
		{ color = palette.NeonPink, lit = true, font = Enum.Font.GothamBlack }
	)
	local glow = Builder.decor(
		store,
		"SignGlow",
		Vector3.new(1, 1, 1),
		CFrame.new(storeCenter.X, top + 10, frontZ - 2),
		palette.NeonPink,
		Enum.Material.SmoothPlastic,
		{ Transparency = 1 }
	)
	Builder.pointLight(glow, palette.NeonPink, 26, 1.2, false)

	-- Inredning: hyllor, disk, kylväggar, lysrör
	for k = -1, 1 do
		Builder.box(
			store,
			"Shelf",
			Vector3.new(2.4, 5, 14),
			CFrame.new(storeCenter.X - 6 + k * 7, top + 2.6, storeCenter.Z + 1),
			Color3.fromRGB(220, 220, 214),
			Enum.Material.SmoothPlastic
		)
	end
	Builder.box(
		store,
		"Counter",
		Vector3.new(9, 3.6, 3),
		CFrame.new(storeCenter.X + 14, top + 1.9, storeCenter.Z - 9),
		Color3.fromRGB(110, 40, 90),
		Enum.Material.SmoothPlastic
	)
	local fridge = Builder.decor(
		store,
		"FridgeWall",
		Vector3.new(0.4, 7, 20),
		CFrame.new(storeCenter.X - 20.6, top + 4, storeCenter.Z),
		Color3.fromRGB(200, 236, 255),
		Enum.Material.Neon,
		{ Transparency = 0.2 }
	)
	fridge:SetAttribute("Lit", true)
	fridge:AddTag(Constants.Tags.WindowLight)
	for _, dx in { -10, 10 } do
		local panel = Builder.decor(
			store,
			"CeilingPanel",
			Vector3.new(8, 0.2, 2),
			CFrame.new(storeCenter.X + dx, top + 11.8, storeCenter.Z),
			Color3.fromRGB(240, 250, 255),
			Enum.Material.Neon
		)
		panel:AddTag("AH_InteriorLight")
		Builder.pointLight(panel, Color3.fromRGB(235, 245, 255), 24, 1.1, false)
	end
	-- Lagret längst in (bakom en vägg med dörröppning)
	local partitionZ = storeCenter.Z + 7
	Builder.box(
		store,
		"Partition",
		Vector3.new(6, 12, 0.6),
		CFrame.new(storeCenter.X + 11, top + 6, partitionZ),
		Color3.fromRGB(70, 60, 76),
		Enum.Material.Concrete
	)
	Builder.box(
		store,
		"Partition",
		Vector3.new(4, 12, 0.6),
		CFrame.new(storeCenter.X + 20, top + 6, partitionZ),
		Color3.fromRGB(70, 60, 76),
		Enum.Material.Concrete
	)
	Builder.box(
		store,
		"Partition",
		Vector3.new(4, 4, 0.6),
		CFrame.new(storeCenter.X + 16, top + 10, partitionZ),
		Color3.fromRGB(70, 60, 76),
		Enum.Material.Concrete
	)
	local staffSign = Builder.decor(
		store,
		"StaffSign",
		Vector3.new(3, 0.8, 0.1),
		CFrame.new(storeCenter.X + 16, top + 8.6, partitionZ - 0.4),
		Color3.fromRGB(20, 20, 20),
		Enum.Material.SmoothPlastic
	)
	Builder.sign(staffSign, Enum.NormalId.Front, "STAFF ONLY", { color = Color3.new(1, 1, 1), pixelsPerStud = 20 })
	Builder.box(
		store,
		"Boxes",
		Vector3.new(4, 3, 3),
		CFrame.new(storeCenter.X + 18, top + 1.6, storeCenter.Z + 11),
		Color3.fromRGB(150, 120, 80),
		Enum.Material.Cardboard
	)
	ctx.addSite(
		"StoreBackroom",
		"NiteOwlBackroom",
		"the Nite Owl Mart stockroom",
		CFrame.new(storeCenter.X + 14, top + 2, storeCenter.Z + 11),
		nil
	)

	-- Affischen med symbolnyckeln (texten skrivs av CityBuilder från SecretConfig)
	local poster = Builder.decor(
		store,
		"Poster",
		Vector3.new(0.1, 5, 4),
		CFrame.new(storeCenter.X + 20.9, top + 5, storeCenter.Z - 2),
		Color3.fromRGB(250, 240, 220),
		Enum.Material.SmoothPlastic
	)
	ctx.addPoster("PosterStore", poster, Enum.NormalId.Left)

	ctx.addZone("Safe", "Nite Owl Mart", CFrame.new(storeCenter.X, top + 6, storeCenter.Z), storeSize)
	ctx.addLoot("Interior", Vector3.new(storeCenter.X - 2, top + 0.6, storeCenter.Z + 9))
	ctx.addLoot("Interior", Vector3.new(storeCenter.X + 18, top + 0.6, storeCenter.Z + 9))

	-- Gränden och Maintenance B-7 -------------------------------------------------------
	local b7 = Buildings.annex(ctx, root, {
		name = "MaintenanceB7",
		center = Vector3.new(c.X - 26, top, c.Z - 1),
		size = Vector3.new(16, 9, 14),
		doorFace = "North",
		gateId = "Maintenance7",
		sign = "MAINTENANCE  B-7",
		wallColor = palette.ConcreteDark,
		wallMaterial = Enum.Material.Concrete,
	})
	local keypad = Builder.box(
		root,
		"Keypad",
		Vector3.new(1.2, 1.6, 0.3),
		b7.doorCFrame * CFrame.new(3.6, 0.2, -0.4),
		Color3.fromRGB(40, 44, 50),
		Enum.Material.Metal
	)
	local keyLed = Builder.decor(
		root,
		"KeypadLed",
		Vector3.new(0.3, 0.3, 0.1),
		keypad.CFrame * CFrame.new(0, 0.6, -0.2),
		Color3.fromRGB(255, 40, 40),
		Enum.Material.Neon
	)
	ctx.world.keypad = { part = keypad, led = keyLed, gateId = "Maintenance7" }
	Builder.prompt(
		keypad,
		Constants.Actions.Keypad,
		"Maintenance7",
		{ actionText = "Enter code", objectText = "Keypad", distance = 8 }
	)
	Builder.box(
		b7.model,
		"Desk",
		Vector3.new(6, 3, 3),
		CFrame.new(b7.center + Vector3.new(-3, 1.5, 4)),
		Color3.fromRGB(70, 60, 50),
		Enum.Material.Wood
	)
	local note = Builder.decor(
		b7.model,
		"Note",
		Vector3.new(1.2, 0.05, 1.6),
		CFrame.new(b7.center + Vector3.new(-3, 3.05, 4)),
		Color3.fromRGB(240, 236, 220),
		Enum.Material.SmoothPlastic
	)
	Builder.prompt(
		note,
		Constants.Actions.Investigate,
		"NoteB7",
		{ actionText = "Read", objectText = "Shift log", distance = 6 }
	)
	ctx.addLoot("Secret", b7.center + Vector3.new(4, 0.5, 3))
	ctx.addDiscovery("Maintenance7", CFrame.new(b7.center + Vector3.new(0, 4, 0)), Vector3.new(14, 8, 12))
	ctx.world.maintenance7 = b7

	for _, p in { Vector3.new(c.X - 46, 0, c.Z - 14), Vector3.new(c.X + 2, 0, c.Z - 15) } do
		Builder.box(
			root,
			"Dumpster",
			Vector3.new(6, 4, 3.5),
			CFrame.new(p.X, top + 2, p.Z),
			Color3.fromRGB(40, 70, 52),
			Enum.Material.Metal
		)
	end
	ctx.addLoot("Alley", Vector3.new(c.X - 34, top + 0.5, c.Z - 16))
	ctx.addLoot("Alley", Vector3.new(c.X - 6, top + 0.5, c.Z - 13))

	-- Byggnader runt omkring -------------------------------------------------------------
	Buildings.build(ctx, root, {
		name = "SouthFlats",
		center = Vector3.new(c.X - 25, 0, c.Z + 31),
		size = Vector3.new(58, 50, 46),
		color = palette.Brick,
		material = Enum.Material.Brick,
		windows = { faces = { "North", "West", "South" }, style = "Residential" },
	})
	Buildings.build(ctx, root, {
		name = "CornerBuilding",
		center = Vector3.new(c.X + 30, 0, c.Z + 31),
		size = Vector3.new(44, 64, 46),
		color = palette.Plaster,
		material = Enum.Material.Concrete,
		windows = { faces = { "East", "South", "North" }, style = "Residential" },
	})
	Buildings.build(ctx, root, {
		name = "LumenCorner",
		center = Vector3.new(c.X + 24, 0, c.Z - 38),
		size = Vector3.new(56, 40, 36),
		color = palette.BrickDark,
		material = Enum.Material.Brick,
		windows = { faces = { "North", "East" }, style = "Residential" },
		storefront = { face = "North", sign = "PAWN & LOAN", signColor = Color3.fromRGB(255, 200, 80), lit = false },
	})

	-- Apoteket som stängde förra året (rum för SOMETHING INSIDE)
	local pharmacy = Buildings.annex(ctx, root, {
		name = "Pharmacy",
		center = Vector3.new(c.X + 43, top, c.Z - 3),
		size = Vector3.new(18, 10, 18),
		doorFace = "East",
		gateId = "Twist_Pharmacy",
		sign = "PHARMACY - CLOSED",
		wallColor = Color3.fromRGB(200, 196, 186),
		wallMaterial = Enum.Material.Concrete,
	})
	ctx.addTwistRoom("Pharmacy", "the closed pharmacy on Mercer St", pharmacy)
	return root
end

return Store
