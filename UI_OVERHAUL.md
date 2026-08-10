# UI Overhaul plan

Goal: keep the Windows-95 aesthetic but make the game genuinely usable on
mobile, and modernize presentation. Approved direction from Stravant:

1. **Floating windows** — Win95-styled windows float over the scene instead of
   blanketing screen edges. One responsive UI for desktop and mobile (the
   separate UnitInfoView / UnitInfoViewMobile split collapses into one).
2. **Command row** — the selected unit's attacks/commands render as a row of
   content at the bottom center of the screen.
3. **Drag-drop upload** — initial unit placement is a drag from the program
   window onto an upload zone (replaces the two-click select-zone-then-program
   flow). Must work with touch.
4. **3D databattle view** — the board renders in 3D for anti-aliasing:
   camera stays vertically aligned (straight top-down, NOT isometric),
   pinch/scroll-wheel zoomable and pannable.
5. **Netmap parallax** — faint matrix-style line grids at several depths
   below the netmap islands so panning has parallax interest.

## Architecture decisions

- **3D board via SurfaceGui**: the whole existing 2D board GUI (Tiles /
  UploadZones / Units / HighlightedTiles / Effects layers driven by
  TileView/UnitsView/FlashySquareView) moves onto a SurfaceGui on a flat
  board part floating at kBattleOrigin (well away from the netmap scene).
  All the per-tile rendering machinery survives unchanged; the 3D camera and
  input become a new layer. Tutorial arrows keep working (they parent into
  the board's Effects container, which now lives on the surface).
- **BattleCamera** module (pattern-match NetmapCamera): Install/Uninstall,
  straight-down view, zoom = camera height (scroll wheel + TouchPinch), pan =
  XZ offset (drag beyond a movement threshold; tap below threshold = act),
  clamped to board bounds. Fires a Tapped signal with a world raycast point;
  Battle3DView converts to grid coords and feeds GameView's existing click
  logic (refactored to take grid coords directly).
- **PlaceBackground** becomes a big image plane a bit below the board part —
  gets slight parallax for free.
- **Battle chrome** (React, ScreenGui): command row bottom-center; floating
  unit-info window; Done Turn / Undo / Menu as a floating cluster; the in-game
  menu and end-game boxes stay floating Win95 windows (already are).
- **Netmap parallax grids**: static place assets (thin neon parts forming
  line grids) under workspace.NetmapBackground at increasing depths with
  increasing transparency — real 3D depth gives the parallax.

## Status

- [x] Netmap parallax grids (place asset: workspace.NetmapBackground.MatrixGrids,
      3 neon line layers at y=-12/-34/-70)
- [x] BattleBoard3D + BattleCamera (board GUI on a SurfaceGui at y=500, straight-down
      camera, wheel/pinch zoom, threshold drag-pan, Tapped -> grid coords)
- [ ] Floating window chrome + bottom-center command row (unified
      desktop/mobile; retires UnitInfoViewMobile usage in battle)
- [ ] Drag-drop upload
