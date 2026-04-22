# Golden Boy 2D: Development TODO

## Current Tasks
- [ ] **Environment Detail**: Add wall face polygons to structural pillars in `level_base.gd`.
- [ ] **Audio System**: Create a `SoundManager` singleton to handle 2D positional audio for footsteps and alerts.
- [ ] **NPC AI Polish**: Implement a "Searching" state where NPCs move to the player's last known position if they lose sight at high alertness.
- [ ] **Save System**: Implement JSON serialization for the `MissionManager` state.

## Completed Milestones
- [x] Modular Architecture (World / Level / Mission).
- [x] Responsive Anchor-based HUD.
- [x] Individual NPC Alertness Logic.
