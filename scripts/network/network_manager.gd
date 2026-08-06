extends Node

## Autoload NetworkManager handling ENet multiplayer hosting, joining, and player character selection.

signal connection_status_changed(status: String)
signal player_list_changed(players: Dictionary)

const DEFAULT_PORT: int = 8910
const MAX_CLIENTS: int = 8

var peer: ENetMultiplayerPeer
var connected_players: Dictionary = {} # peer_id -> Player Info dict
var player_character_choices: Dictionary = {} # peer_id -> character_id ("thin" / "fat")

var local_character_id: String = "fat"
var current_ip: String = "127.0.0.1"
var current_port: int = DEFAULT_PORT

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func set_local_character(character_id: String) -> void:
	local_character_id = character_id

func get_character_for_peer(peer_id: int) -> String:
	return player_character_choices.get(peer_id, "thin")

func host_game(port: int = DEFAULT_PORT) -> Error:
	current_port = port
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(current_port, MAX_CLIENTS)
	if err != OK:
		connection_status_changed.emit("Failed to host server! Error code: %d" % err)
		return err

	multiplayer.multiplayer_peer = peer
	connected_players.clear()
	player_character_choices.clear()

	# Register host choice
	player_character_choices[1] = local_character_id
	_register_player(1, "Host Player")
	connection_status_changed.emit("Hosting server on port %d" % current_port)
	
	load_game_world()
	return OK

func join_game(ip: String = "127.0.0.1", port: int = DEFAULT_PORT) -> Error:
	current_ip = ip
	current_port = port
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(current_ip, current_port)
	if err != OK:
		connection_status_changed.emit("Failed to connect to %s:%d" % [current_ip, current_port])
		return err

	multiplayer.multiplayer_peer = peer
	connection_status_changed.emit("Connecting to %s:%d..." % [current_ip, current_port])
	return OK

func disconnect_game() -> void:
	if peer:
		peer.close()
		multiplayer.multiplayer_peer = null
	connected_players.clear()
	player_character_choices.clear()
	connection_status_changed.emit("Disconnected")
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func load_game_world() -> void:
	get_tree().change_scene_to_file("res://scenes/world.tscn")

# RPC to sync chosen character to host & peers
@rpc("any_peer", "call_local", "reliable")
func rpc_send_character_choice(character_id: String) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = multiplayer.get_unique_id()
	player_character_choices[sender_id] = character_id

# Signal Handlers
func _on_peer_connected(id: int) -> void:
	print("Peer connected with ID: ", id)
	if multiplayer.is_server():
		_register_player(id, "Player_%d" % id)

func _on_peer_disconnected(id: int) -> void:
	print("Peer disconnected with ID: ", id)
	if connected_players.has(id):
		connected_players.erase(id)
		player_list_changed.emit(connected_players)
	if player_character_choices.has(id):
		player_character_choices.erase(id)

	var players_container := get_tree().root.get_node_or_null("World/Players")
	if players_container and players_container.has_node(str(id)):
		var player_node := players_container.get_node(str(id))
		player_node.queue_free()

func _on_connected_to_server() -> void:
	var my_id := multiplayer.get_unique_id()
	connection_status_changed.emit("Connected as Client ID: %d" % my_id)
	rpc_send_character_choice.rpc(local_character_id)
	load_game_world()

func _on_connection_failed() -> void:
	connection_status_changed.emit("Connection failed!")
	multiplayer.multiplayer_peer = null

func _on_server_disconnected() -> void:
	connection_status_changed.emit("Server disconnected!")
	disconnect_game()

func _register_player(id: int, player_name: String) -> void:
	connected_players[id] = {
		"id": id,
		"name": player_name,
		"score": 0
	}
	player_list_changed.emit(connected_players)
