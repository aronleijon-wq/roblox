-- DataSchema: hur en spelarprofil ser ut, och hur gamla profiler uppgraderas.
--
-- Regler som skyddar sparad data:
--   * Varje profil har ett versionsnummer. Migreringar körs i ordning, en version i taget.
--   * Fält som saknas fylls i med standardvärden; fält med fel typ återställs bara på den nivån.
--   * Okända fält (t.ex. från en nyare serverversion) behålls orörda.
--   * En profil från en nyare version nedgraderas aldrig.

local DataSchema = {}

DataSchema.Version = 2

function DataSchema.default()
	return {
		version = DataSchema.Version,
		credits = 0,
		reputation = 0,
		stats = {
			shifts = 0,
			extractions = 0,
			failures = 0,
			contracts = 0,
			highRiskContracts = 0,
			incidentsWitnessed = 0,
			itemsSecured = 0,
			totalEarned = 0,
			bestShift = 0,
			downed = 0,
		},
		discoveries = {}, -- [id] = os.time() när den hittades
		collection = {}, -- [itemId] = antal säkrade
		titles = { NewHire = true },
		equippedTitle = "NewHire",
		cosmetics = {
			flashlight = { Standard = true },
			vest = { HiVis = true },
		},
		equipped = { flashlight = "Standard", vest = "HiVis" },
		purchases = {}, -- [shopItemId] = true
		season = { id = "S0", points = 0 },
		settings = {},
		onboarding = { step = 0 },
		firstJoin = 0,
		lastJoin = 0,
	}
end

-- Migreringar: Migrations[n] uppgraderar en profil från version n till n + 1.
DataSchema.Migrations = {
	-- 0 -> 1: profiler utan versionsnummer (tidiga tester) hade "money" i stället för "credits".
	[0] = function(data)
		if type(data.money) == "number" and data.credits == nil then
			data.credits = data.money
		end
		data.money = nil
	end,
	-- 1 -> 2: kosmetika delades upp i ficklampa och väst.
	[1] = function(data)
		if type(data.cosmetics) == "table" and data.cosmetics.flashlight == nil and data.cosmetics.vest == nil then
			local old = data.cosmetics
			data.cosmetics = { flashlight = {}, vest = {} }
			for key, value in old do
				if type(key) == "string" and value == true then
					data.cosmetics.flashlight[key] = true
				end
			end
		end
	end,
}

local function reconcile(target, template)
	for key, defaultValue in template do
		local current = target[key]
		if current == nil or type(current) ~= type(defaultValue) then
			target[key] = if type(defaultValue) == "table" then table.clone(defaultValue) else defaultValue
			if type(defaultValue) == "table" then
				reconcile(target[key], defaultValue) -- djupkopiera nästlade standardtabeller
			end
		elseif type(current) == "table" and next(defaultValue) ~= nil then
			reconcile(current, defaultValue)
		end
	end
end

-- Tar vad som helst från DataStore och returnerar en giltig profil.
-- Andra värdet säger om något ändrades (migrerades eller reparerades).
function DataSchema.migrate(raw: any): (any, boolean)
	if type(raw) ~= "table" then
		return DataSchema.default(), true
	end

	local changed = false
	local version = if type(raw.version) == "number" then raw.version else 0
	while version < DataSchema.Version do
		local step = DataSchema.Migrations[version]
		if step then
			step(raw)
		end
		version += 1
		changed = true
	end
	raw.version = math.max(version, if type(raw.version) == "number" then raw.version else 0)

	local before = DataSchema.fingerprint(raw)
	reconcile(raw, DataSchema.default())
	if DataSchema.fingerprint(raw) ~= before then
		changed = true
	end
	return raw, changed
end

-- Enkel signatur av tabellens nycklar och typer (för att se om reconcile ändrade något).
function DataSchema.fingerprint(value: any): string
	if type(value) ~= "table" then
		return type(value) .. ":" .. tostring(value)
	end
	local keys = {}
	for key in value do
		table.insert(keys, tostring(key))
	end
	table.sort(keys)
	local parts = {}
	for _, key in keys do
		local v = value[key]
		if v == nil then
			v = value[tonumber(key)]
		end
		table.insert(parts, key .. "=" .. DataSchema.fingerprint(v))
	end
	return "{" .. table.concat(parts, ",") .. "}"
end

return DataSchema
