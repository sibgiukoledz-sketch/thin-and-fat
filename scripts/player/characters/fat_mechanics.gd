class_name FatMechanics
extends BaseCharacterMechanics

## Controller for "Fat / Жирдяй" character mechanics:
## 1. AAA Volumetric Stench & Buzzing Flies System.
## 2. Low Heavy Leap + Seismic Earthquake Landing (Pops Heavy Boulder & physical objects + players).
## 3. Slingshot Launch Shove: Powerful push launching Thin players and Dummy NPCs into the stratosphere!

signal stench_changed(current: float, max_stench: float)

@export var max_stench: float = 100.0
@export var stench_level: float = 0.0

# Balanced Accumulation Rates
@export var stench_walk_rate: float = 0.6
@export var stench_sprint_rate: float = 3.0

@export var stench_damage_threshold: float = 75.0
@export var stench_damage_per_sec: float = 5.0
@export var stench_aura_radius: float = 8.0

var _damage_timer: float = 0.0

# High Quality VFX Emitters
var _gas_particles: GPUParticles3D
var _flies_particles: GPUParticles3D
var _spore_particles: GPUParticles3D
var _seismic_shockwave_particles: GPUParticles3D
var _slingshot_blast_particles: GPUParticles3D

# Slingshot Target Tracking & Cooldown
@export var slingshot_cooldown_max: float = 1.8
var _slingshot_cooldown: float = 0.0


func _ready() -> void:
	super._ready()
	if not player and get_parent() is Player:
		player = get_parent() as Player

	if player:
		if not player.player_landed.is_connected(_on_player_landed):
			player.player_landed.connect(_on_player_landed)

	_setup_visual_nodes()
	_setup_seismic_vfx()
	_setup_slingshot_vfx()

