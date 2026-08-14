#!/usr/bin/env python3
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[1]
for relative in ("build", "game/.godot"):
    target = ROOT / relative
    if target.exists():
        shutil.rmtree(target)
        print(f"removed {relative}")
