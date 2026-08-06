extends Control

## Main menu script supporting Slender/Bone themed UI and multiplayer actions.

@onready var ip_input: LineEdit = %IPInput
@onready var port_input: LineEdit = %PortInput
@onready var host_btn: Button = %HostButton
@onready var join_btn: Button = %JoinButton
@onready var char_select_btn: Button = %CharSelectButton
@onready var quit_btn: Button = %QuitButton
@onready var status_label: Label = %StatusLabel

@onready var char_name_label: Label = %CharNameLabel
@onready var char_desc_label: Label = %CharDescLabel

var selected_character: String = "fat"

func _ready() -> void:
	if NetworkManager:
		NetworkManager.connection_status_changed.connect(_on_connection_status_changed)

	host_btn.pressed.connect(_on_host_pressed)
	join_btn.pressed.connect(_on_join_pressed)
	char_select_btn.pressed.connect(_on_toggle_character)
	if quit_btn:
		quit_btn.pressed.connect(func(): get_tree().quit())

	_update_character_ui("fat")

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
			char_name_label.text = "🦛 2. Жирный (Жирдяй)"
		if char_desc_label:
			char_desc_label.text = "Широкий хитбокс (0.75m), рост 1.5m | 160 HP | Спринт выдыхается быстро"
		if char_select_btn:
			char_select_btn.text = "[ CHARACTER: FAT (ЖИРДЯЙ) ]"
	else:
		if char_name_label:
			char_name_label.text = "🦒 1. Высокий (Худой)"
		if char_desc_label:
			char_desc_label.text = "Узкий хитбокс (0.28m), рост 2.4m | 80 HP | Быстрый долгий спринт"
		if char_select_btn:
			char_select_btn.text = "[ CHARACTER: THIN (ХУДОЙ) ]"

func _on_host_pressed() -> void:
	var port := int(port_input.text) if port_input.text.is_valid_int() else NetworkManager.DEFAULT_PORT
	status_label.text = "Starting server..."
	NetworkManager.host_game(port)

func _on_join_pressed() -> void:
	var ip := ip_input.text.strip_edges()
	if ip.is_empty():
		ip = "127.0.0.1"
	var port := int(port_input.text) if port_input.text.is_valid_int() else NetworkManager.DEFAULT_PORT
	status_label.text = "Connecting..."
	NetworkManager.join_game(ip, port)

func _on_connection_status_changed(status_text: String) -> void:
	if status_label:
		status_label.text = status_text
