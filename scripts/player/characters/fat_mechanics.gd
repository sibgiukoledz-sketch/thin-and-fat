class_name FatMechanics
extends BaseCharacterMechanics

## Controller for "Fat / Жирдяй" character mechanics: AAA Realistic Volumetric Stench VFX & Buzzing Flies System.

signal stench_changed(current: float, max_stench: float)

@export var max_stench: float = 100.0
@export var stench_level: float = 0.0

# Balanced Accumulation Rates (Slow & Realistic)
@export var stench_walk_rate: float = 0.6
@export var stench_sprint_rate: float = 3.0

@export var stench_damage_threshold: float = 75.0
@export var stench_damage_per_sec: float = 20.0
@export var stench_aura_radius: float = 8.0

var _damage_timer: float = 0.0

# High Quality VFX Emitters
var _gas_particles: GPUParticles3D
var _flies_particles: GPUParticles3D
var _spore_particles: GPUParticles3D
var _toxic_ring_mesh: MeshInstance3D
var _ring_material: StandardMaterial3D

func _ready() -> void:
	super._ready()
	if not player and get_parent() is Player:
		player = get_parent() as Player
	_setup_visual_nodes()

func _setup_visual_nodes() -> void:
	var parent_3d: Node3D = player if player else (get_parent() as Node3D)
	if not parent_3d:
		return

	# Generate realistic smoke texture procedurally
	var smoke_texture := _create_procedural_smoke_texture()
	var fly_texture := _create_procedural_fly_texture()

	# 1. Realistic Volumetric Gas Clouds (Proximity Fade & Quad Billboards)
	if not _gas_particles:
		_gas_particles = GPUParticles3D.new()
		_gas_particles.name = "VFX_StenchGasClouds"
		_gas_particles.emitting = false
		_gas_particles.amount = 55
		_gas_particles.lifetime = 2.2
		_gas_particles.speed_scale = 0.9

		var mat_proc := ParticleProcessMaterial.new()
		mat_proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		mat_proc.emission_sphere_radius = 1.3
		mat_proc.direction = Vector3(0, 1, 0)
		mat_proc.spread = 45.0
		mat_proc.initial_velocity_min = 0.3
		mat_proc.initial_velocity_max = 1.1
		mat_proc.gravity = Vector3(0, 0.25, 0)
		mat_proc.scale_min = 0.8
		mat_proc.scale_max = 1.6
		mat_proc.color = Color(0.38, 0.85, 0.22, 0.55) # Realistic Toxic Green

		# Realistic turbulence for organic billows
		mat_proc.turbulence_enabled = true
		mat_proc.turbulence_noise_strength = 1.8
		mat_proc.turbulence_noise_scale = 1.4

		var draw_mat := StandardMaterial3D.new()
		draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		draw_mat.albedo_texture = smoke_texture
		draw_mat.albedo_color = Color(0.4, 0.9, 0.22, 0.6)
		draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		draw_mat.billboard_keep_scale = true

		# Enable Proximity Fade so gas puffs softly blend with ground, walls and player
		draw_mat.proximity_fade_enabled = true
		draw_mat.proximity_fade_distance = 0.8

		var quad_mesh := QuadMesh.new()
		quad_mesh.material = draw_mat
		quad_mesh.size = Vector2(1.2, 1.2)

		_gas_particles.process_material = mat_proc
		_gas_particles.draw_pass_1 = quad_mesh
		_gas_particles.position = Vector3(0, 0.9, 0)
		parent_3d.add_child(_gas_particles)

	# 2. Realistic Buzzing Flies Swarm with Wing Texture & Erratic Brownian Motion
	if not _flies_particles:
		_flies_particles = GPUParticles3D.new()
		_flies_particles.name = "VFX_BuzzingFliesSwarm"
		_flies_particles.emitting = false
		_flies_particles.amount = 40
		_flies_particles.lifetime = 1.0
		_flies_particles.speed_scale = 1.6

		var mat_proc := ParticleProcessMaterial.new()
		mat_proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		mat_proc.emission_sphere_radius = 1.5
		mat_proc.direction = Vector3(0, 1, 0)
		mat_proc.spread = 180.0
		mat_proc.initial_velocity_min = 2.5
		mat_proc.initial_velocity_max = 5.0
		mat_proc.gravity = Vector3(0, 0, 0)
		mat_proc.scale_min = 0.12
		mat_proc.scale_max = 0.22

		# Fast turbulence for erratic buzzing trajectories
		mat_proc.turbulence_enabled = true
		mat_proc.turbulence_noise_strength = 5.0
		mat_proc.turbulence_noise_scale = 3.5

		var draw_mat := StandardMaterial3D.new()
		draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		draw_mat.albedo_texture = fly_texture
		draw_mat.albedo_color = Color(0.1, 0.1, 0.1, 0.95)
		draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED

		var fly_quad := QuadMesh.new()
		fly_quad.material = draw_mat
		fly_quad.size = Vector2(0.18, 0.18)

		_flies_particles.process_material = mat_proc
		_flies_particles.draw_pass_1 = fly_quad
		_flies_particles.position = Vector3(0, 1.3, 0)
		parent_3d.add_child(_flies_particles)

	# 3. Glowing Toxic Spores (Rising embers)
	if not _spore_particles:
		_spore_particles = GPUParticles3D.new()
		_spore_particles.name = "VFX_ToxicSpores"
		_spore_particles.emitting = false
		_spore_particles.amount = 30
		_spore_particles.lifetime = 2.2

		var mat_proc := ParticleProcessMaterial.new()
		mat_proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		mat_proc.emission_box_extents = Vector3(1.3, 0.2, 1.3)
		mat_proc.direction = Vector3(0, 1, 0)
		mat_proc.spread = 35.0
		mat_proc.initial_velocity_min = 0.7
		mat_proc.initial_velocity_max = 1.5
		mat_proc.gravity = Vector3(0, 0.2, 0)
		mat_proc.scale_min = 0.08
		mat_proc.scale_max = 0.16

		var draw_mat := StandardMaterial3D.new()
		draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		draw_mat.albedo_color = Color(0.75, 1.0, 0.25, 0.9)
		draw_mat.proximity_fade_enabled = true
		draw_mat.proximity_fade_distance = 0.5

		var spore_mesh := SphereMesh.new()
		spore_mesh.material = draw_mat
		spore_mesh.radius = 0.06
		spore_mesh.height = 0.12

		_spore_particles.process_material = mat_proc
		_spore_particles.draw_pass_1 = spore_mesh
		_spore_particles.position = Vector3(0, 0.2, 0)
		parent_3d.add_child(_spore_particles)

	# 4. Soft Proximity-Faded Ground Toxic Damage Ring Emitter
	if not _toxic_ring_mesh:
		_toxic_ring_mesh = MeshInstance3D.new()
		_toxic_ring_mesh.name = "VFX_ToxicDamageRing"
		var torus := TorusMesh.new()
		torus.inner_radius = stench_aura_radius - 0.3
		torus.outer_radius = stench_aura_radius

		_ring_material = StandardMaterial3D.new()
		_ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ring_material.albedo_color = Color(0.45, 0.95, 0.2, 0.5)
		_ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ring_material.proximity_fade_enabled = true
		_ring_material.proximity_fade_distance = 0.5

		_toxic_ring_mesh.mesh = torus
		_toxic_ring_mesh.material_override = _ring_material
		_toxic_ring_mesh.position = Vector3(0, 0.1, 0)
		_toxic_ring_mesh.visible = false
		parent_3d.add_child(_toxic_ring_mesh)

