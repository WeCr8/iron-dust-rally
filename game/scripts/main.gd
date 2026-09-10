extends Node2D

const Racer = preload("res://scripts/racer.gd")
const Tracks = preload("res://scripts/tracks.gd")
const Vehicles = preload("res://scripts/vehicles.gd")
const UIAtlas = preload("res://scripts/ui_atlas.gd")
const TrackGeometry = preload("res://scripts/track_geometry.gd")

var racers: Array[RallyRacer] = []
var pickup_active: Array[bool] = []
var pickup_timers: Array[float] = []
var rock_cooldowns: Array[float] = []
var finish_count := 0
var countdown := 3.0
var race_started := false
var title_font: Font
var track: Dictionary
var game_state: Node
var wall_bodies: Array = []
var rock_bodies: Array = []
var finish_grace := -1.0
var race_finishing := false

func _ready() -> void:
	title_font = ThemeDB.fallback_font
	game_state = get_node("/root/GameState")
	track = Tracks.get_track(game_state.track_id)
	_start_race()

func _start_race() -> void:
	for racer in racers:
		racer.queue_free()
	racers.clear()
	for body in wall_bodies:
		body.queue_free()
	wall_bodies.clear()
	for body in rock_bodies:
		body.queue_free()
	rock_bodies.clear()
	finish_count = 0
	finish_grace = -1.0
	race_finishing = false
	countdown = 3.0
	race_started = false
	var pickups: Array = track["pickups"]
	pickup_active.clear()
	pickup_timers.clear()
	for i in pickups.size():
		pickup_active.append(true)
		pickup_timers.append(0.0)
	var rocks: Array = track["rocks"]
	rock_cooldowns.clear()
	for i in rocks.size():
		rock_cooldowns.append(0.0)
	_build_track_walls()
	_build_rock_bodies()
	var spawns: Array = track["spawns"]
	for i in 4:
		var racer := RallyRacer.new()
		add_child(racer)
		racer.setup(i, game_state.joined[i], spawns[i], game_state.car_index[i], track)
		racer.set_physics_process(false)
		racers.append(racer)
	queue_redraw()

func _build_track_walls() -> void:
	for edge in [track["outer_boundary"], track["inner_boundary"]]:
		for i in edge.size():
			wall_bodies.append(_add_wall_segment(edge[i], edge[(i + 1) % edge.size()]))

