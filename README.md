# Iron Dust Rally

An original, browser-first, four-player top-down off-road arcade racer built with Godot 4. It is inspired by the *genre and feel* of late-1980s/early-1990s cabinet racers, but it does not copy any protected title, celebrity identity, characters, tracks, artwork, sounds, or source code.

This repository is also a self-contained autonomous development workspace. A local LLM can select a scoped task, propose a patch, run quality gates, checkpoint success, and continue for a time or iteration budget.

## What is included

- Playable Godot vertical slice: four original illustrated racers, CPU fallback, three-lap race, boost pickups, standings, keyboard/gamepad input, and procedural track fallback.
- Complete original vertical-slice asset pack: vehicle, environment, logo/UI atlases plus six synthesized sound effects.
- Browser export preset configured without threads for simple static hosting.
- Local-LLM adapters for Ollama, LM Studio, and llama.cpp.
- Guarded build loop: patch-only writes, path allowlist, diff-size budget, tests, automatic rollback, logs, checkpoints, stop file, and iteration/time limits.
- One-command unattended supervisor with model/Godot preflight, exclusive run lock, final Web export, and human-readable handoff report.
- PRD, architecture, game design, art/audio direction, research notes, testing plan, task backlog, and repo-local agent skills.

## Quick start

Requirements: Godot 4.3+ and Python 3.11+. Export templates are required only for the Web build.

After extracting into a folder that is not already inside Git, bootstrap it first:

```bash
python3 tools/bootstrap.py
git add . && git commit -m "Baseline before autonomous sprint"
```

```bash
godot --editor --path game
```

Press **F6/F5** in Godot. Keyboard controls:

| Player | Steer | Accelerate | Brake/reverse | Boost |
| --- | --- | --- | --- | --- |
| P1 | A/D | W | S | Space |
| P2 | Left/Right | Up | Down | Enter |
| P3/P4 | Gamepad left stick/D-pad | A / south | B / east | X / west |

Connected gamepads claim human slots automatically; remaining cars use CPU control.

## Validate and export

```bash
python3 tools/doctor.py
python3 tools/validate_repo.py
python3 -m unittest discover -s agent/tests -v
godot --headless --path game --quit-after 180
godot --headless --path game --export-release Web ../build/web/index.html
python3 -m http.server 8080 --directory build/web
```

Open `http://localhost:8080`. Do not open the exported HTML directly from the filesystem.

## Run the autonomous loop

Copy the example environment file and edit the model name:

```bash
cp .env.example .env
python3 tools/doctor.py
python3 agent/run_loop.py --runtime ollama --hours 4 --max-iterations 30
```

For a complete unattended sprint:

```bash
python3 tools/sprint.py --runtime ollama --model qwen3-coder:30b --hours 6 --max-iterations 60
```

Read [docs/UNATTENDED_SPRINT.md](docs/UNATTENDED_SPRINT.md) before leaving it unobserved.

Other runtimes:

```bash
python3 agent/run_loop.py --runtime lmstudio --model your-loaded-model --hours 4
python3 agent/run_loop.py --runtime llamacpp --model local-model --hours 4
```

Run from a clean Git worktree. Create `STOP` in the repository root to halt after the current operation. See [docs/AUTONOMOUS_LOOP.md](docs/AUTONOMOUS_LOOP.md) before a long run.

## Recommended first run

Use a coding-capable model with at least a 16k context window; 32k is preferable. Start with `--max-iterations 3`, inspect `agent/runs/`, then increase the budget. The loop is deliberately conservative: it makes one small task change per iteration and rejects oversized or unsafe patches.

## Legal boundary

This is a clean-room spiritual successor. “Super Off Road” and “Ivan ‘Ironman’ Stewart” are referenced only as historical inspiration in planning context and must not appear in the shipped game or marketing. Read [docs/IP_CLEAN_ROOM.md](docs/IP_CLEAN_ROOM.md).

## Repository map

```text
game/                 Godot project and playable vertical slice
agent/                autonomous controller, prompts, tests, task state
skills/               repo-local skills for local coding agents
docs/                 PRD, design, architecture, research, QA, operations
tools/                 doctor, validation, build helpers
```

License: code is MIT. Original game content in this repository is CC BY 4.0 unless replaced by a separately licensed asset. See `LICENSE` and `ASSET_LICENSES.md`.
