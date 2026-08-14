#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REQUIRED = ["README.md", "AGENTS.md", "docs/PRD.md", "docs/IP_CLEAN_ROOM.md", "game/project.godot", "game/export_presets.cfg", "agent/config.json", "agent/tasks.json"]
REQUIRED_ASSETS = [
    "game/assets/art/vehicles_atlas.png",
    "game/assets/art/environment_atlas.png",
    "game/assets/art/logo_ui_atlas.png",
    "game/assets/audio/engine_loop.wav",
    "game/assets/audio/boost.wav",
    "game/assets/audio/pickup.wav",
    "game/assets/audio/countdown.wav",
    "game/assets/audio/impact.wav",
    "game/assets/audio/finish_stinger.wav",
    "game/assets/asset_manifest.json",
]
RESTRICTED_SHIPPED = [r"Super Off Road", r"Ivan(?: the)? Ironman", r"Ivan Stewart"]


def main() -> int:
    errors = []
    for item in REQUIRED:
        if not (ROOT / item).is_file():
            errors.append(f"missing {item}")
    for item in REQUIRED_ASSETS:
        path = ROOT / item
        if not path.is_file() or path.stat().st_size < 256:
            errors.append(f"missing or empty asset {item}")
    try:
        config = json.loads((ROOT / "agent/config.json").read_text())
        tasks = json.loads((ROOT / "agent/tasks.json").read_text())
        if not config.get("gates"):
            errors.append("agent config has no gates")
        ids = [task["id"] for task in tasks["tasks"]]
        if len(ids) != len(set(ids)):
            errors.append("task IDs are not unique")
        json.loads((ROOT / "game/assets/asset_manifest.json").read_text())
    except (OSError, json.JSONDecodeError, KeyError) as exc:
        errors.append(f"invalid agent JSON: {exc}")
    for folder in (ROOT / "game/scripts", ROOT / "game/scenes"):
        for path in folder.rglob("*") if folder.exists() else []:
            if path.is_file():
                text = path.read_text(encoding="utf-8", errors="replace")
                for pattern in RESTRICTED_SHIPPED:
                    if re.search(pattern, text, re.IGNORECASE):
                        errors.append(f"restricted legacy reference in shipped file {path.relative_to(ROOT)}")
    skills = list((ROOT / "skills").glob("*/SKILL.md")) if (ROOT / "skills").exists() else []
    if len(skills) < 3:
        errors.append("expected at least three repo-local skills")
    if errors:
        print("Validation failed:")
        for error in errors:
            print(f"- {error}")
        return 1
    print(f"Repository validation passed ({len(skills)} skills, {len(REQUIRED_ASSETS)} game assets).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
