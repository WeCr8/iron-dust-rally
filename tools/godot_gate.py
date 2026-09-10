#!/usr/bin/env python3
"""godot_gate - boot the game headless and fail on anything the engine complains about.

This is the gate that actually knows whether the game runs. check-project.mjs is a static
reference checker: it verifies that a referenced path EXISTS, which is necessary and not
sufficient. Godot does not load a raw PNG, it loads the imported artifact, so the project once
showed 0 critical findings while every preload in ui_atlas.gd failed at parse time and the game
did not boot. Only the engine can settle it.

Errors are re-emitted as `PROBLEM: file:line:col: message [rule]`, which is the shape the
improve loop's lint picker already parses. Without a file and a line the loop can measure this
project but cannot work it - it would have nothing to hand an agent.
"""
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def find_godot():
    """PATH first, then the places Windows installers actually put it.

    winget cannot create its command-line alias without admin rights, so on this fleet `godot`
    is frequently absent from PATH while the binary is present. Falling back to the known
    install roots is the difference between a working gate and one that reports "Godot is
    required" forever.
    """
    for name in ("godot4", "godot", "Godot"):
        found = shutil.which(name)
        if found:
            return found

    roots = [
        Path(os.environ.get("LOCALAPPDATA", "")) / "Microsoft" / "WinGet" / "Packages",
        Path(os.environ.get("ProgramFiles", "")) / "Godot",
        Path(os.environ.get("LOCALAPPDATA", "")) / "Programs" / "Godot",
    ]
    for root in roots:
        if not root.is_dir():
            continue
        # Prefer the console build: the plain win64 exe detaches from the terminal on Windows
        # and its output never reaches us, which reads as a silent pass.
        found = sorted(root.rglob("Godot_v*_console.exe")) or sorted(root.rglob("Godot_v*.exe"))
        if found:
            return str(found[-1])
    return None


godot = find_godot()
if not godot:
    print("Godot 4 is required for autonomous code acceptance.", file=sys.stderr)
    raise SystemExit(2)

result = subprocess.run(
    [godot, "--headless", "--path", "game", "--quit-after", "180"],
    cwd=ROOT, text=True, capture_output=True, timeout=240, check=False,
)
out = (result.stdout or "") + (result.stderr or "")
print(out[-12000:])

# Godot prints the location on a FOLLOWING line, as
#   at: GDScript::reload (res://scripts/ui_atlas.gd:64)
# so messages and locations must be paired up rather than read off one line.
lines = out.splitlines()
problems = []
for i, line in enumerate(lines):
    m = re.match(r"^(SCRIPT ERROR|ERROR):\s*(.+?)\s*$", line)
    if not m:
        continue
    message = m.group(2)
    where, lineno = "", 0
    for nxt in lines[i + 1:i + 3]:
        loc = re.search(r"\(res://([^:)]+):(\d+)\)", nxt)
        if loc:
            where, lineno = loc.group(1), int(loc.group(2))
            break
    if not where:
        continue          # engine-level error with no source location - not agent-fixable
    abs_path = (ROOT / "game" / where).as_posix()
    rule = "godot-parse" if "Parse Error" in message else "godot-runtime"
    problems.append("PROBLEM: {}:{}:1: {} [{}]".format(abs_path, lineno, message, rule))

for p_line in problems:
    print(p_line)

# Godot exits 0 even when an autoload fails to instantiate, so the return code alone would call
# a broken game green. Count instead.
errors = re.findall(r"^(?:SCRIPT ERROR|ERROR):", out, re.MULTILINE)
print("\nGODOT_GATE: {} engine error(s), {} locatable, exit {}".format(
    len(errors), len(problems), result.returncode))

raise SystemExit(result.returncode if result.returncode else (1 if errors else 0))
