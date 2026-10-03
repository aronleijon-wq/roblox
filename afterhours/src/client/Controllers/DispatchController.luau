-- DispatchController: DISPATCH-panelen. Öppnas med TAB, med knappen DISPATCH (mobil/handkontroll)
-- eller vid disken på depån. Fyra flikar:
--   CONTRACTS - jobberbjudanden (Safe / Normal / High Risk), aktivt kontrakt, nya erbjudanden
--   SQUAD     - laget: bjud in spelare eller vänner, lämna laget
--   LOCKER    - förrådsskåpet: utökningar och utseende (köps på depån)
--   PROFILE   - nivå, rykte, statistik, titlar och upptäckter
-- Klienten visar bara och ber om saker; servern bestämmer allt.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local Format = require(ReplicatedStorage.Shared.Util.Format)
local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)
local ProgressionConfig = require(ReplicatedStorage.Shared.Config.ProgressionConfig)
local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)
local Theme = require(script.Parent.Parent.UI.Theme)
local Ui = require(script.Parent.Parent.UI.Ui)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local DispatchController = {}

local C = Theme.Colors
local TABS = { "CONTRACTS", "SQUAD", "LOCKER", "PROFILE" }
local TIER_COLORS = { Safe = C.Good, Normal = C.Warning, HighRisk = C.Danger }

local app
local window: Frame
local content: ScrollingFrame
local tabButtons: { [string]: TextButton } = {}
local currentTab = "CONTRACTS"
local isOpen = false

local function header(text: string, order: number, color: Color3?)
	return Widgets.label({
		Text = text,
		Font = Theme.Fonts.Display,
		TextSize = 13,
		TextColor3 = color or C.TextDim,
		Size = UDim2.new(1, 0, 0, 22),
		LayoutOrder = order,
		Parent = content,
	})
end

local function note(text: string, order: number, color: Color3?)
	return Widgets.label({
		Text = text,
		Font = Theme.Fonts.Body,
		TextSize = 13,
		TextColor3 = color or C.TextDim,
		TextWrapped = true,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
		Parent = content,
	})
end

-- Ett kort med text till vänster och en knapp till höger.
local function card(order: number, accent: Color3?): (Frame, Frame)
	local frame = Ui.new("Frame", {
		BackgroundColor3 = C.PanelLight,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
		Parent = content,
	}, { Ui.corner(8), Ui.padding(10) })
	if accent then
		Ui.stroke(accent, 1, 0.5).Parent = frame
	end
	local text = Ui.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -140, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = frame,
	}, { Ui.list(Enum.FillDirection.Vertical, 3) })
	return frame, text
end

