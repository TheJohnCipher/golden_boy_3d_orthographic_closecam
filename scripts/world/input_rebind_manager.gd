extends RefCounted

# Runtime input rebinding with persistent storage.
# Manages rebinding UI, InputMap updates, and config persistence.

const CONFIG_FILE_PATH = "user://input_bindings.ini"
const REBINDABLE_ACTIONS = {
	"move_left": "Move Left",
	"move_right": "Move Right",
	"move_forward": "Move Forward",
	"move_back": "Move Back",
	"interact": "Interact / Takedown",
	"phase_switch": "Day/Night Toggle",
	"restart_level": "Restart Level",
	"toggle_mouse_capture": "Toggle Mouse Capture",
	"toggle_fullscreen": "Toggle Fullscreen",
	"pause": "Pause",
}

static func load_bindings() -> void:
	var config = ConfigFile.new()
	var error = config.load(CONFIG_FILE_PATH)
	if error == OK:
		for action in REBINDABLE_ACTIONS.keys():
			if config.has_section_key("input_bindings", action):
				var keycode_int = config.get_value("input_bindings", action)
				_rebind_action(action, keycode_int)

static func save_bindings() -> void:
	var config = ConfigFile.new()
	for action in REBINDABLE_ACTIONS.keys():
		var events = InputMap.action_get_events(action)
		if events.size() > 0 and events[0] is InputEventKey:
			config.set_value("input_bindings", action, events[0].keycode)
	config.save(CONFIG_FILE_PATH)

static func reset_to_defaults() -> void:
	var defaults = {
		"move_left": KEY_A,
		"move_right": KEY_D,
		"move_forward": KEY_W,
		"move_back": KEY_S,
		"interact": KEY_E,
		"phase_switch": KEY_TAB,
		"restart_level": KEY_R,
		"toggle_mouse_capture": KEY_ESCAPE,
		"toggle_fullscreen": KEY_F11,
		"pause": KEY_P,
	}
	for action in defaults.keys():
		_rebind_action(action, defaults[action])
	save_bindings()

static func rebind_action(action: String, keycode: int) -> bool:
	if not REBINDABLE_ACTIONS.has(action):
		return false
	_rebind_action(action, keycode)
	save_bindings()
	return true

static func _rebind_action(action: String, keycode: int) -> void:
	InputMap.action_erase_events(action)
	var ev = InputEventKey.new()
	ev.keycode = keycode
	InputMap.action_add_event(action, ev)

static func get_current_keycode(action: String) -> int:
	var events = InputMap.action_get_events(action)
	if events.size() > 0 and events[0] is InputEventKey:
		return events[0].keycode
	return KEY_NONE

static func keycode_to_string(keycode: int) -> String:
	if keycode == KEY_NONE:
		return "---"
	return OS.get_keycode_string(keycode)
