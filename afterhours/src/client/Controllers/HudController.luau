-- HudController: den minimala HUD:en. Visar bara TID, HEAT, KONTRAKT, PENGAR, LAG och knappar.
-- När det blir farligt (02:30 ->) blir klockan större och röd. Under stora händelser göms
-- HUD:en en stund (filmiskt läge) så att man kan spela in utan skräp på skärmen.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Shared.Constants)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local ShiftClock = require(ReplicatedStorage.Shared.Logic.ShiftClock)
local Theme = require(script.Parent.Parent.UI.Theme)
local Ui = require(script.Parent.Parent.UI.Ui)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local HudController = {}

local C = Theme.Colors
local Attr = Constants.WorldAttributes
local app
local layer: Frame
local refs = {}

local COMPASS = { "N", "NE", "E", "SE", "S", "SW", "W", "NW" }

local label = Widgets.label
local panel = Widgets.panel

-- Klockan ----------------------------------------------------------------------------------

local function buildClock()
	local clock = panel({
		Name = "Clock",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(230, 62),
		Parent = layer,
	})
	refs.clockText = label({
		Name = "Time",
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.fromOffset(0, 2),
		Font = Theme.Fonts.Digital,
		TextSize = 38,
		TextColor3 = C.Clock,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "00:00",
		Parent = clock,
	})
	refs.clockScale = Ui.new("UIScale", { Parent = refs.clockText })
	refs.phaseText = label({
		Name = "Phase",
		Size = UDim2.new(1, -12, 0, 16),
		Position = UDim2.fromOffset(6, 42),
		Font = Theme.Fonts.Bold,
		TextSize = 12,
		TextColor3 = C.TextDim,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "",
		Parent = clock,
	})
	refs.clock = clock
end

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function updateClock()
	local phase = ReplicatedStorage:GetAttribute(Attr.Phase) or Constants.Phases.Hub
	local shift = GameConfig.Shift
	if phase == Constants.Phases.Night or phase == Constants.Phases.Extraction then
		local startedAt = ReplicatedStorage:GetAttribute(Attr.NightStartedAt) or now()
		local endsAt = ReplicatedStorage:GetAttribute(Attr.NightEndsAt) or now() + 1
		local clock = ShiftClock.clock(shift.StartClock, shift.EndClock, startedAt, endsAt, now())
		refs.clockText.Text = Format.clock(clock)
		if phase == Constants.Phases.Extraction then
			local left = math.max(0, endsAt - now())
			refs.phaseText.Text = "SHIFT ENDING  ·  GET TO THE DEPOT  " .. Format.duration(left)
			refs.phaseText.TextColor3 = C.Danger
			refs.clockText.TextColor3 = if math.floor(now() * 2) % 2 == 0 then C.Danger else C.Clock
			refs.clockScale.Scale = 1.12
		else
			local district = "DOWNTOWN"
			if ReplicatedStorage:GetAttribute("PowerOut") then
				district = "DOWNTOWN  ·  NO POWER"
			end
			refs.phaseText.Text = "NIGHT SHIFT  ·  " .. district
			refs.phaseText.TextColor3 = C.TextDim
			refs.clockText.TextColor3 = C.Clock
			refs.clockScale.Scale = 1
		end
	elseif phase == Constants.Phases.Results then
		refs.clockText.Text = "03:00"
		refs.clockText.TextColor3 = C.Clock
		refs.clockScale.Scale = 1
		refs.phaseText.Text = "SHIFT OVER"
		refs.phaseText.TextColor3 = C.TextDim
	else
		local endsAt = ReplicatedStorage:GetAttribute(Attr.PhaseEndsAt) or now()
		refs.clockText.Text = "23:5" .. tostring(9 - math.clamp(math.floor((endsAt - now()) / 5), 0, 9))
		refs.clockText.TextColor3 = C.Clock
		refs.clockScale.Scale = 1
		local forecast = ReplicatedStorage:GetAttribute(Attr.Forecast)
		local next = "NEXT SHIFT IN " .. Format.duration(endsAt - now())
		refs.phaseText.Text = if forecast and forecast ~= ""
			then next .. "  ·  TONIGHT: " .. forecast .. " RISK"
			else next
		refs.phaseText.TextColor3 = C.Dispatch
	end
end

-- HEAT ---------------------------------------------------------------------------------------

