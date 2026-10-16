local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local KeycapVisual = require(Shared:WaitForChild("KeycapVisual"))

-- ClockTime nao replica server→client; sem isso o sol fica no default e a sombra some
do
	local preset = Config.Lighting.Presets[Config.Lighting.Active]
	if preset then
		Lighting.ClockTime = preset.ClockTime
		Lighting.GeographicLatitude = preset.GeographicLatitude
	end
	if Lighting.LightingStyle ~= Enum.LightingStyle.Realistic then
		warn(
			"[Keycap] LightingStyle=",
			tostring(Lighting.LightingStyle),
			"— no Studio: Explorer > Lighting > LightingStyle = Realistic (sombra de objetos)"
		)
	end
end

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "KeycapHUD"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local cash = 0
local rebirths = 0
local nextCost = 1000
local mult = 1
local bag: { { Legend: string, Rarity: string, Event: string } } = {}
local selected: number? = nil

local cashLabel = Instance.new("TextLabel")
cashLabel.Name = "Cash"
cashLabel.Size = UDim2.fromOffset(280, 40)
cashLabel.Position = UDim2.new(0, 16, 0, 16)
cashLabel.BackgroundTransparency = 0.3
cashLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
cashLabel.TextColor3 = Color3.fromRGB(240, 240, 245)
cashLabel.Font = Enum.Font.GothamBold
cashLabel.TextSize = 20
cashLabel.TextXAlignment = Enum.TextXAlignment.Left
cashLabel.Text = " $ 0  |  0/s"
cashLabel.Parent = gui

local pad = Instance.new("UIPadding")
pad.PaddingLeft = UDim.new(0, 12)
pad.Parent = cashLabel

local rebirthLabel = Instance.new("TextLabel")
rebirthLabel.Name = "RebirthInfo"
rebirthLabel.Size = UDim2.fromOffset(280, 32)
rebirthLabel.Position = UDim2.new(0, 16, 0, 64)
rebirthLabel.BackgroundTransparency = 0.3
rebirthLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
rebirthLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
rebirthLabel.Font = Enum.Font.Gotham
rebirthLabel.TextSize = 15
rebirthLabel.TextXAlignment = Enum.TextXAlignment.Left
rebirthLabel.Text = " Rebirth 0  |  x1.00"
rebirthLabel.Parent = gui

local pad3 = Instance.new("UIPadding")
pad3.PaddingLeft = UDim.new(0, 12)
pad3.Parent = rebirthLabel

local rebirthBtn = Instance.new("TextButton")
rebirthBtn.Name = "RebirthButton"
rebirthBtn.Size = UDim2.fromOffset(280, 40)
rebirthBtn.Position = UDim2.new(0, 16, 0, 104)
rebirthBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 90)
rebirthBtn.TextColor3 = Color3.fromRGB(230, 230, 240)
rebirthBtn.Font = Enum.Font.GothamBold
rebirthBtn.TextSize = 16
rebirthBtn.AutoButtonColor = true
rebirthBtn.Text = "Rebirth ($1000)"
rebirthBtn.Parent = gui

-- inventario
local invFrame = Instance.new("Frame")
invFrame.Name = "Inventory"
invFrame.Size = UDim2.fromOffset(280, 256)
invFrame.Position = UDim2.new(0, 16, 0, 156)
invFrame.BackgroundTransparency = 0.25
invFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
invFrame.Parent = gui

local invTitle = Instance.new("TextLabel")
invTitle.Size = UDim2.new(1, -12, 0, 28)
invTitle.Position = UDim2.fromOffset(8, 4)
invTitle.BackgroundTransparency = 1
invTitle.TextColor3 = Color3.fromRGB(220, 220, 230)
invTitle.Font = Enum.Font.GothamBold
invTitle.TextSize = 14
invTitle.TextXAlignment = Enum.TextXAlignment.Left
invTitle.Text = "Inventario (0/" .. Config.Keycap.InventoryMax .. ")"
invTitle.Parent = invFrame

local invScroll = Instance.new("ScrollingFrame")
invScroll.Size = UDim2.new(1, -12, 1, -76)
invScroll.Position = UDim2.fromOffset(6, 34)
invScroll.BackgroundTransparency = 1
invScroll.BorderSizePixel = 0
invScroll.ScrollBarThickness = 4
invScroll.CanvasSize = UDim2.fromOffset(0, 0)
invScroll.Parent = invFrame

