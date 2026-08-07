class_name HeavyPressureButton
extends Node3D

## Heavy Pressure Button ("Тяжелая нажимная кнопка / Плита под вес"):
## - Activates ONLY under heavy weight (>= 150 kg):
##   * Fat player ("Жирдяй", 160 kg)
##   * Heavy Boulder ("HeavyBoulder", 450 kg)
## - Thin player ("Худой", 80 kg) is too light and CANNOT activate it alone!
## - Premium industrial design with octagonal hazard base, 4 hydraulic pistons, center emblem, and dynamic light!

signal button_pressed(trigger_object: Node)
signal button_released()
signal button_toggled(is_pressed: bool)

@export var required_weight: float = 150.0 ## Minimum required weight in kg
@export var is_toggle: bool = false ## Stay pressed until pressed again?
@export var target_object: Node3D ## Target object to trigger (e.g. WindTunnelFan, Door, Elevator)
@export var target_method_on_press: String = "" ## Optional method name to invoke on target when pressed
@export var target_method_on_release: String = "" ## Optional method name to invoke on target when released

@onready var plunger: MeshInstance3D = $Plunger
@onready var center_emblem: MeshInstance3D = $Plunger/CenterEmblem
@onready var indicator_ring: MeshInstance3D = $Base/IndicatorRing
@onready var button_light: OmniLight3D = $ButtonLight
@onready var detection_area: Area3D = $DetectionArea
@onready var press_particles: GPUParticles3D = $PressParticles
@onready var idle_aura_particles: GPUParticles3D = $IdleAuraParticles
@onready var audio_stream_player: AudioStreamPlayer3D = $AudioStreamPlayer3D

@onready var piston_nw: MeshInstance3D = $Base/PistonNW
@onready var piston_ne: MeshInstance3D = $Base/PistonNE
@onready var piston_sw: MeshInstance3D = $Base/PistonSW
@onready var piston_se: MeshInstance3D = $Base/PistonSE

var is_pressed: bool = false
var _current_weight: float = 0.0
var _primary_trigger: Node = null

# Plunger Y positions
const UNPRESSED_Y: float = 0.24
const PRESSED_Y: float = 0.08

# Indicator colors
const INACTIVE_COLOR: Color = Color(1.0, 0.15, 0.1, 1.0) # Ruby Red
const ACTIVE_COLOR: Color = Color(0.0, 1.0, 0.85, 1.0) # Neon Electric Cyan

var _indicator_mat: StandardMaterial3D
var _emblem_mat: StandardMaterial3D

func _ready() -> void:
	if indicator_ring:
		_indicator_mat = StandardMaterial3D.new()
		_indicator_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		_indicator_mat.albedo_color = INACTIVE_COLOR
		_indicator_mat.emission_enabled = true
		_indicator_mat.emission = INACTIVE_COLOR
		_indicator_mat.emission_energy_multiplier = 3.5
		indicator_ring.material_override = _indicator_mat

	if center_emblem:
		_emblem_mat = StandardMaterial3D.new()
		_emblem_mat.albedo_color = INACTIVE_COLOR
		_emblem_mat.emission_enabled = true
		_emblem_mat.emission = INACTIVE_COLOR
		_emblem_mat.emission_energy_multiplier = 4.0
		center_emblem.material_override = _emblem_mat

	if detection_area:
		detection_area.body_entered.connect(_on_body_entered)
		detection_area.body_exited.connect(_on_body_exited)

func _physics_process(delta: float) -> void:
	_calculate_weight_and_state()
	_animate_plunger(delta)

func _calculate_weight_and_state() -> void:
	if not detection_area:
		return

	var total_weight: float = 0.0
	var top_trigger: Node = null

	var bodies: Array[Node3D] = detection_area.get_overlapping_bodies()
	for body in bodies:
		if body == self or body is StaticBody3D:
			continue

		if body is Player:
			var p: Player = body as Player
			if not p.is_dead:
				var p_weight: float = 80.0 # Default Thin weight
				if p.selected_character_id.to_lower() == "fat":
					p_weight = 160.0 # Fat weight
				
				if p.is_carrying_heavy_object:
					p_weight += 450.0 # Carrying boulder adds mass!
				
				total_weight += p_weight
				if not top_trigger:
					top_trigger = p

		elif body is RigidBody3D:
			var rb: RigidBody3D = body as RigidBody3D
			total_weight += rb.mass
			if not top_trigger:
				top_trigger = rb

	_current_weight = total_weight

	var should_be_pressed: bool = total_weight >= required_weight

	if should_be_pressed and not is_pressed:
		_press_button(top_trigger)
	elif not should_be_pressed and is_pressed and not is_toggle:
		_release_button()

