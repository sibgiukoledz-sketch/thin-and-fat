class_name FragileGlassFloor
extends StaticBody3D

## Realistic AAA Fragile Glass Floor panel.
## Safely supports Thin characters, but shatters into small 3D physical glass micro-shards that fall naturally
## under gravity, land on the ground below, and fade away over time when Fat (or a Heavy Boulder) steps on it!

signal glass_shattered

@export var is_broken: bool = false
@export var break_delay_fat: float = 0.18 # Spiderweb crack animation delay before shatter
@export var respawn_time: float = 8.0 # Auto-restore floor after 8 seconds

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var detection_area: Area3D = $DetectionArea
@onready var shatter_particles: GPUParticles3D = $ShatterParticles

var _is_breaking: bool = false
var _glass_material: StandardMaterial3D
var _cracked_texture: ImageTexture
var _clean_texture: ImageTexture
var _active_shards: Array[Node] = []

func _ready() -> void:
	_setup_glass_material()
	_setup_particles()
	if detection_area:
		if not detection_area.body_entered.is_connected(_on_body_entered):
			detection_area.body_entered.connect(_on_body_entered)

func _setup_glass_material() -> void:
	if not mesh_instance:
		return

	_clean_texture = _create_procedural_glass_texture(false)
	_cracked_texture = _create_procedural_glass_texture(true)

	_glass_material = StandardMaterial3D.new()
	_glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glass_material.albedo_color = Color(0.82, 0.96, 1.0, 0.38) # Crystal clear glass tint
	_glass_material.roughness = 0.02
	_glass_material.metallic = 0.15
	_glass_material.refraction_enabled = true
	_glass_material.refraction_scale = 0.05
	_glass_material.albedo_texture = _clean_texture

	mesh_instance.material_override = _glass_material

func _create_procedural_glass_texture(has_cracks: bool) -> ImageTexture:
	var img: Image = Image.create(512, 512, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0.22))

	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.frequency = 0.025
	noise.fractal_octaves = 3

	var center: Vector2 = Vector2(256, 256)
	for y in range(512):
		for x in range(512):
			# Chrome Outer Frame
			if x <= 10 or x >= 501 or y <= 10 or y >= 501:
				img.set_pixel(x, y, Color(0.9, 0.95, 1.0, 0.95))
				continue

			# Beveled Glass Edges
			if x <= 18 or x >= 493 or y <= 18 or y >= 493:
				img.set_pixel(x, y, Color(1.0, 1.0, 1.0, 0.45))
				continue

			if has_cracks:
				var pos: Vector2 = Vector2(x, y)
				var dist: float = pos.distance_to(center)
				var angle: float = pos.angle_to_point(center)

				# High-contrast organic spiderweb fracture pattern
				var n_val: float = absf(noise.get_noise_2d(float(x), float(y)))
				var radial_crack: bool = (int(absf(angle * 14.0)) % 2 == 0) and dist < 240.0
				var ring_crack: bool = (int(dist) % 40 < 3) and dist > 20.0
				var cell_crack: bool = n_val > 0.48 and dist < 240.0

				if radial_crack or ring_crack or cell_crack:
					img.set_pixel(x, y, Color(1.0, 1.0, 1.0, 0.95))

	return ImageTexture.create_from_image(img)

func _setup_particles() -> void:
	if shatter_particles:
		return

	shatter_particles = GPUParticles3D.new()
	shatter_particles.name = "ShatterParticles"
	shatter_particles.top_level = true
	shatter_particles.amount = 120
	shatter_particles.lifetime = 1.2
	shatter_particles.one_shot = true
	shatter_particles.explosiveness = 0.95
	shatter_particles.emitting = false

	# Downward showering glass dust particle process material
	var mat_proc: ParticleProcessMaterial = ParticleProcessMaterial.new()
	mat_proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat_proc.emission_box_extents = Vector3(1.5, 0.05, 1.5)
	mat_proc.direction = Vector3(0, -1, 0) # Shower downwards under gravity!
	mat_proc.spread = 45.0
	mat_proc.initial_velocity_min = 1.5
	mat_proc.initial_velocity_max = 4.5
	mat_proc.gravity = Vector3(0, -18.0, 0)
	mat_proc.scale_min = 0.03
	mat_proc.scale_max = 0.12

	var draw_mat: StandardMaterial3D = StandardMaterial3D.new()
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.albedo_color = Color(0.85, 0.96, 1.0, 0.8)
	draw_mat.roughness = 0.04

	var shard_mesh: PrismMesh = PrismMesh.new()
	shard_mesh.material = draw_mat
	shard_mesh.size = Vector3(0.08, 0.1, 0.03)

	shatter_particles.process_material = mat_proc
	shatter_particles.draw_pass_1 = shard_mesh
	add_child(shatter_particles)

func _on_body_entered(body: Node) -> void:
	if is_broken or _is_breaking:
		return

	if body is Player:
		var p: Player = body as Player
		if p.selected_character_id.to_lower() == "fat":
			_start_shatter_sequence()
		elif p.is_carrying_heavy_object:
			_start_shatter_sequence()
	elif body is HeavyBoulder:
		_start_shatter_sequence()

func _start_shatter_sequence() -> void:
	if _is_breaking or is_broken:
		return
	_is_breaking = true

	# Phase 1: Instant White Spiderweb Crack Animation (Clean crystal white!)
	if _glass_material:
		_glass_material.albedo_texture = _cracked_texture
		_glass_material.albedo_color = Color(0.95, 0.98, 1.0, 0.75)

	get_tree().create_timer(break_delay_fat).timeout.connect(shatter)

