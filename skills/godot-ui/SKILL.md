---
name: godot-ui
description: Build controller-first Godot 4 menus, HUD, settings, results, joining, selection, and accessible interface flows for Iron Dust Rally Web and local multiplayer.
---

# Godot UI

1. Read `docs/PRD.md` and the active task.
2. Map every operation to keyboard and standard gamepad; never require a mouse.
3. Call `grab_focus()` on the intended initial control and define predictable focus neighbors for grids.
4. Keep HUD observational: consume race state/signals without changing rules.
5. Use anchors/containers for 16:9 from 1280×720 through 4K.
6. Pair player colors with numbers/shapes; maintain strong contrast.
7. Provide reduced shake, vibration, and volume controls where feedback is introduced.
8. Test one keyboard, mixed controllers, disconnect/reconnect, focus loss, and rematch.
9. Preserve original visual language and provenance requirements.
