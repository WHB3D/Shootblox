--!strict
--[[
	SHOOTBLOX — Client Entry Point
	Initializes all controllers in dependency order.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MovementController = require(ReplicatedStorage.Client.Controllers.MovementController)
local ViewmodelController = require(ReplicatedStorage.Client.Controllers.ViewmodelController)

local Controllers = {
	MovementController,
	ViewmodelController,
	-- Add more: UIController, GunController, etc.
}

for _, controller in Controllers do
	if controller.Init then
		task.spawn(controller.Init)
	end
end

print("[Shootblox] Client ready - all controllers initialized")