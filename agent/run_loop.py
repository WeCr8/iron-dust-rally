#!/usr/bin/env python3
from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import subprocess
import sys
import time
from pathlib import Path

try:
    from .guardrails import PatchRejected, parse_model_json, validate_patch
    from .local_llm import LocalLLMError, chat
except ImportError:  # Direct script execution.
    from guardrails import PatchRejected, parse_model_json, validate_patch
    from local_llm import LocalLLMError, chat

ROOT = Path(__file__).resolve().parents[1]


def load_env_file(path: Path) -> None:
    """Load simple KEY=VALUE entries without overriding the caller's environment."""
    if not path.exists():
        return
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        os.environ.setdefault(key.strip(), value.strip().strip("\"'"))


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def run(command: list[str], timeout: int, input_text: str | None = None) -> subprocess.CompletedProcess:
    return subprocess.run(command, cwd=ROOT, input=input_text, text=True, capture_output=True, timeout=timeout, check=False)


def select_task(tasks: dict) -> dict | None:
    completed = {task["id"] for task in tasks["tasks"] if task["status"] == "done"}
    ready = [task for task in tasks["tasks"] if task["status"] == "ready" and set(task.get("depends_on", [])) <= completed]
    return min(ready, key=lambda task: task["priority"], default=None)


def context_for(task: dict, config: dict) -> str:
    files = [ROOT / "AGENTS.md", ROOT / "docs/PRD.md", ROOT / "docs/IP_CLEAN_ROOM.md", ROOT / "docs/ARCHITECTURE.md"]
    skill = ROOT / "skills" / task["skill"] / "SKILL.md"
    if skill.exists():
        files.append(skill)
    for folder in (ROOT / "game/scripts", ROOT / "game/scenes", ROOT / "agent/tests"):
        if folder.exists():
            files.extend(sorted(path for path in folder.rglob("*") if path.is_file() and "__pycache__" not in path.parts and path.suffix != ".pyc"))
    chunks = ["ACTIVE TASK:\n" + json.dumps(task, indent=2)]
    budget = int(config["max_context_chars"])
    for path in files:
        content = path.read_text(encoding="utf-8", errors="replace")
        chunk = f"\nFILE {path.relative_to(ROOT).as_posix()}\n{content}"
        if sum(len(item) for item in chunks) + len(chunk) > budget:
            break
        chunks.append(chunk)
    return "".join(chunks)


def write_event(handle, event: dict) -> None:
    event["time"] = dt.datetime.now(dt.timezone.utc).isoformat()
    handle.write(json.dumps(event) + "\n")
    handle.flush()


