#!/usr/bin/env python3
import datetime as dt,json,subprocess
from collections import Counter
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]; tasks=json.loads((ROOT/"agent/tasks.json").read_text())["tasks"]; runs=sorted((ROOT/"agent/runs").glob("*/events.jsonl")); events=[json.loads(x) for x in runs[-1].read_text().splitlines() if x.strip()] if runs else []
tc=Counter(t["status"] for t in tasks); ec=Counter(e.get("event") for e in events); commits=subprocess.run(["git","log","--oneline","-20"],cwd=ROOT,text=True,capture_output=True,check=False).stdout
lines=["# Autonomous sprint handoff","",f"Generated: {dt.datetime.now(dt.timezone.utc).isoformat()}",f"Tasks: {dict(tc)}",f"Events: {dict(ec)}",f"Last event: {events[-1].get('event') if events else 'none'}","","## Remaining work",""]
lines += [f"- **{t['id']} {t['title']}** — {t['status']}"+(f": {t.get('blocker')}" if t.get('blocker') else "") for t in tasks if t["status"]!="done"]
lines += ["","## Recent checkpoints","","```text",commits.strip(),"```","","## Human review required","","1. Play with keyboard and four gamepads.","2. Inspect feel, atlas crops, audio loudness, accessibility, and browser behavior.","3. Review every agent commit, blocked task, and asset/IP record before release.",""]
out=ROOT/"agent/reports/LATEST_HANDOFF.md"; out.parent.mkdir(parents=True,exist_ok=True); out.write_text("\n".join(lines)); print(out)
