# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

A Roblox game project written in Luau and synced into Roblox Studio with [Rojo](https://rojo.space/docs) 7.7.1. It is currently the stock Rojo template: there is no gameplay code, test framework, or package manager (Wally) set up yet.

## Toolchain

Tools are pinned in `rokit.toml` and installed with [Rokit](https://github.com/rojo-rbx/rokit) (`rokit install`): rojo, selene, StyLua.

```bash
rojo build -o robloxfg.rbxlx   # build a place file from scratch, then open it in Studio
rojo serve                     # live-sync src/ into an open Studio session (Rojo plugin required)
rojo sourcemap -o sourcemap.json   # for luau-lsp; output is gitignored
selene src                     # lint (std = "roblox", see selene.toml)
stylua src                     # format (stylua.toml is empty → StyLua defaults: tabs, 120 cols)
stylua --check src             # verify formatting without writing
```

VS Code formats `.luau`/`.lua` on save with the StyLua extension (`.vscode/settings.json`).

There are no tests. Code can only be run inside Roblox Studio (play-test after `rojo serve` or `rojo build`).

## Architecture

`default.project.json` is the source of truth for how files map into the Roblox DataModel:

| Folder | Instance in game | Runs on |
|---|---|---|
| `src/shared` | `ReplicatedStorage.Shared` | ModuleScripts required by both sides |
| `src/server` | `ServerScriptService.Server` | Server only |
| `src/client` | `StarterPlayer.StarterPlayerScripts.Client` | Each player's client |

Rojo file-naming conventions determine the instance type:
- `init.server.luau` / `init.client.luau` make the **folder itself** a `Script` / `LocalScript`; sibling files in that folder become its children.
- `*.server.luau` → `Script`, `*.client.luau` → `LocalScript`, plain `*.luau` → `ModuleScript`.

Shared modules are required from either side via `require(game:GetService("ReplicatedStorage").Shared.ModuleName)`. Client/server communication must go through RemoteEvents/RemoteFunctions (FilteringEnabled is on), so never trust client input on the server.

The project file also defines the Workspace baseplate and Lighting/SoundService properties; change those there, because property edits made only in Studio won't appear in a fresh `rojo build`.

Place files (`*.rbxl*`, `*.rbxm*`) are gitignored — Studio owns maps, models, and UI; only code and the project file live in git.

## Project rules

This is a frame-accurate 3D fighting game in the style of Tekken. The design doc is the source of truth for game design.

- All code is strict-typed Luau: start every file with `--!strict`.
- Rojo owns scripts. Studio owns maps, models and UI. Never edit scripts inside Studio.
- Combat runs as a deterministic simulation at a fixed 60 Hz, independent of render frame rate.
  - No `math.random`, `tick()`, `os.clock()` or other wall-clock or random values inside the simulation.
  - No Roblox physics, `Touched` events or `Humanoid` movement for combat; hitboxes and hurtboxes are checked in code each frame.
  - Update fighters in a fixed order every frame.
- Animation and rendering follow the simulation and never drive it.
- Input is one bitmask per frame (directions plus buttons 1–4), tagged with its frame number.
- Fighters and moves are data (startup, active, recovery, block and hit advantage, hit level, hitboxes, cancel windows). Balance changes go in data, not code.
- The server owns match results, currency and unlocks. Clients send inputs only.
- Run `selene src` and `stylua --check src` before calling a change done.
