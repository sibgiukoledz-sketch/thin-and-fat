extends Node3D

## World level controller managing player spawning across peers.

@export var player_scene: PackedScene = preload("res://scenes/player.tscn")

@onready var players_container: Node3D = $Players
@onready var spawn_points: Node3D = $SpawnPoints
@onready var spawner: MultiplayerSpawner = $MultiplayerSpawner

func _ready() -> void:
	if spawner:
		spawner.spawn_function = _custom_spawn

	# Server handles player spawning
	if multiplayer.is_server():
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		
		# Spawn host player (ID 1)
		_spawn_player_for_peer(1)
		
		# Spawn existing peers
		for peer_id in multiplayer.get_peers():
			_spawn_player_for_peer(peer_id)

func _on_peer_connected(id: int) -> void:
	_spawn_player_for_peer(id)

func _on_peer_disconnected(id: int) -> void:
	if players_container.has_node(str(id)):
		var p := players_container.get_node(str(id))
		p.queue_free()

func _spawn_player_for_peer(id: int) -> void:
	if not multiplayer.is_server():
		return
	if players_container.has_node(str(id)):
		return

	spawner.spawn(id)

func _custom_spawn(id: int) -> Node:
	var player_inst := player_scene.instantiate() as Player
	player_inst.name = str(id)
	
	# Select spawn point
	var spawn_pos := Vector3(randf_range(-4.0, 4.0), 1.5, randf_range(-4.0, 4.0))
	if spawn_points and spawn_points.get_child_count() > 0:
		var count := spawn_points.get_child_count()
		var point_idx := (id % count)
		spawn_pos = spawn_points.get_child(point_idx).global_position

	player_inst.global_position = spawn_pos
	return player_inst
