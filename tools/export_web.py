#!/usr/bin/env python3
import shutil, subprocess, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]; OUT=ROOT/"build/web/index.html"
godot=shutil.which("godot4") or shutil.which("godot")
if not godot: print("Godot 4 not found",file=sys.stderr); raise SystemExit(2)
OUT.parent.mkdir(parents=True,exist_ok=True)
r=subprocess.run([godot,"--headless","--path","game","--export-release","Web","../build/web/index.html"],cwd=ROOT,text=True,capture_output=True,timeout=600,check=False)
print((r.stdout+r.stderr)[-16000:])
missing=[p for p in (OUT,OUT.with_suffix('.wasm'),OUT.with_suffix('.pck')) if not p.exists()]
raise SystemExit(r.returncode or (1 if missing else 0))
