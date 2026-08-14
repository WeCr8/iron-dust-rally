class_name RallyRacer
extends CharacterBody2D

var player_index := 0
var human := false
var accent := Color.WHITE
var heading := -PI / 2.0
var speed := 0.0
var boost := 45.0
var lap := 0
var checkpoint := 0
var finished := false
var finish_place := 0
var next_target := Vector2.ZERO
var track_center := Vector2(640, 360)

const MAX_SPEED := 330.0
const REVERSE_SPEED := 105.0
const ACCEL := 235.0
const BRAKE := 300.0
const COAST := 115.0
const TURN_RATE := 2.45
const VEHICLE_ATLAS = preload("res://assets/art/vehicles_atlas.png")

func setup(index: int, is_human: bool, color: Color, spawn: Vector2) -> void:
	player_index = index
	human = is_human
	accent = color
	position = spawn
	_add_vehicle_art(index)
	queue_redraw()

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
	if finished:
		speed = move_toward(speed, 0.0, COAST * delta)
		velocity = Vector2.from_angle(heading) * speed
		move_and_slide()
		return
	var intent: Vector3 = _human_intent() if human else _cpu_intent()
	var throttle: float = intent.x
	var steer: float = intent.y
	if throttle > 0.0:
		speed = move_toward(speed, MAX_SPEED, ACCEL * throttle * delta)
	elif throttle < 0.0:
		speed = move_toward(speed, -REVERSE_SPEED, BRAKE * -throttle * delta)
	else:
		speed = move_toward(speed, 0.0, COAST * delta)
	if intent.z > 0.5 and boost > 0.0 and speed > 30.0:
		speed = min(speed + 260.0 * delta, MAX_SPEED * 1.34)
		boost = max(0.0, boost - 28.0 * delta)
	var steering_scale: float = clamp(abs(speed) / 95.0, 0.15, 1.0)
	heading += steer * TURN_RATE * steering_scale * delta * sign(speed if abs(speed) > 2.0 else 1.0)
	var radial := position.distance_to(track_center)
	if radial < 150.0 or radial > 335.0:
		speed = move_toward(speed, 0.0, 210.0 * delta)
	velocity = Vector2.from_angle(heading) * speed
	move_and_slide()
	rotation = heading

func _human_intent() -> Vector3:
	var prefix := "p%d_" % (player_index + 1)
	if not InputMap.has_action(prefix + "accelerate"):
		return _cpu_intent()
	var throttle := Input.get_action_strength(prefix + "accelerate") - Input.get_action_strength(prefix + "brake")
	var steer := Input.get_action_strength(prefix + "right") - Input.get_action_strength(prefix + "left")
	return Vector3(throttle, steer, 1.0 if Input.is_action_pressed(prefix + "boost") else 0.0)

func _cpu_intent() -> Vector3:
	var desired := position.direction_to(next_target).angle()
	var error := wrapf(desired - heading, -PI, PI)
	var steer: float = clamp(error * 1.8, -1.0, 1.0)
	var throttle: float = 0.58 if abs(error) > 1.15 else 1.0
	var use_boost: bool = boost > 20.0 and abs(error) < 0.18 and position.distance_to(next_target) > 220.0
	return Vector3(throttle, steer, 1.0 if use_boost else 0.0)

func add_boost(amount: float) -> void:
	boost = min(100.0, boost + amount)

func _draw() -> void:
	draw_circle(Vector2.ZERO, 22.0, Color(0.08, 0.07, 0.06, 0.45))
