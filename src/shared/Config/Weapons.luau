--!strict
--[[
	SHOOTBLOX — Weapon Configuration (12 weapons, TTK-banded)
	Pure data: no Roblox globals.
	TTK bands: Close (0-15m), Mid (15-40m), Long (40m+)
]]

local Types = require(script.Parent.Parent.Types)

export type WeaponConfig = Types.WeaponConfig

local Weapons = {}

-- Base stats shared across archetypes
local BASE = {
	HeadshotMultiplier = 2.0,
	MinDamagePercent = 0.1,
}

-- PRIMARY: Assault Rifles (Mid-range kings)
Weapons.AR_Standard = {
	Id = "AR_Standard",
	Name = "M4A1",
	Slot = "Primary",
	Damage = 28,
	FireRate = 10, -- 600 RPM
	Range = 120,
	Spread = 1.2,
	HeadshotMultiplier = BASE.HeadshotMultiplier,
	DamageDropoff = {
		[0] = 1.0,
		[30] = 0.9,
		[60] = 0.75,
		[120] = 0.5,
	},
	MagSize = 30,
	ReloadTime = 2.2,
	ProjectileSpeed = 400,
	ProjectileType = "Hitscan",
	RecoilPattern = {
		Vector2.new(0.02, 0.3),
		Vector2.new(-0.05, 0.35),
		Vector2.new(0.08, 0.4),
		Vector2.new(-0.03, 0.45),
	},
	Sounds = {
		Fire = "rbxassetid://9118823102",
		Reload = "rbxassetid://9118823103",
		Empty = "rbxassetid://9118823104",
	},
	Visuals = {
		MuzzleFlash = "rbxassetid://9118823105",
		Tracer = "rbxassetid://9118823106",
		ImpactEffect = "rbxassetid://9118823107",
	},
} :: WeaponConfig

Weapons.AR_Heavy = {
	Id = "AR_Heavy",
	Name = "AK-47",
	Slot = "Primary",
	Damage = 36,
	FireRate = 8.33, -- 500 RPM
	Range = 100,
	Spread = 1.8,
	HeadshotMultiplier = BASE.HeadshotMultiplier,
	DamageDropoff = {
		[0] = 1.0,
		[25] = 0.85,
		[50] = 0.7,
		[100] = 0.5,
	},
	MagSize = 30,
	ReloadTime = 2.5,
	ProjectileSpeed = 380,
	ProjectileType = "Hitscan",
	RecoilPattern = {
		Vector2.new(0.05, 0.5),
		Vector2.new(-0.1, 0.6),
		Vector2.new(0.12, 0.7),
		Vector2.new(-0.08, 0.8),
	},
	Sounds = {
		Fire = "rbxassetid://9118823108",
		Reload = "rbxassetid://9118823109",
		Empty = "rbxassetid://9118823110",
	},
	Visuals = {
		MuzzleFlash = "rbxassetid://9118823111",
		Tracer = "rbxassetid://9118823112",
		ImpactEffect = "rbxassetid://9118823113",
	},
} :: WeaponConfig

Weapons.AR_Tactical = {
	Id = "AR_Tactical",
	Name = "SCAR-H",
	Slot = "Primary",
	Damage = 32,
	FireRate = 9, -- 540 RPM
	Range = 130,
	Spread = 1.0,
	HeadshotMultiplier = BASE.HeadshotMultiplier,
	DamageDropoff = {
		[0] = 1.0,
		[40] = 0.9,
		[80] = 0.75,
		[130] = 0.55,
	},
	MagSize = 25,
	ReloadTime = 2.3,
	ProjectileSpeed = 420,
	ProjectileType = "Hitscan",
	RecoilPattern = {
		Vector2.new(0.01, 0.25),
		Vector2.new(-0.04, 0.3),
		Vector2.new(0.06, 0.35),
		Vector2.new(-0.02, 0.4),
	},
	Sounds = {
		Fire = "rbxassetid://9118823114",
		Reload = "rbxassetid://9118823115",
		Empty = "rbxassetid://9118823116",
	},
	Visuals = {
		MuzzleFlash = "rbxassetid://9118823117",
		Tracer = "rbxassetid://9118823118",
		ImpactEffect = "rbxassetid://9118823119",
	},
} :: WeaponConfig

