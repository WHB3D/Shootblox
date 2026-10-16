--!strict
--[[
	SHOOTBLOX — Spring Test
	Pure module, no Roblox globals beyond Vector3 (same convention as
	Types.luau). Does NOT run in CI yet (see PROGRESS.md "Known gap").
]]

local TestEZ = require(game:GetService("ReplicatedStorage").Packages.TestEZ)
local Spring = require(game:GetService("ReplicatedStorage").Shared.Spring)

local Tests = {}

Tests["Settles at the target after enough time"] = function()
	local spring = Spring.new(1, 50, 4, 4)
	spring.Target = Vector3.new(1, 0, 0)
	local result = Vector3.zero
	for _ = 1, 300 do
		result = spring:update(1 / 60)
	end
	TestEZ.assert((result - spring.Target).Magnitude < 0.01, "spring should converge on its target")
end

Tests["Starts at rest: zero position, zero velocity"] = function()
	local spring = Spring.new()
	TestEZ.assert(spring.Position == Vector3.zero, "position should start at zero")
	TestEZ.assert(spring.Velocity == Vector3.zero, "velocity should start at zero")
end

Tests["A shove adds velocity without jumping position instantly"] = function()
	local spring = Spring.new(1, 50, 4, 4)
	spring:shove(Vector3.new(10, 0, 0))
	TestEZ.assert(spring.Velocity.X > 0, "shove should add velocity")
	TestEZ.assert(spring.Position == Vector3.zero, "shove should not teleport position")
end

Tests["update() is the only thing that advances position, and only toward Target"] = function()
	local spring = Spring.new(1, 50, 4, 4)
	spring.Target = Vector3.new(5, 0, 0)
	local first = spring:update(1 / 60)
	TestEZ.assert(first.X > 0 and first.X < 5, "position should move toward, not past, target in one step")
end

return Tests