local function buildHeat()
	local heat =
		panel({ Name = "Heat", Position = UDim2.fromOffset(12, 78), Size = UDim2.fromOffset(250, 46), Parent = layer })
	label({
		Text = "HEAT",
		Font = Theme.Fonts.Display,
		TextSize = 13,
		TextColor3 = C.TextDim,
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.fromOffset(60, 14),
		Parent = heat,
	})
	refs.heatTier = label({
		Text = "CALM",
		Font = Theme.Fonts.Display,
		TextSize = 13,
		Position = UDim2.fromOffset(60, 6),
		Size = UDim2.fromOffset(120, 14),
		Parent = heat,
	})
	refs.heatValue = label({
		Text = "0",
		Font = Theme.Fonts.Digital,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.new(1, -52, 0, 5),
		Size = UDim2.fromOffset(40, 16),
		Parent = heat,
	})
	local bar = Ui.new("Frame", {
		BackgroundColor3 = C.PanelLight,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(12, 27),
		Size = UDim2.new(1, -24, 0, 8),
		Parent = heat,
	}, { Ui.corner(4) })
	refs.heatFill = Ui.new(
		"Frame",
		{ BackgroundColor3 = Theme.HeatColors.CALM, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1), Parent = bar },
		{ Ui.corner(4) }
	)
end

local function updateHeat(heat)
	if not heat then
		return
	end
	refs.heatTier.Text = heat.tier
	local color = Theme.HeatColors[heat.tier] or C.Text
	refs.heatTier.TextColor3 = color
	refs.heatValue.Text = tostring(heat.value)
	refs.heatFill.BackgroundColor3 = color
	TweenService
		:Create(refs.heatFill, TweenInfo.new(0.4), { Size = UDim2.fromScale(math.clamp(heat.value / 100, 0, 1), 1) })
		:Play()
end

-- Kontraktet ---------------------------------------------------------------------------------

local function buildContract()
	local card = panel({
		Name = "Contract",
		Position = UDim2.fromOffset(12, 130),
		Size = UDim2.fromOffset(300, 96),
		Parent = layer,
	})
	refs.contractTier = Ui.new("TextLabel", {
		BackgroundColor3 = C.Good,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(12, 10),
		Size = UDim2.fromOffset(74, 18),
		Font = Theme.Fonts.Display,
		TextSize = 11,
		TextColor3 = Color3.new(0, 0, 0),
		Text = "SAFE",
		Parent = card,
	}, { Ui.corner(4) })
	refs.contractTitle = label({
		Text = "",
		Font = Theme.Fonts.Bold,
		TextSize = 15,
		Position = UDim2.fromOffset(94, 9),
		Size = UDim2.new(1, -104, 0, 20),
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = card,
	})
	refs.contractStep = label({
		Text = "",
		Font = Theme.Fonts.Body,
		TextSize = 13,
		TextWrapped = true,
		TextColor3 = C.Text,
		Position = UDim2.fromOffset(12, 34),
		Size = UDim2.new(1, -24, 0, 34),
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = card,
	})
	refs.contractNav = label({
		Text = "",
		Font = Theme.Fonts.Digital,
		TextSize = 13,
		TextColor3 = C.Dispatch,
		Position = UDim2.fromOffset(12, 72),
		Size = UDim2.new(1, -24, 0, 16),
		Parent = card,
	})
	refs.contract = card
end

local function updateContract(contract)
	local hasContract = contract and contract.active
	if not hasContract then
		refs.contractTier.Text = "NO JOB"
		refs.contractTier.BackgroundColor3 = C.Line
		refs.contractTitle.Text = "Waiting for a contract"
		local touch = UserInputService.TouchEnabled
		refs.contractStep.Text = if touch
			then "Tap DISPATCH to pick your next job."
			else "Press TAB or use DISPATCH at the depot."
		refs.contractNav.Text = ""
		return
	end
	local tierColors = { Safe = C.Good, Normal = C.Warning, HighRisk = C.Danger }
	refs.contractTier.Text = contract.tierLabel
	refs.contractTier.BackgroundColor3 = tierColors[contract.tier] or C.Good
	refs.contractTitle.Text = contract.title
	refs.contractStep.Text = string.format("%d/%d  %s", contract.step.index, contract.step.total, contract.step.text)
end

local function updateNav()
	local contract = app.state.get("contract")
	local here = app.rootPosition()
	if not contract or not contract.active or not contract.targetPosition or not here then
		refs.contractNav.Text = ""
		return
	end
	local offset = contract.targetPosition - here
	local flat = Vector3.new(offset.X, 0, offset.Z)
	-- Väderstreck: norr = -Z
	local angle = math.atan2(flat.X, -flat.Z)
	local index = (math.floor((angle / (math.pi * 2)) * 8 + 0.5) % 8) + 1
	local height = if math.abs(offset.Y) > 8 then (if offset.Y > 0 then "  ▲ UP" else "  ▼ DOWN") else ""
	refs.contractNav.Text = "◆ " .. Format.distance(flat.Magnitude) .. "  " .. COMPASS[index] .. height
