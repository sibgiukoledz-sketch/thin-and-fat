extends Control

## Modern AAA Lobby & Room System:
## 1. Live Server Browser: Auto-discovers LAN & Radmin VPN games with Ping & Player count.
## 2. Direct Room Code & IP Connect with 1-click clipboard paste.
## 3. Host Room Creation: Custom room name & shareable Room Code.
## 4. Active Ready Room: Live player cards, character switcher, readiness toggle, and dance emotes!

@onready var tab_container: TabContainer = %TabContainer
@onready var radmin_status_label: Label = %RadminStatusLabel
@onready var btn_copy_my_ip: Button = %BtnCopyMyIP

# Server Browser Tab
@onready var server_list_container: VBoxContainer = %ServerListContainer
@onready var btn_refresh_servers: Button = %BtnRefreshServers
@onready var direct_code_input: LineEdit = %DirectCodeInput
@onready var btn_direct_paste: Button = %BtnDirectPaste
@onready var btn_direct_join: Button = %BtnDirectJoin
@onready var btn_direct_localhost: Button = %BtnDirectLocalhost
@onready var btn_open_create_room: Button = %BtnOpenCreateRoom
@onready var btn_browser_back_menu: Button = %BtnBrowserBackMenu

# Host Create Room Tab
@onready var host_room_name_input: LineEdit = %HostRoomNameInput
@onready var host_generated_code_label: Label = %HostGeneratedCodeLabel
@onready var btn_regenerate_code: Button = %BtnRegenerateCode
@onready var btn_confirm_create_room: Button = %BtnConfirmCreateRoom
@onready var btn_cancel_create_room: Button = %BtnCancelCreateRoom

# Active Room Tab
@onready var room_title_label: Label = %RoomTitleLabel
@onready var room_code_label: Label = %RoomCodeLabel
@onready var btn_room_copy_info: Button = %BtnRoomCopyInfo
@onready var player_cards_container: HBoxContainer = %PlayerCardsContainer
@onready var btn_room_pick_fat: Button = %BtnRoomPickFat
@onready var btn_room_pick_thin: Button = %BtnRoomPickThin
@onready var btn_room_ready: Button = %BtnRoomReady
@onready var btn_start_match: Button = %BtnStartMatch
@onready var btn_leave_room: Button = %BtnLeaveRoom
@onready var room_notification_label: Label = %RoomNotificationLabel

# Emotes in Room
@onready var btn_emote_kazachok: Button = %BtnEmoteKazachok
@onready var btn_emote_disco: Button = %BtnEmoteDisco
@onready var btn_emote_wiggle: Button = %BtnEmoteWiggle

var current_room_code: String = ""
var is_local_player_ready: bool = true

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if LANDiscovery:
		LANDiscovery.room_list_updated.connect(_on_server_list_updated)

	if NetworkManager:
		NetworkManager.connection_status_changed.connect(_on_connection_status_changed)
		NetworkManager.player_list_changed.connect(_on_player_list_changed)
		NetworkManager.character_choices_updated.connect(_on_character_choices_updated)

	_setup_listeners()
	_setup_button_animations()
	_update_header_ip()

	# Start in Server Browser tab
	current_room_code = LANDiscoveryManager.generate_room_code() if LANDiscoveryManager else "TF-1001"
	if host_generated_code_label:
		host_generated_code_label.text = current_room_code

	# Check if already in active session
	if multiplayer and multiplayer.multiplayer_peer and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		_switch_tab(2)
	else:
		_switch_tab(0)