func _setup_visual_nodes() -> void:
	var parent_3d: Node3D = player if player else (get_parent() as Node3D)
	if not parent_3d:
		return

	var smoke_texture: ImageTexture = _create_procedural_smoke_texture()
	var fly_texture: ImageTexture = _create_procedural_fly_texture()

	# 1. Volumetric Gas Clouds
	if not _gas_particles:
		_gas_particles = GPUParticles3D.new()
		_gas_particles.name = "VFX_StenchGasClouds"
		_gas_particles.emitting = false
		_gas_particles.amount = 28
		_gas_particles.lifetime = 1.4
		_gas_particles.speed_scale = 1.2

		var mat_proc: ParticleProcessMaterial = ParticleProcessMaterial.new()
		mat_proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		mat_proc.emission_sphere_radius = 0.35
		mat_proc.direction = Vector3(0, 1, 0)
		mat_proc.spread = 35.0
		mat_proc.initial_velocity_min = 0.8
		mat_proc.initial_velocity_max = 2.2
		mat_proc.gravity = Vector3(0, 0.4, 0)
		mat_proc.scale_min = 0.3
		mat_proc.scale_max = 0.7
		mat_proc.color = Color(0.4, 0.85, 0.2, 0.5)

		mat_proc.turbulence_enabled = true
		mat_proc.turbulence_noise_strength = 2.5
		mat_proc.turbulence_noise_scale = 2.0

		var draw_mat: StandardMaterial3D = StandardMaterial3D.new()
		draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		draw_mat.albedo_texture = smoke_texture
		draw_mat.albedo_color = Color(0.4, 0.85, 0.2, 0.55)
		draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		draw_mat.billboard_keep_scale = true
		draw_mat.proximity_fade_enabled = true
		draw_mat.proximity_fade_distance = 0.4

		var quad_mesh: QuadMesh = QuadMesh.new()
		quad_mesh.material = draw_mat
		quad_mesh.size = Vector2(0.45, 0.45)

		_gas_particles.process_material = mat_proc
		_gas_particles.draw_pass_1 = quad_mesh
		_gas_particles.position = Vector3(0, 0.9, 0)
		parent_3d.add_child(_gas_particles)

	# 2. Buzzing Flies Swarm
	if not _flies_particles:
		_flies_particles = GPUParticles3D.new()
		_flies_particles.name = "VFX_BuzzingFliesSwarm"
		_flies_particles.emitting = false
		_flies_particles.amount = 20
		_flies_particles.lifetime = 0.8
		_flies_particles.speed_scale = 1.8

		var mat_proc: ParticleProcessMaterial = ParticleProcessMaterial.new()
		mat_proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		mat_proc.emission_sphere_radius = 0.55
		mat_proc.direction = Vector3(0, 1, 0)
		mat_proc.spread = 180.0
		mat_proc.initial_velocity_min = 2.0
		mat_proc.initial_velocity_max = 4.2
		mat_proc.gravity = Vector3(0, 0, 0)
		mat_proc.scale_min = 0.05
		mat_proc.scale_max = 0.1

		mat_proc.turbulence_enabled = true
		mat_proc.turbulence_noise_strength = 5.5
		mat_proc.turbulence_noise_scale = 4.0

		var draw_mat: StandardMaterial3D = StandardMaterial3D.new()
		draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		draw_mat.albedo_texture = fly_texture
		draw_mat.albedo_color = Color(0.1, 0.1, 0.1, 0.95)
		draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED

		var fly_quad: QuadMesh = QuadMesh.new()
		fly_quad.material = draw_mat
		fly_quad.size = Vector2(0.08, 0.08)

		_flies_particles.process_material = mat_proc
		_flies_particles.draw_pass_1 = fly_quad
		_flies_particles.position = Vector3(0, 1.3, 0)
		parent_3d.add_child(_flies_particles)

	# 3. Glowing Toxic Spores
	if not _spore_particles:
		_spore_particles = GPUParticles3D.new()
		_spore_particles.name = "VFX_ToxicSpores"
		_spore_particles.emitting = false
		_spore_particles.amount = 16
		_spore_particles.lifetime = 1.8

		var mat_proc: ParticleProcessMaterial = ParticleProcessMaterial.new()
		mat_proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		mat_proc.emission_box_extents = Vector3(0.4, 0.1, 0.4)
		mat_proc.direction = Vector3(0, 1, 0)
		mat_proc.spread = 35.0
		mat_proc.initial_velocity_min = 0.6
		mat_proc.initial_velocity_max = 1.4
		mat_proc.gravity = Vector3(0, 0.2, 0)
		mat_proc.scale_min = 0.04
		mat_proc.scale_max = 0.1

		var draw_mat: StandardMaterial3D = StandardMaterial3D.new()
		draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		draw_mat.albedo_color = Color(0.7, 0.95, 0.2, 0.85)
		draw_mat.proximity_fade_enabled = true
		draw_mat.proximity_fade_distance = 0.4

		var spore_mesh: SphereMesh = SphereMesh.new()
		spore_mesh.material = draw_mat
		spore_mesh.radius = 0.04
		spore_mesh.height = 0.08

		_spore_particles.process_material = mat_proc
		_spore_particles.draw_pass_1 = spore_mesh
		_spore_particles.position = Vector3(0, 0.2, 0)
		parent_3d.add_child(_spore_particles)

