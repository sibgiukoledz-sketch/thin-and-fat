class_name HeavyBoulder
extends RigidBody3D

## Giant Rugged Boulder with native Godot 3D Rigid Body physics.
## Features 512x512 AAA procedural multi-layer granite textures, normal map displacement,
## non-uniform roughness, and top-level world-space detailed micro-particle systems (Dust, Shards, Shockwave, Friction Sparks).

signal boulder_picked_up(by_player: Node3D)
signal boulder_thrown(by_player: Node3D)
signal boulder_impact(position: Vector3)

@export var damage_on_impact: float = 75.0
@export var impact_radius: float = 5.5
@export var throw_force: float = 18.5

@onready var prompt_label: Label3D = $PromptLabel3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var interaction_area: Area3D = $InteractionArea

var _is_carried: bool = false
var _carrier_player: CharacterBody3D = null

# 4-Tier AAA VFX Nodes (Top-level World Space)
var _vfx_dict: Dictionary = {}

var _warning_timer: float = 0.0
var _warning_text: String = ""
var _last_impact_time: float = 0.0

func _enter_tree() -> void:
	set_multiplayer_authority(1)

func _ready() -> void:
	collision_layer = 4
	collision_mask = 7
	mass = 450.0
	linear_damp = 0.4
	angular_damp = 0.5
	freeze = false
	contact_monitor = true
	max_contacts_reported = 8

	if interaction_area:
		interaction_area.body_entered.connect(_on_interaction_body_entered)
	body_entered.connect(_on_physics_body_entered)

	_setup_boulder_visuals()
	_vfx_dict = BoulderVFXBuilder.build_impact_vfx(self)
	_update_prompt()

func _physics_process(delta: float) -> void:
	if _is_carried:
		return

	var space_state := get_world_3d().direct_space_state
	if not space_state:
		return

	var shape := SphereShape3D.new()
	shape.radius = 3.2
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
		sphere.radius = 1.8
		sphere.height = 3.4
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
		caps.radius = 1.8
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
		prompt_label.text = "🪨 ВАЛУН (В РУКАХ)\n[E] - БРОСИТЬ ВАЛУН"
		prompt_label.modulate = Color(1.0, 0.85, 0.2)
	else:
		prompt_label.text = "🪨 ГРОМАДНЫЙ ВАЛУН (450 КГ)\n[E] - ПОДНЯТЬ (ТОЛЬКО ЖИРДЯЙ)"
		prompt_label.modulate = Color(0.9, 0.9, 0.9)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		if _is_carried and _carrier_player and _carrier_player.is_multiplayer_authority():
			try_interact_boulder(_carrier_player)
			return

		if interaction_area:
			for body in interaction_area.get_overlapping_bodies():
				if body is Player:
					var p: Player = body as Player
					if p.is_multiplayer_authority():
						try_interact_boulder(p)
						break

func _on_interaction_body_entered(body: Node) -> void:
	if body.has_method("is_multiplayer_authority"):
		var p: CharacterBody3D = body as CharacterBody3D
		if p.is_multiplayer_authority() and Input.is_action_just_pressed("interact"):
			try_interact_boulder(p)

func try_interact_boulder(player: CharacterBody3D) -> void:
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
	freeze = true

	# Disable boulder collision shape while carried so Fat does NOT levitate or collide with boulder!
	if collision_shape:
		collision_shape.disabled = true
	if interaction_area:
		interaction_area.monitoring = false

	reparent(player_node)
	# Position boulder in front of Fat's chest & arms (not floating high in the sky!)
	position = Vector3(0.0, 1.25, -1.55)
	rotation = Vector3.ZERO

	if prompt_label:
		prompt_label.position = Vector3(0, 2.1, 0)

	boulder_picked_up.emit(player_node)
	if AudioManager:
		AudioManager.play_sfx_3d("heavy_lift", global_position)
	print("🪨 BOULDER PICKED UP by %s" % player_node.name)

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

	# Re-enable collision shape for dynamic physics simulation & impact
	if collision_shape:
		collision_shape.disabled = false
	if interaction_area:
		interaction_area.monitoring = true

	freeze = false
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
				var vel := linear_velocity.length()
				if vel > 0.8:
					if p.has_method("apply_paper_flatten"):
						p.call("apply_paper_flatten", 10.0)
					if AudioManager:
						AudioManager.play_sfx_3d("boulder_impact", global_position)
					print("💥 BOULDER ROLLED OVER THIN PLAYER AND FLATTENED HIM!")
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _last_impact_time < 0.20:
		return
	_last_impact_time = now

	var impact_vel := linear_velocity.length()
	if impact_vel > 2.5:
		BoulderVFXBuilder.trigger_impact_vfx(_vfx_dict, global_position)
		if AudioManager:
			AudioManager.play_sfx_3d("boulder_impact", global_position)
		boulder_impact.emit(global_position)

		if impact_vel > 6.0:
			_apply_area_crush_damage()

func _apply_area_crush_damage() -> void:
	var space_state := get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = impact_radius

	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = global_transform
	query.collision_mask = 3

	var results := space_state.intersect_shape(query)
	for res in results:
		var collider: Object = res.collider
		if collider and collider is CharacterBody3D and collider.has_method("is_multiplayer_authority") and collider != _carrier_player:
			var p: CharacterBody3D = collider as CharacterBody3D
			if p:
				var char_id: String = String(p.get("selected_character_id"))
				if char_id.to_lower() == "thin":
					if p.has_method("apply_paper_flatten"):
						p.call("apply_paper_flatten", 10.0)
					print("💥 BOULDER CRUSHED THIN PLAYER INTO PAPER!")
				else:
					if p.has_method("take_damage"):
						p.call("take_damage", damage_on_impact, global_position)

func _show_warning(msg: String) -> void:
	_warning_text = msg
	_warning_timer = 2.5
