extends Node

static func confirm_pressed(event: InputEvent) -> bool:
	if event is InputEventMouseButton and event.pressed:
		return true
	if event is InputEventScreenTouch and event.pressed:
		return true
	if event is InputEventKey and event.pressed and not event.echo:
		var code: int = event.physical_keycode
		if code == KEY_ENTER or code == KEY_SPACE or code == KEY_KP_ENTER:
			return true
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A:
		return true
	return false

static func cancel_pressed(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		return true
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B:
		return true
	return false
