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
@export var throw_force: float = 11.5

@onready var prompt_label: Label3D = $PromptLabel3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var interaction_area: Area3D = $InteractionArea

var _is_carried: bool = false
var _carrier_player: Player = null
var _is_crushing: bool = false

# Lifting Interpolation
var _lift_progress: float = 1.0
var _lift_start_pos: Vector3 = Vector3.ZERO

# 4-Tier AAA VFX Nodes (Top-level World Space)
var _dust_particles: GPUParticles3D
var _debris_particles: GPUParticles3D
var _shockwave_particles: GPUParticles3D
var _spark_particles: GPUParticles3D

var _warning_timer: float = 0.0
var _warning_text: String = ""
var _last_impact_time: float = 0.0

func _ready() -> void:
	if interaction_area:
		interaction_area.body_entered.connect(_on_interaction_body_entered)
	body_entered.connect(_on_physics_body_entered)

	_setup_boulder_visuals()
	_setup_impact_vfx()
	_update_prompt()

func _setup_boulder_visuals() -> void:
	if mesh_instance:
		var sphere: SphereMesh = SphereMesh.new()
		sphere.radius = 1.8
		sphere.height = 3.4
		sphere.radial_segments = 32
		sphere.rings = 24

		var textures: Array[ImageTexture] = _generate_high_detail_rock_textures()
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

func _generate_high_detail_rock_textures() -> Array[ImageTexture]:
	var width: int = 512
	var height: int = 512
	var albedo_img: Image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	var normal_img: Image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	var rough_img: Image = Image.create(width, height, false, Image.FORMAT_RGBA8)

	var noise_base: FastNoiseLite = FastNoiseLite.new()
	noise_base.seed = 12345
	noise_base.noise_type = FastNoiseLite.TYPE_PERLIN
	noise_base.frequency = 0.02
	noise_base.fractal_octaves = 6

	var noise_cracks: FastNoiseLite = FastNoiseLite.new()
	noise_cracks.seed = 99999
	noise_cracks.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise_cracks.frequency = 0.06

	var noise_lichen: FastNoiseLite = FastNoiseLite.new()
	noise_lichen.seed = 77777
	noise_lichen.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise_lichen.frequency = 0.09

	for y in range(height):
		for x in range(width):
			var fx: float = float(x)
			var fy: float = float(y)

			var n_base: float = (noise_base.get_noise_2d(fx, fy) + 1.0) * 0.5
			var n_crack: float = (noise_cracks.get_noise_2d(fx, fy) + 1.0) * 0.5
			var n_lichen: float = (noise_lichen.get_noise_2d(fx, fy) + 1.0) * 0.5

			var granite_col: Color = Color(0.20, 0.18, 0.16, 1.0).lerp(Color(0.55, 0.50, 0.42, 1.0), n_base)
			if n_crack < 0.35:
				var crack_factor: float = smoothstep(0.35, 0.1, n_crack)
				granite_col = granite_col.lerp(Color(0.12, 0.09, 0.07, 1.0), crack_factor * 0.85)
			if n_lichen > 0.62:
				var moss_factor: float = smoothstep(0.62, 0.85, n_lichen)
				granite_col = granite_col.lerp(Color(0.32, 0.38, 0.22, 1.0), moss_factor * 0.7)

			albedo_img.set_pixel(x, y, granite_col)

			var nx: float = (noise_base.get_noise_2d(fx + 1.0, fy) - noise_base.get_noise_2d(fx - 1.0, fy)) * 6.0
			var ny: float = (noise_base.get_noise_2d(fx, fy + 1.0) - noise_base.get_noise_2d(fx, fy - 1.0)) * 6.0
			var normal_vec: Vector3 = Vector3(-nx, -ny, 1.0).normalized()
			var norm_col: Color = Color(normal_vec.x * 0.5 + 0.5, normal_vec.y * 0.5 + 0.5, normal_vec.z * 0.5 + 0.5, 1.0)
			normal_img.set_pixel(x, y, norm_col)

			var rough_val: float = clampf(0.85 + (n_base - 0.5) * 0.3 - (n_lichen * 0.25), 0.35, 0.98)
			rough_img.set_pixel(x, y, Color(rough_val, rough_val, rough_val, 1.0))

	var albedo_tex: ImageTexture = ImageTexture.create_from_image(albedo_img)
	var normal_tex: ImageTexture = ImageTexture.create_from_image(normal_img)
	var rough_tex: ImageTexture = ImageTexture.create_from_image(rough_img)
	return [albedo_tex, normal_tex, rough_tex]

