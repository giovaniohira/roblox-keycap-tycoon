-- Plugin local: Bake do mapa em Edit mode (persiste no Save).
-- Instalar: copie este arquivo para
--   %LOCALAPPDATA%\Roblox\Plugins\BakeKeycapWorld.lua
-- Reinicie o Studio. Toolbar "Keycap" → "Bake World".
-- Requer Rojo Connected (ServerScriptService.MapWorld).

local toolbar = plugin:CreateToolbar("Keycap")
local button = toolbar:CreateButton(
	"Bake World",
	"Gera/substitui Workspace.World a partir do codigo (MapWorld)",
	""
)

button.Click:Connect(function()
	local sss = game:GetService("ServerScriptService")
	local mod = sss:FindFirstChild("MapWorld")
	if not mod then
		warn("[BakeKeycapWorld] ServerScriptService.MapWorld nao encontrado — rode rojo serve + Connect")
		return
	end
	local okRequire, MapWorld = pcall(require, mod)
	if not okRequire then
		warn("[BakeKeycapWorld] require falhou:", MapWorld)
		return
	end
	local ok, err = pcall(function()
		MapWorld.rebuildWorld(workspace)
	end)
	if not ok then
		warn("[BakeKeycapWorld] falha:", err)
		return
	end
	print("[BakeKeycapWorld] Workspace.World ok — File → Save pra gravar no place")
end)
