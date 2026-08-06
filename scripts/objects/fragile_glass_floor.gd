class_name FragileGlassFloor
extends StaticBody3D

## Realistic Fragile Glass Floor panel that supports Thin characters safely,
## but immediately shatters into flying glass shards when Fat (or a Heavy Boulder) steps on it!

signal glass_shattered

@export var is_broken: bool = false
@export var break_delay_fat: float = 0.2 # Brief crack delay before shattering
@export var respawn_time: float = 8.0 # Auto-restore floor after 8 seconds

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var detection_area: Area3D = $DetectionArea
@onready var shatter_particles: GPUParticles3D = $ShatterParticles

var _is_breaking: bool = false
var _glass_material: StandardMaterial3D

func _ready() -> void:
	_setup_glass_material()
	_setup_particles()
	if detection_area:
		if not detection_area.body_entered.is_connected(_on_body_entered):
			detection_area.body_entered.connect(_on_body_entered)

func _setup_glass_material() -> void:
	if not mesh_instance:
		return

	_glass_material = StandardMaterial3D.new()
	_glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glass_material.albedo_color = Color(0.7, 0.9, 0.98, 0.35) # Ice-blue glass tint
	_glass_material.roughness = 0.06
	_glass_material.metallic = 0.2
	_glass_material.refraction_enabled = true
	_glass_material.refraction_scale = 0.04

	_glass_material.albedo_texture = _create_procedural_glass_texture()
	mesh_instance.material_override = _glass_material

func _create_procedural_glass_texture() -> ImageTexture:
	var img: Image = Image.create(256, 256, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0.3))

	# Procedural hairline cracks & frame border
	for y in range(256):
		for x in range(256):
			if x <= 5 or x >= 250 or y <= 5 or y >= 250:
				img.set_pixel(x, y, Color(0.85, 0.92, 1.0, 0.85)) # Metallic frame
			elif (x + y * 2) % 43 == 0 or (x * 3 + y) % 51 == 0:
				img.set_pixel(x, y, Color(1, 1, 1, 0.65)) # Fine cracks

	return ImageTexture.create_from_image(img)

func _setup_particles() -> void:
	if shatter_particles:
		return

	shatter_particles = GPUParticles3D.new()
	shatter_particles.name = "ShatterParticles"
	shatter_particles.top_level = true
	shatter_particles.amount = 75
	shatter_particles.lifetime = 1.2
	shatter_particles.one_shot = true
	shatter_particles.explosiveness = 0.98
	shatter_particles.emitting = false

	var mat_proc: ParticleProcessMaterial = ParticleProcessMaterial.new()
	mat_proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat_proc.emission_box_extents = Vector3(1.4, 0.05, 1.4)
	mat_proc.direction = Vector3(0, 1, 0)
	mat_proc.spread = 180.0
	mat_proc.initial_velocity_min = 2.0
	mat_proc.initial_velocity_max = 6.5
	mat_proc.gravity = Vector3(0, -18.0, 0)
	mat_proc.scale_min = 0.05
	mat_proc.scale_max = 0.22

	var draw_mat: StandardMaterial3D = StandardMaterial3D.new()
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.albedo_color = Color(0.8, 0.95, 1.0, 0.75)
	draw_mat.roughness = 0.08

	var shard_mesh: PrismMesh = PrismMesh.new()
	shard_mesh.material = draw_mat
	shard_mesh.size = Vector3(0.12, 0.15, 0.05)

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

	if _glass_material:
		_glass_material.albedo_color = Color(1.0, 0.4, 0.4, 0.6) # Red warning crack tint

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

	if shatter_particles:
		shatter_particles.global_position = global_position
		shatter_particles.restart()
		shatter_particles.emitting = true

	glass_shattered.emit()
	print("💥 GLASS FLOOR SHATTERED! Fat collapsed through the floor!")

	if respawn_time > 0.0:
		get_tree().create_timer(respawn_time).timeout.connect(restore_floor)

func restore_floor() -> void:
	rpc_restore_floor.rpc()

@rpc("any_peer", "call_local", "reliable")
func rpc_restore_floor() -> void:
	is_broken = false
	_is_breaking = false
	if collision_shape:
		collision_shape.set_deferred("disabled", false)
	if mesh_instance:
		mesh_instance.show()
	if _glass_material:
		_glass_material.albedo_color = Color(0.7, 0.9, 0.98, 0.35)
	print("✨ GLASS FLOOR RESTORED!")
