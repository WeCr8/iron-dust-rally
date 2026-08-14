# Autonomous development loop

## Preparation

1. Install Godot 4.3+ and Web export templates.
2. Install/start one runtime and a coding model.
3. Run `python3 tools/doctor.py` and `make test`.
4. Commit your baseline. Use a disposable branch and a clean worktree.
5. Review task priorities and acceptance criteria in `agent/tasks.json`.
6. Run one dry iteration: `python3 agent/run_loop.py --runtime ollama --dry-run --max-iterations 1`.

## Runtime setup

### Ollama

Start Ollama, pull a coding model, and use the default API at `127.0.0.1:11434`. The adapter calls `/api/chat` with streaming disabled.

### LM Studio

Load a model, enable the local server (commonly port 1234), and provide the model identifier. The adapter uses the OpenAI-compatible `/v1/chat/completions` endpoint.

### llama.cpp

Start `llama-server`/`llama serve` with an instruct-capable GGUF (commonly port 8080). The adapter uses `/v1/chat/completions`.

## Budgets

- `--hours`: hard wall-clock limit.
- `--max-iterations`: maximum model calls.
- `max_patch_lines`: rejects broad changes.
- `max_consecutive_failures`: stops unproductive loops.
- `STOP`: create this root file to stop safely.

## Iteration lifecycle

The controller chooses the highest-priority ready task, assembles only relevant documentation/source, calls the model, validates JSON/diff, applies the patch, runs fixed gates, and commits a checkpoint. A failed patch is reversed and the task receives failure notes for the next attempt. A task is marked complete only when the model says it is complete *and* all gates pass.

## Supervision

Check `agent/runs/<run-id>/events.jsonl` periodically. Stop if the model repeatedly changes unrelated code, tests are shallow, token latency is unreasonable, or game feel needs human judgment. Autonomous completion is not release approval: visually play every milestone and conduct provenance/legal review.

## Recovery

- Failed gate: patch is rolled back automatically.
- Process interruption: inspect `git status`; use the run log and last checkpoint. Never blindly discard pre-existing user changes.
- Repeated task failure: add a smaller prerequisite task or a human-authored design decision.
- Bad successful checkpoint: revert that specific loop commit through normal Git review.

## Model guidance

Prefer a strong code model with 16k minimum context and low temperature. A 7B model may handle narrow tests/docs but is unlikely to sustain architecture work. Use a quantization that leaves enough memory for context; throughput matters less than reliable structured output.
