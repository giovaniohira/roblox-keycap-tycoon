-- Keycap visual: clona Assets.Cap se existir; texto flutuante estilo outline
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(script.Parent.Config)
local Format = require(script.Parent.Format)

local KeycapVisual = {}

local BODY_BLACK = Color3.fromRGB(12, 12, 16)
local FACE_BLACK = Color3.fromRGB(22, 22, 28)
local STEM = Color3.fromRGB(8, 8, 10)

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 70, 180)),
	ColorSequenceKeypoint.new(0.20, Color3.fromRGB(180, 70, 255)),
	ColorSequenceKeypoint.new(0.40, Color3.fromRGB(70, 130, 255)),
	ColorSequenceKeypoint.new(0.60, Color3.fromRGB(70, 230, 255)),
	ColorSequenceKeypoint.new(0.80, Color3.fromRGB(90, 255, 120)),
	ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 220, 70)),
})

local warnedMissingCap = false
local auditedCap = false

local function styleStroke(label: TextLabel)
	local stroke = Instance.new("UIStroke")
	stroke.Name = "Outline"
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Thickness = 2.4
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = label
	local solid = Instance.new("UIGradient")
	solid.Color = ColorSequence.new(Color3.new(0, 0, 0))
	solid.Parent = stroke
	return stroke
end

-- billboard (mods flutuantes) — mantem outline pra ler de longe
local function styleTitle(label: TextLabel, rarity: string, rarityColor: Color3)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamMedium
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	styleStroke(label)

	if rarity == "FullRGB" then
		label.TextColor3 = Color3.new(1, 1, 1)
		local grad = Instance.new("UIGradient")
		grad.Name = "RainbowGrad"
		grad.Color = RAINBOW
		grad.Parent = label
	elseif rarity == "NoRGB" then
		label.TextColor3 = Color3.new(1, 1, 1)
	else
		label.TextColor3 = rarityColor
	end
end

-- texto NA keycap: sem border/stroke; RGB brilha via PointLight no corpo
local function styleLegend(label: TextLabel, rarity: string, rarityColor: Color3)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Gotham
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center

	if rarity == "FullRGB" then
		label.TextColor3 = Color3.new(1, 1, 1)
		local grad = Instance.new("UIGradient")
		grad.Name = "RainbowGrad"
		grad.Color = RAINBOW
		grad.Parent = label
	elseif rarity == "NoRGB" then
		label.TextColor3 = Color3.fromRGB(230, 230, 235)
	else
		-- um pouco mais claro pra “emitir” sem stroke
		label.TextColor3 = rarityColor:Lerp(Color3.new(1, 1, 1), 0.35)
	end
end

local function clearRgbGlow(root: Instance)
	local old = root:FindFirstChild("RgbGlow")
	if old then
		old:Destroy()
	end
	for _, d in root:GetDescendants() do
		if d.Name == "RgbGlow" and d:IsA("PointLight") then
			d:Destroy()
		end
	end
end

local function attachRgbGlow(part: BasePart, rarity: string, rarityColor: Color3)
	clearRgbGlow(part)
	if rarity == "NoRGB" then
		return
	end
	local light = Instance.new("PointLight")
	light.Name = "RgbGlow"
	light.Shadows = false
	if rarity == "FullRGB" then
		light.Color = Color3.fromRGB(255, 140, 220)
		light.Brightness = 2.4
		light.Range = 10
		light:SetAttribute("AnimateRainbow", true)
	else
		light.Color = rarityColor
		light.Brightness = 2.0
		light.Range = 8
	end
	light.Parent = part
end

local function paintModel(model: Model, _rarity: string)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			if d.Name == "Face" then
				d.Color = FACE_BLACK
			elseif d.Name == "Stem" then
				d.Color = STEM
			else
				d.Color = BODY_BLACK
			end
		end
	end
end

local function stripScripts(root: Instance): number
	local n = 0
	for _, d in root:GetDescendants() do
		if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ModuleScript") then
			-- mesh visual nao deve ter logica; free models infectados escondem scripts aqui
			d:Destroy()
			n += 1
		end
	end
	return n
end

-- rejeita Cap se tiver sinais tipicos de backdoor (alem de Script)
local function isCapSuspicious(root: Instance): string?
	for _, d in root:GetDescendants() do
		local className = d.ClassName
		if className == "Script" or className == "LocalScript" or className == "ModuleScript" then
			return "contem " .. className .. " em " .. d:GetFullName()
		end
		if className == "RemoteEvent" or className == "RemoteFunction" or className == "BindableEvent" or className == "BindableFunction" then
			return "contem " .. className .. " (mesh nao precisa de remotes)"
		end
		if className == "Fire" or className == "Smoke" or className == "Sparkles" then
			-- ok estetico; ignore
		elseif className == "Sound" and d:IsA("Sound") and (d :: Sound).SoundId ~= "" then
			-- ok
		end
		local nameLower = string.lower(d.Name)
		if string.find(nameLower, "backdoor", 1, true)
			or string.find(nameLower, "virus", 1, true)
			or string.find(nameLower, "inject", 1, true)
			or string.find(nameLower, "bypass", 1, true)
			or string.find(nameLower, "serverhopper", 1, true)
		then
			return "nome suspeito: " .. d:GetFullName()
		end
	end
	return nil
