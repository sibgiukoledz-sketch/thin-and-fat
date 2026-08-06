class_name PlayerHUD
extends CanvasLayer

## Component script for managing HUD UI displays, status bars, and circular ability cooldown icons ("Кругляшки").

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

# Bottom-Right Slingshot Ability Circular Widget
@onready var slingshot_widget: Control = $SlingshotAbilityWidget
@onready var slingshot_circle_bg: Panel = $SlingshotAbilityWidget/CircleBg
@onready var slingshot_timer_label: Label = $SlingshotAbilityWidget/CircleBg/TimerLabel
@onready var slingshot_key_label: Label = $SlingshotAbilityWidget/KeyBadge/KeyLabel

var player: Player

func setup(player_node: Player) -> void:
	player = player_node

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
	if char_info_label and player.active_character_data:
		var view_mode: String = "1ST PERSON" if player.current_camera_zoom < 0.25 else "3RD PERSON (%.1fm)" % player.current_camera_zoom
		char_info_label.text = "CHAR: %s | VIEW: %s" % [player.active_character_data.character_name, view_mode]

	# Handle Stench & Slingshot Ability Widget visibility
	if player.active_mechanics and player.active_mechanics is FatMechanics:
		var fat_mech: FatMechanics = player.active_mechanics as FatMechanics
		if stench_bar and stench_label:
			stench_bar.show()
			stench_label.show()
			stench_bar.max_value = fat_mech.max_stench
			stench_bar.value = fat_mech.stench_level
			if fat_mech.stench_level >= fat_mech.stench_damage_threshold:
				stench_label.text = "ВОНЬ: %d%% (ОПАСНАЯ АУРА!)" % int(fat_mech.stench_level)
			else:
				stench_label.text = "ВОНЬ: %d%%" % int(fat_mech.stench_level)

		if slingshot_widget:
			slingshot_widget.show()
	else:
		if stench_bar and stench_label:
			stench_bar.hide()
			stench_label.hide()
		if slingshot_widget:
			slingshot_widget.hide()

func update_respawn_timer(seconds_left: float) -> void:
	if respawn_label:
		respawn_label.text = "ВОЗРОЖДЕНИЕ ЧЕРЕЗ %d СЕК..." % int(ceil(seconds_left))

func update_slingshot_cooldown(cooldown_timer: float, max_cooldown: float) -> void:
	if not slingshot_widget or not slingshot_timer_label:
		return

	if cooldown_timer <= 0.0:
		slingshot_timer_label.text = "ГОТОВО"
		slingshot_timer_label.modulate = Color(0.2, 1.0, 0.4)
		if slingshot_circle_bg:
			slingshot_circle_bg.modulate = Color(1.0, 1.0, 1.0)
	else:
		slingshot_timer_label.text = "%.1f с" % cooldown_timer
		slingshot_timer_label.modulate = Color(1.0, 0.6, 0.2)
		if slingshot_circle_bg:
			slingshot_circle_bg.modulate = Color(0.75, 0.75, 0.75)