local function cardLine(parent: Instance, text: string, order: number, props)
	local defaults = {
		Text = text,
		Font = Theme.Fonts.Body,
		TextSize = 13,
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

local function cardButton(frame: Frame, text: string, style: string?, onClick: () -> ()): TextButton
	return Widgets.button({
		Text = text,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(124, 44),
		Parent = frame,
	}, onClick, style)
end

-- CONTRACTS ---------------------------------------------------------------------------------

local function renderContracts()
	local contract = app.state.get("contract")
	if contract and contract.active then
		header("ACTIVE CONTRACT", 1, C.Dispatch)
		local frame, text = card(2, TIER_COLORS[contract.tier])
		cardLine(
			text,
			contract.tierLabel,
			1,
			{ Font = Theme.Fonts.Display, TextSize = 11, TextColor3 = TIER_COLORS[contract.tier] }
		)
		cardLine(text, contract.title, 2, { Font = Theme.Fonts.Display, TextSize = 16, TextColor3 = C.Text })
		cardLine(text, string.format("Step %d/%d: %s", contract.step.index, contract.step.total, contract.step.text), 3)
		cardLine(text, "Pays about " .. Format.credits(contract.reward) .. " cr", 4, { TextColor3 = C.Credits })
		cardButton(frame, "ABANDON", "danger", function()
			app.remotes.AbandonContract:FireServer()
		end)
		note("Abandoning gives up the job and any contract items you carry.", 3)
		return
	end

	local offers = app.state.get("offers")
	header("TONIGHT'S JOBS", 1, C.Dispatch)
	if not offers or #offers.list == 0 then
		note("Dispatch has nothing for you right now. Check back in a moment.", 2)
		return
	end
	for index, offer in offers.list do
		local color = TIER_COLORS[offer.tier] or C.Text
		local frame, text = card(1 + index, color)
		cardLine(
			text,
			offer.tierLabel .. "  ·  " .. offer.riskLabel,
			1,
			{ Font = Theme.Fonts.Display, TextSize = 11, TextColor3 = color }
		)
		cardLine(text, offer.title, 2, { Font = Theme.Fonts.Display, TextSize = 16, TextColor3 = C.Text })
		cardLine(text, offer.brief, 3, { TextColor3 = C.TextDim })
		cardLine(
			text,
			"◆ " .. offer.siteLabel .. "     ≈ " .. Format.credits(offer.reward) .. " cr",
			4,
			{ Font = Theme.Fonts.Bold, TextColor3 = C.Credits }
		)
		if offer.locked then
			local button = cardButton(frame, "LOCKED", "ghost", function() end)
			Widgets.setEnabled(button, false)
			cardLine(text, offer.lockReason or "Requires a license.", 5, { TextColor3 = C.Danger, TextSize = 12 })
		else
			cardButton(frame, "ACCEPT", "primary", function()
				app.remotes.AcceptContract:FireServer(offer.offerId)
				if app.onboarding then
					app.onboarding.step("Accepted")
				end
				DispatchController.close()
			end)
		end
	end
	local reroll = Widgets.button({
		Text = if offers.rerollCooldown > 0
			then "NEW OFFERS IN " .. math.ceil(offers.rerollCooldown) .. "s"
			else "ASK FOR NEW OFFERS",
		Size = UDim2.new(1, 0, 0, 40),
		LayoutOrder = 10,
		Parent = content,
	}, function()
		app.remotes.RerollContracts:FireServer()
	end, "ghost")
	Widgets.setEnabled(reroll, offers.rerollCooldown <= 0)
	note("Higher risk pays more. It also raises your HEAT, and HEAT invites trouble.", 11)
end

-- SQUAD -------------------------------------------------------------------------------------

local function renderSquad()
	local squad = app.state.get("squad")
	local inSquad = {}
	if squad and squad.id then
		header("YOUR SQUAD", 1, C.Dispatch)
		for index, member in squad.members do
			inSquad[member.userId] = true
			local _, text = card(1 + index)
			cardLine(text, member.name, 1, { Font = Theme.Fonts.Display, TextSize = 15, TextColor3 = C.Text })
			cardLine(
				text,
				string.format("%s  ·  HEAT %d  ·  carrying %d", member.status:upper(), member.heat, member.carrying),
				2
			)
		end
		Widgets.button(
			{ Text = "LEAVE SQUAD", Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 8, Parent = content },
			function()
				app.remotes.SquadRequest:FireServer("leave")
			end,
			"danger"
		)
	else
		header("NO SQUAD", 1)
		note("Squads share a bonus when they extract together, see each other's status and can ping places.", 2)
	end

	header("ON THIS SERVER", 20)
	local count = 0
	for _, player in Players:GetPlayers() do
		if player ~= Players.LocalPlayer and not inSquad[player.UserId] then
			count += 1
			local frame, text = card(20 + count)
			cardLine(text, player.DisplayName, 1, { Font = Theme.Fonts.Bold, TextSize = 14, TextColor3 = C.Text })
			local title = player:GetAttribute("Title")
			local def = type(title) == "string" and ProgressionConfig.Titles[title]
			if def then
				cardLine(text, def.text, 2, { TextSize = 11, TextColor3 = def.color })
			end
			cardButton(frame, "INVITE", "primary", function()
				app.remotes.SquadRequest:FireServer("invite", player.UserId)
			end)
		end
	end
	if count == 0 then
		note("Nobody else here yet.", 21)
	end
	Widgets.button(
		{ Text = "INVITE FRIENDS", Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 60, Parent = content },
		function()
			local options = Instance.new("ExperienceInviteOptions")
			options.PromptMessage = "Work the night shift with me."
			pcall(SocialService.PromptGameInvite, SocialService, Players.LocalPlayer, options)
		end,
		"ghost"
	)
end

-- LOCKER ------------------------------------------------------------------------------------

local function ownsCosmetic(profile, kind: string, id: string, def): boolean
	local key = if kind == "Flashlight" then "flashlight" else "vest"
	if profile.cosmetics[key] and profile.cosmetics[key][id] then
		return true
	end
	if def.price == 0 then
		return true
	end
	return def.requiresTitle ~= nil and profile.titles[def.requiresTitle] == true
end

local function hasLicense(profile, license: string): boolean
	for _, level in ProgressionConfig.Levels do
		if level.level <= profile.level then
			for _, unlock in level.unlocks do
				if unlock == license then
					return true
				end
			end
		end
	end
	return false
end

local function cosmeticRow(order: number, profile, kind: string, id: string, def)
	local key = if kind == "Flashlight" then "flashlight" else "vest"
	local owned = ownsCosmetic(profile, kind, id, def)
	local equipped = profile.equipped[key] == id
	local frame, text = card(order)
	Ui.new("Frame", {
		BackgroundColor3 = def.color,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(14, 14),
		LayoutOrder = 0,
		Parent = text,
	}, { Ui.corner(7) })
	cardLine(text, def.name, 1, { Font = Theme.Fonts.Bold, TextSize = 14, TextColor3 = C.Text })
	if equipped then
		local button = cardButton(frame, "EQUIPPED", "good", function() end)
		Widgets.setEnabled(button, false)
		button.TextTransparency = 0
	elseif owned then
		cardButton(frame, "EQUIP", "primary", function()
			app.remotes.Equip:FireServer(kind, id)
		end)
	elseif def.requiresTitle then
		local title = ProgressionConfig.Titles[def.requiresTitle]
		cardLine(text, "Reward for the title " .. (if title and not title.hidden then title.text else "???"), 2)
		local button = cardButton(frame, "LOCKED", "ghost", function() end)
		Widgets.setEnabled(button, false)
	else
		cardButton(frame, Format.credits(def.price) .. " cr", "ghost", function()
			app.remotes.ShopPurchase:FireServer(kind, id)
		end)
	end
end

local function sortedByPrice(list)
	local ids = {}
	for id in list do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		local pa = list[a].price or math.huge
		local pb = list[b].price or math.huge
		if pa == pb then
			return a < b
		end
		return pa < pb
	end)
	return ids
