print("[KeycapConveyor] boot")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- defesa: so varre containers onde free model esconde backdoor.
-- NUNCA tocar StarterPlayer/PlayerModule (camera/controls nativos do Roblox).

local function stripScriptsUnder(root: Instance): number
	local n = 0
	for _, d in root:GetDescendants() do
		if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ModuleScript") then
			warn("[KeycapConveyor] removendo script suspeito:", d:GetFullName())
			d:Destroy()
			n += 1
		end
	end
	return n
end

do
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if not assets then
		assets = Instance.new("Folder")
		assets.Name = "Assets"
		assets.Parent = ReplicatedStorage
	end

	local asmr = assets:FindFirstChild("ASMR")
	if asmr then
		warn("[KeycapConveyor] removendo Assets.ASMR residual")
		asmr:Destroy()
	end

	-- Cap pode ter sido dropado no Workspace; move pra Assets
	local cap = assets:FindFirstChild("Cap")
	if not cap then
		for _, root in { workspace, game:GetService("ServerStorage"), ReplicatedStorage } do
			local found = root:FindFirstChild("Cap", true)
			if found and (found:IsA("Model") or found:IsA("BasePart")) then
				print("[KeycapConveyor] Cap achado em", found:GetFullName(), "→ movendo pra Assets")
				found.Name = "Cap"
				found.Parent = assets
				cap = found
				break
			end
		end
	end

	local clickFolder = assets:FindFirstChild("ClickSounds")
	if not clickFolder then
		clickFolder = Instance.new("Folder")
		clickFolder.Name = "ClickSounds"
		clickFolder.Parent = assets
		print("[KeycapConveyor] coloque 3 Sounds em ReplicatedStorage.Assets.ClickSounds")
	else
		local n = 0
		for _, c in clickFolder:GetChildren() do
			if c:IsA("Sound") then
				n += 1
			end
		end
		print("[KeycapConveyor] ClickSounds:", n)
	end

	local stripped = 0
	stripped += stripScriptsUnder(assets)
	for _, root in { workspace, game:GetService("ServerStorage"), game:GetService("Lighting"), game:GetService("SoundService") } do
		stripped += stripScriptsUnder(root)
	end
	for _, child in ReplicatedStorage:GetChildren() do
		if child.Name ~= "Shared" and child.Name ~= "Assets" then
			stripped += stripScriptsUnder(child)
		end
	end

	if cap and cap.Parent == assets then
		print("[KeycapConveyor] Assets.Cap ok:", cap.ClassName)
	else
		warn("[KeycapConveyor] Assets.Cap nao encontrado — coloque o mesh Cap em ReplicatedStorage.Assets")
	end
	if stripped == 0 then
		print("[KeycapConveyor] varredura de scripts: limpo")
	else
		warn("[KeycapConveyor] varredura removeu", stripped, "scripts — salve o place se quiser persistir")
	end
end

local Shared = ReplicatedStorage:WaitForChild("Shared", 15)
if not Shared then
	warn("[KeycapConveyor] ReplicatedStorage.Shared nao syncou (Rojo). Abortando.")
	return
end

local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local KeycapVisual = require(Shared:WaitForChild("KeycapVisual"))
local Format = require(Shared:WaitForChild("Format"))
local MapWorld = require(script.Parent:WaitForChild("MapWorld"))

