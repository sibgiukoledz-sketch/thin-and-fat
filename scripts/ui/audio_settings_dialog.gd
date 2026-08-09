class_name AudioSettingsDialog
extends Control

## Modern Audio & Microphone Settings Modal supporting Volume Sliders,
## Output / Microphone Device Selectors, Live Mic Level Meter & Test Mode, and Push-To-Talk settings.

@onready var master_slider: HSlider = %MasterSlider
@onready var master_val_label: Label = %MasterValLabel

@onready var sfx_slider: HSlider = %SFXSlider
@onready var sfx_val_label: Label = %SFXValLabel

@onready var voice_slider: HSlider = %VoiceSlider
@onready var voice_val_label: Label = %VoiceValLabel

@onready var output_device_opt: OptionButton = %OutputDeviceOpt
@onready var input_device_opt: OptionButton = %InputDeviceOpt

@onready var mic_test_btn: Button = %MicTestButton
@onready var mic_level_bar: ProgressBar = %MicLevelBar
@onready var mic_status_label: Label = %MicStatusLabel
@onready var ptt_mode_opt: OptionButton = %PTTModeOpt

@onready var close_btn: Button = %CloseButton

var _is_testing_mic: bool = false

func _ready() -> void:
	visible = false

	if close_btn:
		close_btn.pressed.connect(hide_dialog)

	_setup_volume_sliders()
	_setup_device_selectors()
	_setup_mic_test()

	# Save/Load config on start
	load_audio_settings()

func show_dialog() -> void:
	visible = true
	_populate_devices()
	_update_ui_from_audio_server()

func hide_dialog() -> void:
	if _is_testing_mic:
		_toggle_mic_test(false)
	visible = false
	save_audio_settings()

func _process(_delta: float) -> void:
	if visible and _is_testing_mic and VoiceChatManager:
		var level: float = VoiceChatManager.get_mic_input_level()
		if mic_level_bar:
			mic_level_bar.value = level * 100.0

		if mic_status_label:
			if level > 0.05:
				mic_status_label.text = "🔊 МИКРОФОН АКТИВЕН: СИГНАЛ ИДЕТ (%.0f%%)" % (level * 100.0)
			else:
				mic_status_label.text = "🎙️ Говорите в микрофон для проверки..."

func _setup_volume_sliders() -> void:
	if master_slider:
		master_slider.value_changed.connect(func(val: float) -> void:
			_set_bus_volume("Master", val)
			if master_val_label: master_val_label.text = "%d%%" % int(val)
		)
	if sfx_slider:
		sfx_slider.value_changed.connect(func(val: float) -> void:
			_set_bus_volume("SFX", val)
			if sfx_val_label: sfx_val_label.text = "%d%%" % int(val)
		)
	if voice_slider:
		voice_slider.value_changed.connect(func(val: float) -> void:
			_set_bus_volume("VoicePlaybackBus", val)
			if voice_val_label: voice_val_label.text = "%d%%" % int(val)
		)

