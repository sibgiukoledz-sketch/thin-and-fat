extends Node

## Universal AAA Audio Manager Autoload Singleton for Godot 4.
## Features:
## - High-performance pre-allocated 2D/3D Audio Player Pooling (0 ms lag).
## - Built-in Procedural Audio Synthesizer fallback for missing sound assets.
## - Spatial 3D positional audio, pitch randomization, and volume attenuation.
## - Music crossfading, bus layout management, and simple string-event API.

signal sound_event_triggered(event_name: String, position: Vector3)

# Sound Buses
const BUS_MASTER: String = "Master"
const BUS_MUSIC: String = "Music"
const BUS_SFX: String = "SFX"
const BUS_UI: String = "UI"

# Pre-allocated Player Pools
const POOL_SIZE_2D: int = 16
const POOL_SIZE_3D: int = 32

var _pool_2d: Array[AudioStreamPlayer] = []
var _pool_3d: Array[AudioStreamPlayer3D] = []
var _pool_2d_idx: int = 0
var _pool_3d_idx: int = 0

# Music Players for smooth crossfading
var _music_player_a: AudioStreamPlayer
var _music_player_b: AudioStreamPlayer
var _active_music_is_a: bool = true

# Sound Registry: event_name -> AudioStream or Array[AudioStream]
var sound_registry: Dictionary = {}
# Procedural Synthesized Stream Cache: event_name -> AudioStreamWAV
var _procedural_cache: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_audio_buses()
	_create_player_pools()
	_create_music_players()
	_load_sound_files()

func _setup_audio_buses() -> void:
	# Ensure SFX, Music, and UI buses exist in AudioServer
	for b_name in [BUS_MUSIC, BUS_SFX, BUS_UI]:
		if AudioServer.get_bus_index(b_name) == -1:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, b_name)
			AudioServer.set_bus_send(idx, BUS_MASTER)

func _create_player_pools() -> void:
	# 1. 2D Pool
	var container_2d := Node.new()
	container_2d.name = "AudioPool2D"
	add_child(container_2d)

	for i in range(POOL_SIZE_2D):
		var p := AudioStreamPlayer.new()
		p.name = "Player2D_%d" % i
		p.bus = BUS_SFX
		container_2d.add_child(p)
		_pool_2d.append(p)

	# 2. 3D Pool
	var container_3d := Node.new()
	container_3d.name = "AudioPool3D"
	add_child(container_3d)

	for i in range(POOL_SIZE_3D):
		var p3d := AudioStreamPlayer3D.new()
		p3d.name = "Player3D_%d" % i
		p3d.bus = BUS_SFX
		p3d.max_distance = 45.0
		p3d.unit_size = 6.0
		p3d.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		container_3d.add_child(p3d)
		_pool_3d.append(p3d)

func _create_music_players() -> void:
	var music_box := Node.new()
	music_box.name = "MusicContainer"
	add_child(music_box)

	_music_player_a = AudioStreamPlayer.new()
	_music_player_a.name = "MusicPlayerA"
	_music_player_a.bus = BUS_MUSIC
	music_box.add_child(_music_player_a)

	_music_player_b = AudioStreamPlayer.new()
	_music_player_b.name = "MusicPlayerB"
	_music_player_b.bus = BUS_MUSIC
	music_box.add_child(_music_player_b)

func _load_sound_files() -> void:
	# Scan res://assets/audio/ for sound files if present
	var audio_dir := "res://assets/audio/"
	if DirAccess.dir_exists_absolute(audio_dir):
		_scan_audio_folder(audio_dir)

