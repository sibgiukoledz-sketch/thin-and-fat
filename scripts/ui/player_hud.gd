class_name PlayerHUD
extends CanvasLayer

## Component script for managing HUD UI displays, status bars, circular ability cooldown icons, and Pause Menu overlay.

@onready var fps_label: Label = $MarginContainer/VBoxContainer/FPSLabel
@onready var state_label: Label = $MarginContainer/VBoxContainer/StateLabel
@onready var authority_label: Label = $MarginContainer/VBoxContainer/AuthorityLabel

@onready var char_info_label: Label = $MarginContainer/VBoxContainer/CharInfoLabel
@onready var health_bar: ProgressBar = $MarginContainer/VBoxContainer/HealthBar
@onready var health_label: Label = $MarginContainer/VBoxContainer/HealthLabel
@onready var stamina_bar: ProgressBar = $MarginContainer/VBoxContainer/StaminaBar
@onready var stamina_label: Label = $MarginContainer/VBoxContainer/StaminaLabel
@onready var stench_bar: ProgressBar = $MarginContainer/VBoxContainer/StenchBar
@onready var stench_label: Label = $MarginContainer/VBoxContainer/StenchLabel
@onready var crosshair: Control = $Crosshair
@onready var nausea_overlay: ColorRect = $NauseaOverlay
@onready var death_overlay: Control = $DeathOverlay
@onready var respawn_label: Label = $DeathOverlay/VBox/RespawnLabel

# Pause Menu Overlay Controls
@onready var pause_overlay: Control = $PauseOverlay
@onready var btn_resume: Button = $PauseOverlay/CenterContainer/CardPanel/Margin/VBox/BtnResume
@onready var btn_switch_char: Button = $PauseOverlay/CenterContainer/CardPanel/Margin/VBox/BtnSwitchChar
@onready var btn_respawn: Button = $PauseOverlay/CenterContainer/CardPanel/Margin/VBox/BtnRespawn
@onready var btn_quit: Button = $PauseOverlay/CenterContainer/CardPanel/Margin/VBox/BtnQuit

# Bottom-Right Slingshot Ability Circular Widget
@onready var slingshot_widget: Control = $SlingshotAbilityWidget
@onready var slingshot_circle_bg: Panel = $SlingshotAbilityWidget/CircleBg
@onready var slingshot_timer_label: Label = $SlingshotAbilityWidget/CircleBg/TimerLabel
@onready var slingshot_key_label: Label = $SlingshotAbilityWidget/KeyBadge/KeyLabel

var player: Player
var _fps_timer: float = 0.0

func _ready() -> void:
	if btn_resume:
		btn_resume.pressed.connect(hide_pause_menu)
	if btn_switch_char:
		btn_switch_char.pressed.connect(func() -> void:
			hide_pause_menu()
			if player and player.has_method("rpc_toggle_character"):
				player.rpc_toggle_character.rpc()
		)
	if btn_respawn:
		btn_respawn.pressed.connect(func() -> void:
			hide_pause_menu()
			if player and player.has_method("rpc_respawn"):
				player.rpc_respawn.rpc()
		)
	if btn_quit:
		btn_quit.pressed.connect(func() -> void:
			hide_pause_menu()
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		)

func _process(delta: float) -> void:
	_fps_timer += delta
	if _fps_timer >= 0.25:
		_fps_timer = 0.0
		if fps_label:
			var fps: int = int(Engine.get_frames_per_second())
			var ms: float = (1.0 / maxf(float(fps), 1.0)) * 1000.0
			var voice_status := "🎙️ [V] ВОЙС-ЧАТ"
			if VoiceChatManager and VoiceChatManager._is_speaking:
				voice_status = "🔊 [V] ВЫ ГОВОРИТЕ"
			fps_label.text = "⚡ %d FPS (%.1f ms) | %s" % [fps, ms, voice_status]

func setup(player_node: Player) -> void:
	player = player_node

func toggle_pause_menu() -> void:
	if pause_overlay:
		if pause_overlay.visible:
			hide_pause_menu()
		else:
			show_pause_menu()

