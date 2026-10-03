-- ResultsController: skiftrapporten efter 03:00 ("AFTERHOURS REPORT"). Kortet ska kännas
-- som en liten berättelse om natten och se bra ut på en skärmdump: rubrik, vad som hände,
-- största händelsen, pengarna rad för rad och nattens bästa fynd.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)
local ProgressionConfig = require(ReplicatedStorage.Shared.Config.ProgressionConfig)
local Theme = require(script.Parent.Parent.UI.Theme)
local Ui = require(script.Parent.Parent.UI.Ui)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local ResultsController = {}

local C = Theme.Colors
local app
local overlay: Frame
local cardFrame: Frame
local body: ScrollingFrame

local function line(text: string, order: number, props)
	local defaults = {
		Text = text,
		Font = Theme.Fonts.Body,
		TextSize = 14,
		TextColor3 = C.Text,
		Size = UDim2.new(1, 0, 0, 18),
		LayoutOrder = order,
		Parent = body,
	}
	for k, v in props or {} do
		defaults[k] = v
	end
	return Widgets.label(defaults)
end

-- Rad med etikett till vänster och värde till höger.
local function row(label: string, text: string, order: number, valueColor: Color3?): (Frame, TextLabel)
	local frame = Ui.new(
		"Frame",
		{ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = order, Parent = body }
	)
	Widgets.label({
		Text = label,
		Font = Theme.Fonts.Body,
		TextSize = 14,
		TextColor3 = C.TextDim,
		Size = UDim2.fromScale(0.65, 1),
		Parent = frame,
	})
	local value = Widgets.label({
		Text = text,
		Font = Theme.Fonts.Digital,
		TextSize = 15,
		TextColor3 = valueColor or C.Text,
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.fromScale(0.65, 0),
		Size = UDim2.fromScale(0.35, 1),
		Parent = frame,
	})
	return frame, value
end

local function divider(order: number)
	Ui.new("Frame", {
		BackgroundColor3 = C.Line,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 1),
		LayoutOrder = order,
		Parent = body,
	})
end

function ResultsController.show(report)
	Ui.clear(body)
	local survived = report.survived
	local accent = if survived then C.Good else C.Danger

	line(report.title, 1, { Font = Theme.Fonts.Display, TextSize = 13, TextColor3 = C.Dispatch })
	line(report.shift, 2, { Font = Theme.Fonts.Digital, TextSize = 13, TextColor3 = C.TextDim })
	line(
		report.headline,
		3,
		{ Font = Theme.Fonts.Display, TextSize = 30, Size = UDim2.new(1, 0, 0, 38), TextColor3 = accent }
	)
	divider(4)

	local order = 10
	for _, fact in report.facts do
		order += 1
		row(fact.label, fact.value, order)
	end
	if report.biggestIncident then
		order += 1
		row("Biggest incident", report.biggestIncident, order, C.Warning)
	end
	divider(30)

	order = 30
	for _, entry in report.lines do
		order += 1
		local value = (if entry.value < 0 then "-" else "+") .. Format.credits(math.abs(entry.value))
		row(entry.label, value, order, if entry.value < 0 then C.Danger else C.Text)
	end
	order += 1
	local totalRow, totalLabel = row("TOTAL", "0 cr", order, C.Credits)
	totalLabel.TextSize = 20
	totalRow.Size = UDim2.new(1, 0, 0, 24)
	divider(50)

	order = 50
	if report.find then
		local rarity = ItemConfig.Rarities[report.find.rarity]
		order += 1
		row("Best find", report.find.name, order, rarity and rarity.color)
	end
	for _, discovery in report.discoveries or {} do
		order += 1
		line("◆ DISCOVERED  " .. discovery, order, { TextColor3 = C.Discovery, Font = Theme.Fonts.Bold })
	end
	for _, titleId in report.titlesEarned or {} do
		local def = ProgressionConfig.Titles[titleId]
		order += 1
		line(
			"NEW TITLE  " .. (if def then def.text else titleId),
			order,
			{ TextColor3 = def and def.color or C.Text, Font = Theme.Fonts.Display }
		)
	end
	order += 1
	line(
		if survived
			then "Your pay is safe. The city will be different tomorrow."
			else "What you carried is still out there. Someone else will find it.",
		order,
		{
			TextColor3 = C.TextDim,
			TextSize = 12,
			TextWrapped = true,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
		}
	)
	order += 1
	Widgets.button(
		{ Text = "CONTINUE", Size = UDim2.new(1, 0, 0, 44), LayoutOrder = order, Parent = body },
		ResultsController.hide,
		"primary"
	)

	-- Visa kortet och räkna upp summan
	overlay.Visible = true
	body.CanvasPosition = Vector2.zero
	cardFrame.Position = UDim2.new(0.5, 0, 0.5, 30)
	TweenService:Create(
		cardFrame,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = UDim2.fromScale(0.5, 0.5) }
	):Play()
	local counter = Instance.new("NumberValue")
	counter.Changed:Connect(function(value)
		totalLabel.Text = Format.credits(math.floor(value)) .. " cr"
	end)
	local tween = TweenService:Create(
		counter,
		TweenInfo.new(1.6, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{ Value = report.total }
	)
	tween:Play()
	tween.Completed:Once(function()
		totalLabel.Text = Format.credits(report.total) .. " cr"
		counter:Destroy()
	end)
	if app.audio then
		app.audio.play(if survived then "Secure" else "PowerDown")
	end
	app.hud.setVisible(false)
	if app.dispatch then
		app.dispatch.close()
	end
end

function ResultsController.hide()
	overlay.Visible = false
	app.hud.setVisible(true)
end

function ResultsController.start(appRef)
	app = appRef
	overlay = Ui.new("Frame", {
		Name = "Results",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 20,
		Parent = app.root,
	})
	-- Kortet får aldrig bli högre än skärmen; blir det långt kan man scrolla.
	cardFrame = Widgets.panel({
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 440, 1, -24),
		BackgroundTransparency = 0.02,
		Parent = overlay,
	}, { Ui.new("UISizeConstraint", { MaxSize = Vector2.new(440, 660) }) })
	body = Ui.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(20, 16),
		Size = UDim2.new(1, -32, 1, -32),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = C.Line,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = cardFrame,
	}, { Ui.list(Enum.FillDirection.Vertical, 5), Ui.new("UIPadding", { PaddingRight = UDim.new(0, 8) }) })

	app.remotes.ShiftReport.OnClientEvent:Connect(function(report)
		if type(report) == "table" and type(report.lines) == "table" then
			ResultsController.show(report)
		end
	end)
	-- Kortet stängs av sig självt när nästa skift börjar.
	ReplicatedStorage:GetAttributeChangedSignal(Constants.WorldAttributes.Phase):Connect(function()
		local phase = ReplicatedStorage:GetAttribute(Constants.WorldAttributes.Phase)
		if phase == Constants.Phases.Night and overlay.Visible then
			ResultsController.hide()
		end
	end)
end

return ResultsController
