class_name BaseCharacterMechanics
extends Node

## Base class for unique character mechanics and abilities.

var player: CharacterBody3D

func _ready() -> void:
	if owner:
		if not owner.is_node_ready():
			await owner.ready
		player = owner as CharacterBody3D
	elif get_parent():
		player = get_parent() as CharacterBody3D

func setup(p: CharacterBody3D) -> void:
	player = p

func handle_ability_input(_event: InputEvent) -> void:
	pass

func update_mechanics(_delta: float) -> void:
	pass

func physics_update_mechanics(_delta: float) -> void:
	pass

func is_movement_blocked() -> bool:
	return false
