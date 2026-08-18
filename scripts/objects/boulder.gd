class_name HeavyBoulder
extends RigidBody3D

## Heavy Puzzle Boulder ("Супер-Валун"):
## - Mass: 450 kg (Only "Fat / Жирдяй" can lift and throw it).
## - Overhead carry: lifts high above Fat's head in raised hands.
## - Physics isolation while carried (prevents player repulsion / flying).
## - Puzzle interaction: Acts as a windbreak against Wind Tunnel Fan,
##   triggers Heavy Pressure Buttons, and catapults players on Seesaws.

signal boulder_picked_up(by_player: CharacterBody3D)
signal boulder_thrown(by_player: CharacterBody3D)

@export var throw_force: float = 14.0
@export var min_impact_damage_velocity: float = 4.5

var _is_carried: bool = false
var _carrier_player: CharacterBody3D = null
var _warning_text: String = ""
var _warning_timer: float = 0.0

@onready var collision_shape: CollisionShape3D = get_node_or_null("CollisionShape3D") as CollisionShape3D
@onready var mesh_instance: MeshInstance3D = get_node_or_null("MeshInstance3D") as MeshInstance3D
@onready var interaction_area: Area3D = get_node_or_null("InteractionArea") as Area3D
@onready var prompt_label: Label3D = get_node_or_null("PromptLabel3D") as Label3D

func _ready() -> void:
	max_contacts_reported = 4
	contact_monitor = true
	body_entered.connect(_on_physics_body_entered)

	if interaction_area:
		interaction_area.body_entered.connect(_on_interaction_body_entered)
		interaction_area.body_exited.connect(_on_interaction_body_exited)

	_setup_boulder_visuals()
	_update_prompt()

func _physics_process(delta: float) -> void:
	if _is_carried:
		return

	var space_state := get_world_3d().direct_space_state
	if not space_state:
		return

	var shape := SphereShape3D.new()
	shape.radius = 2.4
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = global_transform
	query.collision_mask = 2

	var results := space_state.intersect_shape(query)
	var thin_touching := false
	for res in results:
		var collider: Object = res.collider
		if collider is Player:
			var p: Player = collider as Player
			if p.selected_character_id.to_lower() == "thin":
				thin_touching = true
				break

	if thin_touching:
		linear_velocity.x = lerpf(linear_velocity.x, 0.0, 25.0 * delta)
		linear_velocity.z = lerpf(linear_velocity.z, 0.0, 25.0 * delta)
		angular_velocity = angular_velocity.lerp(Vector3.ZERO, 30.0 * delta)

func _setup_boulder_visuals() -> void:
	if mesh_instance:
		var sphere: SphereMesh = SphereMesh.new()
		sphere.radius = 1.1
		sphere.height = 2.2
		sphere.radial_segments = 32
		sphere.rings = 24

		var textures: Array[ImageTexture] = BoulderTextureGenerator.generate_rock_textures()
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_texture = textures[0]
		mat.normal_enabled = true
		mat.normal_texture = textures[1]
		mat.normal_scale = 3.5
		mat.roughness_texture = textures[2]
		mat.metallic = 0.08
		mat.uv1_scale = Vector3(2.5, 2.5, 2.5)
		sphere.material = mat

		mesh_instance.mesh = sphere

	if collision_shape and not collision_shape.shape:
		var caps: SphereShape3D = SphereShape3D.new()
		caps.radius = 1.1
		collision_shape.shape = caps

func _process(delta: float) -> void:
	if _warning_timer > 0.0:
		_warning_timer -= delta
		if prompt_label:
			prompt_label.text = _warning_text
			prompt_label.modulate = Color(1.0, 0.25, 0.25)
	else:
		_update_prompt()

func _update_prompt() -> void:
	if not prompt_label:
		return

	if _is_carried:
		prompt_label.text = "🪨 СУПЕР-ВАЛУН\n[E] — Бросить вперёд"
		prompt_label.modulate = Color(0.3, 1.0, 0.4)
	else:
		prompt_label.text = "🪨 СУПЕР-ВАЛУН\n[E] — Поднять (Только для Толстяка)"
		prompt_label.modulate = Color(1.0, 0.9, 0.3)