func _setup_listeners() -> void:
	if btn_copy_my_ip: btn_copy_my_ip.pressed.connect(_on_copy_my_ip_pressed)
	if btn_refresh_servers: btn_refresh_servers.pressed.connect(_refresh_server_list)
	if btn_direct_paste: btn_direct_paste.pressed.connect(_on_direct_paste_pressed)
	if btn_direct_join: btn_direct_join.pressed.connect(_on_direct_join_pressed)
	if btn_direct_localhost: btn_direct_localhost.pressed.connect(_on_direct_localhost_pressed)
	if btn_open_create_room: btn_open_create_room.pressed.connect(func(): _switch_tab(1))
	if btn_browser_back_menu: btn_browser_back_menu.pressed.connect(_on_back_to_menu_pressed)

	if btn_regenerate_code:
		btn_regenerate_code.pressed.connect(func():
			if AudioManager: AudioManager.play_sfx_2d("ui_click")
			current_room_code = LANDiscoveryManager.generate_room_code() if LANDiscoveryManager else "TF-2002"
			if host_generated_code_label: host_generated_code_label.text = current_room_code
		)
	if btn_confirm_create_room: btn_confirm_create_room.pressed.connect(_on_host_room_confirmed)
	if btn_cancel_create_room: btn_cancel_create_room.pressed.connect(func(): _switch_tab(0))

	if btn_room_copy_info: btn_room_copy_info.pressed.connect(_on_room_copy_info_pressed)
	if btn_room_pick_fat: btn_room_pick_fat.pressed.connect(func(): _select_character("fat"))
	if btn_room_pick_thin: btn_room_pick_thin.pressed.connect(func(): _select_character("thin"))
	if btn_room_ready: btn_room_ready.pressed.connect(_on_toggle_ready_pressed)
	if btn_start_match: btn_start_match.pressed.connect(_on_start_match_pressed)
	if btn_leave_room: btn_leave_room.pressed.connect(_on_leave_room_pressed)

	# Emote triggers
	if btn_emote_kazachok: btn_emote_kazachok.pressed.connect(func(): _trigger_emote("dance_kazachok"))
	if btn_emote_disco: btn_emote_disco.pressed.connect(func(): _trigger_emote("dance_disco"))
	if btn_emote_wiggle: btn_emote_wiggle.pressed.connect(func(): _trigger_emote("dance_wiggle"))

func _switch_tab(index: int) -> void:
	if tab_container:
		tab_container.current_tab = index
	if index == 0:
		_refresh_server_list()
	elif index == 2:
		_update_active_room_ui()

func _update_header_ip() -> void:
	if not NetworkManager or not radmin_status_label: return
	var radmin := NetworkManager.get_radmin_ip()
	var local_ip := NetworkManager.get_local_ip_address()
	if radmin != "":
		radmin_status_label.text = "🌐 RADMIN VPN: %s (СЕТЬ АКТИВНА)" % radmin
	else:
		radmin_status_label.text = "🌐 ЛОКАЛЬНЫЙ IP: %s (Radmin VPN не запущен)" % local_ip

func _on_copy_my_ip_pressed() -> void:
	if AudioManager: AudioManager.play_sfx_2d("ui_click")
	var ip := NetworkManager.get_local_ip_address() if NetworkManager else "127.0.0.1"
	DisplayServer.clipboard_set(ip)
	if radmin_status_label:
		radmin_status_label.text = "📋 IP %s скопирован в буфер!" % ip

func _refresh_server_list() -> void:
	if AudioManager: AudioManager.play_sfx_2d("ui_click")
	if LANDiscovery:
		_on_server_list_updated(LANDiscovery.active_rooms.values())

func _on_server_list_updated(rooms: Array) -> void:
	if not server_list_container: return

	for child in server_list_container.get_children():
		child.queue_free()

	if rooms.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "📡 Поиск активных комнат в LAN / Radmin VPN...\nЕсли друг создал сервер, он появится здесь автоматически!\nИли введите его IP / Код комнаты ниже."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_color_override("font_color", Color(0.65, 0.75, 0.85, 0.7))
		empty_lbl.add_theme_font_size_override("font_size", 14)
		server_list_container.add_child(empty_lbl)
		return

	for room in rooms:
		var room_dict: Dictionary = room as Dictionary
		var row := _create_server_row(room_dict)
		server_list_container.add_child(row)