func shatter() -> void:
	rpc_shatter.rpc()

@rpc("any_peer", "call_local", "reliable")
func rpc_shatter() -> void:
	is_broken = true
	_is_breaking = false

	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	if mesh_instance:
		mesh_instance.hide()

	# 1. Trigger Glass Dust Shower VFX
	if shatter_particles:
		shatter_particles.global_position = global_position
		shatter_particles.restart()
		shatter_particles.emitting = true

	# 2. Spawn Realistic Downward-Falling 3D Glass Micro-Shards (No Player Collision!)
	_spawn_3d_physical_shards()

	glass_shattered.emit()
	print("💥 GLASS FLOOR SHATTERED! Micro glass shards collapsing downward.")

	if respawn_time > 0.0:
		get_tree().create_timer(respawn_time).timeout.connect(restore_floor)

func _spawn_3d_physical_shards() -> void:
	_clear_shards()

	# Create a 6x6 grid of 36 small 3D glass micro-shards
	var grid_count: int = 6
	var tile_size: float = 3.0 / float(grid_count)

	var draw_mat: StandardMaterial3D = StandardMaterial3D.new()
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.albedo_color = Color(0.8, 0.95, 1.0, 0.65)
	draw_mat.roughness = 0.04
	draw_mat.metallic = 0.2

	for gx in range(grid_count):
		for gz in range(grid_count):
			var offset_x: float = (float(gx) - float(grid_count - 1) * 0.5) * tile_size + randf_range(-0.05, 0.05)
			var offset_z: float = (float(gz) - float(grid_count - 1) * 0.5) * tile_size + randf_range(-0.05, 0.05)
			var shard_pos: Vector3 = global_position + Vector3(offset_x, randf_range(-0.05, 0.05), offset_z)

			# Create 3D RigidBody for each small glass shard
			var shard_rb: RigidBody3D = RigidBody3D.new()
			shard_rb.name = "GlassShard3D"
			shard_rb.mass = 0.3 # Lightweight micro-shard
			shard_rb.global_position = shard_pos

			# CRITICAL FIX: Set collision_layer = 4 (debris) and collision_mask = 1 (world floor ONLY).
			# NO collision with Player (layer 2) so players NEVER get flung into the air!
			shard_rb.collision_layer = 4
			shard_rb.collision_mask = 1

			# Small Shard Mesh
			var shard_mesh: MeshInstance3D = MeshInstance3D.new()
			var p_mesh: PrismMesh = PrismMesh.new()
			p_mesh.material = draw_mat
			var s_x: float = randf_range(0.1, 0.22)
			var s_y: float = randf_range(0.03, 0.08)
			var s_z: float = randf_range(0.1, 0.22)
			p_mesh.size = Vector3(s_x, s_y, s_z)
			shard_mesh.mesh = p_mesh

			# Shard Collision Shape
			var shard_col: CollisionShape3D = CollisionShape3D.new()
			var box_shape: BoxShape3D = BoxShape3D.new()
			box_shape.size = Vector3(s_x, s_y, s_z)
			shard_col.shape = box_shape

			shard_rb.add_child(shard_mesh)
			shard_rb.add_child(shard_col)

			get_tree().root.add_child(shard_rb)
			_active_shards.append(shard_rb)

			# REALISTIC COLLAPSE PHYSICS: Downward drop under gravity with gentle local tumble (NO far horizontal explosive fling!)
			var nudge_x: float = randf_range(-0.5, 0.5)
			var nudge_z: float = randf_range(-0.5, 0.5)
			var drop_y: float = randf_range(-3.5, -0.8) # Heavy downward collapse!
			shard_rb.apply_central_impulse(Vector3(nudge_x, drop_y, nudge_z))
			shard_rb.apply_torque_impulse(Vector3(randf_range(-2.5, 2.5), randf_range(-2.5, 2.5), randf_range(-2.5, 2.5)))

			# Schedule smooth fade-out and destruction after 4.5 seconds
			_fade_and_free_shard(shard_rb, draw_mat)

func _fade_and_free_shard(shard_rb: RigidBody3D, mat_template: StandardMaterial3D) -> void:
	var tween: Tween = create_tween()
	tween.tween_interval(3.8) # Stay on ground for 3.8s
	tween.tween_callback(func() -> void:
		if is_instance_valid(shard_rb):
			var mesh_inst: MeshInstance3D = shard_rb.get_node_or_null("MeshInstance3D") as MeshInstance3D
			if mesh_inst:
				var unique_mat: StandardMaterial3D = mat_template.duplicate() as StandardMaterial3D
				mesh_inst.material_override = unique_mat

				var fade_tween: Tween = create_tween()
				fade_tween.tween_property(unique_mat, "albedo_color:a", 0.0, 1.2)
				fade_tween.tween_callback(func() -> void:
					if is_instance_valid(shard_rb):
						shard_rb.queue_free()
				)
	)

func _clear_shards() -> void:
	for shard in _active_shards:
		if is_instance_valid(shard):
			shard.queue_free()
	_active_shards.clear()

func restore_floor() -> void:
	rpc_restore_floor.rpc()

@rpc("any_peer", "call_local", "reliable")
func rpc_restore_floor() -> void:
	is_broken = false
	_is_breaking = false
	_clear_shards()

	if collision_shape:
		collision_shape.set_deferred("disabled", false)
	if mesh_instance:
		mesh_instance.show()

	if _glass_material:
		_glass_material.albedo_texture = _clean_texture
		_glass_material.albedo_color = Color(0.82, 0.96, 1.0, 0.38)
	print("✨ GLASS FLOOR RESTORED!")
