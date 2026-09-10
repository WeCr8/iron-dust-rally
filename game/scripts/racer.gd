class_name RallyRacer
extends CharacterBody2D

const Tracks = preload("res://scripts/tracks.gd")
const Vehicles = preload("res://scripts/vehicles.gd")

var player_index := 0
var human := false
var accent := Color.WHITE
var heading := -PI / 2.0
var speed := 0.0
var boost := 45.0
var lap := 0
var checkpoint := 1
var finished := false
var finish_place := 0
var next_target := Vector2.ZERO
var centerline: Array = []
var track_width := 190.0
var jumps: Array = []
var speed_mult := 1.0
var accel_mult := 1.0
var boost_mult := 1.0
var cpu_stuck_time := 0.0
var cpu_recovery_time := 0.0
var cpu_progress_sample := Vector2.ZERO
var cpu_sample_time := 0.0
var previous_position := Vector2.ZERO

const MAX_SPEED := 330.0
const REVERSE_SPEED := 105.0
const ACCEL := 235.0
const BRAKE := 300.0
const COAST := 115.0
const TURN_RATE := 2.45
const OFF_TRACK_PENALTY := 480.0
const VIEWPORT_MARGIN := 24.0
const VEHICLE_ATLAS = preload("res://assets/art/vehicles_atlas.png")

func setup(index: int, is_human: bool, spawn: Vector2, car_index: int, track: Dictionary) -> void:
	player_index = index
	human = is_human
	position = spawn
	centerline = track["centerline"]
	checkpoint = 1 if centerline.size() > 1 else 0
	next_target = centerline[checkpoint]
	previous_position = spawn
	track_width = track["width"]
	jumps = track["jumps"]
	var vehicle: Dictionary = Vehicles.get_vehicle(car_index)
	accent = vehicle["color"]
	speed_mult = vehicle["speed_mult"]
	accel_mult = vehicle["accel_mult"]
	boost_mult = vehicle["boost_mult"]
	cpu_progress_sample = spawn
	_add_vehicle_art(car_index)
	_add_collision_shape()
	queue_redraw()

func _add_collision_shape() -> void:
	var shape := CircleShape2D.new()
	shape.radius = 20.0
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)

func _add_vehicle_art(index: int) -> void:
	var atlas := AtlasTexture.new()
	atlas.atlas = VEHICLE_ATLAS
	var cell_size := Vector2(619, 635)
	atlas.region = Rect2(Vector2((index % 2) * 619, (index / 2) * 635), cell_size)
	var sprite := Sprite2D.new()
	sprite.texture = atlas
	sprite.scale = Vector2(0.088, 0.088)
	sprite.rotation = -PI / 2.0
	sprite.z_index = 1
	add_child(sprite)

func _physics_process(delta: float) -> void:
	previous_position = position
	if finished:
		speed = move_toward(speed, 0.0, COAST * delta)
		velocity = Vector2.from_angle(heading) * speed
		move_and_slide()
		_clamp_to_viewport()
		return
	if not human:
		_update_cpu_recovery(delta)
	var intent: Vector3 = _human_intent() if human else _cpu_intent()
	var throttle: float = intent.x
	var steer: float = intent.y
	var max_speed: float = MAX_SPEED * speed_mult
	var off_track := not _in_jump_zone() and Tracks.distance_to_centerline(position, centerline) > track_width / 2.0
	if off_track:
		speed = move_toward(speed, 0.0, OFF_TRACK_PENALTY * delta)
	elif throttle > 0.0:
		speed = move_toward(speed, max_speed, ACCEL * accel_mult * throttle * delta)
	elif throttle < 0.0:
		speed = move_toward(speed, -REVERSE_SPEED, BRAKE * -throttle * delta)
	else:
		speed = move_toward(speed, 0.0, COAST * delta)
	if not off_track and intent.z > 0.5 and boost > 0.0 and speed > 30.0:
		speed = min(speed + 260.0 * boost_mult * delta, max_speed * 1.34)
		boost = max(0.0, boost - 28.0 * delta)
	var steering_scale: float = clamp(abs(speed) / 95.0, 0.15, 1.0)
	heading += steer * TURN_RATE * steering_scale * delta * sign(speed if abs(speed) > 2.0 else 1.0)
	velocity = Vector2.from_angle(heading) * speed
	move_and_slide()
	_clamp_to_viewport()
	rotation = heading

