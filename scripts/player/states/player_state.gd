class_name PlayerState
extends State

## Base class for player-specific states in the FSM.

var player: CharacterBody3D

func _ready() -> void:
	if owner:
		if not owner.is_node_ready():
			await owner.ready
		player = owner as CharacterBody3D
	else:
		var parent := get_parent()
		if parent and parent.get_parent() is CharacterBody3D:
			player = parent.get_parent() as CharacterBody3D
