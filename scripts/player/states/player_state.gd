class_name PlayerState
extends State

## Base class for player-specific states in the FSM.

var player: Player

func _ready() -> void:
	if owner:
		if not owner.is_node_ready():
			await owner.ready
		player = owner as Player
	else:
		var parent := get_parent()
		if parent and parent.get_parent() is Player:
			player = parent.get_parent() as Player
