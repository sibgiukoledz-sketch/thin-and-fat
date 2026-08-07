extends Control

## State-driven Lobby UI:
## SetupView (Form input) <-> ActiveLobbyView (Live Room Player Cards)

@onready var setup_view: Control = %SetupView
@onready var active_lobby_view: Control = %ActiveLobbyView

# Setup View Controls
@onready var ip_input: LineEdit = %IPInput
@onready var port_input: LineEdit = %PortInput
@onready var host_btn: Button = %HostButton
@onready var join_btn: Button = %JoinButton
@onready var btn_copy_ip: Button = %BtnCopyIP
@onready var btn_paste_ip: Button = %BtnPasteIP
@onready var btn_localhost: Button = %BtnLocalhost
@onready var btn_select_fat: Button = %BtnSelectFat
@onready var btn_select_thin: Button = %BtnSelectThin
@onready var setup_back_btn: Button = %SetupBackButton

# Active Lobby Controls
@onready var active_status_label: Label = %ActiveStatusLabel
@onready var room_copy_ip_btn: Button = %RoomCopyIPButton
@onready var player_cards_container: HBoxContainer = %PlayerCardsContainer
@onready var room_btn_fat: Button = %RoomBtnFat
@onready var room_btn_thin: Button = %RoomBtnThin
@onready var start_match_btn: Button = %StartMatchButton
@onready var leave_room_btn: Button = %LeaveRoomButton
@onready var notification_label: Label = %NotificationLabel

var _last_player_count: int = 0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if NetworkManager:
		NetworkManager.connection_status_changed.connect(_on_connection_status_changed)
		NetworkManager.player_list_changed.connect(_on_player_list_changed)
		NetworkManager.character_choices_updated.connect(_on_character_choices_updated)

	# Setup View Listeners
	if host_btn: host_btn.pressed.connect(_on_host_pressed)
	if join_btn: join_btn.pressed.connect(_on_join_pressed)
	if btn_copy_ip: btn_copy_ip.pressed.connect(_on_copy_ip_pressed)
	if btn_paste_ip: btn_paste_ip.pressed.connect(_on_paste_ip_pressed)
	if btn_localhost: btn_localhost.pressed.connect(_on_localhost_pressed)
	if setup_back_btn: setup_back_btn.pressed.connect(_on_setup_back_pressed)

	if btn_select_fat: btn_select_fat.pressed.connect(func(): _select_character("fat"))
	if btn_select_thin: btn_select_thin.pressed.connect(func(): _select_character("thin"))

	# Active Room Listeners
	if room_copy_ip_btn: room_copy_ip_btn.pressed.connect(_on_copy_ip_pressed)
	if room_btn_fat: room_btn_fat.pressed.connect(func(): _select_character("fat"))
	if room_btn_thin: room_btn_thin.pressed.connect(func(): _select_character("thin"))
	if start_match_btn: start_match_btn.pressed.connect(_on_start_match_pressed)
	if leave_room_btn: leave_room_btn.pressed.connect(_on_leave_room_pressed)

	_update_character_ui(NetworkManager.local_character_id if NetworkManager else "fat")

	# Check if already connected or hosted
	var is_net_connected: bool = (multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED)
	if is_net_connected:
		_show_active_lobby_view()
	else:
		_show_setup_view()

func _show_setup_view() -> void:
	if setup_view: setup_view.show()
	if active_lobby_view: active_lobby_view.hide()

func _show_active_lobby_view() -> void:
	if setup_view: setup_view.hide()
	if active_lobby_view: active_lobby_view.show()
	_update_active_room_ui()

func _select_character(id: String) -> void:
	if NetworkManager:
		NetworkManager.set_local_character(id)
	_update_character_ui(id)

func _update_character_ui(id: String) -> void:
	if btn_select_fat and btn_select_thin:
		btn_select_fat.modulate = Color(1.4, 1.4, 1.4) if id == "fat" else Color(0.5, 0.5, 0.5)
		btn_select_thin.modulate = Color(1.4, 1.4, 1.4) if id == "thin" else Color(0.5, 0.5, 0.5)

	if room_btn_fat and room_btn_thin:
		room_btn_fat.modulate = Color(1.4, 1.4, 1.4) if id == "fat" else Color(0.5, 0.5, 0.5)
		room_btn_thin.modulate = Color(1.4, 1.4, 1.4) if id == "thin" else Color(0.5, 0.5, 0.5)

	_update_player_cards()