-- PRIMARY: SMGs (Close-range beasts)
Weapons.SMG_Standard = {
	Id = "SMG_Standard",
	Name = "MP5",
	Slot = "Primary",
	Damage = 22,
	FireRate = 13.33, -- 800 RPM
	Range = 60,
	Spread = 1.5,
	HeadshotMultiplier = BASE.HeadshotMultiplier,
	DamageDropoff = {
		[0] = 1.0,
		[15] = 0.8,
		[30] = 0.55,
		[60] = 0.3,
	},
	MagSize = 35,
	ReloadTime = 1.8,
	ProjectileSpeed = 350,
	ProjectileType = "Hitscan",
	RecoilPattern = {
		Vector2.new(0.01, 0.2),
		Vector2.new(-0.03, 0.25),
		Vector2.new(0.04, 0.3),
	},
	Sounds = {
		Fire = "rbxassetid://9118823120",
		Reload = "rbxassetid://9118823121",
		Empty = "rbxassetid://9118823122",
	},
	Visuals = {
		MuzzleFlash = "rbxassetid://9118823123",
		Tracer = "rbxassetid://9118823124",
		ImpactEffect = "rbxassetid://9118823125",
	},
} :: WeaponConfig

Weapons.SMG_Compact = {
	Id = "SMG_Compact",
	Name = "MAC-10",
	Slot = "Primary",
	Damage = 20,
	FireRate = 18, -- 1080 RPM
	Range = 40,
	Spread = 2.5,
	HeadshotMultiplier = BASE.HeadshotMultiplier,
	DamageDropoff = {
		[0] = 1.0,
		[10] = 0.7,
		[25] = 0.4,
		[40] = 0.2,
	},
	MagSize = 32,
	ReloadTime = 1.6,
	ProjectileSpeed = 320,
	ProjectileType = "Hitscan",
	RecoilPattern = {
		Vector2.new(0.03, 0.3),
		Vector2.new(-0.06, 0.4),
		Vector2.new(0.08, 0.5),
	},
	Sounds = {
		Fire = "rbxassetid://9118823126",
		Reload = "rbxassetid://9118823127",
		Empty = "rbxassetid://9118823128",
	},
	Visuals = {
		MuzzleFlash = "rbxassetid://9118823129",
		Tracer = "rbxassetid://9118823130",
		ImpactEffect = "rbxassetid://9118823131",
	},
} :: WeaponConfig

-- PRIMARY: Sniper (Long-range precision)
Weapons.Sniper_Bolt = {
	Id = "Sniper_Bolt",
	Name = "AWP",
	Slot = "Primary",
	Damage = 115,
	FireRate = 1.2, -- 72 RPM
	Range = 300,
	Spread = 0.0, -- no spread when scoped
	HeadshotMultiplier = 2.5,
	DamageDropoff = {
		[0] = 1.0,
		[100] = 0.95,
		[200] = 0.9,
		[300] = 0.85,
	},
	MagSize = 5,
	ReloadTime = 3.5,
	ProjectileSpeed = 800,
	ProjectileType = "Hitscan",
	RecoilPattern = {
		Vector2.new(0, 2.0),
	},
	Sounds = {
		Fire = "rbxassetid://9118823132",
		Reload = "rbxassetid://9118823133",
		Empty = "rbxassetid://9118823134",
	},
	Visuals = {
		MuzzleFlash = "rbxassetid://9118823135",
		Tracer = "rbxassetid://9118823136",
		ImpactEffect = "rbxassetid://9118823137",
	},
} :: WeaponConfig

Weapons.Sniper_Semi = {
	Id = "Sniper_Semi",
	Name = "MK11",
	Slot = "Primary",
	Damage = 65,
	FireRate = 3, -- 180 RPM
	Range = 200,
	Spread = 0.2,
	HeadshotMultiplier = 2.2,
	DamageDropoff = {
		[0] = 1.0,
		[75] = 0.9,
		[150] = 0.75,
		[200] = 0.6,
	},
	MagSize = 10,
	ReloadTime = 2.8,
	ProjectileSpeed = 650,
	ProjectileType = "Hitscan",
	RecoilPattern = {
		Vector2.new(0.01, 0.8),
		Vector2.new(-0.02, 1.0),
	},
	Sounds = {
		Fire = "rbxassetid://9118823138",
		Reload = "rbxassetid://9118823139",
		Empty = "rbxassetid://9118823140",
	},
	Visuals = {
		MuzzleFlash = "rbxassetid://9118823141",
		Tracer = "rbxassetid://9118823142",
		ImpactEffect = "rbxassetid://9118823143",
	},
} :: WeaponConfig

-- PRIMARY: Shotgun (Close-range deletion)
Weapons.Shotgun_Pump = {
	Id = "Shotgun_Pump",
	Name = "M870",
	Slot = "Primary",
	Damage = 12, -- per pellet x8 = 96 max
	FireRate = 1.1, -- 66 RPM
	Range = 25,
	Spread = 4.0,
	HeadshotMultiplier = 1.5,
	DamageDropoff = {
		[0] = 1.0,
		[10] = 0.7,
		[20] = 0.4,
		[25] = 0.2,
	},
	MagSize = 8,
	ReloadTime = 0.5, -- per shell
	ProjectileSpeed = 300,
	ProjectileType = "Hitscan",
	RecoilPattern = {
		Vector2.new(0, 3.0),
	},
	Sounds = {
		Fire = "rbxassetid://9118823144",
		Reload = "rbxassetid://9118823145",
		Empty = "rbxassetid://9118823146",
	},
	Visuals = {
		MuzzleFlash = "rbxassetid://9118823147",
		Tracer = "rbxassetid://9118823148",
		ImpactEffect = "rbxassetid://9118823149",
	},
} :: WeaponConfig

