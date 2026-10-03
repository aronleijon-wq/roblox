-- Halden Substation: inhägnat ställverk (RESTRICTED) med grind som öppnas för den som har
-- ett kontrakt. Ett hål i bakre stängslet, bakom en lastbil, för den som letar.

local Builder = require(script.Parent.Parent.Builder)
local Buildings = require(script.Parent.Parent.Buildings)
local Site9 = require(script.Parent.Site9)

local Substation = {}

local function transformer(parent: Instance, position: Vector3)
	local body = Builder.box(
		parent,
		"Transformer",
		Vector3.new(8, 8, 6),
		CFrame.new(position + Vector3.new(0, 4, 0)),
		Color3.fromRGB(96, 110, 100),
		Enum.Material.Metal
	)
	for k = -3, 3 do
		Builder.decor(
			parent,
			"CoolingFin",
			Vector3.new(0.3, 6, 1),
			CFrame.new(position + Vector3.new(k * 1.1, 4, 3.5)),
			Color3.fromRGB(80, 92, 84),
			Enum.Material.Metal
		)
	end
	for _, dx in { -2.5, 0, 2.5 } do
		Builder.cylinder(
			parent,
			"Insulator",
			2.4,
			0.6,
			CFrame.new(position + Vector3.new(dx, 9.2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
			Color3.fromRGB(150, 90, 60),
			Enum.Material.SmoothPlastic
		)
	end
	return body
end

function Substation.build(ctx, c: Vector3, _layout)
	local palette = ctx.palette
	local root = Builder.model(ctx.root, "HaldenSubstation")
	local top = ctx.config.sidewalkHeight
	local fence = Site9.fence
	local yardX, yardZ1, yardZ2 = 50, c.Z - 26, c.Z + 50
	local gate1, gate2 = c.X - 6, c.X + 6
	local gap1, gap2 = c.X + 36, c.X + 39

	-- Stängsel med grind (söder) och ett hål (norr)
	fence(root, Vector3.new(c.X - yardX, top, yardZ2), Vector3.new(gate1, top, yardZ2), 10)
	fence(root, Vector3.new(gate2, top, yardZ2), Vector3.new(c.X + yardX, top, yardZ2), 10)
	fence(root, Vector3.new(c.X - yardX, top, yardZ1), Vector3.new(gap1, top, yardZ1), 10)
	fence(root, Vector3.new(gap2, top, yardZ1), Vector3.new(c.X + yardX, top, yardZ1), 10)
	fence(root, Vector3.new(c.X - yardX, top, yardZ1), Vector3.new(c.X - yardX, top, yardZ2), 10)
	fence(root, Vector3.new(c.X + yardX, top, yardZ1), Vector3.new(c.X + yardX, top, yardZ2), 10)
	local gate = Builder.box(
		root,
		"SubstationGate",
		Vector3.new(12, 9, 0.4),
		CFrame.new(c.X, top + 4.5, yardZ2),
		Color3.fromRGB(140, 146, 150),
		Enum.Material.DiamondPlate,
		{ Transparency = 0.2 }
	)
	ctx.addGate("SubstationGate", gate)
	local danger = Builder.box(
		root,
		"DangerSign",
		Vector3.new(14, 3, 0.3),
		CFrame.new(c.X, top + 11, yardZ2 + 0.5),
		palette.SafetyYellow,
		Enum.Material.SmoothPlastic
	)
	Builder.sign(
		danger,
		Enum.NormalId.Back,
		"HALDEN SUBSTATION - DANGER HIGH VOLTAGE",
		{ color = Color3.fromRGB(20, 20, 20) }
	)
	Builder.decor(
		root,
		"Gravel",
		Vector3.new(yardX * 2, 0.2, yardZ2 - yardZ1),
		CFrame.new(c.X, top + 0.08, (yardZ1 + yardZ2) / 2),
		Color3.fromRGB(70, 70, 72),
		Enum.Material.Slate
	)

	-- Transformatorer, stolpar och kärnan
	for _, p in
		{
			Vector3.new(-30, 0, -10),
			Vector3.new(30, 0, -10),
			Vector3.new(-30, 0, 24),
			Vector3.new(30, 0, 24),
			Vector3.new(-14, 0, 38),
			Vector3.new(14, 0, 38),
		}
	do
		transformer(root, Vector3.new(c.X + p.X, top, c.Z + p.Z))
	end
	for _, p in { Vector3.new(-44, 0, -20), Vector3.new(44, 0, -20), Vector3.new(-44, 0, 44), Vector3.new(44, 0, 44) } do
		local base = Vector3.new(c.X + p.X, top, c.Z + p.Z)
		Builder.box(
			root,
			"Pylon",
			Vector3.new(1, 24, 1),
			CFrame.new(base + Vector3.new(0, 12, 0)),
			palette.Steel,
			Enum.Material.Metal
		)
		Builder.box(
			root,
			"Crossbar",
			Vector3.new(8, 0.6, 0.6),
			CFrame.new(base + Vector3.new(0, 22, 0)),
			palette.Steel,
			Enum.Material.Metal
		)
	end
	for _, z in { c.Z - 20, c.Z + 44 } do
		for _, offset in { -0.7, 0.7 } do
			Builder.decor(
				root,
				"Cable",
				Vector3.new(88, 0.15, 0.15),
				CFrame.new(c.X, top + 21.6, z + offset),
				Color3.fromRGB(20, 20, 20),
				Enum.Material.Metal
			)
		end
	end
	local core = Builder.box(
		root,
		"Core",
		Vector3.new(10, 12, 10),
		CFrame.new(c.X, top + 6, c.Z + 8),
		Color3.fromRGB(56, 64, 72),
		Enum.Material.DiamondPlate
	)
	local coreGlow = Builder.decor(
		root,
		"CoreGlow",
		Vector3.new(10.2, 1, 10.2),
		CFrame.new(c.X, top + 9, c.Z + 8),
		Color3.fromRGB(80, 170, 255),
		Enum.Material.Neon
	)
	coreGlow:AddTag("AH_StreetLight")
	-- Brummet från kärnan (klienten spelar det; tystnar när strömmen går).
	core:SetAttribute("Sound", "ElectricalHum")
	core:AddTag("AH_AmbientSound")
	Builder.pointLight(coreGlow, Color3.fromRGB(90, 170, 255), 28, 1.2, false)
	local panel = Builder.box(
		root,
		"CorePanel",
		Vector3.new(4, 4, 0.6),
		CFrame.new(c.X, top + 3, c.Z + 13.3),
		Color3.fromRGB(200, 200, 190),
		Enum.Material.SmoothPlastic
	)
	ctx.addSite(
		"SubstationCore",
		"SubstationCore",
		"the Halden Substation core",
		panel.CFrame * CFrame.new(0, -1, 2.2),
		panel
	)
	ctx.world.substation = { core = core, glow = coreGlow }

	ctx.addZone(
		"Restricted",
		"Halden Substation",
		CFrame.new(c.X, top + 12, (yardZ1 + yardZ2) / 2),
		Vector3.new(yardX * 2, 26, yardZ2 - yardZ1)
	)
	ctx.addLoot("Restricted", Vector3.new(c.X - 20, top + 0.5, c.Z + 8))
	ctx.addLoot("Restricted", Vector3.new(c.X + 22, top + 0.5, c.Z + 40))
	ctx.addLoot("Restricted", Vector3.new(c.X + 40, top + 0.5, c.Z - 18))

	-- Halden Grid Services kontor (norr) och servicegången bakom stängslet
	Buildings.build(ctx, root, {
		name = "HaldenGridServices",
		center = Vector3.new(c.X, 0, c.Z - 43),
		size = Vector3.new(104, 22, 22),
		color = Color3.fromRGB(90, 96, 104),
		material = Enum.Material.Concrete,
		floorHeight = 11,
		windows = { faces = { "North", "South" }, style = "Office", warm = false, litChance = 0.2 },
	})
	Builder.box(
		root,
		"ServiceTruck",
		Vector3.new(12, 7, 5),
		CFrame.new(c.X + 47, top + 3.5, c.Z - 29),
		Color3.fromRGB(230, 230, 226),
		Enum.Material.SmoothPlastic
	)
	ctx.addLoot("Alley", Vector3.new(c.X - 20, top + 0.5, c.Z - 29))
	return root
end

return Substation
