#!/usr/bin/env python3
"""godot_gate - boot the game headless, parse every script, and fail on anything the engine
complains about.

This is the gate that actually knows whether the game runs. check-project.mjs is a static
reference checker: it verifies that a referenced path EXISTS, which is necessary and not
sufficient. Godot loads imported artifacts, not raw source assets, so the project once reported
0 critical findings while every preload in ui_atlas.gd failed at parse time and the game did not
boot. Only the engine can settle it.

Errors are re-emitted as `PROBLEM: file:line:col: message [rule]`, the shape the improve loop's
lint picker already parses. Without a file and a line the loop can measure this project but
cannot work it - it would have nothing to hand an agent.
"""
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT / "game"


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


def godot_run(args, timeout):
    r = subprocess.run([godot, "--headless", "--path", "game"] + args,
                       cwd=ROOT, text=True, capture_output=True, timeout=timeout, check=False)
    return r, (r.stdout or "") + (r.stderr or "")


godot = find_godot()
if not godot:
    print("Godot 4 is required for autonomous code acceptance.", file=sys.stderr)
    raise SystemExit(2)

# IMPORT FIRST, ALWAYS. The import cache lives in game/.godot/, which is gitignored - correctly,
# it is rebuildable. But that made this gate's answer depend on whether a cache happened to
# exist:
#
#   warm (.godot present)   0 engine errors
#   cold (fresh checkout)  52 engine errors, 19 locatable
#
# Same commit, same code. Every improve-loop worktree is a fresh checkout, so the loop measured
# a cold baseline, watched an agent silence inference errors that existed only because nothing
# had been imported, and recorded it as a real improvement. A gate whose result depends on
# leftover build state is not a gate.
imported, _ = godot_run(["--import"], 600)
if imported.returncode:
    print("WARNING: asset import returned {}".format(imported.returncode), file=sys.stderr)

result, out = godot_run(["--quit-after", "180"], 240)
print(out[-12000:])

problems = []


def add(path, lineno, message, rule):
    entry = "PROBLEM: {}:{}:1: {} [{}]".format(path, lineno, message, rule)
    if entry not in problems:
        problems.append(entry)


# Godot prints the location on a FOLLOWING line, as
#   at: GDScript::reload (res://scripts/ui_atlas.gd:64)
# so messages and locations must be paired up rather than read off one line.
lines = out.splitlines()
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
    add((GAME / where).as_posix(), lineno, message,
        "godot-parse" if "Parse Error" in message else "godot-runtime")

boot_errors = len(re.findall(r"^(?:SCRIPT ERROR|ERROR):", out, re.MULTILINE))

# PER-SCRIPT PARSE CHECK. Booting only parses what the startup path reaches - the four autoloads
# and the main scene. A deliberately broken racer.gd sailed through cleanly because it is a
# spawned entity, not a singleton, so nothing loaded it. That is 4 of 14 scripts covered, and
# the 10 it misses are exactly where an agent is most likely to be editing.
#
# `--check-only --script` parses one file and exits 1 on a parse error, so running it over every
# .gd file closes the gap. About a second per script; cheap next to booting.
script_errors = 0
for gd in sorted(GAME.rglob("*.gd")):
    rel = gd.relative_to(GAME).as_posix()
    chk, chk_out = godot_run(["--check-only", "--script", "res://" + rel], 120)
    if not chk.returncode:
        continue
    for m in re.finditer(r"^SCRIPT ERROR:\s*(.+?)\s*$", chk_out, re.MULTILINE):
        script_errors += 1
        loc = re.search(r"\(res://" + re.escape(rel) + r":(\d+)\)", chk_out)
        add(gd.as_posix(), int(loc.group(1)) if loc else 1, m.group(1), "godot-parse")

for p_line in problems:
    print(p_line)

total = boot_errors + script_errors
print("\nGODOT_GATE: {} engine error(s) on boot, {} script parse error(s), "
      "{} locatable, exit {}".format(boot_errors, script_errors, len(problems), result.returncode))

# Godot exits 0 even when an autoload fails to instantiate, so the return code alone would call
# a broken game green. Count instead.
raise SystemExit(result.returncode if result.returncode else (1 if total else 0))
