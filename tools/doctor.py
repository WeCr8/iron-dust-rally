#!/usr/bin/env python3
from __future__ import annotations

import os
import shutil
import socket
import sys
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[1]


def port_open(url: str) -> bool:
    parsed = urlparse(url)
    try:
        with socket.create_connection((parsed.hostname or "127.0.0.1", parsed.port or 80), timeout=0.5):
            return True
    except OSError:
        return False


def main() -> int:
    checks = []
    checks.append(("Python 3.11+", sys.version_info >= (3, 11), sys.version.split()[0]))
    godot = shutil.which("godot4") or shutil.which("godot")
    checks.append(("Godot 4", bool(godot), godot or "not found (required to play/export)"))
    checks.append(("Git", bool(shutil.which("git")), shutil.which("git") or "not found"))
    checks.append(("Project", (ROOT / "game/project.godot").exists(), str(ROOT / "game")))
    runtime = os.getenv("LOCAL_LLM_RUNTIME", "ollama")
    urls = {"ollama": os.getenv("OLLAMA_BASE_URL", "http://127.0.0.1:11434"), "lmstudio": os.getenv("LMSTUDIO_BASE_URL", "http://127.0.0.1:1234/v1"), "llamacpp": os.getenv("LLAMACPP_BASE_URL", "http://127.0.0.1:8080/v1")}
    url = urls.get(runtime, urls["ollama"])
    checks.append((f"Local LLM ({runtime})", port_open(url), url))
    for name, ok, detail in checks:
        print(f"[{'OK' if ok else '--'}] {name}: {detail}")
    required = [ok for name, ok, _ in checks if name in {"Python 3.11+", "Git", "Project"}]
    return 0 if all(required) else 1


if __name__ == "__main__":
    raise SystemExit(main())
