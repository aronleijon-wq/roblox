-- InputController: kontroller för dator, mobil och handkontroll.
--
--   Handling        Dator          Handkontroll    Mobil
--   Springa         Shift (håll)   L3              SPRINT-knapp (växlar)
--   Ficklampa       F              Y               LIGHT-knapp
--   DISPATCH        Tab            View/Back       DISPATCH-knapp (alltid synlig)
--   Skanner         Q              DPad upp        SCAN-knapp
--   Pinga för laget Mittenknapp/Z  DPad höger      PING-knapp
--   Välj fack       1-9            L1 / R1         tryck på facket
--   Släpp föremål   G              DPad ned        SLÄPP-knappen
--
-- Mobilknapparna placeras ovanför Roblox hoppknapp (vi läser dess position) så att de
-- aldrig täcker den, och storleken följer hoppknappen.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Theme = require(script.Parent.Parent.UI.Theme)
local Ui = require(script.Parent.Parent.UI.Ui)

local InputController = {}

local C = Theme.Colors
local P = GameConfig.Player
local app
local player = Players.LocalPlayer

local wantSprint = false
local stamina = P.StaminaSeconds
local exhausted = false
local flashlightOn = true
local staminaBar: Frame
local staminaFill: Frame
local mobileGui: ScreenGui?
local sprintButton: TextButton?

-- Springa och uthållighet ------------------------------------------------------------------

local function humanoid(): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function setSprint(on: boolean)
	wantSprint = on
	if sprintButton then
		sprintButton.BackgroundColor3 = if on then C.Dispatch else C.Panel
		sprintButton.TextColor3 = if on then Color3.new(0, 0, 0) else C.Text
	end
end

local function updateMovement(dt: number)
	local h = humanoid()
	if not h or h.Health <= 0 then
		return
	end
	local moving = h.MoveDirection.Magnitude > 0.1
	local sprinting = wantSprint and moving and not exhausted and not app.dispatch.isOpen()
	if sprinting then
		stamina = math.max(0, stamina - dt)
		if stamina <= 0 then
			exhausted = true
		end
	else
		stamina = math.min(P.StaminaSeconds, stamina + P.StaminaRegenPerSecond * dt)
		if exhausted and stamina >= P.StaminaSeconds * 0.35 then
			exhausted = false
		end
	end
	local target = if sprinting then P.SprintSpeed else P.WalkSpeed
	if player:GetAttribute("Downed") then
		target = P.WalkSpeed * 0.5
	end
	if h.WalkSpeed ~= target then
		h.WalkSpeed = target
	end
	-- Mätaren syns bara när den inte är full.
	local fraction = stamina / P.StaminaSeconds
	staminaBar.Visible = fraction < 0.999
	staminaFill.Size = UDim2.fromScale(fraction, 1)
	staminaFill.BackgroundColor3 = if exhausted then C.Danger else C.Text
end

-- Handlingar ---------------------------------------------------------------------------------

local function toggleFlashlight()
	flashlightOn = not flashlightOn
	app.remotes.ToggleFlashlight:FireServer(flashlightOn)
end

local function toggleDispatch()
	app.dispatch.toggle()
end

