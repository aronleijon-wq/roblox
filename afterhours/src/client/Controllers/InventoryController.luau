-- InventoryController: raden med fack längst ned. Varje fack visar föremålets sällsynthet
-- som färg. Tryck/klicka (eller 1-9) för att välja, och SLÄPP (eller G) för att lägga det
-- på marken. Allt man bär är osäkrat tills det lämnas på depån.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Format = require(ReplicatedStorage.Shared.Util.Format)
local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)
local Theme = require(script.Parent.Parent.UI.Theme)
local Ui = require(script.Parent.Parent.UI.Ui)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local InventoryController = {}

local C = Theme.Colors
local SLOT = 52
local app
local bar: Frame
local info: Frame
local infoName: TextLabel
local infoMeta: TextLabel
local infoLore: TextLabel
local dropButton: TextButton
local selected: number? = nil
local lastIds: { [number]: string } = {}

local function initials(name: string): string
	local letters = {}
	for word in name:gmatch("[%w%?]+") do
		table.insert(letters, word:sub(1, 1):upper())
		if #letters == 2 then
			break
		end
	end
	return table.concat(letters)
end

local function itemAt(slot: number)
	local inventory = app.state.get("inventory")
	for _, item in inventory and inventory.items or {} do
		if item.slot == slot then
			return item
		end
	end
	return nil
end

local function updateInfo()
	local item = selected and itemAt(selected)
	if not item then
		info.Visible = false
		return
	end
	local def = ItemConfig.get(item.id)
	local rarity = def and ItemConfig.Rarities[def.rarity]
	info.Visible = true
	infoName.Text = def and def.name or item.id
	infoName.TextColor3 = rarity and rarity.color or C.Text
	local parts = { rarity and rarity.label or "" }
	if item.contract then
		table.insert(parts, "CONTRACT ITEM")
	elseif def and def.value then
		table.insert(parts, Format.credits(def.value) .. " cr when secured")
	end
	infoMeta.Text = table.concat(parts, "  ·  ")
	infoLore.Text = def and def.lore or ""
	infoLore.Visible = infoLore.Text ~= ""
	Widgets.setEnabled(dropButton, not item.contract)
end

local function render(inventory)
	Ui.clear(bar)
	if not inventory then
		return
	end
	local filled = {}
	for _, item in inventory.items do
		filled[item.slot] = item
	end
	if selected and (selected > inventory.capacity or not filled[selected]) then
		selected = nil
	end
	for slot = 1, inventory.capacity do
		local item = filled[slot]
		local def = item and ItemConfig.get(item.id)
		local rarity = def and ItemConfig.Rarities[def.rarity]
		local color = rarity and rarity.color or C.Line
		local button = Ui.new("TextButton", {
			Name = "Slot" .. slot,
			LayoutOrder = slot,
			AutoButtonColor = item ~= nil,
			BackgroundColor3 = if item then C.PanelLight else C.Panel,
			BackgroundTransparency = if item then 0.05 else 0.4,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(SLOT, SLOT),
			Text = "",
			Parent = bar,
		}, {
			Ui.corner(8),
			Ui.stroke(
				if selected == slot then C.Text else color,
				if selected == slot then 2.5 else 1.5,
				if item then 0 else 0.6
			),
		})
		Widgets.label({
			Text = tostring(slot),
			Font = Theme.Fonts.Digital,
			TextSize = 11,
			TextColor3 = C.TextDim,
			Position = UDim2.fromOffset(4, 2),
			Size = UDim2.fromOffset(12, 12),
			Parent = button,
		})
		if item and def then
			Widgets.label({
				Text = if def.rarity == "Unknown" then "?" else initials(def.name),
				Font = Theme.Fonts.Display,
				TextSize = 18,
				TextColor3 = color,
				TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.fromScale(1, 1),
				Parent = button,
			})
			if item.contract then
				Widgets.label({
					Text = "◆",
					TextSize = 11,
					TextColor3 = C.Dispatch,
					TextXAlignment = Enum.TextXAlignment.Right,
					Position = UDim2.new(1, -16, 0, 2),
					Size = UDim2.fromOffset(12, 12),
					Parent = button,
				})
			end
			-- Nyss upplockat: kort glöd
			if lastIds[slot] ~= item.uid then
				local glow = Ui.new("Frame", {
					BackgroundColor3 = color,
					BackgroundTransparency = 0.4,
					BorderSizePixel = 0,
					Size = UDim2.fromScale(1, 1),
					Parent = button,
				}, { Ui.corner(8) })
				TweenService:Create(glow, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
				task.delay(0.85, function()
					glow:Destroy()
				end)
			end
		end
		button.Activated:Connect(function()
			InventoryController.select(slot)
		end)
	end
	lastIds = {}
	for slot, item in filled do
		lastIds[slot] = item.uid
	end
	updateInfo()
end

function InventoryController.select(slot: number?)
	if slot and not itemAt(slot) then
		slot = nil
	end
	selected = if selected == slot then nil else slot
	render(app.state.get("inventory"))
end

function InventoryController.selected(): number?
	return selected
end

function InventoryController.dropSelected()
	local item = selected and itemAt(selected)
	if not item or item.contract then
		return
	end
	app.remotes.DropItem:FireServer(selected)
	selected = nil
	render(app.state.get("inventory"))
end

function InventoryController.start(appRef)
	app = appRef
	app.inventory = InventoryController
	bar = Ui.new("Frame", {
		Name = "Inventory",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.fromOffset(600, SLOT),
		Parent = app.hudLayer,
	}, { Ui.list(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Center) })

	-- Info om valt föremål: text till vänster (lista), SLÄPP-knappen till höger.
	info = Widgets.panel({
		Name = "ItemInfo",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -(SLOT + 18)),
		Size = UDim2.fromOffset(380, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		Parent = app.hudLayer,
	}, { Ui.padding(10) })
	local text = Ui.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -90, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = info,
	}, { Ui.list(Enum.FillDirection.Vertical, 2) })
	infoName = Widgets.label({
		Font = Theme.Fonts.Display,
		TextSize = 15,
		Size = UDim2.new(1, 0, 0, 18),
		LayoutOrder = 1,
		Parent = text,
	})
	infoMeta = Widgets.label({
		Font = Theme.Fonts.Bold,
		TextSize = 11,
		TextColor3 = C.TextDim,
		Size = UDim2.new(1, 0, 0, 14),
		LayoutOrder = 2,
		Parent = text,
	})
	infoLore = Widgets.label({
		Font = Theme.Fonts.Body,
		TextSize = 12,
		TextColor3 = C.TextDim,
		TextWrapped = true,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 3,
		Parent = text,
	})
	dropButton = Widgets.button({
		Text = "DROP",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(80, 40),
		Parent = info,
	}, InventoryController.dropSelected, "ghost")

	app.state.watch("inventory", render)
end

return InventoryController