func _set_bus_volume(bus_name: String, percentage: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx != -1:
		if percentage <= 0.0:
			AudioServer.set_bus_mute(idx, true)
		else:
			AudioServer.set_bus_mute(idx, false)
			var db := linear_to_db(percentage / 100.0)
			AudioServer.set_bus_volume_db(idx, db)

func _setup_device_selectors() -> void:
	if output_device_opt:
		output_device_opt.item_selected.connect(func(index: int) -> void:
			var dev_name: String = output_device_opt.get_item_text(index)
			AudioServer.output_device = dev_name
		)

	if input_device_opt:
		input_device_opt.item_selected.connect(func(index: int) -> void:
			var dev_name: String = input_device_opt.get_item_text(index)
			if VoiceChatManager and VoiceChatManager.has_method("set_input_device"):
				VoiceChatManager.set_input_device(dev_name)
			else:
				AudioServer.input_device = dev_name
		)

	if ptt_mode_opt:
		ptt_mode_opt.clear()
		ptt_mode_opt.add_item("🎙️ Push-To-Talk [V]")
		ptt_mode_opt.add_item("🔊 Всегда включен (VAD)")
		ptt_mode_opt.item_selected.connect(func(index: int) -> void:
			if VoiceChatManager:
				VoiceChatManager.push_to_talk = (index == 0)
		)

func _populate_devices() -> void:
	# 1. Output Devices
	if output_device_opt:
		output_device_opt.clear()
		var out_devices := AudioServer.get_output_device_list()
		var current_out := AudioServer.output_device
		var current_out_idx: int = 0

		for i in range(out_devices.size()):
			var dev := out_devices[i]
			output_device_opt.add_item(dev)
			if dev == current_out:
				current_out_idx = i

		output_device_opt.select(current_out_idx)

	# 2. Input Devices (Microphones)
	if input_device_opt:
		input_device_opt.clear()
		var in_devices := AudioServer.get_input_device_list()
		var current_in := AudioServer.input_device
		var current_in_idx: int = 0

		for i in range(in_devices.size()):
			var dev := in_devices[i]
			input_device_opt.add_item(dev)
			if dev == current_in:
				current_in_idx = i

		input_device_opt.select(current_in_idx)

func _setup_mic_test() -> void:
	if mic_test_btn:
		mic_test_btn.pressed.connect(func() -> void:
			_toggle_mic_test(not _is_testing_mic)
		)

func _toggle_mic_test(testing: bool) -> void:
	_is_testing_mic = testing
	if VoiceChatManager:
		VoiceChatManager.mic_test_active = _is_testing_mic

	if mic_test_btn:
		if _is_testing_mic:
			mic_test_btn.text = "⏹️ ОСТАНОВИТЬ ТЕСТ"
		else:
			mic_test_btn.text = "🎙️ ПРОВЕРИТЬ МИКРОФОН"

	if mic_status_label:
		if _is_testing_mic:
			mic_status_label.text = "🎙️ Начните говорить в микрофон..."
		else:
			mic_status_label.text = "Тест микрофона остановлен."
			if mic_level_bar: mic_level_bar.value = 0.0

func _update_ui_from_audio_server() -> void:
	var master_idx := AudioServer.get_bus_index("Master")
	if master_idx != -1 and master_slider:
		var pct := int(db_to_linear(AudioServer.get_bus_volume_db(master_idx)) * 100.0)
		master_slider.value = pct
		if master_val_label: master_val_label.text = "%d%%" % pct

	var sfx_idx := AudioServer.get_bus_index("SFX")
	if sfx_idx != -1 and sfx_slider:
		var pct := int(db_to_linear(AudioServer.get_bus_volume_db(sfx_idx)) * 100.0)
		sfx_slider.value = pct
		if sfx_val_label: sfx_val_label.text = "%d%%" % pct

	var voice_idx := AudioServer.get_bus_index("VoicePlaybackBus")
	if voice_idx != -1 and voice_slider:
		var pct := int(db_to_linear(AudioServer.get_bus_volume_db(voice_idx)) * 100.0)
		voice_slider.value = pct
		if voice_val_label: voice_val_label.text = "%d%%" % pct

	if ptt_mode_opt and VoiceChatManager:
		ptt_mode_opt.select(0 if VoiceChatManager.push_to_talk else 1)

func save_audio_settings() -> void:
	var config := ConfigFile.new()
	if master_slider: config.set_value("audio", "master", master_slider.value)
	if sfx_slider: config.set_value("audio", "sfx", sfx_slider.value)
	if voice_slider: config.set_value("audio", "voice", voice_slider.value)
	config.set_value("audio", "output_device", AudioServer.output_device)
	config.set_value("audio", "input_device", AudioServer.input_device)
	if VoiceChatManager:
		config.set_value("audio", "push_to_talk", VoiceChatManager.push_to_talk)

	config.save("user://audio_settings.cfg")

func load_audio_settings() -> void:
	var config := ConfigFile.new()
	if config.load("user://audio_settings.cfg") == OK:
		var master_pct = config.get_value("audio", "master", 100.0)
		var sfx_pct = config.get_value("audio", "sfx", 100.0)
		var voice_pct = config.get_value("audio", "voice", 100.0)
		_set_bus_volume("Master", master_pct)
		_set_bus_volume("SFX", sfx_pct)
		_set_bus_volume("VoicePlaybackBus", voice_pct)

		var out_dev = config.get_value("audio", "output_device", "")
		if out_dev != "": AudioServer.output_device = out_dev

		var in_dev = config.get_value("audio", "input_device", "")
		if in_dev != "":
			if VoiceChatManager and VoiceChatManager.has_method("set_input_device"):
				VoiceChatManager.set_input_device(in_dev)
			else:
				AudioServer.input_device = in_dev

		var ptt = config.get_value("audio", "push_to_talk", true)
		if VoiceChatManager:
			VoiceChatManager.push_to_talk = ptt
