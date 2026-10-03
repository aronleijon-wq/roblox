-- WorldFxController: hur staden ser ut just nu. Servern sätter några få attribut på
-- ReplicatedStorage (PowerOut, OtherLights, RedSky, Silent) och skickar korta händelser;
-- klienten ändrar fönster, gatlyktor, nödljus och färgton lokalt. Det är billigt för servern
-- och fungerar med StreamingEnabled (delar som strömmas in får rätt utseende direkt).
--
--   BLACKOUT       fönster och gatlyktor släcks, röda nödljus pulserar
--   OTHER LIGHTS   allt släcks utom Calloway Residences, där "03:00" lyser i fasaden
--   CASCADE        som blackout, men himlen går över i rött
--   SILENT CITY    färgerna tappar mättnad (och ljudet försvinner, se AudioController)
--   Followed       mörka kanter på skärmen när något följer efter en

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Ui = require(script.Parent.Parent.UI.Ui)

local WorldFxController = {}

local Tags = Constants.Tags
local app

local DARK_WINDOW = Color3.fromRGB(22, 28, 38)
local DARK_LAMP = Color3.fromRGB(40, 38, 36)
local EMERGENCY_ON = Color3.fromRGB(255, 40, 40)
local OTHER_LIGHT = Color3.fromRGB(190, 255, 236)

-- "03:00" med 3x5-siffror. Tornets fasader har 17 kolumner (Buildings, stil "Tower"),
-- 15 våningar med fönster; texten ligger på våning 9-13.
local TOWER_COLUMNS = 17
local GLYPH_TOP_ROW = 13
local PATTERN = {
	-- 0   3   :  0   0
	"111 111 0 111 111",
	"101 001 1 101 101",
	"101 111 0 101 101",
	"101 001 1 101 101",
	"111 111 0 111 111",
}
-- Varje tecken följs av en tom kolumn (siffror 3 breda, kolon 1): 17 kolumner totalt.
local BITMAP: { { boolean } } = {}
do
	for r, text in PATTERN do
		local groups = string.split(text, " ")
		local bits = {}
		for index, group in groups do
			for i = 1, #group do
				table.insert(bits, group:sub(i, i) == "1")
			end
			if index < #groups then
				table.insert(bits, false)
			end
		end
		BITMAP[r] = bits
	end
end

local windows: { [BasePart]: { color: Color3, material: Enum.Material } } = {}
local lamps: { [BasePart]: { color: Color3, material: Enum.Material } } = {}
local emergencies: { [BasePart]: boolean } = {}
local grade: ColorCorrectionEffect?
local atmosphere: Atmosphere?
local gradeOriginal
local atmosphereOriginal
local vignette: Frame
local shakeUntil = 0
local shakeStrength = 0

local function attr(name: string): boolean
	return ReplicatedStorage:GetAttribute(name) == true
end

