-- Widgets: gemensamma byggstenar i AFTERHOURS stil (paneler, etiketter, knappar).
-- Knapparna är minst 44 px höga (före skalning) så att de går att träffa med tummen.

local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)

local Widgets = {}

local C = Theme.Colors

local function merge(defaults, props)
	for k, v in props or {} do
		defaults[k] = v
	end
	return defaults
end

function Widgets.label(props)
	return Ui.new(
		"TextLabel",
		merge({
			BackgroundTransparency = 1,
			Font = Theme.Fonts.Bold,
			TextColor3 = C.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextScaled = false,
		}, props)
	)
end

function Widgets.panel(props, children)
	local frame = Ui.new(
		"Frame",
		merge({
			BackgroundColor3 = C.Panel,
			BackgroundTransparency = Theme.PanelTransparency,
			BorderSizePixel = 0,
		}, props),
		children
	)
	Ui.corner(10).Parent = frame
	Ui.stroke(C.Line, 1, 0.5).Parent = frame
	return frame
end

-- En knapp med text. style: "primary" (cyan), "danger", "ghost" (bara kant) eller nil.
function Widgets.button(props, onClick: (() -> ())?, style: string?)
	local colors = {
		primary = { bg = C.Dispatch, text = Color3.new(0, 0, 0) },
		danger = { bg = C.Danger, text = Color3.new(1, 1, 1) },
		good = { bg = C.Good, text = Color3.new(0, 0, 0) },
		ghost = { bg = C.PanelLight, text = C.Text },
	}
	local scheme = colors[style or "ghost"] or colors.ghost
	local button = Ui.new(
		"TextButton",
		merge({
			AutoButtonColor = true,
			BackgroundColor3 = scheme.bg,
			BorderSizePixel = 0,
			Font = Theme.Fonts.Display,
			TextSize = 14,
			TextColor3 = scheme.text,
			Size = UDim2.fromOffset(120, 44),
		}, props)
	)
	Ui.corner(8).Parent = button
	if style == "ghost" or style == nil then
		Ui.stroke(C.Line, 1, 0.3).Parent = button
	end
	if onClick then
		button.Activated:Connect(function()
			if not button:GetAttribute("Disabled") then
				onClick()
			end
		end)
	end
	return button
end

-- Sätter en knapp som aktiv/inaktiv (gråar ut den).
function Widgets.setEnabled(button: TextButton, enabled: boolean)
	button:SetAttribute("Disabled", not enabled)
	button.AutoButtonColor = enabled
	button.BackgroundTransparency = if enabled then 0 else 0.6
	button.TextTransparency = if enabled then 0 else 0.4
end

return Widgets
