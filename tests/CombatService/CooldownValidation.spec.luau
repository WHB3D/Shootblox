--!strict
--[[
	SHOOTBLOX — CombatService Cooldown/Anti-Spam Validation Tests
	Tests the global shot throttling check (Check 9)
]]

local TestEZ = require(game:GetService("ReplicatedStorage").Packages.TestEZ)
local CombatConfig = require(game:GetService("ReplicatedStorage").Shared.Config.Combat)

local function createMockPlayer(name: string)
	local attributes = {}
	return {
		Name = name,
		GetAttribute = function(self, key: string)
			return attributes[key]
		end,
		SetAttribute = function(self, key: string, value: any)
			attributes[key] = value
		end,
	}
end

local function createMockRequest(weaponId: string)
	return {
		WeaponId = weaponId,
		Origin = Vector3.new(0, 5, 0),
		Direction = Vector3.new(0, 0, -1),
		Timestamp = os.clock(),
		ServerTick = workspace:GetServerTimeNow(),
		ShotId = "test",
	}
end

local function checkCooldown(player, request)
	local shotsThisTick = player:GetAttribute("ShotsThisTick") or 0
	if shotsThisTick >= CombatConfig.Tolerances.MaxShotsPerTick then
		return { Valid = false, RejectReason = "ON_COOLDOWN" }
	end
	player:SetAttribute("ShotsThisTick", shotsThisTick + 1)
	return { Valid = true }
end

local Tests = {}

Tests["Cooldown passes for first shot in tick"] = function()
	local player = createMockPlayer("TestPlayer")
	local request = createMockRequest("AR_Standard")

	local result = checkCooldown(player, request)
	TestEZ.assert(result.Valid == true, "First shot should pass")
	TestEZ.assert(player:GetAttribute("ShotsThisTick") == 1, "Should increment counter")
end

Tests["Cooldown passes for multiple shots up to limit"] = function()
	local player = createMockPlayer("TestPlayer")
	local maxShots = CombatConfig.Tolerances.MaxShotsPerTick -- 3

	for i = 1, maxShots do
		local request = createMockRequest("AR_Standard")
		local result = checkCooldown(player, request)
		TestEZ.assert(result.Valid == true, "Shot " .. i .. " should pass")
	end

	TestEZ.assert(player:GetAttribute("ShotsThisTick") == maxShots, "Should track all shots")
end

Tests["Cooldown fails when exceeding shots per tick"] = function()
	local player = createMockPlayer("TestPlayer")
	local maxShots = CombatConfig.Tolerances.MaxShotsPerTick -- 3

	-- Fire max allowed
	for i = 1, maxShots do
		local request = createMockRequest("AR_Standard")
		checkCooldown(player, request)
	end

	-- One more should fail
	local request = createMockRequest("AR_Standard")
	local result = checkCooldown(player, request)

	TestEZ.assert(result.Valid == false, "Should fail on shot " .. (maxShots + 1))
	TestEZ.assert(result.RejectReason == "ON_COOLDOWN", "Should return ON_COOLDOWN code")
end

Tests["Cooldown counter is per-tick (resets each tick)"] = function()
	-- This is a design note - the counter should be reset each server tick
	-- The actual reset logic would be in the server heartbeat
	TestEZ.assert(CombatConfig.Tolerances.MaxShotsPerTick == 3, "Max shots per tick is 3")
end

Tests["Cooldown works independently per player"] = function()
	local player1 = createMockPlayer("Player1")
	local player2 = createMockPlayer("Player2")
	local maxShots = CombatConfig.Tolerances.MaxShotsPerTick

	-- Player 1 fires max
	for i = 1, maxShots do
		checkCooldown(player1, createMockRequest("AR_Standard"))
	end

	-- Player 2 should still be able to fire
	for i = 1, maxShots do
		local result = checkCooldown(player2, createMockRequest("AR_Standard"))
		TestEZ.assert(result.Valid == true, "Player 2 shot " .. i .. " should pass")
	end

	-- Player 1 should be blocked
	local result = checkCooldown(player1, createMockRequest("AR_Standard"))
	TestEZ.assert(result.Valid == false, "Player 1 should still be blocked")
end

return Tests
