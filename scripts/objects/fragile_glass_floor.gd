@tool
class_name FragileGlassFloor
extends StaticBody3D


## Realistic AAA Fragile Glass Floor / Wall panel supporting multiple types & formats:
## - Formats: Horizontal Floor panel or Vertical Wall / Window format (is_vertical_wall).
## - Types: CRYSTAL_CLEAR, FROSTED_ARMOURED, STAINED_EMERALD, STAINED_RUBY.
## - 3D Editor Markers: Visual 3D TypeLabel3D showing glass type and format in the editor viewport & game.

enum GlassType {
	CRYSTAL_CLEAR,
	FROSTED_ARMOURED,
	STAINED_EMERALD,
	STAINED_RUBY
}

signal glass_shattered

@export var glass_type: GlassType = GlassType.CRYSTAL_CLEAR:
	set(val):
		glass_type = val
		_update_type_label()
		_setup_glass_material()

@export var is_vertical_wall: bool = false:
	set(val):
		is_vertical_wall = val
		_setup_geometry()
		_update_type_label()

@export var show_editor_label: bool = true:
	set(val):
		show_editor_label = val
		_update_type_label()

@export var is_broken: bool = false
@export var break_delay_fat: float = 0.65 # Extended crack spreading phase (0.65s) before collapse
@export var respawn_time: float = 8.0 # Auto-restore floor after 8 seconds

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var detection_area: Area3D = $DetectionArea
@onready var shatter_particles: GPUParticles3D = $ShatterParticles
@onready var type_label: Label3D = $TypeLabel3D

var _is_breaking: bool = false
var _step_count: int = 0
var _glass_material: StandardMaterial3D
var _cracked_texture: ImageTexture
var _clean_texture: ImageTexture
var _active_shards: Array[Node] = []

func _ready() -> void:
	_setup_geometry()
	_setup_glass_material()
	_setup_particles()
	_update_type_label()

	if detection_area:
		if not detection_area.body_entered.is_connected(_on_body_entered):
			detection_area.body_entered.connect(_on_body_entered)

func _setup_geometry() -> void:
	if not collision_shape or not mesh_instance or not detection_area:
		return

	var box_shape: BoxShape3D = BoxShape3D.new()
	var box_mesh: BoxMesh = BoxMesh.new()
	var detect_shape: BoxShape3D = BoxShape3D.new()
	var detect_col: CollisionShape3D = detection_area.get_node_or_null("CollisionShape3D") as CollisionShape3D

	if is_vertical_wall:
		# Standing Vertical Wall / Window format (3.2m width x 3.2m height x 0.15m thickness) centered at Y = 1.6
		box_shape.size = Vector3(3.2, 3.2, 0.15)
		box_mesh.size = Vector3(3.2, 3.2, 0.15)
		detect_shape.size = Vector3(3.2, 3.2, 0.6)

		mesh_instance.position = Vector3(0, 1.6, 0)
		collision_shape.position = Vector3(0, 1.6, 0)
		detection_area.position = Vector3(0, 1.6, 0)
		if type_label:
			type_label.position = Vector3(0, 3.4, 0)
	else:
		# Horizontal Flat Floor Format (3.2m width x 0.15m height x 3.2m depth) centered at Y = 0
		box_shape.size = Vector3(3.2, 0.15, 3.2)
		box_mesh.size = Vector3(3.2, 0.15, 3.2)
		detect_shape.size = Vector3(3.1, 0.4, 3.1)

		mesh_instance.position = Vector3(0, 0, 0)
		collision_shape.position = Vector3(0, 0, 0)
		detection_area.position = Vector3(0, 0.25, 0)
		if type_label:
			type_label.position = Vector3(0, 0.4, 0)

	collision_shape.shape = box_shape
	mesh_instance.mesh = box_mesh
	if detect_col:
		detect_col.shape = detect_shape


