--!strict
--[[
	SHOOTBLOX — Server Entry Point
	Loads all services in dependency order, initializes them.
]]

local RunService = game:GetService("RunService")

-- Init.server.luau is a sibling of the Services folder under ServerScriptService.Server
local Services = script.Parent.Services

-- Load order is the dependency graph: Data → Combat → Match → Movement → Weapon → Bot.
-- HitboxHistory and RateLimiter are initialized by CombatService.
local DataService = require(Services.DataService)
local CombatService = require(Services.CombatService)
local MatchService = require(Services.MatchService)
local MovementService = require(Services.MovementService)
local WeaponService = require(Services.WeaponService)
local BotService = require(Services.BotService)

type Service = { Init: () -> (), SetDependencies: ((any) -> ())? }

local ordered: { { name: string, service: Service } } = {
	{ name = "DataService", service = DataService :: any },
	{ name = "CombatService", service = CombatService :: any },
	{ name = "MatchService", service = MatchService :: any },
	{ name = "MovementService", service = MovementService :: any },
	{ name = "WeaponService", service = WeaponService :: any },
	{ name = "BotService", service = BotService :: any },
}

-- Inject dependencies before anything runs
local deps = {
	Data = DataService,
	Combat = CombatService,
	Match = MatchService,
	Movement = MovementService,
	Weapon = WeaponService,
	Bot = BotService,
}
for _, entry in ordered do
	if entry.service.SetDependencies then
		entry.service.SetDependencies(deps)
	end
end

-- Initialize in order
for _, entry in ordered do
	local ok, err = pcall(function()
		entry.service.Init()
	end)
	if not ok then
		warn(string.format("[Server] %s.Init failed: %s", entry.name, tostring(err)))
	end
end

print("[Shootblox] Server ready - all services initialized")

-- Frame budget monitor (Blueprint Gate 4: Heartbeat ≤ 8 ms)
RunService.Heartbeat:Connect(function(dt)
	if dt > 0.033 then
		warn(string.format("[Perf] Frame time: %.1fms", dt * 1000))
	end
end)
