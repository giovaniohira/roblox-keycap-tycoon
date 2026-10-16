-- Keycap Conveyor Tycoon
-- Layout: 50% ortolinear 5x10 — todos os slots 1u (so Cap uniforme)
-- CPS = LetterValue * RarityMult * EventMult
local Config = {
	Plots = {
		Count = 6,
		Cols = 2, -- esquerda 1-3, direita 4-6
		Rows = 3,
		SpacingX = 118, -- corredor central entre colunas
		SpacingZ = 78,
	},
	-- hub do mapa (fora dos plots)
	Map = {
		Corridor = {
			Width = 32,
			PadHeight = 0.4,
			BoostSpeed = 28,
			DefaultSpeed = 16,
			Color = Color3.fromRGB(45, 110, 220),
		},
		Shops = {
			Count = 2, -- n decidido; placeholders no meio
			Size = Vector3.new(20, 1, 16),
			SpacingZ = 36,
			Color = Color3.fromRGB(55, 160, 90),
		},
		Leaderboard = {
			Size = Vector3.new(90, 1, 30),
			-- ao norte dos plots (Z negativo)
			GapFromPlots = 28,
			Color = Color3.fromRGB(50, 180, 90),
		},
	},
	Belt = {
		Length = 48, -- corre no eixo Z (N/S) dentro do plot
		Width = 5,
		Height = 0.6,
		Speed = 5, -- studs/s (textura scrolla junto)
		SpawnEvery = 1.4, -- seconds
		Y = 0.3, -- assenta no chao (Height/2)
		EndCapDepth = 3.2, -- entrada/saida
		-- vermelho = esteira de keycaps do plot (diagrama)
		Color = Color3.fromRGB(170, 48, 48),
	},
	Keycap = {
		Size = Vector3.new(1.7, 0.75, 1.7),
		InventoryMax = 24,
		-- LetterValues preenchido abaixo (ordem alfabetica, x unico)
		LetterValues = {} :: { [string]: number },
		LegendList = {} :: { string }, -- ordenado, para roll com peso
		-- NoRGB + 7 cores + FullRGB
		-- ponytail: pesos RGB baixos de proposito; upgrade futuro da esteira sobe Weight dos RGB/FullRGB
		Rarities = {
			-- Price = custo pra pegar da esteira
			{ Id = "NoRGB", Mult = 1, Price = 10, Weight = 88, Color = Color3.fromRGB(40, 40, 48) },
			{ Id = "Red", Mult = 70, Price = 350, Weight = 4.5, Color = Color3.fromRGB(220, 50, 50) },
			{ Id = "Orange", Mult = 85, Price = 550, Weight = 2.8, Color = Color3.fromRGB(255, 140, 40) },
			{ Id = "Yellow", Mult = 100, Price = 800, Weight = 1.8, Color = Color3.fromRGB(255, 220, 50) },
			{ Id = "Green", Mult = 120, Price = 1200, Weight = 1.1, Color = Color3.fromRGB(50, 200, 90) },
			{ Id = "Blue", Mult = 145, Price = 2000, Weight = 0.55, Color = Color3.fromRGB(50, 120, 255) },
			{ Id = "Indigo", Mult = 175, Price = 3500, Weight = 0.28, Color = Color3.fromRGB(90, 60, 200) },
			{ Id = "Violet", Mult = 220, Price = 6000, Weight = 0.12, Color = Color3.fromRGB(180, 60, 220) },
			{ Id = "FullRGB", Mult = 300, Price = 15000, Weight = 0.05, Color = Color3.fromRGB(255, 80, 200) },
		},
		-- runtime ActiveEvent vive no server; EventDurationSec = janela de apply em spawns/board
		EventDurationSec = 300, -- 5 min
		BeltApplyChance = 0.05, -- 5% nas keycaps novas da esteira
		BoardApplyChance = 0.005, -- 0.5% no board; so pecas sem Event ativo
		Events = {
			None = { Mult = 1, Color = nil :: Color3? },
			Gold = { Mult = 2, Color = Color3.fromRGB(255, 200, 50) },
			Diamond = { Mult = 3, Color = Color3.fromRGB(150, 220, 255) },
			Sunny = { Mult = 2.5, Color = Color3.fromRGB(255, 230, 120) },
			Frozen = { Mult = 2.5, Color = Color3.fromRGB(170, 230, 255) },
		},
	},
	Board = {
		-- slots grandes (keycap na esteira fica em Keycap.Size; no board usa Unit)
		Unit = 4.2,
		Gap = 0.05,
		RowGap = 0.05,
		FromBelt = 24, -- distancia da esteira ate a borda do teclado (lado oposto ao corredor)
		CaseColor = Color3.fromRGB(22, 22, 28),
		PlateColor = Color3.fromRGB(32, 32, 40),
		WellColor = Color3.fromRGB(14, 14, 18),
		-- pad verde sob o teclado (diagrama)
		ZoneColor = Color3.fromRGB(40, 140, 70),
		-- 5x10; labels so 0-9/A-Z (preenchido abaixo)
		Rows = {},
	},
	Cash = {
		TickEvery = 0.25,
		Start = 100,
	},
	Sound = {
		-- fallback se Assets.ClickSounds estiver vazio
		Fallbacks = {
			{ Name = "Soft", SoundId = "rbxassetid://7567750067" },
			{ Name = "Pop", SoundId = "rbxassetid://9119718098" },
			{ Name = "Tap", SoundId = "rbxassetid://7969970804" },
		},
	},
	Rebirth = {
		BaseCost = 1000,
		CostMult = 2,
		MultPerRebirth = 0.25,
	},
	Dev = {
		Console = true, -- F2; desliga em producao
	},
	-- presets de look; Active escolhe qual aplicar no boot do server
	Lighting = {
		-- Soft = flat (sombra quase some); Realistic = sombra direcional legivel
		Active = "StudsRealistic",
		Presets = {
			-- studs/pixel + luz PBR: sombra do sol legivel no chao/pecas
			StudsRealistic = {
				ClockTime = 16.5, -- sol lateral = sombra longa nos studs
				GeographicLatitude = 42,
				Brightness = 2.6, -- sol forte vs fill baixo = sombra densa
				-- fill bem baixo: sombra quase preta (sobe Ambient se ficar escuro demais)
				Ambient = Color3.fromRGB(18, 22, 32),
				OutdoorAmbient = Color3.fromRGB(38, 46, 58),
				ColorShift_Top = Color3.fromRGB(255, 210, 160),
				ColorShift_Bottom = Color3.fromRGB(40, 55, 90),
				EnvironmentDiffuseScale = 0.25, -- menos luz do ceu dentro da sombra
				EnvironmentSpecularScale = 1,
				GlobalShadows = true,
				ShadowSoftness = 0.04, -- borda dura = sombra mais "forte"
				ExposureCompensation = 0,
				LightingStyle = "Realistic",
				PrioritizeLightingQuality = true,
				TonemapperPreset = "Default", -- so Default|Retro (ACES nao existe)
				Sky = {
					Bk = "rbxasset://textures/sky/sky512_bk.tex",
					Dn = "rbxasset://textures/sky/sky512_dn.tex",
					Ft = "rbxasset://textures/sky/sky512_ft.tex",
					Lf = "rbxasset://textures/sky/sky512_lf.tex",
					Rt = "rbxasset://textures/sky/sky512_rt.tex",
					Up = "rbxasset://textures/sky/sky512_up.tex",
					CelestialBodiesShown = true,
					StarCount = 2500,
					SunAngularSize = 16,
				},
				Atmosphere = {
					Density = 0.28,
					Offset = 0.15,
					Color = Color3.fromRGB(160, 190, 230),
					Decay = Color3.fromRGB(90, 120, 180),
					Glare = 0.2,
					Haze = 1.2,
				},
				ColorCorrection = {
					Brightness = 0,
					Contrast = 0.1,
					Saturation = 0.06,
					TintColor = Color3.fromRGB(255, 248, 240),
				},
				Bloom = {
					Intensity = 0.28,
					Size = 14,
					Threshold = 1.25,
				},
				SunRays = {
					Intensity = 0.08,
					Spread = 0.55,
				},
				Clouds = {
					Cover = 0.35,
					Density = 0.28,
					Color = Color3.fromRGB(255, 255, 255),
				},
			},
			-- arcade/tycoon: Soft + saturação alta + bloom nos RGB (sombra fraca de proposito)
			VibrantDay = {
				ClockTime = 14.5,
				GeographicLatitude = 22,
				Brightness = 2.4,
				Ambient = Color3.fromRGB(90, 120, 160),
				OutdoorAmbient = Color3.fromRGB(130, 165, 200),
				ColorShift_Top = Color3.fromRGB(255, 235, 190),
				ColorShift_Bottom = Color3.fromRGB(90, 150, 255),
				EnvironmentDiffuseScale = 1,
				EnvironmentSpecularScale = 1,
				GlobalShadows = true,
				ShadowSoftness = 0.25,
				ExposureCompensation = 0,
				LightingStyle = "Soft",
				PrioritizeLightingQuality = false,
				TonemapperPreset = "Default",
				Sky = {
					Bk = "rbxasset://textures/sky/sky512_bk.tex",
					Dn = "rbxasset://textures/sky/sky512_dn.tex",
					Ft = "rbxasset://textures/sky/sky512_ft.tex",
					Lf = "rbxasset://textures/sky/sky512_lf.tex",
					Rt = "rbxasset://textures/sky/sky512_rt.tex",
					Up = "rbxasset://textures/sky/sky512_up.tex",
					CelestialBodiesShown = true,
					StarCount = 2500,
					SunAngularSize = 18,
				},
				Atmosphere = {
					Density = 0.22,
					Offset = 0.1,
					Color = Color3.fromRGB(175, 210, 255),
					Decay = Color3.fromRGB(100, 155, 255),
					Glare = 0.12,
					Haze = 0.8,
				},
				ColorCorrection = {
					Brightness = 0,
					Contrast = 0.12,
					Saturation = 0.28,
					TintColor = Color3.fromRGB(255, 250, 245),
				},
				Bloom = {
					Intensity = 0.45,
					Size = 18,
					Threshold = 1.15,
				},
				SunRays = {
					Intensity = 0.06,
					Spread = 0.7,
				},
				Clouds = {
					Cover = 0.42,
					Density = 0.32,
					Color = Color3.fromRGB(255, 255, 255),
				},
			},
			-- fallback mais neutro se quiser trocar Active
			SoftNeutral = {
				ClockTime = 12,
				GeographicLatitude = 15,
				Brightness = 2.2,
				Ambient = Color3.fromRGB(130, 130, 140),
				OutdoorAmbient = Color3.fromRGB(160, 160, 170),
				ColorShift_Top = Color3.fromRGB(255, 255, 255),
				ColorShift_Bottom = Color3.fromRGB(255, 255, 255),
				EnvironmentDiffuseScale = 0.8,
				EnvironmentSpecularScale = 0.8,
				GlobalShadows = true,
				ShadowSoftness = 0.4,
				ExposureCompensation = 0,
				LightingStyle = "Soft",
				PrioritizeLightingQuality = false,
				TonemapperPreset = "Default",
				Sky = {
					Bk = "rbxasset://textures/sky/sky512_bk.tex",
					Dn = "rbxasset://textures/sky/sky512_dn.tex",
					Ft = "rbxasset://textures/sky/sky512_ft.tex",
					Lf = "rbxasset://textures/sky/sky512_lf.tex",
					Rt = "rbxasset://textures/sky/sky512_rt.tex",
					Up = "rbxasset://textures/sky/sky512_up.tex",
					CelestialBodiesShown = true,
					StarCount = 3000,
					SunAngularSize = 21,
				},
				Atmosphere = {
					Density = 0.2,
					Offset = 0,
					Color = Color3.fromRGB(199, 199, 199),
					Decay = Color3.fromRGB(92, 92, 100),
					Glare = 0,
					Haze = 0,
				},
				ColorCorrection = {
					Brightness = 0,
					Contrast = 0.05,
					Saturation = 0.1,
					TintColor = Color3.fromRGB(255, 255, 255),
				},
				Bloom = {
					Intensity = 0.6,
					Size = 24,
					Threshold = 0.95,
				},
				SunRays = {
					Intensity = 0.05,
					Spread = 0.8,
				},
				Clouds = {
					Cover = 0.3,
					Density = 0.25,
					Color = Color3.fromRGB(255, 255, 255),
				},
			},
		},
	},
}