func _clamp_to_viewport() -> void:
	var clamped := Vector2(
		clampf(position.x, VIEWPORT_MARGIN, 1280.0 - VIEWPORT_MARGIN),
		clampf(position.y, VIEWPORT_MARGIN, 720.0 - VIEWPORT_MARGIN)
	)
	if clamped != position:
		position = clamped
		speed = move_toward(speed, 0.0, 260.0)

func _in_jump_zone() -> bool:
	for jump in jumps:
		var center: Vector2 = jump["center"]
		var radius: float = jump["radius"]
		if position.distance_to(center) < radius:
			return true
	return false

func _human_intent() -> Vector3:
	var prefix := "p%d_" % (player_index + 1)
	if not InputMap.has_action(prefix + "accelerate"):
		return _cpu_intent()
	var throttle := Input.get_action_strength(prefix + "accelerate") - Input.get_action_strength(prefix + "brake")
	var steer := Input.get_action_strength(prefix + "right") - Input.get_action_strength(prefix + "left")
	return Vector3(throttle, steer, 1.0 if Input.is_action_pressed(prefix + "boost") else 0.0)

func _cpu_intent() -> Vector3:
	if cpu_recovery_time > 0.0:
		var recovery_error := wrapf(position.direction_to(next_target).angle() - heading, -PI, PI)
		var recovery_steer := -1.0 if recovery_error >= 0.0 else 1.0
		return Vector3(-1.0, recovery_steer, 0.0)
	var target := next_target
	if not centerline.is_empty():
		# Aim through the checkpoint toward the following section. This keeps
		# CPU cars from steering at a point behind them after entering a turn.
		var following: Vector2 = centerline[(checkpoint + 1) % centerline.size()]
		target = next_target.lerp(following, 0.28)
	var desired := position.direction_to(target).angle()
	var error := wrapf(desired - heading, -PI, PI)
	var steer: float = clamp(error * 1.8, -1.0, 1.0)
	var throttle: float = 0.42 if abs(error) > 1.15 else (0.72 if abs(error) > 0.65 else 1.0)
	var use_boost: bool = boost > 20.0 and abs(error) < 0.16 and position.distance_to(target) > 240.0
	return Vector3(throttle, steer, 1.0 if use_boost else 0.0)

func _update_cpu_recovery(delta: float) -> void:
	if cpu_recovery_time > 0.0:
		cpu_recovery_time = maxf(0.0, cpu_recovery_time - delta)
		cpu_progress_sample = position
		cpu_stuck_time = 0.0
		return
	cpu_sample_time += delta
	if cpu_sample_time < 0.5:
		return
	var moved := position.distance_to(cpu_progress_sample)
	# Displacement is authoritative here. CharacterBody collisions can leave
	# the commanded speed high while the car is physically pinned in place.
	if moved < 9.0:
		cpu_stuck_time += cpu_sample_time
	else:
		cpu_stuck_time = maxf(0.0, cpu_stuck_time - cpu_sample_time * 2.0)
	cpu_progress_sample = position
	cpu_sample_time = 0.0
	if cpu_stuck_time >= 1.5:
		cpu_recovery_time = 1.15
		cpu_stuck_time = 0.0

func add_boost(amount: float) -> void:
	boost = min(100.0, boost + amount)

func hit_rock() -> void:
	speed = move_toward(speed, 0.0, 260.0)

func mark_finished(place: int) -> void:
	finished = true
	finish_place = place
	collision_layer = 0
	collision_mask = 0

func _draw() -> void:
	draw_circle(Vector2.ZERO, 22.0, Color(0.08, 0.07, 0.06, 0.45))
