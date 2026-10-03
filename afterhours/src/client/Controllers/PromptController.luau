-- PromptController: vilka ProximityPrompts spelaren ser, och vad som händer lokalt när man
-- använder dem.
--   * Kontraktsplatser: bara prompten för ens eget kontrakts nuvarande steg syns.
--   * Dispatch-disken öppnar DISPATCH, förrådsskåpet öppnar LOCKER, knappsatsen öppnar sifferpanelen.
-- Själva handlingen (jobba, plocka upp, säkra ...) avgörs alltid på servern.

local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)

local PromptController = {}

local Actions = Constants.Actions
local app
local currentSite: string? = nil

local function applyContractPrompt(prompt: Instance)
	if not prompt:IsA("ProximityPrompt") then
		return
	end
	prompt.Enabled = currentSite ~= nil and prompt:GetAttribute("Target") == currentSite
end

local function refresh()
	local contract = app.state.get("contract")
	currentSite = if contract and contract.active then contract.siteId else nil
	for _, prompt in CollectionService:GetTagged(Constants.Tags.ContractPrompt) do
		applyContractPrompt(prompt)
	end
end

function PromptController.start(appRef)
	app = appRef
	CollectionService:GetInstanceAddedSignal(Constants.Tags.ContractPrompt):Connect(applyContractPrompt)
	app.state.watch("contract", refresh)
	refresh()

	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local action = prompt:GetAttribute("Action")
		if action == Actions.Dispatch then
			app.dispatch.open("CONTRACTS")
		elseif action == Actions.Locker then
			app.dispatch.open("LOCKER")
		elseif action == Actions.Keypad then
			app.dialogs.keypad()
		end
	end)
end

return PromptController
