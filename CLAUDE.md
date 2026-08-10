# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Nightfall is the codebase for "The Nightfall Incident", a Roblox strategy game (a Spybot: The Nightfall Incident tribute). Players fight tactical battles ("hacking") on a tile grid, navigating a network map (Netmap) of nodes, buying programs (units) with credits, and progressing through dialogue-driven missions.

Unlike the plugin projects in this workspace, this project serves a **partially managed place**: the code is managed by Rojo from this folder, while 3D assets (Workspace.Nodes, Workspace.Netmap, Workspace.NetmapBackground), UI template instances, and Lighting stay in the place file ("The Nightfall Incident New").

## Build / Serve / Test Commands

```bash
# Serve code changes into the open "The Nightfall Incident New" place in Studio
rojo serve default.project.json

# Run tests (*.spec.lua files under src/) — uses the runtests.rbxl place in Studio,
# NOT the game place. Very fast; game logic runs against cloned modules with
# place assets mocked as needed.
python runtests.py [filter]

# Install dependencies (must fix the Luau types after installing)
wally install
rojo sourcemap default.project.json --output sourcemap.json
wally-package-types --sourcemap sourcemap.json Packages
```

## Project Structure

Two Rojo projects:

- `default.project.json` — DataModel project served into the real place. Maps `src/shared` flat into ReplicatedStorage, `src/server` into ServerScriptService, and the entry scripts from `src/entry` (NetworkInterface into ServerScriptService, Setup into StarterPlayerScripts, BOOTSTRAP into ReplicatedFirst). Every managed container sets `$ignoreUnknownInstances: true` so the place's own assets (Remotes are managed; templates/3D assets are not) survive syncing. `*.spec.lua` files are excluded via `globIgnorePaths`.
- `runtests.project.json` — Builds a `RunTests.rbxmx` plugin (same name/port convention as the other workspace projects, so only one project's test plugin is active at a time). The plugin runs in the `runtests` place: `runtests.server.lua` first clones `src/shared` children into ReplicatedStorage and `src/server` children into ServerScriptService of the runtests DataModel (plus `Packages`), so production-style `require(game.ReplicatedStorage.X)` paths resolve, then discovers and runs `*.spec` modules.

**IMPORTANT — entry scripts live in `src/entry`, not the module trees.** Script and LocalScript instances inside a `.rbxmx` plugin EXECUTE in plugin context in every open place (the loader's `workspace.Name == "runtests"` guard only guards the loader itself). The test plugin therefore must contain only ModuleScripts; the game's runnable entry scripts are kept in `src/entry`, which `runtests.project.json` never mounts. Don't rely on `globIgnorePaths` to exclude an `init.server.lua` — rojo's init-file handling bypasses it (learned the hard way: the NetworkInterface server script was running in the real place on every plugin reload).

**Spec convention:** specs require game modules via `game.ReplicatedStorage.X` (NOT relative paths) so every module resolves to the single installed copy.

## Architecture

- `src/shared/` — All game logic + views (ReplicatedStorage). Key modules:
  - `GameState/` — Core battle simulation (units, moves, attacks, AI via `AILogic`). Pure-ish logic, main test target.
  - `Places.lua` — Level/mission definitions (large data file).
  - `Scripts.lua` — Program (unit type) definitions.
  - `Netmap.lua` — Network map graph/progression logic.
  - `GameView/`, `NetmapView`, `Netmap3DView`, `MainView/`, `DialogueView`, `WarezView`, `UnitInfoView(+Mobile)`, `NodeInfoView`, `MainMenuView`, `BuyLevelSkipView` — UI views (being converted from template-Instance cloning to React).
  - `LocalPlayerData.lua` — Client-side save data/progression state.
  - `Remotes/` — RemoteEvent/RemoteFunction definitions (model.json files).
- `src/server/` — Server code (ServerScriptService): `ServerPlayerData`, `ReplayChecker` (server-side replay validation), datastore wrappers, and `ServerStatistics` (a no-op analytics seam — the old Google Universal Analytics integration was removed after Google shut UA down; wire a new backend up there).
- `src/shared/DebugFlags.lua` — developer debug switches (mock datastores, skip tutorial, unlock netmap, starting credits); all default-off for production.
- `src/client/Setup/` — StarterPlayerScripts entry point.
- `src/first/BOOTSTRAP.client.lua` — ReplicatedFirst loading screen.
- `ui-reference/` — JSON dumps of the original template UI instance trees, kept as the reference for the React conversion. Not synced anywhere.

## UI: React

The UI is React (`jsdotlua/react` + `react-roblox` via wally, `React.createElement` aliased as `e` — no JSX). The conversion from cloned template Instances is COMPLETE for all live views — see REACT_CONVERSION.md for the pattern, its pitfalls section (required reading before touching view code), and the list of things deliberately left template-based (dead legacy NetmapView, ReplicatedFirst.TitleScreen, dead StarterGui content). Views keep their original imperative public APIs (`new()` objects with signals and `Set*` methods) bridged to React via `Components/StatefulRoot`; shared Win98-style widgets live in `src/shared/Components/`.