local listLayout = Instance.new("UIListLayout")
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding = UDim.new(0, 4)
listLayout.Parent = invScroll

local equipBestBtn = Instance.new("TextButton")
equipBestBtn.Name = "EquipBest"
equipBestBtn.Size = UDim2.new(1, -16, 0, 32)
equipBestBtn.Position = UDim2.new(0, 8, 1, -40)
equipBestBtn.BackgroundColor3 = Color3.fromRGB(70, 110, 90)
equipBestBtn.TextColor3 = Color3.fromRGB(230, 240, 235)
equipBestBtn.Font = Enum.Font.GothamBold
equipBestBtn.TextSize = 14
equipBestBtn.AutoButtonColor = true
equipBestBtn.Text = "Equip Best"
equipBestBtn.Parent = invFrame

local tip = Instance.new("TextLabel")
tip.Size = UDim2.fromOffset(560, 28)
tip.Position = UDim2.new(0.5, -280, 1, -48)
tip.BackgroundTransparency = 1
tip.TextColor3 = Color3.fromRGB(180, 180, 190)
tip.Font = Enum.Font.Gotham
tip.TextSize = 14
tip.Text = "Compre keycaps → encaixe → ande em cima pra coletar  ·  Shift = lock"
tip.Parent = gui

local function rarityColor(id: string): Color3
	for _, r in Config.Keycap.Rarities do
		if r.Id == id then
			return r.Color
		end
	end
	return Color3.fromRGB(200, 200, 210)
end

local function refreshInvUI()
	for _, child in invScroll:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	invTitle.Text = string.format("Inventario (%d/%d)", #bag, Config.Keycap.InventoryMax)
	for i, item in bag do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, -8, 0, 28)
		btn.BackgroundColor3 = if selected == i then Color3.fromRGB(60, 90, 70) else Color3.fromRGB(40, 40, 52)
		btn.TextColor3 = rarityColor(item.Rarity)
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 14
		btn.TextXAlignment = Enum.TextXAlignment.Left
		local label = item.Legend
		if item.Rarity ~= "NoRGB" then
			label ..= "  ·  " .. item.Rarity
		end
		label ..= "  ·  " .. Format.cash(Config.keycapPrice(item.Rarity))
		if item.Event ~= "None" then
			label ..= "  ·  " .. item.Event
		end
		btn.Text = "  " .. label
		btn.LayoutOrder = i
		btn.Parent = invScroll
		btn.MouseButton1Click:Connect(function()
			Remotes.SelectInventory:FireServer(i)
		end)
	end
	invScroll.CanvasSize = UDim2.fromOffset(0, math.max(0, #bag * 32))
end

local function refreshRebirthBtn()
	rebirthBtn.Text = string.format("Rebirth (%s)", Format.cash(nextCost))
	local can = cash >= nextCost
	rebirthBtn.BackgroundColor3 = if can then Color3.fromRGB(90, 140, 80) else Color3.fromRGB(70, 70, 90)
	rebirthBtn.Active = can
end

Remotes.CashUpdated.OnClientEvent:Connect(function(cashAmt: number, cps: number)
	cash = cashAmt
	cashLabel.Text = string.format(" %s  |  %s", Format.cash(cashAmt), Format.moneyPerSec(cps))
	refreshRebirthBtn()
end)

Remotes.InventoryUpdated.OnClientEvent:Connect(function(inventory, selectedIndex: number?)
	bag = inventory or {}
	selected = selectedIndex
	refreshInvUI()
end)

Remotes.RebirthUpdated.OnClientEvent:Connect(function(count: number, cost: number, m: number)
	rebirths = count
	nextCost = cost
	mult = m
	rebirthLabel.Text = string.format(" Rebirth %d  |  x%.2f", rebirths, mult)
	refreshRebirthBtn()
end)

rebirthBtn.MouseButton1Click:Connect(function()
	if cash < nextCost then
		return
	end
	Remotes.RequestRebirth:FireServer()
end)

equipBestBtn.MouseButton1Click:Connect(function()
	Remotes.EquipBest:FireServer()
end)

-- esconde prompts de plots alheios
local function ownerUserId(inst: Instance): number?
	local cur: Instance? = inst
	while cur do
		local id = cur:GetAttribute("OwnerUserId")
		if typeof(id) == "number" then
			return id
		end
		cur = cur.Parent
	end
	return nil
end

local function syncPrompt(prompt: ProximityPrompt)
	prompt.Enabled = ownerUserId(prompt) == player.UserId
end

local function hook(inst: Instance)
	if inst:IsA("ProximityPrompt") then
		syncPrompt(inst)
		inst:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
			syncPrompt(inst)
		end)
	end
end

local world = workspace:WaitForChild("World", 20)
if not world then
	warn("[Keycap] Workspace.World nao apareceu — server provavelmente crashou no boot. Veja Output (F9).")
else
	for _, d in world:GetDescendants() do
		hook(d)
		if d:IsA("Folder") and string.match(d.Name, "^Plot%d+$") then
			d:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
				for _, child in d:GetDescendants() do
					if child:IsA("ProximityPrompt") then
						syncPrompt(child)
					end
				end
			end)
		end
	end

	world.DescendantAdded:Connect(function(inst)
		hook(inst)
		if inst:IsA("Folder") and string.match(inst.Name, "^Plot%d+$") then
			inst:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
				for _, child in inst:GetDescendants() do
					if child:IsA("ProximityPrompt") then
						syncPrompt(child)
					end
				end
			end)
		end
	end)
