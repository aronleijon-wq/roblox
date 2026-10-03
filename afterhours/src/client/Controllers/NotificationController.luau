-- NotificationController: allt spelet säger till spelaren.
--   * Radio (DISPATCH m.fl.): en rad radiotext längst ned till vänster, som en kommunikationsradio.
--     När kommunikationen är nere (THE OTHER LIGHTS) blir texten brus.
--   * Toasts (info/varning/fara/bra/upptäckt): korta lappar under klockan, max tre åt gången.
--   * Incidentbanderoll: stort namn mitt på skärmen när något händer i staden.
-- Allt viktigt visas i text; ljudet förstärker bara (spelet ska gå att spela utan ljud).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Parent.UI.Theme)
local Ui = require(script.Parent.Parent.UI.Ui)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local NotificationController = {}

local C = Theme.Colors
local app
local toastList: Frame
local radioFrame: Frame
local radioFrom: TextLabel
local radioText: TextLabel
local banner: Frame
local bannerTitle: TextLabel
local bannerSub: TextLabel

local KIND_COLORS = {
	info = C.Text,
	warning = C.Warning,
	danger = C.Danger,
	good = C.Good,
	discovery = C.Discovery,
	radio = C.Dispatch,
}

local KIND_SOUNDS = {
	radio = "RadioBlip",
	discovery = "Rare",
	good = "Secure",
}

local RARITY_COLORS = {
	Common = C.TextDim,
	Uncommon = C.Good,
	Rare = C.Dispatch,
	Major = C.Warning,
	Legendary = C.Discovery,
}

local MAX_TOASTS = 3
local order = 0

-- Toasts ------------------------------------------------------------------------------------