local function countSlots(): number
	local n = 0
	for _, row in Config.Board.Rows do
		n += #row
	end
	return n
end

-- Legends: so 0-9 e A-Z (matematica de valor fica pra depois)
do
	local list: { string } = {}
	for i = 0, 9 do
		table.insert(list, tostring(i))
	end
	for b = string.byte("A"), string.byte("Z") do
		table.insert(list, string.char(b))
	end
	table.sort(list)
	local values: { [string]: number } = {}
	for i, legend in list do
		values[legend] = i
	end
	Config.Keycap.LetterValues = values
	Config.Keycap.LegendList = list

	-- board 5x10: QWERTY-ish + extras ciclando a lista
	local layout = {
		{ "1", "2", "3", "4", "5", "6", "7", "8", "9", "0" },
		{ "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P" },
		{ "A", "S", "D", "F", "G", "H", "J", "K", "L", "Z" },
		{ "X", "C", "V", "B", "N", "M", "A", "B", "C", "D" },
		{ "E", "F", "G", "H", "I", "J", "K", "L", "M", "N" },
	}
	local rows = {}
	for _, labels in layout do
		local row = {}
		for _, legend in labels do
			table.insert(row, { legend, 1 })
		end
		table.insert(rows, row)
	end
	Config.Board.Rows = rows
