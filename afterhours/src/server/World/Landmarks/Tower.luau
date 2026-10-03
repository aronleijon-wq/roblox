-- Calloway Residences: stadens högsta hus. Brandtrappan går hela vägen upp till taket.
-- Fönstren i tornet hör till gruppen "Tower" så att THE OTHER LIGHTS kan tända dem i ett
-- mönster som inte borde vara möjligt. Maskinrummet på taket ("19F") öppnas bara då.

local Builder = require(script.Parent.Parent.Builder)
local Buildings = require(script.Parent.Parent.Buildings)

local Tower = {}

Tower.Floors = 16
Tower.FloorHeight = 8

function Tower.build(ctx, c: Vector3, _layout)
	local palette = ctx.palette
	local root = Builder.model(ctx.root, "CallowayBlock")
	local top = ctx.config.sidewalkHeight
	local height = Tower.Floors * Tower.FloorHeight

	-- Själva tornet, mot Mercer St ---------------------------------------------------
	local towerCenter = Vector3.new(c.X + 24, 0, c.Z)
	local tower = Buildings.build(ctx, root, {
		name = "CallowayResidences",
		center = towerCenter,
		size = Vector3.new(40, height, 40),
		color = Color3.fromRGB(112, 104, 96),
		material = Enum.Material.Concrete,
		floorHeight = Tower.FloorHeight,
		windows = {
			faces = { "North", "South", "East", "West" },
			style = "Tower",
			group = "Tower",
			litChance = 0.3,
		},
		fireEscape = "North",
		roof = { noProps = true },
	})
	ctx.world.tower.windows = tower.windows
	ctx.world.tower.floors = Tower.Floors

	-- Entrén med tak och skylt
	local entrance = Vector3.new(towerCenter.X + 20, top, towerCenter.Z)
	Builder.box(
		root,
		"EntranceCanopy",
		Vector3.new(6, 0.6, 14),
		CFrame.new(entrance.X + 3, top + 9, entrance.Z),
		palette.ConcreteDark,
		Enum.Material.Concrete
	)
	local doors = Builder.decor(
		root,
		"LobbyDoors",
		Vector3.new(0.3, 7, 8),
		CFrame.new(entrance.X + 0.2, top + 3.5, entrance.Z),
		Color3.fromRGB(255, 220, 160),
		Enum.Material.Neon,
		{ Transparency = 0.3 }
	)
	doors:SetAttribute("Lit", true)
	doors:AddTag("AH_WindowLight")
	local signPart = Builder.decor(
		root,
		"TowerSign",
		Vector3.new(0.4, 1.6, 14),
		CFrame.new(entrance.X + 6.1, top + 10.2, entrance.Z),
		Color3.fromRGB(26, 26, 30),
		Enum.Material.SmoothPlastic
	)
	Builder.sign(
		signPart,
		Enum.NormalId.Right,
		"CALLOWAY RESIDENCES",
		{ color = Color3.fromRGB(240, 220, 180), lit = true }
	)
	ctx.addSite(
		"Doorstep",
		"TowerLobby",
		"Calloway Residences lobby",
		CFrame.new(entrance.X + 3, top + 2, entrance.Z),
		nil
	)

	-- Taket: relämast, maskinrum ("19F") och en plats att upptäcka ---------------------
	local roofY = height
	local mast = Builder.box(
		root,
		"RelayMast",
		Vector3.new(1, 14, 1),
		CFrame.new(towerCenter.X + 12, roofY + 7, towerCenter.Z - 12),
		palette.Steel,
		Enum.Material.Metal
	)
	local beacon = Builder.decor(
		root,
		"RelayBeacon",
		Vector3.new(1, 1, 1),
		CFrame.new(towerCenter.X + 12, roofY + 14.5, towerCenter.Z - 12),
		Color3.fromRGB(255, 40, 40),
		Enum.Material.Neon
	)
	beacon:AddTag("AH_FlickerLight")
	local relayBox = Builder.box(
		root,
		"RelayBox",
		Vector3.new(3, 4, 2),
		CFrame.new(towerCenter.X + 12, roofY + 2, towerCenter.Z - 9),
		Color3.fromRGB(70, 76, 84),
		Enum.Material.Metal
	)
	local _ = mast
	ctx.addSite(
		"Rooftop",
		"TowerRelay",
		"the Calloway Residences roof",
		relayBox.CFrame * CFrame.new(0, 0, 2.5),
		relayBox
	)

	local machine = Buildings.annex(ctx, root, {
		name = "MachineRoom",
		center = Vector3.new(towerCenter.X - 8, roofY, towerCenter.Z + 6),
		size = Vector3.new(14, 9, 14),
		doorFace = "East",
		gateId = "TowerMachineRoom",
		sign = "19F",
		wallColor = Color3.fromRGB(96, 92, 86),
		wallMaterial = Enum.Material.Concrete,
	})
	ctx.world.tower.machineRoom = machine
	ctx.world.tower.objectCFrame = CFrame.new(machine.center + Vector3.new(0, 2, 0))
	Builder.box(
		machine.model,
		"Pedestal",
		Vector3.new(2.4, 2.4, 2.4),
		CFrame.new(machine.center + Vector3.new(0, 1.2, 0)),
		Color3.fromRGB(30, 30, 34),
		Enum.Material.Slate
	)
	ctx.addDiscovery("TowerRoof", CFrame.new(towerCenter.X, roofY + 4, towerCenter.Z), Vector3.new(40, 8, 40))
	ctx.addLoot("Interior", Vector3.new(towerCenter.X + 10, roofY + 0.5, towerCenter.Z + 12))

	-- Bostadshus i västra delen av kvarteret, med en gränd emellan ----------------------
	Buildings.build(ctx, root, {
		name = "WestApartments",
		center = Vector3.new(c.X - 30, 0, c.Z - 31),
		size = Vector3.new(48, 60, 42),
		color = palette.Brick,
		material = Enum.Material.Brick,
		windows = { faces = { "North", "West", "South" }, style = "Residential" },
		fireEscape = "South",
	})
	Buildings.build(ctx, root, {
		name = "WestFlats",
		center = Vector3.new(c.X - 30, 0, c.Z + 33),
		size = Vector3.new(48, 40, 38),
		color = palette.Plaster,
		material = Enum.Material.Concrete,
		windows = { faces = { "South", "West", "North" }, style = "Residential" },
	})

	-- Pannrummet längst in i gränden (rum för SOMETHING INSIDE)
	local boiler = Buildings.annex(ctx, root, {
		name = "BoilerRoom",
		center = Vector3.new(c.X - 46, top, c.Z + 3),
		size = Vector3.new(14, 9, 12),
		doorFace = "East",
		gateId = "Twist_Boiler",
		sign = "BOILER - KEEP OUT",
	})
	ctx.addTwistRoom("Boiler", "the boiler room off Harlow Ave", boiler)
	Builder.box(
		root,
		"Dumpster",
		Vector3.new(6, 4, 3.5),
		CFrame.new(c.X - 20, top + 2, c.Z - 7),
		Color3.fromRGB(40, 70, 52),
		Enum.Material.Metal
	)
	ctx.addLoot("Alley", Vector3.new(c.X - 30, top + 0.5, c.Z + 6))
	ctx.addLoot("Alley", Vector3.new(c.X - 10, top + 0.5, c.Z - 5))

	-- Ett ställe på trottoaren mittemot där man kan fotografera fönstret
	ctx.addSite(
		"TowerView",
		"TowerViewMercer",
		"the Mercer St sidewalk, facing Calloway",
		CFrame.new(c.X + 85, top + 2, c.Z - 30),
		nil
	)
	return root
end

return Tower
