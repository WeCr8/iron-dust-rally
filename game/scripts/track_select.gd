extends Node2D

const Tracks = preload("res://scripts/tracks.gd")
const MenuInput = preload("res://scripts/menu_input.gd")

var font: Font
var game_state: Node

func _ready() -> void:
	font = ThemeDB.fallback_font
	game_state = get_node("/root/GameState")

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_left") or Input.is_action_just_pressed("p1_left"):
		game_state.track_id = (game_state.track_id + Tracks.LIST.size() - 1) % Tracks.LIST.size()
	if Input.is_action_just_pressed("ui_right") or Input.is_action_just_pressed("p1_right"):
		game_state.track_id = (game_state.track_id + 1) % Tracks.LIST.size()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if MenuInput.confirm_pressed(event):
		get_tree().change_scene_to_file("res://scenes/race.tscn")
	elif MenuInput.cancel_pressed(event):
		get_tree().change_scene_to_file("res://scenes/car_select.tscn")

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("2b1c12"), true)
	draw_string(font, Vector2(0, 55), "SELECT TRACK", HORIZONTAL_ALIGNMENT_CENTER, 1280, 34, Color("fff3d4"))
	var track: Dictionary = Tracks.get_track(game_state.track_id)
	draw_string(font, Vector2(0, 100), "%d / %d" % [game_state.track_id + 1, Tracks.LIST.size()], HORIZONTAL_ALIGNMENT_CENTER, 1280, 16, Color(1, 1, 1, 0.5))
	draw_string(font, Vector2(0, 145), track["name"], HORIZONTAL_ALIGNMENT_CENTER, 1280, 40, Color("ffd166"))
	_draw_preview(track)
	draw_string(font, Vector2(0, 650), "< / >  choose track     click / press start to race", HORIZONTAL_ALIGNMENT_CENTER, 1280, 18, Color(1, 1, 1, 0.6))

func _draw_preview(track: Dictionary) -> void:
	var scale_factor := 0.42
	var offset := Vector2(640, 420)
	var to_preview := func(p: Vector2) -> Vector2:
		return offset + (p - Vector2(640, 360)) * scale_factor
	var centerline: Array = track["centerline"]
	var half_width: float = track["width"] * scale_factor / 2.0
	var preview_line := PackedVector2Array()
	for point in centerline:
		preview_line.append(to_preview.call(point))
	preview_line.append(preview_line[0])
	draw_polyline(preview_line, Color("17120e"), half_width * 2.0 + 8.0, true)
	draw_polyline(preview_line, Color("765234"), half_width * 2.0, true)
	for boundary_key in ["outer_boundary", "inner_boundary"]:
		var boundary := PackedVector2Array()
		for point in track[boundary_key]:
			boundary.append(to_preview.call(point))
		boundary.append(boundary[0])
		draw_polyline(boundary, Color("ead6a1"), 3.0, true)
	# Start stripe uses the exact runtime tangent and width.
	var start: Vector2 = to_preview.call(centerline[0])
	var normal: Vector2 = track["start_normal"]
	draw_line(start - normal * half_width, start + normal * half_width, Color.WHITE, 5.0, true)
	for pos in track["rocks"]:
		draw_circle(to_preview.call(pos), 7.0, Color("8a5a3c"))
	for pos in track["pickups"]:
		draw_circle(to_preview.call(pos), 6.0, Color("56cfe1"))
	for jump in track["jumps"]:
		var center: Vector2 = jump["center"]
		draw_circle(to_preview.call(center), 9.0, Color(1, 0.85, 0.4, 0.55))
