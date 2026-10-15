--!strict
--[[
	SHOOTBLOX — Weapon Service (Server)
	Two distinct operations:
	  • Grant  — put a weapon Tool in the player's Backpack for a slot (silent)
	  • Equip  — hold the Tool for a slot and tell the client (WeaponEquipped)
	Only one slot is ever held; the client's viewmodel follows WeaponEquipped.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local Net = require(ReplicatedStorage.Shared.Net)
local DataService = require(script.Parent.DataService)

local WeaponService = {}

local VALID_SLOTS = { Primary = true, Secondary = true, Melee = true, Utility = true }

-- slot -> weaponId per player, and which slot is currently held
local PlayerLoadouts: { [Player]: { [string]: string } } = {}
local ActiveSlot: { [Player]: string } = {}

function WeaponService.SetDependencies(_deps)
	-- DataService is required directly (ownership checks)
end

function WeaponService.Init()
	Net.ClientToServer.WeaponEquipRequest:Connect(function(player: Player, data: { WeaponId: string, Slot: string })
		if typeof(data) == "table" and typeof(data.WeaponId) == "string" and typeof(data.Slot) == "string" then
			WeaponService.HandleEquipRequest(player, data.WeaponId, data.Slot)
		end
	end)

	Net.ClientToServer.WeaponUnequipRequest:Connect(function(player: Player, data: { Slot: string })
		if typeof(data) == "table" and typeof(data.Slot) == "string" then
			WeaponService.RemoveWeapon(player, data.Slot)
		end
	end)

	Net.ClientToServer.SwapWeapon:Connect(function(player: Player, data: { Slot: string })
		if typeof(data) == "table" and typeof(data.Slot) == "string" then
			WeaponService.EquipSlot(player, data.Slot)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		WeaponService.CleanupPlayer(player)
	end)

	print("[WeaponService] Initialized")
end

local function findTool(player: Player, slot: string): Tool?
	local containers: { Instance? } = { player.Character, player:FindFirstChildOfClass("Backpack") }
	for _, container in containers do
		if container then
			for _, child in container:GetChildren() do
				if child:IsA("Tool") and child:GetAttribute("Slot") == slot then
					return child
				end
			end
		end
	end
	return nil
end

-- Grant: build the Tool and put it in the Backpack. No client event.
function WeaponService.GrantWeapon(player: Player, weaponId: string, slot: string)
	local weapon = Weapons.Get(weaponId)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not weapon or not backpack or not VALID_SLOTS[slot] then
		return
	end

	-- Replace whatever was in that slot
	local existing = findTool(player, slot)
	if existing then
		existing:Destroy()
	end

	-- Server-side Tool: Roblox welds Handle to the hand itself (RequiresHandle),
	-- so other clients see the gun. The local player sees the viewmodel instead.
	local tool = Instance.new("Tool")
	tool.Name = weaponId
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ManualActivationOnly = true -- GunController owns input, not Tool.Activated
	tool:SetAttribute("WeaponId", weaponId)
	tool:SetAttribute("Slot", slot)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.3, 0.3, 2)
	handle.Color = Color3.fromRGB(60, 60, 60)
	handle.Material = Enum.Material.Metal
	handle.CanCollide = false
	handle.CanQuery = false -- never eat the owner's own raycasts
	handle.Massless = true
	handle.Parent = tool

	tool.Parent = backpack

	local loadout = PlayerLoadouts[player]
	if not loadout then
		loadout = {}
		PlayerLoadouts[player] = loadout
	end
	loadout[slot] = weaponId

	-- Ammo lives on the attribute CombatService.CheckAmmo reads.
	-- Match-transient: never touches the persisted profile.
	player:SetAttribute("Ammo_" .. weaponId, weapon.MagSize)

	print("[WeaponService] " .. player.Name .. " granted " .. weaponId .. " in " .. slot)
end

-- Equip: hold the slot's Tool and tell the client which weapon is active.
function WeaponService.EquipSlot(player: Player, slot: string)
	if not VALID_SLOTS[slot] then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local tool = findTool(player, slot)
	local weaponId = PlayerLoadouts[player] and PlayerLoadouts[player][slot]
	if not humanoid or not tool or not weaponId then
		return
	end

	humanoid:EquipTool(tool) -- unequips whatever was held
	ActiveSlot[player] = slot
	Net.ServerFire(player, "WeaponEquipped", { WeaponId = weaponId, Slot = slot })
	print("[WeaponService] " .. player.Name .. " equipped " .. weaponId .. " (" .. slot .. ")")
end

-- Client request: change which weapon occupies a slot (loadout change)
function WeaponService.HandleEquipRequest(player: Player, weaponId: string, slot: string)
	local weapon = Weapons.Get(weaponId)
	if not weapon then
		Net.ServerFire(player, "Error", { Code = "INVALID_WEAPON", Message = "Unknown weapon: " .. weaponId })
		return
	end
	if weapon.Slot ~= slot then
		Net.ServerFire(
			player,
			"Error",
			{ Code = "SLOT_MISMATCH", Message = weaponId .. " cannot go in " .. slot .. " slot" }
		)
		return
	end
	if not DataService.OwnsWeapon(player, weaponId) then
		Net.ServerFire(player, "Error", { Code = "NOT_OWNED", Message = "You don't own " .. weaponId })
		return
	end

	local wasActive = ActiveSlot[player] == slot
	WeaponService.GrantWeapon(player, weaponId, slot)
	if wasActive then
		WeaponService.EquipSlot(player, slot)
	end
end

function WeaponService.RemoveWeapon(player: Player, slot: string)
	local tool = findTool(player, slot)
	if tool then
		tool:Destroy()
	end
	if PlayerLoadouts[player] then
		PlayerLoadouts[player][slot] = nil
	end
	if ActiveSlot[player] == slot then
		ActiveSlot[player] = nil
		Net.ServerFire(player, "WeaponUnequipped", { Slot = slot })
	end
end

function WeaponService.GetLoadout(player: Player): { [string]: string }
	return PlayerLoadouts[player] or {}
end

function WeaponService.GetActiveSlot(player: Player): string?
	return ActiveSlot[player]
end

function WeaponService.CleanupPlayer(player: Player)
	PlayerLoadouts[player] = nil
	ActiveSlot[player] = nil
end

return WeaponService
