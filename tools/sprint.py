#!/usr/bin/env python3
from __future__ import annotations
import argparse,datetime as dt,json,os,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]; LOCK=ROOT/"agent/state/sprint.lock"
p=argparse.ArgumentParser(); p.add_argument("--runtime",choices=["ollama","lmstudio","llamacpp"],default=os.getenv("LOCAL_LLM_RUNTIME","ollama")); p.add_argument("--model",default=os.getenv("LOCAL_LLM_MODEL","qwen3-coder:30b")); p.add_argument("--hours",type=float,default=6); p.add_argument("--max-iterations",type=int,default=60); p.add_argument("--dry-run",action="store_true"); p.add_argument("--skip-export",action="store_true"); p.add_argument("--allow-missing-godot",action="store_true"); a=p.parse_args()
def run(xs,timeout=None): return subprocess.run(xs,cwd=ROOT,timeout=timeout,check=False).returncode
if LOCK.exists(): print(f"Sprint lock exists: {LOCK}",file=sys.stderr); raise SystemExit(2)
LOCK.write_text(json.dumps({"pid":os.getpid(),"started":dt.datetime.now(dt.timezone.utc).isoformat()})+"\n")
code=1
try:
 pre=[sys.executable,"tools/preflight.py","--runtime",a.runtime,"--model",a.model]+(["--allow-missing-godot"] if a.allow_missing_godot else [])
 if run(pre): code=2
 else:
  loop=[sys.executable,"agent/run_loop.py","--runtime",a.runtime,"--model",a.model,"--hours",str(a.hours),"--max-iterations",str(a.max_iterations)]+(["--dry-run"] if a.dry_run else [])
  code=run(loop,int(a.hours*3600)+900)
  if not a.dry_run and not a.skip_export and code==0: code=run([sys.executable,"tools/export_web.py"],700)
finally:
 run([sys.executable,"tools/report.py"]); LOCK.unlink(missing_ok=True)
raise SystemExit(code)
