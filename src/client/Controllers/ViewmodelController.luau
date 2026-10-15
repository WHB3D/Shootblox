--!strict
--[[
	SHOOTBLOX — Viewmodel Controller
	Handles weapon viewmodel, ADS, sway, bob, recoil animation.
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local Net = require(ReplicatedStorage.Shared.Net)

local ViewmodelController = {}

local camera = workspace.CurrentCamera

-- Viewmodel components (created in Init; nil until then)
local viewmodel: Model
local viewmodelRoot: BasePart
local weaponModel: Model?
local currentWeapon: string?
local currentWeaponConfig: any?

-- ADS state
local isADS = false
local adsProgress = 0
local adsSpeed = 8 -- lerp speed

-- Sway / Bob
local swayPosition = Vector3.zero
local swayRotation = Vector3.zero
local bobCycle = 0

-- Recoil
local recoilOffset = CFrame.identity
local recoilRecoverySpeed = 15

-- Offsets
local HIP_OFFSET = CFrame.new(1.2, -0.8, 1.5)
local ADS_OFFSET = CFrame.new(0, -0.2, 0.5) -- weapon-specific offset applied on top

function ViewmodelController.Init()
	-- Create viewmodel container
	viewmodel = Instance.new("Model")
	viewmodel.Name = "Viewmodel"
	viewmodel.Parent = camera

	viewmodelRoot = Instance.new("Part")
	viewmodelRoot.Name = "Root"
	viewmodelRoot.Transparency = 1
	viewmodelRoot.Anchored = true
	viewmodelRoot.CanCollide = false
	viewmodelRoot.Massless = true
	viewmodelRoot.Size = Vector3.new(0.1, 0.1, 0.1)
	viewmodelRoot.CFrame = camera.CFrame
	viewmodelRoot.Parent = viewmodel

	-- Listen for weapon equip
	Net.ClientListen("WeaponEquipped", function(data: { WeaponId: string, Slot: string })
		ViewmodelController.EquipWeapon(data.WeaponId)
	end)

	Net.ClientListen("WeaponUnequipped", function(data: { Slot: string })
		ViewmodelController.UnequipWeapon()
	end)

	-- ADS input
	game:GetService("ContextActionService"):BindAction("ADS", function(_, state)
		if state == Enum.UserInputState.Begin then
			ViewmodelController.SetADS(true)
		elseif state == Enum.UserInputState.End then
			ViewmodelController.SetADS(false)
		end
	end, false, Enum.KeyCode.RightShift, Enum.UserInputType.MouseButton2)

	-- Render loop
	RunService.RenderStepped:Connect(function(dt)
		ViewmodelController.Update(dt)
	end)

	print("[ViewmodelController] Initialized")
end

function ViewmodelController.EquipWeapon(weaponId: string)
	ViewmodelController.UnequipWeapon()

	currentWeapon = weaponId
	currentWeaponConfig = Weapons.Get(weaponId)

	if not currentWeaponConfig then
		warn("[ViewmodelController] Unknown weapon: " .. weaponId)
		return
	end

	-- TODO: Load viewmodel model from ReplicatedStorage
	-- For now, create a placeholder
	local model = Instance.new("Model")
	model.Name = "Weapon_" .. weaponId
	model.Parent = viewmodel

	-- Create a simple visual placeholder
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.3, 0.3, 2)
	handle.Color = Color3.fromRGB(60, 60, 60)
	handle.Material = Enum.Material.Metal
	handle.Anchored = true
	handle.CanCollide = false
	handle.Massless = true
	handle.CFrame = viewmodelRoot.CFrame * HIP_OFFSET
	handle.Parent = model
	model.PrimaryPart = handle

	weaponModel = model

	print("[ViewmodelController] Equipped " .. weaponId)
end

function ViewmodelController.UnequipWeapon()
	if weaponModel then
		weaponModel:Destroy()
		weaponModel = nil
	end
	currentWeapon = nil
	currentWeaponConfig = nil
	isADS = false
	adsProgress = 0
end

function ViewmodelController.SetADS(ads: boolean)
	if not currentWeapon then
		return
	end
	isADS = ads
end

function ViewmodelController.Update(dt: number)
	if not viewmodel or not viewmodelRoot or not camera then
		return
	end
	if not currentWeapon or not currentWeaponConfig then
		return
	end

	-- Update ADS progress
	local targetProgress = isADS and 1 or 0
	adsProgress = math.clamp(adsProgress + (targetProgress - adsProgress) * adsSpeed * dt, 0, 1)

	-- Calculate base CFrame (camera-relative)
	local baseCFrame = camera.CFrame

	-- Hip/ADS offset interpolation
	local hipOffset = HIP_OFFSET
	local adsOffset = ADS_OFFSET
	if currentWeaponConfig.ViewModelOffset then
		adsOffset = currentWeaponConfig.ViewModelOffset
	end
	local offset = hipOffset:Lerp(adsOffset, adsProgress)

	-- Apply sway
	local swayCF = CFrame.new(swayPosition) * CFrame.Angles(swayRotation.X, swayRotation.Y, swayRotation.Z)

	-- Apply bob
	local bobCF = ViewmodelController.CalculateBob(dt)

	-- Apply recoil
	local recoilCF = recoilOffset

	-- Final viewmodel CFrame
	local finalCF = baseCFrame * offset * swayCF * bobCF * recoilCF

	-- Smooth interpolation, then carry the weapon model with the root
	viewmodelRoot.CFrame = viewmodelRoot.CFrame:Lerp(finalCF, 1 - math.exp(-20 * dt))
	if weaponModel then
		weaponModel:PivotTo(viewmodelRoot.CFrame)
	end

	-- Update sway/bob
	ViewmodelController.UpdateSway(dt)
	ViewmodelController.UpdateRecoil(dt)
end

-- Local character's Humanoid + root, or nil if not spawned
local function getLocalRig(): (Humanoid?, BasePart?)
	local character = game:GetService("Players").LocalPlayer.Character
	if not character then
		return nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart and not rootPart:IsA("BasePart") then
		rootPart = nil
	end
	return humanoid, rootPart :: BasePart?
end

function ViewmodelController.UpdateSway(dt: number)
	local humanoid, rootPart = getLocalRig()

	if not humanoid or not rootPart then
		-- Decay sway when not moving
		swayPosition = swayPosition:Lerp(Vector3.zero, 5 * dt)
		swayRotation = swayRotation:Lerp(Vector3.zero, 5 * dt)
		return
	end

	local moveDir = humanoid.MoveDirection
	local moveSpeed = rootPart.AssemblyLinearVelocity.Magnitude
	local isMoving = moveDir.Magnitude > 0.1

	if isMoving then
		-- Horizontal sway (side to side)
		local sideSway = math.sin(bobCycle * 2) * 0.02 * (moveSpeed / 20)
		-- Vertical sway (up/down)
		local vertSway = math.cos(bobCycle * 2) * 0.01 * (moveSpeed / 20)

		swayPosition = Vector3.new(sideSway, vertSway, 0)
		swayRotation = Vector3.new(0, 0, sideSway * 0.5)

		bobCycle += dt * (moveSpeed / 8)
	else
		-- Decay
		swayPosition = swayPosition:Lerp(Vector3.zero, 8 * dt)
		swayRotation = swayRotation:Lerp(Vector3.zero, 8 * dt)
		bobCycle = bobCycle * 0.95
	end
end

function ViewmodelController.CalculateBob(dt: number): CFrame
	local humanoid, rootPart = getLocalRig()

	if not humanoid or not rootPart then
		return CFrame.identity
	end

	local moveDir = humanoid.MoveDirection
	local moveSpeed = rootPart.AssemblyLinearVelocity.Magnitude
	local isMoving = moveDir.Magnitude > 0.1

	if isMoving then
		bobCycle += dt * (moveSpeed / 6)

		local bobX = math.sin(bobCycle) * 0.03 * (moveSpeed / 20)
		local bobY = math.abs(math.sin(bobCycle * 2)) * 0.02 * (moveSpeed / 20)

		-- Reduce bob when ADS
		local adsMult = 1 - adsProgress * 0.7
		bobX *= adsMult
		bobY *= adsMult

		return CFrame.new(bobX, bobY, 0)
	end

	return CFrame.identity
end

function ViewmodelController.UpdateRecoil(dt: number)
	-- Decay recoil
	recoilOffset = recoilOffset:Lerp(CFrame.identity, recoilRecoverySpeed * dt)
end

function ViewmodelController.ApplyRecoil(recoilPattern: { Vector2 }?)
	if not recoilPattern or #recoilPattern == 0 then
		return
	end

	-- Apply first stage of recoil pattern
	local stage = recoilPattern[1] -- simplified: just first stage
	local pitch = -stage.Y * 0.5 -- up
	local yaw = stage.X * 0.3 -- side

	recoilOffset = recoilOffset * CFrame.Angles(math.rad(pitch), math.rad(yaw), 0)
end

return ViewmodelController