end

local function auditCapOnce(root: Instance)
	if auditedCap then
		return
	end
	auditedCap = true
	local parts = 0
	local meshes = 0
	local classes: { [string]: number } = {}
	local function tally(d: Instance)
		classes[d.ClassName] = (classes[d.ClassName] or 0) + 1
		if d:IsA("BasePart") then
			parts += 1
		end
		if d:IsA("MeshPart") or d:IsA("SpecialMesh") then
			meshes += 1
		end
	end
	tally(root)
	for _, d in root:GetDescendants() do
		tally(d)
	end
	local summary = {}
	for className, count in classes do
		table.insert(summary, className .. "=" .. count)
	end
	table.sort(summary)
	print(
		"[KeycapVisual] Cap audit:",
		root.ClassName,
		"parts=",
		parts,
		"meshes=",
		meshes,
		"tree=",
		table.concat(summary, ", ")
	)
end

-- Aceita Model ou MeshPart/BasePart solto sob Assets.Cap
local function findCapTemplate(): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if not assets then
		return nil
	end
	local cap = assets:FindFirstChild("Cap")
	if not cap then
		return nil
	end

	local removed = stripScripts(cap)
	if removed > 0 then
		warn("[KeycapVisual] Removidos", removed, "scripts de Assets.Cap (mesh mantido se limpo)")
	end

	local reason = isCapSuspicious(cap)
	if reason then
		warn("[KeycapVisual] Assets.Cap rejeitado:", reason)
		return nil
	end

	auditCapOnce(cap)

	if cap:IsA("Model") then
		return cap
	end
	if cap:IsA("BasePart") then
		-- ponytail: wrap MeshPart solto em Model uma vez; ScaleTo precisa de Model
		local wrap = Instance.new("Model")
		wrap.Name = "Cap"
		cap.Parent = wrap
		wrap.PrimaryPart = cap
		wrap.Parent = assets
		return wrap
	end

	warn("[KeycapVisual] Assets.Cap e", cap.ClassName, "— esperado Model ou MeshPart")
	return nil
end

local function scaleModelToFit(model: Model, target: Vector3)
	local extents = model:GetExtentsSize()
	if extents.X < 1e-3 or extents.Y < 1e-3 or extents.Z < 1e-3 then
		return
	end
	local sx = target.X / extents.X
	local sy = target.Y / extents.Y
	local sz = target.Z / extents.Z
	local factor = math.min(sx, sy, sz)
	if model.ScaleTo then
		model:ScaleTo(model:GetScale() * factor)
		return
	end
	-- fallback manual
	local pivot = model:GetPivot()
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local offset = pivot:PointToObjectSpace(d.Position)
			d.Size *= factor
			d.Position = pivot:PointToWorldSpace(offset * factor)
		end
	end
end

local function ensurePrimary(model: Model): BasePart?
	if model.PrimaryPart then
		return model.PrimaryPart
	end
	local best: BasePart? = nil
	local bestVol = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local vol = d.Size.X * d.Size.Y * d.Size.Z
			if vol > bestVol then
				bestVol = vol
				best = d
			end
		end
	end
	if best then
		model.PrimaryPart = best
	end
	return best
end

local function findNativeLegendLabel(model: Model): TextLabel?
	local fallback: TextLabel? = nil
	for _, d in model:GetDescendants() do
		if d:IsA("TextLabel") then
			local parent = d.Parent
			-- prefer label colado na face (SurfaceGui); BillboardGui do modelo e secundario
			if parent and parent:IsA("SurfaceGui") then
				return d
			end
			if not fallback then
				fallback = d
			end
		end
	end
	return fallback
end

local function clearLabelDecor(label: TextLabel)
	for _, c in label:GetChildren() do
		if c:IsA("UIStroke") or c:IsA("UIGradient") then
			c:Destroy()
		end
	end
end

local function applyLegend(model: Model, part: BasePart, legend: string, textColor: Color3, rarity: string, textRotation: number): boolean
	local native = findNativeLegendLabel(model)
	if native then
		clearLabelDecor(native)
		native.Text = legend
		native.TextScaled = true
		native.BackgroundTransparency = 1
		native.Rotation = textRotation
		styleLegend(native, rarity, textColor)
		return true
	end

	local old = part:FindFirstChild("LegendGui")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "LegendGui"
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(128, 128)
	gui.LightInfluence = 0
	gui.AlwaysOnTop = true
	gui.ZOffset = 1
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.Name = "Legend"
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(0.8, 0.8)
	label.BackgroundTransparency = 1
	label.Rotation = textRotation
	label.Text = legend
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = gui
	styleLegend(label, rarity, textColor)
	return false
