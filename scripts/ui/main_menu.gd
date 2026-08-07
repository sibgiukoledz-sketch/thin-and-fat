extends Control

## Modern Main Menu script supporting instant Radmin VPN hosting, lobby joining, and character picking.

@onready var host_instant_btn: Button = %HostInstantButton
@onready var lobby_btn: Button = %LobbyButton
@onready var char_select_btn: Button = %CharSelectButton
@onready var quit_btn: Button = %QuitButton
@onready var copy_ip_btn: Button = %CopyIPButton

@onready var radmin_label: Label = %RadminLabel
@onready var char_name_label: Label = %CharNameLabel
@onready var char_desc_label: Label = %CharDescLabel

var selected_character: String = "fat"

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if host_instant_btn:
		host_instant_btn.pressed.connect(_on_host_instant_pressed)
	if lobby_btn:
		lobby_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/lobby_menu.tscn"))
	if char_select_btn:
		char_select_btn.pressed.connect(_on_toggle_character)
	if quit_btn:
		quit_btn.pressed.connect(func(): get_tree().quit())
	if copy_ip_btn:
		copy_ip_btn.pressed.connect(_on_copy_ip_pressed)

	_update_network_info()
	_update_character_ui("fat")

func _update_network_info() -> void:
	if not NetworkManager or not radmin_label:
		return
	var radmin := NetworkManager.get_radmin_ip()
	var local_ip := NetworkManager.get_local_ip_address()

	if radmin != "":
		radmin_label.text = "🌐 RADMIN VPN ОБНАРУЖЕН: %s" % radmin
		if copy_ip_btn:
			copy_ip_btn.show()
	else:
		radmin_label.text = "🌐 IP: %s (Для игры с другом запустите Radmin VPN)" % local_ip
		if copy_ip_btn:
			copy_ip_btn.show()

func _on_copy_ip_pressed() -> void:
	var ip := NetworkManager.get_local_ip_address() if NetworkManager else "127.0.0.1"
	DisplayServer.clipboard_set(ip)
	if radmin_label:
		radmin_label.text = "📋 IP %s скопирован в буфер!" % ip

func _on_host_instant_pressed() -> void:
	if NetworkManager:
		NetworkManager.host_game()
	get_tree().change_scene_to_file("res://scenes/lobby_menu.tscn")

func _on_toggle_character() -> void:
	if selected_character == "fat":
		_update_character_ui("thin")
	else:
		_update_character_ui("fat")

func _update_character_ui(id: String) -> void:
	selected_character = id
	if NetworkManager:
		NetworkManager.set_local_character(id)

	if id == "fat":
		if char_name_label:
			char_name_label.text = "🦛 2. ЖИРДЯЙ (FAT)"
		if char_desc_label:
			char_desc_label.text = "160 HP | Силач: Толкает 450кг валуны | Токсичный пердёж | Маленький прыжок"
		if char_select_btn:
			char_select_btn.text = "🦛 ВЫБРАН: ЖИРДЯЙ (КЛИК ДЛЯ СМЕНЫ)"
	else:
		if char_name_label:
			char_name_label.text = "🦒 1. ХУДОЙ (THIN)"
		if char_desc_label:
			char_desc_label.text = "80 HP | Атлет: Высокий прыжок (8.5м/с) | Блинчик-плинтус под двери"
		if char_select_btn:
			char_select_btn.text = "🦒 ВЫБРАН: ХУДОЙ (КЛИК ДЛЯ СМЕНЫ)"