func _setup_impact_vfx() -> void:
	# === 1. FINE DUST PLUME CLOUD (High-density micro dust particles) ===
	_dust_particles = GPUParticles3D.new()
	_dust_particles.name = "VFX_DustPlume"
	_dust_particles.top_level = true # Stay pinned in global world space!
	_dust_particles.amount = 140
	_dust_particles.lifetime = 1.4
	_dust_particles.one_shot = true
	_dust_particles.explosiveness = 0.94
	_dust_particles.emitting = false

	var mat_proc: ParticleProcessMaterial = ParticleProcessMaterial.new()
	mat_proc.direction = Vector3(0, 1, 0)
	mat_proc.spread = 85.0
	mat_proc.initial_velocity_min = 4.0
	mat_proc.initial_velocity_max = 9.5
	mat_proc.gravity = Vector3(0, -2.5, 0)
	mat_proc.damping_min = 1.0
	mat_proc.damping_max = 3.0
	mat_proc.scale_min = 0.08
	mat_proc.scale_max = 0.25
	mat_proc.color = Color(0.55, 0.48, 0.40, 0.65)

	var draw_mat: StandardMaterial3D = StandardMaterial3D.new()
	draw_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.albedo_color = Color(0.55, 0.48, 0.40, 0.55)
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.proximity_fade_enabled = true
	draw_mat.proximity_fade_distance = 0.3

	var sphere: SphereMesh = SphereMesh.new()
	sphere.material = draw_mat
	sphere.radius = 0.08
	sphere.height = 0.16

	_dust_particles.process_material = mat_proc
	_dust_particles.draw_pass_1 = sphere
	add_child(_dust_particles)

	# === 2. DETAILED MICRO ROCK SHARDS (Sharp stone splinters) ===
	_debris_particles = GPUParticles3D.new()
	_debris_particles.name = "VFX_RockShards"
	_debris_particles.top_level = true # Stay pinned in global world space!
	_debris_particles.amount = 90
	_debris_particles.lifetime = 1.2
	_debris_particles.one_shot = true
	_debris_particles.explosiveness = 0.98
	_debris_particles.emitting = false

	var dmat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	dmat.direction = Vector3(0, 1, 0)
	dmat.spread = 75.0
	dmat.initial_velocity_min = 6.0
	dmat.initial_velocity_max = 14.0
	dmat.gravity = Vector3(0, -20.0, 0)
	dmat.scale_min = 0.04
	dmat.scale_max = 0.12
	dmat.color = Color(0.32, 0.28, 0.24, 1.0)

	var dmesh: PrismMesh = PrismMesh.new()
	var ddraw: StandardMaterial3D = StandardMaterial3D.new()
	ddraw.albedo_color = Color(0.32, 0.28, 0.24, 1.0)
	ddraw.roughness = 0.95
	dmesh.material = ddraw
	dmesh.size = Vector3(0.06, 0.06, 0.06)

	_debris_particles.process_material = dmat
	_debris_particles.draw_pass_1 = dmesh
	add_child(_debris_particles)

	# === 3. EXPANDING HORIZONTAL SHOCKWAVE RING ===
	_shockwave_particles = GPUParticles3D.new()
	_shockwave_particles.name = "VFX_ShockwaveRing"
	_shockwave_particles.top_level = true
	_shockwave_particles.amount = 30
	_shockwave_particles.lifetime = 0.6
	_shockwave_particles.one_shot = true
	_shockwave_particles.explosiveness = 0.95
	_shockwave_particles.emitting = false

	var smat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	smat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	smat.emission_ring_radius = 1.2
	smat.emission_ring_inner_radius = 0.3
	smat.emission_ring_axis = Vector3(0, 1, 0)
	smat.direction = Vector3(0, 0, 0)
	smat.spread = 180.0
	smat.initial_velocity_min = 8.0
	smat.initial_velocity_max = 16.0
	smat.gravity = Vector3(0, -1.0, 0)
	smat.scale_min = 0.06
	smat.scale_max = 0.18
	smat.color = Color(0.65, 0.58, 0.48, 0.7)

	var sw_draw: StandardMaterial3D = StandardMaterial3D.new()
	sw_draw.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	sw_draw.albedo_color = Color(0.65, 0.58, 0.48, 0.6)
	sw_draw.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var sw_mesh: QuadMesh = QuadMesh.new()
	sw_mesh.material = sw_draw
	sw_mesh.size = Vector2(0.15, 0.15)

	_shockwave_particles.process_material = smat
	_shockwave_particles.draw_pass_1 = sw_mesh
	add_child(_shockwave_particles)

	# === 4. FRICTION SPARKS (Glowing orange mineral spark droplets) ===
	_spark_particles = GPUParticles3D.new()
	_spark_particles.name = "VFX_FrictionSparks"
	_spark_particles.top_level = true
	_spark_particles.amount = 50
	_spark_particles.lifetime = 0.5
	_spark_particles.one_shot = true
	_spark_particles.explosiveness = 0.99
	_spark_particles.emitting = false

	var spmat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	spmat.direction = Vector3(0, 1, 0)
	spmat.spread = 90.0
	spmat.initial_velocity_min = 8.0
	spmat.initial_velocity_max = 16.0
	spmat.gravity = Vector3(0, -16.0, 0)
	spmat.scale_min = 0.01
	spmat.scale_max = 0.03
	spmat.color = Color(1.0, 0.7, 0.2, 1.0)

	var spdraw: StandardMaterial3D = StandardMaterial3D.new()
	spdraw.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	spdraw.albedo_color = Color(1.0, 0.75, 0.25, 1.0)

	var spmesh: SphereMesh = SphereMesh.new()
	spmesh.material = spdraw
	spmesh.radius = 0.015
	spmesh.height = 0.03

	_spark_particles.process_material = spmat
	_spark_particles.draw_pass_1 = spmesh
	add_child(_spark_particles)

