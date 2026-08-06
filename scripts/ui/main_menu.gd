extends Control

## Main menu script handling host/join network connections.

@onready var ip_input: LineEdit = %IPInput
@onready var port_input: LineEdit = %PortInput
@onready var host_btn: Button = %HostButton
@onready var join_btn: Button = %JoinButton
@onready var status_label: Label = %StatusLabel

func _ready() -> void:
	if NetworkManager:
		NetworkManager.connection_status_changed.connect(_on_connection_status_changed)

	host_btn.pressed.connect(_on_host_pressed)
	join_btn.pressed.connect(_on_join_pressed)

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
