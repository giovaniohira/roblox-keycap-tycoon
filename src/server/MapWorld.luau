-- Geometria do mapa (plots + hub). Server so gera se Workspace.World nao existir;
-- depois disso o place/Studio e a fonte da verdade.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local MapWorld = {}

local function studs(p: BasePart)
	p.Material = Enum.Material.Plastic
	p.TopSurface = Enum.SurfaceType.Studs
	p.BottomSurface = Enum.SurfaceType.Inlet
	p.CastShadow = true
end

local function makeBillboard(parent: BasePart, text: string, size: Vector2?)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset((size and size.X) or 200, (size and size.Y) or 40)
	bb.StudsOffset = Vector3.new(0, 4, 0)
	bb.AlwaysOnTop = true
	bb.Parent = parent
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.3
	label.BackgroundColor3 = Color3.fromRGB(16, 16, 24)
	label.TextColor3 = Color3.fromRGB(240, 240, 245)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Text = text
	label.Parent = bb
end

local function buildPlotGeometry(id: number, origin: Vector3, world: Folder, mirror: boolean)
	local folder = Instance.new("Folder")
	folder.Name = "Plot" .. id
	folder:SetAttribute("PlotId", id)
	folder:SetAttribute("Mirror", mirror)
	folder.Parent = world

	local sideSign = if mirror then -1 else 1

	local belt = Instance.new("Part")
	belt.Name = "Conveyor"
	belt.Anchored = true
	belt.Size = Vector3.new(Config.Belt.Width, Config.Belt.Height, Config.Belt.Length)
	belt.Position = origin + Vector3.new(0, Config.Belt.Y, 0)
	belt.Color = Config.Belt.Color
	belt.Material = Enum.Material.Plastic
	belt.TopSurface = Enum.SurfaceType.Smooth
	belt.BottomSurface = Enum.SurfaceType.Inlet
	belt.Parent = folder

	local beltScroll = Instance.new("Texture")
	beltScroll.Name = "Scroll"
	beltScroll.Face = Enum.NormalId.Top
	beltScroll.Texture = "rbxassetid://5975482343"
	beltScroll.StudsPerTileU = 2
	beltScroll.StudsPerTileV = 2
	beltScroll.Color3 = Color3.fromRGB(220, 90, 90)
	beltScroll.Parent = belt

	for _, side in { -1, 1 } do
		local rail = Instance.new("Part")
		rail.Name = "BeltRail"
		rail.Anchored = true
		rail.Size = Vector3.new(0.35, Config.Belt.Height + 0.4, Config.Belt.Length)
		rail.Position = origin + Vector3.new(side * (Config.Belt.Width * 0.5 + 0.1), Config.Belt.Y + 0.1, 0)
		rail.Color = Color3.fromRGB(90, 40, 40)
		studs(rail)
		rail.Parent = folder
	end

	local function makeBeltPortal(name: string, zSign: number)
		local depth = Config.Belt.EndCapDepth
		local wallT = 0.45
		local openH = 2.2
		local zCenter = origin.Z + zSign * (Config.Belt.Length * 0.5 + depth * 0.5)
		local x = origin.X
		local w = Config.Belt.Width + 1.4
		local portal = Instance.new("Folder")
		portal.Name = name
		portal.Parent = folder

		local floor = Instance.new("Part")
		floor.Name = "Floor"
		floor.Anchored = true
		floor.Size = Vector3.new(w, Config.Belt.Height, depth)
		floor.Position = Vector3.new(x, Config.Belt.Y, zCenter)
		floor.Color = Color3.fromRGB(120, 40, 40)
		studs(floor)
		floor.Parent = portal

		for _, side in { -1, 1 } do
			local wall = Instance.new("Part")
			wall.Name = if side < 0 then "WallL" else "WallR"
			wall.Anchored = true
			wall.Size = Vector3.new(wallT, openH, depth)
			wall.Position = Vector3.new(x + side * (w * 0.5 - wallT * 0.5), openH * 0.5, zCenter)
			wall.Color = Color3.fromRGB(90, 40, 40)
			studs(wall)
			wall.Parent = portal
		end

		local top = Instance.new("Part")
		top.Name = "Top"
		top.Anchored = true
		top.Size = Vector3.new(w, wallT, depth)
		top.Position = Vector3.new(x, openH + wallT * 0.5, zCenter)
		top.Color = Color3.fromRGB(90, 40, 40)
		studs(top)
		top.Parent = portal

		local void = Instance.new("Part")
		void.Name = "Void"
		void.Anchored = true
		void.Size = Vector3.new(w - wallT * 2, openH - 0.05, 0.35)
		void.Position = Vector3.new(
			x,
			openH * 0.5,
			origin.Z + zSign * (Config.Belt.Length * 0.5 + depth - 0.15)
		)
		void.Color = Color3.new(0, 0, 0)
		void.Material = Enum.Material.SmoothPlastic
		void.TopSurface = Enum.SurfaceType.Smooth
		void.BottomSurface = Enum.SurfaceType.Smooth
		void.Parent = portal
	end
	makeBeltPortal("Entrada", -1)
	makeBeltPortal("Saida", 1)

	local keycaps = Instance.new("Folder")
	keycaps.Name = "Keycaps"
	keycaps.Parent = folder

	local boardFolder = Instance.new("Folder")
	boardFolder.Name = "Board"
	boardFolder.Parent = folder

	local unit = Config.Board.Unit
	local gap = Config.Board.Gap
	local rowGap = Config.Board.RowGap
	local pitch = unit + gap
	local rowPitch = unit + rowGap
	local cols = #Config.Board.Rows[1]
	local rows = #Config.Board.Rows
	local boardAlongZ = cols * pitch - gap
	local boardAlongX = rows * rowPitch - rowGap
	local caseMargin = unit * 0.35
	local caseH = 0.85
	local plateH = 0.45
	local wellH = 0.35
	local caseCenterY = caseH * 0.5
	local plateCenterY = caseH + plateH * 0.5
	local plateTopY = caseH + plateH
	local fromBelt = Config.Board.FromBelt

	local boardCenterX = origin.X - sideSign * (fromBelt + boardAlongX * 0.5)
	local boardCenterZ = origin.Z
	local boardMinX = boardCenterX - boardAlongX * 0.5
	local boardMinZ = boardCenterZ - boardAlongZ * 0.5

	local zone = Instance.new("Part")
	zone.Name = "KeyboardZone"
	zone.Anchored = true
	zone.Size = Vector3.new(boardAlongX + caseMargin * 4, 0.35, boardAlongZ + caseMargin * 4)
	zone.Position = Vector3.new(boardCenterX, 0.175, boardCenterZ)
	zone.Color = Config.Board.ZoneColor
	zone.Material = Enum.Material.Plastic
	zone.TopSurface = Enum.SurfaceType.Smooth
	zone.BottomSurface = Enum.SurfaceType.Inlet
	zone.Parent = boardFolder

	local case = Instance.new("Part")
	case.Name = "Case"
	case.Anchored = true
	case.Size = Vector3.new(boardAlongX + caseMargin * 2, caseH, boardAlongZ + caseMargin * 2)
	case.Position = Vector3.new(boardCenterX, caseCenterY, boardCenterZ)
	case.Color = Config.Board.CaseColor
	studs(case)
	case.Parent = boardFolder

	local plate = Instance.new("Part")
	plate.Name = "Plate"
	plate.Anchored = true
	plate.Size = Vector3.new(boardAlongX + unit * 0.15, plateH, boardAlongZ + unit * 0.15)
	plate.Position = Vector3.new(boardCenterX, plateCenterY, boardCenterZ)
	plate.Color = Config.Board.PlateColor
	studs(plate)
	plate.Parent = boardFolder

	local bezel = Instance.new("Part")
	bezel.Name = "Bezel"
	bezel.Anchored = true
	bezel.Size = Vector3.new(unit * 0.35, caseH * 0.55, boardAlongZ + caseMargin * 2)
	bezel.Position = Vector3.new(
		boardCenterX + sideSign * (boardAlongX * 0.5 + caseMargin * 0.55),
		caseCenterY + caseH * 0.15,
		boardCenterZ
	)
	bezel.Color = Config.Board.CaseColor
	studs(bezel)
	bezel.Parent = boardFolder

	local labelPart = Instance.new("Part")
	labelPart.Name = "PlotLabel"
	labelPart.Anchored = true
	labelPart.CanCollide = false
	labelPart.Transparency = 1
	labelPart.Size = Vector3.new(1, 1, 1)
	labelPart.Position = origin + Vector3.new(sideSign * -8, 8, 0)
	labelPart.Parent = folder
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(160, 36)
	bb.AlwaysOnTop = true
	bb.Parent = labelPart
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.fromScale(1, 1)
	title.BackgroundTransparency = 0.35
	title.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
	title.TextColor3 = Color3.fromRGB(230, 230, 240)
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.Text = "Plot " .. id .. " (livre)"
	title.Parent = bb

	local wellXZ = unit + gap - 0.06
	local wellCenterY = plateTopY + wellH * 0.5 + 0.02
	local index = 0
	for rowIndex, row in Config.Board.Rows do
		local xOff = (rowIndex - 1) * rowPitch + unit / 2
		local wellX = if mirror then boardMinX + boardAlongX - xOff else boardMinX + xOff
		for colIndex, key in row do
			index += 1
			local keyLabel = key[1]
			local wellZ = boardMinZ + (colIndex - 1) * pitch + unit / 2

			local well = Instance.new("Part")
			well.Name = "Slot_" .. index
			well.Anchored = true
			well.Size = Vector3.new(wellXZ, wellH, wellXZ)
			well.Position = Vector3.new(wellX, wellCenterY, wellZ)
			well.Color = Config.Board.WellColor
			studs(well)
			well:SetAttribute("SlotIndex", index)
			well:SetAttribute("KeyLabel", keyLabel)
			well:SetAttribute("PlotId", id)
			well.Parent = boardFolder

			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Encaixar"
			prompt.ObjectText = "Slot"
			prompt.MaxActivationDistance = 22
			prompt.RequiresLineOfSight = false
			prompt.Enabled = false
			prompt:SetAttribute("PlotId", id)
			prompt.Parent = well
		end
	end

	local spawnX = origin.X + sideSign * (Config.Belt.Width * 0.5 + 10)
	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "Spawn"
	spawnLocation.Anchored = true
	spawnLocation.Duration = 0
	spawnLocation.Neutral = true
	spawnLocation.Enabled = false
	spawnLocation.Size = Vector3.new(8, 1, 8)
	spawnLocation.CFrame = CFrame.new(spawnX, 0.5, origin.Z)
		* CFrame.Angles(0, if mirror then -math.pi / 2 else math.pi / 2, 0)
	spawnLocation.Transparency = 0.25
	spawnLocation.Color = Color3.fromRGB(60, 120, 220)
	studs(spawnLocation)
	spawnLocation.CanCollide = true
	spawnLocation.Parent = folder

	local trash = Instance.new("Part")
	trash.Name = "Trash"
	trash.Anchored = true
	trash.Size = Vector3.new(3.2, 3.6, 3.2)
	trash.Position = origin
		+ Vector3.new(sideSign * (Config.Belt.Width * 0.5 + 4.2), 3.6 * 0.5, Config.Belt.Length * 0.22)
	trash.Color = Color3.fromRGB(28, 28, 32)
	studs(trash)
	trash.Parent = folder

	local trashRim = Instance.new("Part")
	trashRim.Name = "TrashRim"
	trashRim.Anchored = true
	trashRim.Size = Vector3.new(3.6, 0.35, 3.6)
	trashRim.Position = trash.Position + Vector3.new(0, trash.Size.Y * 0.5 + 0.1, 0)
	trashRim.Color = Color3.fromRGB(50, 50, 56)
	studs(trashRim)
	trashRim.Parent = folder

	local trashVoid = Instance.new("Part")
	trashVoid.Name = "TrashVoid"
	trashVoid.Anchored = true
	trashVoid.CanCollide = false
	trashVoid.Size = Vector3.new(2.4, 0.2, 2.4)
	trashVoid.Position = trashRim.Position + Vector3.new(0, 0.15, 0)
	trashVoid.Color = Color3.new(0, 0, 0)
	trashVoid.Material = Enum.Material.SmoothPlastic
	trashVoid.TopSurface = Enum.SurfaceType.Smooth
	trashVoid.BottomSurface = Enum.SurfaceType.Smooth
	trashVoid.Parent = folder

	local trashPrompt = Instance.new("ProximityPrompt")
	trashPrompt.ActionText = "Jogar fora"
	trashPrompt.ObjectText = "Lixeira"
	trashPrompt.MaxActivationDistance = 14
	trashPrompt.RequiresLineOfSight = false
	trashPrompt.HoldDuration = 0
	trashPrompt.KeyboardKeyCode = Enum.KeyCode.E
	trashPrompt.Enabled = false
	trashPrompt:SetAttribute("PlotId", id)
	trashPrompt.Parent = trash

	local trashAllPrompt = Instance.new("ProximityPrompt")
	trashAllPrompt.Name = "DiscardAll"
	trashAllPrompt.ActionText = "Descartar tudo (segurar)"
	trashAllPrompt.ObjectText = "Lixeira"
	trashAllPrompt.MaxActivationDistance = 14
	trashAllPrompt.RequiresLineOfSight = false
	trashAllPrompt.HoldDuration = 3
	trashAllPrompt.KeyboardKeyCode = Enum.KeyCode.R
	trashAllPrompt.UIOffset = Vector2.new(0, 60)
	trashAllPrompt.Enabled = false
	trashAllPrompt:SetAttribute("PlotId", id)
	trashAllPrompt.Parent = trash