func _setup_seismic_vfx() -> void:
	var parent_3d: Node3D = player if player else (get_parent() as Node3D)
	if not parent_3d or _seismic_shockwave_particles:
		return

	_seismic_shockwave_particles = GPUParticles3D.new()
	_seismic_shockwave_particles.name = "VFX_SeismicLandingShockwave"
	_seismic_shockwave_particles.top_level = true
	_seismic_shockwave_particles.amount = 45
	_seismic_shockwave_particles.lifetime = 0.8
	_seismic_shockwave_particles.one_shot = true
	_seismic_shockwave_particles.explosiveness = 0.96
	_seismic_shockwave_particles.emitting = false

	var mat_proc: ParticleProcessMaterial = ParticleProcessMaterial.new()
	mat_proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat_proc.emission_ring_radius = 1.5
	mat_proc.emission_ring_inner_radius = 0.2
	mat_proc.emission_ring_axis = Vector3(0, 1, 0)
	mat_proc.direction = Vector3(0, 0.2, 0)
	mat_proc.spread = 180.0
	mat_proc.initial_velocity_min = 7.0
	mat_proc.initial_velocity_max = 16.0
	mat_proc.gravity = Vector3(0, -2.0, 0)
	mat_proc.scale_min = 0.08
	mat_proc.scale_max = 0.25
	mat_proc.color = Color(0.65, 0.55, 0.42, 0.8)

	var draw_mat: StandardMaterial3D = StandardMaterial3D.new()
	draw_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.albedo_color = Color(0.65, 0.55, 0.42, 0.7)
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var quad: QuadMesh = QuadMesh.new()
	quad.material = draw_mat
	quad.size = Vector2(0.2, 0.2)

	_seismic_shockwave_particles.process_material = mat_proc
	_seismic_shockwave_particles.draw_pass_1 = quad
	parent_3d.add_child(_seismic_shockwave_particles)

func _setup_slingshot_vfx() -> void:
	var parent_3d: Node3D = player if player else (get_parent() as Node3D)
	if not parent_3d or _slingshot_blast_particles:
		return

	_slingshot_blast_particles = GPUParticles3D.new()
	_slingshot_blast_particles.name = "VFX_SlingshotBlast"
	_slingshot_blast_particles.top_level = true
	_slingshot_blast_particles.amount = 50
	_slingshot_blast_particles.lifetime = 0.7
	_slingshot_blast_particles.one_shot = true
	_slingshot_blast_particles.explosiveness = 0.98
	_slingshot_blast_particles.emitting = false

	var mat_proc: ParticleProcessMaterial = ParticleProcessMaterial.new()
	mat_proc.direction = Vector3(0, 1, -1.0)
	mat_proc.spread = 45.0
	mat_proc.initial_velocity_min = 10.0
	mat_proc.initial_velocity_max = 22.0
	mat_proc.gravity = Vector3(0, -5.0, 0)
	mat_proc.scale_min = 0.08
	mat_proc.scale_max = 0.25
	mat_proc.color = Color(0.9, 0.75, 0.4, 0.85)

	var draw_mat: StandardMaterial3D = StandardMaterial3D.new()
	draw_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.albedo_color = Color(0.9, 0.75, 0.4, 0.75)
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var quad: QuadMesh = QuadMesh.new()
	quad.material = draw_mat
	quad.size = Vector2(0.18, 0.18)

	_slingshot_blast_particles.process_material = mat_proc
	_slingshot_blast_particles.draw_pass_1 = quad
	parent_3d.add_child(_slingshot_blast_particles)

func _create_procedural_smoke_texture() -> ImageTexture:
	var img: Image = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.025
	noise.fractal_octaves = 4

	var center: Vector2 = Vector2(64, 64)
	var max_radius: float = 60.0

	for y in range(128):
		for x in range(128):
			var pos: Vector2 = Vector2(x, y)
			var dist: float = pos.distance_to(center)
			if dist >= max_radius:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue

			var n_val: float = (noise.get_noise_2d(float(x), float(y)) + 1.0) * 0.5
			var falloff: float = 1.0 - (dist / max_radius)
			falloff = smoothstep(0.0, 1.0, falloff)
			var alpha: float = clampf(n_val * falloff * 0.9, 0.0, 1.0)

			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))

	return ImageTexture.create_from_image(img)

func _create_procedural_fly_texture() -> ImageTexture:
	var img: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	for y in range(64):

		for x in range(64):
			var pos: Vector2 = Vector2(x, y)
			var dx: float = (float(x) - 32.0) * 1.5
			var dy: float = (float(y) - 32.0) * 0.8
			var body_val: float = sqrt(dx * dx + dy * dy)
			if body_val <= 10.0:
				img.set_pixel(x, y, Color(0.08, 0.08, 0.08, 0.95))
				continue

			var wing_left: float = pos.distance_to(Vector2(22, 24))
			var wing_right: float = pos.distance_to(Vector2(42, 24))
			if wing_left <= 8.0 or wing_right <= 8.0:
				img.set_pixel(x, y, Color(0.7, 0.8, 0.9, 0.6))

	return ImageTexture.create_from_image(img)

