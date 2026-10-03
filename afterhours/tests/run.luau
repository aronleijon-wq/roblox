-- Kör alla tester:  lune run tests/run.luau   (från mappen afterhours/)

local Harness = require("./harness")

local SPECS = {
	require("./logic.spec"),
	require("./world.spec"),
	require("./server.spec"),
}

for _, spec in SPECS do
	spec(Harness.new("."))
end

Harness.finish()