func _trigger_all_impact_vfx(at_position: Vector3) -> void:
	if _dust_particles:
		_dust_particles.global_position = at_position
		_dust_particles.restart()
		_dust_particles.emitting = true
	if _debris_particles:
		_debris_particles.global_position = at_position
		_debris_particles.restart()
		_debris_particles.emitting = true
	if _shockwave_particles:
		_shockwave_particles.global_position = at_position
		_shockwave_particles.restart()
		_shockwave_particles.emitting = true
	if _spark_particles:
		_spark_particles.global_position = at_position
		_spark_particles.restart()
		_spark_particles.emitting = true

	var root: Node = get_tree().root
	_break_nearby_glass_recursive(root, at_position, 6.5)

func _break_nearby_glass_recursive(node: Node, center: Vector3, radius: float) -> void:
	if not node:
		return
	if node is FragileGlassFloor:
		var glass: FragileGlassFloor = node as FragileGlassFloor
		if glass.global_position.distance_to(center) <= radius:
			glass.trigger_seismic_break()
	for child in node.get_children():
		_break_nearby_glass_recursive(child, center, radius)


func _update_prompt() -> void:
	if not prompt_label:
		return

	if _warning_timer > 0.0:
		prompt_label.text = _warning_text
		prompt_label.modulate = Color(1.0, 0.2, 0.2)
	elif _is_carried:
		prompt_label.text = "🪨 ГИГАНТСКИЙ ВАЛУН В РУКАХ ЖИРДЯЯ!\n[E] / [ЛКМ] — БРОСИТЬ ВАЛУН!"
		prompt_label.modulate = Color(1.0, 0.85, 0.2)
	else:
		prompt_label.text = "🪨 ГИГАНТСКИЙ ТЯЖЁЛЫЙ ВАЛУН\n[E] — Поднять (Только для Жирдяя)"
		prompt_label.modulate = Color(1.0, 1.0, 1.0)

func _process(delta: float) -> void:
	if _warning_timer > 0.0:
		_warning_timer -= delta
		if _warning_timer <= 0.0:
			_update_prompt()

	# Handling smooth physical carrying position above Fat player's head
	if _is_carried and is_instance_valid(_carrier_player):
		var target_pos: Vector3 = _carrier_player.global_position + Vector3(0, 3.2, 0)

		if _lift_progress < 1.0:
			_lift_progress = minf(_lift_progress + delta * 1.8, 1.0)
			var ease_p: float = 1.0 - pow(1.0 - _lift_progress, 3.0)
			global_position = _lift_start_pos.lerp(target_pos, ease_p)
		else:
			global_position = global_position.lerp(target_pos, 18.0 * delta)

		rotation = _carrier_player.rotation

func _unhandled_input(event: InputEvent) -> void:
	var is_interact_pressed: bool = event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E)
	var is_lmb_pressed: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)

	# Case 1: Fat player is carrying boulder -> THROW IT!
	if _is_carried and _carrier_player and _carrier_player.is_multiplayer_authority():
		if is_interact_pressed or is_lmb_pressed:
			get_viewport().set_input_as_handled()
			var throw_dir: Vector3 = -_carrier_player.global_transform.basis.z
			if _carrier_player.camera_3d:
				throw_dir = -_carrier_player.camera_3d.global_transform.basis.z
			
			throw_dir = (throw_dir + Vector3(0, 0.30, 0)).normalized()
			rpc_throw_boulder.rpc(_carrier_player.global_position + Vector3(0, 2.5, 0), throw_dir * throw_force)
			return

	# Case 2: Player is standing near boulder and tries to pick it up
	if not _is_carried and not _is_crushing and is_interact_pressed and interaction_area:
		var bodies: Array[Node3D] = interaction_area.get_overlapping_bodies()
		for body in bodies:
			if body is Player and (body as Player).is_multiplayer_authority():
				var player_node: Player = body as Player
				_attempt_pick_up(player_node)
				get_viewport().set_input_as_handled()
				break

