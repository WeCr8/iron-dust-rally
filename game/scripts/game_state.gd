extends Node

var joined: Array[bool] = [true, false, false, false]
var car_index: Array[int] = [0, 1, 2, 3]
var track_id: int = 0
var last_results: Array = []

# Who is sitting in each seat, and what paint they picked. Empty name = an anonymous
# guest: they can still race, they just bank no points and get the free colours only.
var player_name: Array[String] = ["", "", "", ""]
var tint_index: Array[int] = [0, 8, 5, 3]
# Points earned in the last race, per seat, so the results screen can show "+10".
var last_points: Array[int] = [0, 0, 0, 0]

func _ready() -> void:
	_setup_keyboard_inputs()
	_setup_extra_gamepad_inputs()

func _setup_keyboard_inputs() -> void:
	# Players 1 and 2 are keyboard, and NOTHING registered their actions. project.godot has no
	# [input] section at all, and _setup_extra_gamepad_inputs below only covers seats 3 and 4.
	# racer.gd:131 bails out when `pN_accelerate` is missing, so a human car received zero input
	# and simply sat there - the game was unplayable by keyboard, which is the default seat.
	# main.gd also polls "restart" unguarded, which spammed
	#     ERROR: The InputMap action "restart" doesn't exist
	# every single frame.
	#
	# Registered here rather than in project.godot to match how seats 3 and 4 are already done.
	# Moving all of them into a project.godot [input] block would be better - it makes the
	# bindings visible and editable in the editor's Input Map panel - but that is a change of
	# approach, not a bug fix.
	var keyboard := {
		"p1_accelerate": [KEY_UP],
		"p1_brake": [KEY_DOWN],
		"p1_left": [KEY_LEFT],
		"p1_right": [KEY_RIGHT],
		"p1_boost": [KEY_SHIFT],
		"p2_accelerate": [KEY_W],
		"p2_brake": [KEY_S],
		"p2_left": [KEY_A],
		"p2_right": [KEY_D],
		"p2_boost": [KEY_TAB],
		"restart": [KEY_R],
	}
	for action in keyboard.keys():
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for code in keyboard[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = code
			InputMap.action_add_event(action, ev)


func _setup_extra_gamepad_inputs() -> void:
	var pads := Input.get_connected_joypads()
	var button_map := {"accelerate": 0, "brake": 1, "left": 3, "right": 2, "boost": 4}
	for i in range(2, 4):
		if pads.size() > i:
			var device_id: int = pads[i]
			var prefix := "p%d_" % (i + 1)
			for act_name in button_map.keys():
				var action: String = prefix + act_name
				if not InputMap.has_action(action):
					InputMap.add_action(action)
					var ev := InputEventJoypadButton.new()
					ev.device = device_id
					ev.button_index = button_map[act_name]
					InputMap.action_add_event(action, ev)

func reset_join_state() -> void:
	joined = [true, false, false, false]
	car_index = [0, 1, 2, 3]
	last_points = [0, 0, 0, 0]
	# Names and paint are deliberately NOT cleared: the same family plays several races
	# in a row, and retyping names between every one would be miserable.


func seat_name(i: int) -> String:
	return player_name[clampi(i, 0, 3)]


func set_seat_name(i: int, value: String) -> void:
	player_name[clampi(i, 0, 3)] = value
	# Restore whatever paint this racer used last time they played.
	var profiles := get_node_or_null("/root/Profiles")
	if profiles != null and value.strip_edges() != "":
		tint_index[clampi(i, 0, 3)] = profiles.remembered_tint(value)
