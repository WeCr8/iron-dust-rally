from __future__ import annotations

import json
import re
from pathlib import Path


class PatchRejected(ValueError):
    pass


def parse_model_json(raw: str) -> dict:
    text = raw.strip()
    if text.startswith("```"):
        text = re.sub(r"^```(?:json)?\s*|\s*```$", "", text, flags=re.DOTALL)
    try:
        data = json.loads(text)
    except json.JSONDecodeError as exc:
        raise PatchRejected(f"Model did not return valid JSON: {exc}") from exc
    required = {"summary", "patch", "tests", "task_complete", "blocker"}
    if not required.issubset(data):
        raise PatchRejected(f"Missing response keys: {sorted(required - set(data))}")
    if not isinstance(data["patch"], str) or not isinstance(data["tests"], list):
        raise PatchRejected("patch must be a string and tests must be a list")
    return data


def changed_paths(patch: str) -> list[str]:
    paths = []
    for line in patch.splitlines():
        if line.startswith("+++ b/") or line.startswith("--- a/"):
            path = line[6:]
            if path != "/dev/null" and path not in paths:
                paths.append(path)
    return paths


def validate_patch(patch: str, config: dict) -> list[str]:
    if not patch.strip():
        return []
    if not patch.startswith("diff --git "):
        raise PatchRejected("Patch must be a git unified diff")
    if "GIT binary patch" in patch or "Binary files" in patch:
        raise PatchRejected("Binary patches are not allowed")
    changed_lines = sum(1 for line in patch.splitlines() if line.startswith(("+", "-")) and not line.startswith(("+++", "---")))
    if changed_lines > int(config["max_patch_lines"]):
        raise PatchRejected(f"Patch has {changed_lines} changed lines; budget is {config['max_patch_lines']}")
    paths = changed_paths(patch)
    if not paths:
        raise PatchRejected("Patch contains no changed paths")
    allowed = tuple(root.rstrip("/") + "/" for root in config["allowed_roots"])
    denied = tuple(config["denied_paths"])
    for raw in paths:
        path = Path(raw)
        if path.is_absolute() or ".." in path.parts:
            raise PatchRejected(f"Unsafe path: {raw}")
        if not raw.startswith(allowed):
            raise PatchRejected(f"Path outside allowlist: {raw}")
        if any(raw == item or raw.startswith(item.rstrip("/") + "/") for item in denied):
            raise PatchRejected(f"Denied path: {raw}")
    return paths
