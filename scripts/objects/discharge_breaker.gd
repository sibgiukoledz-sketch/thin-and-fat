class_name DischargeBreaker
extends Node3D

## Heavy Electric Discharge Breaker Switch (Рубильник разрядки):
## - Players (especially Fat) can press [E] to flip the breaker switch.
## - Sends an electric shockwave pulse that discharges static electricity from Thin,
##   causing him to instantly uncling from metal ceilings and fall down.

signal breaker_pulled(is_active: bool)

@export var is_active: bool = false
@export var target_thin_player: Player = null

@onready var lever_pivot: Node3D = $Base/LeverPivot
@onready var interaction_area: Area3D = $InteractionArea
@onready var prompt_label: Label3D = $PromptLabel3D
@onready var spark_light: OmniLight3D = $SparkLight

const OFF_ANGLE_Z: float = -40.0
const ON_ANGLE_Z: float = 40.0

var _players_in_range: Array[Player] = []

func _ready() -> void:
	if interaction_area:
		interaction_area.body_entered.connect(_on_body_entered)
		interaction_area.body_exited.connect(_on_body_exited)

	if prompt_label:
		prompt_label.hide()

func _physics_process(delta: float) -> void:
	_animate_lever(delta)
	_handle_player_input()

func _animate_lever(delta: float) -> void:
	if not lever_pivot:
		return
	var target_deg := ON_ANGLE_Z if is_active else OFF_ANGLE_Z
	var cur_deg := rad_to_deg(lever_pivot.rotation.z)
	var new_deg := lerpf(cur_deg, target_deg, 12.0 * delta)
	lever_pivot.rotation.z = deg_to_rad(new_deg)

func _handle_player_input() -> void:
	if _players_in_range.is_empty():
		return

	for p in _players_in_range:
		if p and p.is_multiplayer_authority():
			if Input.is_action_just_pressed("interact") or Input.is_key_pressed(KEY_E):
				rpc_flip_breaker.rpc()
				break

@rpc("any_peer", "call_local", "reliable")
func rpc_flip_breaker() -> void:
	is_active = not is_active
	breaker_pulled.emit(is_active)

	if AudioManager:
		AudioManager.play_sfx_3d("discharge_zap", global_position, 40.0, 2.0)
		AudioManager.play_sfx_3d("lever_flip", global_position, 30.0)

	if spark_light:
		spark_light.light_energy = 5.0
		create_tween().tween_property(spark_light, "light_energy", 0.0, 0.4)

	# Search all players in level to discharge Thin characters
	var players := get_tree().get_nodes_in_group("players")
	for node in players:
		if node is Player:
			var p := node as Player
			if p.selected_character_id.to_lower() == "thin" and p.active_mechanics:
				if p.active_mechanics.has_method("rpc_discharge"):
					p.active_mechanics.rpc_discharge.rpc()

func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		var p := body as Player
		if not _players_in_range.has(p):
			_players_in_range.append(p)
		if p.is_multiplayer_authority() and prompt_label:
			prompt_label.show()
			prompt_label.text = "[E] РАЗРЯДИТЬ ХУДОГО"

func _on_body_exited(body: Node3D) -> void:
	if body is Player:
		var p := body as Player
		_players_in_range.erase(p)
		if p.is_multiplayer_authority() and prompt_label:
			prompt_label.hide()