func _create_server_row(data: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.15, 0.22, 0.9)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.7, 0.95, 0.6)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	margin.add_child(hbox)

	var name_lbl := Label.new()
	name_lbl.text = "🎮 %s" % data.get("name", "Игровая комната")
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	name_lbl.add_theme_font_size_override("font_size", 16)
	hbox.add_child(name_lbl)

	var code_lbl := Label.new()
	code_lbl.text = "🏷️ КОД: %s" % data.get("code", "TF-0000")
	code_lbl.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0, 1.0))
	code_lbl.add_theme_font_size_override("font_size", 14)
	hbox.add_child(code_lbl)

	var players_lbl := Label.new()
	players_lbl.text = "👥 %d/%d" % [int(data.get("players", 1)), int(data.get("max_players", 2))]
	players_lbl.add_theme_color_override("font_color", Color(0.3, 0.95, 0.5, 1.0))
	players_lbl.add_theme_font_size_override("font_size", 14)
	hbox.add_child(players_lbl)

	var join_btn := Button.new()
	join_btn.text = "⚡ ВОЙТИ"
	join_btn.custom_minimum_size = Vector2(110, 36)
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.18, 0.72, 0.38, 1)
	btn_style.corner_radius_top_left = 8
	btn_style.corner_radius_top_right = 8
	btn_style.corner_radius_bottom_right = 8
	btn_style.corner_radius_bottom_left = 8
	join_btn.add_theme_stylebox_override("normal", btn_style)

	var target_ip: String = String(data.get("ip", "127.0.0.1"))
	var target_port: int = int(data.get("port", 8910))

	join_btn.pressed.connect(func():
		if AudioManager: AudioManager.play_sfx_2d("ui_click")
		if NetworkManager:
			NetworkManager.join_game(target_ip, target_port)
		_switch_tab(2)
	)
	hbox.add_child(join_btn)

	return panel

func _on_direct_paste_pressed() -> void:
	if AudioManager: AudioManager.play_sfx_2d("ui_click")
	var clip := DisplayServer.clipboard_get().strip_edges()
	if direct_code_input:
		direct_code_input.text = clip

func _on_direct_localhost_pressed() -> void:
	if AudioManager: AudioManager.play_sfx_2d("ui_click")
	if direct_code_input:
		direct_code_input.text = "127.0.0.1"

func _on_direct_join_pressed() -> void:
	if AudioManager: AudioManager.play_sfx_2d("ui_click")
	var target := direct_code_input.text.strip_edges() if direct_code_input else "127.0.0.1"
	if target.is_empty():
		target = "127.0.0.1"

	# Check if target is a room code in LAN discovery
	var target_ip := target
	var target_port := NetworkManager.DEFAULT_PORT
	if LANDiscovery and LANDiscovery.active_rooms.has(target.to_upper()):
		var room: Dictionary = LANDiscovery.active_rooms[target.to_upper()]
		target_ip = String(room.get("ip", target))
		target_port = int(room.get("port", NetworkManager.DEFAULT_PORT))

	if NetworkManager:
		NetworkManager.join_game(target_ip, target_port)
	_switch_tab(2)

func _on_host_room_confirmed() -> void:
	if AudioManager: AudioManager.play_sfx_2d("ui_click")
	var r_name := host_room_name_input.text.strip_edges() if host_room_name_input else "Комната Коопа"
	if r_name.is_empty(): r_name = "Комната Коопа"

	var port := NetworkManager.DEFAULT_PORT
	if NetworkManager:
		NetworkManager.host_game(port)

	if LANDiscovery:
		LANDiscovery.start_broadcasting(r_name, current_room_code, port, 1, 2)

	_switch_tab(2)

