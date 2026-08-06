class_name TrashBin
extends Area3D

## Interactive Trash Bin that grants Stench level to Fat player when stepped in or interacted with.

signal stench_granted(player_node: Node3D, amount: float)

@export var is_infinite: bool = false
@export var stench_amount: float = 35.0
@export var tick_interval: float = 1.5

@onready var prompt_label: Label3D = $PromptLabel3D
@onready var trash_particles: GPUParticles3D = $TrashParticles

var _is_used: bool = false
var _tick_timer: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_update_prompt()

func _update_prompt() -> void:
	if not prompt_label:
		return
	if is_infinite:
		prompt_label.text = "♻️ БЕСКОНЕЧНАЯ МУСОРКА (+35% ВОНИ)"
	else:
		if _is_used:
			prompt_label.text = "🗑️ МУСОРКА ПУСТА"
		else:
			prompt_label.text = "🗑️ ОДНОРАЗОВАЯ МУСОРКА (+35% ВОНИ)"

func _process(delta: float) -> void:
	var overlapping := get_overlapping_bodies()
	for body in overlapping:
		if body is Player:
			_handle_player_inside(body as Player, delta)

func _on_body_entered(body: Node) -> void:
	if body is Player:
		_grant_stench_to_player(body as Player)

func _handle_player_inside(player_node: Player, delta: float) -> void:
	if not is_infinite or _is_used:
		return

	_tick_timer += delta
	if _tick_timer >= tick_interval:
		_tick_timer = 0.0
		_grant_stench_to_player(player_node)

func _grant_stench_to_player(player_node: Player) -> void:
	if not player_node:
		return

	if not is_infinite and _is_used:
		return

	if player_node.active_mechanics and player_node.active_mechanics is FatMechanics:
		var fat_mech := player_node.active_mechanics as FatMechanics
		fat_mech.add_stench(stench_amount)

		if not is_infinite:
			_is_used = true
			_update_prompt()

		if trash_particles:
			trash_particles.restart()
			trash_particles.emitting = true

		stench_granted.emit(player_node, stench_amount)
		print("🗑️ TRASH BIN: Granted %f stench to %s" % [stench_amount, player_node.name])