-- look: aplica preset de Lighting (skybox + atmosphere + post FX)
do
	local Lighting = game:GetService("Lighting")
	local preset = Config.Lighting.Presets[Config.Lighting.Active]
	assert(preset, "Lighting.Active invalido")

	Lighting.ClockTime = preset.ClockTime
	Lighting.GeographicLatitude = preset.GeographicLatitude
	Lighting.Brightness = preset.Brightness
	Lighting.Ambient = preset.Ambient
	Lighting.OutdoorAmbient = preset.OutdoorAmbient
	Lighting.ColorShift_Top = preset.ColorShift_Top
	Lighting.ColorShift_Bottom = preset.ColorShift_Bottom
	Lighting.EnvironmentDiffuseScale = preset.EnvironmentDiffuseScale
	Lighting.EnvironmentSpecularScale = preset.EnvironmentSpecularScale
	Lighting.GlobalShadows = preset.GlobalShadows
	Lighting.ShadowSoftness = preset.ShadowSoftness
	Lighting.ExposureCompensation = preset.ExposureCompensation
	-- LightingStyle / PrioritizeLightingQuality = RobloxScriptSecurity:
	-- script de jogo NAO consegue setar (pcall falhava em silencio). Tem que ser
	-- Lighting no Explorer do Studio → LightingStyle = Realistic (salva no place).
	local style = Lighting.LightingStyle
	if preset.LightingStyle == "Realistic" and style ~= Enum.LightingStyle.Realistic then
		warn(
			"[KeycapConveyor] Lighting.LightingStyle esta",
			tostring(style),
			"— mude p/ Realistic no Studio (Explorer > Lighting). Sem isso so o player tem sombra."
		)
	end
	print("[KeycapConveyor] lighting preset:", Config.Lighting.Active, "style=", tostring(Lighting.LightingStyle), "shadows=", Lighting.GlobalShadows)

	for _, child in Lighting:GetChildren() do
		if
			child:IsA("Sky")
			or child:IsA("Atmosphere")
			or child:IsA("BloomEffect")
			or child:IsA("ColorCorrectionEffect")
			or child:IsA("SunRaysEffect")
			or child:IsA("ColorGradingEffect")
		then
			child:Destroy()
		end
	end

	local sky = Instance.new("Sky")
	sky.Name = "Sky"
	sky.SkyboxBk = preset.Sky.Bk
	sky.SkyboxDn = preset.Sky.Dn
	sky.SkyboxFt = preset.Sky.Ft
	sky.SkyboxLf = preset.Sky.Lf
	sky.SkyboxRt = preset.Sky.Rt
	sky.SkyboxUp = preset.Sky.Up
	sky.CelestialBodiesShown = preset.Sky.CelestialBodiesShown
	sky.StarCount = preset.Sky.StarCount
	sky.SunAngularSize = preset.Sky.SunAngularSize
	sky.Parent = Lighting

	local atmo = Instance.new("Atmosphere")
	atmo.Density = preset.Atmosphere.Density
	atmo.Offset = preset.Atmosphere.Offset
	atmo.Color = preset.Atmosphere.Color
	atmo.Decay = preset.Atmosphere.Decay
	atmo.Glare = preset.Atmosphere.Glare
	atmo.Haze = preset.Atmosphere.Haze
	atmo.Parent = Lighting

	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "LookCC"
	cc.Brightness = preset.ColorCorrection.Brightness
	cc.Contrast = preset.ColorCorrection.Contrast
	cc.Saturation = preset.ColorCorrection.Saturation
	cc.TintColor = preset.ColorCorrection.TintColor
	cc.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Name = "LookBloom"
	bloom.Intensity = preset.Bloom.Intensity
	bloom.Size = preset.Bloom.Size
	bloom.Threshold = preset.Bloom.Threshold
	bloom.Parent = Lighting

	local rays = Instance.new("SunRaysEffect")
	rays.Name = "LookSunRays"
	rays.Intensity = preset.SunRays.Intensity
	rays.Spread = preset.SunRays.Spread
	rays.Parent = Lighting

	local grading = Instance.new("ColorGradingEffect")
	grading.Name = "LookGrading"
	local toneName = preset.TonemapperPreset or "Default"
	local tone = Enum.TonemapperPreset[toneName]
	if tone == nil then
		warn("[KeycapConveyor] TonemapperPreset invalido:", toneName, "→ Default")
		tone = Enum.TonemapperPreset.Default
	end
	grading.TonemapperPreset = tone
	grading.Parent = Lighting

	local terrain = workspace:FindFirstChildOfClass("Terrain")
	if terrain then
		local clouds = terrain:FindFirstChildOfClass("Clouds")
		if not clouds then
			clouds = Instance.new("Clouds")
			clouds.Parent = terrain
		end
		clouds.Cover = preset.Clouds.Cover
		clouds.Density = preset.Clouds.Density
		clouds.Color = preset.Clouds.Color
	end

	local base = workspace:FindFirstChild("Baseplate")
	if base and base:IsA("BasePart") then
		base.Color = Color3.fromRGB(91, 154, 76)
		base.Material = Enum.Material.Plastic
		base.TopSurface = Enum.SurfaceType.Studs
		base.BottomSurface = Enum.SurfaceType.Inlet
	end
end

export type KeycapData = {
	Legend: string,
	Rarity: string,
	Event: string,
	Accrued: number,
}

export type PlayerState = {
	Cash: number,
	CashPerSec: number,
	Inventory: { KeycapData },
	SelectedIndex: number?, -- 1-based; nil se vazio
	Slots: { KeycapData? },
	Pressed: { [number]: boolean }, -- slotIndex -> tecla afundada
	PlotId: number,
	Rebirths: number,
}

type Plot = {
	Id: number,
	Folder: Folder,
	Owner: Player?,
	SlotParts: { BasePart },
	Keycaps: Folder,
	-- esteira corre em +Z
	BeltStartZ: number,
	BeltEndZ: number,
	BeltY: number,
	BeltX: number,
	SpawnCFrame: CFrame,
	SpawnLocation: SpawnLocation,
}

local state: { [Player]: PlayerState } = {}
local plots: { Plot } = {}
local playerPlot: { [Player]: Plot } = {}

-- evento global: so afeta rolls de spawn/board enquanto ativo; Event nas pecas persiste
local activeEventId = "None"
local activeEventToken = 0

-- ponytail: board chance tem que ser menor que belt; se inverter, upgrade = balancear no Config
assert(Config.Keycap.BoardApplyChance < Config.Keycap.BeltApplyChance, "BoardApplyChance deve ser < BeltApplyChance")

local function rollLegend(): string
	local list = Config.Keycap.LegendList
	local n = #list
	local total = 0
	for i = 1, n do
		total += (n + 1 - i) -- peso inverso ao LetterValue (x=i)
	end
	local roll = math.random() * total
	local acc = 0
	for i = 1, n do
		acc += (n + 1 - i)
		if roll <= acc then
			return list[i]
		end
	end
	return list[1]
end

local function rollRarity()
	local total = 0
	for _, r in Config.Keycap.Rarities do
		total += r.Weight
	end
	local roll = math.random() * total
	local acc = 0
	for _, r in Config.Keycap.Rarities do
		acc += r.Weight
		if roll <= acc then
			return r
		end
	end
	return Config.Keycap.Rarities[1]
end

