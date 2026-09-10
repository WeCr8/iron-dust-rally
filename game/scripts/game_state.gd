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
	_setup_extra_gamepad_inputs()

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
