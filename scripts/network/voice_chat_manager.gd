extends Node

## Universal AAA 3D Positional Spatial Voice Chat Manager for Godot 4.
## Features:
## - Push-to-Talk (Default: 'V') & Always-On Modes.
## - Low-bandwidth 16-bit PCM Audio Capture via AudioEffectCapture.
## - Live Local Mic Loopback Test with real-time level meter.
## - 3D Spatialized Positional Playback per peer (AudioStreamPlayer3D).
## - Visual 3D Speaking Indicators & Per-Peer Mute / Volume controls.

signal voice_state_changed(is_speaking: bool)
signal peer_speaking_changed(peer_id: int, is_speaking: bool)

@export var ptt_action: String = "voice_chat"
@export var sample_rate: int = 22050 # High-fidelity 22.05 kHz sample rate
@export var push_to_talk: bool = true

const RECORD_BUS_NAME: String = "VoiceRecordBus"
const VOICE_VOX_BUS: String = "VoicePlaybackBus"

var _capture_effect: AudioEffectCapture
var _is_speaking: bool = false
var _muted_peers: Dictionary = {} # peer_id -> bool
var _peer_players: Dictionary = {} # peer_id -> AudioStreamPlayer3D
var _peer_playback: Dictionary = {} # peer_id -> AudioStreamGeneratorPlayback
var _peer_speaking: Dictionary = {} # peer_id -> bool
var _peer_speak_timers: Dictionary = {} # peer_id -> float

var _mic_player: AudioStreamPlayer = null
var _test_player: AudioStreamPlayer = null
var _test_playback: AudioStreamGeneratorPlayback = null

var _last_mic_level: float = 0.0
var mic_test_active: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_voice_input_action()
	_setup_voice_buses()
	_setup_capture()

func _setup_voice_input_action() -> void:
	if not InputMap.has_action(ptt_action):
		InputMap.add_action(ptt_action)
		var ev := InputEventKey.new()
		ev.keycode = KEY_V
		InputMap.action_add_event(ptt_action, ev)

func _setup_voice_buses() -> void:
	# 1. Voice Capture Record Bus (Muted send to prevent raw unbuffered echo)
	var rec_idx := AudioServer.get_bus_index(RECORD_BUS_NAME)
	if rec_idx == -1:
		rec_idx = AudioServer.bus_count
		AudioServer.add_bus(rec_idx)
		AudioServer.set_bus_name(rec_idx, RECORD_BUS_NAME)
		AudioServer.set_bus_send(rec_idx, "Master")
		AudioServer.set_bus_mute(rec_idx, true)

	# Add AudioEffectCapture to record bus
	_capture_effect = null
	for i in range(AudioServer.get_bus_effect_count(rec_idx)):
		var eff := AudioServer.get_bus_effect(rec_idx, i)
		if eff is AudioEffectCapture:
			_capture_effect = eff as AudioEffectCapture
			break

	if not _capture_effect:
		_capture_effect = AudioEffectCapture.new()
		_capture_effect.buffer_length = 0.5
		AudioServer.add_bus_effect(rec_idx, _capture_effect)

	# 2. Voice Playback Bus (Connected to SFX / Master)
	var vox_idx := AudioServer.get_bus_index(VOICE_VOX_BUS)
	if vox_idx == -1:
		vox_idx = AudioServer.bus_count
		AudioServer.add_bus(vox_idx)
		AudioServer.set_bus_name(vox_idx, VOICE_VOX_BUS)
		AudioServer.set_bus_send(vox_idx, "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master")

func _setup_capture() -> void:
	var devices := AudioServer.get_input_device_list()
	if devices.size() > 0 and (AudioServer.input_device == "" or AudioServer.input_device == "Default"):
		AudioServer.input_device = devices[0]

	if not _mic_player:
		_mic_player = AudioStreamPlayer.new()
		_mic_player.name = "MicrophoneInputPlayer"
		_mic_player.stream = AudioStreamMicrophone.new()
		_mic_player.bus = RECORD_BUS_NAME
		_mic_player.autoplay = true
		add_child(_mic_player)
		_mic_player.play()

func _ensure_test_player() -> void:
	if not _test_player:
		_test_player = AudioStreamPlayer.new()
		_test_player.name = "MicTestAudioPlayer"
		_test_player.bus = VOICE_VOX_BUS
		var gen := AudioStreamGenerator.new()
		gen.mix_rate = 44100.0
		gen.buffer_length = 0.4
		_test_player.stream = gen
		add_child(_test_player)
		_test_player.play()
		_test_playback = _test_player.get_stream_playback() as AudioStreamGeneratorPlayback

func set_input_device(device_name: String) -> void:
	AudioServer.input_device = device_name
	if _mic_player:
		_mic_player.stop()
		_mic_player.play()

func set_output_device(device_name: String) -> void:
	AudioServer.output_device = device_name