local function toast(kind: string, title: string?, text: string, duration: number?)
	order += 1
	local color = KIND_COLORS[kind] or C.Text
	local card = Widgets.panel({
		Name = "Toast",
		Size = UDim2.fromOffset(360, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
		BackgroundTransparency = 1,
		Parent = toastList,
	}, { Ui.padding(10), Ui.list(Enum.FillDirection.Vertical, 2) })
	Ui.new("Frame", {
		Name = "Accent",
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(-10, -10),
		Size = UDim2.new(0, 3, 1, 20),
		Parent = card,
	})
	local labels = {}
	if title then
		table.insert(
			labels,
			Widgets.label({
				Text = title,
				Font = Theme.Fonts.Display,
				TextSize = 13,
				TextColor3 = color,
				Size = UDim2.new(1, 0, 0, 16),
				LayoutOrder = 1,
				TextTransparency = 1,
				Parent = card,
			})
		)
	end
	table.insert(
		labels,
		Widgets.label({
			Text = text,
			Font = Theme.Fonts.Body,
			TextSize = 14,
			TextWrapped = true,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 2,
			TextTransparency = 1,
			Parent = card,
		})
	)

	-- Tona in
	local fadeIn = TweenInfo.new(0.25)
	TweenService:Create(card, fadeIn, { BackgroundTransparency = Theme.PanelTransparency }):Play()
	for _, label in labels do
		TweenService:Create(label, fadeIn, { TextTransparency = 0 }):Play()
	end

	-- Bara de senaste syns
	local toasts = {}
	for _, child in toastList:GetChildren() do
		if child:IsA("Frame") then
			table.insert(toasts, child)
		end
	end
	table.sort(toasts, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	while #toasts > MAX_TOASTS do
		table.remove(toasts, 1):Destroy()
	end

	task.delay(duration or 4, function()
		if not card.Parent then
			return
		end
		local fadeOut = TweenInfo.new(0.4)
		TweenService:Create(card, fadeOut, { BackgroundTransparency = 1 }):Play()
		for _, label in labels do
			TweenService:Create(label, fadeOut, { TextTransparency = 1 }):Play()
		end
		local stroke = card:FindFirstChildOfClass("UIStroke")
		if stroke then
			TweenService:Create(stroke, fadeOut, { Transparency = 1 }):Play()
		end
		task.wait(0.45)
		card:Destroy()
	end)
end

-- Radio -------------------------------------------------------------------------------------

local radioToken = 0

local function scramble(text: string): string
	local noise = { "#", "/", "~", "=", "-", " " }
	local out = {}
	for i = 1, math.min(#text, 48) do
		out[i] = if math.random() < 0.7 then noise[math.random(1, #noise)] else text:sub(i, i)
	end
	return table.concat(out)
end

local function radio(from: string?, text: string, duration: number?)
	radioToken += 1
	local token = radioToken
	local commsDown = ReplicatedStorage:GetAttribute("CommsDown") == true
	radioFrom.Text = "◉  " .. (from or "RADIO")
	radioFrom.TextColor3 = if commsDown then C.TextDim else C.Dispatch
	radioFrame.Visible = true
	-- Skrivmaskinseffekt: radion "tar emot" texten
	local message = if commsDown then scramble(text) else text
	task.spawn(function()
		for i = 1, #message, 2 do
			if token ~= radioToken then
				return
			end
			radioText.Text = message:sub(1, i)
			task.wait(0.012)
		end
		radioText.Text = message
	end)
	task.delay(duration or 6, function()
		if token == radioToken then
			radioFrame.Visible = false
		end
	end)
end

-- Incidentbanderoll ------------------------------------------------------------------------

local bannerToken = 0
function NotificationController.banner(title: string, subtitle: string?, color: Color3?, seconds: number?)
	bannerToken += 1
	local token = bannerToken
	bannerTitle.Text = title
	bannerTitle.TextColor3 = color or C.Text
	bannerSub.Text = subtitle or ""
	banner.Visible = true
	banner.Position = UDim2.new(0.5, 0, 0.3, 12)
	bannerTitle.TextTransparency = 1
	bannerSub.TextTransparency = 1
	local info = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(banner, info, { Position = UDim2.fromScale(0.5, 0.3) }):Play()
	TweenService:Create(bannerTitle, info, { TextTransparency = 0 }):Play()
	TweenService:Create(bannerSub, info, { TextTransparency = 0.15 }):Play()
	task.delay(seconds or 3.5, function()
		if token ~= bannerToken then
			return
		end
		local out = TweenInfo.new(0.6)
		TweenService:Create(bannerTitle, out, { TextTransparency = 1 }):Play()
		TweenService:Create(bannerSub, out, { TextTransparency = 1 }):Play()
		task.wait(0.65)
		if token == bannerToken then
			banner.Visible = false
		end
	end)
end

-- Publikt: andra controllers kan visa lokala meddelanden (tips, fel).
function NotificationController.show(kind: string, title: string?, text: string, duration: number?)
	if kind == "radio" then
		radio(title, text, duration)
	else
		toast(kind, title, text, duration)
	end
	local sound = KIND_SOUNDS[kind]
	if sound and app.audio then
		app.audio.play(sound)
	end
end

local function onWorldEvent(event)
	if event.type == "IncidentStart" then
		local color = RARITY_COLORS[event.rarity] or C.Text
		local subtitle = if event.rarity == "Legendary" then "SOMETHING IS WRONG WITH THE CITY" else nil
		if event.data and event.data.multiplier then
			subtitle = string.format("ALL PAY x%.1f", event.data.multiplier)
		elseif event.data and event.data.label then
			subtitle = string.upper(event.data.label)
		end
		local seconds = if event.rarity == "Legendary" then 6 else 3.5
		NotificationController.banner(string.upper(event.name), subtitle, color, seconds)
		if event.rarity == "Legendary" or event.rarity == "Major" then
			app.hud.cinematic(seconds)
		end
	end
end

function NotificationController.start(appRef)
	app = appRef
	local layer = Ui.new("Frame", {
		Name = "Notifications",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 5,
		Parent = app.root,
	})

	toastList = Ui.new("Frame", {
		Name = "Toasts",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 80),
		Size = UDim2.fromOffset(360, 300),
		Parent = layer,
	}, { Ui.list(Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Center) })

	radioFrame = Widgets.panel({
		Name = "Radio",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -12),
		Size = UDim2.fromOffset(420, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		Parent = layer,
	}, { Ui.padding(10), Ui.list(Enum.FillDirection.Vertical, 2) })
	radioFrom = Widgets.label({
		Font = Theme.Fonts.Display,
		TextSize = 12,
		TextColor3 = C.Dispatch,
		Size = UDim2.new(1, 0, 0, 14),
		LayoutOrder = 1,
		Parent = radioFrame,
	})
	radioText = Widgets.label({
		Font = Theme.Fonts.Digital,
		TextSize = 15,
		TextWrapped = true,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = radioFrame,
	})

	banner = Ui.new("Frame", {
		Name = "Banner",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromOffset(900, 110),
		Visible = false,
		Parent = layer,
	})
	bannerTitle = Widgets.label({
		Font = Theme.Fonts.Display,
		TextSize = 54,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 64),
		TextStrokeTransparency = 0.6,
		Parent = banner,
	})
	bannerSub = Widgets.label({
		Font = Theme.Fonts.Bold,
		TextSize = 18,
		TextColor3 = C.Text,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 66),
		Size = UDim2.new(1, 0, 0, 24),
		Parent = banner,
	})

	app.remotes.Notify.OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" or type(payload.text) ~= "string" then
			return
		end
		NotificationController.show(payload.kind or "info", payload.title, payload.text, payload.duration)
	end)
	app.worldEvents:Connect(onWorldEvent)
	app.notify = NotificationController.show
end

return NotificationController