func _on_player_landed(downward_vel: float) -> void:
	if not _ensure_player_ref() or not player.is_multiplayer_authority() or player.is_dead:
		return

	if downward_vel < -1.8:
		var impact_speed: float = absf(downward_vel)
		rpc_seismic_earthquake.rpc(player.global_position, impact_speed)

@rpc("any_peer", "call_local", "reliable")
func rpc_seismic_earthquake(center_pos: Vector3, impact_speed: float) -> void:
	if _seismic_shockwave_particles:
		_seismic_shockwave_particles.global_position = center_pos + Vector3(0, 0.1, 0)
		_seismic_shockwave_particles.restart()
		_seismic_shockwave_particles.emitting = true

	if player and player.is_multiplayer_authority() and player.camera_3d:
		player.camera_3d.rotation.z = deg_to_rad(randf_range(-14.0, 14.0))

	var radius: float = 7.5
	var root: Node = get_tree().root
	_pop_seismic_nodes_recursive(root, center_pos, radius, impact_speed)

	print("💥 SEISMIC EARTHQUAKE: Fat landed! Popped items & players within %.1fm radius." % radius)

func _pop_seismic_nodes_recursive(node: Node, center: Vector3, radius: float, impact_speed: float) -> void:
	if not node:
		return

	if node is Node3D and node != player:
		var n3d: Node3D = node as Node3D
		var dist: float = center.distance_to(n3d.global_position)
		if dist <= radius:
			var falloff: float = 1.0 - (dist / radius)

			# Case A: RigidBody3D physical objects (Heavy Boulder, barrels, crates, items) -> MASSIVE POP UPWARD!
			if node is RigidBody3D:
				var rb: RigidBody3D = node as RigidBody3D
				if not rb.freeze:
					# Scaled mass impulse so giant 450kg Heavy Boulder pops up noticeably in the air!
					var pop_y: float = clampf(rb.mass * 9.5 * (impact_speed / 3.5) * falloff, 300.0, 5000.0)
					var dir_xz: Vector3 = (rb.global_position - center)
					dir_xz.y = 0
					if dir_xz.length_squared() > 0.001:
						dir_xz = dir_xz.normalized()
					rb.apply_central_impulse(Vector3(dir_xz.x * rb.mass * 3.5 * falloff, pop_y, dir_xz.z * rb.mass * 3.5 * falloff))
					rb.apply_torque_impulse(Vector3(randf_range(-150.0, 150.0), 0, randf_range(-150.0, 150.0)))
					print("💥 SEISMIC POP: Launched RigidBody %s into the air!" % rb.name)

			# Case B: Teammates / Other Players -> POP UPWARD IN THE AIR!
			elif node is Player:
				var target_player: Player = node as Player
				if not target_player.is_dead:
					var pop_y_vel: float = clampf(6.5 * (impact_speed / 3.5) * falloff, 4.2, 9.2)
					target_player.velocity.y = pop_y_vel
					if target_player.camera_3d:
						target_player.camera_3d.rotation.z = deg_to_rad(randf_range(-14.0, 14.0))
					print("💥 SEISMIC POP: Launched teammate %s into the air! (y_vel: %.1f)" % [target_player.name, pop_y_vel])

			# Case C: Dummy NPC
			elif node is DummyNPC:
				var dummy: DummyNPC = node as DummyNPC
				var pop_y_vel: float = clampf(6.5 * (impact_speed / 3.5) * falloff, 4.2, 9.2)
				dummy.velocity = Vector3(randf_range(-3, 3), pop_y_vel, randf_range(-3, 3))
				dummy.take_damage(15.0 * falloff, n3d.global_position)
				print("💥 SEISMIC POP: Launched DummyNPC %s into the air!" % dummy.name)

			# Case D: Fragile Glass Floor -> Shatter from nearby seismic earthquake landing!
			elif node is FragileGlassFloor:
				var glass: FragileGlassFloor = node as FragileGlassFloor
				glass.trigger_seismic_break()


	for child in node.get_children():
		_pop_seismic_nodes_recursive(child, center, radius, impact_speed)

