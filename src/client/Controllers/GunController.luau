--!strict
--[[
	SHOOTBLOX — Gun Controller (Client)
	Input, cosmetic prediction (ammo, recoil), and the Fire request. The client
	raycasts what the player sees and sends it as evidence — target, hit point,
	hit part, server-clock timestamp — and CombatService decides.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")

local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local Net = require(ReplicatedStorage.Shared.Net)
local ViewmodelController = require(script.Parent.ViewmodelController)
local UIController = require(script.Parent.UIController)

local GunController = {}

local player = Players.LocalPlayer
local rng = Random.new()

local currentWeapon: string?
local currentWeaponConfig: Weapons.WeaponConfig?
local currentSlot: string?

-- Ammo: magazine predicted locally; the server's Ammo_<id> attribute is truth
local currentAmmo = 0
local reserveByWeapon: { [string]: number } = {}
local isReloading = false
local lastFireTime = 0
local shotCounter = 0

-- Random direction inside a cone of `degrees` around `direction`
local function applySpread(direction: Vector3, degrees: number): Vector3
	if degrees <= 0 then
		return direction
	end
	local tilt = math.rad(degrees) * math.sqrt(rng:NextNumber())
	local roll = rng:NextNumber() * math.pi * 2
	local frame = CFrame.lookAt(Vector3.zero, direction)
	return (frame * CFrame.Angles(0, 0, roll) * CFrame.Angles(tilt, 0, 0)).LookVector
end

-- The character Model (anything with a Humanoid) a hit part belongs to
local function findCharacter(instance: Instance): Model?
	local model = instance:FindFirstAncestorOfClass("Model")
	while model do
		if model:FindFirstChildOfClass("Humanoid") then
			return model
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return nil
end

function GunController.Init()
	Net.ClientListen("WeaponEquipped", function(data: { WeaponId: string, Slot: string })
		GunController.EquipWeapon(data.WeaponId, data.Slot)
	end)

	Net.ClientListen("WeaponUnequipped", function(data: { Slot: string })
		GunController.UnequipWeapon(data.Slot)
	end)

	Net.ClientListen("Reloaded", function(data: { WeaponId: string, Ammo: number })
		if data.WeaponId == currentWeapon then
			local reserve = reserveByWeapon[data.WeaponId] or 0
			reserveByWeapon[data.WeaponId] = math.max(0, reserve - (data.Ammo - currentAmmo))
			currentAmmo = data.Ammo
			isReloading = false
			GunController.UpdateAmmoUI()
		end
	end)

	Net.ClientListen("Error", function(data: { Code: string, Message: string })
		if data.Code == "INVALID_AMMO" then
			currentAmmo = 0
			GunController.HandleEmptyMag()
		elseif RunService:IsStudio() then
			warn("[GunController] " .. data.Message)
		end
	end)

	ContextActionService:BindAction("Fire", function(_, state)
		if state == Enum.UserInputState.Begin then
			GunController.StartFiring()
		end
	end, false, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)

	ContextActionService:BindAction("Reload", function(_, state)
		if state == Enum.UserInputState.Begin then
			GunController.Reload()
		end
	end, false, Enum.KeyCode.R, Enum.KeyCode.ButtonX)

	-- Weapon swap (1-4 keys)
	local slotKeys = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four }
	for i, key in slotKeys do
		ContextActionService:BindAction("WeaponSlot" .. i, function(_, state)
			if state == Enum.UserInputState.Begin then
				GunController.RequestWeaponSwap(i)
			end
		end, false, key)
	end

	-- ADS handled by ViewmodelController (RightShift / MouseButton2)

	RunService.RenderStepped:Connect(function()
		GunController.UpdateFiring()
	end)

	print("[GunController] Initialized")
end

function GunController.EquipWeapon(weaponId: string, slot: string)
	local config = Weapons.Get(weaponId)
	if not config then
		warn("[GunController] Unknown weapon: " .. weaponId)
		return
	end

	currentWeapon = weaponId
	currentSlot = slot
	currentWeaponConfig = config
	isReloading = false

	-- Pick up where the server says this weapon's magazine is
	local stored = player:GetAttribute("Ammo_" .. weaponId)
	currentAmmo = if typeof(stored) == "number" then stored else config.MagSize
	if reserveByWeapon[weaponId] == nil then
		reserveByWeapon[weaponId] = config.MagSize * 3
	end

	ViewmodelController.EquipWeapon(weaponId)
	GunController.UpdateAmmoUI()

	print("[GunController] Equipped " .. weaponId .. " in slot " .. slot)
end

function GunController.UnequipWeapon(slot: string)
	if slot == currentSlot then
		currentWeapon = nil
		currentSlot = nil
		currentWeaponConfig = nil
		currentAmmo = 0
		GunController.UpdateAmmoUI()
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
	GunController.FireOnce()
end

-- Held trigger: keep firing at the weapon's rate
function GunController.UpdateFiring()
	local config = currentWeaponConfig
	if not config then
		return
	end
	local held = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
		or UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonR2)
	if held and os.clock() - lastFireTime >= 1 / config.FireRate then
		GunController.FireOnce()
	end
end

function GunController.FireOnce()
	local weaponId = currentWeapon
	local config = currentWeaponConfig
	if not weaponId or not config or isReloading then
		return
	end
	if os.clock() - lastFireTime < 1 / config.FireRate then
		return
	end
	if currentAmmo <= 0 then
		GunController.HandleEmptyMag()
		return
	end
	local character = player.Character
	local camera = workspace.CurrentCamera
	if not character or not camera then
		return
	end

	currentAmmo -= 1
	lastFireTime = os.clock()
	shotCounter += 1
	ViewmodelController.ApplyRecoil(config.RecoilPattern)
	GunController.UpdateAmmoUI()

	-- Raycast what this client sees; the server re-checks every claim
	local origin = camera.CFrame.Position
	local direction = applySpread(camera.CFrame.LookVector, config.Spread)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, camera }
	local result = workspace:Raycast(origin, direction * config.Range, params)
	local target = if result then findCharacter(result.Instance) else nil
	local now = workspace:GetServerTimeNow()

	Net.ClientFire("Fire", {
		WeaponId = weaponId,
		Origin = origin,
		Direction = direction,
		Target = target,
		HitPosition = if target and result then result.Position else nil,
		HitNormal = if target and result then result.Normal else nil,
		HitPart = if target and result then result.Instance.Name else nil,
		Timestamp = now,
		ServerTick = now,
		ShotId = player.UserId .. "-" .. shotCounter,
	})

	-- TODO: fire sound from config.Sounds.Fire
end

function GunController.Reload()
	local weaponId = currentWeapon
	local config = currentWeaponConfig
	if not weaponId or not config or isReloading then
		return
	end
	if currentAmmo >= config.MagSize or (reserveByWeapon[weaponId] or 0) <= 0 then
		return
	end
	isReloading = true
	-- TODO: ViewmodelController.PlayAnimation("Reload")
	Net.ClientFire("Reload", { WeaponId = weaponId })
end

function GunController.HandleEmptyMag()
	-- TODO: empty sound from Sounds.Empty
	GunController.UpdateAmmoUI()
	if not isReloading then
		task.delay(0.1, GunController.Reload)
	end
end

function GunController.UpdateAmmoUI()
	local reserve = if currentWeapon then reserveByWeapon[currentWeapon] or 0 else 0
	UIController.SetAmmo(currentAmmo, reserve)
end

return GunController