func _on_host_pressed() -> void:
	var port := int(port_input.text) if (port_input and port_input.text.is_valid_int()) else NetworkManager.DEFAULT_PORT
	if NetworkManager:
		NetworkManager.host_game(port)
	_show_active_lobby_view()

func _on_join_pressed() -> void:
	var ip := ip_input.text.strip_edges() if ip_input else "127.0.0.1"
	if ip.is_empty():
		ip = "127.0.0.1"
	var port := int(port_input.text) if (port_input and port_input.text.is_valid_int()) else NetworkManager.DEFAULT_PORT
	if NetworkManager:
		NetworkManager.join_game(ip, port)
	_show_active_lobby_view()

func _on_leave_room_pressed() -> void:
	if NetworkManager:
		NetworkManager.disconnect_game()
	_show_setup_view()

func _on_setup_back_pressed() -> void:
	if NetworkManager:
		NetworkManager.disconnect_game()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_copy_ip_pressed() -> void:
	var ip := NetworkManager.get_local_ip_address() if NetworkManager else "127.0.0.1"
	DisplayServer.clipboard_set(ip)
	if notification_label:
		notification_label.text = "📋 IP адрес (%s) скопирован в буфер обмена!" % ip
		_flash_notification()

func _on_paste_ip_pressed() -> void:
	var clip := DisplayServer.clipboard_get().strip_edges()
	if not clip.is_empty():
		if ip_input:
			ip_input.text = clip
		if notification_label:
			notification_label.text = "📋 IP адрес (%s) вставлен!" % clip
			_flash_notification()

func _on_localhost_pressed() -> void:
	if ip_input:
		ip_input.text = "127.0.0.1"
	_on_join_pressed()

func _on_start_match_pressed() -> void:
	if NetworkManager:
		NetworkManager.start_game_match()

func _update_active_room_ui() -> void:
	var is_in_game := (multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED)
	var is_server := multiplayer.is_server() if is_in_game else false
	var best_ip := NetworkManager.get_local_ip_address() if NetworkManager else "127.0.0.1"

	if active_status_label:
		if is_server:
			active_status_label.text = "👑 ВЫ ХОСТ | IP: %s:%d" % [best_ip, NetworkManager.current_port if NetworkManager else 8910]
		else:
			active_status_label.text = "🎮 ПОДКЛЮЧЕНО К ХОСТУ (Client ID: %d)" % multiplayer.get_unique_id()

	if start_match_btn:
		if is_server:
			start_match_btn.show()
			start_match_btn.disabled = false
			start_match_btn.text = "🚀 ЗАПУСТИТЬ МАТЧ (START MATCH)"
		else:
			if is_in_game:
				start_match_btn.show()
				start_match_btn.disabled = true
				start_match_btn.text = "⏳ ОЖИДАНИЕ ЗАПУСКА ХОСТОМ..."
			else:
				start_match_btn.hide()

	if room_btn_fat and room_btn_thin:
		room_btn_fat.disabled = not is_server
		room_btn_thin.disabled = not is_server

	var room_char_label: Label = get_node_or_null("%RoomCharLabel")
	if room_char_label:
		if is_server:
			room_char_label.text = "СМЕНИТЬ ПЕРСОНАЖА ХОСТА:"
		else:
			room_char_label.text = "🔒 ПЕРСОНАЖИ НАЗНАЧАЮТСЯ ХОСТОМ:"

	_update_player_cards()

func _on_player_list_changed(players: Dictionary) -> void:
	var count := players.size()
	if count > _last_player_count and _last_player_count > 0:
		if notification_label:
			notification_label.text = "🔔 НОВЫЙ ИГРОК ПОДКЛЮЧИЛСЯ К КОМНАТЕ!"
			_flash_notification()
	_last_player_count = count

	_update_active_room_ui()

func _on_character_choices_updated() -> void:
	if NetworkManager:
		var my_id := multiplayer.get_unique_id() if (multiplayer and multiplayer.multiplayer_peer) else 1
		var my_char := NetworkManager.get_character_for_peer(my_id)
		if btn_select_fat and btn_select_thin:
			btn_select_fat.modulate = Color(1.4, 1.4, 1.4) if my_char == "fat" else Color(0.5, 0.5, 0.5)
			btn_select_thin.modulate = Color(1.4, 1.4, 1.4) if my_char == "thin" else Color(0.5, 0.5, 0.5)
		if room_btn_fat and room_btn_thin:
			room_btn_fat.modulate = Color(1.4, 1.4, 1.4) if my_char == "fat" else Color(0.5, 0.5, 0.5)
			room_btn_thin.modulate = Color(1.4, 1.4, 1.4) if my_char == "thin" else Color(0.5, 0.5, 0.5)
	_update_player_cards()

