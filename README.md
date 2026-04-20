# Golden Boy 3D City Blockout

This project is a **single-level 3D stealth blockout** built directly in code.

It currently gives you:
- a perspective third-person camera with mouse look
- a low-resolution pixel-scaled presentation rendered up to the current monitor
- a downtown city block built procedurally from a world controller plus data modules
- a daytime social setup phase
- a nighttime assassination phase
- extraction, fail, restart, and fullscreen flow
- runtime window sizing that snaps to the current monitor resolution

## Important docs

- `docs/city_block_map.md`  
  The main layout reference. Use this when moving walls, changing doors, or rebuilding the city.
- `docs/architecture.md`  
  The code architecture map. Read this first before making structural changes.
- `scripts/world_3d.gd`  
  The orchestration layer for geometry placement, mission flow, lighting, and HUD.

## Controls

- `WASD` move
- Mouse move the camera
- `E` interact / takedown / extract
- `Esc` free or recapture the cursor
- `Tab` begin the night phase once all day contacts are covered
- `R` restart after fail or completion
- `F11` toggle fullscreen

## Current level flow

### Day

Work the public side of the block:
- **Mara** at the cafe arcade for the alibi
- **Jules** at the gallery doors for the guest pass
- **Nico** in the west alley for the service route

When all three are complete, press `Tab`.

### Night

- Enter from the city frontage
- Track **Alden Vale** through the gala route
- Stay out of guard and witness sight lines
- Get behind Alden for the takedown
- Break into the rear loading lane
- Reach the **green safehouse door**

## Project structure

- `scripts/world_3d.gd`  
  World orchestrator. Builds the city, spawns actors, runs mission state, and creates the HUD.
- `scripts/world/layout_data.gd`  
  Declarative coordinates and spawn records (shadow zones, contacts, guards, civilians, target).
- `scripts/world/intent_catalog.gd`  
  Object intent documentation catalog used to annotate generated geometry metadata.
- `scripts/world/material_library.gd`  
  Procedural texture generation and material mapping rules.
- `scripts/player_3d.gd`  
  Handles movement, gravity, mouse-look camera control, and shadow state.
- `scripts/npc_3d.gd`  
  Handles patrols, line-of-sight checks, takedown reach checks, and role visuals.
- `scripts/shadow_zone_3d.gd`  
  Small helper that marks the player hidden when they enter a shadow area.
- `project.godot`  
  Default project config. The live screen size is still forced from code at runtime, and the viewport now renders at a lower pixel-art resolution.

## Collision and ground note

The city uses a hidden support floor underneath the visible slabs so small seam mistakes in the greybox do not drop the player through the map. If you rebuild the block layout, keep that support plane aligned with the playable footprint.

## Recommended next steps

1. Play the level in Godot and note exact coordinates for any remaining collision snags.
2. Move repeated props into reusable scenes once the floor plan stops changing.
3. Replace procedural materials with authored textures when the layout is locked.
4. Split the mission flow out of `world_3d.gd` once the prototype rules stabilize.

## Honest note

This environment does not have a runnable Godot editor or export binary, so the changes here are code-checked and documented, not live playtested.
