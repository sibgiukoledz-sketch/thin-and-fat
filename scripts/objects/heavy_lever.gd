class_name HeavyLever
extends Node3D

## Heavy Interactive Lever ("Тяжелый интерактивный рычаг"):
## - Players can walk up to it and press [E] to flip the lever ON/OFF!
## - Features 3D HUD prompts, smooth mechanical lever arm rotation, dual neon LEDs,
##   sound effects, spark particles, and universal target object invocation!

signal lever_toggled(is_on: bool)
signal lever_turned_on()
signal lever_turned_off()

@export var is_on: bool = false ## Initial state of the lever
@export var is_one_time: bool = false ## Lock in ON state once pulled?
@export var target_object: Node3D ## Target object to trigger (e.g. WindTunnelFan, Door, Elevator)
@export var target_method_on_enable: String = "activate" ## Method called when lever is flipped ON
@export var target_method_on_disable: String = "deactivate" ## Method called when lever is flipped OFF

@onready var lever_pivot: Node3D = $Base/LeverPivot
@onready var led_off: MeshInstance3D = $Base/TopPanel/BezelOff/LedOff
@onready var led_on: MeshInstance3D = $Base/TopPanel/BezelOn/LedOn
@onready var console_light: OmniLight3D = $ConsoleLight
@onready var interaction_area: Area3D = $InteractionArea
@onready var spark_particles: GPUParticles3D = $SparkParticles
@onready var audio_stream_player: AudioStreamPlayer3D = $AudioStreamPlayer3D

# Lever rotation angles in degrees (around Z axis)
const OFF_ANGLE_Z: float = -38.0
const ON_ANGLE_Z: float = 38.0

# Material LED colors
const OFF_LED_COLOR: Color = Color(1.0, 0.1, 0.1, 1.0)
const ON_LED_COLOR: Color = Color(0.0, 1.0, 0.4, 1.0)
const DIM_LED_COLOR: Color = Color(0.15, 0.15, 0.15, 1.0)

var _led_off_mat: StandardMaterial3D
var _led_on_mat: StandardMaterial3D
var _players_in_range: Array[Player] = []

func _ready() -> void:
	if led_off:
		_led_off_mat = StandardMaterial3D.new()
		_led_off_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		_led_off_mat.emission_enabled = true
		led_off.material_override = _led_off_mat

	if led_on:
		_led_on_mat = StandardMaterial3D.new()
		_led_on_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		_led_on_mat.emission_enabled = true
		led_on.material_override = _led_on_mat

	_update_led_materials()

	if interaction_area:
		interaction_area.body_entered.connect(_on_body_entered)
		interaction_area.body_exited.connect(_on_body_exited)

func _physics_process(delta: float) -> void:
	_animate_lever(delta)
	_handle_player_input()

func toggle_lever() -> void:
	if is_one_time and is_on:
		print("🔒 Lever is locked in ON position!")
		return

	set_lever_state(not is_on)

func set_lever_state(new_state: bool) -> void:
	is_on = new_state
	_update_led_materials()

	if spark_particles:
		spark_particles.restart()
		spark_particles.emitting = true

	lever_toggled.emit(is_on)

	if is_on:
		lever_turned_on.emit()
		print("🕹️ LEVER FLIPPED ON!")
	else:
		lever_turned_off.emit()
		print("🕹️ LEVER FLIPPED OFF!")

	_invoke_target_object()

func _invoke_target_object() -> void:
	var target: Node = _get_target_node()
	if not target:
		return

	var method_to_call: String = target_method_on_enable if is_on else target_method_on_disable

	if method_to_call != "" and target.has_method(method_to_call):
		target.call(method_to_call)
	elif target.has_method("set_active"):
		target.call("set_active", is_on)
	elif target.has_method("toggle_active"):
		target.call("toggle_active")
	elif "is_active" in target:
		target.set("is_active", is_on)

func _get_target_node() -> Node:
	if target_object:
		return target_object
	return null

func _animate_lever(delta: float) -> void:
	if not lever_pivot:
		return

	var target_x: float = ON_ANGLE_Z if is_on else OFF_ANGLE_Z
	lever_pivot.rotation_degrees.x = lerpf(lever_pivot.rotation_degrees.x, target_x, 14.0 * delta)

func _update_led_materials() -> void:
	if _led_off_mat:
		_led_off_mat.albedo_color = OFF_LED_COLOR if not is_on else DIM_LED_COLOR
		_led_off_mat.emission = OFF_LED_COLOR if not is_on else Color.BLACK
		_led_off_mat.emission_energy_multiplier = 4.0 if not is_on else 0.0

	if _led_on_mat:
		_led_on_mat.albedo_color = ON_LED_COLOR if is_on else DIM_LED_COLOR
		_led_on_mat.emission = ON_LED_COLOR if is_on else Color.BLACK
		_led_on_mat.emission_energy_multiplier = 4.0 if is_on else 0.0

	if console_light:
		console_light.light_color = ON_LED_COLOR if is_on else OFF_LED_COLOR
		console_light.light_energy = 3.0 if is_on else 2.0

func _handle_player_input() -> void:
	for p in _players_in_range:
		if p and p.is_multiplayer_authority() and not p.is_dead:
			if Input.is_action_just_pressed("interact"):
				toggle_lever()

func _on_body_entered(body: Node) -> void:
	if body is Player:
		var p: Player = body as Player
		if not _players_in_range.has(p):
			_players_in_range.append(p)
		if p.is_multiplayer_authority():
			_show_prompt(p)

func _on_body_exited(body: Node) -> void:
	if body is Player:
		var p: Player = body as Player
		_players_in_range.erase(p)
		if p.is_multiplayer_authority():
			_hide_prompt(p)

func _show_prompt(p: Player) -> void:
	# Show interactive HUD prompt to player
	if p.has_node("HUD"):
		var hud: Node = p.get_node("HUD")
		if hud.has_method("show_interaction_prompt"):
			var state_text: String = "выключить" if is_on else "включить"
			hud.show_interaction_prompt("[E] Потянуть рычаг (%s)" % state_text)

func _hide_prompt(p: Player) -> void:
	if p.has_node("HUD"):
		var hud: Node = p.get_node("HUD")
		if hud.has_method("hide_interaction_prompt"):
			hud.hide_interaction_prompt()
