-- CourseBuilder: bygger hinderbanan utifrån Config.Course.Sections när servern startar.
--
-- Banan byggs i ett eget koordinatsystem där x = sidled, y = höjd och z = hur långt
-- fram man kommit. Allt placeras sedan relativt Config.Course.Origin, med "framåt" = -Z.
-- Byggaren skapar bara delar med taggar och attribut; själva beteendet (döda, snurra,
-- åka fram och tillbaka ...) sköts av Hazards, Coins och Checkpoints.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local Course = Config.Course
local Colors = Course.Colors
local Tags = Config.Tags

type Context = {
	folder: Folder,
	z: number, -- hur långt fram vi byggt hittills
	y: number, -- höjden på ovansidan av senaste plattformen
	color: Color3, -- färgen för sektionen vi bygger just nu
}

local CourseBuilder = {}

local function toWorld(x: number, y: number, z: number): CFrame
	return Course.Origin * CFrame.new(x, y, -z)
end

-- Skapar ett förankrat block. (x, z) är blockets mitt och topY höjden på ovansidan.
local function block(ctx: Context, name: string, size: Vector3, x: number, topY: number, z: number): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = toWorld(x, topY - size.Y / 2, z)
	part.Anchored = true
	part.Material = Enum.Material.SmoothPlastic
	part.Color = ctx.color
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = ctx.folder
	return part
end

local function killBrick(part: Part)
	part.Color = Colors.KillBrick
	part.Material = Enum.Material.Neon
	part:AddTag(Tags.KillBrick)
end

local function coin(ctx: Context, x: number, y: number, z: number)
	local part = Instance.new("Part")
	part.Name = "Coin"
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(0.4, 2.4, 2.4)
	-- En cylinder ligger längs X-axeln; vrid den så att myntet står upp och vänder sig mot spelaren.
	part.CFrame = toWorld(x, y, z) * CFrame.Angles(0, math.pi / 2, 0)
	part.Anchored = true
	part.CanCollide = false
	part.Material = Enum.Material.Neon
	part.Color = Colors.Coin
	part.Parent = ctx.folder
	part:AddTag(Tags.Coin)
end

local function sign(part: BasePart, text: string, color: Color3)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Sign"
	gui.Size = UDim2.fromScale(10, 2.5) -- i studs eftersom det är en BillboardGui
	gui.StudsOffsetWorldSpace = Vector3.new(0, 6, 0)
	gui.MaxDistance = 150

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.Parent = gui

	gui.Parent = part
end

local function checkpoint(ctx: Context, stage: number, isFinish: boolean)
	local size = Course.PadSize
	local pad = block(ctx, `Checkpoint{stage}`, size, 0, ctx.y, ctx.z + size.Z / 2)
	if stage == 1 then
		pad.Color = Colors.Start
		sign(pad, "START", Colors.Start)
	elseif isFinish then
		pad.Color = Colors.Finish
		pad.Material = Enum.Material.Neon
		sign(pad, "MÅL!", Colors.Finish)
	else
		pad.Color = Colors.Checkpoint
		sign(pad, `Checkpoint {stage}`, Color3.new(1, 1, 1))
	end
	pad:SetAttribute("Stage", stage)
	pad:AddTag(Tags.Checkpoint)
	ctx.z += size.Z
end

-- En funktion per sektionstyp. Varje funktion bygger från ctx.z/ctx.y och flyttar
-- fram ctx.z (och ev. ctx.y) till där nästa checkpoint ska ligga.
local Sections = {}

function Sections.Jumps(ctx: Context, s)
	local size: Vector3 = s.platformSize
	for i = 1, s.count do
		ctx.z += s.gap
		ctx.y += s.rise
		local x = if i % 2 == 0 then s.sway else -s.sway
		local z = ctx.z + size.Z / 2
		block(ctx, "Jump", size, x, ctx.y, z)
		if i % 2 == 1 then
			coin(ctx, x, ctx.y + 3, z)
		end
		ctx.z += size.Z
	end
	ctx.z += s.gap
end

