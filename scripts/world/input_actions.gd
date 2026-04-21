extends RefCounted

const ACTION_KEYS = {
	"move_left": [KEY_A],
	"move_right": [KEY_D],
	"move_forward": [KEY_W],
	"move_back": [KEY_S],
	"interact": [KEY_E],
	"phase_switch": [KEY_TAB],
	"restart_level": [KEY_R],
	"toggle_mouse_capture": [KEY_ESCAPE],
	"toggle_fullscreen": [KEY_F11],
}

static func ensure_defaults() -> void:
	for action in ACTION_KEYS.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var existing_events = InputMap.action_get_events(action)
		for keycode in ACTION_KEYS[action]:
			var already_bound := false
			for existing in existing_events:
				if existing is InputEventKey and existing.keycode == keycode:
					already_bound = true
					break
			if already_bound:
				continue
			var ev = InputEventKey.new()
			ev.keycode = keycode
			InputMap.action_add_event(action, ev)
