#!/usr/bin/env python3
import shutil, subprocess, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
godot=shutil.which("godot4") or shutil.which("godot")
if not godot:
    print("Godot 4 is required for autonomous code acceptance.",file=sys.stderr); raise SystemExit(2)
result=subprocess.run([godot,"--headless","--path","game","--quit-after","180"],cwd=ROOT,text=True,capture_output=True,timeout=240,check=False)
print((result.stdout+result.stderr)[-12000:]); raise SystemExit(result.returncode)