func get_mic_input_level() -> float:
	return _last_mic_level

func _process(delta: float) -> void:
	_update_speaking_timers(delta)
	_handle_input_and_capture()

func _update_speaking_timers(delta: float) -> void:
	for peer_id in _peer_speak_timers.keys():
		_peer_speak_timers[peer_id] -= delta
		if _peer_speak_timers[peer_id] <= 0.0:
			_peer_speak_timers.erase(peer_id)
			_set_peer_speaking(peer_id, false)

func _handle_input_and_capture() -> void:
	# Voice chat disabled / stubbed by user request
	_is_speaking = false
	_last_mic_level = 0.0
	return

func _compress_pcm_frames(frames: PackedVector2Array) -> PackedByteArray:
	# Downsample & Quantize 32-bit Vector2 PCM frames into 16-bit PCM byte array
	var step: int = maxi(1, int(44100.0 / float(sample_rate)))
	var count: int = int(float(frames.size()) / float(step))
	var bytes := PackedByteArray()
	bytes.resize(count * 2)

	var idx: int = 0
	var i: int = 0
	while i < frames.size() and idx < count * 2:
		var mono_sample: float = (frames[i].x + frames[i].y) * 0.5
		var int16_sample: int = int(clampf(mono_sample * 32767.0, -32768.0, 32767.0))
		bytes.encode_s16(idx, int16_sample)
		idx += 2
		i += step

	return bytes

@rpc("any_peer", "call_remote", "unreliable_ordered")
func rpc_receive_voice_chunk(sender_id: int, audio_bytes: PackedByteArray) -> void:
	if _muted_peers.get(sender_id, false):
		return

	var playback: AudioStreamGeneratorPlayback = _get_or_create_peer_player(sender_id)
	if not playback:
		return

	_peer_speak_timers[sender_id] = 0.4
	_set_peer_speaking(sender_id, true)

	# Decompress 16-bit PCM into PackedVector2Array and push buffer
	var sample_count: int = audio_bytes.size() / 2
	if sample_count == 0:
		return

	var frames := PackedVector2Array()
	frames.resize(sample_count)

	for i in range(sample_count):
		var sample_f: float = float(audio_bytes.decode_s16(i * 2)) / 32767.0
		frames[i] = Vector2(sample_f, sample_f)

	var can_push: int = playback.get_frames_available()
	if can_push > 0:
		var push_count: int = mini(can_push, frames.size())
		if push_count < frames.size():
			frames = frames.slice(0, push_count)
		playback.push_buffer(frames)

func _get_or_create_peer_player(peer_id: int) -> AudioStreamGeneratorPlayback:
	if _peer_playback.has(peer_id) and is_instance_valid(_peer_players.get(peer_id, null)):
		return _peer_playback[peer_id]

	# Create 3D Spatialized AudioStreamPlayer3D for remote peer
	var p3d := AudioStreamPlayer3D.new()
	p3d.name = "VoicePlayer3D_%d" % peer_id
	p3d.bus = VOICE_VOX_BUS
	p3d.max_distance = 35.0
	p3d.unit_size = 5.0
	p3d.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE

	var generator := AudioStreamGenerator.new()
	generator.mix_rate = float(sample_rate)
	generator.buffer_length = 0.4
	p3d.stream = generator

	# Attach player to remote player's 3D node in the world if available
	var root: Node = get_tree().root
	var target_parent: Node = root
	var player_node := root.find_child(str(peer_id), true, false)
	if player_node:
		target_parent = player_node

	target_parent.add_child(p3d)
	p3d.play()

	var playback := p3d.get_stream_playback() as AudioStreamGeneratorPlayback
	_peer_players[peer_id] = p3d
	_peer_playback[peer_id] = playback
	return playback

@rpc("any_peer", "call_local", "reliable")
func rpc_set_peer_speaking(peer_id: int, speaking: bool) -> void:
	_set_peer_speaking(peer_id, speaking)

func _set_peer_speaking(peer_id: int, speaking: bool) -> void:
	if _peer_speaking.get(peer_id, false) != speaking:
		_peer_speaking[peer_id] = speaking
		peer_speaking_changed.emit(peer_id, speaking)
		_update_player_voice_indicator(peer_id, speaking)

func _update_player_voice_indicator(peer_id: int, speaking: bool) -> void:
	var root: Node = get_tree().root
	var player_node := root.find_child(str(peer_id), true, false)
	if player_node and player_node.has_method("set_voice_indicator"):
		player_node.call("set_voice_indicator", speaking)

func set_peer_muted(peer_id: int, muted: bool) -> void:
	_muted_peers[peer_id] = muted

func is_peer_muted(peer_id: int) -> bool:
	return _muted_peers.get(peer_id, false)

func is_peer_speaking(peer_id: int) -> bool:
	return _peer_speaking.get(peer_id, false)