func _update_type_label() -> void:
	if not is_node_ready() or not type_label:
		return

	# Show 3D text label ONLY in the Godot Editor viewport! Hide completely during gameplay!
	if not Engine.is_editor_hint():
		type_label.hide()
		return

	var type_name: String = ""

	var type_color: Color = Color.WHITE
	var format_str: String = "СТЕНА" if is_vertical_wall else "ПОЛ"

	match glass_type:
		GlassType.CRYSTAL_CLEAR:
			type_name = "💎 КРИСТАЛЬНОЕ СТЕКЛО (%s)" % format_str
			type_color = Color(0.6, 0.95, 1.0)
		GlassType.FROSTED_ARMOURED:
			type_name = "🛡️ АРМИРОВАННОЕ СТЕКЛО (2 ШАГА, %s)" % format_str
			type_color = Color(0.4, 0.8, 1.0)
		GlassType.STAINED_EMERALD:
			type_name = "🟢 ИЗУМРУДНЫЙ ВИТРАЖ (%s)" % format_str
			type_color = Color(0.2, 1.0, 0.5)
		GlassType.STAINED_RUBY:
			type_name = "🔴 РУБИНОВЫЙ ВИТРАЖ (%s)" % format_str
			type_color = Color(1.0, 0.3, 0.4)

	type_label.text = type_name
	type_label.modulate = type_color
	type_label.visible = show_editor_label and not is_broken

func _setup_glass_material() -> void:
	if not mesh_instance:
		return

	_clean_texture = _create_procedural_glass_texture(false)
	_cracked_texture = _create_procedural_glass_texture(true)

	_glass_material = StandardMaterial3D.new()
	_glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glass_material.roughness = 0.03
	_glass_material.metallic = 0.15
	_glass_material.refraction_enabled = true
	_glass_material.refraction_scale = 0.05
	_glass_material.albedo_texture = _clean_texture

	match glass_type:
		GlassType.CRYSTAL_CLEAR:
			_glass_material.albedo_color = Color(0.85, 0.96, 1.0, 0.32)
		GlassType.FROSTED_ARMOURED:
			_glass_material.albedo_color = Color(0.7, 0.88, 0.98, 0.62)
			_glass_material.roughness = 0.25
		GlassType.STAINED_EMERALD:
			_glass_material.albedo_color = Color(0.2, 0.95, 0.5, 0.6)
			_glass_material.emission_enabled = true
			_glass_material.emission = Color(0.08, 0.6, 0.25)
			_glass_material.emission_energy_multiplier = 0.5
		GlassType.STAINED_RUBY:
			_glass_material.albedo_color = Color(0.95, 0.25, 0.35, 0.6)
			_glass_material.emission_enabled = true
			_glass_material.emission = Color(0.65, 0.1, 0.15)
			_glass_material.emission_energy_multiplier = 0.5

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
			if x <= 12 or x >= 499 or y <= 12 or y >= 499:
				img.set_pixel(x, y, Color(0.9, 0.95, 1.0, 0.95))
				continue

			if glass_type == GlassType.FROSTED_ARMOURED:
				if (x + y) % 36 == 0 or (x - y + 512) % 36 == 0:
					img.set_pixel(x, y, Color(0.4, 0.45, 0.5, 0.7))
					continue

			if has_cracks:
				var pos: Vector2 = Vector2(x, y)
				var dist: float = pos.distance_to(center)
				var angle: float = pos.angle_to_point(center)

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

	var mat_proc: ParticleProcessMaterial = ParticleProcessMaterial.new()
	mat_proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat_proc.emission_box_extents = Vector3(1.5, 1.5, 0.1) if is_vertical_wall else Vector3(1.5, 0.05, 1.5)
	mat_proc.direction = Vector3(0, -1, 0)
	mat_proc.spread = 45.0
	mat_proc.initial_velocity_min = 1.5
	mat_proc.initial_velocity_max = 4.5
	mat_proc.gravity = Vector3(0, -18.0, 0)
	mat_proc.scale_min = 0.03
	mat_proc.scale_max = 0.12

	match glass_type:
		GlassType.STAINED_EMERALD:
			mat_proc.color = Color(0.2, 0.95, 0.5, 0.8)
		GlassType.STAINED_RUBY:
			mat_proc.color = Color(0.95, 0.25, 0.35, 0.8)
		_:
			mat_proc.color = Color(0.85, 0.96, 1.0, 0.8)

	var draw_mat: StandardMaterial3D = StandardMaterial3D.new()
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
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
		if p.selected_character_id.to_lower() == "fat" or p.is_carrying_heavy_object or p.velocity.length_squared() > 100.0:
			_handle_heavy_step()
	elif body is HeavyBoulder or body is RigidBody3D:
		_start_shatter_sequence()

func _handle_heavy_step() -> void:
	_step_count += 1
	if glass_type == GlassType.FROSTED_ARMOURED and _step_count < 2:
		if _glass_material:
			_glass_material.albedo_texture = _cracked_texture
		print("⚡ ARMOURED GLASS CRACKED! (Step 1/2)")
		return

	_start_shatter_sequence()

func trigger_seismic_break() -> void:
	if is_broken or _is_breaking:
		return
	_start_shatter_sequence()

