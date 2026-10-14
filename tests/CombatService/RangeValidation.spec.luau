--!strict
--[[
	SHOOTBLOX — CombatService Range Validation Tests
	Tests the weapon range check (Check 7)
]]

local TestEZ = require(game:GetService("ReplicatedStorage").Packages.TestEZ)
local CombatConfig = require(game:GetService("ReplicatedStorage").Shared.Config.Combat)
local Weapons = require(game:GetService("ReplicatedStorage").Shared.Config.Weapons)

local function createMockRequest(weaponId: string, range: number)
	return {
		WeaponId = weaponId,
		Origin = Vector3.new(0, 5, 0),
		Direction = Vector3.new(0, 0, -1),
		HitPosition = Vector3.new(0, 5, -range),
		Timestamp = os.clock(),
		ServerTick = workspace:GetServerTimeNow(),
	}
end

local function checkRange(player, request, weapon)
	local range = (request.HitPosition - request.Origin).Magnitude
	if range > weapon.Range + 10 then -- 10 stud tolerance
		return { Valid = false, RejectReason = "INVALID_RANGE" }
	end
	return { Valid = true }
end

local Tests = {}

Tests["Range check passes within weapon range"] = function()
	local weapon = Weapons.Get("AR_Standard") -- 120 range
	local request = createMockRequest("AR_Standard", 100)
	
	local result = checkRange(nil, request, weapon)
	TestEZ.assert(result.Valid == true, "Should pass within range")
end

Tests["Range check passes within tolerance beyond range"] = function()
	local weapon = Weapons.Get("AR_Standard") -- 120 range, +10 tolerance = 130
	local request = createMockRequest("AR_Standard", 125) -- 5 studs over
	
	local result = checkRange(nil, request, weapon)
	TestEZ.assert(result.Valid == true, "Should pass within 10 stud tolerance")
end

Tests["Range check fails beyond tolerance"] = function()
	local weapon = Weapons.Get("AR_Standard") -- 120 range, +10 tolerance = 130
	local request = createMockRequest("AR_Standard", 140) -- 20 studs over
	
	local result = checkRange(nil, request, weapon)
	TestEZ.assert(result.Valid == false, "Should fail beyond tolerance")
	TestEZ.assert(result.RejectReason == "INVALID_RANGE", "Should return INVALID_RANGE code")
end

Tests["Range check works for short range weapons"] = function()
	local weapon = Weapons.Get("Shotgun_Pump") -- 25 range
	local request = createMockRequest("Shotgun_Pump", 20)
	
	local result = checkRange(nil, request, weapon)
	TestEZ.assert(result.Valid == true, "Should pass for shotgun in range")
end

Tests["Range check fails for shotgun beyond range"] = function()
	local weapon = Weapons.Get("Shotgun_Pump") -- 25 range, +10 = 35
	local request = createMockRequest("Shotgun_Pump", 40)
	
	local result = checkRange(nil, request, weapon)
	TestEZ.assert(result.Valid == false, "Should fail for shotgun beyond range")
end

Tests["Range check works for sniper long range"] = function()
	local weapon = Weapons.Get("Sniper_Bolt") -- 300 range
	local request = createMockRequest("Sniper_Bolt", 280)
	
	local result = checkRange(nil, request, weapon)
	TestEZ.assert(result.Valid == true, "Should pass for sniper in range")
end

Tests["Range check at exactly weapon range"] = function()
	local weapon = Weapons.Get("AR_Standard") -- 120 range
	local request = createMockRequest("AR_Standard", 120)
	
	local result = checkRange(nil, request, weapon)
	TestEZ.assert(result.Valid == true, "Should pass at exactly weapon range")
end

Tests["Range check at exactly tolerance boundary"] = function()
	local weapon = Weapons.Get("AR_Standard") -- 120 range, +10 = 130
	local request = createMockRequest("AR_Standard", 130)
	
	local result = checkRange(nil, request, weapon)
	TestEZ.assert(result.Valid == true, "Should pass at exactly tolerance boundary")
end

return Tests