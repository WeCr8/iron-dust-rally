# Research notes (verified 2026-08-13)

Primary sources used for architecture decisions:

- [Godot: Exporting for the Web](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html) — generated files must be served; threaded exports require a secure context and cross-origin isolation headers unless using the documented PWA workaround.
- [Godot: Controllers, gamepads, and joysticks](https://docs.godotengine.org/en/stable/tutorials/inputs/controllers_gamepads_joysticks.html) — controller support includes Web; standard mappings are preferred.
- [Godot: GUI keyboard/controller navigation](https://docs.godotengine.org/en/stable/tutorials/ui/gui_navigation.html) — initial UI focus must be assigned for controller navigation.
- [Godot: Command line tutorial](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html) and [exporting projects](https://docs.godotengine.org/en/stable/tutorials/export/exporting_projects.html) — headless operation/export and export-template requirements.
- [Ollama API introduction](https://docs.ollama.com/api/introduction) and [chat endpoint](https://docs.ollama.com/api/chat) — local default base URL and non-streamed chat request shape.
- [LM Studio local server](https://lmstudio.ai/docs/developer/core/server) and [OpenAI compatibility](https://lmstudio.ai/docs/developer/openai-compat) — local serving and `/v1` compatible API, commonly on port 1234.
- [llama.cpp repository](https://github.com/ggml-org/llama.cpp) — `llama-server`/`llama serve` provides an OpenAI-compatible local HTTP server, commonly on port 8080.

## Inferences applied

- A dependency-free GDScript 2D project is the lowest-risk browser baseline.
- Single-threaded export is appropriate until profiling demonstrates a need for threads.
- LM Studio and llama.cpp can share one OpenAI-compatible adapter; Ollama uses its native endpoint to minimize version assumptions.
- Fixed commands and patch-only model output materially reduce the risk of unattended local execution.

## Research still required before release

- Current browser/gamepad matrix on the exact hosted origin.
- Trademark clearance for final game/studio names.
- Asset-by-asset licensing and generated-content terms.
- Browser storage quota/eviction behavior for the chosen save scope.
- Performance profiling on representative low/mid/high target devices.
