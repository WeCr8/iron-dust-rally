# Test plan

## Automated gates

1. Repository structure/config validation (`tools/validate_repo.py`).
2. Orchestrator unit tests (`agent/tests`).
3. Godot import/parse smoke test in headless mode when installed.
4. Web export smoke test when export templates are installed.

## Gameplay test matrix

| Area | Cases |
| --- | --- |
| Input | keyboard P1/P2; 1–4 gamepads; hot-unplug; reconnect; held input at countdown |
| Race | ordered checkpoints; reverse crossing; missed checkpoint; lap increment; tie finish; restart |
| Vehicle | accelerate; reverse; steering at zero speed; boost cap/depletion; off-track drag; collision recovery |
| CPU | completes race; unsticks; targets checkpoint; uses boost; no NaN/stationary loop |
| UI | 1–4 human players; position/lap/boost; countdown; results; controller focus; 720p–4K scaling |
| Web | Chrome, Edge, Firefox, Safari; focus loss; fullscreen; gamepad permission/activation; audio activation |

## Playtest rubric

After every handling/content milestone, run ten races: two solo, two keyboard co-op, three mixed controllers, three four-controller. Record completion time, wrong-way events, stuck events, lead changes, rematch choice, and qualitative handling score (1–5). Do not let autonomous tests substitute for game-feel review.

## Performance

Profile 1080p with four cars and maximum effects. Capture average, 1% low, memory, initial compressed download, and first-interaction load time. Budget particle counts and audio voices explicitly before content expansion.
