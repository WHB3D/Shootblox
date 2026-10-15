--!strict
--[[
	SHOOTBLOX — Weapon Service (Server)
	Handles weapon equip/unequip/swap, ammo management, inventory.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local Net = require(ReplicatedStorage.Shared.Net)
local DataService = require(script.Parent.DataService)

local WeaponService = {}

-- Track equipped weapons per player
local PlayerLoadouts: { [Player]: {
	Primary: string?,
	Secondary: string?,
	Melee: string?,
	Utility: string?,
} } = {}

function WeaponService.SetDependencies(deps)
	-- Store dependencies if needed
end

function WeaponService.Init()
	Net.ClientToServer.WeaponEquipRequest:Connect(function(player: Player, data: { WeaponId: string, Slot: string })
		WeaponService.HandleEquipRequest(player, data.WeaponId, data.Slot)
	end)

	Net.ClientToServer.WeaponUnequipRequest:Connect(function(player: Player, data: { Slot: string })
		WeaponService.HandleUnequipRequest(player, data.Slot)
	end)

	Net.ClientToServer.SwapWeapon:Connect(function(player: Player, data: { Slot: string })
		WeaponService.HandleSwapRequest(player, data.Slot)
	end)

	Players.PlayerRemoving:Connect(function(player)
		WeaponService.CleanupPlayer(player)
	end)

	print("[WeaponService] Initialized")
end

function WeaponService.HandleEquipRequest(player: Player, weaponId: string, slot: string)
	-- Validate weapon exists
	local weapon = Weapons.Get(weaponId)
	if not weapon then
		Net.ServerFire(player, "Error", { Code = "INVALID_WEAPON", Message = "Unknown weapon: " .. weaponId })
		return
	end

	-- Validate slot matches weapon
	if weapon.Slot ~= slot then
		Net.ServerFire(
			player,
			"Error",
			{ Code = "SLOT_MISMATCH", Message = weaponId .. " cannot go in " .. slot .. " slot" }
		)
		return
	end

	-- Check if player owns weapon
	if not DataService.OwnsWeapon(player, weaponId) then
		Net.ServerFire(player, "Error", { Code = "NOT_OWNED", Message = "You don't own " .. weaponId })
		return
	end

	-- Unequip current weapon in that slot
	WeaponService.UnequipWeapon(player, slot)

	-- Equip new weapon
	WeaponService.EquipWeapon(player, weaponId, slot)
end

function WeaponService.EquipWeapon(player: Player, weaponId: string, slot: string)
	local character = player.Character
	if not character then
		return
	end

	-- Create tool on server (for other clients to see)
	local tool = Instance.new("Tool")
	tool.Name = weaponId
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool:SetAttribute("WeaponId", weaponId)
	tool:SetAttribute("Slot", slot)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.3, 0.3, 2)
	handle.Color = Color3.fromRGB(60, 60, 60)
	handle.Material = Enum.Material.Metal
	handle.Anchored = false
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	-- Weld to character (server-side visual)
	-- For first-person, client handles viewmodel; this is for other clients
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	weld.Part1 = handle
	weld.Parent = handle

	tool.Parent = player.Backpack
	tool.Parent = character -- Equip immediately

	-- Update loadout
	if not PlayerLoadouts[player] then
		PlayerLoadouts[player] = { Primary = nil, Secondary = nil, Melee = nil, Utility = nil }
	end
	PlayerLoadouts[player][slot] = weaponId

	-- Tell client to equip viewmodel
	Net.ServerFire(player, "WeaponEquipped", { WeaponId = weaponId, Slot = slot })

	-- Initialize ammo on the player attribute CombatService.CheckAmmo reads.
	-- Ammo is match-transient and must never touch the persisted profile.
	local weapon = Weapons.Get(weaponId)
	if weapon then
		player:SetAttribute("Ammo_" .. weaponId, weapon.MagSize)
	end

	print("[WeaponService] " .. player.Name .. " equipped " .. weaponId .. " in " .. slot)
end

function WeaponService.HandleUnequipRequest(player: Player, slot: string)
	WeaponService.UnequipWeapon(player, slot)
end

function WeaponService.UnequipWeapon(player: Player, slot: string)
	local character = player.Character
	if not character then
		return
	end

	-- Find and remove tool
	for _, tool in character:GetChildren() do
		if tool:IsA("Tool") and tool:GetAttribute("Slot") == slot then
			tool:Destroy()
			break
		end
	end

	for _, tool in player.Backpack:GetChildren() do
		if tool:IsA("Tool") and tool:GetAttribute("Slot") == slot then
			tool:Destroy()
			break
		end
	end

	if PlayerLoadouts[player] then
		PlayerLoadouts[player][slot] = nil
	end

	Net.ServerFire(player, "WeaponUnequipped", { Slot = slot })
end

function WeaponService.HandleSwapRequest(player: Player, slot: string)
	-- Swap to a different weapon in the same slot (from inventory)
	-- For now, just equip the default weapon for that slot
	local defaultLoadout = Weapons.DefaultLoadout
	local weaponId = defaultLoadout[slot]
	if weaponId then
		WeaponService.HandleEquipRequest(player, weaponId, slot)
	end
end

function WeaponService.GetLoadout(
	player: Player
): { Primary: string?, Secondary: string?, Melee: string?, Utility: string? }
	return PlayerLoadouts[player] or { Primary = nil, Secondary = nil, Melee = nil, Utility = nil }
end

function WeaponService.GetEquippedWeapon(player: Player, slot: string): string?
	return PlayerLoadouts[player] and PlayerLoadouts[player][slot]
end

function WeaponService.CleanupPlayer(player: Player)
	PlayerLoadouts[player] = nil
end

return WeaponService
