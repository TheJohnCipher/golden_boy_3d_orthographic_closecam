# TODO

## Gameplay
- Tune player locomotion animation timing and stride amplitude after in-game playtest.
- Add crouch/sprint states with matching animation and footstep variation.
- Improve takedown feedback (camera shake, short hit-stop, audio sting).

## AI
- Add line-of-sight memory so suspicion decays more naturally.
- Add per-role reaction states (investigate, alert, return to patrol).
- Add basic crowd avoidance for civilian patrol intersections.

## World
- Continue detail pass for service corridor cover readability.
- Add additional shadow-zone validation markers for debug builds.
- Add night-only ambient SFX zones.

## UX
- Add input rebinding UI and persist bindings.
- Add pause menu and options panel.
- Add mission restart/complete overlays beyond text HUD.

## Tech
- Integrate `tools/validate_wrappers.ps1` into CI or pre-commit checks.
- Extract legacy blockout generation out of `scripts/world_3d.gd` to keep the orchestrator lean.
- Add optional runtime debug panel for mission and AI state.
- Keep docs updated when ownership/module paths change.
