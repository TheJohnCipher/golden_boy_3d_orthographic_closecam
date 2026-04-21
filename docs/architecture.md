# Architecture Guide

This project is a procedural stealth prototype where the world is generated at runtime.

## Project Layout

- `scenes/`
  - Scene entry points.
- `scripts/`
  - Active runtime scripts (`world_3d.gd`, `player_3d.gd`, `npc_3d.gd`) plus compatibility wrappers.
- `scripts/world/`
  - Subsystems, builders, data, and runtime factories.
- `art/`
  - Intentional assets used by the prototype.
- `docs/`
  - Architecture and map notes.

## Runtime Entry Points

- `scenes/main.tscn`
  - Main scene, bound to `res://scripts/world_3d.gd`.
- `scripts/world_3d.gd`
  - Active world orchestrator (boot order, generation, mission flow, HUD updates).
- `scripts/player_3d.gd`
  - Active player controller (movement, camera, stealth state, locomotion visuals).
- `scripts/npc_3d.gd`
  - Active NPC controller (patrols, detection, interactions).

## Active Modules

- `scripts/world/layout_data.gd`
  - Declarative layout records (shadow zones, contacts, guards, civilians, target).
- `scripts/world/mission_controller.gd`
  - Mission state machine and objective/progression logic.
- `scripts/world/hud_controller.gd`
  - HUD creation, layout, and frame updates.
- `scripts/world/input_actions.gd`
  - InputMap defaults.
- `scripts/world/player_factory.gd`
  - Runtime player node construction.
- `scripts/world/npc_factory.gd`
  - Runtime NPC node construction.
- `scripts/world/velvet_strip_builder.gd`
  - District geometry generation.
- `scripts/world/pbr_materials.gd`
  - PBR material palette used by the Velvet Strip builder.
- `scripts/world/material_library.gd`
  - Procedural material/texture fallback pipeline.
- `scripts/world/intent_catalog.gd`
  - Metadata intent notes for generated geometry.

## Compatibility Wrappers

These files exist so old paths do not silently break:

- `scripts/world/world_3d.gd` -> extends `res://scripts/world_3d.gd`
- `scripts/world/player_3d.gd` -> extends `res://scripts/player_3d.gd`
- `scripts/world/npc_3d.gd` -> extends `res://scripts/npc_3d.gd`
- `scripts/input_actions.gd` -> forwards to `scripts/world/input_actions.gd`
- `scripts/velvet_strip_builder.gd` -> forwards to `scripts/world/velvet_strip_builder.gd`

Edit the active files listed above, not the wrappers.

## Validation

- Run `powershell -ExecutionPolicy Bypass -File tools/validate_wrappers.ps1` after moving or renaming script paths.
- The script checks that wrapper targets still exist and wrappers still forward to the expected file.

## Maintainer Conventions

- Keep `scripts/world_3d.gd` orchestration-focused.
- Prefer data-driven updates in `scripts/world/layout_data.gd`.
- Preserve generated metadata (`intent_note`, `authored_name`, `authored_size`, `build_mode`).