end

local function renderLocker()
	local profile = app.state.get("profile")
	if not profile then
		note("Loading your locker...", 1)
		return
	end
	header("SUPPLY LOCKER  ·  " .. Format.credits(profile.credits) .. " cr", 1, C.Credits)
	note("Everything here is bought with credits you earned on shift. Purchases happen at the depot.", 2)

	header("UPGRADES", 10)
	local order = 10
	for _, id in sortedByPrice(ShopConfig.Items) do
		local def = ShopConfig.Items[id]
		order += 1
		local frame, text = card(order)
		cardLine(text, def.name, 1, { Font = Theme.Fonts.Bold, TextSize = 14, TextColor3 = C.Text })
		cardLine(text, def.description, 2)
		if profile.purchases[id] then
			local button = cardButton(frame, "OWNED", "good", function() end)
			Widgets.setEnabled(button, false)
			button.TextTransparency = 0
		elseif def.requiresLicense and not hasLicense(profile, def.requiresLicense) then
			local needed
			for _, level in ProgressionConfig.Levels do
				if table.find(level.unlocks, def.requiresLicense) then
					needed = level
				end
			end
			cardLine(
				text,
				if needed then "Requires level " .. needed.level .. " (" .. needed.name .. ")" else "Locked",
				3,
				{ TextColor3 = C.Danger }
			)
			local button = cardButton(frame, Format.credits(def.price) .. " cr", "ghost", function() end)
			Widgets.setEnabled(button, false)
		else
			cardButton(frame, Format.credits(def.price) .. " cr", "ghost", function()
				app.remotes.ShopPurchase:FireServer("Upgrade", id)
			end)
		end
	end

	header("FLASHLIGHT", 30)
	order = 30
	for _, id in sortedByPrice(ShopConfig.Flashlights) do
		order += 1
		cosmeticRow(order, profile, "Flashlight", id, ShopConfig.Flashlights[id])
	end
	header("WORK VEST", 50)
	order = 50
	for _, id in sortedByPrice(ShopConfig.Vests) do
		order += 1
		cosmeticRow(order, profile, "Vest", id, ShopConfig.Vests[id])
	end
