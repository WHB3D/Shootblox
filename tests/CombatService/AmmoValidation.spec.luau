--!strict
--[[
	SHOOTBLOX — CombatService Ammo Validation Tests
	Tests the server-authoritative ammo check (Check 6)
]]

local TestEZ = require(game:GetService("ReplicatedStorage").Packages.TestEZ)
local CombatConfig = require(game:GetService("ReplicatedStorage").Shared.Config.Combat)
local Weapons = require(game:GetService("ReplicatedStorage").Shared.Config.Weapons)

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
		ShotId = "test"
	}
end

local function checkAmmo(player, request, weapon)
	local currentAmmo = player:GetAttribute("Ammo_" .. request.WeaponId) or weapon.MagSize
	if currentAmmo <= 0 then
		return { Valid = false, RejectReason = "INVALID_AMMO" }
	end

	player:SetAttribute("Ammo_" .. request.WeaponId, currentAmmo - 1)
	return { Valid = true }
end

local Tests = {}

Tests["Ammo check passes when ammo available"] = function()
	local player = createMockPlayer("TestPlayer")
	local weapon = Weapons.Get("AR_Standard") -- 30 mag
	player:SetAttribute("Ammo_AR_Standard", 15)
	
	local request = createMockRequest("AR_Standard")
	local result = checkAmmo(player, request, weapon)
	
	TestEZ.assert(result.Valid == true, "Should pass when ammo > 0")
	TestEZ.assert(player:GetAttribute("Ammo_AR_Standard") == 14, "Should decrement ammo")
end

Tests["Ammo check fails when ammo depleted"] = function()
	local player = createMockPlayer("TestPlayer")
	local weapon = Weapons.Get("AR_Standard")
	player:SetAttribute("Ammo_AR_Standard", 0)
	
	local request = createMockRequest("AR_Standard")
	local result = checkAmmo(player, request, weapon)
	
	TestEZ.assert(result.Valid == false, "Should fail when ammo = 0")
	TestEZ.assert(result.RejectReason == "INVALID_AMMO", "Should return INVALID_AMMO code")
end

Tests["Ammo check initializes to mag size when not set"] = function()
	local player = createMockPlayer("TestPlayer")
	-- Don't set Ammo attribute - should default to mag size
	local weapon = Weapons.Get("AR_Standard") -- 30 mag
	local request = createMockRequest("AR_Standard")
	
	local result = checkAmmo(player, request, weapon)
	
	TestEZ.assert(result.Valid == true, "Should pass with default mag size")
	TestEZ.assert(player:GetAttribute("Ammo_AR_Standard") == 29, "Should initialize to magSize - 1")
end

Tests["Ammo check works for different weapons independently"] = function()
	local player = createMockPlayer("TestPlayer")
	player:SetAttribute("Ammo_AR_Standard", 5)
	player:SetAttribute("Ammo_SMG_Standard", 20)
	
	local arWeapon = Weapons.Get("AR_Standard")
	local smgWeapon = Weapons.Get("SMG_Standard")
	
	local arRequest = createMockRequest("AR_Standard")
	local smgRequest = createMockRequest("SMG_Standard")
	
	local arResult = checkAmmo(player, arRequest, arWeapon)
	local smgResult = checkAmmo(player, smgRequest, smgWeapon)
	
	TestEZ.assert(arResult.Valid == true)
	TestEZ.assert(smgResult.Valid == true)
	TestEZ.assert(player:GetAttribute("Ammo_AR_Standard") == 4)
	TestEZ.assert(player:GetAttribute("Ammo_SMG_Standard") == 19)
end

Tests["Ammo check decrements correctly for multi-shot"] = function()
	local player = createMockPlayer("TestPlayer")
	player:SetAttribute("Ammo_Shotgun_Pump", 8)
	
	local weapon = Weapons.Get("Shotgun_Pump")
	local request = createMockRequest("Shotgun_Pump")
	
	-- Fire 3 times
	for i = 1, 3 do
		local result = checkAmmo(player, request, weapon)
		TestEZ.assert(result.Valid == true, "Shot " .. i .. " should pass")
	end
	
	TestEZ.assert(player:GetAttribute("Ammo_Shotgun_Pump") == 5, "Should decrement 3 times")
end

return Tests