func _scan_audio_folder(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if dir.current_is_dir() and not file_name.begins_with("."):
				_scan_audio_folder(path + file_name + "/")
			elif file_name.ends_with(".wav") or file_name.ends_with(".ogg") or file_name.ends_with(".mp3"):
				var event_key := file_name.get_basename().to_lower()
				var full_path := path + file_name
				var stream := load(full_path) as AudioStream
				if stream:
					register_sound(event_key, stream)
			file_name = dir.get_next()

func register_sound(event_name: String, stream: AudioStream) -> void:
	var key := event_name.to_lower()
	if sound_registry.has(key):
		var existing = sound_registry[key]
		if existing is Array:
			existing.append(stream)
		else:
			sound_registry[key] = [existing, stream]
	else:
		sound_registry[key] = stream

func play_sfx_2d(event_name: String, volume_db: float = 0.0, pitch_variance: float = 0.08, bus_override: String = "") -> void:
	var stream := _get_stream_for_event(event_name)
	if not stream:
		return

	var player := _get_next_2d_player()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = randf_range(1.0 - pitch_variance, 1.0 + pitch_variance)
	player.bus = bus_override if bus_override != "" else (BUS_UI if event_name.begins_with("ui_") else BUS_SFX)
	player.play()

	sound_event_triggered.emit(event_name, Vector3.ZERO)

func play_sfx_3d(event_name: String, pos: Vector3, max_dist: float = 40.0, volume_db: float = 0.0, pitch_variance: float = 0.10) -> void:
	var stream := _get_stream_for_event(event_name)
	if not stream:
		return

	var player3d := _get_next_3d_player()
	player3d.global_position = pos
	player3d.max_distance = max_dist
	player3d.stream = stream
	player3d.volume_db = volume_db
	player3d.pitch_scale = randf_range(1.0 - pitch_variance, 1.0 + pitch_variance)
	player3d.bus = BUS_SFX
	player3d.play()

	sound_event_triggered.emit(event_name, pos)

func play_music(music_stream_or_path, fade_duration: float = 1.5) -> void:
	var stream: AudioStream = null
	if music_stream_or_path is AudioStream:
		stream = music_stream_or_path
	elif music_stream_or_path is String and ResourceLoader.exists(music_stream_or_path):
		stream = load(music_stream_or_path) as AudioStream

	if not stream:
		return

	var current_p := _music_player_a if _active_music_is_a else _music_player_b
	var next_p := _music_player_b if _active_music_is_a else _music_player_a

	if current_p.playing and current_p.stream == stream:
		return # Already playing

	next_p.stream = stream
	next_p.volume_db = -80.0
	next_p.play()

	var tw := create_tween().set_parallel(true)
	tw.tween_property(next_p, "volume_db", 0.0, fade_duration)
	if current_p.playing:
		tw.tween_property(current_p, "volume_db", -80.0, fade_duration)
		tw.chain().tween_callback(current_p.stop)

	_active_music_is_a = not _active_music_is_a

func set_bus_volume(bus_name: String, volume_linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx != -1:
		var db := linear_to_db(clampf(volume_linear, 0.0001, 1.0))
		AudioServer.set_bus_volume_db(idx, db)

func get_bus_volume(bus_name: String) -> float:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx != -1:
		return db_to_linear(AudioServer.get_bus_volume_db(idx))
	return 1.0

func _get_next_2d_player() -> AudioStreamPlayer:
	var player := _pool_2d[_pool_2d_idx]
	_pool_2d_idx = (_pool_2d_idx + 1) % _pool_2d.size()
	return player

func _get_next_3d_player() -> AudioStreamPlayer3D:
	var player3d := _pool_3d[_pool_3d_idx]
	_pool_3d_idx = (_pool_3d_idx + 1) % _pool_3d.size()
	return player3d

func _get_stream_for_event(event_name: String) -> AudioStream:
	var key := event_name.to_lower()

	# 1. Registered Sound File Check
	if sound_registry.has(key):
		var val = sound_registry[key]
		if val is Array:
			return val.pick_random() as AudioStream
		return val as AudioStream

	# 2. Cached Procedural Sound Check
	if _procedural_cache.has(key):
		return _procedural_cache[key]

	# 3. Generate Procedural Sound Sample
	var proc_stream := _synthesize_sound_event(key)
	if proc_stream:
		_procedural_cache[key] = proc_stream
		return proc_stream

	return null

# ==============================================================================
# PROCEDURAL AUDIO SYNTHESIZER FOR ZERO-MISSING ASSET FALLBACK
# ==============================================================================
func _synthesize_sound_event(key: String) -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 0.25
	var samples_count: int = int(sample_rate * duration)
	var pcm_data := PackedByteArray()
	pcm_data.resize(samples_count * 2)

	match key:
		"step_fat":
			duration = 0.28
			samples_count = int(sample_rate * duration)
			pcm_data.resize(samples_count * 2)
			for i in range(samples_count):
				var t := float(i) / float(sample_rate)
				var env := exp(-18.0 * t)
				var freq := lerpf(110.0, 35.0, t / duration)
				var val := sin(2.0 * PI * freq * t) * env * 0.9
				var noise := (randf() * 2.0 - 1.0) * env * 0.25
				var sample_16 := int(clampf(val + noise, -1.0, 1.0) * 32767.0)
				pcm_data.encode_s16(i * 2, sample_16)

		"step_thin":
			duration = 0.12
			samples_count = int(sample_rate * duration)
			pcm_data.resize(samples_count * 2)
			for i in range(samples_count):
				var t := float(i) / float(sample_rate)
				var env := exp(-35.0 * t)
				var noise := (randf() * 2.0 - 1.0) * env * 0.6
				var tone := sin(2.0 * PI * 420.0 * t) * env * 0.2
				var sample_16 := int(clampf(noise + tone, -1.0, 1.0) * 32767.0)
				pcm_data.encode_s16(i * 2, sample_16)

		"jump_fat", "jump_thin", "jump":
			duration = 0.22
			samples_count = int(sample_rate * duration)
			pcm_data.resize(samples_count * 2)
			for i in range(samples_count):
				var t := float(i) / float(sample_rate)
				var env := exp(-10.0 * t)
				var freq := lerpf(120.0, 340.0, t / duration)
				var val := sin(2.0 * PI * freq * t) * env * 0.7
				var sample_16 := int(clampf(val, -1.0, 1.0) * 32767.0)
				pcm_data.encode_s16(i * 2, sample_16)

		"land":
			duration = 0.35
			samples_count = int(sample_rate * duration)
			pcm_data.resize(samples_count * 2)
			for i in range(samples_count):
				var t := float(i) / float(sample_rate)
				var env := exp(-12.0 * t)
				var freq := lerpf(90.0, 25.0, t / duration)
				var val := sin(2.0 * PI * freq * t) * env * 0.95
				var sample_16 := int(clampf(val, -1.0, 1.0) * 32767.0)
				pcm_data.encode_s16(i * 2, sample_16)

		"seismic_shockwave", "boulder_impact":
			duration = 0.55
			samples_count = int(sample_rate * duration)
			pcm_data.resize(samples_count * 2)
			for i in range(samples_count):
				var t := float(i) / float(sample_rate)
				var env := exp(-6.0 * t)
				var freq := lerpf(85.0, 20.0, t / duration)
				var val := sin(2.0 * PI * freq * t) * env * 0.95
				var sub := sin(2.0 * PI * (freq * 0.5) * t) * env * 0.7
				var noise := (randf() * 2.0 - 1.0) * env * 0.35
				var sample_16 := int(clampf(val + sub + noise, -1.0, 1.0) * 32767.0)
				pcm_data.encode_s16(i * 2, sample_16)

		"slingshot_launch":
			duration = 0.30
			samples_count = int(sample_rate * duration)
			pcm_data.resize(samples_count * 2)
			for i in range(samples_count):
				var t := float(i) / float(sample_rate)
				var env := exp(-8.0 * t)
				var freq := lerpf(380.0, 140.0, t / duration)
				var val := sin(2.0 * PI * freq * t) * env * 0.8
				var sample_16 := int(clampf(val, -1.0, 1.0) * 32767.0)
				pcm_data.encode_s16(i * 2, sample_16)

		"trampoline_bounce":
			duration = 0.45
			samples_count = int(sample_rate * duration)
			pcm_data.resize(samples_count * 2)
			for i in range(samples_count):
				var t := float(i) / float(sample_rate)
				var env := exp(-5.0 * t)
				var freq := lerpf(140.0, 420.0, sin(t * 24.0) * 0.5 + 0.5)
				var val := sin(2.0 * PI * freq * t) * env * 0.85
				var sample_16 := int(clampf(val, -1.0, 1.0) * 32767.0)
				pcm_data.encode_s16(i * 2, sample_16)

		"vomit_burst", "stench_burst":
			duration = 0.40
			samples_count = int(sample_rate * duration)
			pcm_data.resize(samples_count * 2)
			for i in range(samples_count):
				var t := float(i) / float(sample_rate)
				var env := exp(-5.0 * t)
				var noise := (randf() * 2.0 - 1.0) * env * 0.7
				var gurgle := sin(2.0 * PI * 18.0 * t) * noise
				var sample_16 := int(clampf(gurgle, -1.0, 1.0) * 32767.0)
				pcm_data.encode_s16(i * 2, sample_16)

		"glass_crack", "glass_shatter":
			duration = 0.25
			samples_count = int(sample_rate * duration)
			pcm_data.resize(samples_count * 2)
			for i in range(samples_count):
				var t := float(i) / float(sample_rate)
				var env := exp(-25.0 * t)
				var noise := (randf() * 2.0 - 1.0) * env * 0.95
				var tone := sin(2.0 * PI * 2800.0 * t) * env * 0.4
				var sample_16 := int(clampf(noise + tone, -1.0, 1.0) * 32767.0)
				pcm_data.encode_s16(i * 2, sample_16)

		"glass_restore":
			duration = 0.35
			samples_count = int(sample_rate * duration)
			pcm_data.resize(samples_count * 2)
			for i in range(samples_count):
				var t := float(i) / float(sample_rate)
				var env := exp(-7.0 * t)
				var freq := lerpf(600.0, 1400.0, t / duration)
				var chime := sin(2.0 * PI * freq * t) * env * 0.6
				var sample_16 := int(clampf(chime, -1.0, 1.0) * 32767.0)
				pcm_data.encode_s16(i * 2, sample_16)

		"lever_flip", "button_press", "button_release":
			duration = 0.15
			samples_count = int(sample_rate * duration)
			pcm_data.resize(samples_count * 2)
			for i in range(samples_count):
				var t := float(i) / float(sample_rate)
				var env := exp(-30.0 * t)
				var tone := sin(2.0 * PI * 220.0 * t) * env * 0.7
				var click := (randf() * 2.0 - 1.0) * env * 0.5
				var sample_16 := int(clampf(tone + click, -1.0, 1.0) * 32767.0)
				pcm_data.encode_s16(i * 2, sample_16)

		"ui_click", "ui_hover", _:
			duration = 0.08
			samples_count = int(sample_rate * duration)
			pcm_data.resize(samples_count * 2)
			for i in range(samples_count):
				var t := float(i) / float(sample_rate)
				var env := exp(-45.0 * t)
				var tone := sin(2.0 * PI * 880.0 * t) * env * 0.5
				var sample_16 := int(clampf(tone, -1.0, 1.0) * 32767.0)
				pcm_data.encode_s16(i * 2, sample_16)

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = pcm_data
	return wav