func _show_warning(text: String, duration: float = 2.5) -> void:
	_warning_text = text
	_warning_timer = duration

func _on_interaction_body_entered(body: Node3D) -> void:
	if body is Player:
		var p: Player = body as Player
		if p.selected_character_id.to_lower() == "thin":
			_show_warning("⚠️ ВАЛУН СЛИШКОМ ТЯЖЕЛЫЙ (450 КГ)!\nНУЖЕН ТОЛСТЯК!", 3.0)

func _on_interaction_body_exited(_body: Node3D) -> void:
	pass

func interact(player: Player) -> void:
	if not player:
		return

	if player.selected_character_id.to_lower() != "fat":
		_show_warning("💥 ВАЛУН СЛИШКОМ ТЯЖЕЛЫЙ! ХУДОГО СПЛЮЩИЛО В БУМАГУ!")
		if AudioManager:
			AudioManager.play_sfx_3d("fail_buzz", global_position)
		player.apply_paper_flatten(10.0)
		return

	if not _is_carried:
		rpc_pickup_boulder.rpc(player.get_path())
	else:
		if _carrier_player == player:
			rpc_throw_boulder.rpc(player.get_path(), player.global_transform.basis.z * -1.0)

@rpc("any_peer", "call_local", "reliable")
func rpc_pickup_boulder(player_path: NodePath) -> void:
	var player_node := get_node_or_null(player_path) as CharacterBody3D
	if not player_node:
		return

	_is_carried = true
	_carrier_player = player_node
	player_node.is_carrying_heavy_object = true

	# Complete physics isolation while carried to prevent physics engine repulsion
	collision_layer = 0
	collision_mask = 0
	freeze = true
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC

	if collision_shape:
		collision_shape.disabled = true
	if interaction_area:
		interaction_area.monitoring = false
		interaction_area.monitorable = false

	reparent(player_node)
	# Position directly overhead at y = 1.60m so rock bottom rests on raised hands above head
	position = Vector3(0.0, 1.60, 0.0)
	rotation = Vector3.ZERO

	if prompt_label:
		prompt_label.position = Vector3(0, 2.6, 0)

	boulder_picked_up.emit(player_node)
	if AudioManager:
		AudioManager.play_sfx_3d("heavy_lift", global_position)
	print("🪨 BOULDER PICKED UP OVERHEAD by %s" % player_node.name)

@rpc("any_peer", "call_local", "reliable")
func rpc_throw_boulder(player_path: NodePath, throw_dir: Vector3) -> void:
	var player_node := get_node_or_null(player_path) as CharacterBody3D
	if not player_node:
		player_node = _carrier_player

	_is_carried = false
	if player_node:
		player_node.is_carrying_heavy_object = false
	_carrier_player = null

	var current_global_pos := global_position
	var main_world := get_tree().current_scene
	reparent(main_world)
	global_position = current_global_pos

	# Re-enable full physics layers & mask for dynamic impact
	collision_layer = 4
	collision_mask = 7
	freeze = false
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC

	if collision_shape:
		collision_shape.disabled = false
	if interaction_area:
		interaction_area.monitoring = true
		interaction_area.monitorable = true

	var impulse_vector := (throw_dir.normalized() + Vector3(0, 0.45, 0)).normalized() * throw_force * mass
	apply_central_impulse(impulse_vector)
	apply_torque_impulse(Vector3(randf_range(-40, 40), randf_range(-40, 40), randf_range(-40, 40)))

	boulder_thrown.emit(player_node)
	if AudioManager:
		AudioManager.play_sfx_3d("boulder_throw", global_position)
	print("🪨 BOULDER THROWN WITH IMPULSE: %s" % str(impulse_vector))

func _on_physics_body_entered(body: Node) -> void:
	if body and body is CharacterBody3D and body.has_method("is_multiplayer_authority"):
		var p: CharacterBody3D = body as CharacterBody3D
		if p:
			var char_id: String = String(p.get("selected_character_id"))
			if char_id.to_lower() == "thin":
				if linear_velocity.length() > min_impact_damage_velocity:
					if p.has_method("apply_paper_flatten"):
						p.call("apply_paper_flatten", 8.0)
					if AudioManager:
						AudioManager.play_sfx_3d("boulder_impact", global_position)
