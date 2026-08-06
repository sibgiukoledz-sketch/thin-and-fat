class_name VomitPuddle
extends Area3D

## Universal Surface Vomit Puddle / Splatter using Godot 4 Decals.
## Projects seamlessly onto any surface: floors, walls, sloped obstacles, boxes, and player character meshes!

@export var lifetime: float = 25.0
@export var extra_nausea: float = 0.4

var _life_timer: float = 0.0
var _target_scale: Vector3 = Vector3.ONE
var _steam_particles: GPUParticles3D
var _fly_particles: GPUParticles3D
var _decal: Decal
var _puddle_mesh: MeshInstance3D
var _chunks_node: Node3D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_decal = get_node_or_null("Decal") as Decal
	_puddle_mesh = get_node_or_null("PuddleMesh") as MeshInstance3D

	# 1. Setup Procedural Circular Radial Alpha Splatter Decal (NO square box edges!)
	_setup_procedural_decal()

	# 2. Scatter 3D organic food lumps
	_scatter_food_chunks()

	# 3. Create noxious steam & buzzing flies
	_create_steam_particles()
	_create_fly_particles()

	# 4. Animated spreading expansion: Start small and expand smoothly
	var rand_radius := randf_range(0.9, 1.3)
	_target_scale = Vector3(rand_radius, rand_radius, rand_radius)
	scale = Vector3(0.1, 0.1, 0.1)

	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", _target_scale, 1.2)

func align_to_surface(hit_point: Vector3, normal: Vector3, parent_body: Node3D = null) -> void:
	global_position = hit_point

	# Orient basis to align with hit normal
	if normal.length_squared() > 0.001:
		var up := Vector3.UP
		if absf(normal.dot(up)) > 0.99:
			up = Vector3.FORWARD
		var x_axis := normal.cross(up).normalized()
		var z_axis := x_axis.cross(normal).normalized()
		global_transform.basis = Basis(x_axis, normal, z_axis)

	# If hit another player or moving object, attach directly to them!
	if parent_body and parent_body != get_parent():
		var global_trans := global_transform
		get_parent().remove_child(self)
		parent_body.add_child(self)
		global_transform = global_trans
		print("🤮 VOMIT SPLATTER: Attached onto %s!" % parent_body.name)

func _setup_procedural_decal() -> void:
	var splatter_tex := _generate_liquid_splatter_texture()

	if _decal:
		_decal.texture_albedo = splatter_tex
		_decal.size = Vector3(1.6, 0.4, 1.6) # Shallow Y depth (0.4m) prevents stretch stripes on 3D boxes!
		_decal.lower_fade = 0.1
		_decal.upper_fade = 0.1
		_decal.normal_fade = 0.5
		_decal.cull_mask = 0xFFFFFFFF # Project onto EVERYTHING (World + Players)

	if _puddle_mesh:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.48, 0.58, 0.08, 0.92)
		mat.roughness = 0.04
		mat.metallic = 0.12
		mat.metallic_specular = 0.75
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_texture = splatter_tex
		_puddle_mesh.material_override = mat

func _generate_liquid_splatter_texture() -> Texture2D:
	var width := 128
	var height := 128
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)

	var noise := FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 0.08
	noise.fractal_octaves = 3

	var center := Vector2(width * 0.5, height * 0.5)
	var max_radius := width * 0.46

	for y in range(height):
		for x in range(width):
			var pos := Vector2(x, y)
			var dist := pos.distance_to(center)
			var norm_dist := dist / max_radius

			var n_val := (noise.get_noise_2d(float(x), float(y)) + 1.0) * 0.5
			# Organic liquid splash edge threshold
			var threshold := 0.75 + (n_val - 0.5) * 0.35

			if norm_dist < threshold:
				var edge_alpha := smoothstep(threshold, threshold - 0.2, norm_dist)
				var col := Color(0.48, 0.58, 0.08, edge_alpha * 0.95)
				img.set_pixel(x, y, col)
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))

	return ImageTexture.create_from_image(img)

func _scatter_food_chunks() -> void:
	_chunks_node = Node3D.new()
	_chunks_node.name = "FoodChunks"
	add_child(_chunks_node)

	var chunk_mat := StandardMaterial3D.new()
	chunk_mat.albedo_color = Color(0.55, 0.42, 0.12, 1.0)
	chunk_mat.roughness = 0.25

	var num_chunks := randi_range(6, 10)
	for i in num_chunks:
		var chunk := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		var r := randf_range(0.04, 0.09)
		sphere.radius = r
		sphere.height = r * randf_range(0.6, 1.1)
		sphere.material = chunk_mat

		chunk.mesh = sphere
		chunk.position = Vector3(
			randf_range(-0.45, 0.45),
			0.02,
			randf_range(-0.45, 0.45)
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
		if _decal:
			_decal.modulate.a = fade_alpha * 0.95
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
