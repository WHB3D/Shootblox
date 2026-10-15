--!strict
--[[
	SHOOTBLOX — Self-Test (Studio only)
	Runs only when ReplicatedStorage.SBSelfTest exists (the selftest.project.json
	build). Samples the live Play session, prints SBDIAG lines that
	tools/sb-test.sh collects from the Studio log, then ends the session.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SelfTest = {}

local function diag(msg: string)
	print("SBDIAG server " .. msg)
end

local function snapshot(label: string)
	local player = Players:GetPlayers()[1]
	local charInfo, tools = "nochar", {}
	if player then
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hrp and hrp:IsA("BasePart") then
			charInfo = string.format(
				"pos=%.0f,%.0f,%.0f hp=%d",
				hrp.Position.X,
				hrp.Position.Y,
				hrp.Position.Z,
				hum and math.floor(hum.Health) or -1
			)
		end
		if char then
			for _, c in char:GetChildren() do
				if c:IsA("Tool") then
					table.insert(tools, c.Name .. "(eq)")
				end
			end
		end
		for _, c in player.Backpack:GetChildren() do
			table.insert(tools, c.Name)
		end
	end

	local bots = {}
	for _, c in workspace:GetChildren() do
		if c:IsA("Model") and string.find(c.Name, "^Bot_") then
			local h = c:FindFirstChildOfClass("Humanoid")
			table.insert(bots, c.Name .. "=" .. (h and tostring(math.floor(h.Health)) or "?"))
		end
	end

	local net = ReplicatedStorage:FindFirstChild("Net")
	diag(
		string.format(
			"%s arena=%s players=%d char=%s tools=[%s] bots=[%s] remotes=%d",
			label,
			tostring(workspace:FindFirstChild("Arena") ~= nil),
			#Players:GetPlayers(),
			charInfo,
			table.concat(tools, ","),
			table.concat(bots, ","),
			net and #net:GetChildren() or 0
		)
	)
end

-- Gate 3: crafted shots through the real Fire handler. Every cheat must be
-- rejected with zero damage; legit shots must land; only accepted shots
-- spend ammo.
local function probeCombat()
	local CombatService = require(script.Parent.Services.CombatService) :: any
	local BotService = require(script.Parent.Services.BotService) :: any

	local player = Players:GetPlayers()[1]
	local deadline = os.clock() + 8
	local character: any, head: any, bot: any
	repeat
		task.wait(0.25)
		character = player and player.Character
		head = character and character:FindFirstChild("Head")
		bot = BotService.GetBots()[1]
	until (
			head
			and bot
			and character:FindFirstChildOfClass("Tool")
			and not character:FindFirstChildOfClass("ForceField")
		) or os.clock() > deadline
	if not (head and head:IsA("BasePart") and bot) then
		diag("gate3 FAIL setup: no player head, held weapon, or bot")
		return
	end

	-- Freeze the bot 15 studs in front of the player, inside the cover ring
	BotService.SetPaused(true)
	bot:PivotTo(CFrame.new(head.Position.X, 3, head.Position.Z - 15))
	local botHumanoid = bot:FindFirstChildOfClass("Humanoid") :: Humanoid
	botHumanoid.Health = botHumanoid.MaxHealth
	task.wait(0.5) -- settle + let HitboxHistory record the new position

	local botHead = bot:FindFirstChild("Head") :: BasePart
	local weaponId = "AR_Standard"
	local ammoBefore = player:GetAttribute("Ammo_" .. weaponId)

	local function shot(overrides: { [string]: any }): any
		local now = workspace:GetServerTimeNow()
		local request: { [string]: any } = {
			WeaponId = weaponId,
			Origin = head.Position,
			Direction = (botHead.Position - head.Position).Unit,
			Target = bot,
			HitPosition = botHead.Position,
			HitPart = "Head",
			Timestamp = now,
			ServerTick = now,
			ShotId = "selftest",
		}
		for k, v in overrides do
			request[k] = v
		end
		return request
	end

	local failures = {}
	local function expect(label: string, request: any, want: string)
		local result = CombatService.HandleFire(player, request)
		local got = if result.Valid then "OK" else tostring(result.RejectReason)
		diag(
			string.format(
				"gate3 %-15s -> %-17s dmg=%s botHP=%d",
				label,
				got,
				tostring(result.Damage or 0),
				math.floor(botHumanoid.Health)
			)
		)
		if got ~= want then
			table.insert(failures, label .. "(want " .. want .. ", got " .. got .. ")")
		end
		return request
	end

	-- Cheats (bot must stay at 100)
	expect("stale_timestamp", shot({ Timestamp = workspace:GetServerTimeNow() - 2 }), "INVALID_TIMESTAMP")
	local fakeOrigin = head.Position + Vector3.new(40, 0, 0)
	expect(
		"origin_spoof",
		shot({ Origin = fakeOrigin, Direction = (botHead.Position - fakeOrigin).Unit }),
		"INVALID_ORIGIN"
	)
	local fakeHit = botHead.Position + Vector3.new(0, 0, -30)
	expect("hit_spoof", shot({ HitPosition = fakeHit, Direction = (fakeHit - head.Position).Unit }), "INVALID_TARGET")
	local wall = Instance.new("Part")
	wall.Anchored = true
	wall.Size = Vector3.new(8, 8, 1)
	wall.Material = Enum.Material.Concrete
	wall.CFrame = CFrame.lookAt((head.Position + botHead.Position) / 2, botHead.Position)
	wall.Parent = workspace
	expect("wallbang", shot({}), "INVALID_LOS")
	wall:Destroy()
	expect("self_hit", shot({ Target = character, HitPosition = head.Position }), "INVALID_TARGET")
	local hpAfterCheats = botHumanoid.Health

	-- Legit fire: hit, a too-fast follow-up, then a properly spaced kill shot
	local first = expect("legit_1", shot({}), "OK")
	expect("rapid_fire", shot({ Timestamp = first.Timestamp + 0.01 }), "INVALID_RATE")
	task.wait(0.15)
	expect("legit_2", shot({}), "OK")

	local ammoAfter = player:GetAttribute("Ammo_" .. weaponId)
	local spent = if typeof(ammoBefore) == "number" and typeof(ammoAfter) == "number"
		then ammoBefore - ammoAfter
		else -1
	if hpAfterCheats < botHumanoid.MaxHealth then
		table.insert(failures, "cheats dealt damage")
	end
	if botHumanoid.Health > 0 then
		table.insert(failures, "legit shots did not kill")
	end
	if spent ~= 2 then
		table.insert(failures, "ammo spent " .. spent .. " (want 2)")
	end
	diag(string.format("gate3 ammo spent=%d (2 accepted shots)", spent))
	diag(if #failures == 0 then "gate3 PASS" else "gate3 FAIL: " .. table.concat(failures, "; "))

	BotService.SetPaused(false)
end

function SelfTest.run()
	diag("start")

	-- Wait for the real Play client to join
	local deadline = os.clock() + 15
	while #Players:GetPlayers() == 0 and os.clock() < deadline do
		task.wait(0.25)
	end

	for i = 1, 4 do
		task.wait(2)
		snapshot(string.format("t=%ds", i * 2))
	end

	-- After the client's own live shot (Main.client, ~6s) has gone through
	xpcall(probeCombat, function(err)
		diag("gate3 FAIL error: " .. tostring(err))
	end)

	for i = 1, 3 do
		task.wait(2)
		snapshot(string.format("post t=%ds", i * 2))
	end

	diag("end")
	local ok, err = pcall(function()
		game:GetService("StudioTestService"):EndTest("done")
	end)
	if not ok then
		diag("EndTest failed: " .. tostring(err))
	end
end

return SelfTest
