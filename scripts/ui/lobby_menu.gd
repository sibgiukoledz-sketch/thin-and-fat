extends Control

## Lobby Menu script handling room creation, IP joining, and connected player list.

@onready var ip_input: LineEdit = %IPInput
@onready var port_input: LineEdit = %PortInput
@onready var host_btn: Button = %HostButton
@onready var join_btn: Button = %JoinButton
@onready var back_btn: Button = %BackButton
@onready var status_label: Label = %StatusLabel
@onready var player_list_label: Label = %PlayerListLabel
@onready var selected_char_label: Label = %SelectedCharLabel

func _ready() -> void:
	if NetworkManager:
		NetworkManager.connection_status_changed.connect(_on_connection_status_changed)
		NetworkManager.player_list_changed.connect(_on_player_list_changed)
		_update_character_label()

	host_btn.pressed.connect(_on_host_pressed)
	join_btn.pressed.connect(_on_join_pressed)
	if back_btn:
		back_btn.pressed.connect(_on_back_pressed)

func _update_character_label() -> void:
	if selected_char_label and NetworkManager:
		var char_id := NetworkManager.local_character_id
		if char_id == "thin":
			selected_char_label.text = "Выбран персонаж: 🦒 1. Высокий (Худой)"
		else:
			selected_char_label.text = "Выбран персонаж: 🦛 2. Жирный (Жирдяй)"

func _on_host_pressed() -> void:
	var port := int(port_input.text) if port_input.text.is_valid_int() else NetworkManager.DEFAULT_PORT
	status_label.text = "Creating room..."
	NetworkManager.host_game(port)

func _on_join_pressed() -> void:
	var ip := ip_input.text.strip_edges()
	if ip.is_empty():
		ip = "127.0.0.1"
	var port := int(port_input.text) if port_input.text.is_valid_int() else NetworkManager.DEFAULT_PORT
	status_label.text = "Connecting to room..."
	NetworkManager.join_game(ip, port)

func _on_back_pressed() -> void:
	if NetworkManager:
		NetworkManager.disconnect_game()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_connection_status_changed(status_text: String) -> void:
	if status_label:
		status_label.text = status_text

func _on_player_list_changed(players: Dictionary) -> void:
	if player_list_label:
		var text_out := "Подключенные игроки (%d):\n" % players.size()
		for p_id in players:
			var p_info: Dictionary = players[p_id]
			text_out += "• %s (ID: %d)\n" % [p_info.get("name", "Player"), p_id]
		player_list_label.text = text_out
