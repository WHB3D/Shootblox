--!strict
--[[
	SHOOTBLOX — Client Entry Point
	Initializes all controllers in dependency order.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MovementController = require(ReplicatedStorage.Client.Controllers.MovementController)
local ViewmodelController = require(ReplicatedStorage.Client.Controllers.ViewmodelController)
local GunController = require(ReplicatedStorage.Client.Controllers.GunController)

local Controllers = {
	MovementController,
	ViewmodelController,
	GunController,
}

for _, controller in Controllers do
	if controller.Init then
		task.spawn(controller.Init)
	end
end

print("[Shootblox] Client ready - all controllers initialized")