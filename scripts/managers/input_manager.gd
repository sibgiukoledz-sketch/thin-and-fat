extends Node

## Centralized InputManager handling runtime keybindings, ConfigFile/JSON persistence (user://input_config.json), and default resets.

signal keybindings_changed

const CONFIG_PATH: String = "user://input_config.json"

# Default action mappings: action_name -> Array of physical keycode integers or InputEvent description dicts
const DEFAULT_KEYBINDINGS: Dictionary = {
	"move_forward": [KEY_W, KEY_UP],
	"move_backward": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"jump": [KEY_SPACE],
	"sprint": [KEY_SHIFT],
	"crouch": [KEY_CTRL, KEY_C],
	"ability_1": [KEY_E],
	"ability_2": [KEY_F],
	"interact": [KEY_E]
}

func _ready() -> void:
	ensure_default_input_map()
	load_keybindings()

## Ensures all required game actions are initialized in Godot's InputMap
func ensure_default_input_map() -> void:
	for action_name in DEFAULT_KEYBINDINGS:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)

		# If action has no events, populate defaults
		if InputMap.action_get_events(action_name).is_empty():
			_apply_default_keys_to_action(action_name)

func _apply_default_keys_to_action(action_name: String) -> void:
	var keys: Array = DEFAULT_KEYBINDINGS.get(action_name, [])
	for keycode in keys:
		var event := InputEventKey.new()
		event.physical_keycode = keycode
		InputMap.action_add_event(action_name, event)

## Loads saved keybindings from user://input_config.json
func load_keybindings() -> void:
	if not FileAccess.file_exists(CONFIG_PATH):
		save_keybindings()
		return

	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if not file:
		return

	var json_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(json_text)
	if err != OK:
		printerr("InputManager: Failed to parse input config JSON!")
		return

	var data: Dictionary = json.data
	for action_name in data:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)

		InputMap.action_erase_events(action_name)
		var keycodes: Array = data[action_name]
		for keycode in keycodes:
			var event := InputEventKey.new()
			event.physical_keycode = int(keycode)
			InputMap.action_add_event(action_name, event)

	keybindings_changed.emit()

## Saves current InputMap keybindings to user://input_config.json
func save_keybindings() -> void:
	var data: Dictionary = {}
	for action_name in DEFAULT_KEYBINDINGS:
		if InputMap.has_action(action_name):
			var keycodes: Array = []
			for event in InputMap.action_get_events(action_name):
				if event is InputEventKey:
					keycodes.append(event.physical_keycode)
			data[action_name] = keycodes

	var file := FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()

## Rebinds an action to a new InputEvent and saves automatically
func rebind_action(action_name: String, new_event: InputEvent) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	InputMap.action_erase_events(action_name)
	InputMap.action_add_event(action_name, new_event)
	save_keybindings()
	keybindings_changed.emit()

## Resets all keybindings to factory defaults
func reset_to_defaults() -> void:
	for action_name in DEFAULT_KEYBINDINGS:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)

		InputMap.action_erase_events(action_name)
		_apply_default_keys_to_action(action_name)

	save_keybindings()
	keybindings_changed.emit()

## Helper to get human-readable key name for an action (e.g. "Shift", "Space", "W")
func get_action_key_name(action_name: String) -> String:
	if not InputMap.has_action(action_name):
		return "None"

	var events := InputMap.action_get_events(action_name)
	if events.is_empty():
		return "None"

	var event := events[0]
	if event is InputEventKey:
		return OS.get_keycode_string(event.physical_keycode)
	return event.as_text()
