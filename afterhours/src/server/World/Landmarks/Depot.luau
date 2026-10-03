-- Dispatch Depot 03: hubben. Här börjar och slutar varje skift.
--   * DISPATCH-disken: välj kontrakt
--   * SUPPLY LOCKER: köp uppgraderingar och utseende för krediter
--   * Lastkajen (SECURE): säkra föremål och kontraktspengar
-- Hela tomten är en säker zon och räknas som "hemma" när klockan slår 03:00.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Builder = require(script.Parent.Parent.Builder)
local Buildings = require(script.Parent.Parent.Buildings)
local Site9 = require(script.Parent.Site9)

local Depot = {}

local function van(parent: Instance, position: Vector3, yaw: number)
	local model = Builder.model(parent, "Van")
	local base = CFrame.new(position) * CFrame.Angles(0, yaw, 0)
	local body = Builder.box(
		model,
		"Body",
		Vector3.new(7, 7, 16),
		base * CFrame.new(0, 4.4, 0),
		Color3.fromRGB(226, 228, 230),
		Enum.Material.SmoothPlastic
	)
	Builder.box(
		model,
		"Stripe",
		Vector3.new(7.1, 1, 16.1),
		base * CFrame.new(0, 3.2, 0),
		Color3.fromRGB(40, 210, 230),
		Enum.Material.SmoothPlastic
	)
	Builder.box(
		model,
		"Windshield",
		Vector3.new(6.6, 2.4, 0.3),
		base * CFrame.new(0, 6, -8.05),
		Color3.fromRGB(20, 26, 34),
		Enum.Material.Glass
	)
	for _, w in
		{ Vector3.new(-3.3, 1.2, -5), Vector3.new(3.3, 1.2, -5), Vector3.new(-3.3, 1.2, 5), Vector3.new(3.3, 1.2, 5) }
	do
		Builder.decor(
			model,
			"Wheel",
			Vector3.new(1, 2.4, 2.4),
			base * CFrame.new(w),
			Color3.fromRGB(18, 18, 20),
			Enum.Material.SmoothPlastic,
			{ Shape = Enum.PartType.Cylinder }
		)
	end
	Builder.sign(body, Enum.NormalId.Right, "AFTERHOURS", { color = Color3.fromRGB(20, 30, 40), pixelsPerStud = 12 })
	Builder.sign(body, Enum.NormalId.Left, "AFTERHOURS", { color = Color3.fromRGB(20, 30, 40), pixelsPerStud = 12 })
	return model
end

