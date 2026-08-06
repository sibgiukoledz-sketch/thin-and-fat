extends Control

## Interactive Pre-Match Lobby Room Script supporting live character pick and match launch.

@onready var ip_input: LineEdit = %IPInput
@onready var port_input: LineEdit = %PortInput
@onready var host_btn: Button = %HostButton
@onready var join_btn: Button = %JoinButton
@onready var back_btn: Button = %BackButton
@onready var start_match_btn: Button = %StartMatchButton

@onready var btn_select_fat: Button = %BtnSelectFat
@onready var btn_select_thin: Button = %BtnSelectThin

@onready var status_label: Label = %StatusLabel
@onready var player_list_label: Label = %PlayerListLabel

func _ready() -> void:
	if NetworkManager:
		NetworkManager.connection_status_changed.connect(_on_connection_status_changed)
		NetworkManager.player_list_changed.connect(_on_player_list_changed)
		NetworkManager.character_choices_updated.connect(_on_character_choices_updated)

	host_btn.pressed.connect(_on_host_pressed)
	join_btn.pressed.connect(_on_join_pressed)
	if back_btn:
		back_btn.pressed.connect(_on_back_pressed)

	btn_select_fat.pressed.connect(func(): _select_character("fat"))
	btn_select_thin.pressed.connect(func(): _select_character("thin"))
	start_match_btn.pressed.connect(_on_start_match_pressed)

	_update_character_ui(NetworkManager.local_character_id if NetworkManager else "fat")
	_update_lobby_buttons()

func _select_character(id: String) -> void:
	if NetworkManager:
		NetworkManager.set_local_character(id)
	_update_character_ui(id)

func _update_character_ui(id: String) -> void:
	if id == "fat":
		btn_select_fat.modulate = Color(1.3, 1.3, 1.3)
		btn_select_thin.modulate = Color(0.6, 0.6, 0.6)
	else:
		btn_select_thin.modulate = Color(1.3, 1.3, 1.3)
		btn_select_fat.modulate = Color(0.6, 0.6, 0.6)
	_update_player_list_display()

func _on_host_pressed() -> void:
	var port := int(port_input.text) if port_input.text.is_valid_int() else NetworkManager.DEFAULT_PORT
	status_label.text = "Создание комнаты..."
	NetworkManager.host_game(port)
	_update_lobby_buttons()

func _on_join_pressed() -> void:
	var ip := ip_input.text.strip_edges()
	if ip.is_empty():
		ip = "127.0.0.1"
	var port := int(port_input.text) if port_input.text.is_valid_int() else NetworkManager.DEFAULT_PORT
	status_label.text = "Подключение..."
	NetworkManager.join_game(ip, port)
	_update_lobby_buttons()

func _on_start_match_pressed() -> void:
	if NetworkManager:
		NetworkManager.start_game_match()

func _on_back_pressed() -> void:
	if NetworkManager:
		NetworkManager.disconnect_game()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _update_lobby_buttons() -> void:
	var is_in_game := (multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED)
	var is_server := multiplayer.is_server() if is_in_game else false

	if is_server:
		start_match_btn.show()
		start_match_btn.disabled = false
	else:
		if is_in_game:
			start_match_btn.show()
			start_match_btn.disabled = true
			start_match_btn.text = "[ ⏳ ОЖИДАНИЕ ЗАПУСКА ХОСТОМ... ]"
		else:
			start_match_btn.hide()

func _on_connection_status_changed(status_text: String) -> void:
	if status_label:
		status_label.text = status_text
	_update_lobby_buttons()

func _on_player_list_changed(_players: Dictionary) -> void:
	_update_player_list_display()
	_update_lobby_buttons()

func _on_character_choices_updated() -> void:
	_update_player_list_display()

func _update_player_list_display() -> void:
	if not player_list_label or not NetworkManager:
		return

	var players: Dictionary = NetworkManager.connected_players
	if players.is_empty():
		player_list_label.text = "Подключенные игроки (0):\nСоздайте комнату или подключитесь по IP..."
		return

	var text_out := "ПОДКЛЮЧЕННЫЕ ИГРОКИ В КОМНАТЕ (%d):\n\n" % players.size()
	for p_id in players:
		var p_info: Dictionary = players[p_id]
		var chosen_char := NetworkManager.get_character_for_peer(p_id)
		var char_str := "🦛 Жирный (Жирдяй)" if chosen_char == "fat" else "🦒 Высокий (Худой)"
		var is_local := " (ВЫ)" if (p_id == multiplayer.get_unique_id() or (p_id == 1 and multiplayer.is_server())) else ""
		text_out += "• %s (ID: %d)%s\n   └ Выбран: %s [ГОТОВ]\n\n" % [p_info.get("name", "Игрок"), p_id, is_local, char_str]

	player_list_label.text = text_out
