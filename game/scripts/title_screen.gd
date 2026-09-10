extends Node2D

const UIAtlas = preload("res://scripts/ui_atlas.gd")
const MenuInput = preload("res://scripts/menu_input.gd")

var font: Font
var blink_t := 0.0

func _ready() -> void:
	font = ThemeDB.fallback_font

func _process(delta: float) -> void:
	blink_t += delta
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if MenuInput.confirm_pressed(event):
		var game_state := get_node("/root/GameState")
		game_state.reset_join_state()
		get_tree().change_scene_to_file("res://scenes/join_screen.tscn")

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("2b1c12"), true)
	var logo_size := Vector2(820, 339)
	var logo_pos := Vector2(640, 230) - logo_size / 2.0
	draw_texture_rect_region(UIAtlas.TEXTURE, Rect2(logo_pos, logo_size), UIAtlas.LOGO_REGION)
	if fmod(blink_t, 1.0) < 0.65:
		draw_string(font, Vector2(440, 560), "PRESS START", HORIZONTAL_ALIGNMENT_CENTER, 400, 34, Color("ffd166"))
	draw_string(font, Vector2(290, 605), "1-4 PLAYERS   KEYBOARD, MOUSE, OR GAMEPAD", HORIZONTAL_ALIGNMENT_CENTER, 700, 16, Color(1, 1, 1, 0.7))
