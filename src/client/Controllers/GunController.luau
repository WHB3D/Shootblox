--!strict
--[[
	SHOOTBLOX — Gun Controller (Client)
	Handles weapon input, viewmodel coordination, ammo display, fire requests.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")

local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local Net = require(ReplicatedStorage.Shared.Net)
local ViewmodelController = require(script.Parent.ViewmodelController)

local GunController = {}

local currentWeapon: string?
local currentWeaponConfig: any?
local currentSlot: string?

-- Ammo tracking (client-side prediction, server-authoritative)
local currentAmmo = 0
local reserveAmmo = 0
local isReloading = false
local lastFireTime = 0

function GunController.Init()
	-- Listen for weapon equip/unequip
	Net.ClientListen("WeaponEquipped", function(data: { WeaponId: string, Slot: string })
		GunController.EquipWeapon(data.WeaponId, data.Slot)
	end)

	Net.ClientListen("WeaponUnequipped", function(data: { Slot: string })
		GunController.UnequipWeapon(data.Slot)
	end)

	Net.ClientListen("Reloaded", function(data: { WeaponId: string, Ammo: number })
		if data.WeaponId == currentWeapon then
			currentAmmo = data.Ammo
			isReloading = false
			GunController.UpdateAmmoUI()
		end
	end)

	Net.ClientListen("Error", function(data: { Code: string, Message: string })
		if data.Code == "INVALID_AMMO" then
			GunController.HandleEmptyMag()
		end
	end)

	-- Fire input
	ContextActionService:BindAction("Fire", function(_, state)
		if state == Enum.UserInputState.Begin then
			GunController.StartFiring()
		elseif state == Enum.UserInputState.End then
			GunController.StopFiring()
		end
	end, false, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)

	-- Reload input
	ContextActionService:BindAction("Reload", function(_, state)
		if state == Enum.UserInputState.Begin then
			GunController.Reload()
		end
	end, false, Enum.KeyCode.R, Enum.KeyCode.ButtonX)

	-- Weapon swap (1-4 keys; gamepad cycles via R1/L1)
	local slotKeys = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four }
	for i, key in slotKeys do
		ContextActionService:BindAction("WeaponSlot" .. i, function(_, state)
			if state == Enum.UserInputState.Begin then
				GunController.RequestWeaponSwap(i)
			end
		end, false, key)
	end

	-- ADS handled by ViewmodelController (RightShift / MouseButton2)

	-- Fire loop
	RunService.RenderStepped:Connect(function(dt)
		GunController.UpdateFiring(dt)
	end)

	print("[GunController] Initialized")
end

function GunController.EquipWeapon(weaponId: string, slot: string)
	if not Weapons.Get(weaponId) then
		warn("[GunController] Unknown weapon: " .. weaponId)
		return
	end

	currentWeapon = weaponId
	currentSlot = slot
	currentWeaponConfig = Weapons.Get(weaponId)

	-- Initialize ammo
	currentAmmo = currentWeaponConfig.MagSize
	reserveAmmo = currentWeaponConfig.MagSize * 3 -- 3 spare mags
	isReloading = false

	-- Tell viewmodel
	ViewmodelController.EquipWeapon(weaponId)

	-- Update UI
	GunController.UpdateAmmoUI()

	print("[GunController] Equipped " .. weaponId .. " in slot " .. slot)
end

function GunController.UnequipWeapon(slot: string)
	if slot == currentSlot then
		currentWeapon = nil
		currentSlot = nil
		currentWeaponConfig = nil
		currentAmmo = 0
		reserveAmmo = 0
	end
end

function GunController.RequestWeaponSwap(slotIndex: number)
	local slotNames = { "Primary", "Secondary", "Melee", "Utility" }
	local slot = slotNames[slotIndex]
	if slot and slot ~= currentSlot then
		Net.ClientFire("SwapWeapon", { Slot = slot })
	end
end

function GunController.StartFiring()
	if not currentWeapon or not currentWeaponConfig then
		return
	end
	if isReloading then
		return
	end
	if currentAmmo <= 0 then
		GunController.HandleEmptyMag()
		return
	end

	GunController.FireOnce()
end

function GunController.StopFiring()
	-- For automatic weapons, the fire loop handles continuous fire
end

function GunController.UpdateFiring(dt: number)
	if not currentWeapon or not currentWeaponConfig then
		return
	end

	-- Check if we should continue firing (auto weapons)
	local isFiring = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
		or UserInputService:IsKeyDown(Enum.KeyCode.ButtonR2)

	if not isFiring then
		return
	end

	local now = os.clock()
	local fireInterval = 1 / currentWeaponConfig.FireRate

	if now - lastFireTime >= fireInterval then
		GunController.FireOnce()
	end
end

function GunController.FireOnce()
	if not currentWeapon or not currentWeaponConfig then
		return
	end
	if isReloading then
		return
	end
	if currentAmmo <= 0 then
		GunController.HandleEmptyMag()
		return
	end

	-- Decrement ammo locally (prediction)
	currentAmmo -= 1
	lastFireTime = os.clock()

	-- Apply recoil to viewmodel
	ViewmodelController.ApplyRecoil(currentWeaponConfig.RecoilPattern)

	-- Update UI
	GunController.UpdateAmmoUI()

	-- Send fire request to server
	local character = game:GetService("Players").LocalPlayer.Character
	if not character then
		return
	end

	local camera = workspace.CurrentCamera
	local origin = camera.CFrame.Position
	local direction = camera.CFrame.LookVector

	Net.ClientFire("Fire", {
		WeaponId = currentWeapon,
		Origin = origin,
		Direction = direction,
		Timestamp = os.clock(),
		ServerTick = workspace:GetServerTimeNow(),
	})

	-- Play fire sound locally
	-- TODO: Play sound from currentWeaponConfig.Sounds.Fire
end

function GunController.Reload()
	if not currentWeapon or not currentWeaponConfig then
		return
	end
	if isReloading then
		return
	end
	if currentAmmo >= currentWeaponConfig.MagSize then
		return
	end
	if reserveAmmo <= 0 then
		return
	end

	isReloading = true

	-- Play reload animation
	-- TODO: ViewmodelController.PlayAnimation("Reload")

	Net.ClientFire("Reload", { WeaponId = currentWeapon })
end

function GunController.HandleEmptyMag()
	-- Play empty sound
	-- TODO: Play sound from currentWeaponConfig.Sounds.Empty

	-- Auto-reload if possible
	if reserveAmmo > 0 and not isReloading then
		task.wait(0.1)
		GunController.Reload()
	end
end

function GunController.UpdateAmmoUI()
	-- TODO: Update ammo counter in UI
	-- Net.Broadcast("AmmoUpdate", { Current = currentAmmo, Reserve = reserveAmmo })
end

return GunController
