--!strict
--[[
	SHOOTBLOX — TestEZ Configuration
	Place this in ReplicatedStorage.Packages.TestEZ for in-Studio testing.
]]

-- TestEZ config is typically just the module itself from Wally
-- This file documents the test structure for CI

return {
	-- Test modules pattern
	testModules = {
		"tests.CombatService.OriginValidation",
		"tests.CombatService.FireRateValidation",
		"tests.CombatService.AngleValidation",
		"tests.CombatService.TargetValidation",
		"tests.CombatService.DamageValidation",
		"tests.CombatService.AmmoValidation",
		"tests.CombatService.RangeValidation",
		"tests.CombatService.LOSValidation",
		"tests.CombatService.CooldownValidation",
	},

	-- Reporter options
	reporter = "TextReporter",

	-- Test settings
	settings = {
		-- Stop on first failure for CI
		stopOnFailure = true,
		-- Timeout per test (seconds)
		testTimeout = 5,
	},
}
