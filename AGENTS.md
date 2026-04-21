# AGENTS Guide

This file is for Codex and other automated contributors working in this repo.

## Goals

- Keep iteration fast for the Godot stealth prototype.
- Prefer small, reviewable changes over broad rewrites.
- Preserve gameplay behavior unless the task explicitly asks for design changes.

## Architecture Entry Points

- `scenes/main.tscn`: project entry scene.
- `scripts/world_3d.gd`: active world orchestrator (boot order, roots, high-level flow).
- `scripts/player_3d.gd`: active player controller.
- `scripts/npc_3d.gd`: active NPC controller.
- `scripts/world/mission_controller.gd`: mission state and progression rules.
- `scripts/world/hud_controller.gd`: HUD creation/layout updates.
- `scripts/world/player_factory.gd` and `scripts/world/npc_factory.gd`: runtime actor construction.
- `scripts/world/layout_data.gd`: declarative spawn/zone records.
- `scripts/world/velvet_strip_builder.gd`: district geometry generation.
- `scripts/world/material_library.gd` and `scripts/world/pbr_materials.gd`: material pipelines.

## Editing Conventions

- Keep `world_3d.gd` orchestration-focused. New subsystem logic should go in `scripts/world/`.
- Keep compatibility wrappers as thin pass-through files only:
  `scripts/world/world_3d.gd`, `scripts/world/player_3d.gd`, `scripts/world/npc_3d.gd`,
  `scripts/input_actions.gd`, `scripts/velvet_strip_builder.gd`.
  Edit target modules, not wrappers.
- Favor data-driven updates in `layout_data.gd` over hardcoded spawn edits.
- Keep generated node metadata intact (`intent_note`, `authored_name`, `authored_size`, `build_mode`).
- Preserve existing naming patterns for generated geometry and markers.
- Use ASCII-only text in scripts/docs unless a file already requires Unicode.

## Git Hygiene

- Do not commit transient editor/cache artifacts (especially `.godot/` cache files).
- Commit source files, scene files, and intentional assets only.
- Run `tools/validate_wrappers.ps1` after moving/renaming script paths.
- Keep docs (`README.md`, `docs/architecture.md`) in sync when module ownership changes.
