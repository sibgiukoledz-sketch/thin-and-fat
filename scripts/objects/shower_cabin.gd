class_name ShowerCabin
extends Area3D

## Interactive Shower Cabin object that washes away Fat player's stench and heals HP.

signal player_washed(player_node: Node3D)

@export var heal_amount: float = 20.0
@export var cooldown: float = 4.0

@onready var prompt_label: Label3D = $PromptLabel3D
@onready var water_particles: GPUParticles3D = $WaterParticles

var _is_on_cooldown: bool = false
var _cooldown_timer: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	update_prompt_visibility(false)

func _process(delta: float) -> void:
	if _is_on_cooldown:
		_cooldown_timer -= delta
		if _cooldown_timer <= 0.0:
			_is_on_cooldown = false
			prompt_label.text = "[E] ПОМЫТЬСЯ В ДУШЕ"

func _unhandled_input(event: InputEvent) -> void:
	if _is_on_cooldown:
		return

	if InputMap.has_action("interact") and event.is_action_pressed("interact"):
		_try_interact_local_player()
	elif event is InputEventKey and event.keycode == KEY_E and event.pressed and not event.echo:
		_try_interact_local_player()

func _try_interact_local_player() -> void:
	for body in get_overlapping_bodies():
		if body is Player and body.is_multiplayer_authority():
			rpc_wash_player.rpc(body.get_path())

@rpc("any_peer", "call_local", "reliable")
func rpc_wash_player(player_path: NodePath) -> void:
	var player_node := get_node_or_null(player_path) as Player
	if not player_node:
		return

	_is_on_cooldown = true
	_cooldown_timer = cooldown
	prompt_label.text = "Свежесть! [Перезарядка...]"

	# Reset stench if Fat
	if player_node.active_mechanics and player_node.active_mechanics is FatMechanics:
		(player_node.active_mechanics as FatMechanics).wash_stench()

	# Heal player HP
	player_node.heal(heal_amount)

	# Trigger water particles
	if water_particles:
		water_particles.restart()
		water_particles.emitting = true

	player_washed.emit(player_node)
	print("🚿 Shower Cabin washed player: ", player_node.name)

func _on_body_entered(body: Node) -> void:
	if body is Player and body.is_multiplayer_authority():
		update_prompt_visibility(true)

func _on_body_exited(body: Node) -> void:
	if body is Player and body.is_multiplayer_authority():
		update_prompt_visibility(false)

func update_prompt_visibility(visible_state: bool) -> void:
	if prompt_label:
		prompt_label.visible = visible_state and not _is_on_cooldown
