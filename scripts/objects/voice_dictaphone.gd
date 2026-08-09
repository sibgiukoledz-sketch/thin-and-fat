class_name VoiceDictaphone
extends Area3D

## Interactive 3D Voice Recorder & Spatial Playback Dictaphone for Solo Testing.
## Player walks up, presses 'E', records 5 seconds of voice audio,
## and plays it back with 3D spatial attenuation in singleplayer!

signal recording_started
signal recording_finished
signal playback_started
signal playback_finished

@export var max_record_time: float = 5.0 # Max recording duration in seconds

@onready var status_label: Label3D = $StatusLabel3D
@onready var prompt_label: Label3D = $PromptLabel3D
@onready var rec_light: OmniLight3D = $RecLight
@onready var play_light: OmniLight3D = $PlayLight
@onready var spatial_audio_player: AudioStreamPlayer3D = $SpatialAudioPlayer3D

enum State { IDLE, RECORDING, HAS_RECORDING, PLAYING }
var current_state: int = State.IDLE

var _recorded_frames: PackedVector2Array = PackedVector2Array()
var _record_timer: float = 0.0
var _blink_timer: float = 0.0
var _player_in_range: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	_setup_audio_player()
	_update_ui_display()

func _setup_audio_player() -> void:
	if spatial_audio_player:
		spatial_audio_player.bus = "VoicePlaybackBus" if AudioServer.get_bus_index("VoicePlaybackBus") != -1 else "SFX"
		spatial_audio_player.max_distance = 45.0
		spatial_audio_player.unit_size = 3.0
		spatial_audio_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
		spatial_audio_player.panning_strength = 1.0
		spatial_audio_player.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP

		var gen := AudioStreamGenerator.new()
		gen.mix_rate = AudioServer.get_mix_rate()
		gen.buffer_length = 0.5
		spatial_audio_player.stream = gen

func _on_body_entered(body: Node) -> void:
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		return
	if body and body.has_method("is_multiplayer_authority") and body.is_multiplayer_authority():
		_player_in_range = true
		_update_ui_display()

func _on_body_exited(body: Node) -> void:
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		return
	if body and body.has_method("is_multiplayer_authority") and body.is_multiplayer_authority():
		_player_in_range = false
		_update_ui_display()

func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range and event.is_action_pressed("ability_1"): # Key 'E'
		_on_interact_pressed()

func _on_interact_pressed() -> void:
	if current_state == State.IDLE or current_state == State.HAS_RECORDING:
		start_recording()
	elif current_state == State.PLAYING:
		stop_playback()

func start_recording() -> void:
	current_state = State.RECORDING
	_recorded_frames.clear()
	_record_timer = max_record_time

	if rec_light:
		rec_light.visible = true
		rec_light.light_color = Color(1.0, 0.1, 0.1)

	if play_light: play_light.visible = false
	if AudioManager: AudioManager.play_sfx_3d("ui_click", global_position)

	recording_started.emit()
	print("🎙️ DICTAPHONE: Recording started for %.1f sec..." % max_record_time)
	_update_ui_display()

func stop_recording() -> void:
	current_state = State.HAS_RECORDING
	if rec_light: rec_light.visible = false
	if AudioManager: AudioManager.play_sfx_3d("ui_click", global_position)

	recording_finished.emit()
	print("📼 DICTAPHONE: Recorded %d audio frames successfully!" % _recorded_frames.size())

	# Auto start 3D playback after recording
	start_playback()

func start_playback() -> void:
	if _recorded_frames.size() == 0:
		current_state = State.IDLE
		_update_ui_display()
		return

	current_state = State.PLAYING

	if play_light:
		play_light.visible = true
		play_light.light_color = Color(0.2, 1.0, 0.3)

	if rec_light: rec_light.visible = false

	if spatial_audio_player:
		spatial_audio_player.play()
		var playback := spatial_audio_player.get_stream_playback() as AudioStreamGeneratorPlayback
		if playback:
			for frame in _recorded_frames:
				if playback.can_push_buffer(1):
					playback.push_frame(frame)

	playback_started.emit()
	print("🔊 DICTAPHONE: Playing back %d frames in 3D..." % _recorded_frames.size())
	_update_ui_display()

func stop_playback() -> void:
	current_state = State.HAS_RECORDING
	if play_light: play_light.visible = false
	if spatial_audio_player and spatial_audio_player.playing:
		spatial_audio_player.stop()

	playback_finished.emit()
	_update_ui_display()

func _process(delta: float) -> void:
	_blink_timer += delta * 6.0

	if current_state == State.RECORDING:
		_record_timer -= delta
		if rec_light:
			rec_light.visible = fmod(_blink_timer, 2.0) > 1.0

		# Capture mic frames into dictaphone buffer
		if VoiceChatManager and VoiceChatManager._capture_effect:
			var avail: int = VoiceChatManager._capture_effect.get_frames_available()
			if avail > 0:
				var frames: PackedVector2Array = VoiceChatManager._capture_effect.get_buffer(avail)
				_recorded_frames.append_array(frames)

		if _record_timer <= 0.0:
			stop_recording()
		else:
			if status_label:
				status_label.text = "🔴 ИДЕТ ЗАПИСЬ... %.1f СЕК\nГОВОРИТЕ В МИКРОФОН!" % _record_timer

	elif current_state == State.PLAYING:
		if play_light:
			play_light.visible = fmod(_blink_timer, 2.0) > 1.0

		if spatial_audio_player and not spatial_audio_player.playing:
			stop_playback()

func _update_ui_display() -> void:
	if not status_label or not prompt_label:
		return

	match current_state:
		State.IDLE:
			status_label.text = "📼 ТЕСТОВЫЙ ДИКТАФОН"
			status_label.modulate = Color(0.3, 0.9, 1.0)
			prompt_label.text = "👉 Нажмите [E] чтобы записать голос" if _player_in_range else ""
		State.RECORDING:
			status_label.modulate = Color(1.0, 0.3, 0.3)
			prompt_label.text = "🎙️ ГОВОРИТЕ В МИКРОФОН..."
		State.HAS_RECORDING:
			status_label.text = "📼 ГОЛОС ЗАПИСАН! (%d фреймов)" % _recorded_frames.size()
			status_label.modulate = Color(0.3, 1.0, 0.5)
			prompt_label.text = "👉 Нажмите [E] для воспроизведения 3D" if _player_in_range else ""
		State.PLAYING:
			status_label.text = "🔊 3D ВОСПРОИЗВЕДЕНИЕ ГОЛОСА..."
			status_label.modulate = Color(0.2, 1.0, 0.4)
			prompt_label.text = "👉 Нажмите [E] для остановки" if _player_in_range else ""
