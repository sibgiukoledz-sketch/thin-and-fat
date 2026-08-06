class_name BaseCharacterMechanics
extends Node

## Base class for unique character mechanics and abilities.
## Developers can override this class to add custom abilities for specific characters.

var player: Player

func _ready() -> void:
	await owner.ready
	player = owner as Player

func handle_ability_input(_event: InputEvent) -> void:
	pass

func update_mechanics(_delta: float) -> void:
	pass

func physics_update_mechanics(_delta: float) -> void:
	pass