local function towerLit(part: BasePart): boolean
	local row = part:GetAttribute("Row")
	local col = part:GetAttribute("Col")
	if type(row) ~= "number" or type(col) ~= "number" then
		return false
	end
	local bitmapRow = GLYPH_TOP_ROW - row + 1
	local line = BITMAP[bitmapRow]
	if not line then
		return false
	end
	local offset = math.floor((TOWER_COLUMNS - #line) / 2)
	return line[col - offset] == true
end

-- Fönster -----------------------------------------------------------------------------------

local function applyWindow(part: BasePart)
	local original = windows[part]
	if not original then
		return
	end
	if attr("OtherLights") then
		if part:GetAttribute("Group") == "Tower" and towerLit(part) then
			part.Color = OTHER_LIGHT
			part.Material = Enum.Material.Neon
		else
			part.Color = DARK_WINDOW
			part.Material = Enum.Material.Glass
		end
	elseif attr("PowerOut") then
		part.Color = DARK_WINDOW
		part.Material = Enum.Material.Glass
	else
		part.Color = original.color
		part.Material = original.material
	end
end

local function addWindow(part: Instance)
	if not part:IsA("BasePart") or windows[part] then
		return
	end
	windows[part] = { color = part.Color, material = part.Material }
	applyWindow(part)
end

-- Gatlyktor och nödljus ----------------------------------------------------------------------

local function lampLight(part: BasePart): Light?
	return part:FindFirstChildWhichIsA("Light")
end

local function setLamp(part: BasePart, on: boolean)
	local original = lamps[part]
	if not original then
		return
	end
	part.Color = if on then original.color else DARK_LAMP
	part.Material = if on then original.material else Enum.Material.SmoothPlastic
	local light = lampLight(part)
	if light then
		light.Enabled = on
	end
end

local function lampsOn(): boolean
	return not attr("PowerOut") and not attr("OtherLights")
end

local function addLamp(part: Instance)
	if not part:IsA("BasePart") or lamps[part] then
		return
	end
	lamps[part] = { color = part.Color, material = part.Material }
	setLamp(part, lampsOn())
end

local function setEmergency(part: BasePart, on: boolean, intensity: number?)
	part.Color = if on then EMERGENCY_ON else Color3.fromRGB(60, 10, 10)
	part.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
	local light = lampLight(part)
	if light then
		light.Enabled = on
		light.Brightness = if on then (intensity or 1.2) else 0
	end
end

local function addEmergency(part: Instance)
	if not part:IsA("BasePart") then
		return
	end
	emergencies[part] = true
	setEmergency(part, attr("PowerOut"))
end

-- Färgton -----------------------------------------------------------------------------------

local function findLighting()
	grade = Lighting:FindFirstChild("NightGrade") :: ColorCorrectionEffect?
	atmosphere = Lighting:FindFirstChild("NightAtmosphere") :: Atmosphere?
	if grade and not gradeOriginal then
		gradeOriginal = {
			TintColor = grade.TintColor,
			Saturation = grade.Saturation,
			Brightness = grade.Brightness,
			Contrast = grade.Contrast,
		}
	end
	if atmosphere and not atmosphereOriginal then
		atmosphereOriginal = { Color = atmosphere.Color, Decay = atmosphere.Decay, Density = atmosphere.Density }
	end
end

local function applyGrade()
	findLighting()
	local info = TweenInfo.new(2.5, Enum.EasingStyle.Sine)
	if grade and gradeOriginal then
		local target = table.clone(gradeOriginal)
		if attr("RedSky") then
			target.TintColor = Color3.fromRGB(255, 170, 160)
			target.Saturation = 0.25
			target.Contrast = 0.2
		elseif attr("OtherLights") then
			target.TintColor = Color3.fromRGB(215, 255, 245)
			target.Saturation = -0.35
			target.Brightness = -0.04
		elseif attr("Silent") then
			target.Saturation = -0.6
		elseif attr("PowerOut") then
			target.Brightness = -0.05
			target.Contrast = 0.18
		end
		TweenService:Create(grade, info, target):Play()
	end
	if atmosphere and atmosphereOriginal then
		local target = table.clone(atmosphereOriginal)
		if attr("RedSky") then
			target.Color = Color3.fromRGB(150, 40, 36)
			target.Decay = Color3.fromRGB(90, 20, 20)
			target.Density = 0.4
		elseif attr("OtherLights") then
			target.Color = Color3.fromRGB(40, 70, 66)
			target.Density = 0.38
		elseif attr("PowerOut") then
			target.Color = Color3.fromRGB(32, 36, 52)
			target.Density = 0.36
		end
		TweenService:Create(atmosphere, info, target):Play()
	end
end

-- Att ljuset går: fönster släcks i vågor i stället för på en gång.
local function refreshAll(staggered: boolean)
	local list = {}
	for part in windows do
		table.insert(list, part)
	end
	if staggered then
		task.spawn(function()
			local root = app.rootPosition()
			table.sort(list, function(a, b)
				if not root then
					return false
				end
				return (a.CFrame.Position - root).Magnitude < (b.CFrame.Position - root).Magnitude
			end)
			for index, part in list do
				if part.Parent then
					applyWindow(part)
				end
				if index % 40 == 0 then
					task.wait(0.03)
				end
			end
		end)
	else
		for _, part in list do
			applyWindow(part)
		end
	end
	local on = lampsOn()
	for part in lamps do
		setLamp(part, on)
	end
	local emergency = attr("PowerOut")
	for part in emergencies do
		setEmergency(part, emergency)
	end
	applyGrade()
end

-- Kortare effekter ----------------------------------------------------------------------------

function WorldFxController.shake(seconds: number, strength: number)
	shakeUntil = math.max(shakeUntil, os.clock() + seconds)
	shakeStrength = math.max(if os.clock() < shakeUntil then shakeStrength else 0, strength)
end

local function flashAt(position: Vector3, color: Color3, range: number, seconds: number)
	local part = Instance.new("Part")
	part.Name = "FxFlash"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.CFrame = CFrame.new(position)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = 6
	light.Shadows = false
	light.Parent = part
	part.Parent = Workspace
	TweenService
		:Create(light, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Brightness = 0 })
		:Play()
	task.delay(seconds + 0.1, function()
		part:Destroy()
	end)
end

-- Gatlyktorna nära en plats blixtrar till och dör (spänningstopp).
local function streetSurge(position: Vector3)
	for part in lamps do
		if part.Parent and (part.CFrame.Position - position).Magnitude < 90 then
			local light = lampLight(part)
			task.spawn(function()
				if light and light:IsA("PointLight") then
					local brightness = light.Brightness
					light.Brightness = brightness * 3
					task.wait(0.15 + math.random() * 0.2)
					setLamp(part, false)
					task.wait(1.5 + math.random() * 2)
					light.Brightness = brightness
					setLamp(part, lampsOn())
				end
			end)
		end
	end
	flashAt(position, Color3.fromRGB(200, 230, 255), 60, 0.6)
	WorldFxController.shake(0.4, 0.15)
end

local function setVignette(on: boolean)
	for _, edge in vignette:GetChildren() do
		if edge:IsA("Frame") then
			TweenService:Create(edge, TweenInfo.new(1.2), { BackgroundTransparency = if on then 0 else 1 }):Play()
		end
	end
end

local function onWorldEvent(event)
	if event.type == "StreetSurge" and typeof(event.position) == "Vector3" then
		streetSurge(event.position)
	elseif event.type == "Anomaly" and typeof(event.position) == "Vector3" then
		flashAt(event.position, Color3.fromRGB(255, 30, 30), 40, 1.2)
		WorldFxController.shake(0.8, 0.35)
	elseif event.type == "Followed" then
		setVignette(event.on == true)
	elseif event.type == "IncidentStart" then
		if event.rarity == "Legendary" or event.rarity == "Major" then
			WorldFxController.shake(0.6, 0.12)
		end
	end
end

local function buildVignette()
	vignette = Ui.new("Frame", {
		Name = "Vignette",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
		Parent = app.root,
	})
	-- Fyra kanter med gradient (Roblox har inga radiella gradienter).
	local edges = {
		{ size = UDim2.fromScale(1, 0.3), position = UDim2.fromScale(0, 0), rotation = 90 },
		{ size = UDim2.fromScale(1, 0.3), position = UDim2.fromScale(0, 0.7), rotation = -90 },
		{ size = UDim2.fromScale(0.25, 1), position = UDim2.fromScale(0, 0), rotation = 0 },
		{ size = UDim2.fromScale(0.25, 1), position = UDim2.fromScale(0.75, 0), rotation = 180 },
	}
	for _, edge in edges do
		Ui.new("Frame", {
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = edge.size,
			Position = edge.position,
			Parent = vignette,
		}, {
			Ui.new("UIGradient", {
				Rotation = edge.rotation,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.15),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}),
		})
	end
