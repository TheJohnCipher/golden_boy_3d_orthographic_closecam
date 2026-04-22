# Project Summary: Golden Boy 2D

## 1. Current Architecture
The project follows a **Separation of Concerns** pattern to ensure maintainability and scalability.

*   **Orchestration (`world_2d.gd`)**: The "Brain" of the scene. It handles boot-up, camera setup, and coordinates between the Level and the Player. It no longer contains hardcoded art or UI logic.
*   **Mission Logic (`mission_manager.gd`)**: A dedicated node that tracks the "State of the Game." It handles suspicion levels, contact progress, objectives, and win/loss conditions.
*   **Modular Geometry (`level_base.gd`)**: A tool-enabled scene script. It allows for visual level design in the editor while providing automated prototyping for collision, shadow zones, and extraction points.
*   **Reactive HUD (`hud_2d.gd`)**: A responsive UI system anchored to screen edges. It uses a "Push" model, updating only when the `MissionManager` signals a change.
*   **Configuration (`game_constants.gd`)**: Centralized "Magic Numbers" for colors, room sizes, and spawn data.

## 2. Technical Specifications
*   **Projection**: 2D Oblique with a `0.65` Y-scale.
*   **Resolution**: 640x360 virtual resolution, scaled via `VIEWPORT` mode with `ASPECT_EXPAND` to support non-standard screen sizes.
*   **Filtering**: `TEXTURE_FILTER_NEAREST` is enforced at the `World` root to ensure crisp pixel edges.
*   **Input**: Unified input map initialized programmatically (WASD, Shift-Sprint, Tab-Phase, E-Interact).

## 3. Core Mechanics & Logic Flow
*   **Stealth System**: 
    *   **Shadows**: `Area2D` zones that reduce NPC detection range to 30%.
    *   **Awareness**: NPCs have individual alertness meters. Vision cones transition from White (Calm) to Red (Alert) before raising global suspicion.
*   **Interaction**: Proximity-based system. Prompts appear on the HUD dynamically based on the nearest interactable NPC or object.
*   **Phase Shift**: The game transitions from "Day" (Social Stealth) to "Night" (Traditional Stealth) once all contacts are met.

## 4. How Everything Works Together (Signal Flow)
1.  **NPC** detects player -> Emits `suspicion_detected`.
2.  **MissionManager** receives signal -> Updates global `suspicion` -> Emits `state_changed`.
3.  **HUD** receives `state_changed` -> Re-draws the suspicion bar and text.
*This decoupling means you can change the UI without touching the NPC code.*

## 5. Current State & Recent Milestones
*   [x] Refactored monolithic world script into modular components.
*   [x] Implemented responsive HUD with anchor-based positioning.
*   [x] Created `@tool` based level generator for editor-side visualization.
*   [x] Implemented Individual NPC Alertness and visual vision cone feedback.
*   [x] Decoupled mission rules from world geometry via `MissionManager`.
*   [x] Stabilized HUD initialization to prevent "null instance" errors.

## 6. Active Work & Next Steps
*   **Environment Polish**: Transitioning generated prototype nodes into hand-placed set dressing.
*   **Audio Integration**: The project currently lacks an audio manager. Implementation of footstep sounds (different for floor vs. alley) and alert stingers is a priority.
*   **Game Feel (Juice)**: Adding camera shakes for takedowns and smoother transitions for the night-time color tint.
*   **Save/Load**: The `MissionManager` state needs to be serialized to allow for checkpointing.

---
*Last Updated: April 2024*