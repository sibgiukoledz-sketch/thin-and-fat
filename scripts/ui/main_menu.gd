extends Control

## Main menu script handling character selection and host/join network connections.

@onready var ip_input: LineEdit = %IPInput
@onready var port_input: LineEdit = %PortInput
@onready var host_btn: Button = %HostButton
@onready var join_btn: Button = %JoinButton
@onready var status_label: Label = %StatusLabel

@onready var btn_thin: Button = %BtnCharThin
@onready var btn_fat: Button = %BtnCharFat
@onready var char_desc_label: Label = %CharDescLabel

var selected_character: String = "thin"

func _ready() -> void:
	if NetworkManager:
		NetworkManager.connection_status_changed.connect(_on_connection_status_changed)

	host_btn.pressed.connect(_on_host_pressed)
	join_btn.pressed.connect(_on_join_pressed)

	if btn_thin:
		btn_thin.pressed.connect(func(): _select_character("thin"))
	if btn_fat:
		btn_fat.pressed.connect(func(): _select_character("fat"))

	_select_character("thin")

func _select_character(id: String) -> void:
	selected_character = id
	if NetworkManager:
		NetworkManager.set_local_character(id)

	if id == "fat":
		if char_desc_label:
			char_desc_label.text = "Выбран: 2. Жирный (Жирдяй) — Широкий хитбокс (0.75), низкий рост (1.5м), скорость 3.8"
		btn_fat.modulate = Color(1.3, 1.3, 1.3)
		btn_thin.modulate = Color(0.6, 0.6, 0.6)
	else:
		if char_desc_label:
			char_desc_label.text = "Выбран: 1. Высокий (Худой) — Высокий рост (2.4м), узкий хитбокс (0.28), скорость 7.0"
		btn_thin.modulate = Color(1.3, 1.3, 1.3)
		btn_fat.modulate = Color(0.6, 0.6, 0.6)

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
