-- Theme: AFTERHOURS visuella språk. Mörka paneler med tunna kanter, bärnstensfärgad klocka
-- (digital, som spelets ikon), cyan för dispatch, HEAT från turkos till rött.
-- Allt skalas efter skärmen (UIScale) så att samma layout fungerar på mobil, PC och TV.

local Theme = {}

Theme.Colors = {
	Panel = Color3.fromRGB(10, 13, 20),
	PanelLight = Color3.fromRGB(20, 25, 36),
	Line = Color3.fromRGB(60, 72, 92),
	Text = Color3.fromRGB(230, 234, 240),
	TextDim = Color3.fromRGB(140, 150, 166),
	Clock = Color3.fromRGB(255, 186, 72),
	Dispatch = Color3.fromRGB(80, 230, 255),
	Good = Color3.fromRGB(110, 230, 150),
	Warning = Color3.fromRGB(255, 200, 80),
	Danger = Color3.fromRGB(255, 80, 72),
	Discovery = Color3.fromRGB(110, 255, 214),
	Credits = Color3.fromRGB(255, 214, 110),
}

Theme.HeatColors = {
	CALM = Color3.fromRGB(80, 220, 200),
	UNEASY = Color3.fromRGB(160, 230, 110),
	TENSE = Color3.fromRGB(255, 210, 80),
	FAILING = Color3.fromRGB(255, 140, 60),
	CRITICAL = Color3.fromRGB(255, 60, 60),
}

Theme.Fonts = {
	Display = Enum.Font.GothamBlack,
	Bold = Enum.Font.GothamBold,
	Body = Enum.Font.GothamMedium,
	Digital = Enum.Font.Code,
}

Theme.PanelTransparency = 0.18

-- Skalan för hela gränssnittet: designat för 1280 px bredd/720 px höjd.
function Theme.scaleFor(viewport: Vector2): number
	local scale = math.min(viewport.X / 1280, viewport.Y / 720)
	return math.clamp(scale, 0.62, 1.4)
end

return Theme
