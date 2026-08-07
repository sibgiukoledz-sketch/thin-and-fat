class_name BaseCharacterMechanics
extends Node

## Base class for unique character mechanics and abilities.

var player: Player

func _ready() -> void:
	if owner:
		if not owner.is_node_ready():
			await owner.ready
		player = owner as Player
	elif get_parent() is Player:
		player = get_parent() as Player

func setup(p: Player) -> void:
	player = p

func handle_ability_input(_event: InputEvent) -> void:
	pass

func update_mechanics(_delta: float) -> void:
	pass

func physics_update_mechanics(_delta: float) -> void:
	pass