func _on_room_copy_info_pressed() -> void:
	if AudioManager: AudioManager.play_sfx_2d("ui_click")
	var ip := NetworkManager.get_local_ip_address() if NetworkManager else "127.0.0.1"
	var text_to_copy := "Подключайся в Thin & Fat!\nIP: %s\nКод комнаты: %s" % [ip, current_room_code]
	DisplayServer.clipboard_set(text_to_copy)
	if room_notification_label:
		room_notification_label.text = "📋 Данные комнаты скопированы в буфер!"
		room_notification_label.show()

func _select_character(id: String) -> void:
	if AudioManager: AudioManager.play_sfx_2d("ui_click")
	if NetworkManager:
		NetworkManager.set_local_character(id)
	_update_active_room_ui()

func _on_toggle_ready_pressed() -> void:
	if AudioManager: AudioManager.play_sfx_2d("ui_click")
	is_local_player_ready = not is_local_player_ready
	if btn_room_ready:
		if is_local_player_ready:
			btn_room_ready.text = "🟢 ГОТОВ (READY)"
			btn_room_ready.modulate = Color(1.0, 1.0, 1.0)
		else:
			btn_room_ready.text = "🟡 НЕ ГОТОВ"
			btn_room_ready.modulate = Color(1.2, 0.8, 0.4)

func _trigger_emote(anim_name: String) -> void:
	if AudioManager: AudioManager.play_sfx_2d("ui_click")
	if room_notification_label:
		room_notification_label.text = "💃 ТАНЕЦ: %s" % anim_name.to_upper()
		room_notification_label.show()

func _on_start_match_pressed() -> void:
	if AudioManager: AudioManager.play_sfx_2d("slingshot_launch")
	if NetworkManager:
		if LANDiscovery:
			LANDiscovery.stop_broadcasting()
		NetworkManager.start_game_match()

func _on_leave_room_pressed() -> void:
	if AudioManager: AudioManager.play_sfx_2d("ui_click")
	if LANDiscovery:
		LANDiscovery.stop_broadcasting()
	if NetworkManager:
		NetworkManager.disconnect_game()
	_switch_tab(0)

func _on_back_to_menu_pressed() -> void:
	if AudioManager: AudioManager.play_sfx_2d("ui_click")
	if LANDiscovery:
		LANDiscovery.stop_broadcasting()
	if NetworkManager:
		NetworkManager.disconnect_game()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _update_active_room_ui() -> void:
	if not player_cards_container: return

	for child in player_cards_container.get_children():
		child.queue_free()

	var is_server := (multiplayer and multiplayer.is_server())
	if btn_start_match:
		btn_start_match.visible = is_server

	var my_id := multiplayer.get_unique_id() if (multiplayer and multiplayer.multiplayer_peer) else 1
	var local_char := NetworkManager.local_character_id if NetworkManager else "fat"

	# Host Card
	var host_char := local_char if is_server else NetworkManager.player_character_choices.get(1, "fat")
	var host_card := _create_player_card(1, "👑 ХОСТ (ИГРОК 1)", host_char, true, my_id == 1)
	player_cards_container.add_child(host_card)

	# Client Card
	var client_connected := (NetworkManager and NetworkManager.connected_players.size() >= 2)
	var client_id := 0
	if NetworkManager:
		for id in NetworkManager.connected_players:
			if id != 1:
				client_id = id
				break

	if client_connected or client_id != 0:
		var client_char := local_char if my_id != 1 else NetworkManager.player_character_choices.get(client_id, "thin")
		var client_card := _create_player_card(client_id, "🎮 НАПАРНИК (ИГРОК 2)", client_char, true, my_id == client_id)
		player_cards_container.add_child(client_card)
	else:
		var wait_card := _create_waiting_card()
		player_cards_container.add_child(wait_card)

	# Highlight selected character buttons
	if btn_room_pick_fat and btn_room_pick_thin:
		btn_room_pick_fat.modulate = Color(1.3, 1.3, 1.3) if local_char == "fat" else Color(0.6, 0.6, 0.6)
		btn_room_pick_thin.modulate = Color(1.3, 1.3, 1.3) if local_char == "thin" else Color(0.6, 0.6, 0.6)