func _add_wall_segment(a: Vector2, b: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = (a + b) * 0.5
	body.rotation = (b - a).angle()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(a.distance_to(b) + 12.0, 14.0)
	var col := CollisionShape2D.new()
	col.shape = shape
	body.add_child(col)
	add_child(body)
	return body

func _build_rock_bodies() -> void:
	var rocks: Array = track["rocks"]
	for pos in rocks:
		rock_bodies.append(_add_bollard(pos, 22.0))

func _add_bollard(pos: Vector2, radius: float) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = pos
	var shape := CircleShape2D.new()
	shape.radius = radius
	var col := CollisionShape2D.new()
	col.shape = shape
	body.add_child(col)
	add_child(body)
	return body

func _process(_delta: float) -> void:
	# Input polling belongs here - it is per-frame by nature and must feel immediate.
	if Input.is_action_just_pressed("restart"):
		_start_race()
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
	queue_redraw()


func _physics_process(delta: float) -> void:
	# RACE STATE RUNS AT THE FIXED RATE, NOT THE FRAME RATE.
	#
	# This used to live in _process, and it made lap counting frame-rate dependent. Racer sets
	# `previous_position = position` at the top of every _physics_process, so it is always
	# exactly one physics step old. _crossed_checkpoint compares previous_position against
	# position to catch a sign flip across the checkpoint - a window of one physics step, about
	# 5.5px at full speed.
	#
	# When _process ran slower than physics, several physics steps passed between checks. The
	# car moved the full distance but the crossing test only ever saw the last 5.5px of it, so
	# any checkpoint crossed inside the gap was missed and the lap never counted. On a machine
	# that dropped frames, laps simply stopped registering.
	#
	# That is exactly what made races unfinishable while main.gd polled a missing "restart"
	# action: the per-frame error spam tanked the frame rate, and lap detection went with it.
	# Fixing the input binding hid the symptom; sampling at the fixed rate removes the cause.
	# It also makes a race deterministic, which is what lets the bot test assert on lap times.
	if not race_started:
		countdown -= delta
		if countdown <= 0.0:
			race_started = true
			for racer in racers:
				racer.set_physics_process(true)
		return

	_update_race_progress()
	_update_pickups(delta)
	_update_rocks(delta)
	if finish_grace > 0.0:
		finish_grace -= delta
		if finish_grace <= 0.0:
			_finish_remaining_racers()

func _update_race_progress() -> void:
	# CREDIT EVERY CHECKPOINT CROSSED THIS STEP, NOT JUST ONE.
	#
	# The centerline is dense - around 56 points on these tracks - and a car at full speed
	# covers several of them in a single step. Crediting one per call made progress depend on
	# how often this function ran: polled many times per physics step it banked them all, polled
	# once per step it banked one and the rest were lost, so the same car took three times
	# longer to finish the same lap. Neither answer was the track's actual length.
	#
	# Looping until the crossing test stops passing removes the rate dependence entirely: a step
	# credits exactly the checkpoints the car actually drove through. The bound is a guard, not
	# a limit - it can only be reached if the test somehow always passes, and silently spinning
	# inside a physics step would freeze the game.
	var checkpoints: Array = track["centerline"]
	for racer in racers:
		if racer.finished:
			continue
		var credited := 0
		while credited < checkpoints.size():
			var target: Vector2 = checkpoints[racer.checkpoint]
			racer.next_target = target
			if not _crossed_checkpoint(racer, target):
				break
			credited += 1
			if racer.checkpoint == 0:
				racer.lap += 1
				if racer.lap >= 3:
					finish_count += 1
					racer.mark_finished(finish_count)
					if finish_count == 1:
						finish_grace = 20.0
					break
				racer.checkpoint = 1 if checkpoints.size() > 1 else 0
			else:
				racer.checkpoint = (racer.checkpoint + 1) % checkpoints.size()
	if finish_count >= 4:
		_finish_race()

func _crossed_checkpoint(racer: RallyRacer, target: Vector2) -> bool:
	var checkpoints: Array = track["centerline"]
	var index := racer.checkpoint
	var prev: Vector2 = checkpoints[(index - 1 + checkpoints.size()) % checkpoints.size()]
	var next: Vector2 = checkpoints[(index + 1) % checkpoints.size()]
	var tangent := (next - prev).normalized()
	var old_offset := racer.previous_position - target
	var new_offset := racer.position - target
	var crossed_forward := old_offset.dot(tangent) < 0.0 and new_offset.dot(tangent) >= 0.0
	var moving_forward := (racer.position - racer.previous_position).dot(tangent) > 0.0
	var lateral := absf(new_offset.cross(tangent))
	return crossed_forward and moving_forward and lateral <= track["width"] * 0.55

func _finish_remaining_racers() -> void:
	var unfinished: Array[RallyRacer] = []
	for racer in racers:
		if not racer.finished:
			unfinished.append(racer)
	var checkpoint_count: int = track["centerline"].size()
	unfinished.sort_custom(func(a: RallyRacer, b: RallyRacer):
		var a_score := a.lap * checkpoint_count + a.checkpoint
		var b_score := b.lap * checkpoint_count + b.checkpoint
		if a_score != b_score:
			return a_score > b_score
		return a.position.distance_to(a.next_target) < b.position.distance_to(b.next_target)
	)
	for racer in unfinished:
		finish_count += 1
		racer.mark_finished(finish_count)
	_finish_race()

func _finish_race() -> void:
	if race_finishing:
		return
	race_finishing = true
	var results: Array = []
	for racer in racers:
		results.append({"player_index": racer.player_index, "finish_place": racer.finish_place, "human": racer.human})
	results.sort_custom(func(a, b): return a["finish_place"] < b["finish_place"])
	game_state.last_results = results
	get_tree().change_scene_to_file("res://scenes/results.tscn")

func _update_pickups(delta: float) -> void:
	var pickups: Array = track["pickups"]
	for i in pickups.size():
		if not pickup_active[i]:
			pickup_timers[i] -= delta
			if pickup_timers[i] <= 0.0:
				pickup_active[i] = true
				continue
		for racer in racers:
			if racer.position.distance_to(pickups[i]) < 34.0:
				racer.add_boost(35.0)
				pickup_active[i] = false
				pickup_timers[i] = 5.0
				break

func _update_rocks(delta: float) -> void:
	var rocks: Array = track["rocks"]
	for i in rocks.size():
		if rock_cooldowns[i] > 0.0:
			rock_cooldowns[i] -= delta
			continue
		for racer in racers:
			if racer.position.distance_to(rocks[i]) < 40.0:
				racer.hit_rock()
				rock_cooldowns[i] = 1.2
				break

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("6b4a2f"), true)
	_draw_terrain()
	_draw_track_surface()
	_draw_track_walls()
	_draw_start_finish()
	var rocks: Array = track["rocks"]
	for pos in rocks:
		_draw_rock_cluster(pos)
	var jumps: Array = track["jumps"]
	for jump in jumps:
		var center: Vector2 = jump["center"]
		var radius: float = jump["radius"]
		draw_texture_rect_region(UIAtlas.ENV_TEXTURE, Rect2(center - Vector2(radius, radius) * 0.7, Vector2(radius, radius) * 1.4), UIAtlas.SIGNPOST)
	var pickups: Array = track["pickups"]
	for i in pickups.size():
		if pickup_active[i]:
			var p: Vector2 = pickups[i]
			var battery_size := Vector2(38.0 * UIAtlas.BATTERY_ASPECT, 38.0)
			draw_texture_rect_region(UIAtlas.ENV_TEXTURE, Rect2(p - battery_size / 2.0, battery_size), UIAtlas.BATTERY)
	draw_string(title_font, Vector2(28, 42), track["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("fff3d4"))
	for i in racers.size():
		var racer: RallyRacer = racers[i]
		var status: String = ("FIN %d" % racer.finish_place) if racer.finished else ("LAP %d/3  BOOST %d" % [min(racer.lap + 1, 3), int(racer.boost)])
		draw_rect(Rect2(28, 66 + i * 34, 255, 26), Color(0.05, 0.04, 0.03, 0.78), true)
		draw_circle(Vector2(42, 79 + i * 34), 7.0, racer.accent)
		draw_string(title_font, Vector2(56, 85 + i * 34), "P%d  %s%s" % [i + 1, status, " CPU" if not racer.human else ""], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
	if not race_started:
		var text: String = str(max(1, ceili(countdown))) if countdown > 0.0 else "GO!"
		draw_string(title_font, Vector2(585, 380), text, HORIZONTAL_ALIGNMENT_CENTER, 110, 64, Color.WHITE)

func _draw_rock_cluster(center: Vector2) -> void:
	# The source prop atlas is opaque, so drawing its crop leaves a visible
	# square. A small shaded cluster reads cleanly on every terrain surface.
	_draw_ellipse(center + Vector2(3, 10), Vector2(34, 14), Color(0.08, 0.05, 0.03, 0.35))
	var offsets := [Vector2(-17, 3), Vector2(13, 7), Vector2(-4, -9), Vector2(18, -7), Vector2(1, 8)]
	var radii := [14.0, 15.0, 17.0, 11.0, 13.0]
	for i in offsets.size():
		var p: Vector2 = center + offsets[i]
		draw_circle(p, radii[i], Color("5b3928"))
		draw_circle(p + Vector2(-3, -4), radii[i] * 0.58, Color("946344"))

func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 24:
		var angle := TAU * float(i) / 24.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)

func _draw_terrain() -> void:
	# Ground tiles have an irregular painted edge, not a seamless tileable
	# border, so tiling them in a grid leaves visible seams. Stretching a
	# single instance across the whole background reads far better than a
	# grid of visibly-bordered squares.
	draw_texture_rect_region(UIAtlas.TERRAIN_ATLAS_TEXTURE, Rect2(0, 0, 1280, 720), UIAtlas.TERRAIN_SAND)

func _draw_track_surface() -> void:
	var checkpoints: Array = track["centerline"]
	var width: float = track["width"]
	var loop := TrackGeometry.closed(checkpoints)
	# A continuous silhouette guarantees a clean course edge; inset texture
	# stamps add material detail without defining the outline themselves.
	draw_polyline(loop, Color("30291f"), width + 18.0, true)
	draw_polyline(loop, Color("9a7248"), width, true)
	var texture_width := width - 30.0
	var spacing: float = texture_width * 0.55
	for i in checkpoints.size():
		var a: Vector2 = checkpoints[i]
		var b: Vector2 = checkpoints[(i + 1) % checkpoints.size()]
		var seg: Vector2 = b - a
		var length: float = seg.length()
		if length < 0.01:
			continue
		var count: int = max(1, int(ceil(length / spacing)))
		for step in count + 1:
			var t: float = float(step) / float(count)
			var mid: Vector2 = a + seg * t
			draw_texture_rect_region(UIAtlas.TERRAIN_ATLAS_TEXTURE, Rect2(mid - Vector2(texture_width, texture_width) / 2.0, Vector2(texture_width, texture_width)), UIAtlas.TERRAIN_HARDPACK, Color(1, 1, 1, 0.74))

func _draw_start_finish() -> void:
	var checkpoints: Array = track["centerline"]
	var start_point: Vector2 = checkpoints[0]
	var dir: Vector2 = track["start_direction"]
	var normal: Vector2 = track["start_normal"]
	var half_width: float = track["width"] / 2.0
	var squares := 8
	var square_size: float = (half_width * 2.0) / squares
	var stripe_depth := 16.0
	for i in squares:
		var t0: float = -half_width + i * square_size
		var t1: float = t0 + square_size
		var a: Vector2 = start_point + normal * t0
		var b: Vector2 = start_point + normal * t1
		var a2: Vector2 = a + dir * stripe_depth
		var b2: Vector2 = b + dir * stripe_depth
		var color: Color = Color.WHITE if i % 2 == 0 else Color(0.05, 0.05, 0.05)
		draw_colored_polygon(PackedVector2Array([a, b, b2, a2]), color)
	draw_string(title_font, start_point - dir * 34.0 - Vector2(20, 0), "START", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("fff3d4"))

func _draw_track_walls() -> void:
	var checkpoints: Array = track["centerline"]
	var count: int = checkpoints.size()
	var outer: Array = track["outer_boundary"]
	var inner: Array = track["inner_boundary"]
	_draw_boundary_outline(outer)
	_draw_boundary_outline(inner)
	_draw_corner_barriers(checkpoints, outer, inner, count)
	_draw_boundary_bollards(outer)
	_draw_boundary_bollards(inner)

func _draw_boundary_outline(points: Array[Vector2]) -> void:
	var loop := TrackGeometry.closed(points)
	draw_polyline(loop, Color(0.10, 0.08, 0.06, 0.92), 18.0, true)
	draw_polyline(loop, Color("ead6a1"), 8.0, true)

func _draw_corner_barriers(checkpoints: Array, outer_points: Array[Vector2], inner_points: Array[Vector2], count: int) -> void:
	# One bollard marker on each side of every turn vertex, using whichever
	# reference art (30/45/60/90/180-degree arc) is closest to how sharp
	# that particular turn actually is, rather than one fixed corner piece
	# regardless of angle. Bucket boundaries sit at the midpoints between
	# the five canonical angles the art was made for.
	for i in count:
		var prev: Vector2 = checkpoints[(i - 1 + count) % count]
		var cur: Vector2 = checkpoints[i]
		var next: Vector2 = checkpoints[(i + 1) % count]
		var dir_in: Vector2 = (cur - prev).normalized()
		var dir_out: Vector2 = (next - cur).normalized()
		var turn_deg: float = rad_to_deg(abs(dir_in.angle_to(dir_out)))
		if turn_deg < 20.0:
			continue
		var outer: Vector2 = outer_points[i]
		var inner: Vector2 = inner_points[i]
		var texture: Texture2D
		var region: Rect2
		var aspect: float
		if turn_deg < 37.5:
			texture = UIAtlas.GENTLE_BOLLARD_TEXTURE
			region = UIAtlas.GENTLE_BOLLARD
			aspect = UIAtlas.GENTLE_BOLLARD_ASPECT
		elif turn_deg < 52.5:
			texture = UIAtlas.BOLLARD_45_TEXTURE
			region = UIAtlas.BOLLARD_45
			aspect = UIAtlas.BOLLARD_45_ASPECT
		elif turn_deg < 75.0:
			texture = UIAtlas.BOLLARD_60_TEXTURE
			region = UIAtlas.BOLLARD_60
			aspect = UIAtlas.BOLLARD_60_ASPECT
		elif turn_deg < 135.0:
			texture = UIAtlas.CORNER_BOLLARD_TEXTURE
			region = UIAtlas.CORNER_BOLLARD
			aspect = UIAtlas.CORNER_BOLLARD_ASPECT
		else:
			texture = UIAtlas.BOLLARD_180_TEXTURE
			region = UIAtlas.BOLLARD_180
			aspect = UIAtlas.BOLLARD_180_ASPECT
		var corner_size := Vector2(34.0, 34.0 / aspect)
		draw_texture_rect_region(texture, Rect2(outer - corner_size / 2.0, corner_size), region)
		draw_texture_rect_region(texture, Rect2(inner - corner_size / 2.0, corner_size), region)

func _draw_straight_bollards(outer_points: Array[Vector2], inner_points: Array[Vector2], count: int) -> void:
	# Alternating branded bollard posts along each straight run, leaving a
	# margin near each vertex for the corner piece drawn above.
	var bollard_size := Vector2(30.0, 30.0 / UIAtlas.BOLLARD_ASPECT)
	var spacing := 50.0
	var edge_margin := 40.0
	for side in [outer_points, inner_points]:
		for i in count:
			var a: Vector2 = side[i]
			var b: Vector2 = side[(i + 1) % count]
			var seg: Vector2 = b - a
			var length: float = seg.length()
			if length < edge_margin * 2.0 + spacing:
				continue
			var dir: Vector2 = seg / length
			var usable: float = length - edge_margin * 2.0
			var steps: int = max(1, int(round(usable / spacing)))
			for step in steps + 1:
				var t: float = edge_margin + (usable * step) / steps
				var mid: Vector2 = a + dir * t
				var region: Rect2 = UIAtlas.STRAIGHT_BOLLARD_A if step % 2 == 0 else UIAtlas.STRAIGHT_BOLLARD_B
				draw_texture_rect_region(UIAtlas.BOLLARD_TEXTURE, Rect2(mid - bollard_size / 2.0, bollard_size), region)

func _draw_boundary_bollards(points: Array) -> void:
	var bollard_size := Vector2(20.0, 20.0 / UIAtlas.BOLLARD_ASPECT)
	var spacing := 72.0
	var distance_until_next := spacing * 0.5
	var sequence := 0
	for i in points.size():
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i + 1) % points.size()]
		var segment := b - a
		var length := segment.length()
		if length < 0.01:
			continue
		while distance_until_next <= length:
			var mid := a + segment * (distance_until_next / length)
			var region: Rect2 = UIAtlas.STRAIGHT_BOLLARD_A if sequence % 2 == 0 else UIAtlas.STRAIGHT_BOLLARD_B
			draw_texture_rect_region(UIAtlas.BOLLARD_TEXTURE, Rect2(mid - bollard_size / 2.0, bollard_size), region)
			sequence += 1
			distance_until_next += spacing
		distance_until_next -= length