local function cycleSlot(direction: number)
	local inventory = app.state.get("inventory")
	if not inventory or #inventory.items == 0 then
		return
	end
	local slots = {}
	for _, item in inventory.items do
		table.insert(slots, item.slot)
	end
	table.sort(slots)
	local current = app.inventory.selected()
	local index = table.find(slots, current or -1) or 0
	index = ((index - 1 + direction) % #slots) + 1
	app.inventory.select(slots[index])
end

-- Nycklade på namn (jämförs som text, inte som EnumItem-objekt).
local KEY_SLOTS = {
	One = 1,
	Two = 2,
	Three = 3,
	Four = 4,
	Five = 5,
	Six = 6,
	Seven = 7,
	Eight = 8,
	Nine = 9,
}

local function bind(name: string, fn: () -> (), ...: Enum.KeyCode | Enum.UserInputType)
	ContextActionService:BindAction(name, function(_, state)
		if state == Enum.UserInputState.Begin then
			fn()
		end
		return Enum.ContextActionResult.Pass
	end, false, ...)
end

-- Mobilknappar ------------------------------------------------------------------------------

local function mobileButton(text: string, order: number, size: number, onClick: () -> ()): TextButton
	local button = Ui.new("TextButton", {
		Name = text,
		AutoButtonColor = true,
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(size, size),
		Font = Theme.Fonts.Display,
		Text = text,
		TextSize = math.max(10, math.floor(size * 0.2)),
		TextColor3 = C.Text,
		LayoutOrder = order,
		Parent = (mobileGui :: ScreenGui):FindFirstChild("Column"),
	}, { Ui.corner(math.floor(size / 2)), Ui.stroke(C.Line, 1.5, 0.2) })
	button.Activated:Connect(onClick)
	return button
end

local function placeMobileButtons()
	if not mobileGui then
		return
	end
	local column = mobileGui:FindFirstChild("Column") :: Frame
	local touchGui = player.PlayerGui:FindFirstChild("TouchGui") :: ScreenGui?
	if touchGui then
		-- Samma koordinatsystem som Roblox pekkontroller
		mobileGui.ScreenInsets = touchGui.ScreenInsets
	end
	local jump = touchGui and touchGui:FindFirstChild("JumpButton", true) :: GuiObject?
	local viewport = Workspace.CurrentCamera.ViewportSize
	if jump and jump.AbsoluteSize.X > 0 then
		local size = math.floor(jump.AbsoluteSize.X * 0.72)
		local center = jump.AbsolutePosition.X + jump.AbsoluteSize.X / 2
		column.Position = UDim2.fromOffset(center, jump.AbsolutePosition.Y - 10)
		for _, child in column:GetChildren() do
			if child:IsA("TextButton") then
				child.Size = UDim2.fromOffset(size, size)
				child.TextSize = math.max(10, math.floor(size * 0.2))
				local corner = child:FindFirstChildOfClass("UICorner")
				if corner then
					corner.CornerRadius = UDim.new(0, math.floor(size / 2))
				end
			end
		end
	else
		column.Position = UDim2.fromOffset(viewport.X - 70, viewport.Y - 170)
	end
end

local function buildMobile()
	mobileGui = Ui.new("ScreenGui", {
		Name = "AfterhoursTouch",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 2,
		Parent = player.PlayerGui,
	})
	Ui.new("Frame", {
		Name = "Column",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(80, 260),
		Parent = mobileGui,
	}, {
		Ui.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	mobileButton("PING", 1, 56, function()
		app.markers.pingAtCrosshair()
	end)
	mobileButton("SCAN", 2, 56, function()
		app.markers.scan()
	end)
	mobileButton("LIGHT", 3, 56, toggleFlashlight)
	sprintButton = mobileButton("SPRINT", 4, 56, function()
		setSprint(not wantSprint)
	end)
	placeMobileButtons()
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		task.defer(placeMobileButtons)
	end)
	-- Hoppknappen skapas av Roblox lite senare; placera om när den dyker upp.
	player.PlayerGui.DescendantAdded:Connect(function(descendant)
		if descendant.Name == "JumpButton" then
			task.delay(0.2, placeMobileButtons)
		end
	end)
	-- Dolda när spelaren använder tangentbord, mus eller handkontroll (t.ex. en surfplatta med tangentbord).
	local gui = mobileGui :: ScreenGui
	local function refreshVisibility()
		local last = UserInputService:GetLastInputType()
		local other = last == Enum.UserInputType.Keyboard
			or last.Name:find("Mouse") ~= nil
			or last.Name:find("Gamepad") ~= nil
		gui.Enabled = UserInputService.TouchEnabled and not other
	end
	UserInputService.LastInputTypeChanged:Connect(refreshVisibility)
	refreshVisibility()
end

function InputController.start(appRef)
	app = appRef

	-- Uthållighetsmätare: en tunn linje ovanför inventariet.
	staminaBar = Ui.new("Frame", {
		Name = "Stamina",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -70),
		Size = UDim2.fromOffset(180, 4),
		BackgroundColor3 = C.PanelLight,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		Visible = false,
		Parent = app.hudLayer,
	}, { Ui.corner(2) })
	staminaFill = Ui.new("Frame", {
		BackgroundColor3 = C.Text,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = staminaBar,
	}, { Ui.corner(2) })

	-- DISPATCH-knappen syns för alla (enklast att hitta, och det enda sättet på mobil).
	local dispatchButton = Ui.new("TextButton", {
		Name = "DispatchButton",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.fromOffset(132, 44),
		BackgroundColor3 = C.Dispatch,
		BorderSizePixel = 0,
		Font = Theme.Fonts.Display,
		Text = "DISPATCH",
		TextSize = 15,
		TextColor3 = Color3.new(0, 0, 0),
		Parent = app.hudLayer,
	}, { Ui.corner(8) })
	dispatchButton.Activated:Connect(toggleDispatch)
	app.dispatchButton = dispatchButton
	local hint = Ui.new("TextLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 58),
		Size = UDim2.fromOffset(132, 14),
		Font = Theme.Fonts.Bold,
		TextSize = 11,
		TextColor3 = C.TextDim,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "TAB",
		Parent = app.hudLayer,
	})
	local function refreshHint()
		local last = UserInputService:GetLastInputType()
		if last == Enum.UserInputType.Touch then
			hint.Text = ""
		elseif last.Name:find("Gamepad") then
			hint.Text = "VIEW BUTTON"
		else
			hint.Text = "TAB"
		end
	end
	UserInputService.LastInputTypeChanged:Connect(refreshHint)
	refreshHint()

	-- Tangentbord och handkontroll
	ContextActionService:BindAction("AH_Sprint", function(_, state)
		if state == Enum.UserInputState.Begin then
			setSprint(true)
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			setSprint(false)
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift)
	bind("AH_SprintPad", function()
		setSprint(not wantSprint)
	end, Enum.KeyCode.ButtonL3)
	bind("AH_Flashlight", toggleFlashlight, Enum.KeyCode.F, Enum.KeyCode.ButtonY)
	bind("AH_Dispatch", toggleDispatch, Enum.KeyCode.Tab, Enum.KeyCode.ButtonSelect)
	bind("AH_Scan", function()
		app.markers.scan()
	end, Enum.KeyCode.Q, Enum.KeyCode.DPadUp)
	bind("AH_Ping", function()
		app.markers.pingAtCrosshair()
	end, Enum.UserInputType.MouseButton3, Enum.KeyCode.Z, Enum.KeyCode.DPadRight)
	bind("AH_Drop", function()
		app.inventory.dropSelected()
	end, Enum.KeyCode.G, Enum.KeyCode.DPadDown)
	bind("AH_PrevSlot", function()
		cycleSlot(-1)
	end, Enum.KeyCode.ButtonL1)
	bind("AH_NextSlot", function()
		cycleSlot(1)
	end, Enum.KeyCode.ButtonR1)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or UserInputService:GetFocusedTextBox() then
			return
		end
		local slot = KEY_SLOTS[input.KeyCode.Name]
		if slot then
			app.inventory.select(slot)
		end
	end)
	-- Escape/B stänger DISPATCH
	UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.ButtonB and app.dispatch.isOpen() then
			app.dispatch.close()
		end
	end)

	if UserInputService.TouchEnabled then
		buildMobile()
	end

	player.CharacterAdded:Connect(function()
		stamina = P.StaminaSeconds
		exhausted = false
		flashlightOn = true
		setSprint(false)
	end)
	RunService.Heartbeat:Connect(updateMovement)
end

return InputController
