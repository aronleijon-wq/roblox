-- ContractLogic: skapar kontraktserbjudanden från mallar och platser. Ren logik, testbar.
-- Varje spelare får ett erbjudande per risknivå (SAFE / NORMAL / HIGH RISK). En risknivå
-- spelaren saknar licens för visas ändå, men låst, så att man ser vad som väntar.

local Rewards = require(script.Parent.Rewards)

local ContractLogic = {}

export type Site = { id: string, siteType: string, label: string }

export type Offer = {
	offerId: string,
	templateId: string,
	tier: string,
	siteId: string,
	siteLabel: string,
	title: string,
	brief: string,
	reward: number,
	riskLabel: string,
	locked: boolean,
	lockReason: string?,
}

-- sitesByType: { [siteType] = { Site } }
-- context: { rng, hasLicense = (license) -> boolean, busySites = { [siteId] = true }, nextId = () -> string }
function ContractLogic.generateOffers(config, sitesByType, context): { Offer }
	local offers = {}
	for _, tierId in config.TierOrder do
		local tier = config.Tiers[tierId]

		-- Mallar i den här nivån som har minst en ledig plats.
		local possible = {}
		for _, template in config.Templates do
			if template.tier == tierId then
				local free = {}
				for _, site in sitesByType[template.siteType] or {} do
					if not context.busySites[site.id] then
						table.insert(free, site)
					end
				end
				if #free > 0 then
					table.insert(possible, { template = template, sites = free })
				end
			end
		end

		local choice = context.rng:weighted(possible, function(entry)
			return entry.template.weight or 1
		end)
		if choice then
			local site = context.rng:pick(choice.sites)
			local template = choice.template
			local unlocked = context.hasLicense(tier.license)
			table.insert(offers, {
				offerId = context.nextId(),
				templateId = template.id,
				tier = tierId,
				siteId = site.id,
				siteLabel = site.label,
				title = template.title,
				brief = (template.brief:gsub("{site}", site.label)),
				reward = Rewards.offerValue(template.baseReward, tier.riskMultiplier),
				riskLabel = tier.riskLabel,
				locked = not unlocked,
				lockReason = if unlocked then nil else "Requires " .. tier.label .. " license",
			})
		end
	end
	return offers
end

function ContractLogic.findTemplate(config, templateId: string)
	for _, template in config.Templates do
		if template.id == templateId then
			return template
		end
	end
	return nil
end

return ContractLogic
