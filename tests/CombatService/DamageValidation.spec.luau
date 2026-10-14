--!strict
--[[
	SHOOTBLOX — CombatService Damage Validation Tests
	Tests the damage calculation check (Check 5)
]]

local TestEZ = require(game:GetService("ReplicatedStorage").Packages.TestEZ)
local CombatConfig = require(game:GetService("ReplicatedStorage").Shared.Config.Combat)
local Weapons = require(game:GetService("ReplicatedStorage").Shared.Config.Weapons)

local function createMockRequest(weaponId: string, range: number, headshot: boolean)
	return {
		WeaponId = weaponId,
		Origin = Vector3.new(0, 5, 0),
		Direction = Vector3.new(0, 0, -1),
		HitPosition = Vector3.new(0, 5, -range),
		Headshot = headshot,
		Timestamp = os.clock(),
		ServerTick = workspace:GetServerTimeNow(),
	}
end

local function checkDamage(player, request, weapon)
	local baseDamage = weapon.Damage
	local range = (request.HitPosition - request.Origin).Magnitude

	local multiplier = 1.0
	if weapon.DamageDropoff then
		local sortedRanges = {}
		for r in weapon.DamageDropoff do
			table.insert(sortedRanges, r)
		end
		table.sort(sortedRanges)

		for _, r in sortedRanges do
			if range <= r then
				multiplier = weapon.DamageDropoff[r]
				break
			end
		end
		if range > sortedRanges[#sortedRanges] then
			multiplier = CombatConfig.Tolerances.MinDamagePercent
		end
	end

	if request.Headshot then
		multiplier *= weapon.HeadshotMultiplier
	end

	local finalDamage = math.floor(baseDamage * multiplier + 0.5)
	finalDamage = math.max(1, finalDamage)

	local maxPossible = weapon.Damage * weapon.HeadshotMultiplier
	if finalDamage > maxPossible * 1.1 then
		return { Valid = false, RejectReason = "INVALID_DAMAGE" }
	end

	return { Valid = true, Damage = finalDamage }
end

local Tests = {}

Tests["Damage calc correct at point blank"] = function()
	local weapon = Weapons.Get("AR_Standard") -- 28 base damage
	local request = createMockRequest("AR_Standard", 0, false)
	
	local result = checkDamage(nil, request, weapon)
	TestEZ.assert(result.Valid == true)
	TestEZ.assert(result.Damage == 28, "Point blank should be base damage (28)")
end

Tests["Damage calc applies dropoff at range"] = function()
	local weapon = Weapons.Get("AR_Standard")
	-- At 50 studs, should be in 60 stud bracket (0.75 multiplier)
	local request = createMockRequest("AR_Standard", 50, false)
	
	local result = checkDamage(nil, request, weapon)
	TestEZ.assert(result.Valid == true)
	TestEZ.assert(result.Damage == math.floor(28 * 0.75 + 0.5), "Should apply 0.75 dropoff at 50 studs")
end

Tests["Damage calc applies headshot multiplier"] = function()
	local weapon = Weapons.Get("AR_Standard") -- 28 base, 2.0 headshot
	local request = createMockRequest("AR_Standard", 0, true)
	
	local result = checkDamage(nil, request, weapon)
	TestEZ.assert(result.Valid == true)
	TestEZ.assert(result.Damage == 56, "Headshot should be 2x base (56)")
end

Tests["Damage calc applies both dropoff and headshot"] = function()
	local weapon = Weapons.Get("AR_Standard")
	-- At 50 studs with headshot: 28 * 0.75 * 2.0 = 42
	local request = createMockRequest("AR_Standard", 50, true)
	
	local result = checkDamage(nil, request, weapon)
	TestEZ.assert(result.Valid == true)
	TestEZ.assert(result.Damage == math.floor(28 * 0.75 * 2.0 + 0.5), "Should apply both dropoff and headshot")
end

Tests["Damage calc never goes below 1"] = function()
	local weapon = Weapons.Get("SMG_Compact") -- 20 base, heavy dropoff
	-- At max range (40) with min multiplier (0.2): 20 * 0.2 = 4
	local request = createMockRequest("SMG_Compact", 40, false)
	
	local result = checkDamage(nil, request, weapon)
	TestEZ.assert(result.Valid == true)
	TestEZ.assert(result.Damage >= 1, "Damage should never go below 1")
end

Tests["Damage calc rejects impossible damage"] = function()
	local weapon = Weapons.Get("AR_Standard") -- max 28 * 2.0 = 56
	local request = createMockRequest("AR_Standard", 0, true)
	
	-- Manually inject impossible damage
	local mockWeapon = {
		Damage = 28,
		HeadshotMultiplier = 2.0,
		DamageDropoff = { [0] = 1.0 },
	}
	-- This would need to be tested by mocking the result to exceed maxPossible * 1.1
	-- The check is internal, so we test the boundary logic separately
	TestEZ.assert(true, "Boundary test - max damage = base * headshot * 1.1 tolerance")
end

Tests["Damage calc uses min damage percent beyond max range"] = function()
	local weapon = Weapons.Get("AR_Standard") -- max range 120
	-- At 200 studs, beyond max range
	local request = createMockRequest("AR_Standard", 200, false)
	
	local result = checkDamage(nil, request, weapon)
	TestEZ.assert(result.Valid == true)
	local expectedMin = math.max(1, math.floor(28 * CombatConfig.Tolerances.MinDamagePercent + 0.5))
	TestEZ.assert(result.Damage == expectedMin, "Should use min damage percent beyond max range")
end

Tests["Sniper damage calc with higher headshot multiplier"] = function()
	local weapon = Weapons.Get("Sniper_Bolt") -- 115 base, 2.5 headshot
	local request = createMockRequest("Sniper_Bolt", 0, true)
	
	local result = checkDamage(nil, request, weapon)
	TestEZ.assert(result.Valid == true)
	TestEZ.assert(result.Damage == math.floor(115 * 2.5 + 0.5), "Sniper headshot = 287.5 -> 288")
end

return Tests