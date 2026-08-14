#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,os,shutil,subprocess,sys,urllib.request,urllib.error
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]; sys.path.insert(0,str(ROOT))
from agent.run_loop import load_env_file
load_env_file(ROOT/".env")
p=argparse.ArgumentParser(); p.add_argument("--runtime",choices=["ollama","lmstudio","llamacpp"],default=os.getenv("LOCAL_LLM_RUNTIME","ollama")); p.add_argument("--model",default=os.getenv("LOCAL_LLM_MODEL","qwen3-coder:30b")); p.add_argument("--allow-missing-godot",action="store_true"); a=p.parse_args()
def cmd(xs):
 r=subprocess.run(xs,cwd=ROOT,text=True,capture_output=True,check=False); return r.returncode==0,(r.stdout+r.stderr).strip()
checks=[]; checks.append(("Python",sys.version_info>=(3,11),sys.version.split()[0])); checks.append(("Git",bool(shutil.which("git")),shutil.which("git") or "missing")); g=shutil.which("godot4") or shutil.which("godot"); checks.append(("Godot",bool(g) or a.allow_missing_godot,g or "missing"))
ok,out=cmd(["git","status","--porcelain"]); checks.append(("Clean worktree",ok and not out,out or "clean")); ok,out=cmd([sys.executable,"tools/validate_repo.py"]); checks.append(("Repository",ok,out.splitlines()[-1] if out else "failed")); ok,out=cmd([sys.executable,"-m","unittest","discover","-s","agent/tests","-q"]); checks.append(("Tests",ok,out.splitlines()[-1] if out else "passed"))
base={"ollama":os.getenv("OLLAMA_BASE_URL","http://127.0.0.1:11434")+"/api/tags","lmstudio":os.getenv("LMSTUDIO_BASE_URL","http://127.0.0.1:1234/v1")+"/models","llamacpp":os.getenv("LLAMACPP_BASE_URL","http://127.0.0.1:8080/v1")+"/models"}[a.runtime]
try:
 with urllib.request.urlopen(base,timeout=3) as response: json.loads(response.read().decode()); checks.append(("Local LLM",True,base))
except Exception as exc: checks.append(("Local LLM",False,f"{base}: {exc}"))
for name,ok,detail in checks: print(f"[{'OK' if ok else 'FAIL'}] {name}: {detail}")
raise SystemExit(0 if all(x[1] for x in checks) else 1)