local function cpsFromSlots(slots: { KeycapData? }): number
	local cps = 0
	for _, cap in slots do
		if cap then
			cps += Config.keycapCps(cap.Legend, cap.Rarity, cap.Event)
		end
	end
	return cps
end

local function rebirthCost(rebirths: number): number
	return Config.Rebirth.BaseCost * (Config.Rebirth.CostMult ^ rebirths)
end

local function cashMult(rebirths: number): number
	return 1 + rebirths * Config.Rebirth.MultPerRebirth
end

local function refreshCps(s: PlayerState)
	s.CashPerSec = cpsFromSlots(s.Slots) * cashMult(s.Rebirths)
end

local function ensureLeaderstats(player: Player): Folder
	local folder = player:FindFirstChild("leaderstats")
	if folder and folder:IsA("Folder") then
		return folder
	end
	folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	folder.Parent = player

	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Value = 0
	rebirths.Parent = folder

	local money = Instance.new("IntValue")
	money.Name = "Cash"
	money.Value = 0
	money.Parent = folder

	return folder
end

local function syncLeaderstats(player: Player)
	local s = state[player]
	if not s then
		return
	end
	local folder = ensureLeaderstats(player)
	local rebirths = folder:FindFirstChild("Rebirths")
	local money = folder:FindFirstChild("Cash")
	if rebirths and rebirths:IsA("IntValue") then
		rebirths.Value = s.Rebirths
	end
	if money and money:IsA("IntValue") then
		money.Value = math.floor(s.Cash)
	end
end

local function pushCash(player: Player)
	local s = state[player]
	if not s then
		return
	end
	Remotes.CashUpdated:FireClient(player, s.Cash, s.CashPerSec)
	syncLeaderstats(player)
end

local function pushInv(player: Player)
	local s = state[player]
	if not s then
		return
	end
	Remotes.InventoryUpdated:FireClient(player, s.Inventory, s.SelectedIndex)
end

local function pushRebirth(player: Player)
	local s = state[player]
	if not s then
		return
	end
	Remotes.RebirthUpdated:FireClient(player, s.Rebirths, rebirthCost(s.Rebirths), cashMult(s.Rebirths))
	syncLeaderstats(player)
end

local function setPlotOwnerAttr(plot: Plot, userId: number?)
	plot.Folder:SetAttribute("OwnerUserId", userId)
	for _, d in plot.Folder:GetDescendants() do
		if d:IsA("ProximityPrompt") then
			d:SetAttribute("OwnerUserId", userId)
		end
	end
end

local function clearPlacedOnSlot(slot: BasePart)
	for _, c in slot:GetChildren() do
		if c:IsA("Model") and c.Name == "PlacedKeycap" then
			c:Destroy()
		end
	end
end

local function setSlotPromptMode(slot: BasePart, mode: "place" | "remove")
	local prompt = slot:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		return
	end
	if mode == "remove" then
		prompt.ActionText = "Remover"
		prompt.ObjectText = "Keycap"
		prompt.HoldDuration = 1
	else
		prompt.ActionText = "Encaixar"
		prompt.ObjectText = "Slot"
		prompt.HoldDuration = 0
	end
end

local function dropInventoryAt(s: PlayerState, index: number): KeycapData?
	local data = s.Inventory[index]
	if not data then
		return nil
	end
	table.remove(s.Inventory, index)
	if #s.Inventory == 0 then
		s.SelectedIndex = nil
	elseif index > #s.Inventory then
		-- removed last; clamp selection
		if s.SelectedIndex and s.SelectedIndex > #s.Inventory then
			s.SelectedIndex = #s.Inventory
		end
	elseif s.SelectedIndex then
		if s.SelectedIndex > index then
			s.SelectedIndex -= 1
		elseif s.SelectedIndex == index then
			-- aponta pro item que ocupou o buraco (ou nil se era o ultimo — ja coberto)
			if s.SelectedIndex > #s.Inventory then
				s.SelectedIndex = #s.Inventory
			end
		end
	end
	return data
end

local function capCps(data: KeycapData): number
	return Config.keycapCps(data.Legend, data.Rarity, data.Event)
end

