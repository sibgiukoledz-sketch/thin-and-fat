extends Node3D

## Modern 3D Main Menu Controller:
## - Interactive 3D Workshop Diorama with live Fat & Thin character models.
## - Cinematic parallax camera following mouse movement.
## - Character switcher with smooth 3D camera pan & spotlight transition.
## - Live Dance / Emote player on 3D models (Kazachok, Disco, Jelly Wiggle).
## - Button hover micro-animations (elastic scale, sound, glow).
## - Radmin VPN / Local IP auto-detection and copy helper.
## - Audio & Voice chat settings dialog integration.

@onready var host_instant_btn: Button = %HostInstantButton
@onready var lobby_btn: Button = %LobbyButton
@onready var char_select_btn: Button = %CharSelectButton
@onready var quit_btn: Button = %QuitButton
@onready var copy_ip_btn: Button = %CopyIPButton
@onready var audio_settings_btn: Button = %AudioSettingsButton
@onready var audio_settings_dialog: AudioSettingsDialog = %AudioSettingsDialog

@onready var radmin_label: Label = %RadminLabel
@onready var char_name_label: Label = %CharNameLabel
@onready var char_desc_label: Label = %CharDescLabel
@onready var char_hp_bar: ProgressBar = %CharHpBar
@onready var char_stamina_bar: ProgressBar = %CharStaminaBar

# Dance buttons
@onready var btn_dance_kazachok: Button = %BtnDanceKazachok
@onready var btn_dance_disco: Button = %BtnDanceDisco
@onready var btn_dance_wiggle: Button = %BtnDanceWiggle

# 3D Scene Elements
@onready var camera_rig: Node3D = %CameraRig
@onready var camera_3d: Camera3D = %MenuCamera3D
@onready var fat_model: Node3D = %FatModel
@onready var thin_model: Node3D = %ThinModel
@onready var fat_spotlight: SpotLight3D = %FatSpotlight
@onready var thin_spotlight: SpotLight3D = %ThinSpotlight
@onready var fan_blades: Node3D = get_node_or_null("DioramaStage/WorkshopProps/WallFan/Blades") as Node3D

var selected_character: String = "fat"
var _mouse_target_rot: Vector2 = Vector2.ZERO
var _current_cam_rot: Vector2 = Vector2.ZERO

const CAM_FAT_POS: Vector3 = Vector3(-0.9, 1.4, 3.4)
const CAM_THIN_POS: Vector3 = Vector3(0.9, 1.6, 3.4)
const CAM_CENTER_POS: Vector3 = Vector3(0.0, 1.5, 3.8)

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if host_instant_btn:
		host_instant_btn.pressed.connect(func():
			if AudioManager: AudioManager.play_sfx_2d("ui_click")
			_on_host_instant_pressed()
		)
	if lobby_btn:
		lobby_btn.pressed.connect(func():
			if AudioManager: AudioManager.play_sfx_2d("ui_click")
			if NetworkManager:
				NetworkManager.disconnect_game()
			get_tree().change_scene_to_file("res://scenes/lobby_menu.tscn")
		)
	if char_select_btn:
		char_select_btn.pressed.connect(func():
			if AudioManager: AudioManager.play_sfx_2d("ui_click")
			_on_toggle_character()
		)
	if audio_settings_btn:
		audio_settings_btn.pressed.connect(func():
			if AudioManager: AudioManager.play_sfx_2d("ui_click")
			if audio_settings_dialog:
				audio_settings_dialog.show_dialog()
		)
	if quit_btn:
		quit_btn.pressed.connect(func():
			if AudioManager: AudioManager.play_sfx_2d("ui_click")
			get_tree().quit()
		)
	if copy_ip_btn:
		copy_ip_btn.pressed.connect(func():
			if AudioManager: AudioManager.play_sfx_2d("ui_click")
			_on_copy_ip_pressed()
		)

	# Dance Emote preview buttons
	if btn_dance_kazachok: btn_dance_kazachok.pressed.connect(func(): _play_preview_dance("dance_kazachok"))
	if btn_dance_disco: btn_dance_disco.pressed.connect(func(): _play_preview_dance("dance_disco"))
	if btn_dance_wiggle: btn_dance_wiggle.pressed.connect(func(): _play_preview_dance("dance_wiggle"))

	_setup_button_animations()
	_update_network_info()
	_update_character_ui("fat")

