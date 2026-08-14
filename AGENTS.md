# Agent operating contract

Read `docs/PRD.md`, `docs/IP_CLEAN_ROOM.md`, `docs/ARCHITECTURE.md`, and the relevant file under `skills/` before changing code.

## Non-negotiable rules

1. Preserve the clean-room boundary. Never add legacy names, celebrity likenesses, copied tracks, extracted assets, or imitation audio.
2. Complete one task at a time from `agent/tasks.json`.
3. Keep gameplay deterministic where practical; physics-affecting logic belongs in `_physics_process`.
4. Preserve Web compatibility: GDScript only, no GDExtension, no filesystem assumptions outside `user://`, no required threads.
5. Preserve four-player input and CPU fallback.
6. Add or update a test for behavioral changes.
7. Run the gates in `agent/config.json`. Do not weaken gates to make a change pass.
8. Do not edit `.git/`, `.env`, `agent/runs/`, `build/`, licenses, or this contract unless the active task explicitly requires it.
9. Prefer original procedural placeholder visuals until provenance is recorded.
10. Stop and record a blocker rather than guessing at a destructive or legally questionable action.

## Definition of done

- Acceptance criteria for the active task are met.
- Static validation and Python tests pass.
- Godot project parses/runs headlessly when Godot is installed.
- Web export succeeds when templates are installed.
- Documentation reflects new controls/configuration.
- The patch is scoped, reviewable, and contains no generated build artifacts.