func _start_shatter_sequence() -> void:
	if _is_breaking or is_broken:
		return
	_is_breaking = true

	if _glass_material:
		_glass_material.albedo_texture = _cracked_texture
		_glass_material.albedo_color.a = 0.75

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
	if type_label:
		type_label.hide()

	if shatter_particles:
		shatter_particles.global_position = global_position
		shatter_particles.restart()
		shatter_particles.emitting = true

	_spawn_3d_physical_shards()

	glass_shattered.emit()
	print("💥 GLASS FLOOR/WALL SHATTERED! Format: %s, Type: %d" % ["WALL" if is_vertical_wall else "FLOOR", int(glass_type)])

	if respawn_time > 0.0:
		get_tree().create_timer(respawn_time).timeout.connect(restore_floor)

func _spawn_3d_physical_shards() -> void:
	_clear_shards()

	var grid_count: int = 6
	var tile_size: float = 3.0 / float(grid_count)

	var draw_mat: StandardMaterial3D = StandardMaterial3D.new()
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.roughness = 0.04
	draw_mat.metallic = 0.2

	match glass_type:
		GlassType.STAINED_EMERALD:
			draw_mat.albedo_color = Color(0.2, 0.95, 0.5, 0.7)
		GlassType.STAINED_RUBY:
			draw_mat.albedo_color = Color(0.95, 0.25, 0.35, 0.7)
		GlassType.FROSTED_ARMOURED:
			draw_mat.albedo_color = Color(0.7, 0.88, 0.98, 0.75)
		_:
			draw_mat.albedo_color = Color(0.8, 0.95, 1.0, 0.65)

	for gx in range(grid_count):
		for gy_or_z in range(grid_count):
			var offset_x: float = (float(gx) - float(grid_count - 1) * 0.5) * tile_size + randf_range(-0.05, 0.05)
			var offset_2: float = (float(gy_or_z) - float(grid_count - 1) * 0.5) * tile_size + randf_range(-0.05, 0.05)

			var shard_pos: Vector3 = Vector3.ZERO
			if is_vertical_wall:
				shard_pos = global_position + Vector3(offset_x, offset_2, randf_range(-0.05, 0.05))
			else:
				shard_pos = global_position + Vector3(offset_x, randf_range(-0.05, 0.05), offset_2)

			var shard_rb: RigidBody3D = RigidBody3D.new()
			shard_rb.name = "GlassShard3D"
			shard_rb.mass = 0.3
			shard_rb.global_position = shard_pos
			shard_rb.collision_layer = 4
			shard_rb.collision_mask = 1

			var shard_mesh: MeshInstance3D = MeshInstance3D.new()
			var p_mesh: PrismMesh = PrismMesh.new()
			p_mesh.material = draw_mat
			var s_x: float = randf_range(0.1, 0.22)
			var s_y: float = randf_range(0.03, 0.08)
			var s_z: float = randf_range(0.1, 0.22)
			p_mesh.size = Vector3(s_x, s_y, s_z)
			shard_mesh.mesh = p_mesh

			var shard_col: CollisionShape3D = CollisionShape3D.new()
			var box_shape: BoxShape3D = BoxShape3D.new()
			box_shape.size = Vector3(s_x, s_y, s_z)
			shard_col.shape = box_shape

			shard_rb.add_child(shard_mesh)
			shard_rb.add_child(shard_col)

			get_tree().root.add_child(shard_rb)
			_active_shards.append(shard_rb)

			var nudge_x: float = randf_range(-0.5, 0.5)
			var nudge_z: float = randf_range(-0.5, 0.5)
			var drop_y: float = randf_range(-3.5, -0.8)
			shard_rb.apply_central_impulse(Vector3(nudge_x, drop_y, nudge_z))
			shard_rb.apply_torque_impulse(Vector3(randf_range(-2.5, 2.5), randf_range(-2.5, 2.5), randf_range(-2.5, 2.5)))

			_fade_and_free_shard(shard_rb, draw_mat)

func _fade_and_free_shard(shard_rb: RigidBody3D, mat_template: StandardMaterial3D) -> void:
	var tween: Tween = create_tween()
	tween.tween_interval(3.8)
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
	_step_count = 0
	_clear_shards()

	if collision_shape:
		collision_shape.set_deferred("disabled", false)
	if mesh_instance:
		mesh_instance.show()
	if type_label and show_editor_label:
		type_label.show()

	_setup_glass_material()
	print("✨ GLASS FLOOR/WALL RESTORED!")