func _process(delta: float) -> void:
	# Subtle 3D mouse parallax
	_current_cam_rot = _current_cam_rot.lerp(_mouse_target_rot, delta * 3.0)
	if camera_rig:
		camera_rig.rotation_degrees.y = _current_cam_rot.x * 6.0
		camera_rig.rotation_degrees.x = -_current_cam_rot.y * 3.5

	# Rotate fan blades in workshop
	if fan_blades:
		fan_blades.rotate_z(delta * 8.0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var vp_size := get_viewport().get_visible_rect().size
		if vp_size.x > 0 and vp_size.y > 0:
			var norm_x: float = (event.position.x / vp_size.x) - 0.5
			var norm_y: float = (event.position.y / vp_size.y) - 0.5
			_mouse_target_rot = Vector2(norm_x, norm_y)

func _setup_button_animations() -> void:
	var buttons := [host_instant_btn, lobby_btn, char_select_btn, audio_settings_btn, quit_btn, copy_ip_btn,
					btn_dance_kazachok, btn_dance_disco, btn_dance_wiggle]
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

func _update_network_info() -> void:
	if not NetworkManager or not radmin_label:
		return
	var radmin := NetworkManager.get_radmin_ip()
	var local_ip := NetworkManager.get_local_ip_address()

	if radmin != "":
		radmin_label.text = "🌐 RADMIN VPN: %s" % radmin
		if copy_ip_btn: copy_ip_btn.show()
	else:
		radmin_label.text = "🌐 IP: %s (Запустите Radmin VPN для игры онлайн)" % local_ip
		if copy_ip_btn: copy_ip_btn.show()

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

func _play_preview_dance(dance_name: String) -> void:
	if AudioManager: AudioManager.play_sfx_2d("ui_click")
	var active_model := fat_model if selected_character == "fat" else thin_model
	if active_model and active_model.has_method("play_anim"):
		active_model.play_anim(dance_name)

func _update_character_ui(id: String) -> void:
	selected_character = id
	if NetworkManager:
		NetworkManager.set_local_character(id)

	var target_cam_pos := CAM_CENTER_POS
	if id == "fat":
		target_cam_pos = CAM_FAT_POS
		if char_name_label:
			char_name_label.text = "🦛 ТОЛСТЯК (FAT)"
		if char_desc_label:
			char_desc_label.text = "• Здоровье: 160 HP\n• Силач: Поднимает и бросает 450 кг валуны на [E]\n• Токсичная вонь: Травит врагов и заряжает облако\n• Батут: Ложится на спину на [B] и подбрасывает напарника"
		if char_hp_bar:
			char_hp_bar.value = 160
			char_hp_bar.max_value = 160
		if char_stamina_bar:
			char_stamina_bar.value = 80
			char_stamina_bar.max_value = 100

		if fat_spotlight: fat_spotlight.light_energy = 3.5
		if thin_spotlight: thin_spotlight.light_energy = 0.6

		if fat_model and fat_model.has_method("play_anim"):
			fat_model.play_anim("idle")
	else:
		target_cam_pos = CAM_THIN_POS
		if char_name_label:
			char_name_label.text = "🦒 ХУДОЙ (THIN)"
		if char_desc_label:
			char_desc_label.text = "• Здоровье: 80 HP | Выносливость: 120 (Высокий спринт и прыжок)\n• Бумага: Сплющивается в лист на [C] / [E] и пролезает в любые щели\n• Потолочный альпинизм: Ползает по металлическим потолкам\n• Статический разряд: Накапливает ток на коврах и бьет током"
		if char_hp_bar:
			char_hp_bar.value = 80
			char_hp_bar.max_value = 160
		if char_stamina_bar:
			char_stamina_bar.value = 120
			char_stamina_bar.max_value = 120

		if fat_spotlight: fat_spotlight.light_energy = 0.6
		if thin_spotlight: thin_spotlight.light_energy = 3.5

		if thin_model and thin_model.has_method("play_anim"):
			thin_model.play_anim("idle")

	if camera_3d:
		var tw_cam := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw_cam.tween_property(camera_3d, "position", target_cam_pos, 0.45)