end

-- Pengar ----------------------------------------------------------------------------------------

local function buildMoney()
	local money = panel({
		Name = "Money",
		Position = UDim2.fromOffset(12, 232),
		Size = UDim2.fromOffset(300, 44),
		Parent = layer,
	})
	refs.credits = label({
		Text = "0 cr",
		Font = Theme.Fonts.Display,
		TextSize = 15,
		TextColor3 = C.Credits,
		Position = UDim2.fromOffset(12, 5),
		Size = UDim2.new(1, -24, 0, 18),
		Parent = money,
	})
	refs.unsecured = label({
		Text = "",
		Font = Theme.Fonts.Body,
		TextSize = 12,
		TextColor3 = C.TextDim,
		Position = UDim2.fromOffset(12, 23),
		Size = UDim2.new(1, -24, 0, 16),
		Parent = money,
	})
end

local function updateMoney()
	local profile = app.state.get("profile")
	local economy = app.state.get("economy")
	if profile then
		refs.credits.Text = Format.credits(profile.credits) .. " cr"
	end
	if economy then
		local unsecured = economy.pendingValue + economy.carriedValue
		refs.unsecured.Text = if unsecured > 0
			then "UNSECURED  " .. Format.credits(unsecured) .. " cr  ·  secure it at the depot"
			else "Nothing at risk"
		refs.unsecured.TextColor3 = if unsecured > 0 then C.Warning else C.TextDim
	end
end

-- Laget -----------------------------------------------------------------------------------------

local function buildTeam()
	refs.team = panel({
		Name = "Team",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 78),
		Size = UDim2.fromOffset(210, 34),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		Parent = layer,
	}, {
		Ui.padding(8),
		Ui.list(Enum.FillDirection.Vertical, 4),
	})
end

local function updateTeam(squad)
	Ui.clear(refs.team)
	if not squad or not squad.id then
		refs.team.Visible = false
		return
	end
	refs.team.Visible = true
	label({
		Text = "SQUAD",
		Font = Theme.Fonts.Display,
		TextSize = 12,
		TextColor3 = C.Dispatch,
		Size = UDim2.new(1, 0, 0, 14),
		LayoutOrder = 0,
		Parent = refs.team,
	})
	local colors = { Safe = C.Good, Out = C.Warning, Down = C.Danger }
	for index, member in squad.members do
		local row = Ui.new(
			"Frame",
			{ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 16), LayoutOrder = index, Parent = refs.team }
		)
		Ui.new("Frame", {
			BackgroundColor3 = colors[member.status] or C.Text,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, 4),
			Size = UDim2.fromOffset(8, 8),
			Parent = row,
		}, { Ui.corner(4) })
		label({
			Text = member.name,
			Font = Theme.Fonts.Bold,
			TextSize = 12,
			Position = UDim2.fromOffset(14, 0),
			Size = UDim2.new(1, -70, 1, 0),
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = row,
		})
		label({
			Text = member.status:upper() .. " " .. member.heat,
			Font = Theme.Fonts.Digital,
			TextSize = 11,
			TextColor3 = C.TextDim,
			TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.new(1, -60, 0, 0),
			Size = UDim2.fromOffset(60, 16),
			Parent = row,
		})
	end
end

-- Filmiskt läge -----------------------------------------------------------------------------------

local cinematicToken = 0
function HudController.cinematic(seconds: number)
	cinematicToken += 1
	local token = cinematicToken
	layer.Visible = false
	task.delay(seconds, function()
		if token == cinematicToken then
			layer.Visible = true
		end
	end)
end

function HudController.setVisible(visible: boolean)
	layer.Visible = visible
end

function HudController.start(appRef)
	app = appRef
	layer =
		Ui.new("Frame", { Name = "Hud", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = app.root })
	app.hudLayer = layer
	buildClock()
	buildHeat()
	buildContract()
	buildMoney()
	buildTeam()

	app.state.watch("heat", updateHeat)
	app.state.watch("contract", function(contract)
		updateContract(contract)
		updateNav()
	end)
	app.state.watch("profile", updateMoney)
	app.state.watch("economy", updateMoney)
	app.state.watch("squad", updateTeam)
	updateContract(nil)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= 0.2 then
			elapsed = 0
			updateClock()
			updateNav()
		end
	end)
end

return HudController