func _create_player_card(_peer_id: int, title: String, char_id: String, is_ready: bool, is_me: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(360, 220)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.13, 0.2, 0.95)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.8, 1, 0.8) if is_me else Color(0.3, 0.6, 0.85, 0.5)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_right = 14
	style.corner_radius_bottom_left = 14
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 10
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var lbl_title := Label.new()
	lbl_title.text = title + (" (ВЫ)" if is_me else "")
	lbl_title.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0, 1.0) if is_me else Color(1, 1, 1, 1))
	lbl_title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(lbl_title)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var is_fat := (char_id.to_lower() == "fat")
	var lbl_char := Label.new()
	lbl_char.text = "🦛 ТОЛСТЯК (160 HP | Силач)" if is_fat else "🦒 ХУДОЙ (80 HP | Атлет)"
	lbl_char.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0) if is_fat else Color(0.35, 0.95, 1.0, 1.0))
	lbl_char.add_theme_font_size_override("font_size", 16)
	vbox.add_child(lbl_char)

	var lbl_status := Label.new()
	lbl_status.text = "🟢 ГОТОВ К ИГРЕ" if is_ready else "🟡 ВЫБИРАЕТ ГЕРОЯ..."
	lbl_status.add_theme_color_override("font_color", Color(0.3, 0.95, 0.5, 1.0) if is_ready else Color(1.0, 0.8, 0.3, 1.0))
	lbl_status.add_theme_font_size_override("font_size", 14)
	vbox.add_child(lbl_status)

	return panel

func _create_waiting_card() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(360, 220)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.11, 0.16, 0.75)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.4, 0.5, 0.6, 0.4)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_right = 14
	style.corner_radius_bottom_left = 14
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var lbl_wait := Label.new()
	lbl_wait.text = "⏳ ОЖИДАНИЕ НАПАРНИКА (ИГРОК 2)..."
	lbl_wait.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_wait.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0))
	lbl_wait.add_theme_font_size_override("font_size", 16)
	vbox.add_child(lbl_wait)

	var ip := NetworkManager.get_local_ip_address() if NetworkManager else "127.0.0.1"
	var lbl_info := Label.new()
	lbl_info.text = "Отправьте другу ваш IP:\n%s\nИли Код: %s" % [ip, current_room_code]
	lbl_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_info.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9, 0.85))
	lbl_info.add_theme_font_size_override("font_size", 13)
	vbox.add_child(lbl_info)

	return panel

func _on_connection_status_changed(msg: String) -> void:
	if room_notification_label:
		room_notification_label.text = msg
		room_notification_label.show()

func _on_player_list_changed(_players: Dictionary) -> void:
	_update_active_room_ui()

func _on_character_choices_updated() -> void:
	_update_active_room_ui()

func _setup_button_animations() -> void:
	var buttons := [btn_copy_my_ip, btn_refresh_servers, btn_direct_paste, btn_direct_join,
					btn_direct_localhost, btn_open_create_room, btn_browser_back_menu,
					btn_regenerate_code, btn_confirm_create_room, btn_cancel_create_room,
					btn_room_copy_info, btn_room_pick_fat, btn_room_pick_thin, btn_room_ready,
					btn_start_match, btn_leave_room, btn_emote_kazachok, btn_emote_disco, btn_emote_wiggle]
	for btn in buttons:
		if not btn: continue
		btn.pivot_offset = btn.size * 0.5
		btn.mouse_entered.connect(func():
			if AudioManager: AudioManager.play_sfx_2d("ui_hover")
			var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(btn, "scale", Vector2(1.04, 1.04), 0.16)
		)
		btn.mouse_exited.connect(func():
			var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(btn, "scale", Vector2.ONE, 0.16)
		)
