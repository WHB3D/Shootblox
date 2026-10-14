--!strict
--[[
	SHOOTBLOX — Server Entry Point
	Loads all services in dependency order, initializes them.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage.Shared.Net)

-- Service load order (dependency graph)
local Services = {
	"DataService",
	"CombatService",
	"MatchService",
	"MovementService",
	"WeaponService",
	-- Add more as we build: EconomyService, AntiCheatService, etc.
}

local LoadedServices = {}

-- Initialize all services
for _, name in Services do
	local module = script[name]
	if module then
		local service = require(module)
		LoadedServices[name] = service
		if service.Init then
			service.Init()
		end
	else
		warn("[Server] Service not found: " .. name)
	end
end

-- Inject dependencies
local DataService = LoadedServices.DataService
local CombatService = LoadedServices.CombatService
local MatchService = LoadedServices.MatchService
local MovementService = LoadedServices.MovementService
local WeaponService = LoadedServices.WeaponService

if CombatService and CombatService.SetDependencies then
	CombatService.SetDependencies({ Data = DataService, Match = MatchService, Movement = MovementService })
end
if MatchService and MatchService.SetDependencies then
	MatchService.SetDependencies({ Data = DataService, Combat = CombatService, Movement = MovementService })
end
if MovementService and MovementService.SetDependencies then
	MovementService.SetDependencies({ Data = DataService, Combat = CombatService, Match = MatchService })
end
if WeaponService and WeaponService.SetDependencies then
	WeaponService.SetDependencies({ Data = DataService, Combat = CombatService, Match = MatchService, Movement = MovementService })
end

-- Global error handler
local function onError(msg, trace)
	warn("[Server Error] " .. msg)
	warn(trace)
end

Net.ServerToClient.Error:Connect(function(player, err)
	-- Already handled by validation
end)

print("[Shootblox] Server ready - all services initialized")

-- Heartbeat monitor
RunService.Heartbeat:Connect(function(dt)
	-- Frame budget check
	if dt > 0.033 then -- >33ms = <30 FPS
		warn(string.format("[Perf] Frame time: %.1fms", dt * 1000))
	end
end)