func show_pause_menu() -> void:
	if pause_overlay:
		pause_overlay.visible = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func hide_pause_menu() -> void:
	if pause_overlay:
		pause_overlay.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func is_pause_menu_open() -> bool:
	return pause_overlay != null and pause_overlay.visible

func update_display() -> void:
	if not player or not player.is_multiplayer_authority():
		return

	if state_label and player.state_machine:
		state_label.text = "FSM STATE: %s" % player.state_machine.current_state_name.to_upper()
	if authority_label:
		authority_label.text = "PEER ID: %d (AUTHORITY)" % player.peer_id
	if health_bar:
		health_bar.max_value = player.max_health
		health_bar.value = player.current_health
	if health_label:
		health_label.text = "HP: %d / %d" % [int(player.current_health), int(player.max_health)]
	if stamina_bar:
		stamina_bar.max_value = player.max_stamina
		stamina_bar.value = player.current_stamina
	if stamina_label:
		if player.is_stamina_exhausted:
			stamina_label.text = "STAMINA: EXHAUSTED!"
		else:
			stamina_label.text = "STAMINA: %d%%" % int((player.current_stamina / player.max_stamina) * 100.0)
	if char_info_label:
		var char_name: String = "ЖИРНЫЙ (ЖИРДЯЙ)" if player.selected_character_id.to_lower() == "fat" else "ХУДОЙ"
		var is_fp: bool = ("is_first_person" in player) and bool(player.is_first_person)
		var view_str: String = "1ST PERSON" if is_fp else "3RD PERSON"
		char_info_label.text = "CHAR: %s | VIEW: %s" % [char_name, view_str]

	if stench_bar and stench_label:
		if player.selected_character_id.to_lower() == "fat":
			stench_bar.visible = true
			stench_label.visible = true
			if player.active_mechanics and "stench_level" in player.active_mechanics:
				var stench_val: float = player.active_mechanics.stench_level
				stench_bar.value = stench_val
				stench_label.text = "ВОНЬ: %d%%" % int(stench_val)
		else:
			stench_bar.visible = false
			stench_label.visible = false

	_update_slingshot_widget()

func update_death_display(is_dead: bool, time_left: float = 0.0) -> void:
	if death_overlay:
		death_overlay.visible = is_dead
	if respawn_label and is_dead:
		respawn_label.text = "ВОЗРОДИТЬСЯ ЧЕРЕЗ %d СЕК..." % int(ceilf(time_left))

func set_nausea_intensity(intensity: float) -> void:
	if nausea_overlay and nausea_overlay.material:
		nausea_overlay.material.set_shader_parameter("intensity", clampf(intensity, 0.0, 1.0))

func update_slingshot_cooldown(current: float, _max_cd: float) -> void:
	if slingshot_widget and player and player.selected_character_id.to_lower() == "fat":
		_update_slingshot_widget_val(current)

func _update_slingshot_widget() -> void:
	if not slingshot_widget:
		return

	if not player or player.selected_character_id.to_lower() != "fat":
		slingshot_widget.visible = false
		return

	slingshot_widget.visible = true

	var cooldown_remaining: float = 0.0
	if player.active_mechanics and "_slingshot_cooldown" in player.active_mechanics:
		cooldown_remaining = player.active_mechanics._slingshot_cooldown
	elif player.active_mechanics and "slingshot_cooldown_timer" in player.active_mechanics:
		cooldown_remaining = player.active_mechanics.slingshot_cooldown_timer

	_update_slingshot_widget_val(cooldown_remaining)

func _update_slingshot_widget_val(cooldown_remaining: float) -> void:
	var is_ready: bool = cooldown_remaining <= 0.001

	if is_ready:
		if slingshot_circle_bg:
			slingshot_circle_bg.modulate = Color(0.2, 1.0, 0.4, 0.9)
		if slingshot_timer_label:
			slingshot_timer_label.text = "ГОТОВО"
			slingshot_timer_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	else:
		if slingshot_circle_bg:
			slingshot_circle_bg.modulate = Color(1.0, 0.3, 0.2, 0.85)
		if slingshot_timer_label:
			slingshot_timer_label.text = "%.1fs" % cooldown_remaining
			slingshot_timer_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
