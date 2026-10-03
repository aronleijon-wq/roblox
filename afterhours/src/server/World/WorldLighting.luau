-- WorldLighting: nattens grundljus. Stilen: filmisk natt med hög kontrast, varma gatlyktor,
-- kall himmel och dimma som används sparsamt. Staden ska se normal ut i början.
-- (Lighting.Technology kan inte sättas från skript; den står i default.project.json.)

local Lighting = game:GetService("Lighting")

local WorldLighting = {}

local function ensure(className: string, name: string): Instance
	local existing = Lighting:FindFirstChild(name)
	if existing and existing:IsA(className) then
		return existing
	end
	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = Lighting
	return instance
end

function WorldLighting.apply()
	Lighting.ClockTime = 0.5
	Lighting.Brightness = 1.2
	Lighting.Ambient = Color3.fromRGB(26, 28, 40)
	Lighting.OutdoorAmbient = Color3.fromRGB(46, 52, 76)
	Lighting.EnvironmentDiffuseScale = 0.25
	Lighting.EnvironmentSpecularScale = 0.5
	Lighting.ExposureCompensation = 0.25
	Lighting.GlobalShadows = true

	local atmosphere = ensure("Atmosphere", "NightAtmosphere") :: Atmosphere
	atmosphere.Density = 0.32
	atmosphere.Offset = 0.12
	atmosphere.Color = Color3.fromRGB(60, 70, 96)
	atmosphere.Decay = Color3.fromRGB(28, 30, 44)
	atmosphere.Glare = 0
	atmosphere.Haze = 1.2

	local bloom = ensure("BloomEffect", "NightBloom") :: BloomEffect
	bloom.Intensity = 0.55
	bloom.Size = 26
	bloom.Threshold = 1.15

	-- Grundfärgen. Klienten justerar den lokalt vid incidenter (BLACKOUT, SILENT CITY ...).
	local grade = ensure("ColorCorrectionEffect", "NightGrade") :: ColorCorrectionEffect
	grade.Brightness = 0
	grade.Contrast = 0.1
	grade.Saturation = 0.05
	grade.TintColor = Color3.fromRGB(240, 244, 255)
end

return WorldLighting
