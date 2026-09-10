extends SceneTree
##
## bot_test - let the CPU drivers play the whole game and report what breaks.
##
## WHY THIS EXISTS (2026-09-10)
## ---------------------------
## The headless boot gate only proves the project loads. It reported a clean project while the
## race could not start at all: six scripts called get_node("/root/GameState") and GameState was
## not registered as an autoload, so main.gd died on game_state.track_id and nine errors
## cascaded through centerline, spawns and rocks. Booting never saw it, because booting only
## loads title_screen.tscn. Nothing was actually playing the game.
##
## The game already ships CPU drivers, so it can play itself. This runs a full race on every
## track with four CPUs and asserts the invariants that must hold for a race to be a race.
##
## Failures print as
##     PROBLEM: <file>:<line>:1: <message> [bot-test]
## which is the shape improve-loop.mjs's picker already parses, so a failure becomes work the
## loop can pick up rather than a report someone has to read.
##
## Structured as a state machine driven by _process, NOT a while loop: SceneTree.physics_frame
## and process_frame are Signals in Godot 4, so a script cannot step frames by calling them.
## The engine drives the loop; this decides what to do on each tick.
##
##   godot --headless --path game --script res://tools/bot_test.gd
##
## Exit code is 1 if any invariant failed, so it is usable as a gate.

# get_track is a static func, so preload the script rather than reaching for the autoload -
# a SceneTree script runs before the scene tree is populated the way a node would expect.
const TracksScript = preload("res://scripts/tracks.gd")

const RACERS := 4
const TIME_SCALE := 20
const MAX_SECONDS_PER_RACE := 600.0
# From track_geometry.offset_loop: miter_length is capped at abs(offset) * 1.7, so a boundary
# vertex never sits further than 1.7x half-width from the centerline. racer.gd uses a radius-20
# CircleShape2D and main.gd builds wall segments 14px thick.
const MITER_CAP := 1.7
const CAR_RADIUS := 20.0
const WALL_HALF_THICKNESS := 7.0
const STUCK_SECONDS := 25.0          # generous: CPUs legitimately slow in corners
const MAIN_SCENE := "res://scenes/main.tscn"
const MAIN_GD := "res://scripts/main.gd"
const RACER_GD := "res://scripts/racer.gd"

var _problems: Array[String] = []
var _summary: Array[String] = []
var _track_count := 0
var _track_id := -1
var _race: Node = null
var _elapsed := 0.0
var _last_lap := {}
var _last_pos := {}
var _last_move := {}
var _completed := false
var _warmup := 0
var _max_off := 0.0        # worst distance past the track edge, any car, this race


func _initialize() -> void:
	# Run game-time faster than wall-clock. Engine.time_scale multiplies how many physics steps
	# happen per real second WITHOUT changing the size of each step - _physics_process still
	# receives 1/60 - so car handling is bit-for-bit what a player would get, just sooner.
	# Without this, three races of up to 240 game-seconds take over twelve real minutes and the
	# run is useless as a gate. max_fps = 0 removes the frame cap that would otherwise throttle
	# the same loop back down.
	Engine.time_scale = TIME_SCALE
	Engine.max_fps = 0

	_track_count = _count_tracks()
	print("bot_test: %d track(s), %d CPU racer(s) each, time_scale %d" % [_track_count, RACERS, TIME_SCALE])


func _process(delta: float) -> bool:
	# Autoload _ready() has NOT run by the time _initialize() is called - GameState exists as a
	# node but has not registered its input actions yet. Waiting a couple of ticks before the
	# first race means the game under test is in the same state a player would find it.
	_warmup += 1
	if _warmup < 3:
		return false
	if _warmup == 3:
		return _next_race()

	if _race == null:
		return _finish_run()

	_elapsed += delta
	var racers: Array = _race.racers

	if racers.is_empty():
		_problem(MAIN_GD, 59, "no racers were spawned on %s" % _track_name())
		return _end_race()

	for i in racers.size():
		_check_racer(i, racers[i])

	if _race.finish_count >= RACERS:
		_completed = true
		return _end_race()
	if _elapsed >= MAX_SECONDS_PER_RACE:
		return _end_race()
	return false


