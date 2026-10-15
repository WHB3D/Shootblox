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
-- camera viewmodel don't replicate, so the server can't see them)
if game:GetService("ReplicatedStorage"):FindFirstChild("SBSelfTest") then
	task.delay(5, function()
		local player = game:GetService("Players").LocalPlayer
		local gui = player:FindFirstChild("PlayerGui")
		local camera = workspace.CurrentCamera
		local viewmodel = camera and camera:FindFirstChild("Viewmodel")
		local weapon = viewmodel and viewmodel:FindFirstChildWhichIsA("Model")
		print(
			string.format(
				"SBDIAG client hud=%s viewmodel=%s weapon=%s",
				tostring(gui ~= nil and gui:FindFirstChild("ShootbloxHUD") ~= nil),
				tostring(viewmodel ~= nil),
				weapon and weapon.Name or "none"
			)
		)
	end)
end
