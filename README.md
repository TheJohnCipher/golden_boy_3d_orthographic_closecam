# Golden Boy 3D City Blockout

Complete playable stealth blockout! BLACKBOXAI finished: Tested structure, added win screen, full loop works.

## Quick Start
1. Download Godot 4.6+ from godotengine.org (Engine/Windows/x86_64).
2. Extract to folder, add to PATH or run directly.
3. `godot project.godot` (or drag project.godot to Godot.exe).

## Controls
- WASD: Move (camera-relative)
- Mouse: Look
- E: Interact/takedown/extract
- Tab: Day->Night (after 3 contacts)
- R: Restart
- Esc: Toggle mouse capture
- F11: Fullscreen

## Flow
**Day**: E-talk Mara (bench), Jules (podium), Nico (bar). Tab for night.
**Night**: Shadow-hide (blue zones), takedown target (behind), extract green door.

**Win**: Victory screen!

## Files
See `docs/architecture.md`.

Active gameplay scripts:
- `scripts/world_3d.gd` (world orchestration)
- `scripts/player_3d.gd` / `scripts/npc_3d.gd` (characters)
- `scripts/world/player_factory.gd` / `scripts/world/npc_factory.gd` (runtime construction)
- `scripts/world/mission_controller.gd` (mission flow)
- `scripts/world/hud_controller.gd` (HUD)
- `scripts/world/layout_data.gd` (spawn and zone data)

Note: compatibility wrappers exist at:
`scripts/world/world_3d.gd`, `scripts/world/player_3d.gd`, `scripts/world/npc_3d.gd`,
`scripts/input_actions.gd`, and `scripts/velvet_strip_builder.gd`.
Edit the active targets in `scripts/` and `scripts/world/`.

Maintenance check:
- `powershell -ExecutionPolicy Bypass -File tools/validate_wrappers.ps1`

Prototype ready for art/levels polish.
