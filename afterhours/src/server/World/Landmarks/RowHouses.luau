-- Radhusen på Lumen St, tvättomaten på Vance Ave och ett lager med en bakgård.

local Builder = require(script.Parent.Parent.Builder)
local Buildings = require(script.Parent.Parent.Buildings)

local RowHouses = {}

local HOUSE_COLORS = {
	Color3.fromRGB(122, 64, 52),
	Color3.fromRGB(150, 140, 128),
	Color3.fromRGB(96, 110, 120),
	Color3.fromRGB(140, 110, 80),
	Color3.fromRGB(84, 48, 42),
	Color3.fromRGB(120, 124, 110),
}

function RowHouses.build(ctx, c: Vector3, _layout)
	local palette = ctx.palette
	local root = Builder.model(ctx.root, "RowHouseBlock")
	local top = ctx.config.sidewalkHeight

	for i = 1, 6 do
		local x = c.X - 46 + (i - 1) * 16
		local height = if i % 2 == 0 then 24 else 28
		local house = Buildings.build(ctx, root, {
			name = "RowHouse" .. i,
			center = Vector3.new(x, 0, c.Z - 39),
			size = Vector3.new(16, height, 26),
			color = HOUSE_COLORS[i],
			material = if i % 2 == 0 then Enum.Material.Concrete else Enum.Material.Brick,
			floorHeight = 9,
			windows = { faces = { "North", "South" }, style = "Residential", litChance = 0.4 },
			roof = { noProps = i % 3 ~= 0 },
		})
		local doorZ = c.Z - 52.2
		Builder.box(
			root,
			"Stoop",
			Vector3.new(4, 1.2, 2.4),
			CFrame.new(x + 3, top + 0.6, doorZ - 1.2),
			palette.Concrete,
			Enum.Material.Concrete
		)
		Builder.decor(
			root,
			"FrontDoor",
			Vector3.new(3, 6.5, 0.3),
			CFrame.new(x + 3, top + 4.4, doorZ),
			Color3.fromRGB(40, 26, 20),
			Enum.Material.Wood
		)
		if i % 2 == 1 then
			local lamp = Builder.decor(
				root,
				"PorchLight",
				Vector3.new(0.6, 0.6, 0.6),
				CFrame.new(x + 5.2, top + 7.6, doorZ - 0.4),
				palette.WindowWarm,
				Enum.Material.Neon
			)
			lamp:AddTag("AH_StreetLight")
			Builder.pointLight(lamp, palette.WindowWarm, 12, 0.8, false)
			ctx.addSite(
				"Doorstep",
				"RowHouse" .. i,
				"No. " .. (8 + i * 2) .. " Lumen St",
				CFrame.new(x + 3, top + 2, doorZ - 3.5),
				nil
			)
		end
		local _ = house
	end

	-- Tvättomaten (rum för SOMETHING INSIDE)
	local laundromat = Buildings.annex(ctx, root, {
		name = "Laundromat",
		center = Vector3.new(c.X + 48, top, c.Z - 4),
		size = Vector3.new(16, 10, 20),
		doorFace = "East",
		gateId = "Twist_Laundromat",
		sign = "SUDS 24H LAUNDRY",
		signColor = Color3.fromRGB(120, 220, 255),
		wallColor = Color3.fromRGB(180, 186, 190),
		wallMaterial = Enum.Material.Concrete,
	})
	for k = -1, 1 do
		Builder.box(
			laundromat.model,
			"Washer",
			Vector3.new(3, 3.4, 3),
			CFrame.new(laundromat.center + Vector3.new(-5, 1.7, k * 4.5)),
			Color3.fromRGB(230, 232, 236),
			Enum.Material.SmoothPlastic
		)
	end
	ctx.addTwistRoom("Laundromat", "the laundromat on Vance Ave", laundromat)

	-- Lagret och bakgården
	Buildings.build(ctx, root, {
		name = "Warehouse",
		center = Vector3.new(c.X - 10, 0, c.Z + 33),
		size = Vector3.new(84, 24, 42),
		color = palette.Steel,
		material = Enum.Material.CorrodedMetal,
		floorHeight = 12,
		windows = { faces = { "South", "West", "North" }, style = "Industrial", litChance = 0.15 },
	})
	for _, p in { Vector3.new(c.X - 30, 0, c.Z - 10), Vector3.new(c.X + 12, 0, c.Z - 2) } do
		Builder.box(
			root,
			"Shed",
			Vector3.new(8, 6, 6),
			CFrame.new(p.X, top + 3, p.Z),
			Color3.fromRGB(90, 96, 80),
			Enum.Material.WoodPlanks
		)
	end
	Builder.box(
		root,
		"Dumpster",
		Vector3.new(6, 4, 3.5),
		CFrame.new(c.X - 4, top + 2, c.Z + 8),
		Color3.fromRGB(40, 70, 52),
		Enum.Material.Metal
	)
	ctx.addLoot("Alley", Vector3.new(c.X - 20, top + 0.5, c.Z + 4))
	ctx.addLoot("Alley", Vector3.new(c.X + 26, top + 0.5, c.Z - 12))
	return root
end

return RowHouses
