# Product requirements document

## Product

**Working title:** Iron Dust Rally  
**Version:** 0.1 vertical slice  
**Platform:** Modern desktop/mobile web browsers; keyboard and standard gamepads  
**Players:** 1–4 local, with CPU drivers filling unused slots

## Vision

Deliver the immediate readability, playful collisions, short races, and shared-screen social energy of a classic overhead off-road cabinet racer in an entirely original world. A new player should understand steering within ten seconds, complete a race within four minutes, and want an immediate rematch.

## Product principles

1. **Readable at a glance:** every car, checkpoint, hazard, pickup, and position change is legible on one screen.
2. **Arcade first:** responsive handling and dramatic feedback outrank simulation accuracy.
3. **Together on one device:** joining, playing, finishing, and rematching require no account.
4. **Original identity:** desert festival, fictional drivers, original tracks, vehicles, UI, audio, and vocabulary.
5. **Web dependable:** quick load, stable 60 FPS target, no mandatory server, graceful gamepad fallback.

## Target audience

- Families and friends sharing a screen.
- Arcade racing fans seeking three-to-five-minute sessions.
- Streamers/event booths needing low-friction local competition.

## Core loop

Join → select driver/vehicle → race three laps → collect boost and cash → finish/score → choose an upgrade → rematch or next track.

The vertical slice implements join/fallback, race, boost, laps, finish, standings, and restart. Selection, cash, upgrades, audio, and multiple tracks are backlog items.

## Functional requirements

### FR-1 Race

- Four vehicles share one fixed overhead camera.
- Race begins after a three-second countdown.
- A lap counts only after checkpoints are crossed in order.
- Default race length is three laps, configurable by track resource later.
- Finish order is stable; unfinished racers rank by lap, checkpoint, then distance to next checkpoint.

### FR-2 Handling

- Accelerate, brake/reverse, steer, coast, and use boost.
- Cars slide on dirt, lose speed off the racing surface, and bounce visibly from contact.
- Input should feel responsive at 60 Hz and remain playable at 30 Hz.

### FR-3 Local players

- Support keyboard for P1/P2 and up to four gamepads.
- Connected gamepads claim sequential human slots; unclaimed slots are CPU drivers.
- Menu navigation must work without a mouse.
- Controller disconnect must convert that car to CPU control without ending the race.

### FR-4 Pickups

- Boost pickups respawn after a delay.
- Boost has a visible meter and capped capacity.
- Pickups must not create an unbeatable runaway advantage.

### FR-5 Web

- Export from Godot 4 stable using GDScript.
- Initial preset is single-threaded for broad static-host compatibility.
- Save settings/progression only through browser-compatible `user://` storage.
- Target initial download under 25 MB and steady 60 FPS on a typical 2021 laptop.

### FR-6 Accessibility

- Do not communicate player identity or pickup type by color alone.
- Offer screen shake, vibration, and audio volume toggles before beta.
- Maintain strong text contrast and a scalable UI.

## Non-functional requirements

- Deterministic checkpoint/lap logic covered by tests.
- No runtime network dependency.
- No third-party telemetry by default.
- No secrets in client or repository.
- Original/provenanced assets only.
- Median frame time under 16.7 ms at 1080p on target hardware; 1% low above 30 FPS.

## Art direction

Stylized 2.5D presentation rendered with Godot 2D: chunky silhouettes, painted desert festival barriers, dust plumes, exaggerated suspension motion, high-contrast player markers. Avoid pixel-for-pixel retro imitation. Camera is near-orthographic top-down with enough angle suggested by shadows and vehicle shapes to show volume.

Palette anchors: sun-baked ochre, deep asphalt-brown, turquoise signage, cream UI, and distinct player accents plus numbered roof markers.

## Audio direction

Original layered engines whose pitch follows normalized speed, granular dirt/skid texture, crowd swells near the finish, concise pickup/boost cues, and a short original desert-rock/electronic score. Do not trace melodies, samples, announcer lines, or sound effects from existing games.

## Milestones

| Milestone | Exit criteria |
| --- | --- |
| M0 Foundation | Repo validates; main scene runs; loop dry-run works |
| M1 Vertical slice | One track, four cars, CPU fallback, laps, boost, results |
| M2 Feel | Collisions, surfaces, particles, camera/UI feedback, tuning tests |
| M3 Content | Three original tracks, six fictional drivers, upgrades, original audio |
| M4 Web beta | Export CI, browser matrix, performance/accessibility pass, save data |
| M5 Release | Legal/provenance audit, onboarding, analytics opt-in, hosting/runbook |

## Success metrics

- 80% of first-time testers finish a race without instruction.
- 60% choose rematch in an observed two-player session.
- Fewer than 2% sessions produce a stuck/invalid lap state.
- 95% of sampled frames meet the 30 FPS floor on the browser test matrix.

## Out of scope for v1

Online multiplayer, licensed real people/brands, exact legacy track recreations, realistic vehicle simulation, accounts, monetization, user-generated content, mobile touch controls, and backend services.

## Release acceptance

All P0/P1 tasks complete; four controllers tested; keyboard-only race tested; Chrome/Edge/Firefox desktop tested; Safari documented; provenance complete; no restricted references in shipped strings/assets; clean clone builds using documented commands.
