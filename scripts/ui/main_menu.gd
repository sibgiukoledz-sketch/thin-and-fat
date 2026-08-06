extends Control

## Main menu script supporting Slender/Bone themed UI and transition to Lobby menu.

@onready var play_btn: Button = %PlayButton
@onready var char_select_btn: Button = %CharSelectButton
@onready var quit_btn: Button = %QuitButton

@onready var char_name_label: Label = %CharNameLabel
@onready var char_desc_label: Label = %CharDescLabel

var selected_character: String = "fat"

func _ready() -> void:
	if play_btn:
		play_btn.pressed.connect(_on_play_pressed)
	if char_select_btn:
		char_select_btn.pressed.connect(_on_toggle_character)
	if quit_btn:
		quit_btn.pressed.connect(func(): get_tree().quit())

	_update_character_ui("fat")

func _on_play_pressed() -> void:
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
