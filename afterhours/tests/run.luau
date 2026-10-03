-- Kör alla tester:  lune run tests/run.luau   (från mappen afterhours/)

local Harness = require("./harness")

local SPECS = {
	require("./logic.spec"),
	require("./world.spec"),
	require("./server.spec"),
	require("./client.spec"), -- måste köras efter servertestet (spelar upp det servern skickade)
}

for _, spec in SPECS do
	spec(Harness.new("."))
end

Harness.finish()
