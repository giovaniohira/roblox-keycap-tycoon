# Keycap Conveyor Tycoon

Jogo Roblox (esteira + tycoon). Codigo no Cursor → sync via **Rojo** → Roblox Studio.

## Mapa (`Workspace.World`)

O mapa **nao e rebuildado a cada Play**. O server so faz bind em `Workspace.World` (plots, hub, esteiras).

Fonte da verdade: o **place** (`KeycapConveyor.rbxl`), editavel no Studio. O Rojo **nao** versiona o `World` (fica fora do `default.project.json`; `Workspace` usa `$ignoreUnknownInstances`).

### Assar o mapa no place (uma vez)

Com Rojo **Connected**, no Studio **sem Play**:

**Opcao A — Command Bar**
```lua
require(game.ServerScriptService.MapWorld).rebuildWorld(workspace)
```
Depois **File → Save**.

**Opcao B — Plugin**
1. Copie `plugins/BakeKeycapWorld.lua` → `%LOCALAPPDATA%\Roblox\Plugins\BakeKeycapWorld.lua`
2. Reinicie o Studio → toolbar **Keycap** → **Bake World** → Save

Se `World` nao existir, o Play ainda gera um mapa temporario (some ao Stop).

### Resetar mapa pro codigo

Rode o bake de novo (rebuild apaga o `World` atual e recria).

### O que nao renomear

`Plot1`…`Plot6`, `Conveyor`, `Board`, `Slot_*`, `Keycaps`, `Spawn`, `Trash`, `Hub` / `PlayerBoost` — o server acha por nome.

## Modelo ASMR (keycap)

1. No Studio, com Rojo **Connected**, va em `ReplicatedStorage.Assets`
2. Coloque o modelo da keycap com o nome exato **`ASMR`** (Model)
3. O jogo clona esse modelo em toda keycap da esteira/teclado

Se `ASMR` nao existir, cai no visual procedural e avisa no Output.

## Conectar Cursor ↔ Studio

### 1. Plugin Rojo no Studio
Instale o plugin casado com o CLI: `rojo plugin install`

### 2. Servir
```powershell
cd C:\Users\giova\Desktop\programming\roblox-v1
rojo serve
```

### 3. Connect no Studio → Bake World (se ainda nao tiver) → Play
