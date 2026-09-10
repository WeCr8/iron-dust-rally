extends Node

# Persistent player profiles: a name, the points they have banked, and the paint
# colours those points have unlocked.
#
# Stored at user://profiles.json, which on Windows is
# %APPDATA%\Godot\app_userdata\<project>\profiles.json - it survives reinstalls of the
# game build and is trivially editable if a family argument needs settling.
#
# Deliberately no accounts, passwords or servers. This is a couch game: whoever is
# holding the controller types a name, and the machine remembers it next time.

const SAVE_PATH := "user://profiles.json"

# Points per finishing place, 1st through 4th. Everyone scores - last place still earns
# something, because a child who never scores stops playing.
const PLACE_POINTS := [10, 6, 3, 1]

# Paint unlocks. Index into Vehicles.TINTS, with the points needed to earn it.
# The first four are free so a brand-new player still has a choice on their first race.
const TINT_UNLOCKS := [
	{"tint": 0, "points": 0}, {"tint": 8, "points": 0},
	{"tint": 5, "points": 0}, {"tint": 3, "points": 0},
	{"tint": 1, "points": 20}, {"tint": 6, "points": 40},
	{"tint": 10, "points": 70}, {"tint": 4, "points": 110},
	{"tint": 2, "points": 160}, {"tint": 7, "points": 220},
	{"tint": 9, "points": 300}, {"tint": 11, "points": 400}
]

var _data: Dictionary = {"profiles": {}}


func _ready() -> void:
	load_all()


func load_all() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_data = {"profiles": {}}
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		_data = {"profiles": {}}
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	# A corrupt or hand-edited save must not stop the game starting; worst case a
	# family loses its points, which is better than a title screen that will not load.
	if typeof(parsed) == TYPE_DICTIONARY and parsed.has("profiles"):
		_data = parsed
	else:
		_data = {"profiles": {}}


func save_all() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(_data, "\t"))
	f.close()


func normalise(name: String) -> String:
	# Names are matched case-insensitively so "Zach" and "ZACH" are the same racer, but
	# the display form the player typed is what gets shown back to them.
	return name.strip_edges().to_upper()


func has_profile(name: String) -> bool:
	return _data["profiles"].has(normalise(name))


func get_profile(name: String) -> Dictionary:
	var key := normalise(name)
	if key == "":
		return _blank("")
	if not _data["profiles"].has(key):
		_data["profiles"][key] = _blank(name.strip_edges())
	return _data["profiles"][key]


func _blank(display: String) -> Dictionary:
	return {"display": display, "points": 0, "races": 0, "wins": 0, "tint": 0}


func all_names() -> Array:
	var names: Array = []
	for key in _data["profiles"].keys():
		names.append(String(_data["profiles"][key].get("display", key)))
	names.sort()
	return names


func award(name: String, finish_place: int, was_human: bool) -> int:
	# Returns the points gained, so the results screen can show "+10" next to the racer.
	if not was_human or normalise(name) == "":
		return 0
	var p := get_profile(name)
	var idx := clampi(finish_place - 1, 0, PLACE_POINTS.size() - 1)
	var gained: int = PLACE_POINTS[idx]
	p["points"] = int(p.get("points", 0)) + gained
	p["races"] = int(p.get("races", 0)) + 1
	if finish_place == 1:
		p["wins"] = int(p.get("wins", 0)) + 1
	save_all()
	return gained


func points_for(name: String) -> int:
	if normalise(name) == "":
		return 0
	return int(get_profile(name).get("points", 0))


func unlocked_tints(name: String) -> Array:
	# Which paint indices this racer may pick right now.
	var pts := points_for(name)
	var out: Array = []
	for entry in TINT_UNLOCKS:
		if pts >= int(entry["points"]):
			out.append(int(entry["tint"]))
	return out


func next_unlock(name: String) -> Dictionary:
	# The next thing to race for, so the car screen can show a reason to keep playing.
	var pts := points_for(name)
	for entry in TINT_UNLOCKS:
		if pts < int(entry["points"]):
			return {"tint": int(entry["tint"]), "points": int(entry["points"]), "needed": int(entry["points"]) - pts}
	return {}


func remember_tint(name: String, tint_index: int) -> void:
	if normalise(name) == "":
		return
	var p := get_profile(name)
	p["tint"] = tint_index
	save_all()


func remembered_tint(name: String) -> int:
	if normalise(name) == "":
		return 0
	return int(get_profile(name).get("tint", 0))
