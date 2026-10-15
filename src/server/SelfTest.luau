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

function SelfTest.run()
	diag("start")

	-- Wait for the real Play client to join
	local deadline = os.clock() + 15
	while #Players:GetPlayers() == 0 and os.clock() < deadline do
		task.wait(0.25)
	end

	for i = 1, 6 do
		task.wait(2)
		snapshot(string.format("t=%ds", i * 2))
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