end

local function attachModsBillboard(adornee: BasePart, rarity: string, event: string, rarityColor: Color3, cps: number, moneyText: string)
	local old = adornee:FindFirstChild("ModsBillboard")
	if old then
		old:Destroy()
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ModsBillboard"
	billboard.Size = UDim2.fromOffset(160, 52)
	billboard.StudsOffset = Vector3.new(0, adornee.Size.Y * 0.55 + 1.1, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 90
	billboard.Parent = adornee

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 0)
	layout.Parent = billboard

	if rarity ~= "NoRGB" then
		local rarityLabel = Instance.new("TextLabel")
		rarityLabel.Name = "Rarity"
		rarityLabel.Size = UDim2.new(1, 0, 0, 18)
		rarityLabel.BackgroundTransparency = 1
		rarityLabel.Text = rarity
		rarityLabel.Parent = billboard
		styleTitle(rarityLabel, rarity, rarityColor)
	end

	local cashLabel = Instance.new("TextLabel")
	cashLabel.Name = "Accrued"
	cashLabel.Size = UDim2.new(1, 0, 0, 20)
	cashLabel.BackgroundTransparency = 1
	cashLabel.Font = Enum.Font.GothamBold
	cashLabel.TextScaled = true
	cashLabel.TextColor3 = Color3.fromRGB(255, 220, 50)
	cashLabel.Text = moneyText
	cashLabel.Parent = billboard
	styleStroke(cashLabel)

	local cpsLabel = Instance.new("TextLabel")
	cpsLabel.Name = "Cps"
	cpsLabel.Size = UDim2.new(1, 0, 0, 14)
	cpsLabel.BackgroundTransparency = 1
	cpsLabel.Font = Enum.Font.Gotham
	cpsLabel.TextScaled = true
	cpsLabel.TextColor3 = Color3.fromRGB(180, 180, 190)
	cpsLabel.Text = Format.moneyPerSec(cps)
	cpsLabel.Parent = billboard

	if event ~= "None" then
		local ev = Instance.new("TextLabel")
		ev.Name = "Event"
		ev.Size = UDim2.new(1, 0, 0, 16)
		ev.BackgroundTransparency = 1
		ev.Font = Enum.Font.Gotham
		ev.TextScaled = true
		ev.Text = event
		ev.TextColor3 = Color3.fromRGB(120, 255, 90)
		ev.Parent = billboard
	end
end

function KeycapVisual.setMoneyLabel(model: Model, moneyText: string)
	local adorn = model.PrimaryPart
	if not adorn then
		return
	end
	local bb = adorn:FindFirstChild("ModsBillboard")
	if not bb then
		return
	end
	local label = bb:FindFirstChild("Accrued")
	if label and label:IsA("TextLabel") then
		label.Text = moneyText
	end
end

function KeycapVisual.setAccrued(model: Model, accrued: number)
	KeycapVisual.setMoneyLabel(model, Format.cash(accrued))
end

local function createProcedural(size: Vector3, _rarity: string): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = "Keycap"

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Anchored = true
	body.CanCollide = false
	body.Material = Enum.Material.SmoothPlastic
	body.Color = BODY_BLACK
	body.Size = size
	body.Parent = model

	local face = Instance.new("Part")
	face.Name = "Face"
	face.Anchored = true
	face.CanCollide = false
	face.Material = Enum.Material.SmoothPlastic
	face.Color = FACE_BLACK
	face.Size = Vector3.new(size.X * 0.9, math.max(0.08, size.Y * 0.18), size.Z * 0.9)
	face.Parent = model

	local stem = Instance.new("Part")
	stem.Name = "Stem"
	stem.Anchored = true
	stem.CanCollide = false
	stem.Material = Enum.Material.SmoothPlastic
	stem.Color = STEM
	stem.Size = Vector3.new(
		math.clamp(size.X * 0.22, 0.2, 0.45),
		math.max(0.12, size.Y * 0.4),
		math.clamp(size.Z * 0.22, 0.2, 0.45)
	)
	stem.Parent = model

	model.PrimaryPart = body
	model:SetAttribute("Procedural", true)
	return model, body
end

