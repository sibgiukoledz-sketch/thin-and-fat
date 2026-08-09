extends Node

## Universal AAA 3D Positional Spatial Voice Chat Manager for Godot 4.
## Standard Implementation using AudioEffectCapture, AudioStreamMicrophone, and AudioStreamGenerator.

signal voice_state_changed(is_speaking: bool)
signal peer_speaking_changed(peer_id: int, is_speaking: bool)

@export var ptt_action: String = "voice_chat"
@export var push_to_talk: bool = true

const RECORD_BUS_NAME: String = "VoiceRecordBus"
const VOICE_VOX_BUS: String = "VoicePlaybackBus"

var _capture_effect: AudioEffectCapture = null
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
	# 1. Voice Record Bus (Muted send to prevent local echo back)
	var rec_idx := AudioServer.get_bus_index(RECORD_BUS_NAME)
	if rec_idx == -1:
		rec_idx = AudioServer.bus_count
		AudioServer.add_bus(rec_idx)
		AudioServer.set_bus_name(rec_idx, RECORD_BUS_NAME)
		AudioServer.set_bus_send(rec_idx, "Master")
		AudioServer.set_bus_mute(rec_idx, true)

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

	# 2. Voice Playback Bus (Connected to SFX / Master with AAA 3D spatial reverb & compressor)
	var vox_idx := AudioServer.get_bus_index(VOICE_VOX_BUS)
	if vox_idx == -1:
		vox_idx = AudioServer.bus_count
		AudioServer.add_bus(vox_idx)
		AudioServer.set_bus_name(vox_idx, VOICE_VOX_BUS)
		AudioServer.set_bus_send(vox_idx, "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master")

		# Add subtle room reverb for realistic 3D spatial acoustics
		var rev := AudioEffectReverb.new()
		rev.room_size = 0.20
		rev.damping = 0.60
		rev.wet = 0.15
		rev.dry = 0.85
		AudioServer.add_bus_effect(vox_idx, rev)

		# Add dynamic range compressor for balanced voice levels
		var comp := AudioEffectCompressor.new()
		comp.threshold = -14.0
		comp.ratio = 3.0
		comp.gain = 2.0
		comp.release_ms = 100.0
		AudioServer.add_bus_effect(vox_idx, comp)

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
		gen.mix_rate = AudioServer.get_mix_rate()
		gen.buffer_length = 0.5
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
	if not _capture_effect:
		return

	var frames_avail: int = _capture_effect.get_frames_available()
	if frames_avail <= 0:
		return

	var raw_frames: PackedVector2Array = _capture_effect.get_buffer(frames_avail)

	# 1. Real-time meter level calculation
	var max_amp: float = 0.0
	for f in raw_frames:
		max_amp = maxf(max_amp, maxf(absf(f.x), absf(f.y)))
	_last_mic_level = lerpf(_last_mic_level, clampf(max_amp * 4.0, 0.0, 1.0), 0.35)

	# 2. Mic Test Mode (Settings GUI)
	if mic_test_active:
		_ensure_test_player()
		if _test_playback:
			for frame in raw_frames:
				if _test_playback.can_push_buffer(1):
					_test_playback.push_frame(frame)
		return
	else:
		if _test_player and _test_player.playing:
			_test_player.stop()

	# 3. Check talking state
	var should_talk: bool = false
	if push_to_talk:
		should_talk = Input.is_action_pressed(ptt_action)
	else:
		should_talk = (max_amp > 0.02)

	var is_in_match := (multiplayer and multiplayer.has_multiplayer_peer() and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED)
	if not is_in_match:
		should_talk = false

	if should_talk != _is_speaking:
		_is_speaking = should_talk
		voice_state_changed.emit(_is_speaking)
		if is_in_match:
			rpc_set_peer_speaking.rpc(multiplayer.get_unique_id(), _is_speaking)

	if not _is_speaking or not is_in_match:
		return

	# 4. Stream audio data across network
	rpc_receive_voice_chunk.rpc(multiplayer.get_unique_id(), raw_frames)

@rpc("any_peer", "call_remote", "unreliable_ordered")
func rpc_receive_voice_chunk(sender_id: int, audio_data: PackedVector2Array) -> void:
	if _muted_peers.get(sender_id, false):
		return

	var playback: AudioStreamGeneratorPlayback = _get_or_create_peer_player(sender_id)
	if not playback:
		return

	_peer_speak_timers[sender_id] = 0.4
	_set_peer_speaking(sender_id, true)

	for frame in audio_data:
		if playback.can_push_buffer(1):
			playback.push_frame(frame)

func _get_or_create_peer_player(peer_id: int) -> AudioStreamGeneratorPlayback:
	if _peer_playback.has(peer_id) and is_instance_valid(_peer_players.get(peer_id, null)):
		return _peer_playback[peer_id]

	var p3d := AudioStreamPlayer3D.new()
	p3d.name = "VoicePlayer3D_%d" % peer_id
	p3d.bus = VOICE_VOX_BUS
	p3d.max_distance = 45.0
	p3d.unit_size = 3.0
	p3d.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
	p3d.panning_strength = 1.0
	p3d.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP

	var generator := AudioStreamGenerator.new()
	generator.mix_rate = AudioServer.get_mix_rate()
	generator.buffer_length = 0.5
	p3d.stream = generator

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