end

-- PROFILE -----------------------------------------------------------------------------------

local function renderProfile()
	local profile = app.state.get("profile")
	if not profile then
		note("Loading your profile...", 1)
		return
	end
	header("LEVEL " .. profile.level .. "  ·  " .. profile.levelName, 1, C.Dispatch)
	local progress = Ui.new("Frame", {
		BackgroundColor3 = C.PanelLight,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 10),
		LayoutOrder = 2,
		Parent = content,
	}, { Ui.corner(5) })
	local fraction = 1
	if profile.nextLevelAt then
		fraction = (profile.reputation - profile.levelFloor) / math.max(1, profile.nextLevelAt - profile.levelFloor)
	end
	Ui.new("Frame", {
		BackgroundColor3 = C.Dispatch,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1),
		Parent = progress,
	}, { Ui.corner(5) })
	note(
		if profile.nextLevelAt
			then string.format(
				"Reputation %s / %s",
				Format.credits(profile.reputation),
				Format.credits(profile.nextLevelAt)
			)
			else "Reputation " .. Format.credits(profile.reputation) .. "  ·  max level",
		3
	)
	if profile.temporary then
		note("Your progress could not be loaded. Nothing will be saved this session.", 4, C.Danger)
	end

	local s = profile.stats
	header("RECORD", 10)
	note(
		string.format(
			"Shifts %d   ·   Made it home %d   ·   Didn't %d\nContracts %d (high risk %d)   ·   Incidents witnessed %d\nItems secured %d   ·   Best shift %s cr   ·   Total earned %s cr",
			s.shifts,
			s.extractions,
			s.failures,
			s.contracts,
			s.highRiskContracts,
			s.incidentsWitnessed,
			s.itemsSecured,
			Format.credits(s.bestShift),
			Format.credits(s.totalEarned)
		),
		11,
		C.Text
	)

	header("TITLES", 20)
	local order = 20
	local ids = {}
	for id in ProgressionConfig.Titles do
		table.insert(ids, id)
	end
	table.sort(ids)
	for _, id in ids do
		local def = ProgressionConfig.Titles[id]
		local earned = profile.titles[id] == true
		if earned or not def.hidden then
			order += 1
			local frame, text = card(order)
			cardLine(
				text,
				def.text,
				1,
				{ Font = Theme.Fonts.Display, TextSize = 14, TextColor3 = if earned then def.color else C.TextDim }
			)
			if not earned and def.hint then
				cardLine(text, def.hint, 2)
			end
			if earned and profile.equippedTitle ~= id then
				cardButton(frame, "WEAR", "primary", function()
					app.remotes.Equip:FireServer("Title", id)
				end)
			elseif earned then
				local button = cardButton(frame, "WORN", "good", function() end)
				Widgets.setEnabled(button, false)
				button.TextTransparency = 0
			end
		end
	end

	header("DISCOVERIES", 60)
	local found = {}
	for _, id in profile.discovered or {} do
		found[id] = true
	end
	order = 60
	local dIds = {}
	for id in ProgressionConfig.Discoveries do
		table.insert(dIds, id)
	end
	table.sort(dIds)
	local hiddenLeft = 0
	for _, id in dIds do
		local def = ProgressionConfig.Discoveries[id]
		if found[id] then
			order += 1
			note("◆ " .. def.name .. "  ·  " .. def.kind:upper(), order, C.Discovery)
		elseif def.hidden then
			hiddenLeft += 1
		else
			order += 1
			note("◇ ???  ·  " .. def.kind:upper(), order)
		end
	end
	if hiddenLeft > 0 then
		order += 1
		note(hiddenLeft .. " more that nobody talks about.", order)
	end

	header("COLLECTION", 80)
	order = 80
	for _, rarity in ItemConfig.RarityOrder do
		local names = {}
		for itemId, count in profile.collection or {} do
			local def = ItemConfig.get(itemId)
			if def and def.rarity == rarity then
				table.insert(names, def.name .. " x" .. count)
			end
		end
		if #names > 0 then
			table.sort(names)
			order += 1
			note(
				ItemConfig.Rarities[rarity].label .. ":  " .. table.concat(names, ", "),
				order,
				ItemConfig.Rarities[rarity].color
			)
		end
	end
	if order == 80 then
		note("Secure items at the depot to start your collection.", 81)
	end
