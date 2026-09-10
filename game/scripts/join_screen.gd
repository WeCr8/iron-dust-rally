extends Node2D

const UIAtlas = preload("res://scripts/ui_atlas.gd")
const MenuInput = preload("res://scripts/menu_input.gd")

var font: Font
var game_state: Node
var profiles: Node

# Seat currently being named, or -1 when nobody is typing. Typing is keyboard-only:
# an on-screen A-Z picker driven by a gamepad is slow and nobody enjoys it. Players
# without a keyboard cycle saved profiles with the TAB key instead.
var naming_seat: int = -1
var naming_buffer: String = ""

func _ready() -> void:
	font = ThemeDB.fallback_font
	game_state = get_node("/root/GameState")
	profiles = get_node_or_null("/root/Profiles")

func _process(_delta: float) -> void:
	for i in range(1, 4):
		var action := "p%d_accelerate" % (i + 1)
		if InputMap.has_action(action) and Input.is_action_just_pressed(action):
			game_state.joined[i] = not game_state.joined[i]
	queue_redraw()

func _finish_naming() -> void:
	if naming_seat >= 0:
		game_state.set_seat_name(naming_seat, naming_buffer.strip_edges())
	naming_seat = -1
	naming_buffer = ""


func _cycle_saved_profile(seat: int, direction: int) -> void:
	# TAB walks the saved names for this seat, so returning players never retype.
	if profiles == null:
		return
	var names: Array = profiles.all_names()
	if names.is_empty():
		return
	var current: String = game_state.seat_name(seat)
	var at: int = names.find(current)
	at = 0 if at == -1 else (at + direction + names.size()) % names.size()
	game_state.set_seat_name(seat, String(names[at]))


func _naming_input(event: InputEvent) -> bool:
	# Returns true when the event was consumed by name entry.
	if naming_seat < 0 or not (event is InputEventKey) or not event.pressed or event.echo:
		return false
	var code: int = event.physical_keycode
	if code == KEY_ENTER or code == KEY_KP_ENTER:
		_finish_naming()
		return true
	if code == KEY_ESCAPE:
		naming_seat = -1
		naming_buffer = ""
		return true
	if code == KEY_BACKSPACE:
		naming_buffer = naming_buffer.substr(0, maxi(0, naming_buffer.length() - 1))
		return true
	var ch: String = char(event.unicode)
	# Letters, digits and spaces only, capped at 12 so it still fits under the badge.
	if event.unicode >= 32 and naming_buffer.length() < 12 and ch.strip_edges() != "":
		naming_buffer += ch
		return true
	if event.unicode == 32 and naming_buffer.length() < 12:
		naming_buffer += " "
		return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if _naming_input(event):
		queue_redraw()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var kc: int = event.physical_keycode
		# 1-4 start naming that seat; TAB cycles seat 1 through saved profiles.
		if kc >= KEY_1 and kc <= KEY_4:
			var seat: int = kc - KEY_1
			if game_state.joined[seat]:
				naming_seat = seat
				naming_buffer = game_state.seat_name(seat)
				queue_redraw()
				return
		if kc == KEY_TAB:
			_cycle_saved_profile(0, 1)
			queue_redraw()
			return

	# Player 2-4 controllers use their accelerate button to toggle joining,
	# so only mouse/keyboard/Player-1's controller may advance the screen
	# here, otherwise toggling a player in would immediately leave the screen.
	var is_confirm := false
	if event is InputEventMouseButton and event.pressed:
		is_confirm = true
	elif event is InputEventKey and event.pressed and not event.echo:
		var code: int = event.physical_keycode
		is_confirm = code == KEY_ENTER or code == KEY_SPACE or code == KEY_KP_ENTER
	elif event is InputEventJoypadButton and event.pressed and event.device == 0 and event.button_index == JOY_BUTTON_A:
		is_confirm = true
	if is_confirm:
		get_tree().change_scene_to_file("res://scenes/car_select.tscn")
	elif MenuInput.cancel_pressed(event):
		get_tree().change_scene_to_file("res://scenes/title_screen.tscn")

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("2b1c12"), true)
	draw_string(font, Vector2(0, 70), "SELECT PLAYERS", HORIZONTAL_ALIGNMENT_CENTER, 1280, 34, Color("fff3d4"))
	var badge_size := Vector2(170, 266)
	var start_x := 200.0
	var gap := 260.0
	for i in 4:
		var pos := Vector2(start_x + i * gap, 260)
		draw_texture_rect_region(UIAtlas.TEXTURE, Rect2(pos, badge_size), UIAtlas.BADGE_REGIONS[i])
		# Name plate under each badge: who is in this seat, and what they have banked.
		var nm: String = game_state.seat_name(i)
		var plate: String
		var plate_col: Color
		if naming_seat == i:
			plate = naming_buffer + "_"
			plate_col = Color("ffd166")
		elif nm.strip_edges() != "":
			plate = nm.to_upper()
			plate_col = Color("fff3d4")
		elif game_state.joined[i]:
			plate = "press %d to name" % (i + 1)
			plate_col = Color(1, 1, 1, 0.35)
		else:
			plate = ""
			plate_col = Color(1, 1, 1, 0.2)
		draw_string(font, Vector2(pos.x - 45, pos.y + 300), plate, HORIZONTAL_ALIGNMENT_CENTER, 260, 18, plate_col)
		if profiles != null and nm.strip_edges() != "" and naming_seat != i:
			var prof: Dictionary = profiles.get_profile(nm)
			draw_string(font, Vector2(pos.x - 45, pos.y + 324), "%d pts   %d races   %d wins" % [int(prof.get("points", 0)), int(prof.get("races", 0)), int(prof.get("wins", 0))], HORIZONTAL_ALIGNMENT_CENTER, 260, 12, Color("ffd166"))
		var ready: bool = i == 0 or game_state.joined[i]
		var label: String = "READY" if ready else "CPU"
		draw_string(font, pos + Vector2(-15, 300), label, HORIZONTAL_ALIGNMENT_CENTER, 200, 20, Color("06d6a0") if ready else Color(1, 1, 1, 0.5))
		var hint := ""
		if i == 1:
			hint = "press to toggle"
		elif i >= 2:
			var action := "p%d_accelerate" % (i + 1)
			hint = "press to toggle" if InputMap.has_action(action) else "connect gamepad"
		if hint != "":
			draw_string(font, pos + Vector2(-15, 325), hint, HORIZONTAL_ALIGNMENT_CENTER, 200, 12, Color(1, 1, 1, 0.4))
	draw_string(font, Vector2(0, 650), "click / press start to continue", HORIZONTAL_ALIGNMENT_CENTER, 1280, 18, Color("ffd166"))
	draw_string(font, Vector2(0, 690), "press 1-4 to type a name   TAB cycles saved racers   ENTER to confirm", HORIZONTAL_ALIGNMENT_CENTER, 1280, 14, Color(1, 1, 1, 0.4))
