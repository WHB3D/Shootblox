--!strict
--[[
	SHOOTBLOX — Economy Configuration (Cosmetics-only, PolicyService-gated)
	Pure data: no Roblox globals.
]]

local Economy = {}

-- Currency definitions
Economy.Currency = {
	Coins = "Coins", -- Earned through play (faucet)
	Keys = "Keys", -- Earned through tasks/contracts (faucet)
	Robux = "Robux", -- Premium only (sink for cosmetics)
	Glory = "Glory", -- Ranked-only (sink for ranked rewards)
}

-- Faucet rates (per match/action)
Economy.Faucets = {
	-- Match rewards
	Elimination = 10,
	HeadshotBonus = 5,
	RoundWin = 15,
	MatchWin = 50,
	MatchPlayed = 20,
	MatchLoss = 8,
	-- Daily/Weekly
	DailyLogin = { 50, 60, 70, 80, 100, 150, 200 }, -- streak 1-7
	DailyTask = 25,
	WeeklyTask = 150,
	-- Ranked
	RankedWin = 30,
	RankedPlacement = { 200, 150, 100, 50 }, -- top 4
	RankedSeasonReward = { 1000, 500, 250, 100 }, -- tier based
}

-- Sink prices (Robux for cosmetics, Keys for weapons)
Economy.Sinks = {
	-- Weapon unlocks (Keys)
	WeaponPrices = {
		AR_Standard = 0, -- free starter
		Pistol_Standard = 0, -- free starter
		Melee_Knife = 0, -- free starter
		Utility_Frag = 0, -- free starter
		AR_Heavy = 600,
		AR_Tactical = 750,
		SMG_Standard = 400,
		SMG_Compact = 350,
		Sniper_Bolt = 1200,
		Sniper_Semi = 900,
		Shotgun_Pump = 500,
		Pistol_Heavy = 450,
	},
	-- Skin cases (Robux)
	CasePrices = {
		Standard = 249,
		Premium = 499,
		Contraband = 999,
	},
	-- Direct shop skins (Robux)
	SkinRarityPrice = {
		Common = 99,
		Uncommon = 199,
		Rare = 299,
		Epic = 449,
		Legendary = 599,
		Mythical = 999,
	},
	-- Battle Pass (Robux)
	BattlePass = {
		Free = 0,
		Premium = 599,
		Contraband = 999,
		LevelSkip = 99, -- per level
	},
}

-- Case drop odds (must sum to 100%, disclosed in UI)
Economy.CaseOdds = {
	Standard = {
		Common = 55.0,
		Uncommon = 25.0,
		Rare = 12.0,
		Epic = 5.0,
		Legendary = 2.5,
		Mythical = 0.5,
	},
	Premium = {
		Common = 30.0,
		Uncommon = 30.0,
		Rare = 20.0,
		Epic = 12.0,
		Legendary = 6.0,
		Mythical = 2.0,
	},
	Contraband = {
		Common = 10.0,
		Uncommon = 20.0,
		Rare = 25.0,
		Epic = 20.0,
		Legendary = 15.0,
		Mythical = 10.0,
	},
}

-- Contract milestones (per weapon)
Economy.ContractMilestones = {
	{ Kills = 50, Reward = { Keys = 25, Skin = "Contract_1" } },
	{ Kills = 150, Reward = { Keys = 50, Skin = "Contract_2" } },
	{ Kills = 300, Reward = { Keys = 100, Skin = "Contract_3" } },
	{ Kills = 500, Reward = { Keys = 200, Skin = "Contract_Gold" } },
	{ Kills = 1000, Reward = { Keys = 500, Skin = "Contract_Diamond" } },
}

-- Daily tasks pool
Economy.DailyTasks = {
	{ Id = "kills_10", Name = "Get 10 eliminations", Type = "Kills", Target = 10, Reward = { Keys = 15 } },
	{ Id = "headshots_5", Name = "Land 5 headshots", Type = "Headshots", Target = 5, Reward = { Keys = 20 } },
	{ Id = "matches_3", Name = "Play 3 matches", Type = "MatchesPlayed", Target = 3, Reward = { Keys = 15 } },
	{ Id = "wins_2", Name = "Win 2 rounds", Type = "RoundWins", Target = 2, Reward = { Keys = 25 } },
	{ Id = "damage_2000", Name = "Deal 2000 damage", Type = "Damage", Target = 2000, Reward = { Keys = 20 } },
	{ Id = "matches_5", Name = "Complete 5 matches", Type = "MatchesCompleted", Target = 5, Reward = { Keys = 30 } },
}

-- Weekly tasks pool
Economy.WeeklyTasks = {
	{ Id = "kills_100", Name = "Get 100 eliminations", Type = "Kills", Target = 100, Reward = { Keys = 200 } },
	{ Id = "headshots_30", Name = "Land 30 headshots", Type = "Headshots", Target = 30, Reward = { Keys = 250 } },
	{ Id = "wins_15", Name = "Win 15 rounds", Type = "RoundWins", Target = 15, Reward = { Keys = 300 } },
	{ Id = "damage_25000", Name = "Deal 25,000 damage", Type = "Damage", Target = 25000, Reward = { Keys = 350 } },
	{
		Id = "ranked_5",
		Name = "Play 5 ranked matches",
		Type = "RankedMatches",
		Target = 5,
		Reward = { Keys = 300, Glory = 100 },
	},
}

-- Anti-dupe / idempotency
Economy.IdempotencyKeys = {
	PurchasePrefix = "purchase_",
	ClaimPrefix = "claim_",
	MaxAgeHours = 168, -- 1 week
}

return Economy