func _press_button(trigger: Node) -> void:
	is_pressed = true
	_primary_trigger = trigger

	if _indicator_mat:
		_indicator_mat.albedo_color = ACTIVE_COLOR
		_indicator_mat.emission = ACTIVE_COLOR
		_indicator_mat.emission_energy_multiplier = 4.5

	if _emblem_mat:
		_emblem_mat.albedo_color = ACTIVE_COLOR
		_emblem_mat.emission = ACTIVE_COLOR
		_emblem_mat.emission_energy_multiplier = 5.0

	if button_light:
		button_light.light_color = ACTIVE_COLOR
		button_light.light_energy = 4.5

	if press_particles:
		press_particles.restart()
		press_particles.emitting = true

	button_pressed.emit(trigger)
	button_toggled.emit(true)

	print("🔘 HEAVY BUTTON PRESSED! Total Weight: %.1f kg (Trigger: %s)" % [_current_weight, trigger.name if trigger else "Unknown"])

	var target: Node = _get_target_node()
	if target:
		if target_method_on_press != "" and target.has_method(target_method_on_press):
			target.call(target_method_on_press)
		elif target.has_method("deactivate"):
			target.call("deactivate")
		elif target.has_method("set_active"):
			target.call("set_active", false)

func _release_button() -> void:
	is_pressed = false
	_primary_trigger = null

	if _indicator_mat:
		_indicator_mat.albedo_color = INACTIVE_COLOR
		_indicator_mat.emission = INACTIVE_COLOR
		_indicator_mat.emission_energy_multiplier = 3.5

	if _emblem_mat:
		_emblem_mat.albedo_color = INACTIVE_COLOR
		_emblem_mat.emission = INACTIVE_COLOR
		_emblem_mat.emission_energy_multiplier = 4.0

	if button_light:
		button_light.light_color = INACTIVE_COLOR
		button_light.light_energy = 2.5

	button_released.emit()
	button_toggled.emit(false)

	print("🔘 HEAVY BUTTON RELEASED!")

	var target: Node = _get_target_node()
	if target:
		if target_method_on_release != "" and target.has_method(target_method_on_release):
			target.call(target_method_on_release)
		elif target.has_method("activate"):
			target.call("activate")
		elif target.has_method("set_active"):
			target.call("set_active", true)

func _get_target_node() -> Node:
	if target_object:
		return target_object
	
	# Fallback search for WindTunnelFan in room if not explicitly linked
	var root: Node = get_tree().root
	var fans: Array[Node] = root.find_children("*", "WindTunnelFan", true, false)
	if not fans.is_empty():
		return fans[0]
	
	return null

func _animate_plunger(delta: float) -> void:
	if not plunger:
		return

	var target_y: float = PRESSED_Y if is_pressed else UNPRESSED_Y
	plunger.position.y = lerpf(plunger.position.y, target_y, 14.0 * delta)

	# Animate 4 corner hydraulic pistons downward proportionally!
	var progress: float = clampf((UNPRESSED_Y - plunger.position.y) / (UNPRESSED_Y - PRESSED_Y), 0.0, 1.0)
	var piston_y: float = lerpf(0.15, 0.04, progress)
	if piston_nw: piston_nw.position.y = piston_y
	if piston_ne: piston_ne.position.y = piston_y
	if piston_sw: piston_sw.position.y = piston_y
	if piston_se: piston_se.position.y = piston_y

func _on_body_entered(body: Node) -> void:
	if body is Player:
		var p: Player = body as Player
		if p.selected_character_id.to_lower() == "thin" and not p.is_carrying_heavy_object:
			# Feedback to Thin player that they are too light!
			print("ℹ️ Thin player is too light (80 kg)! Need Fat (160 kg) or Heavy Boulder (450 kg).")

func _on_body_exited(body: Node) -> void:
	pass
