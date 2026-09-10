extends Node2D

const MenuInput = preload("res://scripts/menu_input.gd")
const Vehicles = preload("res://scripts/vehicles.gd")

var font: Font
var game_state: Node
var profiles: Node
var _awarded := false

func _ready() -> void:
	font = ThemeDB.fallback_font
	game_state = get_node("/root/GameState")
	profiles = get_node_or_null("/root/Profiles")
	_award_points()


func _award_points() -> void:
	# Runs once per results screen. Guarded because _ready can fire again if the scene
	# is re-entered, and nobody should bank a race twice for pressing back.
	if _awarded or profiles == null:
		return
	_awarded = true
	game_state.last_points = [0, 0, 0, 0]
	for entry in game_state.last_results:
		var seat: int = int(entry["player_index"])
		var who: String = game_state.seat_name(seat)
		if who.strip_edges() == "":
			continue
		var gained: int = profiles.award(who, int(entry["finish_place"]), bool(entry["human"]))
		game_state.last_points[seat] = gained

func _unhandled_input(event: InputEvent) -> void:
	if MenuInput.confirm_pressed(event):
		get_tree().change_scene_to_file("res://scenes/race.tscn")
	elif MenuInput.cancel_pressed(event):
		get_tree().change_scene_to_file("res://scenes/title_screen.tscn")

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("2b1c12"), true)
	draw_string(font, Vector2(0, 90), "RACE COMPLETE", HORIZONTAL_ALIGNMENT_CENTER, 1280, 42, Color("ffd166"))
	var results: Array = game_state.last_results
	for i in results.size():
		var entry: Dictionary = results[i]
		var player_i: int = entry["player_index"]
		var y: float = 200.0 + i * 70.0
		draw_rect(Rect2(390, y, 500, 54), Color(0.08, 0.07, 0.06, 0.85), true)
		var vehicle: Dictionary = Vehicles.get_vehicle(game_state.car_index[player_i])
		var color: Color = vehicle["color"]
		draw_circle(Vector2(420, y + 27), 12.0, color)
		var tag: String = "" if entry["human"] else "  CPU"
		var who: String = game_state.seat_name(player_i)
		var label: String = "P%d" % (player_i + 1) if who.strip_edges() == "" else who.to_upper()
		draw_string(font, Vector2(450, y + 35), "%d.  %s  %s%s" % [entry["finish_place"], label, vehicle["name"], tag], HORIZONTAL_ALIGNMENT_LEFT, 420, 22, Color.WHITE)
		# Points earned, and the running total, so the reason to race again is on screen.
		var gained: int = int(game_state.last_points[player_i])
		if gained > 0 and profiles != null:
			draw_string(font, Vector2(700, y + 35), "+%d" % gained, HORIZONTAL_ALIGNMENT_RIGHT, 120, 22, Color("ffd166"))
			draw_string(font, Vector2(700, y + 35), "%d pts" % profiles.points_for(who), HORIZONTAL_ALIGNMENT_RIGHT, 185, 15, Color(1, 1, 1, 0.55))
	draw_string(font, Vector2(0, 620), "click / press start to rematch     ESC/B for main menu", HORIZONTAL_ALIGNMENT_CENTER, 1280, 18, Color(1, 1, 1, 0.6))