end

Config.Board.Slots = countSlots()

function Config.letterValue(legend: string): number
	return Config.Keycap.LetterValues[legend] or 1
end

function Config.rarityEntry(id: string)
	for _, r in Config.Keycap.Rarities do
		if r.Id == id then
			return r
		end
	end
	return Config.Keycap.Rarities[1]
end

function Config.rarityMult(id: string): number
	return Config.rarityEntry(id).Mult
end

function Config.eventMult(id: string): number
	local e = Config.Keycap.Events[id]
	if e then
		return e.Mult
	end
	return 1
end

function Config.keycapPrice(rarity: string): number
	return Config.rarityEntry(rarity).Price or 0
end

function Config.keycapCps(legend: string, rarity: string, event: string): number
	return Config.letterValue(legend) * Config.rarityMult(rarity) * Config.eventMult(event)
end

-- asserts
do
	local w = 0
	for _, r in Config.Keycap.Rarities do
		w += r.Weight
	end
	assert(w > 0, "Config.Keycap.Rarities precisa de Weight > 0")
	assert(#Config.Keycap.Rarities == 9, "esperado NoRGB+7+FullRGB = 9 raridades")
	for _, r in Config.Keycap.Rarities do
		assert(typeof(r.Price) == "number" and r.Price >= 0, "Price invalido: " .. r.Id)
	end
	assert(Config.Board.Slots == 50, "teclado 50% deve ter 50 slots, got " .. Config.Board.Slots)
	for _, row in Config.Board.Rows do
		assert(#row == 10, "cada row do 50% deve ter 10 teclas 1u")
		for _, key in row do
			assert(key[2] == 1, "so slots 1u (Cap): " .. tostring(key[1]))
		end
	end
	assert(#Config.Board.Rows == 5, "50% = 5 rows")
	assert(Config.Plots.Count == 6, "MVP fixo em 6 plots")
	assert(Config.Plots.Cols * Config.Plots.Rows == Config.Plots.Count, "Plots deve ser grade Cols x Rows")
	assert(Config.Map.Shops.Count >= 2, "reservar >=2 lojas no hub")
	assert(Config.Map.Corridor.BoostSpeed > Config.Map.Corridor.DefaultSpeed, "corridor boost > walk padrao")
	assert(Config.Board.FromBelt > 0, "Board.FromBelt precisa > 0")

	assert(#Config.Keycap.LegendList == 36, "esperado 0-9 + A-Z = 36 legends")
	for _, legend in Config.Keycap.LegendList do
		assert(string.match(legend, "^[0-9A-Z]$") ~= nil, "legend invalida: " .. legend)
	end
	for _, row in Config.Board.Rows do
		for _, key in row do
			assert(Config.Keycap.LetterValues[key[1]] ~= nil, "legend sem LetterValue: " .. key[1])
		end
	end
	assert(Config.Keycap.Events.None ~= nil, "Events.None obrigatorio")
	local lit = Config.Lighting
	assert(lit.Presets[lit.Active] ~= nil, "Lighting.Active sem preset: " .. tostring(lit.Active))
	assert(lit.Presets.VibrantDay.ColorCorrection.Saturation > 0.2, "VibrantDay deveria ser saturado")
	assert(lit.Presets.VibrantDay.Bloom.Threshold >= 1, "Bloom.Threshold baixo lava a cena")
	local studs = lit.Presets.StudsRealistic
	assert(studs ~= nil, "StudsRealistic obrigatorio")
	assert(studs.LightingStyle == "Realistic", "StudsRealistic precisa LightingStyle Realistic pra sombra")
	assert(studs.GlobalShadows == true, "StudsRealistic precisa GlobalShadows")
	assert(studs.ShadowSoftness <= 0.25, "ShadowSoftness alto dissolve a sombra")
end

return Config
