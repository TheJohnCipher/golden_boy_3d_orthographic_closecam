# Golden Boy 2D City Blockout

Complete playable stealth blockout prototype.

## Quick Start
1. Download Godot 4.6+ from godotengine.org (Engine/Windows/x86_64).
2. Extract to folder, add to PATH or run directly.
3. `godot project.godot` (or drag project.godot to Godot.exe).

## Controls
- WASD: Move
- Shift: Sprint
- Mouse: Aim / Look direction
- E: Interact/takedown/extract
- Tab: Day->Night (after 3 contacts)
- R: Restart
- Esc: Toggle mouse capture
- F11: Fullscreen

## Flow
**Day**: Talk to Mara (Plaza), Jules (West Wing), Nico (East Wing). Press Tab to start the night.
**Night**: Navigate the gallery, neutralize Alden (target), and reach the extraction point in the Alley.

**Win**: Victory screen!

## Core Scripts
- `scripts/world_2d.gd` (world orchestration)
- `scripts/player_2d.gd` / `scripts/npc_2d.gd` (characters)
- `scripts/mission_manager.gd` (game state and rules)
- `scripts/game_constants.gd` (centralized configuration)

The project uses a modular architecture; see `docs/project_summary.md` for details.