-- pool (inv + board) → board = melhores em CPS crescente; resto (piores) no inventário
local function splitBestForBoard(pool: { KeycapData }, slotCount: number, invMax: number): ({ KeycapData }, { KeycapData })
	table.sort(pool, function(a, b)
		return capCps(a) < capCps(b)
	end)
	local keep = math.min(#pool, slotCount)
	local board: { KeycapData } = {}
	local inv: { KeycapData } = {}
	local startBoard = #pool - keep + 1
	for i, cap in pool do
		cap.Accrued = 0
		if i >= startBoard then
			table.insert(board, cap)
		else
			table.insert(inv, cap)
		end
	end
	-- overflow raro: descarta as piores do que sobrou
	while #inv > invMax do
		table.remove(inv, 1)
	end
	return board, inv
end

do
	local function fake(legend: string, rarity: string): KeycapData
		return { Legend = legend, Rarity = rarity, Event = "None", Accrued = 0 }
	end
	local board, inv = splitBestForBoard({
		fake("A", "NoRGB"), -- cps baixo
		fake("Z", "FullRGB"), -- cps alto
		fake("M", "Red"),
	}, 2, 24)
	assert(#board == 2 and #inv == 1, "equipBest: keep=slots")
	assert(capCps(board[1]) <= capCps(board[2]), "equipBest: board crescente")
	assert(capCps(inv[1]) <= capCps(board[1]), "equipBest: piores no inv")
end

local function resetBoardVisual(plot: Plot)
	for _, slot in plot.SlotParts do
		clearPlacedOnSlot(slot)
		slot.Color = Config.Board.WellColor
		setSlotPromptMode(slot, "place")
	end
end

local function clearBelt(plot: Plot)
	plot.Keycaps:ClearAllChildren()
end

-- visual de press e client-side; server so seta atributo pra sync/spectators
local function placeKeycapOnSlot(slot: BasePart, data: KeycapData)
	clearPlacedOnSlot(slot)
	data.Accrued = data.Accrued or 0
	local xz = slot.Size.X * 0.97
	local h = xz * (Config.Keycap.Size.Y / Config.Keycap.Size.X)
	local size = Vector3.new(xz, h, xz)
	local rarity = Config.rarityEntry(data.Rarity)
	local model = KeycapVisual.create(
		size,
		data.Legend,
		rarity.Color,
		data.Rarity,
		data.Event,
		90,
		Format.cash(data.Accrued)
	)
	model.Name = "PlacedKeycap"
	model:SetAttribute("Legend", data.Legend)
	model:SetAttribute("Rarity", data.Rarity)
	model:SetAttribute("Event", data.Event)
	model:SetAttribute("SlotIndex", slot:GetAttribute("SlotIndex"))
	model.Parent = slot
	local pos = slot.Position + Vector3.new(0, slot.Size.Y * 0.5 + h * 0.5 + 0.02, 0)
	KeycapVisual.setCFrame(model, pos, Vector3.new(0, 0, -1))
	model:SetAttribute("RestX", pos.X)
	model:SetAttribute("RestY", pos.Y)
	model:SetAttribute("RestZ", pos.Z)
	model:SetAttribute("Pressed", false)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanTouch = true
			d.CanCollide = false
		end
	end
	setSlotPromptMode(slot, "remove")
end

local function setKeyPressed(model: Model, pressed: boolean)
	if model:GetAttribute("Pressed") == pressed then
		return
	end
	model:SetAttribute("Pressed", pressed)
end

-- coleta dinheiro (som/visual no client)
local function collectFromSlot(player: Player, plot: Plot, slotIndex: number)
	local s = state[player]
	if not s or plot.Owner ~= player then
		return
	end
	local data = s.Slots[slotIndex]
	if not data or data.Accrued <= 0 then
		return
	end
	local gained = data.Accrued
	data.Accrued = 0
	s.Cash += gained
	local slot = plot.SlotParts[slotIndex]
	local model = slot and slot:FindFirstChild("PlacedKeycap")
	if model and model:IsA("Model") then
		KeycapVisual.setAccrued(model, 0)
	end
end

local function pressSlot(player: Player, plot: Plot, slotIndex: number, silent: boolean?)
	local s = state[player]
	if not s then
		return
	end
	local slot = plot.SlotParts[slotIndex]
	local model = slot and slot:FindFirstChild("PlacedKeycap")
	if model and model:IsA("Model") then
		setKeyPressed(model, true)
	end
	if not silent then
		Remotes.KeyClick:FireClient(player, 1)
	end
	collectFromSlot(player, plot, slotIndex)
	s.Pressed[slotIndex] = true
end

local function releaseSlot(player: Player, plot: Plot, slotIndex: number)
	local s = state[player]
	if not s then
		return
	end
	local slot = plot.SlotParts[slotIndex]
	local model = slot and slot:FindFirstChild("PlacedKeycap")
	if model and model:IsA("Model") then
		setKeyPressed(model, false)
	end
	s.Pressed[slotIndex] = nil
end

local function bindPlot(folder: Folder): Plot
	local id = folder:GetAttribute("PlotId")
	assert(typeof(id) == "number", "Plot sem PlotId: " .. folder.Name)
	local belt = folder:FindFirstChild("Conveyor")
	assert(belt and belt:IsA("BasePart"), "Conveyor ausente: " .. folder.Name)
	local keycaps = folder:FindFirstChild("Keycaps")
	assert(keycaps and keycaps:IsA("Folder"), "Keycaps ausente: " .. folder.Name)
	local board = folder:FindFirstChild("Board")
	assert(board and board:IsA("Folder"), "Board ausente: " .. folder.Name)
	local spawnLocation = folder:FindFirstChild("Spawn")
	assert(spawnLocation and spawnLocation:IsA("SpawnLocation"), "Spawn ausente: " .. folder.Name)

	local slotParts: { BasePart } = {}
	local slotCount = 0
	for _, child in board:GetChildren() do
		if child:IsA("BasePart") then
			local idx = child:GetAttribute("SlotIndex")
			if typeof(idx) == "number" then
				slotParts[idx] = child
				slotCount += 1
			end
		end
	end
	assert(slotCount == Config.Board.Slots, "Plot " .. folder.Name .. " slots=" .. slotCount .. " esperado " .. Config.Board.Slots)

	local endInset = Config.Belt.EndCapDepth + 0.4
	local halfLen = belt.Size.Z * 0.5
	local spawnPos = spawnLocation.Position + Vector3.new(0, 2.5, 0)
	local spawnCFrame = CFrame.new(spawnPos, Vector3.new(belt.Position.X, spawnPos.Y, belt.Position.Z))

	return {
		Id = id,
		Folder = folder,
		Owner = nil,
		SlotParts = slotParts,
		Keycaps = keycaps,
		BeltStartZ = belt.Position.Z - halfLen + endInset,
		BeltEndZ = belt.Position.Z + halfLen - endInset,
		BeltY = belt.Position.Y + belt.Size.Y * 0.5 + Config.Keycap.Size.Y / 2 + 0.15,
		BeltX = belt.Position.X,
		SpawnCFrame = spawnCFrame,
		SpawnLocation = spawnLocation,
	}
end

local function wirePlot(plot: Plot)
	local trash = plot.Folder:FindFirstChild("Trash")
	assert(trash and trash:IsA("BasePart"), "Trash ausente: Plot" .. plot.Id)
	local trashPrompt = trash:FindFirstChildOfClass("ProximityPrompt")
	local trashAllPrompt = trash:FindFirstChild("DiscardAll")
	assert(trashPrompt and trashPrompt:IsA("ProximityPrompt"), "Trash prompt ausente")
	assert(trashAllPrompt and trashAllPrompt:IsA("ProximityPrompt"), "DiscardAll ausente")

	trashPrompt.Triggered:Connect(function(player)
		if plot.Owner ~= player then
			return
		end
		local s = state[player]
		if not s then
			return
		end
		local sel = s.SelectedIndex
		if not sel then
			return
		end
		if not dropInventoryAt(s, sel) then
			return
		end
		pushInv(player)
	end)

	trashAllPrompt.Triggered:Connect(function(player)
		if plot.Owner ~= player then
			return
		end
		local s = state[player]
		if not s or #s.Inventory == 0 then
			return
		end
		s.Inventory = {}
		s.SelectedIndex = nil
		pushInv(player)
	end)

	for i, slot in plot.SlotParts do
		local prompt = slot:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Triggered:Connect(function(player)
				if plot.Owner ~= player then
					return
				end
				local s = state[player]
				if not s then
					return
				end

				local placed = s.Slots[i]
				if placed then
					if #s.Inventory >= Config.Keycap.InventoryMax then
						return
					end
					collectFromSlot(player, plot, i)
					if s.Pressed[i] then
						releaseSlot(player, plot, i)
					end
					s.Slots[i] = nil
					clearPlacedOnSlot(slot)
					slot.Color = Config.Board.WellColor
					placed.Accrued = 0
					table.insert(s.Inventory, placed)
					if s.SelectedIndex == nil then
						s.SelectedIndex = #s.Inventory
					end
					refreshCps(s)
					setSlotPromptMode(slot, "place")
					pushCash(player)
					pushInv(player)
					return
				end

				local sel = s.SelectedIndex
				if not sel or not s.Inventory[sel] then
					return
				end
				local data = dropInventoryAt(s, sel)
				if not data then
					return
				end
				data.Accrued = 0
				s.Slots[i] = data
				refreshCps(s)
				placeKeycapOnSlot(slot, data)
				pushCash(player)
				pushInv(player)
			end)
		end
	end
end

local function wireHubBoost(hub: Folder)
	local corridor = hub:FindFirstChild("PlayerBoost")
	assert(corridor and corridor:IsA("BasePart"), "Hub.PlayerBoost ausente")
	local map = Config.Map
	local boostCounts: { [Humanoid]: number } = {}
	local function humanoidFromHit(hit: BasePart): Humanoid?
		local model = hit:FindFirstAncestorOfClass("Model")
		if not model then
			return nil
		end
		return model:FindFirstChildOfClass("Humanoid")
	end
	corridor.Touched:Connect(function(hit)
		if not hit:IsA("BasePart") then
			return
		end
		local hum = humanoidFromHit(hit)
		if not hum then
			return
		end
		boostCounts[hum] = (boostCounts[hum] or 0) + 1
		if boostCounts[hum] == 1 then
			hum.WalkSpeed = map.Corridor.BoostSpeed
		end
	end)
	corridor.TouchEnded:Connect(function(hit)
		if not hit:IsA("BasePart") then
			return
		end
		local hum = humanoidFromHit(hit)
		if not hum then
			return
		end
		local n = (boostCounts[hum] or 1) - 1
		if n <= 0 then
			boostCounts[hum] = nil
			hum.WalkSpeed = map.Corridor.DefaultSpeed
		else
			boostCounts[hum] = n
		end
	end)
end

-- ponytail: World vive no place (Studio). Rojo nao lista World no project.json
-- ($ignoreUnknownInstances). So gera se faltar — Stop+Save pra gravar no .rbxl.
local world = workspace:FindFirstChild("World")
if world and not world:IsA("Folder") then
	world:Destroy()
	world = nil
end
if not world then
	warn("[KeycapConveyor] Workspace.World ausente — gerando so pra este Play (nao grava no place).")
	warn("[KeycapConveyor] Pra fixar no Studio: Edit mode → Command Bar:")
	warn("  require(game.ServerScriptService.MapWorld).rebuildWorld(workspace)")
	warn("Depois File→Save. Ou use o plugin plugins/BakeKeycapWorld.lua")
	world = MapWorld.buildWorld(workspace)
else
	print("[KeycapConveyor] usando Workspace.World do place/Studio")
end

local ok, err = pcall(function()
	for i = 1, Config.Plots.Count do
		local folder = world:FindFirstChild("Plot" .. i)
		assert(folder and folder:IsA("Folder"), "falta Plot" .. i .. " em Workspace.World")
		local plot = bindPlot(folder)
		wirePlot(plot)
		plots[i] = plot
	end
	local hub = world:FindFirstChild("Hub")
	assert(hub and hub:IsA("Folder"), "falta Hub em Workspace.World")
	wireHubBoost(hub)

	assert(plots[1].BeltX < 0 and plots[4].BeltX > 0, "cols esquerda/direita invertidas")
	assert(plots[1].BeltStartZ < plots[2].BeltStartZ and plots[2].BeltStartZ < plots[3].BeltStartZ, "coluna esq fora de ordem Z")
	assert(plots[4].BeltStartZ < plots[5].BeltStartZ and plots[5].BeltStartZ < plots[6].BeltStartZ, "coluna dir fora de ordem Z")
end)
if not ok then
	warn("[KeycapConveyor] FALHA ao bindar mapa:", err)
else
	print("[KeycapConveyor] mapa bindado:", #plots, "plots + hub")
end

local function claimPlot(player: Player): Plot?
	for _, plot in plots do
		if plot.Owner == nil then
			plot.Owner = player
			playerPlot[player] = plot
			plot.SpawnLocation.Enabled = true
			player.RespawnLocation = plot.SpawnLocation
			setPlotOwnerAttr(plot, player.UserId)
			local title = plot.Folder:FindFirstChild("PlotLabel")
			if title then
				local gui = title:FindFirstChildOfClass("BillboardGui")
				local label = gui and gui:FindFirstChild("Title")
				if label and label:IsA("TextLabel") then
					label.Text = "Plot " .. plot.Id .. " - " .. player.DisplayName
				end
			end
			for _, d in plot.Folder:GetDescendants() do
				if d:IsA("ProximityPrompt") then
					d.Enabled = true
				end
			end
			return plot
		end
	end
	return nil
end

local function releasePlot(player: Player)
	local plot = playerPlot[player]
	if not plot then
		return
	end
	if player.RespawnLocation == plot.SpawnLocation then
		player.RespawnLocation = nil
	end
	plot.SpawnLocation.Enabled = false
	plot.Owner = nil
	playerPlot[player] = nil
	clearBelt(plot)
	resetBoardVisual(plot)
	setPlotOwnerAttr(plot, nil)
	for _, d in plot.Folder:GetDescendants() do
		if d:IsA("ProximityPrompt") then
			d.Enabled = false
		end
	end
	local title = plot.Folder:FindFirstChild("PlotLabel")
	if title then
		local gui = title:FindFirstChildOfClass("BillboardGui")
		local label = gui and gui:FindFirstChild("Title")
		if label and label:IsA("TextLabel") then
			label.Text = "Plot " .. plot.Id .. " (livre)"
		end
	end
end

local function pickupKeycap(player: Player, plot: Plot, model: Model)
	if plot.Owner ~= player then
		return
	end
	local s = state[player]
	if not s then
		return
	end
	if #s.Inventory >= Config.Keycap.InventoryMax then
		return
	end
	local legend = model:GetAttribute("Legend")
	local rarity = model:GetAttribute("Rarity")
	local event = model:GetAttribute("Event")
	if typeof(legend) ~= "string" or typeof(rarity) ~= "string" then
		return
	end
	local price = Config.keycapPrice(rarity)
	if s.Cash < price then
		return
	end
	s.Cash -= price
	local data: KeycapData = {
		Legend = legend,
		Rarity = rarity,
		Event = if typeof(event) == "string" then event else "None",
		Accrued = 0,
	}
	table.insert(s.Inventory, data)
	if s.SelectedIndex == nil then
		s.SelectedIndex = #s.Inventory
	end
	model:Destroy()
	pushCash(player)
	pushInv(player)
end

local function applyEventToBoards(eventId: string)
	local chance = Config.Keycap.BoardApplyChance
	for player, s in state do
		local plot = playerPlot[player]
		if plot then
			local changed = false
			for i, data in s.Slots do
				if data and data.Event == "None" and math.random() < chance then
					data.Event = eventId
					placeKeycapOnSlot(plot.SlotParts[i], data)
					changed = true
				end
			end
			if changed then
				refreshCps(s)
				pushCash(player)
			end
		end
	end
end

local function startActiveEvent(eventId: string)
	activeEventToken += 1
	local token = activeEventToken
	activeEventId = eventId
	applyEventToBoards(eventId)
	task.delay(Config.Keycap.EventDurationSec, function()
		if activeEventToken == token then
			activeEventId = "None"
		end
	end)
end

local function spawnKeycapOnPlot(plot: Plot, forceLegend: string?, forceRarityId: string?)
	if not plot.Owner then
		return
	end
	local legend = forceLegend or rollLegend()
	if Config.Keycap.LetterValues[legend] == nil then
		warn("[DevSummon] legend invalida:", legend)
		return
	end
	local rarity = if forceRarityId then Config.rarityEntry(forceRarityId) else rollRarity()
	local eventId = "None"
	if activeEventId ~= "None" and math.random() < Config.Keycap.BeltApplyChance then
		eventId = activeEventId
	end
	local price = Config.keycapPrice(rarity.Id)
	local model = KeycapVisual.create(
		Config.Keycap.Size,
		legend,
		rarity.Color,
		rarity.Id,
		eventId,
		nil,
		Format.cash(price)
	)
	model:SetAttribute("Legend", legend)
	model:SetAttribute("Rarity", rarity.Id)
	model:SetAttribute("Event", eventId)
	model:SetAttribute("PlotId", plot.Id)
	model:SetAttribute("Price", price)
	model.Parent = plot.Keycaps
	KeycapVisual.setCFrame(model, Vector3.new(plot.BeltX, plot.BeltY, plot.BeltStartZ), Vector3.new(0, 0, 1))

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Comprar"
	prompt.ObjectText = if rarity.Id == "NoRGB"
		then (legend .. " · " .. Format.cash(price))
		else (legend .. " " .. rarity.Id .. " · " .. Format.cash(price))
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("OwnerUserId", plot.Owner.UserId)
	prompt:SetAttribute("PlotId", plot.Id)
	prompt.Parent = model.PrimaryPart :: BasePart

	prompt.Triggered:Connect(function(player)
		pickupKeycap(player, plot, model)
	end)
end

local function onPlayerAdded(player: Player)
	if state[player] then
		return
	end
	local plot = claimPlot(player)
	if not plot then
		player:Kick("Servidor cheio (6 plots).")
		return
	end
	state[player] = {
		Cash = Config.Cash.Start,
		CashPerSec = 0,
		Inventory = {},
		SelectedIndex = nil,
		Slots = table.create(Config.Board.Slots),
		Pressed = {},
		PlotId = plot.Id,
		Rebirths = 0,
	}
	ensureLeaderstats(player)
	syncLeaderstats(player)

	local function sendToBase(char: Model)
		local p = playerPlot[player]
		if not p then
			return
		end
		local hrp = char:WaitForChild("HumanoidRootPart") :: BasePart
		task.defer(function()
			if char.Parent and hrp.Parent then
				char:PivotTo(p.SpawnCFrame)
			end
		end)
	end

	player.CharacterAdded:Connect(sendToBase)
	if player.Character then
		sendToBase(player.Character)
	end
	task.defer(function()
		pushCash(player)
		pushInv(player)
		pushRebirth(player)
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)

for _, player in Players:GetPlayers() do
	task.defer(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	releasePlot(player)
	state[player] = nil
end)

-- client detecta press e manda; server valida posicao e coleta
Remotes.KeyPress.OnServerEvent:Connect(function(player: Player, slotIndex: any)
	if typeof(slotIndex) ~= "number" then
		return
	end
	local idx = math.floor(slotIndex)
	local s = state[player]
	local plot = playerPlot[player]
	if not s or not plot or not s.Slots[idx] then
		return
	end
	local slot = plot.SlotParts[idx]
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not (slot and hrp and hrp:IsA("BasePart")) then
		return
	end
	local half = Config.Board.Unit * 0.55
	local d = hrp.Position - slot.Position
	if math.abs(d.X) > half or math.abs(d.Z) > half or d.Y <= -2 or d.Y >= 10 then
		return
	end
	if s.Pressed[idx] then
		collectFromSlot(player, plot, idx)
	else
		pressSlot(player, plot, idx, true)
	end
	pushCash(player)
end)

Remotes.RequestRebirth.OnServerEvent:Connect(function(player: Player)
	local s = state[player]
	local plot = playerPlot[player]
	if not s or not plot then
		return
	end
	local cost = rebirthCost(s.Rebirths)
	if s.Cash < cost then
		return
	end
	s.Cash = 0
	s.Inventory = {}
	s.SelectedIndex = nil
	s.Slots = table.create(Config.Board.Slots)
	s.Pressed = {}
	s.Rebirths += 1
	refreshCps(s)
	resetBoardVisual(plot)
	clearBelt(plot)
	pushCash(player)
	pushInv(player)
	pushRebirth(player)
end)

Remotes.SelectInventory.OnServerEvent:Connect(function(player: Player, index: number)
	local s = state[player]
	if not s or typeof(index) ~= "number" then
		return
	end
	local i = math.floor(index)
	if i < 1 or i > #s.Inventory then
		return
	end
	s.SelectedIndex = i
	pushInv(player)
end)

Remotes.EquipBest.OnServerEvent:Connect(function(player: Player)
	local s = state[player]
	local plot = playerPlot[player]
	if not s or not plot then
		return
	end

	for i = 1, #plot.SlotParts do
		if s.Pressed[i] then
			releaseSlot(player, plot, i)
		end
		collectFromSlot(player, plot, i)
	end

	local pool: { KeycapData } = {}
	for _, cap in s.Inventory do
		table.insert(pool, cap)
	end
	for _, cap in s.Slots do
		if cap then
			table.insert(pool, cap)
		end
	end
	if #pool == 0 then
		return
	end

	local board, inv = splitBestForBoard(pool, Config.Board.Slots, Config.Keycap.InventoryMax)
	s.Inventory = inv
	s.SelectedIndex = if #inv > 0 then 1 else nil
	s.Slots = table.create(Config.Board.Slots)
	s.Pressed = {}
	for i, cap in board do
		s.Slots[i] = cap
	end

	for i, slot in plot.SlotParts do
		local data = s.Slots[i]
		if data then
			placeKeycapOnSlot(slot, data)
		else
			clearPlacedOnSlot(slot)
			slot.Color = Config.Board.WellColor
			setSlotPromptMode(slot, "place")
		end
	end

	refreshCps(s)
	pushCash(player)
	pushInv(player)
end)

Remotes.DevSummon.OnServerEvent:Connect(function(player: Player, legend: any, rarityId: any, dest: any)
	if not Config.Dev.Console then
		return
	end
	if typeof(rarityId) ~= "string" then
		return
	end
	local okRarity = false
	for _, r in Config.Keycap.Rarities do
		if r.Id == rarityId then
			okRarity = true
			break
		end
	end
	if not okRarity then
		warn("[DevSummon] rarity invalida:", rarityId)
		return
	end
	local s = state[player]
	local plot = playerPlot[player]
	if not s or not plot then
		return
	end
	local where = if typeof(dest) == "string" then dest else "belt"

	if where == "fill" then
		s.Pressed = {}
		for i, slot in plot.SlotParts do
			local keyLabel = slot:GetAttribute("KeyLabel")
			local letter = if typeof(keyLabel) == "string" then string.upper(keyLabel) else "A"
			if Config.Keycap.LetterValues[letter] == nil then
				letter = "A"
			end
			local data: KeycapData = {
				Legend = letter,
				Rarity = rarityId,
				Event = "None",
				Accrued = 0,
			}
			s.Slots[i] = data
			placeKeycapOnSlot(slot, data)
		end
		refreshCps(s)
		pushCash(player)
		return
	end

	if typeof(legend) ~= "string" then
		return
	end
	legend = string.upper(legend)
	if Config.Keycap.LetterValues[legend] == nil then
		warn("[DevSummon] legend invalida:", legend)
		return
	end
	if where == "inv" then
		if #s.Inventory >= Config.Keycap.InventoryMax then
			return
		end
		table.insert(s.Inventory, {
			Legend = legend,
			Rarity = rarityId,
			Event = "None",
			Accrued = 0,
		})
		if s.SelectedIndex == nil then
			s.SelectedIndex = #s.Inventory
		end
		pushInv(player)
		return
	end
	spawnKeycapOnPlot(plot, legend, rarityId)
end)

Remotes.DevSummonEvent.OnServerEvent:Connect(function(player: Player, eventId: any)
	if not Config.Dev.Console then
		return
	end
	if typeof(eventId) ~= "string" then
		return
	end
	if eventId == "None" or Config.Keycap.Events[eventId] == nil then
		warn("[DevSummonEvent] evento invalido:", eventId)
		return
	end
	if not state[player] then
		return
	end
	startActiveEvent(eventId)
end)

RunService.Heartbeat:Connect(function(dt)
	local speed = Config.Belt.Speed
	local scrollStep = speed * dt
	for _, plot in plots do
		local belt = plot.Folder:FindFirstChild("Conveyor")
		if belt and belt:IsA("BasePart") then
			local scroll = belt:FindFirstChild("Scroll")
			if scroll and scroll:IsA("Texture") then
				-- Top face: V ~ eixo Z; sincroniza com pecas andando em +Z
				local tile = scroll.StudsPerTileV
				scroll.OffsetStudsV = (scroll.OffsetStudsV + scrollStep) % (if tile > 0 then tile else 1)
			end
		end
		for _, child in plot.Keycaps:GetChildren() do
			if child:IsA("Model") and child.PrimaryPart then
				local pos = child.PrimaryPart.Position
				local z = pos.Z + speed * dt
				if z >= plot.BeltEndZ then
					child:Destroy()
				else
					KeycapVisual.setCFrame(child, Vector3.new(pos.X, pos.Y, z), Vector3.new(0, 0, 1))
				end
			end
		end
	end
end)

task.spawn(function()
	while true do
		for _, plot in plots do
			spawnKeycapOnPlot(plot)
		end
		task.wait(Config.Belt.SpawnEvery)
	end
end)

task.spawn(function()
	while true do
		local dt = Config.Cash.TickEvery
		task.wait(dt)
		local half = Config.Board.Unit * 0.55

		for player, s in state do
			local plot = playerPlot[player]
			if plot then
				local mult = cashMult(s.Rebirths)
				for i, data in s.Slots do
					if data then
						local gain = Config.keycapCps(data.Legend, data.Rarity, data.Event) * mult * dt
						data.Accrued += gain
						local slot = plot.SlotParts[i]
						local model = slot and slot:FindFirstChild("PlacedKeycap")
						if model and model:IsA("Model") then
							KeycapVisual.setAccrued(model, data.Accrued)
						end
					end
				end
				refreshCps(s)

				local char = player.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				local standing: { [number]: boolean } = {}
				if hrp and hrp:IsA("BasePart") then
					for i, data in s.Slots do
						if data then
							local slot = plot.SlotParts[i]
							local d = hrp.Position - slot.Position
							if math.abs(d.X) <= half and math.abs(d.Z) <= half and d.Y > -2 and d.Y < 10 then
								standing[i] = true
							end
						end
					end
				end

				-- edge: press / release (backup se client nao mandou KeyPress; som e visual no client)
				for i, data in s.Slots do
					if data then
						local now = standing[i] == true
						local was = s.Pressed[i] == true
						if now and not was then
							pressSlot(player, plot, i, true)
						elseif not now and was then
							releaseSlot(player, plot, i)
						elseif now then
							collectFromSlot(player, plot, i)
						end
					elseif s.Pressed[i] then
						releaseSlot(player, plot, i)
					end
				end
				pushCash(player)
			end
		end
	end
end)

print("[KeycapConveyor] ready - compra na esteira, coleta andando no teclado")