func _check_racer(i: int, r) -> void:
	var who := "%s racer %d" % [_track_name(), i]

	if not _finite(r.position.x) or not _finite(r.position.y):
		_problem(RACER_GD, 11, "%s reached a non-finite position - physics has diverged" % who)
	if not _finite(r.speed):
		_problem(RACER_GD, 11, "%s has non-finite speed" % who)
	if not _finite(r.heading):
		_problem(RACER_GD, 10, "%s has non-finite heading" % who)
	if not _finite(r.boost) or r.boost < -0.001:
		_problem(RACER_GD, 12, "%s has invalid boost %s - it must never go negative" % [who, r.boost])

	if _last_lap.has(i) and r.lap < _last_lap[i]:
		_problem(RACER_GD, 13, "%s lap count went backwards, %d -> %d" % [who, _last_lap[i], r.lap])
	_last_lap[i] = r.lap

	# BOUNDARY CONTAINMENT, BOUNDED BY THE GEOMETRY THAT BUILDS THE WALLS.
	#
	# Two earlier attempts at this were wrong, and both failure modes are worth recording.
	#
	# A flat threshold of one track width could not tell a corner from an escape. offset_loop
	# places each boundary vertex with a MITER whose length is capped at 1.7x the offset, so on
	# a tight corner the wall genuinely sits far outside half-width and a car pressed against it
	# looked like it had left the track by 265px.
	#
	# Geometry2D.is_point_in_polygon against the boundary loops looked exact and is not usable
	# here: offset_loop can self-intersect on tight corners, and the test then reports points
	# plainly on the track as being inside the infield - it flagged (590, 120) on Desert Oval,
	# roughly 30px from a centerline whose half-width is 95.
	#
	# So the bound comes from the code that builds the walls. The furthest a wall can be from
	# the centerline is half_width * MITER_CAP; a contained car adds its own radius and the half
	# thickness of the wall segment. Anything beyond that could not be resting against a wall.
	var half_width: float = r.track_width / 2.0
	var limit: float = half_width * MITER_CAP + CAR_RADIUS + WALL_HALF_THICKNESS
	# Only measure a car that is actually racing. mark_finished zeroes its collision layers and
	# main.gd then coasts and viewport-clamps it, so a finished car drifts through walls by
	# design - including it made the reported maximum meaningless.
	if r.finished or not _race.race_started:
		return
	var dist: float = TracksScript.distance_to_centerline(r.position, r.centerline)
	if dist > _max_off:
		_max_off = dist
	if dist > limit:
		_problem(MAIN_GD, 67, "%s is %dpx from the centerline at %s, past the %dpx a wall can reach - the boundary is not containing it"
			% [who, int(dist), r.position, int(limit)])

	# Stuck detection applies only once the race is live and the car has not finished.
	if _race.race_started and not r.finished:
		if not _last_pos.has(i):
			_last_pos[i] = r.position
			_last_move[i] = _elapsed
		elif r.position.distance_to(_last_pos[i]) > 8.0:
			_last_pos[i] = r.position
			_last_move[i] = _elapsed
		elif _elapsed - _last_move[i] > STUCK_SECONDS:
			_problem(RACER_GD, 24, "%s has not moved for %ds - the CPU driver cannot recover" % [who, int(STUCK_SECONDS)])
			_last_move[i] = _elapsed      # report once per stall, not once per frame


func _end_race() -> bool:
	var racers: Array = _race.racers if _race != null else []
	if not _completed:
		var state := []
		for r in racers:
			state.append("lap %d cp %d%s" % [r.lap, r.checkpoint, " FINISHED" if r.finished else ""])
		_problem(MAIN_GD, 120, "race on %s did not finish inside %ds - final state %s"
			% [_track_name(), int(MAX_SECONDS_PER_RACE), str(state)])
	else:
		var seen := {}
		for r in racers:
			if seen.has(r.finish_place):
				_problem(MAIN_GD, 133, "two racers were both given finish place %d on %s"
					% [r.finish_place, _track_name()])
			seen[r.finish_place] = true

	var line := "  %-22s %s in %3ds   max %dpx from centerline" % [_track_name(), "COMPLETED" if _completed else "DID NOT FINISH", int(_elapsed), int(_max_off)]
	_summary.append(line)
	print(line)

	if _race != null:
		_race.queue_free()
		_race = null
	return _next_race()


func _next_race() -> bool:
	_track_id += 1
	if _track_id >= _track_count:
		return _finish_run()

	var game_state := root.get_node_or_null("GameState")
	if game_state == null:
		_problem(MAIN_GD, 26, "GameState autoload is missing; every scene calling get_node(\"/root/GameState\") will fail")
		return _finish_run()

	# All four seats CPU: joined[i] is the `human` flag passed to racer.setup().
	# Assign element-wise: `joined` is declared Array[bool], and assigning an untyped array
	# literal to it is rejected outright.
	for i in RACERS:
		game_state.joined[i] = false
	game_state.track_id = _track_id

	var packed: PackedScene = load(MAIN_SCENE)
	if packed == null:
		_problem(MAIN_GD, 1, "could not load %s" % MAIN_SCENE)
		return _finish_run()

	_race = packed.instantiate()
	root.add_child(_race)
	_elapsed = 0.0
	_completed = false
	_max_off = 0.0
	_last_lap.clear()
	_last_pos.clear()
	_last_move.clear()
	return false


func _finish_run() -> bool:
	print("")
	for line in _summary:
		print(line)
	print("")
	for p in _problems:
		print(p)
	print("\nBOT_TEST: %d race(s), %d problem(s)" % [_track_count, _problems.size()])
	quit(1 if _problems.size() > 0 else 0)
	return true


func _count_tracks() -> int:
	## Probe upward until a name repeats, so adding a fourth track needs no change here.
	var seen := {}
	var n := 0
	for i in 16:
		var t: Dictionary = TracksScript.get_track(i)
		if t.is_empty() or not t.has("name"):
			break
		var track_name: String = t["name"]
		if seen.has(track_name):
			break
		seen[track_name] = true
		n += 1
	return maxi(n, 1)


func _track_name() -> String:
	return TracksScript.get_track(_track_id).get("name", "track %d" % _track_id)


func _problem(file: String, line: int, message: String) -> void:
	# Emit a real filesystem path, never res://. The improve loop hands the picked path to an
	# agent that has to open the file - it tried to work on "res://scripts/main.gd", found
	# nothing on disk, and aborted before staging. globalize_path is what makes a finding here
	# actionable rather than merely readable.
	var entry := "PROBLEM: %s:%d:1: %s [bot-test]" % [ProjectSettings.globalize_path(file), line, message]
	if not _problems.has(entry):
		_problems.append(entry)


func _finite(v: float) -> bool:
	return not (is_nan(v) or is_inf(v))


func _polygon(points: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(p)
	return out


func _distance_to_polygon(point: Vector2, poly: PackedVector2Array) -> float:
	## How far the point sits from the nearest edge of the polygon. Used only to size a breach,
	## so that a car resting against a wall is not confused with one that drove through it.
	var best := INF
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var d := Geometry2D.get_closest_point_to_segment(point, a, b).distance_to(point)
		if d < best:
			best = d
	return best
