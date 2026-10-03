-- Tester för den rena spellogiken (ingen Roblox-motor behövs).

local Harness = require("./harness")
local describe, check, equal, near = Harness.describe, Harness.check, Harness.equal, Harness.near

return function(h)
	local GameConfig = h.module("Shared.Config.GameConfig")
	local ItemConfig = h.module("Shared.Config.ItemConfig")
	local ProgressionConfig = h.module("Shared.Config.ProgressionConfig")
	local Rng = h.module("Shared.Util.Rng")
	local Format = h.module("Shared.Util.Format")
	local ShiftClock = h.module("Shared.Logic.ShiftClock")
	local Rewards = h.module("Server.Logic.Rewards")
	local HeatLogic = h.module("Server.Logic.HeatLogic")
	local InventoryLogic = h.module("Server.Logic.InventoryLogic")
	local DirectorLogic = h.module("Server.Logic.DirectorLogic")
	local ContractLogic = h.module("Server.Logic.ContractLogic")
	local DataSchema = h.module("Server.Logic.DataSchema")
	local RateLimiter = h.module("Server.Logic.RateLimiter")
	local LootLogic = h.module("Server.Logic.LootLogic")
	local StoryCard = h.module("Server.Logic.StoryCard")
	local SecretCode = h.module("Server.Logic.SecretCode")
	local IncidentConfig = h.module("Server.Config.IncidentConfig")
	local ContractConfig = h.module("Server.Config.ContractConfig")
	local LootConfig = h.module("Server.Config.LootConfig")
	local SecretConfig = h.module("Server.Config.SecretConfig")

	describe("Rng", function()
		local a, b = Rng.new(42), Rng.new(42)
		local same = true
		for _ = 1, 100 do
			if a:number() ~= b:number() then
				same = false
			end
		end
		check(same, "samma seed ger samma följd")

		local r = Rng.new(7)
		local inRange = true
		for _ = 1, 2000 do
			local n = r:integer(3, 9)
			if n < 3 or n > 9 or n % 1 ~= 0 then
				inRange = false
			end
		end
		check(inRange, "integer håller sig inom gränserna")

		local counts = { 0, 0, 0 }
		local list = { { w = 1 }, { w = 2 }, { w = 0 }, { w = 7 } }
		local rng = Rng.new(99)
		for _ = 1, 20000 do
			local _, index = rng:weighted(list, function(e)
				return e.w
			end)
			if index == 1 then
				counts[1] += 1
			elseif index == 2 then
				counts[2] += 1
			elseif index == 4 then
				counts[3] += 1
			else
				counts[1] = -math.huge -- vikt 0 får aldrig väljas
			end
		end
		near(counts[1] / 20000, 0.1, 0.01, "vikt 1 av 10 väljs ~10 %")
		near(counts[3] / 20000, 0.7, 0.015, "vikt 7 av 10 väljs ~70 %")
		equal(
			rng:weighted({}, function()
				return 1
			end),
			nil,
			"tom lista ger nil"
		)
	end)

	describe("Format", function()
		equal(Format.credits(5990), "5,990", "tusentalsavgränsare")
		equal(Format.credits(123), "123", "inga avgränsare under 1000")
		equal(Format.credits(1234567), "1,234,567", "miljoner")
		equal(Format.clock(2.5), "02:30", "klocka 2.5 -> 02:30")
		equal(Format.clock(0), "00:00", "midnatt")
		equal(Format.duration(65), "1:05", "varaktighet")
	end)

	describe("ShiftClock", function()
		local s = GameConfig.Shift
		equal(ShiftClock.clock(s.StartClock, s.EndClock, 100, 820, 100), 0, "00:00 när natten börjar")
		near(ShiftClock.clock(s.StartClock, s.EndClock, 100, 820, 700), 2.5, 1e-9, "02:30 efter 10 av 12 minuter")
		equal(ShiftClock.clock(s.StartClock, s.EndClock, 100, 820, 5000), 3, "stannar på 03:00")
		near(ShiftClock.timeAt(s.StartClock, s.EndClock, 100, 820, 2.5), 700, 1e-9, "timeAt är inversen")
	end)

	describe("Rewards", function()
		-- Specens exempel: bas 1000, risk x1.5, upptäckt +500, extraktion +20 % -> 2300
		local economy = table.clone(GameConfig.Economy)
		local r = Rewards.contract({ base = 1000, tierRisk = 1.5, extracted = true, discoveries = 1 }, economy)
		equal(r.total, 2300, "specens exempel ger 2300")
		equal(r.extractionBonus, 300, "extraktionsbonus 20 % av 1500")

		local notExtracted = Rewards.contract({ base = 1000, tierRisk = 1.5, extracted = false }, economy)
		equal(notExtracted.total, 1500, "ingen extraktionsbonus om pengarna inte säkrades")

		local failed = Rewards.contract({ base = 1000, extracted = false, failureFraction = 0.5 }, economy)
		equal(failed.total, 500, "misslyckat skift tar hälften")

		local hot = Rewards.contract({ base = 1000, heat = 100, extracted = false }, economy)
		equal(hot.riskBonus, 500, "HEAT 100 ger +50 % riskbonus")
		equal(Rewards.offerValue(880, 1.25), 1100, "NORMAL-erbjudande visar 1,100")
		equal(Rewards.offerValue(3000, 1.5), 4500, "HIGH RISK-erbjudande visar 4,500")
	end)

	describe("HeatLogic", function()
		local heat = GameConfig.Heat
		equal(HeatLogic.add(95, 20, heat), 100, "HEAT tak 100")
		equal(HeatLogic.add(5, -20, heat), 0, "HEAT golv 0")
		equal(HeatLogic.add(10, 10, heat, 1.5), 25, "farlig incident förstärker ökningen")
		equal(HeatLogic.add(10, -5, heat, 1.5), 5, "men inte minskningen")
		equal(HeatLogic.tier(0, heat).name, "CALM", "0 = CALM")
		equal(HeatLogic.tier(65, heat).name, "FAILING", "65 = FAILING")
		equal(HeatLogic.tier(100, heat).name, "CRITICAL", "100 = CRITICAL")
		near(HeatLogic.serverHeat({ 0, 0, 100 }), 60, 1e-9, "en het spelare märks: 0.6*33.3 + 0.4*100")
		equal(HeatLogic.serverHeat({}), 0, "tom server = 0")
	end)

	describe("InventoryLogic", function()
		local capacity = InventoryLogic.capacityFor(0, GameConfig.Inventory)
		equal(capacity, 6, "6 platser från start")
		equal(InventoryLogic.capacityFor(10, GameConfig.Inventory), 9, "aldrig mer än MaxSlots")
		local inv = InventoryLogic.new(capacity)
		for i = 1, 6 do
			equal(InventoryLogic.add(inv, { uid = "u" .. i, id = "OldRadio" }), i, "plats " .. i)
		end
		check(InventoryLogic.isFull(inv), "fullt efter 6")
		equal(InventoryLogic.add(inv, { uid = "x", id = "OldRadio" }), nil, "kan inte lägga till när fullt")
		local removed = InventoryLogic.removeAt(inv, 3)
		equal(removed and removed.uid, "u3", "ta bort plats 3")
		equal(InventoryLogic.removeAt(inv, 3), nil, "tom plats ger nil")
		equal(InventoryLogic.removeAt(inv, 0), nil, "ogiltig plats avvisas")
		equal(InventoryLogic.removeAt(inv, 2.5 :: any), nil, "decimal avvisas")
		equal(InventoryLogic.add(inv, { uid = "new", id = "TheObject" }), 3, "nytt föremål hamnar i luckan")
		local overflow = InventoryLogic.resize(inv, 4)
		equal(#overflow, 2, "två föremål får inte plats när kapaciteten minskar")
		equal(InventoryLogic.count(inv), 4, "fyra kvar")
	end)

	describe("DirectorLogic", function()
		local config = GameConfig.Director
		local defs = IncidentConfig.Incidents
		local function context(overrides)
			local c = {
				now = 1000,
				nightElapsed = 400,
				clock = 1.5,
				serverHeat = 100,
				playerCount = 12,
				active = {},
				lastStartedAt = {},
				history = {},
				previousShiftMajors = {},
				incidentsThisNight = 3,
				lastIncidentAt = 0,
				forecast = nil,
			}
			for k, v in overrides or {} do
				c[k] = v
			end
			return c
		end

		equal(
			DirectorLogic.triggerChance(context({ incidentsThisNight = 0, nightElapsed = 100 }), config),
			0,
			"inget före fönstret"
		)
		equal(
			DirectorLogic.triggerChance(context({ incidentsThisNight = 0, nightElapsed = 210 }), config),
			1,
			"garanterad första incident"
		)
		equal(DirectorLogic.triggerChance(context({ lastIncidentAt = 980 }), config), 0, "MinGap respekteras")
		equal(DirectorLogic.triggerChance(context({ clock = 2.9 }), config), 0, "inga nya incidenter nära 03:00")
		equal(
			DirectorLogic.triggerChance(context({ active = { Blackout = true, FalseAlarm = true } }), config),
			0,
			"max två samtidigt"
		)

		-- Första incidenten får inte vara värre än FirstIncidentMaxRarity
		local first = DirectorLogic.candidates(defs, context({ incidentsThisNight = 0 }), config)
		local tooRare = false
		for _, c in first do
			if DirectorLogic.rarityRank(c.def.rarity) > DirectorLogic.rarityRank(config.FirstIncidentMaxRarity) then
				tooRare = true
			end
		end
		check(#first > 0 and not tooRare, "första incidenten är Common/Uncommon")

		-- Twists väljs aldrig av regissören
		local all = DirectorLogic.candidates(defs, context(), config)
		local hasTwist = false
		for _, c in all do
			if c.def.scope == "Twist" then
				hasTwist = true
			end
		end
		check(not hasTwist, "twists startas bara av kontrakt")

		-- Fördelningen per sällsynthet följer konfigurationen när allt är möjligt
		local rng = Rng.new(2024)
		local byRarity = {}
		local N = 40000
		for _ = 1, N do
			local chosen = DirectorLogic.choose(defs, context(), config, rng)
			byRarity[chosen.def.rarity] = (byRarity[chosen.def.rarity] or 0) + 1
		end
		local total = 0
		for _, w in config.RarityWeights do
			total += w
		end
		for rarity, weight in config.RarityWeights do
			near((byRarity[rarity] or 0) / N, weight / total, 0.012, string.format("%s ~%d %%", rarity, weight))
		end

		-- Cooldown och upprepning
		local cooled = DirectorLogic.candidates(defs, context({ lastStartedAt = { Blackout = 900 } }), config)
		local hasBlackout = false
		for _, c in cooled do
			if c.id == "Blackout" then
				hasBlackout = true
			end
		end
		check(not hasBlackout, "Blackout under cooldown kan inte väljas")

		local function weightOf(list, id)
			for _, c in list do
				if c.id == id then
					return c.weight
				end
			end
			return 0
		end
		local normal = weightOf(all, "Blackout")
		local repeated =
			weightOf(DirectorLogic.candidates(defs, context({ history = { "Blackout" } }), config), "Blackout")
		local forecast =
			weightOf(DirectorLogic.candidates(defs, context({ forecast = "Blackout" }), config), "Blackout")
		check(repeated < normal, "nylig incident blir mindre trolig")
		check(forecast > normal, "kvällens prognos blir mer trolig")

		local blocked = DirectorLogic.candidates(defs, context({ previousShiftMajors = { "Lockdown" } }), config)
		check(weightOf(blocked, "Lockdown") == 0, "Major upprepas inte två skift i rad")
		local cold = DirectorLogic.candidates(defs, context({ serverHeat = 0 }), config)
		check(weightOf(cold, "ImpossibleLights") == 0 and weightOf(cold, "Blackout") > 0, "HEAT-gränser respekteras")

		-- Samma seed ger samma val (för felsökning från loggen)
		local x = DirectorLogic.choose(defs, context(), config, Rng.new(555))
		local y = DirectorLogic.choose(defs, context(), config, Rng.new(555))
		equal(x.id, y.id, "seed återskapar valet")
	end)

	describe("ContractLogic", function()
		local sites = {
			PowerBox = { { id = "pb1", siteType = "PowerBox", label = "Mercer St" } },
			Doorstep = { { id = "d1", siteType = "Doorstep", label = "Calloway Residences" } },
			StoreBackroom = { { id = "s1", siteType = "StoreBackroom", label = "Nite Owl Mart" } },
			GarageBay = { { id = "g1", siteType = "GarageBay", label = "Ostrava Parking L2" } },
			StationSignal = { { id = "st1", siteType = "StationSignal", label = "Line 3 platform" } },
		}
		local n = 0
		local function ctx(licenses, busy)
			return {
				rng = Rng.new(11),
				hasLicense = function(license)
					return table.find(licenses, license) ~= nil
				end,
				busySites = busy or {},
				nextId = function()
					n += 1
					return "offer" .. n
				end,
			}
		end
		local offers = ContractLogic.generateOffers(ContractConfig, sites, ctx({ "ContractsSafe", "ContractsNormal" }))
		equal(#offers, 3, "tre erbjudanden")
		equal(offers[1].tier, "Safe", "första är SAFE")
		equal(offers[3].tier, "HighRisk", "sista är HIGH RISK")
		check(offers[3].locked and offers[3].lockReason ~= nil, "HIGH RISK är låst utan licens")
		check(not offers[1].locked, "SAFE är öppet")
		check(offers[1].brief:find(offers[1].siteLabel, 1, true) ~= nil, "beskrivningen nämner platsen")

		local busy = ContractLogic.generateOffers(
			ContractConfig,
			sites,
			ctx({ "ContractsSafe", "ContractsNormal", "ContractsHighRisk" }, { st1 = true })
		)
		local hasHigh = false
		for _, o in busy do
			if o.tier == "HighRisk" then
				hasHigh = true
			end
		end
		check(not hasHigh, "upptagna platser erbjuds inte")

		for _, template in ContractConfig.Templates do
			check(ContractConfig.Tiers[template.tier] ~= nil, template.id .. ": giltig nivå")
			for _, step in template.steps do
				if step.item then
					check(ItemConfig.get(step.item) ~= nil, template.id .. ": föremålet " .. step.item .. " finns")
				end
			end
			for _, twist in template.twists or {} do
				local def = IncidentConfig.Incidents[twist.id]
				check(def ~= nil and def.scope == "Twist", template.id .. ": twist " .. twist.id .. " finns")
			end
		end
	end)

	describe("Konfigurationen hänger ihop", function()
		for tableName, list in LootConfig.Tables do
			for _, entry in list do
				check(ItemConfig.get(entry.item) ~= nil, "loot " .. tableName .. ": " .. entry.item .. " finns")
			end
		end
		for id, item in ItemConfig.Items do
			check(ItemConfig.Rarities[item.rarity] ~= nil, "föremål " .. id .. ": giltig sällsynthet")
			if item.collection then
				check(ItemConfig.Collections[item.collection] ~= nil, "föremål " .. id .. ": samlingen finns")
			end
		end
		for id, def in IncidentConfig.Incidents do
			check(GameConfig.Director.RarityWeights[def.rarity] ~= nil, "incident " .. id .. ": giltig sällsynthet")
			check(
				type(def.duration) == "number" and type(def.cooldown) == "number",
				"incident " .. id .. ": tider satta"
			)
		end
		local level1 = ProgressionConfig.levelFor(0)
		equal(level1.level, 1, "rykte 0 = nivå 1")
		check(ProgressionConfig.hasLicense(300, "ContractsHighRisk"), "nivå 2 ger HIGH RISK")
		check(not ProgressionConfig.hasLicense(0, "ContractsHighRisk"), "nivå 1 saknar HIGH RISK")
		local digits = {}
		for d, symbol in SecretConfig.SymbolForDigit do
			check(digits[symbol] == nil, "symbolen för " .. d .. " är unik")
			digits[symbol] = d
		end
		local covered = {}
		for _, poster in SecretConfig.Posters do
			for _, d in poster.digits do
				covered[d] = true
			end
		end
		local all = true
		for d = 0, 9 do
			if not covered[tostring(d)] then
				all = false
			end
		end
		check(all, "affischerna täcker tillsammans alla tio siffror")
	end)

	describe("LootLogic", function()
		local rank = function(itemId)
			return ItemConfig.rarityRank(ItemConfig.get(itemId).rarity)
		end
		local function share(heat)
			local rng = Rng.new(5)
			local rare = 0
			for _ = 1, 20000 do
				local id = LootLogic.roll(LootConfig.Tables.Alley, heat, GameConfig.Loot.HeatRarityShift, rank, rng)
				if rank(id) >= 3 then
					rare += 1
				end
			end
			return rare / 20000
		end
		local cold, hot = share(0), share(100)
		check(hot > cold * 1.5, string.format("HEAT 100 ger mer sällsynt loot (%.3f -> %.3f)", cold, hot))
	end)

	describe("DataSchema", function()
		local fresh, changed = DataSchema.migrate(nil)
		equal(fresh.version, DataSchema.Version, "ny profil har aktuell version")
		check(changed, "ny profil räknas som ändrad")

		local legacy = DataSchema.migrate({ money = 750, reputation = 30, customField = "behåll" })
		equal(legacy.credits, 750, "v0: money blir credits")
		equal(legacy.money, nil, "v0: money tas bort")
		equal(legacy.reputation, 30, "befintliga fält behålls")
		equal(legacy.customField, "behåll", "okända fält behålls")
		equal(legacy.stats.shifts, 0, "saknade nästlade fält fylls i")

		local v1 = DataSchema.migrate({ version = 1, credits = 10, cosmetics = { Sodium = true } })
		check(v1.cosmetics.flashlight.Sodium == true, "v1: gammal kosmetika flyttas till ficklampa")
		check(v1.cosmetics.vest.HiVis == true, "v1: västar fylls i med standard")

		local broken =
			DataSchema.migrate({ version = 2, credits = "massor", stats = 5, discoveries = { TowerRoof = 123 } })
		equal(broken.credits, 0, "fel typ återställs")
		equal(type(broken.stats), "table", "trasig tabell återställs")
		equal(broken.discoveries.TowerRoof, 123, "övrig data rörs inte")

		local future = DataSchema.migrate({ version = 99, credits = 5, newSystem = { a = 1 } })
		equal(future.version, 99, "nyare version nedgraderas inte")
		equal(future.newSystem.a, 1, "nyare fält behålls")

		local again, changedAgain = DataSchema.migrate(DataSchema.migrate({ credits = 1 }))
		check(not changedAgain and again.credits == 1, "migrering är idempotent")

		local a, b = DataSchema.default(), DataSchema.default()
		a.titles.Hacked = true
		check(b.titles.Hacked == nil, "standardprofiler delar inga tabeller")
	end)

	describe("RateLimiter", function()
		local limiter = RateLimiter.new({ Default = { rate = 1, burst = 3 } })
		local allowed = 0
		for _ = 1, 10 do
			if limiter:allow("p1", "X", 0) then
				allowed += 1
			end
		end
		equal(allowed, 3, "burst 3 på en gång")
		check(not limiter:allow("p1", "X", 0.5), "inte efter en halv sekund")
		check(limiter:allow("p1", "X", 1.1), "en ny token efter en sekund")
		check(limiter:allow("p2", "X", 0), "andra spelare påverkas inte")
	end)

	describe("StoryCard", function()
		local card = StoryCard.build({
			shiftNumber = 17,
			survived = true,
			contractsCompleted = 3,
			peakHeat = 72,
			itemsSecured = 7,
			itemsLost = 0,
			squadSize = 4,
			squadSurvived = 3,
			biggestIncident = { name = "BLACKOUT", district = "Downtown" },
			earnings = { contracts = 3240, items = 1850, risk = 900, discovery = 0, survival = 0, penalty = 0 },
			discoveries = {},
			bestFind = nil,
			titlesEarned = {},
		}, GameConfig.Heat)
		equal(card.shift, "SHIFT #17", "skiftnummer")
		equal(card.total, 5990, "specens exempel summerar till 5,990")
		equal(card.headline, "YOU SURVIVED 03:00", "rubrik vid överlevnad")
		equal(card.biggestIncident, "BLACKOUT - DOWNTOWN", "största incidenten")
		local squad
		for _, f in card.facts do
			if f.label == "Squad survival" then
				squad = f.value
			end
		end
		equal(squad, "3/4", "squadens överlevnad")
	end)

	describe("SecretCode", function()
		local week = SecretCode.weekIndex(1760000000)
		local code = SecretCode.codeForWeek(week, SecretConfig.Salt, SecretConfig.CodeLength)
		equal(#code, 4, "fyrsiffrig kod")
		equal(code, SecretCode.codeForWeek(week, SecretConfig.Salt, 4), "samma vecka = samma kod på alla servrar")
		local different = 0
		for w = week + 1, week + 10 do
			if SecretCode.codeForWeek(w, SecretConfig.Salt, 4) ~= code then
				different += 1
			end
		end
		check(different >= 9, "koden byts varje vecka")
		equal(SecretCode.weekIndex(345600), 0, "vecka 0 börjar måndag 1970-01-05")
		equal(SecretCode.weekIndex(345600 + 604800 - 1), 0, "söndag kväll är samma vecka")
		local symbols = SecretCode.symbolsFor("1407", SecretConfig.SymbolForDigit)
		equal(table.concat(symbols), "▲✕◇★", "symbolöversättning")
	end)
end