function Sections.KillBricks(ctx: Context, s)
	block(ctx, "Walkway", Vector3.new(s.width, 1, s.length), 0, ctx.y, ctx.z + s.length / 2)

	local spacing = s.length / (s.strips + 1)
	for i = 1, s.strips do
		local z = ctx.z + i * spacing
		local strip =
			block(ctx, "KillBrick", Vector3.new(s.width, s.stripHeight, s.stripDepth), 0, ctx.y + s.stripHeight, z)
		killBrick(strip)
		coin(ctx, 0, ctx.y + 2.5, z + spacing / 2)
	end
	ctx.z += s.length
end

function Sections.Moving(ctx: Context, s)
	local size: Vector3 = s.platformSize
	for i = 1, s.count do
		ctx.z += s.gap
		-- Varannan plattform startar till vänster och varannan till höger,
		-- så att de möts på mitten och man kan hoppa mellan dem.
		local direction = if i % 2 == 1 then 1 else -1
		local platform = block(ctx, "MovingPlatform", size, -direction * s.travel / 2, ctx.y, ctx.z + size.Z / 2)
		platform:SetAttribute("MoveOffset", Course.Origin:VectorToWorldSpace(Vector3.new(direction * s.travel, 0, 0)))
		platform:AddTag(Tags.MovingPlatform)
		ctx.z += size.Z
	end
	ctx.z += s.gap
end

function Sections.Fading(ctx: Context, s)
	local size: Vector3 = s.platformSize
	for _ = 1, s.count do
		ctx.z += s.gap
		local platform = block(ctx, "FadingPlatform", size, 0, ctx.y, ctx.z + size.Z / 2)
		platform.Material = Enum.Material.Glass
		platform.Transparency = 0.2
		platform:AddTag(Tags.FadingPlatform)
		ctx.z += size.Z
	end
	ctx.z += s.gap
end

function Sections.Truss(ctx: Context, s)
	-- Stegen går en bit under nuvarande nivå så att man hinner ta tag i den när man hoppar.
	local below = 4
	local truss = Instance.new("TrussPart")
	truss.Name = "Truss"
	truss.Size = Vector3.new(2, s.height + below, 2) -- en TrussPart måste vara 2 studs tjock
	truss.CFrame = toWorld(0, ctx.y + s.height - truss.Size.Y / 2, ctx.z + s.gap + 1)
	truss.Anchored = true
	truss.Color = Colors.Truss
	truss.Parent = ctx.folder

	ctx.z += s.gap + 2
	ctx.y += s.height
end

function Sections.Spinner(ctx: Context, s)
	local center = ctx.z + s.size / 2
	block(ctx, "SpinnerFloor", Vector3.new(s.size, 1, s.size), 0, ctx.y, center)

	local hub = block(ctx, "SpinnerHub", Vector3.new(2, 3, 2), 0, ctx.y + 3, center)
	hub.Color = Colors.Truss

	-- Bommen svävar 1 stud över golvet; hoppa över den!
	local bar = block(ctx, "SpinnerBar", Vector3.new(s.size - 2, 1, 1), 0, ctx.y + 2, center)
	bar.CanCollide = false
	bar:SetAttribute("SpinSpeed", s.speed)
	killBrick(bar)
	bar:AddTag(Tags.Spinner)

	ctx.z += s.size
end

-- Bygger hela banan och returnerar mappen den ligger i.
function CourseBuilder.build(): Folder
	local folder = Instance.new("Folder")
	folder.Name = "Course"

	local ctx: Context = { folder = folder, z = 0, y = 0, color = Colors.Checkpoint }
	local lowestY = 0

	checkpoint(ctx, 1, false)
	for index, section in Course.Sections do
		local build = Sections[section.kind]
		if not build then
			error(`[CourseBuilder] Okänd sektionstyp "{section.kind}" (sektion {index})`)
		end
		ctx.color = Colors.Sections[(index - 1) % #Colors.Sections + 1]
		build(ctx, section)
		lowestY = math.min(lowestY, ctx.y)
		checkpoint(ctx, index + 1, index == #Course.Sections)
	end

	-- Ett lavahav under hela banan: ramlar man ner börjar man om från senaste checkpoint.
	ctx.color = Colors.Lava
	local margin = 60
	local lava = block(ctx, "Lava", Vector3.new(200, 4, ctx.z + margin * 2), 0, lowestY - Course.LavaDepth, ctx.z / 2)
	lava.Material = Enum.Material.CrackedLava
	lava:AddTag(Tags.KillBrick)

	folder.Parent = Workspace
	return folder
end

return CourseBuilder
