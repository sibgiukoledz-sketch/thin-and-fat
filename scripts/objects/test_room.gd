@tool
class_name TestRoom
extends Node3D

## Modular Testing Chamber Room template.
## Duplicatable chamber with high-tech walls, floor grid, overhead LED lighting,
## and customizable 3D signboard title for testing new character & physics mechanics!

@export var room_title: String = "ТЕСТОВАЯ КАМЕРА: МЕХАНИКИ":
	set(val):
		room_title = val
		_update_signboard()

@export var room_color: Color = Color(0.3, 0.7, 1.0):
	set(val):
		room_color = val
		_update_signboard()

@onready var title_label: Label3D = $TitleLabel3D

func _ready() -> void:
	_update_signboard()

func _update_signboard() -> void:
	if not is_node_ready() or not title_label:
		return

	title_label.text = "🔬 " + room_title
	title_label.modulate = room_color
