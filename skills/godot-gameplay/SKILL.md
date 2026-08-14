---
name: godot-gameplay
description: Implement and test Iron Dust Rally vehicle handling, race rules, CPU drivers, collisions, pickups, and Godot 4 gameplay code while preserving deterministic Web-compatible behavior.
---

# Godot gameplay

1. Read `docs/PRD.md`, `docs/IP_CLEAN_ROOM.md`, and `docs/ARCHITECTURE.md`.
2. Inspect the active task and only the relevant scenes/scripts.
3. Express human and CPU control through the same normalized intent contract.
4. Put motion and race-affecting updates in `_physics_process`; scale by delta.
5. Keep race truth independent from drawing and UI.
6. Prefer resources/data over hard-coded content when adding a second instance.
7. Add deterministic domain tests or a headless smoke test for new rules.
8. Verify keyboard, gamepad, CPU fallback, 30/60 Hz behavior, and restart state.
9. Run configured gates and report any game-feel decision requiring human play.

Never copy a legacy track, tuning table, sprite, name, audio cue, or celebrity identity. Design original equivalents from the product requirements.