end

-- FullRGB: rainbow constante (texto + luz)
do
	local RunService = game:GetService("RunService")
	local grads: { [UIGradient]: boolean } = {}
	local lights: { [PointLight]: boolean } = {}

	local function track(inst: Instance)
		if inst:IsA("UIGradient") and inst.Name == "RainbowGrad" then
			grads[inst] = true
		elseif inst:IsA("PointLight") and inst:GetAttribute("AnimateRainbow") == true then
			lights[inst] = true
		end
	end

	for _, d in workspace:GetDescendants() do
		track(d)
	end
	workspace.DescendantAdded:Connect(track)
	workspace.DescendantRemoving:Connect(function(inst)
		if inst:IsA("UIGradient") then
			grads[inst] = nil
		elseif inst:IsA("PointLight") then
			lights[inst] = nil
		end
	end)

	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		local rot = (t * 120) % 360
		local hue = (t * 0.35) % 1
		local lightColor = Color3.fromHSV(hue, 1, 1)
		for grad in grads do
			if grad.Parent then
				grad.Rotation = rot
			else
				grads[grad] = nil
			end
		end
		for light in lights do
			if light.Parent then
				light.Color = lightColor
			else
				lights[light] = nil
			end
		end
	end)
end

-- Dev console (F2): forca summon de keycap / evento
if Config.Dev.Console then
	local UserInputService = game:GetService("UserInputService")
	local rarities = Config.Keycap.Rarities
	local rarityIndex = 1
	local eventIds = { "Gold", "Diamond", "Sunny", "Frozen" }

	local panel = Instance.new("Frame")
	panel.Name = "DevConsole"
	panel.Size = UDim2.fromOffset(260, 320)
	panel.Position = UDim2.new(1, -276, 0, 16)
	panel.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
	panel.BackgroundTransparency = 0.15
	panel.Visible = false
	panel.Parent = gui

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -12, 0, 24)
	title.Position = UDim2.fromOffset(8, 6)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 14
	title.TextColor3 = Color3.fromRGB(255, 200, 80)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "Dev Console (F2)"
	title.Parent = panel

	local legendBox = Instance.new("TextBox")
	legendBox.Name = "Legend"
	legendBox.Size = UDim2.new(1, -16, 0, 28)
	legendBox.Position = UDim2.fromOffset(8, 36)
	legendBox.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
	legendBox.TextColor3 = Color3.new(1, 1, 1)
	legendBox.Font = Enum.Font.Gotham
	legendBox.TextSize = 16
	legendBox.PlaceholderText = "Legend (A-Z / 0-9)"
	legendBox.Text = "A"
	legendBox.ClearTextOnFocus = false
	legendBox.Parent = panel

	local rarityBtn = Instance.new("TextButton")
	rarityBtn.Size = UDim2.new(1, -16, 0, 28)
	rarityBtn.Position = UDim2.fromOffset(8, 70)
	rarityBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 58)
	rarityBtn.TextColor3 = Color3.new(1, 1, 1)
	rarityBtn.Font = Enum.Font.GothamBold
	rarityBtn.TextSize = 14
	rarityBtn.AutoButtonColor = true
	rarityBtn.Parent = panel

	local function refreshRarityBtn()
		local r = rarities[rarityIndex]
		rarityBtn.Text = "Rarity: " .. r.Id
		rarityBtn.TextColor3 = if r.Id == "NoRGB" then Color3.fromRGB(220, 220, 230) else r.Color
	end
	refreshRarityBtn()

	rarityBtn.MouseButton1Click:Connect(function()
		rarityIndex = rarityIndex % #rarities + 1
		refreshRarityBtn()
	end)

	local function fire(dest: string)
		local legend = string.upper(string.gsub(legendBox.Text, "%s+", ""))
		if legend == "" then
			return
		end
		Remotes.DevSummon:FireServer(legend, rarities[rarityIndex].Id, dest)
	end

	local beltBtn = Instance.new("TextButton")
	beltBtn.Size = UDim2.new(0.5, -12, 0, 30)
	beltBtn.Position = UDim2.fromOffset(8, 108)
	beltBtn.BackgroundColor3 = Color3.fromRGB(70, 110, 80)
	beltBtn.TextColor3 = Color3.new(1, 1, 1)
	beltBtn.Font = Enum.Font.GothamBold
	beltBtn.TextSize = 13
	beltBtn.Text = "Esteira"
	beltBtn.Parent = panel
	beltBtn.MouseButton1Click:Connect(function()
		fire("belt")
	end)

	local invBtn = Instance.new("TextButton")
	invBtn.Size = UDim2.new(0.5, -12, 0, 30)
	invBtn.Position = UDim2.new(0.5, 4, 0, 108)
	invBtn.BackgroundColor3 = Color3.fromRGB(70, 90, 130)
	invBtn.TextColor3 = Color3.new(1, 1, 1)
	invBtn.Font = Enum.Font.GothamBold
	invBtn.TextSize = 13
	invBtn.Text = "Inventario"
	invBtn.Parent = panel
	invBtn.MouseButton1Click:Connect(function()
		fire("inv")
	end)

	local fillBtn = Instance.new("TextButton")
	fillBtn.Size = UDim2.new(1, -16, 0, 30)
	fillBtn.Position = UDim2.fromOffset(8, 144)
	fillBtn.BackgroundColor3 = Color3.fromRGB(140, 90, 50)
	fillBtn.TextColor3 = Color3.new(1, 1, 1)
	fillBtn.Font = Enum.Font.GothamBold
	fillBtn.TextSize = 13
	fillBtn.Text = "Fill keyboard"
	fillBtn.Parent = panel
	fillBtn.MouseButton1Click:Connect(function()
		Remotes.DevSummon:FireServer("A", rarities[rarityIndex].Id, "fill")
	end)

	local eventLabel = Instance.new("TextLabel")
	eventLabel.Size = UDim2.new(1, -12, 0, 18)
	eventLabel.Position = UDim2.fromOffset(8, 182)
	eventLabel.BackgroundTransparency = 1
	eventLabel.Font = Enum.Font.GothamBold
	eventLabel.TextSize = 12
	eventLabel.TextColor3 = Color3.fromRGB(180, 180, 190)
	eventLabel.TextXAlignment = Enum.TextXAlignment.Left
	eventLabel.Text = "Summon evento (5 min)"
	eventLabel.Parent = panel

	for i, eventId in eventIds do
		local col = (i - 1) % 2
		local row = math.floor((i - 1) / 2)
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0.5, -12, 0, 28)
		btn.Position = UDim2.new(col * 0.5, if col == 0 then 8 else 4, 0, 204 + row * 32)
		local ev = Config.Keycap.Events[eventId]
		btn.BackgroundColor3 = if ev and ev.Color then ev.Color else Color3.fromRGB(60, 60, 70)
		btn.TextColor3 = Color3.fromRGB(20, 20, 24)
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 13
		btn.Text = eventId
		btn.Parent = panel
		btn.MouseButton1Click:Connect(function()
			Remotes.DevSummonEvent:FireServer(eventId)
		end)
	end

	local hint = Instance.new("TextLabel")
	hint.Size = UDim2.new(1, -12, 0, 18)
	hint.Position = UDim2.fromOffset(8, 274)
	hint.BackgroundTransparency = 1
	hint.Font = Enum.Font.Gotham
	hint.TextSize = 11
	hint.TextColor3 = Color3.fromRGB(140, 140, 150)
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.Text = "Mods nas pecas persistem apos o evento"
	hint.Parent = panel

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.F2 then
			panel.Visible = not panel.Visible
		end
	end)