func _on_connection_status_changed(status_text: String) -> void:
	if notification_label:
		notification_label.text = status_text
		_flash_notification()
	_update_active_room_ui()

func _flash_notification() -> void:
	if notification_label:
		notification_label.show()
		var tw := create_tween()
		tw.tween_property(notification_label, "modulate:a", 1.0, 0.1)
		tw.tween_interval(3.0)
		tw.tween_property(notification_label, "modulate:a", 0.0, 0.5)

func _update_player_cards() -> void:
	if not player_cards_container or not NetworkManager:
		return

	# Clear existing card nodes
	for c in player_cards_container.get_children():
		c.queue_free()

	var players: Dictionary = NetworkManager.connected_players
	var my_id: int = multiplayer.get_unique_id() if (multiplayer and multiplayer.multiplayer_peer) else 1

	if players.is_empty():
		var is_server := multiplayer.is_server() if (multiplayer and multiplayer.multiplayer_peer) else true
		var title := "👑 Хост [ВЫ]" if is_server else "🎮 Игрок [ВЫ] (ID: %d)" % my_id
		var dummy_card := _create_player_card(title, NetworkManager.local_character_id, true)
		player_cards_container.add_child(dummy_card)
		var waiting_card := _create_waiting_card()
		player_cards_container.add_child(waiting_card)
		return

	for p_id in players:
		var p_id_int: int = int(p_id)
		var p_info: Dictionary = players[p_id]
		var p_name: String = String(p_info.get("name", "Игрок"))
		var chosen_char := NetworkManager.get_character_for_peer(p_id_int)
		var is_me: bool = (p_id_int == my_id)
		var is_host: bool = (p_id_int == 1)

		var role_title := ""
		if is_host and is_me:
			role_title = "👑 %s [ВЫ] (ID: 1)" % p_name
		elif is_host:
			role_title = "👑 %s (ID: 1)" % p_name
		elif is_me:
			role_title = "🎮 %s [ВЫ] (ID: %d)" % [p_name, p_id_int]
		else:
			role_title = "🎮 %s (ID: %d)" % [p_name, p_id_int]

		var card := _create_player_card(role_title, chosen_char, is_me)
		player_cards_container.add_child(card)

	# If only 1 player in session, add "Waiting for Player 2" card!
	if players.size() < 2:
		var waiting_card := _create_waiting_card()
		player_cards_container.add_child(waiting_card)

func _create_player_card(title: String, char_id: String, is_me: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(360, 180)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.18, 0.28, 0.95) if is_me else Color(0.09, 0.14, 0.22, 0.9)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.8, 0.5, 0.9) if is_me else Color(0.3, 0.6, 0.9, 0.7)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var lbl_title := Label.new()
	lbl_title.text = title
	lbl_title.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0, 1.0))
	lbl_title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(lbl_title)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var is_fat := (char_id.to_lower() == "fat")
	var lbl_char := Label.new()
	lbl_char.text = "🦛 ЖИРДЯЙ (FAT)" if is_fat else "🦒 ХУДОЙ (THIN)"
	lbl_char.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3, 1.0) if is_fat else Color(0.3, 0.95, 1.0, 1.0))
	lbl_char.add_theme_font_size_override("font_size", 18)
	vbox.add_child(lbl_char)

	var lbl_status := Label.new()
	lbl_status.text = "✅ ГОТОВ К ИГРЕ"
	lbl_status.add_theme_color_override("font_color", Color(0.3, 0.95, 0.5, 1.0))
	lbl_status.add_theme_font_size_override("font_size", 13)
	vbox.add_child(lbl_status)

	return panel

func _create_waiting_card() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(360, 180)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.15, 0.7)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.4, 0.5, 0.6, 0.4)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var best_ip := NetworkManager.get_local_ip_address() if NetworkManager else "127.0.0.1"

	var lbl_wait := Label.new()
	lbl_wait.text = "⏳ ОЖИДАНИЕ ИГРОКА 2..."
	lbl_wait.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_wait.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0))
	lbl_wait.add_theme_font_size_override("font_size", 16)
	vbox.add_child(lbl_wait)

	var lbl_info := Label.new()
	lbl_info.text = "Отправьте ваш Radmin IP другому игроку:\n%s" % best_ip
	lbl_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_info.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9, 0.8))
	lbl_info.add_theme_font_size_override("font_size", 12)
	lbl_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(lbl_info)

	return panel
