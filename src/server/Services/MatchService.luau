--!strict
--[[
	SHOOTBLOX — Match Service
	Duel matchmaking, queue, reserved servers, round state machine.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")

local Types = require(ReplicatedStorage.Shared.Types)
local Maps = require(ReplicatedStorage.Shared.Config.Maps)
local CombatConfig = require(ReplicatedStorage.Shared.Config.Combat)
local Net = require(ReplicatedStorage.Shared.Net)

local MatchService = {}

-- Active matches and queues
local ActiveMatches: { [string]: Types.MatchState } = {}
local Queues: { [string]: { Player } } = {
	["1v1"] = {},
	["2v2"] = {},
	["5v5"] = {},
	["FFA"] = {},
}
local PlayerMatch: { [Player]: string } = {}
local MapVotes: { [Player]: string } = {}

-- Match configuration defaults
local DEFAULT_CONFIG: Types.MatchConfig = {
	Mode = "1v1",
	MapId = "Foundry",
	RoundsToWin = CombatConfig.Match.DefaultRoundsToWin,
	RoundTime = CombatConfig.Match.DefaultRoundTime,
	FreezeTime = CombatConfig.Match.DefaultFreezeTime,
	Respawn = false,
	RespawnDelay = CombatConfig.Match.DefaultRespawnDelay,
	Ranked = false,
	Region = "auto",
}

function MatchService.Init()
	-- Queue join/leave
	Net.ClientToServer.QueueJoin:Connect(function(player: Player, data: { Mode: string })
		MatchService.JoinQueue(player, data.Mode)
	end)

	Net.ClientToServer.QueueLeave:Connect(function(player: Player)
		MatchService.LeaveQueue(player)
	end)

	-- Map voting
	Net.ClientToServer.VoteMap:Connect(function(player: Player, data: { MapId: string })
		local map = Maps.Get(data.MapId)
		if map and table.find(map.Modes, MatchService.GetPlayerMatchConfig(player).Mode) then
			MapVotes[player] = data.MapId
		end
	end)

	-- Start matchmaker loop
	task.spawn(MatchService.MatchmakerLoop)

	print("[MatchService] Initialized")
end

function MatchService.GetPlayerMatchConfig(player: Player): Types.MatchConfig
	local matchId = PlayerMatch[player]
	if matchId and ActiveMatches[matchId] then
		return ActiveMatches[matchId].Config
	end
	return DEFAULT_CONFIG
end

function MatchService.JoinQueue(player: Player, mode: string)
	if PlayerMatch[player] then return end -- already in match
	if not Queues[mode] then return end

	-- Leave any other queue
	for _, queue in Queues do
		local idx = table.find(queue, player)
		if idx then table.remove(queue, idx) end
	end

	table.insert(Queues[mode], player)
	Net.ServerFire(player, "State", { State = "Queueing", Data = { Mode = mode, Position = #Queues[mode] } })
	print(string.format("[MatchService] %s joined %s queue (pos %d)", player.Name, mode, #Queues[mode]))
end

function MatchService.LeaveQueue(player: Player)
	for mode, queue in Queues do
		local idx = table.find(queue, player)
		if idx then
			table.remove(queue, idx)
			Net.ServerFire(player, "State", { State = "Lobby", Data = {} })
			print(string.format("[MatchService] %s left %s queue", player.Name, mode))
			return
		end
	end
end

function MatchService.MatchmakerLoop()
	while true do
		task.wait(1)
		for mode, queue in Queues do
			local config = table.clone(DEFAULT_CONFIG)
			config.Mode = mode
			config.MapId = MatchService.PickMap(mode)

			local required = mode == "FFA" and 2 or (mode == "1v1" and 2 or mode == "2v2" and 4 or 10)
			if #queue >= required then
				-- Form match
				local players = {}
				for i = 1, required do
					table.insert(players, table.remove(queue, 1))
				end
				MatchService.CreateMatch(players, config)
			end
		end
	end
end

function MatchService.PickMap(mode: string): string
	local eligible = Maps.GetByMode(mode)
	if #eligible == 0 then return "Foundry" end
	return eligible[math.random(1, #eligible)].Id
end

function MatchService.CreateMatch(players: { Player }, config: Types.MatchConfig)
	local matchId = string.format("match_%d_%s", os.time(), game:GetService("HttpService"):GenerateGUID(false):sub(1, 8))

	-- Assign teams
	local teamAssignments = {}
	if config.Mode == "FFA" then
		for _, p in players do teamAssignments[p] = 0 end
	elseif config.Mode == "1v1" then
		teamAssignments[players[1]] = 1
		teamAssignments[players[2]] = 2
	elseif config.Mode == "2v2" then
		teamAssignments[players[1]] = 1
		teamAssignments[players[2]] = 1
		teamAssignments[players[3]] = 2
		teamAssignments[players[4]] = 2
	elseif config.Mode == "5v5" then
		for i, p in players do
			teamAssignments[p] = i <= 5 and 1 or 2
		end
	end

	-- Reserve server
	local reserveCode = TeleportService:ReserveServer(game.PlaceId)

	-- Build match state
	local matchState: Types.MatchState = {
		Id = matchId,
		Config = config,
		Players = players,
		Teams = teamAssignments,
		State = "Countdown",
		Round = 1,
		Scores = { 0, 0 },
		PlayerStats = {},
		ReserveCode = reserveCode,
		StartTime = workspace:GetServerTimeNow(),
	}

	for _, p in players do
		matchState.PlayerStats[p] = {
			Kills = 0,
			Deaths = 0,
			Damage = 0,
			Headshots = 0,
		}
		PlayerMatch[p] = matchId
	end

	ActiveMatches[matchId] = matchState

	-- Teleport players to match server
	local teleportData = {
		MatchId = matchId,
		Config = config,
		Team = teamAssignments,
	}

	for _, p in players do
		Net.ServerFire(p, "State", { State = "Countdown", Data = { MatchId = matchId, Config = config, Team = teamAssignments[p] } })
		TeleportService:TeleportToPrivateServer(game.PlaceId, reserveCode, { p }, teleportData)
	end

	print(string.format("[MatchService] Created %s (%s) with %d players", matchId, config.Mode, #players))
end

function MatchService.GetMatch(player: Player): Types.MatchState?
	local matchId = PlayerMatch[player]
	return matchId and ActiveMatches[matchId] or nil
end

function MatchService.EndMatch(matchId: string)
	local match = ActiveMatches[matchId]
	if not match then return end

	for _, p in match.Players do
		PlayerMatch[p] = nil
		Net.ServerFire(p, "State", { State = "Lobby", Data = {} })
	end
	ActiveMatches[matchId] = nil
end

return MatchService