end

local function buildMapHub(worldFolder: Folder)
	local map = Config.Map
	local rows = Config.Plots.Rows
	local sz = Config.Plots.SpacingZ
	local plotSpanZ = (rows - 1) * sz + Config.Belt.Length + Config.Belt.EndCapDepth * 2 + 8
	local hub = Instance.new("Folder")
	hub.Name = "Hub"
	hub.Parent = worldFolder

	local corridor = Instance.new("Part")
	corridor.Name = "PlayerBoost"
	corridor.Anchored = true
	corridor.Size = Vector3.new(map.Corridor.Width, map.Corridor.PadHeight, plotSpanZ)
	corridor.Position = Vector3.new(0, map.Corridor.PadHeight * 0.5, 0)
	corridor.Color = map.Corridor.Color
	corridor.Material = Enum.Material.Neon
	corridor.TopSurface = Enum.SurfaceType.Smooth
	corridor.BottomSurface = Enum.SurfaceType.Smooth
	corridor.Parent = hub
	makeBillboard(corridor, "BOOST · corra entre plots", Vector2.new(260, 36))

	local shops = Instance.new("Folder")
	shops.Name = "Shops"
	shops.Parent = hub
	local shopCount = map.Shops.Count
	local shopOriginZ = -((shopCount - 1) * map.Shops.SpacingZ) * 0.5
	for i = 1, shopCount do
		local pad = Instance.new("Part")
		pad.Name = "Shop" .. i
		pad.Anchored = true
		pad.Size = map.Shops.Size
		pad.Position = Vector3.new(0, map.Shops.Size.Y * 0.5 + 0.05, shopOriginZ + (i - 1) * map.Shops.SpacingZ)
		pad.Color = map.Shops.Color
		pad.Material = Enum.Material.Plastic
		pad.TopSurface = Enum.SurfaceType.Studs
		pad.BottomSurface = Enum.SurfaceType.Inlet
		pad.Parent = shops
		makeBillboard(pad, "Loja " .. i .. " (em breve)")
	end

	local lbZ = -plotSpanZ * 0.5 - map.Leaderboard.GapFromPlots - map.Leaderboard.Size.Z * 0.5
	local lb = Instance.new("Part")
	lb.Name = "LeaderboardPlaza"
	lb.Anchored = true
	lb.Size = map.Leaderboard.Size
	lb.Position = Vector3.new(0, map.Leaderboard.Size.Y * 0.5, lbZ)
	lb.Color = map.Leaderboard.Color
	lb.Material = Enum.Material.Plastic
	lb.TopSurface = Enum.SurfaceType.Studs
	lb.BottomSurface = Enum.SurfaceType.Inlet
	lb.Parent = hub
	makeBillboard(lb, "LEADERBOARDS · cash · rebirth · tempo · skins", Vector2.new(420, 44))

	local boardLabels = { "Cash", "Rebirths", "Tempo", "Skins Top" }
	local boardW = map.Leaderboard.Size.X / (#boardLabels + 1)
	for i, name in boardLabels do
		local sign = Instance.new("Part")
		sign.Name = "Board_" .. name:gsub("%s", "")
		sign.Anchored = true
		sign.Size = Vector3.new(boardW * 0.85, 10, 0.6)
		sign.Position = Vector3.new(
			-map.Leaderboard.Size.X * 0.5 + boardW * i,
			5 + map.Leaderboard.Size.Y,
			lbZ - map.Leaderboard.Size.Z * 0.35
		)
		sign.Color = Color3.fromRGB(28, 28, 36)
		sign.Material = Enum.Material.SmoothPlastic
		sign.Parent = hub
		makeBillboard(sign, name, Vector2.new(140, 32))
	end
end

-- Cria Workspace.World (plots + hub). Nao liga prompts/boost — isso e no Main.
function MapWorld.buildWorld(parent: Instance): Folder
	local world = Instance.new("Folder")
	world.Name = "World"
	world.Parent = parent

	local n = Config.Plots.Count
	local cols = Config.Plots.Cols
	local rows = Config.Plots.Rows
	local sx = Config.Plots.SpacingX
	local sz = Config.Plots.SpacingZ
	for i = 1, n do
		local col = if i <= rows then 0 else 1
		local row = if i <= rows then i - 1 else i - rows - 1
		local origin = Vector3.new((col - (cols - 1) / 2) * sx, 0, (row - (rows - 1) / 2) * sz)
		buildPlotGeometry(i, origin, world, col == 1)
	end
	buildMapHub(world)
	return world
end

-- Forca rebuild (apaga World atual). Use no Studio se quiser resetar o mapa do codigo.
function MapWorld.rebuildWorld(parent: Instance): Folder
	local existing = parent:FindFirstChild("World")
	if existing then
		existing:Destroy()
	end
	return MapWorld.buildWorld(parent)
end

return MapWorld