func _create_procedural_smoke_texture() -> ImageTexture:
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.025
	noise.fractal_octaves = 4

	var center := Vector2(64, 64)
	var max_radius := 60.0

	for y in range(128):
		for x in range(128):
			var pos := Vector2(x, y)
			var dist := pos.distance_to(center)
			if dist >= max_radius:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue

			var n_val := (noise.get_noise_2d(x, y) + 1.0) * 0.5
			var falloff := 1.0 - (dist / max_radius)
			falloff = smoothstep(0.0, 1.0, falloff)
			var alpha := clampf(n_val * falloff * 0.9, 0.0, 1.0)

			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))

	return ImageTexture.create_from_image(img)

func _create_procedural_fly_texture() -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	# Draw fly body & wings
	var center := Vector2(32, 32)
	for y in range(64):
		for x in range(64):
			var pos := Vector2(x, y)
			var body_dist := pos.distance_to(center)
			# Oval body
			var dx := (x - 32) * 1.5
			var dy := (y - 32) * 0.8
			var body_val := sqrt(dx * dx + dy * dy)
			if body_val <= 10.0:
				img.set_pixel(x, y, Color(0.08, 0.08, 0.08, 0.95))
				continue

			# Wings
			var wing_left := pos.distance_to(Vector2(22, 24))
			var wing_right := pos.distance_to(Vector2(42, 24))
			if wing_left <= 8.0 or wing_right <= 8.0:
				img.set_pixel(x, y, Color(0.7, 0.8, 0.9, 0.6))

	return ImageTexture.create_from_image(img)

