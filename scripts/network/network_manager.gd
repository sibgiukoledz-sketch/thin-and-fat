extends Node

## Autoload NetworkManager handling ENet multiplayer hosting, joining, character selection in lobby, and match launching.

signal connection_status_changed(status: String)
signal player_list_changed(players: Dictionary)
signal character_choices_updated

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
	var is_in_session := (multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED)
	if is_in_session and not multiplayer.is_server():
		print("ℹ️ Client cannot change character choices. Only Host has authority!")
		return

	local_character_id = character_id.to_lower()
	var host_id := multiplayer.get_unique_id() if is_in_session else 1
	player_character_choices[host_id] = local_character_id
	player_character_choices[1] = local_character_id

	# Assign opposite character to client automatically
	if is_in_session and multiplayer.is_server():
		var opposite := "thin" if local_character_id == "fat" else "fat"
		for peer_id in connected_players:
			if peer_id != host_id and peer_id != 1:
				player_character_choices[peer_id] = opposite
				rpc_sync_player_choice.rpc(peer_id, opposite)
		rpc_sync_player_choice.rpc(host_id, local_character_id)

	character_choices_updated.emit()

# RPC to sync chosen character to host & peers - Host Authority Enforced
@rpc("any_peer", "call_local", "reliable")
func rpc_send_character_choice(character_id: String) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = multiplayer.get_unique_id()

	# Only allow Server / Host to dictate character selection!
	if multiplayer.multiplayer_peer != null and not multiplayer.is_server():
		print("⚠️ Client choice ignored. Host dictates character roles!")
		return

	var chosen := character_id.to_lower()
	local_character_id = chosen
	player_character_choices[1] = chosen

	var opposite := "thin" if chosen == "fat" else "fat"
	for peer_id in connected_players:
		if peer_id != 1:
			player_character_choices[peer_id] = opposite
			rpc_sync_player_choice.rpc(peer_id, opposite)

	rpc_sync_player_choice.rpc(1, chosen)
	character_choices_updated.emit()
	player_list_changed.emit(connected_players)

func get_character_for_peer(peer_id: int) -> String:
	if player_character_choices.has(peer_id):
		return player_character_choices[peer_id]
	return local_character_id

func get_spawn_position_for_peer(peer_id: int) -> Vector3:
	var world_node := get_tree().root.get_node_or_null("World")
	if world_node and world_node.has_node("SpawnPoints"):
		var spawn_points: Node = world_node.get_node("SpawnPoints")
		var idx := 0 if (peer_id == 1 or (multiplayer and peer_id == multiplayer.get_unique_id())) else 1
		if spawn_points.get_child_count() > idx:
			var sp: Node3D = spawn_points.get_child(idx) as Node3D
			if sp:
				return sp.global_position

	if peer_id == 1:
		return Vector3(-2.0, 1.5, 0.0)
	else:
		return Vector3(2.0, 1.5, 0.0)

func get_radmin_ip() -> String:
	var ip_list := IP.get_local_addresses()
	for ip in ip_list:
		if ip.begins_with("26.") and not ":" in ip:
			return ip
	return ""

func get_local_ip_address() -> String:
	var radmin := get_radmin_ip()
	if radmin != "":
		return radmin

	var ip_list := IP.get_local_addresses()
	for ip in ip_list:
		if ip.begins_with("192.168.") or ip.begins_with("10.") or (ip.begins_with("172.") and not ip.begins_with("127.")):
			return ip
	for ip in ip_list:
		if not ip.begins_with("127.") and not ":" in ip:
			return ip
	return "127.0.0.1"

func host_game(port: int = DEFAULT_PORT) -> Error:
	current_port = port
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(current_port, MAX_CLIENTS)
	if err != OK:
		connection_status_changed.emit("❌ Ошибка создания сервера! Код: %d" % err)
		return err

	multiplayer.multiplayer_peer = peer
	connected_players.clear()

	# Register host choice
	var my_id := multiplayer.get_unique_id()
	player_character_choices[my_id] = local_character_id
	player_character_choices[1] = local_character_id
	_register_player(my_id, "Хост")

	var radmin := get_radmin_ip()
	var best_ip := get_local_ip_address()
	if radmin != "":
		connection_status_changed.emit("🌐 Radmin VPN Хост запущен! Ваш IP: %s:%d" % [radmin, current_port])
	else:
		connection_status_changed.emit("✅ Сервер запущен! IP: %s:%d" % [best_ip, current_port])

	return OK

