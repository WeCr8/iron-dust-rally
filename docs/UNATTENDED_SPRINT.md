# Unattended sprint runbook

Run from a clean branch with Godot 4 Web templates and one local model server:

```bash
cp .env.example .env
python3 tools/sprint.py --runtime ollama --model qwen3-coder:30b --hours 6 --max-iterations 60
```

If the package was extracted outside an existing repository, run `python3 tools/bootstrap.py` and create the instructed baseline commit first. The loop depends on Git for transactional rollback and checkpoints.

Use `lmstudio` or `llamacpp` for the other adapters. First use `--dry-run --allow-missing-godot` only to inspect orchestration; a real sprint requires Godot so every accepted patch parses.

The supervisor refuses missing files/assets, dirty Git, failing tests, unavailable inference, or missing Godot. It creates an exclusive lock, enforces all loop budgets, attempts the final Web export, and always writes `agent/reports/LATEST_HANDOFF.md`.

Before leaving: run preflight and a dry run; confirm 25 GB free disk, stable power, sleep disabled, localhost firewall access, a disposable branch, a 16k+ coding model, and a successful manual `python3 tools/export_web.py`.

Create `STOP` to halt gracefully. On return, read the handoff and event log, inspect every `agent:` commit, run `make verify`, and playtest. Autonomous completion is never release approval.
