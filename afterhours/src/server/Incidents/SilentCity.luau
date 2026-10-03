-- SILENT CITY: ingen radio, inga stadsljud, inga NPC:er som rör sig. Något är fel.
-- När det tar slut vänder sig alla NPC:er mot närmaste spelare. Sedan går de vidare.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SilentCity = {}

function SilentCity.start(ctx)
	ReplicatedStorage:SetAttribute("Silent", true)
	ctx.services.Npcs.react("Silent")
end

function SilentCity.stop(ctx)
	ReplicatedStorage:SetAttribute("Silent", false)
	ctx.services.Npcs.react("Stare")
	task.delay(6, function()
		ctx.services.Npcs.react("Normal")
	end)
end

return SilentCity
