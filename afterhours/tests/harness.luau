-- Testmiljö som körs i Lune (https://lune-org.github.io/docs).
-- Bygger samma instansträd som Rojo (ReplicatedStorage.Shared, ServerScriptService.Server ...)
-- så att modulerna kan laddas med sina riktiga require-sökvägar, med riktiga Roblox-datatyper.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local task = require("@lune/task")

local Harness = {}

local MOUNTS = {
	{ dir = "src/shared", service = "ReplicatedStorage", name = "Shared" },
	{ dir = "src/server", service = "ServerScriptService", name = "Server" },
}

local function classFor(fileName: string): (string, string)
	if fileName:match("%.server%.luau$") then
		return "Script", fileName:gsub("%.server%.luau$", "")
	elseif fileName:match("%.client%.luau$") then
		return "LocalScript", fileName:gsub("%.client%.luau$", "")
	end
	return "ModuleScript", (fileName:gsub("%.luau$", ""))
end

function Harness.new(root: string?)
	root = root or "."
	local self = {
		game = roblox.Instance.new("DataModel"),
		paths = {},
		cache = {},
		extraGlobals = {},
	}

	local function mount(dir: string, parent)
		for _, entry in fs.readDir(dir) do
			local path = dir .. "/" .. entry
			if fs.isDir(path) then
				local folder = roblox.Instance.new("Folder")
				folder.Name = entry
				folder.Parent = parent
				mount(path, folder)
			elseif entry:match("%.luau$") then
				local className, name = classFor(entry)
				local inst = roblox.Instance.new(className)
				inst.Name = name
				inst.Parent = parent
				self.paths[inst] = path
			end
		end
	end

	for _, m in MOUNTS do
		local folder = roblox.Instance.new("Folder")
		folder.Name = m.name
		folder.Parent = self.game:GetService(m.service)
		mount(root .. "/" .. m.dir, folder)
	end

	function self.require(moduleScript)
		if self.cache[moduleScript] ~= nil then
			return self.cache[moduleScript]
		end
		local path = self.paths[moduleScript]
		assert(path, "okänd modul: " .. tostring(moduleScript))
		local env = { game = self.game, script = moduleScript, require = self.require, task = task }
		for k, v in roblox :: any do
			env[k] = v
		end
		for k, v in self.extraGlobals do
			env[k] = v
		end
		local chunk = luau.load(fs.readFile(path), { debugName = path, environment = env })
		local result = chunk()
		self.cache[moduleScript] = result
		return result
	end

	-- Bekvämlighet: harness:module("Server.Logic.Rewards")
	function self.module(dotted: string)
		local parts = string.split(dotted, ".")
		local service = if parts[1] == "Shared" then "ReplicatedStorage" else "ServerScriptService"
		local inst = self.game:GetService(service)
		for _, part in parts do
			inst = inst:FindFirstChild(part)
			assert(inst, "hittar inte " .. dotted)
		end
		return self.require(inst)
	end

	return self
end

-- Minimalt testramverk ------------------------------------------------------

local results = { passed = 0, failed = 0, current = "" }

function Harness.describe(name: string, fn)
	results.current = name
	print("\n" .. name)
	local ok, err = pcall(fn)
	if not ok then
		results.failed += 1
		print("  FAIL (krasch): " .. tostring(err))
	end
end

function Harness.check(condition: any, message: string)
	if condition then
		results.passed += 1
		print("  ok - " .. message)
	else
		results.failed += 1
		print("  FAIL - " .. message)
	end
end

function Harness.equal(actual: any, expected: any, message: string)
	local ok = actual == expected
	Harness.check(
		ok,
		message .. (if ok then "" else string.format(" (fick %s, väntade %s)", tostring(actual), tostring(expected)))
	)
end

function Harness.near(actual: number, expected: number, tolerance: number, message: string)
	local ok = math.abs(actual - expected) <= tolerance
	Harness.check(
		ok,
		message
			.. (if ok then "" else string.format(" (fick %.4f, väntade %.4f ± %.4f)", actual, expected, tolerance))
	)
end

function Harness.finish()
	print(string.format("\n%d ok, %d misslyckade", results.passed, results.failed))
	-- Avsluta alltid: serverns bakgrundsloopar skulle annars hålla Lune igång för evigt.
	process.exit(if results.failed > 0 then 1 else 0)
end

return Harness