end

function WorldFxController.start(appRef)
	app = appRef
	app.fx = WorldFxController
	buildVignette()

	local function watchTag(tag: string, add: (Instance) -> (), store)
		for _, part in CollectionService:GetTagged(tag) do
			add(part)
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(add)
		CollectionService:GetInstanceRemovedSignal(tag):Connect(function(part)
			store[part] = nil
		end)
	end
	watchTag(Tags.WindowLight, addWindow, windows)
	watchTag(Tags.StreetLight, addLamp, lamps)
	watchTag(Tags.EmergencyLight, addEmergency, emergencies)

	Lighting.ChildAdded:Connect(function()
		task.defer(applyGrade)
	end)
	for _, name in { "PowerOut", "OtherLights", "RedSky", "Silent" } do
		ReplicatedStorage:GetAttributeChangedSignal(name):Connect(function()
			refreshAll(name == "PowerOut" or name == "OtherLights")
			if name == "OtherLights" and attr("OtherLights") then
				-- Spelaren ska förstå att något är fel med tornet.
				task.delay(1.5, function()
					if app.notify then
						app.notify("discovery", "CALLOWAY RESIDENCES", "Look at the tower.", 6)
					end
				end)
			end
		end)
	end
	refreshAll(false)
	app.worldEvents:Connect(onWorldEvent)

	-- Nödljusen pulserar; gatlyktor fladdrar ibland när det är spänt i stan.
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.1 then
			return
		end
		elapsed = 0
		if attr("PowerOut") then
			local pulse = 0.6 + 0.6 * math.abs(math.sin(os.clock() * 2.4))
			for part in emergencies do
				local light = lampLight(part)
				if light then
					light.Brightness = pulse
				end
			end
		elseif lampsOn() then
			local heat = ReplicatedStorage:GetAttribute(Constants.WorldAttributes.ServerHeat) or 0
			if heat > 40 and math.random() < heat / 1500 then
				local root = app.rootPosition()
				local candidates = {}
				for part in lamps do
					if root and (part.CFrame.Position - root).Magnitude < 120 then
						table.insert(candidates, part)
					end
				end
				local part = candidates[math.random(1, math.max(1, #candidates))]
				if part then
					task.spawn(function()
						for _ = 1, math.random(2, 4) do
							setLamp(part, false)
							task.wait(0.05 + math.random() * 0.08)
							setLamp(part, lampsOn())
							task.wait(0.05 + math.random() * 0.15)
						end
					end)
				end
			end
		end
	end)

	-- Kameraskakning (liten, och bara när något stort händer).
	RunService:BindToRenderStep("AfterhoursShake", Enum.RenderPriority.Camera.Value + 1, function()
		local now = os.clock()
		if now >= shakeUntil then
			return
		end
		local camera = Workspace.CurrentCamera
		local fade = math.clamp((shakeUntil - now) / 0.4, 0, 1)
		local s = shakeStrength * fade
		camera.CFrame *= CFrame.Angles(
			math.rad((math.noise(now * 18, 0) * 2) * s * 3),
			math.rad((math.noise(0, now * 18) * 2) * s * 3),
			0
		)
	end)
end

return WorldFxController
