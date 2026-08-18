class_name LANDiscoveryManager
extends Node

## LAN & Radmin VPN UDP Discovery & Room Code Broadcast System:
## - Broadcasts active hosted rooms on UDP port 8911
## - Discovers live local/Radmin servers automatically without manual IP typing
## - Generates easy 4-character Room Codes (e.g. "TF-7482")

signal room_discovered(room_data: Dictionary)
signal room_list_updated(rooms: Array[Dictionary])

const BROADCAST_PORT: int = 8911
const BROADCAST_INTERVAL: float = 1.0
const ROOM_TIMEOUT: float = 3.5

var _broadcast_peer: PacketPeerUDP = null
var _listen_peer: PacketPeerUDP = null

var is_broadcasting: bool = false
var is_listening: bool = false
var _broadcast_timer: float = 0.0

var active_rooms: Dictionary = {} # room_code -> Dictionary
var current_host_room_data: Dictionary = {}

func _ready() -> void:
	_setup_listener()

func _process(delta: float) -> void:
	# Broadcast if hosting
	if is_broadcasting and _broadcast_peer:
		_broadcast_timer += delta
		if _broadcast_timer >= BROADCAST_INTERVAL:
			_broadcast_timer = 0.0
			_send_broadcast_packet()

	# Listen for broadcasts if searching
	if is_listening and _listen_peer:
		_poll_incoming_packets()

	# Cleanup expired rooms
	_cleanup_expired_rooms(delta)

func _setup_listener() -> void:
	_listen_peer = PacketPeerUDP.new()
	_listen_peer.set_broadcast_enabled(true)
	var err := _listen_peer.bind(BROADCAST_PORT)
	if err == OK:
		is_listening = true
		print("📡 LAN Discovery: Listening on port %d" % BROADCAST_PORT)
	else:
		push_warning("⚠️ LAN Discovery: Failed to bind listen port %d (Code %d)" % [BROADCAST_PORT, err])

func start_broadcasting(room_name: String, room_code: String, port: int, current_players: int = 1, max_players: int = 2) -> void:
	if not _broadcast_peer:
		_broadcast_peer = PacketPeerUDP.new()
		_broadcast_peer.set_broadcast_enabled(true)

	var ip_to_share: String = NetworkManager.get_local_ip_address() if NetworkManager else "127.0.0.1"

	current_host_room_data = {
		"name": room_name,
		"code": room_code,
		"ip": ip_to_share,
		"port": port,
		"players": current_players,
		"max_players": max_players,
		"game": "ThinAndFat",
		"timestamp": Time.get_unix_time_from_system()
	}

	is_broadcasting = true
	_send_broadcast_packet()
	print("📢 LAN Discovery: Started broadcasting room '%s' (%s)" % [room_name, room_code])

func stop_broadcasting() -> void:
	is_broadcasting = false
	current_host_room_data.clear()

func _send_broadcast_packet() -> void:
	if not _broadcast_peer or current_host_room_data.is_empty():
		return

	var json_str := JSON.stringify(current_host_room_data)
	var bytes := json_str.to_utf8_buffer()

	# Broadcast to local subnet and Radmin 255.255.255.255
	_broadcast_peer.set_dest_address("255.255.255.255", BROADCAST_PORT)
	_broadcast_peer.put_packet(bytes)

func _poll_incoming_packets() -> void:
	if not _listen_peer:
		return

	while _listen_peer.get_available_packet_count() > 0:
		var packet := _listen_peer.get_packet()
		var sender_ip := _listen_peer.get_packet_ip()
		var json_str := packet.get_string_from_utf8()

		var test_json := JSON.new()
		if test_json.parse(json_str) == OK:
			var data: Dictionary = test_json.data
			if data.has("game") and data["game"] == "ThinAndFat":
				data["sender_ip"] = sender_ip
				if data.get("ip") == "127.0.0.1" or data.get("ip") == "":
					data["ip"] = sender_ip
				data["last_seen"] = Time.get_unix_time_from_system()

				var code: String = String(data.get("code", sender_ip))
				active_rooms[code] = data
				room_discovered.emit(data)
				_emit_room_list()

func _cleanup_expired_rooms(_delta: float) -> void:
	var now := Time.get_unix_time_from_system()
	var to_remove: Array[String] = []
	for code in active_rooms.keys():
		var room: Dictionary = active_rooms[code]
		if now - float(room.get("last_seen", 0.0)) > ROOM_TIMEOUT:
			to_remove.append(code)

	if to_remove.size() > 0:
		for code in to_remove:
			active_rooms.erase(code)
		_emit_room_list()

func _emit_room_list() -> void:
	var list: Array[Dictionary] = []
	for room in active_rooms.values():
		list.append(room)
	room_list_updated.emit(list)

static func generate_room_code() -> String:
	var chars := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var code := "TF-"
	for i in range(4):
		code += chars[randi() % chars.length()]
	return code
