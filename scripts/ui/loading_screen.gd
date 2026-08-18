class_name LoadingScreen
extends Control

## Modern Threaded Loading Screen:
## - Background scene streaming via ResourceLoader.load_threaded_request()
## - Smooth progress bar animation with percentage label
## - Rotating animated spinner
## - Random gameplay tips carousel
## - Smooth fade-in and fade-out scene transition

@onready var progress_bar: ProgressBar = %ProgressBar
@onready var percent_label: Label = %PercentLabel
@onready var tip_label: Label = %TipLabel
@onready var spinner_icon: Label = %SpinnerIcon
@onready var fade_rect: ColorRect = %FadeRect

var target_scene_path: String = "res://scenes/world.tscn"
var _loading_progress: Array = []
var _target_progress: float = 0.0
var _current_progress: float = 0.0
var _tip_timer: float = 0.0
var _spinner_rot: float = 0.0

const TIPS: Array[String] = [
	"💡 Совет: Толстяк может поднять супер-валун весом 450 кг на [E] и бросить его во врага или стену!",
	"💡 Совет: Худой может сплющиваться в тонкий лист бумаги на [C] / [E] и пролезать в любые щели!",
	"💡 Совет: Толстяк может лечь на спину на [B] и превратиться в живой батут для напарника!",
	"💡 Совет: Худой притягивается к металлическим потолкам и может ползать вверх ногами!",
	"💡 Совет: Используйте [V] для голосового чата (Push-to-Talk) прямо во время игры!",
	"💡 Совет: Зум камеры настраивается колесиком мыши или кликом на колесико (1-е и 3-е лицо)!",
	"💡 Совет: Вонь Толстяка копится при беге и может травить врагов вокруг в зеленом облаке!"
]

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if tip_label:
		tip_label.text = TIPS.pick_random()

	if fade_rect:
		fade_rect.modulate.a = 1.0
		var tw := create_tween()
		tw.tween_property(fade_rect, "modulate:a", 0.0, 0.35)

	# Start background threaded loading
	ResourceLoader.load_threaded_request(target_scene_path)

func _process(delta: float) -> void:
	# Rotate spinner
	_spinner_rot += delta * 360.0
	if spinner_icon:
		spinner_icon.rotation_degrees = _spinner_rot

	# Tip cycle
	_tip_timer += delta
	if _tip_timer > 4.5:
		_tip_timer = 0.0
		if tip_label:
			var tw_tip := create_tween()
			tw_tip.tween_property(tip_label, "modulate:a", 0.0, 0.25)
			tw_tip.tween_callback(func():
				tip_label.text = TIPS.pick_random()
			)
			tw_tip.tween_property(tip_label, "modulate:a", 1.0, 0.25)

	# Poll loading progress
	var status := ResourceLoader.load_threaded_get_status(target_scene_path, _loading_progress)

	if _loading_progress.size() > 0:
		_target_progress = _loading_progress[0] * 100.0

	_current_progress = lerpf(_current_progress, _target_progress, delta * 10.0)

	if progress_bar:
		progress_bar.value = _current_progress
	if percent_label:
		percent_label.text = "%d%%" % int(_current_progress)

	if status == ResourceLoader.THREAD_LOAD_LOADED and _current_progress >= 95.0:
		set_process(false)
		if progress_bar:
			progress_bar.value = 100.0
		if percent_label:
			percent_label.text = "100%"

		var loaded_packed: PackedScene = ResourceLoader.load_threaded_get(target_scene_path) as PackedScene
		if loaded_packed:
			if fade_rect:
				var tw_out := create_tween()
				tw_out.tween_property(fade_rect, "modulate:a", 1.0, 0.3)
				tw_out.tween_callback(func():
					get_tree().change_scene_to_packed(loaded_packed)
				)
			else:
				get_tree().change_scene_to_packed(loaded_packed)
	elif status == ResourceLoader.THREAD_LOAD_FAILED:
		set_process(false)
		if percent_label:
			percent_label.text = "ОШИБКА ЗАГРУЗКИ!"
			percent_label.modulate = Color(1.0, 0.2, 0.2)
