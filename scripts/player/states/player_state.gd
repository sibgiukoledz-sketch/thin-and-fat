class_name PlayerState
extends State

## Base class for player-specific states in the FSM.

var player: Player

func _ready() -> void:
	await owner.ready
	player = owner as Player
	assert(player != null, "PlayerState must be a child of a Player node or descendant of Player owner!")