-- textRotation: esteira -90; teclado +90 (180° vs estado anterior do teclado)
function KeycapVisual.create(
	size: Vector3,
	legend: string,
	rarityColor: Color3,
	rarity: string,
	event: string,
	textRotation: number?,
	moneyText: string?
): Model
	local cps = Config.keycapCps(legend, rarity, event)
	local rot = if textRotation ~= nil then textRotation else -90
	local template = findCapTemplate()
	local model: Model
	local adorn: BasePart

	if template then
		model = template:Clone()
		model.Name = "Keycap"
		stripScripts(model)
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
			end
		end
		scaleModelToFit(model, size)
		local primary = ensurePrimary(model)
		assert(primary, "Cap sem BasePart")
		adorn = primary
		model:SetAttribute("Procedural", false)
		paintModel(model, rarity)
	else
		if not warnedMissingCap then
			warnedMissingCap = true
			warn("[KeycapVisual] ReplicatedStorage.Assets.Cap nao encontrado/limpo — usando keycap procedural")
		end
		local body: BasePart
		model, body = createProcedural(size, rarity)
		adorn = body
	end

	applyLegend(model, adorn, legend, rarityColor, rarity, rot)
	attachRgbGlow(adorn, rarity, rarityColor)
	attachModsBillboard(adorn, rarity, event, rarityColor, cps, moneyText or Format.cash(0))
	return model
end

local function findLegendSurface(model: Model): (SurfaceGui?, BasePart?)
	for _, d in model:GetDescendants() do
		if d:IsA("SurfaceGui") and d:FindFirstChildWhichIsA("TextLabel") then
			local host = d.Parent
			if host and host:IsA("BasePart") then
				return d, host
			end
		end
	end
	return nil, nil
end

-- Eixos locais do SurfaceGui no host (normal da face, "cima" do texto)
local function surfaceGuiLocalAxes(face: Enum.NormalId): (Vector3, Vector3)
	if face == Enum.NormalId.Top then
		return Vector3.yAxis, -Vector3.zAxis
	elseif face == Enum.NormalId.Bottom then
		return -Vector3.yAxis, Vector3.zAxis
	elseif face == Enum.NormalId.Front then
		return -Vector3.zAxis, Vector3.yAxis
	elseif face == Enum.NormalId.Back then
		return Vector3.zAxis, Vector3.yAxis
	elseif face == Enum.NormalId.Left then
		return -Vector3.xAxis, Vector3.yAxis
	elseif face == Enum.NormalId.Right then
		return Vector3.xAxis, Vector3.yAxis
	end
	return Vector3.yAxis, -Vector3.zAxis
end

local function rotationMapping(localNormal: Vector3, localUp: Vector3, worldNormal: Vector3, worldUp: Vector3): CFrame
	local lR = localUp:Cross(localNormal)
	if lR.Magnitude < 1e-3 then
		lR = Vector3.xAxis
	else
		lR = lR.Unit
	end
	local wR = worldUp:Cross(worldNormal)
	if wR.Magnitude < 1e-3 then
		wR = Vector3.xAxis
	else
		wR = wR.Unit
	end
	local from = CFrame.fromMatrix(Vector3.zero, lR, localNormal, lR:Cross(localNormal))
	local to = CFrame.fromMatrix(Vector3.zero, wR, worldNormal, wR:Cross(worldNormal))
	return to * from:Inverse()
end

-- lookFlat = direcao do TOPO das letras (esteira/teclado: -Z, legivel do spawn)
function KeycapVisual.setCFrame(model: Model, position: Vector3, lookFlat: Vector3)
	local flat = Vector3.new(lookFlat.X, 0, lookFlat.Z)
	if flat.Magnitude < 1e-3 then
		flat = Vector3.new(0, 0, -1)
	end
	flat = flat.Unit

	if model:GetAttribute("Procedural") == true then
		-- SurfaceGui Top: cima do texto = LookVector
		local cf = CFrame.lookAt(position, position + flat)
		local body = model.PrimaryPart
		if not body then
			return
		end
		local size = body.Size
		body.CFrame = cf
		local face = model:FindFirstChild("Face")
		if face and face:IsA("BasePart") then
			face.CFrame = cf * CFrame.new(0, size.Y * 0.5 + face.Size.Y * 0.5, 0)
		end
		local stem = model:FindFirstChild("Stem")
		if stem and stem:IsA("BasePart") then
			stem.CFrame = cf * CFrame.new(0, -size.Y * 0.55, 0)
		end
		return
	end

	local gui, host = findLegendSurface(model)
	if not gui or not host then
		model:PivotTo(CFrame.lookAt(position, position + flat))
		return
	end

	local localNormal, localUp = surfaceGuiLocalAxes(gui.Face)
	local rot = rotationMapping(localNormal, localUp, Vector3.yAxis, flat)
	local localPivotPos = host.CFrame:PointToObjectSpace(model:GetPivot().Position)
	local newHostPos = position - rot:VectorToWorldSpace(localPivotPos)
	local newHostCf = CFrame.new(newHostPos) * rot
	local pivotOffset = host.CFrame:ToObjectSpace(model:GetPivot())
	model:PivotTo(newHostCf * pivotOffset)
end

return KeycapVisual
