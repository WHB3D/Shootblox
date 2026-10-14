--[=[
	SHOOTBLOX — Studio Test Runner
	Paste this into Studio's Command Bar (View → Command Bar) to run all tests.
	
	Requires: TestEZ installed via Wally (Packages/TestEZ)
]=]

local TestEZ = require(game:GetService("ReplicatedStorage").Packages.TestEZ)

local testModules = {
	game:GetService("ServerScriptService").Tests.CombatService.OriginValidation,
	game:GetService("ServerScriptService").Tests.CombatService.FireRateValidation,
	game:GetService("ServerScriptService").Tests.CombatService.AngleValidation,
	game:GetService("ServerScriptService").Tests.CombatService.TargetValidation,
	game:GetService("ServerScriptService").Tests.CombatService.DamageValidation,
	game:GetService("ServerScriptService").Tests.CombatService.AmmoValidation,
	game:GetService("ServerScriptService").Tests.CombatService.RangeValidation,
	game:GetService("ServerScriptService").Tests.CombatService.LOSValidation,
	game:GetService("ServerScriptService").Tests.CombatService.CooldownValidation,
}

print("[TestRunner] Starting TestEZ test run...")
local results = TestEZ.TestBootstrap:run(testModules, TestEZ.Reporters.TextReporter)

if results.failureCount > 0 or results.errorCount > 0 then
	warn(string.format("[TestRunner] FAILED: %d failures, %d errors", results.failureCount, results.errorCount))
else
	print("[TestRunner] ALL TESTS PASSED ✓")
end

return results