-- OnboardingController: lär nya spelare spelet genom att spela, inte genom textväggar.
-- En liten tipsrad i taget, och bara tills spelaren gjort det en gång:
--   1. Öppna DISPATCH och ta ett jobb
--   2. Hitta platsen och håll in prompten
--   3. Ta tillbaka det till depån och säkra lönen
-- Efter första säkrade lönen visas inga fler tips.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Theme = require(script.Parent.Parent.UI.Theme)
local Ui = require(script.Parent.Parent.UI.Ui)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local OnboardingController = {}

local C = Theme.Colors
local Hints = GameConfig.Onboarding
local app
local pill: Frame
local pillText: TextLabel
local stage = "Off" -- Off, Dispatch, Site, Secure, Done
local hadUnsecured = false

local function show(text: string?)
	if not text then
		pill.Visible = false
		return
	end
	pillText.Text = text
	pill.Visible = true
end

local function evaluate()
	local profile = app.state.get("profile")
	if not profile then
		return
	end
	if stage == "Off" then
		-- Bara för den som aldrig säkrat något.
		if profile.stats.contracts > 0 or profile.stats.extractions > 0 then
			stage = "Done"
		else
			stage = "Dispatch"
		end
	end
	local contract = app.state.get("contract")
	local economy = app.state.get("economy")
	local unsecured = economy and (economy.pendingValue + economy.carriedValue) or 0
	if unsecured > 0 then
		hadUnsecured = true
	end

	if stage == "Dispatch" and contract and contract.active then
		stage = "Site"
	end
	if stage == "Site" and (not contract or not contract.active or contract.step.index > 1) and unsecured > 0 then
		stage = "Secure"
	end
	if stage == "Secure" and hadUnsecured and unsecured == 0 then
		stage = "Done"
		app.notify(
			"good",
			"YOU'RE ON THE ROSTER",
			"That's the job. Take bigger risks for bigger pay, and be back before 03:00.",
			7
		)
	end

	if stage == "Dispatch" then
		show(Hints.FirstContractHint)
	elseif stage == "Site" then
		show(Hints.FirstSiteHint)
	elseif stage == "Secure" then
		show(Hints.FirstSecureHint)
	else
		show(nil)
	end
end

function OnboardingController.step(_name: string)
	task.defer(evaluate)
end

function OnboardingController.start(appRef)
	app = appRef
	app.onboarding = OnboardingController
	pill = Widgets.panel({
		Name = "Hint",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 78),
		Size = UDim2.fromOffset(0, 34),
		AutomaticSize = Enum.AutomaticSize.X,
		Visible = false,
		Parent = app.hudLayer,
	}, { Ui.new("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }) })
	local stroke = pill:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = C.Dispatch
		stroke.Transparency = 0.1
		-- Långsam puls så att ögat dras dit
		TweenService:Create(
			stroke,
			TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Transparency = 0.7 }
		):Play()
	end
	pillText = Widgets.label({
		Font = Theme.Fonts.Bold,
		TextSize = 14,
		TextColor3 = C.Text,
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		Parent = pill,
	})
	for _, section in { "profile", "contract", "economy" } do
		app.state.watch(section, function()
			evaluate()
		end)
	end
end

return OnboardingController
