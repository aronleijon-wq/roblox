-- Builder: små byggstenar för att skapa världen från kod (delar, skyltar, ljus, prompts).
-- Alla världsmoduler bygger med de här funktionerna så att stil och prestanda blir enhetliga.

local Builder = {}

-- Samma sak som CFrame.lookAt, men byggd med fromMatrix. Ger identiskt resultat i Roblox och
-- fungerar även i testmiljön (Lune), där CFrame.lookAt vänder fel längs Z-axeln.
function Builder.lookAt(from: Vector3, to: Vector3): CFrame
	local look = (to - from).Unit
	local up = Vector3.yAxis
	if math.abs(look:Dot(up)) > 0.999 then
		up = -Vector3.zAxis
	end
	local right = look:Cross(up).Unit
	return CFrame.fromMatrix(from, right, right:Cross(look), -look)
end

-- Skapar en förankrad del. props använder riktiga egenskapsnamn, plus:
--   ClassName (standard "Part"), Tags (lista), Attributes (tabell)
function Builder.part(parent: Instance, props): BasePart
	local part = Instance.new(props.ClassName or "Part") :: BasePart
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if props.Shape then
		(part :: any).Shape = props.Shape -- formen först, den påverkar hur storleken tolkas
	end
	for key, value in props do
		if key ~= "ClassName" and key ~= "Tags" and key ~= "Attributes" and key ~= "Shape" then
			(part :: any)[key] = value
		end
	end
	for name, value in props.Attributes or {} do
		part:SetAttribute(name, value)
	end
	for _, tag in props.Tags or {} do
		part:AddTag(tag)
	end
	part.Parent = parent
	return part
end

-- Vanligt block. extra kan skriva över vilka egenskaper som helst.
function Builder.box(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	extra: { [string]: any }?
): BasePart
	local props = {
		Name = name,
		Size = size,
		CFrame = cframe,
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
	}
	for key, value in extra or {} do
		props[key] = value
	end
	return Builder.part(parent, props)
end

-- Dekoration: syns men påverkar inte fysik, träffytor eller skuggor. Billigt för motorn.
function Builder.decor(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	extra: { [string]: any }?
): BasePart
	local props = {
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
		CastShadow = false,
	}
	for key, value in extra or {} do
		props[key] = value
	end
	return Builder.box(parent, name, size, cframe, color, material, props)
end

-- Ramp eller trappa: en lutande platta vars ovansida går från `bottom` till `top`
-- (mittpunkterna på plattans nedre och övre kant). Karaktärer kan gå på den.
function Builder.ramp(
	parent: Instance,
	name: string,
	bottom: Vector3,
	top: Vector3,
	width: number,
	color: Color3,
	material: Enum.Material?
): BasePart
	local direction = top - bottom
	local middle = bottom + direction / 2
	local cframe = Builder.lookAt(middle, middle + direction) * CFrame.new(0, -0.5, 0)
	return Builder.box(parent, name, Vector3.new(width, 1, direction.Magnitude), cframe, color, material)
end

function Builder.cylinder(
	parent: Instance,
	name: string,
	length: number,
	diameter: number,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	extra: { [string]: any }?
): BasePart
	-- En cylinder ligger längs sin X-axel; cframe bestämmer riktningen.
	local props = { Shape = Enum.PartType.Cylinder }
	for key, value in extra or {} do
		props[key] = value
	end
	return Builder.box(parent, name, Vector3.new(length, diameter, diameter), cframe, color, material, props)
end

-- En skylt: text på en av delens sidor.
function Builder.sign(
	part: BasePart,
	face: Enum.NormalId,
	text: string,
	options: {
		color: Color3?,
		background: Color3?,
		backgroundTransparency: number?,
		lit: boolean?,
		font: Enum.Font?,
		pixelsPerStud: number?,
		name: string?,
	}?
): (SurfaceGui, TextLabel)
	local opts = options or {}
	local gui = Instance.new("SurfaceGui")
	gui.Name = opts.name or "Sign"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = opts.pixelsPerStud or 30
	gui.LightInfluence = if opts.lit then 0 else 1
	gui.MaxDistance = 400

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = opts.background or Color3.new(0, 0, 0)
	label.BackgroundTransparency = opts.backgroundTransparency or (if opts.background then 0 else 1)
	label.Text = text
	label.TextScaled = true
	label.Font = opts.font or Enum.Font.GothamBold
	label.TextColor3 = opts.color or Color3.new(1, 1, 1)
	label.Parent = gui

	gui.Parent = part
	return gui, label
end

-- En ProximityPrompt. Servern läser attributet "Action" (och "Target") när den triggas.
function Builder.prompt(
	part: BasePart,
	action: string,
	target: string?,
	options: {
		actionText: string?,
		objectText: string?,
		hold: number?,
		distance: number?,
		enabled: boolean?,
		keyCode: Enum.KeyCode?,
	}?
): ProximityPrompt
	local opts = options or {}
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Prompt"
	prompt.ActionText = opts.actionText or "Interact"
	prompt.ObjectText = opts.objectText or ""
	prompt.HoldDuration = opts.hold or 0
	prompt.MaxActivationDistance = opts.distance or 10
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = opts.keyCode or Enum.KeyCode.E
	prompt.Enabled = if opts.enabled == nil then true else opts.enabled
	prompt:SetAttribute("Action", action)
	if target then
		prompt:SetAttribute("Target", target)
	end
	prompt.Parent = part
	return prompt
end

function Builder.pointLight(
	part: BasePart,
	color: Color3,
	range: number,
	brightness: number,
	shadows: boolean?
): PointLight
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = shadows == true
	light.Parent = part
	return light
end

function Builder.spotLight(
	part: BasePart,
	face: Enum.NormalId,
	color: Color3,
	range: number,
	angle: number,
	brightness: number,
	shadows: boolean?
): SpotLight
	local light = Instance.new("SpotLight")
	light.Face = face
	light.Color = color
	light.Range = range
	light.Angle = angle
	light.Brightness = brightness
	light.Shadows = shadows == true
	light.Parent = part
	return light
end

function Builder.surfaceLight(
	part: BasePart,
	face: Enum.NormalId,
	color: Color3,
	range: number,
	brightness: number
): SurfaceLight
	local light = Instance.new("SurfaceLight")
	light.Face = face
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Angle = 120
	light.Shadows = false
	light.Parent = part
	return light
end

function Builder.folder(parent: Instance, name: string): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

function Builder.model(parent: Instance, name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	return model
end

-- Ett osynligt ankare (för platser, lootpunkter, zoner).
function Builder.anchor(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	extra: { [string]: any }?
): BasePart
	local props = {
		Transparency = 1,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
		CastShadow = false,
	}
	for key, value in extra or {} do
		props[key] = value
	end
	return Builder.box(parent, name, size, cframe, Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, props)
end

return Builder
