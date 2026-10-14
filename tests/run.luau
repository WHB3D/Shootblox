--!strict
--[[
	SHOOTBLOX — TestEZ Test Harness
	Run with: lune run tests/run.luau
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Load TestEZ
local TestEZ = require(ReplicatedStorage.Packages.TestEZ)

-- Test modules to run
local testModules = {
	script.Parent.CombatService.OriginValidation,
	script.Parent.CombatService.FireRateValidation,
	script.Parent.CombatService.AngleValidation,
	script.Parent.CombatService.TargetValidation,
	script.Parent.CombatService.DamageValidation,
	script.Parent.CombatService.AmmoValidation,
	script.Parent.CombatService.RangeValidation,
	script.Parent.CombatService.LOSValidation,
	script.Parent.CombatService.CooldownValidation,
	-- Add more test modules as we build
}

local results = TestEZ.TestBootstrap:run(testModules, TestEZ.Reporters.TextReporter)

-- Exit with appropriate code
if results.failureCount > 0 or results.errorCount > 0 then
	os.exit(1)
else
	os.exit(0)
end

return {}