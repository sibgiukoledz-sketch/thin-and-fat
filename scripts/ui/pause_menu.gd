class_name PauseMenu
extends Control

## In-game Pause Menu:
## - Full screen blur shader overlay
## - Resume, Audio Settings, Switch Character, Main Menu, Quit
## - Smooth animation on open/close
## - Handles mouse capture toggling

signal character_switched(new_character_id: String)

@onready var blur_rect: ColorRect = %BlurRect
@onready var resume_btn: Button = %ResumeButton
@onready var audio_settings_btn: Button = %AudioSettingsButton
@onready var switch_char_btn: Button = %SwitchCharButton
@onready var main_menu_btn: Button = %MainMenuButton
@onready var quit_btn: Button = %QuitButton
@onready var menu_card: PanelContainer = %MenuCard
@onready var audio_settings_dialog: AudioSettingsDialog = %AudioSettingsDialog

var is_paused: bool = false
var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

	if resume_btn:
		resume_btn.pressed.connect(func():
			if AudioManager: AudioManager.play_sfx_2d("ui_click")
			close_pause_menu()
		)
	if audio_settings_btn:
		audio_settings_btn.pressed.connect(func():
			if AudioManager: AudioManager.play_sfx_2d("ui_click")
			if audio_settings_dialog:
				audio_settings_dialog.show_dialog()
		)
	if switch_char_btn:
		switch_char_btn.pressed.connect(func():
			if AudioManager: AudioManager.play_sfx_2d("ui_click")
			_on_switch_character_pressed()
		)
	if main_menu_btn:
		main_menu_btn.pressed.connect(func():
			if AudioManager: AudioManager.play_sfx_2d("ui_click")
			_on_main_menu_pressed()
		)
	if quit_btn:
		quit_btn.pressed.connect(func():
			if AudioManager: AudioManager.play_sfx_2d("ui_click")
			get_tree().quit()
		)

	_setup_button_hover_animations()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if is_paused:
				close_pause_menu()
			else:
				open_pause_menu()
			get_viewport().set_input_as_handled()

func open_pause_menu() -> void:
	is_paused = true
	visible = true
	_previous_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if menu_card:
		menu_card.modulate.a = 0.0
		menu_card.scale = Vector2(0.9, 0.9)
		menu_card.pivot_offset = menu_card.size * 0.5
		var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(menu_card, "modulate:a", 1.0, 0.25)
		tw.tween_property(menu_card, "scale", Vector2.ONE, 0.25)

func close_pause_menu() -> void:
	is_paused = false
	Input.mouse_mode = _previous_mouse_mode

	if menu_card:
		var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(menu_card, "modulate:a", 0.0, 0.15)
		tw.tween_property(menu_card, "scale", Vector2(0.9, 0.9), 0.15)
		tw.chain().tween_callback(func():
			visible = false
		)
	else:
		visible = false

func _on_switch_character_pressed() -> void:
	var current_id: String = "fat"
	var player_node := _find_local_player()
	if player_node and "selected_character_id" in player_node:
		current_id = player_node.selected_character_id

	var next_id := "thin" if current_id == "fat" else "fat"
	if player_node and player_node.has_method("set_character"):
		player_node.set_character(next_id)
	if NetworkManager:
		NetworkManager.set_local_character(next_id)

	character_switched.emit(next_id)
	close_pause_menu()

func _on_main_menu_pressed() -> void:
	if NetworkManager:
		NetworkManager.disconnect_game()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _find_local_player() -> CharacterBody3D:
	for node in get_tree().get_nodes_in_group("player"):
		if node is CharacterBody3D and node.has_method("is_multiplayer_authority") and node.is_multiplayer_authority():
			return node as CharacterBody3D
	return null

func _setup_button_hover_animations() -> void:
	var buttons := [resume_btn, audio_settings_btn, switch_char_btn, main_menu_btn, quit_btn]
	for btn in buttons:
		if not btn: continue
		btn.pivot_offset = btn.size * 0.5
		btn.mouse_entered.connect(func():
			if AudioManager: AudioManager.play_sfx_2d("ui_hover")
			var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(btn, "scale", Vector2(1.04, 1.04), 0.18)
		)
		btn.mouse_exited.connect(func():
			var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(btn, "scale", Vector2.ONE, 0.18)
		)
