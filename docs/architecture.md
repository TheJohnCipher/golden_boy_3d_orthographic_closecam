# Architecture Guide

This project is a procedural single-level stealth prototype. Most runtime content is generated from scripts.

## Top-level ownership

- `scenes/main.tscn`
  - Entry scene, currently controlled by `scripts/world_3d.gd`.
- `scripts/world_3d.gd`
  - World orchestrator.
  - Owns boot order, scene roots, level blockout calls, mission flow, HUD, and phase transitions.
- `scripts/player_3d.gd`
  - Player movement, camera, and hidden-state behavior.
- `scripts/npc_3d.gd`
  - NPC patrol, detection, interaction checks, and marker behavior.
- `scripts/shadow_zone_3d.gd`
  - Hides/unhides the player when entering/exiting shadow volumes.

## World module layout (`scripts/world/`)

- `intent_catalog.gd`
  - Object intent documentation resolver.
  - Maps authored object names/prefixes to readable intent metadata (`intent_note`).
- `layout_data.gd`
  - Declarative level data.
  - Owns shadow zone coordinates and all NPC spawn records.
- `material_library.gd`
  - Shared visual system.
  - Owns procedural texture generation and material assignment rules.

## How to change things safely

1. Geometry and mission behavior:
   - Edit `scripts/world_3d.gd`.
2. Spawn positions, patrol routes, and shadow-zone bounds:
   - Edit `scripts/world/layout_data.gd`.
3. Visual intent descriptions for generated objects:
   - Edit `scripts/world/intent_catalog.gd`.
4. Surface appearance, texture families, and material matching:
   - Edit `scripts/world/material_library.gd`.

## Maintainer conventions

- Keep `world_3d.gd` focused on orchestration, not low-level asset generation.
- Prefer data-driven records in `layout_data.gd` over new hardcoded spawn calls.
- Preserve metadata annotations (`intent_note`, `authored_name`, `authored_size`, `build_mode`) for generated objects.
- When adding new object naming patterns, update both:
  - geometry naming in `world_3d.gd`
  - intent/material mapping rules in the world modules.