function Depot.build(ctx, layout)
	local palette = ctx.palette
	local root = Builder.model(ctx.root, "DispatchDepot")
	local top = ctx.config.sidewalkHeight
	local z0 = layout.half -- tomtens norra kant
	local halfW = ctx.depotHalfWidth
	local zBuilding, zBack, zEnd = z0 + 68, z0 + 114, z0 + 120
	local floorY = top + 0.1

	-- Mark --------------------------------------------------------------------------------
	Builder.box(
		root,
		"Lot",
		Vector3.new(halfW * 2, 2.6, zBuilding - z0),
		CFrame.new(0, top - 1.3, (z0 + zBuilding) / 2),
		Color3.fromRGB(44, 46, 52),
		Enum.Material.Asphalt
	)
	for _, sign in { -1, 1 } do
		Builder.box(
			root,
			"LotSide",
			Vector3.new(halfW - 70, 2.6, zEnd - zBuilding),
			CFrame.new(sign * (70 + (halfW - 70) / 2), top - 1.3, (zBuilding + zEnd) / 2),
			Color3.fromRGB(44, 46, 52),
			Enum.Material.Asphalt
		)
	end
	Builder.box(
		root,
		"LotBack",
		Vector3.new(140, 2.6, zEnd - zBack),
		CFrame.new(0, top - 1.3, (zBack + zEnd) / 2),
		Color3.fromRGB(44, 46, 52),
		Enum.Material.Asphalt
	)
	for k = -4, 4 do
		Builder.decor(
			root,
			"ParkingLine",
			Vector3.new(0.4, 0.05, 14),
			CFrame.new(k * 11, top + 0.03, z0 + 50),
			palette.LaneWhite,
			Enum.Material.SmoothPlastic
		)
	end

	-- Stängsel med infart från Depot Rd
	local fence = Site9.fence
	fence(root, Vector3.new(-halfW, top, z0), Vector3.new(-30, top, z0), 10)
	fence(root, Vector3.new(30, top, z0), Vector3.new(halfW, top, z0), 10)
	fence(root, Vector3.new(-halfW, top, z0), Vector3.new(-halfW, top, zEnd), 10)
	fence(root, Vector3.new(halfW, top, z0), Vector3.new(halfW, top, zEnd), 10)
	fence(root, Vector3.new(-halfW, top, zEnd), Vector3.new(halfW, top, zEnd), 10)
	for _, x in { -30, 30 } do
		Builder.box(
			root,
			"GatePost",
			Vector3.new(1.2, 12, 1.2),
			CFrame.new(x, top + 6, z0),
			palette.SafetyYellow,
			Enum.Material.Metal
		)
	end

	-- Depåbyggnaden (öppen mot norr) ------------------------------------------------------------
	local hallCenter = Vector3.new(0, floorY, (zBuilding + zBack) / 2)
	local hallSize = Vector3.new(140, 18, zBack - zBuilding)
	local hall = Buildings.room(ctx, root, "DepotHall", hallCenter, hallSize, {
		openFaces = { "North" },
		wallColor = Color3.fromRGB(70, 76, 86),
		floorColor = Color3.fromRGB(96, 98, 104),
	})
	Builder.box(
		hall,
		"Lintel",
		Vector3.new(140, 6, 1),
		CFrame.new(0, floorY + 15, zBuilding + 0.5),
		Color3.fromRGB(70, 76, 86),
		Enum.Material.Concrete
	)
	for _, x in { -69.5, -35, 0, 35, 69.5 } do
		Builder.box(
			hall,
			"Pillar",
			Vector3.new(1.5, 12, 1.5),
			CFrame.new(x, floorY + 6, zBuilding + 0.75),
			palette.SafetyYellow,
			Enum.Material.Metal
		)
	end
	local banner = Builder.decor(
		hall,
		"DepotSign",
		Vector3.new(60, 4, 0.4),
		CFrame.new(0, floorY + 15, zBuilding - 0.3),
		Color3.fromRGB(10, 14, 20),
		Enum.Material.SmoothPlastic
	)
	Builder.sign(
		banner,
		Enum.NormalId.Front,
		"AFTERHOURS DISPATCH  -  DEPOT 03",
		{ color = Color3.fromRGB(80, 230, 255), lit = true, font = Enum.Font.GothamBlack }
	)
	local glow = Builder.anchor(hall, "SignGlow", Vector3.one, CFrame.new(0, floorY + 13, zBuilding - 4))
	Builder.pointLight(glow, Color3.fromRGB(80, 220, 255), 40, 1.2, false)
	for _, x in { -45, 0, 45 } do
		for _, dz in { 12, 34 } do
			local tube = Builder.decor(
				hall,
				"Fluorescent",
				Vector3.new(10, 0.3, 0.8),
				CFrame.new(x, floorY + 17.6, zBuilding + dz),
				Color3.fromRGB(255, 244, 226),
				Enum.Material.Neon
			)
			tube:AddTag("AH_InteriorLight")
			Builder.pointLight(tube, Color3.fromRGB(255, 240, 220), 30, 1.1, false)
		end
	end

	-- Dispatch-disken
	local desk = Builder.box(
		hall,
		"DispatchDesk",
		Vector3.new(14, 3.6, 4),
		CFrame.new(0, floorY + 1.8, zBuilding + 30),
		Color3.fromRGB(40, 44, 52),
		Enum.Material.SmoothPlastic
	)
	local screen = Builder.decor(
		hall,
		"DispatchScreen",
		Vector3.new(18, 7, 0.4),
		CFrame.new(0, floorY + 8, zBack - 1.4),
		Color3.fromRGB(8, 18, 30),
		Enum.Material.Neon
	)
	Builder.sign(
		screen,
		Enum.NormalId.Front,
		"DISPATCH\nTONIGHT'S CONTRACTS",
		{ color = Color3.fromRGB(90, 230, 255), lit = true }
	)
	Builder.prompt(
		desk,
		Constants.Actions.Dispatch,
		"Dispatch",
		{ actionText = "Open dispatch", objectText = "Dispatch", distance = 12 }
	)
	ctx.world.depot.dispatch = desk
	ctx.world.npc.posts.Dispatcher =
		Builder.lookAt(Vector3.new(0, floorY + 3, zBuilding + 33), Vector3.new(0, floorY + 3, z0))
	local shelf = Builder.box(
		hall,
		"ParcelShelf",
		Vector3.new(8, 6, 2.4),
		CFrame.new(-14, floorY + 3, zBack - 2),
		Color3.fromRGB(120, 96, 70),
		Enum.Material.WoodPlanks
	)
	Builder.box(
		hall,
		"Parcel",
		Vector3.new(2.4, 1.8, 2),
		CFrame.new(-15, floorY + 5.2, zBack - 2),
		Color3.fromRGB(176, 140, 96),
		Enum.Material.Cardboard
	)
	ctx.world.depot.pickup = ctx.addSite(
		"DepotPickup",
		"DepotShelf",
		"the depot parcel shelf",
		shelf.CFrame * CFrame.new(0, -1, -2.4),
		shelf
	)

	-- Förrådsskåpen
	for k = 0, 5 do
		Builder.box(
			hall,
			"Locker",
			Vector3.new(3, 7, 2.4),
			CFrame.new(-56 + k * 3.2, floorY + 3.5, zBack - 1.6),
			Color3.fromRGB(60, 90, 120),
			Enum.Material.Metal
		)
	end
	local lockerSign = Builder.decor(
		hall,
		"LockerSign",
		Vector3.new(19, 1.6, 0.2),
		CFrame.new(-48, floorY + 8, zBack - 1.2),
		Color3.fromRGB(20, 24, 30),
		Enum.Material.SmoothPlastic
	)
	Builder.sign(
		lockerSign,
		Enum.NormalId.Front,
		"SUPPLY LOCKER",
		{ color = Color3.fromRGB(230, 230, 220), lit = true }
	)
	local lockerPrompt =
		Builder.anchor(hall, "LockerPrompt", Vector3.new(2, 2, 2), CFrame.new(-48, floorY + 3, zBack - 4))
	Builder.prompt(
		lockerPrompt,
		Constants.Actions.Locker,
		"Locker",
		{ actionText = "Open locker", objectText = "Supply locker", distance = 12 }
	)
	ctx.world.depot.locker = lockerPrompt

	-- Fikarummet med en av affischerna
	Builder.box(
		hall,
		"BreakTable",
		Vector3.new(6, 3, 4),
		CFrame.new(-62, floorY + 1.5, zBuilding + 12),
		Color3.fromRGB(110, 90, 70),
		Enum.Material.Wood
	)
	local vending = Builder.box(
		hall,
		"Vending",
		Vector3.new(4, 7, 3),
		CFrame.new(-66.8, floorY + 3.5, zBuilding + 22),
		Color3.fromRGB(150, 30, 40),
		Enum.Material.SmoothPlastic
	)
	local vendGlow = Builder.decor(
		hall,
		"VendingGlow",
		Vector3.new(0.2, 5, 2.4),
		vending.CFrame * CFrame.new(2.05, 0.5, 0),
		Color3.fromRGB(255, 240, 220),
		Enum.Material.Neon
	)
	vendGlow:SetAttribute("Lit", true)
	vendGlow:AddTag(Constants.Tags.WindowLight)
	local poster = Builder.decor(
		hall,
		"Poster",
		Vector3.new(0.1, 5, 4),
		CFrame.new(-68.9, floorY + 5, zBuilding + 8),
		Color3.fromRGB(240, 236, 220),
		Enum.Material.SmoothPlastic
	)
	ctx.addPoster("PosterDepot", poster, Enum.NormalId.Right)

	-- Lastkajen: säkra föremål och kontraktspengar här
	local bay = Vector3.new(48, floorY, zBuilding + 24)
	for k = -4, 4 do
		Builder.decor(
			hall,
			"BayStripe",
			Vector3.new(2, 0.05, 36),
			CFrame.new(bay.X + k * 4, floorY + 0.03, bay.Z) * CFrame.Angles(0, 0.4, 0),
			if k % 2 == 0 then palette.SafetyYellow else Color3.fromRGB(20, 20, 20),
			Enum.Material.SmoothPlastic
		)
	end
	local cage = Builder.box(
		hall,
		"SecureCage",
		Vector3.new(12, 8, 2),
		CFrame.new(bay.X, floorY + 4, zBack - 1.5),
		Color3.fromRGB(90, 96, 104),
		Enum.Material.DiamondPlate
	)
	Builder.sign(
		cage,
		Enum.NormalId.Front,
		"SECURE ITEMS",
		{ color = palette.SafetyYellow, lit = true, font = Enum.Font.GothamBlack }
	)
	local secureAnchor =
		Builder.anchor(hall, "SecurePrompt", Vector3.new(2, 2, 2), CFrame.new(bay.X, floorY + 3, zBack - 5))
	Builder.prompt(
		secureAnchor,
		Constants.Actions.Secure,
		"Depot",
		{ actionText = "Secure", objectText = "Loading bay", hold = 1, distance = 14 }
	)
	local bayLight = Builder.anchor(hall, "BayLight", Vector3.one, CFrame.new(bay.X, floorY + 14, bay.Z))
	Builder.pointLight(bayLight, Color3.fromRGB(255, 210, 90), 30, 1.3, false)
	ctx.world.depot.secure = secureAnchor

	-- Skåpbilar och strålkastare
	van(root, Vector3.new(-40, top, z0 + 40), 0.1)
	van(root, Vector3.new(-56, top, z0 + 44), -0.05)
	van(root, Vector3.new(56, top, z0 + 38), math.pi + 0.2)
	for _, p in
		{
			Vector3.new(-halfW + 6, 0, z0 + 6),
			Vector3.new(halfW - 6, 0, z0 + 6),
			Vector3.new(-halfW + 6, 0, zBuilding - 6),
			Vector3.new(halfW - 6, 0, zBuilding - 6),
		}
	do
		local post = Builder.box(
			root,
			"FloodPost",
			Vector3.new(0.8, 20, 0.8),
			CFrame.new(p.X, top + 10, p.Z),
			palette.Steel,
			Enum.Material.Metal
		)
		local head = Builder.decor(
			root,
			"FloodHead",
			Vector3.new(2.4, 1.2, 1.2),
			Builder.lookAt(post.CFrame.Position + Vector3.new(0, 10, 0), Vector3.new(0, 0, z0 + 40)),
			Color3.fromRGB(255, 250, 235),
			Enum.Material.Neon
		)
		head:AddTag(Constants.Tags.StreetLight)
		Builder.spotLight(head, Enum.NormalId.Front, Color3.fromRGB(255, 244, 222), 70, 60, 1.6, false)
	end

	-- Kulisser bakom stängslet
	for _, spec in
		{
			{ Vector3.new(-halfW - 30, 0, z0 + 88), Vector3.new(56, 90, 80), "East" },
			{ Vector3.new(halfW + 30, 0, z0 + 88), Vector3.new(56, 70, 80), "West" },
			{ Vector3.new(0, 0, zEnd + 30), Vector3.new(260, 60, 50), "North" },
		}
	do
		Buildings.build(ctx, root, {
			name = "DepotBackdrop",
			center = spec[1],
			size = spec[2],
			color = palette.ConcreteDark,
			material = Enum.Material.Concrete,
			windows = { faces = { spec[3] }, style = "Industrial", litChance = 0.1 },
			roof = { noProps = true },
		})
	end

	-- Zoner och spawn
	local zoneCFrame = CFrame.new(0, 18, (z0 + zEnd) / 2)
	local zoneSize = Vector3.new(halfW * 2, 40, zEnd - z0)
	ctx.addZone("Safe", "Dispatch Depot", zoneCFrame, zoneSize)
	ctx.addZone("Extraction", "Dispatch Depot", zoneCFrame, zoneSize)
	ctx.world.depot.spawn =
		Builder.lookAt(Vector3.new(0, floorY + 3.5, zBuilding + 20), Vector3.new(0, floorY + 3.5, z0))
	ctx.world.depot.center = Vector3.new(0, floorY, (z0 + zEnd) / 2)
	return root
end

return Depot
