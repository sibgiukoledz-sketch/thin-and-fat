class_name VomitPuddle
extends Area3D

## AAA Quality Organic Vomit Puddle with dynamic spreading expansion,
## procedural irregular noise shape, chunky food lumps, rising noxious steam, and buzzing flies.

@export var lifetime: float = 25.0
@export var extra_nausea: float = 0.4

var _life_timer: float = 0.0
var _target_scale: Vector3 = Vector3.ONE
var _steam_particles: GPUParticles3D
var _fly_particles: GPUParticles3D
var _puddle_mesh: MeshInstance3D
var _chunks_node: Node3D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_puddle_mesh = get_node_or_null("PuddleMesh") as MeshInstance3D

	# 1. Setup Procedural Irregular Noise Shape Material for organic liquid look
	_setup_procedural_puddle_material()

	# 2. Scatter chunky food lumps inside puddle
	_scatter_food_chunks()

	# 3. Create noxious steam & buzzing flies
	_create_steam_particles()
	_create_fly_particles()

	# 4. Animated spreading expansion: Start small and expand smoothly
	var rand_radius := randf_range(0.9, 1.4)
	_target_scale = Vector3(rand_radius, 1.0, rand_radius * randf_range(0.85, 1.15))
	scale = Vector3(0.1, 1.0, 0.1)
	rotation.y = randf() * TAU

	# Smoothly expand over 1.2 seconds
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", _target_scale, 1.2)

func _setup_procedural_puddle_material() -> void:
	if not _puddle_mesh:
		return

	# Create procedural noise for organic puddle edges
	var noise := FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 0.08
	noise.fractal_octaves = 3

	var noise_tex := NoiseTexture2D.new()
	noise_tex.noise = noise
	noise_tex.seamless = true
	await noise_tex.changed

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.52, 0.08, 0.92)
	mat.roughness = 0.04 # Glossy wet liquid reflection
	mat.metallic = 0.12
	mat.metallic_specular = 0.75
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = noise_tex

	_puddle_mesh.material_override = mat

func _scatter_food_chunks() -> void:
	_chunks_node = Node3D.new()
	_chunks_node.name = "FoodChunks"
	add_child(_chunks_node)

	var chunk_mat := StandardMaterial3D.new()
	chunk_mat.albedo_color = Color(0.55, 0.42, 0.12, 1.0)
	chunk_mat.roughness = 0.2

	var num_chunks := randi_range(5, 9)
	for i in num_chunks:
		var chunk := MeshInstance3D.new()
		var box := BoxMesh.new()
		var size_xz := randf_range(0.06, 0.16)
		box.size = Vector3(size_xz, randf_range(0.03, 0.07), randf_range(0.06, 0.14))
		box.material = chunk_mat

		chunk.mesh = box
		chunk.position = Vector3(
			randf_range(-0.6, 0.6),
			0.02,
			randf_range(-0.6, 0.6)
		)
		chunk.rotation.y = randf() * TAU
		_chunks_node.add_child(chunk)

func _create_steam_particles() -> void:
	_steam_particles = GPUParticles3D.new()
	_steam_particles.name = "VomitSteam"
	_steam_particles.amount = 16
	_steam_particles.lifetime = 2.2
	_steam_particles.emitting = true

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 35.0
	mat.initial_velocity_min = 0.25
	mat.initial_velocity_max = 0.7
	mat.gravity = Vector3(0, 0.35, 0)
	mat.scale_min = 0.15
	mat.scale_max = 0.4
	mat.color = Color(0.48, 0.58, 0.12, 0.38)

	var mesh := SphereMesh.new()
	var draw_mat := StandardMaterial3D.new()
	draw_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.albedo_color = Color(0.48, 0.58, 0.12, 0.35)
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = draw_mat
	mesh.radius = 0.12
	mesh.height = 0.24

	_steam_particles.process_material = mat
	_steam_particles.draw_pass_1 = mesh
	_steam_particles.transform.origin = Vector3(0, 0.08, 0)
	add_child(_steam_particles)

func _create_fly_particles() -> void:
	_fly_particles = GPUParticles3D.new()
	_fly_particles.name = "PuddleFlies"
	_fly_particles.amount = 10
	_fly_particles.lifetime = 1.5
	_fly_particles.emitting = true

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.85
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 0.9
	mat.initial_velocity_max = 2.2
	mat.gravity = Vector3(0, -0.4, 0)
	mat.scale_min = 0.025
	mat.scale_max = 0.045
	mat.color = Color(0.12, 0.12, 0.08, 0.95)

	var mesh := QuadMesh.new()
	var draw_mat := StandardMaterial3D.new()
	draw_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.albedo_color = Color(0.12, 0.12, 0.08, 0.95)
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mesh.material = draw_mat
	mesh.size = Vector2(0.04, 0.04)

	_fly_particles.process_material = mat
	_fly_particles.draw_pass_1 = mesh
	_fly_particles.transform.origin = Vector3(0, 0.35, 0)
	add_child(_fly_particles)

func _process(delta: float) -> void:
	_life_timer += delta

	# Fade out puddle near end of lifetime
	var fade_start := lifetime - 5.0
	if _life_timer >= fade_start:
		var fade_alpha := clampf(1.0 - (_life_timer - fade_start) / 5.0, 0.0, 1.0)
		if _puddle_mesh and _puddle_mesh.material_override:
			var mat := _puddle_mesh.material_override as StandardMaterial3D
			if mat:
				mat.albedo_color.a = fade_alpha * 0.92
		if _steam_particles and fade_alpha < 0.3:
			_steam_particles.emitting = false
		if _fly_particles and fade_alpha < 0.5:
			_fly_particles.emitting = false

	if _life_timer >= lifetime:
		queue_free()

func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		var p := body as Player
		if p.has_method("trigger_nausea"):
			p.trigger_nausea(extra_nausea)
			print("🤢 STEPPED IN VOMIT PUDDLE: Triggered nausea for %s" % p.name)
