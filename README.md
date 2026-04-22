# Golden Boy 2D City Blockout

Complete playable stealth blockout prototype.

## Quick Start
1. Download Godot 4.6+ from godotengine.org (Engine/Windows/x86_64).
2. Extract to folder, add to PATH or run directly.
3. `godot project.godot` (or drag project.godot to Godot.exe).

## Controls
- WASD: Move (camera-relative)
- Mouse: Aim / Look direction
- E: Interact/takedown/extract
- Tab: Day->Night (after 3 contacts)
- R: Restart
- Esc: Toggle mouse capture
- F11: Fullscreen

## Flow
**Day**: E-talk Mara (bench), Jules (podium), Nico (bar). Tab for night.
**Night**: Shadow-hide (blue zones), takedown target (behind), extract green door.

**Win**: Victory screen!

## Core Scripts
- `scripts/world_2d.gd` (world orchestration)
- `scripts/player_2d.gd` / `scripts/npc_2d.gd` (characters)

All core logic and data are now consolidated within `scripts/world_2d.gd`.