func handle_ability_input(event: InputEvent) -> void:
	if not _ensure_player_ref() or not player.is_multiplayer_authority():
		return

	# Quick Test Key K or G: Instantly add +35% Stench
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_K or event.keycode == KEY_G:
			add_stench(35.0)
			print("🧪 TEST KEY: Added +35% Stench! Current: ", int(stench_level))

func add_stench(amount: float) -> void:
	stench_level = clampf(stench_level + amount, 0.0, max_stench)
	stench_changed.emit(stench_level, max_stench)
	_update_gas_visuals()

func update_mechanics(delta: float) -> void:
	if not _ensure_player_ref() or not player.is_multiplayer_authority() or player.is_dead:
		return

	# Accumulate stench when moving
	var input_dir := player.get_movement_input()
	if input_dir.length_squared() > 0.01:
		var is_sprinting := (player.synced_state_name.to_lower() == "sprint")
		var rate := stench_sprint_rate if is_sprinting else stench_walk_rate
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

	# 1. Volumetric Gas Clouds
	if _gas_particles:
		var should_emit := (stench_level >= 20.0)
		if _gas_particles.emitting != should_emit:
			_gas_particles.emitting = should_emit
		if should_emit:
			_gas_particles.amount = int(lerpf(20.0, 55.0, intensity))

	# 2. Buzzing Flies Swarm
	if _flies_particles:
		var should_flies := (stench_level >= 35.0)
		if _flies_particles.emitting != should_flies:
			_flies_particles.emitting = should_flies
		if should_flies:
			_flies_particles.amount = int(lerpf(15.0, 40.0, intensity))

	# 3. Glowing Toxic Spores
	if _spore_particles:
		var should_spores := (stench_level >= 50.0)
		if _spore_particles.emitting != should_spores:
			_spore_particles.emitting = should_spores

	# 4. Animated Damage Ring
	if _toxic_ring_mesh and _ring_material:
		var is_toxic := (stench_level >= stench_damage_threshold)
		_toxic_ring_mesh.visible = is_toxic
		if is_toxic:
			var alpha := 0.45 + sin(Time.get_ticks_msec() * 0.009) * 0.2
			_ring_material.albedo_color.a = alpha

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

	if node is Node3D and node != player and node.has_method("take_damage"):
		var n3d := node as Node3D
		var dist := center.distance_to(n3d.global_position)
		if dist <= stench_aura_radius:
			node.take_damage(stench_damage_per_sec, n3d.global_position)
			print("🤢 STENCH AURA: Dealt %f damage to %s (dist: %.1fm)" % [stench_damage_per_sec, node.name, dist])

	for child in node.get_children():
		_damage_nodes_recursive(child, center)

func _ensure_player_ref() -> bool:
	if not player and get_parent() is Player:
		player = get_parent() as Player
	return player != null
