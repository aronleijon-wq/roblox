-- DebugController: testpanel (F8) för Studio och spelets ägare. Startar incidenter, hoppar
-- i tiden, ger HEAT, krediter och föremål. Servern kontrollerar ändå vem som får använda den.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Parent.UI.Theme)
local Ui = require(script.Parent.Parent.UI.Ui)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local DebugController = {}

local C = Theme.Colors

local INCIDENTS = {
	"Blackout",
	"FalseAlarm",
	"EmergencyShift",
	"SilentCity",
	"ClosedStation",
	"TheFollower",
	"UnknownPackage",
	"Lockdown",
	"CascadeFailure",
	"ImpossibleLights",
}
local TWISTS = { "LightsReturn", "Overload", "WrongAddress" }
local QUICK = {
	{ "clock 2.4", "clock", "2.4" },
	{ "clock 2.9", "clock", "2.9" },
	{ "skip phase", "skip", "" },
	{ "heat 85", "heat", "85" },
	{ "heat 0", "heat", "0" },
	{ "+5000 cr", "credits", "5000" },
	{ "+1000 rep", "rep", "1000" },
	{ "give radio", "give", "OldRadio" },
	{ "give letter", "give", "SealedLetter" },
}

local function allowed(): boolean
	local player = Players.LocalPlayer
	return RunService:IsStudio() or (game.CreatorType == Enum.CreatorType.User and game.CreatorId == player.UserId)
end

function DebugController.start(app)
	if not allowed() then
		return
	end
	local panel = Widgets.panel({
		Name = "Debug",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -12),
		Size = UDim2.fromOffset(420, 360),
		BackgroundTransparency = 0.05,
		Visible = false,
		ZIndex = 30,
		Parent = app.root,
	})
	Widgets.label({
		Text = "DEBUG  (F8)",
		Font = Theme.Fonts.Display,
		TextSize = 13,
		TextColor3 = C.Warning,
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.fromOffset(200, 16),
		Parent = panel,
	})
	local scroll = Ui.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(12, 30),
		Size = UDim2.new(1, -24, 1, -42),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		Parent = panel,
	}, {
		Ui.new("UIGridLayout", {
			CellSize = UDim2.new(1 / 3, -6, 0, 34),
			CellPadding = UDim2.fromOffset(6, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local order = 0
	local function add(label: string, command: string, argument: string, style: string?)
		order += 1
		local button = Widgets.button({ Text = label, TextSize = 11, LayoutOrder = order, Parent = scroll }, function()
			app.remotes.DebugCommand:FireServer(command, argument)
		end, style)
		button.TextWrapped = true
	end
	for _, entry in QUICK do
		add(entry[1], entry[2], entry[3], "ghost")
	end
	for _, id in INCIDENTS do
		add(id, "incident", id, "primary")
	end
	for _, id in TWISTS do
		add("twist " .. id, "twist", id, "danger")
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.F8 then
			panel.Visible = not panel.Visible
		end
	end)
end

return DebugController
