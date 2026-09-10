# Test gaps — what is covered, what is not, and who can close it

**2026-09-10.** Written after installing Godot 4 and getting the game bot-testable.

## How the loop actually works, and what that means for this list

The improve loop repairs **gate failures**. It measures a gate, picks the file with the biggest
cluster of failures, hands it to a model, re-measures, and keeps the change only if the count
went down. It does not author new test coverage from a wishlist — nothing in it can read
"reverse crossing is untested" and write the test.

So an item here becomes loop-actionable only once an **assertion exists and fails**. Writing the
assertion is the human half; making it pass can be the loop's half. Items are grouped by that.

Current gate state: `python tools/godot_gate.py` → **0 boot errors, 0 script parse errors,
0 gameplay failures**. The loop has nothing to correct on this project right now, and that is
the correct answer rather than a problem.

---

## Covered now

- [x] Project imports and boots headless with no engine errors
- [x] Every one of the 14 `.gd` scripts parses (`--check-only`, not just the 4 autoloads)
- [x] A full four-CPU race completes on all three tracks
- [x] No NaN or infinite position, speed or heading
- [x] Boost stays within `[0, 100]` — both floor and the cap `add_boost` enforces
- [x] Lap count never decreases
- [x] Checkpoint index never moves backwards
- [x] No car sits motionless for 25s while racing
- [x] Finish places are unique
- [x] Cars stay within `half_width * 1.7 + 27` of the centerline — the furthest a wall can reach
- [x] Races are deterministic: identical results across repeated runs

## Loop-actionable once someone writes the assertion

Each of these is a real invariant with no test behind it. Write it as a failing assertion in
`tools/bot_test.gd` and the loop can take the repair.

- [ ] **Reverse crossing is rejected.** `_crossed_checkpoint` requires `crossed_forward`,
      `moving_forward` and `lateral <= width * 0.55`. The logic reads correctly and has never
      been exercised. Testable directly: place a racer past a checkpoint, set
      `previous_position` ahead of `position`, assert no credit.
- [ ] **Restart resets race state.** `_start_race()` clears racers, walls, rocks, pickups,
      `finish_count`, `countdown` and `finish_grace`. Callable directly; assert each field.
- [ ] **Tie finish.** Two cars crossing on the same step must still receive distinct places.
      `finish_count` increments per racer so this probably holds; unverified.
- [ ] **Collision recovery.** `cpu_stuck_time` / `cpu_recovery_time` exist and the 25s stuck
      check never fires, so recovery works in the cases the CPUs hit. Deliberately driving a car
      into a wall and asserting it recovers is untested.
- [ ] **Off-track penalty.** `OFF_TRACK_PENALTY` bleeds speed toward zero past `width/2`.
      Assert that a car placed off-track decelerates.
- [ ] **Pickups and rocks.** `_update_pickups` and `_update_rocks` run every step and nothing
      asserts a pickup grants boost or that a rock cooldown expires.

## Needs a human — not loop work

- [ ] **Corner cutting.** Max checkpoint advance in a single step is 4 / 7 / 6 across the three
      tracks. Checkpoints are ~42px apart and a car covers ~5.5px per step, so crossing several
      in one step is not physically possible — `_crossed_checkpoint` is accepting checkpoints the
      car passed *near*. The acceptance window is `lateral <= width * 0.55`. Tightening it
      changes how the game plays, so it is a design decision, not a defect. The number is
      printed every run so a regression is visible.
- [ ] **Human input paths.** The bot drives only CPUs. A player reaches states a CPU never will:
      deliberate wall-riding, reversing off a jump, holding boost into a corner. Requires
      synthesised input events, and the assertions are about feel as much as correctness.
- [ ] **Game feel.** `docs/TEST_PLAN.md` already says it and is right: ten races, recorded
      completion times, lead changes, a 1-5 handling score. No loop substitutes for a controller.
- [ ] **Keyboard bindings.** Arrows for P1, WASD for P2, Shift/Tab boost, R restart. Registered
      at runtime in `game_state.gd` to match how seats 3-4 already work. Moving them into a
      `project.godot [input]` block would make them visible in the editor's Input Map panel.
      Someone should decide which, and whether these are the right keys.
- [ ] **Web export.** `tools/export_web.py` exists; export templates are not installed and the
      browser matrix in TEST_PLAN has never been run.
- [ ] **Resolution scaling and gamepad hot-plug.** 720p-4K, and connect/disconnect mid-race.
      Both need a display.
- [ ] **Placeholder art.** The seven generated atlases are flat hatched rectangles standing in
      for real art. `ASSET_LICENSES.md` records them as placeholders.

---

## Running it

    python tools/godot_gate.py        # import -> boot + parse all scripts -> race all tracks

About 25 seconds. Exit 1 on any failure. It is the registered gate for `iron-dust-rally` in the
improve loop's `projects.json`.
