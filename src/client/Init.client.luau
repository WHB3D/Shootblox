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