func join_game(ip: String = "127.0.0.1", port: int = DEFAULT_PORT) -> Error:
	current_ip = ip
	current_port = port
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(current_ip, current_port)
	if err != OK:
		connection_status_changed.emit("❌ Ошибка подключения к %s:%d! Код: %d" % [current_ip, current_port, err])
		return err

	multiplayer.multiplayer_peer = peer
	connection_status_changed.emit("⏳ Подключение к %s:%d..." % [current_ip, current_port])
	return OK

func start_game_match() -> void:
	if multiplayer.is_server():
		rpc_load_match.rpc()

@rpc("call_local", "reliable")
func rpc_load_match() -> void:
	get_tree().change_scene_to_file("res://scenes/world.tscn")

func disconnect_game() -> void:
	if peer:
		peer.close()
		multiplayer.multiplayer_peer = null
	connected_players.clear()
	player_character_choices.clear()
	connection_status_changed.emit("Disconnected")



@rpc("authority", "call_local", "reliable")
func rpc_sync_player_choice(peer_id: int, character_id: String) -> void:
	player_character_choices[peer_id] = character_id.to_lower()
	var my_id := multiplayer.get_unique_id() if (multiplayer and multiplayer.multiplayer_peer) else 1
	if peer_id == my_id or (peer_id == 1 and multiplayer.is_server()):
		local_character_id = character_id.to_lower()
	character_choices_updated.emit()
	player_list_changed.emit(connected_players)

# Signal Handlers
func _on_peer_connected(id: int) -> void:
	print("Peer connected with ID: ", id)
	if multiplayer.is_server():
		_register_player(id, "Игрок_%d" % id)
		# Assign default opposite character to new peer if host is fat -> peer is thin, and vice versa!
		var host_char: String = player_character_choices.get(1, local_character_id)
		var peer_default_char := "thin" if host_char == "fat" else "fat"
		player_character_choices[id] = peer_default_char

		for p_id in player_character_choices:
			rpc_sync_player_choice.rpc(p_id, player_character_choices[p_id])

@rpc("authority", "call_local", "reliable")
func rpc_sync_connected_players(players_dict: Dictionary) -> void:
	connected_players = players_dict
	player_list_changed.emit(connected_players)

func _on_peer_disconnected(id: int) -> void:
	print("Peer disconnected with ID: ", id)
	if connected_players.has(id):
		connected_players.erase(id)
		if multiplayer.is_server():
			rpc_sync_connected_players.rpc(connected_players)
		else:
			player_list_changed.emit(connected_players)

	if player_character_choices.has(id):
		player_character_choices.erase(id)
		character_choices_updated.emit()

	var players_container := get_tree().root.get_node_or_null("World/Players")
	if players_container and players_container.has_node(str(id)):
		var player_node := players_container.get_node(str(id))
		player_node.queue_free()

func _on_connected_to_server() -> void:
	var my_id := multiplayer.get_unique_id()
	connection_status_changed.emit("Вы в комнате (Client ID: %d)" % my_id)
	rpc_send_character_choice.rpc(local_character_id)

func _on_connection_failed() -> void:
	connection_status_changed.emit("Ошибка подключения!")
	multiplayer.multiplayer_peer = null

func _on_server_disconnected() -> void:
	connection_status_changed.emit("Сервер отключился!")
	disconnect_game()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _register_player(id: int, player_name: String) -> void:
	connected_players[id] = {
		"id": id,
		"name": player_name,
		"score": 0
	}
	if multiplayer.is_server():
		rpc_sync_connected_players.rpc(connected_players)
	else:
		player_list_changed.emit(connected_players)
