#!/usr/bin/env python3
"""Prepare an extracted copy without overwriting user configuration."""
from pathlib import Path
import shutil, subprocess, sys
ROOT=Path(__file__).resolve().parents[1]
if not (ROOT/".env").exists(): shutil.copy2(ROOT/".env.example",ROOT/".env"); print("created .env; select your runtime and model")
inside=subprocess.run(["git","rev-parse","--is-inside-work-tree"],cwd=ROOT,text=True,capture_output=True,check=False).returncode==0
if not inside:
    subprocess.run(["git","init","-b","main"],cwd=ROOT,check=True)
    print("initialized Git; review .env, then create the baseline commit before a sprint")
print("next: python3 tools/preflight.py --runtime ollama --model <installed-model>")
raise SystemExit(0)
