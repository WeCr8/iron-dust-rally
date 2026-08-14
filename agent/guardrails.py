from __future__ import annotations

import json
import re
from pathlib import Path


class ResponseRejected(ValueError):
    pass


def parse_model_json(raw: str) -> dict:
    text = raw.strip()
    if text.startswith("```"):
        text = re.sub(r"^```(?:json)?\s*|\s*```$", "", text, flags=re.DOTALL)
    try:
        data = json.loads(text)
    except json.JSONDecodeError as exc:
        raise ResponseRejected(f"Model did not return valid JSON: {exc}") from exc
    required = {"summary", "files", "tests", "task_complete", "blocker"}
    if not required.issubset(data):
        raise ResponseRejected(f"Missing response keys: {sorted(required - set(data))}")
    if not isinstance(data["files"], list) or not isinstance(data["tests"], list):
        raise ResponseRejected("files and tests must be lists")
    for entry in data["files"]:
        if not isinstance(entry, dict) or not isinstance(entry.get("path"), str) or not isinstance(entry.get("content"), str):
            raise ResponseRejected("each files[] entry needs a string path and string content")
    return data


def validate_files(files: list[dict], config: dict) -> list[str]:
    if not files:
        return []
    changed_lines = sum(len(entry["content"].splitlines()) for entry in files)
    if changed_lines > int(config["max_patch_lines"]):
        raise ResponseRejected(f"Files total {changed_lines} lines; budget is {config['max_patch_lines']}")
    allowed = tuple(root.rstrip("/") + "/" for root in config["allowed_roots"])
    denied = tuple(config["denied_paths"])
    paths = []
    for entry in files:
        raw = entry["path"]
        path = Path(raw)
        if path.is_absolute() or ".." in path.parts:
            raise ResponseRejected(f"Unsafe path: {raw}")
        if not raw.startswith(allowed):
            raise ResponseRejected(f"Path outside allowlist: {raw}")
        if any(raw == item or raw.startswith(item.rstrip("/") + "/") for item in denied):
            raise ResponseRejected(f"Denied path: {raw}")
        if raw not in paths:
            paths.append(raw)
    return paths
