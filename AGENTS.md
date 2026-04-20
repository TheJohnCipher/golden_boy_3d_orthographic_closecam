# AGENTS Guide

This file is for Codex and other automated contributors working in this repo.

## Goals

- Keep iteration fast for the Godot stealth prototype.
- Prefer small, reviewable changes over broad rewrites.
- Preserve gameplay behavior unless the task explicitly asks for design changes.

## Architecture Entry Points

- `scenes/main.tscn`: project entry scene.
- `scripts/world_3d.gd`: world orchestrator (boot order, scene roots, high-level flow).
- `scripts/world/mission_controller.gd`: interaction and mission state machine.
- `scripts/world/hud_controller.gd`: HUD build/layout/update.
- `scripts/world/npc_factory.gd`: NPC spawning from layout records.
- `scripts/world/player_factory.gd`: runtime player node construction.
- `scripts/world/layout_data.gd`: declarative positions/routes/spawns.
- `scripts/world/material_library.gd`: procedural texture + material rules.
- `scripts/world/intent_catalog.gd`: object intent metadata for generated geometry.

## Editing Conventions

- Keep `world_3d.gd` orchestration-focused. New subsystem logic should go in `scripts/world/`.
- Favor data-driven updates in `layout_data.gd` over hardcoded spawn edits.
- Keep generated node metadata intact (`intent_note`, `authored_name`, `authored_size`, `build_mode`).
- Preserve existing naming patterns for generated geometry and markers.
- Use ASCII-only text in scripts/docs unless a file already requires Unicode.

## Git Hygiene

- Do not commit transient editor/cache artifacts (especially `.godot/` cache files).
- Commit source files, scene files, and intentional assets only.
- Keep docs (`README.md`, `docs/architecture.md`) in sync when module ownership changes.