end

-- Settings: escolher click sound (Assets.ClickSounds)
do
	local SoundService = game:GetService("SoundService")
	local UserInputService = game:GetService("UserInputService")
	local RunService = game:GetService("RunService")
	local TweenService = game:GetService("TweenService")

	local PRESS_DEPTH = 0.45
	local visualPressed: { [Model]: boolean } = {}
	local pressTweens: { [Model]: Tween } = {}
	local localDown: { [Model]: boolean } = {}

	local function applyPressVisual(model: Model, pressed: boolean)
		if visualPressed[model] == pressed then
			return
		end
		local rx = model:GetAttribute("RestX")
		local ry = model:GetAttribute("RestY")
		local rz = model:GetAttribute("RestZ")
		if typeof(rx) ~= "number" or typeof(ry) ~= "number" or typeof(rz) ~= "number" then
			return
		end
		visualPressed[model] = pressed
		local existing = pressTweens[model]
		if existing then
			existing:Cancel()
			pressTweens[model] = nil
		end
		-- press quase snap; release um pouco mais lento
		local alpha = Instance.new("NumberValue")
		alpha.Value = if pressed then 0 else 1
		local conn = alpha.Changed:Connect(function(a)
			KeycapVisual.setCFrame(
				model,
				Vector3.new(rx, ry - a * PRESS_DEPTH, rz),
				Vector3.new(0, 0, -1)
			)
		end)
		local info = TweenInfo.new(
			if pressed then 0.03 else 0.08,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out
		)
		local tw = TweenService:Create(alpha, info, { Value = if pressed then 1 else 0 })
		pressTweens[model] = tw
		tw.Completed:Connect(function()
			conn:Disconnect()
			alpha:Destroy()
			if pressTweens[model] == tw then
				pressTweens[model] = nil
			end
		end)
		tw:Play()
	end

	local function hookKeycapPress(model: Model)
		if model.Name ~= "PlacedKeycap" then
			return
		end
		model:GetAttributeChangedSignal("Pressed"):Connect(function()
			if localDown[model] then
				return
			end
			applyPressVisual(model, model:GetAttribute("Pressed") == true)
		end)
		if model:GetAttribute("Pressed") == true then
			applyPressVisual(model, true)
		end
		model.Destroying:Connect(function()
			visualPressed[model] = nil
			localDown[model] = nil
			local tw = pressTweens[model]
			if tw then
				tw:Cancel()
				pressTweens[model] = nil
			end
		end)
	end

	-- silencia footstep padrao enquanto em cima de keycap
	local mutedFoot = false
	local function setRunningMuted(muted: boolean)
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not hrp then
			return
		end
		local running = hrp:FindFirstChild("Running")
		if running and running:IsA("Sound") then
			if muted then
				if running:GetAttribute("_BaseVol") == nil then
					running:SetAttribute("_BaseVol", running.Volume)
				end
				running.Volume = 0
			else
				local base = running:GetAttribute("_BaseVol")
				running.Volume = if typeof(base) == "number" then base else 0.65
			end
		end
	end

	local function listClickSounds(): { Sound }
		local out: { Sound } = {}
		local assets = ReplicatedStorage:FindFirstChild("Assets")
		local folder = assets and assets:FindFirstChild("ClickSounds")
		if folder then
			for _, c in folder:GetChildren() do
				if c:IsA("Sound") and c.SoundId ~= "" then
					table.insert(out, c)
				end
			end
		end
		-- fallback: qualquer Sound sob Assets
		if #out == 0 and assets then
			for _, c in assets:GetDescendants() do
				if c:IsA("Sound") and c.SoundId ~= "" then
					table.insert(out, c)
				end
			end
		end
		-- fallback final: presets do Config
		if #out == 0 then
			local holder = Instance.new("Folder")
			holder.Name = "LocalClickFallbacks"
			holder.Parent = SoundService
			for _, preset in Config.Sound.Fallbacks do
				local s = Instance.new("Sound")
				s.Name = preset.Name
				s.SoundId = preset.SoundId
				s.Volume = 0.7
				s.Parent = holder
				table.insert(out, s)
			end
		end
		return out
	end

	local clickSounds = listClickSounds()
	local selectedClick = 1

	-- one-shot por clique: clones separados → varias teclas soam juntas
	local function playSelectedClick()
		local src = clickSounds[selectedClick]
		if not src then
			return
		end
		local s = Instance.new("Sound")
		s.Name = "KeyClickOneShot"
		s.SoundId = src.SoundId
		s.Volume = src.Volume
		-- ponytail: ±8% pitch jitter anti-repetição
		s.PlaybackSpeed = src.PlaybackSpeed * (0.92 + math.random() * 0.16)
		s.RollOffMode = Enum.RollOffMode.Linear
		s.Parent = SoundService
		s:Play()
		local life = (src.TimeLength > 0 and src.TimeLength or 1.2) + 0.15
		task.delay(life, function()
			if s.Parent then
				s:Destroy()
			end
		end)
	end

	RunService.Heartbeat:Connect(function()
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not hrp then
			if mutedFoot then
				mutedFoot = false
				setRunningMuted(false)
			end
			local toUp: { Model } = {}
			for model in localDown do
				table.insert(toUp, model)
			end
			for _, model in toUp do
				localDown[model] = nil
				applyPressVisual(model, false)
			end
			return
		end

		local half = Config.Board.Unit * 0.55
		local world = workspace:FindFirstChild("World")
		local standing: { [Model]: boolean } = {}
		local onKey = false
		if world then
			for _, d in world:GetDescendants() do
				if d:IsA("Model") and d.Name == "PlacedKeycap" then
					local pivot = d:GetPivot().Position
					local delta = hrp.Position - pivot
					if math.abs(delta.X) <= half and math.abs(delta.Z) <= half and delta.Y > -2 and delta.Y < 10 then
						standing[d] = true
						onKey = true
					end
				end
			end
		end

		if onKey ~= mutedFoot then
			mutedFoot = onKey
			setRunningMuted(onKey)
		elseif onKey then
			-- RbxCharacterSounds pode recriar/ajustar Volume
			setRunningMuted(true)
		end

		-- press preditivo: visual + som agora; server confere via KeyPress
		for model in standing do
			if not localDown[model] then
				localDown[model] = true
				applyPressVisual(model, true)
				playSelectedClick()
				local slotIndex = model:GetAttribute("SlotIndex")
				if typeof(slotIndex) == "number" then
					Remotes.KeyPress:FireServer(slotIndex)
				end
			end
		end
		local toUp: { Model } = {}
		for model in localDown do
			if not standing[model] then
				table.insert(toUp, model)
			end
		end
		for _, model in toUp do
			localDown[model] = nil
			applyPressVisual(model, false)
		end
	end)

	local worldFolder = workspace:FindFirstChild("World") or workspace
	for _, d in worldFolder:GetDescendants() do
		if d:IsA("Model") then
			hookKeycapPress(d)
		end
	end
	worldFolder.DescendantAdded:Connect(function(d)
		if d:IsA("Model") then
			hookKeycapPress(d)
		end
	end)

	-- fallback se algum caminho server ainda disparar KeyClick
	Remotes.KeyClick.OnClientEvent:Connect(function(count: any)
		local n = if typeof(count) == "number" then math.clamp(math.floor(count), 1, 16) else 1
		for _ = 1, n do
			playSelectedClick()
		end
	end)

	local settingsBtn = Instance.new("TextButton")
	settingsBtn.Name = "SettingsButton"
	settingsBtn.Size = UDim2.fromOffset(100, 32)
	settingsBtn.Position = UDim2.new(1, -116, 0, 16)
	settingsBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 58)
	settingsBtn.TextColor3 = Color3.fromRGB(230, 230, 240)
	settingsBtn.Font = Enum.Font.GothamBold
	settingsBtn.TextSize = 14
	settingsBtn.Text = "Settings"
	settingsBtn.Parent = gui

	local settingsPanel = Instance.new("Frame")
	settingsPanel.Name = "Settings"
	settingsPanel.Size = UDim2.fromOffset(280, 200)
	settingsPanel.Position = UDim2.new(1, -296, 0, 56)
	settingsPanel.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
	settingsPanel.BackgroundTransparency = 0.12
	settingsPanel.Visible = false
	settingsPanel.Parent = gui

	local sTitle = Instance.new("TextLabel")
	sTitle.Size = UDim2.new(1, -16, 0, 28)
	sTitle.Position = UDim2.fromOffset(8, 6)
	sTitle.BackgroundTransparency = 1
	sTitle.Font = Enum.Font.GothamBold
	sTitle.TextSize = 16
	sTitle.TextColor3 = Color3.fromRGB(240, 240, 245)
	sTitle.TextXAlignment = Enum.TextXAlignment.Left
	sTitle.Text = "Click sound"
	sTitle.Parent = settingsPanel

	local sHint = Instance.new("TextLabel")
	sHint.Size = UDim2.new(1, -16, 0, 18)
	sHint.Position = UDim2.fromOffset(8, 32)
	sHint.BackgroundTransparency = 1
	sHint.Font = Enum.Font.Gotham
	sHint.TextSize = 11
	sHint.TextColor3 = Color3.fromRGB(140, 140, 150)
	sHint.TextXAlignment = Enum.TextXAlignment.Left
	sHint.Text = if #clickSounds > 0
		then (#clickSounds .. " sons · preview ao selecionar")
		else "Nenhum som em Assets.ClickSounds"
	sHint.Parent = settingsPanel

	local function refreshButtons()
		for _, child in settingsPanel:GetChildren() do
			if child:IsA("TextButton") and child.Name:match("^ClickOpt") then
				child:Destroy()
			end
		end
		for i, snd in clickSounds do
			local btn = Instance.new("TextButton")
			btn.Name = "ClickOpt" .. i
			btn.Size = UDim2.new(1, -16, 0, 32)
			btn.Position = UDim2.fromOffset(8, 54 + (i - 1) * 38)
			btn.BackgroundColor3 = if i == selectedClick
				then Color3.fromRGB(70, 120, 90)
				else Color3.fromRGB(40, 40, 52)
			btn.TextColor3 = Color3.fromRGB(240, 240, 245)
			btn.Font = Enum.Font.GothamBold
			btn.TextSize = 14
			btn.TextXAlignment = Enum.TextXAlignment.Left
			btn.Text = "  " .. i .. ". " .. snd.Name
			btn.Parent = settingsPanel
			btn.MouseButton1Click:Connect(function()
				selectedClick = i
				refreshButtons()
				playSelectedClick()
			end)
		end
		settingsPanel.Size = UDim2.fromOffset(280, math.max(120, 60 + #clickSounds * 38))
	end
	refreshButtons()

	local function toggleSettings()
		settingsPanel.Visible = not settingsPanel.Visible
	end
	settingsBtn.MouseButton1Click:Connect(toggleSettings)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.F3 then
			toggleSettings()
		end
	end)
end

-- Shift lock: mouse no centro + personagem vira com a camera
do
	local UserInputService = game:GetService("UserInputService")
	local RunService = game:GetService("RunService")

	local locked = false
	-- ponytail: offset classico de ombro; se quiser 1a pessoa/over-shoulder fino, ajusta so aqui
	local OFFSET = Vector3.new(1.75, 0, 0)

	local function applyToChar(char: Model?)
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not hum then
			return
		end
		hum.CameraOffset = if locked then OFFSET else Vector3.zero
		hum.AutoRotate = not locked
	end

	local function setLocked(on: boolean)
		locked = on
		UserInputService.MouseBehavior = if on
			then Enum.MouseBehavior.LockCenter
			else Enum.MouseBehavior.Default
		applyToChar(player.Character)
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
			setLocked(not locked)
		end
	end)

	player.CharacterAdded:Connect(function(char)
		char:WaitForChild("Humanoid")
		applyToChar(char)
	end)

	RunService.RenderStepped:Connect(function()
		if not locked then
			return
		end
		-- TextBox focado: libera mouse pra digitar
		if UserInputService:GetFocusedTextBox() then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			return
		end
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter

		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local cam = workspace.CurrentCamera
		if not hrp or not hum or not cam or hum.Sit then
			return
		end
		local look = cam.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude < 0.05 then
			return
		end
		hrp.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + flat.Unit)
	end)
end
