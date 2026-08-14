---
name: web-release
description: Validate, optimize, export, host, and test the Iron Dust Rally Godot 4 Web build, including browser compatibility, gamepads, performance budgets, and release provenance.
---

# Web release

1. Read `docs/RESEARCH.md`, `docs/TEST_PLAN.md`, and `game/export_presets.cfg`.
2. Keep the baseline GDScript-only, GL Compatibility, extension-free, and single-threaded unless profiling plus hosting changes justify otherwise.
3. Run repository/Python gates, Godot headless parse, and release export.
4. Serve the exported directory over HTTP; never validate through a `file://` URL.
5. Test Chrome, Edge, Firefox, and Safari as documented, including first gamepad activation, focus loss, audio start, and fullscreen.
6. Record compressed download, load time, average/1% frame rate, and memory against PRD budgets.
7. If enabling threads, require HTTPS/secure context and documented cross-origin isolation headers or the supported PWA strategy.
8. Confirm build output is ignored and assets have provenance before release.
