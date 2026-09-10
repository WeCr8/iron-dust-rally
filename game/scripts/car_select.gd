extends Node2D

const UIAtlas = preload("res://scripts/ui_atlas.gd")
const Vehicles = preload("res://scripts/vehicles.gd")
const MenuInput = preload("res://scripts/menu_input.gd")
const VEHICLE_ATLAS = preload("res://assets/art/vehicles_atlas.png")
# One atlas per paint colour, same 2x2 layout and region maths as the original.
# Pre-rendered rather than shaded at runtime so the web export stays a plain
# texture draw with no per-pixel work on a phone-class GPU.
const TINT_ATLASES := [
	preload("res://assets/art/vehicles_atlas_tint00.png"),
	preload("res://assets/art/vehicles_atlas_tint01.png"),
	preload("res://assets/art/vehicles_atlas_tint02.png"),
	preload("res://assets/art/vehicles_atlas_tint03.png"),
	preload("res://assets/art/vehicles_atlas_tint04.png"),
	preload("res://assets/art/vehicles_atlas_tint05.png"),
	preload("res://assets/art/vehicles_atlas_tint06.png"),
	preload("res://assets/art/vehicles_atlas_tint07.png"),
	preload("res://assets/art/vehicles_atlas_tint08.png"),
	preload("res://assets/art/vehicles_atlas_tint09.png"),
	preload("res://assets/art/vehicles_atlas_tint10.png"),
	preload("res://assets/art/vehicles_atlas_tint11.png")
]

var font: Font
var game_state: Node
var profiles: Node

func _ready() -> void:
	font = ThemeDB.fallback_font
	game_state = get_node("/root/GameState")
	profiles = get_node_or_null("/root/Profiles")

func _process(_delta: float) -> void:
	for i in 4:
		if not game_state.joined[i]:
			continue
		var left_action := "p%d_left" % (i + 1)
		var right_action := "p%d_right" % (i + 1)
		if InputMap.has_action(left_action) and Input.is_action_just_pressed(left_action):
			_cycle(i, -1)
		if InputMap.has_action(right_action) and Input.is_action_just_pressed(right_action):
			_cycle(i, 1)
		# Paint is on the other axis: left/right picks the buggy, up/down repaints it.
		var up_action := "p%d_accelerate" % (i + 1)
		var down_action := "p%d_brake" % (i + 1)
		if InputMap.has_action(up_action) and Input.is_action_just_pressed(up_action):
			_cycle_tint(i, 1)
		if InputMap.has_action(down_action) and Input.is_action_just_pressed(down_action):
			_cycle_tint(i, -1)
	queue_redraw()


func _unlocked_for(player_i: int) -> Array:
	# Unknown/guest racers get the free colours; a named profile gets whatever it earned.
	if profiles == null:
		return [0, 8, 5, 3]
	return profiles.unlocked_tints(game_state.seat_name(player_i))


func _cycle_tint(player_i: int, direction: int) -> void:
	var allowed: Array = _unlocked_for(player_i)
	if allowed.is_empty():
		return
	var current: int = game_state.tint_index[player_i]
	var at: int = allowed.find(current)
	if at == -1:
		at = 0
	else:
		at = (at + direction + allowed.size()) % allowed.size()
	game_state.tint_index[player_i] = int(allowed[at])
	if profiles != null:
		profiles.remember_tint(game_state.seat_name(player_i), int(allowed[at]))

func _cycle(player_i: int, direction: int) -> void:
	var taken := {}
	for j in 4:
		if game_state.joined[j] and j != player_i:
			taken[game_state.car_index[j]] = true
	var idx: int = game_state.car_index[player_i]
	for _n in 4:
		idx = (idx + direction + 4) % 4
		if not taken.has(idx):
			break
	game_state.car_index[player_i] = idx