# Slingshot Shove & Launch Mechanics (Supports Thin Players AND Dummy NPCs)
func handle_ability_input(event: InputEvent) -> void:
	if not _ensure_player_ref() or not player.is_multiplayer_authority() or player.is_dead:
		return

	var is_interact_pressed: bool = event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_E or event.keycode == KEY_F))

	if is_interact_pressed and _slingshot_cooldown <= 0.0:
		var target_node: Node3D = _find_thin_target()
		if target_node:
			var forward: Vector3 = -player.camera_3d.global_transform.basis.z if player.camera_3d else -player.global_transform.basis.z
			var launch_dir: Vector3 = (forward + Vector3(0, 0.45, 0)).normalized()
			var launch_vel: Vector3 = launch_dir * 28.0 # Slingshot velocity!

			_slingshot_cooldown = slingshot_cooldown_max
			rpc_slingshot_launch.rpc(target_node.get_path(), launch_vel)

			return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_K or event.keycode == KEY_G:
			add_stench(35.0)

func _find_thin_target() -> Node3D:
	if not player:
		return null

	var origin: Vector3 = player.head.global_position if player.head else player.global_position + Vector3(0, 1.5, 0)
	var forward: Vector3 = -player.camera_3d.global_transform.basis.z if player.camera_3d else -player.global_transform.basis.z

	# 1. Raycast check forward (4.0m range)
	var space_state: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin + forward * 4.0)
	query.exclude = [player]

	var hit: Dictionary = space_state.intersect_ray(query)
	if not hit.is_empty() and hit.get("collider") is Node3D:
		var col: Node3D = hit["collider"] as Node3D
		if _is_valid_thin_target(col):
			return col

	# 2. Fallback: Radial search within 3.8m radius
	var root: Node = get_tree().root
	return _find_thin_target_recursive(root, player.global_position, 3.8)

func _is_valid_thin_target(node: Node3D) -> bool:
	if node is Player and node != player:
		var p: Player = node as Player
		return p.selected_character_id.to_lower() == "thin" and not p.is_dead
	elif node is DummyNPC:
		var dummy: DummyNPC = node as DummyNPC
		return not dummy.is_dead
	return false

func _find_thin_target_recursive(node: Node, center: Vector3, radius: float) -> Node3D:
	if not node:
		return null

	if node is Node3D and node != player:
		var n3d: Node3D = node as Node3D
		if _is_valid_thin_target(n3d):
			if center.distance_to(n3d.global_position) <= radius:
				return n3d

	for child in node.get_children():
		var res: Node3D = _find_thin_target_recursive(child, center, radius)
		if res:
			return res
	return null

@rpc("any_peer", "call_local", "reliable")
func rpc_slingshot_launch(target_path: NodePath, launch_velocity: Vector3) -> void:
	var target_node: Node3D = get_node_or_null(target_path) as Node3D
	if not target_node:
		return

	# Apply Slingshot Launch to Player or DummyNPC
	if target_node is Player:
		var p: Player = target_node as Player
		p.velocity = launch_velocity
		if p.camera_3d:
			p.set_target_fov(95.0)
	elif target_node is DummyNPC:
		var dummy: DummyNPC = target_node as DummyNPC
		dummy.velocity = launch_velocity
		dummy.take_damage(20.0, dummy.global_position)

	# Trigger Particle Blast VFX at launch point
	if _slingshot_blast_particles:
		_slingshot_blast_particles.global_position = target_node.global_position + Vector3(0, 1.0, 0)
		_slingshot_blast_particles.restart()
		_slingshot_blast_particles.emitting = true

	# Camera recoil for Fat player
	if player and player.is_multiplayer_authority() and player.camera_3d:
		player.camera_3d.rotation.z = deg_to_rad(-12.0)

	print("🚀 SLINGSHOT LAUNCH: Fat launched %s into the air! Velocity: %s" % [target_node.name, str(launch_velocity)])