end

local RENDERERS = {
	CONTRACTS = renderContracts,
	SQUAD = renderSquad,
	LOCKER = renderLocker,
	PROFILE = renderProfile,
}

local function render()
	if not isOpen then
		return
	end
	for name, button in tabButtons do
		button.BackgroundColor3 = if name == currentTab then C.Dispatch else C.PanelLight
		button.TextColor3 = if name == currentTab then Color3.new(0, 0, 0) else C.Text
	end
	local scroll = content.CanvasPosition
	Ui.clear(content)
	RENDERERS[currentTab]()
	content.CanvasPosition = scroll
end

function DispatchController.open(tab: string?)
	if tab and RENDERERS[tab] then
		if tab ~= currentTab then
			content.CanvasPosition = Vector2.zero
		end
		currentTab = tab
	end
	isOpen = true
	window.Visible = true
	render()
	if app.onboarding then
		app.onboarding.step("Opened")
	end
end

function DispatchController.close()
	isOpen = false
	window.Visible = false
	-- Handkontrollens markering ska inte ligga kvar på en dold knapp.
	local selectedObject = GuiService.SelectedObject
	if selectedObject and selectedObject:IsDescendantOf(window) then
		GuiService.SelectedObject = nil
	end
end

function DispatchController.toggle(tab: string?)
	if isOpen and (tab == nil or tab == currentTab) then
		DispatchController.close()
	else
		DispatchController.open(tab)
	end
end

function DispatchController.isOpen(): boolean
	return isOpen
end

function DispatchController.start(appRef)
	app = appRef
	app.dispatch = DispatchController

	window = Widgets.panel({
		Name = "Dispatch",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(660, 470),
		BackgroundTransparency = 0.05,
		Visible = false,
		ZIndex = 10,
		Parent = app.root,
	})
	Widgets.label({
		Text = "DISPATCH",
		Font = Theme.Fonts.Display,
		TextSize = 20,
		TextColor3 = C.Dispatch,
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.fromOffset(200, 28),
		Parent = window,
	})
	Widgets.button({
		Text = "✕",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(44, 36),
		Parent = window,
	}, DispatchController.close, "ghost")

	local tabs = Ui.new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 48),
		Size = UDim2.new(1, -32, 0, 38),
		Parent = window,
	}, { Ui.list(Enum.FillDirection.Horizontal, 6) })
	for index, name in TABS do
		tabButtons[name] = Widgets.button({
			Text = name,
			TextSize = 12,
			Size = UDim2.new(0.25, -5, 1, 0),
			LayoutOrder = index,
			Parent = tabs,
		}, function()
			DispatchController.open(name)
		end, "ghost")
	end

	content = Ui.new("ScrollingFrame", {
		Name = "Content",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(16, 96),
		Size = UDim2.new(1, -32, 1, -108),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = C.Line,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = window,
	}, { Ui.list(Enum.FillDirection.Vertical, 8) })
	-- Lite luft till höger om korten (scrollbaren)
	Ui.new("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), Parent = content })

	for _, section in { "offers", "contract", "squad", "profile" } do
		app.state.watch(section, function()
			render()
		end)
	end
	Players.PlayerAdded:Connect(render)
	Players.PlayerRemoving:Connect(function()
		task.defer(render)
	end)
	-- Nedräkningen för nya erbjudanden
	task.spawn(function()
		while true do
			task.wait(1)
			local offers = app.state.get("offers")
			if isOpen and currentTab == "CONTRACTS" and offers and offers.rerollCooldown > 0 then
				offers.rerollCooldown = math.max(0, offers.rerollCooldown - 1)
				render()
			end
		end
	end)
end

return DispatchController
