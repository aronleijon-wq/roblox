-- DialogController: små rutor som kräver ett beslut.
--   * Kontraktsvändning ("SOMETHING INSIDE"): välj vad du gör.
--   * Laginbjudan: gå med eller tacka nej.
--   * Knappsatsen vid Maintenance B-7: skriv en fyrsiffrig kod.
-- Rutorna stänger sig själva efter en stund så att man aldrig fastnar i dem.

local Theme = require(script.Parent.Parent.UI.Theme)
local Ui = require(script.Parent.Parent.UI.Ui)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local DialogController = {}

local C = Theme.Colors
local CODE_LENGTH = 4 -- samma som SecretConfig.CodeLength (den filen finns bara på servern)
local app
local layer: Frame

local function dialog(name: string, width: number, accent: Color3): (Frame, Frame)
	local existing = layer:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
	local frame = Widgets.panel({
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.58),
		Size = UDim2.fromOffset(width, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 0.05,
		Parent = layer,
	}, { Ui.padding(16) })
	local stroke = frame:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = accent
		stroke.Transparency = 0.2
	end
	local body = Ui.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = frame,
	}, { Ui.list(Enum.FillDirection.Vertical, 8) })
	return frame, body
end

local function text(parent: Instance, value: string, order: number, props)
	local defaults = {
		Text = value,
		Font = Theme.Fonts.Body,
		TextSize = 14,
		TextWrapped = true,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
		Parent = parent,
	}
	for k, v in props or {} do
		defaults[k] = v
	end
	return Widgets.label(defaults)
end

local function buttonRow(parent: Instance, order: number): Frame
	return Ui.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 44),
		LayoutOrder = order,
		Parent = parent,
	}, { Ui.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center) })
end

-- Kontraktsvändning ---------------------------------------------------------------------------

local function twistChoice(event)
	if type(event.key) ~= "string" or type(event.options) ~= "table" then
		return
	end
	local frame, body = dialog("TwistChoice", 460, C.Warning)
	text(
		body,
		tostring(event.title or "SOMETHING HAPPENED"),
		1,
		{ Font = Theme.Fonts.Display, TextSize = 20, TextColor3 = C.Warning }
	)
	text(body, tostring(event.text or ""), 2)
	local grid = Ui.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 3,
		Parent = body,
	}, {
		Ui.new("UIGridLayout", {
			CellSize = UDim2.new(0.5, -4, 0, 44),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local chosen = false
	for index, option in event.options do
		local button = Widgets.button({
			Text = string.upper(tostring(option.label)),
			LayoutOrder = index,
			Parent = grid,
		}, function()
			if chosen then
				return
			end
			chosen = true
			app.remotes.TwistChoice:FireServer(event.key, option.id)
			frame:Destroy()
		end, if index == 1 then "primary" else "ghost")
		button.TextSize = 13
	end
	if app.audio then
		app.audio.play("Knock")
	end
	task.delay(20, function()
		if frame.Parent then
			frame:Destroy()
		end
	end)
end

-- Laginbjudan --------------------------------------------------------------------------------

local function squadInvite(invite)
	if type(invite) ~= "table" or type(invite.fromUserId) ~= "number" then
		return
	end
	local frame, body = dialog("SquadInvite", 380, C.Dispatch)
	frame.Position = UDim2.new(0.5, 0, 0, 150)
	frame.AnchorPoint = Vector2.new(0.5, 0)
	text(body, "SQUAD INVITE", 1, { Font = Theme.Fonts.Display, TextSize = 14, TextColor3 = C.Dispatch })
	text(body, tostring(invite.fromName) .. " wants you on their squad tonight.", 2)
	local row = buttonRow(body, 3)
	local function respond(accept: boolean)
		app.remotes.SquadRequest:FireServer("respond", { accept = accept, fromUserId = invite.fromUserId })
		frame:Destroy()
	end
	Widgets.button({ Text = "JOIN", Size = UDim2.fromOffset(150, 44), LayoutOrder = 1, Parent = row }, function()
		respond(true)
	end, "primary")
	Widgets.button({ Text = "NOT NOW", Size = UDim2.fromOffset(150, 44), LayoutOrder = 2, Parent = row }, function()
		respond(false)
	end, "ghost")
	task.delay(28, function()
		if frame.Parent then
			frame:Destroy()
		end
	end)
end

-- Knappsatsen --------------------------------------------------------------------------------

local keypadDisplay: TextLabel? = nil
local keypadFrame: Frame? = nil
local entered = ""

local function updateDisplay(color: Color3?)
	if not keypadDisplay then
		return
	end
	local shown = entered .. string.rep("_", CODE_LENGTH - #entered)
	keypadDisplay.Text = shown:gsub(".", "%0 "):sub(1, -2)
	keypadDisplay.TextColor3 = color or C.Clock
end

function DialogController.keypad()
	local frame, body = dialog("Keypad", 280, C.Line)
	keypadFrame = frame
	entered = ""
	text(body, "MAINTENANCE B-7", 1, {
		Font = Theme.Fonts.Display,
		TextSize = 13,
		TextColor3 = C.TextDim,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	keypadDisplay = text(body, "", 2, {
		Font = Theme.Fonts.Digital,
		TextSize = 34,
		TextXAlignment = Enum.TextXAlignment.Center,
		AutomaticSize = Enum.AutomaticSize.None,
		Size = UDim2.new(1, 0, 0, 44),
	})
	updateDisplay()
	local grid = Ui.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 3,
		Parent = body,
	}, {
		Ui.new("UIGridLayout", {
			CellSize = UDim2.new(1 / 3, -6, 0, 46),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local keys = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "CLR", "0", "OK" }
	for index, key in keys do
		Widgets.button({ Text = key, TextSize = 18, LayoutOrder = index, Parent = grid }, function()
			if key == "CLR" then
				entered = ""
				updateDisplay()
			elseif key == "OK" then
				if #entered == CODE_LENGTH then
					app.remotes.SubmitCode:FireServer(entered)
				end
			elseif #entered < CODE_LENGTH then
				entered ..= key
				updateDisplay()
			end
		end, if key == "OK" then "primary" else "ghost")
	end
	Widgets.button({ Text = "CLOSE", Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 4, Parent = body }, function()
		frame:Destroy()
	end, "ghost")
	task.delay(85, function()
		if frame.Parent then
			frame:Destroy()
		end
	end)
end

local function keypadResult(ok: boolean)
	if not keypadFrame or not keypadFrame.Parent then
		return
	end
	if ok then
		updateDisplay(C.Good)
		local frame = keypadFrame
		task.delay(1.2, function()
			if frame.Parent then
				frame:Destroy()
			end
		end)
	else
		updateDisplay(C.Danger)
		task.delay(0.8, function()
			entered = ""
			updateDisplay()
		end)
	end
end

function DialogController.start(appRef)
	app = appRef
	app.dialogs = DialogController
	layer = Ui.new("Frame", {
		Name = "Dialogs",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 15,
		Parent = app.root,
	})
	app.remotes.SquadInvite.OnClientEvent:Connect(squadInvite)
	app.worldEvents:Connect(function(event)
		if event.type == "TwistChoice" then
			twistChoice(event)
		elseif event.type == "Keypad" then
			keypadResult(event.ok == true)
		end
	end)
end

return DialogController