func add_stench(amount: float) -> void:
	stench_level = clampf(stench_level + amount, 0.0, max_stench)
	stench_changed.emit(stench_level, max_stench)
	_update_gas_visuals()

func update_mechanics(delta: float) -> void:
	if not _ensure_player_ref() or not player.is_multiplayer_authority() or player.is_dead:
		return

	if _slingshot_cooldown > 0.0:
		_slingshot_cooldown = maxf(_slingshot_cooldown - delta, 0.0)

	if player and player.hud and player.hud.has_method("update_slingshot_cooldown"):
		player.hud.update_slingshot_cooldown(_slingshot_cooldown, slingshot_cooldown_max)

	var input_dir: Vector3 = player.get_movement_input()

	if input_dir.length_squared() > 0.01:
		var is_sprinting: bool = (player.synced_state_name.to_lower() == "sprint")
		var rate: float = stench_sprint_rate if is_sprinting else stench_walk_rate

		stench_level = clampf(stench_level + rate * delta, 0.0, max_stench)
		stench_changed.emit(stench_level, max_stench)

	_update_gas_visuals()
	_update_aoe_poison_damage(delta)

func wash_stench() -> void:
	stench_level = 0.0
	stench_changed.emit(stench_level, max_stench)
	_update_gas_visuals()

func wash_stench_gradual(amount: float) -> void:
	stench_level = clampf(stench_level - amount, 0.0, max_stench)
	stench_changed.emit(stench_level, max_stench)
	_update_gas_visuals()

func _update_gas_visuals() -> void:
	var intensity := stench_level / max_stench

	if _gas_particles:
		var should_emit := (stench_level >= 20.0)
		if _gas_particles.emitting != should_emit:
			_gas_particles.emitting = should_emit
		if should_emit:
			_gas_particles.amount = int(lerpf(20.0, 55.0, intensity))

	if _flies_particles:
		var should_flies := (stench_level >= 35.0)
		if _flies_particles.emitting != should_flies:
			_flies_particles.emitting = should_flies
		if should_flies:
			_flies_particles.amount = int(lerpf(15.0, 40.0, intensity))

	if _spore_particles:
		var should_spores := (stench_level >= 50.0)
		if _spore_particles.emitting != should_spores:
			_spore_particles.emitting = should_spores

func _update_aoe_poison_damage(delta: float) -> void:
	if stench_level < stench_damage_threshold:
		return

	_damage_timer += delta
	if _damage_timer >= 1.0:
		_damage_timer = 0.0
		_apply_aoe_damage_tick()

func _apply_aoe_damage_tick() -> void:
	if not _ensure_player_ref():
		return

	var center := player.global_position
	var root := get_tree().root
	_damage_nodes_recursive(root, center)

func _damage_nodes_recursive(node: Node, center: Vector3) -> void:
	if not node:
		return

	if node is Node3D and node != player:
		var n3d := node as Node3D
		var dist := center.distance_to(n3d.global_position)
		if dist <= stench_aura_radius:
			if node.has_method("trigger_nausea"):
				node.trigger_nausea(0.5)
			if node.has_method("take_damage"):
				node.take_damage(stench_damage_per_sec, n3d.global_position)
				print("🤢 STENCH AURA: Dealt %f damage to %s (dist: %.1fm)" % [stench_damage_per_sec, node.name, dist])

	for child in node.get_children():
		_damage_nodes_recursive(child, center)

func _ensure_player_ref() -> bool:
	if not player and get_parent() is Player:
		player = get_parent() as Player
	return player != null
