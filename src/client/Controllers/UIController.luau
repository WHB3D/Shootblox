--!strict
--[[
	SHOOTBLOX — UI Controller
	Handles HUD: ammo counter, health, crosshair, kill feed, scoreboard.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Net = require(ReplicatedStorage.Shared.Net)

local UIController = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- UI elements
local screenGui: ScreenGui?
local ammoFrame: Frame?
local ammoText: TextLabel?
local reserveText: TextLabel?
local healthFrame: Frame?
local healthBar: Frame?
local healthText: TextLabel?
local crosshairFrame: Frame?
local killFeedFrame: Frame?
local scoreboardFrame: Frame?

-- State
local currentAmmo = 0
local reserveAmmo = 0
local currentHealth = 100
local maxHealth = 100

function UIController.Init()
	UIController.CreateHUD()
	UIController.BindNetEvents()

	print("[UIController] Initialized")
end

function UIController.CreateHUD()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ShootbloxHUD"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = playerGui

	-- Ammo Counter (bottom right)
	ammoFrame = Instance.new("Frame")
	ammoFrame.Name = "AmmoFrame"
	ammoFrame.Size = UDim2.fromOffset(180, 60)
	ammoFrame.Position = UDim2.new(1, -200, 1, -80)
	ammoFrame.BackgroundTransparency = 0.3
	ammoFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	ammoFrame.BorderSizePixel = 0
	ammoFrame.Parent = screenGui

	local ammoCorner = Instance.new("UICorner")
	ammoCorner.CornerRadius = UDim.new(0, 8)
	ammoCorner.Parent = ammoFrame

	ammoText = Instance.new("TextLabel")
	ammoText.Name = "AmmoText"
	ammoText.Size = UDim2.fromScale(0.6, 1)
	ammoText.Position = UDim2.fromScale(0, 0)
	ammoText.BackgroundTransparency = 1
	ammoText.Text = "30"
	ammoText.TextColor3 = Color3.fromRGB(255, 255, 255)
	ammoText.TextScaled = true
	ammoText.Font = Enum.Font.GothamBold
	ammoText.TextXAlignment = Enum.TextXAlignment.Right
	ammoText.Parent = ammoFrame

	reserveText = Instance.new("TextLabel")
	reserveText.Name = "ReserveText"
	reserveText.Size = UDim2.fromScale(0.4, 1)
	reserveText.Position = UDim2.fromScale(0.6, 0)
	reserveText.BackgroundTransparency = 1
	reserveText.Text = "/ 90"
	reserveText.TextColor3 = Color3.fromRGB(180, 180, 180)
	reserveText.TextScaled = true
	reserveText.Font = Enum.Font.Gotham
	reserveText.TextXAlignment = Enum.TextXAlignment.Left
	reserveText.Parent = ammoFrame

	-- Health Bar (bottom left)
	healthFrame = Instance.new("Frame")
	healthFrame.Name = "HealthFrame"
	healthFrame.Size = UDim2.fromOffset(200, 30)
	healthFrame.Position = UDim2.fromOffset(20, -50)
	healthFrame.AnchorPoint = Vector2.new(0, 1)
	healthFrame.BackgroundTransparency = 0.3
	healthFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	healthFrame.BorderSizePixel = 0
	healthFrame.Parent = screenGui

	local healthCorner = Instance.new("UICorner")
	healthCorner.CornerRadius = UDim.new(0, 6)
	healthCorner.Parent = healthFrame

	healthBar = Instance.new("Frame")
	healthBar.Name = "HealthBar"
	healthBar.Size = UDim2.fromScale(1, 1)
	healthBar.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
	healthBar.BorderSizePixel = 0
	healthBar.Parent = healthFrame

	local healthBarCorner = Instance.new("UICorner")
	healthBarCorner.CornerRadius = UDim.new(0, 6)
	healthBarCorner.Parent = healthBar

	healthText = Instance.new("TextLabel")
	healthText.Name = "HealthText"
	healthText.Size = UDim2.fromScale(1, 1)
	healthText.BackgroundTransparency = 1
	healthText.Text = "100 / 100"
	healthText.TextColor3 = Color3.fromRGB(255, 255, 255)
	healthText.TextScaled = true
	healthText.Font = Enum.Font.GothamBold
	healthText.Parent = healthFrame

	-- Crosshair (center)
	crosshairFrame = Instance.new("Frame")
	crosshairFrame.Name = "CrosshairFrame"
	crosshairFrame.Size = UDim2.fromOffset(40, 40)
	crosshairFrame.Position = UDim2.fromScale(0.5, 0.5)
	crosshairFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	crosshairFrame.BackgroundTransparency = 1
	crosshairFrame.Parent = screenGui

	-- Crosshair lines
	for i = 1, 4 do
		local line = Instance.new("Frame")
		line.Name = "Line" .. i
		line.Size = i % 2 == 1 and UDim2.fromOffset(2, 12) or UDim2.fromOffset(12, 2)
		line.Position = UDim2.fromScale(0.5, 0.5)
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		line.BorderSizePixel = 0
		line.Parent = crosshairFrame

		if i == 1 then
			line.Position = UDim2.fromScale(0.5, 0.2)
		elseif i == 2 then
			line.Position = UDim2.fromScale(0.5, 0.8)
		elseif i == 3 then
			line.Position = UDim2.fromScale(0.2, 0.5)
		elseif i == 4 then
			line.Position = UDim2.fromScale(0.8, 0.5)
		end

		local lineCorner = Instance.new("UICorner")
		lineCorner.CornerRadius = UDim.new(0, 1)
		lineCorner.Parent = line
	end

	-- Kill Feed (top right)
	killFeedFrame = Instance.new("Frame")
	killFeedFrame.Name = "KillFeedFrame"
	killFeedFrame.Size = UDim2.fromOffset(300, 400)
	killFeedFrame.Position = UDim2.new(1, -320, 0, 20)
	killFeedFrame.BackgroundTransparency = 1
	killFeedFrame.Parent = screenGui

	local killFeedLayout = Instance.new("UIListLayout")
	killFeedLayout.SortOrder = Enum.SortOrder.LayoutOrder
	killFeedLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	killFeedLayout.Padding = UDim.new(0, 4)
	killFeedLayout.Parent = killFeedFrame

	-- Scoreboard (hidden by default, toggled with Tab)
	scoreboardFrame = Instance.new("Frame")
	scoreboardFrame.Name = "ScoreboardFrame"
	scoreboardFrame.Size = UDim2.fromScale(0.6, 0.7)
	scoreboardFrame.Position = UDim2.fromScale(0.5, 0.5)
	scoreboardFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	scoreboardFrame.BackgroundTransparency = 0.2
	scoreboardFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
	scoreboardFrame.BorderSizePixel = 0
	scoreboardFrame.Visible = false
	scoreboardFrame.Parent = screenGui

	local scoreboardCorner = Instance.new("UICorner")
	scoreboardCorner.CornerRadius = UDim.new(0, 12)
	scoreboardCorner.Parent = scoreboardFrame

	print("[UIController] HUD created")
end

function UIController.BindNetEvents()
	-- Ammo updates
	Net.ClientListen("AmmoUpdate", function(data: { Current: number, Reserve: number })
		currentAmmo = data.Current
		reserveAmmo = data.Reserve
		UIController.UpdateAmmoDisplay()
	end)

	-- Health updates
	Net.ClientListen("HealthUpdate", function(data: { Current: number, Max: number })
		currentHealth = data.Current
		maxHealth = data.Max
		UIController.UpdateHealthDisplay()
	end)

	-- Kill feed
	Net.ClientListen("KillFeed", function(data: { Killer: string, Victim: string, Weapon: string, Headshot: boolean })
		UIController.AddKillFeedEntry(data.Killer, data.Victim, data.Weapon, data.Headshot)
	end)

	-- Scoreboard
	Net.ClientListen("Scoreboard", function(data: { Players: { any } })
		UIController.UpdateScoreboard(data.Players)
	end)

	-- Scoreboard toggle
	game:GetService("UserInputService").InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Tab then
			scoreboardFrame.Visible = true
		end
	end)
	game:GetService("UserInputService").InputEnded:Connect(function(input, processed)
		if input.KeyCode == Enum.KeyCode.Tab then
			scoreboardFrame.Visible = false
		end
	end)
end

function UIController.UpdateAmmoDisplay()
	if ammoText then
		ammoText.Text = tostring(currentAmmo)
	end
	if reserveText then
		reserveText.Text = "/ " .. tostring(reserveAmmo)
	end

	-- Color change when low
	if ammoText then
		ammoText.TextColor3 = currentAmmo <= 5 and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(255, 255, 255)
	end
end

function UIController.UpdateHealthDisplay()
	if healthBar then
		local percent = math.clamp(currentHealth / maxHealth, 0, 1)
		healthBar.Size = UDim2.fromScale(percent, 1)
		healthBar.BackgroundColor3 = percent > 0.5 and Color3.fromRGB(0, 200, 100)
			or percent > 0.25 and Color3.fromRGB(255, 180, 50)
			or Color3.fromRGB(255, 60, 60)
	end
	if healthText then
		healthText.Text = currentHealth .. " / " .. maxHealth
	end
end

function UIController.AddKillFeedEntry(killer: string, victim: string, weapon: string, headshot: boolean)
	local entry = Instance.new("Frame")
	entry.Size = UDim2.fromOffset(280, 28)
	entry.BackgroundTransparency = 0.3
	entry.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	entry.BorderSizePixel = 0
	entry.LayoutOrder = -tick() -- newest on top
	entry.Parent = killFeedFrame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = entry

	local killerLabel = Instance.new("TextLabel")
	killerLabel.Size = UDim2.fromScale(0.35, 1)
	killerLabel.Position = UDim2.fromScale(0, 0)
	killerLabel.BackgroundTransparency = 1
	killerLabel.Text = killer
	killerLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
	killerLabel.TextScaled = true
	killerLabel.Font = Enum.Font.GothamBold
	killerLabel.TextXAlignment = Enum.TextXAlignment.Right
	killerLabel.Parent = entry

	local weaponIcon = Instance.new("TextLabel")
	weaponIcon.Size = UDim2.fromScale(0.15, 1)
	weaponIcon.Position = UDim2.fromScale(0.35, 0)
	weaponIcon.BackgroundTransparency = 1
	weaponIcon.Text = headshot and "💥 " .. weapon or weapon
	weaponIcon.TextColor3 = headshot and Color3.fromRGB(255, 100, 100) or Color3.fromRGB(200, 200, 200)
	weaponIcon.TextScaled = true
	weaponIcon.Font = Enum.Font.Gotham
	weaponIcon.TextXAlignment = Enum.TextXAlignment.Center
	weaponIcon.Parent = entry

	local victimLabel = Instance.new("TextLabel")
	victimLabel.Size = UDim2.fromScale(0.35, 1)
	victimLabel.Position = UDim2.fromScale(0.5, 0)
	victimLabel.BackgroundTransparency = 1
	victimLabel.Text = victim
	victimLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
	victimLabel.TextScaled = true
	victimLabel.Font = Enum.Font.GothamBold
	victimLabel.TextXAlignment = Enum.TextXAlignment.Left
	victimLabel.Parent = entry

	-- Fade out after 5 seconds
	task.delay(5, function()
		if entry and entry.Parent then
			local tween = TweenService:Create(entry, TweenInfo.new(0.5), { BackgroundTransparency = 1 })
			tween:Play()
			tween.Completed:Wait()
			entry:Destroy()
		end
	end)

	-- Limit kill feed entries
	local children = killFeedFrame:GetChildren()
	if #children > 10 then
		table.sort(children, function(a, b)
			return a.LayoutOrder > b.LayoutOrder
		end)
		for i = 11, #children do
			children[i]:Destroy()
		end
	end
end

function UIController.UpdateScoreboard(players: { any })
	-- Clear existing entries
	for _, child in scoreboardFrame:GetChildren() do
		if child:IsA("Frame") and child.Name ~= "Header" then
			child:Destroy()
		end
	end

	-- Create header if not exists
	if not scoreboardFrame:FindFirstChild("Header") then
		local header = Instance.new("Frame")
		header.Name = "Header"
		header.Size = UDim2.new(1, 0, 0, 40)
		header.BackgroundTransparency = 0.5
		header.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
		header.Parent = scoreboardFrame

		local headers = { "Player", "Team", "Kills", "Deaths", "Score" }
		local positions = { 0.05, 0.25, 0.5, 0.65, 0.85 }
		for i, text in headers do
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(0.2, 1)
			label.Position = UDim2.fromScale(positions[i], 0)
			label.BackgroundTransparency = 1
			label.Text = text
			label.TextColor3 = Color3.fromRGB(180, 180, 180)
			label.TextScaled = true
			label.Font = Enum.Font.GothamBold
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.Parent = header
		end
	end

	-- Sort players by score
	table.sort(players, function(a, b)
		return (a.kills or 0) > (b.kills or 0)
	end)

	for i, p in players do
		local entry = Instance.new("Frame")
		entry.Size = UDim2.new(1, 0, 0, 35)
		entry.Position = UDim2.new(0, 0, 0, 40 + (i - 1) * 35)
		entry.BackgroundTransparency = i % 2 == 0 and 0.3 or 0.5
		entry.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
		entry.Parent = scoreboardFrame

		local data = { p.name, p.team or "FFA", tostring(p.kills or 0), tostring(p.deaths or 0), tostring(p.score or 0) }
		local positions = { 0.05, 0.25, 0.5, 0.65, 0.85 }
		for j, text in data do
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(0.2, 1)
			label.Position = UDim2.fromScale(positions[j], 0)
			label.BackgroundTransparency = 1
			label.Text = text
			label.TextColor3 = Color3.fromRGB(255, 255, 255)
			label.TextScaled = true
			label.Font = Enum.Font.Gotham
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.Parent = entry
		end
	end
end

return UIController