func _unhandled_input(event: InputEvent) -> void:
	if MenuInput.confirm_pressed(event):
		get_tree().change_scene_to_file("res://scenes/track_select.tscn")
	elif MenuInput.cancel_pressed(event):
		get_tree().change_scene_to_file("res://scenes/join_screen.tscn")

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("2b1c12"), true)
	draw_string(font, Vector2(0, 60), "CHOOSE YOUR CAR", HORIZONTAL_ALIGNMENT_CENTER, 1280, 34, Color("fff3d4"))
	var joined_indices: Array[int] = []
	for i in 4:
		if game_state.joined[i]:
			joined_indices.append(i)
	var slot_count := joined_indices.size()
	var gap: float = 1280.0 / float(slot_count + 1)
	for slot in slot_count:
		var player_i: int = joined_indices[slot]
		var car_i: int = game_state.car_index[player_i]
		var vehicle: Dictionary = Vehicles.get_vehicle(car_i)
		var color: Color = vehicle["color"]
		var cx: float = gap * (slot + 1)
		var region := Rect2(Vector2((car_i % 2) * 619, (car_i / 2) * 635), Vector2(619, 635))
		var display_size := Vector2(180, 184)
		var tint_i: int = clampi(game_state.tint_index[player_i], 0, TINT_ATLASES.size() - 1)
		draw_texture_rect_region(TINT_ATLASES[tint_i], Rect2(Vector2(cx - display_size.x / 2.0, 220), display_size), region)
		# Seat label carries the racer's name when they have one - on a TV across the room
		# "MAYA" is far easier to find than "P2".
		var who: String = game_state.seat_name(player_i)
		var seat_label: String = "P%d" % (player_i + 1) if who.strip_edges() == "" else "P%d  %s" % [player_i + 1, who.to_upper()]
		draw_string(font, Vector2(cx - 140, 430), seat_label, HORIZONTAL_ALIGNMENT_CENTER, 280, 16, Color(1, 1, 1, 0.6))
		draw_string(font, Vector2(cx - 140, 455), vehicle["name"], HORIZONTAL_ALIGNMENT_CENTER, 280, 22, color)
		draw_string(font, Vector2(cx - 140, 478), vehicle["blurb"], HORIZONTAL_ALIGNMENT_CENTER, 280, 13, Color(1, 1, 1, 0.7))
		var stats_text := "SPD %d%%  ACC %d%%  BOOST %d%%" % [int(vehicle["speed_mult"] * 100), int(vehicle["accel_mult"] * 100), int(vehicle["boost_mult"] * 100)]
		draw_string(font, Vector2(cx - 140, 500), stats_text, HORIZONTAL_ALIGNMENT_CENTER, 280, 13, Color("ffd166"))
		var tint: Dictionary = Vehicles.get_tint(tint_i)
		var allowed: Array = _unlocked_for(player_i)
		draw_string(font, Vector2(cx - 140, 522), "PAINT: %s  (%d of %d)" % [tint["name"], allowed.size(), Vehicles.tint_count()], HORIZONTAL_ALIGNMENT_CENTER, 280, 13, tint["color"])
		draw_string(font, Vector2(cx - 140, 542), "< car >     ^ paint v", HORIZONTAL_ALIGNMENT_CENTER, 280, 12, Color(1, 1, 1, 0.4))
		if profiles != null and who.strip_edges() != "":
			var pts: int = profiles.points_for(who)
			draw_string(font, Vector2(cx - 140, 566), "%d pts" % pts, HORIZONTAL_ALIGNMENT_CENTER, 280, 14, Color("ffd166"))
			var nxt: Dictionary = profiles.next_unlock(who)
			if not nxt.is_empty():
				var nxt_tint: Dictionary = Vehicles.get_tint(int(nxt["tint"]))
				draw_string(font, Vector2(cx - 140, 586), "%d more -> %s" % [int(nxt["needed"]), nxt_tint["name"]], HORIZONTAL_ALIGNMENT_CENTER, 280, 12, Color(1, 1, 1, 0.45))
	draw_string(font, Vector2(0, 650), "click / press start to continue", HORIZONTAL_ALIGNMENT_CENTER, 1280, 18, Color("ffd166"))
