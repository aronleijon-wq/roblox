-- InteractionService: alla ProximityPrompts i spelet går genom en enda lyssnare.
-- Prompten har attributen "Action" (vad) och "Target" (vilket objekt). En hanterare kan
-- registreras för "Action" eller för en enskild "Action:Target". Servern kontrollerar
-- att spelaren lever, är nära och inte spammar, och skickar sedan vidare till rätt system.
-- ProximityPrompts fungerar automatiskt med tangentbord, pekskärm och handkontroll.

local ProximityPromptService = game:GetService("ProximityPromptService")

local InteractionService = {}

local handlers: { [string]: (Player, ProximityPrompt, string?) -> () } = {}
local services

function InteractionService.init(registry)
	services = registry
end

function InteractionService.register(action: string, handler: (Player, ProximityPrompt, string?) -> ())
	handlers[action] = handler
end

local function promptPosition(prompt: ProximityPrompt): Vector3?
	local parent = prompt.Parent
	if parent and parent:IsA("BasePart") then
		return parent.CFrame.Position
	elseif parent and parent:IsA("Attachment") then
		return parent.WorldPosition
	end
	return nil
end

function InteractionService.start()
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, player: Player)
		local action = prompt:GetAttribute("Action")
		local target = prompt:GetAttribute("Target")
		if type(action) ~= "string" then
			return
		end
		local handler = (type(target) == "string" and handlers[action .. ":" .. target]) or handlers[action]
		if not handler then
			return
		end
		if not services.Data.isLoaded(player) or not services.Security.allow(player, "Interact") then
			return
		end
		local position = promptPosition(prompt)
		if not position or not services.Security.near(player, position, prompt.MaxActivationDistance) then
			return
		end
		local ok, err = pcall(handler, player, prompt, if type(target) == "string" then target else nil)
		if not ok then
			warn(`[Interaction] fel i {action}:`, err)
		end
	end)
end

return InteractionService