def main() -> int:
    load_env_file(ROOT / ".env")
    parser = argparse.ArgumentParser(description="Guarded multi-iteration local-LLM development loop")
    parser.add_argument("--runtime", choices=["ollama", "lmstudio", "llamacpp", "openrouter"], default=os.getenv("LOCAL_LLM_RUNTIME", "ollama"))
    parser.add_argument("--model", default=os.getenv("LOCAL_LLM_MODEL", "qwen3-coder:30b"))
    parser.add_argument("--hours", type=float, default=1.0)
    parser.add_argument("--max-iterations", type=int, default=10)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--allow-dirty", action="store_true")
    args = parser.parse_args()
    config = load_json(ROOT / "agent/config.json")
    status = run(["git", "status", "--porcelain"], 30)
    if status.returncode != 0:
        print("Run inside a Git repository.", file=sys.stderr)
        return 2
    if status.stdout.strip() and not args.allow_dirty:
        print("Worktree is not clean; commit/stash changes or explicitly use --allow-dirty.", file=sys.stderr)
        return 2
    urls = {
        "ollama": os.getenv("OLLAMA_BASE_URL", "http://127.0.0.1:11434"),
        "lmstudio": os.getenv("LMSTUDIO_BASE_URL", "http://127.0.0.1:1234/v1"),
        "llamacpp": os.getenv("LLAMACPP_BASE_URL", "http://127.0.0.1:8080/v1"),
        "openrouter": os.getenv("OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1"),
    }
    api_key = os.getenv("OPENROUTER_API_KEY") if args.runtime == "openrouter" else None
    run_id = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    run_dir = ROOT / "agent/runs" / run_id
    run_dir.mkdir(parents=True)
    deadline = time.monotonic() + args.hours * 3600
    failures = 0
    tasks_path = ROOT / "agent/tasks.json"
    system = (ROOT / "agent/prompts/system.md").read_text(encoding="utf-8")
    reviewer_system = (ROOT / "agent/prompts/reviewer.md").read_text(encoding="utf-8")
    response_schema = load_json(ROOT / "agent/schemas/model_response.schema.json") if args.runtime == "ollama" else None
    reviewer_schema = {
        "type": "object",
        "additionalProperties": False,
        "required": ["approved", "findings", "summary"],
        "properties": {
            "approved": {"type": "boolean"},
            "findings": {"type": "array", "items": {"type": "object"}},
            "summary": {"type": "string"},
        },
    } if args.runtime == "ollama" else None
    previous_failure = ""
    with (run_dir / "events.jsonl").open("a", encoding="utf-8") as log:
        for iteration in range(1, args.max_iterations + 1):
            if time.monotonic() >= deadline or (ROOT / "STOP").exists():
                write_event(log, {"event": "stopped", "iteration": iteration})
                break
            tasks = load_json(tasks_path)
            task = select_task(tasks)
            if not task:
                write_event(log, {"event": "queue_empty"})
                break
            prompt = context_for(task, config)
            if previous_failure:
                prompt += "\n\nPREVIOUS ATTEMPT FAILURE:\n" + previous_failure[-6000:]
            write_event(log, {"event": "iteration_start", "iteration": iteration, "task": task["id"]})
            if args.dry_run:
                print(f"DRY RUN: would submit {task['id']} ({len(prompt)} context chars) to {args.runtime}/{args.model}")
                continue
            applied_patch = ""
            try:
                raw = chat(args.runtime, urls[args.runtime], args.model, [{"role": "system", "content": system}, {"role": "user", "content": prompt}], int(config["command_timeout_seconds"]), api_key, response_schema)
                response = parse_model_json(raw)
                paths = validate_patch(response["patch"], config)
                if response["blocker"] and not response["patch"].strip():
                    task["status"] = "blocked"
                    task["blocker"] = response["blocker"]
                    tasks_path.write_text(json.dumps(tasks, indent=2) + "\n", encoding="utf-8")
                    run(["git", "add", "--", "agent/tasks.json"], 30)
                    run(["git", "commit", "-m", f"agent: block {task['id']} with evidence"], 60)
                    write_event(log, {"event": "blocked", "task": task["id"], "reason": response["blocker"]})
                    continue
                applied = run(["git", "apply", "--whitespace=fix", "--recount", "-C3", "-"], 60, response["patch"])
                if applied.returncode:
                    raise PatchRejected(applied.stderr.strip())
                applied_patch = response["patch"]
                gate_outputs = []
                passed = True
                for gate in config["gates"]:
                    result = run(gate, int(config["command_timeout_seconds"]))
                    gate_outputs.append({"command": gate, "returncode": result.returncode, "output": (result.stdout + result.stderr)[-8000:]})
                    if result.returncode:
                        passed = False
                        break
                if not passed:
                    run(["git", "apply", "-R", "--recount", "-C3", "-"], 60, response["patch"])
                    applied_patch = ""
                    failures += 1
                    previous_failure = json.dumps(gate_outputs)
                    write_event(log, {"event": "gates_failed", "task": task["id"], "gates": gate_outputs})
                else:
                    review_raw = chat(args.runtime, urls[args.runtime], args.model, [{"role": "system", "content": reviewer_system}, {"role": "user", "content": json.dumps({"task": task, "diff": response["patch"], "gates": gate_outputs})}], int(config["command_timeout_seconds"]), api_key, reviewer_schema)
                    review = json.loads(review_raw.strip().removeprefix("```json").removesuffix("```").strip())
                    if not review.get("approved", False):
                        raise RuntimeError("Review rejected patch: " + json.dumps(review.get("findings", [])))
                    if response["task_complete"]:
                        task["status"] = "done"
                        task["completed_at"] = dt.datetime.now(dt.timezone.utc).isoformat()
                        tasks_path.write_text(json.dumps(tasks, indent=2) + "\n", encoding="utf-8")
                    run(["git", "add", "--", *paths, "agent/tasks.json"], 60)
                    commit = run(["git", "commit", "-m", f"agent: {task['id']} {task['title']}"], 60)
                    if commit.returncode:
                        raise RuntimeError(commit.stderr.strip())
                    failures = 0
                    previous_failure = ""
                    applied_patch = ""
                    write_event(log, {"event": "checkpoint", "task": task["id"], "paths": paths, "summary": response["summary"]})
            except (LocalLLMError, PatchRejected, RuntimeError, subprocess.TimeoutExpired, json.JSONDecodeError) as exc:
                if applied_patch:
                    run(["git", "apply", "-R", "--recount", "-C3", "-"], 60, applied_patch)
                failures += 1
                previous_failure = str(exc)
                write_event(log, {"event": "failure", "task": task["id"], "error": str(exc)})
            if failures >= int(config["max_consecutive_failures"]):
                write_event(log, {"event": "failure_budget_exhausted", "failures": failures})
                return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