func _attempt_pick_up(player_node: Player) -> void:
	if player_node.selected_character_id.to_lower() != "fat":
		rpc_crush_player.rpc(player_node.get_path())
		print("💥 THIN PLAYER SQUASHED BY BOULDER!")
		return

	rpc_pick_up_boulder.rpc(player_node.get_path())

func _show_warning(msg: String) -> void:
	_warning_text = msg
	_warning_timer = 3.0
	_update_prompt()

@rpc("any_peer", "call_local", "reliable")
func rpc_crush_player(player_path: NodePath) -> void:
	var p: Player = get_node_or_null(player_path) as Player
	if not p:
		return

	_is_crushing = true
	freeze = true
	_show_warning("💥 СЛИШКОМ ТЯЖЁЛЫЙ ВАЛУН!\nТонкого раздавило в лепёшку!")

	# Trigger full 4-tier impact VFX
	_trigger_all_impact_vfx(p.global_position)

	# Tilt physical boulder over onto Thin player
	var tween: Tween = create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", p.global_position + Vector3(0, 0.8, 0), 0.4)

	# Deal lethal crushing physical HP damage
	p.take_damage(150.0, p.global_position)

	get_tree().create_timer(1.2).timeout.connect(func():
		freeze = false
		_is_crushing = false
	)

@rpc("any_peer", "call_local", "reliable")
func rpc_pick_up_boulder(player_path: NodePath) -> void:
	var p: Player = get_node_or_null(player_path) as Player
	if not p:
		return

	_is_carried = true
	_carrier_player = p
	p.is_carrying_heavy_object = true
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO

	_lift_progress = 0.0
	_lift_start_pos = global_position
	_update_prompt()

	if p.is_multiplayer_authority() and p.camera_3d:
		p.camera_3d.rotation.z = deg_to_rad(8.0)

	if _dust_particles:
		_dust_particles.global_position = p.global_position
		_dust_particles.restart()
		_dust_particles.emitting = true

	boulder_picked_up.emit(p)
	print("🪨 REALISTIC HEAVY LIFT: Boulder lifted by %s!" % p.name)

@rpc("any_peer", "call_local", "reliable")
func rpc_throw_boulder(start_pos: Vector3, initial_velocity: Vector3) -> void:
	global_position = start_pos
	if _carrier_player:
		_carrier_player.is_carrying_heavy_object = false
		boulder_thrown.emit(_carrier_player)
		_carrier_player = null

	_is_carried = false
	freeze = false

	linear_velocity = initial_velocity
	angular_velocity = Vector3(randf_range(-4.0, -7.0), randf_range(-1.5, 1.5), randf_range(-1.5, 1.5))

	_update_prompt()
	print("🪨 REALISTIC HEAVY THROW! Velocity: %s" % str(initial_velocity))

func _on_physics_body_entered(body: Node) -> void:
	if _is_carried:
		return

	var cur_time: float = Time.get_ticks_msec() * 0.001
	if cur_time - _last_impact_time < 0.35:
		return

	var speed: float = linear_velocity.length()
	if speed > 4.2:
		_last_impact_time = cur_time
		var impact_pos: Vector3 = global_position

		# Trigger full 4-tier impact VFX in global world space
		_trigger_all_impact_vfx(impact_pos)

		if body is Node3D and body != self and body != _carrier_player:
			if body.has_method("take_damage"):
				var dmg: float = clampf(speed * 3.5, 25.0, damage_on_impact)
				body.take_damage(dmg, (body as Node3D).global_position)
				print("💥 PHYSICAL BOULDER CRUSH: Dealt %.1f damage to %s" % [dmg, body.name])

		_apply_impact_aoe_damage(impact_pos, speed)
		boulder_impact.emit(impact_pos)

func _apply_impact_aoe_damage(center: Vector3, speed: float) -> void:
	var root: Node = get_tree().root
	_damage_nodes_recursive(root, center, speed)

func _damage_nodes_recursive(node: Node, center: Vector3, speed: float) -> void:
	if not node:
		return

	if node is Node3D and node != self and node != _carrier_player:
		var n3d: Node3D = node as Node3D
		var dist: float = center.distance_to(n3d.global_position)
		if dist <= impact_radius:
			if node.has_method("take_damage"):
				var falloff: float = 1.0 - (dist / impact_radius)
				var final_dmg: float = maxf(damage_on_impact * (speed / 15.0) * falloff, 15.0)
				node.take_damage(final_dmg, n3d.global_position)

	for child in node.get_children():
		_damage_nodes_recursive(child, center, speed)

func _on_interaction_body_entered(body: Node) -> void:
	if not _is_carried and body is Player:
		var p: Player = body as Player
		if p.is_multiplayer_authority() and p.selected_character_id.to_lower() == "fat":
			_update_prompt()
