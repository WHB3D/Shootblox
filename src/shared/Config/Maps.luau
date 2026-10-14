--!strict
--[[
	SHOOTBLOX — Map Configuration (3 curated maps, TTK-banded)
	Pure data: no Roblox globals.
]]

local Types = require(script.Parent.Types)

export type MapSpec = Types.MapSpec

local Maps = {}

-- MAP 1: FOUNDRY (Industrial, Medium, asymmetrical)
-- Converted from store-map, spawn points balanced for 1v1/2v2/5v5
Maps.Foundry = {
	Id = "Foundry",
	Name = "Foundry",
	Symmetrical = false,
	Modes = { "1v1", "2v2", "5v5" },
	Size = "Medium",
	Spawns = {
		-- Team 1 spawns (Alpha)
		Vector3.new(-120, 5, -80),
		Vector3.new(-110, 5, -60),
		Vector3.new(-100, 5, -100),
		Vector3.new(-130, 5, -40),
		Vector3.new(-90, 5, -120),
		-- Team 2 spawns (Omega)
		Vector3.new(120, 5, 80),
		Vector3.new(110, 5, 60),
		Vector3.new(100, 5, 100),
		Vector3.new(130, 5, 40),
		Vector3.new(90, 5, 120),
	},
	Bounds = {
		Min = Vector3.new(-150, -10, -150),
		Max = Vector3.new(150, 60, 150),
	},
	Cover = {
		{ Position = Vector3.new(-40, 3, -20), Size = Vector3.new(8, 6, 8) },
		{ Position = Vector3.new(40, 3, 20), Size = Vector3.new(8, 6, 8) },
		{ Position = Vector3.new(0, 3, -50), Size = Vector3.new(12, 6, 6) },
		{ Position = Vector3.new(0, 3, 50), Size = Vector3.new(12, 6, 6) },
		{ Position = Vector3.new(-80, 3, 0), Size = Vector3.new(6, 6, 12) },
		{ Position = Vector3.new(80, 3, 0), Size = Vector3.new(6, 6, 12) },
	},
} :: MapSpec

-- MAP 2: SKYLINE (Vertical, Large, symmetrical)
-- High-rise rooftops with ziplines, multiple elevations
Maps.Skyline = {
	Id = "Skyline",
	Name = "Skyline",
	Symmetrical = true,
	Modes = { "1v1", "2v2", "5v5" },
	Size = "Large",
	Spawns = {
		-- Team 1 (South rooftops)
		Vector3.new(-100, 50, -140),
		Vector3.new(-60, 50, -120),
		Vector3.new(-140, 50, -100),
		Vector3.new(-80, 50, -160),
		Vector3.new(-120, 50, -80),
		-- Team 2 (North rooftops)
		Vector3.new(100, 50, 140),
		Vector3.new(60, 50, 120),
		Vector3.new(140, 50, 100),
		Vector3.new(80, 50, 160),
		Vector3.new(120, 50, 80),
	},
	Bounds = {
		Min = Vector3.new(-200, 40, -200),
		Max = Vector3.new(200, 80, 200),
	},
	Cover = {
		{ Position = Vector3.new(0, 52, 0), Size = Vector3.new(20, 4, 20) }, -- center helipad
		{ Position = Vector3.new(-60, 52, -20), Size = Vector3.new(8, 4, 8) },
		{ Position = Vector3.new(60, 52, 20), Size = Vector3.new(8, 4, 8) },
		{ Position = Vector3.new(-120, 52, 40), Size = Vector3.new(6, 4, 12) },
		{ Position = Vector3.new(120, 52, -40), Size = Vector3.new(6, 4, 12) },
		{ Position = Vector3.new(0, 52, -80), Size = Vector3.new(12, 4, 6) },
		{ Position = Vector3.new(0, 52, 80), Size = Vector3.new(12, 4, 6) },
	},
} :: MapSpec

-- MAP 3: SHIPPING YARD (Container maze, Small, asymmetrical)
-- Tight corridors, vertical containers, fast-paced
Maps.ShippingYard = {
	Id = "ShippingYard",
	Name = "Shipping Yard",
	Symmetrical = false,
	Modes = { "1v1", "2v2" },
	Size = "Small",
	Spawns = {
		-- Team 1 (West containers)
		Vector3.new(-80, 5, -30),
		Vector3.new(-60, 5, -60),
		Vector3.new(-100, 5, -10),
		Vector3.new(-40, 5, -80),
		-- Team 2 (East containers)
		Vector3.new(80, 5, 30),
		Vector3.new(60, 5, 60),
		Vector3.new(100, 5, 10),
		Vector3.new(40, 5, 80),
	},
	Bounds = {
		Min = Vector3.new(-120, -10, -120),
		Max = Vector3.new(120, 30, 120),
	},
	Cover = {
		{ Position = Vector3.new(-20, 3, 0), Size = Vector3.new(6, 6, 12) },
		{ Position = Vector3.new(20, 3, 0), Size = Vector3.new(6, 6, 12) },
		{ Position = Vector3.new(0, 3, -40), Size = Vector3.new(10, 6, 6) },
		{ Position = Vector3.new(0, 3, 40), Size = Vector3.new(10, 6, 6) },
		{ Position = Vector3.new(-60, 3, -40), Size = Vector3.new(4, 6, 8) },
		{ Position = Vector3.new(60, 3, 40), Size = Vector3.new(4, 6, 8) },
	},
} :: MapSpec

Maps.All = { Maps.Foundry, Maps.Skyline, Maps.ShippingYard }

function Maps.Get(id: string): MapSpec?
	for _, m in Maps.All do
		if m.Id == id then
			return m
		end
	end
	return nil
end

function Maps.GetByMode(mode: string): { MapSpec }
	local result = {}
	for _, m in Maps.All do
		if table.find(m.Modes, mode) then
			table.insert(result, m)
		end
	end
	return result
end

return Maps