-- SECONDARY: Pistols
Weapons.Pistol_Standard = {
	Id = "Pistol_Standard",
	Name = "Glock 17",
	Slot = "Secondary",
	Damage = 26,
	FireRate = 8, -- 480 RPM (semi-auto capped)
	Range = 50,
	Spread = 1.0,
	HeadshotMultiplier = BASE.HeadshotMultiplier,
	DamageDropoff = {
		[0] = 1.0,
		[20] = 0.8,
		[40] = 0.55,
		[50] = 0.35,
	},
	MagSize = 17,
	ReloadTime = 1.5,
	ProjectileSpeed = 380,
	ProjectileType = "Hitscan",
	RecoilPattern = {
		Vector2.new(0, 0.5),
	},
	Sounds = {
		Fire = "rbxassetid://9118823150",
		Reload = "rbxassetid://9118823151",
		Empty = "rbxassetid://9118823152",
	},
	Visuals = {
		MuzzleFlash = "rbxassetid://9118823153",
		Tracer = "rbxassetid://9118823154",
		ImpactEffect = "rbxassetid://9118823155",
	},
} :: WeaponConfig

Weapons.Pistol_Heavy = {
	Id = "Pistol_Heavy",
	Name = "Deagle",
	Slot = "Secondary",
	Damage = 55,
	FireRate = 3.5, -- 210 RPM
	Range = 70,
	Spread = 0.8,
	HeadshotMultiplier = 2.2,
	DamageDropoff = {
		[0] = 1.0,
		[30] = 0.85,
		[50] = 0.7,
		[70] = 0.5,
	},
	MagSize = 7,
	ReloadTime = 2.0,
	ProjectileSpeed = 400,
	ProjectileType = "Hitscan",
	RecoilPattern = {
		Vector2.new(0, 1.8),
	},
	Sounds = {
		Fire = "rbxassetid://9118823156",
		Reload = "rbxassetid://9118823157",
		Empty = "rbxassetid://9118823158",
	},
	Visuals = {
		MuzzleFlash = "rbxassetid://9118823159",
		Tracer = "rbxassetid://9118823160",
		ImpactEffect = "rbxassetid://9118823161",
	},
} :: WeaponConfig

-- MELEE
Weapons.Melee_Knife = {
	Id = "Melee_Knife",
	Name = "Combat Knife",
	Slot = "Melee",
	Damage = 50,
	FireRate = 1.5,
	Range = 4,
	Spread = 0,
	HeadshotMultiplier = 2.0,
	MagSize = 1,
	ReloadTime = 0,
	ProjectileType = "Hitscan",
	Sounds = {
		Fire = "rbxassetid://9118823162",
	},
	Visuals = {
		ImpactEffect = "rbxassetid://9118823163",
	},
} :: WeaponConfig

-- UTILITY
Weapons.Utility_Frag = {
	Id = "Utility_Frag",
	Name = "Frag Grenade",
	Slot = "Utility",
	Damage = 100,
	FireRate = 0.5,
	Range = 20, -- throw range
	Spread = 0,
	HeadshotMultiplier = 1.0,
	MagSize = 1,
	ReloadTime = 4.0, -- cook + throw
	ProjectileSpeed = 30,
	ProjectileType = "Projectile",
	Sounds = {
		Fire = "rbxassetid://9118823164",
	},
	Visuals = {
		ImpactEffect = "rbxassetid://9118823165",
	},
} :: WeaponConfig

-- Default loadout (free starter)
Weapons.DefaultLoadout = {
	Primary = "AR_Standard",
	Secondary = "Pistol_Standard",
	Melee = "Melee_Knife",
	Utility = "Utility_Frag",
}

-- All weapons indexed by ID
Weapons.All = {
	Weapons.AR_Standard,
	Weapons.AR_Heavy,
	Weapons.AR_Tactical,
	Weapons.SMG_Standard,
	Weapons.SMG_Compact,
	Weapons.Sniper_Bolt,
	Weapons.Sniper_Semi,
	Weapons.Shotgun_Pump,
	Weapons.Pistol_Standard,
	Weapons.Pistol_Heavy,
	Weapons.Melee_Knife,
	Weapons.Utility_Frag,
}

function Weapons.Get(id: string): WeaponConfig?
	for _, w in Weapons.All do
		if w.Id == id then
			return w
		end
	end
	return nil
end

function Weapons.GetBySlot(slot: string): { WeaponConfig }
	local result = {}
	for _, w in Weapons.All do
		if w.Slot == slot then
			table.insert(result, w)
		end
	end
	return result
end

return Weapons