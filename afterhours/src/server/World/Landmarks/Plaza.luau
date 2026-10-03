-- Mercer Plaza och den stängda tunnelbanestationen under den (Line 3, stängd sedan 1987).
--
-- Ingångar:
--   * Huvudtrappan i mitten av torget. Rullgallret är nere, utom under CLOSED STATION.
--   * Servicedörren (StationService) i den lilla hyddan, för den som har ett HIGH RISK-kontrakt.
--   * Nödluckan längst österut. Den öppnas bara inifrån, så ingen blir instängd.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Builder = require(script.Parent.Parent.Builder)
local Buildings = require(script.Parent.Parent.Buildings)

local Plaza = {}

local FLOOR = -18 -- stationens golvnivå (ovansidan)

function Plaza.build(ctx, c: Vector3, layout)
	local palette = ctx.palette
	local root = Builder.model(ctx.root, "MercerPlaza")
	local top = ctx.config.sidewalkHeight
	local ph = layout.platformHalf
	local stone = Color3.fromRGB(104, 100, 96)

	-- Torgets mark, med hål för huvudtrappan och servicetrappan ---------------------
	local holes = {
		{ x1 = c.X - 7, x2 = c.X + 7, z1 = c.Z + 6, z2 = c.Z + 36 }, -- huvudtrappan
		{ x1 = c.X + 30, x2 = c.X + 36, z1 = c.Z - 24, z2 = c.Z - 4 }, -- servicetrappan
	}
	local xs = { c.X - ph, c.X + ph }
	for _, h in holes do
		table.insert(xs, h.x1)
		table.insert(xs, h.x2)
	end
	table.sort(xs)
	for i = 1, #xs - 1 do
		local x1, x2 = xs[i], xs[i + 1]
		if x2 - x1 > 0.01 then
			local zCuts = { { c.Z - ph, c.Z + ph } }
			for _, h in holes do
				if x1 >= h.x1 - 0.01 and x2 <= h.x2 + 0.01 then
					local next = {}
					for _, seg in zCuts do
						if h.z1 > seg[1] then
							table.insert(next, { seg[1], math.min(h.z1, seg[2]) })
						end
						if h.z2 < seg[2] then
							table.insert(next, { math.max(h.z2, seg[1]), seg[2] })
						end
					end
					zCuts = next
				end
			end
			for _, seg in zCuts do
				if seg[2] - seg[1] > 0.01 then
					Builder.box(
						root,
						"PlazaGround",
						Vector3.new(x2 - x1, 2.6, seg[2] - seg[1]),
						CFrame.new((x1 + x2) / 2, top - 1.3, (seg[1] + seg[2]) / 2),
						stone,
						Enum.Material.Pavement
					)
				end
			end
		end
	end

	-- Planteringar, bänkar, kiosk ----------------------------------------------------
	for _, offset in
		{ Vector3.new(-34, 0, -34), Vector3.new(34, 0, 34), Vector3.new(-34, 0, 34), Vector3.new(-6, 0, -36) }
	do
		local p = c + offset
		Builder.box(
			root,
			"Planter",
			Vector3.new(10, 2, 10),
			CFrame.new(p.X, top + 1, p.Z),
			palette.ConcreteDark,
			Enum.Material.Concrete
		)
		Builder.box(
			root,
			"Soil",
			Vector3.new(9, 0.4, 9),
			CFrame.new(p.X, top + 2.1, p.Z),
			palette.Grass,
			Enum.Material.Grass
		)
		Builder.cylinder(
			root,
			"Trunk",
			8,
			1,
			CFrame.new(p.X, top + 6, p.Z) * CFrame.Angles(0, 0, math.pi / 2),
			Color3.fromRGB(70, 50, 36),
			Enum.Material.Wood
		)
		Builder.box(
			root,
			"Leaves",
			Vector3.new(8, 6, 8),
			CFrame.new(p.X, top + 12, p.Z),
			Color3.fromRGB(34, 58, 36),
			Enum.Material.Grass,
			{ Shape = Enum.PartType.Ball, CastShadow = true }
		)
	end
	for _, b in { { -20, -10, 0 }, { -20, 0, 0 }, { 20, 16, math.pi }, { 20, 26, math.pi } } do
		local p = c + Vector3.new(b[1], 0, b[2])
		local cf = CFrame.new(p.X, top + 1, p.Z) * CFrame.Angles(0, b[3] + math.pi / 2, 0)
		Builder.box(root, "Bench", Vector3.new(6, 0.5, 2), cf, Color3.fromRGB(84, 60, 44), Enum.Material.WoodPlanks)
		Builder.box(
			root,
			"BenchBack",
			Vector3.new(6, 1.6, 0.4),
			cf * CFrame.new(0, 1, 0.9),
			Color3.fromRGB(84, 60, 44),
			Enum.Material.WoodPlanks
		)
	end
	local kiosk = Builder.box(
		root,
		"Kiosk",
		Vector3.new(8, 7, 6),
		CFrame.new(c.X - 30, top + 3.5, c.Z - 8),
		Color3.fromRGB(46, 70, 60),
		Enum.Material.Metal
	)
	Builder.sign(
		kiosk,
		Enum.NormalId.Front,
		"NEWS - CLOSED",
		{ color = Color3.fromRGB(230, 220, 190), pixelsPerStud = 14 }
	)

	-- Huvudingången: glastak, skylt och rullgaller -----------------------------------
	local entrance = Builder.model(root, "StationEntrance")
	for _, x in { c.X - 7.5, c.X + 7.5 } do
		-- glasväggar ända upp till taket, så att man inte kan hoppa förbi gallret
		Builder.box(
			entrance,
			"EntranceWall",
			Vector3.new(1, 8.6, 30),
			CFrame.new(x, top + 4.3, c.Z + 21),
			Color3.fromRGB(120, 150, 160),
			Enum.Material.Glass,
			{ Transparency = 0.4 }
		)
		Builder.box(
			entrance,
			"CanopyPost",
			Vector3.new(0.6, 9, 0.6),
			CFrame.new(x, top + 4.5, c.Z + 36),
			palette.Steel,
			Enum.Material.Metal
		)
		Builder.box(
			entrance,
			"CanopyPost",
			Vector3.new(0.6, 9, 0.6),
			CFrame.new(x, top + 4.5, c.Z + 8),
			palette.Steel,
			Enum.Material.Metal
		)
	end
	Builder.box(
		entrance,
		"CanopyGlass",
		Vector3.new(16, 0.4, 30),
		CFrame.new(c.X, top + 9.2, c.Z + 22),
		Color3.fromRGB(120, 150, 160),
		Enum.Material.Glass,
		{ Transparency = 0.5 }
	)
	Builder.box(
		entrance,
		"BackWall",
		Vector3.new(16, 8.6, 1),
		CFrame.new(c.X, top + 4.3, c.Z + 5.5),
		palette.ConcreteDark,
		Enum.Material.Concrete
	)
	local stationSign = Builder.box(
		entrance,
		"StationSign",
		Vector3.new(14, 2.4, 0.4),
		CFrame.new(c.X, top + 10.8, c.Z + 37),
		Color3.fromRGB(20, 40, 90),
		Enum.Material.SmoothPlastic
	)
	Builder.sign(stationSign, Enum.NormalId.Back, "MERCER ST  -  LINE 3", { color = Color3.new(1, 1, 1), lit = true })
	local shutter = Builder.box(
		entrance,
		"Shutter",
		Vector3.new(14, 8.5, 0.6),
		CFrame.new(c.X, top + 4.25, c.Z + 36.5),
		Color3.fromRGB(110, 112, 104),
		Enum.Material.CorrodedMetal
	)
	shutter:AddTag(Constants.Tags.AccessGate)
	shutter:SetAttribute("GateId", "StationShutter")
	ctx.addGate("StationShutter", shutter)
	Builder.sign(shutter, Enum.NormalId.Back, "CLOSED", { color = Color3.fromRGB(220, 60, 50), pixelsPerStud = 10 })

	-- Huvudtrappan ned till hallen
	Builder.ramp(
		entrance,
		"MainStairs",
		Vector3.new(c.X, top, c.Z + 36),
		Vector3.new(c.X, FLOOR, c.Z + 8),
		13.6,
		palette.ConcreteDark,
		Enum.Material.Concrete
	)
	for _, x in { c.X - 7.5, c.X + 7.5 } do
		Builder.box(
			entrance,
			"StairWall",
			Vector3.new(1, 20, 30),
			CFrame.new(x, (FLOOR + top) / 2 - 1, c.Z + 21),
			palette.Concrete,
			Enum.Material.Concrete
		)
	end

	-- Hallen (biljetthallen) ---------------------------------------------------------
	local hall = Buildings.room(ctx, root, "Concourse", Vector3.new(c.X, FLOOR, c.Z - 6), Vector3.new(40, 12, 28), {
		wallColor = Color3.fromRGB(150, 160, 150),
		floorColor = Color3.fromRGB(80, 84, 82),
		doors = {
			{ face = "South", width = 14, height = 11, offset = 0 },
			{ face = "North", width = 30, height = 10, offset = 0 },
		},
	})
	for k = -3, 3 do
		Builder.box(
			hall,
			"Turnstile",
			Vector3.new(0.8, 3.2, 3),
			CFrame.new(c.X + k * 4, FLOOR + 1.6, c.Z - 8),
			palette.Steel,
			Enum.Material.Metal
		)
	end
	for _, x in { c.X - 14, c.X + 14 } do
		local tube = Builder.decor(
			hall,
			"Fluorescent",
			Vector3.new(6, 0.3, 0.6),
			CFrame.new(x, FLOOR + 11.6, c.Z - 6),
			Color3.fromRGB(200, 230, 220),
			Enum.Material.Neon
		)
		tube:AddTag("AH_FlickerLight")
		Builder.pointLight(tube, Color3.fromRGB(190, 225, 215), 22, 0.8, false)
	end

	-- Perrongen ------------------------------------------------------------------------
	local platformCenter = Vector3.new(c.X, FLOOR, c.Z - 32)
	local platform = Buildings.room(ctx, root, "Platform", platformCenter, Vector3.new(140, 13, 24), {
		wallColor = Color3.fromRGB(196, 190, 170),
		floorColor = Color3.fromRGB(120, 116, 108),
		doors = {
			{ face = "South", width = 30, height = 10, offset = 0 },
			{ face = "South", width = 6, height = 10, offset = 33 },
		},
	})
	-- Spårgraven och spåren (norra halvan av perrongen)
	Builder.box(
		platform,
		"TrackBed",
		Vector3.new(140, 1, 9),
		CFrame.new(c.X, FLOOR - 0.4, c.Z - 39.5),
		Color3.fromRGB(36, 34, 32),
		Enum.Material.Slate
	)
	for _, dz in { -1.6, 1.6 } do
		Builder.decor(
			platform,
			"Rail",
			Vector3.new(140, 0.3, 0.3),
			CFrame.new(c.X, FLOOR + 0.2, c.Z - 39.5 + dz),
			Color3.fromRGB(90, 80, 70),
			Enum.Material.Metal
		)
	end
	Builder.decor(
		platform,
		"EdgeLine",
		Vector3.new(140, 0.06, 0.8),
		CFrame.new(c.X, FLOOR + 0.03, c.Z - 34.6),
		palette.SafetyYellow,
		Enum.Material.SmoothPlastic
	)
	for _, x in { c.X - 69.5, c.X + 69.5 } do
		Builder.box(
			platform,
			"TunnelGrate",
			Vector3.new(1, 9, 9),
			CFrame.new(x, FLOOR + 4.5, c.Z - 39.5),
			Color3.fromRGB(30, 30, 30),
			Enum.Material.DiamondPlate,
			{ Transparency = 0.3 }
		)
	end
	for k = -2, 2 do
		local tube = Builder.decor(
			platform,
			"Fluorescent",
			Vector3.new(8, 0.3, 0.6),
			CFrame.new(c.X + k * 26, FLOOR + 12.6, c.Z - 28),
			Color3.fromRGB(200, 230, 220),
			Enum.Material.Neon
		)
		tube:AddTag("AH_FlickerLight")
		Builder.pointLight(tube, Color3.fromRGB(190, 225, 215), 24, 0.7, false)
	end
	local lineSign = Builder.decor(
		platform,
		"LineSign",
		Vector3.new(16, 3, 0.3),
		CFrame.new(c.X - 30, FLOOR + 7, c.Z - 20.8) * CFrame.Angles(0, math.pi, 0),
		Color3.fromRGB(20, 40, 90),
		Enum.Material.SmoothPlastic
	)
	Builder.sign(lineSign, Enum.NormalId.Front, "LINE 3  -  MERCER ST", { color = Color3.new(1, 1, 1) })

	-- Väggen med veckans symboler (fylls i av SecretService)
	local wall = Builder.decor(
		platform,
		"SymbolWall",
		Vector3.new(14, 4, 0.2),
		CFrame.new(c.X + 30, FLOOR + 6, c.Z - 20.8) * CFrame.Angles(0, math.pi, 0),
		Color3.fromRGB(196, 190, 170),
		Enum.Material.Concrete
	)
	local _, symbolLabel = Builder.sign(wall, Enum.NormalId.Front, "", {
		color = Color3.fromRGB(150, 20, 24),
		font = Enum.Font.GothamBlack,
		name = "Symbols",
	})
	ctx.world.station.symbolLabel = symbolLabel

	-- Signalrummet i västra änden (HIGH RISK-kontraktets mål)
	local signalRoom =
		Buildings.room(ctx, root, "SignalRoom", Vector3.new(c.X - 61, FLOOR, c.Z - 25), Vector3.new(14, 9, 8), {
			floor = false, -- står på perrongens golv
			wallColor = Color3.fromRGB(90, 96, 90),
			doors = { { face = "East", width = 4, height = 7, offset = 0 } },
		})
	local panel = Builder.box(
		signalRoom,
		"SignalPanel",
		Vector3.new(6, 5, 1),
		CFrame.new(c.X - 66, FLOOR + 2.5, c.Z - 25) * CFrame.Angles(0, -math.pi / 2, 0),
		Color3.fromRGB(50, 56, 50),
		Enum.Material.Metal
	)
	local blink = Builder.decor(
		signalRoom,
		"SignalBlink",
		Vector3.new(0.4, 0.4, 0.4),
		panel.CFrame * CFrame.new(1.5, 1.6, -0.6),
		Color3.fromRGB(255, 40, 40),
		Enum.Material.Neon
	)
	blink:AddTag("AH_FlickerLight")
	Builder.pointLight(blink, Color3.fromRGB(255, 60, 50), 10, 1, false)
	ctx.addSite(
		"StationSignal",
		"StationSignal",
		"the Line 3 signal room",
		panel.CFrame * CFrame.new(0, -0.5, -2),
		panel
	)

	-- Servicetrappan och hyddan på torget --------------------------------------------
	local service = Builder.model(root, "ServiceAccess")
	local hutCenter = Vector3.new(c.X + 33, top, c.Z - 14)
	Builder.box(
		service,
		"HutWall",
		Vector3.new(8, 9, 1),
		CFrame.new(hutCenter.X, top + 4.5, c.Z - 24.5),
		palette.ConcreteDark,
		Enum.Material.Concrete
	)
	for _, x in { c.X + 29.5, c.X + 36.5 } do
		Builder.box(
			service,
			"HutWall",
			Vector3.new(1, 9, 22),
			CFrame.new(x, top + 4.5, c.Z - 14),
			palette.ConcreteDark,
			Enum.Material.Concrete
		)
	end
	Builder.box(
		service,
		"HutRoof",
		Vector3.new(8, 0.6, 22),
		CFrame.new(hutCenter.X, top + 9.3, c.Z - 14),
		palette.Steel,
		Enum.Material.Metal
	)
	Builder.box(
		service,
		"HutFront",
		Vector3.new(8, 2, 1),
		CFrame.new(hutCenter.X, top + 8, c.Z - 3.5),
		palette.ConcreteDark,
		Enum.Material.Concrete
	)
	local serviceDoor = Builder.box(
		service,
		"ServiceDoor",
		Vector3.new(6, 7, 0.5),
		CFrame.new(hutCenter.X, top + 3.5, c.Z - 3.5),
		Color3.fromRGB(140, 60, 40),
		Enum.Material.Metal
	)
	Builder.sign(
		serviceDoor,
		Enum.NormalId.Back,
		"LINE 3 SERVICE\nAUTHORIZED ONLY",
		{ color = Color3.new(1, 1, 1), pixelsPerStud = 14 }
	)
	ctx.addGate("StationService", serviceDoor)
	Builder.ramp(
		service,
		"ServiceStairs",
		Vector3.new(c.X + 33, top, c.Z - 4),
		Vector3.new(c.X + 33, FLOOR, c.Z - 24),
		5.6,
		palette.ConcreteDark,
		Enum.Material.Concrete
	)
	for _, x in { c.X + 29.5, c.X + 36.5 } do
		Builder.box(
			service,
			"ShaftWall",
			Vector3.new(1, 20, 20),
			CFrame.new(x, (FLOOR + top) / 2 - 1, c.Z - 14),
			palette.Concrete,
			Enum.Material.Concrete
		)
	end

	-- Nödutgång: knappen längst ner i servicetrappan öppnar servicedörren inifrån,
	-- så att ingen blir instängd när CLOSED STATION tar slut.
	local release = Builder.box(
		service,
		"EmergencyRelease",
		Vector3.new(1.2, 1.6, 0.4),
		CFrame.new(c.X + 35.8, FLOOR + 3.5, c.Z - 22) * CFrame.Angles(0, math.pi / 2, 0),
		Color3.fromRGB(200, 40, 40),
		Enum.Material.SmoothPlastic
	)
	Builder.prompt(release, Constants.Actions.Investigate, "StationService", {
		actionText = "Emergency release",
		objectText = "Service door",
		hold = 1,
	})

	-- Zoner, loot och upptäckter -------------------------------------------------------
	ctx.addZone("Restricted", "Line 3 Station", CFrame.new(c.X, FLOOR + 7, c.Z - 22), Vector3.new(142, 16, 64))
	ctx.addDiscovery("StationPlatform", CFrame.new(c.X, FLOOR + 4, c.Z - 30), Vector3.new(120, 10, 16))
	-- Stationens dova ljud (går även utan ström: det kommer någonstans längre in i tunneln).
	local drone = Builder.anchor(root, "StationDrone", Vector3.new(1, 1, 1), CFrame.new(c.X, FLOOR + 5, c.Z - 32))
	drone:SetAttribute("Sound", "StationDrone")
	drone:SetAttribute("NeedsPower", false)
	drone:AddTag(Constants.Tags.AmbientSound)
	for _, offset in
		{ Vector3.new(-40, 0, -28), Vector3.new(10, 0, -24), Vector3.new(48, 0, -30), Vector3.new(-12, 0, -2) }
	do
		ctx.addLoot("Station", Vector3.new(c.X + offset.X, FLOOR + 0.5, c.Z + offset.Z))
	end
	ctx.addLoot("Street", Vector3.new(c.X + 22, top + 0.5, c.Z + 30))
	ctx.addLoot("Street", Vector3.new(c.X - 40, top + 0.5, c.Z - 20))

	-- Mannen som står på samma plats varje natt och tittar mot Calloway Residences.
	ctx.world.npc.posts.Watcher =
		Builder.lookAt(Vector3.new(c.X - 50, top + 3, c.Z - 46), Vector3.new(c.X - 200, top + 3, c.Z))
	-- Ställen att fotografera tornet ifrån
	ctx.addSite(
		"TowerView",
		"TowerViewPlaza",
		"the west edge of Mercer Plaza",
		CFrame.new(c.X - 54, top + 2, c.Z + 10),
		nil
	)

	ctx.world.station.center = Vector3.new(c.X, FLOOR, c.Z - 22)
	ctx.world.station.lootZone = "Station"
	return root
end

return Plaza
