--!strict
--[[
	SHOOTBLOX — Client Entry Point
	Initializes all controllers in dependency order.
]]

local ControllersFolder = script.Parent.Controllers

-- Every controller exposes Init(); the rest of its surface varies.
type Controller = { Init: () -> () }

local Controllers: { Controller } = {
	require(ControllersFolder.MovementController) :: any,
	require(ControllersFolder.ViewmodelController) :: any,
	require(ControllersFolder.GunController) :: any,
	require(ControllersFolder.UIController) :: any,
}

for _, controller in Controllers do
	task.spawn(controller.Init)
end

print("[Shootblox] Client ready - all controllers initialized")

-- Automated Play-mode self-test: report client-only state (PlayerGui and the
-- camera viewmodel don't replicate, so the server can't see them), then fire
-- one real shot through GunController to prove the live client payload
if game:GetService("ReplicatedStorage"):FindFirstChild("SBSelfTest") then
	local player = game:GetService("Players").LocalPlayer
	local GunController = require(ControllersFolder.GunController) :: any

	local function ammoText(): string
		local gui = player:FindFirstChild("PlayerGui")
		local label = gui and gui:FindFirstChild("AmmoText", true)
		return if label and label:IsA("TextLabel") then label.Text else "?"
	end

	task.delay(4, function()
		local gui = player:FindFirstChild("PlayerGui")
		local camera = workspace.CurrentCamera
		local viewmodel = camera and camera:FindFirstChild("Viewmodel")
		local weapon = viewmodel and viewmodel:FindFirstChildWhichIsA("Model")
		print(
			string.format(
				"SBDIAG client hud=%s viewmodel=%s weapon=%s camera=%s ammo=%s",
				tostring(gui ~= nil and gui:FindFirstChild("ShootbloxHUD") ~= nil),
				tostring(viewmodel ~= nil),
				weapon and weapon.Name or "none",
				player.CameraMode.Name,
				ammoText()
			)
		)
	end)

	task.delay(6, function()
		local bot: Model? = nil
		for _, child in workspace:GetChildren() do
			if child:IsA("Model") and child:GetAttribute("IsBot") then
				bot = child
			end
		end
		local head = bot and bot:FindFirstChild("Head")
		local humanoid = bot and bot:FindFirstChildOfClass("Humanoid")
		local camera = workspace.CurrentCamera
		if not bot or not head or not head:IsA("BasePart") or not humanoid or not camera then
			print("SBDIAG client liveshot SKIP no bot")
			return
		end
		local before = humanoid.Health
		camera.CFrame = CFrame.lookAt(camera.CFrame.Position, head.Position)
		GunController.FireOnce()
		task.wait(0.5)
		print(
			string.format(
				"SBDIAG client liveshot at %s dist=%.0f botHP %d -> %d ammo=%s",
				bot.Name,
				(head.Position - camera.CFrame.Position).Magnitude,
				math.floor(before),
				math.floor(humanoid.Health),
				ammoText()
			)
		)
	end)
end
